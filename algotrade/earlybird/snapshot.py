"""Option-chain snapshotting for the Early Bird scanner.

Builds the F&O universe from Kite's NFO instrument dump once per day, then on
each cycle fetches spot + near-ATM strikes (OI, volume, LTP) for every
underlying in batched quote calls. Snapshots persist to one JSON file per day
so the detector can compare against a baseline and, later, be backtested.
"""

from __future__ import annotations

import datetime as dt
import json
import logging
from collections import defaultdict
from pathlib import Path

from ..timeutils import IST

log = logging.getLogger(__name__)

INDEX_SPOT_KEY = {
    "NIFTY": "NSE:NIFTY 50",
    "BANKNIFTY": "NSE:NIFTY BANK",
    "FINNIFTY": "NSE:NIFTY FIN SERVICE",
    "MIDCPNIFTY": "NSE:NIFTY MID SELECT",
}
QUOTE_BATCH = 400
RETENTION_DAYS = 21


def _chunks(items: list, n: int):
    for i in range(0, len(items), n):
        yield items[i:i + n]


class ChainSnapshotter:
    def __init__(self, kite, strikes_each_side: int = 5, min_dte: int = 1):
        self.kite = kite
        self.strikes_each_side = strikes_each_side
        self.min_dte = min_dte
        self._built_for: dt.date | None = None
        self._chains: dict[str, dict] = {}  # SYM -> {expiry, dte, strikes: {strike: {CE: tsym, PE: tsym}}}

    def _build_universe(self) -> None:
        today = dt.datetime.now(IST).date()
        if self._built_for == today:
            return
        by_name: dict[str, list] = defaultdict(list)
        for inst in self.kite.instruments("NFO"):
            if inst["instrument_type"] in ("CE", "PE"):
                by_name[inst["name"]].append(inst)
        chains = {}
        for name, opts in by_name.items():
            expiries = sorted({o["expiry"] for o in opts})
            expiry = next((e for e in expiries if (e - today).days >= self.min_dte), None)
            if expiry is None:
                continue
            strikes: dict[float, dict] = defaultdict(dict)
            for o in opts:
                if o["expiry"] == expiry:
                    strikes[float(o["strike"])][o["instrument_type"]] = o["tradingsymbol"]
            chains[name] = {
                "expiry": expiry,
                "dte": (expiry - today).days,
                "strikes": strikes,
            }
        self._chains = chains
        self._built_for = today
        log.info("earlybird universe: %d underlyings (nearest expiry, dte>=%d)",
                 len(chains), self.min_dte)

    def _spot_quotes(self) -> dict[str, float]:
        keys = [INDEX_SPOT_KEY.get(sym, f"NSE:{sym}") for sym in self._chains]
        spots: dict[str, float] = {}
        rev = {v: k for k, v in INDEX_SPOT_KEY.items()}
        for batch in _chunks(keys, QUOTE_BATCH):
            try:
                for key, q in self.kite.ltp(batch).items():
                    sym = rev.get(key, key.split(":", 1)[1])
                    spots[sym] = float(q["last_price"])
            except Exception as exc:
                log.warning("spot ltp batch failed: %s", exc)
        return spots

    def take(self) -> dict:
        """One full snapshot: {"ts": iso, "symbols": {SYM: chain-dict}}."""
        self._build_universe()
        spots = self._spot_quotes()

        wanted: list[str] = []          # "NFO:<tradingsymbol>"
        meta: dict[str, tuple] = {}     # tradingsymbol -> (sym, strike, type)
        for sym, chain in self._chains.items():
            spot = spots.get(sym)
            if not spot:
                continue
            ladder = sorted(chain["strikes"])
            atm_i = min(range(len(ladder)), key=lambda i: abs(ladder[i] - spot))
            lo = max(0, atm_i - self.strikes_each_side)
            for strike in ladder[lo:atm_i + self.strikes_each_side + 1]:
                for opt_type, tsym in chain["strikes"][strike].items():
                    wanted.append(f"NFO:{tsym}")
                    meta[tsym] = (sym, strike, opt_type)

        symbols: dict[str, dict] = {
            sym: {"spot": spots[sym], "dte": chain["dte"],
                  "expiry": str(chain["expiry"]), "strikes": []}
            for sym, chain in self._chains.items() if spots.get(sym)
        }
        for batch in _chunks(wanted, QUOTE_BATCH):
            try:
                quotes = self.kite.quote(batch)
            except Exception as exc:
                log.warning("chain quote batch failed: %s", exc)
                continue
            for key, q in quotes.items():
                tsym = key.split(":", 1)[1]
                if tsym not in meta:
                    continue
                sym, strike, opt_type = meta[tsym]
                symbols[sym]["strikes"].append({
                    "strike": strike,
                    "type": opt_type,
                    "oi": int(q.get("oi") or 0),
                    "volume": int(q.get("volume") or q.get("volume_traded") or 0),
                    "ltp": float(q.get("last_price") or 0),
                })
        return {"ts": dt.datetime.now(IST).isoformat(), "symbols": symbols}


class SnapshotStore:
    """One JSON file per day holding the day's snapshot list."""

    def __init__(self, directory: Path):
        self.dir = Path(directory)
        self.dir.mkdir(parents=True, exist_ok=True)

    def _file(self, d: dt.date) -> Path:
        return self.dir / f"chains_{d.isoformat()}.json"

    def _load(self, d: dt.date) -> list[dict]:
        try:
            return json.loads(self._file(d).read_text())
        except Exception:
            return []

    def append(self, snap: dict) -> None:
        today = dt.datetime.now(IST).date()
        snaps = self._load(today)
        snaps.append(snap)
        self._file(today).write_text(json.dumps(snaps))
        self._cleanup(today)

    def baseline(self) -> dict | None:
        """Yesterday's last snapshot if available, else today's first."""
        today = dt.datetime.now(IST).date()
        for back in range(1, 4):  # skip weekends/holidays
            prev = self._load(today - dt.timedelta(days=back))
            if prev:
                return prev[-1]
        snaps = self._load(today)
        return snaps[0] if snaps else None

    def today_count(self) -> int:
        return len(self._load(dt.datetime.now(IST).date()))

    def _cleanup(self, today: dt.date) -> None:
        cutoff = today - dt.timedelta(days=RETENTION_DAYS)
        for f in self.dir.glob("chains_*.json"):
            try:
                if dt.date.fromisoformat(f.stem.replace("chains_", "")) < cutoff:
                    f.unlink()
            except Exception:
                pass

"""Early Bird orchestrator: snapshot -> detect -> alert -> log.

Alert-only by design. Every signal is appended to a JSONL log together with
the spot at signal time; the EOD scorecard then records what the stock
actually did, building the evidence needed before any signal is ever traded.
"""

from __future__ import annotations

import datetime as dt
import json
import logging
import time
from pathlib import Path

from ..notify import notify
from ..timeutils import IST, now_ist
from .detector import DetectorConfig, detect
from .snapshot import INDEX_SPOT_KEY, ChainSnapshotter, SnapshotStore

log = logging.getLogger(__name__)

REALERT_SECONDS = 3600     # same symbol+direction: stay quiet for an hour...
REALERT_SCORE_JUMP = 8     # ...unless the score jumps meaningfully
MAX_ALERTS_PER_CYCLE = 5


class EarlyBird:
    def __init__(self, kite, data_dir: Path = Path("data/earlybird"),
                 cfg: DetectorConfig | None = None):
        self.kite = kite
        self.cfg = cfg or DetectorConfig()
        self.snapshotter = ChainSnapshotter(kite)
        self.store = SnapshotStore(data_dir)
        self.signals_file = Path(data_dir) / f"signals_{now_ist().date().isoformat()}.jsonl"
        self._alerted: dict[tuple, tuple] = {}  # (sym, direction) -> (score, ts)
        self._scorecard_done = False

    # ---------- main cycle ----------

    def cycle(self) -> list[dict]:
        snap = self.snapshotter.take()
        if not snap["symbols"]:
            log.warning("empty snapshot — skipping cycle")
            return []
        baseline = self.store.baseline()
        self.store.append(snap)
        signals = detect(baseline, snap, self.cfg)
        log.info("cycle: %d underlyings, %d signals", len(snap["symbols"]), len(signals))

        sent = 0
        for sig in signals:
            self._log_signal(sig)
            if sent < MAX_ALERTS_PER_CYCLE and self._should_alert(sig):
                arrow = {"BULLISH": "🟢", "BEARISH": "🔴"}.get(sig["direction"], "👀")
                notify(f"⚡ {sig['symbol']} {arrow} {sig['direction']} "
                       f"{sig['pattern']} score {sig['score']}\n{sig['detail']}\n"
                       f"spot ₹{sig['spot']:.2f} — signal only, NOT a trade")
                sent += 1
        return signals

    def _should_alert(self, sig: dict) -> bool:
        key = (sig["symbol"], sig["direction"])
        prev_score, prev_ts = self._alerted.get(key, (0, 0.0))
        now = time.time()
        if now - prev_ts < REALERT_SECONDS and sig["score"] < prev_score + REALERT_SCORE_JUMP:
            return False
        self._alerted[key] = (sig["score"], now)
        return True

    def _log_signal(self, sig: dict) -> None:
        rec = dict(sig, ts=now_ist().isoformat())
        with self.signals_file.open("a") as f:
            f.write(json.dumps(rec) + "\n")

    # ---------- EOD scorecard ----------

    def eod_scorecard(self) -> None:
        """Once, near the close: how did today's signals actually do?"""
        if self._scorecard_done or not self.signals_file.exists():
            self._scorecard_done = True
            return
        best: dict[str, dict] = {}
        for line in self.signals_file.read_text().splitlines():
            try:
                sig = json.loads(line)
            except Exception:
                continue
            cur = best.get(sig["symbol"])
            if cur is None or sig["score"] > cur["score"]:
                best[sig["symbol"]] = sig
        if not best:
            self._scorecard_done = True
            return

        keys = [INDEX_SPOT_KEY.get(s, f"NSE:{s}") for s in best]
        closes: dict[str, float] = {}
        try:
            rev = {v: k for k, v in INDEX_SPOT_KEY.items()}
            for key, q in self.kite.ltp(keys).items():
                closes[rev.get(key, key.split(":", 1)[1])] = float(q["last_price"])
        except Exception as exc:
            log.warning("scorecard ltp failed: %s", exc)

        lines, moves = [], []
        for sym, sig in sorted(best.items(), key=lambda kv: -kv[1]["score"]):
            close = closes.get(sym)
            if not close or not sig.get("spot"):
                continue
            raw = (close - sig["spot"]) / sig["spot"] * 100
            move = {"BULLISH": raw, "BEARISH": -raw}.get(sig["direction"], abs(raw))
            moves.append(move)
            ok = "✅" if move > 0 else "❌"
            lines.append(f"{ok} {sym} {sig['pattern']} s{sig['score']}: {move:+.2f}%")
            self._log_signal(dict(sig, pattern="EOD_RESULT", detail=f"move {move:+.2f}%"))
        if moves:
            hits = sum(1 for m in moves if m > 0)
            notify("Early Bird scorecard\n" + "\n".join(lines[:12]) +
                   f"\n{hits}/{len(moves)} in direction, avg {sum(moves)/len(moves):+.2f}%")
        self._scorecard_done = True


def run_loop(kite, interval_seconds: int = 600) -> None:
    """Market-hours scan loop; exits after close."""
    open_t, close_t, scorecard_t = dt.time(9, 16), dt.time(15, 30), dt.time(15, 18)
    bird = EarlyBird(kite)
    notify(f"Early Bird scanner online — chain scan every {interval_seconds//60} min "
           f"[ALERT-ONLY, no orders]")
    while True:
        now = now_ist()
        if now.time() >= close_t:
            bird.eod_scorecard()
            log.info("market closed; scanner stopping")
            return
        if now.time() < open_t:
            time.sleep(30)
            continue
        if now.time() >= scorecard_t:
            bird.eod_scorecard()
        try:
            bird.cycle()
        except Exception:
            log.exception("scan cycle failed; continuing")
        time.sleep(interval_seconds)

"""STOCK OPTIONS selling — monthly Iron Condors on liquid F&O stocks. PAPER.

The Nifty condor book's sibling, pointed at SINGLE STOCKS from the NSE F&O
list. Each month it sells a defined-risk Iron Condor on up to `max_names`
stocks: short strikes ±dist from spot, wings `wing` beyond, held to the
monthly expiry (last Thursday), settled at spot, rolled.

Stocks are NOT the index — they move harder and gap on earnings. So the book
is deliberately more conservative than the Nifty condor:

  · wider short strikes (±6% vs the index's ±2.5%)
  · monthly cycle (stock weeklies are illiquid; monthlies are the market)
  · 1% of the book risked per name, max `max_names` condors at once
    (worst case month = max_names × 1% — survivable by construction)

The universe reads from fno_stocks.txt at the repo root — paste NSE's full
F&O stock list there (one symbol per line); a liquid large-cap starter set
ships by default. The book takes the FIRST max_names priceable names, so put
the names you want condors on at the top.

HONESTY: the credit is MODELLED (~30% of the wing) exactly like the Nifty
book — win/loss geometry is real, the rupee size is indicative until a live
option chain is wired in. Real stock options are PHYSICALLY SETTLED if they
expire in the money — a real account must exit before expiry; the paper book
cash-settles. PAPER ONLY, never an order.
"""

import json
import os
from calendar import monthrange
from datetime import date, timedelta
from pathlib import Path


def month_expiry(d) -> str:
    """The NSE monthly F&O expiry STRICTLY AFTER d: last Thursday of d's month,
    or of the next month if d is on/past it (a condor opened on expiry day must
    target the next cycle — zero days to expiry is not a trade)."""
    def last_thursday(y, m):
        last = date(y, m, monthrange(y, m)[1])
        return last - timedelta(days=(last.weekday() - 3) % 7)
    e = last_thursday(d.year, d.month)
    if e <= d:
        y, m = (d.year + 1, 1) if d.month == 12 else (d.year, d.month + 1)
        e = last_thursday(y, m)
    return e.isoformat()


def load_fno_universe() -> list:
    """F&O stock symbols from fno_stocks.txt (repo root; FNO_STOCKS to
    override). One NSE symbol per line, '#' comments ignored, order kept —
    the book opens condors from the TOP of this list."""
    env = os.environ.get("FNO_STOCKS", "")
    cands = ([Path(env)] if env else
             [Path(__file__).resolve().parent.parent / "fno_stocks.txt",
              Path("fno_stocks.txt")])
    p = next((c for c in cands if c.exists()), None)
    if p is None:
        return []
    out = []
    for line in p.read_text(encoding="utf-8-sig").splitlines():
        s = line.split(",")[0].strip().upper()
        if s and not s.startswith("#") and s not in out:
            out.append(s)
    return out


class StockCondorBook:
    """PAPER monthly Iron Condors on F&O stocks (see module docstring)."""

    def __init__(self, capital=1_000_000.0, dist=0.06, wing=0.025,
                 credit_frac=0.30, alloc_pct=0.01, max_names=10,
                 realized=0.0, positions=None, history=None, trades=None):
        self.capital = capital
        self.starting_capital = capital
        self.dist = dist
        self.wing = wing
        self.credit_frac = credit_frac
        self.alloc_pct = alloc_pct            # risk per name (1% of book)
        self.max_names = max_names
        self.realized = realized
        # {sym: {strikes{sp,lp,sc,lc}, entry_spot, entry_date, expiry, risk}}
        self.positions = positions or {}
        self.history = history or []
        self.trades = trades or []

    # --- persistence -------------------------------------------------------
    @classmethod
    def load(cls, path, **kw):
        p = Path(path)
        if p.exists():
            d = json.loads(p.read_text())
            d.update(kw)
            return cls(**d)
        return cls(**kw)

    def save(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(json.dumps({
            "capital": self.starting_capital, "dist": self.dist,
            "wing": self.wing, "credit_frac": self.credit_frac,
            "alloc_pct": self.alloc_pct, "max_names": self.max_names,
            "realized": self.realized, "positions": self.positions,
            "history": self.history[-800:], "trades": self.trades[-500:],
        }, indent=2))

    # --- condor math (same transparent model as the Nifty book) ------------
    @property
    def _max_loss_frac(self):
        return self.wing * (1 - self.credit_frac)

    def _net_frac(self, pos, spot_now):
        credit = self.credit_frac * self.wing * pos["entry_spot"]
        sc, sp = pos["strikes"]["sc"], pos["strikes"]["sp"]
        w = self.wing * pos["entry_spot"]
        if spot_now >= sc:
            net = credit - min(spot_now - sc, w)
        elif spot_now <= sp:
            net = credit - min(sp - spot_now, w)
        else:
            net = credit
        return net / pos["entry_spot"]

    def _pnl_rupees(self, pos, spot_now):
        return (self._net_frac(pos, spot_now) / self._max_loss_frac
                * (self.starting_capital * self.alloc_pct))

    # --- the monthly cycle -------------------------------------------------
    def _open(self, sym, spot, today):
        self.positions[sym] = {
            "strikes": {"sp": round(spot * (1 - self.dist), 1),
                        "lp": round(spot * (1 - self.dist - self.wing), 1),
                        "sc": round(spot * (1 + self.dist), 1),
                        "lc": round(spot * (1 + self.dist + self.wing), 1)},
            "entry_spot": spot, "entry_date": today.isoformat(),
            "expiry": month_expiry(today),
            "risk": round(self.starting_capital * self.alloc_pct, 0),
        }
        self.trades.append({"date": today.isoformat(), "side": "OPEN",
                            "symbol": sym, "spot": round(spot, 2),
                            "expiry": self.positions[sym]["expiry"]})

    def _settle(self, sym, spot, today):
        pnl = self._pnl_rupees(self.positions[sym], spot)
        self.realized += pnl
        self.trades.append({"date": today.isoformat(), "side": "SETTLE",
                            "symbol": sym, "spot": round(spot, 2),
                            "pnl": round(pnl, 0)})
        del self.positions[sym]

    def step(self, prices: dict, today, market_open, universe=None):
        """Daily advance: settle condors at/after their monthly expiry, then
        open new ones from the universe (priceable, not held) up to max_names.
        Only transacts while the market is open — like every Garuda book."""
        if not market_open:
            return
        for sym in list(self.positions):
            pos = self.positions[sym]
            spot = prices.get(sym) or 0.0
            if today.isoformat() >= pos["expiry"] and spot > 0:
                self._settle(sym, spot, today)
        want = universe if universe is not None else load_fno_universe()
        for sym in want:
            if len(self.positions) >= self.max_names:
                break
            spot = prices.get(sym) or 0.0
            if sym in self.positions or spot <= 0:
                continue
            self._open(sym, spot, today)

    # --- dashboard view ----------------------------------------------------
    def state(self, prices: dict):
        rows, unreal = [], 0.0
        for sym, pos in self.positions.items():
            spot = prices.get(sym) or pos["entry_spot"]
            mark = self._pnl_rupees(pos, spot)
            unreal += mark
            s = pos["strikes"]
            try:
                y, m, d = (int(x) for x in pos["expiry"].split("-"))
                dte = (date(y, m, d) - date.today()).days
            except ValueError:
                dte = None
            rows.append({"sym": sym, "spot": round(spot, 2),
                         "sp": s["sp"], "sc": s["sc"],
                         "expiry": pos["expiry"], "dte": dte,
                         "in_range": bool(s["sp"] < spot < s["sc"]),
                         "mark": round(mark, 0), "risk": pos["risk"]})
        rows.sort(key=lambda r: r["mark"])
        settles = [t for t in self.trades if t.get("side") == "SETTLE"]
        wins = sum(1 for t in settles if (t.get("pnl") or 0) > 0)
        equity = self.starting_capital + self.realized + unreal
        return {
            "positions": rows, "n": len(rows), "max_names": self.max_names,
            "risk_per_name": round(self.starting_capital * self.alloc_pct, 0),
            "dist_pct": round(self.dist * 100, 1),
            "realized": round(self.realized, 0), "unrealized": round(unreal, 0),
            "equity": round(equity, 0),
            "pnl_pct": round((equity / self.starting_capital - 1) * 100, 2),
            "settled": len(settles), "wins": wins,
            "win_pct": round(wins / len(settles) * 100) if settles else None,
        }

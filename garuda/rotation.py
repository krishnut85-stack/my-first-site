"""PAPER industry-rotation book — the tested rule, running forward.

What it does, once a week is irrelevant and once every six months is the point:

    hold the top 5 industries by 6-month momentum, equally weighted,
    and do not touch them again for 6 months.

That rule earned +49.31%/yr against a +38.44% benchmark on the 2020-2026 years
it had never seen, and +29.30% against +19.0% on the years before them — the
same ~10-point excess in two eras fourteen years apart. This book runs it
forward on live prices so the claim can be checked rather than believed.

Deliberately narrow
-------------------
* **It does not choose.** The industries come from rotation_study.json, which
  is produced by the backtest itself. If that file is stale or missing the book
  holds what it has and says so — it never falls back to a fresh opinion.
* **It skips what the backtest could not vouch for.** An industry whose stocks
  listed last year has no 20-year evidence behind it; those picks are dropped
  here, not quietly bought.
* **It does nothing between rebalances.** No stops, no trims, no reacting to
  news. Six months of sitting still is the strategy, and a book that flinches
  is testing something else.

Paper only. It holds a LivePortfolio like every other Garuda book, so its
equity, trades and P&L are counted exactly the same way.
"""

import json
from datetime import date
from pathlib import Path

from .portfolio import LivePortfolio

#: The rule, as validated. Changing these means the backtest no longer applies.
LOOKBACK_M = 6
HOLD_M = 6
TOP_K = 5

CAPITAL = 1_000_000.0


def _today():
    return date.today().isoformat()


def months_between(a, b):
    """Whole months from 'YYYY-MM-DD' a to b (negative if b precedes a)."""
    ay, am = int(a[:4]), int(a[5:7])
    by, bm = int(b[:4]), int(b[5:7])
    return (by - ay) * 12 + (bm - am)


class RotationBook:
    """The rotation rule as a book: picks in, equal weight, six months' silence."""

    def __init__(self, capital=CAPITAL, hold_m=HOLD_M, top_k=TOP_K,
                 lookback_m=LOOKBACK_M, portfolio=None, opened=None,
                 industries=None, skipped=None, study_as_of=None, notes=None):
        self.capital = capital
        self.hold_m = hold_m
        self.top_k = top_k
        self.lookback_m = lookback_m
        self.pf = portfolio or LivePortfolio(capital)
        self.opened = opened              # date of the last rebalance
        self.industries = industries or []   # what we hold, by name
        self.skipped = skipped or []      # picks dropped for thin history
        self.study_as_of = study_as_of
        self.notes = notes or []

    # ---------------------------------------------------------- persistence --
    @classmethod
    def load(cls, path, capital=CAPITAL, **kw):
        p = Path(path)
        if p.exists():
            d = json.loads(p.read_text())
            pf = LivePortfolio(**d.pop("portfolio", {"starting_capital": capital}))
            d.update(kw)
            return cls(portfolio=pf, **d)
        return cls(capital=capital, **kw)

    def save(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(json.dumps({
            "capital": self.capital, "hold_m": self.hold_m,
            "top_k": self.top_k, "lookback_m": self.lookback_m,
            "opened": self.opened, "industries": self.industries,
            "skipped": self.skipped, "study_as_of": self.study_as_of,
            "notes": self.notes[-20:],
            "portfolio": {
                "starting_capital": self.pf.starting_capital,
                "cash": self.pf.cash, "holdings": self.pf.holdings,
                "realized": self.pf.realized,
                "trades": self.pf.trades[-500:],
                "history": self.pf.history[-800:],
            },
        }, indent=2))

    # ------------------------------------------------------------- the rule --
    def due(self, today=None):
        """Is a rebalance owed? True before the first one, then every hold_m."""
        today = today or _today()
        if not self.opened or not self.pf.holdings:
            return True
        return months_between(self.opened, today) >= self.hold_m

    def next_rerank(self):
        if not self.opened:
            return None
        y, m = int(self.opened[:4]), int(self.opened[5:7]) + self.hold_m
        y, m = y + (m - 1) // 12, (m - 1) % 12 + 1
        return f"{y:04d}-{m:02d}"

    def targets(self, study):
        """(industries, {industry: [symbols]}, skipped) from the study file.

        Picks the backtest flagged as thin-history are removed here rather than
        bought with a warning: an industry that listed last year is not the
        thing the twenty-year test measured.
        """
        today = ((study or {}).get("today") or {})
        picks = today.get("picks") or []
        keep, members, skipped = [], {}, []
        for p in picks:
            name = p.get("industry")
            syms = [s for s in (p.get("members") or []) if s]
            if not name or not syms:
                continue
            if p.get("thin_history"):
                skipped.append({"industry": name,
                                "months": p.get("history_months")})
                continue
            keep.append(name)
            members[name] = syms
        return keep, members, skipped

    def adopt_rule(self, study):
        """Take the rule from the study rather than assuming one.

        The study picks whichever lookback/hold/K survived both halves, and
        that choice moves when the data does. A book that holds a 3-month
        rule's picks for 6 months is running neither rule — so the hold period
        comes from the file that produced the picks, not from a constant here.
        Returns a note when the rule changed, else None.
        """
        rule = ((study or {}).get("today") or {}).get("rule") or {}
        if not rule:
            return None
        before = (self.lookback_m, self.hold_m, self.top_k)
        self.lookback_m = int(rule.get("lookback") or self.lookback_m)
        self.hold_m = int(rule.get("hold") or self.hold_m)
        self.top_k = int(rule.get("k") or self.top_k)
        after = (self.lookback_m, self.hold_m, self.top_k)
        if before == after:
            return None
        return (f"rule changed: look {before[0]}m hold {before[1]}m "
                f"top{before[2]} -> look {after[0]}m hold {after[1]}m "
                f"top{after[2]}")

    def rebalance(self, prices, study, today=None):
        """Sell everything, buy the study's picks equally weighted. Returns a note."""
        today = today or _today()
        changed = self.adopt_rule(study)
        if changed:
            self.notes.append({"date": today, "note": changed})
        keep, members, skipped = self.targets(study)
        if not keep:
            note = "no usable picks in the study — holding"
            self.notes.append({"date": today, "note": note})
            return note

        for sym in list(self.pf.holdings):
            px = prices.get(sym)
            if px:
                self.pf.sell(sym, px, reason="ROTATE", date=today)
        # anything unpriceable stays put rather than being marked out at a guess
        stuck = list(self.pf.holdings)

        equity = self.pf.cash + sum(
            h["qty"] * (prices.get(s) or h["entry_price"])
            for s, h in self.pf.holdings.items())
        per_industry = equity / len(keep)
        bought = 0
        for ind in keep:
            syms = [s for s in members[ind] if prices.get(s)]
            if not syms:
                continue
            per_stock = per_industry / len(syms)
            for s in syms:
                px = prices[s]
                qty = int(per_stock // px)
                if qty > 0 and self.pf.buy(s, qty, px, entry_len=0, date=today):
                    bought += 1

        self.opened = today
        self.industries = keep
        self.skipped = skipped
        self.study_as_of = ((study or {}).get("today") or {}).get("as_of")
        note = (f"rebalanced into {len(keep)} industries, {bought} positions"
                + (f"; skipped {len(skipped)} thin-history" if skipped else "")
                + (f"; {len(stuck)} unpriceable held" if stuck else ""))
        self.notes.append({"date": today, "note": note})
        return note

    def step(self, prices, today, market_open, study):
        """Rebalance only when due, and only while the market is open.

        Between rebalances this deliberately does nothing at all.
        """
        if not market_open or not prices:
            return None
        if not self.due(today):
            return None
        return self.rebalance(prices, study, today)

    # ------------------------------------------------------------- reporting --
    def equity(self, price_of):
        return self.pf.equity(price_of)

    def state(self, price_of):
        eq = self.equity(price_of)
        pos = []
        for s, h in self.pf.holdings.items():
            ltp = price_of(s) or h["entry_price"]
            pos.append({"sym": s, "qty": h["qty"],
                        "entry": round(h["entry_price"], 2),
                        "ltp": round(ltp, 2),
                        "chg": round((ltp / h["entry_price"] - 1) * 100, 2)
                        if h["entry_price"] else 0.0,
                        "pnl": round((ltp - h["entry_price"]) * h["qty"], 0)})
        pos.sort(key=lambda p: p["pnl"], reverse=True)
        return {
            "capital": self.pf.starting_capital,
            "equity": round(eq, 0),
            "pnl_pct": round((eq / self.pf.starting_capital - 1) * 100, 2)
            if self.pf.starting_capital else 0.0,
            "cash": round(self.pf.cash, 0),
            "industries": self.industries,
            "skipped": self.skipped,
            "opened": self.opened,
            "next_rerank": self.next_rerank(),
            "hold_m": self.hold_m, "lookback_m": self.lookback_m,
            "top_k": self.top_k,
            "study_as_of": self.study_as_of,
            "positions": pos,
            "notes": self.notes[-5:],
            "rule": (f"top {self.top_k} industries by {self.lookback_m}-month "
                     f"momentum, equal weight, held {self.hold_m} months"),
        }

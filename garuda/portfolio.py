"""Garuda paper portfolio — persistent, position-sized, no arbitrary count cap.

PAPER ONLY: tracks cash, holdings, realised P&L and an equity curve on disk so a
daily scan builds a real forward track record. No live orders here.
"""

import json
from pathlib import Path


def _today():
    from datetime import datetime, timezone, timedelta
    ist = timezone(timedelta(hours=5, minutes=30))
    return datetime.now(ist).date().isoformat()


class LivePortfolio:
    def __init__(self, starting_capital, cash=None, holdings=None,
                 realized=0.0, trades=None, history=None):
        self.starting_capital = starting_capital
        self.cash = starting_capital if cash is None else cash
        self.holdings = holdings or {}   # symbol -> {qty, entry_price, entry_date, entry_len}
        self.realized = realized
        self.trades = trades or []       # capped log
        self.history = history or []     # [{date, equity}]

    @classmethod
    def load(cls, path, starting_capital):
        p = Path(path)
        if p.exists():
            return cls(**json.loads(p.read_text()))
        return cls(starting_capital)

    def save(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(json.dumps({
            "starting_capital": self.starting_capital,
            "cash": self.cash,
            "holdings": self.holdings,
            "realized": self.realized,
            "trades": self.trades[-500:],
            "history": self.history[-800:],
        }, indent=2))

    def buy(self, symbol, qty, price, entry_len, date=None):
        cost = qty * price
        if qty <= 0 or cost > self.cash:
            return False
        date = date or _today()
        self.cash -= cost
        self.holdings[symbol] = {"qty": qty, "entry_price": price,
                                 "entry_date": date, "entry_len": entry_len,
                                 "bars_held": 0, "last_date": date}
        self.trades.append({"date": date, "side": "BUY", "symbol": symbol,
                            "qty": qty, "price": round(price, 2)})
        return True

    def scale_in(self, symbol, qty, price, entry_len, date=None):
        """Buy OR average into a holding (for the scale-in book): first unit opens
        the position; later units blend the entry price and bump the unit count."""
        cost = qty * price
        if qty <= 0 or cost > self.cash:
            return False
        date = date or _today()
        self.cash -= cost
        h = self.holdings.get(symbol)
        if h:                                          # average in
            tot = h["qty"] + qty
            h["entry_price"] = (h["entry_price"] * h["qty"] + price * qty) / tot
            h["qty"] = tot
            h["units"] = h.get("units", 1) + 1
            h["last_add"] = price
        else:                                          # first unit
            self.holdings[symbol] = {"qty": qty, "entry_price": price,
                                     "entry_date": date, "entry_len": entry_len,
                                     "bars_held": 0, "last_date": date,
                                     "units": 1, "last_add": price}
        self.trades.append({"date": date, "side": "BUY", "symbol": symbol,
                            "qty": qty, "price": round(price, 2)})
        return True

    def sell(self, symbol, price, reason="", date=None):
        h = self.holdings.get(symbol)
        if not h:
            return 0.0
        date = date or _today()
        proceeds = h["qty"] * price
        pnl = proceeds - h["qty"] * h["entry_price"]
        self.cash += proceeds
        self.realized += pnl
        self.trades.append({"date": date, "side": "SELL", "symbol": symbol,
                            "qty": h["qty"], "price": round(price, 2),
                            "reason": reason, "pnl": round(pnl, 2)})
        del self.holdings[symbol]
        return pnl

    def holdings_value(self, price_of):
        return sum(h["qty"] * (price_of(s) or h["entry_price"])
                   for s, h in self.holdings.items())

    def equity(self, price_of):
        return self.cash + self.holdings_value(price_of)

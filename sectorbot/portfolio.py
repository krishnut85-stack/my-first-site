"""Persistent paper-trading portfolio (survives across runs via JSON).

This is what makes the paper trading a real forward track record: positions,
cash and realised P&L are saved to data/portfolio.json and reloaded on the next
run. Still PAPER -- no real orders are placed.
"""

import json
from pathlib import Path

from . import config


def _today() -> str:
    from .data_loader import IST
    from datetime import datetime
    return datetime.now(IST).date().isoformat()


class Portfolio:
    def __init__(self, starting_capital, cash, holdings=None,
                 realized_pnl=0.0, history=None, trades=None):
        self.starting_capital = starting_capital
        self.cash = cash
        # holdings: {symbol: {qty, avg_price, entry_date, peak_price, atr}}
        self.holdings = holdings or {}
        self.realized_pnl = realized_pnl
        self.history = history or []   # [{date, equity}]
        self.trades = trades or []     # log (most recent kept)

    # --- persistence -------------------------------------------------------
    @classmethod
    def load(cls, path=None) -> "Portfolio":
        path = Path(path or config.PORTFOLIO_JSON)
        if path.exists():
            d = json.loads(path.read_text())
            return cls(**d)
        return cls(config.PAPER_CAPITAL, config.PAPER_CAPITAL)

    def save(self, path=None) -> None:
        path = Path(path or config.PORTFOLIO_JSON)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({
            "starting_capital": self.starting_capital,
            "cash": self.cash,
            "holdings": self.holdings,
            "realized_pnl": self.realized_pnl,
            "history": self.history[-400:],   # cap growth
            "trades": self.trades[-200:],
        }, indent=2))

    # --- operations (simulated) -------------------------------------------
    def buy(self, symbol, qty, price, atr=0.0, reason="", breakout_level=None):
        cost = qty * price
        if qty <= 0 or cost > self.cash:
            return False
        self.cash -= cost
        self.holdings[symbol] = {
            "qty": qty, "avg_price": price, "entry_date": _today(),
            "peak_price": price, "atr": atr, "breakout_level": breakout_level,
        }
        self.trades.append({"date": _today(), "side": "BUY", "symbol": symbol,
                            "qty": qty, "price": round(price, 2), "reason": reason})
        return True

    def sell(self, symbol, price, reason=""):
        h = self.holdings.get(symbol)
        if not h:
            return 0.0
        proceeds = h["qty"] * price
        pnl = proceeds - h["qty"] * h["avg_price"]
        self.cash += proceeds
        self.realized_pnl += pnl
        self.trades.append({"date": _today(), "side": "SELL", "symbol": symbol,
                            "qty": h["qty"], "price": round(price, 2),
                            "reason": reason, "pnl": round(pnl, 2)})
        del self.holdings[symbol]
        return pnl

    # --- reporting ---------------------------------------------------------
    def holdings_value(self, price_of) -> float:
        return sum(h["qty"] * price_of(s) for s, h in self.holdings.items())

    def equity(self, price_of) -> float:
        return self.cash + self.holdings_value(price_of)

    def unrealized_pnl(self, price_of) -> float:
        return sum((price_of(s) - h["avg_price"]) * h["qty"]
                   for s, h in self.holdings.items())

"""A simulated broker. Tracks virtual cash, positions and P&L.

No real orders are ever placed here. This lets you watch how a strategy behaves
before risking a single rupee. A future LiveBroker would implement the same
methods using kite.place_order(...).
"""

from dataclasses import dataclass, field


@dataclass
class Position:
    symbol: str
    qty: int
    avg_price: float

    def market_value(self, ltp: float) -> float:
        return self.qty * ltp

    def pnl(self, ltp: float) -> float:
        return (ltp - self.avg_price) * self.qty


@dataclass
class Trade:
    symbol: str
    side: str          # "BUY" or "SELL"
    qty: int
    price: float
    reason: str = ""


class PaperBroker:
    def __init__(self, capital: float):
        self.starting_capital = capital
        self.cash = capital
        self.positions: dict[str, Position] = {}
        self.trades: list[Trade] = []

    # --- order placement (simulated) --------------------------------------
    def buy(self, symbol: str, qty: int, price: float, reason: str = "") -> bool:
        cost = qty * price
        if qty <= 0 or cost > self.cash:
            return False
        self.cash -= cost
        pos = self.positions.get(symbol)
        if pos:
            total_qty = pos.qty + qty
            pos.avg_price = (pos.avg_price * pos.qty + price * qty) / total_qty
            pos.qty = total_qty
        else:
            self.positions[symbol] = Position(symbol, qty, price)
        self.trades.append(Trade(symbol, "BUY", qty, price, reason))
        return True

    def sell(self, symbol: str, qty: int, price: float, reason: str = "") -> bool:
        pos = self.positions.get(symbol)
        if not pos or qty <= 0 or qty > pos.qty:
            return False
        self.cash += qty * price
        pos.qty -= qty
        self.trades.append(Trade(symbol, "SELL", qty, price, reason))
        if pos.qty == 0:
            del self.positions[symbol]
        return True

    # --- reporting ---------------------------------------------------------
    def equity(self, price_of) -> float:
        """Total portfolio value = cash + market value of open positions."""
        holdings = sum(p.market_value(price_of(s)) for s, p in self.positions.items())
        return self.cash + holdings

    def total_pnl(self, price_of) -> float:
        return self.equity(price_of) - self.starting_capital

    def total_pnl_pct(self, price_of) -> float:
        return self.total_pnl(price_of) / self.starting_capital * 100.0

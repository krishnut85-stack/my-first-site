"""Bar-based backtester that reuses the PaperBroker and live Strategy interface.

Feed it a DataFrame of OHLCV bars (datetime index) per symbol; it replays them
through the strategy, fills at the current bar's close, and reports stats.
Single-symbol strategies only (sufficient for futures strategies; options
backtests need historical chain data).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import numpy as np
import pandas as pd

from .brokers.paper import PaperBroker
from .risk import RiskManager
from .strategies.base import Context, Strategy

log = logging.getLogger(__name__)


@dataclass
class BacktestResult:
    equity_curve: pd.Series
    trades: int
    total_pnl: float
    max_drawdown: float
    win_rate: float
    sharpe: float

    def summary(self) -> str:
        return (
            f"trades={self.trades}  pnl={self.total_pnl:,.0f}  "
            f"max_dd={self.max_drawdown:,.0f}  win_rate={self.win_rate:.0%}  "
            f"sharpe={self.sharpe:.2f}"
        )


class Backtester:
    def __init__(self, strategy: Strategy, risk: RiskManager, symbol: str,
                 bars: pd.DataFrame, slippage_bps: float = 5.0,
                 cost_per_order: float = 25.0):
        required = {"open", "high", "low", "close"}
        missing = required - set(bars.columns)
        if missing:
            raise ValueError(f"bars missing columns: {missing}")
        self.symbol = symbol
        self.bars = bars.sort_index()
        self._idx = 0
        self.broker = PaperBroker(self._quote, slippage_bps, cost_per_order)
        self.risk = risk
        self.strategy = strategy
        self.ctx = Context(self.broker, risk, history_fn=self._history)

    def _quote(self, symbol: str) -> float:
        if symbol != self.symbol:
            raise KeyError(f"no data for {symbol}")
        return float(self.bars["close"].iloc[self._idx])

    def _history(self, symbol: str, lookback: int) -> pd.DataFrame:
        if symbol != self.symbol:
            raise KeyError(f"no data for {symbol}")
        start = max(0, self._idx + 1 - lookback)
        return self.bars.iloc[start : self._idx + 1]

    def run(self) -> BacktestResult:
        self.strategy.on_start(self.ctx)
        equity = []
        last_session = None
        for i, ts in enumerate(self.bars.index):
            self._idx = i
            self.ctx.now = ts.to_pydatetime()

            session = ts.date()
            if last_session is not None and session != last_session:
                # New session: reset the daily kill switch.
                self.risk.kill_switch = False
            last_session = session

            if self.risk.check_daily_loss(self.broker) or self.risk.should_square_off(
                ts.time()
            ):
                if any(p.quantity for p in self.broker.positions().values()):
                    self.broker.square_off_all(tag="eod")
                    self.strategy.on_square_off(self.ctx)
            else:
                self.strategy.on_bar(self.ctx)
            equity.append(self.broker.total_pnl())

        self._idx = len(self.bars) - 1
        if any(p.quantity for p in self.broker.positions().values()):
            self.broker.square_off_all(tag="final")
            equity[-1] = self.broker.total_pnl()

        return self._stats(pd.Series(equity, index=self.bars.index))

    def _stats(self, equity: pd.Series) -> BacktestResult:
        drawdown = equity - equity.cummax()
        fills = [o for o in self.broker.order_log if o.status.value == "FILLED"]
        round_trips = len(fills) // 2
        daily = equity.resample("1D").last().dropna().diff().dropna()
        win_rate = float((daily > 0).mean()) if len(daily) else 0.0
        sharpe = (
            float(daily.mean() / daily.std() * np.sqrt(252))
            if len(daily) > 1 and daily.std() > 0
            else 0.0
        )
        return BacktestResult(
            equity_curve=equity,
            trades=round_trips,
            total_pnl=float(equity.iloc[-1]) if len(equity) else 0.0,
            max_drawdown=float(drawdown.min()) if len(drawdown) else 0.0,
            win_rate=win_rate,
            sharpe=sharpe,
        )


def load_bars_csv(path: str) -> pd.DataFrame:
    """Load OHLCV bars from CSV with columns: datetime,open,high,low,close[,volume]."""
    df = pd.read_csv(path, parse_dates=["datetime"], index_col="datetime")
    df.columns = [c.lower() for c in df.columns]
    return df

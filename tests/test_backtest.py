import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from run_backtest import SYMBOL, synthetic_bars

from algotrade.backtest import Backtester
from algotrade.instruments import LOT_SIZES
from algotrade.risk import RiskLimits, RiskManager
from algotrade.strategies import EmaCrossover


def test_backtest_runs_end_to_end():
    bars = synthetic_bars(days=10)
    lot = LOT_SIZES["NIFTY"]
    risk = RiskManager(RiskLimits(capital=500_000, max_daily_loss=50_000), lot_size=lot)
    strategy = EmaCrossover(symbol=SYMBOL, lot_size=lot)
    result = Backtester(strategy, risk, SYMBOL, bars).run()

    assert len(result.equity_curve) == len(bars)
    assert result.max_drawdown <= 0


def test_no_overnight_positions():
    bars = synthetic_bars(days=5)
    lot = LOT_SIZES["NIFTY"]
    risk = RiskManager(RiskLimits(capital=500_000, max_daily_loss=50_000), lot_size=lot)
    strategy = EmaCrossover(symbol=SYMBOL, lot_size=lot)
    bt = Backtester(strategy, risk, SYMBOL, bars)
    bt.run()
    assert all(p.quantity == 0 for p in bt.broker.positions().values())

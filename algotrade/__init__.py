"""NSE F&O algorithmic trading framework.

Modules:
    instruments  - NSE F&O symbols, expiries, lot sizes
    options      - Black-Scholes pricing and Greeks
    risk         - position sizing, stop losses, daily loss limits
    brokers      - broker adapters (paper trading, Zerodha Kite)
    strategies   - pluggable trading strategies
    engine       - live/paper trading loop
    backtest     - bar-based backtesting engine
"""

__version__ = "0.1.0"

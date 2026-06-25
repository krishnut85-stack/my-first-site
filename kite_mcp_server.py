"""Claude Code ⇄ Zerodha Kite — a local MCP bridge.

This is the Kite analogue of the "Claude controls TradingView via a local MCP
bridge" idea: a small MCP (Model Context Protocol) server that exposes your
Kite-backed SectorBot engine as tools Claude Code can call directly in chat.

Once registered (see .mcp.json / MCP_BRIDGE.md), you can just say things like:
    "what's the LTP of RELIANCE?"
    "rank the top 10 industries"
    "run the backtest"
    "show my paper portfolio"
    "run a paper session and Telegram me the result"
and Claude calls the tools below — no copy-pasting numbers around.

SAFETY BY DESIGN
----------------
This bridge is READ + PAPER only. It can fetch quotes/history, rank industries,
backtest, run the *paper* portfolio, and send Telegram alerts. It deliberately
exposes NO live-order tool — placing real Zerodha orders from an LLM chat is
not something this basic bridge will do. Add that yourself, behind your own
confirmations, only once you fully trust the setup.

Run standalone (for a quick smoke test):
    pip install mcp
    python kite_mcp_server.py        # speaks MCP over stdio; Ctrl-C to stop
"""

import sys

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:  # pragma: no cover
    sys.stderr.write(
        "\n[kite-mcp] The 'mcp' package is not installed.\n"
        "          Install it with:  pip install mcp\n"
        "          (it powers the Model Context Protocol server.)\n\n"
    )
    raise

mcp = FastMCP("claude-code-kite")


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
def _ds():
    """The active price feed (real Kite if keys present, else synthetic)."""
    from sectorbot.datasource import get_datasource
    return get_datasource()


def _is_real(ds) -> bool:
    from sectorbot.datasource import PaperDataSource
    return not isinstance(ds, PaperDataSource)


# --------------------------------------------------------------------------
# Tools
# --------------------------------------------------------------------------
@mcp.tool()
def kite_status() -> dict:
    """Report whether the bridge is talking to REAL Kite data or synthetic
    prices, plus which env vars are configured. Start here to verify setup."""
    from sectorbot import config
    ds = _ds()
    return {
        "real_kite_data": _is_real(ds),
        "kite_api_key_set": bool(config.KITE_API_KEY),
        "access_token_resolved": bool(config.resolve_access_token()),
        "use_kite_data": config.USE_KITE_DATA,
        "live_trading": config.LIVE_TRADING,  # always False unless you flip it
        "telegram_configured": bool(config.TELEGRAM_BOT_TOKEN
                                    and config.TELEGRAM_CHAT_ID),
        "note": ("REAL prices in use." if _is_real(ds)
                 else "SYNTHETIC prices — set KITE_API_KEY + token for real data."),
    }


@mcp.tool()
def get_quote(symbol: str) -> dict:
    """Last traded price for an NSE symbol (e.g. 'RELIANCE', 'INFY').

    Uses live Kite LTP when configured, otherwise a clearly-flagged synthetic
    price so the tool always works offline."""
    ds = _ds()
    symbol = symbol.strip().upper()
    price = ds.last_price(symbol)
    return {
        "symbol": symbol,
        "last_price": round(float(price), 2),
        "source": "kite_live" if _is_real(ds) else "synthetic_demo",
    }


@mcp.tool()
def get_history(symbol: str, bars: int = 60) -> dict:
    """Recent daily OHLC bars for a symbol plus its ATR (volatility).

    With real Kite keys this is genuine historical data; otherwise synthetic.
    `bars` is how many trailing daily candles to return (default 60)."""
    from sectorbot import config
    from sectorbot.indicators import atr
    ds = _ds()
    symbol = symbol.strip().upper()
    bars = max(2, min(int(bars), 400))
    history = ds.history(symbol, bars)
    return {
        "symbol": symbol,
        "source": "kite_live" if _is_real(ds) else "synthetic_demo",
        "atr": round(atr(history, config.ATR_PERIOD), 2),
        "bars": [{"high": b.high, "low": b.low, "close": b.close}
                 for b in history],
    }


@mcp.tool()
def rank_industries(top: int = 10) -> dict:
    """Rank NSE industries by the transparent momentum+quality score and return
    the top `top`, each with representative tradeable symbols. This is the same
    ranking the daily bot trades on."""
    from sectorbot.instruments import symbols_for
    from sectorbot.screener import top_industries
    rows = []
    for ind in top_industries()[: max(1, min(int(top), 50))]:
        rows.append({
            "industry": ind.name,
            "sector": ind.sector,
            "score": round(ind.score, 1),
            "fundamental_score": round(ind.fundamental_score, 1),
            "breadth_score": round(ind.sector_breadth_score, 1),
            "pe": ind.pe,
            "symbols": symbols_for(ind.name),
        })
    return {"count": len(rows), "industries": rows,
            "disclaimer": "Ranking of existing data — not a prediction or advice."}


@mcp.tool()
def run_backtest() -> dict:
    """Walk-forward backtest of the ranking strategy over the daily CSV
    snapshots in sectorbot/data/snapshots/ (needs 2+ days). Compares the
    top-picks strategy to a buy-everything benchmark."""
    from sectorbot.backtest import run_backtest as _bt
    return _bt(verbose=False)


@mcp.tool()
def portfolio_status() -> dict:
    """Current state of the persistent PAPER portfolio (holdings, cash, P&L)
    priced at the latest available prices. Does not place or change anything."""
    from sectorbot.portfolio import Portfolio
    ds = _ds()
    pf = Portfolio.load()
    holdings = []
    holdings_value = 0.0
    for s, h in pf.holdings.items():
        try:
            ltp = float(ds.last_price(s))
        except Exception:  # noqa: BLE001
            ltp = h["avg_price"]
        value = ltp * h["qty"]
        holdings_value += value
        holdings.append({
            "symbol": s, "qty": h["qty"], "avg_price": h["avg_price"],
            "ltp": round(ltp, 2), "pnl": round((ltp - h["avg_price"]) * h["qty"], 2),
            "since": h["entry_date"],
        })
    equity = pf.cash + holdings_value
    return {
        "real_prices": _is_real(ds),
        "starting_capital": pf.starting_capital,
        "cash": round(pf.cash, 2),
        "holdings_value": round(holdings_value, 2),
        "equity": round(equity, 2),
        "total_pnl": round(equity - pf.starting_capital, 2),
        "realized_pnl": round(pf.realized_pnl, 2),
        "holdings": holdings,
    }


@mcp.tool()
def run_paper_session() -> dict:
    """Run ONE paper-trading session: price holdings, apply exit rules, buy new
    top picks with available cash, save the portfolio. PAPER ONLY — no real
    orders are ever placed. Returns a summary of equity and exits."""
    from sectorbot.engine import run_paper_session as _run
    result = _run(verbose=False)
    if result.get("aborted"):
        return {"aborted": True, "message": result["message"]}
    return {
        "aborted": False,
        "real_data": result["real_data"],
        "equity": round(result["equity"], 2),
        "total_pnl_pct": round(result["total_pnl_pct"], 2),
        "cash": round(result["cash"], 2),
        "realized": round(result["realized"], 2),
        "unrealized": round(result["unrealized"], 2),
        "holdings": len(result["portfolio"].holdings),
        "exits": [{"symbol": s, "ltp": ltp, "reason": r, "pnl": round(p, 2)}
                  for s, ltp, r, p in result["exits"]],
    }


@mcp.tool()
def scorecard() -> dict:
    """Honest verdict on the paper strategy: total return, the Nifty index
    return over the same period, the edge vs index (the number that matters),
    drawdown, win-rate, and a plain-English verdict (TOO EARLY / LOSING /
    LAGGING THE INDEX / PROMISING). Reads the saved portfolio."""
    from sectorbot.portfolio import Portfolio
    from sectorbot.scorecard import compute_scorecard
    return compute_scorecard(Portfolio.load())


@mcp.tool()
def check_universe() -> dict:
    """Audit the tradeable stock universe: for each top-ranked industry, how
    many stocks are mapped, which are live on Kite vs dead, and which top
    industries have NO stocks (blind spots the bot can't trade). Uses real Kite
    prices when configured."""
    from sectorbot.instruments import audit_universe
    ds = _ds()
    return audit_universe(ds=ds if _is_real(ds) else None)


@mcp.tool()
def send_telegram_alert(message: str) -> dict:
    """Send a free-text alert to your configured Telegram chat. Safe no-op
    (console dry-run) if TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID aren't set."""
    from sectorbot.telegram import send_telegram
    delivered = send_telegram(message)
    return {"delivered": delivered}


if __name__ == "__main__":
    mcp.run()  # default transport: stdio (what Claude Code connects to)

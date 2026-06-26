#!/usr/bin/env python3
"""Mayura 🦚 — a PAPER-ONLY trading companion, blessed in the name of Lord Muruga.

   "Mayura" (மயூரம்) is the divine peacock, the vahana of Lord Muruga. Just as the
   peacock keeps its calm and its colours while the serpent of fear and greed
   coils below it, this bot is built to trade with discipline, never with panic.

   ┌──────────────────────────────────────────────────────────────────────┐
   │  PAPER TRADING ONLY. No real order is ever placed. Mayura simulates    │
   │  buying/selling against REAL Kite market prices so you can see whether │
   │  the strategy works — with fake money and zero risk — before you ever  │
   │  risk a single rupee. This is NOT investment advice and NOT a profit   │
   │  guarantee. Markets can fall. Test for months. Trade what you can lose.│
   └──────────────────────────────────────────────────────────────────────┘

This is a clean, single-command launcher built on the proven `sectorbot` engine
(the same ranking, risk rules, Kite price feed and Telegram alerts) but rebranded
as Mayura and locked to paper mode. It does NOT duplicate the strategy code — it
reuses it, so there is only one tested engine to trust.

USAGE
-----
    python mayura.py run        # ⭐ the main one: run a paper session + Telegram you
    python mayura.py rank       # show today's top-ranked industries (no trading)
    python mayura.py status     # your saved track record (equity, trades, win-rate)
    python mayura.py scorecard  # honest verdict: is it beating the Nifty index?
    python mayura.py check       # check the Kite token + Telegram are wired up
    python mayura.py universe    # audit which stocks Mayura can actually trade

Daily rhythm: drop today's Trendlyne CSV into sectorbot/data/ (any name ending
.csv), then run `python mayura.py run`. Mayura prices your holdings on real Kite
data, applies the exit rules, buys fresh leaders, saves the portfolio, and pings
your phone on Telegram. See MAYURA.md for the Trendlyne features it feeds on.
"""

import sys
from datetime import date
from pathlib import Path

# Mayura reuses the battle-tested engine; it never re-implements the strategy.
from sectorbot import config


PEACOCK = "🦚"
BLESSING = "ஓம் சரவணபவ — Vel Muruga! May this run be steady, not greedy."

# Mayura is its OWN bot. It borrows the proven strategy code from `sectorbot`,
# but runs on a completely SEPARATE data folder and a SEPARATE portfolio, so it
# never shares a track record or data with the equity bot. (Same engine design,
# two independent cars.) These paths are applied to `config` at startup.
REPO_ROOT = Path(__file__).resolve().parent
MAYURA_DATA = REPO_ROOT / "mayura_data"


def _use_mayura_paths() -> None:
    """Point the shared engine at Mayura's OWN data + portfolio + reports.

    The engine reads every path from `config` at call time, so overriding these
    module globals here makes Mayura fully independent without forking the code.
    Industry→symbol reference maps stay shared (generic lookup tables, not the
    other bot's data)."""
    MAYURA_DATA.mkdir(parents=True, exist_ok=True)
    config.DATA_DIR = MAYURA_DATA
    config.DATA_CSV = MAYURA_DATA / "fundamentals.csv"          # fallback name
    config.SNAPSHOTS_DIR = MAYURA_DATA / "snapshots"
    config.PORTFOLIO_JSON = MAYURA_DATA / "mayura_portfolio.json"
    config.UNIVERSE_CSV = MAYURA_DATA / "universe.csv"          # optional override
    config.PORTFOLIO_REPORT_TXT = REPO_ROOT / "mayura_report.txt"
    config.PORTFOLIO_REPORT_HTML = REPO_ROOT / "mayura_report.html"
    config.DASHBOARD_HTML = REPO_ROOT / "mayura_dashboard.html"


def _banner(subtitle: str) -> None:
    print()
    print("=" * 70)
    print(f"  {PEACOCK}  M A Y U R A   ·   PAPER TRADING   ·   {subtitle}")
    print(f"      In the name of Lord Muruga — discipline over fear & greed.")
    print("=" * 70)


def _assert_paper_only() -> None:
    """Mayura is paper-only by covenant. If LIVE_TRADING was ever flipped on,
    refuse to run rather than risk a real order — that is not what Mayura is."""
    if getattr(config, "LIVE_TRADING", False):
        print(f"{PEACOCK} ABORT: LIVE_TRADING is ON, but Mayura is PAPER-ONLY by "
              "design. Set sectorbot/config.py LIVE_TRADING=False to use Mayura.")
        sys.exit(2)


# --------------------------------------------------------------------------
# Telegram summary — Mayura-branded, phone-friendly
# --------------------------------------------------------------------------
def _mayura_telegram(result: dict) -> str:
    real = result["real_data"]
    tag = "REAL Kite prices" if real else "SYNTHETIC prices — NOT real"
    exits = result["exits"]
    lines = [
        f"{PEACOCK} <b>Mayura · {date.today().isoformat()}</b>",
        f"<i>Paper trading ({tag}) · Vel Muruga 🙏</i>",
        f"Equity: <b>Rs {result['equity']:,.0f}</b> "
        f"({result['total_pnl_pct']:+.2f}%)",
        f"Cash Rs {result['cash']:,.0f} · "
        f"Unrealised {result['unrealized']:+,.0f} · "
        f"Realised {result['realized']:+,.0f}",
        f"Holdings: {len(result['portfolio'].holdings)} · Exits: {len(exits)}",
    ]
    if result.get("data_stale"):
        lines.insert(1, f"⚠️ <b>STALE DATA</b> (file {result.get('data_date')}) "
                        "— upload today's Trendlyne CSV!")
    elif result.get("data_date"):
        lines.append(f"Data: {result['data_date']}")
    if result.get("regime_blocked"):
        lines.append("🛑 Market downtrend — Mayura holds cash, no new buys")
    sc = result.get("scorecard")
    if sc:
        edge = (f" (edge {sc['edge_vs_index_pct']:+.1f}% vs Nifty)"
                if sc.get("edge_vs_index_pct") is not None else "")
        lines.append(f"📈 Verdict: <b>{sc['verdict']}</b>{edge}")
    for s, ltp, reason, pnl in exits[:8]:
        lines.append(f"  SELL {s} @ {ltp:.2f} [{reason}] P&amp;L {pnl:+,.0f}")
    lines.append("")
    lines.append("<i>Paper only — not investment advice.</i>")
    return "\n".join(lines)


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------
def _print_mayura(result: dict) -> None:
    """Mayura's own portfolio printout (so the screen says Mayura, not SectorBot)."""
    pf = result["portfolio"]
    tag = "REAL Kite prices" if result["real_data"] else "SYNTHETIC — NOT real"
    print("-" * 70)
    print(f"  {PEACOCK} Mayura paper portfolio   ({tag})")
    print(f"  Starting capital : Rs {pf.starting_capital:,.0f}")
    print(f"  Equity (now)     : Rs {result['equity']:,.0f}  "
          f"({result['total_pnl_pct']:+.2f}%)")
    print(f"  Cash             : Rs {result['cash']:,.0f}")
    print(f"  Holdings value   : Rs {result['holdings_value']:,.0f}")
    print(f"  Unrealised P&L   : Rs {result['unrealized']:,.0f}")
    print(f"  Realised P&L     : Rs {result['realized']:,.0f}")
    if result.get("data_date"):
        warn = "  ⚠️ STALE — drop today's CSV in mayura_data/" if result.get("data_stale") else ""
        print(f"  Data file date   : {result['data_date']}{warn}")
    if result.get("regime_blocked"):
        print(f"  Regime           : DOWNTREND — holding cash, no new buys "
              f"({config.REGIME_INDEX} below {config.REGIME_SMA}-DMA)")
    print(f"  Holdings ({len(pf.holdings)}):")
    for s, h in pf.holdings.items():
        print(f"    {s:12} qty {h['qty']:>5}  entry {h['avg_price']:>9.2f}  since {h['entry_date']}")
    if result["exits"]:
        print("  Exits this run:")
        for s, ltp, reason, pnl in result["exits"]:
            print(f"    SELL {s:12} @ {ltp:>9.2f}  [{reason}]  P&L {pnl:+,.0f}")
    print("-" * 70)


def _breakout_watchlist():
    """If a Trendlyne breakout export sits in universe.csv, return it as a
    best-first [(symbol, score)] list; else None. This is Mayura's 'trade my
    breakout list directly' mode."""
    from sectorbot.stocks import load_breakout_watchlist
    if not config.UNIVERSE_CSV.exists():
        return None
    wl = load_breakout_watchlist(config.UNIVERSE_CSV)
    return wl or None


def cmd_run() -> None:
    """The main event: one paper-trading session + a Telegram ping."""
    _banner("DAILY RUN")
    print(f"  {BLESSING}\n")
    print(f"  Data folder : {config.DATA_DIR}")
    print(f"  Portfolio   : {config.PORTFOLIO_JSON}  (Mayura's own track record)")
    from sectorbot.engine import run_paper_session
    from sectorbot.notify import write_portfolio_report
    from sectorbot.telegram import send_telegram

    # WATCHLIST MODE: if a Trendlyne breakout export is present, trade it directly.
    wl = _breakout_watchlist()
    ranked = None
    if wl:
        ranked = [s for s, _ in wl]
        print(f"  Mode        : 🎯 BREAKOUT WATCHLIST — {len(ranked)} stocks from "
              f"your Trendlyne export (top: {', '.join(ranked[:5])})\n")
    else:
        print(f"  Mode        : industry DVM ranking (no breakout universe.csv)\n")

    # verbose=False so the engine's own "SectorBot" printout is suppressed; we
    # render Mayura's branded summary instead.
    result = run_paper_session(verbose=False, ranked_symbols=ranked)
    if ranked and not result.get("aborted"):
        # In watchlist mode the fundamentals-CSV date is irrelevant — what
        # matters is the breakout universe.csv. Don't show a misleading "stale".
        result["data_stale"] = False
        result["data_date"] = None
    if result.get("aborted"):
        # Engine refused (e.g. real Kite data required but unavailable). The
        # portfolio was left untouched — nothing to report or send.
        print(f"  {PEACOCK} Skipped: {result['message']}")
        send_telegram(f"{PEACOCK} <b>Mayura</b> skipped today: "
                      f"{result['message']}")
        return

    _print_mayura(result)
    txt, _ = write_portfolio_report(result)
    print(f"  Report written: {txt}")
    delivered = send_telegram(_mayura_telegram(result))
    print(f"  Telegram: {'sent 🙏' if delivered else 'dry-run (set the two env vars)'}")
    print(f"\n  {PEACOCK} May Lord Muruga guide steady gains. Paper only.\n")


def cmd_rank() -> None:
    _banner("TODAY'S RANKING")
    from sectorbot.data_loader import resolve_csv
    from sectorbot.instruments import symbols_for
    from sectorbot.screener import top_industries

    def _c(v):  # format an optional DVM pillar (0-100) or a dash
        return f"{v:4.0f}" if v is not None else "   -"

    from sectorbot import instruments
    # If a breakout watchlist is present, show THAT (it's what Mayura will trade).
    wl = _breakout_watchlist()
    if wl:
        print(f"  🎯 BREAKOUT WATCHLIST  ({len(wl)} stocks from your Trendlyne "
              f"export — this is what Mayura trades)\n")
        print(f"  {'#':>3}  {'Symbol':14} {'Breakout score':>14}")
        print("  " + "-" * 36)
        for i, (sym, sc) in enumerate(wl[:20], 1):
            print(f"  {i:>3}  {sym:14} {sc:>14.1f}")
        mode = ("EARLY-STAGE: fresh golden cross (green just crossed red), "
                "parabolic/extended names demoted" if config.BREAKOUT_EARLY_STAGE
                else "continuation: strength near 52-week high")
        print(f"\n  Score model = {mode}")
        print("  + delivery accumulation + relative strength. Not advice. 🦚\n")
        return
    print(f"  Data file: {resolve_csv(None)}")
    smart = config.USE_SMART_SCORE
    print(f"  Industry brain: {'SMART DVM (Durability/Valuation/Momentum)' if smart else 'legacy momentum+breadth'}")
    if instruments.has_stock_signals():
        print("  Stock brain   : ✅ ranking real stocks by their Trendlyne "
              "DVM/checklist/technicals (universe.csv)")
    else:
        print("  Stock brain   : — (drop a Trendlyne STOCK export as "
              "mayura_data/universe.csv to enable per-stock ranking)")
    print()
    if smart:
        print(f"  {'#':>3}  {'Industry':28} {'Score':>6} {'D':>4} {'V':>4} {'M':>4} {'PE':>6}  Symbols")
        print("  " + "-" * 86)
        show_scores = instruments.has_stock_signals()
        for i, ind in enumerate(top_industries(n=12), 1):
            pe = f"{ind.pe:.0f}" if ind.pe is not None else "-"
            picks = symbols_for(ind.name)[:3]
            if show_scores:
                syms = ", ".join(
                    f"{s}({instruments.stock_score(s):.0f})"
                    if instruments.stock_score(s) is not None else s
                    for s in picks) or "(none mapped)"
            else:
                syms = ", ".join(picks) or "(none mapped)"
            print(f"  {i:>3}  {ind.name[:28]:28} {ind.score:6.1f} "
                  f"{_c(ind.durability)} {_c(ind.valuation)} {_c(ind.momentum)} "
                  f"{pe:>6}  {syms}")
        print("\n  D=Durability  V=Valuation  M=Momentum  (0–100 each, from your "
              "Trendlyne CSV).")
    else:
        print(f"  {'#':>3}  {'Industry':32} {'Score':>6} {'PE':>7}  Tradeable symbols")
        print("  " + "-" * 78)
        for i, ind in enumerate(top_industries(n=12), 1):
            pe = f"{ind.pe:.1f}" if ind.pe is not None else "-"
            syms = ", ".join(symbols_for(ind.name)[:4]) or "(none mapped)"
            print(f"  {i:>3}  {ind.name[:32]:32} {ind.score:6.1f} {pe:>7}  {syms}")
    print("\n  Ranking of existing data — not a prediction, not advice.\n")


def cmd_status() -> None:
    _banner("TRACK RECORD")
    from sectorbot.__main__ import cmd_status as _status
    _status()


def cmd_scorecard() -> None:
    _banner("HONEST VERDICT")
    from sectorbot.portfolio import Portfolio
    from sectorbot.scorecard import compute_scorecard, format_scorecard
    print("\n" + format_scorecard(compute_scorecard(Portfolio.load())) + "\n")


def cmd_check() -> None:
    """Verify the two APIs Mayura needs: Kite (prices) and Telegram (alerts)."""
    _banner("WIRING CHECK")
    # Kite
    tok = config.resolve_access_token()
    if tok:
        print(f"  Kite token   : ✅ resolved (len {len(tok)}, ...{tok[-4:]})")
        if config.KITE_API_KEY:
            try:
                from sectorbot.datasource import KiteDataSource
                ltp = KiteDataSource().last_price("RELIANCE")
                print(f"  Kite live    : ✅ real data OK — RELIANCE LTP = {ltp}")
            except Exception as exc:  # noqa: BLE001
                print(f"  Kite live    : ❌ {exc}")
        else:
            print("  Kite live    : ⚠️ KITE_API_KEY not set — cannot test live fetch")
    else:
        print("  Kite token   : ⚠️ none — set KITE_TOKEN_FILE or KITE_ACCESS_TOKEN")
        print("                 (without it, Mayura uses SYNTHETIC demo prices)")
    # Telegram
    from sectorbot.telegram import configured, send_telegram
    if configured():
        ok = send_telegram(f"{PEACOCK} Mayura wiring check — Telegram is live. "
                           "Vel Muruga! 🙏")
        print(f"  Telegram     : {'✅ test message sent' if ok else '❌ send failed'}")
    else:
        print("  Telegram     : ⚠️ TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID not set")
        print("                 (alerts will print to console instead)")
    print()


def cmd_universe() -> None:
    _banner("TRADEABLE UNIVERSE")
    from sectorbot.__main__ import cmd_universe_check
    cmd_universe_check()


def cmd_data() -> None:
    """Audit the Trendlyne files you've downloaded into mayura_data/.

    Tells you which of the 3 useful files are present, whether they're fresh,
    and (for the stock export) which DVM/technical columns Mayura detected — so
    your manual download workflow is foolproof. This is the data Kite CANNOT
    give: fundamentals, breadth and DVM/checklist/technical scores."""
    _banner("TRENDLYNE DATA CHECK")
    from sectorbot import instruments
    from sectorbot.data_loader import (active_csv_info, classify_csv,
                                       resolve_breadth_csv, resolve_csv)
    from sectorbot.stocks import resolve_columns
    import csv as _csv

    print(f"  Folder: {config.DATA_DIR}\n")

    # 1) Fundamentals (Sector Dashboard) — industry PE/ROE/growth, NOT on Kite.
    info = active_csv_info()
    fund = resolve_csv()
    if fund.exists() and classify_csv(fund) == "fundamentals":
        fresh = "⚠️ STALE — download today's" if info["stale"] else "fresh"
        print(f"  1. Fundamentals  : ✅ {fund.name}  (date {info['date']}, {fresh})")
    else:
        print("  1. Fundamentals  : ❌ MISSING")
        print("       → Trendlyne ▸ Sector Dashboard ▸ Export  →  save as "
              "fundamentals-YYYY-MM-DD.csv")

    # 2) Breadth (Market Breadth Analysis, equi-weighted) — RSI/MFI/SMA %.
    breadth = resolve_breadth_csv()
    if breadth:
        print(f"  2. Breadth       : ✅ {breadth.name}")
    else:
        print("  2. Breadth       : ❌ MISSING")
        print("       → Trendlyne ▸ Market Breadth (set Equi-weighted) ▸ Export "
              " →  save as industry-breadth-equi-YYYY-MM-DD.csv")

    # 3) Stock export (universe.csv) — DVM/checklist/technicals per stock.
    uni = config.UNIVERSE_CSV
    if uni.exists():
        try:
            with open(uni, newline="", encoding="utf-8") as f:
                fields = next(_csv.reader(f), [])
        except OSError:
            fields = []
        found = resolve_columns(fields)
        nice = {
            "durability": "Durability", "valuation": "Valuation",
            "momentum": "Momentum", "checklist": "Checklist",
            "pe": "PE", "pbv": "P/B", "rsi": "RSI", "mfi": "MFI",
            "delivery": "Delivery%", "month_change": "MonthΔ",
            "qtr_change": "QtrΔ", "week_change": "WeekΔ", "day_change": "DayΔ",
        }
        have = [nice[k] for k in nice if k in found]
        print(f"  3. Stock export  : ✅ universe.csv  → using: "
              f"{', '.join(have) if have else 'symbol+industry only (no scores)'}")
        instruments.reload_universe()
        if instruments.has_stock_signals():
            print("       Stock brain ON — picks ranked by real per-stock data.")
        else:
            print("       (No score columns detected — add DVM/checklist/RSI etc. "
                  "for smarter stock picks.)")
    else:
        print("  3. Stock export  : ⬜ optional (RECOMMENDED) — universe.csv")
        print("       → Trendlyne ▸ a Stock Screener with DVM columns ▸ Export "
              " →  save as universe.csv  (see universe.sample.csv)")

    print("\n  These are exactly the things Kite can't give you. Drop the files")
    print("  above into this folder, then run `python mayura.py run`. 🦚\n")


COMMANDS = {
    "run": cmd_run,
    "rank": cmd_rank,
    "status": cmd_status,
    "scorecard": cmd_scorecard,
    "check": cmd_check,
    "universe": cmd_universe,
    "data": cmd_data,
}


def main() -> None:
    _assert_paper_only()
    _use_mayura_paths()   # ← make Mayura independent: own data folder + portfolio
    choice = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "run"
    if choice in ("-h", "--help", "help"):
        print(__doc__)
        return
    fn = COMMANDS.get(choice)
    if not fn:
        print(f"{PEACOCK} Unknown command '{choice}'.")
        print(f"   Use one of: {', '.join(COMMANDS)}  (or --help)")
        sys.exit(1)
    fn()


if __name__ == "__main__":
    main()

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

THREE STRATEGIES (the abodes of Lord Muruga) — each independent, own portfolio:
    🌄 palani       breakout / momentum   (fresh golden cross)
    🌊 tiruchendur  quality + value       (DVM Durability/Valuation, low PE)
    🛕 madurai      accumulation          (delivery spike, money-flow, FII)

USAGE
-----
    python mayura.py run               # run ALL three strategies + Telegram you
    python mayura.py run palani        # run just one strategy
    python mayura.py rank [strategy]   # show a strategy's scored watchlist
    python mayura.py status [strategy] # a strategy's track record
    python mayura.py scorecard [strat] # honest verdict vs the Nifty index
    python mayura.py rules [strategy]  # that strategy's exit rules
    python mayura.py data [strategy]   # which Trendlyne columns it detected
    python mayura.py check             # Kite token + Telegram wired? (global)
    python mayura.py regime            # NIFTY vs its 200-DMA (global)

Each strategy reads its OWN screen from mayura_data/<strategy>/universe.csv and
keeps its OWN portfolio there. Build a different Trendlyne screen per strategy
(see the README in each folder), upload it, then `python mayura.py run`. Mayura
prices holdings on real Kite data, applies that strategy's exit rules, buys its
leaders, saves the portfolio, and pings your phone — once per strategy.
Omitting [strategy] runs/show all three. PAPER ONLY.
"""

import sys
from datetime import date
from pathlib import Path

# Mayura reuses the battle-tested engine; it never re-implements the strategy.
from sectorbot import config


PEACOCK = "🦚"
BLESSING = "ஓம் சரவணபவ — Vel Muruga! May this run be steady, not greedy."

# Mayura is its OWN bot, and it now runs THREE independent strategies — named
# after three abodes of Lord Muruga. Each has its OWN data folder, its OWN
# universe.csv (a different Trendlyne screen) and its OWN portfolio/track record,
# so they make separate decisions and you can see which edge wins. They share
# only the proven engine code.
REPO_ROOT = Path(__file__).resolve().parent
MAYURA_DATA = REPO_ROOT / "mayura_data"

# In a market DOWNTREND (NIFTY below its 200-DMA): "reduced" = smart middle —
# still buy, but only the strongest few leaders at smaller size. Shared by all.
MAYURA_DOWNTREND_MODE          = "reduced"
MAYURA_DOWNTREND_MAX_POSITIONS = 3
MAYURA_DOWNTREND_SIZE_FACTOR   = 0.5

# --- The three temple-strategies (tweak freely) -----------------------------
# Each "exits" block tunes how that strategy manages a trade. Edit the numbers.
STRATEGIES = {
    "palani": {
        "name": "Palani", "emoji": "🌄",
        "tagline": "breakout / momentum — buy the fresh golden cross",
        "profile": "breakout",   # scoring profile in sectorbot/stocks.py
        "exits": dict(stop=0.08, trail_arm=0.10, trail_give=0.10, tp=1.00,
                      atr=2.5, hold_days=10, time_min=0.05, failed_breakout=True,
                      max_ext=0.30),   # skip if >30% above 200-DMA (freshest)
    },
    "tiruchendur": {
        "name": "Tiruchendur", "emoji": "🌊",
        "tagline": "quality + value — strong, fairly-priced businesses",
        "profile": "quality",
        "exits": dict(stop=0.12, trail_arm=0.15, trail_give=0.12, tp=1.00,
                      atr=3.0, hold_days=45, time_min=0.05, failed_breakout=False,
                      max_ext=0.50),   # quality may be pricier, but still capped
    },
    "madurai": {
        "name": "Madurai", "emoji": "🛕",
        "tagline": "accumulation — follow the smart money (delivery/MFI/FII)",
        "profile": "accumulation",
        "exits": dict(stop=0.10, trail_arm=0.12, trail_give=0.10, tp=1.00,
                      atr=2.5, hold_days=20, time_min=0.05, failed_breakout=False,
                      max_ext=0.40),   # skip if >40% above 200-DMA
    },
}
STRATEGY_ORDER = ["palani", "tiruchendur", "madurai"]
CURRENT: dict = {}   # the active strategy (set by _use_strategy)


def _migrate_legacy_palani(folder: Path) -> None:
    """One-time: move the original single-Mayura data (mayura_data/universe.csv +
    mayura_portfolio.json) into the Palani folder so its track record carries on."""
    import shutil
    legacy_uni = MAYURA_DATA / "universe.csv"
    legacy_pf = MAYURA_DATA / "mayura_portfolio.json"
    if legacy_uni.exists() and not (folder / "universe.csv").exists():
        shutil.copy2(legacy_uni, folder / "universe.csv")
    if legacy_pf.exists() and not (folder / "portfolio.json").exists():
        shutil.copy2(legacy_pf, folder / "portfolio.json")


def _use_strategy(key: str) -> None:
    """Point the shared engine at one temple-strategy's OWN folder + portfolio,
    and apply that strategy's exit rules (this process only — the equity bot is
    never touched)."""
    global CURRENT
    s = STRATEGIES[key]
    CURRENT = {**s, "key": key}
    folder = MAYURA_DATA / key
    (folder / "snapshots").mkdir(parents=True, exist_ok=True)
    if key == "palani":
        _migrate_legacy_palani(folder)
    # paths (independent per strategy)
    config.DATA_DIR = folder
    config.DATA_CSV = folder / "fundamentals.csv"
    config.SNAPSHOTS_DIR = folder / "snapshots"
    config.PORTFOLIO_JSON = folder / "portfolio.json"
    config.UNIVERSE_CSV = folder / "universe.csv"
    config.PORTFOLIO_REPORT_TXT = REPO_ROOT / f"mayura_{key}_report.txt"
    config.PORTFOLIO_REPORT_HTML = REPO_ROOT / f"mayura_{key}_report.html"
    config.DASHBOARD_HTML = REPO_ROOT / f"mayura_{key}_dashboard.html"
    # exit rules (EXIT-RULE mode so the trailing stop runs)
    e = s["exits"]
    config.REBALANCE = False
    config.STOP_LOSS_PCT = e["stop"]
    config.USE_TRAILING_STOP = True
    config.TRAILING_ACTIVATE_PCT = e["trail_arm"]
    config.TRAILING_SL_PCT = e["trail_give"]
    config.TAKE_PROFIT_PCT = e["tp"]
    config.USE_ATR_STOP = True
    config.ATR_MULT = e["atr"]
    config.MAX_HOLDING_DAYS = e["hold_days"]
    config.TIME_STOP_MIN_GAIN_PCT = e["time_min"]
    config.USE_FAILED_BREAKOUT_EXIT = e["failed_breakout"]
    config.MAX_EXTENSION_ABOVE_SMA200 = e.get("max_ext", 0.0)
    config.REGIME_DOWNTREND_MODE = MAYURA_DOWNTREND_MODE
    config.REGIME_DOWNTREND_MAX_POSITIONS = MAYURA_DOWNTREND_MAX_POSITIONS
    config.REGIME_DOWNTREND_SIZE_FACTOR = MAYURA_DOWNTREND_SIZE_FACTOR


def _banner(subtitle: str) -> None:
    title = "M A Y U R A"
    if CURRENT:
        title = f"M A Y U R A › {CURRENT['emoji']} {CURRENT['name'].upper()}"
    print()
    print("=" * 70)
    print(f"  {PEACOCK}  {title}   ·   {subtitle}")
    if CURRENT:
        print(f"      {CURRENT['tagline']}")
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
    who = f"{CURRENT['emoji']} {CURRENT['name']}" if CURRENT else "Mayura"
    lines = [
        f"{PEACOCK} <b>Mayura · {who} · {date.today().isoformat()}</b>",
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
    if result.get("regime_reduced"):
        lines.append(f"🟠 Downtrend — reduced: top "
                     f"{config.REGIME_DOWNTREND_MAX_POSITIONS} leaders, "
                     f"{config.REGIME_DOWNTREND_SIZE_FACTOR:.0%} size")
    elif result.get("regime_blocked"):
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
    who = f"{CURRENT['emoji']} {CURRENT['name']}" if CURRENT else "Mayura"
    print("-" * 70)
    print(f"  {PEACOCK} {who} paper portfolio   ({tag})")
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
    if result.get("regime_reduced"):
        print(f"  Regime           : DOWNTREND — REDUCED mode: top "
              f"{config.REGIME_DOWNTREND_MAX_POSITIONS} leaders at "
              f"{config.REGIME_DOWNTREND_SIZE_FACTOR:.0%} size "
              f"({config.REGIME_INDEX} below {config.REGIME_SMA}-DMA)")
    elif result.get("regime_blocked"):
        print(f"  Regime           : DOWNTREND — holding cash, no new buys "
              f"({config.REGIME_INDEX} below {config.REGIME_SMA}-DMA)")
    print(f"  Holdings ({len(pf.holdings)}):")
    for s, h in pf.holdings.items():
        print(f"    {s:12} qty {h['qty']:>5}  entry {h['avg_price']:>9.2f}  since {h['entry_date']}")
    if result["exits"]:
        print("  Exits this run:")
        for s, ltp, reason, pnl in result["exits"]:
            print(f"    SELL {s:12} @ {ltp:>9.2f}  [{reason}]  P&L {pnl:+,.0f}")
    skx = result.get("skipped_extended") or []
    if skx:
        print(f"  Skipped ({len(skx)}) — already too far above 200-DMA (not chased):")
        for s, ltp, pct in skx[:8]:
            print(f"    {s:12} @ {ltp:>9.2f}  (+{pct*100:.0f}% vs 200-DMA)")
    print("-" * 70)


def _watchlist():
    """Load THIS strategy's universe.csv, scored by its profile (breakout /
    quality / accumulation). Returns a best-first list of dicts, or None."""
    from sectorbot.stocks import load_watchlist
    if not config.UNIVERSE_CSV.exists():
        return None
    profile = CURRENT.get("profile", "breakout") if CURRENT else "breakout"
    wl = load_watchlist(config.UNIVERSE_CSV, profile)
    return wl or None


def cmd_run() -> None:
    """The main event: one paper-trading session + a Telegram ping."""
    _banner("DAILY RUN")
    print(f"  {BLESSING}\n")
    print(f"  Strategy    : {CURRENT['emoji']} {CURRENT['name']} — {CURRENT['tagline']}")
    print(f"  Folder      : {config.DATA_DIR}")
    from sectorbot.engine import run_paper_session
    from sectorbot.notify import write_portfolio_report
    from sectorbot.telegram import send_telegram

    wl = _watchlist()
    if not wl:
        print(f"\n  ⏭  No universe.csv for {CURRENT['name']} yet — upload this "
              f"strategy's Trendlyne screen to:\n     {config.UNIVERSE_CSV}\n"
              "     (see the README in that folder). Skipping.\n")
        return
    ranked = [d["symbol"] for d in wl]
    levels = {d["symbol"]: d["sma50"] for d in wl if d.get("sma50")}
    ext_levels = {d["symbol"]: d["sma200"] for d in wl if d.get("sma200")}
    print(f"  Watchlist   : 🎯 {len(ranked)} stocks ({CURRENT['profile']} score; "
          f"top: {', '.join(ranked[:5])})")
    print(f"  Guard       : skip any stock >{config.MAX_EXTENSION_ABOVE_SMA200:.0%} "
          f"above its 200-DMA (no chasing already-run-up names)\n")

    # verbose=False so the engine's own "SectorBot" printout is suppressed; we
    # render Mayura's branded summary instead.
    result = run_paper_session(verbose=False, ranked_symbols=ranked,
                               levels=levels, ext_levels=ext_levels)
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
    wl = _watchlist()
    if not wl:
        print(f"\n  ⏭  No universe.csv for {CURRENT['name']} yet — upload this "
              f"strategy's Trendlyne screen to:\n     {config.UNIVERSE_CSV}\n")
        return
    print(f"  🎯 {CURRENT['name']} watchlist — {len(wl)} stocks, scored by the "
          f"'{CURRENT['profile']}' model\n")
    print(f"  {'#':>3}  {'Symbol':14} {'Score':>8}")
    print("  " + "-" * 30)
    for i, d in enumerate(wl[:20], 1):
        print(f"  {i:>3}  {d['symbol']:14} {d['score']:>8.1f}")
    print(f"\n  Profile '{CURRENT['profile']}' — {CURRENT['tagline']}.")
    print("  Ranking of existing data — not a prediction, not advice. 🦚\n")


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

    uni = config.UNIVERSE_CSV
    print(f"  Strategy : {CURRENT['emoji']} {CURRENT['name']} ({CURRENT['profile']})")
    print(f"  Folder   : {config.DATA_DIR}\n")
    if uni.exists():
        try:
            with open(uni, newline="", encoding="utf-8") as f:
                fields = next(_csv.reader(f), [])
        except OSError:
            fields = []
        found = resolve_columns(fields)
        nice = {
            "symbol": "NSE Code", "durability": "Durability",
            "valuation": "Valuation", "momentum": "Momentum",
            "checklist": "Checklist", "pe": "PE", "pbv": "P/B", "rsi": "RSI",
            "mfi": "MFI", "deliv_month": "Delivery%", "fii": "FII",
            "dist52": "52WHigh%", "sma50": "SMA50", "sma200": "SMA200",
            "rs_qtr": "RelStr",
        }
        have = [nice[k] for k in nice if k in found]
        wl = _watchlist()
        n = len(wl) if wl else 0
        print(f"  universe.csv : ✅ {n} tradeable stocks")
        print(f"  columns used : {', '.join(have) if have else '(symbol only)'}")
    else:
        print("  universe.csv : ❌ MISSING — upload this strategy's Trendlyne screen here.")
        print("     See the README in this folder for which filters to use.")
    print()


def cmd_regime() -> None:
    """Show WHY Mayura thinks the market is up/down: NIFTY's latest close vs its
    own 200-day average. Cross-check these numbers on your Kite/TradingView."""
    _banner("MARKET REGIME (NIFTY 50 vs its 200-day average)")
    from sectorbot.datasource import PaperDataSource, get_datasource
    ds = get_datasource()
    if isinstance(ds, PaperDataSource):
        print("\n  Synthetic data — no real index to judge. Load your Kite keys"
              "\n  (set -a; source .env; set +a) and re-run.\n")
        return
    try:
        bars = ds.history(config.REGIME_INDEX, config.REGIME_SMA + 10)
    except Exception as exc:  # noqa: BLE001
        print(f"\n  Could not fetch {config.REGIME_INDEX} history: {exc}\n")
        return
    closes = [b.close for b in bars if b.close and b.close > 0]
    if len(closes) < config.REGIME_SMA:
        print(f"\n  Only {len(closes)} daily bars available — need "
              f"{config.REGIME_SMA}. Trend unknown → Mayura ALLOWS trading "
              "(fail-open).\n")
        return
    sma = sum(closes[-config.REGIME_SMA:]) / config.REGIME_SMA
    last = closes[-1]
    up = last >= sma
    print(f"""
  {config.REGIME_INDEX} latest close : {last:,.1f}
  {config.REGIME_SMA}-day average       : {sma:,.1f}
  Difference            : {(last / sma - 1) * 100:+.1f}%  vs the 200-DMA
  Daily bars used       : {len(closes)}

  Verdict : {'📈 UPTREND — new buys allowed' if up else '🛑 DOWNTREND — ' + ('reduced (smart middle)' if config.REGIME_DOWNTREND_MODE == 'reduced' else 'holding cash')}

  👉 Cross-check: open NIFTY 50 daily chart on Kite/TradingView, add a 200-day
     SMA. If price is below that line, Mayura is right. Holiday/your location do
     NOT affect this — it's Indian market data, computed on the server. 🦚
""")


def cmd_rules() -> None:
    """Show THIS strategy's exit rules in plain English (each temple differs)."""
    _banner("EXIT RULES")
    fb = ("💔 Failed breakout  : exit the moment price falls below its SMA50\n"
          if config.USE_FAILED_BREAKOUT_EXIT else "")
    print(f"""
  {CURRENT['emoji']} {CURRENT['name']} manages each trade with these rules
  (first to trigger wins):

  {fb}🛑 Hard stop-loss   : exit at  −{config.STOP_LOSS_PCT:.0%}  from entry
  📈 Trailing stop    : once +{config.TRAILING_ACTIVATE_PCT:.0%}, follow the peak; exit if it
                        drops {config.TRAILING_SL_PCT:.0%} from the high (rides + locks the gain)
  🎯 Take-profit      : hard cap at +{config.TAKE_PROFIT_PCT:.0%}  (rare)
  🌊 ATR stop         : volatility-based ({config.ATR_MULT}× ATR below entry)
  ⏳ Time stop        : exit after {config.MAX_HOLDING_DAYS} days IF still under +{config.TIME_STOP_MIN_GAIN_PCT:.0%}
  🚫 Extension guard  : NEVER buy a stock already >{config.MAX_EXTENSION_ABOVE_SMA200:.0%} above its
                        200-DMA (no chasing parabolic / already-run-up names)
  🛡️ Market regime    : in a NIFTY downtrend, buy only the top
                        {config.REGIME_DOWNTREND_MAX_POSITIONS} leaders at {config.REGIME_DOWNTREND_SIZE_FACTOR:.0%} size (smart middle)

  Edit each strategy's numbers in mayura.py (STRATEGIES → exits). Paper only. 🦚
""")


# Commands that run once for the WHOLE bot (not per strategy).
GLOBAL_COMMANDS = {"check": cmd_check, "regime": cmd_regime}
# Commands that run PER strategy (loop all three unless one is named).
PER_STRATEGY_COMMANDS = {
    "run": cmd_run, "rank": cmd_rank, "status": cmd_status,
    "scorecard": cmd_scorecard, "data": cmd_data, "rules": cmd_rules,
    "universe": cmd_universe,
}


def main() -> None:
    _assert_paper_only()
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    choice = args[0] if args else "run"
    strat = args[1].lower() if len(args) > 1 else None
    if choice in ("-h", "--help", "help") or "-h" in sys.argv or "--help" in sys.argv:
        print(__doc__)
        return

    if choice in GLOBAL_COMMANDS:
        GLOBAL_COMMANDS[choice]()
        return

    fn = PER_STRATEGY_COMMANDS.get(choice)
    if not fn:
        print(f"{PEACOCK} Unknown command '{choice}'.")
        print(f"   Commands: {', '.join(list(PER_STRATEGY_COMMANDS) + list(GLOBAL_COMMANDS))}")
        print(f"   Strategies: {', '.join(STRATEGY_ORDER)}  (omit to run all three)")
        sys.exit(1)

    if strat and strat not in STRATEGIES:
        print(f"{PEACOCK} Unknown strategy '{strat}'. Use one of: "
              f"{', '.join(STRATEGY_ORDER)}")
        sys.exit(1)

    keys = [strat] if strat else STRATEGY_ORDER
    for key in keys:
        _use_strategy(key)
        fn()


if __name__ == "__main__":
    main()

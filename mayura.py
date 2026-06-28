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

SIX FACES — Arumugam (Lord Muruga as worshipped at his six temples), independent:
    🌄 dandapani    breakout / momentum   (fresh golden cross)      — Palani
    🌊 senthil      quality + value       (DVM Durability/Valuation) — Tiruchendur
    🛕 subramanya   accumulation          (delivery/MFI/FII)         — Madurai
    📜 swaminatha   filings-driven        (buy on bullish NSE/BSE news) — Swamimalai
    🕊️ thanikesa    small-cap momentum    (Minervini VCP+Stage2, valuation-aware) — Thiruttani
    🍃 solaimalai   large/mid value+quality (quant + special situations)      — Pazhamudircholai

USAGE
-----
    python mayura.py run               # run ALL faces + Telegram you
    python mayura.py run dandapani     # run just one strategy
    python mayura.py rank [strategy]   # show a strategy's scored watchlist
    python mayura.py status [strategy] # a strategy's track record
    python mayura.py scorecard [strat] # honest verdict vs the Nifty index
    python mayura.py rules [strategy]  # that strategy's exit rules
    python mayura.py data [strategy]   # which Trendlyne columns it detected
    python mayura.py filings swaminatha # dry-run the filings reader (no trades)
    python mayura.py check             # Kite token + Telegram wired? (global)
    python mayura.py regime            # NIFTY vs its 200-DMA (global)

Each strategy reads its OWN screen from mayura_data/<strategy>/universe.csv and
keeps its OWN portfolio there. Build a different Trendlyne screen per strategy
(see the README in each folder), upload it, then `python mayura.py run`. Mayura
prices holdings on real Kite data, applies that strategy's exit rules, buys its
leaders, saves the portfolio, and pings your phone — once per strategy.
Omitting [strategy] runs/show all three. PAPER ONLY.
"""

import os
import sys
from datetime import date
from pathlib import Path

# Mayura reuses the battle-tested engine; it never re-implements the strategy.
from sectorbot import config


PEACOCK = "🦚"
BLESSING = "ஓம் சரவணபவ — Vel Muruga! May this run be steady, not greedy."

# Mayura is its OWN bot, and it now runs THREE independent strategies — each
# named after Lord Muruga AS WORSHIPPED at one of his temples. Each has its OWN
# data folder, its OWN universe.csv (a different Trendlyne screen) and its OWN
# portfolio/track record, so they make separate decisions and you can see which
# edge wins. They share only the proven engine code.
REPO_ROOT = Path(__file__).resolve().parent
MAYURA_DATA = REPO_ROOT / "mayura_data"

# In a market DOWNTREND (NIFTY below its 200-DMA): "reduced" = smart middle —
# still buy, but only the strongest few leaders at smaller size. Shared by all.
MAYURA_DOWNTREND_MODE          = "reduced"
MAYURA_DOWNTREND_MAX_POSITIONS = 3
MAYURA_DOWNTREND_SIZE_FACTOR   = 0.5
# Give a fresh breakout this many days before the failed-breakout exit can fire
# (avoids same-day whipsaws; market holidays are skipped entirely anyway).
MAYURA_BREAKOUT_GRACE_DAYS     = 3

# --- The three temple-deity strategies (tweak freely) -----------------------
# Names are the form of Muruga at each temple. Each "exits" block tunes how that
# strategy manages a trade. Edit the numbers freely.
STRATEGIES = {
    "dandapani": {  # Dandayuthapani of PALANI — his weapon strikes
        "name": "Dandapani", "emoji": "🌄",
        "tagline": "breakout / momentum — strike the fresh golden cross",
        "profile": "breakout",   # scoring profile in sectorbot/stocks.py
        "exits": dict(stop=0.08, trail_arm=0.10, trail_give=0.10, tp=1.00,
                      atr=2.5, hold_days=10, time_min=0.05, failed_breakout=True,
                      max_ext=0.30),   # skip if >30% above 200-DMA (freshest)
    },
    "senthil": {  # Senthil Aandavan of TIRUCHENDUR — steady & enduring
        "name": "Senthil", "emoji": "🌊",
        "tagline": "quality + value — strong, fairly-priced, enduring",
        "profile": "quality",
        "exits": dict(stop=0.12, trail_arm=0.15, trail_give=0.12, tp=1.00,
                      atr=3.0, hold_days=45, time_min=0.05, failed_breakout=False,
                      max_ext=0.50),   # quality may be pricier, but still capped
    },
    "subramanya": {  # Subramanya Swamy of THIRUPPARANKUNDRAM (Madurai)
        "name": "Subramanya", "emoji": "🛕",
        "tagline": "accumulation — follow the smart money (delivery/MFI/FII)",
        "profile": "accumulation",
        "exits": dict(stop=0.10, trail_arm=0.12, trail_give=0.10, tp=1.00,
                      atr=2.5, hold_days=20, time_min=0.05, failed_breakout=False,
                      max_ext=0.40),   # skip if >40% above 200-DMA
    },
    # --- The three NEW faces (Arumugam = six faces). The remaining Aaru Padai
    #     Veedu abodes. Swaminatha reads NSE/BSE filings; the other two await
    #     the user's direction (dormant until a screen is uploaded). ----------
    "swaminatha": {  # Swaminathaswami of SWAMIMALAI — the Guru who taught Om
        "name": "Swaminatha", "emoji": "📜",
        "tagline": "filings-driven — read NSE/BSE announcements, buy on bullish news",
        "profile": "quality",   # base screen; the filings gate decides the buy
        "uses_filings": True,    # the news/filings face (engine support coming)
        "exits": dict(stop=0.10, trail_arm=0.12, trail_give=0.10, tp=1.00,
                      atr=2.5, hold_days=15, time_min=0.05, failed_breakout=False,
                      max_ext=0.40),
    },
    "thanikesa": {  # Thanikesa of THIRUTTANI — the calm, contented victor
        "name": "Thanikesa", "emoji": "🕊️",
        "tagline": "small-cap momentum — Minervini VCP + Stage-2, valuation-aware",
        "compute": "ohlc",          # score from live Kite bars, not CSV columns
        "ohlc_scorer": "thanikesa",  # sectorbot/technicals.py SCORERS_OHLC
        "profile": "technical",      # (only used if it ever falls back to CSV)
        # Small caps move fast & hard both ways: keep a firm stop, arm the
        # trailing profit-lock early, and exit a failed breakout quickly.
        "exits": dict(stop=0.10, trail_arm=0.10, trail_give=0.12, tp=1.00,
                      atr=2.5, hold_days=20, time_min=0.05, failed_breakout=True,
                      max_ext=0.30),   # don't chase already-parabolic small caps
    },
    "solaimalai": {  # Solaimalai Murugan of PAZHAMUDIRCHOLAI — abundance
        "name": "Solaimalai", "emoji": "🍃",
        "tagline": "large/mid-cap value+quality quant + Greenblatt special situations",
        "compute": "value_multifactor",   # cross-sectional z-score of CSV fundamentals
        "profile": "quality",        # (only if it ever falls back to CSV)
        "exits": dict(stop=0.12, trail_arm=0.15, trail_give=0.12, tp=1.00,
                      atr=3.0, hold_days=45, time_min=0.05, failed_breakout=False,
                      max_ext=0.50),
    },
}
STRATEGY_ORDER = ["dandapani", "senthil", "subramanya",
                  "swaminatha", "thanikesa", "solaimalai"]
CURRENT: dict = {}   # the active strategy (set by _use_strategy)


def _migrate_to_dandapani(folder: Path) -> None:
    """One-time: carry the original single-Mayura / 'palani' data into the
    Dandapani folder so its track record continues. Looks (in order) at the old
    'palani' folder, then the legacy mayura_data/universe.csv + portfolio."""
    import shutil
    srcs_uni = [MAYURA_DATA / "palani" / "universe.csv", MAYURA_DATA / "universe.csv"]
    srcs_pf = [MAYURA_DATA / "palani" / "portfolio.json",
               MAYURA_DATA / "mayura_portfolio.json"]
    if not (folder / "universe.csv").exists():
        for s in srcs_uni:
            if s.exists():
                shutil.copy2(s, folder / "universe.csv"); break
    if not (folder / "portfolio.json").exists():
        for s in srcs_pf:
            if s.exists():
                shutil.copy2(s, folder / "portfolio.json"); break


def _use_strategy(key: str) -> None:
    """Point the shared engine at one temple-strategy's OWN folder + portfolio,
    and apply that strategy's exit rules (this process only — the equity bot is
    never touched)."""
    global CURRENT
    s = STRATEGIES[key]
    CURRENT = {**s, "key": key}
    folder = MAYURA_DATA / key
    (folder / "snapshots").mkdir(parents=True, exist_ok=True)
    if key == "dandapani":
        _migrate_to_dandapani(folder)
    # paths (independent per strategy)
    config.DATA_DIR = folder
    config.DATA_CSV = folder / "fundamentals.csv"
    config.SNAPSHOTS_DIR = folder / "snapshots"
    config.PORTFOLIO_JSON = folder / "portfolio.json"
    # CONVENTION: each strategy's screen is a file named after the strategy,
    # uploaded flat into mayura_data/  →  mayura_data/<strategy>.csv
    #   mayura_data/dandapani.csv · mayura_data/senthil.csv · mayura_data/subramanya.csv
    # (the older folder/universe.csv still works as a fallback).
    config.UNIVERSE_CSV_PRIMARY = MAYURA_DATA / f"{key}.csv"
    _uni_candidates = [MAYURA_DATA / f"{key}.csv", folder / "universe.csv",
                       folder / f"{key}.csv"]
    # Case-insensitive AND location-tolerant: accept Subramanya.csv / SENTHIL.csv
    # whether it was dropped flat in mayura_data/ OR inside mayura_data/<key>/.
    # (Linux is case-sensitive, but a screen export shouldn't be lost over a
    # capital letter or a wrong folder.)
    # CRITICAL: a generic "universe.csv" only counts INSIDE this strategy's OWN
    # folder. We must NEVER pick the shared/legacy mayura_data/universe.csv for a
    # named strategy — that would make every face trade another face's shares.
    for searchdir, allow_generic in ((MAYURA_DATA, False), (folder, True)):
        try:
            for p in sorted(searchdir.glob("*.csv")):
                stem = p.stem.lower()
                if stem == key or (allow_generic and stem == "universe"):
                    _uni_candidates.insert(0, p)
        except OSError:
            pass
    config.UNIVERSE_CSV = next((c for c in _uni_candidates if c.exists()),
                              MAYURA_DATA / f"{key}.csv")
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
    config.BREAKOUT_GRACE_DAYS = MAYURA_BREAKOUT_GRACE_DAYS
    config.SKIP_MARKET_HOLIDAYS = True   # never trade on a holiday/weekend
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
def _mayura_telegram(result: dict, filings_summary: dict | None = None) -> str:
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
    age = _pool_age_note()
    if age:
        lines.append(age)
    if filings_summary and filings_summary.get("ran"):
        fs = filings_summary
        lines.append(f"📜 Filings: scanned {fs['scanned']} · "
                     f"✅ {len(fs['buy'])} bullish · 🚫 {len(fs['blocked'])} "
                     f"red-flag · {len(fs['neutral'])} quiet")
        for sym in fs["buy"][:5]:
            head = fs["verdicts"][sym].get("headline", "")[:48]
            lines.append(f"  ✅ {sym}: {head}")
        for sym in fs["blocked"][:3]:
            head = fs["verdicts"][sym].get("headline", "")[:48]
            lines.append(f"  🚫 {sym}: {head}")
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


def _topic_id():
    """The Telegram forum-topic id for the active strategy, from the env var
    TELEGRAM_TOPIC_<STRATEGY> (e.g. TELEGRAM_TOPIC_DANDAPANI). None = no topic
    (posts to the group's General / a plain chat)."""
    if not CURRENT:
        return None
    return os.environ.get(f"TELEGRAM_TOPIC_{CURRENT['key'].upper()}") or None


def _present_csvs_hint() -> str:
    """List the CSVs actually on disk so a filename/location mismatch is obvious
    (e.g. you uploaded 'Subramanya.csv' into the wrong folder)."""
    found = []
    folder = MAYURA_DATA / CURRENT["key"] if CURRENT else None
    for d in (MAYURA_DATA, folder):
        if d and d.exists():
            for p in sorted(d.glob("*.csv")):
                found.append(f"       • {p}")
    if not found:
        return f"     (no .csv files found under {MAYURA_DATA})"
    return "     CSV files I can see right now:\n" + "\n".join(found)


def _pool_csvs() -> list:
    """All CSV files that make up the current strategy's pool. Drop several files
    into mayura_data/<strategy>/ (e.g. small.csv + micro.csv) and Mayura MERGES
    them automatically — plus the flat mayura_data/<strategy>.csv if present.
    Only this strategy's own files; never the shared universe.csv."""
    if not CURRENT:
        return []
    key = CURRENT["key"]
    files, seen = [], set()
    flat = MAYURA_DATA / f"{key}.csv"
    folder = MAYURA_DATA / key
    candidates = [flat] if flat.exists() else []
    if folder.exists():
        candidates += sorted(folder.glob("*.csv"))
    for p in candidates:
        rp = p.resolve()
        if p.exists() and rp not in seen:
            seen.add(rp)
            files.append(p)
    return files


def _pool_age_note() -> str:
    """A short note about how old the freshest pool/screen file is, so you know
    when to re-upload. '' if there's no file."""
    import time as _time
    if CURRENT and CURRENT.get("compute") in ("ohlc", "value_multifactor"):
        paths = [p for p in _pool_csvs() if p.exists()]
    else:
        paths = [config.UNIVERSE_CSV] if config.UNIVERSE_CSV.exists() else []
    if not paths:
        return ""
    newest = max(paths, key=lambda p: p.stat().st_mtime)
    age = (_time.time() - newest.stat().st_mtime) / 86400.0
    stale = age > config.POOL_STALE_DAYS
    flag = " ⚠️ consider re-uploading a fresh export" if stale else ""
    return f"📁 Pool: {newest.name} · {age:.0f}d old{flag}"


def _watchlist():
    """Load THIS strategy's watchlist, best-first. CSV-scored strategies use
    their Trendlyne columns; OHLC strategies (Thanikesa) COMPUTE the score from
    live Kite price bars. Returns a list of dicts or None."""
    compute = CURRENT.get("compute") if CURRENT else None
    if compute == "ohlc":
        return _ohlc_watchlist()
    if compute == "value_multifactor":
        return _value_multifactor_watchlist()
    if not config.UNIVERSE_CSV.exists():
        return None
    from sectorbot.stocks import load_watchlist
    profile = CURRENT.get("profile", "breakout") if CURRENT else "breakout"
    wl = load_watchlist(config.UNIVERSE_CSV, profile)
    return wl or None


def _ohlc_watchlist():
    """Compute the watchlist from live OHLC bars (Minervini VCP/Stage-2 etc.).
    The pool CSV(s) are just the candidate universe (e.g. Smallcap 250 + Microcap
    250); the EDGE is computed here, not screened. Returns best-first dicts shaped
    like load_watchlist (symbol/score/sma50/sma200/dist52) so the engine is unchanged."""
    import time
    from sectorbot import technicals as T
    from sectorbot.stocks import load_symbols, load_valuations
    from sectorbot.datasource import get_datasource

    paths = _pool_csvs()
    rows, seen = [], set()
    for p in paths:                          # MERGE all pool files, de-duped
        for r in load_symbols(p):
            if r["symbol"] not in seen:
                seen.add(r["symbol"])
                rows.append(r)
    if not rows:
        return None
    if len(paths) > 1:
        print(f"  🧩 Merged {len(paths)} pool files → {len(rows)} unique stocks.")
    symbols = [r["symbol"] for r in rows][: config.OHLC_MAX_SYMBOLS]
    scorer = T.SCORERS_OHLC.get(CURRENT.get("ohlc_scorer", "thanikesa"),
                                T.thanikesa_score)
    vals = {}
    for p in paths:
        vals.update(load_valuations(p))       # {} unless a pool file has valuation
    if vals and config.THANIKESA_VALUATION_FLOOR:
        print(f"  💰 Valuation guard ON (skip Trendlyne valuation < "
              f"{config.THANIKESA_VALUATION_FLOOR:.0f}; demote up to "
              f"{config.THANIKESA_VALUATION_FULL:.0f}).")
    ds = get_datasource()
    idx = ds.history(config.REGIME_INDEX, config.OHLC_HISTORY_BARS)
    print(f"  🧮 Computing {CURRENT['name']} edge from live OHLC for "
          f"{len(symbols)} candidates (this takes a moment)…")
    out = []
    for i, sym in enumerate(symbols):
        try:
            bars = ds.history(sym, config.OHLC_HISTORY_BARS)
        except Exception:  # noqa: BLE001  (rate limit / bad symbol -> skip)
            bars = []
        if not bars:
            continue
        sc = scorer(bars, idx)
        if sc is None:
            continue
        # Valuation guard (lenient): skip the very expensive, demote the rest.
        note = ""
        info = vals.get(sym)
        if info and config.THANIKESA_VALUATION_FLOOR:
            vscore = info.get("valuation")
            if vscore is not None:
                if vscore < config.THANIKESA_VALUATION_FLOOR:
                    if config.OHLC_FETCH_DELAY and i < len(symbols) - 1:
                        time.sleep(config.OHLC_FETCH_DELAY)
                    continue   # too expensive — skipped
                sc *= _valuation_factor(vscore)
                if vscore < config.THANIKESA_VALUATION_FULL:
                    note = f"💰 val {vscore:.0f} (pricey)"
        s50, s200, dist = T.levels(bars)
        out.append({"symbol": sym, "score": round(sc, 1),
                    "sma50": s50, "sma200": s200, "dist52": dist, "event": note})
        if config.OHLC_FETCH_DELAY and i < len(symbols) - 1:
            time.sleep(config.OHLC_FETCH_DELAY)
    out.sort(key=lambda d: d["score"], reverse=True)
    return out or None


def _valuation_factor(vscore: float) -> float:
    """0.65–1.0 multiplier: cheap (>= FULL) keeps full score, expensive (at the
    FLOOR) is demoted to THANIKESA_VALUATION_MIN_FACTOR. Linear in between."""
    floor, full = config.THANIKESA_VALUATION_FLOOR, config.THANIKESA_VALUATION_FULL
    if vscore >= full:
        return 1.0
    if vscore <= floor or full <= floor:
        return config.THANIKESA_VALUATION_MIN_FACTOR
    frac = (vscore - floor) / (full - floor)
    return config.THANIKESA_VALUATION_MIN_FACTOR + frac * (1 - config.THANIKESA_VALUATION_MIN_FACTOR)


def _value_multifactor_watchlist():
    """Solaimalai: large/mid-cap VALUE + QUALITY quant + Greenblatt special
    situations. Reads fundamental factors from a Trendlyne export, cross-
    sectionally z-scores them (the 'quant' step), then overlays filings to BOOST
    special situations (buyback/demerger/promoter buying) and BLOCK red-flags.
    Value-led, so it deliberately AVOIDS the expensive momentum leaders Thanikesa
    holds. Returns engine-shaped dicts (symbol/score/sma50/sma200/dist52)."""
    from sectorbot import technicals as T
    from sectorbot.stocks import load_fundamental_factors

    paths = _pool_csvs()
    data, seen = [], set()
    for p in paths:                          # MERGE all pool files, de-duped
        for r in load_fundamental_factors(p):
            if r["symbol"] not in seen:
                seen.add(r["symbol"])
                data.append(r)
    if not data:
        return None
    if len(paths) > 1:
        print(f"  🧩 Merged {len(paths)} pool files.")
    print(f"  🧮 Solaimalai: value+quality multi-factor over {len(data)} stocks "
          f"(weights {config.SOLAIMALAI_FUND_WEIGHTS}).")
    scores = T.composite_zscore(data, config.SOLAIMALAI_FUND_WEIGHTS)
    for d in data:
        d["score"] = scores.get(d["symbol"], 0.0)
        d["event"] = ""
        d.pop("factors", None)
    # Greenblatt special-situations overlay on the top names (filings) — boost
    # buyback/demerger/spin-off/promoter-buying, block red-flags. Fail-open.
    data.sort(key=lambda d: d["score"], reverse=True)
    if date.today().weekday() < 5:        # skip the network on weekends
        from sectorbot import filings
        top = data[: config.FILINGS_SCAN_TOP]
        print(f"  ⭐ Checking filings for special situations on the top "
              f"{len(top)} names…")
        for d in top:
            a = filings.assess_symbol(d["symbol"])
            if a["verdict"] == "bearish":
                d["score"] = 0.0
                d["event"] = "🚫 " + (a.get("headline", "")[:34])
            elif a.get("special"):
                d["score"] = min(100.0, d["score"] + config.SOLAIMALAI_SPECIAL_BOOST)
                d["event"] = "⭐ " + ", ".join(a["special"])
        data.sort(key=lambda d: d["score"], reverse=True)
    return data or None


def _filings_gate(ranked: list) -> dict:
    """Swaminatha's brain: read recent NSE/BSE filings for the top-ranked
    candidates and keep ONLY those with bullish news (red-flag filings are
    blocked). Returns a summary dict; 'buy' is the filtered, rank-ordered list
    the engine should trade. FAIL-SAFE: a stock we can't read is NOT bought."""
    from sectorbot import filings
    # Don't hammer the exchange on weekends — the engine is the authority on
    # actual holidays (it checks Kite), this just avoids pointless fetches.
    if date.today().weekday() >= 5:
        print("  📜 Filings: weekend — skipping (engine will report 'resting').")
        return {"ran": False, "buy": ranked}
    scan = ranked[: config.FILINGS_SCAN_TOP]
    print(f"  📜 Reading {config.FILINGS_SOURCE.upper()} filings for the top "
          f"{len(scan)} candidates (last {config.FILINGS_DAYS_BACK} days)…")
    verdicts = {sym: filings.assess_symbol(sym) for sym in scan}
    buckets = filings.gate(verdicts)
    summary = {"ran": True, "scanned": len(scan), "verdicts": verdicts, **buckets}
    print(f"     ✅ {len(buckets['buy'])} bullish · 🚫 {len(buckets['blocked'])} "
          f"red-flag · {len(buckets['neutral'])} quiet · "
          f"{len(buckets['unknown'])} unreadable")
    if buckets["buy"]:
        print(f"     Buy candidates: {', '.join(buckets['buy'][:8])}")
    if buckets["blocked"]:
        print(f"     Blocked (red flag): {', '.join(buckets['blocked'][:8])}")
    if not buckets["buy"]:
        print("     No bullish filings today — Mayura will manage existing "
              "holdings but buy nothing new. (No news = no buy.)")
    return summary


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
        print(f"\n  ⏭  No screen for {CURRENT['name']} yet — upload its Trendlyne "
              f"export as:\n     {config.UNIVERSE_CSV_PRIMARY}\n     Skipping.")
        print(_present_csvs_hint())
        return
    ranked = [d["symbol"] for d in wl]
    levels = {d["symbol"]: d["sma50"] for d in wl if d.get("sma50")}
    ext_levels = {d["symbol"]: d["sma200"] for d in wl if d.get("sma200")}
    print(f"  Watchlist   : 🎯 {len(ranked)} stocks ({CURRENT['profile']} score; "
          f"top: {', '.join(ranked[:5])})")
    print(f"  Guard       : skip any stock >{config.MAX_EXTENSION_ABOVE_SMA200:.0%} "
          f"above its 200-DMA (no chasing already-run-up names)")

    # SWAMINATHA: read NSE/BSE filings and keep ONLY stocks with bullish news.
    filings_summary = None
    if CURRENT.get("uses_filings"):
        filings_summary = _filings_gate(ranked)
        if filings_summary.get("ran"):
            ranked = filings_summary["buy"]   # bullish-only, rank order preserved
    print()

    # verbose=False so the engine's own "SectorBot" printout is suppressed; we
    # render Mayura's branded summary instead.
    result = run_paper_session(verbose=False, ranked_symbols=ranked,
                               levels=levels, ext_levels=ext_levels)
    if ranked and not result.get("aborted"):
        # In watchlist mode the fundamentals-CSV date is irrelevant — what
        # matters is the breakout universe.csv. Don't show a misleading "stale".
        result["data_stale"] = False
        result["data_date"] = None
    topic = _topic_id()
    if result.get("market_closed"):
        print(f"\n  📴 {result['message']}\n")
        # Send a short "resting today" ping so you get daily confirmation each
        # strategy (and its topic) is alive, even on holidays/weekends. No
        # trading happens — holdings are untouched.
        who = f"{CURRENT['emoji']} {CURRENT['name']}" if CURRENT else "Mayura"
        age = _pool_age_note()
        msg = (f"{PEACOCK} <b>Mayura · {who} · {date.today().isoformat()}</b>\n"
               f"😴 Market closed today (holiday/weekend) — resting, no trades.\n"
               + (age + "\n" if age else "") +
               f"<i>Holdings untouched. Vel Muruga 🙏</i>")
        delivered = send_telegram(msg, message_thread_id=topic)
        print(f"  Telegram: {'sent 🙏' if delivered else 'dry-run (set the two env vars)'}")
        return
    if result.get("aborted"):
        # Engine refused (e.g. real Kite data required but unavailable). The
        # portfolio was left untouched — nothing to report or send.
        print(f"  {PEACOCK} Skipped: {result['message']}")
        send_telegram(f"{PEACOCK} <b>Mayura · {CURRENT['name']}</b> skipped: "
                      f"{result['message']}", message_thread_id=topic)
        return

    _print_mayura(result)
    txt, _ = write_portfolio_report(result)
    print(f"  Report written: {txt}")
    delivered = send_telegram(_mayura_telegram(result, filings_summary),
                              message_thread_id=topic)
    print(f"  Telegram: {'sent 🙏' if delivered else 'dry-run (set the two env vars)'}")
    print(f"\n  {PEACOCK} May Lord Muruga guide steady gains. Paper only.\n")


def cmd_rank() -> None:
    _banner("TODAY'S RANKING")
    wl = _watchlist()
    if not wl:
        print(f"\n  ⏭  No screen for {CURRENT['name']} yet — upload its Trendlyne "
              f"export as:\n     {config.UNIVERSE_CSV_PRIMARY}\n")
        return
    print(f"  🎯 {CURRENT['name']} watchlist — {len(wl)} stocks, scored by the "
          f"'{CURRENT['profile']}' model\n")
    print(f"  {'#':>3}  {'Symbol':14} {'Score':>8}  Note")
    print("  " + "-" * 46)
    for i, d in enumerate(wl[:20], 1):
        print(f"  {i:>3}  {d['symbol']:14} {d['score']:>8.1f}  {d.get('event','')}")
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


def cmd_filings() -> None:
    """Dry-run Swaminatha's filings reader: show the bullish / red-flag verdict
    for each top candidate WITHOUT trading. Great for sanity-checking the feed."""
    _banner("FILINGS READ")
    if not CURRENT.get("uses_filings"):
        print(f"\n  {CURRENT['name']} is not a filings strategy. Try: "
              f"python mayura.py filings swaminatha\n")
        return
    wl = _watchlist()
    if not wl:
        print(f"\n  ⏭  No screen for {CURRENT['name']} yet — upload its base "
              f"export as:\n     {config.UNIVERSE_CSV_PRIMARY}\n")
        print(_present_csvs_hint())
        return
    from sectorbot import filings
    scan = [d["symbol"] for d in wl][: config.FILINGS_SCAN_TOP]
    print(f"\n  📜 Reading {config.FILINGS_SOURCE.upper()} filings for {len(scan)} "
          f"candidates (last {config.FILINGS_DAYS_BACK} days). No trading.\n")
    print(f"  {'Symbol':14} {'Verdict':9} Headline")
    print("  " + "-" * 64)
    icon = {"bullish": "✅", "bearish": "🚫", "neutral": "·", "unknown": "❓"}
    for sym in scan:
        a = filings.assess_symbol(sym)
        v = a["verdict"]
        print(f"  {sym:14} {icon.get(v,'?')} {v:7} {a.get('headline','')[:46]}")
    print("\n  ✅ bullish = would buy · 🚫 red flag = blocked · ❓ unreadable = "
          "skipped (no news = no buy). Paper only. 🦚\n")


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
    pool = _pool_csvs()
    if CURRENT.get("compute") == "value_multifactor":
        # Solaimalai: value+quality from Trendlyne fundamentals export(s).
        from sectorbot.stocks import load_fundamental_factors
        if pool:
            data, seen = [], set()
            for p in pool:
                for r in load_fundamental_factors(p):
                    if r["symbol"] not in seen:
                        seen.add(r["symbol"]); data.append(r)
            print(f"  pool files   : 🧩 {len(pool)} ({', '.join(p.name for p in pool)})")
            print(f"  universe     : ✅ {len(data)} stocks with usable factors")
            print(f"  scoring      : 🧮 VALUE + QUALITY cross-sectional z-score "
                  f"(Trendlyne DVM/PE/PBV) + Greenblatt special-situations "
                  f"overlay from filings. Large/mid-cap; value-led.")
            print(f"  note         : upload Trendlyne LARGE/MID-cap export(s) with "
                  f"NSE Code + Durability/Valuation/PE/PBV/Momentum columns.")
        else:
            print(f"  screen file  : ❌ MISSING — upload a Trendlyne export as")
            print(f"     {config.UNIVERSE_CSV_PRIMARY}  (or drop files in {config.DATA_DIR})")
        print()
        return
    if CURRENT.get("compute") == "ohlc":
        # Thanikesa: pool CSV(s) are the candidate universe; the edge is computed
        # from live bars. Count cheaply (no fetch). Valuation guard if present.
        from sectorbot.stocks import load_symbols, load_valuations
        if pool:
            syms, seen, vals = [], set(), {}
            for p in pool:
                for r in load_symbols(p):
                    if r["symbol"] not in seen:
                        seen.add(r["symbol"]); syms.append(r)
                vals.update(load_valuations(p))
            guard = "ON 💰" if vals else "off (bare symbol list)"
            print(f"  pool files   : 🧩 {len(pool)} ({', '.join(p.name for p in pool)})")
            print(f"  universe     : ✅ {len(syms)} unique candidate stocks")
            print(f"  scoring      : 🧮 LIVE Kite OHLC — "
                  f"{CURRENT.get('ohlc_scorer','technical')} (Minervini VCP + "
                  f"Stage-2 + momentum + RS).")
            print(f"  valuation guard : {guard}")
            print(f"  note         : drop several files in {config.DATA_DIR} "
                  f"(e.g. small.csv + micro.csv) — Mayura merges them.")
        else:
            print(f"  screen file  : ❌ MISSING — upload a candidate pool as")
            print(f"     {config.UNIVERSE_CSV_PRIMARY}  (or drop files in {config.DATA_DIR})")
        print()
        return
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
        print(f"  screen file  : ❌ MISSING — upload this strategy's Trendlyne")
        print(f"     export as:  {config.UNIVERSE_CSV_PRIMARY}")
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


def cmd_telegram_setup() -> None:
    """Help wire a 'Mayura' group with one TOPIC per strategy. It reads recent
    Telegram updates and prints each chat id + topic (thread) id, so you can put
    them in .env."""
    _banner("TELEGRAM TOPICS SETUP")
    import json, urllib.request
    if not config.TELEGRAM_BOT_TOKEN:
        print("\n  Set TELEGRAM_BOT_TOKEN first (source your .env).\n")
        return
    print("""
  STEP 1 — In Telegram: create a group called "Mayura" → group settings →
           enable "Topics". Create SIX topics (Arumugam — Muruga's six faces):
           Dandapani, Senthil, Subramanya, Swaminatha, Thanikesa, Solaimalai.
  STEP 2 — Add your Mayura bot to the group and make it an Admin.
  STEP 3 — In EACH topic, type any message (e.g. "hi").
  STEP 4 — Run this command. It prints the ids below — copy them into .env:

      TELEGRAM_CHAT_ID=<the group id (a negative number)>
      TELEGRAM_TOPIC_DANDAPANI=<Dandapani topic id>
      TELEGRAM_TOPIC_SENTHIL=<Senthil topic id>
      TELEGRAM_TOPIC_SUBRAMANYA=<Subramanya topic id>
      TELEGRAM_TOPIC_SWAMINATHA=<Swaminatha topic id>
      TELEGRAM_TOPIC_THANIKESA=<Thanikesa topic id>
      TELEGRAM_TOPIC_SOLAIMALAI=<Solaimalai topic id>
""")
    url = f"https://api.telegram.org/bot{config.TELEGRAM_BOT_TOKEN}/getUpdates"
    try:
        data = json.loads(urllib.request.urlopen(url, timeout=20).read())
    except Exception as exc:  # noqa: BLE001
        print(f"  Could not fetch updates: {exc}\n")
        return
    rows = data.get("result", [])
    if not rows:
        print("  No recent messages found. Post a message in each topic, then "
              "re-run (getUpdates only shows the last ~24h).\n")
        return
    print(f"  {'chat id':>16}  {'topic id':>9}  {'topic name / text'}")
    print("  " + "-" * 60)
    seen = set()
    detected: dict[str, str] = {}   # env var -> value, auto-matched by topic name
    chat_id = None
    # Build name -> strategy-key map (so a topic literally named "Swaminatha"
    # auto-maps to TELEGRAM_TOPIC_SWAMINATHA). Also accept the message text, so
    # typing the strategy name into a topic works even if the topic-created
    # event has scrolled out of getUpdates' 24h window.
    name_to_key = {STRATEGIES[k]["name"].lower(): k for k in STRATEGY_ORDER}
    name_to_key.update({k: k for k in STRATEGY_ORDER})
    for u in rows:
        m = u.get("message") or u.get("channel_post") or {}
        chat = m.get("chat", {})
        thread = m.get("message_thread_id")
        topic_name = (m.get("forum_topic_created", {}) or {}).get("name") or ""
        text = m.get("text") or ""
        label = topic_name or text
        key = (chat.get("id"), thread)
        if chat.get("id") is not None and (chat.get("type") in ("group", "supergroup")):
            chat_id = chat.get("id")
        # try to auto-match this topic to one of the six faces
        for probe in (topic_name, text):
            sk = name_to_key.get(probe.strip().lower())
            if sk and thread is not None:
                detected[f"TELEGRAM_TOPIC_{sk.upper()}"] = str(thread)
                break
        if key in seen:
            continue
        seen.add(key)
        print(f"  {str(chat.get('id')):>16}  {str(thread or '-'):>9}  "
              f"{(chat.get('title') or '')} | {label[:30]}")
    if chat_id is not None:
        detected["TELEGRAM_CHAT_ID"] = str(chat_id)

    if not detected:
        print("\n  Couldn't auto-match any topic names. Make sure each topic is "
              "NAMED after a face (Dandapani/Senthil/Subramanya/Swaminatha/"
              "Thanikesa/Solaimalai) or type that name as a message in the "
              "topic, then re-run. 🦚\n")
        return
    print("\n  ✅ Auto-detected:")
    for k, v in detected.items():
        print(f"       {k}={v}")
    written = _upsert_env(detected)
    if written:
        print(f"\n  📝 Written into {written}. Run `source .env` (or just re-run "
              "Mayura — it now auto-loads .env). Vel Muruga! 🦚\n")
    else:
        print("\n  Could not find a .env to update — add the lines above "
              "manually.\n")


def _upsert_env(values: dict) -> "Path | None":
    """Insert/replace KEY=VALUE lines in the repo-root .env (create if missing).
    Returns the path written, or None on failure. Never touches other lines."""
    env_path = REPO_ROOT / ".env"
    try:
        lines = env_path.read_text().splitlines() if env_path.exists() else []
        remaining = dict(values)
        out = []
        for line in lines:
            stripped = line.strip()
            key = stripped.split("=", 1)[0].strip() if "=" in stripped else ""
            key = key[len("export "):].strip() if key.startswith("export ") else key
            if key in remaining:
                out.append(f"{key}={remaining.pop(key)}")
            else:
                out.append(line)
        for k, v in remaining.items():     # any not already present → append
            out.append(f"{k}={v}")
        env_path.write_text("\n".join(out) + "\n")
        return env_path
    except OSError:
        return None


def cmd_explain(symbol: str) -> None:
    """Show WHY a stock scores what it does — the full OHLC factor breakdown
    (Stage-2 trend template, VCP, momentum, relative strength). So you can see
    exactly why e.g. RRKABEL ranks high (or shouldn't)."""
    _banner(f"WHY: {symbol}")
    if not symbol:
        print("\n  Usage: python mayura.py explain <SYMBOL>   (e.g. RRKABEL)\n")
        return
    from sectorbot import technicals as T
    from sectorbot.datasource import PaperDataSource, get_datasource
    ds = get_datasource()
    if isinstance(ds, PaperDataSource):
        print("\n  Synthetic data — load your Kite keys (.env) for real numbers.\n")
        return
    bars = ds.history(symbol, config.OHLC_HISTORY_BARS)
    idx = ds.history(config.REGIME_INDEX, config.OHLC_HISTORY_BARS)
    if not bars:
        print(f"\n  No OHLC for {symbol} (bad symbol or not on NSE).\n")
        return
    tt = T.trend_template(bars)
    v = T.vcp(bars)
    mom = T.momentum(bars)
    rs = T.relative_strength(bars, idx)
    vol = T.volatility_pct(bars)
    s50, s200, dist = T.levels(bars)
    ext = ((bars[-1].close / s200 - 1) * 100) if (s200 and s200 > 0) else None
    print(f"\n  Price {bars[-1].close:,.1f}  ·  {len(bars)} daily bars\n")
    print("  📐 STAGE-2 TREND TEMPLATE (Minervini's 8 checks):")
    labels = {"above_150_200": "price above 150 & 200-DMA",
              "150_above_200": "150-DMA above 200-DMA",
              "200_rising": "200-DMA trending up",
              "50_above_150_200": "50 > 150 > 200-DMA",
              "above_50": "price above 50-DMA",
              "30pct_above_low": "≥30% above 52-week low",
              "within_25pct_high": "within 25% of 52-week high"}
    for k, ok in tt["checks"].items():
        print(f"     {'✅' if ok else '❌'} {labels.get(k, k)}")
    print(f"     → trend score {tt['score']:.0f}/100  ({'Stage-2 ✅' if T.is_stage2(bars) else 'NOT Stage-2 ❌'})")
    print(f"\n  🌀 VCP (volatility contraction): score {v['score']:.0f}/100  "
          f"{'is-VCP ✅' if v['is_vcp'] else 'not a clean VCP'}")
    print(f"     contractions {v['contractions']} (want shrinking) · "
          f"latest tightness {v['tightness']} · near-pivot {v['near_pivot']} · "
          f"vol-dry-up {v['vol_dryup']}")
    print(f"\n  🚀 Momentum (6-mo, skip 1-mo): "
          f"{mom*100:+.1f}%" if mom is not None else "  🚀 Momentum: n/a")
    print(f"  💪 Relative strength vs NIFTY: "
          f"{rs*100:+.1f}%" if rs is not None else "  💪 RS: n/a")
    print(f"  📊 Daily volatility: {vol*100:.2f}%" if vol is not None else "  📊 vol: n/a")
    print(f"  📍 {dist:.1f}% below 52-wk high · {ext:+.0f}% vs its 200-DMA"
          if (dist is not None and ext is not None) else "")
    th = T.thanikesa_score(bars, idx)
    print(f"\n  🕊️ Thanikesa score: {th}")
    if ext is not None and ext > config.MAX_EXTENSION_ABOVE_SMA200 * 100:
        print(f"  ⚠️ {ext:.0f}% above 200-DMA exceeds the {config.MAX_EXTENSION_ABOVE_SMA200:.0%} "
              "extension guard — it would be SKIPPED at buy time even if ranked high.")
    print("\n  Note: these are PURE technicals — they say nothing about PE/PB/"
          "valuation. A stock can be a perfect momentum setup AND expensive. 🦚\n")


def cmd_rules() -> None:
    """Show THIS strategy's exit rules in plain English (each temple differs)."""
    _banner("EXIT RULES")
    fb = ("💔 Failed breakout  : exit the moment price falls below its SMA50\n"
          if config.USE_FAILED_BREAKOUT_EXIT else "")
    if CURRENT.get("uses_filings"):
        print(f"""
  📜 ENTRY GATE (Swaminatha only): before buying, reads {config.FILINGS_SOURCE.upper()}
     filings (last {config.FILINGS_DAYS_BACK} days) for the top {config.FILINGS_SCAN_TOP} candidates.
     ✅ Buys ONLY on a bullish filing (order win, approval, buyback, upgrade…)
     🚫 Blocks any red flag (SEBI action, default, auditor exit, pledge…)
     ❓ Can't read it = no buy (no news, no trade).""")
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
GLOBAL_COMMANDS = {"check": cmd_check, "regime": cmd_regime,
                   "telegram-setup": cmd_telegram_setup}
# Commands that run PER strategy (loop all three unless one is named).
PER_STRATEGY_COMMANDS = {
    "run": cmd_run, "rank": cmd_rank, "status": cmd_status,
    "scorecard": cmd_scorecard, "data": cmd_data, "rules": cmd_rules,
    "universe": cmd_universe, "filings": cmd_filings,
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

    if choice == "explain":
        # `explain <SYMBOL>` — factor breakdown, strategy-agnostic.
        _use_strategy("thanikesa")          # sets config context for OHLC
        cmd_explain((args[1] if len(args) > 1 else "").upper())
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

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

# Mayura reuses the battle-tested engine; it never re-implements the strategy.
from sectorbot import config


PEACOCK = "🦚"
BLESSING = "ஓம் சரவணபவ — Vel Muruga! May this run be steady, not greedy."


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
def cmd_run() -> None:
    """The main event: one paper-trading session + a Telegram ping."""
    _banner("DAILY RUN")
    print(f"  {BLESSING}\n")
    from sectorbot.engine import run_paper_session
    from sectorbot.notify import write_portfolio_report
    from sectorbot.telegram import send_telegram

    result = run_paper_session(verbose=True)
    if result.get("aborted"):
        # Engine refused (e.g. real Kite data required but unavailable). The
        # portfolio was left untouched — nothing to report or send.
        send_telegram(f"{PEACOCK} <b>Mayura</b> skipped today: "
                      f"{result['message']}")
        return

    txt, _ = write_portfolio_report(result)
    print(f"\n  Report written: {txt}")
    delivered = send_telegram(_mayura_telegram(result))
    print(f"  Telegram: {'sent 🙏' if delivered else 'dry-run (set the two env vars)'}")
    print(f"\n  {PEACOCK} May Lord Muruga guide steady gains. Paper only.\n")


def cmd_rank() -> None:
    _banner("TODAY'S RANKING")
    from sectorbot.data_loader import resolve_csv
    from sectorbot.instruments import symbols_for
    from sectorbot.screener import top_industries
    print(f"  Data file: {resolve_csv(None)}\n")
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


COMMANDS = {
    "run": cmd_run,
    "rank": cmd_rank,
    "status": cmd_status,
    "scorecard": cmd_scorecard,
    "check": cmd_check,
    "universe": cmd_universe,
}


def main() -> None:
    _assert_paper_only()
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

"""What gapped overnight, known before the options start trading.

NSE runs a pre-open call auction for EQUITIES from 09:00 to 09:08, matches it
by 09:12, and opens continuous trading at 09:15. Options do not take part —
there is no pre-open auction in F&O, so an option order placed before 09:15
simply queues and competes at the open like everyone else's.

That gap is the only real lead time available to a retail screen. By 09:08 the
equity auction has an indicative price, and it is usually close to where the
stock actually opens. So on a morning when a stock is indicated -8%, you know
which way its options will reprice roughly seven minutes before they can be
traded.

**What this does NOT give you.** It does not let you buy the put at yesterday's
price. The option reprices on its first tick at 09:15, fully reflecting the gap
the equity auction has already published. A limit left at yesterday's premium
never fills — it is under the market from the first print, which is exactly how
an order sits "unprocessed" while the option runs away. What seven minutes buys
is the chance to decide deliberately and to set a limit at a price that can
actually trade, instead of discovering the move after it has happened.

    python3 -m garuda.preopen                # F&O names, gaps >= 3%
    python3 -m garuda.preopen --min 5        # only the big ones
    python3 -m garuda.preopen --all          # every name, no threshold

Run it between 09:05 and 09:14. Outside that window it still runs and simply
reports the last available prices, which on an open market is just today's
move — useful for a check, not a forecast.
"""

from .market import now_ist

#: Report a name once it is indicated this far from yesterday's close.
GAP_PCT = 3.0

#: The equity pre-open auction: order entry 09:00-09:08, matched by 09:12,
#: continuous trading (and all F&O) from 09:15.
PREOPEN_OPEN_MIN = 9 * 60          # 09:00
PREOPEN_ENTRY_END_MIN = 9 * 60 + 8  # 09:08
MARKET_OPEN_MIN = 9 * 60 + 15      # 09:15

#: NSE strike intervals widen with price. This is a reasonable reading of the
#: usual bands, NOT the exchange's contract master — a stock can and does carry
#: a different interval. Treat the ladder as "look around here", and read the
#: real strikes off the option chain before sending anything.
STRIKE_BANDS = ((100, 2.5), (250, 5), (500, 10), (1000, 20),
                (2500, 50), (5000, 100), (float("inf"), 200))


def in_preopen(dt=None):
    """Is the equity pre-open auction running right now?"""
    dt = dt or now_ist()
    mins = dt.hour * 60 + dt.minute
    return PREOPEN_OPEN_MIN <= mins < MARKET_OPEN_MIN


def strike_step(price):
    for ceiling, step in STRIKE_BANDS:
        if price < ceiling:
            return step
    return STRIKE_BANDS[-1][1]


def strike_ladder(price, n=2):
    """The nearest strikes above and below an indicated price. An estimate —
    see STRIKE_BANDS."""
    if not price or price <= 0:
        return []
    step = strike_step(price)
    atm = round(price / step) * step
    out = [atm + i * step for i in range(-n, n + 1)]
    return [int(s) if float(s).is_integer() else s for s in out if s > 0]


def gap_rows(quotes, min_pct=GAP_PCT):
    """[{sym, pc, ltp, gap_pct, side, strikes}] for names past the threshold.

    `quotes` is KiteFeed.ohlc_quote()-shaped: {sym: {pc, ltp, ...}}. A name
    with no previous close is skipped rather than shown at 0% — an unknown gap
    is not a small one.
    """
    out = []
    for sym, q in (quotes or {}).items():
        pc, ltp = (q or {}).get("pc"), (q or {}).get("ltp")
        if not pc or not ltp or pc <= 0:
            continue
        gap = (ltp - pc) / pc * 100.0
        if abs(gap) < min_pct:
            continue
        out.append({"sym": sym, "pc": round(pc, 2), "ltp": round(ltp, 2),
                    "gap_pct": round(gap, 2),
                    # The side that GAINS from the move continuing. Named this
                    # way round because a gap down is a put's morning.
                    "side": "PE" if gap < 0 else "CE",
                    "strikes": strike_ladder(ltp)})
    out.sort(key=lambda r: -abs(r["gap_pct"]))
    return out


def main(argv=None):
    import sys
    argv = list(sys.argv[1:] if argv is None else argv)

    def opt(flag, cast=str, default=None):
        return cast(argv[argv.index(flag) + 1]) if flag in argv else default

    min_pct = 0.0 if "--all" in argv else opt("--min", float, GAP_PCT)

    from .feed import KiteFeed
    from .stock_options import load_fno_universe

    fno = load_fno_universe()
    if not fno:
        print("no fno_stocks.txt — nothing to watch")
        return 1
    # NSE's F&O stock list runs to roughly 220 names. A much shorter file is
    # stale, and a stock missing from it is invisible here no matter how far
    # it gaps — which is the failure mode worth naming out loud.
    if len(fno) < 150:
        print(f"WARNING: fno_stocks.txt has only {len(fno)} names. NSE's F&O "
              f"list is ~220.\n  Any stock missing from it cannot be reported "
              f"below, however far it moves.\n  Refresh it with "
              f"scripts/refresh_cas_stocks.py before relying on this.\n")

    feed = KiteFeed()
    if not feed.live:
        print("no live Kite session — cannot read pre-open prices")
        return 1

    now = now_ist()
    mins = now.hour * 60 + now.minute
    if in_preopen(now):
        when = ("pre-open auction is running — these are INDICATED prices, "
                "not trades" if mins < PREOPEN_ENTRY_END_MIN else
                "pre-open order entry has closed; the auction is matching")
    elif mins < PREOPEN_OPEN_MIN:
        when = "before the pre-open auction — these are yesterday's prices"
    else:
        when = "market is open — this is today's move, not a forecast"
    print(f"{now:%Y-%m-%d %H:%M} IST · {when}")
    print(f"{len(fno)} F&O names · reporting gaps of {min_pct:.1f}% or more\n")

    quotes = feed.ohlc_quote(fno)
    if not quotes:
        print("no quotes returned")
        return 1
    rows = gap_rows(quotes, min_pct)
    if not rows:
        print(f"nothing gapping {min_pct:.1f}% or more "
              f"({len(quotes)} of {len(fno)} names quoted)")
        return 0

    print(f"  {'SYMBOL':<14}{'PREV':>10}{'NOW':>10}{'GAP':>9}  "
          f"{'side':<5}strikes near the indicated open")
    for r in rows:
        ladder = " ".join(str(s) for s in r["strikes"])
        print(f"  {r['sym']:<14}{r['pc']:>10.2f}{r['ltp']:>10.2f}"
              f"{r['gap_pct']:>+8.2f}%  {r['side']:<5}{ladder}")
    print(f"\n  {len(quotes)} of {len(fno)} names quoted.")
    print("  Strikes are an ESTIMATE from the usual NSE intervals — read the")
    print("  real chain before sending an order.")
    if mins < MARKET_OPEN_MIN:
        print("  Options do not trade until 09:15. They will open already")
        print("  repriced for this gap: a limit at yesterday's premium will")
        print("  not fill.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

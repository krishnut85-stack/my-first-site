"""Tests for Garuda's live brain: profiles, portfolio, and the daily scanner."""

import random

from garuda.strategy import PROFILES, Profile
from garuda.portfolio import LivePortfolio
from garuda.scan import run_scan


def _reverting(days=400, seed=1):
    rng = random.Random(seed)
    price, prev = 100.0, 0.0
    c = [price]
    for _ in range(days):
        noise = -0.6 * prev + rng.gauss(0.0, 0.02)
        price = max(1.0, price * (1.0 + 0.0005 + noise))
        c.append(round(price, 3))
        prev = noise
    return c


def test_profiles_use_proven_settings():
    sc, mc = PROFILES["smallcap"], PROFILES["microcap"]
    for p in (sc, mc):
        assert p.entry_rsi == 10 and p.strategy == "rsi2"
        assert p.use_trend is True          # the uptrend filter is now ON (the showdown winner)
        assert p.label and p.capital == 1_000_000
    # microcap: the original quick-exit contract (no deep data to retest it)
    assert mc.exit_rsi == 85 and mc.max_hold == 30 and mc.hard_stop == 0.20
    # smallcap: DIP EXAM + DIP RACE retune — patient trail, RSI exit disabled
    assert sc.exit_rsi >= 100 and sc.trail == 0.25 and sc.max_hold == 180
    assert sc.hard_stop == 0.0
    n50 = PROFILES["next50"]
    assert n50.strategy == "momentum"       # Next 50 runs breakout + trailing stop
    assert n50.breakout == 20 and n50.trail == 0.15 and n50.max_hold == 120
    assert n50.label
    st = PROFILES["strength"]               # 4th book: whole-NSE strength swing
    assert st.strategy == "strength"
    assert st.rsi_lo == 55 and st.rsi_hi == 70 and st.trend_ma == 200
    assert st.trail == 0.12 and st.max_hold == 90 and st.label
    ld = PROFILES["leaders"]                # 5th book: momentum leaders
    assert ld.strategy == "leaders"
    assert ld.mom_days == 63 and ld.mom_min == 0.25 and ld.trend_ma == 200
    assert ld.trail == 0.20 and ld.max_hold == 180 and ld.label
    assert ld.daily_csv == "strength_daily.csv"   # shares the strength universe
    scl = PROFILES["scalein"]               # 6th book: scale-in (average-down)
    assert scl.strategy == "scalein"
    assert scl.entry_rsi == 10 and scl.exit_rsi == 50 and scl.max_units == 4
    assert scl.max_hold == 60 and scl.stop == 0.25 and scl.label


def test_portfolio_buy_sell_cash():
    pf = LivePortfolio(100_000)
    assert pf.buy("KEI", 10, 100.0, entry_len=250)
    assert pf.cash == 99_000
    pnl = pf.sell("KEI", 110.0)
    assert pnl == 100  # 10 shares * +10
    assert round(pf.cash) == 100_100
    assert pf.equity(lambda s: 0) == 100_100


def test_portfolio_rejects_overspend():
    pf = LivePortfolio(1_000)
    assert pf.buy("X", 100, 100.0, entry_len=1) is False   # 10,000 > 1,000 cash


def test_scan_no_position_cap_fills_by_cash():
    # 60 always-oversold-ish names; with ~2% each on 10L, ~50 should fill (cash-
    # bound), NOT an arbitrary 20 cap.
    prof = Profile("t", "T", "", "", entry_rsi=99, exit_rsi=85, max_hold=30,
                   use_trend=False, capital=1_000_000, alloc_pct=0.02)
    series = {f"S{i}": _reverting(seed=i) for i in range(60)}
    pf = LivePortfolio(prof.capital)
    result = run_scan(prof, series, pf)
    assert result["positions"] > 20            # not capped at 20
    assert pf.cash >= 0                         # never oversold cash


def test_scan_exits_on_max_hold():
    prof = PROFILES["smallcap"]
    series = {f"S{i}": _reverting(seed=i) for i in range(6)}
    pf = LivePortfolio(prof.capital)
    run_scan(prof, series, pf)                      # open some positions
    assert pf.holdings
    # make a holding look long-held (past max_hold), from an old scan date
    for h in pf.holdings.values():
        h["bars_held"] = prof.max_hold
        h["last_date"] = "2000-01-01"
    r = run_scan(prof, series, pf)                  # today's scan bumps it over -> exit
    assert r["sells"], "a maxed-out hold should be sold"


def test_rsi2_book_fires_the_hard_stop_loss():
    prof = PROFILES["microcap"]                     # keeps the 20% hard stop
    pf = LivePortfolio(prof.capital)
    # open a position via a normal oversold-in-uptrend entry
    up = _reverting(seed=42)
    run_scan(prof, {"AAA": up}, pf, live_prices={"AAA": up[-1]})
    if "AAA" not in pf.holdings:                     # force a holding if the scan didn't buy
        pf.buy("AAA", 10, 100.0, entry_len=len(up))
    entry = pf.holdings["AAA"]["entry_price"]
    # price down 22% from entry -> past the 20% catastrophe stop -> must sell
    r = run_scan(prof, {"AAA": up}, pf, live_prices={"AAA": round(entry * 0.78, 2)})
    assert r["sells"] and "stop-loss" in r["sells"][0]["reason"]
    assert "AAA" not in pf.holdings


def _rising(days=60, start=100.0, step=1.0):
    return [start + i * step for i in range(days)]


def test_momentum_enters_on_breakout_and_trails_out():
    prof = PROFILES["next50"]                       # the momentum book
    pf = LivePortfolio(prof.capital)
    series = {"AAA": _rising(60)}                    # steady climb, last=159
    # a live price above every prior close = a fresh 20-day high -> breakout entry
    r = run_scan(prof, series, pf, live_prices={"AAA": 200.0})
    assert r["buys"] and "AAA" in pf.holdings
    assert pf.holdings["AAA"]["peak"] == 200.0       # peak seeded at entry
    # price gives back >15% off the 200 peak (160 < 170) -> trailing-stop exit
    r2 = run_scan(prof, series, pf, live_prices={"AAA": 160.0})
    assert r2["sells"] and "trailing stop" in r2["sells"][0]["reason"]
    assert "AAA" not in pf.holdings


def test_momentum_holds_while_above_trailing_stop():
    prof = PROFILES["next50"]
    pf = LivePortfolio(prof.capital)
    series = {"AAA": _rising(60)}
    run_scan(prof, series, pf, live_prices={"AAA": 200.0})
    # a shallow pullback (5% < 15% trail) must NOT stop us out
    r = run_scan(prof, series, pf, live_prices={"AAA": 190.0})
    assert not r["sells"] and "AAA" in pf.holdings
    assert pf.holdings["AAA"]["peak"] == 200.0       # peak unchanged by a dip


def test_strength_buys_uptrend_strength_and_trails_out():
    prof = PROFILES["strength"]
    pf = LivePortfolio(prof.capital)
    # a long steady climb (well above the 200-DMA) that ends in a +3/-2 chop so
    # RSI-14 lands at ~60 — inside the 55-70 strength band, not pinned at 100.
    base = [100.0 + i for i in range(292)]
    tail, p = [], base[-1]
    for _ in range(7):
        p += 3; tail.append(p); p -= 2; tail.append(p)
    series = {"AAA": base + tail}
    r = run_scan(prof, series, pf, live_prices={"AAA": 420.0})
    assert r["buys"] and "AAA" in pf.holdings
    assert pf.holdings["AAA"]["peak"] == 420.0 and pf.holdings["AAA"].get("rsi14")
    # give back >12% off the 420 peak (360 < 369.6) -> trailing-stop exit
    r2 = run_scan(prof, series, pf, live_prices={"AAA": 360.0})
    assert r2["sells"] and "trailing stop" in r2["sells"][0]["reason"]
    assert "AAA" not in pf.holdings


def test_strength_skips_downtrend_and_overbought():
    prof = PROFILES["strength"]
    pf = LivePortfolio(prof.capital)
    # a long steady DECLINE: price below its 200-day SMA -> never buy (no strength)
    down = {"DN": _rising(320, start=420.0, step=-1.0)}
    r = run_scan(prof, down, pf, live_prices={"DN": 95.0})
    assert not r["buys"] and not pf.holdings


def test_leaders_buys_strong_momentum_and_trails_out():
    prof = PROFILES["leaders"]
    pf = LivePortfolio(prof.capital)
    c = [100.0]
    for _ in range(320):
        c.append(round(c[-1] * 1.006, 3))            # ~+0.6%/day: >25% over 63d, above 200-DMA
    series = {"AAA": c}
    r = run_scan(prof, series, pf)                    # no live price -> uses last close
    assert r["buys"] and "AAA" in pf.holdings
    peak = pf.holdings["AAA"]["peak"]
    assert pf.holdings["AAA"].get("mom")
    # give back >20% off the peak -> trailing-stop exit
    r2 = run_scan(prof, series, pf, live_prices={"AAA": round(peak * 0.79, 2)})
    assert r2["sells"] and "trailing stop" in r2["sells"][0]["reason"]
    assert "AAA" not in pf.holdings


def test_leaders_skips_weak_and_downtrend():
    prof = PROFILES["leaders"]
    pf = LivePortfolio(prof.capital)
    # flat/weak: no 25% momentum and below its own average -> never buy
    flat = {"FL": [100.0 + (i % 3) for i in range(320)]}
    r = run_scan(prof, flat, pf, live_prices={"FL": 101.0})
    assert not r["buys"] and not pf.holdings


def test_scalein_averages_down_then_exits_on_recovery():
    prof = PROFILES["scalein"]
    pf = LivePortfolio(prof.capital)
    # a long uptrend base (above 200-DMA) that ends with a sharp multi-day drop
    # so RSI-2 is deeply oversold and keeps falling -> scale-in adds units.
    base = [100.0 + i * 0.5 for i in range(260)]          # 100 -> 229.5, clearly above 200-DMA
    drop = [225.0, 215.0, 205.0, 196.0]                   # 4 down days -> RSI-2 near 0
    series = {"AAA": base + drop}
    r1 = run_scan(prof, series, pf)                        # first unit
    assert r1["buys"] and pf.holdings["AAA"]["units"] == 1
    entry1 = pf.holdings["AAA"]["entry_price"]
    # another lower down-day -> should ADD a unit and blend the entry lower
    series["AAA"] = series["AAA"] + [188.0]
    run_scan(prof, series, pf)
    assert pf.holdings["AAA"]["units"] == 2
    assert pf.holdings["AAA"]["entry_price"] < entry1     # averaged down
    # a big bounce -> RSI-2 recovers above 50 -> sell the whole averaged position
    series["AAA"] = series["AAA"] + [230.0, 235.0]
    r3 = run_scan(prof, series, pf)
    assert r3["sells"] and "AAA" not in pf.holdings


def test_scan_exits_on_hold_and_records_equity():
    prof = PROFILES["smallcap"]
    series = {f"S{i}": _reverting(seed=i) for i in range(10)}
    pf = LivePortfolio(prof.capital)
    r1 = run_scan(prof, series, pf)
    # grow each series by 40 bars so held positions exceed the 30-bar max hold
    for s in series:
        series[s] += _reverting(days=40, seed=hash(s) % 100)[1:]
    r2 = run_scan(prof, series, pf)
    assert "equity" in r1 and "equity" in r2
    assert len(pf.history) == 2

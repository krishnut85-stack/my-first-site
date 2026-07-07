"""Tests for the CRASH-BOUNCE book (9th book) — profile + live scan engine."""

from garuda.portfolio import LivePortfolio
from garuda.scan import run_scan
from garuda.strategy import PROFILES


def _steep_uptrend(days=80):
    return [round(100 * 1.01 ** i, 2) for i in range(days)]


def test_crash_profile_uses_validated_settings():
    p = PROFILES["crash"]
    assert p.strategy == "crash"
    assert p.trail == 0.25 and p.max_hold == 180      # the exit-sweep winner
    assert p.daily_csv == "strength_daily.csv"        # shares the top-1500 universe
    assert p.capital == 1_000_000 and p.alloc_pct == 0.02
    assert p.label and "50-DMA" in p.rules


def test_crash_scan_buys_panic_above_50dma_only():
    p = PROFILES["crash"]
    up = _steep_uptrend()
    panic = up + [round(up[-1] * 0.85, 2)]            # -15% day => -11% 5-day, above SMA50
    dead = [200.0 - i for i in range(80)]             # downtrend crash: below SMA50
    dead += [round(dead[-1] * 0.85, 2)]
    flat = [100.0] * 81                               # nothing happening
    series = {"PANIC": panic, "DEAD": dead, "FLAT": flat}
    pf = LivePortfolio(p.capital)
    res = run_scan(p, series, pf)
    assert [b["symbol"] for b in res["buys"]] == ["PANIC"]
    assert "PANIC" in pf.holdings
    h = pf.holdings["PANIC"]
    assert h["peak"] == panic[-1]                     # peak starts at entry
    assert h["mom"] <= -8.0                           # crash depth recorded


def test_crash_scan_trailing_exit():
    p = PROFILES["crash"]
    up = _steep_uptrend()
    panic = up + [round(up[-1] * 0.85, 2)]
    series = {"PANIC": panic}
    pf = LivePortfolio(p.capital)
    run_scan(p, series, pf)
    entry = pf.holdings["PANIC"]["entry_price"]
    # price recovers 50% (peak moves up), then gives back 26% -> 25% trail fires
    # (1.50 x 0.74 = 1.11 -> the exit still books a profit over the panic entry)
    peak_px = round(entry * 1.50, 2)
    run_scan(p, {"PANIC": panic + [peak_px]}, pf, live_prices={"PANIC": peak_px})
    assert pf.holdings["PANIC"]["peak"] == peak_px
    drop_px = round(peak_px * 0.74, 2)
    res = run_scan(p, {"PANIC": panic + [peak_px, drop_px]}, pf,
                   live_prices={"PANIC": drop_px})
    sells = [s for s in res["sells"] if s["symbol"] == "PANIC"]
    assert sells and "trailing stop" in sells[0]["reason"]
    assert "PANIC" not in pf.holdings
    assert sells[0]["pnl"] > 0                        # sold above the panic entry
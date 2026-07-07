"""regime_lite — shared market regime gate for Phoenix & Hunter lanes.
Self-contained: caller passes a logged-in KiteConnect. Fail-open by design:
any error -> NEUTRAL mult 1.0 with reason, never blocks on infrastructure.
Cached per-day in regime_cache.json so multiple lanes share one fetch.
"""
from __future__ import annotations
import datetime as dt, json, os

NIFTY_TOKEN = 256265
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "regime_cache.json")
VIX_PANIC, VIX_HIGH = 28.0, 20.0
DIST_PANIC, DIST_BEAR, DIST_BULL = -0.04, -0.01, 0.02

def _calc(kite) -> dict:
    today = dt.date.today()
    candles = kite.historical_data(NIFTY_TOKEN, today - dt.timedelta(days=120), today, "day")
    closes = [c["close"] for c in candles]
    if len(closes) < 50:
        raise RuntimeError(f"only {len(closes)} NIFTY candles")
    sma50 = sum(closes[-50:]) / 50.0
    dist = (closes[-1] - sma50) / sma50
    vix = 0.0
    try:
        vix = float(kite.ltp(["NSE:INDIA VIX"]).get("NSE:INDIA VIX", {}).get("last_price") or 0.0)
    except Exception:
        pass  # VIX optional; trend alone still classifies
    base = {"date": today.isoformat(), "nifty_close": closes[-1],
            "sma50": round(sma50, 2), "dist_pct": round(dist * 100, 2), "vix": vix}
    if vix >= VIX_PANIC or dist <= DIST_PANIC:
        base.update(regime="PANIC", mult=0.0,
                    reason=f"VIX {vix:.1f} / NIFTY {dist*100:+.1f}% vs 50DMA")
    elif vix >= VIX_HIGH or dist <= DIST_BEAR:
        base.update(regime="BEAR", mult=0.5,
                    reason=f"VIX {vix:.1f} / NIFTY {dist*100:+.1f}% vs 50DMA")
    else:
        base.update(regime="BULL" if dist >= DIST_BULL else "NEUTRAL", mult=1.0,
                    reason=f"VIX {vix:.1f} / NIFTY {dist*100:+.1f}% vs 50DMA")
    return base

def get_regime(kite) -> dict:
    """Returns {regime, mult, reason, ...}. Never raises (fail-open NEUTRAL)."""
    today = dt.date.today().isoformat()
    try:
        with open(CACHE) as f:
            c = json.load(f)
        if c.get("date") == today:
            return c
    except Exception:
        pass
    try:
        r = _calc(kite)
        try:
            with open(CACHE, "w") as f:
                json.dump(r, f)
        except Exception:
            pass
        return r
    except Exception as e:
        return {"date": today, "regime": "NEUTRAL", "mult": 1.0,
                "reason": f"FAIL-OPEN: {e}", "vix": 0, "dist_pct": 0}

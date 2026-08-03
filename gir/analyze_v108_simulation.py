#!/usr/bin/env python3
"""analyze_v108_simulation.py — V108_DAY_TREND_GATE pre-deploy validation"""
import os, sys, json, time
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict

TRADES_FILE = Path("/home/globalbot/data/equity_trades.json")
CACHE_FILE = Path("/home/globalbot/.v108_dayhist_cache.json")

SCENARIOS = [
    {"name": "STRICT",   "pct_threshold": -0.3, "score_required": 85},
    {"name": "BALANCED", "pct_threshold": -0.5, "score_required": 80},
    {"name": "LOOSE",    "pct_threshold": -1.0, "score_required": 75},
]


def load_trades(days=None):
    if not TRADES_FILE.exists():
        print(f"❌ No trades file at {TRADES_FILE}"); sys.exit(1)
    data = json.loads(TRADES_FILE.read_text())
    trades = data.get("trades", [])
    if days:
        cutoff = datetime.now() - timedelta(days=days)
        trades = [t for t in trades if _parse_dt(t.get("entry_time")) > cutoff]
    return trades


def _parse_dt(s):
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00").split("+")[0])
    except Exception:
        return datetime(2000, 1, 1)


def load_cache():
    try:
        if CACHE_FILE.exists():
            return json.loads(CACHE_FILE.read_text())
    except Exception:
        pass
    return {}


def save_cache(c):
    try:
        CACHE_FILE.write_text(json.dumps(c, indent=2))
    except Exception:
        pass


def _to_minutes(hhmm):
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def get_day_pct_at_entry(kite, sym, entry_time_str, inst_token_cache, hist_cache):
    """Return (stock_pct_at_entry, prev_close, entry_ltp) for the given trade."""
    if not entry_time_str:
        return None, None, None
    try:
        entry_dt = datetime.fromisoformat(entry_time_str.split("+")[0])
    except Exception:
        return None, None, None

    cache_key = f"{sym}:{entry_dt.date()}"
    if cache_key in hist_cache:
        rec = hist_cache[cache_key]
        prev_close = rec.get("prev_close")
        target_minute = entry_dt.strftime("%H:%M")
        candle = rec.get("candles", {}).get(target_minute)
        if candle and prev_close:
            ltp = candle["close"]
            pct = (ltp - prev_close) / prev_close * 100
            return pct, prev_close, ltp
        return None, prev_close, None

    token = inst_token_cache.get(sym)
    if not token:
        try:
            instruments = kite.instruments("NSE")
            for i in instruments:
                if i.get("tradingsymbol") == sym and i.get("instrument_type") == "EQ":
                    token = i["instrument_token"]
                    inst_token_cache[sym] = token
                    break
        except Exception as e:
            print(f"  ! inst lookup {sym}: {e}")
            return None, None, None
    if not token:
        return None, None, None

    from_dt = datetime.combine(entry_dt.date(), datetime.min.time().replace(hour=9, minute=15))
    to_dt = datetime.combine(entry_dt.date(), datetime.min.time().replace(hour=15, minute=30))
    prev_dt_start = entry_dt - timedelta(days=5)
    prev_dt_end = entry_dt - timedelta(days=0, hours=18)

    try:
        candles = kite.historical_data(token, from_dt, to_dt, "minute")
        time.sleep(0.4)
        prev_day_candles = kite.historical_data(token, prev_dt_start, prev_dt_end, "day")
        time.sleep(0.4)
    except Exception as e:
        print(f"  ! historical {sym}: {e}")
        return None, None, None

    if not candles or not prev_day_candles:
        return None, None, None

    prev_close = None
    for c in reversed(prev_day_candles):
        c_date = c["date"]
        if hasattr(c_date, "date"):
            c_date = c_date.date()
        if c_date < entry_dt.date():
            prev_close = c["close"]
            break

    if not prev_close:
        return None, None, None

    minute_map = {}
    for c in candles:
        c_dt = c["date"]
        if hasattr(c_dt, "strftime"):
            key = c_dt.strftime("%H:%M")
            minute_map[key] = {"close": c["close"], "high": c["high"], "low": c["low"]}

    hist_cache[cache_key] = {"prev_close": prev_close, "candles": minute_map}

    target_minute = entry_dt.strftime("%H:%M")
    candle = minute_map.get(target_minute)
    if not candle:
        all_minutes = sorted(minute_map.keys())
        nearest = min(all_minutes, key=lambda m: abs(_to_minutes(m) - _to_minutes(target_minute))) if all_minutes else None
        if nearest:
            candle = minute_map[nearest]
    if not candle:
        return None, prev_close, None

    ltp = candle["close"]
    pct = (ltp - prev_close) / prev_close * 100
    return pct, prev_close, ltp


def main():
    days = None
    args = sys.argv[1:]
    while args:
        if args[0] == "--days" and len(args) > 1:
            days = int(args[1])
            args = args[2:]
        else:
            args = args[1:]

    trades = load_trades(days)
    if not trades:
        print("No trades found"); return
    print(f"Loaded {len(trades)} trades" + (f" (last {days} days)" if days else ""))
    print()

    sys.path.insert(0, "/home/globalbot")
    os.chdir("/home/globalbot")
    try:
        from dotenv import load_dotenv
        load_dotenv()
    except Exception:
        pass

    from kiteconnect import KiteConnect
    api_key = os.getenv("KITE_API_KEY")
    if not api_key:
        print("❌ KITE_API_KEY not in env"); sys.exit(1)

    kite = KiteConnect(api_key=api_key)
    token_file = Path("/home/globalbot/data/kite_token.json")
    if token_file.exists():
        try:
            td = json.loads(token_file.read_text())
            tok = td.get("access_token", "")
            if not tok:
                print("❌ Token file has no access_token field"); sys.exit(1)
            kite.set_access_token(tok)
            kite.profile()
            print("✓ Using cached Kite session")
        except Exception as e:
            print(f"❌ Cached token invalid: {e}")
            print("   Run during market hours when bot has fresh token.")
            sys.exit(1)
    else:
        print(f"❌ No cached Kite token at {token_file}"); sys.exit(1)

    hist_cache = load_cache()
    inst_token_cache = {}
    enriched = []
    print("Fetching historical data for each trade entry...")
    for i, t in enumerate(trades, 1):
        sym = t["symbol"]
        et = t.get("entry_time", "")
        if (i % 10) == 0:
            print(f"  {i}/{len(trades)}...")
        pct, prev_close, ltp = get_day_pct_at_entry(kite, sym, et, inst_token_cache, hist_cache)
        enriched.append({**t, "stock_pct_at_entry": pct, "prev_close": prev_close, "entry_ltp_chk": ltp})
    save_cache(hist_cache)

    def proxy_score(t):
        src = (t.get("source") or "").upper()
        hi = ("BUYBACK", "EARNINGS_BEAT", "BLOCK_DEAL", "ACQUISITION")
        if any(k in src for k in hi):
            return 85
        return 70

    print()
    print("=" * 90)
    print("V108_DAY_TREND_GATE SIMULATION")
    print("=" * 90)
    print()
    total = len(enriched)
    no_data = sum(1 for t in enriched if t["stock_pct_at_entry"] is None)
    print(f"Total trades:              {total}")
    print(f"Could not reconstruct:     {no_data}  (missing historical data)")
    print(f"Usable for simulation:     {total - no_data}")
    print()
    sl_losses = [t for t in enriched if "SL" in (t.get("reason", "") or "") and (t.get("pnl", 0) or 0) < 0]
    print(f"SL-hit losing trades:      {len(sl_losses)}")
    print(f"Total SL loss:             Rs.{sum(t.get('pnl', 0) for t in sl_losses):+.2f}")
    print()
    print(f"{'Scenario':<10} {'pct<':>7} {'score>=':>8} {'Blocked':>9} {'SL_Avoid':>10} "
          f"{'Win_Miss':>10} {'Rs_Saved':>12} {'Rs_Missed':>12} {'Net_D':>12}")
    print("-" * 95)

    for sc in SCENARIOS:
        pct_thr = sc["pct_threshold"]
        score_req = sc["score_required"]
        blocked = []
        for t in enriched:
            pct = t.get("stock_pct_at_entry")
            if pct is None:
                continue
            score = proxy_score(t)
            if pct < pct_thr and score < score_req:
                blocked.append(t)
        if not blocked:
            print(f"{sc['name']:<10} {pct_thr:>+6.1f}% {score_req:>8} {0:>9} {0:>10} {0:>10} {0:>12} {0:>12} {0:>12}")
            continue
        sl_avoided = [t for t in blocked if (t.get("pnl", 0) or 0) < 0]
        winners_missed = [t for t in blocked if (t.get("pnl", 0) or 0) > 0]
        money_saved = -sum(t.get("pnl", 0) for t in sl_avoided)
        money_missed = sum(t.get("pnl", 0) for t in winners_missed)
        net = money_saved - money_missed
        print(f"{sc['name']:<10} {pct_thr:>+6.1f}% {score_req:>8} {len(blocked):>9} "
              f"{len(sl_avoided):>10} {len(winners_missed):>10} "
              f"Rs.{money_saved:>9.0f} Rs.{money_missed:>9.0f} Rs.{net:>+9.0f}")

    print()
    print("=" * 90)
    print("INTERPRETATION")
    print("=" * 90)
    print("  Blocked  = trades V108 would have prevented entering")
    print("  SL_Avoid = of those, how many were actual losses")
    print("  Win_Miss = of those, how many would have been winners")
    print("  Rs_Saved = total absolute losses prevented")
    print("  Rs_Missed = total wins forfeited")
    print("  Net_D    = Rs_Saved - Rs_Missed (positive = V108 net positive)")
    print()
    print("NOTE: Uses proxy score (70 default, 85 for high-conviction catalysts)")
    print("because real entry scores aren't in trade log.")


if __name__ == "__main__":
    main()

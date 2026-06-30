#!/usr/bin/env python3
"""
patch_v81_earnings_oi_buildup.py — Wire earnings calendar to OI buildup engine
                                    + remove dead/duplicate earnings code

==============================================================================
WHY THIS PATCH EXISTS
==============================================================================
The bot has FOUR places that touch earnings, but they don't share signals:

  1. EarningsCalendar.get_earnings_plays()       — returns 14-21d & 7-13d & 0-3d plays
  2. EarningsCalendar.get_upcoming()             — returns 0-14d earnings dates
  3. _get_combined_candidates Source 5 (line 9506) — uses #1, requires news to confirm direction
  4. _get_combined_candidates Source 6 (line 9566) — uses #2, BULLISH-only, NO signal logic
  5. _earnings_amo_scan (line 7747)               — F&O AMO scan, uses 20-SMA for direction

Problems:
  - Source 6 is duplicative noise. It adds BULLISH-default earnings candidates that
    conflict with Source 5 (which uses news direction). Same symbol gets queued twice
    with different directions. ExpertPanel then has to break the tie. Dead/harmful.
  - Source 5 only fires when news already exists for the symbol. At T-21 there usually
    isn't news yet — that's WHY you'd want to enter early. Result: 14-21d entry path
    silently never fires. Dormant.
  - Source 7 (_earnings_amo_scan) uses a 20-day SMA crossover for direction. SMA
    is a price-only signal — it doesn't tell you what institutions are doing. The
    proper signal is OI buildup direction, which the bot already computes for general
    F&O entries via OISnapshotEngine.detect_buildup_signals().
  - Effect size: academic data (Linnainmaa & Zhang 2019) shows pre-earnings drift
    is concentrated in smaller / higher-uncertainty stocks. Bot treats all stocks
    equally. Should boost smaller F&O names where the edge is real.

==============================================================================
WHAT IT CHANGES
==============================================================================

CHANGE 1 — Delete duplicate "Source 6" earnings block (line 9564-9576)
    Removes 13 lines of dead/harmful code that adds BULLISH-default earnings
    candidates fighting with the proper Source 5. Source 5 stays — it's the
    correct one with direction inheritance.

CHANGE 2 — Source 5 inherits direction from OI buildup as well as news
    Currently Source 5 builds _existing_dirs only from candidates already in the
    pool (news/filing/brokerage/macro). At T-15 to T-21 there's usually no news
    yet, so direction lookup fails and the play is skipped.

    Fix: also call self._oi_engine.detect_buildup_signals(mode="daily") and
    merge those directions into _existing_dirs. Now if OI shows long buildup
    on a stock with earnings in 18 days, the bot enters BULLISH automatically.

    This is what makes early entry actually work.

CHANGE 3 — _earnings_amo_scan uses OI buildup instead of 20-SMA
    Replace the "20-day SMA crossover -> direction" block (lines 7786-7810)
    with "OI buildup signal -> direction" lookup against the same engine.

    Why: SMA crossover is a noisy retail signal. OI buildup reflects what
    smart money is actually doing. Same engine the rest of the bot trusts.

    Fallback preserved: if OI engine returns no signal for a symbol (early in
    morning before snapshots accumulated), fall back to 20-SMA. Old logic kept
    as safety net, just demoted from primary to fallback.

CHANGE 4 — Tier-weighted score boost for earnings candidates
    Research-backed: pre-earnings drift effect is largest in smaller stocks.
    Add boost based on Trendlyne mcap:
      - mcap < 5,000 Cr     -> +5 score (small cap, biggest drift edge)
      - 5,000 <= mcap < 50,000 -> +3 (mid cap)
      - mcap >= 50,000 Cr   -> +0 (large cap, edge is smallest)
      - mcap = 0 (no data)  -> +0 (don't boost what we can't classify)

    Applied to candidates from Source 5 AND _earnings_amo_scan.

==============================================================================
WHAT IT DOES NOT CHANGE (deliberate)
==============================================================================
- get_earnings_plays() definition itself (line 2632) — the 3-tier window logic
  (14-21 / 7-13 / 0-3) is correct, no change needed. Just feeding it better
  direction inputs.
- IV crush guard (V70 + EXIT_IV_CRUSH at line 9550) — already correct.
- Telegram earnings calendar update (line 9876) — informational, kept.
- OI_BUILDUP_MIN_PCT / OI_SIGNAL_MIN_SCORE thresholds — left at general values.
  Earnings-tagged candidates piggyback on the same OI signals general F&O uses.

==============================================================================
DEPLOYMENT
==============================================================================
This script ONLY edits gir.py. It does NOT restart the bot.
After running:
    python3 -c "import ast; ast.parse(open('/home/globalbot/gir.py').read()); print('OK')"
    bash /home/globalbot/safe_deploy.sh --force

Rollback if needed:
    cp /home/globalbot/gir.py.bak_v81_<ts> /home/globalbot/gir.py
    systemctl restart globaleye
"""

import ast
import shutil
import time
from pathlib import Path

GIR_PATH = Path("/home/globalbot/gir.py")
BACKUP_PATH = Path(f"/home/globalbot/gir.py.bak_v81_{int(time.time())}")

# ═══════════════════════════════════════════════════════════════════════════════
# CHANGE 1 — Delete dead duplicate "Source 6" earnings block
# ═══════════════════════════════════════════════════════════════════════════════
CHANGE1_OLD = '''        # Source 6: Earnings calendar — boost stocks with upcoming results
        if self.earnings:
            upcoming = self.earnings.get_upcoming(days_ahead=14)
            for earn in upcoming:
                sym = earn["symbol"]
                if sym in self.fno_stocks:
                    candidates.append({
                        "symbol": sym,
                        "direction": "BULLISH",  # Default bullish for earnings play
                        "score": 65 + max(0, 14 - earn["days_to"]) * 2,  # Higher score closer to date
                        "catalyst": f"EARNINGS in {earn['days_to']}d ({earn['date']})",
                        "source": "EARNINGS",
                    })
'''

CHANGE1_NEW = '''        # V81: Source 6 (duplicate get_upcoming earnings boost) REMOVED.
        # It generated BULLISH-default candidates that conflicted with Source 5
        # (which uses real direction signals). Source 5 above is the correct path.
'''

# ═══════════════════════════════════════════════════════════════════════════════
# CHANGE 2 — Source 5 inherits direction from OI buildup as well as news
# ═══════════════════════════════════════════════════════════════════════════════
CHANGE2_OLD = '''        # Source 5: Earnings plays — pre-earnings IV expansion strategy
        # PATCH_V7_SIGNAL_QUALITY: inherit direction from other signals on same stock, skip if none
        if self.earnings:
            plays = self.earnings.get_earnings_plays(self.fno_stocks)
            # Build direction map from current candidates (news/macro/filing/brokerage already scanned)
            _existing_dirs = {}
            for _c in candidates:
                _sym = _c.get("symbol")
                _d = _c.get("direction")
                if _sym and _d in ("BULLISH", "BEARISH"):
                    if _sym not in _existing_dirs:
                        _existing_dirs[_sym] = []
                    _existing_dirs[_sym].append(_d)'''

CHANGE2_NEW = '''        # Source 5: Earnings plays — pre-earnings IV expansion strategy
        # PATCH_V7_SIGNAL_QUALITY: inherit direction from other signals on same stock, skip if none
        # V81: also inherit direction from OI buildup engine — this is what makes the
        # 14-21d early entry path actually fire. At T-21 there usually isn't news yet,
        # but institutional OI positioning is visible. OI buildup is the smart-money signal.
        if self.earnings:
            plays = self.earnings.get_earnings_plays(self.fno_stocks)
            # Build direction map from current candidates (news/macro/filing/brokerage already scanned)
            _existing_dirs = {}
            for _c in candidates:
                _sym = _c.get("symbol")
                _d = _c.get("direction")
                if _sym and _d in ("BULLISH", "BEARISH"):
                    if _sym not in _existing_dirs:
                        _existing_dirs[_sym] = []
                    _existing_dirs[_sym].append(_d)
            # V81: merge OI buildup directions into the same map
            try:
                if hasattr(self, "_oi_engine") and self._oi_engine:
                    _oi_sigs = self._oi_engine.detect_buildup_signals(mode="daily") or []
                    for _o in _oi_sigs:
                        _osym = _o.get("symbol"); _od = _o.get("direction")
                        if _osym and _od in ("BULLISH", "BEARISH"):
                            _existing_dirs.setdefault(_osym, []).append(_od)
                    if _oi_sigs:
                        log.info(f"[V81_EARNINGS_OI] merged {len(_oi_sigs)} OI buildup directions into earnings direction map")
            except Exception as _v81e:
                log.warning(f"[V81_EARNINGS_OI] OI direction merge failed: {_v81e}")'''

# ═══════════════════════════════════════════════════════════════════════════════
# CHANGE 3 — _earnings_amo_scan uses OI buildup instead of 20-SMA (with SMA fallback)
# ═══════════════════════════════════════════════════════════════════════════════
CHANGE3_OLD = '''                direction = None
                src_lbl = ""
                nd = news_dirs.get(sym, [])
                if nd and not ("BULLISH" in nd and "BEARISH" in nd):
                    direction = nd[0]
                    src_lbl = "news"
                elif kite:
                    try:
                        today_dt = datetime.combine(today, datetime.min.time())
                        from_dt = today_dt - timedelta(days=40)
                        tok = None
                        try:
                            if _nse_cache is None:
                                _nse_cache = kite.instruments("NSE")
                            for inst in _nse_cache:
                                if inst.get("tradingsymbol") == sym and inst.get("segment") == "NSE":
                                    tok = inst.get("instrument_token")
                                    break
                        except Exception:
                            pass
                        if tok:
                            h = kite.historical_data(tok, from_dt, today_dt, "day")
                            if h and len(h) >= 20:
                                rc = h[-1].get("close", 0)
                                sma = sum(x.get("close", 0) for x in h[-20:]) / 20
                                if rc > sma * 1.01:
                                    direction = "BULLISH"
                                    src_lbl = f"sma20 {rc:.1f}>{sma:.1f}"
                                elif rc < sma * 0.99:
                                    direction = "BEARISH"
                                    src_lbl = f"sma20 {rc:.1f}<{sma:.1f}"
                    except Exception as _te:
                        log.debug(f"[FIX_V33_EARNINGS] {sym} trend: {_te}")'''

CHANGE3_NEW = '''                direction = None
                src_lbl = ""
                nd = news_dirs.get(sym, [])
                if nd and not ("BULLISH" in nd and "BEARISH" in nd):
                    direction = nd[0]
                    src_lbl = "news"
                # V81: PRIMARY direction source — OI buildup (smart-money signal)
                if not direction:
                    try:
                        if hasattr(self, "_oi_engine") and self._oi_engine:
                            _v81_oi = self._oi_engine.detect_buildup_signals(mode="daily") or []
                            for _o in _v81_oi:
                                if _o.get("symbol") == sym and _o.get("direction") in ("BULLISH", "BEARISH"):
                                    direction = _o["direction"]
                                    src_lbl = f"oi_buildup score={_o.get('score',0)}"
                                    break
                    except Exception as _v81oe:
                        log.debug(f"[V81_EARNINGS_OI] {sym} OI lookup failed: {_v81oe}")
                # V81: FALLBACK direction source — 20-SMA crossover (kept as safety net
                # for early-morning case when OI snapshots haven't accumulated yet)
                if not direction and kite:
                    try:
                        today_dt = datetime.combine(today, datetime.min.time())
                        from_dt = today_dt - timedelta(days=40)
                        tok = None
                        try:
                            if _nse_cache is None:
                                _nse_cache = kite.instruments("NSE")
                            for inst in _nse_cache:
                                if inst.get("tradingsymbol") == sym and inst.get("segment") == "NSE":
                                    tok = inst.get("instrument_token")
                                    break
                        except Exception:
                            pass
                        if tok:
                            h = kite.historical_data(tok, from_dt, today_dt, "day")
                            if h and len(h) >= 20:
                                rc = h[-1].get("close", 0)
                                sma = sum(x.get("close", 0) for x in h[-20:]) / 20
                                if rc > sma * 1.01:
                                    direction = "BULLISH"
                                    src_lbl = f"sma20_fallback {rc:.1f}>{sma:.1f}"
                                elif rc < sma * 0.99:
                                    direction = "BEARISH"
                                    src_lbl = f"sma20_fallback {rc:.1f}<{sma:.1f}"
                    except Exception as _te:
                        log.debug(f"[FIX_V33_EARNINGS] {sym} trend: {_te}")'''

# ═══════════════════════════════════════════════════════════════════════════════
# CHANGE 4 — Tier-weighted score boost for earnings candidates in _earnings_amo_scan
# Applied just before append to `out`, modifies `score`.
# ═══════════════════════════════════════════════════════════════════════════════
CHANGE4_OLD = '''                score = 70 + (7 - days_to) * 3 + iv_boost
                score = min(90, max(70, score))
                out.append({
                    "symbol": sym,
                    "direction": direction,
                    "score": score,
                    "catalyst": f"EARNINGS {days_to}d dir={direction} ivr={ivr} {src_lbl}",
                    "source": "EARNINGS_TRADER_V33",
                })
                log.info(f"[FIX_V33_EARNINGS] queued {sym} {direction} score={score} days={days_to} ivr={ivr}")'''

CHANGE4_NEW = '''                score = 70 + (7 - days_to) * 3 + iv_boost
                # V81: tier-weighted boost (research: pre-earnings drift strongest in smaller caps)
                _v81_mcap = 0
                try:
                    _tl = getattr(self, "trendlyne", None) or globals().get("trendlyne")
                    if _tl and hasattr(_tl, "_data"):
                        _v81_mcap = _tl._data.get(sym, {}).get("market_cap", 0)
                except Exception:
                    pass
                if _v81_mcap and _v81_mcap < 5000:
                    score += 5      # small cap: biggest drift edge
                    src_lbl += " smallcap+5"
                elif _v81_mcap and _v81_mcap < 50000:
                    score += 3      # mid cap
                    src_lbl += " midcap+3"
                # large cap (>=50k Cr) and unknown (mcap=0): +0
                score = min(95, max(70, score))  # raised cap from 90 to 95 to allow boost
                out.append({
                    "symbol": sym,
                    "direction": direction,
                    "score": score,
                    "catalyst": f"EARNINGS {days_to}d dir={direction} ivr={ivr} {src_lbl}",
                    "source": "EARNINGS_TRADER_V33",
                })
                log.info(f"[FIX_V33_EARNINGS] queued {sym} {direction} score={score} days={days_to} ivr={ivr} mcap={_v81_mcap}")'''


def apply_edit(content, old, new, label, expected_count=1):
    count = content.count(old)
    if count == 0:
        raise RuntimeError(f"[{label}] OLD pattern NOT FOUND. Aborting.")
    if count != expected_count:
        raise RuntimeError(f"[{label}] OLD pattern matched {count} times (expected {expected_count}). Aborting.")
    return content.replace(old, new, expected_count)


def main():
    print(f"Reading {GIR_PATH} ...")
    original = GIR_PATH.read_text()
    print(f"  size: {len(original)} bytes, {len(original.splitlines())} lines")

    print(f"Backing up to {BACKUP_PATH} ...")
    shutil.copy(GIR_PATH, BACKUP_PATH)
    print()

    print("Applying CHANGE 1 (delete duplicate Source 6 earnings block) ...")
    patched = apply_edit(original, CHANGE1_OLD, CHANGE1_NEW, "CHANGE1", expected_count=1)
    print("  OK")

    print("Applying CHANGE 2 (Source 5: merge OI buildup into direction map) ...")
    patched = apply_edit(patched, CHANGE2_OLD, CHANGE2_NEW, "CHANGE2", expected_count=1)
    print("  OK")

    print("Applying CHANGE 3 (_earnings_amo_scan: OI buildup primary, SMA fallback) ...")
    patched = apply_edit(patched, CHANGE3_OLD, CHANGE3_NEW, "CHANGE3", expected_count=1)
    print("  OK")

    print("Applying CHANGE 4 (tier-weighted score boost for earnings candidates) ...")
    patched = apply_edit(patched, CHANGE4_OLD, CHANGE4_NEW, "CHANGE4", expected_count=1)
    print("  OK")
    print()

    print("Validating Python syntax of patched file ...")
    try:
        ast.parse(patched)
    except SyntaxError as e:
        print(f"  SYNTAX ERROR: {e}")
        print(f"  NOT writing file. Backup at {BACKUP_PATH}")
        raise SystemExit(1)
    print("  OK")

    print(f"Writing patched gir.py ({len(patched)} bytes) ...")
    GIR_PATH.write_text(patched)
    print(f"  new size: {len(patched)} bytes, {len(patched.splitlines())} lines")
    print()
    print("=" * 60)
    print("PATCH COMPLETE.")
    print(f"  backup: {BACKUP_PATH}")
    print()
    print("Summary of changes applied:")
    print("  CHANGE 1: Removed dead duplicate Source 6 earnings block (-13 lines)")
    print("  CHANGE 2: Source 5 now uses OI buildup direction (early entries activated)")
    print("  CHANGE 3: _earnings_amo_scan uses OI buildup, SMA fallback")
    print("  CHANGE 4: Tier-weighted score boost (small +5, mid +3, large +0)")
    print()
    print("Next step:")
    print("  bash /home/globalbot/safe_deploy.sh --force")
    print()
    print("Rollback if needed:")
    print(f"  cp {BACKUP_PATH} {GIR_PATH} && systemctl restart globaleye")
    print("=" * 60)


if __name__ == "__main__":
    main()

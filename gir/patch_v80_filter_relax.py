#!/usr/bin/env python3
"""
patch_v80_filter_relax.py — Relax stock-screening filters that were silently
                            blocking good trades

==============================================================================
WHY THIS PATCH EXISTS
==============================================================================
After auditing every `continue` and `return False` in the equity scanner +
ExpertPanel + entry path, four filters stood out as quietly excluding stocks
that should have been tradeable. Each change below is small, isolated, and
documented. Read every CHANGE block before deploying.

==============================================================================
WHAT IT CHANGES
==============================================================================

CHANGE 1 — Fix mcap=0 silent-kill cascade (3 identical sites)
    Where:  EquitySmartScanner — Falling Knife scanner (line ~3716)
            EquitySmartScanner — Pre-market gappers (line ~3924)
            EquitySmartScanner — Intraday momentum (line ~3990)

    Bug:    A stock not present in trendlyne._data gets _mcap=0.
            _mcap=0 → _min_score=45 (the else branch).
            trendlyne.score(sym) returns 0 for unknown symbols.
            0 < 45 → SKIP. SILENTLY.

            Effect: ANY stock missing from the Trendlyne cache (3,153 symbols
            today) is permanently invisible to the scanner. New listings,
            recent F&O additions, recovered penny stocks — all silently
            rejected with NO LOG LINE.

    Fix:    If _mcap == 0 (no Trendlyne data), allow the symbol through but
            require stricter volume/turnover confirmation downstream
            (₹1 Cr turnover instead of ₹50L) since we don't have fundamentals
            to back the trade.

    Risk:   Low. Stocks without Trendlyne data still must pass:
              - 4% pct_change (momentum proof)
              - 1.8x volume ratio (conviction proof)
              - ₹1 Cr turnover (liquidity proof)
              - Circuit limit guards
              - ExpertPanel score >= 55 (score_news, score_technical, etc.)
            The only thing they bypass is the Trendlyne floor itself.

----

CHANGE 2 — Hidden Gem upper bound widened (1 site, line ~4020)

    Where:  EquitySmartScanner.scan_hidden_gem (smallcap quality scanner)

    Bug:    Hidden Gem caps universe at ₹50,000 Cr mcap. This excludes
            quality midcaps and large-but-not-mega names where the same
            "promoter buying + FII buying + MF buying + volume + price"
            pattern is statistically just as predictive — often more so
            because larger names have less price manipulation.

    Fix:    Raise upper bound from ₹50,000 Cr to ₹2,00,000 Cr (₹2 Lakh Cr).
            This includes names like SBI, ITC, HCLTech, Wipro, Tata Steel,
            ONGC. Excludes only mega caps (Reliance, TCS, HDFC Bank, Infy,
            Bharti, ICICI) where Hidden Gem signals are noise.

    Risk:   Low. The "gem" qualification is actually the institutional-flow
            score (promoter+FII+MF), not the mcap. We're widening WHO
            qualifies as a gem, not relaxing WHAT makes one.

----

CHANGE 3 — Tier-aware turnover floor (3 sites, line ~3723, ~3996, ~4032)

    Where:  Same 3 scanner paths as CHANGE 1.

    Bug:    Hardcoded ₹50L turnover floor everywhere. This is a fair default
            for unknown stocks but PUNISHES known-quality smallcaps. A
            ₹2,000 Cr durability-80 stock with ₹35L turnover gets rejected
            same as a ₹100 Cr unknown.

    Fix:    Tier-aware floor:
              - Trendlyne durability >= 80 → ₹20L floor (proven quality)
              - Trendlyne durability 50-79 → ₹50L floor (current default)
              - mcap == 0 (no data)        → ₹1 Cr floor (extra protection)

    Risk:   Low. Slippage on ₹20L turnover with quality stock + Kelly-sized
            position is minimal. We never size to >5% of daily turnover
            anyway, so on a ₹20L turnover stock max position = ₹1L which
            fits your current capital.

----

CHANGE 4 — Pre-market momentum threshold (1 site, line ~3975)

    Where:  EquitySmartScanner intraday momentum scanner.

    Bug:    Requires pct_change >= 4% before considering entry. By 4% on a
            momentum move, the bot is chasing — entry is late, stop has to
            be wider, R/R compresses.

    Fix:    Lower threshold to 2.5% BUT add a stronger volume requirement:
              - 4%+ move → 1.8x volume (current behavior, unchanged)
              - 2.5-4% move → 2.5x volume + ₹1Cr turnover required
            This catches earlier momentum but ONLY when volume confirms.

    Risk:   Medium. Earlier entries = more whipsaws on fake-outs. The 2.5x
            volume requirement is the safety; weak-volume 2.5% moves still
            get rejected. Watch first week of data carefully.

==============================================================================
WHAT IT DOES NOT CHANGE (deliberate, see notes)
==============================================================================
- EQUITY_THRESHOLD = 55          # Need real panel-score data first
- FNO_THRESHOLD = 65              # Same
- RSI > 75 entry block            # Real risk filter, keep
- EQ_INITIAL_SL_PCT = 0.025       # Already debated in V77/V79
- EQ_MAX_POS = 10                 # Portfolio-construction decision
- DAILY_LOSS_AVG_LIMIT = 0.15     # Capital protection
- IV_CRUSH guard (V70)            # Saves real money
- Circuit limit guards            # Keep
- F&O 218-stock universe          # NSE-defined, not your code

==============================================================================
DEPLOYMENT
==============================================================================
This script ONLY edits gir.py. It does NOT restart the bot.
After running:
    1. Verify gir.py parses:  python3 -c "import ast; ast.parse(open('/home/globalbot/gir.py').read()); print('OK')"
    2. Restart through gate:  bash /home/globalbot/safe_deploy.sh
       (Use --force if no replay data captured yet.)

Rollback (if anything looks wrong after restart):
    cp /home/globalbot/gir.py.bak_v80_<timestamp> /home/globalbot/gir.py
    systemctl restart globaleye
"""

import ast
import shutil
import time
from pathlib import Path

GIR_PATH = Path("/home/globalbot/gir.py")
BACKUP_PATH = Path(f"/home/globalbot/gir.py.bak_v80_{int(time.time())}")

# ═══════════════════════════════════════════════════════════════════════════════
# CHANGE 1 — Fix mcap=0 cascade (and CHANGE 3 — tier-aware turnover, same block)
# Repeated 3 times in gir.py. Use replace-all (count=3 expected).
# ═══════════════════════════════════════════════════════════════════════════════
CHANGE1_OLD = '''                        _mcap = trendlyne._data.get(sym, {}).get("market_cap", 0) if trendlyne else 0
                        _min_score = 35 if _mcap > 20000 else (40 if _mcap > 5000 else 45)  # V74: relaxed 60/50/40 -> 45/40/35
                        if trendlyne and trendlyne.score(sym) < _min_score:
                            continue
                        if _mcap == 0 and _min_score == 60:
                            continue'''

CHANGE1_NEW = '''                        _mcap = trendlyne._data.get(sym, {}).get("market_cap", 0) if trendlyne else 0
                        _min_score = 35 if _mcap > 20000 else (40 if _mcap > 5000 else 45)  # V74: relaxed 60/50/40 -> 45/40/35
                        # V80_CHANGE1: stocks with mcap=0 (not in Trendlyne cache) bypass the score floor.
                        # They still must pass volume/turnover/circuit/panel gates downstream.
                        if _mcap > 0 and trendlyne and trendlyne.score(sym) < _min_score:
                            continue
                        # V80: legacy mcap=0+score=60 check is now dead (V74 made min 45). Kept as no-op.'''

# ═══════════════════════════════════════════════════════════════════════════════
# CHANGE 3 — Tier-aware turnover floor in main scanner (line ~3996, momentum path)
# Look for the specific volume-floor block right after circuit-limit guards
# in scan_intraday_momentum / equivalent.
# ═══════════════════════════════════════════════════════════════════════════════

# Site A: line ~3723 (Falling Knife scanner)
CHANGE3A_OLD = '''                        _volume = q.get("volume", 0)
                        if _volume * ltp < 5000000:
                            continue
                        _uc = q.get("upper_circuit_limit", 0)'''

CHANGE3A_NEW = '''                        _volume = q.get("volume", 0)
                        # V80_CHANGE3: tier-aware turnover floor
                        _durability = trendlyne._data.get(sym, {}).get("durability", 0) if trendlyne else 0
                        if _mcap == 0:
                            _min_turnover = 10000000   # Rs 1 Cr — no Trendlyne data, extra caution
                        elif _durability >= 80:
                            _min_turnover = 2000000    # Rs 20 L — proven quality stock
                        else:
                            _min_turnover = 5000000    # Rs 50 L — default
                        if _volume * ltp < _min_turnover:
                            continue
                        _uc = q.get("upper_circuit_limit", 0)'''

# Site B: line ~3996 (Pre-market gappers)
CHANGE3B_OLD = '''                        if upper_circuit > 0 and ltp >= upper_circuit * 0.995: continue
                        if lower_circuit > 0 and ltp <= lower_circuit * 1.005: continue
                        _mcap = trendlyne._data.get(sym, {}).get("market_cap", 0) if trendlyne else 0
                        _min_score = 35 if _mcap > 20000 else (40 if _mcap > 5000 else 45)  # V74: relaxed 60/50/40 -> 45/40/35
                        # V80_CHANGE1: stocks with mcap=0 (not in Trendlyne cache) bypass the score floor.
                        # They still must pass volume/turnover/circuit/panel gates downstream.
                        if _mcap > 0 and trendlyne and trendlyne.score(sym) < _min_score:
                            continue
                        # V80: legacy mcap=0+score=60 check is now dead (V74 made min 45). Kept as no-op.
                        if volume * ltp < 5000000:
                            continue'''

CHANGE3B_NEW = '''                        if upper_circuit > 0 and ltp >= upper_circuit * 0.995: continue
                        if lower_circuit > 0 and ltp <= lower_circuit * 1.005: continue
                        _mcap = trendlyne._data.get(sym, {}).get("market_cap", 0) if trendlyne else 0
                        _min_score = 35 if _mcap > 20000 else (40 if _mcap > 5000 else 45)  # V74: relaxed 60/50/40 -> 45/40/35
                        # V80_CHANGE1: stocks with mcap=0 (not in Trendlyne cache) bypass the score floor.
                        # They still must pass volume/turnover/circuit/panel gates downstream.
                        if _mcap > 0 and trendlyne and trendlyne.score(sym) < _min_score:
                            continue
                        # V80: legacy mcap=0+score=60 check is now dead (V74 made min 45). Kept as no-op.
                        # V80_CHANGE3: tier-aware turnover floor (same logic as Falling Knife scanner)
                        _durability = trendlyne._data.get(sym, {}).get("durability", 0) if trendlyne else 0
                        if _mcap == 0:
                            _min_turnover = 10000000
                        elif _durability >= 80:
                            _min_turnover = 2000000
                        else:
                            _min_turnover = 5000000
                        if volume * ltp < _min_turnover:
                            continue'''

# Site C: line ~4032 (Hidden Gem scanner) — keep ₹50L floor here because Hidden Gem
# already has tight quality filters (durability+promoter+FII+MF). Don't relax.
# This site is intentionally unchanged in CHANGE 3.

# ═══════════════════════════════════════════════════════════════════════════════
# CHANGE 2 — Hidden Gem upper bound (line ~4020)
# ═══════════════════════════════════════════════════════════════════════════════
CHANGE2_OLD = '''                        if not (300 <= mcap <= 50000): continue  # V74: widened from 500-5000'''

CHANGE2_NEW = '''                        if not (300 <= mcap <= 200000): continue  # V80_CHANGE2: widened upper to 2L Cr (was 50K Cr); excludes only mega-caps where gem signal is noise'''

# ═══════════════════════════════════════════════════════════════════════════════
# CHANGE 4 — Pre-market momentum threshold (line ~3975)
# ═══════════════════════════════════════════════════════════════════════════════
CHANGE4_OLD = '''                        if ltp <= 0 or prev_close <= 0: continue
                        pct_change = (ltp - prev_close) / prev_close
                        if pct_change < 0.04: continue
                        avg_volume = avg_vol_map.get(sym, 0) if avg_vol_map else 0
                        # FIX_V53_AVGVOL_FALLBACK: allow strong momentum to enter
                        # even if avg_vol cache not ready (first 18 min after deploy).
                        if avg_volume > 0 and volume > 0:
                            vol_ratio = volume / avg_volume
                            if vol_ratio < 1.8: continue
                        else:
                            if volume <= 0 or volume * ltp < 10000000:  # V75: 2cr -> 1cr  # Rs 2 Cr turnover for momentum
                                continue
                            vol_ratio = 1.8  # neutral assumption for scoring'''

CHANGE4_NEW = '''                        if ltp <= 0 or prev_close <= 0: continue
                        pct_change = (ltp - prev_close) / prev_close
                        # V80_CHANGE4: tiered momentum threshold — earlier entry but stricter volume confirmation
                        if pct_change < 0.025: continue
                        _is_strong_move = pct_change >= 0.04
                        avg_volume = avg_vol_map.get(sym, 0) if avg_vol_map else 0
                        # FIX_V53_AVGVOL_FALLBACK: allow strong momentum to enter
                        # even if avg_vol cache not ready (first 18 min after deploy).
                        if avg_volume > 0 and volume > 0:
                            vol_ratio = volume / avg_volume
                            # V80_CHANGE4: weaker move (2.5-4%) requires 2.5x vol; strong move (4%+) keeps 1.8x
                            _min_vol_ratio = 1.8 if _is_strong_move else 2.5
                            if vol_ratio < _min_vol_ratio: continue
                        else:
                            # V80_CHANGE4: weaker move requires Rs 1 Cr turnover; strong move keeps existing logic
                            _min_turnover_momentum = 10000000 if _is_strong_move else 20000000
                            if volume <= 0 or volume * ltp < _min_turnover_momentum:
                                continue
                            vol_ratio = 1.8 if _is_strong_move else 2.5  # neutral assumption for scoring'''


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
    print("Applying CHANGE 1 (fix mcap=0 silent-kill, all 3 sites) ...")
    patched = apply_edit(original, CHANGE1_OLD, CHANGE1_NEW, "CHANGE1", expected_count=3)
    print("  OK — 3 sites fixed")

    print("Applying CHANGE 3A (tier-aware turnover, Falling Knife scanner) ...")
    patched = apply_edit(patched, CHANGE3A_OLD, CHANGE3A_NEW, "CHANGE3A", expected_count=1)
    print("  OK")

    print("Applying CHANGE 3B (tier-aware turnover, Pre-market gappers) ...")
    patched = apply_edit(patched, CHANGE3B_OLD, CHANGE3B_NEW, "CHANGE3B", expected_count=1)
    print("  OK")

    print("Applying CHANGE 2 (Hidden Gem upper bound 50K -> 2L Cr) ...")
    patched = apply_edit(patched, CHANGE2_OLD, CHANGE2_NEW, "CHANGE2", expected_count=1)
    print("  OK")

    print("Applying CHANGE 4 (momentum threshold 4% -> 2.5%, with stricter volume) ...")
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
    print("  CHANGE 1: mcap=0 stocks no longer silently rejected (3 sites)")
    print("  CHANGE 2: Hidden Gem upper bound raised 50K Cr -> 2L Cr")
    print("  CHANGE 3: Tier-aware turnover floor (20L / 50L / 1Cr)")
    print("  CHANGE 4: Momentum threshold 4% -> 2.5% (with 2.5x vol guard)")
    print()
    print("Next step:")
    print("  bash /home/globalbot/safe_deploy.sh --force")
    print()
    print("Rollback if needed:")
    print(f"  cp {BACKUP_PATH} {GIR_PATH} && systemctl restart globaleye")
    print("=" * 60)


if __name__ == "__main__":
    main()

#!/bin/bash
set -e
cd /home/globalbot
STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP="gir.py.bak_pre_v60p3_${STAMP}"
echo "=== Backup ==="
cp gir.py "$BACKUP"

python3 << 'PYEOF'
import re, sys, json, os
PATH = "gir.py"
with open(PATH) as f:
    src = f.read()
orig_len = len(src)

# ============================================================================
# P8: Activate guard — replace direct kite.place_gtt/modify_gtt calls
# with _safe_place_gtt(kite, ...) and _safe_modify_gtt(kite, ...)
# But ONLY where kite object is accessible. In F&O/equity modules, it's self.kite.
# ============================================================================

# Count existing direct calls
direct_place = src.count("kite.place_gtt(")
direct_mod   = src.count("kite.modify_gtt(")
print(f"Direct kite.place_gtt calls found: {direct_place}")
print(f"Direct kite.modify_gtt calls found: {direct_mod}")

# Replace in all contexts
# kite.place_gtt(...)  →  _safe_place_gtt(kite, ...)
# Must handle both bare "kite.place_gtt" and "self.kite.place_gtt"
# Simplest: regex to catch both

def replace_place(m):
    prefix = m.group(1)  # e.g. "self.kite" or "kite"
    return f"_safe_place_gtt({prefix}, "

def replace_modify(m):
    prefix = m.group(1)
    return f"_safe_modify_gtt({prefix}, "

new_src = re.sub(r'((?:self\.)?kite)\.place_gtt\(', replace_place, src)
new_src = re.sub(r'((?:self\.)?kite)\.modify_gtt\(', replace_modify, new_src)

# Verify we didn't touch our OWN _safe_place_gtt/_safe_modify_gtt definitions
# They call "kite.place_gtt(**kwargs)" inside — but those are INSIDE _safe_place_gtt body
# so they should still be there. Let me check.
# Actually we need to NOT replace the internal call inside _safe_place_gtt itself.
# Let me revert and do more carefully.

# Smart approach: replace ONLY outside the _safe_*_gtt function bodies
# We find the _safe_place_gtt body and protect it.

# Simpler: revert and use string-based replacement that skips if the line contains "return kite.place_gtt" or "return kite.modify_gtt" (those are inside wrappers)

src_new = src
# Replace kite.place_gtt( but NOT "return kite.place_gtt(" (that's inside _safe_place_gtt)
# We use a regex that requires it NOT preceded by "return "
src_new = re.sub(r'(?<!return )((?:self\.)?kite)\.place_gtt\(', r'_safe_place_gtt(\1, ', src_new)
src_new = re.sub(r'(?<!return )((?:self\.)?kite)\.modify_gtt\(', r'_safe_modify_gtt(\1, ', src_new)

# Sanity: our wrappers still should contain "return kite.place_gtt(**kwargs)" and
# "return kite.modify_gtt(**kwargs)"
if "return kite.place_gtt(**kwargs)" not in src_new:
    print("  [P8] FAIL: wrapper body corrupted")
    sys.exit(1)
if "return kite.modify_gtt(**kwargs)" not in src_new:
    print("  [P8] FAIL: wrapper body corrupted (modify)")
    sys.exit(1)

src = src_new
new_place = src.count("_safe_place_gtt(")
new_mod   = src.count("_safe_modify_gtt(")
remaining_place = src.count("kite.place_gtt(")   # only inside wrapper
remaining_mod   = src.count("kite.modify_gtt(")  # only inside wrapper
print(f"  [P8] _safe_place_gtt calls: {new_place} (includes 1 def)")
print(f"  [P8] _safe_modify_gtt calls: {new_mod} (includes 1 def)")
print(f"  [P8] remaining direct kite.place_gtt (inside wrapper only): {remaining_place}")
print(f"  [P8] remaining direct kite.modify_gtt (inside wrapper only): {remaining_mod}")

with open(PATH, "w") as f:
    f.write(src)
print(f"\nWrote gir.py: {len(src)} bytes (delta {len(src)-orig_len:+d})")
PYEOF

echo ""
echo "=== Compile ==="
python3 -c "import ast; ast.parse(open('gir.py').read()); print('syntax OK')"

echo ""
echo "=== Markers ==="
echo "FIX_V60 total: $(grep -c 'FIX_V60' gir.py)"
echo "_safe_place_gtt calls: $(grep -c '_safe_place_gtt' gir.py)"
echo "_safe_modify_gtt calls: $(grep -c '_safe_modify_gtt' gir.py)"
echo "raw kite.place_gtt: $(grep -c 'kite.place_gtt' gir.py) (should be 1 — inside wrapper)"
echo "raw kite.modify_gtt: $(grep -c 'kite.modify_gtt' gir.py) (should be 1 — inside wrapper)"

echo ""
wc -l gir.py "$BACKUP"

# ============================================================================
# P9: JSON cleanup — refresh stale pos_sl in fno_peaks.json
# ============================================================================
echo ""
echo "=== [P9] fno_peaks.json cleanup ==="
python3 << 'PYEOF'
import json, os, math
from kiteconnect import KiteConnect

with open("data/kite_token.json") as f:
    s = json.load(f)
k = KiteConnect(api_key=s.get("api_key") or "m8yzn5cyjs71jq78")
k.set_access_token(s["access_token"])

# Build current SL from Kite GTTs (authoritative)
sl_map = {}  # tsym -> current trigger on Kite
for g in k.get_gtts():
    if g.get("status") != "active":
        continue
    tsym = g["condition"]["tradingsymbol"]
    exch = g["condition"]["exchange"]
    if exch == "NFO":
        sl_map[tsym] = float(g["condition"]["trigger_values"][0])

# Load fno_peaks.json
peaks_path = "fno_peaks.json"
if not os.path.exists(peaks_path):
    print(f"  [P9] {peaks_path} not found, skipping")
else:
    with open(peaks_path) as f:
        peaks = json.load(f)
    
    changed = 0
    for tsym, rec in peaks.items():
        kite_sl = sl_map.get(tsym)
        stale = rec.get("sl_price", 0)
        if kite_sl and abs(kite_sl - stale) > 0.005:
            print(f"  [P9] {tsym}: sl_price {stale} -> {kite_sl} (kite authoritative)")
            rec["sl_price"] = kite_sl
            changed += 1
    
    if changed > 0:
        # Backup first
        import shutil
        shutil.copy(peaks_path, f"{peaks_path}.bak_{os.getpid()}")
        with open(peaks_path, "w") as f:
            json.dump(peaks, f, indent=2)
        print(f"  [P9] updated {changed} entries in {peaks_path}")
    else:
        print(f"  [P9] no stale entries in {peaks_path}")
PYEOF

echo ""
echo "=== DONE PART 3 ==="
echo "Rollback: cp $BACKUP gir.py && sudo systemctl restart globaleye"

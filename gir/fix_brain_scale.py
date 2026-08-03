import shutil, ast, subprocess, datetime, sys
F = "/home/globalbot/paper/decision_brain.py"
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
bak = f"{F}.bak.scalefix_{ts}"
shutil.copy2(F, bak); print(f"[backup] {bak}")
src = open(F).read()

# ---- PATCH 1: rewrite _compute_final_score body (normalize layers to 0-100) ----
OLD = '''        weighted_sum = 0.0
        weight_total = 0.0
        supporting = 0
        for layer_name, weight in LAYER_WEIGHTS.items():
            layer = c.layers.get(layer_name)
            if layer is None:
                # Missing layer - treat as neutral (score 50) with low confidence
                # so it neither helps nor hurts, but doesn't crash the brain
                weighted_sum += 50.0 * weight * 0.3
                weight_total += weight * 0.3
                continue
            weighted_sum += layer.score * weight * layer.confidence
            weight_total += weight * layer.confidence
            if layer.supports:
                supporting += 1
        final = weighted_sum / weight_total if weight_total > 0 else 0
        return round(final, 2), supporting'''

NEW = '''        # PATCH_SCALEFIX: wired scorers emit 0-20 by design (summed to ~100 in
        # ExpertPanel.evaluate_*). This brain reuses them PER-LAYER, so each must be
        # normalized to 0-100 before averaging, and "supporting" recomputed on that
        # normalized scale. Fixes both gates (floor + MIN_SUPPORTING_LAYERS) at the
        # source. Scorers / evaluate_* / SCORE_FLOOR / LAYER_WEIGHTS untouched.
        _LAYER_MAX = {
            "technical": 20.0, "delivery_pct": 100.0, "oi_buildup": 20.0,
            "promoter_inst": 100.0, "fii_dii_flow": 100.0, "news_sentiment": 100.0,
            "regime_filter": 100.0, "earnings_window": 100.0, "sector_rotation": 20.0,
            "fundamental": 20.0, "filings_signal": 20.0,
        }
        weighted_sum = 0.0
        weight_total = 0.0
        supporting = 0
        for layer_name, weight in LAYER_WEIGHTS.items():
            layer = c.layers.get(layer_name)
            if layer is None:
                # Missing layer - neutral (50/100) at low confidence: neither helps nor hurts
                weighted_sum += 50.0 * weight * 0.3
                weight_total += weight * 0.3
                continue
            _mx = _LAYER_MAX.get(layer_name, 100.0)
            norm = (layer.score / _mx) * 100.0 if _mx else layer.score
            if norm < 0: norm = 0.0
            if norm > 100: norm = 100.0
            weighted_sum += norm * weight * layer.confidence
            weight_total += weight * layer.confidence
            # recompute support on normalized 0-100 scale (stale upstream bool ignored)
            if norm >= 55.0:
                supporting += 1
        final = weighted_sum / weight_total if weight_total > 0 else 0
        return round(final, 2), supporting'''

if OLD not in src:
    print("[FAIL] PATCH1 anchor not found - aborting, no change written"); sys.exit(1)
if src.count(OLD) != 1:
    print(f"[FAIL] PATCH1 anchor not unique ({src.count(OLD)}) - aborting"); sys.exit(1)
src = src.replace(OLD, NEW)
print("[ok] PATCH1 applied (normalize + supporting on 0-100)")

# ---- PATCH 2: MIN_SUPPORTING_LAYERS 5 -> 3 ----
OLD2 = "MIN_SUPPORTING_LAYERS = 5"
NEW2 = "MIN_SUPPORTING_LAYERS = 3   # PATCH_SCALEFIX: only 6/11 layers wired; 5 hardcoded neutral. 3 = genuine multi-layer agreement."
if src.count(OLD2) != 1:
    print(f"[FAIL] PATCH2 anchor count={src.count(OLD2)} - aborting"); sys.exit(1)
src = src.replace(OLD2, NEW2)
print("[ok] PATCH2 applied (MIN_SUPPORTING_LAYERS 5->3)")

# ---- write + AST validate + auto-rollback ----
open(F, "w").write(src)
try:
    ast.parse(open(F).read()); print("[ok] AST valid")
except SyntaxError as e:
    shutil.copy2(bak, F); print(f"[ROLLBACK] syntax error: {e}"); sys.exit(1)

print("[restart] globaleye.service")
r = subprocess.run(["systemctl","restart","globaleye.service"])
if r.returncode != 0:
    print("[WARN] restart returned nonzero - check: systemctl status globaleye.service")
print(f"[DONE] permanent scale fix applied. backup: {bak}")

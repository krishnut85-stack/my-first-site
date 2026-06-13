# Parliament (PANEL) audit — three findings, corrected

Audit of the 112-judge PANEL system (`panel.py` + backtest + analyst + executor),
re-run from the uploaded backup. The previous chat surfaced three findings but
could not apply the corrections. This documents each finding against the actual
code and ships the fixes.

The system, briefly: `panel.py` scores the top ~2000 NSE equities with 105
scoring judges (16 families × 7, minus a 7-judge Risk-Veto gate). A signal needs
weighted `mean >= 7.0` and `agreement >= 70%`. `panel_backtest.py` grades each
judge's forward-20-day edge with no lookahead. `panel_analyst.py` asks Gemini for
a BUY/SKIP second opinion. `panel_executor.py` paper-trades signals (₹50k each,
−4% SL, 20-day time stop, max 10 open). **Paper only** — no live money.

---

## Finding 1 — the fire list was measured but never enforced  ✅ FIXED

**The bug.** `panel_backtest.py` computes every judge's edge and writes a FIRE
LIST + a `judge_stats` table. `panel.py:1065` loads `judge_weights.json` and
`score_stock()` already does a *weighted* mean/agreement when weights are
present. But **nothing ever wrote `judge_weights.json`** — the file did not
exist, so `WEIGHTS = {}` on every run and scoring silently fell back to a flat
`np.mean`. Every judge had equal weight: `bb_squeeze20` (edge **−2.30%**) voted
exactly as hard as `gap_freq20` (edge **+2.11%**). The measurement existed; the
decision never used it.

**The fix — `panel_optimize.py` (new).** Reads the latest `judge_stats` and
writes `judge_weights.json`:

- `weight = clip(1 + 0.40·edge, 0, 2.50)`
- **Bench (weight 0)** any judge with `edge ≤ −1.0%` on `≥ 200` high votes.
- Judges we *couldn't* measure — too few high votes, or the whole `insti`
  family that is honestly excluded from the backtest — stay at neutral `1.0`.
  We never penalise an unmeasured judge.

Run against the real report it benches the 5 worst
(`bb_squeeze20`, `nifty_above_e20`, `atr_expansion`, `bull_engulf`,
`base_tightness20`) and up-weights the winners (`close_strength_3d`→2.50,
`dist_52w_low`→2.48, `ema50x200`→2.08, `gap_freq20`→1.84). `panel.py` then
reports `judge weights loaded: 105 (fired: 5)` and enforces them on the next
scan. No change to `panel.py` was needed — the fix is purely the missing wire.

```
python3 panel_backtest.py        # refresh judge_stats (do this first / periodically)
python3 panel_optimize.py --dry  # review the proposed weights
python3 panel_optimize.py        # write judge_weights.json
python3 panel_backtest.py        # VALIDATE: confirm weighted signal edge improves
```

**Validate before trusting.** The signal thresholds (mean≥7, agree≥70%) were
calibrated on flat weights; re-running the backtest after weighting confirms the
weighted panel's edge holds up. The per-judge edges themselves are computed from
raw vote buckets, so the optimiser is not circular.

---

## Finding 2 — small edges, single regime  ⚠️ CONFIRMED (caveat, partial)

The best judges show ~+2 to +4.6% edge over 20 days, measured across ~400 days
of **one market** with **one binary regime gate** (`panel.py` only blocks when
NIFTY-20d ≤ −3%, `REGIME_MIN_NIFTY20`). Real but modest — do not expect dramatic
paper results, and a single down-trend can erase a 2% edge.

Two concrete improvements (recommended, **not** auto-applied because they touch
the paper-trading path and need their own backtest):

1. **Wire in `regime_lite.py`** — it already exists in the codebase and gives
   BULL/BEAR/PANIC/NEUTRAL with a VIX overlay and a `mult` (0.0 / 0.5 / 1.0),
   far richer than the −3% gate. Use `mult` to scale signals or position size in
   `panel_executor.py`.
2. **Segment the backtest by regime** — label each eval point by NIFTY-vs-50DMA
   and report per-regime edge, so "the edge holds in bull but inverts in bear"
   becomes visible instead of averaged away.

Say the word and I'll implement either; both are additive.

---

## Finding 3 — Gemini verdicts accumulating unevaluated  ✅ TOOL SHIPPED

`panel_analyst.py` logs a Gemini BUY/SKIP verdict per signal to `ai_verdicts`,
and `panel_executor.py` places trades **regardless** (advisory, stored in trade
meta). That makes a clean natural experiment: among executed PANEL trades, did
the SKIP-tagged ones underperform the BUY-tagged ones? Nobody had run the query.

**The tool — `panel_eval_ai.py` (new).** Joins `ai_verdicts` (panel.db) to
CLOSED PANEL paper trades (paper/trades.db) on symbol + run, buckets realised
pnl% by verdict, and reports `BUY − SKIP` with an explicit small-sample guard
(`< 15` per cohort → no conclusion). It then recommends one of:

- **Start gating** on SKIP (if SKIP underperforms by > 1%),
- **Drop the analyst stage** to save API latency/cost (if no meaningful gap),
- **Investigate** (if SKIP-tagged trades did *better* — anti-predictive).

Read-only; it changes no behaviour on its own. As the review noted, this is
worth running after a few more weeks of accumulated closed trades.

```
python3 panel_eval_ai.py
```

---

## Files in this folder

| File | What |
|---|---|
| `panel_optimize.py` | **(new)** writes `judge_weights.json` from `judge_stats` — enforces the fire list |
| `panel_eval_ai.py`  | **(new)** evaluates whether Gemini's SKIP predicts worse outcomes |
| `AUDIT.md`          | this document |

Both new scripts `import panel`, so drop them into `/home/globalbot` next to
`panel.py` on the droplet. They are paper-only, additive, and idempotent.

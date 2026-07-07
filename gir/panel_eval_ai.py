#!/usr/bin/env python3
"""PANEL EVAL AI — does Gemini's SKIP actually predict worse outcomes?

Audit finding #3. panel_analyst.py logs a Gemini BUY/SKIP verdict per signal
into the ai_verdicts table, and panel_executor.py places the trade REGARDLESS
of that verdict (it is advisory, stored only in trade meta). That accidental
design is a clean natural experiment: among executed PANEL trades, did the ones
Gemini tagged SKIP underperform the ones it tagged BUY?

  - If SKIP trades did meaningfully worse  -> Gemini's SKIP has predictive value;
    start gating on it in panel_executor.
  - If they did the same or better          -> the analyst stage is spending API
    latency/cost for nothing; drop it. The math panel stands alone.

This joins ai_verdicts (panel.db) to CLOSED PANEL paper trades (paper/trades.db)
on symbol + run, buckets realised pnl% by verdict, and reports the gap with an
explicit small-sample caveat. Read-only; it changes no behaviour by itself.

Usage (on droplet, from /home/globalbot):
  python3 panel_eval_ai.py
"""
import os
import sqlite3
import statistics as st

import panel  # DB_PATH

PAPER_DB = "/home/globalbot/paper/trades.db"
MIN_PER_COHORT = 15     # below this, refuse to draw a conclusion
GAP_THRESHOLD = 1.0     # pnl% difference that counts as "meaningful"


def main():
    con = sqlite3.connect(panel.DB_PATH)
    try:
        verdicts = con.execute(
            "SELECT run_id, symbol, verdict, conviction FROM ai_verdicts"
        ).fetchall()
    except sqlite3.OperationalError:
        print("[EVAL] ai_verdicts table missing -- run panel_analyst.py first.")
        return
    finally:
        con.close()

    if not verdicts:
        print("[EVAL] ai_verdicts empty -- run panel_analyst.py on some signals first.")
        return
    vmap = {(rid, sym): (verdict, conv) for rid, sym, verdict, conv in verdicts}

    if not os.path.exists(PAPER_DB):
        print(f"[EVAL] {PAPER_DB} not found (run this on the droplet).")
        return
    pc = sqlite3.connect(PAPER_DB)
    trades = pc.execute(
        "SELECT signal_source, symbol, qty, entry_price, pnl FROM paper_trades "
        "WHERE status='CLOSED' AND UPPER(strategy) LIKE 'PANEL%'"
    ).fetchall()
    pc.close()

    cohorts = {"BUY": [], "SKIP": [], "NONE": []}
    matched = 0
    for src, sym, qty, entry, pnl in trades:
        rid = None
        if src and src.startswith("panel_run_"):
            try:
                rid = int(src.rsplit("_", 1)[1])
            except Exception:
                rid = None
        verdict, _conv = vmap.get((rid, sym), ("NONE", None))
        cost = (entry or 0) * (qty or 0)
        if cost <= 0:
            continue
        pnl_pct = (pnl or 0) / cost * 100
        cohorts.setdefault(verdict or "NONE", []).append(pnl_pct)
        if verdict in ("BUY", "SKIP"):
            matched += 1

    print(f"[EVAL] {len(trades)} closed PANEL trades | "
          f"{matched} carried a Gemini verdict\n")
    print(f"{'COHORT':<8}{'N':>5}{'MEAN_PNL%':>11}{'WIN%':>7}{'MEDIAN%':>9}")
    summary = {}
    for name in ("BUY", "SKIP", "NONE"):
        pnls = cohorts.get(name, [])
        if not pnls:
            print(f"{name:<8}{0:>5}{'--':>11}{'--':>7}{'--':>9}")
            continue
        mean = sum(pnls) / len(pnls)
        win = sum(1 for p in pnls if p > 0) / len(pnls) * 100
        med = st.median(pnls)
        summary[name] = (len(pnls), mean, win)
        print(f"{name:<8}{len(pnls):>5}{mean:>11.2f}{win:>7.0f}{med:>9.2f}")

    b, s = summary.get("BUY"), summary.get("SKIP")
    print()
    if not b or not s:
        print("[EVAL] need closed trades in BOTH cohorts to compare. "
              "Keep logging; revisit in a few weeks.")
        return
    gap = b[1] - s[1]
    print(f"[EVAL] BUY mean {b[1]:+.2f}% (n={b[0]}) vs SKIP mean {s[1]:+.2f}% "
          f"(n={s[0]}) -> BUY-SKIP = {gap:+.2f}%")
    if b[0] < MIN_PER_COHORT or s[0] < MIN_PER_COHORT:
        print(f"[EVAL] VERDICT: sample too small (want >={MIN_PER_COHORT} per "
              f"cohort). No action yet -- keep accumulating.")
    elif gap > GAP_THRESHOLD:
        print("[EVAL] VERDICT: SKIP predicts worse outcomes -> START GATING on "
              "Gemini SKIP in panel_executor (skip or down-size SKIP-tagged signals).")
    elif gap < -GAP_THRESHOLD:
        print("[EVAL] VERDICT: SKIP-tagged trades did BETTER -> Gemini is "
              "anti-predictive here. Do NOT gate; investigate or drop the stage.")
    else:
        print("[EVAL] VERDICT: no meaningful edge from Gemini's verdict -> DROP "
              "the analyst stage (saves API latency/cost). The math panel stands alone.")


if __name__ == "__main__":
    main()

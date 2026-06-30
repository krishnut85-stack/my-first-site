#!/usr/bin/env python3
"""
GIR FUNNEL DIAGNOSTIC — read-only, no patches
═══════════════════════════════════════════════════════════════════════════════

Walks the last N days of journalctl logs and reconstructs the full equity
candidate funnel:

   Scout sources  →  NewsBrain validation  →  Expert Panel  →  Fill

For each stage it shows:
   - count
   - rejection reasons (with frequency)
   - sample of rejected candidates with full reason

Goal: answer "where does the bot lose 95% of identified opportunities?"

Usage:
   python3 funnel_diagnostic.py            # last 7 days
   python3 funnel_diagnostic.py 14         # last 14 days
   python3 funnel_diagnostic.py 3          # last 3 days only

Output:
   - prints to console
   - also written to /home/globalbot/audits/funnel_<DATE>.txt

Read-only. Safe to run anytime. No bot interaction.
"""

from __future__ import annotations
import sys, re, subprocess, json
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

IST = timezone(timedelta(hours=5, minutes=30))

DAYS = int(sys.argv[1]) if len(sys.argv) > 1 else 7
NOW  = datetime.now(IST)
SINCE = (NOW - timedelta(days=DAYS)).strftime("%Y-%m-%d %H:%M:%S")

OUT_DIR = Path("/home/globalbot/audits")
OUT_DIR.mkdir(exist_ok=True)
OUT_FILE = OUT_DIR / f"funnel_{NOW.strftime('%Y-%m-%d')}.txt"

print(f"Pulling logs from {SINCE} (last {DAYS} days)...")
print(f"Output also written to: {OUT_FILE}")

# ─────────────────────────────────────────────────────────────────────────────
# Pull all relevant log lines in one journalctl call
# ─────────────────────────────────────────────────────────────────────────────
cmd = [
    "journalctl", "-u", "globaleye",
    "--since", SINCE,
    "--no-pager", "-o", "short-iso",
]
try:
    raw = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    lines = raw.stdout.splitlines()
except Exception as e:
    print(f"FATAL: journalctl failed: {e}")
    sys.exit(1)

print(f"  Retrieved {len(lines):,} log lines")

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 — Scout emissions  (where candidates come from)
# Pattern: "X candidates from Y headlines/filings/scouts"
# Pattern: "Filing EQUITY: 5 signals", "News EQUITY: 9 candidates", etc.
# ─────────────────────────────────────────────────────────────────────────────
PAT_SCOUT_FILING   = re.compile(r"Filing EQUITY:\s*(\d+)\s*signals", re.I)
PAT_SCOUT_NEWS     = re.compile(r"News EQUITY:\s*(\d+)\s*candidates", re.I)
PAT_SCOUT_BROKER   = re.compile(r"Brokerage EQUITY:\s*(\d+)\s*analyst calls", re.I)
PAT_SCOUT_MACRO    = re.compile(r"Macro EQUITY:\s*(\d+)\s*scout candidates", re.I)
PAT_SCOUT_AMO_HOLD = re.compile(r"Equity AMO:.*?(\d+)\s*live holdings", re.I)

scout_filing = scout_news = scout_broker = scout_macro = 0
for ln in lines:
    if (m := PAT_SCOUT_FILING.search(ln)):   scout_filing += int(m.group(1))
    if (m := PAT_SCOUT_NEWS.search(ln)):     scout_news   += int(m.group(1))
    if (m := PAT_SCOUT_BROKER.search(ln)):   scout_broker += int(m.group(1))
    if (m := PAT_SCOUT_MACRO.search(ln)):    scout_macro  += int(m.group(1))

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 — NewsBrain validation results
# Pattern: "NewsBrain v4 [EQUITY]: validating X (DIRECTION) - full=Y, cross=Z"
# Pattern: "NewsBrain v4 [EQUITY]: ... CONFIRMED|REJECTED|CORRECTED"
# ─────────────────────────────────────────────────────────────────────────────
PAT_NB_VALIDATING = re.compile(
    r"NewsBrain.*?\[EQUITY\].*?validating\s+(\w+)\s*\((\w+)\).*?full=(\w+),\s*cross=(\d+)",
    re.I,
)
PAT_NB_VERDICT = re.compile(
    r"NewsBrain.*?\[EQUITY\].*?(CONFIRMED|REJECTED|CORRECTED|VALIDATED)\s+(\w+)",
    re.I,
)
PAT_NB_AUTHORITATIVE = re.compile(
    r"FIX_NB_C1\s*FILING\s*(\w+)\s*authoritative\s*source",
    re.I,
)
PAT_NB_GEMINI_FAIL = re.compile(
    r"NewsBrain.*?Gemini failed for", re.I,
)

nb_validating = []
nb_verdicts   = Counter()
nb_authoritative = 0
nb_gemini_fails = 0
for ln in lines:
    if (m := PAT_NB_VALIDATING.search(ln)):
        nb_validating.append((m.group(1), m.group(2), m.group(3), int(m.group(4))))
    if (m := PAT_NB_VERDICT.search(ln)):
        nb_verdicts[m.group(1).upper()] += 1
    if PAT_NB_AUTHORITATIVE.search(ln):  nb_authoritative += 1
    if PAT_NB_GEMINI_FAIL.search(ln):    nb_gemini_fails += 1

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3 — Expert Panel decisions
# Pattern: "[FIX_V46_PANEL_EQ] SYM DIR: news=X fund=Y tech=Z sector=A hist=B → TOTAL=N → TRADE|BLOCKED"
# ─────────────────────────────────────────────────────────────────────────────
PAT_PANEL = re.compile(
    r"PANEL.*?(\w+)\s+(BULLISH|BEARISH).*?"
    r"news=(\d+)\s+fund=(\d+)\s+tech=(\d+)\s+sector=(\d+)\s+hist(?:ory)?=(\d+)"
    r".*?TOTAL=(\d+).*?(TRADE|BLOCKED|VETO)",
    re.I,
)

panel_decisions = []
for ln in lines:
    if (m := PAT_PANEL.search(ln)):
        panel_decisions.append({
            "symbol":  m.group(1),
            "dir":     m.group(2),
            "news":    int(m.group(3)),
            "fund":    int(m.group(4)),
            "tech":    int(m.group(5)),
            "sector":  int(m.group(6)),
            "history": int(m.group(7)),
            "total":   int(m.group(8)),
            "verdict": m.group(9).upper(),
        })

# ─────────────────────────────────────────────────────────────────────────────
# Stage 4 — Actual fills (V101C_ORDER ... BUY COMPLETE)
# ─────────────────────────────────────────────────────────────────────────────
PAT_FILL = re.compile(
    r"\[V101C_ORDER\]\s+(\S+)\s+BUY\s+COMPLETE\s+qty=(\d+)\s+avg=([\d.]+)",
    re.I,
)
fills = []
for ln in lines:
    if (m := PAT_FILL.search(ln)):
        # Skip F&O symbols (contain CE/PE/FUT)
        sym = m.group(1)
        if any(sfx in sym for sfx in ("CE", "PE", "FUT")):
            continue
        fills.append({"symbol": sym, "qty": int(m.group(2)), "avg": float(m.group(3))})

# ─────────────────────────────────────────────────────────────────────────────
# Stage 5 — Other rejection reasons (non-panel)
# Patterns: "skipping", "rejected", "blocked", "guard"
# ─────────────────────────────────────────────────────────────────────────────
PAT_REJECT_GENERIC = re.compile(
    r"\[GIR\].*?(?:skipping|rejected|blocked|GUARD).*?[: ](.{20,200})",
    re.I,
)
generic_rejects = Counter()
for ln in lines:
    if PAT_REJECT_GENERIC.search(ln):
        # Extract reason — first 80 chars after the keyword
        m = re.search(r"(?:skipping|rejected|blocked|GUARD)[: ]+(.{0,120})", ln, re.I)
        if m:
            reason_short = re.sub(r"\s+", " ", m.group(1)).strip()[:80]
            generic_rejects[reason_short] += 1

# ─────────────────────────────────────────────────────────────────────────────
# Build report
# ─────────────────────────────────────────────────────────────────────────────
out = []
P = out.append

P("=" * 79)
P(f"  GIR EQUITY FUNNEL DIAGNOSTIC — last {DAYS} days (since {SINCE} IST)")
P("=" * 79)

# ─── STAGE 1 ───
total_scouts = scout_filing + scout_news + scout_broker + scout_macro
P(f"\n[STAGE 1] SCOUT EMISSIONS — {total_scouts} total candidates surfaced")
P("-" * 79)
P(f"  Filing scouts    : {scout_filing:>5}")
P(f"  News scouts      : {scout_news:>5}")
P(f"  Brokerage scouts : {scout_broker:>5}")
P(f"  Macro scouts     : {scout_macro:>5}")

# ─── STAGE 2 ───
P(f"\n[STAGE 2] NEWSBRAIN VALIDATION")
P("-" * 79)
P(f"  Items entered validation : {len(nb_validating):>5}")
P(f"  Authoritative bypasses   : {nb_authoritative:>5}  (FIX_NB_C1 single-source filings)")
P(f"  Gemini failures (429 etc): {nb_gemini_fails:>5}")
P(f"")
P(f"  Verdicts:")
for v, n in nb_verdicts.most_common():
    P(f"    {v:14} : {n:>5}")

# Validation pass rate
total_verdicts = sum(nb_verdicts.values())
if total_verdicts:
    pass_count = nb_verdicts.get("VALIDATED", 0) + nb_verdicts.get("CONFIRMED", 0) + nb_verdicts.get("CORRECTED", 0)
    pass_rate  = pass_count / total_verdicts * 100
    P(f"")
    P(f"  Validation pass rate: {pass_count}/{total_verdicts} = {pass_rate:.1f}%")

# ─── STAGE 3 ───
P(f"\n[STAGE 3] EXPERT PANEL DECISIONS")
P("-" * 79)
P(f"  Total panel evaluations : {len(panel_decisions)}")

if panel_decisions:
    panel_traded  = [p for p in panel_decisions if p["verdict"] == "TRADE"]
    panel_blocked = [p for p in panel_decisions if p["verdict"] in ("BLOCKED", "VETO")]
    P(f"  TRADE  : {len(panel_traded):>5}")
    P(f"  BLOCKED: {len(panel_blocked):>5}")

    if panel_blocked:
        avg_blocked_total = sum(p["total"] for p in panel_blocked) / len(panel_blocked)
        P(f"")
        P(f"  Average TOTAL score for BLOCKED candidates: {avg_blocked_total:.1f}/100")
        P(f"  (Threshold is 55 per V74 — anything below 55 is blocked)")

    # Score component analysis — where do points get lost?
    P(f"")
    P(f"  Score component averages (BLOCKED candidates only):")
    if panel_blocked:
        for comp in ("news", "fund", "tech", "sector", "history"):
            avg = sum(p[comp] for p in panel_blocked) / len(panel_blocked)
            P(f"    {comp:8}: {avg:>5.1f} / 20")

    P(f"")
    P(f"  Score component averages (TRADE candidates only):")
    if panel_traded:
        for comp in ("news", "fund", "tech", "sector", "history"):
            avg = sum(p[comp] for p in panel_traded) / len(panel_traded)
            P(f"    {comp:8}: {avg:>5.1f} / 20")

    # Distribution of blocked totals
    P(f"")
    P(f"  Distribution of BLOCKED totals (where they fall short):")
    bands = [(0,30), (30,40), (40,50), (50,55)]
    for lo, hi in bands:
        n = sum(1 for p in panel_blocked if lo <= p["total"] < hi)
        bar = "█" * (n if n < 50 else 50)
        P(f"    {lo:2}-{hi-1:2}  : {n:>4}  {bar}")

    # Sample BLOCKED with biggest gap
    P(f"")
    P(f"  Sample BLOCKED candidates (closest to threshold — would have traded with small lift):")
    near_miss = sorted([p for p in panel_blocked if 45 <= p["total"] < 55], key=lambda p: -p["total"])[:10]
    for p in near_miss:
        P(f"    {p['symbol']:14} {p['dir']:8} news={p['news']:>2} fund={p['fund']:>2} tech={p['tech']:>2} sector={p['sector']:>2} hist={p['history']:>2} → {p['total']:>3}")
else:
    P(f"  (No panel decisions matched — log pattern may differ from expected.")
    P(f"   Investigate by running: journalctl -u globaleye --since '{SINCE}' | grep -i panel | head)")

# ─── STAGE 4 ───
P(f"\n[STAGE 4] ACTUAL FILLS (equity only)")
P("-" * 79)
P(f"  Total fills: {len(fills)}")
for f in fills[:20]:
    cost = f["qty"] * f["avg"]
    P(f"    {f['symbol']:14}  qty={f['qty']:>5}  @ Rs.{f['avg']:>8.2f}   cost=Rs.{cost:>10,.0f}")

# ─── FUNNEL SUMMARY ───
P(f"\n[FUNNEL] DROP-OFF SUMMARY")
P("-" * 79)
P(f"  Stage 1: Scouts emitted              {total_scouts:>6}")
P(f"  Stage 2: NewsBrain validations       {len(nb_validating):>6}  "
  f"({len(nb_validating)/total_scouts*100:>5.1f}% of scouts)" if total_scouts else "")
nb_pass = nb_verdicts.get('VALIDATED', 0) + nb_verdicts.get('CONFIRMED', 0) + nb_verdicts.get('CORRECTED', 0)
P(f"  Stage 3: Panel evaluations           {len(panel_decisions):>6}  "
  f"({len(panel_decisions)/total_scouts*100:>5.1f}% of scouts)" if total_scouts else "")
P(f"  Stage 4: Panel TRADE verdicts        "
  f"{sum(1 for p in panel_decisions if p['verdict']=='TRADE'):>6}")
P(f"  Stage 5: Actual fills                {len(fills):>6}  "
  f"({len(fills)/total_scouts*100:>5.1f}% of scouts)" if total_scouts else "")

P(f"\n[GENERIC REJECTIONS] — top non-panel rejection reasons")
P("-" * 79)
for reason, n in generic_rejects.most_common(15):
    P(f"  {n:>4} x  {reason}")

P("\n" + "=" * 79)
P("  END OF FUNNEL DIAGNOSTIC")
P("=" * 79)

report = "\n".join(out)
print(report)
OUT_FILE.write_text(report)
print(f"\n[funnel_diagnostic] report saved -> {OUT_FILE}")

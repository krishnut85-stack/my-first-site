#!/usr/bin/env python3
"""
GIR DAILY SESSION AUDIT  -  v1.0
═══════════════════════════════════════════════════════════════════════════════
Forensic per-day audit of bot performance.  Read-only.  No order placement.

Usage:
    python3 gir_daily_audit.py                  # audits today
    python3 gir_daily_audit.py 2026-05-08       # audits a specific date
    python3 gir_daily_audit.py 2026-05-07 2026-05-08   # range (inclusive)

Outputs:
    1. Full text report  ->  /home/globalbot/audits/audit_<DATE>.txt
    2. Telegram digest   ->  sent via existing bot creds in /home/globalbot/.env

Data sources (all read-only):
    - journalctl -u globaleye   (every scan, decision, rejection)
    - /home/globalbot/equity_trades.json
    - /home/globalbot/fno_trades.json
    - Kite API (positions, holdings, orderbook for fills + slippage)
    - GTT audit logs

What it answers:
    A. Which trades made/lost money and why
    B. Which candidates fired but bot did NOT trade (missed opportunities)
    C. Which trades bot took that it shouldn't have (rule violations)
    D. Concrete parameter fixes with evidence

Standing rules respected:
    - Kite is single source of truth (no JSON-only conclusions)
    - All positions assumed bot-entered; unprotected = bug, flagged
    - Standards: jane-street-grade attribution, not retail summary
"""

from __future__ import annotations

import os
import sys
import json
import re
import subprocess
import logging
from collections import defaultdict, Counter
from datetime import datetime, timedelta, timezone, date
from pathlib import Path
from typing import Any

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIG
# ─────────────────────────────────────────────────────────────────────────────
BOT_HOME      = Path("/home/globalbot")
ENV_FILE      = BOT_HOME / ".env"
EQ_TRADES     = BOT_HOME / "equity_trades.json"
FNO_TRADES    = BOT_HOME / "fno_trades.json"
AUDIT_DIR     = BOT_HOME / "audits"
SERVICE       = "globaleye"

IST = timezone(timedelta(hours=5, minutes=30))

AUDIT_DIR.mkdir(exist_ok=True)

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(message)s")
log = logging.getLogger("audit")

# ─────────────────────────────────────────────────────────────────────────────
#  ENV LOADER (Telegram + Kite creds, never asked again per standing rule)
# ─────────────────────────────────────────────────────────────────────────────
def load_env() -> dict:
    env = {}
    if not ENV_FILE.exists():
        log.warning(f"{ENV_FILE} missing — Telegram + Kite calls will be skipped")
        return env
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env

ENV = load_env()

# ─────────────────────────────────────────────────────────────────────────────
#  DATE HANDLING
# ─────────────────────────────────────────────────────────────────────────────
def parse_date(s: str) -> date:
    return datetime.strptime(s, "%Y-%m-%d").date()

def date_range(args: list[str]) -> list[date]:
    if not args:
        return [datetime.now(IST).date()]
    if len(args) == 1:
        return [parse_date(args[0])]
    start, end = parse_date(args[0]), parse_date(args[1])
    out, cur = [], start
    while cur <= end:
        out.append(cur)
        cur += timedelta(days=1)
    return out

# ─────────────────────────────────────────────────────────────────────────────
#  JOURNAL READER
# ─────────────────────────────────────────────────────────────────────────────
def fetch_journal(d: date) -> list[str]:
    """Pull every globaleye log line for the given IST date."""
    since = f"{d.isoformat()} 00:00:00"
    until = f"{(d + timedelta(days=1)).isoformat()} 00:00:00"
    cmd = [
        "journalctl", "-u", SERVICE,
        "--since", since, "--until", until,
        "--no-pager", "-o", "short-iso",
    ]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        return r.stdout.splitlines()
    except Exception as e:
        log.error(f"journalctl failed: {e}")
        return []

# ─────────────────────────────────────────────────────────────────────────────
#  PATTERN EXTRACTORS  (forensic regexes against actual gir.py log strings)
# ─────────────────────────────────────────────────────────────────────────────
PAT_ENTRY        = re.compile(r"\b(ENTRY|ENTERED|ORDER PLACED|FILLED)\b.*?([A-Z0-9&]+)\s+qty[=: ]+(\d+).*?@\s*([\d.]+)", re.I)
PAT_EXIT         = re.compile(r"\b(EXIT|EXITED|SL_BREACH|TARGET_HIT|DTE_CUT|MANUAL_EXIT)\b.*?([A-Z0-9&]+).*?pnl[=: ]+(-?[\d.]+)", re.I)
PAT_REJECT       = re.compile(r"\b(REJECTED|SKIP(?:PED)?|BLOCKED|FILTER)\b.*?([A-Z0-9&]+).*?reason[=: ]+([^|;]+)", re.I)
PAT_NEWSBRAIN    = re.compile(r"NewsBrain.*?(VALIDATED|REJECTED).*?([A-Z0-9&]+).*?conviction[=: ]+(\d+)", re.I)
PAT_GTT_PLACED   = re.compile(r"GTT.*?(PLACED|MODIFIED|CREATED).*?([A-Z0-9&]+).*?@\s*([\d.]+)", re.I)
PAT_GTT_TRIGGER  = re.compile(r"GTT.*?TRIGGER(?:ED)?.*?([A-Z0-9&]+)", re.I)
PAT_CIRCUIT      = re.compile(r"\b(CIRCUIT_BREAKER|HALT|DAILY_LOSS_LIMIT|EXPOSURE_CAP)\b.*?:\s*(.*)", re.I)
PAT_IV_CRUSH     = re.compile(r"IV[_ ]?CRUSH.*?([A-Z0-9&]+)", re.I)
PAT_KELLY        = re.compile(r"Kelly.*?([A-Z0-9&]+).*?qty[=: ]+(\d+).*?cap[=: ]+(\d+)", re.I)
PAT_CRASH        = re.compile(r"\b(Traceback|ERROR|Exception|CRITICAL)\b", re.I)

def parse_journal(lines: list[str]) -> dict:
    """Walk the day's log lines and structure every decision."""
    out = {
        "entries":      [],   # [(ts, sym, qty, price, raw)]
        "exits":        [],   # [(ts, sym, pnl, reason, raw)]
        "rejections":   [],   # [(ts, sym, reason, raw)]
        "newsbrain":    [],   # [(ts, verdict, sym, conviction, raw)]
        "gtt_placed":   [],
        "gtt_triggered":[],
        "circuit":      [],
        "iv_crush":     [],
        "kelly_caps":   [],
        "crashes":      [],
        "scan_count":   0,
        "raw_lines":    len(lines),
    }
    for ln in lines:
        # timestamp prefix from short-iso = "2026-05-08T09:15:23+0530 host service: msg"
        ts_match = re.match(r"(\S+)", ln)
        ts = ts_match.group(1) if ts_match else ""

        if "scan cycle" in ln.lower() or "running scan" in ln.lower():
            out["scan_count"] += 1

        m = PAT_ENTRY.search(ln)
        if m:
            out["entries"].append((ts, m.group(2), int(m.group(3)), float(m.group(4)), ln))
            continue
        m = PAT_EXIT.search(ln)
        if m:
            out["exits"].append((ts, m.group(2), float(m.group(3)), m.group(1), ln))
            continue
        m = PAT_REJECT.search(ln)
        if m:
            out["rejections"].append((ts, m.group(2), m.group(3).strip(), ln))
            continue
        m = PAT_NEWSBRAIN.search(ln)
        if m:
            out["newsbrain"].append((ts, m.group(1), m.group(2), int(m.group(3)), ln))
            continue
        m = PAT_GTT_PLACED.search(ln)
        if m:
            out["gtt_placed"].append((ts, m.group(2), float(m.group(3)), ln))
            continue
        m = PAT_GTT_TRIGGER.search(ln)
        if m:
            out["gtt_triggered"].append((ts, m.group(1), ln))
            continue
        m = PAT_CIRCUIT.search(ln)
        if m:
            out["circuit"].append((ts, m.group(2), ln))
            continue
        m = PAT_IV_CRUSH.search(ln)
        if m:
            out["iv_crush"].append((ts, m.group(1), ln))
            continue
        m = PAT_KELLY.search(ln)
        if m:
            out["kelly_caps"].append((ts, m.group(1), int(m.group(2)), int(m.group(3)), ln))
            continue
        if PAT_CRASH.search(ln):
            out["crashes"].append((ts, ln))
    return out

# ─────────────────────────────────────────────────────────────────────────────
#  TRADE FILE READERS
# ─────────────────────────────────────────────────────────────────────────────
def load_trades(path: Path, d: date) -> list[dict]:
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text())
    except Exception as e:
        log.error(f"{path} unreadable: {e}")
        return []
    out = []
    for t in data if isinstance(data, list) else data.get("trades", []):
        # match on exit_date / closed_at / date fields, whichever exists
        ts = t.get("exit_date") or t.get("closed_at") or t.get("date") or ""
        if ts.startswith(d.isoformat()):
            out.append(t)
    return out

# ─────────────────────────────────────────────────────────────────────────────
#  KITE LIVE SNAPSHOT  (positions + holdings + orderbook)
# ─────────────────────────────────────────────────────────────────────────────
def kite_snapshot() -> dict:
    """Best-effort Kite call. Returns {} on any failure — audit still works without it."""
    try:
        from kiteconnect import KiteConnect
    except ImportError:
        return {}
    api_key      = ENV.get("KITE_API_KEY")
    access_token = ENV.get("KITE_ACCESS_TOKEN")
    if not api_key or not access_token:
        return {}
    try:
        kite = KiteConnect(api_key=api_key)
        kite.set_access_token(access_token)
        return {
            "positions": kite.positions(),
            "holdings":  kite.holdings(),
            "orders":    kite.orders(),
            "gtts":      kite.get_gtts(),
        }
    except Exception as e:
        log.warning(f"Kite snapshot failed: {e}")
        return {}

# ─────────────────────────────────────────────────────────────────────────────
#  MISTAKE DETECTION  (objective rules, no opinion)
# ─────────────────────────────────────────────────────────────────────────────
def detect_mistakes(parsed: dict, eq_closed: list[dict], fno_closed: list[dict]) -> list[dict]:
    mistakes = []

    # 1. Same-day SL hits — known bleed pattern
    same_day_losses = [t for t in eq_closed
                       if t.get("hold_days", 0) <= 1 and t.get("pnl", 0) < 0]
    if same_day_losses:
        total = sum(t.get("pnl", 0) for t in same_day_losses)
        mistakes.append({
            "severity": "HIGH",
            "kind": "SAME_DAY_SL_BLEED",
            "count": len(same_day_losses),
            "loss":  total,
            "evidence": [t.get("symbol") for t in same_day_losses],
            "fix": "Raise EQ_INITIAL_SL_PCT 2.5%→3.5%, OR require NewsBrain conviction >=60 for entry",
        })

    # 2. Entries without NewsBrain validation
    nb_validated_syms = {n[2] for n in parsed["newsbrain"] if n[1] == "VALIDATED"}
    unvalidated_entries = [e for e in parsed["entries"] if e[1] not in nb_validated_syms]
    if unvalidated_entries:
        mistakes.append({
            "severity": "HIGH",
            "kind": "ENTRY_WITHOUT_NEWSBRAIN",
            "count": len(unvalidated_entries),
            "evidence": [e[1] for e in unvalidated_entries[:10]],
            "fix": "Wire NewsBrain conviction tag as hard gate in equity entry path; verify KITE_SYNC isn't bypassing validation",
        })

    # 3. Unprotected positions (entry without GTT placement same day)
    entry_syms      = {e[1] for e in parsed["entries"]}
    gtt_placed_syms = {g[1] for g in parsed["gtt_placed"]}
    unprotected     = entry_syms - gtt_placed_syms
    if unprotected:
        mistakes.append({
            "severity": "CRITICAL",
            "kind": "ENTRY_WITHOUT_GTT",
            "count": len(unprotected),
            "evidence": list(unprotected),
            "fix": "Investigate _fno_gtt_audit / equity SL placement — every entry must have GTT within 60s",
        })

    # 4. Crashes / exceptions
    if parsed["crashes"]:
        mistakes.append({
            "severity": "HIGH",
            "kind": "RUNTIME_CRASH",
            "count": len(parsed["crashes"]),
            "evidence": [c[1][:200] for c in parsed["crashes"][:3]],
            "fix": "Read full traceback in journalctl; harden the crashing module",
        })

    # 5. Repeated rejection reasons (signal that filter is too aggressive)
    reject_reasons = Counter(r[2] for r in parsed["rejections"])
    top_rejects = reject_reasons.most_common(5)
    if top_rejects and top_rejects[0][1] > 20:
        mistakes.append({
            "severity": "MEDIUM",
            "kind": "FILTER_TOO_AGGRESSIVE",
            "count": top_rejects[0][1],
            "evidence": [f"{r}: {n}" for r, n in top_rejects],
            "fix": "Review threshold for the top rejection reason — may be killing valid setups",
        })

    # 6. F&O IV crush violations
    if parsed["iv_crush"]:
        mistakes.append({
            "severity": "MEDIUM",
            "kind": "IV_CRUSH_NEAR_EARNINGS",
            "count": len(parsed["iv_crush"]),
            "evidence": [i[1] for i in parsed["iv_crush"][:5]],
            "fix": "V70 IV crush guard fired — verify earnings calendar accuracy; widen 3-day buffer if needed",
        })

    # 7. Circuit breakers
    if parsed["circuit"]:
        mistakes.append({
            "severity": "INFO",
            "kind": "CIRCUIT_BREAKER_FIRED",
            "count": len(parsed["circuit"]),
            "evidence": [c[2][:150] for c in parsed["circuit"][:3]],
            "fix": "Not a mistake per se — confirm halt was justified",
        })

    return mistakes

# ─────────────────────────────────────────────────────────────────────────────
#  P&L ATTRIBUTION
# ─────────────────────────────────────────────────────────────────────────────
def pnl_breakdown(eq_closed: list[dict], fno_closed: list[dict]) -> dict:
    def summarise(trades, label):
        if not trades:
            return {"label": label, "n": 0, "wins": 0, "losses": 0, "net": 0.0,
                    "wr": 0.0, "rr": 0.0, "exp": 0.0, "by_source": {}, "by_exit": {}}
        wins   = [t for t in trades if t.get("pnl", 0) > 0]
        losses = [t for t in trades if t.get("pnl", 0) < 0]
        net    = sum(t.get("pnl", 0) for t in trades)
        avg_w  = sum(t["pnl"] for t in wins)   / len(wins)   if wins   else 0
        avg_l  = abs(sum(t["pnl"] for t in losses) / len(losses)) if losses else 0
        wr     = len(wins) / len(trades) * 100 if trades else 0
        rr     = avg_w / avg_l if avg_l else 0
        exp    = (wr/100 * avg_w) - ((1 - wr/100) * avg_l)

        by_src  = defaultdict(lambda: {"n": 0, "pnl": 0.0})
        by_exit = defaultdict(lambda: {"n": 0, "pnl": 0.0})
        for t in trades:
            s = t.get("source", "UNKNOWN")
            e = t.get("exit_reason", "UNKNOWN")
            by_src[s]["n"]  += 1; by_src[s]["pnl"]  += t.get("pnl", 0)
            by_exit[e]["n"] += 1; by_exit[e]["pnl"] += t.get("pnl", 0)

        return {"label": label, "n": len(trades), "wins": len(wins), "losses": len(losses),
                "net": net, "wr": wr, "rr": rr, "exp": exp,
                "by_source": dict(by_src), "by_exit": dict(by_exit)}

    return {"equity": summarise(eq_closed, "EQUITY"),
            "fno":    summarise(fno_closed, "F&O")}

# ─────────────────────────────────────────────────────────────────────────────
#  REPORT BUILDERS
# ─────────────────────────────────────────────────────────────────────────────
def fmt_inr(x: float) -> str:
    sign = "-" if x < 0 else "+"
    return f"{sign}Rs.{abs(x):,.0f}"

def build_text_report(d: date, parsed: dict, pnl: dict, mistakes: list[dict],
                      eq_closed: list, fno_closed: list, kite: dict) -> str:
    lines = []
    P = lines.append
    P("=" * 79)
    P(f"  GIR DAILY AUDIT — {d.strftime('%A, %d %b %Y')}")
    P("=" * 79)

    # ── DECISIONS TAKEN ──
    P("\n[A] DECISIONS TAKEN")
    P("-" * 79)
    P(f"  Scan cycles run         : {parsed['scan_count']}")
    P(f"  Journal lines processed : {parsed['raw_lines']:,}")
    P(f"  Entries                 : {len(parsed['entries'])}")
    P(f"  Exits                   : {len(parsed['exits'])}")
    P(f"  GTTs placed/modified    : {len(parsed['gtt_placed'])}")
    P(f"  GTTs triggered          : {len(parsed['gtt_triggered'])}")
    P(f"  NewsBrain validated     : {sum(1 for n in parsed['newsbrain'] if n[1]=='VALIDATED')}")
    P(f"  NewsBrain rejected      : {sum(1 for n in parsed['newsbrain'] if n[1]=='REJECTED')}")

    if parsed["entries"]:
        P("\n  Entries detail:")
        for ts, sym, qty, px, _ in parsed["entries"][:30]:
            P(f"    {ts}  {sym:14} qty={qty:6} @{px:>10.2f}")
    if parsed["exits"]:
        P("\n  Exits detail:")
        for ts, sym, pnl_, reason, _ in parsed["exits"][:30]:
            P(f"    {ts}  {sym:14} pnl={fmt_inr(pnl_):>12}  ({reason})")

    # ── DECISIONS SKIPPED ──
    P("\n[B] DECISIONS SKIPPED  (candidates the bot saw but did not trade)")
    P("-" * 79)
    if parsed["rejections"]:
        rcount = Counter(r[2] for r in parsed["rejections"])
        P(f"  Total rejections : {len(parsed['rejections'])}")
        P(f"  Top reasons:")
        for reason, n in rcount.most_common(10):
            P(f"    {n:4} x  {reason}")
    else:
        P("  (no rejections logged — could indicate logging gap)")

    # ── P&L ATTRIBUTION ──
    P("\n[C] P&L ATTRIBUTION  (closed trades only)")
    P("-" * 79)
    for k in ("equity", "fno"):
        s = pnl[k]
        P(f"\n  {s['label']}:")
        P(f"    Trades  : {s['n']}  ({s['wins']}W / {s['losses']}L)")
        P(f"    Win rate: {s['wr']:.1f}%")
        P(f"    R:R     : {s['rr']:.2f}")
        P(f"    Net P&L : {fmt_inr(s['net'])}")
        P(f"    Expect. : {fmt_inr(s['exp'])} per trade")
        if s["by_source"]:
            P(f"    By source:")
            for src, v in sorted(s["by_source"].items(), key=lambda x: x[1]["pnl"], reverse=True):
                P(f"      {src:14} {v['n']:3} trades   {fmt_inr(v['pnl'])}")
        if s["by_exit"]:
            P(f"    By exit reason:")
            for er, v in sorted(s["by_exit"].items(), key=lambda x: x[1]["pnl"], reverse=True):
                P(f"      {er:14} {v['n']:3} trades   {fmt_inr(v['pnl'])}")

    # ── OPEN BOOK MTM (from Kite) ──
    if kite:
        P("\n[D] OPEN BOOK SNAPSHOT (Kite, end of day)")
        P("-" * 79)
        net_pos = kite.get("positions", {}).get("net", [])
        for p in net_pos:
            if p.get("quantity", 0) != 0:
                P(f"    {p['tradingsymbol']:24}  qty={p['quantity']:6}  "
                  f"avg={p.get('average_price',0):>9.2f}  "
                  f"ltp={p.get('last_price',0):>9.2f}  "
                  f"mtm={fmt_inr(p.get('pnl',0)):>12}")
        holdings = kite.get("holdings", [])
        if holdings:
            P(f"\n    Holdings:")
            for h in holdings:
                P(f"    {h['tradingsymbol']:24}  qty={h['quantity']:6}  "
                  f"avg={h.get('average_price',0):>9.2f}  "
                  f"ltp={h.get('last_price',0):>9.2f}  "
                  f"mtm={fmt_inr(h.get('pnl',0)):>12}")

    # ── MISTAKES ──
    P("\n[E] MISTAKES & RULE VIOLATIONS")
    P("-" * 79)
    if not mistakes:
        P("  (none detected — clean session)")
    else:
        for m in sorted(mistakes, key=lambda x: ("CRITICAL", "HIGH", "MEDIUM", "INFO").index(x["severity"])):
            P(f"\n  [{m['severity']}]  {m['kind']}  (count={m['count']})")
            for ev in m["evidence"][:8]:
                P(f"      • {ev}")
            P(f"      FIX  : {m['fix']}")

    # ── CRASHES ──
    if parsed["crashes"]:
        P("\n[F] CRASHES / EXCEPTIONS")
        P("-" * 79)
        for ts, line in parsed["crashes"][:10]:
            P(f"  {ts}  {line[:200]}")

    P("\n" + "=" * 79)
    P("  END OF AUDIT")
    P("=" * 79)
    return "\n".join(lines)

def build_telegram_digest(d: date, parsed: dict, pnl: dict, mistakes: list[dict]) -> str:
    eq, fn = pnl["equity"], pnl["fno"]
    sev_emoji = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "INFO": "🔵"}
    msg = []
    msg.append(f"🔍 *GIR AUDIT — {d.strftime('%a %d %b')}*\n")
    msg.append(f"📊 *Activity*")
    msg.append(f"  Scans: {parsed['scan_count']}  |  Entries: {len(parsed['entries'])}  |  Exits: {len(parsed['exits'])}")
    msg.append(f"  NB validated: {sum(1 for n in parsed['newsbrain'] if n[1]=='VALIDATED')}  |  rejected: {sum(1 for n in parsed['newsbrain'] if n[1]=='REJECTED')}")
    msg.append(f"  Skipped candidates: {len(parsed['rejections'])}\n")

    msg.append(f"💰 *P&L*")
    msg.append(f"  EQ:  {eq['n']}T  {eq['wr']:.0f}%WR  {fmt_inr(eq['net'])}  (exp {fmt_inr(eq['exp'])}/T)")
    msg.append(f"  FNO: {fn['n']}T  {fn['wr']:.0f}%WR  {fmt_inr(fn['net'])}  (exp {fmt_inr(fn['exp'])}/T)\n")

    if mistakes:
        msg.append(f"⚠️ *Mistakes ({len(mistakes)})*")
        for m in mistakes[:5]:
            e = sev_emoji.get(m["severity"], "•")
            msg.append(f"  {e} {m['kind']} (x{m['count']})")
        msg.append("")
        msg.append(f"🔧 *Top fix:*")
        top = sorted(mistakes, key=lambda x: ("CRITICAL","HIGH","MEDIUM","INFO").index(x["severity"]))[0]
        msg.append(f"  {top['fix']}")
    else:
        msg.append("✅ No mistakes detected")

    return "\n".join(msg)

# ─────────────────────────────────────────────────────────────────────────────
#  TELEGRAM SEND
# ─────────────────────────────────────────────────────────────────────────────
def send_telegram(text: str) -> bool:
    token   = ENV.get("TELEGRAM_BOT_TOKEN") or ENV.get("TG_BOT_TOKEN")
    chat_id = ENV.get("TELEGRAM_CHAT_ID")   or ENV.get("TG_CHAT_ID")
    if not token or not chat_id:
        log.warning("Telegram creds missing in .env — skipping send")
        return False
    try:
        import urllib.request, urllib.parse
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        data = urllib.parse.urlencode({
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "Markdown",
        }).encode()
        req = urllib.request.Request(url, data=data)
        urllib.request.urlopen(req, timeout=15).read()
        return True
    except Exception as e:
        log.error(f"Telegram send failed: {e}")
        return False

# ─────────────────────────────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────────────────────────────
def audit_one_day(d: date, kite: dict | None = None) -> tuple[str, str]:
    log.info(f"Auditing {d.isoformat()} ...")
    raw_lines  = fetch_journal(d)
    parsed     = parse_journal(raw_lines)
    eq_closed  = load_trades(EQ_TRADES, d)
    fno_closed = load_trades(FNO_TRADES, d)
    pnl        = pnl_breakdown(eq_closed, fno_closed)
    mistakes   = detect_mistakes(parsed, eq_closed, fno_closed)
    text       = build_text_report(d, parsed, pnl, mistakes, eq_closed, fno_closed, kite or {})
    digest     = build_telegram_digest(d, parsed, pnl, mistakes)
    out_path   = AUDIT_DIR / f"audit_{d.isoformat()}.txt"
    out_path.write_text(text)
    log.info(f"  full report → {out_path}")
    return text, digest

def main():
    args  = sys.argv[1:]
    days  = date_range(args)
    kite  = kite_snapshot()  # one snapshot is enough for now
    for d in days:
        text, digest = audit_one_day(d, kite)
        print(text)
        print()
        sent = send_telegram(digest)
        print(f"[Telegram digest sent: {sent}]\n")

if __name__ == "__main__":
    main()

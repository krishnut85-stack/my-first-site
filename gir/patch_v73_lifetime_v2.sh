#!/bin/bash
# PATCH_V73_LIFETIME_REPORTER v2 — simplified
# Adds since-inception P&L summary class.
# Wires into existing weekly attribution send (Sunday) so going forward you get
# both weekly + lifetime reports together. For one-shot trigger: a flag file
# /home/globalbot/data/.lifetime_pending fires the report on next tick.

set -e
FILE=/home/globalbot/gir.py
BACKUP=/home/globalbot/gir.py.bak_v73v2_$(date +%Y%m%d_%H%M%S)
cp "$FILE" "$BACKUP"
echo "Backup: $BACKUP"

python3 << 'PYEOF'
import sys

path = "/home/globalbot/gir.py"
with open(path) as f:
    code = f.read()

# ---------- ANCHOR 1: insert LifetimeReporter class before generate_weekly_attribution ----------
anchor1 = '''    @staticmethod
    def generate_weekly_attribution(equity_module, fno_module):'''

if code.count(anchor1) != 1:
    print(f"ANCHOR 1 matched {code.count(anchor1)} times — must be 1. Aborting.")
    sys.exit(1)

new_class = '''    @staticmethod
    def generate_lifetime_report(equity_module, fno_module):
        """PATCH_V73: Since-inception performance summary."""
        try:
            from datetime import datetime

            def _load(module):
                try:
                    return load_json(module._trades_file, {"trades": []}).get("trades", [])
                except Exception:
                    return []

            def _parse_dt(s):
                try:
                    return datetime.fromisoformat(str(s).replace("Z","")).replace(tzinfo=None)
                except Exception:
                    return None

            def _section(label, trades):
                closed = [t for t in trades if t.get("pnl") is not None and t.get("exit_time")]
                if not closed:
                    return f"*{label}*: No closed trades\\n"
                pnls = [t.get("pnl", 0) for t in closed]
                wins = [p for p in pnls if p > 0]
                losses = [p for p in pnls if p < 0]
                total = sum(pnls)
                wr = (len(wins) / len(closed) * 100) if closed else 0
                avg_w = (sum(wins) / len(wins)) if wins else 0
                avg_l = (sum(losses) / len(losses)) if losses else 0
                pf = (sum(wins) / abs(sum(losses))) if losses and sum(losses) != 0 else 0
                # max drawdown on cumulative curve
                sorted_t = sorted(closed, key=lambda t: t.get("exit_time",""))
                running = 0; peak = 0; max_dd = 0
                for t in sorted_t:
                    running += t.get("pnl", 0)
                    if running > peak: peak = running
                    dd = peak - running
                    if dd > max_dd: max_dd = dd
                dates = [d for d in (_parse_dt(t.get("exit_time")) for t in closed) if d]
                first = min(dates).strftime("%Y-%m-%d") if dates else "?"
                last  = max(dates).strftime("%Y-%m-%d") if dates else "?"
                days = ((max(dates) - min(dates)).days + 1) if len(dates) >= 2 else 1
                best = max(closed, key=lambda t: t.get("pnl", 0))
                worst = min(closed, key=lambda t: t.get("pnl", 0))
                lines = [
                    f"*{label}*",
                    f"Period: {first} to {last} ({days}d)",
                    f"Trades: {len(closed)} | {len(wins)}W / {len(losses)}L | WR {wr:.0f}%",
                    f"Total P&L: Rs.{total:+,.0f}",
                    f"Avg W: Rs.{avg_w:+,.0f} | Avg L: Rs.{avg_l:+,.0f} | PF: {pf:.2f}",
                    f"Max DD: Rs.{max_dd:,.0f}",
                    f"Best: {best.get('symbol', best.get('tradingsymbol','?'))} Rs.{best.get('pnl',0):+,.0f}",
                    f"Worst: {worst.get('symbol', worst.get('tradingsymbol','?'))} Rs.{worst.get('pnl',0):+,.0f}",
                ]
                # by source
                by_src = {}
                for t in closed:
                    src = (t.get("source") or "UNKNOWN").split("|")[0].split("(")[0].strip()[:20]
                    if src not in by_src:
                        by_src[src] = {"n":0, "w":0, "pnl":0.0}
                    by_src[src]["n"] += 1
                    by_src[src]["pnl"] += t.get("pnl", 0)
                    if t.get("pnl", 0) > 0: by_src[src]["w"] += 1
                if by_src:
                    lines.append("By source:")
                    for src, s in sorted(by_src.items(), key=lambda x: -x[1]["pnl"]):
                        wr_s = (s["w"]/s["n"]*100) if s["n"] else 0
                        lines.append(f"  {src}: n={s['n']} WR={wr_s:.0f}% Rs.{s['pnl']:+,.0f}")
                return "\\n".join(lines) + "\\n"

            eq = _load(equity_module)
            fno = _load(fno_module)
            msg = ["LIFETIME PERFORMANCE REPORT", ""]
            msg.append(_section("EQUITY", eq))
            msg.append(_section("F&O", fno))
            all_closed = ([t for t in eq if t.get("pnl") is not None and t.get("exit_time")] +
                          [t for t in fno if t.get("pnl") is not None and t.get("exit_time")])
            if all_closed:
                total_combined = sum(t.get("pnl", 0) for t in all_closed)
                msg.append(f"*COMBINED P&L: Rs.{total_combined:+,.0f}* ({len(all_closed)} trades)")
            return "\\n".join(msg)
        except Exception as e:
            return f"Lifetime report error: {e}"


    @staticmethod
    def check_lifetime_flag(equity_module, fno_module):
        """PATCH_V73: Polls /home/globalbot/data/.lifetime_pending; if exists,
        sends lifetime report and deletes flag. Called from main scheduler."""
        try:
            flag = DATA_DIR / ".lifetime_pending"
            if flag.exists():
                flag.unlink()
                rpt = EODReporter.generate_lifetime_report(equity_module, fno_module)
                send_telegram(rpt, silent=False)
                log.info("[PATCH_V73] one-shot lifetime report sent")
        except Exception as e:
            log.error(f"[PATCH_V73] flag-trigger failed: {e}")


    @staticmethod
    def generate_weekly_attribution(equity_module, fno_module):'''

code = code.replace(anchor1, new_class)

# ---------- ANCHOR 2: wire the flag-poll into the same place where weekly fires ----------
# Use the existing _wk_report line as anchor — that block runs inside the main scheduler
anchor2 = '_wk_report = EODReporter.generate_weekly_attribution(equity, fno)'
if code.count(anchor2) != 1:
    print(f"ANCHOR 2 matched {code.count(anchor2)} times — must be 1. Aborting.")
    sys.exit(1)

# Find indentation
idx = code.index(anchor2)
line_start = code.rfind("\n", 0, idx) + 1
indent = code[line_start:idx]

# After weekly fires, also fire lifetime
new_block = (anchor2 +
             "\n" + indent + "# PATCH_V73: lifetime report after weekly attribution" +
             "\n" + indent + "try:" +
             "\n" + indent + "    _life_rpt = EODReporter.generate_lifetime_report(equity, fno)" +
             "\n" + indent + "    send_telegram(_life_rpt, silent=False)" +
             "\n" + indent + "except Exception as _le:" +
             "\n" + indent + "    log.error(f'[PATCH_V73] weekly lifetime send failed: {_le}')")
code = code.replace(anchor2, new_block)

# ---------- ANCHOR 3: poll the flag from the EOD reporter (runs every minute) ----------
# Anchor on the EOD report invocation at line 6242: report = EODReporter.generate_equity_report(self)
anchor3 = 'report = EODReporter.generate_equity_report(self)'
if code.count(anchor3) != 1:
    print(f"ANCHOR 3 matched {code.count(anchor3)} times — must be 1. Aborting.")
    sys.exit(1)

# We won't insert there — instead, find a tick-frequency anchor in main loop.
# Simpler: piggyback on the F&O GTT audit which runs every 10s.
# Even simpler: find the line that does periodic stuff. The gap-status seems
# to be checked every minute. Let's just hook into the main while-loop time.sleep.
# Actually — simplest: hook into the same per-minute check as the weekly.
# That's already happening, so for one-shot we hook it into a more frequent
# place. Let's use the same minute-tick that the EOD uses.

# Find: look for a heartbeat or sleep loop
import re
# Find "time.sleep(60)" as the main-loop anchor
sleep_anchors = list(re.finditer(r'(\n[ \t]+)time\.sleep\((\d+)\)', code))
if sleep_anchors:
    # Pick the longest sleep (60s = main loop, not 1s ticks)
    main_sleep = max(sleep_anchors, key=lambda m: int(m.group(2)))
    sleep_indent = main_sleep.group(1).lstrip("\n")
    sleep_text = main_sleep.group(0).lstrip("\n")
    insert_pos = main_sleep.start() + 1  # after the leading \n

    poll_block = (sleep_indent + "# PATCH_V73: poll lifetime flag (one-shot manual trigger)\n" +
                  sleep_indent + "try:\n" +
                  sleep_indent + "    EODReporter.check_lifetime_flag(equity, fno)\n" +
                  sleep_indent + "except Exception:\n" +
                  sleep_indent + "    pass\n")
    code = code[:insert_pos] + poll_block + code[insert_pos:]
    print("PATCH_V73: flag-poll installed at main-loop sleep anchor")
else:
    print("WARNING: no time.sleep anchor found; one-shot flag will only fire on Sunday.")

# Write
with open(path, "w") as f:
    f.write(code)

# Compile check
import py_compile
try:
    py_compile.compile(path, doraise=True)
    print("SYNTAX: CLEAN")
except py_compile.PyCompileError as e:
    print(f"SYNTAX ERROR: {e}")
    sys.exit(1)

print("PATCH_V73_LIFETIME v2: applied")
PYEOF

echo ""
echo "=== Verification ==="
grep -n "PATCH_V73\|generate_lifetime_report\|check_lifetime_flag" /home/globalbot/gir.py | head -10

echo ""
echo "=== Set flag, restart, watch for lifetime report ==="
touch /home/globalbot/data/.lifetime_pending
systemctl restart globaleye
sleep 8
systemctl status globaleye --no-pager | head -8

echo ""
echo "=== Watching 120s for lifetime report ==="
timeout 120 journalctl -u globaleye -f --no-pager | grep -iE "PATCH_V73|lifetime|ERROR|Traceback" || echo "Watch ended"

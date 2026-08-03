#!/bin/bash
# PATCH_V73_LIFETIME_REPORTER
# Add since-inception P&L reporter. Sends to Telegram every Sunday after weekly
# attribution. Also fires on startup if /home/globalbot/data/.lifetime_pending
# flag file exists (one-shot manual trigger).

set -e
FILE=/home/globalbot/gir.py
BACKUP=/home/globalbot/gir.py.bak_v73_$(date +%Y%m%d_%H%M%S)

cp "$FILE" "$BACKUP"
echo "Backup: $BACKUP"

python3 << 'PYEOF'
import sys, re

path = "/home/globalbot/gir.py"
with open(path) as f:
    code = f.read()

# ---------- ANCHOR 1: insert LifetimeReporter class after EODReporter ----------
# Anchor on the @staticmethod marker before generate_weekly_attribution
anchor1 = '''    @staticmethod
    def generate_weekly_attribution(equity_module, fno_module):'''

new_class_block = '''
# ══════════════════════════════════════════════════════════════
#  PATCH_V73: LifetimeReporter — since-inception P&L summary
#  Reads equity_trades.json + fno_trades.json (no time cutoff).
#  Triggered weekly (Sunday 09:00 after weekly attribution) and
#  on-demand via /home/globalbot/data/.lifetime_pending flag.
# ══════════════════════════════════════════════════════════════

class LifetimeReporter:
    """Generates since-inception performance report for Telegram."""

    @staticmethod
    def generate(equity_module, fno_module):
        try:
            from datetime import datetime

            def _load_trades(module):
                try:
                    data = load_json(module._trades_file, {"trades": []})
                    return data.get("trades", [])
                except Exception:
                    return []

            def _parse_dt(s):
                try:
                    return datetime.fromisoformat(str(s).replace("Z","")).replace(tzinfo=None)
                except Exception:
                    return None

            def _stats(trades, label):
                # only closed trades with non-null pnl
                closed = [t for t in trades if t.get("pnl") is not None and t.get("exit_time")]
                if not closed:
                    return f"*{label}*: No closed trades yet\\n"
                pnls = [t.get("pnl", 0) for t in closed]
                wins = [p for p in pnls if p > 0]
                losses = [p for p in pnls if p < 0]
                total = sum(pnls)
                wr = (len(wins) / len(closed) * 100) if closed else 0
                avg_w = (sum(wins) / len(wins)) if wins else 0
                avg_l = (sum(losses) / len(losses)) if losses else 0
                pf = (sum(wins) / abs(sum(losses))) if losses and sum(losses) != 0 else 0

                # max drawdown on cumulative equity curve (sorted by exit_time)
                sorted_t = sorted(closed, key=lambda t: t.get("exit_time",""))
                running = 0; peak = 0; max_dd = 0
                for t in sorted_t:
                    running += t.get("pnl", 0)
                    if running > peak: peak = running
                    dd = peak - running
                    if dd > max_dd: max_dd = dd

                # date range
                dates = [_parse_dt(t.get("exit_time")) for t in closed]
                dates = [d for d in dates if d]
                first = min(dates).strftime("%Y-%m-%d") if dates else "?"
                last  = max(dates).strftime("%Y-%m-%d") if dates else "?"
                days_active = (max(dates) - min(dates)).days + 1 if len(dates) >= 2 else 1

                best = max(closed, key=lambda t: t.get("pnl", 0))
                worst = min(closed, key=lambda t: t.get("pnl", 0))

                lines = [
                    f"*{label}*",
                    f"Period: {first} → {last} ({days_active}d)",
                    f"Trades: {len(closed)} closed | {len(wins)}W / {len(losses)}L | WR {wr:.0f}%",
                    f"Total P&L: Rs.{total:+,.0f}",
                    f"Avg W: Rs.{avg_w:+,.0f} | Avg L: Rs.{avg_l:+,.0f} | PF: {pf:.2f}",
                    f"Max DD: Rs.{max_dd:,.0f}",
                    f"Best: {best.get('symbol', best.get('tradingsymbol','?'))} Rs.{best.get('pnl',0):+,.0f}",
                    f"Worst: {worst.get('symbol', worst.get('tradingsymbol','?'))} Rs.{worst.get('pnl',0):+,.0f}",
                ]

                # by-source attribution
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

            eq_trades = _load_trades(equity_module)
            fno_trades = _load_trades(fno_module)

            msg = ["📊 *LIFETIME PERFORMANCE REPORT*", ""]
            msg.append(_stats(eq_trades, "EQUITY"))
            msg.append(_stats(fno_trades, "F&O"))

            # combined
            all_closed = ([t for t in eq_trades if t.get("pnl") is not None and t.get("exit_time")] +
                          [t for t in fno_trades if t.get("pnl") is not None and t.get("exit_time")])
            if all_closed:
                total_combined = sum(t.get("pnl", 0) for t in all_closed)
                msg.append(f"*COMBINED P&L: Rs.{total_combined:+,.0f}* ({len(all_closed)} trades)")

            return "\\n".join(msg)
        except Exception as e:
            return f"Lifetime report error: {e}"


    @staticmethod
'''

if anchor1 not in code:
    print("ANCHOR 1 NOT FOUND — aborting.")
    sys.exit(1)
if code.count(anchor1) != 1:
    print(f"ANCHOR 1 matched {code.count(anchor1)} times — must be 1. Aborting.")
    sys.exit(1)

code = code.replace(anchor1, new_class_block + "    def generate_weekly_attribution(equity_module, fno_module):")

# ---------- ANCHOR 2: wire it into the Sunday weekly attribution send site ----------
# At line 9962: _wk_report = EODReporter.generate_weekly_attribution(equity, fno)
# We insert immediately after that line a call to LifetimeReporter + send.

anchor2 = '_wk_report = EODReporter.generate_weekly_attribution(equity, fno)'

if anchor2 not in code:
    print("ANCHOR 2 NOT FOUND — aborting.")
    sys.exit(1)
if code.count(anchor2) != 1:
    print(f"ANCHOR 2 matched {code.count(anchor2)} times — must be 1. Aborting.")
    sys.exit(1)

# Find the indentation of anchor2 line so we match it
anchor2_idx = code.index(anchor2)
line_start = code.rfind("\n", 0, anchor2_idx) + 1
indent = code[line_start:anchor2_idx]

new_block_2 = (anchor2 +
               "\n" + indent + "# PATCH_V73: lifetime report after weekly" +
               "\n" + indent + "try:" +
               "\n" + indent + "    _life_report = LifetimeReporter.generate(equity, fno)" +
               "\n" + indent + "    send_telegram(_life_report, silent=False)" +
               "\n" + indent + "except Exception as _le:" +
               "\n" + indent + "    log.error(f'[PATCH_V73] lifetime report failed: {_le}')")

code = code.replace(anchor2, new_block_2)

# ---------- ANCHOR 3: one-shot startup trigger via flag file ----------
# Find the bot startup banner area. We look for the systemd Started message
# OR a clearly-startup log line. Safest anchor: where __main__ runs or first
# log.info after services init. Use the "[SECTOR_MAP] total=" log we saw at startup.

# Actually simpler: hook into the main loop's first iteration. Look for the
# main run() method's start. We'll attach via a once-per-process flag.
# Use the FnoModule and EquityModule init-complete moment.

# Strategy: insert a tick-time check that triggers once if flag file exists.
# Anchor on "is_market_hours()" pattern in the main scheduler is too risky.
# Instead, just hook into the same block as the weekly trigger — extend it
# to also fire if the flag exists, regardless of weekday/time.

# Look for the WEEKLY trigger condition (Sunday 09:00 check).
# Find the if-block that gates _wk_report. We insert a flag check before it.

# Search for the surrounding scheduler condition
import re
# Find the line just before our anchor2 insert — it should be a Sunday/time gate
m = re.search(r'(if\s+[^\n]{0,200}weekday[^\n]{0,200}:\s*\n[^\n]*\n[^\n]*' + re.escape("_wk_report = EODReporter.generate_weekly_attribution"), code)
# That regex is brittle. Skip auto-insertion of one-shot trigger via main loop.
# Use a simpler approach: a startup-time check inside __init__ or run()-start.

# Add to module-level startup. Search for "def main(" or the top-level startup.
# Safest: hook into the EquityModule.__init__ or wherever bot announces ready.
# Actually the simplest: poll the flag inside the same minute-loop tick.
# We'll add a separate check that fires if flag exists, runs once, deletes flag.

# Insert the flag-check block near where weekly attribution fires (it's inside
# the main scheduler tick loop — perfect place).
# Anchor: just before the 'if' that gates the weekly report.

# Find the gate condition by searching backward from anchor2 for an "if" statement
gate_search_start = max(0, code.index(new_block_2) - 800)
gate_window = code[gate_search_start:code.index(new_block_2)]
# Find the most recent "if " in the window that controls the weekly block
gate_match = list(re.finditer(r'\n(\s*)if\s+[^\n]+:\s*\n', gate_window))
if not gate_match:
    print("WARNING: could not locate weekly gate; skipping one-shot startup trigger.")
    print("PATCH_V73: weekly trigger added; one-shot flag NOT installed.")
else:
    last_gate = gate_match[-1]
    gate_indent = last_gate.group(1)
    gate_pos_in_code = gate_search_start + last_gate.start() + 1  # +1 for the \n

    # Build the flag-check block at same indent as the gate
    flag_block = (
        gate_indent + "# PATCH_V73: one-shot lifetime report on flag\n" +
        gate_indent + "try:\n" +
        gate_indent + "    _flag = DATA_DIR / '.lifetime_pending'\n" +
        gate_indent + "    if _flag.exists():\n" +
        gate_indent + "        _flag.unlink()\n" +
        gate_indent + "        _life_report = LifetimeReporter.generate(equity, fno)\n" +
        gate_indent + "        send_telegram(_life_report, silent=False)\n" +
        gate_indent + "        log.info('[PATCH_V73] one-shot lifetime report sent (flag triggered)')\n" +
        gate_indent + "except Exception as _fe:\n" +
        gate_indent + "    log.error(f'[PATCH_V73] flag-trigger failed: {_fe}')\n"
    )

    code = code[:gate_pos_in_code] + flag_block + code[gate_pos_in_code:]
    print("PATCH_V73: one-shot flag trigger installed.")

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

print("PATCH_V73_LIFETIME_REPORTER: applied successfully")
PYEOF

# Verify
echo ""
echo "=== Verification ==="
grep -n "PATCH_V73\|class LifetimeReporter\|LifetimeReporter\." /home/globalbot/gir.py | head -10

echo ""
echo "=== Restart + trigger one-shot lifetime report ==="
touch /home/globalbot/data/.lifetime_pending
echo "Flag created: /home/globalbot/data/.lifetime_pending"
systemctl restart globaleye
sleep 8
systemctl status globaleye --no-pager | head -10

echo ""
echo "=== Watching 90s for lifetime report send ==="
timeout 90 journalctl -u globaleye -f --no-pager | grep -iE "PATCH_V73|lifetime|LifetimeReporter|ERROR|Traceback" || echo "Watch ended"

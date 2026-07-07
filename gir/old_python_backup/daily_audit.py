#!/usr/bin/env python3
"""
Griffin Bot Daily Audit — April 6, 2026
Checks ALL bot activity, Kite positions, GTTs, orders, P&L
"""
import json, os, sys
from datetime import datetime

DATA_DIR = "/home/globalbot/data"

print("=" * 70)
print("  GRIFFIN BOT DAILY AUDIT — April 6, 2026")
print("=" * 70)

# 1. Bot Version & Status
print("\n📋 BOT STATUS")
print("-" * 40)
os.system('grep "VERSION" /home/globalbot/griffin_bot.py | head -1')
os.system('ps aux | grep "griffin_bot" | grep -v grep | awk \'{print "PID:", $2, "CPU:", $3"%", "MEM:", $4"%", "Started:", $9}\'')

# 2. All orders placed today
print("\n📊 ORDERS PLACED TODAY")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "ORDER PLACED\|BUY.*x[0-9]\|LIVE SWING ENTRY\|F&O.*placed" | head -20')

# 3. GTT activity
print("\n🛡️ GTT ACTIVITY TODAY")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "GTT OCO\|GTT.*trigger\|GTT.*CAPPED\|GTT.*update\|GTT.*modify\|GTT.*status" | head -20')

# 4. Exits / SL triggered
print("\n🚪 EXITS & SL TRIGGERS")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "EXIT\|SL.*trigger\|SOLD\|position.*closed\|exited\|SYNC.*removed\|SYNC.*triggered" | head -20')

# 5. Pipeline activity
print("\n⚡ PIPELINE ACTIVITY (all cycles)")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "PIPELINE TRIGGER\|PIPELINE.*QUEUE\|RANK done\|PIPELINE.*EXECUTE\|PIPELINE.*DONE\|Fed.*pipeline" | head -30')

# 6. F&O attempts
print("\n📈 F&O ATTEMPTS")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "F&O.*placed\|F&O.*reject\|F&O.*skip\|FNOTrader\|INDEX F&O\|MOONSHOT SCAN\|INDEPENDENT SCAN\|F&O SCAN:" | head -20')

# 7. Oversold bounces
print("\n📉 OVERSOLD BOUNCE DETECTIONS")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "OVERSOLD BOUNCE\|CONFIRMED.*GREEN\|CONFIRMED.*BOUNCE" | head -15')

# 8. Errors
print("\n❌ ERRORS & WARNINGS")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "ERROR\|TRACEBACK\|EXCEPTION\|CRITICAL\|BLOCKED_RISK\|CIRCUIT REJECT" | grep -v "Suppressed\|debug\|GTT modify" | tail -15')

# 9. Current positions from bot book
print("\n💰 CURRENT POSITIONS (Bot Book)")
print("-" * 40)
for fname in ["paper_swing.json", "paper_equity.json"]:
    fpath = os.path.join(DATA_DIR, fname)
    if os.path.exists(fpath):
        try:
            with open(fpath) as f:
                d = json.load(f)
            positions = d.get("positions", {})
            available = d.get("available", 0)
            capital = d.get("capital", 0)
            print(f"\n  [{fname}] Capital: ₹{capital:,.0f} | Available: ₹{available:,.0f} | Positions: {len(positions)}")
            for sym, pos in positions.items():
                entry = pos.get("entry_price", 0)
                qty = pos.get("qty", 0)
                sl = pos.get("stop_loss", 0)
                t1 = pos.get("target1", 0)
                gtt = pos.get("gtt_id", "?")
                src = pos.get("source", "?")
                cost = pos.get("cost", 0)
                print(f"    {sym:15s} qty={qty:4d} entry=₹{entry:>8.2f} SL=₹{sl:>8.2f} T1=₹{t1:>8.2f} GTT={gtt} cost=₹{cost:,.0f} src={src}")
        except Exception as e:
            print(f"  Error reading {fname}: {e}")

# 10. F&O book
print("\n📊 F&O POSITIONS")
print("-" * 40)
for fname in ["paper_fno.json", "fno_book.json"]:
    fpath = os.path.join(DATA_DIR, fname)
    if os.path.exists(fpath):
        try:
            with open(fpath) as f:
                d = json.load(f)
            positions = d.get("positions", {})
            capital = d.get("capital", 0)
            available = d.get("available", 0)
            print(f"  [{fname}] Capital: ₹{capital:,.0f} | Available: ₹{available:,.0f} | Positions: {len(positions)}")
            for k, v in positions.items():
                print(f"    {k}: {v}")
        except Exception as e:
            print(f"  Error: {e}")

# 11. Telegram messages sent
print("\n📱 TELEGRAM MESSAGES SENT TODAY")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "telegram.*send\|MORNING_BRIEF\|EOD_PDF\|MIDDAY_PDF\|TRADE_EXECUTED\|send_telegram" | grep -v "def \|#\|import" | head -15')

# 12. Capital allocation history
print("\n💵 CAPITAL ALLOCATION (Three-Engine)")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "Pipeline capital\|Safe F&O\|Three.*Engine\|Eq=.*F&O=.*Moon=" | head -10')

# 13. Restarts today
print("\n🔄 BOT RESTARTS TODAY")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "LIVE TRADING MODE\|Autonomous Pipeline initialized\|v25\." | head -10')

# 14. Battle plans
print("\n🗺️ BATTLE PLANS TODAY")
print("-" * 40)
os.system('journalctl -u globaleye --no-pager --since "2026-04-06 00:00" | grep -i "BATTLE PLAN" | head -10')

print("\n" + "=" * 70)
print("  AUDIT COMPLETE")
print("=" * 70)

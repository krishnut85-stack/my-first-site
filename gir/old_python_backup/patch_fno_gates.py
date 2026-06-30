filepath = "/home/globalbot/griffin_bot.py"
with open(filepath, "r") as f:
    content = f.read()

changes = 0

# Patch line 14819: if is_fno and sym in FNOTrader.INSTRUMENTS:
old1 = "if is_fno and sym in FNOTrader.INSTRUMENTS:"
new1 = "if is_fno and sym in FNO_STOCKS:  # v25.6.1: use full 218 F&O universe"
if old1 in content:
    content = content.replace(old1, new1)
    changes += 1
    print(f"Patched: line ~14819 FNOTrader.INSTRUMENTS -> FNO_STOCKS")

# Patch line 15003: if ta_score >= 5 and is_fno and sym in FNOTrader.INSTRUMENTS:
old2 = "if ta_score >= 5 and is_fno and sym in FNOTrader.INSTRUMENTS:"
new2 = "if ta_score >= 5 and is_fno and sym in FNO_STOCKS:  # v25.6.1: full universe"
if old2 in content:
    content = content.replace(old2, new2)
    changes += 1
    print(f"Patched: line ~15003 FNOTrader.INSTRUMENTS -> FNO_STOCKS")

if changes == 0:
    print("ERROR: No patterns matched. Checking for variations...")
    import re
    for m in re.finditer(r'FNOTrader\.INSTRUMENTS', content):
        start = max(0, m.start()-80)
        print(f"  Found at pos {m.start()}: ...{content[start:m.end()+20]}...")
else:
    with open(filepath, "w") as f:
        f.write(content)
    print(f"\n{changes} patches applied. Restart with: systemctl restart globaleye")


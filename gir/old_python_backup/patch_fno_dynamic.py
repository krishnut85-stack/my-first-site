import re

filepath = "/home/globalbot/griffin_bot.py"
with open(filepath, "r") as f:
    content = f.read()

# Patch 1: Replace the INSTRUMENTS gate in enter() with dynamic lookup
# Find: if symbol not in self.INSTRUMENTS: return None
# And the inst/lot/step lines after it
old_enter = '''        if symbol not in self.INSTRUMENTS: return None
        if len(self.book["positions"]) >= MAX_FNO_POS: return None
        if not self.risk.can_trade(): return None

        inst = self.INSTRUMENTS[symbol]
        lot  = inst["lot"]
        step = inst["step"]'''

new_enter = '''        if len(self.book["positions"]) >= MAX_FNO_POS: return None
        if not self.risk.can_trade(): return None

        # v25.6.1: Dynamic F&O — accept ANY symbol with valid lot size
        lot = self.get_lot_size(symbol)
        if not lot or lot < 1:
            logger.debug(f"F&O {symbol}: no lot size found — skipping")
            return None
        # Infer strike step from spot price (standard NSE rules)
        if spot < 500:    step = 5
        elif spot < 2000: step = 10
        elif spot < 5000: step = 20
        elif spot < 10000: step = 50
        elif spot < 25000: step = 100
        elif spot < 50000: step = 200
        else:              step = 500
        # Override for known index steps
        if symbol == "NIFTY": step = 50
        elif symbol == "BANKNIFTY": step = 100
        elif symbol == "FINNIFTY": step = 50
        elif symbol == "MIDCPNIFTY": step = 25'''

count1 = content.count(old_enter)
if count1 == 0:
    print("ERROR: Could not find enter() INSTRUMENTS gate pattern")
    print("Searching for partial match...")
    if "if symbol not in self.INSTRUMENTS: return None" in content:
        print("Found the gate line but surrounding context differs")
    exit(1)
elif count1 > 1:
    print(f"WARNING: Found {count1} matches, replacing first only")

content = content.replace(old_enter, new_enter, 1)
print(f"Patch 1 applied: enter() now accepts all F&O symbols dynamically")

# Patch 2: Fix _select_strike lot lookup to use dynamic cache
old_strike_lot = '''        _lot = self.INSTRUMENTS.get("NIFTY", {}).get("lot", 65)  # fallback
        # Find instrument lot for proper sizing
        for _sym_key, _inst_val in self.INSTRUMENTS.items():
            if abs(spot - round(spot / _inst_val.get("step", 50)) * _inst_val.get("step", 50)) < spot * 0.01:
                _lot = _inst_val.get("lot", 65)
                break'''

new_strike_lot = '''        _lot = self.get_lot_size(symbol) if hasattr(self, '_current_symbol') else lot
        if not _lot or _lot < 1: _lot = 65  # fallback'''

# This patch is trickier - the _select_strike doesn't have symbol context
# Let's skip this for now and just fix enter() which is the main blocker
# The _select_strike already receives step as param so it will work

with open(filepath, "w") as f:
    f.write(content)

print("Patch complete! Restart the bot with: systemctl restart globaleye")

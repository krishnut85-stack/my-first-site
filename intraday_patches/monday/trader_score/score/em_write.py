#!/usr/bin/env python3
"""TRADER_CALLS_scored.json -> v2/data/trader_reads.json + a 'trader_reads' block in v2/data/event_memory.json (backup first)."""
import os, sys, json, shutil, datetime as dt

SCORED = sys.argv[1]
V2D = "/home/globalbot/intraday/v2/data"
EM = os.path.join(V2D, "event_memory.json")
TR = os.path.join(V2D, "trader_reads.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
now = dt.datetime.now(IST)

S = json.load(open(SCORED))
reads = S["reads"]
by = {r["id"]: r for r in reads}

def pick(r):
    return {"id": r["id"], "row": r["row"], "said_ist": r["said"], "read": r["name"] if isinstance(r["name"], str) else r["name"],
            "expected": r["want"], "side": r["ce_pe"], "from": "%s %s" % (r["entry_day"], r["entry_at"]),
            "move_to_close_pct": r["move_to_close"], "move_to_next_close_pct": r["move_to_next_close"],
            "nifty_to_close_pct": r["nifty"]["to_close"], "nifty_to_next_close_pct": r["nifty"]["to_next_close"],
            "vs_nifty_close": r["vs_nifty_close"], "vs_nifty_next": r["vs_nifty_next"],
            "sector": r.get("sector"), "vs_sector_close": r["vs_sector_close"], "vs_sector_next": r["vs_sector_next"],
            "main_horizon": r["primary"], "right_main": r["right_primary"], "right_close": r["right_close"], "right_next": r["right_next"],
            "beat_nifty_main": r["right_vs_nifty_primary"], "counted": r["counted"], "note": r.get("note")}

HR = S["hit_rate"]
def hr(side):
    h = HR[side]
    return {"right_main": h["right_primary"], "right_to_close": h["right_close"], "right_to_next_close": h["right_next"],
            "beat_nifty_main": h["right_vs_nifty_primary"]}

n1, n3 = by.get("N1"), by.get("N3")
block = {
    "source": "TRADER READ",
    "made": now.isoformat(timespec="minutes"),
    "label": "IDEA - NOT PROVEN (small n; EVENT_MEMORY D sample-size rules apply)",
    "what": "the trader's own short reads (a share / sector with a direction, a warning, a flagged headline), scored from the minute store and NSE closes",
    "rules": S["rules"],
    "hit_rate": {"CE": hr("CE"), "PE": hr("PE"),
                 "note": "CE and PE kept apart. 'right_main' = right side at the main horizon; 'beat_nifty_main' = beat NIFTY in his direction. "
                         "20 Nov reads have no next-day close until Mon 23 Nov."},
    "threads": [{
        "thread": "DEFENCE capex + institutional buying (20 Nov)",
        "chain": [
            {"when": "2026-11-19 (TV, his account)", "src": "CNBC-TV18", "what": "government expects ~20% higher defence capex",
             "verified": False, "desk_note": "20% matches the Nov 2025 (FY27) figure; latest ask (9 Oct 2026) 35%, 25% called realistic - not fresh"},
            {"when": "2026-11-18 (NSE bulk-deal file)", "src": "NSE bulk deals", "verified": True,
             "what": "AZAD (Azad Engineering, not F&O): Norges Bank (FII) 473,088 + ValueQuest funds 1,147,000 = 1,620,088 shares bought at 2,286 (headline: 2.51%; share count not checked); the promoter sold 3,500,000"},
            {"when": "2026-11-19 close", "src": "NSE bhavcopy", "verified": True, "what": "AZAD 2,318.9 -> 2,410.2 (+3.94%)"},
            {"when": "2026-11-19 ~22:45", "src": "Trade Brains article (his photo, 07:45)", "verified": True, "what": "'aerospace and defence stock jumps 4% after FIIs and DIIs buy 2.51% stake via bulk deal'"},
            {"when": "2026-11-20 07:45 / 08:05", "src": "TRADER READ", "what": "defence F&O shares UP; DIXON group UP"}],
        "outcome_20nov": {
            "defence_F&O_median_open_to_close_pct": n1 and n1["move_to_close"], "defence_from_thu_close_pct": n1 and n1.get("alt_to_close"),
            "defence_breadth_on_his_side": n1 and n1.get("breadth_right_close"),
            "nifty_open_to_close_pct": n1 and n1["nifty"]["to_close"], "defence_vs_nifty": n1 and n1["vs_nifty_close"],
            "AZAD_open_to_close_pct": n3 and n3["move_to_close"], "AZAD_from_thu_close_pct": n3 and n3.get("alt_to_close")}}],
    "reads": [pick(r) for r in reads],
    "full_table": "/home/globalbot/girdata/review/monday/TRADER_CALLS_scored.md (+ .json)",
}

json.dump(block, open(TR + ".tmp", "w"), indent=1, ensure_ascii=False, default=str)
os.replace(TR + ".tmp", TR)

bak = EM + ".bak" + now.strftime("%H%M")
shutil.copy2(EM, bak)
m = json.load(open(EM))
m["trader_reads"] = block
tmp = EM + ".tmp"
with open(tmp, "w") as f:
    json.dump(m, f, indent=1, ensure_ascii=False, default=str)
os.replace(tmp, EM)
print("wrote", TR, "and event_memory.json['trader_reads']; backup", bak)

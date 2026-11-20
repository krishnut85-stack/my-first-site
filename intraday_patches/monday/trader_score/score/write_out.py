#!/usr/bin/env python3
"""scored_raw.json -> TRADER_CALLS_scored.md / .json (+ trader_reads.json for EVENT_MEMORY)."""
import os, sys, json, datetime as dt
NOW = dt.datetime.now(dt.timezone(dt.timedelta(hours=5, minutes=30))).strftime("%H:%M")

SP = os.path.dirname(os.path.abspath(__file__))
OUTDIR = sys.argv[1] if len(sys.argv) > 1 else SP
R = json.load(open(os.path.join(SP, "scored_raw.json")))
reads = R["reads"]

def f(x, sign=True):
    if x is None:
        return "-"
    return ("%+.2f" % x) if sign else ("%.2f" % x)

def yn(x):
    return {True: "yes", False: "no", None: "-"}[x]

def rate(rows, key):
    v = [r[key] for r in rows if r[key] is not None]
    return sum(v), len(v)

def fmt_rate(h, n):
    return "%d/%d = %d%%" % (h, n, round(100 * h / n)) if n else "n=0"

counted = [r for r in reads if r["counted"]]
ce = [r for r in counted if r["ce_pe"] == "CE"]
pe = [r for r in counted if r["ce_pe"] == "PE"]
past = lambda rs: [r for r in rs if not str(r["row"]).startswith("20N")]

def rates(rs):
    return {k: dict(zip(("hits", "n"), rate(rs, k))) for k in ("right_primary", "right_close", "right_next", "right_vs_nifty_primary",
                                                               "right_vs_nifty_close", "right_vs_nifty_next")}
HR = {"CE": rates(ce), "PE": rates(pe), "CE_before_20nov": rates(past(ce)), "PE_before_20nov": rates(past(pe))}

L = []
P = L.append
P("# TRADER'S READS - scored (server, Fri 20 Nov 2026 after the close)")
P("")
P("Source list: design_v3/TRADER_CALLS.md (33 rows) + his 20 Nov 07:45 reads + his 19 Nov 14:44 call. Ideas only, never orders.")
P("")
P("## Hit rate - CE (expected up) and PE (expected down) kept apart")
P("")
P("| | CE (up) | PE (down) |")
P("|---|---|---|")
for k, lab in (("right_primary", "**Right side, main horizon** (the day's close from the time he said it; for #25 and #33 the next close, the day he named)"),
               ("right_close", "Right side, to that day's close"), ("right_next", "Right side, to the next day's close"),
               ("right_vs_nifty_primary", "Beat NIFTY in his direction, main horizon"),
               ("right_vs_nifty_close", "Beat NIFTY, to that day's close"), ("right_vs_nifty_next", "Beat NIFTY, to the next day's close")):
    P("| %s | %s | %s |" % (lab, fmt_rate(**{"h": HR["CE"][k]["hits"], "n": HR["CE"][k]["n"]}), fmt_rate(HR["PE"][k]["hits"], HR["PE"][k]["n"])))
P("| Main horizon, past reads only (before 20 Nov) | %s | %s |" % (fmt_rate(HR["CE_before_20nov"]["right_primary"]["hits"], HR["CE_before_20nov"]["right_primary"]["n"]),
                                                                   fmt_rate(HR["PE_before_20nov"]["right_primary"]["hits"], HR["PE_before_20nov"]["right_primary"]["n"])))
P("")
P("n = scored reads with a direction. Not counted: no direction (#3, #22, #26), conditional with no clean trigger (#21), too vague (#1). "
  "A sector / group read counts once, on the median of its F&O members (R49 basis); breadth is shown beside it. "
  "The 20 Nov reads have no next-day close yet (Mon 23 Nov) - those cells are '-' and the n is smaller.")
P("")
P("## The scored table")
P("")
P("Move % = from the price when he said it (in market hours: that minute's price; before the open or on a holiday / weekend: the next session's "
  "open) to that day's official close, and to the next session's close. 'alt' = the same move from the previous close (gap included). "
  "vs NIFTY = move minus NIFTY over the same window; vs sector = move minus the median of the share's sector F&O members (sectors.json). "
  "Right = the move is on his side (CE up, PE down).")
P("")
P("| # | Said (IST) | Read | CE/PE | From | Move to day close | Move to next close | alt (from prev close) day / next | NIFTY day / next | vs NIFTY day / next | Sector | vs sector day / next | Right? day / next | Counted | Note |")
P("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for r in reads:
    name = r["name"] if isinstance(r["name"], str) else ", ".join(r["name"])
    if r.get("breadth_right_close"):
        name += " (n=%d; on his side: %s day%s)" % (r["n"], r["breadth_right_close"], (", %s next" % r["breadth_right_next"]) if r.get("breadth_right_next") else "")
    frm = "%s %s" % (r["entry_day"][5:], r["entry_at"])
    alt = "%s / %s" % (f(r.get("alt_to_close")), f(r.get("alt_to_next_close"))) if r.get("alt_basis") else "-"
    sec = r.get("sector") or "-"
    right = "%s / %s" % (yn(r["right_close"]), yn(r["right_next"])) if r["want"] else "no direction"
    note = r.get("note") or ""
    if r.get("level"):
        lv = r["level"]
        if lv.get("kind") == "cap":
            note += " Closed below 1,100 on 16 Nov: %s." % yn(lv.get("close_below_cap_on_entry_day"))
        elif lv.get("kind") == "floor":
            note += " Floor 4,200 broken on %s." % (lv.get("broke_floor_on") or "no day to 20 Nov")
        else:
            note += " Level %s: %s." % (lv["rule"], ("first reached " + lv["first_day_reached"]) if lv.get("first_day_reached") else "not reached by 20 Nov")
    if r.get("range_after_to_20nov") and not r.get("level"):
        g = r["range_after_to_20nov"]; note += " Range after, to 20 Nov: %s-%s." % (g["low"], g["high"])
    if r.get("condition_check"):
        note += " Capital-goods median / ABB day %: " + "; ".join("%s %s / %s" % (c["day"][5:], f(c["capital_goods_median_day"]), f(c["ABB_day"])) for c in r["condition_check"]) + "."
    P("| %s | %s | %s | %s | %s | %s | %s | %s | %s / %s | %s / %s | %s | %s / %s | %s | %s | %s |" % (
        r["row"], r["said"], name, r["ce_pe"] or "-", frm, f(r["move_to_close"]), f(r["move_to_next_close"]), alt,
        f(r["nifty"]["to_close"]), f(r["nifty"]["to_next_close"]), f(r["vs_nifty_close"]), f(r["vs_nifty_next"]), sec,
        f(r["vs_sector_close"]), f(r["vs_sector_next"]), right, "yes" if r["counted"] else "no", note.replace("|", "/")))
P("")
P("## Pending")
if next(r for r in reads if r["id"] == "N3")["move_to_close"] is None:
  P("- **AZAD (20N-c)**: not F&O, so it is not in the 20 Nov minute fetch (463 F&O instruments) or the Kite daily top-up, and the NSE bhavcopy "
  "for 20 Nov was still not posted (polled every 5 min until %s IST, 404). Its row fills when the 20 Nov bhavcopy is read. Its 19 Nov jump is verified: 2,318.9 -> 2,410.2 (+3.94%%)." % NOW)
P("- **Next-day column of the 20 Nov reads**: Mon 23 Nov close.")
P("")
P("## Not scored")
P("- **#1 (Sat 7 Nov 16:32, LTCG cut for FIIs, NIFTY ~300 points up 'a few days back')**: too vague to score - no day is named, and it is his "
  "account of a move that had already happened, not a forecast.")
P("")
P("## Group members (the 20 Nov reads and #33)")
for r in reads:
    if len(r["members"]) > 1 and (str(r["row"]).startswith("20N") or r["row"] == 33):
        P("")
        P("**%s** - %s from %s %s" % (r["id"], r["name"], r["entry_day"], r["entry_at"]))
        P("")
        P("| Share | Entry | Move to day close | Move to next close |" + (" Own sector | Sector day |" if any("sector" in v for v in r["members"].values()) else ""))
        P("|---|---|---|---|" + ("---|---|" if any("sector" in v for v in r["members"].values()) else ""))
        for s, v in r["members"].items():
            extra = (" %s | %s |" % (v.get("sector"), f(v.get("sector_to_close")))) if "sector" in v else ""
            P("| %s | %s | %s | %s |%s" % (s, v["entry"], f(v["to_close"]), f(v["to_next_close"]), extra))
P("")
P("## Data")
srcs = R.get("sources", {})
P("- Closes / opens: NSE CM bhavcopy (nsearchives, downloaded after 15:35) for 5-19 Nov; 20 Nov from %s. Kite daily closes matched the "
  "bhavcopy on all 218 F&O shares checked for 19 Nov." % ", ".join(sorted(srcs.get("2026-11-20", ["-"]))))
P("- Intraday prices at the time he spoke: girdata/minute/<day>/<SYM>__eq.npz (bar open of that minute); NIFTY from NIFTY_50__ix.npz and its daily file.")
P("- Bulk deals: NSE bulk.csv / block.csv (19 Nov, downloaded today) and the desk's saved NSE bulk file for 18 Nov (intraday/data/instdeals/2026-11-18.json).")
P("- 10 Nov was an NSE holiday (Diwali-Balipratipada); 8 Nov (Sunday) was the Muhurat session.")
P("- Sector lists: /root/hist/sectors.json, F&O members only (F&O list of 19 Nov).")
md = "\n".join(L) + "\n"

out = {"made": dt.datetime.now(dt.timezone(dt.timedelta(hours=5, minutes=30))).isoformat(timespec="minutes"),
       "source": "TRADER READ", "label": "IDEA - NOT PROVEN (small n)", "hit_rate": HR,
       "rules": "main horizon = that day's close from the time he said it (pre-open / holiday / weekend = next session's open); #33 = the 20 Nov close; "
                "group reads = median of F&O members; vs NIFTY = move minus NIFTY over the same window",
       "reads": reads}
open(os.path.join(OUTDIR, "TRADER_CALLS_scored.md"), "w").write(md)
json.dump(out, open(os.path.join(OUTDIR, "TRADER_CALLS_scored.json"), "w"), indent=1, default=str)
print(md[:3000])

#!/usr/bin/env python3
"""render.py <external_delays.json> [<after.json>] -> markdown tables (stdout): per source the 5 items, median / worst, extras."""
import json, sys


def fmt(x):
    return "-" if x is None else (("%.0f" % x) if isinstance(x, (int, float)) else str(x))


def table(src, v):
    out = ["", "### %s - target <= %s s" % (src, v.get("target_s")), ""]
    if v.get("error"):
        return out + ["analysis error: %s" % v["error"]]
    out += ["| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs target |",
            "|---|---|---|---|---|---|---|---|---|---|"]
    for i, it in enumerate(v.get("items") or [], 1):
        out.append("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (i, it["source"], it["item"].replace("|", "/"), it["source_time"], it["gir_seen"] or "-",
                                                                        it["page_seen"] or "not on the page", fmt(it.get("gir_lag_s")), fmt(it.get("page_after_gir_s")),
                                                                        fmt(it.get("delay_s")), it["verdict"]))
    s5 = v.get("stats5") or {}
    out += ["", "5 items: median **%s s**, worst **%s s**." % (fmt(s5.get("median")), fmt(s5.get("worst")))]
    for d in v.get("dead_or_missing") or []:
        if d:
            out.append("- DEAD / MISSING: %s" % d)
    return out


D = json.load(open(sys.argv[1]))
print("Window %s %s-%s IST, made %s" % (D["day"], D["window"][0], D["window"][1], D["made"]))
for src, v in D["sources"].items():
    print("\n".join(table(src, v)))

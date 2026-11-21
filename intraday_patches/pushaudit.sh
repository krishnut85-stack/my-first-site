#!/bin/bash
# pushaudit.sh - READ ONLY. WHO IS PUSHING / PULLING, measured: 1) the bulk / block deals GIR reads (how many named FII / DII, which big names it
# does NOT recognise) 2) the delivery footprint 3) the 12 pushers across every F&O share now (how often each lights up) 4) today's PUSH / PULL
# STARTED alerts - right or wrong 60 min later. Changes nothing.   bash pushaudit.sh [YYYY-MM-DD]
D=/home/globalbot/intraday; DAY=${1:-$(TZ=Asia/Kolkata date +%F)}
cd $D || exit 1
python3 - "$DAY" <<'PY'
import sys, os, re, json, glob, sqlite3, collections
sys.path.insert(0, "/home/globalbot/intraday")
day = sys.argv[1]
print("=== 1 · BULK / BLOCK DEALS (the only daily data that NAMES FII / DII buyers and sellers)")
try:
    import instflow
    fo = instflow.fo_set()
    files = sorted(f for f in glob.glob("data/instdeals/*.json") if not os.path.basename(f).startswith("deliv_"))[-30:]
    tot, cls, fo_cls, other_val = 0, collections.Counter(), collections.Counter(), collections.Counter()
    shares = collections.defaultdict(set)
    for f in files:
        for r in json.load(open(f)).get("rows") or []:
            tot += 1
            c = instflow.classify(r.get("who"))
            cls[c] += 1
            if r.get("s") in fo:
                fo_cls[c] += 1
                if c in ("FII", "DII"):
                    shares[c].add(r["s"])
                else:
                    other_val[r.get("who") or "?"] += r.get("q", 0) * r.get("p", 0) / 1e7
    print("   %d days (%s .. %s) · %d deals · FII %d · DII %d · other %d" % (len(files), os.path.basename(files[0])[:10] if files else "-",
          os.path.basename(files[-1])[:10] if files else "-", tot, cls["FII"], cls["DII"], cls["other"]))
    print("   on F&O shares: FII %d deals on %d shares · DII %d deals on %d shares · other %d" % (fo_cls["FII"], len(shares["FII"]), fo_cls["DII"], len(shares["DII"]), fo_cls["other"]))
    print("   the biggest 'other' names on F&O shares (an FII / DII GIR did not recognise would show here):")
    for n, v in other_val.most_common(15):
        print("     ₹%7.0f cr  %s" % (v, n[:70]))
    s = instflow.summary()
    for w in ("5", "30"):
        W = s["w"].get(w) or {}
        print("   window %s days: lists GIR keeps - FII buy %d · FII sell %d · DII buy %d · DII sell %d (each list cut at 12)" % (
            w, len(W.get("fii_buy") or []), len(W.get("fii_sell") or []), len(W.get("dii_buy") or []), len(W.get("dii_sell") or [])))
except Exception as ex:
    print("   not read: %s" % ex)
print("=== 2 · DELIVERY (shares bought and KEPT - 'big hands', FII or DII, not named)")
try:
    dl = instflow.deliv_signals()
    print("   day %s · %s F&O shares · big hands BUYING %d · SELLING %d" % (dl.get("day"), dl.get("n"), len(dl.get("acc") or []), len(dl.get("dist") or [])))
    print("   buying: " + " · ".join("%s %.1fx" % (r["s"], r["x"]) for r in (dl.get("acc") or [])[:10]))
    print("   selling: " + " · ".join("%s %.1fx" % (r["s"], r["x"]) for r in (dl.get("dist") or [])[:10]))
except Exception as ex:
    print("   not read: %s" % ex)
print("=== 3 · THE 12 PUSHERS across every F&O share now (how often each one lights up)")
try:
    import pushwho
    st = json.load(open("dash_state.json"))
    fps = [f for f in st.get("fo_paths") or [] if f.get("s") and f.get("chg") is not None]
    on, kinds, n = collections.Counter(), collections.Counter(), 0
    for f in fps:
        try:
            p = pushwho.read(f["s"])
        except Exception:
            continue
        n += 1
        kinds[p.get("kind") or "-"] += 1
        for r in p.get("rows") or []:
            if r.get("on"):
                on[r["k"]] += 1
    print("   %d shares read" % n)
    print("   " + " · ".join("%s %d" % (k, on[k]) for k in ("FII", "DII", "FUTURES", "WRITERS", "PROMOTER", "INDEX", "COMPANY", "REGULATOR", "TIDE", "BROKERS", "ALGOS", "MECHANICAL")))
    print("   kinds: " + " · ".join("%s %d" % kv for kv in kinds.most_common()))
except Exception as ex:
    print("   not read: %s" % ex)
print("=== 4 · TODAY's PUSH / PULL STARTED alerts - right or wrong 60 min later")
try:
    c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
    rows = c.execute("select t, sym, text from alerts where day=? and (text like '%PUSH STARTED%' or text like '%PULL STARTED%') order by t", (day,)).fetchall(); c.close()
    ch = json.load(open("charts.json"))
    ok = n = 0
    for t, s, tx in rows:
        d = 1 if "PUSH STARTED" in tx.split("\n")[0] else -1
        C = (ch.get(s) or {}).get("c") or []
        i = (int(t[:2]) * 60 + int(t[3:5]) - 555) // 5
        if not (0 <= i < len(C)) or not C[i]:
            continue
        j = min(len(C) - 1, i + 12)
        m = (C[j] / C[i] - 1) * 100 * d if C[j] else None
        n += 1; ok += bool(m is not None and m > 0.3)
        fi = "FII" if re.search(r"\bFII\b", tx) else ""; di = "DII" if re.search(r"\bDII\b", tx) else ""
        print("   %s %-11s %s %+5.1f%% in 60m %s %s" % (t[:5], s, "PUSH" if d > 0 else "PULL", m or 0, "✅" if (m or 0) > 0.3 else "❌", " ".join(x for x in (fi, di) if x)))
    print("   right after 60 min: %d of %d" % (ok, n))
except Exception as ex:
    print("   not read: %s" % ex)
PY
echo "=== done - nothing was changed"

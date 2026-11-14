#!/bin/bash
# resultswatch.sh - READ ONLY. THE RESULTS WATCH (Rama, 13 Nov: "an agent only for the results shares - who is betting on a rise, who on a fall,
# how much"). For every F&O share with results TODAY (and tomorrow): the brokers' number, the run-up, what the options price in, the OI battle
# (call writers above = betting it will NOT rise, put writers below = betting it will NOT fall), the futures money, who is pushing, and the
# history of its past results. Plain words at the end. Run it any time; it changes nothing and sends nothing.   bash resultswatch.sh
D=/home/globalbot/intraday
cd $D || exit 1
python3 - <<'PY'
import sys, json, datetime as dt
sys.path.insert(0, "/home/globalbot/intraday")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
now = dt.datetime.now(IST)
import resultsdesk
v = resultsdesk.desk()
rows = [r for r in v.get("rows") or [] if r.get("days") in (0, 1) and not r.get("err")]
try:
    fp = {f["s"]: f for f in json.load(open("dash_state.json")).get("fo_paths") or [] if f.get("s")}
except Exception:
    fp = {}
try:
    q = json.load(open("quotes_live.json")).get("q") or {}
except Exception:
    q = {}
print("=== THE RESULTS WATCH · %s · %d F&O shares with results today / tomorrow" % (now.strftime("%d %b %H:%M"), len(rows)))
for r in sorted(rows, key=lambda x: (x["days"], x["s"])):
    s = r["s"]
    print("\n■ %s · results %s · %s" % (s, "TODAY" if r["days"] == 0 else "TOMORROW", r.get("q") or ""))
    px = (q.get(s) or [None, None])
    print("   price ₹%s %s · into the results: %s in a week, %s in a month" % (px[0] if px[0] else r.get("px"), ("(%+.1f%% today)" % px[1]) if px[1] is not None else "",
          ("%+.1f%%" % r["wk"]) if r.get("wk") is not None else "?", ("%+.1f%%" % r["mo"]) if r.get("mo") is not None else "?"))
    print("   brokers expect: %s" % (r.get("exp") or "no broker number found"))
    if r.get("em"):
        print("   the options price in ±%.1f%% (its typical day ±%s%%) · IV percentile %s%s" % (r["em"], r.get("typ") or "?", r.get("ivp"),
              " - EXPENSIVE: an option bought now loses when IV collapses after the numbers, unless the move is bigger than that" if (r.get("ivp") or 0) >= 80 else ""))
    b = r.get("battle")
    if b:
        print("   who bets what (option writers): %s" % b.get("short"))
    f = fp.get(s) or {}
    if f.get("bu"):
        print("   futures money: %s ₹%.0f cr · futures OI %s" % (str(f["bu"]).replace("_", " ").lower(), abs(f.get("cr") or 0), ("%+.1f%%" % f["oi"]) if f.get("oi") is not None else "?"))
    try:
        import pushwho
        p = pushwho.read(s)
        up = [x["k"] for x in p["rows"] if x["on"] and x["side"] > 0]; dn = [x["k"] for x in p["rows"] if x["on"] and x["side"] < 0]
        print("   who is pushing: ▲ %s · ▼ %s%s" % (", ".join(up) or "none", ", ".join(dn) or "none", (" · " + p["kline"][:120]) if p.get("kline") else ""))
    except Exception:
        pass
    h = r.get("hist") or []
    if h:
        print("   past results: %s" % " · ".join("%s %s" % (x.get("q", ""), x.get("v", "")) if isinstance(x, dict) else str(x) for x in h[:4]))
    lean_up = ("BULL" in (b or {}).get("verdict", "").upper()) + (str(f.get("bu", "")).upper() in ("LONG_BUILD_UP", "LONG BUILD-UP", "SHORT_COVERING", "SHORT COVERING"))
    lean_dn = ("BEAR" in (b or {}).get("verdict", "").upper()) + (str(f.get("bu", "")).upper() in ("SHORT_BUILD_UP", "SHORT BUILD-UP", "LONG_UNWINDING", "LONG UNWINDING"))
    word = "money leans UP" if lean_up > lean_dn else "money leans DOWN" if lean_dn > lean_up else "no clear lean"
    print("   IN SIMPLE WORDS: %s before the numbers. %s Best: wait for the filing - GIR rings 🚨 RESULTS REACTION (ambulance) within ~1 minute when the price shows the verdict." % (
        word, "Options are expensive now - buying before the results is a gamble on a big move." if (r.get("ivp") or 0) >= 80 else ""))
PY
echo
echo "=== done - nothing was changed or sent"

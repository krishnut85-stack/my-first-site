#!/usr/bin/env python3
"""girdecide.py - patch 382: 🎯 GIR DECIDES - ONE CALL PER SHARE, ON THE ONE RULE THAT TESTED WELL (Rama, 17 Nov: "I am seeing everything in GIR
but I am not able to make out what to buy and sell"; ASHOKLEY got CE at 09:20 and PE at 09:50 from two alert makers; ~1,250 alerts a day).
The alert audit (alertaudit.py, 6 days, 13,789 alerts) found ONE rule that beat the shares already moving at the same time of day in BOTH
halves of the days: two DIFFERENT good alert types (the ✔ types of the audit) flag the same share the same way within 15 minutes, before
10:30 - 231 calls, 38.5 a day, +0.53% to 15:10 its way, 60% its way, 51% reached +1.5% before -1%, edge +0.72% (+0.80% / +0.65%).
Capping it to the first 3 or 5 of the day was NOT steady (one half negative), so every agreement is called.
  every 15 s, 09:20-10:30 IST: today's alerts (tomorrow.db) -> each alert's type and side exactly as the audit reads them -> the share's FIRST
  agreement -> 🎯 GIR DECIDES ▲ SHARE · CE side: the two types and their times, the price, WHY (callwhy: today's news with the AI's
  reading, the sector, the peers, the futures), the 07:00 list if it named the share, and the rule's tested record.
  ONE call per share a day: if the other side agrees later, the card gets a ⚠ note (and a quiet 📄 line) - not a second call.
  The ✔ types are read from the last audit (data/alertaudit.txt, "✔ types: ..."), so a re-run of the audit updates them.
  The page first (data/girdecide.json -> dashserve /girdecide -> the 🎯 box in TRADE NOW, its own sound), then Telegram (engine2.tg_fo).
  A paper record: every call is kept with its price; the audit scores "GIR DECIDES" as a type of its own from tomorrow. Orders nothing.
  python3 girdecide.py run          the service (gir-decide)
  python3 girdecide.py once [--dry] one pass now (--dry: nothing written, nothing sent), printed"""
import os, re, sys, json, time, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "girdecide.json")
FROM, TO, WIN = "09:20", "10:30", 15
OK_DEFAULT = ["FIRST MOVE", "MOVER", "OPENING", "RUNNING", "SPEED", "WHY", "YOUR RULE"]
RECORD = "the rule's record (alert audit, 6 days): 231 calls, 38.5 a day · +0.53% to 15:10 its way · its way 60% · +1.5% before -1%: 51% · beat the shares moving then by +0.72%"
SEND = None                                                    # tests put a list's append here


def now():
    return dt.datetime.now(IST)


def _j(p, d):
    try:
        return json.load(open(p))
    except Exception:
        return d


def ok_types():
    """the ✔ types of the last alert audit ("1c AGREEMENT ... (✔ types: A, B, C)"), else the 17 Nov list"""
    try:
        for ln in open(os.path.join(D, "data", "alertaudit.txt"), encoding="utf-8"):
            m = re.search(r"✔ types: ([^)]*)\)", ln)
            if m and m.group(1).strip() and m.group(1).strip() != "none":
                return sorted({x.strip() for x in m.group(1).split(",") if x.strip()}), "the last alert audit"
    except Exception:
        pass
    return OK_DEFAULT, "the 17 Nov audit (data/alertaudit.txt not read)"


def side_of(side, text):
    """the audit's reading: CE / PE, else the arrows in the first line"""
    if side == "CE":
        return 1
    if side == "PE":
        return -1
    first = (text or "").split("\n")[0]
    return 1 if "▲" in first and "▼" not in first else -1 if "▼" in first and "▲" not in first else 0


def alerts_today(day):
    p = next((x for x in (os.path.join(D, "tomorrow.db"), os.path.join(D, "data", "tomorrow.db")) if os.path.exists(x)), None)
    if not p:
        return []
    c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=10)
    R = c.execute("select t, kind, sym, side, text from alerts where day=? and sym is not null and sym != '' and sym != 'MARKET' order by t", (day,)).fetchall()
    c.close()
    return R


def agreements(R, OK, kind_of):
    """[(time, sym, dir, [(type, time), ...])] - the FIRST moment a second different ✔ type agrees, per share and side, FROM-TO"""
    seen, out, done = {}, [], set()
    for t, k, s, side, text in R:
        t5 = str(t)[:5]
        if not (FROM <= t5 < TO):                               # the audit: 09:20 on, agreements before 10:30
            continue
        ty = kind_of(text)
        if ty not in OK:
            continue
        dr = side_of(side, text)
        if not dr:
            continue
        m_ = int(t5[:2]) * 60 + int(t5[3:5]); key = (s, dr)
        prev = [x for x in seen.get(key, []) if m_ - x[0] <= WIN and x[1] != ty]
        if prev and key not in done:
            done.add(key)
            ts = sorted({(x[1], x[2]) for x in prev}, key=lambda z: z[1]) + [(ty, t5)]
            out.append((t5, s, dr, ts))
        seen.setdefault(key, []).append((m_, ty, t5))
    return out


def facts(sym, dr):
    L = []
    try:
        import callwhy
        L += [b for b in (callwhy.view(sym, dr).get("bul") or [])][:4]
    except Exception as ex:
        L.append("(the why lines could not be read: %s)" % str(ex)[:50])
    try:
        ov = _j(os.path.join(D, "data", "overnight.json"), {})
        if ov.get("day") == str(now().date()):
            for w in ov.get("watch") or []:
                if w.get("s") == sym:
                    L.append("07:00 list: 👀 watch %s - %s" % ("UP" if w.get("dir") == "up" else "DOWN", " + ".join(w.get("why") or [])[:140]))
            for it in ov.get("items") or []:
                if sym in (it.get("shares") or []) and it.get("kind") != "market":
                    L.append("07:00 list: %s %s - %s" % ({"up": "▲", "down": "▼"}.get(it.get("dir"), "?"), it.get("strength"), (it.get("headline") or "")[:110]))
                    break
    except Exception:
        pass
    return L


def price(sym):
    q = (_j(os.path.join(D, "quotes_live.json"), {}).get("q") or {}).get(sym)
    try:
        return float(q[0]), float(q[1])
    except Exception:
        return None, None


def text_of(c):
    arrow = "▲" if c["dir"] > 0 else "▼"
    L = ["🎯 GIR DECIDES %s %s · %s side · %s" % (arrow, c["s"], "CE" if c["dir"] > 0 else "PE", c["t"]),
         ("₹%.2f (%+.2f%% today)" % (c["px"], c["chg"])) if c.get("px") else "price not read",
         "agreed: " + " + ".join("%s %s" % (a, b) for a, b in c["types"])]
    L += ["why: " + x for x in c.get("why") or []]
    L += [RECORD, "the strike, the size and the stop are your call - GIR DECIDES picks the share and the side"]
    return "\n".join(L)


def send(text):
    if SEND is not None:
        return SEND(text)
    try:
        import engine2
        return engine2.tg_fo(text)
    except Exception as ex:
        print("girdecide telegram: %s" % str(ex)[:80], flush=True); return False


def tick(dry=False, n_=None):
    n = n_ or now(); day = str(n.date())
    import alertaudit
    OK, src = ok_types()
    st = _j(OUT, {})
    if st.get("day") != day:
        st = {"day": day, "calls": [], "notes": []}
    st.update({"at": n.strftime("%H:%M:%S"), "ok": OK, "ok_src": src, "rule": RECORD, "from": FROM, "to": TO})
    have = {c["s"]: c for c in st["calls"]}; noted = {(x["s"], x["t"]) for x in st["notes"]}
    new = []
    for t5, s, dr, types in agreements(alerts_today(day), set(OK), alertaudit.kind_of):
        if s in have:
            c = have[s]
            if c["dir"] != dr and (s, t5) not in noted:                     # the other side agreed later: a note, not a second call
                nt = {"s": s, "t": t5, "dir": dr, "types": types}
                st["notes"].append(nt); noted.add((s, t5))
                c.setdefault("against", []).append("%s %s: %s" % (t5, "▲ CE" if dr > 0 else "▼ PE", " + ".join(a for a, b in types)))
                if not dry:
                    send("📄 GIR DECIDES NOTE %s %s · %s\nthe other side now agrees too: %s\nGIR's %s call at %s stands - one call a share a day; watch your stop" % (
                        "▲" if dr > 0 else "▼", s, t5, " + ".join("%s %s" % (a, b) for a, b in types), "CE" if c["dir"] > 0 else "PE", c["t"]))
            continue
        px, chg = price(s)
        c = {"t": t5, "s": s, "dir": dr, "types": types, "px": px, "chg": chg, "why": facts(s, dr), "ts": time.time()}
        st["calls"].append(c); have[s] = c; new.append(c)
    if not dry:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        json.dump(st, open(OUT + ".tmp", "w"), ensure_ascii=False); os.replace(OUT + ".tmp", OUT)    # the page first
        for c in new:
            send(text_of(c))                                                                       # then Telegram
    return st, new


def view():
    st = _j(OUT, {})
    for c in st.get("calls") or []:                                    # the move since the call, for the page
        px, chg = price(c["s"])
        if px and c.get("px"):
            c["now"] = px; c["since"] = round(100 * (px / c["px"] - 1) * c["dir"], 2)
    st["t"] = time.time()
    return st


def run():
    print("GIR DECIDES up: %s-%s IST, every 15 s" % (FROM, TO), flush=True)
    while True:
        n = now(); hm = n.strftime("%H:%M")
        if n.weekday() < 5 and FROM <= hm <= "10:31":
            try:
                st, new = tick()
                for c in new:
                    print("%s 🎯 %s %s %s" % (c["t"], c["s"], "CE" if c["dir"] > 0 else "PE", " + ".join(a for a, b in c["types"])), flush=True)
            except Exception as ex:
                print("girdecide: %s" % str(ex)[:160], flush=True)
            time.sleep(15)
        else:
            time.sleep(60)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["run"]:
        run()
    else:
        st, new = tick(dry="--dry" in a)
        print("GIR DECIDES %s · the ✔ types (%s): %s" % (st["day"], st["ok_src"], ", ".join(st["ok"])))
        for c in st["calls"]:
            print("  %s %-11s %s · %s%s" % (c["t"], c["s"], "▲ CE" if c["dir"] > 0 else "▼ PE", " + ".join("%s %s" % (x, y) for x, y in c["types"]),
                  ("  ⚠ " + "; ".join(c["against"])) if c.get("against") else ""))
        print("  %d calls today" % len(st["calls"]))

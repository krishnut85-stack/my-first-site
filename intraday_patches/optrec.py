#!/usr/bin/env python3
"""optrec.py - patch 359: KEEP THE OPTION PRICES (the trade database's first shelf). Kite gives minute prices of an option only while the
contract is alive - once it expires they are gone, and with them any chance to test a rule on real option prices beyond the current month
(optreal.py could only ever look back a few weeks). So every evening after the close this saves, for every F&O share and for NIFTY / BANKNIFTY:
  · the share's own minute prices of the day
  · the minute prices of its CE and PE at every strike the share could have been "at the money" for during the day (the day's low -3% to its
    high +3%), nearest expiry - and the next expiry too in the expiry's last 5 days
into data/optrec/<day>.npz (about 2,000-2,500 contracts, a few MB a day). load(day) gives them back: {tradingsymbol: {minute: (o, h, l, c)}}.
Reads Kite, writes only its own folder. Orders nothing, sends nothing.
  python3 optrec.py [YYYY-MM-DD]     record that day (today; a day already kept is skipped - `again` records it afresh)
  python3 optrec.py show             the days kept"""
import os, sys, json, time, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
DIR = os.path.join(D, "data", "optrec")
IDX = {"NIFTY": 256265, "BANKNIFTY": 260105}


def record(day=None, again=False):
    import optreal as OR, seclive as SL
    day = day or str(dt.datetime.now(SL.IST).date()); f = os.path.join(DIR, "%s.npz" % day)
    if os.path.exists(f) and not again:
        return "already kept"
    K = OR.Kite(day); d0 = dt.date.fromisoformat(day); FO = sorted(SL.fo_set())
    rows, meta, t0 = [], [], time.time()

    def keep(ts, tok, info):
        c = K.candles(tok); time.sleep(0.34)
        if len(c) < 30:
            return False
        i = len(meta); meta.append(dict(info, ts=ts))
        rows.extend((i, m, o, h, l, cl) for m, (o, h, l, cl) in sorted(c.items()))
        return True
    spots = [(s, K.eq[s]) for s in FO if s in K.eq] + [(s, t) for s, t in IDX.items()]
    n_spot = n_opt = 0
    for s, tok in spots:
        if not keep(s, tok, {"kind": "spot", "name": s}):
            continue
        n_spot += 1
        c = K.candles(tok); lo, hi = min(v[2] for v in c.values()) * 0.97, max(v[1] for v in c.values()) * 1.03
        for typ in ("CE", "PE"):
            L = [x for x in K.opt.get((s, typ), []) if x[0] >= d0]
            if not L:
                continue
            e1 = min(x[0] for x in L); exps = [e1]
            later = sorted({x[0] for x in L if x[0] > e1})
            if (e1 - d0).days <= 5 and later and s not in IDX:
                exps.append(later[0])                                  # the expiry's last days: trades are already in the next month
            for e, strike, otok, ts, lot in sorted(L):
                if e in exps and lo <= strike <= hi:
                    n_opt += keep(ts, otok, {"kind": typ, "name": s, "expiry": str(e), "strike": strike, "lot": lot})
        K.cache.clear()                                               # one share's candles at a time - the rows are kept, not the cache
    if n_spot < 20:
        return "Kite gave prices for only %d shares - nothing kept (a holiday, or not logged in?)" % n_spot
    os.makedirs(DIR, exist_ok=True)
    np.savez_compressed(f + ".tmp.npz", rows=np.array(rows, dtype=np.float32), meta=np.array(json.dumps(meta)))
    os.replace(f + ".tmp.npz", f)
    return "%s: %d shares · %d option contracts · %d minute rows · %.1f MB · %d min" % (day, n_spot, n_opt, len(rows), os.path.getsize(f) / 1e6, (time.time() - t0) / 60)


def load(day):
    """{tradingsymbol or share: {minute since 09:15: (o, h, l, c)}}, {tradingsymbol: its details} - a day recorded earlier"""
    z = np.load(os.path.join(DIR, "%s.npz" % day), allow_pickle=False); meta = json.loads(str(z["meta"])); out = {m["ts"]: {} for m in meta}
    for i, mn, o, h, l, c in z["rows"]:
        out[meta[int(i)]["ts"]][int(mn)] = (float(o), float(h), float(l), float(c))
    return out, {m["ts"]: m for m in meta}


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["show"]:
        fs = sorted(x for x in (os.listdir(DIR) if os.path.isdir(DIR) else []) if x.endswith(".npz") and ".tmp" not in x)
        print("option prices kept: %d days%s · %.0f MB" % (len(fs), (" (%s to %s)" % (fs[0][:10], fs[-1][:10])) if fs else "", sum(os.path.getsize(os.path.join(DIR, x)) for x in fs) / 1e6))
    else:
        print("optrec " + record(next((x for x in a if x[:2] == "20"), None), "again" in a), flush=True)

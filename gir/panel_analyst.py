#!/usr/bin/env python3
"""PANEL ANALYST v1.0 — Stage-2 AI review of panel signals.
Reads latest run's signals from panel.db, builds a dossier per stock,
asks Gemini for a human-style verdict, logs to ai_verdicts table.
Usage: python3 panel_analyst.py            (analyze latest run's signals)
       python3 panel_analyst.py --dryrun   (no signals? analyze top-mean stock to prove pipeline)
Requires .env loaded (GEMINI_API_KEY)."""
import os, re, json, pickle, sqlite3, datetime as dt
import numpy as np
import panel

def _parliament_tg(sym, v, sig):
    import os, urllib.request, urllib.parse
    tok = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat = os.environ.get("TELEGRAM_CHAT_ID", "")
    thr = os.environ.get("TG_THREAD_PARLIAMENT", "").strip()
    if not (tok and chat): return
    if str(v.get("verdict", "")).upper() != "BUY": return
    pat = "A" if sig == 1 else "B" if sig == 2 else "dryrun"
    text = f"\U0001f3db *[PARLIAMENT]* {sym} {v.get('verdict')} \u00b7 conviction {v.get('conviction', 0)}/100 \u00b7 {pat} \u00b7 paper"
    try:
        d = {"chat_id": chat, "text": text[:4000], "parse_mode": "Markdown"}
        if thr: d["message_thread_id"] = int(thr)
        urllib.request.urlopen("https://api.telegram.org/bot" + tok + "/sendMessage?" + urllib.parse.urlencode(d), timeout=10)
    except Exception: pass

def gemini_model():
    m = os.environ.get("GEMINI_MODEL")
    if m: return m
    try:
        src = open("/home/globalbot/gir.py").read()
        hits = re.findall(r"gemini-[a-z0-9.\-]+", src)
        if hits: return max(set(hits), key=hits.count)
    except Exception: pass
    return "gemini-flash-lite-latest"

def ask_gemini(prompt):
    import google.generativeai as genai
    key = (os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
           or os.environ.get("GEMINI_KEY") or os.environ.get("GOOGLE_GENAI_API_KEY"))
    if not key:
        raise SystemExit("[ANALYST] no Gemini key found in env (tried GEMINI_API_KEY/GOOGLE_API_KEY/GEMINI_KEY/GOOGLE_GENAI_API_KEY)")
    genai.configure(api_key=key)
    model = genai.GenerativeModel(gemini_model())
    r = model.generate_content(prompt)
    return r.text

def dossier(sym, d, votes, pattern, mean, agree, nifty20):
    c, h, l, v = d["c"], d["h"], d["l"], d["v"]
    fam = {}
    for jname, (f_, s) in votes.items():
        fam.setdefault(f_, []).append(s)
    fams = {k: round(float(np.mean(x)), 1) for k, x in fam.items()}
    e200 = panel.ema(c, 200); e20 = panel.ema(c, 20)
    last10 = ", ".join(f"{x:.1f}" for x in c[-10:])
    return f"""You are a veteran NSE equity analyst. A quantitative screening panel flagged this stock. Give your independent verdict.

STOCK: {sym} | PATTERN FIRED: {"A: dip-in-uptrend (buy pullback in established uptrend)" if pattern==1 else "B: breakout-from-strength"}
MARKET: NIFTY 20-day {nifty20:+.1f}%
PRICE: last close {c[-1]:.1f} | vs 20EMA {(c[-1]/e20[-1]-1)*100:+.1f}% | vs 200EMA {(c[-1]/e200[-1]-1)*100:+.1f}%
52w range position: {(c[-1]-c[-250:].min())/(c[-250:].max()-c[-250:].min())*100 if len(c)>=250 else 50:.0f}th percentile
Last 10 closes: {last10}
20d avg turnover: Rs.{np.mean(c[-20:]*v[-20:])/1e7:.1f} crore | today vol vs 20d avg: {v[-1]/max(np.mean(v[-21:-1]),1):.1f}x
Panel: weighted mean {mean:.2f}/10, agreement {agree*100:.0f}%
Family scores (0-10): {json.dumps(fams)}

The quant rules already passed. Your job is what rules can't see: does this look like genuine accumulation or a trap? Any red flags in the price/volume behavior? Reply ONLY with JSON, no markdown:
{{"verdict":"BUY"|"SKIP","conviction":0-100,"reasons":["...","..."],"red_flags":["..."]}}"""

def main(dryrun=False):
    con = sqlite3.connect(panel.DB_PATH)
    con.executescript("""CREATE TABLE IF NOT EXISTS ai_verdicts(
        ts TEXT, run_id INTEGER, symbol TEXT, pattern INTEGER,
        verdict TEXT, conviction INTEGER, reasons TEXT, red_flags TEXT, raw TEXT);""")
    rid = con.execute("SELECT MAX(run_id) FROM runs").fetchone()[0]
    if not rid: raise SystemExit("[ANALYST] no panel runs yet")
    rows = con.execute("SELECT symbol, signal, mean, agreement FROM results "
                       "WHERE run_id=? AND signal>0 ORDER BY mean DESC", (rid,)).fetchall()
    if not rows and dryrun:
        rows = [(r[0], 0, r[1], r[2]) for r in con.execute(
            "SELECT symbol, mean, agreement FROM results WHERE run_id=? AND vetoed='' "
            "ORDER BY mean DESC LIMIT 1", (rid,))]
        print("[ANALYST] dryrun: no signals, analyzing top-mean stock to prove pipeline")
    if not rows:
        print(f"[ANALYST] run #{rid}: no signals to analyze. Done."); return
    hist = pickle.load(open(os.path.join(panel.CACHE, "hist.pkl"), "rb"))
    nif = hist.get("__NIFTY__", {}).get("c")
    nifty20 = (nif[-1]/nif[-21]-1)*100 if nif is not None and len(nif) >= 21 else 0.0
    fii = {}
    fp = os.path.join(panel.CACHE, "fii_dii.json")
    if os.path.exists(fp):
        try: fii = json.load(open(fp))
        except Exception: pass
    mkt = panel.market_context(hist, fii)
    for sym, sig, mean, agree in rows:
        d = hist.get(sym)
        if d is None: print(f"[ANALYST] {sym}: not in cache, skip"); continue
        f = panel.features(sym, d, mkt); f["deliv"] = None; f["bulk"] = {}
        _, _, _, votes = panel.score_stock(f)
        prompt = dossier(sym, d, votes, sig, mean, agree, nifty20)
        try:
            raw = ask_gemini(prompt)
            jt = re.search(r"\{.*\}", raw, re.S).group(0)
            v = json.loads(jt)
        except Exception as e:
            print(f"[ANALYST] {sym}: Gemini/parse error: {e}"); continue
        con.execute("INSERT INTO ai_verdicts VALUES(?,?,?,?,?,?,?,?,?)",
                    (dt.datetime.now().isoformat(), rid, sym, sig, v.get("verdict"),
                     int(v.get("conviction", 0)), json.dumps(v.get("reasons", [])),
                     json.dumps(v.get("red_flags", [])), raw[:2000]))
        con.commit()
        _parliament_tg(sym, v, sig)
        print(f"\n{sym} [pattern {'A' if sig==1 else 'B' if sig==2 else 'dryrun'}] -> "
              f"{v.get('verdict')} conviction {v.get('conviction')}")
        for r_ in v.get("reasons", []): print(f"   + {r_}")
        for r_ in v.get("red_flags", []): print(f"   ! {r_}")
    con.close()
    print(f"\n[ANALYST] model={gemini_model()} | verdicts logged to ai_verdicts in panel.db")

if __name__ == "__main__":
    import sys
    main(dryrun="--dryrun" in sys.argv)

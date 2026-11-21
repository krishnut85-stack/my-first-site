#!/usr/bin/env python3
"""moverswhy.py - patch 378: WHY THEY MOVED, ALL DAY (Rama, 17 Nov 15:04: "do we know why these stocks moved? If we were really proactive we
could have got the information and given it to me" - LAURUSLABS, the PSU banks, KAYNES, KEI / POLYCAB ... the reasons were in GIR or in the
news, and nobody put them together).
Every 15 minutes in market hours, for the 10 biggest F&O gainers and the 10 biggest losers (1.5%+ either way):
  1 GIR's OWN FACTS (callwhy.py): today's news on the share with the AI's reading, last night's list, its sector now and the peers moving with
    it, the futures build-up, filings / broker calls / analyst meets GIR read (whymove), results due
  2 A FRESH SEARCH: Google News for the company's name, since the last close
  3 ONE LINE each, written by Claude Haiku from those lines ONLY: the reason, what kind (news · filing · broker · results · sector · market ·
    deal · none), how sure (clear · likely · not found), and its source. When nothing explains it, it says "no news found" and whether the
    sector moved with it - "not checked" and "checked, nothing" never look the same.
A share's line is kept 30 minutes unless it moved another 1%+ (so the model reads only what changed). -> data/moverswhy.json for the page's
❓ WHY THEY MOVED panel and the share's note. The key is read from the server's .env (never printed). Orders nothing, sends nothing.
  python3 moverswhy.py            one pass now, printed
  python3 moverswhy.py --dry      the facts it would send, no model call"""
import os, re, sys, json, time, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "moverswhy.json")
MODEL = os.environ.get("MOVERSWHY_MODEL") or "claude-haiku-5-5"
N_EACH, MIN_MOVE, KEEP_S, AGAIN_MOVE = 10, 1.5, 1800, 1.0
SYSTEM = """You explain, for an Indian F&O options trader, why each share is moving today. For each share you get its move, and the facts GIR
collected (news since the last close with times, the AI's reading of full stories, its sector and peers, futures build-up, filings, broker
calls, results due) plus fresh news-search headlines for the company.
Rules:
- Use ONLY the lines given. Never invent a reason, a number, a source or a time. If a headline is older than the last close, say it is old.
- Prefer the most direct cause: company news or a filing > a broker call > results > its sector moving the same way > the whole market.
- A headline about the company that points the other way to the move is not the reason; say "no reason found" rather than force it.
- If nothing explains the move, say so plainly, and say whether its sector or peers moved with it ("no news found - its sector fell with it" /
  "no news found - moving on its own").
Answer with a JSON array only. One item per share: {"s": "SYMBOL", "why": "one short line, under 22 words", "kind": "news|filing|broker|results|
sector|market|deal|none", "sure": "clear|likely|not found", "src": "source name and time if known, else empty"}."""


def now():
    return dt.datetime.now(IST)


def last_close(n):
    c = n.replace(hour=15, minute=30, second=0, microsecond=0)
    if n < c:
        c -= dt.timedelta(days=1)
    while c.weekday() > 4:
        c -= dt.timedelta(days=1)
    return c


def _j(path, default):
    try:
        return json.load(open(path))
    except Exception:
        return default


def movers():
    """[(sym, % today)] - the 10 biggest gainers and losers among the F&O shares, 1.5%+"""
    import seclive as SL
    FO = SL.fo_set()
    q = _j(os.path.join(D, "quotes_live.json"), {}).get("q") or {}
    R = [(s, float(v[1])) for s, v in q.items() if s in FO and len(v) > 1 and v[1] is not None]
    up = sorted([r for r in R if r[1] >= MIN_MOVE], key=lambda r: -r[1])[:N_EACH]
    dn = sorted([r for r in R if r[1] <= -MIN_MOVE], key=lambda r: r[1])[:N_EACH]
    return up + dn


def search(name, since):
    """Google News for the company since the last close -> ["HH:MM source: headline"]"""
    import requests, xml.etree.ElementTree as ET
    from email.utils import parsedate_to_datetime
    from urllib.parse import quote
    q = re.sub(r"\b(ltd|limited|india|the|co|company|corporation|industries)\b\.?", "", name, flags=re.I).strip(" .,&")
    if len(q) < 3:
        return []
    out = []
    try:
        r = requests.get("https://news.google.com/rss/search?q=" + quote('"%s" share' % q) + "&hl=en-IN&gl=IN&ceid=IN:en", headers={"User-Agent": "Mozilla/5.0"}, timeout=15)
        if r.status_code == 200:
            for it in ET.fromstring(r.content).iter("item"):
                try:
                    t = parsedate_to_datetime(it.findtext("pubDate") or "").astimezone(IST)
                except Exception:
                    continue
                h = (it.findtext("title") or "").strip(); src = (it.findtext("source") or "").strip()
                if h and t >= since - dt.timedelta(hours=6):
                    out.append("%s %s%s: %s" % (t.strftime("%d %b %H:%M"), src, "" if t >= since else " (before the close)", re.sub(r"\s+-\s+[^-]{2,40}$", "", h)[:150]))
                if len(out) >= 5:
                    break
    except Exception:
        pass
    return out


def facts(sym, chg, names, since):
    dr = 1 if chg > 0 else -1
    try:
        import callwhy
        v = callwhy.view(sym, dr); bul = v.get("bul") or []
    except Exception:
        bul = []
    return {"s": sym, "move": "%+.2f%% today" % chg, "company": names.get(sym, ""), "gir": bul[:9], "search": search(names.get(sym, "") or sym, since)}


def run(dry=False):
    n = now(); since = last_close(n)
    try:
        import seclive as SL
        _, names = SL.universe()
    except Exception:
        names = {}
    prev = _j(OUT, {}); keep = {r["s"]: r for r in (prev.get("rows") or [])} if prev.get("day") == str(n.date()) else {}
    M = movers(); todo = []; rows = []
    for s, chg in M:
        k = keep.get(s)
        if k and time.time() - float(k.get("ts") or 0) < KEEP_S and abs(chg - float(k.get("chg") or 0)) < AGAIN_MOVE and k.get("sure") != "error":
            k = dict(k); k["chg"] = round(chg, 2); rows.append(k)
        else:
            todo.append((s, chg))
    F = [facts(s, c, names, since) for s, c in todo]
    if dry:
        print(json.dumps(F, ensure_ascii=False, indent=1)[:6000]); return
    got = {}
    if F:
        try:
            import anthropic
            user = "The last close was %s IST. Now %s IST.\n\n%s" % (since.strftime("%d %b %H:%M"), n.strftime("%d %b %H:%M"), json.dumps(F, ensure_ascii=False))
            with anthropic.Anthropic().messages.stream(model=MODEL, max_tokens=6000, system=SYSTEM, messages=[{"role": "user", "content": user}]) as s_:
                r = s_.get_final_message()
            txt = "\n".join(b.text for b in r.content if b.type == "text"); a, b = txt.find("["), txt.rfind("]")
            for x in (json.loads(txt[a:b + 1]) if a >= 0 and b > a else []):
                if isinstance(x, dict) and x.get("s"):
                    got[str(x["s"]).upper()] = x
        except Exception as ex:
            print("the model: %s" % str(ex)[:160])
    for (s, chg), f in zip(todo, F):
        x = got.get(s) or {}
        rows.append({"s": s, "chg": round(chg, 2), "why": str(x.get("why") or ("could not be read now - " + (f["gir"][0] if f["gir"] else "no facts")))[:200],
                     "kind": x.get("kind") if x.get("kind") in ("news", "filing", "broker", "results", "sector", "market", "deal", "none") else "none",
                     "sure": x.get("sure") if x.get("sure") in ("clear", "likely", "not found") else ("error" if not x else "not found"),
                     "src": str(x.get("src") or "")[:80], "t": n.strftime("%H:%M"), "ts": time.time(), "n_search": len(f["search"]), "n_gir": len(f["gir"])})
    rows.sort(key=lambda r: -r["chg"])
    o = {"day": str(n.date()), "at": n.strftime("%H:%M:%S"), "since": since.strftime("%d %b %H:%M"), "model": MODEL, "rows": rows, "read": len(todo)}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(o, open(OUT + ".tmp", "w"), ensure_ascii=False); os.replace(OUT + ".tmp", OUT)
    for r_ in rows:
        print("  %-11s %+6.2f%%  [%s · %s] %s%s" % (r_["s"], r_["chg"], r_["kind"], r_["sure"], r_["why"], ("  (" + r_["src"] + ")") if r_["src"] else ""))
    return o


def view():
    return _j(OUT, {})


if __name__ == "__main__":
    run(dry="--dry" in sys.argv)

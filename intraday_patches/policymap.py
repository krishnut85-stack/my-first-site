#!/usr/bin/env python3
"""policymap.py - patch 383: A RULE STORY THAT NAMES NO COMPANY STILL HITS SHARES (Rama, 17 Nov, ANGELONE: "SEBI may limit bets on leveraged / MTF
stock trading - negative for broker stocks like NSE, BSE, Groww, Angel One"). GIR's market desk had the story at 12:59 (Business Today, NDTV
Profit; ET Now 13:10, Business Standard 13:37) - but it names SEBI, not a company, so nothing linked it to ANGELONE / BSE / CDSL, and the only
copy filed under a share came through Google at 13:13, under BSE, read UP ("pare gains"). The shares were falling from about 12:45.
Every 30 s this reads the market desk's headlines (data/macro.json, the business wires and regulators GIR already reads every minute):
  THEMES   a regulator / government story on a subject that moves a known group of F&O shares - margin trading, F&O rules, brokerage,
           exchange charges (brokers, exchanges, depositories) · mutual-fund rules (AMCs, registrars) · insurance rules (insurers) ·
           telecom tariffs / dues (telcos) · bank / NBFC rules from the RBI (lenders) · gold-loan rules · microfinance rules
  -> for each share of the group (F&O only, the most exposed first, at most 6): Claude reads the story FOR THAT SHARE (the same reader as
     every news alert - newsalert.model_read - told why the share is linked), and the alert goes out the same way as other news:
     🚨 CRITICAL / 📰 rings, 📄 quiet, "already in the price" quiet - "🧭 POLICY: ANGELONE · SEBI margin trading" with the AI's direction.
     The story is also filed under the share in news.db with the AI's reading (the page, WHY NOW, the engine see it).
  once per theme and share in 3 hours - unless the reading turns the other way (SEBI's denial at 16:03 would come through).
  python3 policymap.py run                 the service (gir-policymap)
  python3 policymap.py test "headline"     which theme and shares a headline would reach (nothing read, nothing sent)"""
import os, re, sys, json, time, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
STATE = os.path.join(D, "data", "policymap.json")
REG = r"\b(sebi|rbi|reserve bank|irdai|trai|dot\b|telecom department|finance ministry|government|govt|centre|cabinet|regulator|amfi|nse|bse|exchanges?)\b"
THEMES = [
    ("capital-markets", "margin trading, F&O rules, brokerage, exchange charges",
     r"\b(margin[- ]?(trading|funding|funded|money|requirements?)|\bmtf\b|leverag\w*|f&o (rules?|curbs?|norms?|framework)|derivatives? (rules?|curbs?|norms?|framework|trading)|"
     r"weekly expir\w*|lot size|stt\b|securities transaction tax|brokerage (fees?|charges?|caps?)|transaction charges?|exchange fees?|retail (traders?|investors?) (losses|curbs?)|"
     r"algo(rithmic)? trading|intraday (curbs?|limits?)|position limits?|pledg\w+ (rules?|norms?)|demat)\b",
     ["ANGELONE", "BSE", "CDSL", "MCX", "MOTILALOFS", "NUVAMA", "360ONE", "IIFL"], "earns from trading, margin funding or exchange fees"),
    ("mutual-funds", "mutual-fund rules", r"\b(mutual funds? (rules?|norms?|fees?|charges?)|\bter\b|total expense ratio|expense ratio|amc (fees?|rules?)|sip (rules?|norms?)|mf distributors?)\b",
     ["HDFCAMC", "NAM-INDIA", "CAMS", "KFINTECH", "ABSLAMC", "UTIAMC"], "earns from mutual-fund assets or their servicing"),
    ("insurance", "insurance rules", r"\b(insurance (rules?|norms?|commission|regulations?|bill|amendment)|insurers?|commission caps?|bancassurance|surrender value|irdai)\b",
     ["HDFCLIFE", "SBILIFE", "ICICIPRULI", "LICI", "ICICIGI", "POLICYBZR", "STARHEALTH"], "is an insurer or insurance seller"),
    ("telecom", "telecom tariffs and dues", r"\b(telecom (tariffs?|dues|levies|licen[cs]e fees?|policy)|\bagr\b|adjusted gross revenue|spectrum (auction|dues|charges?|price)|mobile tariffs?|trai)\b",
     ["BHARTIARTL", "IDEA", "INDUSTOWER"], "is a telecom operator or tower company"),
    ("lenders", "RBI rules for banks and NBFCs", r"\b(repo rate|crr\b|cash reserve ratio|slr\b|risk weights?|unsecured (loans?|lending)|lending (norms?|rules?)|provisioning (norms?|rules?)|"
     r"ecl\b|expected credit loss|nbfc (rules?|norms?)|liquidity coverage|lcr\b|co-?lending|digital lending)\b",
     ["HDFCBANK", "ICICIBANK", "SBIN", "AXISBANK", "KOTAKBANK", "BAJFINANCE"], "is a large lender"),
    ("gold-loans", "gold-loan rules", r"\b(gold loans?|loan[- ]to[- ]value|\bltv\b)\b", ["MUTHOOTFIN", "MANAPPURAM"], "is a gold-loan lender"),
    ("microfinance", "microfinance rules", r"\b(microfinance|micro-?finance|mfi\b|joint liability)\b", ["BANDHANBNK", "CREDITACC", "IDFCFIRSTB"], "is a microfinance lender"),
]
MAX_SH, COOL = 6, 3 * 3600


def now():
    return dt.datetime.now(IST)


def _j(p, d):
    try:
        return json.load(open(p))
    except Exception:
        return d


def match(h):
    """-> (theme key, theme name, the F&O shares, why) or None: a regulator / government word AND a theme's subject in the headline"""
    if not re.search(REG, h or "", re.I):
        return None
    for key, name, rx, shares, why in THEMES:
        if re.search(rx, h or "", re.I):
            return key, name, shares, why
    return None


def fo_shares(shares):
    try:
        import seclive as SL
        FO = SL.fo_set()
        return [s for s in shares if s in FO][:MAX_SH]
    except Exception:
        return shares[:MAX_SH]


def read_one(sym, h, link, src, t, theme, why, also):
    """the AI's reading for this share -> the alert (the same reader, the same rules as every news alert)"""
    import newsalert
    hm = dt.datetime.fromtimestamp(t, IST).strftime("%H:%M")
    try:
        import newsbody
        body = newsbody.get(link) if link else ""
    except Exception:
        body = ""
    note = "\n\n(GIR's note: this story names no company; %s is linked because it %s - %s. Read it for THIS share.)" % (sym, why, theme)
    r = newsalert.model_read(sym, ((h + "\n\nTHE FULL STORY:\n" + body) if body else h) + note, src, hm, "POLICY")
    if r is None:
        return None, None
    r = dict(r, full=bool(body))
    try:                                                        # the story is filed under the share, with the AI's reading
        import newsroom
        con = newsroom.db(); newsroom.store(con, sym, [(t, h, link, newsroom._domain(link) or src)], src="POLICY"); con.close()
        newsalert.remember(sym, h, r, t)
    except Exception as ex:
        print("policymap store %s: %s" % (sym, str(ex)[:80]), flush=True)
    extra = ["🧭 POLICY - %s: %s %s" % (theme, sym, why)] + (["the same story touches: " + ", ".join(also)] if also else [])
    if not newsalert.decide(r):
        if not (r.get("relevant") and r.get("known") and r.get("level") in ("critical", "important") and newsalert.fresh_since_close(t)):
            return r, None
        extra.append("ⓘ the reader thinks this is already in the price - sent as information (quiet), not a call")
        r = dict(r, level="minor")
    return r, newsalert.compose(r, "POLICY", sym, "POLICY", src, hm, h, extra, link)


def tick(items=None, send=None, n_=None):
    n = n_ or now(); st = _j(STATE, {"seen": {}, "sent": {}})
    items = items if items is not None else (_j(os.path.join(D, "data", "macro.json"), {}).get("items") or [])
    out = []
    for x in items:
        h = str(x.get("h") or ""); t = float(x.get("t") or 0)
        k = re.sub(r"[^a-z0-9]", "", h.lower())[:60]
        if not h or k in st["seen"] or n.timestamp() - t > 2 * 3600:
            continue
        st["seen"][k] = n.timestamp()
        m = match(h)
        if not m:
            continue
        key, name, shares, why = m
        S = fo_shares(shares)
        turn = bool(re.search(r"\b(not|no|denies|denied|clarif\w*|rules? out|ruled out|withdraw\w*|scrap\w*|u-?turn|reverses?|eases?|relax\w*)\b", h, re.I))
        for sym in S:
            last = st["sent"].get("%s|%s" % (key, sym))
            if last and n.timestamp() - last["t"] < COOL and not turn:
                continue                                        # the same theme again within 3 hours, no turn in the words: not read again
            r, txt = read_one(sym, h, str(x.get("link") or x.get("l") or ""), str(x.get("src") or "market desk"), t or n.timestamp(), name, why, [s for s in S if s != sym])
            if not txt or r is None:
                continue
            if last and n.timestamp() - last["t"] < COOL and last["side"] == r["side"]:
                continue                                        # the same theme, the same reading, within 3 hours: once
            st["sent"]["%s|%s" % (key, sym)] = {"t": n.timestamp(), "side": r["side"], "h": h[:120]}
            out.append((sym, r["side"], txt))
            (send or _send)(txt)
    st["seen"] = {k: v for k, v in st["seen"].items() if n.timestamp() - v < 2 * 86400}
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    json.dump(st, open(STATE + ".tmp", "w"), ensure_ascii=False); os.replace(STATE + ".tmp", STATE)
    return out


def _send(txt):
    import newsalert
    return newsalert._send(txt)


def run():
    print("policymap up: the market desk's rule stories -> the shares they hit, every 30 s", flush=True)
    first = True
    while True:
        hm = now().strftime("%H:%M")
        if "07:00" <= hm <= "22:30":
            try:
                if first:                                       # the first pass only learns what is already there (no flood after a restart)
                    st = _j(STATE, {"seen": {}, "sent": {}})
                    for x in _j(os.path.join(D, "data", "macro.json"), {}).get("items") or []:
                        st["seen"].setdefault(re.sub(r"[^a-z0-9]", "", str(x.get("h") or "").lower())[:60], time.time())
                    os.makedirs(os.path.dirname(STATE), exist_ok=True); json.dump(st, open(STATE, "w"), ensure_ascii=False); first = False
                for sym, side, txt in tick():
                    print("%s 🧭 %s %s" % (hm, sym, {1: "UP", -1: "DOWN"}.get(side, "-")), flush=True)
            except Exception as ex:
                print("policymap: %s" % str(ex)[:160], flush=True)
        time.sleep(30)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["run"]:
        run()
    elif a[:1] == ["test"]:
        h = " ".join(a[1:]); m = match(h)
        print("no theme - not a rule story GIR links to a group" if not m else "theme: %s · the shares: %s · why: %s" % (m[1], ", ".join(fo_shares(m[2])), m[3]))

#!/usr/bin/env python3
"""whydesk.py - WHO IS MOVING THE SECTOR, AND WHY (Rama, 16 Nov: "the sector does not move on its own - someone is pushing and pulling every
day on some data. Who, and why? That answer we did not get."). Prices only say THAT a sector moved. This puts the other evidence GIR already
holds next to the day's strongest and weakest sectors, and has Claude read it:
  THE MOVE   each sector from ALL its NSE shares, size-weighted (seclive.py) · the shares pushing it (size x move) · its F&O shares not moved yet
  WHY        for the pushing shares and the sector's F&O shares: GIR's own reasons (whymove.py - results read, exchange filings, the news GIR
             checked, a broker's call, results due) and the newsroom's headlines · the market-wide news desk (macro.py: Finance Ministry, RBI,
             SEBI, budget, GST, the Fed, crude, tariffs ...)
  WHO        · NSE's participant file (nsextra.py): FII / funds (DII) / proprietary desks / clients - net index-futures and stock-futures
               positions, the change on the day and over 5 days
             · NSE's delivery file: for each sector the shares actually TAKEN HOME (₹ crore) today against its last 10 days - far above normal
               with the price = investors really buying / selling, not day traders; and the last 5 days against the 20 before (building quietly?)
             · today's bulk and block deals in those shares
  THE READING  Claude (WHYDESK_MODEL, else claude-haiku-5-5; the key is the one already in the server's .env) writes for each sector: why, the
             kind of reason, who the footprints point to, the F&O shares exposed and not moved, what to watch tomorrow. It may use only the
             facts given; where they hold no reason it must say "no reason in today's data".
Places no order, sends nothing to Telegram. It fetches NSE's evening files into data/extra.db the same way the evening job (earlystudy) does, and
sends the collected facts (public market data, GIR's news lines) to Anthropic's API for the reading; nothing else leaves the server.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 whydesk.py [facts]   ("facts" = collect and print, no AI call)
  -> prints, saves data/whydesk.txt, data/whydesk.json and one file a day in data/whydesk/ (the record to build on). Best after 19:00 (NSE publishes delivery ~18:00, positions ~19:00)."""
import os, re, io, csv, sys, json, time, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L, SRC = [], []
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36", "Accept": "*/*"}
MODEL = os.environ.get("WHYDESK_MODEL") or "claude-haiku-5-5"
TOP = 5                                                  # the 5 strongest and the 5 weakest sectors are read
pc = lambda v: "%+.2f%%" % v
ro = lambda name: sqlite3.connect("file:%s?mode=ro" % os.path.join(D, name), uri=True, timeout=10)
dm = lambda d: dt.date.fromisoformat(str(d)[:10]).strftime("%d %b")


def say(s=""):
    L.append(s); print(s, flush=True)


def refresh(today):
    """NSE's evening files (delivery, participant positions) into data/extra.db - what gir-early does every evening (days already stored are
    skipped); a 'not there yet' mark for today is cleared first so a later run picks the file up"""
    try:
        import nsextra
        c = nsextra.db(); c.execute("delete from fetched where d=? and status='none'", (str(today),)); c.commit(); c.close()
        try:
            n = nsextra.fetch_extra(today - dt.timedelta(days=40), today, quiet=True, sources=("deliv", "part"))
        except TypeError:
            n = nsextra.fetch_extra(today - dt.timedelta(days=40), today, quiet=True)
        SRC.append("NSE evening files: %d new" % n)
    except Exception as ex:
        SRC.append("NSE evening files NOT refreshed (%s)" % str(ex)[:70])


def participants():
    """[{who, day, index/stock futures net (contracts), change on the day, change over 5 days}] from data/extra.db"""
    out = []
    try:
        c = ro(os.path.join("data", "extra.db"))
        days = [r[0] for r in c.execute("select distinct d from part order by d desc limit 6")]
        if not days:
            SRC.append("participant positions: none stored"); return out
        P = {}
        for d, who, fil, fis, fsl, fss in c.execute("select d, who, fi_l, fi_s, fs_l, fs_s from part where d>=?", (days[-1],)):
            if None not in (fil, fis, fsl, fss):
                P[(d, str(who).upper())] = (fil - fis, fsl - fss, fil, fis)
        c.close()
        for who in ("FII", "DII", "PRO", "CLIENT"):
            a = P.get((days[0], who))
            if not a:
                continue
            b = P.get((days[1], who)) if len(days) > 1 else None; w = P.get((days[-1], who)) if len(days) > 2 else None
            out.append({"who": {"FII": "FII (foreign investors)", "DII": "DII (Indian funds, insurers)", "PRO": "PRO (brokers' own desks)", "CLIENT": "CLIENT (retail, HNI)"}[who],
                        "day": days[0], "index_fut_net": round(a[0]), "index_fut_change_1d": round(a[0] - b[0]) if b else None,
                        "index_fut_change_%dd" % (len(days) - 1): round(a[0] - w[0]) if w else None, "index_fut_long_share_pct": round(100 * a[2] / (a[2] + a[3])) if a[2] + a[3] else None,
                        "stock_fut_net": round(a[1]), "stock_fut_change_1d": round(a[1] - b[1]) if b else None, "stock_fut_change_%dd" % (len(days) - 1): round(a[1] - w[1]) if w else None})
        SRC.append("participant positions: %s (%d days)" % (dm(days[0]), len(days)))
    except Exception as ex:
        SRC.append("participant positions: not read (%s)" % str(ex)[:70])
    return out


def delivery(SEC, Q):
    """{sector: {day, deliv_cr, x_10d, deliv_pct, deliv_pct_10d, build_5d_vs_20d}} - the shares taken home, valued at one price so only the
    quantity moves the comparison"""
    out = {}
    try:
        c = ro(os.path.join("data", "extra.db"))
        days = [r[0] for r in c.execute("select distinct d from deliv order by d desc limit 26")]
        if len(days) < 4:
            SRC.append("delivery: only %d days stored" % len(days)); return out
        G = {}
        for d, s, q, dq in c.execute("select d, sym, qty, dq from deliv where d>=?", (days[-1],)):
            sec = SEC.get(s)
            if sec and s in Q and q and dq is not None:
                a = G.setdefault(sec, {}).setdefault(d, [0.0, 0.0, 0.0]); p = Q[s][1]
                a[0] += dq * p / 1e7; a[1] += dq * p; a[2] += q * p
        c.close()
        for sec, g in G.items():
            a = g.get(days[0]); prev = [g[d] for d in days[1:11] if d in g]
            if not a or len(prev) < 3 or not a[2]:
                continue
            av = sum(p[0] for p in prev) / len(prev); ap = sum(100 * p[1] / p[2] for p in prev if p[2]) / len(prev)
            l5 = [g[d][0] for d in days[:5] if d in g]; b20 = [g[d][0] for d in days[5:25] if d in g]
            out[sec] = {"day": days[0], "deliv_cr": round(a[0]), "x_10d": round(a[0] / av, 2) if av else None, "deliv_pct": round(100 * a[1] / a[2], 1), "deliv_pct_10d": round(ap, 1),
                        "build_5d_vs_20d": round((sum(l5) / len(l5)) / (sum(b20) / len(b20)), 2) if len(l5) >= 4 and len(b20) >= 10 and sum(b20) else None}
        SRC.append("delivery: %s (%d days)" % (dm(days[0]), len(days)))
    except Exception as ex:
        SRC.append("delivery: not read (%s)" % str(ex)[:70])
    return out


def deals(syms, SEC):
    """today's bulk and block deals (NSE's archive) in the shares of the sectors read, the biggest first"""
    import requests
    out, got = [], []
    for name in ("bulk", "block"):
        try:
            r = requests.get("https://nsearchives.nseindia.com/content/equities/%s.csv" % name, headers=UA, timeout=20); r.raise_for_status()
            n = 0
            for row in csv.DictReader(io.StringIO(r.text.lstrip("﻿"))):
                row = {(k or "").strip().lower(): (v or "").strip() for k, v in row.items()}
                s = (row.get("symbol") or "").upper(); n += 1
                if s not in syms:
                    continue
                num = lambda k: float((next((v for kk, v in row.items() if kk.startswith(k)), "0") or "0").replace(",", "") or 0)
                try:
                    cr = num("quantity") * num("trade price") / 1e7
                except Exception:
                    cr = 0.0
                out.append({"kind": name, "date": row.get("date"), "sym": s, "sector": SEC.get(s, ""), "client": (row.get("client name") or "")[:44], "side": row.get("buy/sell") or row.get("buy / sell") or "", "cr": round(cr, 1)})
            got.append("%s %d" % (name, n))
        except Exception as ex:
            got.append("%s failed (%s)" % (name, str(ex)[:40]))
    SRC.append("deals: " + ", ".join(got))
    return sorted(out, key=lambda x: -x["cr"])[:25]


def reasons(syms, day):
    """{sym: [text]} - GIR's own company-level reasons (whymove), the newsroom's headlines, else the news lines in today's alerts"""
    out, n_w, n_n = {}, 0, 0
    try:
        import whymove
    except Exception as ex:
        whymove = None; SRC.append("whymove not loaded (%s)" % str(ex)[:50])
    try:
        import newsroom
    except Exception:
        newsroom = None
    for s in syms:
        R = []
        if whymove:
            try:
                for r in whymove.explain(s).get("reasons") or []:
                    if r.get("k") in ("results", "filing", "news", "broker", "due", "event"):
                        R.append(str(r.get("t") or "")[:230]); n_w += 1
            except Exception:
                pass
        if newsroom:
            try:
                for it in newsroom.items_for(s, 40, 0)[:4]:
                    h = str(it.get("h") or "")[:170]
                    if h and not any(h[:40].lower() in x.lower() for x in R):
                        R.append("headline (%s, %s): %s" % (it.get("t"), it.get("src"), h)); n_n += 1
            except Exception:
                pass
        if R:
            out[s] = R[:5]
    if not out:                                          # neither module answered: the news lines GIR sent today
        try:
            c = ro("tomorrow.db")
            for t, s, tx in c.execute("select t, sym, text from alerts where day=? and kind in ('📰','🚨','📄') order by t", (day,)):
                if s in syms:
                    ln = [x.strip() for x in str(tx or "").split("\n") if x.strip() and "SOMETHING IS HAPPENING" not in x and "TRADE ALERT" not in x]
                    out.setdefault(s, []).append("news %s: %s" % (str(t)[:5], " | ".join(ln[:3])[:230]))
            c.close(); out = {s: v[-4:] for s, v in out.items()}
        except Exception:
            pass
    SRC.append("company reasons: %d shares with something (GIR's reasons %d, headlines %d)" % (len(out), n_w, n_n))
    return out


def market_news():
    """the market-wide desk (macro.py): the headlines of the last 30 hours that scored, the strongest first"""
    try:
        j = json.load(open(os.path.join(D, "data", "macro.json")))
        it = [x for x in j.get("items") or [] if time.time() - float(x.get("t") or 0) < 30 * 3600 and (x.get("score") or 0) >= 4]
        it.sort(key=lambda x: (-(x.get("score") or 0), -float(x.get("t") or 0)))
        SRC.append("market-wide news: %d headlines" % len(it))
        return [{"when": dt.datetime.fromtimestamp(float(x["t"]), dt.timezone(dt.timedelta(hours=5, minutes=30))).strftime("%d %b %H:%M"), "source": x.get("src"),
                 "headline": str(x.get("h") or "")[:200], "likely": {1: "market up", -1: "market down"}.get(x.get("side"), ""), "about": x.get("why") or ""} for x in it[:18]]
    except Exception as ex:
        SRC.append("market-wide news: not read (%s)" % str(ex)[:50]); return []


def fpi_flows():
    """NSDL's fortnightly record of foreign funds' buying by sector (fpisec.py keeps it): the last 4 fortnights, ₹ crore, the newest first"""
    try:
        j = json.load(open(os.path.join(D, "data", "fpisec.json")))
        F = sorted(k for k, v in j["net"].items() if len(v) >= 12)[-4:][::-1]
        if not F:
            return None
        SRC.append("FPI sector flows: to %s" % dm(F[0]))
        return {"fortnights_ending": F, "net_equity_cr_newest_first": {s: [j["net"][k].get(s) for k in F] for s in j["net"][F[0]]}}
    except Exception:
        return None


def due(syms, today):
    try:
        c = ro("chains.db")
        r = [(s, d) for s, d in c.execute("select sym, d from results_cal where d>=? and d<=?", (str(today), str(today + dt.timedelta(days=3)))) if s in syms]
        c.close(); return {s: d for s, d in r}
    except Exception:
        return {}


def collect():
    import seclive as SL
    n = SL.now(); today = n.date()
    refresh(today)
    SEC, NAMES = SL.universe(); FO = SL.fo_set(); W, wsrc = SL.nse_weights(); kite = SL.get_kite(); Q = SL.quotes(kite, SEC)
    idx = {}
    try:
        import getdata
        for k, v in (getdata.call(kite.ohlc, ["NSE:NIFTY 50", "NSE:NIFTY BANK", "NSE:INDIA VIX"]) or {}).items():
            cl = float((v.get("ohlc") or {}).get("close") or 0)
            if cl:
                idx[k.split(":")[1]] = round(100 * (float(v["last_price"]) / cl - 1), 2)
    except Exception:
        pass
    G = {}
    for s, sec in SEC.items():
        if s in Q and (W.get(s) or not W):
            lp, pcl = Q[s]; G.setdefault(sec, []).append((s, 100 * (lp / pcl - 1), W.get(s) or 1.0))
    S = []
    for sec, R in G.items():
        if len(R) < 3:
            continue
        w = sum(r[2] for r in R); mv = sum(r[1] * r[2] for r in R) / w; dr = 1 if mv >= 0 else -1
        drivers = sorted(R, key=lambda r: -r[1] * r[2] * dr)[:5]
        lag = sorted([r for r in R if r[0] in FO and r[1] * dr < 0.4 * abs(mv)], key=lambda r: -r[2])[:6] if abs(mv) >= 0.5 else []
        S.append({"sector": sec, "_all": {r[0] for r in R}, "move_pct": round(mv, 2), "shares": len(R), "up": sum(1 for r in R if r[1] > 0), "down": sum(1 for r in R if r[1] < 0),
                  "pushing": [{"sym": s, "company": NAMES.get(s, "")[:36], "move_pct": round(c, 2), "share_of_sector_move_pct": round(100 * c * wt / w / mv) if abs(mv) >= 0.3 else None, "fo": s in FO}
                              for s, c, wt in drivers],
                  "fo_moves": {s: round(c, 2) for s, c, wt in sorted(R, key=lambda r: -r[2]) if s in FO},
                  "fo_not_moved": [{"sym": s, "move_pct": round(c, 2)} for s, c, wt in lag]})
    S.sort(key=lambda x: -x["move_pct"])
    pick = S[:TOP] + S[-TOP:] if len(S) > 2 * TOP else S
    want = []
    for x in pick:
        x["_ask"] = [d["sym"] for d in x["pushing"]] + [s for s, c in sorted(x["fo_moves"].items(), key=lambda kv: -abs(kv[1]))[:6]]
        want += x["_ask"]
    want = list(dict.fromkeys(want)); allsy = {s for x in pick for s in x["_all"]}
    for x in S:
        x.pop("_all", None)
    RS = reasons(want, str(today)); DU = due(set(want) | {s for x in pick for s in x["fo_moves"]}, today)
    DV = delivery(SEC, Q)
    for x in pick:
        x["reasons"] = {s: RS[s] for s in dict.fromkeys(x.pop("_ask")) if s in RS}
        x["results_due"] = {s: DU[s] for s in x["fo_moves"] if s in DU}
        x["delivery"] = DV.get(x["sector"])
    build = sorted(((sec, v["build_5d_vs_20d"]) for sec, v in DV.items() if v.get("build_5d_vs_20d")), key=lambda kv: -kv[1])
    return {"day": str(today), "at": n.strftime("%H:%M"), "weights": wsrc, "indices": idx, "all_sectors": [(x["sector"], x["move_pct"]) for x in S], "sectors": pick,
            "market_news": market_news(), "participants": participants(), "deals": deals(allsy, SEC),
            "delivery_build_5d_vs_20d": build[:6] + build[-4:] if len(build) > 10 else build, "fpi_sector_flows_fortnightly": fpi_flows(), "sources": SRC}


def show(F):
    say("📊 WHO AND WHY · %s %s · %s" % (dm(F["day"]), F["at"], " · ".join("%s %s" % (k, pc(v)) for k, v in F["indices"].items())))
    say("  sectors from all their NSE shares, sizes: %s" % F["weights"])
    say("  " + " · ".join("%s %s" % (a, pc(b)) for a, b in F["all_sectors"]))
    say("  sources: " + " · ".join(F["sources"]))
    say(""); say("WHO - the footprints")
    for p in F["participants"]:
        k5 = next((k for k in p if k.startswith("index_fut_change_") and k != "index_fut_change_1d"), None); s5 = next((k for k in p if k.startswith("stock_fut_change_") and k != "stock_fut_change_1d"), None)
        f = lambda v: "?" if v is None else "%+d" % v
        say("  %-28s index futures net %+8d (day %s, %s %s) · stock futures net %+9d (day %s, %s %s)" % (p["who"], p["index_fut_net"], f(p["index_fut_change_1d"]),
            k5[17:] if k5 else "", f(p.get(k5)), p["stock_fut_net"], f(p["stock_fut_change_1d"]), s5[17:] if s5 else "", f(p.get(s5))))
    if F["participants"]:
        say("    (contracts, NSE's file of %s; + = net long, - = net short)" % dm(F["participants"][0]["day"]))
    else:
        say("  participant positions: not available")
    for x in F["deals"][:10]:
        say("  %s deal %s: %s (%s) %s ₹%s cr · %s" % (x["kind"], x["date"], x["sym"], x["sector"], x["side"], x["cr"], x["client"]))
    if F["delivery_build_5d_vs_20d"]:
        say("  taken home, last 5 days against the 20 before (above 1 = more than usual): " + " · ".join("%s %.2fx" % (a, b) for a, b in F["delivery_build_5d_vs_20d"]))
    for x in F["sectors"]:
        dv = x.get("delivery"); say("")
        say("%s %s %s · %d up, %d down of %d shares" % ("▲" if x["move_pct"] >= 0 else "▼", x["sector"].upper(), pc(x["move_pct"]), x["up"], x["down"], x["shares"]))
        say("    taken home: " + (("₹%s cr = %.2fx its 10-day normal · %s%% of what traded (normal %s%%)%s" % (dv["deliv_cr"], dv["x_10d"] or 0, dv["deliv_pct"], dv["deliv_pct_10d"],
            "" if dv["day"] == F["day"] else " · NSE's file of %s, today's is not out yet" % dm(dv["day"]))) if dv else "no delivery data"))
        say("    pushing it: " + " · ".join("%s %s%s%s" % (d["sym"], pc(d["move_pct"]), (" (%d%% of the move)" % d["share_of_sector_move_pct"]) if d["share_of_sector_move_pct"] is not None else "",
            "" if d["fo"] else " not F&O") for d in x["pushing"]))
        if x["fo_not_moved"]:
            say("    F&O not moved: " + " · ".join("%s %s" % (d["sym"], pc(d["move_pct"])) for d in x["fo_not_moved"]))
        if x["results_due"]:
            say("    results due: " + " · ".join("%s %s" % (s, dm(d)) for s, d in x["results_due"].items()))
        for s, R in x["reasons"].items():
            for r in R[:3]:
                say("    %s: %s" % (s, r[:170]))
        if not x["reasons"]:
            say("    reasons: nothing company-level in GIR's data for these shares")
    if F["market_news"]:
        say(""); say("market-wide news (the strongest first):")
        for a in F["market_news"][:10]:
            say("    %s %s: %s%s" % (a["when"], a["source"], a["headline"][:150], (" [%s]" % a["likely"]) if a["likely"] else ""))


SYSTEM = """You explain to an Indian F&O options trader why stock-market sectors moved today and who was behind it. You are given facts collected by his own system (GIR): each sector's move (all its NSE shares, weighted by size), the shares pushing it, the company-level reasons the system holds (results, exchange filings, checked news, broker calls, results due), market-wide news headlines, NSE's participant positions (FII, DII, proprietary, client; futures contracts), delivery (the value of shares taken home, against the sector's 10-day normal, and the last 5 days against the 20 before), bulk/block deals, and - when present - NSDL's fortnightly record of foreign funds' net buying by sector (it is weeks old: a background lean, never today's cause).

Rules:
- Today's reasons must come from the facts given. Name the share and the reason line you rely on. If the facts hold no reason for a sector, write "no reason in today's data" - never invent news, numbers, events or names.
- You may add what is generally true about what drives that kind of business, but label it "background:" so it cannot be mistaken for today's news, and keep it to one clause.
- Read the footprints with care. Delivery far above normal alongside the price points to investors really buying or selling rather than day trading; delivery at or below normal on a big move points to traders. One share making most of a sector's move is that share's story, not the sector's. Most shares moving the same way with no company news suggests a basket trade, a read-across or a market-wide cause. Participant positions are for the whole market, not one sector: do not claim "FIIs bought this sector" from them; say what they show about the day's mood. If the delivery or position file is from an earlier day than the move, say so and give it little weight.
- If the evidence is thin, say it is thin. A confident wrong reason costs him money.
- Plain English, short sentences, no jargon, no hype. Never promise an outcome and do not tell him to buy or sell; list what is exposed and what to watch.

Write exactly this for each sector, in the order given:
<SECTOR NAME> <move>
WHY: one or two sentences.
KIND: one of - results · policy/government · global/macro · one share's story · sector read-across · flow without news · no reason in today's data
WHO: one sentence on what delivery, deals and positions suggest for this sector.
EXPOSED: the F&O shares of the sector that have not moved with it (or "none").
WATCH TOMORROW: one sentence.

Keep each sector to those five lines. Then end with these two parts:

AFTER THE CLOSE - FOR TOMORROW: go through every reason line and market-wide headline time-stamped after 15:30 today (or marked as tomorrow's event). For each one that could move an F&O share or a sector at tomorrow's open, write one line: the time and headline in a few words → the F&O shares it touches → likely up or down → how sure (strong / moderate / weak) and why. Routine items (small orders, small fines, meetings, ESOPs) are left out. If there is none, write "nothing after the close in the data". This is not yet tested against prices - say so in one closing clause.

THE DAY: three or four sentences - who was moving money across the market today, which sectors show quiet building or selling over the last days, and where the evidence is thin."""


def read(F):
    """Claude reads the facts -> (text, response). The Anthropic SDK reads the key from the environment (the server's .env)."""
    import anthropic
    client = anthropic.Anthropic()
    facts = {k: v for k, v in F.items() if k not in ("weights", "sources")}
    msg = [{"role": "user", "content": "The facts for %s at %s IST (JSON):\n\n%s" % (F["day"], F["at"], json.dumps(facts, ensure_ascii=False, default=str))}]
    def ask(model):                                      # streamed: the answer and its thinking can be long (16 Nov: cut off at 12,000)
        with client.messages.stream(model=model, max_tokens=30000, system=SYSTEM, messages=msg) as st:
            return st.get_final_message()
    try:
        r = ask(MODEL)
    except anthropic.NotFoundError:                      # this key does not have that model: the one GIR's own reader is set to
        alt = os.environ.get("GIR_LLM_MODEL")
        if not alt or alt == MODEL:
            raise
        say("  (%s is not available on this key - read with %s)" % (MODEL, alt))
        r = ask(alt)
    if r.stop_reason == "refusal":
        return "(the model declined to read this - nothing written)", r
    return "\n".join(b.text for b in r.content if b.type == "text").strip(), r


def main():
    F = collect(); show(F)
    os.makedirs(os.path.join(D, "data"), exist_ok=True)
    text = None
    if sys.argv[1:2] != ["facts"]:
        say(""); say("=" * 64); say("THE READING (%s) - from the facts above only" % MODEL); say("")
        try:
            text, r = read(F); say(text)
            u = r.usage; say(""); say("  (read %d tokens, wrote %d%s)" % (u.input_tokens, u.output_tokens, " - CUT OFF at the length limit" if r.stop_reason == "max_tokens" else ""))
        except Exception as ex:
            say("  the reading failed: %s: %s" % (type(ex).__name__, str(ex)[:220])); say("  (the facts above are complete - `python3 whydesk.py facts` skips the reading)")
    out = {"facts": F, "reading": text, "model": MODEL}
    json.dump(out, open(os.path.join(D, "data", "whydesk.json"), "w"), ensure_ascii=False, default=str)
    try:                                                 # one file a day is kept, so the trend can be built from the record later
        os.makedirs(os.path.join(D, "data", "whydesk"), exist_ok=True)
        json.dump(out, open(os.path.join(D, "data", "whydesk", "%s.json" % F["day"]), "w"), ensure_ascii=False, default=str)
    except Exception:
        pass
    open(os.path.join(D, "data", "whydesk.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/whydesk.txt")


if __name__ == "__main__":
    main()

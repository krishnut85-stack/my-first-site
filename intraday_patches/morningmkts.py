#!/usr/bin/env python3
"""morningmkts.py - patch 380: THE OVERNIGHT MARKETS -> INDIAN SECTORS, FOR THE 07:00 MORNING LIST (Rama, 17 Nov 16:45: "how will you know when
something happens, which shares will be affected once the market is over? Start monitoring all the news and the overnight sector movement, and
keep the list ready at 07:00"). GIR read the news through the night, but not the MARKETS that decide which Indian sectors open strong or weak.
  markets()   the overnight close / the live price (Yahoo Finance's public chart feed, no key): the US indices and sector funds, the Indian
              companies traded in New York, crude, gold, silver, copper, aluminium, natural gas, the US 10-year yield, the dollar, the rupee,
              Asia (Japan, Hong Kong, Korea, Shanghai) - each with its move since its previous close
  LINKS       each market mapped to the Indian sectors / F&O shares it usually moves, and which way - written out here, one reason each, so it can
              be read and corrected (they are GIR's working assumptions, not tested yet: the 15:50 score of the morning list tests them)
  calendar()  today: results due (chains.db results_cal), the F&O ban list (NSE's fo_secban file)
Read only. overnight.py (the morning list) uses it at 07:00 and 08:35.   python3 morningmkts.py"""
import os, sys, csv, io, json, time, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
# symbol, the name shown, how big a move counts (%; the yield in points), what it moves in India: [(group - a plain label, not GIR's sector map, F&O shares, +1 same way / -1 opposite / 0 unclear, why)]
LINKS = [
    ("^GSPC", "S&P 500 (US)", 1.0, [("whole market", [], 1, "the US close sets the tone for Asia and the Indian open")]),
    ("^IXIC", "Nasdaq (US tech)", 1.2, [("it", ["INFY", "TCS", "HCLTECH", "WIPRO", "TECHM", "LTM", "PERSISTENT", "COFORGE", "MPHASIS"], 1, "US tech spending sentiment carries to Indian IT")]),
    ("^SOX", "US chip shares (SOX)", 2.0, [("electronics & hardware", ["DIXON", "KAYNES", "PGEL", "AMBER", "SYRMA"], 1, "a weak read-across - global electronics sentiment")]),
    ("XLF", "US banks fund (XLF)", 1.5, [("banks", [], 1, "a weak read-across - global bank sentiment")]),
    ("XLE", "US energy fund (XLE)", 1.5, [("oil producers", ["ONGC", "OIL", "RELIANCE"], 1, "global energy shares")]),
    ("XLV", "US healthcare fund (XLV)", 1.5, [("pharma", [], 1, "a weak read-across - US drug-pricing / healthcare policy")]),
    ("INFY", "Infosys in New York (ADR)", 2.0, [("it", ["INFY"], 1, "the same company, traded overnight")]),
    ("WIT", "Wipro in New York (ADR)", 2.0, [("it", ["WIPRO"], 1, "the same company, traded overnight")]),
    ("HDB", "HDFC Bank in New York (ADR)", 2.0, [("banks", ["HDFCBANK"], 1, "the same company, traded overnight")]),
    ("IBN", "ICICI Bank in New York (ADR)", 2.0, [("banks", ["ICICIBANK"], 1, "the same company, traded overnight")]),
    ("RDY", "Dr Reddy's in New York (ADR)", 2.0, [("pharma", ["DRREDDY"], 1, "the same company, traded overnight")]),
    ("BZ=F", "Brent crude", 2.0, [("oil producers", ["ONGC", "OIL"], 1, "producers earn more on dearer crude"),
                                  ("oil marketers", ["BPCL", "HINDPETRO", "IOC"], -1, "refiners / marketers pay more when crude rises"),
                                  ("paints", ["ASIANPAINT"], -1, "paint inputs are crude derivatives"),
                                  ("airlines", ["INDIGO"], -1, "jet fuel is the biggest airline cost")]),
    ("NG=F", "US natural gas", 4.0, [("gas", ["GAIL", "PETRONET"], 0, "gas prices: mixed for gas transporters / importers")]),
    ("GC=F", "Gold", 1.5, [("gold-loan lenders", ["MUTHOOTFIN", "MANAPPURAM"], 1, "gold-loan lenders: the collateral is worth more"),
                           ("jewellers", ["TITAN", "KALYANKJIL"], 0, "jewellers: stock gains, but demand can fall - unclear")]),
    ("SI=F", "Silver", 2.5, [("metals & mining", ["HINDZINC"], 1, "a large silver producer")]),
    ("HG=F", "Copper", 2.0, [("metals & mining", ["HINDALCO", "VEDL"], 1, "metal producers"),
                             ("cable makers", ["KEI", "POLYCAB"], -1, "cable makers: copper is their main input")]),
    ("ALI=F", "Aluminium", 2.0, [("metals & mining", ["HINDALCO", "NATIONALUM", "VEDL"], 1, "aluminium producers")]),
    ("^TNX", "US 10-year yield", 0.08, [("whole market", [], -1, "higher US yields pull foreign money from India (banks, large caps)")]),
    ("DX-Y.NYB", "US dollar index", 0.6, [("whole market", [], -1, "a strong dollar usually means foreign selling in India")]),
    ("INR=X", "Dollar-rupee", 0.4, [("it (rupee)", ["INFY", "TCS", "HCLTECH", "WIPRO", "TECHM"], 1, "a weaker rupee (dollar up) lifts exporters' earnings"),
                                    ("pharma (rupee)", ["SUNPHARMA", "DRREDDY", "CIPLA", "LUPIN"], 1, "pharma exporters earn in dollars"),
                                    ("oil marketers", ["BPCL", "HINDPETRO", "IOC"], -1, "importers pay more")]),
    ("^N225", "Japan (Nikkei)", 1.2, [("whole market", [], 1, "Asia's morning mood")]),
    ("^HSI", "Hong Kong (Hang Seng)", 1.5, [("metals (China)", ["TATASTEEL", "JSWSTEEL", "HINDALCO", "VEDL", "SAIL"], 1, "China-linked: metal demand"),
                                            ("whole market", [], 1, "Asia's morning mood")]),
    ("^KS11", "Korea (Kospi)", 1.2, [("whole market", [], 1, "Asia's morning mood - foreign money in emerging markets")]),
    ("000001.SS", "Shanghai", 1.2, [("steel (China)", ["TATASTEEL", "JSWSTEEL", "SAIL", "JINDALSTEL"], 1, "China's steel demand")]),
]


def quote(sym):
    """(last, previous session's close, the time of the last price) from Yahoo's public chart feed - None if it does not answer.
    range=1d: Yahoo's chartPreviousClose is then the close of the session before the current one - the same for the indices (closed at
    night) and the futures that trade nearly round the clock (crude, gold), whose daily bars do not line up with Indian dates"""
    import requests
    try:
        for host in ("query1", "query2"):                   # Yahoo's second host when the first refuses
            r = requests.get("https://%s.finance.yahoo.com/v8/finance/chart/%s?range=1d&interval=1h" % (host, sym), timeout=12,
                             headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"})
            if r.status_code == 200:
                break
        if r.status_code != 200:
            return None
        res = (r.json().get("chart") or {}).get("result") or []
        if not res:
            return None
        m = res[0].get("meta") or {}
        last, prev, lt = m.get("regularMarketPrice"), m.get("previousClose") or m.get("chartPreviousClose"), m.get("regularMarketTime")
        if not last or not prev:
            return None
        return float(last), float(prev), int(lt or 0)
    except Exception:
        return None


def markets():
    out = []
    for sym, name, big, links in LINKS:
        q = quote(sym); time.sleep(0.25)
        if not q:
            out.append({"sym": sym, "name": name, "ok": False}); continue
        last, prev, lt = q
        chg = (last - prev) if sym == "^TNX" else 100.0 * (last / prev - 1)
        mv = abs(chg) >= big
        L = []
        for sec, shares, sign, why in links:
            d = 0 if sign == 0 else (1 if chg * sign > 0 else -1)
            L.append({"sector": sec, "shares": shares, "dir": "up" if d > 0 else "down" if d < 0 else "unclear", "why": why})
        out.append({"sym": sym, "name": name, "ok": True, "last": round(last, 4), "chg": round(chg, 3 if sym == "^TNX" else 2), "unit": "pts" if sym == "^TNX" else "%",
                    "at": dt.datetime.fromtimestamp(lt, IST).strftime("%d %b %H:%M") if lt else "", "big": mv, "links": L})
    return out


def calendar(day):
    """today's results due and the F&O ban list"""
    c_ = {"results": [], "ban": [], "ban_note": ""}
    try:
        con = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=10)
        c_["results"] = sorted({s for (s,) in con.execute("select sym from results_cal where d=?", (str(day),))}); con.close()
    except Exception:
        pass
    try:
        import requests
        r = requests.get("https://nsearchives.nseindia.com/content/fo/fo_secban_%s.csv" % day.strftime("%d%m%Y"), timeout=15,
                         headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36", "Referer": "https://www.nseindia.com/"})
        if r.ok and r.text.strip():
            rows = [ln.split(",") for ln in r.text.strip().splitlines()[1:]]
            c_["ban"] = sorted({x[1].strip() for x in rows if len(x) > 1 and x[1].strip()})
        else:
            c_["ban_note"] = "NSE's ban list for %s not read (%s)" % (day, r.status_code)
    except Exception as ex:
        c_["ban_note"] = "NSE's ban list not read: %s" % str(ex)[:50]
    return c_


def lines_for_model(M):
    """the big overnight moves as news lines for the morning list's reader"""
    out = []
    for m in M:
        if m.get("ok") and m.get("big"):
            ln = "; ".join("%s %s (%s)" % ("/".join(l["shares"][:5]) or l["sector"], l["dir"], l["why"]) for l in m["links"])
            out.append("%s %s%.2f%s overnight (as of %s) -> %s" % (m["name"], "+" if m["chg"] > 0 else "", m["chg"], m["unit"] if m["unit"] == "%" else " points", m["at"], ln))
    return out


if __name__ == "__main__":
    M = markets()
    for m in M:
        if not m.get("ok"):
            print("  %-30s not read" % m["name"]); continue
        print("  %-30s %+7.2f%s %s  %s" % (m["name"], m["chg"], m["unit"] if m["unit"] == "%" else "p", " BIG" if m["big"] else "    ", " · ".join("%s %s" % ("/".join(l["shares"][:4]) or l["sector"], l["dir"]) for l in m["links"])))
    c = calendar(dt.datetime.now(IST).date()); print("  results today:", ", ".join(c["results"]) or "none", "· F&O ban:", ", ".join(c["ban"]) or (c["ban_note"] or "none"))

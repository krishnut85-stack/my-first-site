#!/usr/bin/env python3
"""themestudy.py - READ ONLY. THE THEMES: READ-ACROSS AND THE DRAGGED-DOWN BOUNCE (Rama, 16 Nov: "Inox Wind and Vikram Solar reported weak results
and Premier / Waaree fell with them - this is what we should find BEFORE it happens" · "ABB had a good result and was still crushed by the sector
wave - when the sector comes back that share will bounce").
NSE's sectors are too wide (Inox Wind, Waaree and Premier sit inside 119 'capital goods' shares). Here every F&O share is in a TIGHT business group -
a THEME - with what drives it at home and abroad (THEMES below). On Kite's 5-minute prices of the last 60 trading days:
  1) READ-ACROSS   one share of a theme has moved 3%+ (a shock - a result, an order, a downgrade) while a peer of the same theme has moved less than
                   half of that: does the PEER follow in the same direction? At 09:30 / 09:45 / 10:00 / 10:30 / 11:00, to 2 hours later and to 15:10.
                   Split: the size of the shock · a shock that was there at the open (overnight - a result) or built in the day · a peer still flat
                   or already leaning · and against "no shock in the theme" (the base).
  2) DRAGGED DOWN -> BOUNCE   a share that fell 2%+ yesterday WITH its theme (the theme -1%+; the share not far worse than the theme - a wave, not
                   its own bad news): today, when the theme TURNS (up 0.3%+ with 60%+ of its shares green at 09:45 / 10:00 / 10:30), does the
                   dragged share bounce more than the others? Against: the theme has not turned · the theme's other shares on a turn day.
  3) THE THEMES    the list, the F&O shares in each and what moves it.
CE = up, PE = down. The moves are the SHARE's (%). "worked" = +1.5% its way before -1%. Orders nothing, sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 themestudy.py   -> prints, saves data/themestudy.txt"""
import os, sys, datetime as dt
import numpy as np
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
TS = (15, 30, 45, 75, 105)                       # 09:30 09:45 10:00 10:30 11:00
END = 355
hm = lambda m: "%02d:%02d" % ((555 + m) // 60, (555 + m) % 60)
# theme: (its F&O shares, peers that are not F&O but set the tone, what drives it)
THEMES = {
 "renewables - solar & wind makers": ("WAAREEENER PREMIERENE INOXWIND SUZLON", "VIKRAMSOLR ACMESOLAR SWSOLAR KPIGREEN WEBELSOLAR", "module / turbine prices and margins · order execution · import duty and ALMM / PLI policy · China's module glut · US tariffs on solar · their own results (one bad margin reads across to all)"),
 "power - generation & utilities": ("NTPC TATAPOWER ADANIPOWER JSWENERGY NHPC ADANIGREEN POWERGRID ADANIENSOL", "TORNTPOWER SJVN NLCINDIA", "power demand (heat, monsoon) · coal supply and prices · tariff orders · capex plans · bond yields (they borrow heavily)"),
 "electrical equipment & T&D": ("ABB SIEMENS CGPOWER GVT&D POWERINDIA ENRIN BHEL CUMMINSIND", "THERMAX HITACHIENERGY", "order inflows · government and private capex · transmission tenders · margins and execution · high valuations (they fall hard on any miss - and bounce together)"),
 "PSU lenders - power & rail": ("PFC RECLTD IREDA IRFC", "HUDCO", "power-sector capex · RBI project-finance rules · bond yields · government stake sales"),
 "hospitals": ("MAXHEALTH APOLLOHOSP FORTIS", "NH MEDANTA ASTERDM KIMS", "occupancy and revenue per bed · new beds · insurance / government price caps · results (one strong quarter lifts all)"),
 "pharma - US generics": ("SUNPHARMA DRREDDY CIPLA LUPIN AUROPHARMA ZYDUSLIFE GLENMARK BIOCON", "", "US price erosion · USFDA inspections and warning letters · the dollar · US tariff talk on drugs · product launches (gRevlimid and others)"),
 "pharma - domestic brands": ("TORNTPHARM ALKEM MANKIND", "ABBOTINDIA JBCHEPHARM", "domestic prescription growth · price control list (NLEM) · acquisitions"),
 "pharma - CDMO & API": ("DIVISLAB LAURUSLABS", "SYNGENE PPLPHARMA", "global innovator contracts · the US Biosecure Act (China out) · API prices"),
 "electronics makers (EMS)": ("KAYNES DIXON SYRMA AMBER PGEL", "CYIENTDLM AVALON", "PLI scheme · client orders (mobile, AC, auto) · working capital and margins · very high valuations (results shocks read across at once)"),
 "defence": ("HAL BEL BDL DATAPATTNS SOLARINDS MAZDOCK COCHINSHIP", "BEML GRSE", "defence orders and the budget · border tension · export deals · execution"),
 "railways & PSU infra": ("RVNL CONCOR NBCC", "IRCON RAILTEL TITAGARH", "rail budget and tenders · order wins · government capex"),
 "PSU banks": ("SBIN BANKBARODA PNB CANBK UNIONBANK BANKINDIA INDIANB MAHABANK", "", "bond yields (treasury gains) · credit growth · bad-loan trends · government stake / merger news · RBI policy"),
 "private banks - large": ("HDFCBANK ICICIBANK AXISBANK KOTAKBANK INDUSINDBK", "", "loan and deposit growth · margins when rates move · FII flows (they are the index) · RBI actions"),
 "private banks - mid & small": ("FEDERALBNK IDFCFIRSTB BANDHANBNK RBLBANK YESBANK AUBANK CUB KARURVYSYA UJJIVANSFB", "", "microfinance and unsecured-loan stress · deposit costs · stake sales and takeovers"),
 "NBFC lenders": ("BAJFINANCE BAJAJFINSV CHOLAFIN SHRIRAMFIN LTF ABCAPITAL JIOFIN SBICARD", "", "interest rates and liquidity · RBI risk weights · asset quality in unsecured / vehicle loans"),
 "housing finance": ("LICHSGFIN PNBHOUSING", "CANFINHOME HOMEFIRST", "home-loan demand · rate cuts · competition from banks"),
 "gold lenders": ("MUTHOOTFIN MANAPPURAM", "", "the gold price · RBI gold-loan rules (LTV)"),
 "insurance": ("SBILIFE HDFCLIFE ICICIPRULI ICICILIFE LICI MFSL ICICIGI POLICYBZR", "", "premium growth each month · regulation (surrender value, commissions, GST) · bond yields"),
 "capital markets": ("BSE MCX CDSL CAMS KFINTECH ANGELONE MOTILALOFS 360ONE ANANDRATHI HDFCAMC NAM-INDIA IEX", "", "market volumes and F&O rules (SEBI) · new demat accounts · mutual-fund flows · for IEX: power-market coupling rules"),
 "IT services - large": ("TCS INFY HCLTECH WIPRO TECHM LTM LTIM", "", "US tech spending and Nasdaq · the dollar · US visa (H-1B) and tariff news · deal wins · Accenture's results (the lead indicator)"),
 "IT services - mid & ER&D": ("PERSISTENT COFORGE MPHASIS OFSS KPITTECH TATAELXSI SAGILITY", "", "the same as large IT, with bigger moves · client concentration · auto / telecom R&D budgets"),
 "internet platforms": ("ETERNAL SWIGGY NYKAA PAYTM NAUKRI", "", "quick-commerce competition and cash burn · regulation (payments, e-commerce) · lock-in expiries and block deals"),
 "autos - cars & SUVs": ("MARUTI M&M HYUNDAI TMPV", "", "monthly sales (1st of the month) · GST / tax changes · rural demand · the yen and input costs · EV policy"),
 "autos - two-wheelers": ("BAJAJ-AUTO HEROMOTOCO TVSMOTOR EICHERMOT ATHERENERG", "", "monthly sales · rural income and monsoon · exports (Africa, LatAm) · EV subsidies"),
 "autos - trucks & parts": ("ASHOKLEY FORCEMOT MOTHERSON BOSCHLTD SONACOMS UNOMINDA BHARATFORG TIINDIA", "", "truck sales and freight · US / Europe auto demand and tariffs (parts exporters) · EV orders"),
 "steel & iron ore": ("TATASTEEL JSWSTEEL JINDALSTEL SAIL NMDC APLAPOLLO", "", "China's steel prices and stimulus · safeguard / import duty · coking coal and iron-ore prices · the dollar"),
 "non-ferrous metals & coal": ("HINDALCO VEDL HINDZINC NATIONALUM COALINDIA", "", "LME aluminium, zinc, copper · China demand · the dollar · for Vedanta: dividends and the demerger"),
 "oil & gas - producers": ("ONGC OIL", "", "crude price up = good · windfall tax · gas price orders"),
 "oil & gas - refiners & marketers": ("BPCL HINDPETRO IOC", "", "crude price up = bad · marketing margins · LPG losses and government compensation · fuel price decisions"),
 "oil & gas - gas & Reliance": ("GAIL PETRONET RELIANCE", "IGL MGL GUJGASLTD", "gas prices and allocation · for Reliance: refining margins, Jio tariffs, retail"),
 "cement": ("ULTRACEMCO SHREECEM AMBUJACEM GRASIM", "DALBHARAT ACC JKCEMENT", "cement price hikes (dealer checks) · monsoon and construction season · fuel (petcoke) cost · capacity mergers"),
 "cables, pipes & paints": ("POLYCAB KEI HAVELLS ASTRAL SUPREMEIND ASIANPAINT PIDILITIND", "BERGEPAINT", "housing and capex demand · copper / PVC / crude prices · new competition (cables: Birla / Adani; paints: Birla Opus)"),
 "cooling & appliances": ("VOLTAS BLUESTARCO CROMPTON", "WHIRLPOOL", "summer heat and channel stock · copper prices · GST changes"),
 "FMCG staples": ("HINDUNILVR ITC NESTLEIND BRITANNIA DABUR MARICO GODREJCP COLPAL TATACONSUM PATANJALI VBL", "", "rural demand and monsoon · palm oil, wheat, milk prices · price cuts / hikes · GST · for ITC: cigarette tax"),
 "alcohol & tobacco": ("UNITDSPR RADICO GODFRYPHLP", "", "state excise policy · tax on tobacco · barley / ENA prices"),
 "retail & jewellery": ("TRENT DMART TITAN KALYANKJIL PAGEIND VMM JUBLFOOD", "", "store growth and same-store sales · the gold price (jewellers) · festive demand · quarterly updates before results"),
 "real estate": ("DLF LODHA GODREJPROP OBEROIRLTY PRESTIGE PHOENIXLTD", "", "pre-sales updates · interest rates · launches · stamp-duty and policy news"),
 "travel - airlines, hotels, airports": ("INDIGO INDHOTEL GMRAIRPORT", "", "crude / jet fuel · the rupee · air-traffic data · room rates and wedding / holiday season"),
 "chemicals & agri inputs": ("SRF NAVINFLUOR PIIND UPL COROMANDEL", "", "China's chemical prices and dumping · refrigerant gas prices · monsoon and sowing · fertiliser subsidy"),
 "telecom": ("BHARTIARTL IDEA INDUSTOWER", "", "tariff hikes · AGR dues and court orders · Vodafone Idea funding · 5G spending"),
 "construction, ports & logistics": ("LT ADANIPORTS ADANIENT DELHIVERY", "", "order inflows · Middle-East orders (L&T) · cargo volumes · freight rates"),
}
GROUPS = {"adani group": "ADANIENT ADANIPORTS ADANIGREEN ADANIPOWER ADANIENSOL AMBUJACEM"}   # a second tie: a group shock reads across all of it


def say(s=""):
    L.append(s); print(s, flush=True)


def stat(X, k="ret2"):
    if not X:
        return None
    n = len(X); return n, 100.0 * sum(1 for x in X if x[k] > 0) / n, 100.0 * sum(x[k] for x in X) / n, 100.0 * sum(1 for x in X if x["hit"] > 0) / n, 100.0 * sum(x["ret"] for x in X) / n


def line(name, X):
    s = stat(X)
    if not s:
        return "    %-52s -" % name
    return "    %-52s %5d picks · 2 hours later: %3.0f%% its way, average %+.2f%% · at 15:10: %+.2f%% · worked %2.0f%%" % (name, s[0], s[1], s[2], s[4], s[3])


def outcome(b, T, p, dr):
    """the share from minute T: after 2 hours, at 15:10, and +1.5% before -1%"""
    a = b[(b[:, 0] >= T) & (b[:, 0] <= END - 5)]
    if not len(a):
        return None
    hit = 0
    for row in a:
        lo = ((row[3] if dr > 0 else row[2]) / p - 1) * dr; hi = ((row[2] if dr > 0 else row[3]) / p - 1) * dr
        if lo <= -0.010:
            hit = -1; break
        if hi >= 0.015:
            hit = 1; break
    a2 = a[a[:, 0] <= T + 115]
    return {"ret": (float(a[-1, 4]) / p - 1) * dr, "ret2": (float(a2[-1, 4]) / p - 1) * dr if len(a2) else 0.0, "hit": hit}


def main(themes=None):
    import seclive as SL, sectorstudy as SS
    TH = themes or THEMES
    FO = SL.fo_set(); kite = SL.get_kite()
    mem = {}                                                                 # sym -> theme (its first)
    for t, (fo, also, why) in TH.items():
        for s in (fo + " " + also).split():
            mem.setdefault(s, t)
    say("📊 THE THEMES · read-across and the dragged-down bounce · Kite 5-minute prices, the last 60 trading days")
    RAW = SS.fetch_all(kite, list(mem), 60)
    P = {s: SS.by_day(a) for s, a in RAW.items()}
    days = sorted(P.get("NIFTY50", {}))
    px = lambda b, T: (float(b[b[:, 0] <= T - 5][-1, 4]) if (b[:, 0] <= T - 5).any() else None)
    tfo = {t: [s for s in fo.split() if s in P and (not FO or s in FO)] for t, (fo, also, why) in TH.items()}
    tall = {t: [s for s in (fo + " " + also).split() if s in P] for t, (fo, also, why) in TH.items()}
    say("  %d themes · %d of their F&O shares with prices · %d days" % (len(TH), len({s for v in tfo.values() for s in v}), len(days) - 1))
    RA = {T: [] for T in TS}; BASE = {T: [] for T in TS}; DR = {T: {"turn": [], "noturn": [], "others": []} for T in (30, 45, 75)}
    EX = []
    for di in range(1, len(days)):
        d, dp = days[di], days[di - 1]; day = str(dt.date.fromordinal(d)); dpp = days[di - 2] if di >= 2 else None
        for t in TH:
            R = {}
            for s in tall[t]:
                b, bp = P[s].get(d), P[s].get(dp)
                if b is not None and bp is not None and len(b) >= 30:
                    R[s] = (float(bp[-1, 4]), b, float(b[0, 1]))
            if len(R) < 2:
                continue
            ymove = {}                                                       # yesterday's close-to-close, for the bounce
            if dpp is not None:
                for s in R:
                    b2 = P[s].get(dpp)
                    if b2 is not None:
                        ymove[s] = R[s][0] / float(b2[-1, 4]) - 1
            yth = (sum(ymove.values()) / len(ymove)) if len(ymove) >= 2 else None
            for T in TS:
                c = {s: (px(b, T) / pc - 1) for s, (pc, b, o) in R.items() if px(b, T)}
                if len(c) < 2:
                    continue
                lead = max(c, key=lambda s: abs(c[s])); lv = c[lead]
                shock = abs(lv) >= 0.03
                for s in tfo[t]:
                    if s not in c or s == lead:
                        continue
                    pc, b, o = R[s]; p = px(b, T)
                    if shock and abs(c[s]) < 0.5 * abs(lv) and c[s] * np.sign(lv) > -0.01:      # a peer that has not followed yet (and is not going hard the other way)
                        dr = 1 if lv > 0 else -1; r = outcome(b, T, p, dr)
                        if r:
                            gap = (R[lead][2] / R[lead][0] - 1) * dr
                            r.update({"s": s, "day": day, "lead": lead, "lv": lv, "big": abs(lv) >= 0.05, "overnight": gap >= 0.6 * abs(lv), "flat": abs(c[s]) < 0.005,
                                      "leadfo": lead in FO, "theme": t, "c": c[s]})
                            RA[T].append(r)
                            if T == 30:
                                EX.append((day, t, lead, lv, s, c[s], r["ret2"], r["ret"]))
                    elif not shock:
                        dr = 1 if c[s] >= 0 else -1; r = outcome(b, T, p, dr)
                        if r:
                            BASE[T].append(r)
                if T in DR and yth is not None and yth <= -0.01:             # 2) the theme fell yesterday
                    up = sum(1 for v in c.values() if v > 0) / len(c); tnow = sum(c.values()) / len(c); turned = tnow >= 0.003 and up >= 0.6
                    for s in tfo[t]:
                        if s not in c or s not in ymove:
                            continue
                        pc, b, o = R[s]; r = outcome(b, T, px(b, T), 1)
                        if not r:
                            continue
                        dragged = ymove[s] <= -0.02 and ymove[s] >= 2.0 * yth - 0.01
                        r.update({"s": s, "day": day, "theme": t, "y": ymove[s]})
                        if dragged:
                            DR[T]["turn" if turned else "noturn"].append(r)
                        elif turned:
                            DR[T]["others"].append(r)
    say("")
    say("1) READ-ACROSS - one share of the theme has moved 3%+; a peer of the same theme has moved less than half of that. Does the PEER follow?")
    say("   (the peer is bought the leader's way: CE if the leader is up, PE if it is down)")
    for T in TS:
        X = RA[T]
        say("  %s" % hm(T))
        say(line("every peer of a 3%+ shock", X))
        say(line("  the shock is 5%+", [x for x in X if x["big"]]))
        say(line("  the shock was there at the open (overnight)", [x for x in X if x["overnight"]]))
        say(line("  the shock built during the day", [x for x in X if not x["overnight"]]))
        say(line("  the peer still flat (under 0.5%)", [x for x in X if x["flat"]]))
        say(line("  the peer already leaning that way", [x for x in X if not x["flat"] and x["c"] * (1 if x["lv"] > 0 else -1) > 0]))
        say(line("  the shock is DOWN (PE on the peers)", [x for x in X if x["lv"] < 0]))
        say(line("  the shock is UP (CE on the peers)", [x for x in X if x["lv"] > 0]))
        say(line("BASE - no 3% shock in the theme, the share its own way", BASE[T]))
    say("")
    say("   by theme at 09:45 (themes with 8+ cases):")
    bt = {}
    for x in RA[30]:
        bt.setdefault(x["theme"], []).append(x)
    for t, X in sorted(bt.items(), key=lambda kv: -(stat(kv[1])[2] if len(kv[1]) >= 8 else -99)):
        if len(X) >= 8:
            say(line("  " + t[:48], X))
    say("")
    say("   the last cases at 09:45 (the leader, the peer, the peer 2 hours later / at 15:10 - in the leader's direction):")
    for day, t, lead, lv, s, c, r2, r in EX[-18:]:
        say("    %s %-34s %-11s %+5.1f%% -> %-11s was %+5.1f%% · then %+5.2f%% in 2 hours · %+5.2f%% at 15:10" % (day[5:], t[:34], lead, lv * 100, s, c * 100, r2 * 100, r * 100))
    say("")
    say("2) DRAGGED DOWN -> BOUNCE - the share fell 2%+ yesterday with its theme (the theme -1%+, the share not far worse than the theme). Today, CE:")
    for T in sorted(DR):
        say("  %s" % hm(T))
        say(line("the theme has TURNED up (0.3%+, 60%+ green): the dragged", DR[T]["turn"]))
        say(line("the theme has NOT turned: the dragged share", DR[T]["noturn"]))
        say(line("the theme has turned: its OTHER shares", DR[T]["others"]))
    say("")
    say("3) THE THEMES - the F&O shares in each, and what moves it")
    for t, (fo, also, why) in TH.items():
        say("  %s (%d F&O): %s%s" % (t.upper(), len(tfo[t]), " ".join(tfo[t]), (" · also watched: " + also) if also else ""))
        say("      moved by: %s" % why)
    for g, m in GROUPS.items():
        say("  %s: %s - a shock to the group reads across all of it" % (g.upper(), m))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "themestudy.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/themestudy.txt")


if __name__ == "__main__":
    main()

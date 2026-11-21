#!/usr/bin/env python3
"""Score the trader's market reads (TRADER_CALLS.md) from the minute store + NSE closes. Read-only on desk data."""
import os, io, csv, json, glob, zipfile, statistics, datetime as dt
import numpy as np

SP = os.path.dirname(os.path.abspath(__file__))
BHAV = os.path.join(os.path.dirname(SP), "dl_bhav")
MIN = "/home/globalbot/girdata/minute"
HIST = "/home/globalbot/girdata/history"
SECT = json.load(open("/root/hist/sectors.json"))

def fo_list():
    z = zipfile.ZipFile("/root/hist/fo_20261119.csv.zip")
    r = csv.DictReader(io.TextIOWrapper(z.open(z.namelist()[0])))
    return set(x["TckrSymb"] for x in r)
FO = fo_list()

# trading days (from the NSE calendar cache + 20 Nov)
CAL = json.load(open("/home/globalbot/girdata/archive/calendar.json"))
DAYS = sorted(set([x["date"] for x in CAL["days"] if x["session"]] + ["2026-11-20"]))
DAYS = [d for d in DAYS if "2026-11-02" <= d <= "2026-11-20"]

def nextday(d):
    i = DAYS.index(d)
    return DAYS[i + 1] if i + 1 < len(DAYS) else None

def prevday(d):
    return DAYS[DAYS.index(d) - 1]

# ---- official closes: NSE CM bhavcopy (EQ/BE), else Kite daily history (matches bhav on all 218 checked)
_bhav = {}
def bhav(day):
    if day in _bhav:
        return _bhav[day]
    f = os.path.join(BHAV, "cm_%s.zip" % day.replace("-", ""))
    out = {}
    if os.path.exists(f):
        z = zipfile.ZipFile(f)
        for x in csv.DictReader(io.TextIOWrapper(z.open(z.namelist()[0]))):
            if x["SctySrs"] in ("EQ", "BE", "BZ"):
                out[x["TckrSymb"]] = {k: float(x[v]) for k, v in (("o", "OpnPric"), ("h", "HghPric"), ("l", "LwPric"), ("c", "ClsPric"))}
    _bhav[day] = out
    return out

_hist = {}
def hist(sym):
    if sym not in _hist:
        f = os.path.join(HIST, ("ix_%s.npz" if sym.startswith("NIFTY") else "eq_%s.npz") % sym)
        _hist[sym] = np.load(f) if os.path.exists(f) else None
    return _hist[sym]

SRC = {}
def daybar(sym, day):
    b = bhav(day).get(sym)
    if b:
        SRC.setdefault(day, set()).add("bhav")
        return b
    h = hist(sym)
    if h is not None:
        i = np.where(h["d"] == dt.date.fromisoformat(day).toordinal())[0]
        if len(i):
            SRC.setdefault(day, set()).add("kite-daily")
            j = i[0]
            return {"o": float(h["o"][j]), "h": float(h["h"][j]), "l": float(h["l"][j]), "c": float(h["c"][j])}
    return None

_min = {}
def minute(sym, day, kind="eq"):
    k = (sym, day, kind)
    if k not in _min:
        f = os.path.join(MIN, day, "%s__%s.npz" % (sym, kind))
        _min[k] = np.load(f) if os.path.exists(f) else None
    return _min[k]

def base(day):
    return (dt.date.fromisoformat(day) - dt.date(1970, 1, 1)).days * 86400

def secs(hhmm):
    h, m = hhmm.split(":")
    return int(h) * 3600 + int(m) * 60

def price_at(sym, day, hhmm):
    """price at the start of minute hhmm (that bar's open); NIFTY from the index file"""
    z = minute("NIFTY_50", day, "ix") if sym == "NIFTY_50" else minute(sym, day)
    if z is None:
        return None
    t = base(day) + secs(hhmm)
    i = np.searchsorted(z["t"], t)
    if i < len(z["t"]) and z["t"][i] == t:
        return float(z["o"][i])
    if i == 0:
        return None
    return float(z["c"][i - 1])

def hilo_after(sym, day, hhmm):
    z = minute(sym, day)
    if z is None:
        return None, None
    m = z["t"] >= base(day) + secs(hhmm)
    if not m.any():
        return None, None
    return float(z["h"][m].max()), float(z["l"][m].min())

def entry(sym, day, at):
    """at = 'open' | 'prevclose' | 'HH:MM'"""
    if at == "open":
        b = daybar(sym, day); return b and b["o"]
    if at == "prevclose":
        b = daybar(sym, prevday(day)); return b and b["c"]
    if sym == "NIFTY_50":
        return price_at("NIFTY_50", day, at)
    return price_at(sym, day, at)

def close(sym, day):
    if day is None:
        return None
    b = daybar(sym, day); return b and b["c"]

def pct(a, b):
    return None if (a is None or b is None or b == 0) else round((a / b - 1) * 100, 2)

def move(sym, day, at):
    e = entry(sym, day, at)
    return e, pct(close(sym, day), e), pct(close(sym, nextday(day)), e)

def sector_of(sym):
    for k, v in SECT.items():
        if sym in v:
            return k
    return None

def members(sec, excl=()):
    return [s for s in dict.fromkeys(SECT[sec]) if s in FO and s not in excl]

def med(xs):
    xs = [x for x in xs if x is not None]
    return (round(statistics.median(xs), 2), len(xs)) if xs else (None, 0)

def basket(syms, day, at):
    rows = {s: move(s, day, at) for s in syms}
    d0 = med([r[1] for r in rows.values()]); d1 = med([r[2] for r in rows.values()])
    return rows, d0, d1

def side_ok(x, want):
    if x is None:
        return None
    return x > 0 if want == "UP" else x < 0

DEF8 = ["HAL", "BEL", "BDL", "MAZDOCK", "COCHINSHIP", "SOLARINDS", "DATAPATTNS", "BHARATFORG"]
EMS5 = ["DIXON", "KAYNES", "PGEL", "AMBER", "SYRMA"]
AUTO = members("auto")
DURABLES = ["VOLTAS", "BLUESTARCO", "HAVELLS", "CROMPTON", "DIXON", "AMBER", "PGEL", "TITAN", "KALYANKJIL"]
METALS = members("metals")
PVTBANKS = [s for s in ["AXISBANK", "BANDHANBNK", "FEDERALBNK", "HDFCBANK", "ICICIBANK", "IDFCFIRSTB", "INDUSINDBK", "KOTAKBANK", "YESBANK",
                        "AUBANK", "RBLBANK", "CUB", "KARURVYSYA", "UJJIVANSFB"] if s in FO]
BANKS = members("banks")
STEEL = ["TATASTEEL", "JSWSTEEL"]

# id, row no, said (IST), words, want, side, target (sym or basket list), day of entry, entry 'at', extra basis, counted?, note, sector override
READS = [
 dict(id="R02", row=2, said="Sun 8 Nov 07:35", want="UP", tgt="DIVISLAB", day="2026-11-08", at="open", alt="prevclose",
      note="First tradable price after 07:35 = the 8 Nov Muhurat session open (14:20); next day = Mon 9 Nov."),
 dict(id="R03", row=3, said="Sun 8 Nov 20:45 / Mon 9 Nov 10:38", want=None, tgt="DATAPATTNS", day="2026-11-09", at="10:38", alt="open",
      note="'Keep a close watch' on the board meeting: no direction given - move shown, not counted."),
 dict(id="R04", row=4, said="Mon 9 Nov 08:46", want="UP", tgt="EICHERMOT", day="2026-11-09", at="open", alt="prevclose",
      note="Pre-open: from the 9 Nov open (alt: from the 8 Nov Muhurat close)."),
 dict(id="R05", row=5, said="Mon 9 Nov 11:18", want="UP", tgt="COCHINSHIP", day="2026-11-09", at="11:18", alt="open"),
 dict(id="R06", row=6, said="Mon 9 Nov 22:46", want="DOWN", tgt="GLENMARK", day="2026-11-11", at="open", alt="prevclose",
      note="Warning 'overbought - no CE' scored as the PE side (right = it did not rise). 10 Nov was an NSE holiday, so from the 11 Nov open."),
 dict(id="R07", row=7, said="Tue 10 Nov 14:50", want="DOWN", tgt="COCHINSHIP", day="2026-11-11", at="open", alt="prevclose", level=("<=", 1180),
      note="10 Nov was an NSE holiday (Diwali-Balipratipada): first tradable price = 11 Nov open; alt = from the 9 Nov close (before the results)."),
 dict(id="R08", row=8, said="Wed 11 Nov 09:40", want="UP", tgt="SWIGGY", day="2026-11-11", at="09:40", alt="open"),
 dict(id="R09", row=9, said="Thu 12 Nov 09:41", want="UP", tgt="DATAPATTNS", day="2026-11-12", at="09:41", alt="open", level=(">=", 4200, "floor"),
      note="Floor 4,200: lowest price after 09:41 shown."),
 dict(id="R10", row=10, said="Thu 12 Nov 14:32", want="UP", tgt="POLICYBZR", day="2026-11-12", at="14:32", alt="open"),
 dict(id="R11", row=11, said="Fri 13 Nov 06:37 (again 15:24, 16:38)", want="UP", tgt="POLICYBZR", day="2026-11-13", at="open", alt="prevclose",
      note="First words 06:37 on 13 Nov, so from the 13 Nov open; next day = Mon 16 Nov, the day he named."),
 dict(id="R12", row=12, said="Fri 13 Nov 11:48", want="DOWN", tgt="NMDC", day="2026-11-13", at="11:48", alt="open", level=("<=", 65)),
 dict(id="R13", row=13, said="Fri 13 Nov 12:33", want="UP", tgt="POWERINDIA", day="2026-11-13", at="12:33", alt="open", level=(">=", 33000)),
 dict(id="R14", row=14, said="Fri 13 Nov 13:00", want="DOWN", tgt="HINDALCO", day="2026-11-13", at="13:00", alt="open"),
 dict(id="R15", row=15, said="Fri 13 Nov 13:04-13:51", want="UP", tgt="RVNL", day="2026-11-13", at="13:51", alt="open", trigger=200.0,
      note="Conditional: CE only above 200. Counted only if 200 traded after 13:51 (checked to 20 Nov)."),
 dict(id="R16", row=16, said="Sat 14 Nov 22:57", want="DOWN", tgt="PATANJALI", day="2026-11-16", at="open", alt="prevclose",
      note="His condition (NIFTY down, money pulled out) not modelled: scored from the 16 Nov open."),
 dict(id="R17", row=17, said="Sat 14 Nov 17:46", want="DOWN", tgt="POLICYBZR", day="2026-11-16", at="open", alt="prevclose", level=("<", 1100, "cap"),
      note="'Resistance at 1,100' scored as the PE side (no CE) from the 16 Nov open; 1,100 check on the close."),
 dict(id="R18", row=18, said="Sun 15 Nov 10:28", want="DOWN", tgt="TMPV", day="2026-11-16", at="open", alt="prevclose"),
 dict(id="R19", row=19, said="Sun 15 Nov 11:06", want="DOWN", tgt="RELIANCE", day="2026-11-16", at="open", alt="prevclose", level=("<=", 1320)),
 dict(id="R20", row=20, said="Mon 16 Nov 09:47", want="UP", tgt="KAYNES", day="2026-11-16", at="09:47", alt="open"),
 dict(id="R21", row=21, said="Mon 16 Nov 21:47", want="UP", tgt="ABB", day="2026-11-17", at="open", alt="prevclose", cond="capital-goods",
      note="Conditional on capital goods turning up - not counted; ABB and the capital-goods median shown."),
 dict(id="R22a", row=22, said="Tue 17 Nov 00:47", want=None, tgt=members("it"), name="IT (FII buying)", day="2026-11-17", at="open", alt="prevclose",
      note="A flow statement; he said it is not a CE / PE reason by itself - shown, not counted."),
 dict(id="R22b", row=22, said="Tue 17 Nov 00:47", want=None, tgt=members("oil-gas"), name="Oil & gas (FII selling)", day="2026-11-17", at="open", alt="prevclose",
      note="As R22a - shown, not counted."),
 dict(id="R23", row=23, said="Tue 17 Nov 07:36", want="DOWN", tgt=STEEL, name="Steel (TATASTEEL, JSWSTEEL)", day="2026-11-17", at="open", alt="prevclose", sector="metals"),
 dict(id="R24", row=24, said="Tue 17 Nov 09:05", want="DOWN", tgt=PVTBANKS, name="Private banks (F&O)", day="2026-11-17", at="open", alt="prevclose", sector="banks"),
 dict(id="R25", row=25, said="Tue 17 Nov 12:15", want="UP", tgt="ADANIENSOL", day="2026-11-17", at="12:15", alt="open",
      note="He asked about 18 Nov: the next-day close (18 Nov) is the main horizon.", primary="d1"),
 dict(id="R26", row=26, said="Tue 17 Nov 12:16", want=None, tgt="HEROMOTOCO", day="2026-11-17", at="12:16", alt="open",
      note="Watch (OI up, price flat): no direction - shown, not counted."),
 dict(id="R27", row=27, said="Tue 17 Nov 12:30", want="DOWN", tgt="ANGELONE", day="2026-11-17", at="12:30", alt="open",
      note="Said after the fall had started ('fell from 8 to 1 percent')."),
 dict(id="R28", row=28, said="Wed 18 Nov 08:13", want="DOWN", tgt="MANAPPURAM", day="2026-11-18", at="open", alt="prevclose"),
 dict(id="R29", row=29, said="Wed 18 Nov 12:20 (his trade was earlier, time not known)", want="DOWN", tgt="TITAN", day="2026-11-18", at="12:20", alt="open",
      note="Scored from 12:20, the time of his message; alt = from the open (his trade time is unknown)."),
 dict(id="R30", row=30, said="Wed 18 Nov 12:20", want="DOWN", tgt="KALYANKJIL", day="2026-11-18", at="12:20", alt="open",
      note="Said after the share had already crossed -3% (11:40)."),
 dict(id="R31", row=31, said="Thu 19 Nov 09:13", want="DOWN", tgt="UNITDSPR", day="2026-11-19", at="open", alt="prevclose"),
 dict(id="R32", row=32, said="Thu 19 Nov 12:52", want="DOWN", tgt=BANKS, name="Banks (F&O)", day="2026-11-19", at="12:52", alt="open",
      note="Asked as a question ('correct? I don't understand'); counted, as in the desk's table."),
 dict(id="R33a", row=33, said="Thu 19 Nov 14:44", want="DOWN", tgt=AUTO, name="Auto (F&O)", day="2026-11-19", at="14:44", alt=None,
      note="He meant 20 Nov: the 20 Nov close (next-day column) is the one that counts for this read.", primary="d1"),
 dict(id="R33b", row=33, said="Thu 19 Nov 14:44", want="DOWN", tgt=DURABLES, name="Consumer durables / ACs (F&O)", day="2026-11-19", at="14:44", alt=None, sector="consumer",
      note="VOLTAS, BLUESTARCO, HAVELLS, CROMPTON, DIXON, AMBER, PGEL, TITAN, KALYANKJIL. Scored on the 20 Nov close.", primary="d1"),
 dict(id="R33c", row=33, said="Thu 19 Nov 14:44", want="UP", tgt=METALS, name="Metals 'come back' (F&O)", day="2026-11-19", at="14:44", alt=None,
      note="'It will again come back' - read as metals up after the 52-week low; implied, scored on the 20 Nov close.", primary="d1"),
 dict(id="N1", row="20N-a", said="Fri 20 Nov 07:45", want="UP", tgt=DEF8, name="Defence F&O (8)", day="2026-11-20", at="open", alt="prevclose",
      sec_excl=DEF8, note="HAL, BEL, BDL, MAZDOCK, COCHINSHIP, SOLARINDS, DATAPATTNS, BHARATFORG (ASTRAMICRO is not F&O). Sector = capital goods without the 8."),
 dict(id="N2", row="20N-b", said="Fri 20 Nov 07:45", want="UP", tgt=EMS5, name="DIXON + EMS group (F&O)", day="2026-11-20", at="open", alt="prevclose", per_member_sector=True,
      note="DIXON, KAYNES, PGEL, AMBER, SYRMA."),
 dict(id="N3", row="20N-c", said="Fri 20 Nov 07:45 (photo)", want="UP", tgt="AZAD", day="2026-11-20", at="open", alt="prevclose",
      sector="capital-goods",
      note="AZAD (Azad Engineering, not F&O). NSE bulk deals of Wed 18 Nov: buyers Norges Bank (FII) 473,088 + ValueQuest funds 1,147,000 = "
           "1,620,088 shares at 2,286 (the headline's 2.51% fits an equity of ~6.45 crore shares; share count not checked here); the promoter sold 3,500,000. Thu 19 Nov close 2,410.2, +3.94% (the 'jumps 4%'). "
           "Thursday's own NSE bulk / block files (19 Nov) hold no aerospace / defence share."),
]

def score(r):
    syms = r["tgt"] if isinstance(r["tgt"], list) else [r["tgt"]]
    day, at = r["day"], r["at"]
    out = {k: r.get(k) for k in ("id", "row", "said", "want", "note")}
    out["name"] = r.get("name") or r["tgt"]
    out["ce_pe"] = {"UP": "CE", "DOWN": "PE"}.get(r["want"])
    out["entry_day"], out["entry_at"], out["next_day"] = day, at, nextday(day)
    nif = move("NIFTY_50", day, at)
    out["nifty"] = {"entry": nif[0], "to_close": nif[1], "to_next_close": nif[2]}
    rows, d0, d1 = basket(syms, day, at)
    out["members"] = {s: {"entry": v[0], "to_close": v[1], "to_next_close": v[2]} for s, v in rows.items()}
    out["move_to_close"], out["n"] = d0
    out["move_to_next_close"], _ = d1
    if r.get("alt"):
        _, a0, a1 = basket(syms, day, r["alt"])
        out["alt_basis"] = r["alt"]; out["alt_to_close"] = a0[0]; out["alt_to_next_close"] = a1[0]
        an = move("NIFTY_50", day, r["alt"]); out["alt_nifty"] = {"to_close": an[1], "to_next_close": an[2]}
    # sector median
    if len(syms) == 1:
        sec = r.get("sector") or sector_of(syms[0])
        excl = ()
    else:
        sec = r.get("sector") or ("capital-goods" if r.get("sec_excl") else None)
        excl = r.get("sec_excl") or (tuple(syms) if r.get("sector") else ())
    if sec:
        _, s0, s1 = basket(members(sec, excl), day, at)
        out["sector"] = sec + (" (without the basket)" if excl else "")
        out["sector_to_close"], out["sector_n"] = s0
        out["sector_to_next_close"] = s1[0]
    else:
        out["sector"] = None; out["sector_to_close"] = out["sector_to_next_close"] = None
        if len(syms) > 1 and r.get("per_member_sector"):
            diffs0, diffs1, secs_ = [], [], {}
            for x in syms:
                sx = sector_of(x); secs_[x] = sx
                _, a0, a1 = basket(members(sx, tuple(syms)), day, at)
                v = rows[x]
                if v[1] is not None and a0[0] is not None: diffs0.append(v[1] - a0[0])
                if v[2] is not None and a1[0] is not None: diffs1.append(v[2] - a1[0])
                out["members"][x]["sector"] = sx; out["members"][x]["sector_to_close"] = a0[0]; out["members"][x]["sector_to_next_close"] = a1[0]
            out["sector"] = "each member vs its own sector median (without the group)"
            out["vs_sector_close_direct"] = med(diffs0)[0]; out["vs_sector_next_direct"] = med(diffs1)[0]
        elif len(syms) > 1:
            out["sector"] = "(the basket is the sector)"
    rel = lambda a, b: None if a is None or b is None else round(a - b, 2)
    out["vs_nifty_close"] = rel(out["move_to_close"], nif[1]); out["vs_nifty_next"] = rel(out["move_to_next_close"], nif[2])
    out["vs_sector_close"] = rel(out["move_to_close"], out["sector_to_close"]); out["vs_sector_next"] = rel(out["move_to_next_close"], out["sector_to_next_close"])
    if "vs_sector_close_direct" in out:
        out["vs_sector_close"] = out.pop("vs_sector_close_direct"); out["vs_sector_next"] = out.pop("vs_sector_next_direct")
    if len(syms) > 1 and r["want"]:
        good = [side_ok(v[1], r["want"]) for v in rows.values() if v[1] is not None]
        out["breadth_right_close"] = "%d/%d" % (sum(good), len(good))
        good = [side_ok(v[2], r["want"]) for v in rows.values() if v[2] is not None]
        out["breadth_right_next"] = "%d/%d" % (sum(good), len(good)) if good else None
    # levels / triggers (single share)
    s = syms[0]
    if r.get("level") or r.get("trigger"):
        hi, lo = hilo_after(s, day, at if ":" in at else "09:15")
        later = [d for d in DAYS if d > day]
        his = [daybar(s, d) for d in later]
        his = [b for b in his if b]
        mx = max([hi or 0] + [b["h"] for b in his]); mn = min([lo or 1e12] + [b["l"] for b in his])
        out["range_after_to_20nov"] = {"high": mx, "low": mn, "to": later[-1] if later else day}
        if r.get("trigger"):
            fired = None
            if hi is not None and hi > r["trigger"]:
                fired = day
            else:
                for d in later:
                    b = daybar(s, d)
                    if b and b["h"] > r["trigger"]:
                        fired = d; break
            out["trigger_fired"] = fired
        if r.get("level"):
            lv = r["level"][1]; op = r["level"][0]; hit = None
            for d in [day] + later:
                if d == day:
                    h_, l_ = hi, lo
                else:
                    b = daybar(s, d); h_, l_ = (b["h"], b["l"]) if b else (None, None)
                if h_ is None:
                    continue
                if (op in ("<=", "<") and l_ <= lv) or (op == ">=" and h_ >= lv and len(r["level"]) == 2):
                    hit = d; break
            out["level"] = {"rule": "%s %s" % (op, lv), "first_day_reached": hit}
            if len(r["level"]) == 3:
                out["level"]["kind"] = r["level"][2]
                if r["level"][2] == "floor":
                    out["level"]["broke_floor_on"] = next((d for d in [day] + later if (lo if d == day else (daybar(s, d) or {}).get("l", 1e12)) < lv), None)
                if r["level"][2] == "cap":
                    out["level"]["close_below_cap_on_entry_day"] = (close(s, day) or 1e12) < lv
    if r.get("trigger") and out.get("trigger_fired"):
        fd = out["trigger_fired"]; z = minute(s, fd); tt = None
        if z is not None:
            m = (z["h"] > r["trigger"]) & (z["t"] >= base(fd) + (secs(at) if fd == day else 0))
            if m.any():
                tt = int(z["t"][m][0] - base(fd)); tt = "%02d:%02d" % (tt // 3600, tt % 3600 // 60)
        e = r["trigger"]
        out["entry_day"], out["entry_at"], out["next_day"] = fd, "trigger %s at %s" % (e, tt), nextday(fd)
        out["members"] = {s: {"entry": e, "to_close": pct(close(s, fd), e), "to_next_close": pct(close(s, nextday(fd)), e)}}
        out["move_to_close"] = out["members"][s]["to_close"]; out["move_to_next_close"] = out["members"][s]["to_next_close"]
        n0 = entry("NIFTY_50", fd, tt) if tt else None
        out["nifty"] = {"entry": n0, "to_close": pct(close("NIFTY_50", fd), n0), "to_next_close": pct(close("NIFTY_50", nextday(fd)), n0)}
        sm = [move(x, fd, tt) for x in members(sector_of(s))] if tt else []
        out["sector_to_close"] = med([m_[1] for m_ in sm])[0]; out["sector_to_next_close"] = med([m_[2] for m_ in sm])[0]
        out["vs_nifty_close"] = rel(out["move_to_close"], out["nifty"]["to_close"]); out["vs_nifty_next"] = rel(out["move_to_next_close"], out["nifty"]["to_next_close"])
        out["vs_sector_close"] = rel(out["move_to_close"], out["sector_to_close"]); out["vs_sector_next"] = rel(out["move_to_next_close"], out["sector_to_next_close"])
    out["counted"] = bool(r["want"]) and not r.get("cond") and not (r.get("trigger") and not out.get("trigger_fired"))
    if r.get("trigger") and out.get("trigger_fired"):
        out["note"] += " 200 traded on %s (%s); scored from 200." % (out["trigger_fired"], out["entry_at"])
    if r.get("cond") == "capital-goods":
        cg = []
        for d in [x for x in DAYS if "2026-11-17" <= x <= "2026-11-20"]:
            m = med([pct(close(x, d), close(x, prevday(d))) for x in members("capital-goods")])
            a = pct(close("ABB", d), close("ABB", prevday(d)))
            cg.append({"day": d, "capital_goods_median_day": m[0], "ABB_day": a})
        out["condition_check"] = cg
    prim = r.get("primary", "d0")
    out["primary"] = "to_next_close" if prim == "d1" else "to_close"
    out["right_close"] = side_ok(out["move_to_close"], r["want"]) if r["want"] else None
    out["right_next"] = side_ok(out["move_to_next_close"], r["want"]) if r["want"] else None
    out["right_vs_nifty_close"] = side_ok(out["vs_nifty_close"], r["want"]) if r["want"] else None
    out["right_vs_nifty_next"] = side_ok(out["vs_nifty_next"], r["want"]) if r["want"] else None
    out["right_primary"] = out["right_next"] if prim == "d1" else out["right_close"]
    out["right_vs_nifty_primary"] = out["right_vs_nifty_next"] if prim == "d1" else out["right_vs_nifty_close"]
    return out

if __name__ == "__main__":
    res = [score(r) for r in READS]
    json.dump({"reads": res, "sources": {k: sorted(v) for k, v in SRC.items()}}, open(os.path.join(SP, "scored_raw.json"), "w"), indent=1, default=str)
    for o in res:
        print(o["id"], o["ce_pe"], o["name"] if isinstance(o["name"], str) else "", o["entry_day"], o["entry_at"], "n=%s" % o["n"],
              "D0", o["move_to_close"], "D1", o["move_to_next_close"], "NIF", o["nifty"]["to_close"], o["nifty"]["to_next_close"],
              "SEC", o["sector_to_close"], o["sector_to_next_close"], "R", o["right_primary"], o.get("trigger_fired", ""), o.get("range_after_to_20nov", ""))
    print({k: sorted(v) for k, v in SRC.items()})

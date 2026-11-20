# FIXTURE v2/data/desk/state.json (DESK_api.md v1 shape) for the TEST copy of gir-preview on 127.0.0.1:8102 only - never the live file.
# Every text says FIXTURE; numbers are invented for layout tests. Re-run (or --loop) keeps the heartbeat fresh so the facts stay LIVE.
import json, os, sys, time
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'state.json')


def hm(dm=0):
    return time.strftime('%H:%M', time.gmtime(time.time() + 19800 + dm * 60))


def doc():
    now = time.time()
    ideas = [
        {"id": "T:fx000001", "s": "SBIN", "side": "CE", "state": "BUY NOW", "first_hm": hm(-140), "why": "FIXTURE: FII net buyers in banks five sessions running",
         "against": "FIXTURE: RSI near 75 - late entries get shaken out", "chain": "FIXTURE: AI IPO -> FII rotation -> banks", "enter_if": "FIXTURE: a pullback to VWAP that holds",
         "cancel_if": "FIXTURE: bank index loses VWAP for 2 closed 5-min bars", "conviction": "MEDIUM", "source": "flows", "sources": ["NSDL", "tape"], "rank": 1,
         "contract": "SBIN Dec 1000 CE (ATM, exp 2026-12-29)", "entry": 991.2, "trigger_text": "a pullback to VWAP that holds", "stop": 984.6, "t1": 1004.8,
         "size": "2 lots (1% risk)", "gate_wait": None, "horizon": "TODAY",
         "history": [{"hm": hm(-140), "event": "NEW", "why": "19:45 brief"}, {"hm": hm(-60), "event": "STANDS", "why": "09:08"}, {"hm": hm(-3), "event": "BUY NOW", "why": "trigger hit"}], "proof": "NOT PROVEN"},
        {"id": "T:fx000002", "s": "ICICIBANK", "side": "CE", "state": "ARMED", "first_hm": hm(-140), "why": "FIXTURE: same foreign-flow theme, second bank", "against": "FIXTURE: two up days",
         "chain": "FIXTURE: AI IPO -> FII rotation -> banks", "enter_if": "FIXTURE: a 1-minute close above yesterday's high", "cancel_if": "FIXTURE: bank index red", "conviction": "LOW",
         "source": "theme", "sources": ["board"], "rank": 2, "contract": "ICICIBANK Dec 1440 CE (ATM, exp 2026-12-29)", "entry": 1438.0, "trigger_text": "a 1-minute close above yesterday's high",
         "stop": 1426.0, "t1": 1462.0, "size": "1 lot", "gate_wait": "WAIT: trigger not hit", "horizon": "TODAY", "history": [{"hm": hm(-140), "event": "NEW", "why": "19:45 brief"}], "proof": "NOT PROVEN"},
        {"id": "T:fx000003", "s": "INFY", "side": "PE", "state": "STANDS", "first_hm": hm(-140), "why": "FIXTURE: US tech slide overnight, ADR down", "against": "FIXTURE: a weaker rupee helps exporters",
         "chain": "FIXTURE: US tech -> IT", "enter_if": "FIXTURE: back below VWAP with volume", "cancel_if": "FIXTURE: Nasdaq futures turn green", "conviction": "LOW", "source": "world",
         "sources": ["Reuters"], "rank": 3, "contract": "INFY Dec 1560 PE (ATM, exp 2026-12-29)", "entry": 1561.0, "trigger_text": "back below VWAP with volume", "stop": 1574.0, "t1": 1535.0,
         "size": "1 lot", "gate_wait": "WAIT: trigger not hit", "horizon": "TODAY", "history": [{"hm": hm(-140), "event": "NEW", "why": "19:45 brief"}], "proof": "NOT PROVEN"},
        {"id": "T:fx000004", "s": "TCS", "side": "PE", "state": "CANCELLED", "first_hm": hm(-140), "why": "FIXTURE: same US tech theme", "against": "FIXTURE: defensive buying", "chain": "FIXTURE: US tech -> IT",
         "enter_if": "FIXTURE: back below VWAP", "cancel_if": "FIXTURE: IT holds VWAP 30 min", "conviction": "LOW", "source": "world", "sources": ["Reuters"], "rank": 9,
         "contract": "TCS Dec 3300 PE (ATM, exp 2026-12-29)", "entry": None, "trigger_text": None, "stop": None, "t1": None, "size": None, "gate_wait": None, "horizon": "TODAY",
         "history": [{"hm": hm(-140), "event": "NEW", "why": "19:45 brief"}, {"hm": hm(-20), "event": "CANCELLED", "why": "FIXTURE: IT held VWAP for 30 min"}], "proof": "NOT PROVEN"}]
    buy = [{"id": "T:fx000001", "s": "SBIN", "side": "CE", "hm": hm(-3), "valid_till": hm(11),
            "plan": {"contract": "SBIN Dec 1000 CE (ATM, exp 2026-12-29)", "exp": "2026-12-29", "strike": 1000, "strike_kind": "ATM", "prem": 32.4, "lot": 750, "lots": 2, "entry": 991.2,
                     "stop": 984.6, "t1": 1004.8, "rr": 1.9, "prem_entry": 33.0, "prem_stop": 27.9, "prem_t1": 39.5, "trigger_text": "a pullback to VWAP that holds",
                     "levels_src": "FIXTURE", "size_text": "2 lots (1% risk Rs 4,120)", "gates": [{"t": "ban", "ok": True, "why": ""}, {"t": "quote age", "ok": True, "why": "4 s"}]},
            "why": "FIXTURE: banks lead on foreign buying and the trigger hit",
            "why_lines": [{"text": "FIXTURE: FII net buyers in banks five sessions running", "ids": ["E:nsdl"], "sources": ["NSDL"], "seats": ["10"]},
                          {"text": "FIXTURE: bank index holds VWAP on a flat NIFTY", "ids": ["E:tape"], "sources": ["code"], "seats": ["33"]},
                          {"text": "FIXTURE: PSU bank breadth 11 of 12 up", "ids": ["E:br"], "sources": ["code"], "seats": ["19"]}],
            "from_seats": ["10", "19", "35"], "against": "FIXTURE: banks already priced the flows", "cancel_if": "FIXTURE: bank index loses VWAP for 2 closed 5-min bars",
            "connection": "FIXTURE: AI IPO -> FII rotation -> banks", "risk_stamp": "APPROVED", "trade_n": "2 of 3", "proof": "NOT PROVEN"}]
    seats = [{"id": "H", "name": "HEAD ANALYST", "bench": "Head", "tier": "O", "bucket": "LIVE", "cadence": "briefs + live", "minimum": True, "status": "on", "why": "running", "prompt": "fx01"},
             {"id": "R1", "name": "Filings reader", "bench": "Readers", "tier": "H", "bucket": "READ", "cadence": "each item", "minimum": True, "status": "on", "why": "running", "prompt": "fx02"},
             {"id": "R3", "name": "TV reader", "bench": "Readers", "tier": "H", "bucket": "READ", "cadence": "one call a minute", "minimum": False, "status": "off", "why": "no prompt file in desk/prompts/ yet", "prompt": None},
             {"id": "10", "name": "FLOWS (India)", "bench": "Money", "tier": "S", "bucket": "SEATS", "cadence": "17:30-21:00, 07:15", "minimum": True, "status": "on", "why": "running", "prompt": "fx03"},
             {"id": "15", "name": "Filings desk", "bench": "Company", "tier": "S", "bucket": "SEATS", "cadence": "each item", "minimum": True, "status": "on", "why": "running", "prompt": "fx04"},
             {"id": "19", "name": "Banks", "bench": "Sectors", "tier": "S", "bucket": "SEATS", "cadence": "19:45, 07:15, events", "minimum": False, "status": "off", "why": "prompt present - not switched on", "prompt": "fx05"},
             {"id": "33", "name": "Live tape", "bench": "Market", "tier": "C", "bucket": "-", "cadence": "every 5 min", "minimum": False, "status": "on", "why": "code seat", "prompt": None},
             {"id": "35", "name": "CONNECTIONS / THEMES", "bench": "Reasoning", "tier": "O", "bucket": "MEET", "cadence": "19:45, 07:15, 09:05", "minimum": True, "status": "on", "why": "running", "prompt": "fx06"},
             {"id": "36", "name": "DEVIL'S ADVOCATE", "bench": "Reasoning", "tier": "S", "bucket": "SEATS", "cadence": "every meeting + BUY NOW", "minimum": True, "status": "on", "why": "running", "prompt": "fx07"}]
    cards = [{"id": "C:fx01", "seat": "10", "hm": hm(-35), "kind": "VIEW", "strength": 4, "headline": "FIXTURE: foreign buyers net long banks five sessions running"},
             {"id": "C:fx02", "seat": "35", "hm": hm(-140), "kind": "THEME", "strength": 4, "headline": "FIXTURE: AI IPO money pulls FII cash from Korea and Taiwan into India banks"},
             {"id": "C:fx03", "seat": "36", "hm": hm(-3), "kind": "OBJECTION", "strength": 3, "headline": "FIXTURE: banks already priced the flows; late entries get shaken out"},
             {"id": "C:fx04", "seat": "R1", "hm": hm(-2), "kind": "FACT", "strength": 2, "headline": "FIXTURE: a small order win, repeat of last week"}]
    themes = [{"id": "C:fx02", "hm": hm(-140), "headline": "FIXTURE: AI IPO -> FII rotation -> banks",
               "theme": {"chain": ["US AI IPO", "Korea / Taiwan FII outflow", "FII buy India banks"], "state": "CONFIRMING", "confirms_live": "bank index beats NIFTY 30 min", "kills": "FII turn net sellers", "analogue": "FIXTURE: one past episode"},
               "winners": [{"name": "SBIN", "side": "CE", "role": "LEADER"}, {"name": "HDFCBANK", "side": "CE", "role": "FOLLOWER"}], "losers": [{"name": "INFY", "side": "PE", "role": "LEADER"}]}]
    objections = [{"id": "C:fx03", "hm": hm(-3), "headline": "FIXTURE: banks already priced the flows", "target": "T:fx000001", "verdict": "FOR_STRONGER"},
                  {"id": "C:fx05", "hm": hm(-30), "headline": "FIXTURE: two up days already", "target": "T:fx000002", "verdict": "AGAINST_STRONGER"}]
    brief = {"slot": "07:15", "session": "2026-11-23", "made_hm": hm(-200), "ok": True, "why": None, "no_ai": False, "line": "FIXTURE: banks lead on foreign buying, IT under pressure from the US slide.",
             "view": "FIXTURE: banks lead on foreign buying; IT weak", "lean": "UP",
             "ideas": {"CE": [dict(i, line="BUY %s · WHY: %s · NOT PROVEN" % (i["contract"], i["why"]), plan={"stop": i["stop"], "t1": i["t1"], "size": i["size"]}) for i in ideas if i["side"] == "CE"],
                       "PE": [dict(i, line="BUY %s · WHY: %s · NOT PROVEN" % (i["contract"], i["why"]), plan={"stop": i["stop"], "t1": i["t1"], "size": i["size"]}) for i in ideas if i["side"] == "PE"]}}
    meter = {"from": "15:40 2026-11-20", "to": "15:40 2026-11-23", "session": "2026-11-23", "total": 1.84, "cap": 5.0, "step": "NORMAL", "calls": 264,
             "buckets": {"MEET": {"spent": 0.6, "cap": 1.6, "room": 1.0}, "LIVE": {"spent": 0.9, "cap": 2.0, "room": 1.1}, "READ": {"spent": 0.21, "cap": 0.6, "room": 0.39},
                         "SEATS": {"spent": 0.13, "cap": 0.5, "room": 0.37}, "ASK": {"spent": 0.0, "cap": 0.3, "room": 0.3}},
             "by_seat": {"H": 0.92, "R1": 0.21, "10": 0.18, "35": 0.30, "36": 0.08, "15": 0.04}, "by_model": {}, "counted_extra_parts": [], "extra_usd": 0}
    return {"status": "running", "updated": now, "heartbeat": now, "updated_hm": hm(), "heartbeat_hm": hm(), "mode": "live", "session": "2026-11-23", "why": None,
            "ai_enabled": True, "head_looks": {"shared_used": 4, "shared_cap": 8, "trigger_used": 1, "trigger_cap": 2, "extra_trigger_cap": 3, "last_hm": hm(-4), "heartbeat_due_hm": hm(8)},
            "prompts": {"dirs": [], "files": [], "contracts": True}, "looks_today": 5, "last_look": {"hm": hm(-4), "kind": "trigger", "ok": True, "model": "x", "usd": 0.08},
            "view": {"text": "FIXTURE: banks lead on foreign buying; IT weak on the US tech slide. Lean UP for banks, PE side for IT.", "lean": "UP", "hm": hm(-4), "fake": False, "stale": os.path.exists(OUT + ".stale"),
                     "next_look": "when woken · heartbeat by " + hm(8)},
            "buy_now": buy, "wait": [{"id": "T:fx000002", "s": "ICICIBANK", "side": "CE", "hm": hm(-6), "why": "WAIT: second read pending"}], "ideas": ideas,
            "manage": [{"pos": "POS:HDFCBANK26DEC820PE", "hm": hm(-5), "action": "HOLD", "why": "FIXTURE: thesis intact - banks breadth negative for this name"}],
            "why_not": [{"s": "ADANIENT", "code": "PRICE_ONLY", "line": "price-only move, no reason found", "by": "code"}, {"s": "TRENT", "code": "EXTREME_RSI", "line": "EXTREME RSI - no chase", "by": "head"}],
            "brief": brief, "seats": seats, "cards": cards, "themes": themes, "objections": objections, "meter": meter, "proof": "NOT PROVEN"}


def write():
    tmp = OUT + '.tmp'; json.dump(doc(), open(tmp, 'w'), ensure_ascii=False); os.replace(tmp, OUT)


if __name__ == '__main__':
    write()
    while '--loop' in sys.argv:
        time.sleep(30); write()

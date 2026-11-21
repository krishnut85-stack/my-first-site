#!/bin/bash
# PATCH 78 - THE GATE REVIEW (on top of patch 77i): every line to GIR Box Picks passes the house gates in ONE place,
#   and nothing is lost or muted in silence. Self-tests, backs up, rolls back. Nothing is deployed by itself: paste on the server.
#   · tg_gate (engine2.py): no call before 09:30 (STOCKS IN PLAY's time) · no call on a share in NSE's F&O ban list ·
#     when the day's cap is reached, ONE line says so on Box Picks instead of going quiet
#   · tg_fo: one retry on a Telegram hiccup; a line that still fails is written to the home page's NOW list marked NOT SENT
#   · BOX PICK · MOVER · NEWS SHOCK · BREAKING NOW · WALL FLIP: the word is BUY only when the rule measures 55%+ on 50+ cases,
#     else WATCH (new rules start as WATCH); the size line (risk_rs) and "rule measured:" on every line; a ticket only with a
#     premium of ₹2+ and a liquid strike; MOVER shows a ticket only when the box says BUY on that side
#   · NEWS SHOCK no longer starts at 09:20; WALL FLIP's ticket strike needs OI 20,000+ and ₹2+
#   · THE THREE 14:30 text: the size on every row, "in the F&O ban list" when it is, no link to /expert
#   · desk.py: a FAILED ban-list fetch is logged and NOT cached as "no bans" for the day · the auditor holds a CE with a roof
#     under 2% above (and a PE with a floor under 2% below) - the RECLTD lesson · YOUR RULES skip banned shares and carry the
#     ticket, the stop and the size · desk_calls write failures are logged (the measured numbers depend on them)
#   · engine.py: shares with no FIRST MOVE normal are named in the log · exchange.py: results_map failures are logged
#   · home.html: the dead "full box" link to /expert goes
#   Edits engine2.py engine.py desk.py exchange.py home.html in place (exact anchors; nothing written if one does not match).
#   Installs p78test.py (the gate test). Restarts gir-intraday, gir-desk, gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g78; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p78.sh now"; exit 1; fi
[ -f $D/my_alerts.txt ] && grep -q "THE THREE — for tomorrow" $D/home.html || { echo "patch 77i is not installed yet - paste patch 77i first"; exit 1; }
grep -q "def ban_today" $D/engine2.py && { echo "patch 78 is already installed (engine2.py has ban_today)"; exit 1; }
F="engine2.py engine.py desk.py exchange.py home.html"
for f in $F; do [ -f $D/$f ] || { echo "missing $D/$f"; exit 1; }; cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p78test.py; systemctl restart gir-intraday gir-desk gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p78_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p78_patch.py - PATCH 78: the gate review fixes, applied as exact in-place edits.
Usage: python3 p78_patch.py /home/globalbot/intraday
Two phases: (1) every anchor must occur exactly once in every file, else nothing is written; (2) write.
"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}          # file -> [(old, new), ...]


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


# ============================================================ engine2.py
# 1. the helpers: ban list for the engine, the size rule, the BUY/WATCH word from the measured number, ticket liquidity
E("engine2.py", 'def fm_measured(tier=None):\n', '''_BAN = {"day": None, "at": 0.0, "set": set()}


def ban_today():
    """NSE's F&O ban list for the day (desk.ban_list: NSE's file, else data/ban.txt) - re-read every hour.
    The gate holds every new call on a banned share (no new positions)."""
    d_ = str(core.ist_now().date())
    if _BAN["day"] != d_ or time.time() - _BAN["at"] > 3600:
        _BAN.update({"day": d_, "at": time.time()})
        try:
            import desk
            _BAN["set"] = set(desk.ban_list())
        except Exception as ex:
            log("ban list: %s" % str(ex)[:80])
    return _BAN["set"]


def size_text(lot, prem):
    """lots = rupees at risk (data/desk_config.json risk_rs) / (half the premium x lot size) - the desk's size rule, on every line"""
    try:
        risk = desk_config().get("risk_rs"); lot = int(lot or 0); prem = float(prem or 0)
    except Exception:
        return "size: not worked out"
    if not risk:
        return "size: set risk_rs in data/desk_config.json"
    if not lot or not prem:
        return "size: lot size or premium not read"
    per_lot = 0.5 * prem * lot
    n = int(risk // per_lot) if per_lot else 0
    if n == 0:
        return "size: NO TRADE at this size — one lot risks ₹%s at half the premium, more than your ₹%s" % ("{:,}".format(int(per_lot)), "{:,}".format(int(risk)))
    return "size: %d lot%s (₹%s at risk with the stop at half the premium; 1 lot = %d × ₹%g)" % (n, "" if n == 1 else "s", "{:,}".format(int(n * per_lot)), lot, prem)


def rule_word(e_):
    """the house rule: BUY only when the rule measures 55%+ on 50+ cases, else WATCH. e_ = (pct, n, avg) or None"""
    if e_ and e_[0] >= 55 and e_[1] >= 50:
        return "BUY", "rule measured: %d%% right of %d" % (e_[0], e_[1])
    if e_:
        return "WATCH", "rule measured: %d%% right of %d — not 55%% on 50+ cases yet, so WATCH, not BUY" % (e_[0], e_[1])
    return "WATCH", "rule measured: not yet (new rule) — WATCH until it has 50 cases"


def ticket_ok(ck_):
    """a ticket from the checklist is tradeable only with a premium of ₹2+ and the LIQUIDITY check not failed"""
    a_ = (ck_ or {}).get("atm") or {}
    if not a_.get("p") or a_["p"] < 2:
        return False, "premium under ₹2 — too thin to trade"
    liq_ = next((it_ for it_ in (ck_ or {}).get("items", []) if it_[0] == "LIQUIDITY"), None)
    if liq_ and liq_[1] == -1:
        return False, "very few contracts at that strike — hard to sell when you want out"
    return True, ""


def fm_measured(tier=None):
''')

# 2. tg_fo: one retry, and a line that still fails is written to the page's NOW list marked NOT SENT - nothing is lost in silence
E("engine2.py", '''    try:
        import requests
        r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok,
                          data={"chat_id": chat, "text": text[:4000], "disable_web_page_preview": "true"}, timeout=15)
        if not r.ok:
            log("box telegram error: %s %s" % (r.status_code, r.text[:120]))
        else:
            alert_log(text)                                     # the home page's NOW list, the same second
        return r.ok
    except Exception as ex:
        log("box telegram error: %s" % str(ex)[:120])
        return False''', '''    err_ = None
    for try_ in (1, 2):                                         # one retry: a Telegram hiccup must not lose the call
        try:
            import requests
            r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok,
                              data={"chat_id": chat, "text": text[:4000], "disable_web_page_preview": "true"}, timeout=15)
            if r.ok:
                alert_log(text)                                 # the home page's NOW list, the same second
                return True
            err_ = "%s %s" % (r.status_code, r.text[:120])
            if 400 <= r.status_code < 500:
                break                                           # a bad request will not get better on a retry
        except Exception as ex:
            err_ = str(ex)[:120]
        if try_ == 1:
            time.sleep(1)
    log("box telegram error: %s" % err_)
    alert_log(text.rstrip() + "\\n⚠ NOT SENT to Telegram (%s) — on the page only" % (err_ or "?")[:80])
    return False''')

# 3. tg_gate: the house gates in ONE place - not before 09:30, not a banned share; the day cap says so once instead of going quiet
E("engine2.py", '''    d_ = str(core.ist_now().date())
    if _GATE["day"] != d_:
        _GATE.update({"day": d_, "sent": {}, "n": 0})
    key = (kind, sym, side)''', '''    now__ = core.ist_now(); d_ = str(now__.date())
    if _GATE["day"] != d_:
        _GATE.update({"day": d_, "sent": {}, "n": 0, "capsaid": False})
    key = (kind, sym, side)
    if now__.strftime("%H:%M") < "09:30":
        log("gate: before 09:30 (STOCKS IN PLAY's time), held: %s %s %s" % key); return False
    if sym in ban_today():
        log("gate: %s is in the F&O ban list — no new position, held: %s %s" % (sym, kind, side)); return False''')
E("engine2.py", '''    if not exempt and _GATE["n"] >= GATE_CAP:
        log("gate: day cap reached, kept on the page: %s %s %s" % key); return False''', '''    if not exempt and _GATE["n"] >= GATE_CAP:
        log("gate: day cap reached, kept on the page: %s %s %s" % key)
        if not _GATE.get("capsaid"):
            _GATE["capsaid"] = True
            tg_fo("⚠ the day's %d actionable alerts are spent — from now the picks, movers and breaking lines stay on the home page (NOW list). Say the word and the cap goes." % GATE_CAP)
        return False''')

# 4. NEWS SHOCK: not inside the first 15 minutes
E("engine2.py", 'if not ("09:20" <= hm_ <= "15:15") or not live:', 'if not ("09:30" <= hm_ <= "15:15") or not live:')

# 5. MOVER: a ticket only when the box says BUY on that side and the strike is liquid; the word from the measured number; the size
E("engine2.py", '''                            txt_ = "📈 MOVER %s %s ₹%s %+.1f%% · %s\\n%s\\n▶ %s ~₹%s%s · stop: half the premium%s · %s" % (
                                "▲" if side_ == "CE" else "▼", s_, f_.get("px") or "?", chg_, hm_, why_, a_.get("label", side_), a_.get("p", "?"),
                                (" · 1 lot ₹{:,}".format(a_["cost"]) if a_.get("cost") else ""),
                                (" · next wall ₹%g (%.1f L)" % (wall_["k"], (wall_.get("oi") or 0) / 1e5)) if wall_ and wall_.get("k") else "",
                                "the box says %s" % ((P_.get("advice") or {}).get("act") or "WAIT"))''', '''                            act_ = (P_.get("advice") or {}).get("act") or "WAIT"
                            ok_t, why_t = ticket_ok((chk_.get(s_) or {}).get(side_))
                            word_, meas_ = rule_word(None)                 # MOVER is not measured yet: WATCH by the house rule
                            if act_ == ("BUY CE" if side_ == "CE" else "BUY PE") and ok_t:
                                tk_ = "▶ %s: %s ~₹%s%s · stop: half the premium%s · %s" % (word_, a_.get("label", side_), a_.get("p", "?"),
                                      (" · 1 lot ₹{:,}".format(a_["cost"]) if a_.get("cost") else ""),
                                      (" · next wall ₹%g (%.1f L)" % (wall_["k"], (wall_.get("oi") or 0) / 1e5)) if wall_ and wall_.get("k") else "", size_text(fo.get(s_), a_.get("p")))
                            else:
                                tk_ = "WATCH — not a trade yet: the box says %s%s" % (act_, (" (%s)" % why_t) if why_t else ((" — " + ((P_.get("advice") or {}).get("why") or ""))[:160] if act_ != "WAIT" or (P_.get("advice") or {}).get("why") else ""))
                            txt_ = "📈 MOVER %s %s ₹%s %+.1f%% · %s\\n%s\\n%s\\n%s" % (
                                "▲" if side_ == "CE" else "▼", s_, f_.get("px") or "?", chg_, hm_, why_, tk_, meas_)''')

# 6. NEWS SHOCK: the word, the size, the thin-strike warning, the measured line
E("engine2.py", '''                        txt_ = "⚡ NEWS SHOCK %s %s %+.1f%% today%s\\n%s\\n▶ BUY %s ~₹%s%s · stop: half the premium%s\\nthis is a chain: GIR alerts every 2%% further while the money keeps agreeing, and 🛑 when it turns" % (
                            "▼" if side_ == "PE" else "▲", s_, chg_, " — most of it at the open, this is for the continuation: half size" if abs(chg_) >= 8 else "",
                            L_["news"][1] if L_["news"][0] else "no audited news yet — the money is the only reason, size small",
                            a_.get("label", side_), a_.get("p", "?"), (" · 1 lot ₹{:,}".format(a_["cost"]) if a_.get("cost") else ""),
                            (" · trail: share %s ₹%s" % ("above" if side_ == "PE" else "below", trail_)) if trail_ else "")''', '''                        word_, meas_ = rule_word(None)                     # NEWS SHOCK is not measured yet: WATCH by the house rule
                        ok_t, why_t = ticket_ok((chk_.get(s_) or {}).get(side_))
                        txt_ = "⚡ NEWS SHOCK %s %s %+.1f%% today%s\\n%s\\n▶ %s: %s ~₹%s%s · stop: half the premium%s · %s%s\\n%s\\nthis is a chain: GIR alerts every 2%% further while the money keeps agreeing, and 🛑 when it turns" % (
                            "▼" if side_ == "PE" else "▲", s_, chg_, " — most of it at the open, this is for the continuation: half size" if abs(chg_) >= 8 else "",
                            L_["news"][1] if L_["news"][0] else "no audited news yet — the money is the only reason, size small",
                            word_, a_.get("label", side_), a_.get("p", "?"), (" · 1 lot ₹{:,}".format(a_["cost"]) if a_.get("cost") else ""),
                            (" · trail: share %s ₹%s" % ("above" if side_ == "PE" else "below", trail_)) if trail_ else "", size_text(fo.get(s_), a_.get("p")),
                            ("" if ok_t else " · ⚠ " + why_t), meas_)''')

# 7. BOX PICK: premium ₹2+, the word from the box rule's measured number, the size, the measured line
E("engine2.py", '''                    PK["sent"].add(key_); PK["n"] += 1
                    L_ = lights_for(r_["s"], fp_, cur) if fp_ is not None else None''', '''                    if not r_.get("p") or float(r_["p"]) < 2:
                        log("BOX PICK %s %s held: premium ₹%s under ₹2" % (r_["s"], r_["act"], r_.get("p"))); continue
                    PK["sent"].add(key_); PK["n"] += 1
                    L_ = lights_for(r_["s"], fp_, cur) if fp_ is not None else None
                    word_, meas_ = rule_word((edge_today() or {}).get("box"))''')
E("engine2.py", '''                    tg_gate("pick", r_["s"], r_["kind"], "🎯 BOX PICK %s %s — %s\\nBUY %g %s at about ₹%s (%s expiry)%s\\ntarget: share ₹%s (option ≈ +%s%%) · stop: share %s ₹%s\\nroom to the %s %s%%%s\\n%s\\n(tap the share in GIR for the full box)" % (
                        "▲" if ce_ else "▼", r_["s"], r_.get("title") or "", r_["k"], r_["kind"], r_["p"], r_.get("exp") or "",
                        (" · 1 lot ₹{:,}".format(r_["cost"]) if r_.get("cost") else ""), r_.get("tgt"), r_.get("gain"), "below" if ce_ else "above", r_.get("stop"),
                        "roof" if ce_ else "floor", r_.get("room"), " · LATE ENTRY: it already moved a lot today" if r_.get("late") else "", vd_), L_)''', '''                    tg_gate("pick", r_["s"], r_["kind"], "🎯 BOX PICK %s %s — %s\\n%s %g %s at about ₹%s (%s expiry)%s\\ntarget: share ₹%s (option ≈ +%s%%) · stop: share %s ₹%s\\nroom to the %s %s%%%s\\n%s\\n%s · %s\\n(type the share on the home page for the full box)" % (
                        "▲" if ce_ else "▼", r_["s"], r_.get("title") or "", word_, r_["k"], r_["kind"], r_["p"], r_.get("exp") or "",
                        (" · 1 lot ₹{:,}".format(r_["cost"]) if r_.get("cost") else ""), r_.get("tgt"), r_.get("gain"), "below" if ce_ else "above", r_.get("stop"),
                        "roof" if ce_ else "floor", r_.get("room"), " · LATE ENTRY: it already moved a lot today" if r_.get("late") else "", vd_,
                        size_text(fo.get(r_["s"]), r_.get("p")), meas_), L_)''')

# 8. BREAKING NOW: the word, the size, the thin-strike warning, the measured line
E("engine2.py", '''                    txt_ = ("⚡ BREAKING NOW · %s %s %+.1f%% in 15 min (day %+.1f%%)\\n%s %s in 15 min%s\\nCHECKLIST %s %d/7 %s\\n▶ BUY %s (ATM) ~₹%s%s · stop: half the premium%s\\nsignal under test — scored from today" % (
                        s_, "▲" if d_ > 0 else "▼", m15_, f_.get("chg") or 0, read_, ("+₹%.2f cr" % same_), (" · futures: " + f_["bu"].lower()) if f_.get("bu") else "",
                        side_, ck_.get("score", 0), marks_, a_.get("label", side_), a_.get("p", "?"), (" · 1 lot ₹{:,}".format(a_["cost"]) if a_.get("cost") else ""),
                        (" or share %s %g" % ("below" if d_ > 0 else "above", stop_)) if stop_ else ""))''', '''                    word_, meas_ = rule_word(None)                         # BREAKING NOW is not measured yet: WATCH by the house rule
                    ok_t, why_t = ticket_ok(ck_)
                    txt_ = ("⚡ BREAKING NOW · %s %s %+.1f%% in 15 min (day %+.1f%%)\\n%s %s in 15 min%s\\nCHECKLIST %s %d/7 %s\\n▶ %s: %s (ATM) ~₹%s%s · stop: half the premium%s · %s%s\\n%s" % (
                        s_, "▲" if d_ > 0 else "▼", m15_, f_.get("chg") or 0, read_, ("+₹%.2f cr" % same_), (" · futures: " + f_["bu"].lower()) if f_.get("bu") else "",
                        side_, ck_.get("score", 0), marks_, word_, a_.get("label", side_), a_.get("p", "?"), (" · 1 lot ₹{:,}".format(a_["cost"]) if a_.get("cost") else ""),
                        (" or share %s %g" % ("below" if d_ > 0 else "above", stop_)) if stop_ else "", size_text(fo.get(s_), a_.get("p")),
                        ("" if ok_t else " · ⚠ " + why_t), meas_))''')

# 9. THE THREE text: no link to a page outside the home screen; the ban list and the size on every row
E("engine2.py", '''                    L_.append("others on /expert: " + " · ".join(T_["others"]))''',
  '''                    L_.append("others (type the share on the home page): " + " · ".join(T_["others"]))''')
E("engine2.py", '''                    L_.append("   ₹%s · 1 lot ₹%s · stop ₹%s (option) / ₹%s (share) · target ₹%s" % (r_["p"], "{:,}".format(int(r_["cost"])) if r_.get("cost") else "—", r_["stop_p"], r_.get("stop_share") or "—", r_.get("tgt") or "—"))''',
  '''                    L_.append("   ₹%s · 1 lot ₹%s · stop ₹%s (option) / ₹%s (share) · target ₹%s" % (r_["p"], "{:,}".format(int(r_["cost"])) if r_.get("cost") else "—", r_["stop_p"], r_.get("stop_share") or "—", r_.get("tgt") or "—"))
                    L_.append("   " + size_text(fo.get(r_["s"]), r_.get("p")))
                    if r_["s"] in ban_today():
                        L_.append("   ⛔ in the F&O ban list — no new position")''')

# 10. WALL FLIP: the ticket strike must be liquid (OI 20,000+, premium ₹2+); the word from the flip rule's number; the size
E("engine2.py", '''tk_ = sorted([(kk_, p2_) for (kk_, kd2_), (oi2_, p2_) in ch_.items() if kd2_ == side_ and p2_ and ((kk_ >= sp_) if dir_ == "UP" else (kk_ <= sp_))],''',
  '''tk_ = sorted([(kk_, p2_) for (kk_, kd2_), (oi2_, p2_) in ch_.items() if kd2_ == side_ and p2_ and p2_ >= 2 and oi2_ >= 20000 and ((kk_ >= sp_) if dir_ == "UP" else (kk_ <= sp_))],''')
E("engine2.py", '''                        l3_ = "▶ %s %s · new %s %g · stop: a close %s %g · target %s · premium %s%s" % (
                            ("%g %s ₹%g" % (k_t_, side_, p_t_)) if k_t_ else side_, "— share price going UP" if dir_ == "UP" else "— share price going DOWN",
                            "floor" if dir_ == "UP" else "roof", k_, "under" if dir_ == "UP" else "over", k_, ("₹%g" % aim_[1]) if aim_ else "open",
                            prem_, (" (IV percentile %d)" % ivp_) if ivp_ is not None else "")
                        e_ = (edge_today() or {}).get("flip")
                        l4_ = "rule measured: %s — the flip is the setup, not a certainty" % (("%d%% right of %d" % e_[:2]) if e_ else "not yet (new rule)")''',
  '''                        e_ = (edge_today() or {}).get("flip")
                        word_, meas_ = rule_word(e_)
                        l3_ = "▶ %s: %s %s · new %s %g · stop: a close %s %g · target %s · premium %s%s · %s" % (
                            word_, ("%g %s ₹%g" % (k_t_, side_, p_t_)) if k_t_ else (side_ + " (no liquid strike yet: OI 20,000+ and ₹2+)"), "— share price going UP" if dir_ == "UP" else "— share price going DOWN",
                            "floor" if dir_ == "UP" else "roof", k_, "under" if dir_ == "UP" else "over", k_, ("₹%g" % aim_[1]) if aim_ else "open",
                            prem_, (" (IV percentile %d)" % ivp_) if ivp_ is not None else "", size_text(fo.get(s_), p_t_))
                        l4_ = "%s — the flip is the setup, not a certainty" % meas_''')

# ============================================================ engine.py
# 11. FIRST MOVE norms: a share whose normal volume cannot be built is named in the log (FIRST MOVE is silent on it), not dropped quietly
E("engine.py", '''    out = np.full((len(syms), 75), np.nan)
    for i, s in enumerate(syms):
        try:
            a = core.load_npz(s)''', '''    out = np.full((len(syms), 75), np.nan)
    bad_ = []
    for i, s in enumerate(syms):
        try:
            a = core.load_npz(s)''')
E("engine.py", '''                out[i] = np.where(cnt > 0, acc / cnt / 5.0, np.nan)
        except Exception:
            continue
    return out''', '''                out[i] = np.where(cnt > 0, acc / cnt / 5.0, np.nan)
        except Exception as ex:
            bad_.append("%s (%s)" % (s, str(ex)[:40]))
            continue
    if bad_:
        log("first-move norms: %d shares have no normal volume - FIRST MOVE stays silent on them: %s" % (len(bad_), ", ".join(bad_[:15])))
    return out''')

# ============================================================ desk.py
# 12. the ban list: a failed NSE fetch is logged and NOT cached as "no bans" for the day; retried on the next call
E("desk.py", '''def ban_list():
    """NSE's F&O ban list for the day (no new positions) - fetched once a day, else data/ban.txt by hand"""
    d = str(core.ist_now().date())
    p = os.path.join(DATA, "ban_%s.txt" % d)
    if os.path.exists(p):
        return set(open(p).read().split())
    out = set()
    try:
        import requests
        r = requests.get("https://nsearchives.nseindia.com/content/fo/fo_secban.csv", timeout=15,
                         headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36", "Referer": "https://www.nseindia.com/"})
        if r.ok:
            for line in r.text.splitlines()[1:]:
                parts = [x.strip() for x in line.split(",") if x.strip()]
                if parts:
                    out.add(parts[-1].upper())
    except Exception:
        pass
    try:
        out |= set(open(os.path.join(DATA, "ban.txt")).read().split())
    except Exception:
        pass
    try:
        os.makedirs(DATA, exist_ok=True); open(p, "w").write(" ".join(sorted(out)))
    except Exception:
        pass
    return out''', '''def ban_list():
    """NSE's F&O ban list for the day (no new positions): NSE's file, cached for the day ONLY when the fetch worked,
    plus data/ban.txt by hand. A failed fetch is logged and tried again on the next call - never cached as 'no bans'."""
    d = str(core.ist_now().date())
    p = os.path.join(DATA, "ban_%s.txt" % d)
    if os.path.exists(p):
        return set(open(p).read().split())
    out, fetched = set(), False
    try:
        import requests
        r = requests.get("https://nsearchives.nseindia.com/content/fo/fo_secban.csv", timeout=15,
                         headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36", "Referer": "https://www.nseindia.com/"})
        if r.ok:
            fetched = True
            for line in r.text.splitlines()[1:]:
                parts = [x.strip() for x in line.split(",") if x.strip()]
                if parts:
                    out.add(parts[-1].upper())
        else:
            log("ban list: NSE answered %s - will try again (data/ban.txt still counts)" % r.status_code)
    except Exception as ex:
        log("ban list: NSE fetch failed (%s) - will try again (data/ban.txt still counts)" % str(ex)[:60])
    try:
        out |= set(open(os.path.join(DATA, "ban.txt")).read().split())
    except Exception:
        pass
    if fetched:
        try:
            os.makedirs(DATA, exist_ok=True); open(p, "w").write(" ".join(sorted(out)))
        except Exception as ex:
            log("ban list: cannot cache %s: %s" % (p, str(ex)[:60]))
    return out''')

# 13. the auditor: no CE right under a roof, no PE right over a floor (the RECLTD lesson) - the box's own 2% room rule
E("desk.py", '''        if sym in self.ban:
            notes.append("in the F&O ban list — no new positions"); v = 0
        side = "CE" if v > 0 else "PE" if v < 0 else None''', '''        if sym in self.ban:
            notes.append("in the F&O ban list — no new positions"); v = 0
        wr_, wf_ = a["walls"].get("roof"), a["walls"].get("floor")
        if v > 0 and wr_ and wr_.get("k") and spot < wr_["k"] and wr_.get("away", 9) < 2.0:
            notes.append("the roof ₹%g is only %.1f%% above — no CE under a roof, WAIT for it to break" % (wr_["k"], wr_["away"])); v = 0
        elif v < 0 and wf_ and wf_.get("k") and spot > wf_["k"] and wf_.get("away", 9) < 2.0:
            notes.append("the floor ₹%g is only %.1f%% below — no PE over a floor, WAIT for it to break" % (wf_["k"], wf_["away"])); v = 0
        side = "CE" if v > 0 else "PE" if v < 0 else None''')

# 14. YOUR RULES: never on a banned share; the ticket, the stop and the size on the line (the desk already has them)
E("desk.py", '''        for sym in list(rd.ch):
            spot = rd.spot.get(sym)
            if not spot:
                continue
            hits = eval_rules(''', '''        for sym in list(rd.ch):
            spot = rd.spot.get(sym)
            if not spot or sym in self.ban:
                continue
            hits = eval_rules(''')
E("desk.py", '''                txt = "📜 YOUR RULE \\"%s\\" · %s ₹%g%s · %s\\n%s\\nshare price going %s → %s side · %s\\nrule: %s · measured: %s" % (''',
  '''                tk_ = ("▶ %s · stop: a close %s %s%s" % (d["ticket"], "under" if r["side"] == "CE" else "over", d.get("stop") or "—", ("\\n" + d["size"]) if d.get("size") else "")) if (d.get("ticket") and d.get("side") == r["side"]) else "no liquid ticket on this side yet (OI 20,000+ and ₹2+) — WATCH"
                txt = "📜 YOUR RULE \\"%s\\" · %s ₹%g%s · %s\\n%s\\nshare price going %s → %s side · %s\\n%s\\nrule: %s · measured: %s" % (''')
E("desk.py", '''("desk %s %+d" % (d.get("label"), d.get("v"))) if d.get("v") else "desk: no call", r["text"], self.measured("rule:" + r["name"][:30]))
''', '''("desk %s %+d" % (d.get("label"), d.get("v"))) if d.get("v") else "desk: no call", tk_, r["text"], self.measured("rule:" + r["name"][:30]))
''')

# 15. desk_calls writes that fail are said in the log (the measured numbers depend on them)
E("desk.py", '''"rule:" + r["name"][:30], r["side"], 1 if r["side"] == "CE" else -1, spot, detail[:200])); c.commit(); c.close()
                except Exception:
                    pass''', '''"rule:" + r["name"][:30], r["side"], 1 if r["side"] == "CE" else -1, spot, detail[:200])); c.commit(); c.close()
                except Exception as ex:
                    log("desk_calls (rule): %s" % str(ex)[:80])''')
E("desk.py", '''"SUDDEN", r["side"], r["v"], r["spot"], " · ".join(r["steps"])[:200])); c.commit(); c.close()
            except Exception:
                pass''', '''"SUDDEN", r["side"], r["v"], r["spot"], " · ".join(r["steps"])[:200])); c.commit(); c.close()
            except Exception as ex:
                log("desk_calls (SUDDEN): %s" % str(ex)[:80])''')

# 16. no page outside the home screen is offered
E("desk.py", "the board has every share's counting", "every share's counting is on the home page (type the share)")

# ============================================================ exchange.py
# 17. results_map: a failure is said, not swallowed (the desk reader and THE THREE read results from it)
E("exchange.py", '''        con.close()
    except Exception:
        pass
    return out''', '''        con.close()
    except Exception as ex:
        log("results_map: %s" % str(ex)[:80])
    return out''')

# ============================================================ home.html
# 18. the dead "full box" link to /expert goes
E("home.html", '''    <a class="xl" href="${lnk("expert")}&sym=${encodeURIComponent(sym)}">full box: chain, walls, story →</a>`;''', '''    `;''')


def main():
    bad = 0
    texts = {}
    for f, edits in EDITS.items():
        p = os.path.join(D, f)
        if not os.path.exists(p):
            print("MISSING %s" % p); bad += 1; continue
        s = open(p, encoding="utf-8").read()
        for i, (old, new) in enumerate(edits, 1):
            n = s.count(old)
            if n != 1:
                print("ANCHOR %s #%d found %d times (need 1): %r" % (f, i, n, old[:90])); bad += 1
        texts[f] = s
    if bad:
        print("p78: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p78: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $D/p78test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p78test.py - the gate test for PATCH 78 (no network, no Telegram, nothing written to the live databases).
  1 tg_gate holds every call before 09:30 and every call on a banned share; lets a clean call through after 09:30
  2 the day cap says so once on Box Picks instead of going quiet
  3 tg_fo retries once on a Telegram hiccup; a line that still fails lands on the page's NOW list marked NOT SENT
  4 rule_word: BUY only at 55%+ on 50+ cases, else WATCH · size_text: the desk's size rule · ticket_ok: ₹2+ and liquid
  5 desk.ban_list: a failed NSE fetch is NOT cached as 'no bans' for the day; a good fetch is
  6 the auditor: no CE under a roof within 2%, no PE over a floor within 2%; a roof 3% away does not block
  7 home.html offers no page outside the home screen
"""
import os, sys, time, types, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import core, engine2, desk

ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


# ---- a fake clock and a fake Telegram
real_now = core.ist_now
real_sleep = time.sleep
time.sleep = lambda s: None
SENT, LOGGED = [], []
engine2.alert_log = lambda text: LOGGED.append(text)


def clock(hm):
    core.ist_now = lambda: dt.datetime(2026, 11, 10, int(hm[:2]), int(hm[3:]), 0)


class FakeResp(object):
    def __init__(self, code, text=""):
        self.status_code, self.text, self.ok = code, text, 200 <= code < 300


class FakeRequests(object):
    plan = []
    def post(self, url, data=None, timeout=None):
        SENT.append(data["text"])
        r = self.plan.pop(0) if self.plan else FakeResp(200)
        if isinstance(r, Exception):
            raise r
        return r
    def get(self, *a, **k):
        r = self.plan.pop(0) if self.plan else FakeResp(200, "")
        if isinstance(r, Exception):
            raise r
        return r


fake = FakeRequests()
sys.modules["requests"] = fake
os.environ["TELEGRAM_TOKEN"] = "test-token"
engine2._TGFO.update({"at": time.time() + 3600, "chat": "-100test"})      # tg_fo: configured, no .env read for an hour
engine2._BAN.update({"day": "2026-11-10", "at": time.time() + 3600, "set": {"RECLTD"}})

print("1. the gate: time and the ban list")
clock("09:25"); SENT[:] = []
check("09:25: a BOX PICK is held", engine2.tg_gate("pick", "GLENMARK", "CE", "🎯 BOX PICK test") is False and not SENT)
check("09:25: a FIRST MOVE is held too", engine2.tg_gate("firstmove", "GLENMARK", "CE", "⚡ FIRST MOVE test", exempt=True) is False and not SENT)
clock("09:31")
check("09:31: a banned share (RECLTD) is held", engine2.tg_gate("pick", "RECLTD", "PE", "🎯 BOX PICK test") is False and not SENT)
check("09:31: a clean call goes to Box Picks", engine2.tg_gate("pick", "GLENMARK", "CE", "🎯 BOX PICK test") is True and len(SENT) == 1)
check("   and lands on the page's NOW list", len(LOGGED) == 1 and LOGGED[0].startswith("🎯 BOX PICK"))
check("   a repeat of the same call within 2 h is skipped", engine2.tg_gate("pick", "GLENMARK", "CE", "🎯 BOX PICK test") is False and len(SENT) == 1)

print("2. the day cap says so once")
engine2._GATE["n"] = engine2.GATE_CAP; SENT[:] = []
r1 = engine2.tg_gate("mover", "TATASTEEL", "CE", "📈 MOVER test")
r2 = engine2.tg_gate("mover", "JSWSTEEL", "CE", "📈 MOVER test")
check("cap reached: the line is held and ONE notice goes out", r1 is False and r2 is False and len(SENT) == 1 and "alerts are spent" in SENT[0])
check("an exempt line (SUDDEN-type) still goes", engine2.tg_gate("flip", "HINDALCO", "CE", "🧱 WALL FLIP test", exempt=True) is True)
engine2._GATE["n"] = 0

print("3. tg_fo: retry, and NOT SENT on the page")
SENT[:] = []; LOGGED[:] = []
fake.plan = [Exception("read timed out"), FakeResp(200)]
check("one hiccup, then sent: True, two tries, one NOW line", engine2.tg_fo("🎯 BOX PICK retry") is True and len(SENT) == 2 and len(LOGGED) == 1 and "NOT SENT" not in LOGGED[0])
SENT[:] = []; LOGGED[:] = []
fake.plan = [Exception("read timed out"), Exception("read timed out")]
check("two failures: False, and the line is on the page marked NOT SENT", engine2.tg_fo("🎯 BOX PICK lost") is False and len(SENT) == 2 and len(LOGGED) == 1 and "NOT SENT" in LOGGED[0] and LOGGED[0].startswith("🎯 BOX PICK lost"))
SENT[:] = []; LOGGED[:] = []
fake.plan = [FakeResp(400, "Bad Request: chat not found")]
check("a 4xx is not retried", engine2.tg_fo("🎯 BOX PICK bad") is False and len(SENT) == 1 and "NOT SENT" in LOGGED[0])
fake.plan = []

print("4. the words and the size")
check("rule_word 60% of 80 -> BUY", engine2.rule_word((60, 80, 0.5))[0] == "BUY")
check("rule_word 60% of 30 -> WATCH (not 50 cases)", engine2.rule_word((60, 30, 0.5))[0] == "WATCH")
check("rule_word 52% of 120 -> WATCH (under 55%)", engine2.rule_word((52, 120, 0.1))[0] == "WATCH")
check("rule_word None -> WATCH (new rule)", engine2.rule_word(None)[0] == "WATCH" and "new rule" in engine2.rule_word(None)[1])
real_cfg = engine2.desk_config
engine2.desk_config = lambda: {"risk_rs": 5000}
check("size: risk 5000, premium 20, lot 500 -> 1 lot", engine2.size_text(500, 20).startswith("size: 1 lot "))
check("size: risk 5000, premium 40, lot 500 -> NO TRADE", "NO TRADE" in engine2.size_text(500, 40))
check("size: risk 5000, premium 4, lot 500 -> 5 lots", engine2.size_text(500, 4).startswith("size: 5 lots"))
engine2.desk_config = lambda: {}
check("size: no risk_rs -> says to set it", "set risk_rs" in engine2.size_text(500, 20))
engine2.desk_config = real_cfg
check("ticket_ok: ₹1.5 premium -> no", engine2.ticket_ok({"atm": {"p": 1.5}, "items": []})[0] is False)
check("ticket_ok: liquidity failed -> no", engine2.ticket_ok({"atm": {"p": 30}, "items": [["LIQUIDITY", -1, "ATM OI 12 lots"]]})[0] is False)
check("ticket_ok: ₹30 and liquid -> yes", engine2.ticket_ok({"atm": {"p": 30}, "items": [["LIQUIDITY", 1, "ATM OI 400 lots"]]})[0] is True)

print("5. desk.ban_list never caches a failed fetch")
tmp = tempfile.mkdtemp(prefix="p78ban"); desk.DATA = tmp
core.ist_now = lambda: dt.datetime(2026, 11, 10, 8, 30)
fake.plan = [Exception("connection refused")]
b = desk.ban_list()
check("fetch failed: empty set, and NO ban_2026-11-10.txt written", b == set() and not os.path.exists(os.path.join(tmp, "ban_2026-11-10.txt")))
open(os.path.join(tmp, "ban.txt"), "w").write("MANUALBAN")
fake.plan = [Exception("connection refused")]
check("fetch failed: data/ban.txt still counts", desk.ban_list() == {"MANUALBAN"} and not os.path.exists(os.path.join(tmp, "ban_2026-11-10.txt")))
fake.plan = [FakeResp(200, "Date,Symbol\n10-NOV-2026,RECLTD\n10-NOV-2026,SAIL\n")]
b = desk.ban_list()
check("fetch worked: RECLTD SAIL (+ ban.txt), cached for the day", b == {"RECLTD", "SAIL", "MANUALBAN"} and os.path.exists(os.path.join(tmp, "ban_2026-11-10.txt")))
fake.plan = [Exception("must not be called")]
check("second call reads the day's cache", desk.ban_list() == {"RECLTD", "SAIL", "MANUALBAN"})
fake.plan = []

print("6. the auditor: no CE under a roof, no PE over a floor")
d = desk.Desk(sectors_map={"test": ["ABC"]}, normal={}, big=1, fetch_ban=False, news=False)
d.day = "2026-11-10"
rd = desk.Reading(int(core.ist_epoch(dt.datetime(2026, 11, 10, 10, 0))), {"ABC": 1000.0}, {}, "test"); rd.hm = "10:00"
def A(roof=None, floor=None, sv=2):
    return {"strikes": {"v": sv, "line": "test", "prim": None}, "walls": {"v": 0, "line": "test", "roof": roof, "floor": floor, "pcr": None, "maxpain": None},
            "futures": {"v": 0, "line": ""}, "reader": {"v": 0, "line": "", "item": None}}
r = d.audit("ABC", 1000.0, A(roof={"k": 1010.0, "oi": 50000, "p": 5.0, "away": 1.0}), rd, "09:45")
check("CE vote with a roof 1% above -> held (v 0), says why", r["v"] == 0 and any("no CE under a roof" in n for n in r["notes"]))
r = d.audit("ABC", 1000.0, A(roof={"k": 1030.0, "oi": 50000, "p": 5.0, "away": 3.0}), rd, "09:45")
check("CE vote with a roof 3% above -> stands (v +2)", r["v"] == 2)
r = d.audit("ABC", 1000.0, A(roof={"k": 995.0, "oi": 50000, "p": 5.0, "away": 0.5}), rd, "09:45")
check("CE vote with the roof already crossed (995 under the price) -> stands", r["v"] == 2)
r = d.audit("ABC", 1000.0, A(floor={"k": 990.0, "oi": 50000, "p": 5.0, "away": 1.0}, sv=-2), rd, "09:45")
check("PE vote with a floor 1% below -> held (v 0)", r["v"] == 0 and any("no PE over a floor" in n for n in r["notes"]))
r = d.audit("ABC", 1000.0, A(floor={"k": 970.0, "oi": 50000, "p": 5.0, "away": 3.0}, sv=-2), rd, "09:45")
check("PE vote with a floor 3% below -> stands (v -2)", r["v"] == -2)

print("7. the home page offers no other page")
h = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "home.html"), encoding="utf-8").read()
check("no link to /expert, /sectors, /tomorrow or terminal in home.html", not any(x in h for x in ('lnk("expert")', 'lnk("sectors")', 'lnk("tomorrow")', "terminal.html")))
e2 = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "engine2.py"), encoding="utf-8").read()
check("no '/expert' offered in a Telegram line", "others on /expert" not in e2)

core.ist_now = real_now; time.sleep = real_sleep
print("\nP78 GATE TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits (every anchor must match exactly once, else nothing is written):"
python3 $W/p78_patch.py $D || { rm -f $D/p78test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile engine2.py engine.py desk.py exchange.py p78test.py || back
cd /home/globalbot && set -a && source .env && set +a && cd $D
echo "--- 2. the gate test (no network, no Telegram, no live database):"
timeout 120 python3 p78test.py 2>&1 | grep "OK  \|FAIL\|GATE TEST\|Traceback\|Error" | head -50
timeout 120 python3 p78test.py >/dev/null 2>&1 || { echo "the gate test failed"; back; }
echo "--- 3. the desk self-test (GLENMARK / UNOMINDA / quiet share, your rules):"
timeout 180 python3 desk.py --test 2>&1 | grep "FAIL\|SELF-TEST" | head -20
timeout 180 python3 desk.py --test >/dev/null 2>&1 || { echo "the desk self-test failed"; back; }
echo "--- 4. the FIRST MOVE + ORDER BOOK test:"
timeout 120 python3 fmtest.py 2>&1 | tail -1
timeout 120 python3 fmtest.py >/dev/null 2>&1 || { echo "the FIRST MOVE test failed"; back; }
echo "--- 5. the ban list as the desk reads it now (NSE's file, else data/ban.txt):"
timeout 60 python3 -c "
import desk; b = sorted(desk.ban_list()); print('    F&O ban list today: %s' % (' '.join(b) if b else 'none (or NSE did not answer - see the desk log; it is retried, never cached as empty)'))"
systemctl restart gir-intraday gir-desk gir-dash && sleep 8
K=$(cat $D/dash_token.txt)
curl -s --max-time 10 "http://127.0.0.1:8090/?k=$K" | grep -q "THE THREE — for tomorrow" || { echo "the home page is not being served"; back; }
curl -s --max-time 10 "http://127.0.0.1:8090/?k=$K" | grep -q 'lnk("expert")' && { echo "home.html still links to /expert"; back; }
curl -s --max-time 20 "http://127.0.0.1:8090/home?k=$K" | python3 -c "
import json, sys; d = json.load(sys.stdin); print('    home data: NOW %d · sectors %d · tape %d · news %d' % (len(d['now']), len(d['sectors']), len(d['tape']), len(d['news'])))" || { echo "/home did not answer"; back; }
echo "engine: $(systemctl is-active gir-intraday) · desk: $(systemctl is-active gir-desk) · page: $(systemctl is-active gir-dash)"
journalctl -u gir-intraday --since "-1min" --no-pager -o cat | grep -i "error\|traceback" | head -3
journalctl -u gir-desk --since "-1min" --no-pager -o cat | grep -i "error\|traceback" | head -3
echo "PATCH 78 APPLIED - the gates are in one place (tg_gate), BUY only with a measured 55%/50, the size on every line, nothing lost in silence."
echo "  backups: $D/*.bak$TS · roll back by hand: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-intraday gir-desk gir-dash"

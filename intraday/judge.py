#!/usr/bin/env python3
"""judge.py - JUDGE (last check before a buy) and REVIEW (end-of-day post-mortem).

Both work on rules. If a model key is present in the environment, each also asks the model
(llm.py) and shows its one-line opinion; the model can veto, it cannot force a buy.
"""
import time, collections
import numpy as np
import core, dash, llm
from engine import log, rs

V = lambda: core.cfg().get("v2", {})


class Judge(object):
    def __init__(self, feed, flw, news, fst=None):
        self.feed, self.flw, self.news, self.fst = feed, flw, news, fst
        self.whips = collections.Counter()      # shares that already failed a confirm today

    def note_failed_confirm(self, sym):
        self.whips[sym] += 1

    def strikes(self, sym, px, kind, tape):
        """List of (strike_text) - two or more means NO."""
        v = V()
        out = []
        m = self.flw.m if (self.flw is not None and self.flw.m) else None
        i = self.flw.syms.index(sym) if (m is not None and sym in self.flw.syms) else None
        chg = float(m["chg"][i]) if (i is not None and np.isfinite(m["chg"][i])) else None
        # 1. chasing an extended move (what the entry rules allow, but the judge frowns on past this)
        lim = v.get("judge_max_chg", 6.0) if kind != "RUNNER" else v.get("runner_max_chg", 12.0)
        if chg is not None and chg > lim:
            out.append("already +%.1f%% today (limit %.0f%%)" % (chg, lim))
        # 2. weak tape
        if tape == "weak":
            out.append("weak tape")
        # 3. thin liquidity: value traded in the last minute
        if self.fst is not None:
            try:
                vol1, _ = self.fst.minute()
                j = self.feed.pos.get(sym)
                if vol1 is not None and j is not None and np.isfinite(vol1[j]):
                    val = float(vol1[j]) * px
                    if val < v.get("judge_min_value_lakh", 5) * 1e5:
                        out.append("thin: ₹%.0f lakh traded last minute" % (val / 1e5))
            except Exception:
                pass
        # 4. sellers leading the book
        obi = self.feed.obi(sym) if hasattr(self.feed, "obi") else None
        if obi is not None and obi < -0.15:
            out.append("sellers %.0f%% of the book" % (50 - 50 * obi))
        # 5. fresh negative news
        if self.news is not None:
            try:
                pts, side, head, age = self.news.for_share(sym, time.time())
                if pts and side == -1:
                    out.append("negative news: %s" % (head or "")[:60])
            except Exception:
                pass
        # 6. whipsawed already
        if self.whips[sym] >= 1:
            out.append("already failed a confirm today")
        # 7. index itself falling hard right now
        try:
            nif = self.feed.nifty_chg()
            if nif is not None and nif < -0.8:
                out.append("Nifty %+.1f%%" % nif)
        except Exception:
            pass
        # 8. far from VWAP (late)
        if m is not None and i is not None:
            try:
                vw = float(m["vw"][i])
                if np.isfinite(vw) and vw > 0 and px / vw - 1 > v.get("judge_max_vwap_pct", 4.0) / 100.0:
                    out.append("%.1f%% above VWAP" % ((px / vw - 1) * 100))
            except Exception:
                pass
        return out

    def card_text(self, sym, px, kind, tape, strikes):
        m = self.flw.m if (self.flw is not None and self.flw.m) else None
        i = self.flw.syms.index(sym) if (m is not None and sym in self.flw.syms) else None
        bits = ["Share %s · entry type %s · price %s · time %s IST · tape %s" % (sym, kind, rs(px), core.ist_now().strftime("%H:%M"), tape)]
        if i is not None:
            c = self.flw.card(i, 1)
            bits.append("day %+.2f%% · blast score %d/100 · %s · vol %sx normal · sector %s" % (
                c["chg"] or 0, c["sc"], c["bu"] or ("F&O OI neutral" if c["fo"] else "cash share"), c["rv"], c["sec"] or "?"))
            bits.append("reasons: " + "; ".join(c["why"]))
            bits.append("support %s · resistance %s · R:R 1:%s" % (c["s1"], c["r1"], c["rr"]))
        if self.news is not None:
            try:
                pts, side, head, age = self.news.for_share(sym, time.time())
                if head:
                    bits.append("news (%s, %s min ago): %s" % ({1: "positive", -1: "negative"}.get(side, "neutral"), age, head[:120]))
            except Exception:
                pass
        if strikes:
            bits.append("rule strikes: " + "; ".join(strikes))
        return "\n".join(bits)

    def verdict(self, sym, px, kind, tape):
        """('GO'|'NO', reason, model_line). Rules decide; a model (if configured) can add a veto."""
        v = V()
        strikes = self.strikes(sym, px, kind, tape)
        need = int(v.get("judge_strikes", 2))
        ok = len(strikes) < need
        reason = ("; ".join(strikes) if strikes else "no strikes")
        model_line = None
        if llm.provider() and v.get("judge_ai", True):
            mv, mr = llm.judge(self.card_text(sym, px, kind, tape, strikes), tag="judge:" + sym)
            if mv:
                model_line = "%s - %s" % (mv, mr)
                if mv == "NO":
                    ok = False
                    reason = "model: " + (mr or "no")
        return ("GO" if ok else "NO"), reason, model_line


# ------------------------------------------------------------------ REVIEW
def review_text(con, day, tape_log=None):
    rows = con.execute("select sym,label,strat,entry_ts,exit_ts,entry,exit,reason,net,qty from trades where day=? and status='CLOSED' order by id",
                       (day,)).fetchall()
    if not rows:
        return None
    hm = lambda ts: time.strftime("%H:%M", time.gmtime(ts + core.IST_OFF)) if ts else "--:--"
    n = len(rows)
    wins = [r for r in rows if (r[8] or 0) > 0]
    losses = [r for r in rows if (r[8] or 0) <= 0]
    net = sum((r[8] or 0) for r in rows)
    avg_w = (sum(r[8] for r in wins) / len(wins)) if wins else 0.0
    avg_l = (sum(r[8] for r in losses) / len(losses)) if losses else 0.0
    L = ["🧾 REVIEW %s — %d trades · %d wins %d losses · net %s%s" % (day, n, len(wins), len(losses), "+" if net >= 0 else "−", rs(abs(net)))]
    L.append("Avg win %s · avg loss %s · payoff %.1f" % (rs(avg_w), rs(abs(avg_l)), (avg_w / abs(avg_l)) if avg_l else 0.0))
    # by entry type
    by = collections.defaultdict(list)
    for r in rows:
        by[r[1] or r[2] or "?"].append(r[8] or 0)
    L.append("By entry type: " + " · ".join("%s %d/%d wins %s%s" % (k, sum(1 for x in xs if x > 0), len(xs), "+" if sum(xs) >= 0 else "−", rs(abs(sum(xs))))
                                            for k, xs in sorted(by.items(), key=lambda kv: -sum(kv[1]))))
    # by hour of entry
    byh = collections.defaultdict(list)
    for r in rows:
        byh[time.strftime("%H", time.gmtime(r[3] + core.IST_OFF))].append(r[8] or 0)
    L.append("By entry hour: " + " · ".join("%s:00 %d/%d %s%s" % (h, sum(1 for x in xs if x > 0), len(xs), "+" if sum(xs) >= 0 else "−", rs(abs(sum(xs))))
                                            for h, xs in sorted(byh.items())))
    # by exit reason
    byx = collections.defaultdict(list)
    for r in rows:
        k = (r[7] or "?").split(" (")[0]
        byx[k].append(r[8] or 0)
    L.append("By exit: " + " · ".join("%s ×%d %s%s" % (k, len(xs), "+" if sum(xs) >= 0 else "−", rs(abs(sum(xs)))) for k, xs in sorted(byx.items(), key=lambda kv: -len(kv[1]))))
    # worst and best
    rows_s = sorted(rows, key=lambda r: r[8] or 0)
    L.append("Worst: " + ", ".join("%s %s (%s %s)" % (r[0], rs(r[8] or 0), hm(r[3]), (r[7] or "")[:18]) for r in rows_s[:3]))
    L.append("Best: " + ", ".join("%s +%s (%s)" % (r[0], rs(r[8] or 0), hm(r[3])) for r in reversed(rows_s[-3:]) if (r[8] or 0) > 0) or "Best: none")
    # tightenings, only when the data points at them
    T = []
    early = [r for r in rows if time.strftime("%H%M", time.gmtime(r[3] + core.IST_OFF)) < "0930"]
    if len(early) >= 3 and sum(1 for r in early if (r[8] or 0) <= 0) / len(early) >= 0.66:
        T.append("%d of %d entries before 09:30 lost → raise min score before 09:30 to 85 or start at 09:30" % (
            sum(1 for r in early if (r[8] or 0) <= 0), len(early)))
    stops = byx.get("stop hit", [])
    if len(stops) >= 3 and sum(stops) < 0 and len(stops) / n >= 0.5:
        T.append("%d of %d exits were stop hits → confirm window 25→40 s, or require buyers ≥60%% at entry" % (len(stops), n))
    for k, xs in by.items():
        if len(xs) >= 3 and sum(1 for x in xs if x > 0) == 0:
            T.append("%s: 0 of %d won today → half size for %s tomorrow" % (k, len(xs), k))
    if avg_l and avg_w and avg_w / abs(avg_l) < 0.8 and len(wins) >= 2:
        T.append("average win (%s) is smaller than average loss (%s) → trail tighter after +1R (1.5R instead of 2R)" % (rs(avg_w), rs(abs(avg_l))))
    if tape_log:
        weak_min = sum(1 for t in tape_log if t == "weak")
        if weak_min >= 60 and net < 0:
            T.append("tape was weak for %d minutes and the day lost → keep weak-tape mode; consider no new buys when under 25%% of shares up" % weak_min)
    L.append("TIGHTEN: " + (" | ".join(T) if T else "nothing the data clearly points at today"))
    keep = [k for k, xs in by.items() if sum(xs) > 0 and sum(1 for x in xs if x > 0) >= 2]
    L.append("KEEP: " + (", ".join(keep) if keep else "nothing stood out"))
    return "\n".join(L)


def review(con, day, tape_log=None):
    txt = review_text(con, day, tape_log)
    if not txt:
        return None
    if llm.provider() and V().get("review_ai", True):
        ai = llm.review(txt, tag="review")
        if ai:
            txt += "\n\n🤖 model view:\n" + ai[:1400]
    try:
        with open(core.BASE + "/reviews.txt", "a") as f:
            f.write(txt + "\n\n")
    except Exception:
        pass
    return txt

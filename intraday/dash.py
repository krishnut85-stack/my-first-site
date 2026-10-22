#!/usr/bin/env python3
"""dash.py - shared live event log ("agent feed") and state-file writer for the web terminal."""
import os, json, time, collections, threading
import core

STATE = os.path.join(core.BASE, "dash_state.json")
EVENTS = collections.deque(maxlen=250)
AGENTS = collections.OrderedDict((a, {"t": "", "m": "waiting", "n": 0}) for a in
                                 ("SCOUT", "NEWS", "CHARTS", "FLOW", "CONFIRM", "JUDGE", "RISK", "MANAGER"))
ROLES = {"SCOUT": "opening volume · gaps · stocks in play", "NEWS": "filings · headlines · market news",
         "CHARTS": "breakouts · pre-breakouts · live checks", "FLOW": "money flow · futures OI · blast radar",
         "CONFIRM": "holds the trigger 25 s · buyers still leading", "RISK": "limits · spacing · daily loss · weak-tape mode",
         "JUDGE": "last check before every buy · strikes", "MANAGER": "buys · exits · P&L", "REVIEW": "end-of-day post-mortem"}
_lock = threading.Lock()


def event(agent, text, kind="info"):
    """kind: info | buy | win | loss | warn | news"""
    try:
        t = core.ist_now().strftime("%H:%M:%S")
        with _lock:
            EVENTS.append({"t": t, "a": agent, "m": str(text)[:220], "k": kind})
            a = AGENTS.setdefault(agent, {"t": "", "m": "", "n": 0})
            a["t"], a["m"], a["n"] = t, str(text)[:120], a["n"] + 1
    except Exception:
        pass


def snapshot():
    with _lock:
        return list(EVENTS), [{"name": k, "role": ROLES.get(k, ""), **v} for k, v in AGENTS.items()]


def write(state):
    try:
        tmp = STATE + ".tmp"
        with open(tmp, "w") as f:
            json.dump(state, f, separators=(",", ":"), allow_nan=False, default=str)
        os.replace(tmp, STATE)
    except Exception as ex:
        print("dash write failed:", ex)

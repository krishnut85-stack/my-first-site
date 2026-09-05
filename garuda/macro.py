"""Where the rate cycle is — Garuda's read-only view of GIR's macro layer.

GIR owns this state machine (see gir/macro_cycle.py, which also carries the CLI
that writes the signals). Garuda reads it so the dashboard's CYCLE tab can show
the same phase the bots are trading, rather than a second opinion. The
classification logic is duplicated here because the two deploy to different
roots, and tests/test_cas_parity.py walks every case and fails if they ever
disagree. Change one, change both.

Layer 1 — the rate cycle (high confidence). Three monthly signals: RBI repo
direction, the 10-year G-sec 3-month slope, and bank credit growth YoY.
Rotation needs **two of the three** to agree; one flipping is noise.

Layer 2 — the calendar (low confidence, sizing only). Returns exactly 1.0 for
every month/sector pair the evidence does not support, so it can shade a
position the macro layer already chose but never open one.
"""

import json
import os
from datetime import date, datetime
from pathlib import Path

from . import config

EASING = "EASING"
EXPANSION = "EXPANSION"
SLOWDOWN = "SLOWDOWN"
UNKNOWN = "UNKNOWN"
PHASES = (EASING, EXPANSION, SLOWDOWN)

#: Where GIR keeps macro_signals.json and data/macro_phase.json. Both bots run
#: on the same droplet, so Garuda reads GIR's files rather than keeping a
#: second, divergent copy of the reading.
GIR_HOME = Path(os.environ.get("GIR_HOME", "/home/globalbot"))

PHASE_SECTORS = {
    EASING:    {"BANKING", "PVTBANK", "PSUBANK", "SERVICES", "REALTY", "AUTO"},
    EXPANSION: {"INFRA", "METALS", "ENERGY", "OILGAS", "CONSUMPTION", "AUTO"},
    SLOWDOWN:  {"IT", "PHARMA", "FMCG", "HEALTHCARE"},
}
PHASE_AVOID = {
    EASING:    {"IT", "FMCG", "PHARMA"},
    EXPANSION: {"BANKING", "PSUBANK", "PVTBANK"},
    SLOWDOWN:  {"REALTY", "METALS", "INFRA", "AUTO"},
}

#: What each phase means in one line, for the dashboard.
PHASE_STORY = {
    EASING: "Rates are being cut. Cheap money reaches lenders and "
            "rate-sensitive borrowers first.",
    EXPANSION: "Cuts have landed and credit is growing. Spending turns into "
               "orders — capex, infrastructure, materials.",
    SLOWDOWN: "Rates or yields are rising. Earnings that do not depend on the "
              "cycle hold up best.",
}

SIGNALS_MAX_AGE_DAYS = 45
GSEC_FALLING_BPS = -15
GSEC_RISING_BPS = 25

_REPO_VOTES = {"cutting": EASING, "holding_after_cuts": EXPANSION,
               "holding": EXPANSION, "hiking": SLOWDOWN}
_CREDIT_VOTES = {"accelerating": EXPANSION, "decelerating": SLOWDOWN,
                 "flat": None}

AUTO_FESTIVE_MONTHS = (10, 11)
AUTO_FESTIVE_MULT = 1.15
MARCH_MULT = 0.85
MULT_FLOOR, MULT_CEILING = 0.85, 1.15

CALENDAR_NOTES = {
    1: "Budget run-up — infra, capital goods, defence get the headlines",
    2: "Budget month — and the news is in the price by month end",
    3: "Weakest month; tax-loss selling and year-end book-squaring",
    4: "Broadest strength — new FY allocations, SIP flows resume",
    5: "Pharma and FMCG tend to hold up",
    6: "Auto seasonally weakest; pharma/FMCG steadier",
    7: "Results season — IT and banks report first",
    8: "No pattern worth naming",
    9: "Festive build begins — autos start discounting",
    10: "Festive demand — auto, consumer durables, realty",
    11: "Auto despatches usually peak",
    12: "Mild positive bias into year-end",
}


def _read_json(path):
    """Never raises: a missing or corrupt file must not break the dashboard."""
    try:
        p = Path(path)
        if p.exists():
            d = json.loads(p.read_text())
            if isinstance(d, dict):
                return d
    except Exception:  # noqa: BLE001
        pass
    return {}


def read_signals():
    """GIR's macro_signals.json, falling back to a copy beside Garuda."""
    for p in (GIR_HOME / "macro_signals.json",
              config.BASE_DIR / "macro_signals.json",
              config.BASE_DIR.parent / "gir" / "macro_signals.json"):
        d = _read_json(p)
        if d:
            return d
    return {}


def read_phase():
    """The phase GIR is actually trading, not one Garuda recomputed."""
    for p in (GIR_HOME / "data" / "macro_phase.json",
              GIR_HOME / "macro_phase.json"):
        d = _read_json(p)
        ph = str(d.get("phase", "")).strip().upper()
        if ph in PHASES:
            return ph
    return UNKNOWN


def signals_age_days(signals, today=None):
    stamp = str(signals.get("as_of", "")).strip()[:10]
    if not stamp:
        return None
    try:
        when = datetime.strptime(stamp, "%Y-%m-%d").date()
    except ValueError:
        return None
    return ((today or date.today()) - when).days


def is_stale(signals, today=None):
    age = signals_age_days(signals, today)
    return age is None or age > SIGNALS_MAX_AGE_DAYS


def vote_repo(signals):
    return _REPO_VOTES.get(str(signals.get("repo_direction", "")).strip().lower())


def vote_gsec(signals):
    raw = signals.get("gsec_10y_slope_3m_bps")
    if raw is None:
        return None
    try:
        bps = float(raw)
    except (TypeError, ValueError):
        return None
    if bps <= GSEC_FALLING_BPS:
        return EASING
    if bps >= GSEC_RISING_BPS:
        return SLOWDOWN
    return EXPANSION


def vote_credit(signals):
    return _CREDIT_VOTES.get(
        str(signals.get("credit_growth_yoy_trend", "")).strip().lower())


def tally(signals):
    votes = {"repo": vote_repo(signals), "gsec": vote_gsec(signals),
             "credit": vote_credit(signals)}
    counts = {p: 0 for p in PHASES}
    for v in votes.values():
        if v in counts:
            counts[v] += 1
    return counts, votes


def advance(current, signals, today=None):
    """The phase after these signals. Two of three must agree to rotate."""
    current = current if current in PHASES else UNKNOWN
    counts, votes = tally(signals)
    named = ", ".join("%s=%s" % (k, v or "—") for k, v in votes.items())
    if not any(counts.values()):
        return current, "no usable signals (%s) — holding %s" % (named, current)
    if is_stale(signals, today):
        age = signals_age_days(signals, today)
        shown = "undated" if age is None else "%dd old" % age
        return current, ("signals %s (> %dd) — holding %s, refresh "
                         "macro_signals.json" % (shown, SIGNALS_MAX_AGE_DAYS,
                                                 current))
    leader = max(PHASES, key=lambda p: counts[p])
    if counts[leader] < 2:
        return current, ("no majority (%s) — holding %s; one signal flipping "
                         "is noise" % (named, current))
    if leader == current:
        return current, "%d/3 confirm %s (%s)" % (counts[leader], current, named)
    return leader, "rotate %s -> %s on %d/3 (%s)" % (current, leader,
                                                     counts[leader], named)


def sector_tilt(sector, phase):
    if phase not in PHASE_SECTORS or not sector:
        return 0
    s = str(sector).strip().upper()
    if s in PHASE_SECTORS[phase]:
        return 1
    if s in PHASE_AVOID[phase]:
        return -1
    return 0


def size_multiplier(sector, when=None):
    """Calendar layer. Never 0 — it can shade a position, never veto one."""
    d = when or date.today()
    s = str(sector or "").strip().upper()
    if d.month == 3:
        return MARCH_MULT
    if s == "AUTO" and d.month in AUTO_FESTIVE_MONTHS:
        return AUTO_FESTIVE_MULT
    return 1.0


def calendar_note(when=None):
    return CALENDAR_NOTES.get((when or date.today()).month, "")


def state(today=None):
    """Everything the CYCLE tab draws, in one dict."""
    d = today or date.today()
    signals = read_signals()
    held = read_phase()
    suggested, why = advance(held, signals, d)
    counts, votes = tally(signals)
    return {
        "phase": held,
        "suggested": suggested,
        "why": why,
        "story": PHASE_STORY.get(held, ""),
        "as_of": signals.get("as_of"),
        "age_days": signals_age_days(signals, d),
        "stale": is_stale(signals, d),
        "signals": {
            "repo": {"value": signals.get("repo_direction"),
                     "vote": votes["repo"],
                     "source": "RBI MPC"},
            "gsec": {"value": signals.get("gsec_10y_slope_3m_bps"),
                     "vote": votes["gsec"],
                     "source": "10-yr G-sec, 3m slope (bps)"},
            "credit": {"value": signals.get("credit_growth_yoy_trend"),
                       "vote": votes["credit"],
                       "source": "Bank credit growth YoY"},
        },
        "counts": counts,
        "order": list(PHASES),
        "sectors": {p: sorted(PHASE_SECTORS[p]) for p in PHASES},
        "avoid": {p: sorted(PHASE_AVOID[p]) for p in PHASES},
        "stories": PHASE_STORY,
        "month": d.month,
        "calendar": [
            {"m": m,
             "note": CALENDAR_NOTES[m],
             "mult": (MARCH_MULT if m == 3
                      else AUTO_FESTIVE_MULT if m in AUTO_FESTIVE_MONTHS
                      else 1.0),
             "who": ("every sector" if m == 3
                     else "auto only" if m in AUTO_FESTIVE_MONTHS else "")}
            for m in range(1, 13)
        ],
    }

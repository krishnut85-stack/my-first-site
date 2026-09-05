"""Where the rate cycle is, and what that means for sector selection.

Two layers, deliberately unequal — the whole point of this module is that they
are *not* treated the same.

Layer 1 — the macro rate cycle (high confidence)
------------------------------------------------
This repeats because it has a cause: the cost of money changes, which changes
which businesses earn more. It is a state machine driven by three observable
numbers, checked monthly:

===============================  ==============================  ==================
Signal                           Source                          Reading
===============================  ==============================  ==================
Repo rate direction              RBI MPC, every ~2 months        cutting -> EASING
                                                                 holding after cuts
                                                                 -> EXPANSION
                                                                 hiking -> SLOWDOWN
10-year G-sec yield, 3m slope    NSE / CCIL                      falling -> EASING
                                                                 rising sharply
                                                                 -> SLOWDOWN
Bank credit growth YoY           RBI weekly statistical supp.    accelerating
                                                                 -> EXPANSION
                                                                 decelerating
                                                                 -> SLOWDOWN
===============================  ==============================  ==================

**Rotation needs two of the three to agree.** One signal flipping is noise; that
rule is the entire reason this is a state machine and not a lookup. A phase is
held until something else wins a majority.

Layer 2 — the calendar (low confidence, sizing only)
-----------------------------------------------------
Month-of-year seasonality is ten samples per month over a decade, and the
published studies contradict each other on most months. So it can only ever
scale a position the macro layer already chose — :func:`size_multiplier` returns
a number to multiply a quantity by, and there is no function here that returns
an entry signal from the calendar. Only the two patterns with a real cash-flow
story behind them move that number at all:

* **auto into the festive peak (Oct-Nov)** — dealer despatches genuinely rise
* **March weakness** — tax-loss selling and year-end book-squaring

Everything else in the calendar is carried as text in :func:`calendar_note` for
a human to read, and multiplies by exactly 1.0. That is on purpose: a bad
seasonality guess then costs a small sizing error instead of a wrong trade.

Feeding it
----------
Signals live in ``macro_signals.json`` beside the bot (see
macro_signals.sample.json), refreshed monthly after the MPC meeting::

    {"as_of": "2026-09-05",
     "repo_direction": "holding_after_cuts",
     "gsec_10y_slope_3m_bps": -8,
     "credit_growth_yoy_trend": "accelerating"}

Stale signals do not silently steer trades: past :data:`SIGNALS_MAX_AGE_DAYS`
the file stops being able to *change* the phase, and the reading is flagged.
"""

import json
from datetime import date, datetime
from pathlib import Path

# ---------------------------------------------------------------- phases ----

EASING = "EASING"           # rates being cut; rate-sensitives lead
EXPANSION = "EXPANSION"     # holding after cuts, credit accelerating; capex leads
SLOWDOWN = "SLOWDOWN"       # hiking or yields rising sharply; defensives lead
UNKNOWN = "UNKNOWN"         # no usable signals yet

PHASES = (EASING, EXPANSION, SLOWDOWN)

#: Sectors that lead in each phase, named as GIR's SECTOR_INDICES_MAP names them.
#: NOTE: NSE has no capital-goods, cement or defence index in that map, so the
#: capex phase is expressed through INFRA, METALS and ENERGY. If those indices
#: are ever added, widen this — do not silently proxy them elsewhere.
PHASE_SECTORS = {
    EASING:    {"BANKING", "PVTBANK", "PSUBANK", "SERVICES", "REALTY", "AUTO"},
    EXPANSION: {"INFRA", "METALS", "ENERGY", "OILGAS", "CONSUMPTION", "AUTO"},
    SLOWDOWN:  {"IT", "PHARMA", "FMCG", "HEALTHCARE"},
}

#: Sectors to stand back from in each phase — the ones whose tailwind has passed.
PHASE_AVOID = {
    EASING:    {"IT", "FMCG", "PHARMA"},
    EXPANSION: {"BANKING", "PSUBANK", "PVTBANK"},   # their easing run is behind them
    SLOWDOWN:  {"REALTY", "METALS", "INFRA", "AUTO"},
}

# --------------------------------------------------------------- signals ----

#: Signals are a monthly cadence; past this they can no longer change the phase.
SIGNALS_MAX_AGE_DAYS = 45

#: 3-month change in the 10-year G-sec yield, in basis points.
GSEC_FALLING_BPS = -15      # at or below -> yields falling
GSEC_RISING_BPS = 25        # at or above -> rising sharply

_REPO_VOTES = {
    "cutting": EASING,
    "holding_after_cuts": EXPANSION,
    "holding": EXPANSION,
    "hiking": SLOWDOWN,
}

_CREDIT_VOTES = {
    "accelerating": EXPANSION,
    "decelerating": SLOWDOWN,
    "flat": None,
}


def _bases():
    here = Path(__file__).resolve().parent
    return [Path.cwd(), here, here.parent]


def read_signals(path=None):
    """Load macro_signals.json. Returns {} when absent or unreadable.

    Never raises: a missing or corrupt signals file must leave the bot in its
    current phase, not crash it mid-session.
    """
    candidates = [Path(path)] if path else [Path(b) / "macro_signals.json"
                                            for b in _bases()]
    for p in candidates:
        try:
            if p.exists():
                d = json.loads(p.read_text())
                return d if isinstance(d, dict) else {}
        except Exception:  # noqa: BLE001
            continue
    return {}


_phase_cache = {}


def load_phase(path):
    """The phase we were in before this restart. UNKNOWN when unrecorded.

    Cached on the file's mtime: this is read once per scored symbol, so a fresh
    open() per call would put real file I/O in the scoring hot path.
    """
    try:
        p = Path(path)
        if not p.exists():
            return UNKNOWN
        key = str(p)
        stamp = p.stat().st_mtime_ns
        hit = _phase_cache.get(key)
        if hit and hit[0] == stamp:
            return hit[1]
        d = json.loads(p.read_text())
        ph = str(d.get("phase", "")).strip().upper()
        ph = ph if ph in PHASES else UNKNOWN
        _phase_cache[key] = (stamp, ph)
        return ph
    except Exception:  # noqa: BLE001
        return UNKNOWN


def save_phase(phase, path, reason="", today=None):
    """Persist the phase so a restart does not reset the state machine.

    Silent on failure — losing the file costs one held phase, never a crash.
    """
    try:
        Path(path).write_text(json.dumps(
            {"phase": phase, "reason": reason,
             "at": (today or date.today()).isoformat()}, indent=2))
        _phase_cache.pop(str(Path(path)), None)
    except Exception:  # noqa: BLE001
        pass


def signals_age_days(signals, today=None):
    """Days since the signals were last refreshed; None if undated."""
    stamp = str(signals.get("as_of", "")).strip()[:10]
    if not stamp:
        return None
    try:
        when = datetime.strptime(stamp, "%Y-%m-%d").date()
    except ValueError:
        return None
    return ((today or date.today()) - when).days


def is_stale(signals, today=None):
    """True when the signals are too old to be trusted to move the phase."""
    age = signals_age_days(signals, today)
    return age is None or age > SIGNALS_MAX_AGE_DAYS


# ------------------------------------------------------------- the votes ----

def vote_repo(signals):
    """RBI repo direction -> phase vote (None when unstated)."""
    return _REPO_VOTES.get(str(signals.get("repo_direction", "")).strip().lower())


def vote_gsec(signals):
    """10-year G-sec 3-month slope -> phase vote.

    Falling yields are risk-on for rate-sensitives; a sharp rise is the cue to
    rotate defensive. A flat curve reads as expansion — the cuts have landed and
    the market is not yet pricing the next hike.
    """
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
    """Bank credit growth YoY trend -> phase vote."""
    return _CREDIT_VOTES.get(
        str(signals.get("credit_growth_yoy_trend", "")).strip().lower())


def tally(signals):
    """The three votes as {phase: count}, plus which signal voted for what."""
    votes = {"repo": vote_repo(signals), "gsec": vote_gsec(signals),
             "credit": vote_credit(signals)}
    counts = {p: 0 for p in PHASES}
    for v in votes.values():
        if v in counts:
            counts[v] += 1
    return counts, votes


def advance(current, signals, today=None):
    """The phase after reading these signals. This is the state machine.

    Rotation requires **two of the three** signals to agree on a different
    phase — one signal flipping is noise. Anything short of that keeps the
    current phase, as does a stale signals file.

    Returns ``(phase, reason)``; the reason is a short human string for the log.
    """
    current = current if current in PHASES else UNKNOWN
    counts, votes = tally(signals)
    named = ", ".join(f"{k}={v or '—'}" for k, v in votes.items())

    if not any(counts.values()):
        return current, f"no usable signals ({named}) — holding {current}"

    if is_stale(signals, today):
        age = signals_age_days(signals, today)
        shown = "undated" if age is None else f"{age}d old"
        return current, (f"signals {shown} (> {SIGNALS_MAX_AGE_DAYS}d) — "
                         f"holding {current}, refresh macro_signals.json")

    leader = max(PHASES, key=lambda p: counts[p])
    if counts[leader] < 2:
        return current, (f"no majority ({named}) — holding {current}; "
                         "one signal flipping is noise")
    if leader == current:
        return current, f"{counts[leader]}/3 confirm {current} ({named})"
    return leader, f"rotate {current} -> {leader} on {counts[leader]}/3 ({named})"


def current_phase(previous=UNKNOWN, path=None, today=None):
    """Convenience: read the signals file and advance from ``previous``."""
    return advance(previous, read_signals(path), today)


# ------------------------------------------------------- sector selection ----

def sector_tilt(sector, phase):
    """+1 if this sector leads the phase, -1 if its tailwind has passed, else 0.

    This is the macro layer's only say in *what* to buy. It is a tilt, not a
    veto: the caller decides how much a tilt is worth.
    """
    if phase not in PHASE_SECTORS or not sector:
        return 0
    s = str(sector).strip().upper()
    if s in PHASE_SECTORS[phase]:
        return 1
    if s in PHASE_AVOID[phase]:
        return -1
    return 0


# ------------------------------------------------- calendar overlay (L2) ----

#: The only two calendar patterns with a cash-flow story behind them. Everything
#: else multiplies by 1.0 — see the module docstring.
AUTO_FESTIVE_MONTHS = (10, 11)
AUTO_FESTIVE_MULT = 1.15
MARCH_MULT = 0.85

MULT_FLOOR, MULT_CEILING = 0.85, 1.15

_CALENDAR_NOTES = {
    1: "Budget run-up — infra, capital goods, defence get the headlines",
    2: "Budget month — same, and the news is already in the price by month end",
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


def size_multiplier(sector, when=None):
    """How much to scale a position the macro layer already chose. Never 0.

    This is the calendar layer's *only* output that touches a number, and it
    cannot open a trade on its own — it multiplies a quantity that something
    else decided. Returns exactly 1.0 for every month/sector pair the evidence
    does not actually support.
    """
    d = when or date.today()
    s = str(sector or "").strip().upper()
    if d.month == 3:
        return MARCH_MULT
    if s == "AUTO" and d.month in AUTO_FESTIVE_MONTHS:
        return AUTO_FESTIVE_MULT
    return 1.0


def calendar_note(when=None):
    """The month's seasonal folklore, as text. Informational only — nothing
    downstream reads this, by design."""
    d = when or date.today()
    return _CALENDAR_NOTES.get(d.month, "")


def describe(phase, when=None):
    """One line for Telegram/logs: the phase, its sectors, and the month's note."""
    d = when or date.today()
    if phase not in PHASE_SECTORS:
        return f"macro phase UNKNOWN — refresh macro_signals.json ({d:%b %Y})"
    lead = ", ".join(sorted(PHASE_SECTORS[phase]))
    return (f"macro phase {phase} — leading: {lead} | "
            f"{d:%b}: {calendar_note(d)} (sizing only)")


# ------------------------------------------------------------------ CLI ----
#
#   python3 macro_cycle.py              what phase are we in, and is it stale?
#   python3 macro_cycle.py where        where each of the three numbers comes from
#   python3 macro_cycle.py set hold -8 up       write this month's reading
#
# Three words, three values — typeable from a phone over SSH.

SOURCES = [
    ("repo direction",
     "RBI MPC statement — rbi.org.in > Press Releases (or any broker app's "
     "rate page). Every ~2 months.",
     "cut | hold | hike      (hold = holding after cuts)"),
    ("10-year G-sec, 3-month slope",
     "ccilindia.com, or NSE's 10-year benchmark yield. Today's yield minus "
     "the yield three months ago.",
     "the change in BASIS POINTS, e.g. -8 for 8 bps lower"),
    ("bank credit growth YoY",
     "RBI Weekly Statistical Supplement — rbi.org.in > Statistics > WSS, "
     "'Scheduled Commercial Banks — Bank Credit' YoY %.",
     "up | down | flat       (up = accelerating vs last month)"),
]

_REPO_WORDS = {"cut": "cutting", "cutting": "cutting",
               "hold": "holding_after_cuts", "holding": "holding_after_cuts",
               "hike": "hiking", "hiking": "hiking"}
_CREDIT_WORDS = {"up": "accelerating", "accelerating": "accelerating",
                 "down": "decelerating", "decelerating": "decelerating",
                 "flat": "flat"}


def parse_set(argv):
    """Turn ['hold', '-8', 'up'] into a signals dict. ValueError on junk."""
    if len(argv) != 3:
        raise ValueError("need exactly three values: "
                         "<cut|hold|hike> <bps> <up|down|flat>")
    repo, bps, credit = argv
    if repo.lower() not in _REPO_WORDS:
        raise ValueError("repo must be cut, hold or hike - got %r" % repo)
    if credit.lower() not in _CREDIT_WORDS:
        raise ValueError("credit must be up, down or flat - got %r" % credit)
    try:
        slope = int(round(float(bps)))
    except (TypeError, ValueError):
        raise ValueError("G-sec slope must be a number in bps - got %r" % bps)
    return {"repo_direction": _REPO_WORDS[repo.lower()],
            "gsec_10y_slope_3m_bps": slope,
            "credit_growth_yoy_trend": _CREDIT_WORDS[credit.lower()]}


def signals_path():
    """The macro_signals.json this bot will actually read."""
    for base in _bases():
        p = Path(base) / "macro_signals.json"
        if p.exists():
            return p
    return Path(_bases()[0]) / "macro_signals.json"


def phase_path():
    """Where the running bot persists its phase.

    gir.py writes it under its DATA_DIR (``/home/globalbot/data``), so look
    there first — reading the wrong path would make the CLI report UNKNOWN
    forever while the bot was happily trading a phase.
    """
    for base in _bases():
        for p in (Path(base) / "data" / "macro_phase.json",
                  Path(base) / "macro_phase.json"):
            if p.exists():
                return p
    return Path(_bases()[0]) / "data" / "macro_phase.json"


def _cli(argv):
    if argv and argv[0] == "where":
        for name, where, fmt in SOURCES:
            print("\n%s\n  from : %s\n  type : %s" % (name, where, fmt))
        print("\nthen:  python3 macro_cycle.py set <repo> <bps> <credit>")
        return 0

    path = signals_path()

    if argv and argv[0] == "set":
        try:
            new = parse_set(argv[1:])
        except ValueError as e:
            print("error: %s\n\nexample:  python3 macro_cycle.py set hold -8 up" % e)
            return 2
        data = read_signals(path)
        data.update(new)
        # The free-text note described the OLD reading; leaving it beside fresh
        # numbers is worse than having no note at all.
        data.pop("note", None)
        data["as_of"] = date.today().isoformat()
        path.write_text(json.dumps(data, indent=2) + "\n")
        print("wrote %s\n" % path)

    signals = read_signals(path)
    if not signals:
        print("no signals file at %s\nrun:  python3 macro_cycle.py where" % path)
        return 1

    _counts, votes = tally(signals)
    age = signals_age_days(signals)
    held = load_phase(phase_path())
    phase, why = advance(held, signals)

    aged = "undated" if age is None else "%dd old" % age
    stale = ", STALE - refresh it" if is_stale(signals) else ""
    print("as of   : %s  (%s%s)" % (signals.get("as_of", "-"), aged, stale))
    print("repo    : %-20s -> %s" % (signals.get("repo_direction", "-"),
                                     votes["repo"] or "-"))
    print("gsec 3m : %-20s -> %s" % ("%s bps" % signals.get("gsec_10y_slope_3m_bps", "-"),
                                     votes["gsec"] or "-"))
    print("credit  : %-20s -> %s" % (signals.get("credit_growth_yoy_trend", "-"),
                                     votes["credit"] or "-"))
    print("\nGIR is trading : %s" % held)
    print("signals say    : %s   (%s)" % (phase, why))
    if phase != held:
        print("\n-> GIR picks this up at its own 08:05 check. Nothing to do by hand.")
    print("\n%s" % describe(phase))
    return 0


if __name__ == "__main__":
    import sys
    raise SystemExit(_cli(sys.argv[1:]))

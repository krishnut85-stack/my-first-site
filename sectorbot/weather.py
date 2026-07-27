"""Market Weather 👁 — the outside observer that briefs Mayura before the open.

Every pre-market morning it asks one question: "how does TODAY look?" — and
answers it from three independent signals, each fail-open:

  1. GEMINI (web-grounded): reads GIFT Nifty, overnight US/Asia closes and the
     morning's big India headlines — the "person reading the news".
  2. INDIA VIX from Kite: the fear gauge. Elevated fear = smaller steps.
  3. NIFTY momentum from Kite history: the last close vs 1 and 5 days ago.

The verdict is a single dial written to a small JSON file that BOTH bots read
(Garuda reads the same file on its side):

  score +2/+1/0  →  trade normally (full size)
  score -1       →  new buys at HALF size today
  score -2       →  NO new buys today (existing exits always run)

HONESTY: this is a RISK DIAL, not a crystal ball. Nobody predicts daily
direction reliably; what this does is scale how aggressively the bots ENTER on
mornings that look hostile, which is where most of the avoidable red comes
from. It never touches exits, and if anything fails (no network, no key, stale
file) the dial reads NEUTRAL — the bots never freeze. PAPER ONLY."""

import json
import os
from datetime import date, datetime
from pathlib import Path

from . import config

# Both bots (different folders, same machine) read this one file. Override with
# MARKET_WEATHER_FILE; default lives in the home dir so any checkout finds it.
def weather_file() -> Path:
    return Path(os.environ.get("MARKET_WEATHER_FILE", "")
                or Path.home() / "market_weather.json")


LABELS = {2: "STRONG UP", 1: "UP", 0: "NEUTRAL", -1: "DOWN", -2: "STRONG DOWN"}

_PROMPT = """You are a disciplined Indian market strategist writing a PRE-OPEN \
brief at {now} IST. Use web search to check, as of this morning:

1) GIFT NIFTY (the Nifty futures traded on NSE IX, formerly SGX Nifty): its \
current/overnight level vs the Nifty 50's last close — the single best pre-open \
gauge for today's Indian open.
2) OVERNIGHT GLOBAL CUES: last close of the S&P 500 and Nasdaq; Asian markets \
this morning (Nikkei, Hang Seng); Brent crude and USD/INR if notable.
3) MAJOR MARKET-MOVING INDIA NEWS this morning: RBI/budget/policy moves, \
global shocks, wars/tariffs, big earnings — only things that move the WHOLE \
market, not single-stock stories.

Judge how the Indian market looks for TODAY and the next session. Be \
conservative: most days are NEUTRAL; reserve +/-2 for clearly one-sided \
mornings (e.g. GIFT Nifty gapping ~1%+ with global cues aligned).

Respond with ONLY compact JSON, no prose:
{{"direction":-2|-1|0|1|2,"gift_nifty_pct":0.0,"reason":"one short sentence \
naming the numbers you saw"}}"""


# --------------------------------------------------------------------------
# Signal 1 — Gemini reads the news + GIFT Nifty (fail-open None)
# --------------------------------------------------------------------------
def judge_market(_post=None):
    """{direction, gift_nifty_pct, reason} or None on any failure."""
    from . import gemini
    if not gemini.configured():
        return None
    try:
        from .data_loader import IST
        now = datetime.now(IST).strftime("%Y-%m-%d %H:%M")
    except Exception:  # noqa: BLE001
        now = datetime.now().strftime("%Y-%m-%d %H:%M")
    payload = {
        "contents": [{"parts": [{"text": _PROMPT.format(now=now)}]}],
        "generationConfig": {"temperature": 0.2},
    }
    if config.GEMINI_USE_SEARCH:
        payload["tools"] = [{"google_search": {}}]
    try:
        resp = (_post or gemini._http_post)(payload)
        data = gemini._extract_json(gemini._extract_text(resp))
        if not data:
            return None
        d = int(data.get("direction", 0) or 0)
        return {"direction": max(-2, min(2, d)),
                "gift_nifty_pct": float(data.get("gift_nifty_pct", 0) or 0),
                "reason": str(data.get("reason", "")).strip()[:200]}
    except Exception:  # noqa: BLE001
        return None


# --------------------------------------------------------------------------
# Signals 2+3 — hard numbers from Kite (each fail-open None)
# --------------------------------------------------------------------------
def hard_signals(ds):
    """{vix, nifty_chg1_pct, nifty_chg5_pct} — None fields when unavailable."""
    out = {"vix": None, "nifty_chg1_pct": None, "nifty_chg5_pct": None}
    try:
        v = ds.last_price("INDIA VIX")
        out["vix"] = round(float(v), 2) if v and v > 0 else None
    except Exception:  # noqa: BLE001
        pass
    try:
        bars = ds.history(config.REGIME_INDEX, 10)
        closes = [b.close for b in bars if b.close and b.close > 0]
        if len(closes) >= 2:
            out["nifty_chg1_pct"] = round((closes[-1] / closes[-2] - 1) * 100, 2)
        if len(closes) >= 6:
            out["nifty_chg5_pct"] = round((closes[-1] / closes[-6] - 1) * 100, 2)
    except Exception:  # noqa: BLE001
        pass
    return out


# --------------------------------------------------------------------------
# The combine — deterministic, unit-tested
# --------------------------------------------------------------------------
def combine(gem, hard):
    """Merge the signals into one verdict dict (score -2..+2 + reasons)."""
    reasons = []
    score = 0
    if gem:
        score = gem["direction"]
        if gem.get("reason"):
            reasons.append(f"news: {gem['reason']}")
        if gem.get("gift_nifty_pct"):
            reasons.append(f"GIFT Nifty {gem['gift_nifty_pct']:+.1f}%")
    else:
        reasons.append("news read unavailable — judging on hard data only")
    vix = (hard or {}).get("vix")
    if vix is not None:
        if vix >= 25:
            score -= 1
            reasons.append(f"India VIX {vix:.0f} — high fear")
        elif vix >= 20:
            reasons.append(f"India VIX {vix:.0f} — elevated")
        else:
            reasons.append(f"India VIX {vix:.0f}")
    c5 = (hard or {}).get("nifty_chg5_pct")
    if c5 is not None:
        if c5 <= -3.0:
            score -= 1
            reasons.append(f"Nifty {c5:+.1f}% over 5d — falling market")
        elif c5 >= 3.0:
            score = min(score + 1, 2)
            reasons.append(f"Nifty {c5:+.1f}% over 5d — rising market")
    score = max(-2, min(2, score))
    return {
        "date": date.today().isoformat(),
        "ts": datetime.now().isoformat(timespec="seconds"),
        "score": score, "label": LABELS[score],
        "size_factor": 1.0 if score >= 0 else (0.5 if score == -1 else 0.0),
        "allow_new": score > -2,
        "reasons": reasons,
        "gemini": gem, "hard": hard or {},
    }


# --------------------------------------------------------------------------
# Persistence + the dial the engines actually read
# --------------------------------------------------------------------------
def save_weather(w: dict) -> None:
    try:
        p = weather_file()
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(w, indent=2), encoding="utf-8")
    except OSError:
        pass


def load_weather() -> dict | None:
    try:
        return json.loads(weather_file().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def dial(w: dict | None, max_age_h: float = 20.0) -> dict:
    """The safe dial for the engines: {size, block_new, label, score, info}.
    Missing/stale/foreign-day weather -> NEUTRAL (fail-open, never freezes)."""
    neutral = {"size": 1.0, "block_new": False, "label": "NEUTRAL",
               "score": 0, "info": ""}
    if not w:
        return neutral
    try:
        age_h = (datetime.now()
                 - datetime.fromisoformat(w["ts"])).total_seconds() / 3600.0
        if age_h > max_age_h or w.get("date") != date.today().isoformat():
            return neutral
        info = f"{w['label']} ({w['score']:+d}) — " + "; ".join(w.get("reasons", [])[:3])
        return {"size": float(w.get("size_factor", 1.0)),
                "block_new": not w.get("allow_new", True),
                "label": w["label"], "score": int(w["score"]),
                "info": info[:300]}
    except (KeyError, TypeError, ValueError):
        return neutral


def fetch_and_save(ds, _post=None) -> dict:
    """One pre-market oracle run: gather → combine → save → return verdict.
    Synthetic (non-Kite) data carries no real VIX/momentum — skip it rather
    than let fake numbers colour the verdict."""
    from .datasource import PaperDataSource
    hard = {} if isinstance(ds, PaperDataSource) else hard_signals(ds)
    w = combine(judge_market(_post=_post), hard)
    save_weather(w)
    return w

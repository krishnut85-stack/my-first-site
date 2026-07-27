"""Market Weather 👁 reader — Garuda's side of the shared pre-open oracle.

Mayura's oracle runs pre-market (Gemini reads GIFT Nifty + global cues + the
morning's news; Kite adds India VIX + Nifty momentum) and writes ONE verdict
file. Garuda reads the same file and turns it into a risk dial for its signal
books:

  score +2/+1/0  →  trade normally (full size)
  score -1       →  new entries at HALF size today
  score -2       →  NO new entries today (all exits still run)

Rotation books (chakra / qmom / captain) are deliberately untouched — their
design is "always invested, the rotation is the exit", and a daily dial has no
business inside a monthly/annual wheel.

FAIL-OPEN: file missing, unreadable, stale, or from another day → NEUTRAL.
Garuda never freezes because the oracle overslept. Stdlib only. PAPER ONLY.

View from a shell:   python3 -m garuda.weather
"""

import json
import os
from datetime import date, datetime
from pathlib import Path


def weather_file() -> Path:
    """The shared verdict file (same resolution as Mayura's oracle)."""
    return Path(os.environ.get("MARKET_WEATHER_FILE", "")
                or Path.home() / "market_weather.json")


def load_weather() -> dict | None:
    try:
        return json.loads(weather_file().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def dial(w: dict | None, max_age_h: float = 20.0) -> dict:
    """{size, block_new, label, score, info} — NEUTRAL unless the verdict is
    from today and fresh. `size` alone is enough to gate entries: 0 size means
    zero quantity on every would-be buy."""
    neutral = {"size": 1.0, "block_new": False, "label": "NEUTRAL",
               "score": 0, "info": ""}
    if not w:
        return neutral
    try:
        age_h = (datetime.now()
                 - datetime.fromisoformat(w["ts"])).total_seconds() / 3600.0
        if age_h > max_age_h or w.get("date") != date.today().isoformat():
            return neutral
        info = (f"{w['label']} ({w['score']:+d}) — "
                + "; ".join(w.get("reasons", [])[:3]))
        return {"size": max(float(w.get("size_factor", 1.0)), 0.0),
                "block_new": not w.get("allow_new", True),
                "label": str(w.get("label", "NEUTRAL")),
                "score": int(w.get("score", 0)),
                "info": info[:300]}
    except (KeyError, TypeError, ValueError):
        return neutral


def main() -> None:
    w = load_weather()
    d = dial(w)
    print(f"\n👁 Market Weather file: {weather_file()}")
    if not w:
        print("  (no verdict file — Mayura's `weather` cron writes it "
              "pre-market; Garuda trades NEUTRAL until then)\n")
        return
    print(f"  Verdict : {w.get('label')} ({w.get('score', 0):+d}) "
          f"on {w.get('date')} at {w.get('ts', '')[11:16]}")
    for r in w.get("reasons", []):
        print(f"    · {r}")
    if d["info"]:
        act = ("NO new entries today" if d["block_new"] or d["size"] == 0
               else f"entries at {d['size']:.0%} size" if d["size"] < 1
               else "trading normally")
        print(f"  Dial    : {act} (signal books; rotations untouched)\n")
    else:
        print("  Dial    : STALE/other-day verdict → NEUTRAL (full size)\n")


if __name__ == "__main__":
    main()

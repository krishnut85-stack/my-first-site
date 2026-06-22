"""Resolve which CSV to use.

Priority:
  1. an explicit path passed in code / on the CLI (--csv ...)
  2. the SECTORBOT_CSV environment variable
  3. the *.csv in data/ with the latest date in its filename (your daily
     upload, e.g. 2026-06-22.csv or 2026.06.22.csv); mtime breaks ties
  4. the bundled data/sectors.csv fallback

This means your workflow is simply: scp/upload today's file into
sectorbot/data/ (any name ending in .csv) and run the bot -- it picks the
newest one automatically.
"""

from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

from . import config

IST = timezone(timedelta(hours=5, minutes=30))


def classify_csv(path: Path) -> str:
    """Identify a CSV by its header: 'breadth', 'fundamentals', or 'unknown'."""
    try:
        with open(path, newline="", encoding="utf-8") as f:
            header = f.readline().upper()
    except OSError:
        return "unknown"
    if "MOMENTUM SCORE" in header and "RSI > 50" in header:
        return "breadth"
    if "INDUSTRY SCORE" in header or "PE TTM" in header:
        return "fundamentals"
    return "unknown"


def _date_key(path: Path) -> int:
    """Numeric date pulled from the filename digits, e.g.
    2026-06-22 / 2026.06.22 / 20260622 -> 20260622. No digits -> -1.

    Using the filename (not the file mtime) makes selection deterministic even
    in CI, where `git checkout` gives every file the same modified-time.
    """
    digits = "".join(ch for ch in path.stem if ch.isdigit())
    return int(digits) if digits else -1


def resolve_csv(explicit: Optional[str] = None) -> Path:
    if explicit:
        return Path(explicit).expanduser()
    if config.CSV_OVERRIDE:
        return Path(config.CSV_OVERRIDE).expanduser()

    # Pick the newest fundamentals/unknown CSV; never the breadth file.
    csvs = [
        p for p in config.DATA_DIR.glob("*.csv")
        if classify_csv(p) != "breadth"
    ]
    csvs.sort(key=lambda p: (_date_key(p), p.stat().st_mtime), reverse=True)
    if csvs:
        return csvs[0]
    return config.DATA_CSV


def list_breadth_csvs() -> list[Path]:
    """All breadth CSVs in data/ (sector- and industry-level), newest first."""
    breadths = [
        p for p in config.DATA_DIR.glob("*.csv")
        if classify_csv(p) == "breadth"
    ]
    breadths.sort(key=lambda p: (_date_key(p), p.stat().st_mtime), reverse=True)
    return breadths


def resolve_breadth_csv() -> Optional[Path]:
    """Newest breadth CSV in data/ (latest date in name), or None."""
    breadths = list_breadth_csvs()
    return breadths[0] if breadths else None


def list_snapshots() -> list[Path]:
    """Historical daily CSVs (for backtesting), oldest first, sorted by name."""
    if not config.SNAPSHOTS_DIR.exists():
        return []
    return sorted(config.SNAPSHOTS_DIR.glob("*.csv"))


def save_snapshot(explicit: Optional[str] = None) -> Path:
    """Copy today's active CSV into snapshots/<YYYY-MM-DD>.csv (IST date).

    Re-running on the same day overwrites that day's snapshot, so repeated
    runs never create duplicates. Returns the snapshot path.
    """
    import shutil

    src = resolve_csv(explicit)
    config.SNAPSHOTS_DIR.mkdir(parents=True, exist_ok=True)
    today = datetime.now(IST).date().isoformat()
    dst = config.SNAPSHOTS_DIR / f"{today}.csv"
    shutil.copyfile(src, dst)
    return dst

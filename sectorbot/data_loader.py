"""Resolve which CSV to use.

Priority:
  1. an explicit path passed in code / on the CLI (--csv ...)
  2. the SECTORBOT_CSV environment variable
  3. the most recently modified *.csv in data/  (your daily Termius upload)
  4. the bundled data/sectors.csv fallback

This means your workflow is simply: scp/upload today's file into
sectorbot/data/ (any name ending in .csv) and run the bot -- it picks the
newest one automatically.
"""

from pathlib import Path
from typing import Optional

from . import config


def resolve_csv(explicit: Optional[str] = None) -> Path:
    if explicit:
        return Path(explicit).expanduser()
    if config.CSV_OVERRIDE:
        return Path(config.CSV_OVERRIDE).expanduser()

    csvs = sorted(
        config.DATA_DIR.glob("*.csv"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if csvs:
        return csvs[0]
    return config.DATA_CSV


def list_snapshots() -> list[Path]:
    """Historical daily CSVs (for backtesting), oldest first, sorted by name."""
    if not config.SNAPSHOTS_DIR.exists():
        return []
    return sorted(config.SNAPSHOTS_DIR.glob("*.csv"))

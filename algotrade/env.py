"""Tiny .env loader so scripts work the same under systemd, tmux, and cron."""

from __future__ import annotations

import os
from pathlib import Path


def load_dotenv_if_present() -> None:
    for path in (Path.home() / ".env", Path(".env")):
        if path.exists():
            for line in path.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, _, v = line.partition("=")
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
            return

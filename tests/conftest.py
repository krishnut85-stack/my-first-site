"""Shared test fixtures.

Some tests call mayura._use_strategy(), which mutates the global sectorbot.config
(DATA_DIR, UNIVERSE_CSV, exit rules, etc.) to point at a temp folder. Without a
reset that mutated state leaks into later tests (e.g. config.DATA_DIR left
pointing at a deleted tmp dir). Snapshot every config setting before each test
and restore it afterwards so tests are order-independent.
"""

import pytest

from sectorbot import config


@pytest.fixture(autouse=True)
def _restore_config():
    snap = {k: getattr(config, k) for k in dir(config) if k.isupper()}
    yield
    for k, v in snap.items():
        try:
            setattr(config, k, v)
        except Exception:  # noqa: BLE001
            pass

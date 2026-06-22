"""Tests for daily CSV resolution and snapshotting."""

from datetime import datetime

from sectorbot import config
from sectorbot.data_loader import IST, resolve_csv, save_snapshot


def test_explicit_path_wins():
    assert resolve_csv("/tmp/foo.csv").name == "foo.csv"


def test_picks_newest_csv_in_data_dir(tmp_path, monkeypatch):
    older = tmp_path / "2026-06-20.csv"
    newer = tmp_path / "2026-06-22.csv"
    older.write_text("x")
    newer.write_text("y")
    import os, time
    os.utime(older, (time.time() - 100, time.time() - 100))

    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    monkeypatch.setattr(config, "CSV_OVERRIDE", "")
    assert resolve_csv().name == "2026-06-22.csv"


def test_falls_back_to_bundled(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)  # empty dir
    monkeypatch.setattr(config, "CSV_OVERRIDE", "")
    assert resolve_csv() == config.DATA_CSV


def test_save_snapshot_uses_ist_date_and_overwrites(tmp_path, monkeypatch):
    src = tmp_path / "today.csv"
    src.write_text("a,b\n1,2\n")
    snaps = tmp_path / "snaps"
    monkeypatch.setattr(config, "SNAPSHOTS_DIR", snaps)
    monkeypatch.setattr(config, "CSV_OVERRIDE", str(src))

    dst = save_snapshot()
    expected = datetime.now(IST).date().isoformat() + ".csv"
    assert dst.name == expected
    assert dst.read_text() == "a,b\n1,2\n"

    # re-running the same day overwrites rather than duplicating
    src.write_text("a,b\n3,4\n")
    dst2 = save_snapshot()
    assert dst2 == dst
    assert dst2.read_text() == "a,b\n3,4\n"
    assert len(list(snaps.glob("*.csv"))) == 1

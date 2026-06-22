"""Tests for daily CSV resolution."""

from sectorbot import config
from sectorbot.data_loader import resolve_csv


def test_explicit_path_wins():
    assert resolve_csv("/tmp/foo.csv").name == "foo.csv"


def test_picks_newest_csv_in_data_dir(tmp_path, monkeypatch):
    older = tmp_path / "2026-06-20.csv"
    newer = tmp_path / "2026-06-22.csv"
    older.write_text("x")
    newer.write_text("y")
    # make 'newer' genuinely newer
    import os, time
    os.utime(older, (time.time() - 100, time.time() - 100))

    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    monkeypatch.setattr(config, "CSV_OVERRIDE", "")
    assert resolve_csv().name == "2026-06-22.csv"


def test_falls_back_to_bundled(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)  # empty dir
    monkeypatch.setattr(config, "CSV_OVERRIDE", "")
    assert resolve_csv() == config.DATA_CSV

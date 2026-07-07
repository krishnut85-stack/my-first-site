"""The pool-age note tells you how old the freshest pool file is."""

import os
import time

import mayura


def _setup(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    (tmp_path / "thanikesa" / "snapshots").mkdir(parents=True)
    mayura._use_strategy("thanikesa")


def test_fresh_pool_no_warning(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    (tmp_path / "thanikesa" / "small.csv").write_text("NSE Code\nAAA\n")
    note = mayura._pool_age_note()
    assert "small.csv" in note and "0d old" in note
    assert "consider re-uploading" not in note


def test_old_pool_warns(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    f = tmp_path / "thanikesa" / "small.csv"
    f.write_text("NSE Code\nAAA\n")
    old = time.time() - 60 * 86400          # 60 days ago (> POOL_STALE_DAYS=45)
    os.utime(f, (old, old))
    note = mayura._pool_age_note()
    assert "60d old" in note and "consider re-uploading" in note


def test_no_pool_empty_note(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    assert mayura._pool_age_note() == ""

"""Mayura merges multiple pool files per strategy (e.g. small.csv + micro.csv)."""

import mayura
from sectorbot.stocks import load_symbols


def _merge_symbols(paths):
    seen, out = set(), []
    for p in paths:
        for r in load_symbols(p):
            if r["symbol"] not in seen:
                seen.add(r["symbol"])
                out.append(r["symbol"])
    return out


def test_pool_merges_folder_files(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    (tmp_path / "thanikesa" / "snapshots").mkdir(parents=True)
    (tmp_path / "thanikesa" / "small.csv").write_text("NSE Code\nAAA\nBBB\n")
    (tmp_path / "thanikesa" / "micro.csv").write_text("NSE Code\nBBB\nCCC\n")  # BBB dup
    mayura._use_strategy("thanikesa")
    pool = mayura._pool_csvs()
    assert len(pool) == 2
    merged = _merge_symbols(pool)
    assert set(merged) == {"AAA", "BBB", "CCC"}   # both files merged
    assert len(merged) == 3                        # BBB de-duped, not doubled


def test_pool_includes_flat_and_folder(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    (tmp_path / "thanikesa" / "snapshots").mkdir(parents=True)
    (tmp_path / "thanikesa.csv").write_text("NSE Code\nFLAT1\n")
    (tmp_path / "thanikesa" / "extra.csv").write_text("NSE Code\nFOLDER1\n")
    mayura._use_strategy("thanikesa")
    syms = _merge_symbols(mayura._pool_csvs())
    assert "FLAT1" in syms and "FOLDER1" in syms


def test_pool_empty_when_no_files(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    (tmp_path / "thanikesa" / "snapshots").mkdir(parents=True)
    mayura._use_strategy("thanikesa")
    assert mayura._pool_csvs() == []


def test_pool_does_not_grab_shared_universe(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    (tmp_path / "thanikesa" / "snapshots").mkdir(parents=True)
    (tmp_path / "universe.csv").write_text("NSE Code\nSHARED\n")   # shared, must skip
    (tmp_path / "thanikesa" / "small.csv").write_text("NSE Code\nAAA\n")
    mayura._use_strategy("thanikesa")
    syms = _merge_symbols(mayura._pool_csvs())
    assert "SHARED" not in syms and "AAA" in syms

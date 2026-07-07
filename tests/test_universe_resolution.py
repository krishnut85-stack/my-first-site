"""Each Mayura face must trade ONLY its own pool — never borrow the shared/legacy
mayura_data/universe.csv or another face's screen."""

import mayura
from sectorbot import config


def _mk(tmp_path, key):
    (tmp_path / key / "snapshots").mkdir(parents=True, exist_ok=True)


def test_does_not_borrow_shared_universe(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    # a shared/legacy universe that belongs to no single face
    (tmp_path / "universe.csv").write_text("NSE Code\nSHARED1\nSHARED2\n")
    _mk(tmp_path, "thanikesa")           # thanikesa has NO own screen
    mayura._use_strategy("thanikesa")
    # must NOT pick the shared universe.csv
    assert config.UNIVERSE_CSV != tmp_path / "universe.csv"
    # with no own file it points at the (missing) flat named file -> dormant
    assert config.UNIVERSE_CSV == tmp_path / "thanikesa.csv"
    assert not config.UNIVERSE_CSV.exists()


def test_uses_own_folder_universe(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    _mk(tmp_path, "thanikesa")
    (tmp_path / "universe.csv").write_text("NSE Code\nSHARED1\n")   # must be ignored
    (tmp_path / "thanikesa" / "universe.csv").write_text("NSE Code\nOWN1\n")
    mayura._use_strategy("thanikesa")
    assert config.UNIVERSE_CSV == tmp_path / "thanikesa" / "universe.csv"


def test_uses_flat_named_file_over_shared(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    _mk(tmp_path, "senthil")
    (tmp_path / "universe.csv").write_text("NSE Code\nSHARED1\n")   # must be ignored
    (tmp_path / "senthil.csv").write_text("NSE Code\nOWN1\n")
    mayura._use_strategy("senthil")
    assert config.UNIVERSE_CSV == tmp_path / "senthil.csv"


def test_case_insensitive_named_file(tmp_path, monkeypatch):
    monkeypatch.setattr(mayura, "MAYURA_DATA", tmp_path)
    _mk(tmp_path, "subramanya")
    (tmp_path / "Subramanya.csv").write_text("NSE Code\nOWN1\n")    # capital S
    mayura._use_strategy("subramanya")
    assert config.UNIVERSE_CSV == tmp_path / "Subramanya.csv"

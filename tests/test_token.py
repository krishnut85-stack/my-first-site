"""Tests for Kite access-token resolution (env var vs token file)."""

import json

from sectorbot import config


def test_env_token_wins(monkeypatch):
    monkeypatch.setattr(config, "KITE_ACCESS_TOKEN", "envtoken123")
    monkeypatch.setattr(config, "KITE_TOKEN_FILE", "/nonexistent")
    assert config.resolve_access_token() == "envtoken123"


def test_reads_json_token_file(tmp_path, monkeypatch):
    f = tmp_path / "kite_token.json"
    f.write_text(json.dumps({"access_token": "abc123def", "user_id": "XY1234"}))
    monkeypatch.setattr(config, "KITE_ACCESS_TOKEN", "")
    monkeypatch.setattr(config, "KITE_TOKEN_FILE", str(f))
    assert config.resolve_access_token() == "abc123def"


def test_reads_plain_token_file(tmp_path, monkeypatch):
    f = tmp_path / "token.txt"
    f.write_text("plaintoken999\n")
    monkeypatch.setattr(config, "KITE_ACCESS_TOKEN", "")
    monkeypatch.setattr(config, "KITE_TOKEN_FILE", str(f))
    assert config.resolve_access_token() == "plaintoken999"


def test_reads_keyvalue_token_file(tmp_path, monkeypatch):
    f = tmp_path / "token.env"
    f.write_text('OTHER=1\naccess_token="kv_token_55"\n')
    monkeypatch.setattr(config, "KITE_ACCESS_TOKEN", "")
    monkeypatch.setattr(config, "KITE_TOKEN_FILE", str(f))
    assert config.resolve_access_token() == "kv_token_55"


def test_no_token_returns_empty(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "KITE_ACCESS_TOKEN", "")
    monkeypatch.setattr(config, "KITE_TOKEN_FILE", str(tmp_path / "missing.json"))
    assert config.resolve_access_token() == ""

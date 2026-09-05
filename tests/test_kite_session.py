"""One access token per API key — so only one process may ever mint one.

Zerodha invalidates the previous token when a new one is issued. These tests
pin the behaviour that keeps a second process from taking the live bot's
session away.
"""

import importlib.util
import json
from datetime import date, timedelta
from pathlib import Path

import pytest


@pytest.fixture(scope="module")
def ks():
    path = Path(__file__).resolve().parent.parent / "gir" / "kite_session.py"
    spec = importlib.util.spec_from_file_location("gir_kite_session", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class FakeKite:
    """Stands in for KiteConnect. `alive` decides what profile() does."""

    def __init__(self, api_key=None, token=None, alive=True):
        self.api_key, self.access_token, self.alive = api_key, token, alive
        self.calls = []

    def set_access_token(self, tok):
        self.access_token = tok

    def profile(self):
        self.calls.append("profile")
        if not self.alive:
            raise Exception("TokenException: Incorrect `api_key` or `access_token`")
        return {"user_name": "TEST"}

    def quote(self, *a, **k):
        return {}

    def historical_data(self, *a, **k):
        return []

    def place_order(self, **kw):            # must never be reachable read-only
        raise AssertionError("an order was placed")


def ist_today(ks):
    from datetime import datetime
    return datetime.now(ks.IST).date()


def write_token(p, tok, day=None, ks=None):
    """Stamp with the IST date, the way the module and gir.py both do."""
    d = day or (ist_today(ks) if ks else date.today())
    p.write_text(json.dumps({"access_token": tok, "date": d.isoformat()}))


def test_a_live_saved_token_is_reused_and_nobody_logs_in(ks, tmp_path):
    p = tmp_path / "kite_token.json"
    write_token(p, "GOOD", ks=ks)
    logins = []

    def login_fn():
        logins.append(1)
        return FakeKite(token="NEW")

    k = ks.get_kite(login_fn, api_key="k", path=p, lock=tmp_path / "l",
                    kite_factory=lambda api_key=None: FakeKite(api_key, alive=True))
    assert k.access_token == "GOOD"
    assert logins == []                 # the live bot's session is untouched


def test_a_dead_token_triggers_exactly_one_login_and_is_saved(ks, tmp_path):
    p = tmp_path / "kite_token.json"
    write_token(p, "DEAD", ks=ks)
    logins = []

    def login_fn():
        logins.append(1)
        return FakeKite(token="FRESH")

    k = ks.get_kite(login_fn, api_key="k", path=p, lock=tmp_path / "l",
                    kite_factory=lambda api_key=None: FakeKite(api_key, alive=False))
    assert logins == [1]
    assert k.access_token == "FRESH"
    assert json.loads(p.read_text())["access_token"] == "FRESH"   # persisted


def test_yesterdays_token_is_not_even_tried(ks, tmp_path):
    """Tokens die ~07:00 IST, so a dated-yesterday token is known-dead."""
    p = tmp_path / "kite_token.json"
    write_token(p, "STALE", day=ist_today(ks) - timedelta(days=1), ks=ks)
    assert ks.load_token(p) is None


def test_the_loser_of_a_race_uses_the_winners_token(ks, tmp_path, monkeypatch):
    """The re-check under the lock is what stops a second, killing login."""
    p = tmp_path / "kite_token.json"
    write_token(p, "DEAD", ks=ks)
    logins = []

    # While we "wait" for the lock, another process refreshes the file.
    class WinnerWrites:
        def __init__(self, *a, **k):
            pass

        def __enter__(self):
            write_token(p, "WINNER", ks=ks)
            return self

        def __exit__(self, *a):
            return False

    monkeypatch.setattr(ks, "_Lock", WinnerWrites)

    def login_fn():
        logins.append(1)
        return FakeKite(token="SECOND")

    def factory(api_key=None):
        # the original "DEAD" fails, the winner's token works
        return FakeKite(api_key, alive=True) if p.read_text().count("WINNER") \
            else FakeKite(api_key, alive=False)

    seen = []

    def factory2(api_key=None):
        seen.append(1)
        return FakeKite(api_key, alive=(len(seen) > 1))

    k = ks.get_kite(login_fn, api_key="k", path=p, lock=tmp_path / "l",
                    kite_factory=factory2)
    assert logins == []                       # no second login was minted
    assert k.access_token == "WINNER"


def test_missing_or_corrupt_token_file_never_raises(ks, tmp_path):
    assert ks.load_token(tmp_path / "absent.json") is None
    bad = tmp_path / "bad.json"
    bad.write_text("{not json")
    assert ks.load_token(bad) is None
    bad.write_text('["a list"]')
    assert ks.load_token(bad) is None


def test_saved_token_is_written_atomically_and_locked_down(ks, tmp_path):
    p = tmp_path / "deep" / "kite_token.json"
    assert ks.save_token("ABC", p)
    assert json.loads(p.read_text())["access_token"] == "ABC"
    assert oct(p.stat().st_mode)[-3:] == "600"
    assert not (tmp_path / "deep" / "kite_token.tmp").exists()   # no leftover


def test_read_only_handle_has_no_order_methods(ks):
    ro = ks.ReadOnlyKite(FakeKite())
    assert callable(ro.quote) and callable(ro.historical_data)
    for forbidden in ("place_order", "modify_order", "cancel_order", "place_gtt"):
        with pytest.raises(AttributeError):
            getattr(ro, forbidden)


def test_read_only_wrapper_reuses_the_token_too(ks, tmp_path):
    p = tmp_path / "kite_token.json"
    write_token(p, "GOOD", ks=ks)
    ro = ks.read_only(lambda: FakeKite(token="X"), api_key="k", path=p,
                      lock=tmp_path / "l",
                      kite_factory=lambda api_key=None: FakeKite(api_key, alive=True))
    assert isinstance(ro, ks.ReadOnlyKite)
    with pytest.raises(AttributeError):
        ro.place_order

"""Tests for the Kite retry/backoff helper — how Mayura coexists with other
bots sharing the Kite token (throttle -> wait & retry, never fight)."""

import pytest

from sectorbot.datasource import _retry_kite


def test_succeeds_first_try():
    calls = []
    assert _retry_kite(lambda: calls.append(1) or "ok", sleep=lambda s: None) == "ok"
    assert len(calls) == 1


def test_retries_then_succeeds_with_backoff():
    attempts = {"n": 0}
    slept = []

    def flaky():
        attempts["n"] += 1
        if attempts["n"] < 3:
            raise RuntimeError("Too many requests")   # transient throttle
        return "done"

    out = _retry_kite(flaky, base_delay=1.0, sleep=slept.append)
    assert out == "done"
    assert attempts["n"] == 3
    assert slept == [1.0, 2.0]        # exponential backoff between the 3 tries


def test_gives_up_after_attempts():
    def always_busy():
        raise RuntimeError("network error")

    with pytest.raises(RuntimeError):
        _retry_kite(always_busy, attempts=3, sleep=lambda s: None)


def test_auth_errors_not_retried():
    attempts = {"n": 0}

    def bad_token():
        attempts["n"] += 1
        raise RuntimeError("Invalid token: api_key/access_token")

    with pytest.raises(RuntimeError):
        _retry_kite(bad_token, sleep=lambda s: None)
    assert attempts["n"] == 1          # tried once, did NOT retry

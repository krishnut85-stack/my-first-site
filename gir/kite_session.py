"""One owner for the Kite access token.

Zerodha allows **exactly one active access token per API key**. Minting a new
one silently invalidates the last, so a second process that logs in fresh takes
the live bot's session away and every lane starts eating 403 TokenException
with no order flow — a failure with no crash and no log line to point at.

The rule this module enforces:

    try the saved token first; log in fresh ONLY when it is genuinely dead,
    and only one process at a time.

``gir.py``'s KiteSession already did the first half. The second half is the
``flock`` here, which matters twice: it stops two processes racing into
simultaneous logins, and it stops TOTP-code reuse — the same six digits
replayed inside one 30-second window are rejected by Zerodha, so two logins a
second apart can both fail.

A token stays valid until roughly 07:00-07:30 IST the next morning, so a
healthy droplet does exactly one login per trading day, whoever wakes first.

Usage — pass your existing login function, do not write a second one::

    import kite_session
    kite = kite_session.get_kite(login_fn=kite_login)   # kite_login() -> KiteConnect

Anything that only reads (a study, a screener, an instrument dump) should ask
for :func:`read_only`, which hands back an object with no order methods on it
at all — it cannot place, modify or cancel, whatever it is later asked to do.
"""

import errno
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

IST = timezone(timedelta(hours=5, minutes=30))

#: Where the token lives. Every module must agree on this — a module reading a
#: different path finds nothing, logs in fresh, and takes down the others.
DEFAULT_TOKEN_FILE = "/home/globalbot/data/kite_token.json"

#: Held only while a login is in flight, never during normal reads.
DEFAULT_LOCK_FILE = "/home/globalbot/data/.kite_login.lock"

#: Read methods a study or screener may use. Everything else — place_order,
#: modify_order, cancel_order, place_gtt — is absent by construction.
READ_ONLY_METHODS = (
    "profile", "margins", "quote", "ltp", "ohlc", "instruments",
    "historical_data", "holdings", "positions", "orders", "trades",
)


def token_path():
    return Path(os.environ.get("KITE_TOKEN_FILE", DEFAULT_TOKEN_FILE))


def lock_path():
    return Path(os.environ.get("KITE_LOCK_FILE", DEFAULT_LOCK_FILE))


def _today_ist():
    return datetime.now(IST).date().isoformat()


def load_token(path=None):
    """The saved token if it was written today, else None.

    Dated deliberately: a token from yesterday is known-dead (they expire at
    ~07:00 IST), so there is no point spending a network call to prove it.
    """
    p = Path(path) if path else token_path()
    try:
        d = json.loads(p.read_text())
    except Exception:  # noqa: BLE001
        return None
    if not isinstance(d, dict):
        return None
    tok = str(d.get("access_token", "")).strip()
    if not tok:
        return None
    stamp = str(d.get("date", "")).strip()[:10]
    return tok if (not stamp or stamp == _today_ist()) else None


def save_token(access_token, path=None):
    """Persist a freshly minted token so the next process reuses it."""
    p = Path(path) if path else token_path()
    try:
        p.parent.mkdir(parents=True, exist_ok=True)
        tmp = p.with_suffix(".tmp")
        tmp.write_text(json.dumps({"access_token": access_token,
                                   "date": _today_ist()}))
        os.chmod(tmp, 0o600)
        tmp.replace(p)          # atomic: a reader never sees a half-written file
        return True
    except Exception:  # noqa: BLE001
        return False


def _alive(kite):
    """Is this token actually good? One cheap authenticated call."""
    try:
        kite.profile()
        return True
    except Exception:  # noqa: BLE001
        return False


class _Lock:
    """flock around the login. Falls through if fcntl is unavailable."""

    def __init__(self, path, timeout=90):
        self.path, self.timeout, self.fh = Path(path), timeout, None

    def __enter__(self):
        try:
            import fcntl
            import time
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.fh = open(self.path, "w")
            deadline = time.time() + self.timeout
            while True:
                try:
                    fcntl.flock(self.fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    return self
                except OSError as e:
                    if e.errno not in (errno.EACCES, errno.EAGAIN):
                        raise
                    if time.time() > deadline:
                        return self          # proceed rather than never log in
                    time.sleep(0.5)
        except Exception:  # noqa: BLE001
            return self

    def __exit__(self, *exc):
        try:
            if self.fh:
                import fcntl
                fcntl.flock(self.fh, fcntl.LOCK_UN)
                self.fh.close()
        except Exception:  # noqa: BLE001
            pass
        return False


def get_kite(login_fn, api_key=None, kite_factory=None, path=None,
             lock=None, log=None):
    """An authenticated KiteConnect, reusing the live token wherever possible.

    ``login_fn`` is YOUR existing TOTP login — it must return a KiteConnect (or
    anything exposing ``access_token``). It is called only when the saved token
    fails an authenticated call, and only while holding the lock.

    The re-check after acquiring the lock is the point of the whole design: if
    two processes start together, the loser waits, then finds the winner's
    fresh token already on disk and uses it instead of minting a second one
    that would kill the first.
    """
    say = log.info if log else (lambda *a, **k: None)
    factory = kite_factory
    if factory is None:                       # imported lazily: tests need neither
        from kiteconnect import KiteConnect   # noqa: PLC0415
        factory = KiteConnect

    key = api_key or os.environ.get("KITE_API_KEY", "")

    tok = load_token(path)
    if tok:
        k = factory(api_key=key)
        k.set_access_token(tok)
        if _alive(k):
            say("kite: reused the saved token (no login, no one displaced)")
            return k
        say("kite: saved token is dead — taking the login lock")

    with _Lock(lock or lock_path()):
        # Someone may have refreshed it while we queued for the lock.
        tok2 = load_token(path)
        if tok2 and tok2 != tok:
            k = factory(api_key=key)
            k.set_access_token(tok2)
            if _alive(k):
                say("kite: another process refreshed it while we waited")
                return k
        say("kite: fresh TOTP login")
        fresh = login_fn()
        new = (getattr(fresh, "access_token", None)
               or getattr(fresh, "_access_token", None))
        if new:
            save_token(new, path)
        return fresh


class ReadOnlyKite:
    """A Kite handle with the order methods absent, not merely discouraged.

    Attribute access is whitelisted, so ``place_order`` raises AttributeError
    rather than reaching the exchange. Give this to studies, screeners and
    anything an agent drives.
    """

    def __init__(self, kite):
        self._kite = kite

    def __getattr__(self, name):
        if name in READ_ONLY_METHODS:
            return getattr(self._kite, name)
        raise AttributeError(
            f"{name!r} is not available on a read-only Kite handle "
            f"(allowed: {', '.join(READ_ONLY_METHODS)})")

    def __repr__(self):
        return "<ReadOnlyKite: reads only, no order methods>"


def read_only(login_fn, **kw):
    """get_kite(), wrapped so it cannot place an order."""
    return ReadOnlyKite(get_kite(login_fn, **kw))

"""Kite Connect TOTP auto-login with a daily token cache.

Replicates the proven login flow from the previous server setup so the bot
can run unattended: /api/login (user+password) -> /api/twofa (TOTP) ->
request_token -> generate_session. The day's access token is cached to disk
and reused until it expires.

Credentials come from the environment (.env on the server, same names as
before — never hardcode or commit them):
    KITE_API_KEY, KITE_API_SECRET
    ZERODHA_USER_ID, ZERODHA_PASSWORD, KITE_TOTP_SECRET
Optional:
    KITE_ACCESS_TOKEN  - if set (manual login), used directly
    KITE_TOKEN_FILE    - token cache path (default ~/.kite_token.json)
"""

from __future__ import annotations

import datetime as dt
import json
import logging
import os
import time
from pathlib import Path

from ..timeutils import IST

log = logging.getLogger(__name__)

TOKEN_FILE = Path(os.environ.get("KITE_TOKEN_FILE", "~/.kite_token.json")).expanduser()


def _today() -> str:
    return str(dt.datetime.now(IST).date())


def _cached_token() -> str | None:
    try:
        data = json.loads(TOKEN_FILE.read_text())
        if data.get("date") == _today() and data.get("access_token"):
            return data["access_token"]
    except Exception:
        pass
    return None


def _save_token(token: str) -> None:
    try:
        TOKEN_FILE.write_text(json.dumps({"date": _today(), "access_token": token}))
        TOKEN_FILE.chmod(0o600)
    except Exception as exc:
        log.warning("token cache write failed: %s", exc)


def auto_login():
    """Return a logged-in KiteConnect. Raises RuntimeError on failure."""
    from kiteconnect import KiteConnect

    api_key = os.environ.get("KITE_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("KITE_API_KEY not set")
    kite = KiteConnect(api_key=api_key)

    # 1) Explicit token from env (manual login flow).
    env_token = os.environ.get("KITE_ACCESS_TOKEN", "").strip()
    if env_token:
        kite.set_access_token(env_token)
        return kite

    # 2) Today's cached token.
    cached = _cached_token()
    if cached:
        kite.set_access_token(cached)
        try:
            kite.profile()
            log.info("kite: reused today's cached token")
            return kite
        except Exception:
            log.info("kite: cached token stale — fresh TOTP login")

    # 3) Fresh TOTP login.
    import pyotp
    import requests

    api_secret = os.environ.get("KITE_API_SECRET", "").strip()
    user_id = os.environ.get("ZERODHA_USER_ID", "").strip()
    password = os.environ.get("ZERODHA_PASSWORD", "").strip()
    totp_secret = os.environ.get("KITE_TOTP_SECRET", "").strip()
    if not all([api_secret, user_id, password, totp_secret]):
        raise RuntimeError(
            "TOTP login needs KITE_API_SECRET, ZERODHA_USER_ID, "
            "ZERODHA_PASSWORD, KITE_TOTP_SECRET"
        )

    s = requests.Session()
    s.headers.update({"User-Agent": "Mozilla/5.0"})

    r1 = s.post(
        "https://kite.zerodha.com/api/login",
        data={"user_id": user_id, "password": password},
        timeout=30,
    )
    request_id = r1.json().get("data", {}).get("request_id", "") if r1.ok else ""
    if not request_id:
        raise RuntimeError(f"kite login step 1 failed (HTTP {r1.status_code})")

    time.sleep(1)
    r2 = s.post(
        "https://kite.zerodha.com/api/twofa",
        data={
            "user_id": user_id,
            "request_id": request_id,
            "twofa_value": pyotp.TOTP(totp_secret).now(),
            "twofa_type": "totp",
        },
        timeout=30,
        allow_redirects=True,
    )
    final_url = r2.url
    if "request_token=" not in final_url:
        r3 = s.get(kite.login_url(), allow_redirects=True, timeout=30)
        final_url = r3.url
    if "request_token=" not in final_url:
        raise RuntimeError("kite 2FA succeeded but no request_token in redirect")

    request_token = final_url.split("request_token=")[1].split("&")[0]
    session = kite.generate_session(request_token, api_secret=api_secret)
    token = session.get("access_token", "")
    if not token:
        raise RuntimeError("generate_session returned no access_token")

    kite.set_access_token(token)
    _save_token(token)
    log.info("kite: fresh TOTP login OK")
    return kite

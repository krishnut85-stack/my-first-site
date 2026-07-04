"""Automatic Zerodha Kite daily token refresh — so the whole system needs NO
manual login each morning.

Kite access tokens expire every day (~07:30 IST). This logs in for you using
credentials read from the environment (never committed), completes the TOTP
2FA, exchanges the request_token for a fresh access_token, and writes it to
KITE_TOKEN_FILE. Run it from cron before the market opens.

Required env (put these in /home/globalbot/.env, chmod 600 — NEVER in git):
    KITE_API_KEY        your Kite Connect app api_key
    KITE_API_SECRET     your Kite Connect app api_secret
    KITE_USER_ID        your Zerodha client id (e.g. AB1234)
    KITE_PASSWORD       your Zerodha login password
    KITE_TOTP_SECRET    the base32 seed behind your authenticator ("external
                        TOTP" secret from Zerodha profile > settings > 2FA)
    KITE_TOKEN_FILE     where to write the token (e.g. /home/globalbot/data/kite_token.json)

Stdlib only (urllib + a hand-rolled TOTP) — no pip needed beyond kiteconnect,
which the feed already uses.
"""

import base64
import hashlib
import hmac
import http.cookiejar
import json
import os
import struct
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from urllib.parse import parse_qs, urlparse

LOGIN = "https://kite.zerodha.com/api/login"
TWOFA = "https://kite.zerodha.com/api/twofa"
CONNECT = "https://kite.zerodha.com/connect/login?v=3&api_key={}"
UA = "Mozilla/5.0"


def totp(secret: str, when: float | None = None) -> str:
    """RFC-6238 6-digit TOTP from a base32 secret (stdlib only)."""
    secret = secret.strip().replace(" ", "").upper()
    secret += "=" * (-len(secret) % 8)                 # pad to a multiple of 8
    key = base64.b32decode(secret)
    counter = int((when if when is not None else time.time()) // 30)
    mac = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
    off = mac[-1] & 0x0F
    code = (struct.unpack(">I", mac[off:off + 4])[0] & 0x7FFFFFFF) % 1_000_000
    return f"{code:06d}"


def _post(opener, url, data):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, body, headers={"User-Agent": UA, "X-Kite-Version": "3"})
    with opener.open(req, timeout=30) as r:
        return json.loads(r.read().decode())


class _Grab(urllib.request.HTTPRedirectHandler):
    """Capture request_token from the redirect Kite issues after 2FA."""
    token = None

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if "request_token=" in newurl:
            _Grab.token = parse_qs(urlparse(newurl).query).get("request_token", [None])[0]
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch_access_token() -> str:
    key = os.environ["KITE_API_KEY"]
    secret = os.environ["KITE_API_SECRET"]
    uid = os.environ["KITE_USER_ID"]
    pwd = os.environ["KITE_PASSWORD"]
    seed = os.environ["KITE_TOTP_SECRET"]

    cj = http.cookiejar.CookieJar()
    _Grab.token = None
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(cj), _Grab())

    r1 = _post(opener, LOGIN, {"user_id": uid, "password": pwd})
    if r1.get("status") != "success":
        raise RuntimeError(f"login failed: {r1}")
    request_id = r1["data"]["request_id"]

    r2 = _post(opener, TWOFA, {"user_id": uid, "request_id": request_id,
                               "twofa_value": totp(seed), "twofa_type": "totp"})
    if r2.get("status") != "success":
        raise RuntimeError(f"2FA failed: {r2}")

    try:                                                # this redirect carries the token
        opener.open(urllib.request.Request(CONNECT.format(key),
                    headers={"User-Agent": UA}), timeout=30)
    except Exception:                                   # noqa: BLE001 — redirect target may 4xx
        pass
    token = _Grab.token
    if not token:
        raise RuntimeError("could not capture request_token (check redirect URL on the Kite app)")

    from kiteconnect import KiteConnect  # type: ignore
    sess = KiteConnect(api_key=key).generate_session(token, api_secret=secret)
    return sess["access_token"]


def main():
    try:
        access = fetch_access_token()
    except Exception as exc:  # noqa: BLE001
        print(f"[kite_login] FAILED: {exc}", flush=True)
        raise SystemExit(1)
    out = os.environ.get("KITE_TOKEN_FILE", "").strip()
    payload = json.dumps({"access_token": access})
    if out:
        Path(out).parent.mkdir(parents=True, exist_ok=True)
        Path(out).write_text(payload)
        os.chmod(out, 0o600)
        print(f"[kite_login] fresh access_token written to {out}", flush=True)
    else:
        print(payload)


if __name__ == "__main__":
    main()

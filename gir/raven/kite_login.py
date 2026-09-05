#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kite_login.py  —  standalone Kite TOTP auto-login for RAVEN.

Mirrors gir.py's proven KiteSession.login() flow EXACTLY:
  /api/login (user_id + password) -> request_id
  /api/twofa  (pyotp TOTP)        -> redirect -> request_token
  generate_session(request_token) -> access_token

Differences from gir.py's version (deliberate):
  * Reuses gir.py's SAVED daily token file -> RAVEN and gir share ONE login
    per day (no double Zerodha hit, no rate-limit conflict).
  * Returns a CLEAN KiteConnect (no _paper_hard_block). RAVEN's own PAPER_MODE
    governs writes; RAVEN only calls reads (quote/ltp) + paper fills.

RAVEN already does `from kite_login import get_kite` first, so this drops in.
Credentials come from /home/globalbot/.env (never hardcoded here).
"""

import os
import json
import time
import datetime as dt
from pathlib import Path

# Must match gir.py's KITE_TOKEN_FILE exactly (DATA_DIR/kite_token.json).
# It used to default to /home/globalbot/kite_token.json — one directory too
# high. With KITE_TOKEN_FILE unset, RAVEN then found no token, logged in
# fresh, and invalidated globaleye's session; gir.py logged in fresh in turn,
# invalidating RAVEN's. Zerodha allows exactly one live token per API key.
KITE_TOKEN_FILE = Path(os.environ.get(
    "KITE_TOKEN_FILE", "/home/globalbot/data/kite_token.json"))

IST = dt.timezone(dt.timedelta(hours=5, minutes=30))

def _today_ist():
    return dt.datetime.now(IST).date()

def _load_json(path, default):
    try:
        return json.loads(Path(path).read_text())
    except Exception:
        return default

def _save_token(access_token):
    try:
        KITE_TOKEN_FILE.write_text(json.dumps(
            {"date": str(_today_ist()), "access_token": access_token}))
    except Exception:
        pass

def get_kite():
    """Return a logged-in KiteConnect, or None on failure."""
    from kiteconnect import KiteConnect
    import requests, pyotp

    API_KEY    = os.environ.get("KITE_API_KEY", "")
    API_SECRET = os.environ.get("KITE_API_SECRET", "")
    TOTP_SECRET= os.environ.get("KITE_TOTP_SECRET", "")
    USER_ID    = os.environ.get("ZERODHA_USER_ID", "")
    PASSWORD   = os.environ.get("ZERODHA_PASSWORD", "")

    kite = KiteConnect(api_key=API_KEY)

    # Step 1: reuse today's saved token (shared with gir.py) if present
    td = _load_json(KITE_TOKEN_FILE, {})
    if td.get("date") == str(_today_ist()) and td.get("access_token"):
        try:
            kite.set_access_token(td["access_token"])
            kite.profile()  # validate
            print("[kite_login] reused today's saved token")
            return kite
        except Exception:
            print("[kite_login] saved token expired — fresh TOTP login")

    # Step 2: fresh TOTP login
    if not (PASSWORD and TOTP_SECRET and USER_ID):
        print("[kite_login] ERROR: missing ZERODHA_USER_ID / PASSWORD / TOTP secret")
        return None

    s = requests.Session()
    s.headers.update({"User-Agent": "Mozilla/5.0"})

    r1 = s.post("https://kite.zerodha.com/api/login",
                data={"user_id": USER_ID, "password": PASSWORD}, timeout=30)
    if r1.status_code != 200:
        print(f"[kite_login] ERROR: login step 1 failed: {r1.status_code}")
        return None
    request_id = r1.json().get("data", {}).get("request_id", "")
    if not request_id:
        print("[kite_login] ERROR: no request_id")
        return None

    time.sleep(1)
    totp = pyotp.TOTP(TOTP_SECRET).now()
    r2 = s.post("https://kite.zerodha.com/api/twofa",
                data={"user_id": USER_ID, "request_id": request_id,
                      "twofa_value": totp, "twofa_type": "totp"},
                timeout=30, allow_redirects=True)

    final_url = r2.url
    if "request_token=" not in final_url:
        if r2.status_code == 200 and "status" in r2.text:
            login_url = kite.login_url()
            r3 = s.get(login_url, allow_redirects=True, timeout=30)
            final_url = r3.url
    if "request_token=" not in final_url:
        print(f"[kite_login] ERROR: no request_token in {final_url[:100]}")
        return None

    request_token = final_url.split("request_token=")[1].split("&")[0]
    data = kite.generate_session(request_token, api_secret=API_SECRET)
    access_token = data.get("access_token", "")
    if not access_token:
        print("[kite_login] ERROR: no access_token from generate_session")
        return None

    kite.set_access_token(access_token)
    _save_token(access_token)
    print("[kite_login] fresh TOTP login OK")
    return kite


if __name__ == "__main__":
    # quick self-test
    try:
        from dotenv import load_dotenv
        load_dotenv("/home/globalbot/.env")
    except Exception:
        pass
    k = get_kite()
    if k:
        print("PROFILE:", k.profile().get("user_name"))
    else:
        print("LOGIN FAILED")



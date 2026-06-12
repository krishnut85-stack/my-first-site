#!/usr/bin/env python3
"""Generate the daily Kite Connect access token.

Kite access tokens expire every morning. Run this once per day:

    export KITE_API_KEY=xxx KITE_API_SECRET=yyy
    python scripts/kite_login.py

It prints the login URL; open it, authorize, and paste back the
`request_token` from the redirect URL. Export the printed access token:

    export KITE_ACCESS_TOKEN=<printed token>
"""

import os
import sys


def main() -> None:
    try:
        from kiteconnect import KiteConnect
    except ImportError:
        sys.exit("pip install kiteconnect")

    api_key = os.environ.get("KITE_API_KEY")
    api_secret = os.environ.get("KITE_API_SECRET")
    if not api_key or not api_secret:
        sys.exit("Set KITE_API_KEY and KITE_API_SECRET environment variables")

    kite = KiteConnect(api_key=api_key)
    print(f"1. Open and authorize: {kite.login_url()}")
    request_token = input("2. Paste request_token from the redirect URL: ").strip()
    session = kite.generate_session(request_token, api_secret=api_secret)
    print("\nexport KITE_ACCESS_TOKEN=" + session["access_token"])


if __name__ == "__main__":
    main()

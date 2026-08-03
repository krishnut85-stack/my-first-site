#!/usr/bin/env python3
"""
paper_exit_monitor.py — Phase 5 Virtual Exit Engine

Polls LTPs every 60s during NSE market hours, walks all OPEN paper_trades,
and fires paper_record_exit() on virtual SL hit, trail ratchet, or time stop.

Runs as systemd service paper_exit_monitor.service.
Always does fresh TOTP login on startup (no saved-token reuse).
Strategy-aware: GIR_EQ / HUNTER_* get equity trail + 30d stop;
                GIR_FNO gets fixed SL + 7d stop, no trail.
"""
import os
import sys
import time
import json
import logging
import traceback
from datetime import datetime, timezone, timedelta
from pathlib import Path

# Load .env BEFORE importing anything else env-dependent
try:
    from dotenv import load_dotenv
    load_dotenv("/home/globalbot/.env")
except ImportError:
    pass  # If dotenv missing, assume systemd EnvironmentFile loaded vars

# Make paper_trader importable
sys.path.insert(0, "/home/globalbot/paper")
import paper_trader as pt
import notify

import requests
import pyotp
from kiteconnect import KiteConnect

# ============================================================
# CONSTANTS — mirror Phase 3 settings in gir.py / hunter_config
# Tune here without touching gir.py or hunter
# ============================================================
EQ_INITIAL_SL_PCT = 0.06   # hard floor: entry * (1 - 0.06)
EQ_TRAIL_SL_PCT   = 0.07   # trail: peak * (1 - 0.07)
EQ_MAX_HOLD_DAYS  = 30
FNO_SL_PCT        = 0.25   # premium drop %
FNO_MAX_HOLD_DAYS = 7

POLL_SECONDS = 60
EOD_BUMP_HOUR_UTC = 10     # ~15:30 IST = 10:00 UTC; bump at 10:05
EOD_BUMP_MIN_UTC  = 5

LOG_FILE = "/home/globalbot/paper/exit_monitor.log"

# ============================================================
# Logging
# ============================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("paper_exit_monitor")

# ============================================================
# Env credentials
# ============================================================
KITE_API_KEY     = os.getenv("KITE_API_KEY", "")
KITE_API_SECRET  = os.getenv("KITE_API_SECRET", "")
KITE_TOTP_SECRET = os.getenv("KITE_TOTP_SECRET", "")
ZERODHA_USER_ID  = os.getenv("ZERODHA_USER_ID", "")
ZERODHA_PASSWORD = os.getenv("ZERODHA_PASSWORD", "")

# ============================================================
# Helpers
# ============================================================
def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def is_market_hours_utc(now: datetime = None) -> bool:
    """NSE: Mon-Fri, 09:15-15:30 IST = 03:45-10:00 UTC."""
    if now is None:
        now = utc_now()
    if now.weekday() >= 5:  # Sat=5, Sun=6
        return False
    t = now.hour * 60 + now.minute
    return (3 * 60 + 45) <= t <= (10 * 60 + 0)


def kite_login() -> KiteConnect:
    """Fresh TOTP login. Verbatim port of gir.py login flow, minus saved-token reuse."""
    if not (KITE_API_KEY and KITE_API_SECRET and KITE_TOTP_SECRET
            and ZERODHA_USER_ID and ZERODHA_PASSWORD):
        raise RuntimeError("Missing one or more Kite/Zerodha env vars")

    kite = KiteConnect(api_key=KITE_API_KEY)
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0"})

    # Step 1: password login
    r1 = session.post(
        "https://kite.zerodha.com/api/login",
        data={"user_id": ZERODHA_USER_ID, "password": ZERODHA_PASSWORD},
        timeout=30,
    )
    if r1.status_code != 200:
        raise RuntimeError(f"Kite login step 1 failed: {r1.status_code}")
    request_id = r1.json().get("data", {}).get("request_id", "")
    if not request_id:
        raise RuntimeError("Kite login: no request_id")

    # Step 2: TOTP
    time.sleep(1)
    totp = pyotp.TOTP(KITE_TOTP_SECRET).now()
    r2 = session.post(
        "https://kite.zerodha.com/api/twofa",
        data={
            "user_id": ZERODHA_USER_ID,
            "request_id": request_id,
            "twofa_value": totp,
            "twofa_type": "totp",
        },
        timeout=30,
        allow_redirects=True,
    )

    final_url = r2.url
    if "request_token=" not in final_url:
        # Try login_url redirect
        login_url = kite.login_url()
        r3 = session.get(login_url, allow_redirects=True, timeout=30)
        final_url = r3.url

    if "request_token=" not in final_url:
        raise RuntimeError(f"Kite TOTP: no request_token in {final_url[:100]}")

    request_token = final_url.split("request_token=")[1].split("&")[0]
    data = kite.generate_session(request_token, api_secret=KITE_API_SECRET)
    access_token = data.get("access_token", "")
    if not access_token:
        raise RuntimeError("Kite: no access_token from generate_session")
    kite.set_access_token(access_token)

    try:
        profile = kite.profile()
        log.info("Kite login OK as %s", profile.get("user_name", ZERODHA_USER_ID))
    except Exception:
        log.info("Kite login OK (profile fetch failed, continuing)")
    return kite


def _reload_token_from_file():
    """Reload access token from kite_token.json (gir.py keeps it fresh)."""
    import json
    try:
        with open("/home/globalbot/data/kite_token.json") as f:
            tok = json.load(f)
        return tok.get("access_token")
    except Exception as e:
        log.warning("token file reload failed: %s", e)
        return None

def _relogin_on_auth_error(kite, exc):
    """Called when an LTP/read fails with TokenException.
    Try cheaper recovery first (reload from disk), then full TOTP if needed."""
    msg = str(exc).lower()
    is_auth = ("api_key" in msg) or ("access_token" in msg) or ("token" in msg and "incorrect" in msg)
    if not is_auth:
        return False  # not an auth error, don't retry
    log.warning("auth error detected, attempting token reload from file")
    new_tok = _reload_token_from_file()
    if new_tok:
        try:
            kite.set_access_token(new_tok)
            kite.profile()  # verify it works
            log.info("token reload from file: SUCCESS")
            return True
        except Exception as e:
            log.warning("file-reload token also invalid: %s", e)
    log.warning("falling back to full TOTP re-login")
    try:
        new_kite = kite_login()
        # copy the new token onto the existing kite instance so callers keep their reference
        kite.set_access_token(new_kite.access_token if hasattr(new_kite, "access_token") else new_kite._access_token)
        log.info("TOTP re-login: SUCCESS")
        return True
    except Exception as e:
        log.exception("TOTP re-login failed: %s", e)
        return False



def build_instrument_map(kite: KiteConnect) -> dict:
    """Returns {(exchange, tradingsymbol): instrument_token}."""
    m = {}
    for exch in ("NSE", "NFO", "BFO", "BSE"):
        try:
            instruments = kite.instruments(exch)
            for ins in instruments:
                m[(exch, ins["tradingsymbol"])] = ins["instrument_token"]
        except Exception as e:
            log.warning("Failed to fetch instruments for %s: %s", exch, e)
    log.info("Built instrument map: %d entries", len(m))
    return m


# ============================================================
# Exit evaluation
# ============================================================
def parse_entry_ts(s: str) -> datetime:
    """Parse stored entry_ts. Handles both with and without timezone."""
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        dt = datetime.strptime(s[:19], "%Y-%m-%d %H:%M:%S")
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def is_fno_strategy(strategy: str) -> bool:
    return "FNO" in (strategy or "").upper()


def evaluate_trade(t: dict, ltp: float, kite: KiteConnect) -> None:
    """Decide whether to exit, ratchet trail, or do nothing."""
    trade_id = t["trade_id"]
    strategy = t["strategy"] or ""
    if (strategy or "").upper().startswith("PANEL"):
        # PANEL spec: fixed hard SL + per-trade time stop, NO trail (exit lab 2026-06-11)
        _hsl = t.get("sl_trigger") or 0
        if _hsl and ltp <= _hsl:
            _fire_exit(t, _hsl, "PANEL_HARD_SL", kite); return
        _tsd = t.get("time_stop_days") or 20
        if (t.get("days_held") or 0) >= _tsd:
            _fire_exit(t, ltp, "PANEL_TIME_STOP", kite); return
        return

    if (strategy or "").upper().startswith("GIR_EQ_FLOOR"):
        return  # GIR_EQ_FLOOR exits owned by gir_eq_floor.py — monitor must not trail these
    entry_price = t["entry_price"]
    qty = t["qty"]
    side = t["side"]
    peak = t.get("peak_price") or entry_price
    current_sl = t.get("current_sl")
    days_held = t.get("days_held") or 0

    # === FNO branch ===
    if is_fno_strategy(strategy):
        # Hard SL: premium dropped FNO_SL_PCT below entry
        hard_sl = entry_price * (1.0 - FNO_SL_PCT) if side == "BUY" else entry_price * (1.0 + FNO_SL_PCT)
        hit_sl = (side == "BUY" and ltp <= hard_sl) or (side == "SELL" and ltp >= hard_sl)
        if hit_sl:
            _fire_exit(t, ltp, "VIRTUAL_HARD_SL_FNO", kite)
            return
        if days_held >= FNO_MAX_HOLD_DAYS:
            _fire_exit(t, ltp, "VIRTUAL_TIME_STOP_FNO", kite)
            return
        return

    # === EQUITY / HUNTER branch (BUY-side only — equity bot never shorts) ===
    hard_sl = entry_price * (1.0 - EQ_INITIAL_SL_PCT)

    # Trail ratchet up
    if ltp > peak:
        new_peak = ltp
        candidate_trail_sl = new_peak * (1.0 - EQ_TRAIL_SL_PCT)
        # Never ratchet SL down — take max of existing current_sl and new candidate
        existing_sl = current_sl if current_sl is not None else hard_sl
        new_sl = max(existing_sl, candidate_trail_sl)
        pt.update_paper_trade_trail(trade_id, new_peak, new_sl)
        pt.record_event(
            module="paper_exit_monitor",
            event_type="TRAIL_UPDATE",
            symbol=t["symbol"],
            strategy_tag=strategy,
            ltp=ltp,
            price=new_sl,
            meta={"trade_id": trade_id, "new_peak": new_peak, "new_sl": new_sl,
                  "prev_peak": peak, "prev_sl": current_sl},
        )
        peak = new_peak
        current_sl = new_sl

    # Effective SL is the higher of hard floor and trailing
    effective_sl = max(hard_sl, current_sl if current_sl is not None else hard_sl)

    if ltp <= effective_sl:
        reason = "VIRTUAL_TRAIL_SL" if (current_sl and current_sl > hard_sl) else "VIRTUAL_HARD_SL_EQ"
        _fire_exit(t, ltp, reason, kite)
        return

    if days_held >= EQ_MAX_HOLD_DAYS:
        _fire_exit(t, ltp, "VIRTUAL_TIME_STOP_EQ", kite)
        return


def _fire_exit(t: dict, exit_price: float, reason: str, kite: KiteConnect) -> None:
    """Wrap paper_record_exit with logging + telemetry."""
    log.info("VIRTUAL EXIT %s %s qty=%s entry=%.2f exit=%.2f reason=%s",
             t["trade_id"], t["symbol"], t["qty"], t["entry_price"], exit_price, reason)
    try:
        pt.paper_record_exit(
            trade_id=t["trade_id"],
            exit_price=exit_price,
            exit_reason=reason,
        )
        # Telegram notification
        try:
            pnl = (exit_price - t["entry_price"]) * t["qty"]
            notify.notify_paper_exit(
                symbol=t["symbol"], qty=t["qty"],
                entry_price=t["entry_price"], exit_price=exit_price,
                pnl=pnl, reason=reason, strategy=t.get("strategy", "")
            )
        except Exception:
            pass
    except Exception as e:
        log.exception("paper_record_exit failed for %s: %s", t["trade_id"], e)
        pt.record_event(
            module="paper_exit_monitor",
            event_type="EXIT_FIRE_FAILED",
            symbol=t["symbol"],
            strategy_tag=t["strategy"],
            reason=reason,
            error=e,
        )


# ============================================================
# Daily days_held bump
# ============================================================
def bump_days_held_all_open() -> int:
    """Increment days_held for every OPEN trade based on entry_ts."""
    trades = pt.get_open_paper_trades()
    n = 0
    now = utc_now()
    for t in trades:
        try:
            ets = parse_entry_ts(t["entry_ts"])
            days = (now.date() - ets.date()).days
            pt.update_paper_trade_days_held(t["trade_id"], days)
            n += 1
        except Exception as e:
            log.warning("days_held bump failed for %s: %s", t.get("trade_id"), e)
    log.info("EOD days_held bumped for %d open trades", n)
    return n


# ============================================================
# Main loop
# ============================================================
def main():
    log.info("===== paper_exit_monitor starting =====")
    log.info("Config: EQ_INITIAL_SL=%s EQ_TRAIL_SL=%s EQ_MAX=%sd FNO_SL=%s FNO_MAX=%sd POLL=%ss",
             EQ_INITIAL_SL_PCT, EQ_TRAIL_SL_PCT, EQ_MAX_HOLD_DAYS,
             FNO_SL_PCT, FNO_MAX_HOLD_DAYS, POLL_SECONDS)

    try:
        kite = kite_login()
    except Exception as e:
        log.exception("Login failed at startup: %s", e)
        pt.record_event(module="paper_exit_monitor", event_type="LOGIN_FAIL", error=e)
        sys.exit(2)

    instr_map = build_instrument_map(kite)
    if not instr_map:
        log.error("Instrument map empty — refusing to start")
        sys.exit(3)

    last_eod_date = None

    while True:
        try:
            now = utc_now()

            # Once-per-day EOD bump (only after 10:05 UTC, once per date)
            if (now.hour > EOD_BUMP_HOUR_UTC or
                (now.hour == EOD_BUMP_HOUR_UTC and now.minute >= EOD_BUMP_MIN_UTC)):
                if last_eod_date != now.date():
                    bump_days_held_all_open()
                    last_eod_date = now.date()

            if not is_market_hours_utc(now):
                time.sleep(POLL_SECONDS)
                continue

            trades = pt.get_open_paper_trades()
            if not trades:
                time.sleep(POLL_SECONDS)
                continue

            # Resolve instrument tokens
            tokens_for_ltp = []
            by_kite_key = {}  # "EXCH:SYMBOL" -> trade
            for t in trades:
                key = (t["exchange"], t["symbol"])
                token = instr_map.get(key)
                if token is None:
                    pt.record_event(
                        module="paper_exit_monitor",
                        event_type="NO_INSTRUMENT_TOKEN",
                        symbol=t["symbol"],
                        strategy_tag=t["strategy"],
                        meta={"exchange": t["exchange"], "trade_id": t["trade_id"]},
                    )
                    continue
                kite_key = f'{t["exchange"]}:{t["symbol"]}'
                tokens_for_ltp.append(kite_key)
                by_kite_key[kite_key] = t

            if not tokens_for_ltp:
                time.sleep(POLL_SECONDS)
                continue

            try:
                ltp_resp = kite.ltp(tokens_for_ltp)
            except Exception as e:
                log.error("kite.ltp failed: %s", e)
                # Try re-login on auth errors
                if _relogin_on_auth_error(kite, e):
                    try:
                        ltp_resp = kite.ltp(tokens_for_ltp)
                        log.info("LTP fetch retry after relogin: SUCCESS")
                    except Exception as e2:
                        log.exception("LTP retry after relogin failed: %s", e2)
                        pt.record_event(module="paper_exit_monitor", event_type="LTP_FETCH_FAIL", error=e2)
                        time.sleep(POLL_SECONDS)
                        continue
                else:
                    pt.record_event(module="paper_exit_monitor", event_type="LTP_FETCH_FAIL", error=e)
                    time.sleep(POLL_SECONDS)
                    continue

            for kite_key, t in by_kite_key.items():
                resp = ltp_resp.get(kite_key)
                if not resp or "last_price" not in resp:
                    continue
                ltp = float(resp["last_price"])
                try:
                    evaluate_trade(t, ltp, kite)
                except Exception as e:
                    log.exception("evaluate_trade failed for %s: %s", t.get("trade_id"), e)
                    pt.record_event(
                        module="paper_exit_monitor",
                        event_type="EVALUATE_FAIL",
                        symbol=t.get("symbol"),
                        strategy_tag=t.get("strategy"),
                        error=e,
                    )

            log.info("heartbeat: %d open trades evaluated, polling", len(by_kite_key))
            time.sleep(POLL_SECONDS)

        except KeyboardInterrupt:
            log.info("KeyboardInterrupt — shutting down cleanly")
            break
        except Exception as e:
            log.exception("Main loop unhandled exception: %s", e)
            pt.record_event(module="paper_exit_monitor", event_type="LOOP_ERROR", error=e)
            time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()

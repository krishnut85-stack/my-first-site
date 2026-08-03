#!/usr/bin/env python3
"""paper_counterfactual.py - Phase 6A
Captures forward-price snapshots and running max/min for every paper trade.
Runs every 30 min via systemd timer (market hours and slightly after).
Read-only on Kite. Cannot place orders. Updates only cf_* columns in trades.db.
"""
import os, sys, json, sqlite3, logging
from datetime import datetime, timezone, timedelta
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv("/home/globalbot/.env")
except ImportError:
    pass

from kiteconnect import KiteConnect

TRADES_DB = "/home/globalbot/paper/trades.db"
TOKEN_FILE = "/home/globalbot/data/kite_token.json"
LOG_FILE = "/home/globalbot/paper/counterfactual.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("paper_cf")

CHECKPOINTS = [
    ("cf_1d_price",  timedelta(hours=23, minutes=30), timedelta(hours=24, minutes=30)),
    ("cf_3d_price",  timedelta(days=2, hours=23),     timedelta(days=3, hours=1)),
    ("cf_7d_price",  timedelta(days=6, hours=23),     timedelta(days=7, hours=1)),
    ("cf_30d_price", timedelta(days=29, hours=23),    timedelta(days=30, hours=1)),
]

def kite_login():
    with open(TOKEN_FILE) as f:
        tok = json.load(f)
    kite = KiteConnect(api_key=os.getenv("KITE_API_KEY"))
    kite.set_access_token(tok["access_token"])
    return kite

def _reload_token_or_relogin(kite, exc):
    """On TokenException: reload token from file, fall back to fresh TOTP."""
    import json
    msg = str(exc).lower()
    is_auth = ("api_key" in msg) or ("access_token" in msg) or ("token" in msg)
    if not is_auth:
        return False
    log.warning("auth error, reloading token from file")
    try:
        with open(TOKEN_FILE) as f:
            tok = json.load(f)
        kite.set_access_token(tok["access_token"])
        kite.profile()
        log.info("token reload from file: SUCCESS")
        return True
    except Exception as e:
        log.warning("file reload failed: %s, retrying TOTP", e)
    try:
        new_kite = kite_login()
        new_tok = new_kite.access_token if hasattr(new_kite, "access_token") else None
        if new_tok:
            kite.set_access_token(new_tok)
            log.info("token reload via login: SUCCESS")
            return True
    except Exception as e:
        log.exception("TOTP re-login failed: %s", e)
    return False


def parse_ts(s):
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        dt = datetime.strptime(s[:19], "%Y-%m-%d %H:%M:%S")
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt

def get_target_trades(conn, col_name, window_lo, window_hi):
    """Trades where entry_ts is in [now - window_hi, now - window_lo] AND col is NULL."""
    now = datetime.now(timezone.utc)
    lo = (now - window_hi).isoformat()
    hi = (now - window_lo).isoformat()
    cur = conn.cursor()
    cur.execute(f"""
        SELECT trade_id, symbol, exchange
        FROM paper_trades
        WHERE entry_ts BETWEEN ? AND ?
          AND {col_name} IS NULL
    """, (lo, hi))
    return cur.fetchall()

def update_cf_snapshot(conn, trade_id, col_name, price):
    cur = conn.cursor()
    cur.execute(f"UPDATE paper_trades SET {col_name} = ? WHERE trade_id = ?", (price, trade_id))
    conn.commit()

def update_max_favorable_adverse(conn, kite):
    """For all OPEN trades, track running max favorable + max adverse."""
    cur = conn.cursor()
    cur.execute("""
        SELECT trade_id, symbol, exchange, side, entry_price,
               cf_max_favorable, cf_max_adverse
        FROM paper_trades
        WHERE status = 'OPEN'
    """)
    rows = cur.fetchall()
    if not rows:
        return 0
    keys = [f"{r[2]}:{r[1]}" for r in rows]
    try:
        ltp_resp = kite.ltp(keys)
    except Exception as e:
        log.warning("ltp fetch failed: %s", e)
        if _reload_token_or_relogin(kite, e):
            try:
                ltp_resp = kite.ltp(keys)
                log.info("fav/adv ltp retry after relogin: SUCCESS")
            except Exception as e2:
                log.warning("fav/adv ltp retry failed: %s", e2)
                return 0
        else:
            return 0
    updated = 0
    for r in rows:
        trade_id, symbol, exch, side, entry, cur_fav, cur_adv = r
        key = f"{exch}:{symbol}"
        resp = ltp_resp.get(key)
        if not resp or "last_price" not in resp:
            continue
        ltp = float(resp["last_price"])
        if side == "BUY":
            move = ltp - entry
        else:
            move = entry - ltp
        new_fav = max(move, cur_fav if cur_fav is not None else move)
        new_adv = min(move, cur_adv if cur_adv is not None else move)
        cur.execute("UPDATE paper_trades SET cf_max_favorable=?, cf_max_adverse=? WHERE trade_id=?",
                    (new_fav, new_adv, trade_id))
        updated += 1
    conn.commit()
    return updated

def main():
    log.info("===== counterfactual pass start =====")
    try:
        kite = kite_login()
        log.info("kite login OK")
    except Exception as e:
        log.exception("login failed: %s", e)
        sys.exit(1)

    conn = sqlite3.connect(TRADES_DB)
    total_snaps = 0

    for col_name, w_lo, w_hi in CHECKPOINTS:
        trades = get_target_trades(conn, col_name, w_lo, w_hi)
        if not trades:
            continue
        log.info("checkpoint %s: %d trades to snapshot", col_name, len(trades))
        keys = [f"{exch}:{sym}" for _, sym, exch in trades]
        try:
            ltp_resp = kite.ltp(keys)
        except Exception as e:
            log.warning("ltp fetch failed for %s: %s", col_name, e)
            if _reload_token_or_relogin(kite, e):
                try:
                    ltp_resp = kite.ltp(keys)
                    log.info("ltp retry after relogin: SUCCESS")
                except Exception as e2:
                    log.warning("ltp retry failed: %s", e2)
                    continue
            else:
                continue
        for trade_id, symbol, exch in trades:
            key = f"{exch}:{symbol}"
            resp = ltp_resp.get(key)
            if not resp or "last_price" not in resp:
                log.warning("no ltp for %s", key)
                continue
            price = float(resp["last_price"])
            update_cf_snapshot(conn, trade_id, col_name, price)
            log.info("  %s %s @ %.2f -> %s", trade_id, symbol, price, col_name)
            total_snaps += 1

    fav_adv = update_max_favorable_adverse(conn, kite)
    log.info("===== pass done: %d snapshots, %d fav/adv updates =====", total_snaps, fav_adv)
    conn.close()

if __name__ == "__main__":
    main()

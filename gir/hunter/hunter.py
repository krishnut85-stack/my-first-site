#!/usr/bin/env python3
"""
GIR-HUNTER — Pre-breakout accumulation scanner for NSE equity.

Runs once daily after market close. For each stock in the equity universe:
  1. Pull last 90 daily candles from Kite
  2. Score against the 4-feature accumulation composite
  3. Rank top 20 by composite score
  4. Send Telegram alert with the watchlist
  5. Log every pick to paper_book.jsonl for 30-day expectancy measurement

Phase 2: LIVE — V209 5x5x5 active (5 slots × ₹8,000/slot × ₹40,000 total).
Real orders via Kite GTT-based SL since 2026-05-19. V217 docstring fix 2026-05-20.

Author: GIR-HUNTER v0.1   |   Date: May 16 2026
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time
import traceback
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

import pandas as pd

# ============================================================================
# PAPER MODE (Phase 2A 2026-05-21) — every kite.place_order / place_gtt /
# modify_gtt routes through paper_trader.py when PAPER_MODE=True.
# If paper_trader import fails, PAPER_MODE defaults to False and a loud
# warning prints. Bot then behaves as before.
# ============================================================================
sys.path.insert(0, '/home/globalbot/paper')
try:
    from paper_trader import (
        PAPER_MODE,
        record_event,
        paper_place_order,
        paper_place_gtt,
        paper_modify_gtt,
        paper_cancel_gtt,
        paper_record_exit,
        paper_gemini_call,
    )
except Exception as _paper_e:
    PAPER_MODE = False
    print(f"[PAPER_TRADER IMPORT FAILED] {_paper_e} — bot in LIVE mode!", file=sys.stderr)
import requests
from dotenv import load_dotenv
from kiteconnect import KiteConnect

# local import — scorer.py must be in the same directory
sys.path.insert(0, str(Path(__file__).parent))
from scorer import score_symbol, HunterScore  # noqa: E402


# ============================================================================
# CONFIG
# ============================================================================

HUNTER_DIR        = Path("/home/globalbot/hunter")
LOG_DIR           = HUNTER_DIR / "logs"
STATE_DIR         = HUNTER_DIR / "state"
PAPER_BOOK        = STATE_DIR / "paper_book.jsonl"
WATCHLIST_TODAY   = STATE_DIR / "watchlist_today.json"

ENV_FILE          = "/home/globalbot/.env"
KITE_TOKEN_FILE   = Path("/home/globalbot/data/kite_token.json")
TRENDLYNE_CSV     = Path("/home/globalbot/trendlyne_data/trendlyne_all_stocks.csv")

HISTORICAL_DAYS   = 90
TOP_N             = 20
MIN_PRICE         = 50.0       # avoid penny stocks
MIN_AVG_TURNOVER  = 20_000_000 # ₹2cr daily turnover floor
KITE_RATE_SLEEP   = 0.35       # ~3 req/sec, safe under Kite's 3/sec historical limit
NIFTY_SYMBOL      = "NIFTY 50"
NIFTY_TOKEN       = 256265     # standard Kite token for NIFTY 50 index

# Telegram
TG_CHANNEL_TAG    = "GIR-HUNTER"


# ============================================================================
# LOGGING
# ============================================================================

def _setup_logging() -> logging.Logger:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOG_DIR / f"hunter_{datetime.now().strftime('%Y%m%d')}.log"
    logger = logging.getLogger("hunter")
    logger.setLevel(logging.INFO)
    fmt = logging.Formatter("%(asctime)s %(levelname)-7s %(message)s")
    fh = logging.FileHandler(log_file)
    fh.setFormatter(fmt)
    sh = logging.StreamHandler()
    sh.setFormatter(fmt)
    if not logger.handlers:
        logger.addHandler(fh)
        logger.addHandler(sh)
    return logger


log = _setup_logging()


# ============================================================================
# CREDENTIAL LOADING — mirrors gir.py exactly
# ============================================================================

def load_kite() -> KiteConnect:
    load_dotenv(ENV_FILE)
    api_key = os.getenv("KITE_API_KEY")
    if not api_key:
        raise RuntimeError("KITE_API_KEY missing in .env")
    if not KITE_TOKEN_FILE.exists():
        raise RuntimeError(f"Kite token file not found: {KITE_TOKEN_FILE}")
    with open(KITE_TOKEN_FILE) as f:
        token_data = json.load(f)
    access_token = token_data.get("access_token", "")
    if not access_token:
        raise RuntimeError("access_token empty in kite_token.json")
    kite = KiteConnect(api_key=api_key)
    kite.set_access_token(access_token)
    return kite


def load_telegram() -> tuple[str, str]:
    load_dotenv(ENV_FILE)
    token = os.getenv("TELEGRAM_BOT_TOKEN", "")
    chat  = os.getenv("TELEGRAM_CHAT_ID", "")
    if not token or not chat:
        log.warning("Telegram creds missing — alerts will be skipped")
    return token, chat


# ============================================================================
# UNIVERSE LOADING
# ============================================================================

# V219: cached Trendlyne quality data for current universe (populated by load_universe)
# Keyed by Symbol -> dict of row fields (DVM_M, Promoter_Pledge, etc.)
_TRENDLYNE_QUALITY: dict = {}


def load_universe() -> list[str]:
    """
    Use Trendlyne CSV as the universe source (same as gir.py).
    Falls back to all Kite NSE EQ instruments if Trendlyne file missing.
    """
    if TRENDLYNE_CSV.exists():
        try:
            df = pd.read_csv(TRENDLYNE_CSV)
            # Trendlyne CSV typically has 'NSE Code' or 'symbol' column
            for col in ["NSE Code", "nse_code", "symbol", "Symbol", "tradingsymbol"]:
                if col in df.columns:
                    syms = df[col].dropna().astype(str).str.strip().str.upper().tolist()
                    syms = [s for s in syms if s and s != "NAN"]
                    # V219: also cache full row data keyed by Symbol for quality scoring
                    global _TRENDLYNE_QUALITY
                    _TRENDLYNE_QUALITY = {}
                    try:
                        for _idx, _row in df.iterrows():
                            _sym_val = _row.get(col)
                            if _sym_val is None:
                                continue
                            _sym_key = str(_sym_val).strip().upper()
                            if not _sym_key or _sym_key == "NAN":
                                continue
                            _TRENDLYNE_QUALITY[_sym_key] = _row.to_dict()
                        log.info(f"V219: cached quality data for {len(_TRENDLYNE_QUALITY)} symbols")
                    except Exception as _qe:
                        log.warning(f"V219: quality cache population failed: {_qe}")
                        _TRENDLYNE_QUALITY = {}
                    log.info(f"Loaded {len(syms)} symbols from Trendlyne CSV")
                    return syms
            log.warning(f"Trendlyne CSV has no recognized symbol column: {df.columns.tolist()}")
        except Exception as e:
            log.warning(f"Trendlyne CSV read failed: {e}")
    log.info("Falling back to all Kite NSE instruments")
    return []  # caller will fall back to kite.instruments()


def build_symbol_token_map(kite: KiteConnect, symbols: list[str]) -> dict[str, int]:
    """Map tradingsymbol -> instrument_token for EQ segment only."""
    instruments = kite.instruments("NSE")
    log.info(f"Fetched {len(instruments)} NSE instruments from Kite")
    eq_map = {
        i["tradingsymbol"]: i["instrument_token"]
        for i in instruments
        if i.get("segment") == "NSE" and i.get("instrument_type") == "EQ"
    }
    log.info(f"Filtered to {len(eq_map)} NSE EQ instruments")
    if not symbols:
        return eq_map
    matched = {s: eq_map[s] for s in symbols if s in eq_map}
    log.info(f"Matched {len(matched)} of {len(symbols)} universe symbols to Kite tokens")
    return matched


# ============================================================================
# KITE HISTORICAL FETCHER (with retry + rate-limit)
# ============================================================================

def fetch_history(
    kite: KiteConnect, token: int, days: int = HISTORICAL_DAYS, retries: int = 2
) -> Optional[pd.DataFrame]:
    to_d = datetime.now().date()
    from_d = to_d - timedelta(days=days)
    for attempt in range(retries + 1):
        try:
            data = kite.historical_data(token, from_d, to_d, "day")
            if not data:
                return None
            df = pd.DataFrame(data)
            df["date"] = pd.to_datetime(df["date"])
            df = df.set_index("date").sort_index()
            return df[["open", "high", "low", "close", "volume"]]
        except Exception as e:
            if attempt < retries:
                time.sleep(1.0 * (attempt + 1))
                continue
            log.debug(f"history fetch failed for token {token}: {e}")
            return None
    return None


# ============================================================================
# CORE SCAN LOOP
# ============================================================================

def scan(kite: KiteConnect, sym_tok: dict[str, int]) -> list[HunterScore]:
    log.info(f"Fetching Nifty 50 history for RS baseline...")
    nifty_df = fetch_history(kite, NIFTY_TOKEN, days=HISTORICAL_DAYS)
    if nifty_df is None or len(nifty_df) < 50:
        raise RuntimeError("Nifty 50 history fetch failed — cannot compute RS")
    log.info(f"Nifty 50 history: {len(nifty_df)} candles, last close {nifty_df['close'].iloc[-1]:.2f}")

    scores: list[HunterScore] = []
    total = len(sym_tok)
    log.info(f"Scanning {total} symbols (rate-limit {KITE_RATE_SLEEP}s between calls)")
    log.info(f"Estimated runtime: {total * KITE_RATE_SLEEP / 60:.1f} minutes")

    skipped_price = 0
    skipped_turnover = 0
    skipped_history = 0
    skipped_error = 0
    scored = 0
    start = time.time()

    for idx, (sym, tok) in enumerate(sym_tok.items(), 1):
        if idx % 100 == 0:
            elapsed = time.time() - start
            eta = (elapsed / idx) * (total - idx)
            log.info(
                f"Progress: {idx}/{total} ({100*idx/total:.0f}%)  "
                f"scored={scored} skipped_hist={skipped_history} "
                f"skipped_price={skipped_price} skipped_turnover={skipped_turnover} "
                f"errors={skipped_error}  ETA {eta/60:.1f}min"
            )

        try:
            df = fetch_history(kite, tok)
            time.sleep(KITE_RATE_SLEEP)
            if df is None or len(df) < 50:
                skipped_history += 1
                continue
            last_close = float(df["close"].iloc[-1])
            if last_close < MIN_PRICE:
                skipped_price += 1
                continue
            avg_turnover = float((df["close"] * df["volume"]).tail(20).mean())
            if avg_turnover < MIN_AVG_TURNOVER:
                skipped_turnover += 1
                continue
            # V219: look up quality data and pass to scorer
            _quality = _TRENDLYNE_QUALITY.get(sym)
            score = score_symbol(sym, df, nifty_df, trendlyne_quality=_quality)
            if score is not None:
                # v1.2 BUG#1 FIX: attach instrument_token for downstream consumers
                try:
                    score.__dict__['instrument_token'] = tok
                except Exception:
                    pass
                scores.append(score)
                scored += 1
        except Exception as e:
            skipped_error += 1
            log.debug(f"{sym} error: {e}")

    elapsed = time.time() - start
    log.info(
        f"Scan complete in {elapsed/60:.1f}min — "
        f"scored={scored}  skipped_hist={skipped_history}  "
        f"skipped_price={skipped_price}  skipped_turnover={skipped_turnover}  "
        f"errors={skipped_error}"
    )
    return scores


# ============================================================================
# OUTPUT — Telegram + paper book
# ============================================================================

def format_watchlist(scores: list[HunterScore], top_n: int = TOP_N) -> str:
    top = sorted(scores, key=lambda s: s.composite, reverse=True)[:top_n]
    ts = datetime.now().strftime("%a %d-%b %H:%M IST")
    lines = [
        f"🎯 *{TG_CHANNEL_TAG} — Pre-breakout watchlist*",
        f"_{ts} • scanned {len(scores)} • top {top_n}_",
        "",
        "`Rank  Symbol         Score  BB   RS   Vol  H52   Close`",
    ]
    for i, s in enumerate(top, 1):
        lines.append(
            f"`{i:>3}.  {s.symbol:<13s} "
            f"{s.composite:5.1f}  "
            f"{s.bb_squeeze:4.0f} {s.rs_vs_nifty:4.0f} "
            f"{s.vol_pickup:4.0f} {s.dist_52w_hi:4.0f}  "
            f"₹{s.last_close:>7.2f}`"
        )
    lines.append("")
    lines.append("_Legend: BB=squeeze RS=vs-Nifty Vol=pickup H52=dist-from-high_")
    lines.append("_Shadow mode — no real orders. Watch for next-5-day moves._")
    return "\n".join(lines)


def send_telegram(msg: str) -> None:
    token, chat = load_telegram()
    if not token or not chat:
        log.warning("Telegram skipped — credentials missing")
        return
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    try:
        r = requests.post(
            url,
            json={"chat_id": chat, "text": msg, "parse_mode": "Markdown"},
            timeout=10,
        )
        if r.status_code == 200:
            log.info("Telegram alert sent OK")
        else:
            log.warning(f"Telegram non-200: {r.status_code} {r.text[:200]}")
    except Exception as e:
        log.error(f"Telegram send failed: {e}")


def write_paper_book(scores: list[HunterScore], top_n: int = TOP_N) -> None:
    """Append today's top-N picks to paper_book.jsonl for 30-day measurement."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    top = sorted(scores, key=lambda s: s.composite, reverse=True)[:top_n]
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    with open(PAPER_BOOK, "a") as f:
        for rank, s in enumerate(top, 1):
            row = {
                "scan_date": today,
                "rank": rank,
                **s.to_dict(),
            }
            f.write(json.dumps(row) + "\n")
    log.info(f"Paper book: appended {len(top)} picks")

    # also write watchlist_today.json for downstream consumers
    payload = {
        "scan_date": today,
        "scan_ts_utc": datetime.now(timezone.utc).isoformat(),
        "top": [s.to_dict() for s in top],
    }
    with open(WATCHLIST_TODAY, "w") as f:
        json.dump(payload, f, indent=2)
    log.info(f"Watchlist today: {WATCHLIST_TODAY}")


# ============================================================================
# MAIN
# ============================================================================

def main() -> int:
    log.info("=" * 60)
    log.info("GIR-HUNTER scan starting")
    log.info("=" * 60)

    try:
        kite = load_kite()
        log.info("Kite authenticated OK")
    except Exception as e:
        log.error(f"Kite auth failed: {e}")
        return 2

    universe_syms = load_universe()
    try:
        sym_tok = build_symbol_token_map(kite, universe_syms)
    except Exception as e:
        log.error(f"Universe build failed: {e}")
        return 3

    if not sym_tok:
        log.error("Empty universe — aborting")
        return 4

    try:
        scores = scan(kite, sym_tok)
    except Exception as e:
        log.error(f"Scan crashed: {e}\n{traceback.format_exc()}")
        return 5

    if not scores:
        log.warning("Zero scores — nothing to publish")
        return 0

    write_paper_book(scores)
    msg = format_watchlist(scores)
    log.info("Watchlist preview:\n" + msg)
    send_telegram(msg)
    log.info("GIR-HUNTER run complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())

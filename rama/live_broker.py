"""SEBI-compliant live order execution for Rama.

This is the ONLY module that can place a real order. It mirrors PaperBroker's
surface but routes through Kite Connect — and it enforces the guardrails from
SEBI's Feb-2025 retail-algo framework *in code* so a personal (unregistered)
algo stays compliant:

  1. RATE LIMIT  — a token-bucket capped at config.MAX_ORDERS_PER_SEC, which is
     held UNDER SEBI's 10-orders-per-second registration threshold. (Rama's
     strategy places a few orders a month, so this is a safety ceiling, not a
     speed target — see the note in config.py: order speed is not an edge.)
  2. KILL SWITCH — if config.KILL_SWITCH_FILE exists, every order is refused.
  3. AUDIT LOG   — every attempt (placed / dry-run / rejected) is appended to
     config.ORDER_LOG as JSON lines.
  4. SAFETY LATCHES — nothing is actually sent unless ALL of these are true:
        LIVE_TRADING is on, LIVE_DRY_RUN is off, an ALGO_ID is set, and a real
        Kite client was provided. Otherwise the order is logged as DRY_RUN.

Design note: the Kite client is injected, so this module is fully unit-testable
without any keys or network (tests pass a fake client + a fake clock).
"""

import json
import time
from dataclasses import dataclass

from . import config


class RateLimiter:
    """Token bucket. Refills at `rate` tokens/sec up to `capacity`. `clock` is
    injectable so tests can drive time deterministically."""

    def __init__(self, rate: float, capacity: float | None = None, clock=time.monotonic):
        self.rate = float(rate)
        self.capacity = float(capacity if capacity is not None else rate)
        self.tokens = self.capacity
        self.clock = clock
        self._last = clock()

    def _refill(self) -> None:
        now = self.clock()
        elapsed = max(0.0, now - self._last)
        self.tokens = min(self.capacity, self.tokens + elapsed * self.rate)
        self._last = now

    def try_acquire(self) -> bool:
        """Take one token if available; return False immediately if not."""
        self._refill()
        if self.tokens >= 1.0:
            self.tokens -= 1.0
            return True
        return False

    def acquire(self, sleep=time.sleep) -> None:
        """Block until a token is free (respects the OPS cap under real time)."""
        while not self.try_acquire():
            sleep(1.0 / self.rate)


def kill_switch_engaged() -> bool:
    return config.KILL_SWITCH_FILE.exists()


def _log_order(record: dict) -> None:
    try:
        config.ORDER_LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(config.ORDER_LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps(record) + "\n")
    except Exception:  # noqa: BLE001 — logging must never break trading
        pass


@dataclass
class OrderResult:
    symbol: str
    side: str
    qty: int
    status: str            # PLACED | DRY_RUN | REJECTED
    reason: str = ""
    order_id: str | None = None


class LiveBroker:
    """Places real orders via Kite Connect, under the SEBI guardrails.

    kite : an object exposing .place_order(**kwargs) (e.g. KiteConnect). Pass
           None to force dry-run (used in paper/testing). The rate limiter and
           kill switch apply regardless.
    """

    def __init__(self, kite=None, rate_limiter: RateLimiter | None = None):
        self.kite = kite
        self.limiter = rate_limiter or RateLimiter(config.MAX_ORDERS_PER_SEC)

    def _would_send(self) -> tuple[bool, str]:
        """Decide whether this is a REAL send or a logged dry-run, with reason."""
        if not config.LIVE_TRADING:
            return False, "LIVE_TRADING off"
        if config.LIVE_DRY_RUN:
            return False, "LIVE_DRY_RUN latch on"
        if not config.ALGO_ID:
            return False, "no ALGO_ID (SEBI: order must carry your broker Algo-ID)"
        if self.kite is None:
            return False, "no Kite client"
        return True, "live"

    def place(self, symbol: str, qty: int, side: str, reason: str = "") -> OrderResult:
        """Place (or dry-run) a single order. side is 'BUY' or 'SELL'."""
        side = side.upper()

        # 1. kill switch — highest priority, always wins
        if kill_switch_engaged():
            res = OrderResult(symbol, side, qty, "REJECTED", "KILL SWITCH engaged")
            _log_order(_rec(res, reason))
            return res

        if qty <= 0:
            res = OrderResult(symbol, side, qty, "REJECTED", "qty <= 0")
            _log_order(_rec(res, reason))
            return res

        # 2. OPS rate limit — block until a token frees (stays under SEBI cap)
        self.limiter.acquire()

        send, why = self._would_send()
        if not send:
            res = OrderResult(symbol, side, qty, "DRY_RUN", why)
            _log_order(_rec(res, reason))
            return res

        # 3. real send through the broker, tagged with the Algo-ID
        try:
            order_id = self.kite.place_order(
                variety="regular",
                exchange=config.LIVE_EXCHANGE,
                tradingsymbol=symbol,
                transaction_type=side,
                quantity=int(qty),
                product=config.LIVE_PRODUCT,
                order_type=config.LIVE_ORDER_TYPE,
                tag=config.ALGO_ID,
            )
            res = OrderResult(symbol, side, qty, "PLACED", "sent", str(order_id))
        except Exception as exc:  # noqa: BLE001
            res = OrderResult(symbol, side, qty, "REJECTED", f"broker error: {exc}")
        _log_order(_rec(res, reason))
        return res


def _rec(res: OrderResult, reason: str) -> dict:
    # No wall-clock dependency in the return value; timestamp best-effort only.
    rec = {
        "symbol": res.symbol, "side": res.side, "qty": res.qty,
        "status": res.status, "detail": res.reason, "strategy_reason": reason,
        "order_id": res.order_id, "algo_id": config.ALGO_ID or None,
        "exchange": config.LIVE_EXCHANGE, "product": config.LIVE_PRODUCT,
    }
    try:
        from datetime import datetime
        from .data_loader import IST
        rec["ts"] = datetime.now(IST).isoformat(timespec="seconds")
    except Exception:  # noqa: BLE001
        pass
    return rec

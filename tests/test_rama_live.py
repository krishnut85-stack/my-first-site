"""Tests for Rama's SEBI-compliant live execution layer. All offline: the Kite
client and the clock are faked, so nothing hits a network or needs keys."""

from rama import config
from rama.live_broker import LiveBroker, RateLimiter, kill_switch_engaged


# --- OPS rate limiter (the SEBI 10-orders/sec guardrail) --------------------

def test_rate_limiter_throttles_within_a_second():
    now = [0.0]
    rl = RateLimiter(rate=8, capacity=8, clock=lambda: now[0])
    # 8 tokens available immediately, 9th in the same instant is refused.
    assert sum(rl.try_acquire() for _ in range(8)) == 8
    assert rl.try_acquire() is False
    # after a full second the bucket refills to capacity.
    now[0] += 1.0
    assert rl.try_acquire() is True


def test_rate_limiter_partial_refill():
    now = [0.0]
    rl = RateLimiter(rate=10, capacity=10, clock=lambda: now[0])
    for _ in range(10):
        rl.try_acquire()
    assert rl.try_acquire() is False
    now[0] += 0.5           # half a second -> 5 tokens back at 10/sec
    assert sum(rl.try_acquire() for _ in range(5)) == 5
    assert rl.try_acquire() is False


# --- kill switch ------------------------------------------------------------

def test_kill_switch(tmp_path, monkeypatch):
    ks = tmp_path / "KILL_SWITCH"
    monkeypatch.setattr(config, "KILL_SWITCH_FILE", ks)
    monkeypatch.setattr(config, "ORDER_LOG", tmp_path / "orders.jsonl")
    assert kill_switch_engaged() is False
    ks.write_text("halt")
    assert kill_switch_engaged() is True
    br = LiveBroker(kite=None, rate_limiter=RateLimiter(1000))
    res = br.place("KEI", 10, "BUY")
    assert res.status == "REJECTED" and "KILL SWITCH" in res.reason


# --- safety latches: nothing sends unless everything lines up ---------------

def _fast_broker(**_):
    return LiveBroker(kite=None, rate_limiter=RateLimiter(1000))


def test_dry_run_when_live_off(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "ORDER_LOG", tmp_path / "o.jsonl")
    monkeypatch.setattr(config, "KILL_SWITCH_FILE", tmp_path / "none")
    monkeypatch.setattr(config, "LIVE_TRADING", False)
    res = _fast_broker().place("KEI", 5, "BUY")
    assert res.status == "DRY_RUN" and "LIVE_TRADING off" in res.reason


def test_dry_run_latch_and_missing_algo_id(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "ORDER_LOG", tmp_path / "o.jsonl")
    monkeypatch.setattr(config, "KILL_SWITCH_FILE", tmp_path / "none")
    monkeypatch.setattr(config, "LIVE_TRADING", True)
    monkeypatch.setattr(config, "LIVE_DRY_RUN", True)
    assert _fast_broker().place("KEI", 5, "BUY").status == "DRY_RUN"
    # even with the latch off, a missing Algo-ID must block a real send (SEBI).
    monkeypatch.setattr(config, "LIVE_DRY_RUN", False)
    monkeypatch.setattr(config, "ALGO_ID", "")
    res = _fast_broker().place("KEI", 5, "BUY")
    assert res.status == "DRY_RUN" and "ALGO_ID" in res.reason


def test_real_send_tags_algo_id(tmp_path, monkeypatch):
    class FakeKite:
        def __init__(self):
            self.orders = []
        def place_order(self, **kw):
            self.orders.append(kw)
            return "OID123"

    monkeypatch.setattr(config, "ORDER_LOG", tmp_path / "o.jsonl")
    monkeypatch.setattr(config, "KILL_SWITCH_FILE", tmp_path / "none")
    monkeypatch.setattr(config, "LIVE_TRADING", True)
    monkeypatch.setattr(config, "LIVE_DRY_RUN", False)
    monkeypatch.setattr(config, "ALGO_ID", "RAMA-ALGO-1")
    fk = FakeKite()
    br = LiveBroker(kite=fk, rate_limiter=RateLimiter(1000))
    res = br.place("KEI", 7, "BUY", reason="entry")
    assert res.status == "PLACED" and res.order_id == "OID123"
    o = fk.orders[0]
    assert o["tradingsymbol"] == "KEI"
    assert o["transaction_type"] == "BUY"
    assert o["quantity"] == 7
    assert o["tag"] == "RAMA-ALGO-1"       # SEBI: order carries the Algo-ID


def test_rejects_nonpositive_qty(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "ORDER_LOG", tmp_path / "o.jsonl")
    monkeypatch.setattr(config, "KILL_SWITCH_FILE", tmp_path / "none")
    assert _fast_broker().place("KEI", 0, "BUY").status == "REJECTED"


# --- engine routes entries through the live broker (dry-run) ----------------

def test_engine_routes_orders_when_live(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "USE_KITE_DATA", False)     # synthetic prices
    monkeypatch.setattr(config, "LIVE_TRADING", True)       # turn live routing on
    monkeypatch.setattr(config, "LIVE_DRY_RUN", True)       # but keep the latch on
    monkeypatch.setattr(config, "PORTFOLIO_JSON", tmp_path / "pf.json")
    monkeypatch.setattr(config, "ORDER_LOG", tmp_path / "o.jsonl")
    monkeypatch.setattr(config, "KILL_SWITCH_FILE", tmp_path / "none")
    from rama.engine import run_paper_session
    result = run_paper_session(verbose=False)
    assert not result.get("aborted")
    orders = result["live_orders"]
    assert orders, "entries should have been routed to the live broker"
    # latch is on -> everything is a logged DRY_RUN, nothing actually sent
    assert all(o.status == "DRY_RUN" for o in orders)
    # the paper portfolio still recorded the entries (source of truth)
    assert result["entries"]
    # and the audit trail was written
    assert (tmp_path / "o.jsonl").exists()

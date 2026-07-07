"""
trade_recorder.py — GIR Decision & Order Tap (Phase 1 of Replay Harness)

Single responsibility: capture EVERYTHING the bot does, never block it.

Captures three streams to data/*.jsonl:
  1. decisions_YYYYMMDD.jsonl  — every ExpertPanel evaluate_equity/evaluate_fno call
  2. orders_YYYYMMDD.jsonl     — every kite.place_order() call (success or fail)
  3. gtts_YYYYMMDD.jsonl       — every kite.place_gtt() call (success or fail)

Design rules (non-negotiable):
  - Recorder failures NEVER raise to caller. try/except around every disk op.
  - Recorder NEVER mutates inputs. Only reads.
  - Recorder NEVER calls Kite. Only observes.
  - Recorder is OFF by default. Must be explicitly install()ed.
  - install() is idempotent. Calling twice is a no-op.

Activation (one line in gir.py):
    from trade_recorder import TradeRecorder
    TradeRecorder.install(KiteSession.kite())   # call once after login

Deactivation (if anything goes wrong):
    TradeRecorder.uninstall()
    # bot returns to baseline behaviour instantly
"""

import json
import hashlib
import threading
import time
import traceback
from datetime import datetime
from pathlib import Path

# Match gir.py
DATA_DIR = Path("/home/globalbot/data")
DATA_DIR.mkdir(parents=True, exist_ok=True)


def _now_iso():
    # Same format gir.py uses (now_ist().isoformat())
    try:
        from gir import now_ist
        return now_ist().isoformat()
    except Exception:
        return datetime.now().isoformat()


def _today_str():
    try:
        from gir import today_ist
        return today_ist().strftime("%Y%m%d")
    except Exception:
        return datetime.now().strftime("%Y%m%d")


def _safe_json_default(o):
    """Best-effort serializer for kwargs containing kite objects, datetimes, etc."""
    try:
        if hasattr(o, "isoformat"):
            return o.isoformat()
        if hasattr(o, "__dict__"):
            return f"<{type(o).__name__}>"
        return str(o)
    except Exception:
        return "<unserializable>"


def _hash_payload(obj):
    """Stable hash of a dict for replay-equality checks."""
    try:
        s = json.dumps(obj, sort_keys=True, default=_safe_json_default)
        return hashlib.sha1(s.encode()).hexdigest()[:16]
    except Exception:
        return "hash_failed"


_write_lock = threading.Lock()


def _append_jsonl(filename_stem, row):
    """
    Append one JSON line to data/<stem>_YYYYMMDD.jsonl.
    Thread-safe. Never raises.
    """
    try:
        path = DATA_DIR / f"{filename_stem}_{_today_str()}.jsonl"
        with _write_lock:
            with open(path, "a") as f:
                f.write(json.dumps(row, default=_safe_json_default) + "\n")
    except Exception:
        # Recorder failures are silent by design.
        # If we logged here, a broken disk would spam logs and slow the bot.
        pass


# ═══════════════════════════════════════════════════════════════════════════════
#  TradeRecorder — main interface
# ═══════════════════════════════════════════════════════════════════════════════

class TradeRecorder:
    _installed = False
    _orig_place_order = None
    _orig_place_gtt = None
    _kite_ref = None

    # ─── Decision recording (called from ExpertPanel) ─────────────────────────

    @staticmethod
    def record_decision(kind, result, scout_data, extras=None):
        """
        Called from ExpertPanel.evaluate_equity / evaluate_fno.
        Captures FULL inputs so replay can re-run with identical state.

        kind:       "EQUITY" or "FNO"
        result:     dict from evaluate_*  (output)
        scout_data: dict passed into evaluate_*  (input)
        extras:     optional dict with snapshot of non-deterministic inputs:
                    {"dvm": int, "hist_tail_close": [..], "tech_inputs": {...}}
        """
        try:
            row = {
                "ts": _now_iso(),
                "kind": kind,
                "schema": "decision_v1",

                # output
                "out_total": result.get("total"),
                "out_threshold": result.get("threshold"),
                "out_allow": result.get("allow"),
                "out_veto": result.get("veto"),
                "out_components": {
                    "news": result.get("news"),
                    "fundamental": result.get("fundamental"),
                    "oi": result.get("oi"),
                    "technical": result.get("technical"),
                    "sector": result.get("sector"),
                    "history": result.get("history"),
                    "option": result.get("option"),
                },

                # input — EVERYTHING needed to re-run
                "in_symbol": result.get("symbol"),
                "in_direction": result.get("direction"),
                "in_scout_data": scout_data or {},
                "in_extras": extras or {},

                # hash of input — replay uses this to detect "same input, different output"
                "input_hash": _hash_payload({
                    "symbol": result.get("symbol"),
                    "direction": result.get("direction"),
                    "scout": scout_data or {},
                    "extras": extras or {},
                }),
            }
            _append_jsonl("decisions", row)
        except Exception:
            pass

    # ─── Order tap (monkey-patches kite.place_order) ──────────────────────────

    @classmethod
    def install(cls, kite):
        """
        Wrap kite.place_order and kite.place_gtt with recording proxies.
        Idempotent: calling twice does nothing the second time.
        Order placement still flows through the original method.
        Recording happens AFTER the call — failures in recording never affect order.
        """
        if cls._installed:
            return False
        if kite is None:
            return False

        cls._kite_ref = kite
        cls._orig_place_order = kite.place_order
        cls._orig_place_gtt = kite.place_gtt

        def wrapped_place_order(*args, **kwargs):
            t0 = time.time()
            order_id = None
            err = None
            try:
                order_id = cls._orig_place_order(*args, **kwargs)
                return order_id
            except Exception as e:
                err = f"{type(e).__name__}: {e}"
                raise
            finally:
                try:
                    row = {
                        "ts": _now_iso(),
                        "schema": "order_v1",
                        "fn": "place_order",
                        "args": list(args) if args else [],
                        "kwargs": dict(kwargs) if kwargs else {},
                        "order_id": order_id,
                        "error": err,
                        "latency_ms": int((time.time() - t0) * 1000),
                        "stack": _short_caller_stack(),
                    }
                    _append_jsonl("orders", row)
                except Exception:
                    pass

        def wrapped_place_gtt(*args, **kwargs):
            t0 = time.time()
            gtt_id = None
            err = None
            try:
                gtt_id = cls._orig_place_gtt(*args, **kwargs)
                return gtt_id
            except Exception as e:
                err = f"{type(e).__name__}: {e}"
                raise
            finally:
                try:
                    row = {
                        "ts": _now_iso(),
                        "schema": "gtt_v1",
                        "fn": "place_gtt",
                        "args": list(args) if args else [],
                        "kwargs": dict(kwargs) if kwargs else {},
                        "gtt_id": gtt_id,
                        "error": err,
                        "latency_ms": int((time.time() - t0) * 1000),
                        "stack": _short_caller_stack(),
                    }
                    _append_jsonl("gtts", row)
                except Exception:
                    pass

        kite.place_order = wrapped_place_order
        kite.place_gtt = wrapped_place_gtt
        cls._installed = True
        return True

    @classmethod
    def uninstall(cls):
        """
        Restore original kite methods. Use this if anything goes wrong.
        Bot returns to pre-recorder behaviour instantly.
        """
        if not cls._installed:
            return False
        try:
            if cls._kite_ref is not None and cls._orig_place_order is not None:
                cls._kite_ref.place_order = cls._orig_place_order
            if cls._kite_ref is not None and cls._orig_place_gtt is not None:
                cls._kite_ref.place_gtt = cls._orig_place_gtt
        finally:
            cls._installed = False
            cls._orig_place_order = None
            cls._orig_place_gtt = None
            cls._kite_ref = None
        return True


def _short_caller_stack(skip=3, depth=4):
    """
    Capture a 4-frame trim of the caller stack so replay knows WHICH
    place_order site fired (we have 12 of them in gir.py).
    Returns ["file:line:func", ...].
    """
    try:
        frames = traceback.extract_stack()
        # Drop the last `skip` frames (this fn, the wrapper, the finally).
        useful = frames[:-skip][-depth:]
        return [f"{Path(f.filename).name}:{f.lineno}:{f.name}" for f in useful]
    except Exception:
        return []

"""regime_monitor_equity.py — PATCH_V105_REGIME_EQUITY"""
from __future__ import annotations
import json
from pathlib import Path
from datetime import datetime

ENTRY_SCORES_FILE = Path("/home/globalbot/equity_entry_scores.json")
LAST_REGIME_CHECK_FILE = Path("/home/globalbot/equity_regime_last_check.json")

SCORE_FLIP_DELTA = -20
SCORE_DEGRADE_DELTA = -10
NIFTY_STRONG_BEARISH_PCT = -1.0
GRACE_MINUTES = 30
CHECK_INTERVAL_MIN = 5


class EquityRegimeMonitor:
    def __init__(self, equity_module):
        self.eq = equity_module
        self._last_run_minute = -1
        self._last_check = self._load_last_check()

    def _load_last_check(self):
        try:
            if LAST_REGIME_CHECK_FILE.exists():
                return json.loads(LAST_REGIME_CHECK_FILE.read_text())
        except Exception:
            pass
        return {}

    def _save_last_check(self):
        try:
            LAST_REGIME_CHECK_FILE.write_text(json.dumps(self._last_check, indent=2))
        except Exception as e:
            self.eq_log_error(f"[V105_REGIME_EQ] save failed: {e}")

    def _load_entry_scores(self):
        try:
            if ENTRY_SCORES_FILE.exists():
                return json.loads(ENTRY_SCORES_FILE.read_text())
        except Exception:
            pass
        return {}

    def eq_log_info(self, msg):
        try:
            from __main__ import log
            log.info(msg)
        except Exception:
            print(msg)

    def eq_log_warning(self, msg):
        try:
            from __main__ import log
            log.warning(msg)
        except Exception:
            print(msg)

    def eq_log_error(self, msg):
        try:
            from __main__ import log
            log.error(msg)
        except Exception:
            print(msg)

    def eq_health_fire(self, msg):
        try:
            from __main__ import health
            health.fire(msg)
        except Exception:
            self.eq_log_warning(f"[V105_REGIME_EQ] tg failed: {msg}")

    def maybe_run(self, n):
        try:
            mkey = n.hour * 60 + n.minute
            if mkey == self._last_run_minute:
                return
            if (mkey % CHECK_INTERVAL_MIN) != 0:
                return
            self._last_run_minute = mkey
            self.run_once()
        except Exception as e:
            self.eq_log_error(f"[V105_REGIME_EQ] maybe_run: {e}")

    def run_once(self):
        try:
            from __main__ import KiteSession, now_ist
        except Exception as e:
            self.eq_log_error(f"[V105_REGIME_EQ] import: {e}")
            return
        kite = KiteSession.kite()
        if not kite:
            self.eq_log_warning("[V105_REGIME_EQ] no kite, skip")
            return
        positions = getattr(self.eq, "positions", {}) or {}
        if not positions:
            self.eq_log_info("[V105_REGIME_EQ] no positions")
            return
        nifty_pct = self._get_nifty_change(kite)
        strong_bearish = nifty_pct <= NIFTY_STRONG_BEARISH_PCT
        entry_scores = self._load_entry_scores()
        self.eq_log_info(f"[V105_REGIME_EQ] sweep: {len(positions)} pos, NIFTY {nifty_pct:+.2f}% bearish={strong_bearish}")
        for sym in list(positions.keys()):
            try:
                self._evaluate_position(sym, positions[sym], entry_scores, nifty_pct, strong_bearish, kite)
            except Exception as e:
                self.eq_log_error(f"[V105_REGIME_EQ] {sym}: {e}")
        self._save_last_check()

    def _evaluate_position(self, sym, pos, entry_scores, nifty_pct, strong_bearish, kite):
        avg = pos.get("entry_price", 0) or pos.get("avg", 0) or 0
        if avg <= 0:
            return
        try:
            from __main__ import now_ist
            et_str = pos.get("entry_time", "")
            if et_str:
                et = datetime.fromisoformat(et_str)
                age_min = (now_ist() - et).total_seconds() / 60.0
                if age_min < GRACE_MINUTES:
                    self.eq_log_info(f"[V105_REGIME_EQ] {sym}: age {age_min:.1f}m grace skip")
                    return
        except Exception:
            pass
        ltp_data = kite.ltp([f"NSE:{sym}"])
        ltp = ltp_data.get(f"NSE:{sym}", {}).get("last_price", 0) or 0
        if ltp <= 0:
            return
        pnl_pct = (ltp - avg) / avg * 100
        new_score, _, _ = self._rescore(kite, sym)
        if new_score is None:
            return
        entry_record = entry_scores.get(sym, {})
        entry_score = entry_record.get("score")
        if entry_score is None:
            try:
                from __main__ import ExpertPanel
                entry_score = ExpertPanel.EQUITY_THRESHOLD
            except Exception:
                entry_score = 60
        delta = new_score - entry_score
        stale = delta <= SCORE_FLIP_DELTA
        degrading = delta <= SCORE_DEGRADE_DELTA and not stale
        log_prefix = (f"[V105_REGIME_EQ] {sym} avg={avg:.2f} ltp={ltp:.2f} "
                      f"pnl={pnl_pct:+.1f}% entry={entry_score} new={new_score} d={delta:+d}")
        action = "HOLD"
        if stale:
            if pnl_pct < -2.0:
                self.eq_log_info(f"{log_prefix} STALE+LOSING -> EXIT")
                self.eq_health_fire(f"🚨 EQ REGIME EXIT: {sym}\nBias invalidated (Δ{delta})\nP&L {pnl_pct:+.1f}%")
                self._exit_position(sym, f"V105_REGIME_LOSING d={delta}")
                action = "EXIT"
            elif pnl_pct > 2.0:
                self.eq_log_info(f"{log_prefix} STALE+WINNING -> ALERT+TIGHTEN")
                self.eq_health_fire(f"⚠️ EQ REGIME ALERT: {sym}\nBias invalidated (Δ{delta})\nP&L {pnl_pct:+.1f}% — winner")
                self._tighten_trail(sym, pos, ltp, lock_factor=0.5)
                action = "ALERT+TIGHTEN"
            else:
                self.eq_log_info(f"{log_prefix} STALE+BE -> TIGHTEN")
                self._tighten_trail(sym, pos, ltp, sl_pct=0.015)
                action = "TIGHTEN"
        elif degrading and pnl_pct > 1.0:
            self.eq_log_info(f"{log_prefix} DEGRADING -> MILD TIGHTEN")
            self._tighten_trail(sym, pos, ltp, sl_pct=0.018)
            action = "MILD_TIGHTEN"
        elif strong_bearish:
            self.eq_log_info(f"{log_prefix} NIFTY_BEARISH -> TIGHTEN")
            self._tighten_trail(sym, pos, ltp, sl_pct=0.018)
            action = "NIFTY_TIGHTEN"
        else:
            self.eq_log_info(f"{log_prefix} HEALTHY")
        self._last_check[sym] = {"time": datetime.now().isoformat(timespec="seconds"),
                                 "entry_score": entry_score, "new_score": new_score,
                                 "delta": delta, "pnl_pct": round(pnl_pct, 2),
                                 "nifty_pct": round(nifty_pct, 2), "action": action}

    def _get_nifty_change(self, kite):
        try:
            q = kite.quote(["NSE:NIFTY 50"])
            d = q.get("NSE:NIFTY 50", {})
            ltp = d.get("last_price", 0)
            ohlc = d.get("ohlc", {})
            prev = ohlc.get("close", 0)
            if prev > 0:
                return (ltp - prev) / prev * 100
        except Exception:
            pass
        return 0.0

    def _rescore(self, kite, sym):
        try:
            from __main__ import ExpertPanel
        except Exception:
            return None, None, None
        panel = getattr(self.eq, "_expert_panel", None)
        if panel is None:
            try:
                panel = ExpertPanel(
                    getattr(self.eq, "trendlyne", None),
                    getattr(self.eq, "_sector_rotation", None),
                    getattr(self.eq, "news_brain", None),
                )
                self.eq._expert_panel = panel
            except Exception as e:
                self.eq_log_warning(f"[V105_REGIME_EQ] panel init: {e}")
                return None, None, None
        scout_data = {"symbol": sym, "catalyst": "REGIME_RESCORE",
                      "source": "V105_REGIME_EQ", "headline": "post-entry rescore"}
        try:
            r = panel.evaluate_equity(kite, sym, "BUY", scout_data)
            return r.get("total"), r.get("allow"), r
        except Exception as e:
            self.eq_log_warning(f"[V105_REGIME_EQ] rescore {sym}: {e}")
            return None, None, None

    def _tighten_trail(self, sym, pos, ltp, sl_pct=None, lock_factor=None):
        try:
            current_sl = pos.get("sl", 0) or 0
            if lock_factor is not None:
                entry = pos.get("entry_price", 0) or 0
                if entry > 0 and ltp > entry:
                    new_sl = entry + (ltp - entry) * lock_factor
                else:
                    return
            elif sl_pct is not None:
                new_sl = ltp * (1.0 - sl_pct)
            else:
                return
            if new_sl > current_sl:
                pos["sl"] = new_sl
                pos["regime_tightened_at"] = datetime.now().isoformat(timespec="seconds")
                self.eq_log_info(f"[V105_REGIME_EQ] {sym}: SL {current_sl:.2f}->{new_sl:.2f}")
                try:
                    self.eq.check_trailing_sl()
                except Exception as e:
                    self.eq_log_warning(f"[V105_REGIME_EQ] trail propagate: {e}")
            else:
                self.eq_log_info(f"[V105_REGIME_EQ] {sym}: new_sl {new_sl:.2f} <= current {current_sl:.2f}, skip")
        except Exception as e:
            self.eq_log_error(f"[V105_REGIME_EQ] tighten {sym}: {e}")

    def _exit_position(self, sym, reason):
        try:
            self.eq._exit_position(sym, reason)
        except Exception as e:
            self.eq_log_error(f"[V105_REGIME_EQ] exit {sym}: {e}")

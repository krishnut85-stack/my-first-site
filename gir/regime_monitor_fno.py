"""regime_monitor_fno.py — PATCH_V105_REGIME_FNO"""
from __future__ import annotations
import json
from pathlib import Path
from datetime import datetime

ENTRY_SCORES_FILE = Path("/home/globalbot/fno_entry_scores.json")
LAST_REGIME_CHECK_FILE = Path("/home/globalbot/fno_regime_last_check.json")

SCORE_FLIP_DELTA = -20
SCORE_DEGRADE_DELTA = -10
LOSING_PNL_PCT = 20.0
WINNING_PNL_PCT = -20.0
VIX_SPIKE_LEVEL = 25.0
CHECK_INTERVAL_MIN = 15


class FnoRegimeMonitor:
    def __init__(self, fno_module):
        self.fno = fno_module
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
            self.fno_log_error(f"[V105_REGIME_FNO] save failed: {e}")

    def _load_entry_scores(self):
        try:
            if ENTRY_SCORES_FILE.exists():
                return json.loads(ENTRY_SCORES_FILE.read_text())
        except Exception:
            pass
        return {}

    def fno_log_info(self, msg):
        try:
            from __main__ import log
            log.info(msg)
        except Exception:
            print(msg)

    def fno_log_warning(self, msg):
        try:
            from __main__ import log
            log.warning(msg)
        except Exception:
            print(msg)

    def fno_log_error(self, msg):
        try:
            from __main__ import log
            log.error(msg)
        except Exception:
            print(msg)

    def fno_health_fire(self, msg):
        try:
            from __main__ import health
            health.fire(msg)
        except Exception:
            self.fno_log_warning(f"[V105_REGIME_FNO] tg failed: {msg}")

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
            self.fno_log_error(f"[V105_REGIME_FNO] maybe_run: {e}")

    def run_once(self):
        try:
            from __main__ import KiteSession, now_ist
        except Exception as e:
            self.fno_log_error(f"[V105_REGIME_FNO] import: {e}")
            return
        kite = KiteSession.kite()
        if not kite:
            self.fno_log_warning("[V105_REGIME_FNO] no kite, skip")
            return
        try:
            positions = kite.positions().get("net", [])
        except Exception as e:
            self.fno_log_error(f"[V105_REGIME_FNO] positions: {e}")
            return
        legs = []
        for p in positions:
            tsym = p.get("tradingsymbol", "")
            qty = p.get("quantity", 0)
            exch = p.get("exchange", "")
            if exch != "NFO" or qty == 0:
                continue
            if not (tsym.endswith("CE") or tsym.endswith("PE")):
                continue
            legs.append(p)
        if not legs:
            self.fno_log_info("[V105_REGIME_FNO] no open option legs")
            return
        entry_scores = self._load_entry_scores()
        vix = self._get_vix(kite)
        self.fno_log_info(f"[V105_REGIME_FNO] sweep: {len(legs)} legs, VIX={vix:.2f}")
        for leg in legs:
            try:
                self._evaluate_leg(leg, entry_scores, vix, kite)
            except Exception as e:
                self.fno_log_error(f"[V105_REGIME_FNO] leg {leg.get('tradingsymbol')}: {e}")
        self._save_last_check()

    def _evaluate_leg(self, leg, entry_scores, vix, kite):
        tsym = leg["tradingsymbol"]
        qty = leg["quantity"]
        avg = leg.get("average_price", 0) or 0
        if avg <= 0:
            return
        underlying = self._parse_underlying(tsym)
        if not underlying:
            return
        is_pe = tsym.endswith("PE")
        is_ce = tsym.endswith("CE")
        is_short = qty < 0
        if is_short and is_pe:
            entry_bias = "BULLISH"
        elif is_short and is_ce:
            entry_bias = "BEARISH"
        elif (not is_short) and is_ce:
            entry_bias = "BULLISH"
        elif (not is_short) and is_pe:
            entry_bias = "BEARISH"
        else:
            return
        ltp_data = kite.ltp([f"NFO:{tsym}"])
        ltp = ltp_data.get(f"NFO:{tsym}", {}).get("last_price", 0) or 0
        if ltp <= 0:
            return
        if is_short:
            pnl_pct = (avg - ltp) / avg * 100
        else:
            pnl_pct = (ltp - avg) / avg * 100
        new_score, _, _ = self._rescore(kite, underlying, entry_bias)
        if new_score is None:
            return
        entry_record = entry_scores.get(tsym, {})
        entry_score = entry_record.get("score")
        if entry_score is None:
            try:
                from __main__ import ExpertPanel
                entry_score = ExpertPanel.FNO_THRESHOLD
            except Exception:
                entry_score = 60
        delta = new_score - entry_score
        stale = delta <= SCORE_FLIP_DELTA
        degrading = delta <= SCORE_DEGRADE_DELTA and not stale
        log_prefix = (f"[V105_REGIME_FNO] {tsym} qty={qty} avg={avg:.2f} ltp={ltp:.2f} "
                      f"pnl={pnl_pct:+.1f}% entry={entry_score} new={new_score} d={delta:+d} {entry_bias}")
        if stale:
            if pnl_pct < -10.0:
                self.fno_log_info(f"{log_prefix} STALE+LOSING -> EXIT")
                self.fno_health_fire(f"🚨 FNO REGIME EXIT: {tsym}\nBias {entry_bias} invalidated (Δ{delta})\nP&L {pnl_pct:+.1f}%")
                self._exit_leg(tsym, f"V105_REGIME_LOSING d={delta}")
            elif pnl_pct > 5.0:
                self.fno_log_info(f"{log_prefix} STALE+WINNING -> ALERT")
                self.fno_health_fire(f"⚠️ FNO REGIME ALERT: {tsym}\nBias {entry_bias} invalidated (Δ{delta})\nP&L {pnl_pct:+.1f}% — winner running")
            else:
                self.fno_log_info(f"{log_prefix} STALE+BE -> TIGHTEN")
                self._tighten_via_audit(tsym, 0.30)
        elif degrading and pnl_pct > 5.0:
            self.fno_log_info(f"{log_prefix} DEGRADING -> TIGHTEN")
            self._tighten_via_audit(tsym, 0.20)
        elif vix > VIX_SPIKE_LEVEL and is_short:
            self.fno_log_info(f"{log_prefix} VIX={vix:.1f} -> TIGHTEN")
            self._tighten_via_audit(tsym, 0.25)
        else:
            self.fno_log_info(f"{log_prefix} HEALTHY")
        self._last_check[tsym] = {"time": datetime.now().isoformat(timespec="seconds"),
                                  "entry_score": entry_score, "new_score": new_score,
                                  "delta": delta, "pnl_pct": round(pnl_pct, 2)}

    def _parse_underlying(self, tsym):
        import re
        s = tsym
        if s.endswith("CE") or s.endswith("PE"):
            s = s[:-2]
        # Strip strike (trailing digits)
        s = re.sub(r"\d+$", "", s)
        # Monthly: strip 3-letter month
        s2 = re.sub(r"(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)$", "", s)
        if s2 != s:
            s = re.sub(r"\d+$", "", s2)
            return s
        # Weekly NSE format: NIFTY25N0625000CE -> after strike strip = NIFTY25N
        # Strip single letter weekly month code (O/N/D for Oct/Nov/Dec, 1-9 for Jan-Sep)
        s2 = re.sub(r"[A-Z]$", "", s)
        if s2 != s:
            s = re.sub(r"\d+$", "", s2)
            return s
        # Fallback: strip remaining trailing digits
        s = re.sub(r"\d+$", "", s)
        return s

    def _get_vix(self, kite):
        try:
            v = kite.ltp(["NSE:INDIA VIX"])
            return v.get("NSE:INDIA VIX", {}).get("last_price", 0) or 0
        except Exception:
            return 0.0

    def _rescore(self, kite, underlying, entry_bias):
        try:
            from __main__ import ExpertPanel
        except Exception:
            return None, None, None
        panel = getattr(self.fno, "_expert_panel", None)
        if panel is None:
            try:
                panel = ExpertPanel(
                    getattr(self.fno, "trendlyne", None),
                    getattr(self.fno, "_sector_rotation", None),
                    getattr(self.fno, "news_brain", None),
                )
                self.fno._expert_panel = panel
            except Exception as e:
                self.fno_log_warning(f"[V105_REGIME_FNO] panel init: {e}")
                return None, None, None
        direction = "BUY" if entry_bias == "BULLISH" else "SELL"
        scout_data = {"symbol": underlying, "catalyst": "REGIME_RESCORE",
                      "source": "V105_REGIME_FNO", "headline": "post-entry rescore"}
        try:
            r = panel.evaluate_fno(kite, underlying, direction, scout_data, {})
            return r.get("total"), r.get("allow"), r
        except Exception as e:
            self.fno_log_warning(f"[V105_REGIME_FNO] rescore {underlying}: {e}")
            return None, None, None

    def _exit_leg(self, tsym, reason):
        try:
            for key in list(getattr(self.fno, "positions", {}).keys()):
                if key == tsym or tsym in str(key):
                    self.fno._exit_position(key, reason)
                    return
            self._direct_market_exit(tsym, reason)
        except Exception as e:
            self.fno_log_error(f"[V105_REGIME_FNO] exit {tsym}: {e}")

    def _direct_market_exit(self, tsym, reason):
        try:
            from __main__ import KiteSession
            kite = KiteSession.kite()
            if not kite:
                return
            for p in kite.positions().get("net", []):
                if p.get("tradingsymbol") == tsym and p.get("quantity", 0) != 0:
                    qty = abs(p["quantity"])
                    txn = "BUY" if p["quantity"] < 0 else "SELL"
                    kite.place_order(variety="regular", exchange="NFO",
                                     tradingsymbol=tsym, transaction_type=txn,
                                     quantity=qty, product="NRML",
                                     order_type="MARKET", tag="V105_REG")
                    self.fno_log_info(f"[V105_REGIME_FNO] direct exit {tsym} {txn} {qty}")
                    return
        except Exception as e:
            self.fno_log_error(f"[V105_REGIME_FNO] direct exit {tsym}: {e}")

    def _tighten_via_audit(self, tsym, tighten_pct):
        try:
            flags_file = Path("/home/globalbot/fno_tighten_flags.json")
            flags = {}
            if flags_file.exists():
                try:
                    flags = json.loads(flags_file.read_text())
                except Exception:
                    flags = {}
            flags[tsym] = {"tighten_pct": tighten_pct,
                           "set_at": datetime.now().isoformat(timespec="seconds"),
                           "source": "V105_REGIME_FNO"}
            flags_file.write_text(json.dumps(flags, indent=2))
            self.fno_log_info(f"[V105_REGIME_FNO] tighten flag {tsym} pct={tighten_pct:.2f}")
            try:
                self.fno._fno_gtt_audit()
            except Exception as e:
                self.fno_log_warning(f"[V105_REGIME_FNO] audit trigger: {e}")
        except Exception as e:
            self.fno_log_error(f"[V105_REGIME_FNO] tighten {tsym}: {e}")

#!/usr/bin/env python3
"""
patch_v79_decision_tap.py — Activate decision recording in ExpertPanel

Phase 1B of the replay harness.

What it does:
  Adds TradeRecorder.record_decision() calls inside ExpertPanel.evaluate_equity
  and evaluate_fno. Captures FULL component scores (not just total) so replay
  can verify component math even when sub-calls (Gemini, kite.historical_data,
  trendlyne) are non-deterministic.

  Existing _record_panel_decision (V63) is left alone — it's the legacy logger
  that goes to panel_decisions_*.jsonl. We add a SECOND recording stream to
  decisions_*.jsonl which the replay harness reads.

Edits:
  EDIT 1: Inject TradeRecorder.record_decision in evaluate_equity
  EDIT 2: Inject TradeRecorder.record_decision in evaluate_fno

Both edits add the call right BEFORE the existing _record_panel_decision call,
so V63 logging is untouched. New call wrapped in try/except — never raises.

Behavior:
  - Backs up gir.py to gir.py.bak_v79_<timestamp>
  - Validates with ast.parse before saving
  - Each edit must match exactly once (fails loud otherwise)
  - Does NOT restart the bot

Usage:
  python3 patch_v79_decision_tap.py
  # then:
  systemctl restart globaleye
"""

import ast
import shutil
import time
from pathlib import Path

GIR_PATH = Path("/home/globalbot/gir.py")
BACKUP_PATH = Path(f"/home/globalbot/gir.py.bak_v79_{int(time.time())}")

# ═══════════════════════════════════════════════════════════════════════════════
# EDIT 1 — Decision tap inside evaluate_equity
# ═══════════════════════════════════════════════════════════════════════════════
EDIT1_OLD = '''    def evaluate_equity(self, kite, symbol, direction, scout_data):
        e1, veto = self.score_news(symbol, direction, scout_data)
        e2 = self.score_fundamental(symbol)
        e3 = self.score_technical(kite, symbol, direction)
        e4 = self.score_sector(symbol, direction)
        e5 = self.score_history(symbol)
        total = e1 + e2 + e3 + e4 + e5
        result = {"symbol": symbol, "direction": direction, "news": e1, "fundamental": e2, "technical": e3, "sector": e4, "history": e5, "total": total, "threshold": self.EQUITY_THRESHOLD, "veto": veto, "allow": (not veto) and (total >= self.EQUITY_THRESHOLD)}
        # PATCH_V63_PANEL_TRACKER: persist every equity panel decision for Friday review
        try:
            self._record_panel_decision("EQUITY", result, scout_data)
        except Exception:
            pass
        return result'''

EDIT1_NEW = '''    def evaluate_equity(self, kite, symbol, direction, scout_data):
        e1, veto = self.score_news(symbol, direction, scout_data)
        e2 = self.score_fundamental(symbol)
        e3 = self.score_technical(kite, symbol, direction)
        e4 = self.score_sector(symbol, direction)
        e5 = self.score_history(symbol)
        total = e1 + e2 + e3 + e4 + e5
        result = {"symbol": symbol, "direction": direction, "news": e1, "fundamental": e2, "technical": e3, "sector": e4, "history": e5, "total": total, "threshold": self.EQUITY_THRESHOLD, "veto": veto, "allow": (not veto) and (total >= self.EQUITY_THRESHOLD)}
        # V79: replay-harness decision tap (separate from V63 legacy log)
        try:
            if _TRADE_RECORDER_AVAILABLE:
                TradeRecorder.record_decision("EQUITY", result, scout_data, extras={
                    "components": {"news": e1, "fundamental": e2, "technical": e3, "sector": e4, "history": e5},
                    "veto": veto,
                })
        except Exception:
            pass
        # PATCH_V63_PANEL_TRACKER: persist every equity panel decision for Friday review
        try:
            self._record_panel_decision("EQUITY", result, scout_data)
        except Exception:
            pass
        return result'''

# ═══════════════════════════════════════════════════════════════════════════════
# EDIT 2 — Decision tap inside evaluate_fno
# ═══════════════════════════════════════════════════════════════════════════════
EDIT2_OLD = '''    def evaluate_fno(self, kite, symbol, direction, scout_data, option_data):
        e1, veto = self.score_news(symbol, direction, scout_data)
        e2 = 10
        try:
            cat = scout_data.get("catalyst", "")
            src = scout_data.get("source", "")
            if "OI" in src.upper() or "CALL_WRITING" in cat or "PUT_WRITING" in cat:
                e2 = 20
        except Exception:
            pass
        e3 = self.score_technical(kite, symbol, direction)
        e4 = self.score_sector(symbol, direction)
        e5 = self.score_history(symbol)
        e6 = self.score_option(option_data or {})
        total = e1 + e2 + e3 + e4 + e5 + e6
        result = {"symbol": symbol, "direction": direction, "news": e1, "oi": e2, "technical": e3, "sector": e4, "history": e5, "option": e6, "total": total, "threshold": self.FNO_THRESHOLD, "veto": veto, "allow": (not veto) and (total >= self.FNO_THRESHOLD)}
        # PATCH_V63_PANEL_TRACKER: persist every F&O panel decision for Friday review
        try:
            self._record_panel_decision("FNO", result, scout_data)
        except Exception:
            pass
        return result'''

EDIT2_NEW = '''    def evaluate_fno(self, kite, symbol, direction, scout_data, option_data):
        e1, veto = self.score_news(symbol, direction, scout_data)
        e2 = 10
        try:
            cat = scout_data.get("catalyst", "")
            src = scout_data.get("source", "")
            if "OI" in src.upper() or "CALL_WRITING" in cat or "PUT_WRITING" in cat:
                e2 = 20
        except Exception:
            pass
        e3 = self.score_technical(kite, symbol, direction)
        e4 = self.score_sector(symbol, direction)
        e5 = self.score_history(symbol)
        e6 = self.score_option(option_data or {})
        total = e1 + e2 + e3 + e4 + e5 + e6
        result = {"symbol": symbol, "direction": direction, "news": e1, "oi": e2, "technical": e3, "sector": e4, "history": e5, "option": e6, "total": total, "threshold": self.FNO_THRESHOLD, "veto": veto, "allow": (not veto) and (total >= self.FNO_THRESHOLD)}
        # V79: replay-harness decision tap (separate from V63 legacy log)
        try:
            if _TRADE_RECORDER_AVAILABLE:
                TradeRecorder.record_decision("FNO", result, scout_data, extras={
                    "components": {"news": e1, "oi": e2, "technical": e3, "sector": e4, "history": e5, "option": e6},
                    "veto": veto,
                    "option_data": option_data or {},
                })
        except Exception:
            pass
        # PATCH_V63_PANEL_TRACKER: persist every F&O panel decision for Friday review
        try:
            self._record_panel_decision("FNO", result, scout_data)
        except Exception:
            pass
        return result'''


def apply_edit(content, old, new, label):
    count = content.count(old)
    if count == 0:
        raise RuntimeError(f"[{label}] OLD pattern NOT FOUND. Aborting.")
    if count > 1:
        raise RuntimeError(f"[{label}] OLD pattern matched {count} times (must be 1). Aborting.")
    return content.replace(old, new, 1)


def main():
    print(f"Reading {GIR_PATH} ...")
    original = GIR_PATH.read_text()
    print(f"  size: {len(original)} bytes, {len(original.splitlines())} lines")

    print(f"Backing up to {BACKUP_PATH} ...")
    shutil.copy(GIR_PATH, BACKUP_PATH)

    print("Applying EDIT 1 (evaluate_equity tap) ...")
    patched = apply_edit(original, EDIT1_OLD, EDIT1_NEW, "EDIT1")
    print("  OK")

    print("Applying EDIT 2 (evaluate_fno tap) ...")
    patched = apply_edit(patched, EDIT2_OLD, EDIT2_NEW, "EDIT2")
    print("  OK")

    print("Validating Python syntax of patched file ...")
    try:
        ast.parse(patched)
    except SyntaxError as e:
        print(f"  SYNTAX ERROR: {e}")
        print(f"  NOT writing file. Backup at {BACKUP_PATH}")
        raise SystemExit(1)
    print("  OK")

    print(f"Writing patched gir.py ({len(patched)} bytes) ...")
    GIR_PATH.write_text(patched)
    print(f"  new size: {len(patched)} bytes, {len(patched.splitlines())} lines")
    print()
    print("PATCH COMPLETE.")
    print(f"  backup: {BACKUP_PATH}")
    print()
    print("To activate:  systemctl restart globaleye")
    print("To rollback:  cp {} {} && systemctl restart globaleye".format(BACKUP_PATH, GIR_PATH))


if __name__ == "__main__":
    main()

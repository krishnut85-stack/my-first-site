#!/usr/bin/env python3
"""
patch_v78_recorder.py — Activate TradeRecorder in gir.py

Three surgical edits:
  1. Add import after NewsBrain import block (~line 84)
  2. Install recorder inside KiteSession.kite() before return
  3. Uninstall recorder inside ensure_connected() before re-login

Behavior:
  - Backs up gir.py to gir.py.bak_v78_<timestamp>
  - Validates new file with ast.parse before saving
  - Validates each edit found exactly one match (fails loud otherwise)
  - Does NOT restart the bot. Caller does that manually after review.

Usage:
  python3 patch_v78_recorder.py
  # then if happy:
  systemctl restart globaleye
"""

import ast
import shutil
import time
from pathlib import Path

GIR_PATH = Path("/home/globalbot/gir.py")
BACKUP_PATH = Path(f"/home/globalbot/gir.py.bak_v78_{int(time.time())}")

# ═══════════════════════════════════════════════════════════════════════════════
# EDIT 1 — Add import after NewsBrain import block
# ═══════════════════════════════════════════════════════════════════════════════
EDIT1_OLD = '''try:
    from news_brain import NewsBrain
    _NEWS_BRAIN_AVAILABLE = True
except ImportError as _nbe:
    NewsBrain = None
    _NEWS_BRAIN_AVAILABLE = False
    print(f"WARNING: news_brain.py not importable: {_nbe} - LLM mode disabled")'''

EDIT1_NEW = '''try:
    from news_brain import NewsBrain
    _NEWS_BRAIN_AVAILABLE = True
except ImportError as _nbe:
    NewsBrain = None
    _NEWS_BRAIN_AVAILABLE = False
    print(f"WARNING: news_brain.py not importable: {_nbe} - LLM mode disabled")

# V78: Trade recorder (silent observation, never blocks orders)
try:
    from trade_recorder import TradeRecorder
    _TRADE_RECORDER_AVAILABLE = True
except ImportError as _tre:
    TradeRecorder = None
    _TRADE_RECORDER_AVAILABLE = False
    print(f"WARNING: trade_recorder.py not importable: {_tre} - recording disabled")'''

# ═══════════════════════════════════════════════════════════════════════════════
# EDIT 2 — Install recorder inside KiteSession.kite()
# ═══════════════════════════════════════════════════════════════════════════════
EDIT2_OLD = '''    @classmethod
    def kite(cls):
        """Get KiteConnect instance. Returns None if not logged in."""
        if cls._kite is None:
            cls.login()
        return cls._kite'''

EDIT2_NEW = '''    @classmethod
    def kite(cls):
        """Get KiteConnect instance. Returns None if not logged in."""
        if cls._kite is None:
            cls.login()
        # V78: install recorder on the live kite object (idempotent, never raises)
        if cls._kite is not None and _TRADE_RECORDER_AVAILABLE:
            try:
                TradeRecorder.install(cls._kite)
            except Exception:
                pass  # Never let recorder failure block kite access
        return cls._kite'''

# ═══════════════════════════════════════════════════════════════════════════════
# EDIT 3 — Uninstall recorder inside ensure_connected() before re-login
# ═══════════════════════════════════════════════════════════════════════════════
EDIT3_OLD = '''        try:
            k.profile()
            return True
        except Exception:
            log.info("Kite: token expired, re-logging in")
            cls._kite = None
            return cls.login()'''

EDIT3_NEW = '''        try:
            k.profile()
            return True
        except Exception:
            log.info("Kite: token expired, re-logging in")
            # V78: uninstall recorder so it cleanly re-installs on the new kite object
            if _TRADE_RECORDER_AVAILABLE:
                try:
                    TradeRecorder.uninstall()
                except Exception:
                    pass
            cls._kite = None
            return cls.login()'''


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

    print("Applying EDIT 1 (import) ...")
    patched = apply_edit(original, EDIT1_OLD, EDIT1_NEW, "EDIT1")
    print("  OK")

    print("Applying EDIT 2 (install in kite()) ...")
    patched = apply_edit(patched, EDIT2_OLD, EDIT2_NEW, "EDIT2")
    print("  OK")

    print("Applying EDIT 3 (uninstall in ensure_connected) ...")
    patched = apply_edit(patched, EDIT3_OLD, EDIT3_NEW, "EDIT3")
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

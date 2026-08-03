#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# V83 DEPLOY — six surgical patches to gir.py + news_brain.py
# Patches:
#   V83_KILL_MACRO_EQ    — block V68_MACRO equity entries
#   V83_EXIT_COOLDOWN_24H — 24h hard block per-symbol after ANY exit
#   V83_CONTRADICT       — block on split BULLISH/BEARISH within 4h
#   V83_REFLEX           — basket-signal price-action confirmation
#   V83_HOURLY           — tiered score thresholds by entry hour
#   V83_EARNINGS_SIZE    — 1.5-2x lots for earnings AMO entries
#   V83_EXIT_HOOK        — record every exit (loss/be/win) for cooldown
# ═══════════════════════════════════════════════════════════════════════════════
set -e

cd /home/globalbot

# 1) Backup with timestamp
TS=$(date +%Y%m%d_%H%M%S)
cp gir.py "gir.py.bak.V83_${TS}"
cp news_brain.py "news_brain.py.bak.V83_${TS}"
echo "Backup: gir.py.bak.V83_${TS}"
echo "Backup: news_brain.py.bak.V83_${TS}"

# 2) Pre-flight: refuse double-apply
if grep -q "V83_KILL_MACRO_EQ\|V83_EXIT_COOLDOWN_24H" gir.py; then
    echo "ABORT: V83 markers already present in gir.py"
    exit 1
fi
if grep -q "def get_recent_decisions" news_brain.py; then
    echo "ABORT: V83 helper already present in news_brain.py"
    exit 1
fi

# 3) Apply patches via inline Python (avoids null-byte SCP corruption)
python3 << 'PYPATCH'
import ast, sys
from pathlib import Path

GIR = Path("/home/globalbot/gir.py")
NB  = Path("/home/globalbot/news_brain.py")

gir = GIR.read_text()
nb  = NB.read_text()

# ─── PATCH A: news_brain.py — public helpers for entry-time guards ───
NB_ANCHOR = "    def is_validated(self, symbol, direction=None, max_age_hours=6):"
NB_NEW = '''    # ─── V83: read-only helpers for entry-time guards ────────────────────────
    # Used by gir.enter() for V83_CONTRADICT and V83_REFLEX guards.
    # Read-only access to _scout_cache (no modification, respects lock).
    def get_recent_decisions(self, symbol, hours=4):
        try:
            import time as _t
            cutoff = _t.time() - hours * 3600
            out = []
            with self._scout_cache_lock:
                for _k, _entry in self._scout_cache.items():
                    if _entry.get("ts", 0) < cutoff:
                        continue
                    for c in _entry.get("candidates", []):
                        if c.get("symbol") == symbol:
                            out.append(c)
            return out
        except Exception:
            return []

    def get_candidates_by_catalyst(self, catalyst_prefix, hours=4):
        try:
            import time as _t
            if not catalyst_prefix:
                return []
            cutoff = _t.time() - hours * 3600
            out = []
            cp = catalyst_prefix[:80]
            with self._scout_cache_lock:
                for _k, _entry in self._scout_cache.items():
                    if _entry.get("ts", 0) < cutoff:
                        continue
                    for c in _entry.get("candidates", []):
                        if c.get("catalyst", "")[:80] == cp:
                            out.append(c)
            return out
        except Exception:
            return []

    def is_validated(self, symbol, direction=None, max_age_hours=6):'''

assert NB_ANCHOR in nb, "FAIL: news_brain anchor missing"
assert nb.count(NB_ANCHOR) == 1, "FAIL: news_brain anchor not unique"
nb_new = nb.replace(NB_ANCHOR, NB_NEW, 1)

# ─── PATCH B: gir.py — ExitHistoryTracker class ───
ET_ANCHOR = "_LOSS_TRACKER = None\n"
ET_NEW = '''_LOSS_TRACKER = None


# ─── V83_EXIT_COOLDOWN_24H: tracks ANY exit (loss/be/win/external) per symbol ───
# Distinct from LossHistoryTracker (which only records losses with day granularity).
# This tracker uses ISO timestamps (minute precision) for the 24-hour hard cooldown.
class ExitHistoryTracker:
    def __init__(self):
        self.file = Path("/home/globalbot/data/exit_history.json")
        self.data = self._load()
    def _load(self):
        try:
            if self.file.exists():
                with open(self.file, "r") as f:
                    return json.load(f)
        except Exception as e:
            log.warning(f"[V83_EXIT_TRACKER] load failed: {e}")
        return {}
    def _save(self):
        try:
            self.file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.file, "w") as f:
                json.dump(self.data, f, indent=2)
        except Exception as e:
            log.error(f"[V83_EXIT_TRACKER] save failed: {e}")
    def record_exit(self, symbol, reason="UNKNOWN"):
        ts = now_ist().isoformat()
        if symbol not in self.data:
            self.data[symbol] = []
        self.data[symbol].append({"ts": ts, "reason": reason})
        cutoff = now_ist() - timedelta(days=7)
        self.data[symbol] = [
            e for e in self.data[symbol]
            if datetime.fromisoformat(e["ts"]) >= cutoff
        ]
        self._save()
    def hours_since_last_exit(self, symbol):
        entries = self.data.get(symbol, [])
        if not entries:
            return None
        try:
            last = max(datetime.fromisoformat(e["ts"]) for e in entries)
            delta = now_ist() - last
            return delta.total_seconds() / 3600.0
        except Exception:
            return None

_EXIT_TRACKER = None
def get_exit_tracker():
    global _EXIT_TRACKER
    if _EXIT_TRACKER is None:
        _EXIT_TRACKER = ExitHistoryTracker()
    return _EXIT_TRACKER

'''

assert ET_ANCHOR in gir, "FAIL: ExitTracker anchor missing"
assert gir.count(ET_ANCHOR) == 1, "FAIL: ExitTracker anchor not unique"
gir_new = gir.replace(ET_ANCHOR, ET_NEW, 1)

# ─── PATCH C: gir.py — four entry guards at top of EquityModule.enter() ───
ENTER_ANCHOR = '''    def enter(self, symbol, catalyst, direction, score, source="UNKNOWN"):
        """
        Place a real BUY order for equity.
        Returns True on success.
        """
        can, reason = self._can_enter(symbol)'''

ENTER_NEW = '''    def enter(self, symbol, catalyst, direction, score, source="UNKNOWN"):
        """
        Place a real BUY order for equity.
        Returns True on success.
        """
        # ═══ V83 ENTRY GUARDS (executed in order; first failure returns False) ═══
        # V83_KILL_MACRO_EQ: V68_MACRO is structurally low-quality for equity entries.
        # 91% of equity candidates came from V68_MACRO (avg score 68.6) and produced
        # the bulk of the same-day SL bleed. F&O still uses V68_MACRO via separate path.
        if (source or "").upper() == "V68_MACRO":
            log.info(f"[V83_KILL_MACRO_EQ] BLOCKED {symbol}: V68_MACRO not allowed for equity (use VALIDATED_FILING/BROKERAGE/NEWS)")
            return False

        # V83_EXIT_COOLDOWN_24H: hard block re-entry within 24h of any exit.
        # Stops the VENUSREM-3x and CAMS-2x re-entry death spirals.
        try:
            _et = get_exit_tracker()
            _hrs = _et.hours_since_last_exit(symbol)
            if _hrs is not None and _hrs < 24.0:
                log.info(f"[V83_EXIT_COOLDOWN_24H] BLOCKED {symbol}: last exit {_hrs:.1f}h ago (need 24h)")
                return False
        except Exception as _v83ee:
            log.warning(f"[V83_EXIT_COOLDOWN_24H] check failed for {symbol}: {_v83ee}, allowing")

        # V83_CONTRADICT: block if same symbol has both BULLISH and BEARISH
        # scout entries (score>=65) within last 4 hours. Indicates split conviction.
        try:
            _nb = getattr(self, "news_brain", None)
            if _nb and hasattr(_nb, "get_recent_decisions"):
                _recent = _nb.get_recent_decisions(symbol, hours=4)
                _bull = any(c.get("direction") == "BULLISH" and c.get("score", 0) >= 65 for c in _recent)
                _bear = any(c.get("direction") == "BEARISH" and c.get("score", 0) >= 65 for c in _recent)
                if _bull and _bear:
                    log.info(f"[V83_CONTRADICT] BLOCKED {symbol}: BULLISH+BEARISH both flagged within 4h (split conviction)")
                    return False
        except Exception as _v83ce:
            log.warning(f"[V83_CONTRADICT] check failed for {symbol}: {_v83ce}, allowing")

        # V83_REFLEX: if the same article triggered >=3 candidates simultaneously,
        # this is a basket/reflex signal. Require this specific symbol to also be
        # confirming with price action (>=0.5% move in predicted direction).
        try:
            _nb = getattr(self, "news_brain", None)
            if _nb and hasattr(_nb, "get_candidates_by_catalyst") and catalyst:
                _basket = _nb.get_candidates_by_catalyst(catalyst, hours=4)
                _basket_syms = set(c.get("symbol") for c in _basket if c.get("symbol"))
                if len(_basket_syms) >= 3:
                    try:
                        _kite = KiteSession.kite()
                        if _kite:
                            _q = _kite.quote([f"NSE:{symbol}"]).get(f"NSE:{symbol}", {})
                            _ltp = _q.get("last_price", 0)
                            _pclose = _q.get("ohlc", {}).get("close", 0)
                            if _ltp > 0 and _pclose > 0:
                                _pct = (_ltp - _pclose) / _pclose * 100
                                _confirm_dir = (direction == "BULLISH" and _pct >= 0.5) or \\
                                               (direction == "BEARISH" and _pct <= -0.5)
                                if not _confirm_dir:
                                    log.info(f"[V83_REFLEX] BLOCKED {symbol}: basket signal ({len(_basket_syms)} stocks share catalyst) but price not confirming ({_pct:+.2f}% vs {direction})")
                                    return False
                                log.info(f"[V83_REFLEX] {symbol} basket signal CONFIRMED by price ({_pct:+.2f}%)")
                    except Exception as _v83re:
                        log.warning(f"[V83_REFLEX] price check failed for {symbol}: {_v83re}, allowing")
        except Exception as _v83re2:
            log.warning(f"[V83_REFLEX] outer check failed for {symbol}: {_v83re2}, allowing")

        # V83_HOURLY: tiered filter by IST entry hour. Morning entries face stricter
        # thresholds — the 13:00 cluster produced the only profitable equity trades.
        try:
            _now = now_ist()
            _hm = _now.hour * 60 + _now.minute
            _src_upper = (source or "").upper()
            _is_validated = _src_upper.startswith("VALIDATED_")
            # 9:15->555, 10:30->630, 12:30->750, 14:30->870, 15:15->915
            if 555 <= _hm < 630:
                if score < 75:
                    log.info(f"[V83_HOURLY] BLOCKED {symbol}: morning slot needs score>=75, got {score}")
                    return False
                if not _is_validated:
                    log.info(f"[V83_HOURLY] BLOCKED {symbol}: morning slot needs VALIDATED_*, got {source}")
                    return False
            elif 630 <= _hm < 750:
                if score < 70:
                    log.info(f"[V83_HOURLY] BLOCKED {symbol}: mid-morning slot needs score>=70, got {score}")
                    return False
            elif 870 <= _hm < 915:
                if score < 70:
                    log.info(f"[V83_HOURLY] BLOCKED {symbol}: late slot needs score>=70 (overnight gap risk), got {score}")
                    return False
        except Exception as _v83he:
            log.warning(f"[V83_HOURLY] check failed for {symbol}: {_v83he}, allowing")
        # ═══ END V83 GUARDS ═══

        can, reason = self._can_enter(symbol)'''

assert ENTER_ANCHOR in gir_new, "FAIL: enter() anchor missing"
assert gir_new.count(ENTER_ANCHOR) == 1, "FAIL: enter() anchor not unique"
gir_new = gir_new.replace(ENTER_ANCHOR, ENTER_NEW, 1)

# ─── PATCH D: gir.py — V83_EARNINGS_SIZE in AMO sizing ───
SIZE_ANCHOR = '''                    tsym = option["tradingsymbol"]
                    lot = option["lot_size"]
                    premium = option["premium"]
                    # 50% sizing for safety
                    qty = lot
                    cost = qty * premium * 1.01
                    if cost > self.available * 0.5:'''

SIZE_NEW = '''                    tsym = option["tradingsymbol"]
                    lot = option["lot_size"]
                    premium = option["premium"]
                    # V83_EARNINGS_SIZE: 1.5-2x lots for earnings AMO entries.
                    # Empirical: earnings IV-crush plays were the only profitable F&O
                    # setup (EXIDEIND +Rs.3,240 alone). Sizing up captures more of
                    # that edge while the 50% available cap below still bounds risk.
                    _v83_src = (cand.get("source") or "").upper()
                    _v83_is_earn = ("EARNINGS" in _v83_src) or ("IV_CRUSH" in _v83_src)
                    if _v83_is_earn:
                        qty = max(lot, (int(lot * 1.5) // lot) * lot)
                        if qty == lot:
                            _try_qty = lot * 2
                            _try_cost = _try_qty * premium * 1.01
                            if _try_cost <= self.available * 0.5:
                                qty = _try_qty
                        log.info(f"[V83_EARNINGS_SIZE] {sym}: earnings source detected, qty={qty} (vs base lot={lot})")
                    else:
                        qty = lot
                    cost = qty * premium * 1.01
                    if cost > self.available * 0.5:'''

assert SIZE_ANCHOR in gir_new, "FAIL: AMO sizing anchor missing"
assert gir_new.count(SIZE_ANCHOR) == 1, "FAIL: AMO sizing anchor not unique"
gir_new = gir_new.replace(SIZE_ANCHOR, SIZE_NEW, 1)

# ─── PATCH E: gir.py — V83_EXIT_HOOK at top of _record_trade ───
HOOK_ANCHOR = '''    def _record_trade(self, symbol, pos, exit_price, reason):
        """Record a completed trade."""
        entry = pos.get("entry_price", 0)
        qty = pos.get("qty", 0)
        pnl = (exit_price - entry) * qty if exit_price > 0 else 0'''

HOOK_NEW = '''    def _record_trade(self, symbol, pos, exit_price, reason):
        """Record a completed trade."""
        entry = pos.get("entry_price", 0)
        qty = pos.get("qty", 0)
        pnl = (exit_price - entry) * qty if exit_price > 0 else 0
        # V83_EXIT_HOOK: record EVERY exit (loss/breakeven/win/external) for 24h cooldown.
        # Distinct from V79A_LOSS_HOOK below (which only fires on real losses).
        # Critical: must fire on SOLD_EXTERNAL/breakeven too — VENUSREM 1st re-entry
        # was after a pnl=0 exit, would have slipped through a loss-only hook.
        try:
            get_exit_tracker().record_exit(symbol, reason=reason or "UNKNOWN")
            log.info(f"[V83_EXIT_HOOK] recorded exit: {symbol} reason={reason} pnl={pnl:.2f}")
        except Exception as _v83eh:
            log.warning(f"[V83_EXIT_HOOK] failed for {symbol}: {_v83eh}")'''

assert HOOK_ANCHOR in gir_new, "FAIL: _record_trade anchor missing"
assert gir_new.count(HOOK_ANCHOR) == 1, "FAIL: _record_trade anchor not unique"
gir_new = gir_new.replace(HOOK_ANCHOR, HOOK_NEW, 1)

# ─── Final ast.parse before writing ───
try:
    ast.parse(gir_new)
    print("gir.py ast.parse: OK")
except SyntaxError as e:
    print(f"FAIL gir.py syntax: {e}")
    sys.exit(1)

try:
    ast.parse(nb_new)
    print("news_brain.py ast.parse: OK")
except SyntaxError as e:
    print(f"FAIL news_brain.py syntax: {e}")
    sys.exit(1)

# Write
GIR.write_text(gir_new)
NB.write_text(nb_new)

# Verify markers
markers = ["V83_KILL_MACRO_EQ", "V83_EXIT_COOLDOWN_24H", "V83_CONTRADICT",
           "V83_REFLEX", "V83_HOURLY", "V83_EARNINGS_SIZE", "V83_EXIT_HOOK",
           "ExitHistoryTracker", "get_exit_tracker"]
print("\\n=== V83 marker counts ===")
for m in markers:
    print(f"  {m}: {gir_new.count(m)} in gir.py")
print(f"  get_recent_decisions: {nb_new.count('get_recent_decisions')} in news_brain.py")
print(f"  get_candidates_by_catalyst: {nb_new.count('get_candidates_by_catalyst')} in news_brain.py")

print("\\nV83 PATCH APPLIED OK")
PYPATCH

# 4) Clear pycache
rm -rf /home/globalbot/__pycache__

# 5) Restart and watch
echo ""
echo "=== Restarting globaleye ==="
systemctl restart globaleye
sleep 4

echo ""
echo "=== First 20 log lines after restart ==="
journalctl -u globaleye -n 20 --no-pager

echo ""
echo "=== Process status ==="
systemctl is-active globaleye

echo ""
echo "✓ V83 deployment complete"
echo "  Backup: gir.py.bak.V83_${TS}"
echo "  Backup: news_brain.py.bak.V83_${TS}"
echo ""
echo "To rollback:"
echo "  cp gir.py.bak.V83_${TS} gir.py && cp news_brain.py.bak.V83_${TS} news_brain.py && rm -rf __pycache__ && systemctl restart globaleye"

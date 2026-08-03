#!/bin/bash
set -euo pipefail
GIR=/home/globalbot/gir.py
BAK=/home/globalbot/gir.py.bak_pre_v33_$(date +%Y%m%d_%H%M%S)
echo "=== V33 patch ==="
cp "$GIR" "$BAK"
echo "Backup: $BAK"

if ! grep -q "FIX_V32_FNO_UNIFIED" "$GIR"; then
    echo "ERROR: not V32 baseline"; exit 1
fi
if grep -q "FIX_V33_EARNINGS" "$GIR"; then
    echo "Already patched"; exit 2
fi

python3 << 'PYEOF'
GIR = "/home/globalbot/gir.py"
with open(GIR) as f:
    src = f.read()

OLD1 = '''    def _fno_amo_continuous_scan(self, threshold=65):
        """Hourly scan during 16:01-08:45 window. Accumulates catalysts.

        PATCH_V9_AMO_ARCH:
          - threshold param (default 65, was hardcoded 75) matches OI_SIGNAL_MIN_SCORE
          - adds daily-mode OI detection alongside intraday
        """
        if not self._fno_amo_in_scan_window():
            return
        try:
            existing = self._fno_amo_load_candidates()
            existing_keys = {(c.get("symbol"), c.get("direction")) for c in existing}

            fresh = []
            if getattr(self, "filings", None):
                try: fresh.extend(self.filings.scan() or [])
                except Exception as _e: log.warning(f"[PATCH_V1_FNO_AMO] filings: {_e}")
            if getattr(self, "news", None):
                try: fresh.extend(self.news.scan() or [])
                except Exception as _e: log.warning(f"[PATCH_V1_FNO_AMO] news: {_e}")
            if getattr(self, "brokerage", None):
                try: fresh.extend(self.brokerage.scan(news_candidates=fresh) or [])
                except Exception as _e: log.warning(f"[PATCH_V1_FNO_AMO] brokerage: {_e}")
                try:
                    if self._oi_engine:
                        fresh.extend(self._oi_engine.detect_buildup_signals() or [])
                        try:
                            fresh.extend(self._oi_engine.detect_buildup_signals(mode="daily") or [])
                        except Exception as _e2:
                            log.warning(f"[PATCH_V9_AMO_ARCH] daily OI detect: {_e2}")
                except Exception as _e: log.warning(f"[PATCH_V1_FNO_AMO] brokerage: {_e}")'''

NEW1 = OLD1.replace(
    '        """\n        if not self._fno_amo_in_scan_window():',
    '        \n        FIX_V33_EARNINGS_TRADER: earnings-driven candidates.\n        """\n        if not self._fno_amo_in_scan_window():'
) + '''
            
            # FIX_V33_EARNINGS_TRADER: earnings-driven candidates
            try:
                ef = self._earnings_amo_scan(news_candidates=fresh)
                if ef:
                    log.info(f"[FIX_V33_EARNINGS] {len(ef)} earnings candidates added")
                    fresh.extend(ef)
            except Exception as _ee:
                log.warning(f"[FIX_V33_EARNINGS] scan failed: {_ee}")'''

assert OLD1 in src, "Patch 1 anchor not found"
src = src.replace(OLD1, NEW1)
print("Patch 1 OK")

OLD2 = '''            self._fno_amo_save_candidates(existing)
            log.info(f"[PATCH_V1_FNO_AMO] scan complete: {added} new, {len(existing)} total in pool (threshold={threshold})")
        except Exception as _e:
            log.error(f"[PATCH_V1_FNO_AMO] continuous scan failed: {_e}")

    def _fno_amo_premarket_place(self):'''

NEW2 = '''            self._fno_amo_save_candidates(existing)
            log.info(f"[PATCH_V1_FNO_AMO] scan complete: {added} new, {len(existing)} total in pool (threshold={threshold})")
        except Exception as _e:
            log.error(f"[PATCH_V1_FNO_AMO] continuous scan failed: {_e}")

    def _earnings_amo_scan(self, news_candidates=None):
        """FIX_V33_EARNINGS_TRADER: earnings-driven candidates into AMO pool."""
        out = []
        if not self.earnings:
            return out
        try:
            news_dirs = {}
            if news_candidates:
                for c in news_candidates:
                    s = c.get("symbol"); d = c.get("direction")
                    if s and d in ("BULLISH", "BEARISH"):
                        news_dirs.setdefault(s, []).append(d)
            today = today_ist()
            kite = KiteSession.kite()
            _nse_cache = None
            for sym, info in self.earnings._calendar.items():
                if sym not in self.fno_stocks:
                    continue
                if sym in ("NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"):
                    continue
                date_str = info.get("date", "")
                earn_date = None
                for fmt in ("%d-%b-%Y", "%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y"):
                    try:
                        earn_date = datetime.strptime(date_str, fmt).date()
                        break
                    except ValueError:
                        continue
                if not earn_date:
                    continue
                days_to = (earn_date - today).days
                if not (3 <= days_to <= 7):
                    continue
                direction = None
                src_lbl = ""
                nd = news_dirs.get(sym, [])
                if nd and not ("BULLISH" in nd and "BEARISH" in nd):
                    direction = nd[0]
                    src_lbl = "news"
                elif kite:
                    try:
                        today_dt = datetime.combine(today, datetime.min.time())
                        from_dt = today_dt - timedelta(days=40)
                        tok = None
                        try:
                            if _nse_cache is None:
                                _nse_cache = kite.instruments("NSE")
                            for inst in _nse_cache:
                                if inst.get("tradingsymbol") == sym and inst.get("segment") == "NSE":
                                    tok = inst.get("instrument_token")
                                    break
                        except Exception:
                            pass
                        if tok:
                            h = kite.historical_data(tok, from_dt, today_dt, "day")
                            if h and len(h) >= 20:
                                rc = h[-1].get("close", 0)
                                sma = sum(x.get("close", 0) for x in h[-20:]) / 20
                                if rc > sma * 1.01:
                                    direction = "BULLISH"
                                    src_lbl = f"sma20 {rc:.1f}>{sma:.1f}"
                                elif rc < sma * 0.99:
                                    direction = "BEARISH"
                                    src_lbl = f"sma20 {rc:.1f}<{sma:.1f}"
                    except Exception as _te:
                        log.debug(f"[FIX_V33_EARNINGS] {sym} trend: {_te}")
                if not direction:
                    log.info(f"[FIX_V33_EARNINGS] {sym} skipped: no direction")
                    continue
                ivr = None
                iv_boost = 0
                try:
                    ivr = iv_tracker.iv_rank(sym)
                except Exception:
                    ivr = None
                if ivr is not None:
                    if ivr > 70:
                        log.info(f"[FIX_V33_EARNINGS] {sym} skipped: IVR={ivr:.0f}>70")
                        continue
                    if ivr < 30:
                        iv_boost = 5
                    elif ivr < 50:
                        iv_boost = 2
                score = 70 + (7 - days_to) * 3 + iv_boost
                score = min(90, max(70, score))
                out.append({
                    "symbol": sym,
                    "direction": direction,
                    "score": score,
                    "catalyst": f"EARNINGS {days_to}d dir={direction} ivr={ivr} {src_lbl}",
                    "source": "EARNINGS_TRADER_V33",
                })
                log.info(f"[FIX_V33_EARNINGS] queued {sym} {direction} score={score} days={days_to} ivr={ivr}")
        except Exception as e:
            log.error(f"[FIX_V33_EARNINGS] scan failed: {e}")
        return out

    def _fno_amo_premarket_place(self):'''

assert OLD2 in src, "Patch 2 anchor not found"
src = src.replace(OLD2, NEW2)
print("Patch 2 OK")

with open(GIR, "w") as f:
    f.write(src)
print("Wrote", GIR)
PYEOF

echo ""
echo "=== Syntax ==="
python3 -c "import ast; ast.parse(open('$GIR').read()); print('OK')" || { echo FAIL; cp "$BAK" "$GIR"; exit 1; }

echo ""
echo "=== Markers ==="
wc -l "$GIR"
grep -c FIX_V32_FNO_UNIFIED "$GIR"
grep -c FIX_V33_EARNINGS "$GIR"

echo ""
echo "=== Restart ==="
systemctl restart globaleye
sleep 3
systemctl is-active globaleye
journalctl -u globaleye --since "1 minute ago" --no-pager | tail -15
echo ""
echo "=== DONE ==="

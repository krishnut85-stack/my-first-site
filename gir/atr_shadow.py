"""atr_shadow.py — PATCH_V107_ATR_SHADOW (shadow mode only, no action)"""
from __future__ import annotations
import json
from pathlib import Path
from datetime import datetime, timedelta

CACHE_FILE = Path("/home/globalbot/atr_cache.json")
SHADOW_LOG_FILE = Path("/home/globalbot/atr_shadow_log.jsonl")

ATR_PERIOD = 14
ATR_MULTIPLIER = 2.5
CACHE_TTL_HOURS = 24


class AtrShadow:
    def __init__(self):
        self._cache = self._load_cache()
        self._inst_tokens = {}

    def _load_cache(self):
        try:
            if CACHE_FILE.exists():
                return json.loads(CACHE_FILE.read_text())
        except Exception:
            pass
        return {}

    def _save_cache(self):
        try:
            CACHE_FILE.write_text(json.dumps(self._cache, indent=2))
        except Exception as e:
            self._log_warn(f"[V107_ATR_SHADOW] cache save: {e}")

    def _log_info(self, msg):
        try:
            from __main__ import log
            log.info(msg)
        except Exception:
            print(msg)

    def _log_warn(self, msg):
        try:
            from __main__ import log
            log.warning(msg)
        except Exception:
            print(msg)

    def _get_instrument_token(self, kite, sym):
        if sym in self._inst_tokens:
            return self._inst_tokens[sym]
        try:
            from __main__ import KiteTickerStream
            tok = KiteTickerStream._sym_to_token.get(sym)
            if tok:
                self._inst_tokens[sym] = tok
                return tok
        except Exception:
            pass
        try:
            instruments = kite.instruments("NSE")
            for i in instruments:
                if i.get("tradingsymbol") == sym and i.get("instrument_type") == "EQ":
                    tok = i["instrument_token"]
                    self._inst_tokens[sym] = tok
                    return tok
        except Exception as e:
            self._log_warn(f"[V107_ATR_SHADOW] inst lookup {sym}: {e}")
        return None

    def _fetch_atr(self, kite, sym):
        try:
            rec = self._cache.get(sym)
            if rec:
                ts = datetime.fromisoformat(rec.get("fetched_at", "2000-01-01"))
                age_h = (datetime.now() - ts).total_seconds() / 3600.0
                if age_h < CACHE_TTL_HOURS:
                    return rec.get("atr")
            tok = self._get_instrument_token(kite, sym)
            if not tok:
                return None
            to_dt = datetime.now()
            from_dt = to_dt - timedelta(days=45)
            candles = kite.historical_data(tok, from_dt, to_dt, "day")
            if not candles or len(candles) < ATR_PERIOD + 1:
                return None
            trs = []
            for i in range(1, len(candles)):
                h = candles[i]["high"]
                l = candles[i]["low"]
                cp = candles[i - 1]["close"]
                tr = max(h - l, abs(h - cp), abs(l - cp))
                trs.append(tr)
            if len(trs) < ATR_PERIOD:
                return None
            atr = sum(trs[:ATR_PERIOD]) / ATR_PERIOD
            for tr in trs[ATR_PERIOD:]:
                atr = (atr * (ATR_PERIOD - 1) + tr) / ATR_PERIOD
            self._cache[sym] = {
                "atr": round(atr, 4),
                "fetched_at": datetime.now().isoformat(timespec="seconds"),
            }
            self._save_cache()
            return atr
        except Exception as e:
            self._log_warn(f"[V107_ATR_SHADOW] ATR fetch {sym}: {e}")
            return None

    def shadow_check(self, kite, sym, ltp, active_sl, active_pct, pos):
        try:
            if ltp <= 0:
                return
            atr = self._fetch_atr(kite, sym)
            if atr is None or atr <= 0:
                return
            atr_sl_distance = atr * ATR_MULTIPLIER
            atr_sl = ltp - atr_sl_distance
            avg = pos.get("entry_price", 0) or 0
            qty = pos.get("qty", 0) or 0
            unreal_pct = ((ltp - avg) / avg * 100) if avg > 0 else 0
            atr_pct = (atr_sl_distance / ltp * 100) if ltp > 0 else 0
            active_pct_eff = active_pct * 100
            active_would_fire = (active_sl >= ltp * 0.995)
            atr_would_fire = (atr_sl >= ltp * 0.995)
            delta_per_share = atr_sl - active_sl
            delta_total = delta_per_share * qty if qty > 0 else 0
            line = (
                f"[V107_ATR_SHADOW] {sym} ltp={ltp:.2f} "
                f"ACT_pct={active_pct_eff:.2f}% sl={active_sl:.2f} | "
                f"ATR14={atr:.2f} pct={atr_pct:.2f}% sl={atr_sl:.2f} | "
                f"delta_sh={delta_per_share:+.2f} delta_tot={delta_total:+.2f} | "
                f"unreal={unreal_pct:+.2f}% "
                f"act_fire={active_would_fire} atr_fire={atr_would_fire}"
            )
            self._log_info(line)
            record = {
                "ts": datetime.now().isoformat(timespec="seconds"),
                "sym": sym, "ltp": ltp,
                "active_sl": active_sl, "active_pct": active_pct_eff,
                "atr14": atr, "atr_sl": atr_sl, "atr_pct": atr_pct,
                "atr_multiplier": ATR_MULTIPLIER,
                "delta_per_share": round(delta_per_share, 4),
                "delta_total": round(delta_total, 2),
                "qty": qty, "entry_price": avg,
                "unreal_pct": round(unreal_pct, 2),
                "active_would_fire": active_would_fire,
                "atr_would_fire": atr_would_fire,
            }
            try:
                with open(SHADOW_LOG_FILE, "a") as f:
                    f.write(json.dumps(record) + "\n")
            except Exception as e:
                self._log_warn(f"[V107_ATR_SHADOW] jsonl write: {e}")
        except Exception as e:
            self._log_warn(f"[V107_ATR_SHADOW] {sym}: {e}")

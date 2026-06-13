"""Pure signal-detection logic for the Early Bird scanner.

Compares each underlying's latest option-chain snapshot against a baseline
(yesterday's last snapshot, else the first of today) and flags the classic
footprints that tend to precede large moves:

    PUT_WRITING      spot up,   PE OI building    -> bullish
    CALL_WRITING     spot down, CE OI building    -> bearish
    SHORT_COVERING   spot up,   CE OI unwinding   -> bullish
    LONG_UNWINDING   spot down, PE OI unwinding   -> bearish
    UNUSUAL_VOLUME   strike volume >> OI           -> fresh positioning

plus an IV-expansion component: the ATM straddle getting richer relative to
spot (DTE-normalized) means someone is paying up for optionality.

Snapshot format (produced by snapshot.py):
    {"ts": "...", "symbols": {SYM: {"spot": f, "dte": n, "strikes": [
        {"strike": f, "type": "CE"|"PE", "oi": n, "volume": n, "ltp": f}, ...]}}}

Everything here is pure (no I/O) so it is unit-testable and, later,
backtestable against stored snapshots.
"""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass
class DetectorConfig:
    min_oi_change_pct: float = 15.0   # OI build/unwind vs baseline to count
    spot_confirm_pct: float = 0.30    # spot move confirming direction
    vol_oi_ratio: float = 2.0         # day volume >= 2x OI on a strike = unusual
    min_strike_oi: int = 5000         # ignore vol/OI ratio on illiquid strikes
    iv_rise_pct: float = 12.0         # ATM straddle IV proxy +12% vs baseline
    min_score: int = 70               # alert threshold


def chain_stats(chain: dict) -> dict | None:
    """Aggregate one symbol's chain snapshot into comparable numbers."""
    spot = float(chain.get("spot") or 0)
    strikes = chain.get("strikes") or []
    if spot <= 0 or not strikes:
        return None
    ce = [s for s in strikes if s["type"] == "CE"]
    pe = [s for s in strikes if s["type"] == "PE"]
    if not ce or not pe:
        return None

    atm_strike = min({s["strike"] for s in strikes}, key=lambda k: abs(k - spot))
    atm_ce = next((s["ltp"] for s in ce if s["strike"] == atm_strike), 0.0)
    atm_pe = next((s["ltp"] for s in pe if s["strike"] == atm_strike), 0.0)
    dte = max(int(chain.get("dte") or 1), 1)
    straddle = float(atm_ce or 0) + float(atm_pe or 0)
    # DTE-normalized so theta decay doesn't read as an IV change
    iv_proxy = straddle / spot / math.sqrt(dte / 252.0) if straddle > 0 else 0.0

    return {
        "spot": spot,
        "ce_oi": sum(int(s["oi"] or 0) for s in ce),
        "pe_oi": sum(int(s["oi"] or 0) for s in pe),
        "iv_proxy": iv_proxy,
    }


def max_vol_oi_ratio(chain: dict, min_oi: int) -> float:
    best = 0.0
    for s in chain.get("strikes") or []:
        oi = int(s["oi"] or 0)
        if oi >= min_oi:
            best = max(best, int(s["volume"] or 0) / oi)
    return best


def _pct(now: float, then: float) -> float:
    return (now - then) / then * 100.0 if then > 0 else 0.0


def detect(baseline: dict | None, latest: dict,
           cfg: DetectorConfig | None = None) -> list[dict]:
    """Return signal dicts for symbols whose flow looks pre-explosive."""
    cfg = cfg or DetectorConfig()
    if not baseline:
        return []
    signals = []
    base_syms = baseline.get("symbols", {})
    for sym, chain in latest.get("symbols", {}).items():
        prev_chain = base_syms.get(sym)
        if not prev_chain:
            continue
        now, then = chain_stats(chain), chain_stats(prev_chain)
        if not now or not then:
            continue

        spot_chg = _pct(now["spot"], then["spot"])
        ce_chg = _pct(now["ce_oi"], then["ce_oi"])
        pe_chg = _pct(now["pe_oi"], then["pe_oi"])
        iv_chg = _pct(now["iv_proxy"], then["iv_proxy"])
        ratio = max_vol_oi_ratio(chain, cfg.min_strike_oi)

        pattern = direction = None
        score = 0.0
        if spot_chg > cfg.spot_confirm_pct and pe_chg > cfg.min_oi_change_pct:
            pattern, direction, score = "PUT_WRITING", "BULLISH", 60 + min(pe_chg / 2, 20)
        elif spot_chg < -cfg.spot_confirm_pct and ce_chg > cfg.min_oi_change_pct:
            pattern, direction, score = "CALL_WRITING", "BEARISH", 60 + min(ce_chg / 2, 20)
        elif spot_chg > cfg.spot_confirm_pct and ce_chg < -cfg.min_oi_change_pct:
            pattern, direction, score = "SHORT_COVERING", "BULLISH", 55 + min(-ce_chg / 2, 20)
        elif spot_chg < -cfg.spot_confirm_pct and pe_chg < -cfg.min_oi_change_pct:
            pattern, direction, score = "LONG_UNWINDING", "BEARISH", 55 + min(-pe_chg / 2, 20)
        elif ratio >= cfg.vol_oi_ratio:
            # fresh positioning without a clean OI pattern yet
            pattern = "UNUSUAL_VOLUME"
            direction = ("BULLISH" if spot_chg > 0.15
                         else "BEARISH" if spot_chg < -0.15 else "WATCH")
            score = 50 + min(ratio * 5, 25)

        if not pattern:
            continue
        if ratio >= cfg.vol_oi_ratio and pattern != "UNUSUAL_VOLUME":
            score += 10
        if iv_chg >= cfg.iv_rise_pct:
            score += min(iv_chg, 15)
        score = round(min(score, 95))
        if score < cfg.min_score:
            continue

        signals.append({
            "symbol": sym,
            "direction": direction,
            "pattern": pattern,
            "score": score,
            "spot": now["spot"],
            "detail": (f"spot {spot_chg:+.2f}% CE_OI {ce_chg:+.0f}% "
                       f"PE_OI {pe_chg:+.0f}% IV {iv_chg:+.0f}% volOI {ratio:.1f}x"),
        })
    signals.sort(key=lambda s: -s["score"])
    return signals

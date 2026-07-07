"""Options income (Iron Condor) — the genuine 80%+ win-rate path, tested honestly.

An Iron Condor sells an out-of-the-money call spread AND an out-of-the-money put
spread on an index (Nifty / Bank Nifty). It WINS when the index stays between the
two short strikes at expiry — which, on a weekly horizon, it does most of the
time. That's the structural high win rate the equity books can't reach.

Two numbers matter, and we separate them honestly:
  • WIN RATE — is DATA: the % of weeks the index stayed within +/- dist. Computed
    straight from the index's own history. No modelling.
  • EXPECTANCY — needs the CREDIT collected, which depends on implied vol. We
    model it as `credit_frac` of the wing width (a typical ~15-delta condor
    collects ~25-35% of the wing) and FLAG it as an assumption. The payoff at
    expiry is then the exact Iron Condor payoff.

    python3 -m garuda.options --fetch                 # pull Nifty + Bank Nifty history
    python3 -m garuda.options --condor --csv nifty_daily.csv

PAPER / research only. Trading this as an NRI needs a custodial CP-code NRO F&O
account — this module never places an order.
"""

import csv
import sys
from datetime import date, timedelta

from . import config


def fetch_index_daily(name="NIFTY 50", days=1200, out=None) -> str:
    """Fetch an NSE INDEX's daily closes (symbol,date,close) via Kite. Run on the
    droplet. `name` is the Kite tradingsymbol, e.g. 'NIFTY 50' / 'NIFTY BANK'."""
    out = out or (name.split()[-1].lower() + "_daily.csv")
    try:
        from kiteconnect import KiteConnect  # type: ignore
    except ImportError:
        raise SystemExit("kiteconnect not installed — pip3 install kiteconnect")
    import os
    from .fetch_bars import _resolve_token
    key = os.environ.get("KITE_API_KEY", "")
    tok = _resolve_token()
    if not key or not tok:
        raise SystemExit("KITE_API_KEY / token not set (source /home/globalbot/.env)")
    kite = KiteConnect(api_key=key)
    kite.set_access_token(tok)
    token = None
    for inst in kite.instruments("NSE"):
        if inst.get("tradingsymbol") == name and inst.get("segment") in ("INDICES", "NSE"):
            token = inst["instrument_token"]
            break
    if not token:
        raise SystemExit(f"index '{name}' not found in NSE instruments")
    frm = date.today() - timedelta(days=days)
    data = kite.historical_data(token, frm, date.today(), "day")
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["symbol", "date", "close"])
        for d in data:
            w.writerow([name, d["date"].date().isoformat(), d["close"]])
    print(f"Wrote {len(data)} days -> {out}")
    return out


def backtest_condor(closes, dist, wing, credit_frac, horizon=5):
    """One weekly Iron Condor per `horizon` bars. Short strikes at +/-dist from
    spot, long wings `wing` beyond them (both as fractions of spot). Returns each
    week's net P&L as a fraction of spot (credit modelled as credit_frac*wing)."""
    trades, i, n = [], 0, len(closes)
    while i + horizon < n:
        spot = closes[i]
        exp = closes[i + horizon]
        if spot <= 0:
            i += horizon
            continue
        sc, sp = spot * (1 + dist), spot * (1 - dist)     # short call / short put
        w = spot * wing                                    # wing width (points)
        credit = credit_frac * w
        if exp >= sc:                                      # call side breached
            net = credit - min(exp - sc, w)
        elif exp <= sp:                                    # put side breached
            net = credit - min(sp - exp, w)
        else:                                              # stayed inside -> full credit
            net = credit
        trades.append(net / spot)
        i += horizon
    return trades


def _condor_stats(trades):
    if not trades:
        return None
    import statistics
    wins = [t for t in trades if t > 0]
    gl = -sum(t for t in trades if t <= 0)
    return {
        "weeks": len(trades),
        "win": len(wins) / len(trades) * 100,
        "avg_wk": statistics.mean(trades) * 100,          # % of spot per week
        "annual": statistics.mean(trades) * 50 * 100,      # ~50 weekly cycles/yr
        "worst": min(trades) * 100,
        "pf": (sum(wins) / gl) if gl > 0 else None,
    }


def compare_condor(closes, wing=0.01, credit_frac=0.30, horizon=5,
                   dists=(0.010, 0.015, 0.020, 0.025, 0.030)):
    """Sweep how far OTM the short strikes sit — closer = more credit but lower
    win%, further = higher win% but less credit. Which distance is best?"""
    return {f"+/-{d*100:.1f}% strikes": _condor_stats(
        backtest_condor(closes, d, wing, credit_frac, horizon)) for d in dists}


def format_condor(res, source, wing, credit_frac):
    ranked = sorted(res.items(), key=lambda kv: (kv[1]["win"] if kv[1] else -9), reverse=True)
    lines = ["=" * 82,
             f"  {config.BOT_NAME} · IRON CONDOR   (weekly · defined-risk index option selling)",
             f"  Data: {source}   ·   wing={wing*100:.1f}% of spot   ·   credit≈{credit_frac*100:.0f}% of wing (ASSUMED)",
             "=" * 82,
             f"  {'short strikes':<18}{'win%':>6}{'%/week':>9}{'~annual':>10}{'worst wk':>10}{'PF':>7}{'weeks':>7}",
             "-" * 82]
    for name, s in ranked:
        if not s:
            continue
        lines.append(f"  {name:<18}{s['win']:>5.0f}%{s['avg_wk']:>+8.2f}%{s['annual']:>+9.1f}%"
                     f"{s['worst']:>+9.1f}%{(s['pf'] or 0):>7.2f}{s['weeks']:>7}")
    lines += ["-" * 82,
              "  WIN% is DATA (how often the index stayed inside the strikes). %/week & annual assume the",
              f"  credit model above — validate against real option premiums before trusting the P&L.",
              "  Further-OTM strikes = higher win% but thinner credit; the sweet spot is the best %/week.",
              "=" * 82]
    return "\n".join(lines)


def _load_closes(path):
    from .cross import load_series
    series = load_series(path)
    # index CSV has a single symbol; take its close series
    return next(iter(series.values())) if series else []


def _next_thursday(d):
    """NSE Nifty weekly expiry is Thursday. Next Thursday strictly after d."""
    ahead = (3 - d.weekday()) % 7 or 7
    return d + timedelta(days=ahead)


class OptionsBook:
    """PAPER weekly Iron Condor on an index. Opens a condor at +/-dist strikes,
    holds to Thursday expiry, settles P&L, rolls into the next week. Sizes each
    week to risk `alloc_pct` of capital (max loss = one week's risk). Persistent.

    P&L uses the same transparent credit model as the backtest — to be replaced
    with real option premiums once the live option chain is wired in."""

    def __init__(self, capital=1_000_000.0, dist=0.025, wing=0.01, credit_frac=0.30,
                 alloc_pct=0.02, index="NIFTY 50", realized=0.0, condor=None,
                 history=None, trades=None):
        self.capital = capital
        self.starting_capital = capital
        self.dist = dist
        self.wing = wing
        self.credit_frac = credit_frac
        self.alloc_pct = alloc_pct
        self.index = index
        self.realized = realized
        self.condor = condor          # {strikes, credit_frac_spot, entry_spot, entry_date, expiry, risk}
        self.history = history or []   # [{date, equity}]
        self.trades = trades or []

    @classmethod
    def load(cls, path, **kw):
        import json
        from pathlib import Path
        p = Path(path)
        if p.exists():
            d = json.loads(p.read_text())
            d.update(kw)               # allow config (dist/wing/...) to override saved
            return cls(**d)
        return cls(**kw)

    def save(self, path):
        import json
        from pathlib import Path
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(json.dumps({
            "capital": self.starting_capital, "dist": self.dist, "wing": self.wing,
            "credit_frac": self.credit_frac, "alloc_pct": self.alloc_pct,
            "index": self.index, "realized": self.realized, "condor": self.condor,
            "history": self.history[-800:], "trades": self.trades[-500:],
        }, indent=2))

    @property
    def _max_loss_frac(self):
        return self.wing - self.credit_frac * self.wing      # e.g. 1% - 0.3% = 0.7% of spot

    def _net_frac(self, spot_now):
        """This week's Iron Condor payoff as a fraction of spot, if it settled at
        spot_now (credit modelled)."""
        c = self.condor
        credit = c["credit_frac_spot"]
        sc, sp = c["strikes"]["sc"], c["strikes"]["sp"]
        w = self.wing * c["entry_spot"]
        if spot_now >= sc:
            net = credit * c["entry_spot"] - min(spot_now - sc, w)
        elif spot_now <= sp:
            net = credit * c["entry_spot"] - min(sp - spot_now, w)
        else:
            net = credit * c["entry_spot"]
        return net / c["entry_spot"]

    def _pnl_rupees(self, net_frac):
        return net_frac / self._max_loss_frac * (self.starting_capital * self.alloc_pct)

    def _open(self, spot, today):
        cf_spot = self.credit_frac * self.wing
        self.condor = {
            "strikes": {"sp": round(spot * (1 - self.dist), 1), "lp": round(spot * (1 - self.dist - self.wing), 1),
                        "sc": round(spot * (1 + self.dist), 1), "lc": round(spot * (1 + self.dist + self.wing), 1)},
            "credit_frac_spot": cf_spot, "entry_spot": spot,
            "entry_date": today.isoformat(), "expiry": _next_thursday(today).isoformat(),
            "risk": round(self.starting_capital * self.alloc_pct, 0),
        }
        self.trades.append({"date": today.isoformat(), "side": "OPEN", "spot": round(spot, 1),
                            "expiry": self.condor["expiry"]})

    def _settle(self, spot, today):
        pnl = self._pnl_rupees(self._net_frac(spot))
        self.realized += pnl
        self.trades.append({"date": today.isoformat(), "side": "SETTLE",
                            "spot": round(spot, 1), "pnl": round(pnl, 0)})
        self.condor = None

    def step(self, spot, today, market_open):
        """Advance the weekly cycle: settle at/after expiry, (re)open when flat."""
        if not market_open or not spot or spot <= 0:
            return
        if self.condor and today.isoformat() >= self.condor["expiry"]:
            self._settle(spot, today)
        if self.condor is None:
            self._open(spot, today)

    def state(self, spot):
        """Dashboard view: current condor + live mark + equity."""
        unreal = self._pnl_rupees(self._net_frac(spot)) if (self.condor and spot > 0) else 0.0
        equity = self.starting_capital + self.realized + unreal
        c = self.condor
        in_range = bool(c and spot and c["strikes"]["sp"] < spot < c["strikes"]["sc"])
        from datetime import date as _d
        dte = None
        if c:
            y, m, dd = (int(x) for x in c["expiry"].split("-"))
            dte = (_d(y, m, dd) - _d.today()).days
        return {
            "index": self.index, "spot": round(spot, 1) if spot else None,
            "strikes": c["strikes"] if c else None, "expiry": c["expiry"] if c else None,
            "dte": dte, "in_range": in_range,
            "credit_rs": round(self._credit_frac_to_rs(), 0) if c else None,
            "max_loss_rs": round(self.starting_capital * self.alloc_pct, 0) if c else None,
            "unrealized": round(unreal, 0), "realized": round(self.realized, 0),
            "equity": round(equity, 0),
            "pnl_pct": round((equity / self.starting_capital - 1) * 100, 2),
        }

    def _credit_frac_to_rs(self):
        # reward at a full win = (credit / max_loss) * risk
        return (self.credit_frac * self.wing) / self._max_loss_frac * (self.starting_capital * self.alloc_pct)


def main():
    args = sys.argv[1:]
    if "--fetch" in args:
        fetch_index_daily("NIFTY 50", out="nifty_daily.csv")
        fetch_index_daily("NIFTY BANK", out="banknifty_daily.csv")
        return
    if "--condor" in args:
        path = args[args.index("--csv") + 1] if "--csv" in args else "nifty_daily.csv"
        wing = float(args[args.index("--wing") + 1]) if "--wing" in args else 0.01
        cf = float(args[args.index("--credit") + 1]) if "--credit" in args else 0.30
        closes = _load_closes(path)
        if len(closes) < 60:
            raise SystemExit(f"need an index daily CSV — got {len(closes)} closes from {path}")
        print(format_condor(compare_condor(closes, wing, cf), f"{path} ({len(closes)} days)", wing, cf))
        return
    print("usage: python3 -m garuda.options --fetch | --condor [--csv nifty_daily.csv] "
          "[--wing 0.01] [--credit 0.30]")


if __name__ == "__main__":
    main()

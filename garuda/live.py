"""Garuda live orchestrator — ties the scanner, portfolios and Kite feed together
and produces the JSON state the dashboard renders.

PAPER ONLY. It updates the paper portfolios and prices them at live LTP; it
never places a real order.
"""

from pathlib import Path

from . import config
from .cross import load_series
from .feed import KiteFeed
from .portfolio import LivePortfolio
from .scan import run_scan
from .setups import rsi
from .strategy import PROFILES


def _pf_path(key):
    return config.DATA_DIR / f"garuda_{key}_portfolio.json"


class GarudaLive:
    def __init__(self, csv_dir="."):
        self.csv_dir = Path(csv_dir)
        self.feed = KiteFeed()
        self.portfolios = {k: LivePortfolio.load(_pf_path(k), p.capital)
                           for k, p in PROFILES.items()}
        self.prices = {}      # symbol -> live ltp
        self.charts = {}      # symbol -> {candles, rsi, buy_i, sell_i}
        self.last_signals = {k: {"buys": [], "sells": []} for k in PROFILES}
        # Every symbol's daily closes from the local CSVs — the guaranteed chart
        # source when Kite's historical API isn't available for a name.
        self.series_by_sym = {}
        for prof in PROFILES.values():
            for s, c in self._series(prof).items():
                self.series_by_sym.setdefault(s, c)

    # --- data ---------------------------------------------------------------
    def _series(self, profile):
        p = self.csv_dir / profile.daily_csv
        return load_series(p) if p.exists() else {}

    def held_symbols(self):
        out = set()
        for pf in self.portfolios.values():
            out.update(pf.holdings)
        return out

    # --- daily scan ---------------------------------------------------------
    def scan(self):
        results = {}
        for k, prof in PROFILES.items():
            series = self._series(prof)
            if not series:
                results[k] = {"error": f"{prof.daily_csv} not found in {self.csv_dir}"}
                continue
            res = run_scan(prof, series, self.portfolios[k])
            self.portfolios[k].save(_pf_path(k))
            self.last_signals[k] = {"buys": [b["symbol"] for b in res["buys"]],
                                    "sells": [s["symbol"] for s in res["sells"]]}
            results[k] = res
        return results

    # --- live price refresh (call on a timer) ------------------------------
    def refresh_prices(self):
        syms = list(self.held_symbols())
        if syms:
            self.prices.update(self.feed.ltp(syms))

    def chart_for(self, symbol):
        """On-demand chart for any symbol (used when a row is clicked)."""
        if symbol and symbol not in self.charts:
            self.refresh_chart(symbol)
        return self.charts.get(symbol)

    def _candles_from_series(self, symbol, days=60):
        """Synthesise daily candles from the local CSV closes so every symbol
        renders a chart even when Kite has no history for it. Each bar's body
        spans yesterday's close -> today's close."""
        closes = self.series_by_sym.get(symbol)
        if not closes:
            return []
        closes = closes[-days:]
        out, prev = [], closes[0]
        for c in closes:
            out.append({"o": round(prev, 2), "h": round(max(prev, c), 2),
                        "l": round(min(prev, c), 2), "c": round(c, 2)})
            prev = c
        return out

    def refresh_chart(self, symbol):
        """Cache daily candles + RSI-2 + entry/exit markers for one symbol.
        Prefers real Kite OHLC; falls back to local-CSV closes so the chart
        always draws."""
        candles = self.feed.ohlc_daily(symbol, 60) or self._candles_from_series(symbol, 60)
        if not candles:
            return
        closes = [c["c"] for c in candles]
        r = rsi(closes, 2)
        buy_i = next((i for i, v in enumerate(r) if i > 5 and v is not None and v < 8), None)
        sell_i = None
        if buy_i is not None:
            sell_i = next((i for i in range(buy_i + 1, len(r))
                           if r[i] is not None and r[i] > 85), None)
        self.charts[symbol] = {
            "candles": candles,
            "rsi": [round(v, 1) if v is not None else None for v in r],
            "buy_i": buy_i, "sell_i": sell_i,
        }

    # --- state for the dashboard -------------------------------------------
    def price_of(self, sym, fallback=0.0):
        return self.prices.get(sym) or fallback

    def build_state(self):
        profs = []
        for k, prof in PROFILES.items():
            pf = self.portfolios[k]
            positions = []
            day_pnl = 0.0
            for s, h in pf.holdings.items():
                ltp = self.price_of(s, h["entry_price"])
                chg = (ltp - h["entry_price"]) / h["entry_price"] * 100 if h["entry_price"] else 0
                pnl = (ltp - h["entry_price"]) * h["qty"]
                day_pnl += pnl
                positions.append({"sym": s, "qty": h["qty"],
                                  "entry": round(h["entry_price"], 2), "ltp": round(ltp, 2),
                                  "chg": round(chg, 2), "pnl": round(pnl, 0),
                                  "rsi2": h.get("rsi2_entry")})
            positions.sort(key=lambda x: x["pnl"], reverse=True)
            equity = pf.equity(lambda s: self.price_of(s, pf.holdings.get(s, {}).get("entry_price", 0)))
            win, pfac = _live_stats(pf)
            win_kind = "closed"
            if win is None and positions:      # no closed trades yet -> live win rate
                green = sum(1 for x in positions if x["pnl"] > 0)
                win, win_kind = round(green / len(positions) * 100), "open"
            chart_sym = positions[0]["sym"] if positions else None
            best = positions[0] if positions else None
            worst = positions[-1] if positions else None
            profs.append({
                "best": best, "worst": worst,
                "key": k, "name": prof.name, "desc": prof.daily_csv.replace("_daily.csv", ""),
                "capital": pf.starting_capital, "equity": round(equity, 0),
                "pnl_pct": round((equity / pf.starting_capital - 1) * 100, 2),
                "day_pnl": round(day_pnl, 0), "positions": positions,
                "win": win, "win_kind": win_kind, "pf": pfac, "cash": round(pf.cash, 0),
                "buys": self.last_signals[k]["buys"], "sells": self.last_signals[k]["sells"],
                "chart_sym": chart_sym, "chart": self.charts.get(chart_sym),
            })
        totals = {
            "equity": round(sum(p["equity"] for p in profs), 0),
            "capital": round(sum(p["capital"] for p in profs), 0),
            "day_pnl": round(sum(p["day_pnl"] for p in profs), 0),
            "positions": sum(len(p["positions"]) for p in profs),
        }
        totals["pnl_pct"] = round((totals["equity"] / totals["capital"] - 1) * 100, 2) \
            if totals["capital"] else 0.0
        # combined equity curve (P&L chart) — sum both portfolios by scan index
        hs = self.portfolios["smallcap"].history
        hm = self.portfolios["microcap"].history
        n = min(len(hs), len(hm))
        totals["curve"] = [round(hs[i]["equity"] + hm[i]["equity"], 0) for i in range(n)]
        return {"live": self.feed.live, "profiles": profs, "totals": totals}


def _live_stats(pf):
    closed = [t for t in pf.trades if t.get("side") == "SELL" and "pnl" in t]
    if len(closed) < 5:
        return (None, None)
    wins = [t["pnl"] for t in closed if t["pnl"] > 0]
    gl = -sum(t["pnl"] for t in closed if t["pnl"] <= 0)
    return (round(len(wins) / len(closed) * 100), round(sum(wins) / gl, 2) if gl > 0 else None)

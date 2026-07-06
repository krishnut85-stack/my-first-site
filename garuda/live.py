"""Garuda live orchestrator — ties the scanner, portfolios and Kite feed together
and produces the JSON state the dashboard renders.

PAPER ONLY. It updates the paper portfolios and prices them at live LTP; it
never places a real order.
"""

from pathlib import Path

from . import config
from .cross import load_series
from .feed import KiteFeed
from .market import is_market_open, market_status
from .portfolio import LivePortfolio, _today
from .scan import run_scan
from .setups import rsi, sma
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
        self.day_ohlc = {}    # symbol -> {o,h,l,pc,ltp} today (for the live candle)
        self.charts = {}      # symbol -> {candles, rsi, markers}
        self.last_signals = {k: {"buys": [], "sells": []} for k in PROFILES}
        self.last_scan_date = None    # IST date of the last executed scan (once/session)
        self.intraday = []            # today's live combined-equity samples (P&L curve)
        self.intraday_day = None
        # Every symbol's dated daily closes from the local CSVs — the guaranteed
        # chart source when Kite's historical API isn't available for a name.
        from .cross import _load_long
        self.series_by_sym = {}     # sym -> [closes]
        self.dated_by_sym = {}      # sym -> [(date, close)] sorted by date
        self.universe = {}          # per-profile symbol list (for search/preview)
        for k, prof in PROFILES.items():
            path = self._csv_path(prof)
            long = _load_long(path) if path else {}
            for sym, dv in long.items():
                items = sorted(dv.items())
                self.dated_by_sym.setdefault(sym, items)
                self.series_by_sym.setdefault(sym, [c for _, c in items])
            self.universe[k] = sorted(long.keys())
            print(f"[garuda] {k}: loaded {len(long)} symbols for charts "
                  f"({prof.daily_csv})", flush=True)
        # Pre-compute each stock's latest RSI-2 (daily bars, so it's static
        # intraday) for the live market-watch list.
        self.rsi_by_sym = {}
        for sym, closes in self.series_by_sym.items():
            r = rsi(closes, 2) if len(closes) > 2 else []
            self.rsi_by_sym[sym] = round(r[-1], 1) if r and r[-1] is not None else None
        # optional market caps (₹ crore) from marketcap.csv (symbol,marketcap)
        self.mcap_by_sym = self._load_mcap()

    def _load_mcap(self):
        import csv as _csv
        for base in (self.csv_dir, Path.cwd(), config.BASE_DIR, config.BASE_DIR.parent):
            p = Path(base) / "marketcap.csv"
            if p.exists():
                out = {}
                try:
                    with open(p, newline="", encoding="utf-8") as f:
                        for row in _csv.DictReader(f):
                            s = row.get("symbol") or row.get("Symbol")
                            m = row.get("marketcap") or row.get("mcap") or row.get("MarketCap")
                            if s and m:
                                try:
                                    out[s.strip()] = float(str(m).replace(",", ""))
                                except ValueError:
                                    pass
                    print(f"[garuda] loaded {len(out)} market caps ({p.name})", flush=True)
                    return out
                except Exception:  # noqa: BLE001
                    pass
        return {}

    # --- data ---------------------------------------------------------------
    def _csv_path(self, profile):
        # Look in the given csv-dir first, then the usual repo locations, so the
        # chart data loads even if --csv-dir points somewhere the CSV isn't.
        for base in (self.csv_dir, Path.cwd(), config.BASE_DIR, config.BASE_DIR.parent):
            p = Path(base) / profile.daily_csv
            if p.exists():
                return p
        return None

    def _series(self, profile):
        p = self._csv_path(profile)
        return load_series(p) if p else {}

    def held_symbols(self):
        out = set()
        for pf in self.portfolios.values():
            out.update(pf.holdings)
        return out

    def all_symbols(self):
        out = set()
        for syms in self.universe.values():
            out.update(syms)
        return out

    @property
    def streaming(self):
        return self.feed.streaming

    def start_stream(self):
        """Begin real-time websocket streaming for the whole universe. Ticks
        update live prices + today's OHLC as they arrive (no polling/rate limit)."""
        def on_update(sym, ltp, ohlc):
            if ltp:
                self.prices[sym] = ltp
            if ohlc:
                self.day_ohlc[sym] = {"o": ohlc.get("open"), "h": ohlc.get("high"),
                                      "l": ohlc.get("low"), "pc": ohlc.get("close"),
                                      "ltp": ltp}
        return self.feed.start_stream(sorted(self.all_symbols()), on_update)

    # --- daily scan ---------------------------------------------------------
    def scan(self, force=False):
        """Book the day's exits + entries. PAPER, but timed like live trading:
        it only transacts while the market is open, and fills at the live price
        — never on a weekend/holiday or outside 09:15-15:30 IST. Pass force=True
        to override (e.g. a manual backfill)."""
        if not force and not is_market_open():
            return {k: {"status": f"no trades — market {market_status().lower()}"}
                    for k in PROFILES}
        self.refresh_prices()          # fill entries/exits at the live price
        results = {}
        for k, prof in PROFILES.items():
            series = self._series(prof)
            if not series:
                results[k] = {"error": f"{prof.daily_csv} not found in {self.csv_dir}"}
                continue
            res = run_scan(prof, series, self.portfolios[k], live_prices=self.prices)
            self.portfolios[k].save(_pf_path(k))
            self.last_signals[k] = {"buys": [b["symbol"] for b in res["buys"]],
                                    "sells": [s["symbol"] for s in res["sells"]]}
            results[k] = res
        self.last_scan_date = _today()
        return results

    def maybe_scan(self):
        """Auto-run the scan once per trading session, the moment the market is
        open — so entries/exits appear live, not pre-booked on a closed market."""
        if is_market_open() and self.last_scan_date != _today():
            print(f"[garuda] market open — running the daily scan ({_today()})", flush=True)
            return self.scan()
        return None

    # --- live price refresh (call on a timer) ------------------------------
    def refresh_prices(self, full=False):
        """Price held names every tick; the whole universe on a slower cadence
        (full=True) so every stock shows a live Kite LTP like a market-watch.
        Uses ohlc() so we also get today's open/high/low for a live candle."""
        syms = sorted(self.all_symbols() | self.held_symbols()) if full \
            else list(self.held_symbols())
        if not syms:
            return
        q = self.feed.ohlc_quote(syms)
        if q:
            for s, d in q.items():
                if d.get("ltp"):
                    self.prices[s] = d["ltp"]
                self.day_ohlc[s] = d
        else:                                  # no quote access -> plain LTP
            self.prices.update(self.feed.ltp(syms))

    def live_equity(self):
        """Current combined equity across both paper books at live prices."""
        return sum(pf.equity(lambda s: self.price_of(s, pf.holdings.get(s, {}).get("entry_price", 0)))
                   for pf in self.portfolios.values())

    def snapshot_equity(self):
        """Append a live combined-equity sample for today's intraday P&L curve
        (resets each new day). Only samples while the market is open."""
        if not is_market_open():
            return
        today = _today()
        if self.intraday_day != today:
            self.intraday_day = today
            self.intraday = []
        self.intraday.append(round(self.live_equity(), 0))
        self.intraday = self.intraday[-600:]

    def chart_for(self, symbol):
        """On-demand chart for any symbol (used when a row is clicked)."""
        if symbol and symbol not in self.charts:
            self.refresh_chart(symbol)
        return self.charts.get(symbol)

    def _candles_from_series(self, symbol, days=300):
        """Synthesise dated daily candles from the local CSV closes so every
        symbol renders a chart even when Kite has no history for it. Each bar's
        body spans yesterday's close -> today's close."""
        dated = self.dated_by_sym.get(symbol)
        if not dated:
            return []
        dated = dated[-days:]
        out, prev = [], dated[0][1]
        for dt, c in dated:
            out.append({"t": dt, "o": round(prev, 2), "h": round(max(prev, c), 2),
                        "l": round(min(prev, c), 2), "c": round(c, 2)})
            prev = c
        return out

    def refresh_chart(self, symbol):
        """Cache ~1yr of daily candles + RSI-2 + all oversold/overbought signal
        markers for one symbol. Prefers real Kite OHLC; falls back to local-CSV
        closes so the chart always draws."""
        candles = self.feed.ohlc_daily(symbol, 300) or self._candles_from_series(symbol, 300)
        if not candles:
            print(f"[garuda] no chart data for {symbol} "
                  f"(kite+csv both empty; in csv={symbol in self.dated_by_sym})",
                  flush=True)
            return
        closes = [c["c"] for c in candles]
        r = rsi(closes, 2)
        ma20, ma50 = sma(closes, 20), sma(closes, 50)
        markers, prev = [], None
        for i, v in enumerate(r):
            if v is None:
                continue
            if v < 5 and (prev is None or prev >= 5):        # crossed into oversold
                markers.append({"t": candles[i]["t"], "type": "buy"})
            elif v > 85 and (prev is None or prev <= 85):    # crossed into overbought
                markers.append({"t": candles[i]["t"], "type": "sell"})
            prev = v
        self.charts[symbol] = {
            "candles": candles,
            "rsi": [round(v, 1) if v is not None else None for v in r],
            "ma20": [round(v, 2) if v is not None else None for v in ma20],
            "ma50": [round(v, 2) if v is not None else None for v in ma50],
            "markers": markers,
        }

    # --- state for the dashboard -------------------------------------------
    def price_of(self, sym, fallback=0.0):
        return self.prices.get(sym) or fallback

    def build_state(self):
        profs = []
        mkt_open = is_market_open()
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
                                  "rsi2": h.get("rsi2_entry"), "mom": h.get("mom"),
                                  "peak": round(h["peak"], 2) if h.get("peak") else None})
            positions.sort(key=lambda x: x["pnl"], reverse=True)
            # market-watch: every universe stock with a live LTP + day change
            watch = []
            for sym in self.universe.get(k, []):
                closes = self.series_by_sym.get(sym)
                o = self.day_ohlc.get(sym, {})
                prev_close = o.get("pc") or (closes[-1] if closes else 0.0)
                ltp = self.price_of(sym, prev_close)
                chg = (ltp - prev_close) / prev_close * 100 if prev_close else 0.0
                cl = closes or []

                def _cb(n, _cl=cl, _ltp=ltp):
                    return round((_ltp - _cl[-n]) / _cl[-n] * 100, 2) \
                        if len(_cl) >= n and _cl[-n] > 0 else None
                win = cl[-252:]
                # live provisional RSI-2 (current price as today's close) while open
                if mkt_open and cl:
                    lr = rsi(cl[-25:] + [ltp], 2)
                    rsi2 = round(lr[-1], 1) if lr and lr[-1] is not None else self.rsi_by_sym.get(sym)
                else:
                    rsi2 = self.rsi_by_sym.get(sym)
                h = pf.holdings.get(sym)
                watch.append({
                    "sym": sym, "ltp": round(ltp, 2), "chg": round(chg, 2),
                    "chg_w": _cb(5), "chg_m": _cb(21),
                    "hi52": round(max(win), 2) if win else None,
                    "lo52": round(min(win), 2) if win else None,
                    "mcap": self.mcap_by_sym.get(sym),
                    "rsi2": rsi2, "held": bool(h),
                    "qty": h["qty"] if h else None,
                    "pnl": round((ltp - h["entry_price"]) * h["qty"], 0) if h else None,
                    "o": o.get("o"), "h": o.get("h"), "l": o.get("l"),   # today, for the live candle
                })
            equity = pf.equity(lambda s: self.price_of(s, pf.holdings.get(s, {}).get("entry_price", 0)))
            win, pfac = _live_stats(pf)
            win_kind = "live"
            if win is None:                    # no closed live trades yet
                win, win_kind = prof.proven_win, "backtest"
            green = sum(1 for x in positions if x["pnl"] > 0)
            win_open = round(green / len(positions) * 100) if positions else None
            chart_sym = positions[0]["sym"] if positions else None
            best = positions[0] if positions else None
            worst = positions[-1] if positions else None
            profs.append({
                "best": best, "worst": worst,
                "key": k, "name": prof.name, "desc": prof.daily_csv.replace("_daily.csv", ""),
                "strategy": prof.strategy, "label": prof.label,
                "capital": pf.starting_capital, "equity": round(equity, 0),
                "pnl_pct": round((equity / pf.starting_capital - 1) * 100, 2),
                "day_pnl": round(day_pnl, 0), "positions": positions,
                "win": win, "win_kind": win_kind, "win_open": win_open,
                "proven_win": prof.proven_win, "proven_ret": prof.proven_ret,
                "proven_pf": prof.proven_pf,
                "universe": self.universe.get(k, []), "watch": watch,
                "pf": pfac, "cash": round(pf.cash, 0),
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
        histories = [pf.history for pf in self.portfolios.values()]
        n = min((len(h) for h in histories), default=0)
        daily = [round(sum(h[i]["equity"] for h in histories), 0) for i in range(n)]
        # daily track record + today's live intraday samples + the current tip
        totals["curve"] = daily + self.intraday + [totals["equity"]]
        return {"live": self.feed.live, "profiles": profs, "totals": totals,
                "market_open": is_market_open(), "market_status": market_status(),
                "last_scan": self.last_scan_date, "today": _today()}


def _live_stats(pf):
    closed = [t for t in pf.trades if t.get("side") == "SELL" and "pnl" in t]
    if len(closed) < 5:
        return (None, None)
    wins = [t["pnl"] for t in closed if t["pnl"] > 0]
    gl = -sum(t["pnl"] for t in closed if t["pnl"] <= 0)
    return (round(len(wins) / len(closed) * 100), round(sum(wins) / gl, 2) if gl > 0 else None)

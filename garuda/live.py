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
from .options import OptionsBook
from .portfolio import LivePortfolio, _today
from .scan import run_scan
from .setups import rsi, sma
from .strategy import PROFILES

# The 7th "book" is a weekly Iron Condor on the Nifty — index option selling,
# not a stock scanner, so it lives outside PROFILES and renders in its own tab.
OPTIONS_LABEL = "Iron Condor · Nifty weekly · ±2.5% · defined-risk"
OPTIONS_RULES = ("Sell ±2.5% call & put spreads (1% wings) on the Nifty every week; "
                 "win if the index expires between the short strikes. Loss is capped "
                 "at one week's risk (2% of book) — no blow-ups.")
OPTIONS_WIN = 89.0        # backtested: Nifty stayed inside ±2.5% ~89% of weeks


def _pf_path(key):
    return config.DATA_DIR / f"garuda_{key}_portfolio.json"


def _stop_price(prof, h):
    """The binding stop price for a held share — the HIGHEST (closest) of the
    book's floors: a hard stop / catastrophe stop below entry, and the trailing
    stop below the running peak. Whichever is nearest to price triggers the sell."""
    floors = []
    hs = getattr(prof, "hard_stop", 0.0)
    trail = getattr(prof, "trail", 0.0)
    cat = getattr(prof, "stop", 0.0)              # scale-in catastrophe stop
    ep = h.get("entry_price")
    if hs and ep:
        floors.append(ep * (1 - hs))
    if cat and ep:
        floors.append(ep * (1 - cat))
    if trail and h.get("peak"):
        floors.append(h["peak"] * (1 - trail))
    return max(floors) if floors else None


def _options_path():
    return config.DATA_DIR / "garuda_options_book.json"


def _day_base_path():
    return config.DATA_DIR / "garuda_day_base.json"


def _equity_log_path():
    return config.DATA_DIR / "garuda_equity_log.json"


def _json_state(path, loader, cache):
    """Load a results JSON for the dashboard, re-reading only when the file
    changes; None until a run exists."""
    try:
        mtime = path.stat().st_mtime
    except OSError:
        return None
    if cache.get("mtime") != mtime:
        cache["mtime"] = mtime
        cache["data"] = loader(path)
    return cache.get("data")


def _lab_state(cache={}):
    """The latest curated Strategy LAB run (walk-forward) for the LAB tab."""
    from .lab import load_results, results_path
    return _json_state(results_path(), load_results, cache)


def _discover_state(cache={}):
    """The latest LAB DISCOVER run (reverse strategy search) for the LAB tab."""
    from .lab_discover import load_results, results_path
    return _json_state(results_path(), load_results, cache)


def _movers_state(cache={}):
    """The latest LAB MOVERS run (big-move precursor study) for the LAB tab."""
    from .lab_movers import load_results, results_path
    return _json_state(results_path(), load_results, cache)


def _swaminatha_file():
    """Locate Swaminatha's paper portfolio (Mayura's news-driven face). It lives
    wherever Mayura runs — same checkout, a sibling checkout, or wherever
    SWAMINATHA_PORTFOLIO points. First existing path wins."""
    import os
    cands = []
    env = os.environ.get("SWAMINATHA_PORTFOLIO", "")
    if env:
        cands.append(Path(env))
    for base in (Path("/root/sectorbot"),         # where Mayura actually runs
                 Path.cwd(), config.BASE_DIR.parent,
                 Path.home() / "my-first-site",
                 Path("/home/globalbot/my-first-site"),
                 Path("/home/globalbot/mayura")):
        cands.append(Path(base) / "mayura_data" / "swaminatha" / "portfolio.json")
    for p in cands:
        if p.exists():
            return p
    return None


class GarudaLive:
    def __init__(self, csv_dir="."):
        self.csv_dir = Path(csv_dir)
        self.feed = KiteFeed()
        self.portfolios = {k: LivePortfolio.load(_pf_path(k), p.capital)
                           for k, p in PROFILES.items()}
        self.options = OptionsBook.load(_options_path(), capital=1_000_000.0,
                                        dist=0.025, wing=0.01, credit_frac=0.30,
                                        alloc_pct=0.02, index="NIFTY 50")
        self.prices = {}      # symbol -> live ltp
        self.index = {}       # NSE index name -> {ltp, pc, chg} (Nifty 50, Bank Nifty)
        self.day_ohlc = {}    # symbol -> {o,h,l,pc,ltp} today (for the live candle)
        self.charts = {}      # symbol -> {candles, rsi, markers}
        self.last_signals = {k: {"buys": [], "sells": []} for k in PROFILES}
        self.last_scan_date = None    # IST date of the last executed scan (once/session)
        self.intraday = []            # today's live combined-equity samples (P&L curve)
        self.intraday_day = None
        # per-book equity at the start of today (for DAY P&L) — persisted to disk
        # so a mid-session server restart keeps today's baseline instead of
        # re-zeroing DAY P&L and losing the morning's move.
        self.day_base_date, self.day_base = self._load_day_base()
        # persistent, timestamped grand-total equity samples (the P&L graph's
        # memory: [{t: 'YYYY-MM-DD HH:MM', v: equity}]) — survives restarts/days.
        self.equity_log = self._load_equity_log()
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
        # Pre-compute each stock's latest RSI-2 AND RSI-14 (daily bars, static
        # intraday) for the market-watch — RSI-2 for the dip books, RSI-14 for
        # the STRENGTH book (whose signal is the 55-70 RSI-14 band).
        self.rsi_by_sym = {}
        self.rsi14_by_sym = {}
        for sym, closes in self.series_by_sym.items():
            r2 = rsi(closes, 2) if len(closes) > 2 else []
            self.rsi_by_sym[sym] = round(r2[-1], 1) if r2 and r2[-1] is not None else None
            r14 = rsi(closes, 14) if len(closes) > 14 else []
            self.rsi14_by_sym[sym] = round(r14[-1], 1) if r14 and r14[-1] is not None else None
        # optional market caps (₹ crore) from marketcap.csv (symbol,marketcap)
        self.mcap_by_sym = self._load_mcap()
        self._movers_cache = {}    # daily MOVERS radar (recomputed once per day)
        self._swami_cache = {}     # Swaminatha (Mayura news face) guest-tab state
        from .news import NewsTicker
        self.news = NewsTicker()   # bottom-ticker headlines (rate-limited fetch)

    def _load_day_base(self):
        import json
        p = _day_base_path()
        if p.exists():
            try:
                d = json.loads(p.read_text())
                return d.get("date"), d.get("base", {})
            except Exception:  # noqa: BLE001
                pass
        return None, {}

    def _save_day_base(self):
        import json
        try:
            _day_base_path().parent.mkdir(parents=True, exist_ok=True)
            _day_base_path().write_text(json.dumps(
                {"date": self.day_base_date, "base": self.day_base}))
        except Exception:  # noqa: BLE001
            pass

    def _load_equity_log(self):
        import json
        p = _equity_log_path()
        if p.exists():
            try:
                d = json.loads(p.read_text())
                return d if isinstance(d, list) else []
            except Exception:  # noqa: BLE001
                pass
        return []

    def _save_equity_log(self):
        import json
        try:
            _equity_log_path().write_text(json.dumps(self.equity_log[-4000:]))
        except Exception:  # noqa: BLE001
            pass

    @staticmethod
    def _ist_now():
        from datetime import datetime, timezone, timedelta
        return datetime.now(timezone(timedelta(hours=5, minutes=30)))

    def grand_equity(self):
        """Total paper equity across all 7 books (6 equity + the options book),
        priced live — the number the dashboard's TOTAL tile shows."""
        eq = self.live_equity()                       # 6 equity books
        nifty = (self.index.get("NIFTY 50") or {}).get("ltp") or 0.0
        eq += self.options.state(nifty)["equity"]     # + the weekly condor book
        return eq

    def record_equity(self):
        """Append a timestamped grand-total equity sample so the P&L graph keeps a
        real, persistent multi-day record. Sampled ~1/min while the market is open."""
        if not is_market_open() or not self.prices:
            return
        t = self._ist_now().strftime("%Y-%m-%d %H:%M")
        v = round(self.grand_equity(), 0)
        if self.equity_log and self.equity_log[-1]["t"] == t:
            self.equity_log[-1]["v"] = v              # same minute -> update in place
        else:
            self.equity_log.append({"t": t, "v": v})
        self.equity_log = self.equity_log[-4000:]
        self._save_equity_log()

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
        # + Swaminatha's holdings, so the guest tab prices at live LTP too
        out.update(self._swami_raw().get("holdings", {}))
        return out

    def _swami_raw(self, cache={}):
        """Swaminatha's raw portfolio JSON (mtime-cached; {} when absent)."""
        import json as _json
        p = _swaminatha_file()
        if not p:
            return {}
        try:
            mtime = p.stat().st_mtime
            if cache.get("key") != (str(p), mtime):
                cache["key"] = (str(p), mtime)
                cache["data"] = _json.loads(p.read_text())
                print(f"[garuda] swaminatha state loaded from {p}", flush=True)
            return cache.get("data") or {}
        except (OSError, ValueError):
            return {}

    def swaminatha_state(self):
        """Mayura's news face rendered as a read-only Garuda tab: its own paper
        portfolio, priced live with Garuda's feed. None until the file exists."""
        d = self._swami_raw()
        if not d:
            return None
        from datetime import date as _d
        today = _d.today()
        positions = []
        for sym, h in (d.get("holdings") or {}).items():
            entry = h.get("avg_price") or 0.0
            ltp = self.price_of(sym, entry)
            qty = h.get("qty", 0)
            days = None
            ed = h.get("entry_date")
            if ed:
                try:
                    y, m, dd = (int(x) for x in ed.split("-"))
                    days = (today - _d(y, m, dd)).days
                except ValueError:
                    pass
            positions.append({
                "sym": sym, "qty": qty, "entry": round(entry, 2),
                "ltp": round(ltp, 2),
                "chg": round((ltp / entry - 1) * 100, 2) if entry else 0.0,
                "pnl": round((ltp - entry) * qty, 0),
                "date": ed, "days": days,
            })
        positions.sort(key=lambda x: x["pnl"], reverse=True)
        cash = d.get("cash", 0.0)
        capital = d.get("starting_capital", 0.0) or 1.0
        equity = cash + sum(p["ltp"] * p["qty"] for p in positions)
        trades = list(d.get("trades") or [])[-12:][::-1]     # newest first
        # its own equity curve: the saved daily track record + today's live tip
        curve = [{"t": h.get("date", ""), "v": round(h.get("equity", 0.0), 0)}
                 for h in (d.get("history") or [])[-240:] if h.get("equity")]
        tip = round(equity, 0)
        if not curve or curve[-1]["v"] != tip:
            curve = curve + [{"t": today.isoformat(), "v": tip}]
        return {
            "capital": round(capital, 0), "cash": round(cash, 0),
            "equity": round(equity, 0),
            "pnl_pct": round((equity / capital - 1) * 100, 2),
            "realized": round(d.get("realized_pnl", 0.0), 0),
            "unrealized": round(sum(p["pnl"] for p in positions), 0),
            "positions": positions, "trades": trades, "curve": curve,
            "source": str(_swaminatha_file() or ""),
        }

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
        # stream the universe AND every held symbol — a position must always get
        # live ticks even if its universe CSV didn't load (else it freezes at entry)
        return self.feed.start_stream(sorted(self.all_symbols() | self.held_symbols()),
                                      on_update)

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
        # advance the weekly Iron Condor: settle at expiry, roll into next week
        nifty = (self.index.get("NIFTY 50") or {}).get("ltp") or 0.0
        from datetime import date as _date
        self.options.step(nifty, _date.today(), is_market_open())
        self.options.save(_options_path())
        results["options"] = {"status": f"condor stepped @ nifty {nifty or '—'}"}
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
        idx = self.feed.index_quote()      # live Nifty 50 / Bank Nifty for the header
        if idx:
            self.index = idx
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
        if full:
            self._log_price_coverage(len(syms), len(q or {}))

    def _log_price_coverage(self, requested, priced):
        """Log how many of EACH book's held symbols have a live price, so a frozen
        book (all positions stuck at entry) is obvious in garuda.log."""
        parts = []
        for k, pf in self.portfolios.items():
            held = list(pf.holdings)
            got = sum(1 for s in held if self.prices.get(s))
            parts.append(f"{k} {got}/{len(held)}")
        nifty = "NIFTY 50" in (self.index or {})
        print(f"[prices] {requested} req, {priced} quoted · held live: "
              f"{' '.join(parts)} · index={'ok' if nifty else 'MISSING'}", flush=True)

    def live_equity(self):
        """Current combined equity across both paper books at live prices."""
        return sum(pf.equity(lambda s: self.price_of(s, pf.holdings.get(s, {}).get("entry_price", 0)))
                   for pf in self.portfolios.values())

    def snapshot_equity(self):
        """Append a live combined-equity sample for today's intraday P&L curve
        (resets each new day). Only samples while the market is open."""
        if not is_market_open():
            return
        if not self.prices:            # feed still warming up (e.g. just after a
            return                     # restart) -> skip the bad all-at-entry sample
        today = _today()
        if self.intraday_day != today:
            self.intraday_day = today
            self.intraday = []
        self.intraday.append(round(self.live_equity(), 0))
        self.intraday = self.intraday[-600:]
        self.record_equity()          # persist a timestamped grand-total sample

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
        r14 = rsi(closes, 14)                     # for the STRENGTH book's chart pane
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
            "rsi14": [round(v, 1) if v is not None else None for v in r14],
            "ma20": [round(v, 2) if v is not None else None for v in ma20],
            "ma50": [round(v, 2) if v is not None else None for v in ma50],
            "markers": markers,
        }

    def movers_radar(self):
        """The MOVERS results + TODAY's matches: which stocks sit on a VALIDATED
        big-move precursor right now. The whole-universe scan is heavy-ish, so
        it's recomputed only when the results file or the trading day changes."""
        res = _movers_state()
        if not res:
            return None
        validated = [r for r in res.get("results", []) if r["verdict"] == "VALIDATED"]
        key = (res.get("generated"), _today())
        if self._movers_cache.get("key") != key:
            from .lab_movers import scan_today
            today = scan_today(self.series_by_sym, validated) if validated else {}
            self._movers_cache = {"key": key, "today": today}
            n = sum(len(v) for v in today.values())
            print(f"[garuda] movers radar: {len(validated)} validated precursors, "
                  f"{n} stocks matching today", flush=True)
        return {**res, "today": self._movers_cache["today"]}

    # --- state for the dashboard -------------------------------------------
    def price_of(self, sym, fallback=0.0):
        return self.prices.get(sym) or fallback

    def build_state(self):
        profs = []
        mkt_open = is_market_open()
        today = _today()
        base_changed = False
        if self.day_base_date != today:      # new trading day -> re-baseline DAY P&L
            self.day_base_date = today
            self.day_base = {}
            base_changed = True
        for k, prof in PROFILES.items():
            pf = self.portfolios[k]
            positions = []
            for s, h in pf.holdings.items():
                ltp = self.price_of(s, h["entry_price"])
                chg = (ltp - h["entry_price"]) / h["entry_price"] * 100 if h["entry_price"] else 0
                pnl = (ltp - h["entry_price"]) * h["qty"]     # position total (since entry)
                sp = _stop_price(prof, h)
                positions.append({"sym": s, "qty": h["qty"],
                                  "entry": round(h["entry_price"], 2), "ltp": round(ltp, 2),
                                  "chg": round(chg, 2), "pnl": round(pnl, 0),
                                  "rsi2": h.get("rsi2_entry"), "mom": h.get("mom"),
                                  "rsi14": h.get("rsi14"),
                                  "peak": round(h["peak"], 2) if h.get("peak") else None,
                                  "stop_px": round(sp, 2) if sp else None,
                                  "stop_pct": round((ltp / sp - 1) * 100, 1) if sp and ltp else None})
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
                # live provisional RSI-2 AND RSI-14 (current price as today's close) while open
                if mkt_open and cl:
                    lr = rsi(cl[-25:] + [ltp], 2)
                    rsi2 = round(lr[-1], 1) if lr and lr[-1] is not None else self.rsi_by_sym.get(sym)
                    lr14 = rsi(cl[-40:] + [ltp], 14)
                    rsi14 = round(lr14[-1], 1) if lr14 and lr14[-1] is not None else self.rsi14_by_sym.get(sym)
                else:
                    rsi2 = self.rsi_by_sym.get(sym)
                    rsi14 = self.rsi14_by_sym.get(sym)
                h = pf.holdings.get(sym)
                watch.append({
                    "sym": sym, "ltp": round(ltp, 2), "chg": round(chg, 2),
                    "chg_w": _cb(5), "chg_m": _cb(21),
                    "hi52": round(max(win), 2) if win else None,
                    "lo52": round(min(win), 2) if win else None,
                    "mcap": self.mcap_by_sym.get(sym),
                    "rsi2": rsi2, "rsi14": rsi14, "held": bool(h),
                    "qty": h["qty"] if h else None,
                    "pnl": round((ltp - h["entry_price"]) * h["qty"], 0) if h else None,
                    "o": o.get("o"), "h": o.get("h"), "l": o.get("l"),   # today, for the live candle
                })
            equity = pf.equity(lambda s: self.price_of(s, pf.holdings.get(s, {}).get("entry_price", 0)))
            # DAY P&L = equity now minus this book's equity at the START of today
            # (snapshotted on the first build of each trading day). Resets cleanly
            # every day; immune to stale previous-close data when the market's shut.
            if k not in self.day_base:
                self.day_base[k] = round(equity, 0)
                base_changed = True
            day_pnl = equity - self.day_base[k]
            win, pfac, win_n = _live_stats(pf)
            win_kind = "live"
            if win is None and prof.proven_win:    # no closed live trades yet;
                win, win_kind = prof.proven_win, "backtest"   # 0 = no backtest
                                                   # figure (e.g. CHAKRA) -> '—'
            green = sum(1 for x in positions if x["pnl"] > 0)
            win_open = round(green / len(positions) * 100) if positions else None
            chart_sym = positions[0]["sym"] if positions else None
            best = positions[0] if positions else None
            worst = positions[-1] if positions else None
            profs.append({
                "best": best, "worst": worst,
                "key": k, "name": prof.name, "desc": prof.daily_csv.replace("_daily.csv", ""),
                "strategy": prof.strategy, "label": prof.label, "rules": prof.rules,
                "capital": pf.starting_capital, "equity": round(equity, 0),
                "pnl_pct": round((equity / pf.starting_capital - 1) * 100, 2),
                "day_pnl": round(day_pnl, 0), "positions": positions,
                "win": win, "win_kind": win_kind, "win_open": win_open,
                "win_n": win_n,
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
        # the TRUE combined live win rate: total wins / total closed trades
        # across every book (+ settled option weeks) — each book weighted by
        # its real sample size, never by open-position counts, never mixing
        # backtest figures into a number labeled "live".
        lw = lc = 0
        for pf in self.portfolios.values():
            w, c = _wins_closed(pf.trades)
            lw += w
            lc += c
        ow, oc = _wins_closed(self.options.trades, sides=("SETTLE",))
        lw, lc = lw + ow, lc + oc
        totals["win"] = round(lw / lc * 100) if lc >= 5 else None
        totals["win_n"] = lc
        totals["pnl_pct"] = round((totals["equity"] / totals["capital"] - 1) * 100, 2) \
            if totals["capital"] else 0.0
        # combined equity curve (P&L chart) — sum the books RIGHT-aligned (all
        # histories end 'today'), so a later-added book (e.g. strength) doesn't
        # truncate the curve; before a book existed, count it at its start capital.
        pfs = list(self.portfolios.values())
        histories = [pf.history for pf in pfs]
        m = max((len(h) for h in histories), default=0)
        daily = []
        for i in range(m):
            total = 0.0
            for h, pf in zip(histories, pfs):
                idx = i - (m - len(h))            # align each history to the right end
                total += h[idx]["equity"] if idx >= 0 else pf.starting_capital
            daily.append(round(total, 0))
        # daily track record + today's live intraday samples + the current tip.
        # The curve tracks the six EQUITY books (the weekly options book keeps its
        # own tile) so its history and tip stay consistent.
        totals["curve"] = daily + self.intraday + [totals["equity"]]
        # --- the 7th book: weekly Iron Condor on the Nifty --------------------
        nifty = (self.index.get("NIFTY 50") or {}).get("ltp") or 0.0
        ost = self.options.state(nifty)
        if "options" not in self.day_base:
            self.day_base["options"] = round(ost["equity"], 0)
            base_changed = True
        obase = self.day_base["options"]
        options = {**ost, "key": "options", "name": config.BOT_NAME + "-OPT",
                   "strategy": "options", "label": OPTIONS_LABEL, "rules": OPTIONS_RULES,
                   "capital": self.options.starting_capital,
                   "day_pnl": round(ost["equity"] - obase, 0),
                   "win": OPTIONS_WIN, "win_kind": "backtest"}
        # fold options into the grand-total P&L the dashboard tiles show
        totals["equity"] = round(totals["equity"] + ost["equity"], 0)
        totals["capital"] = round(totals["capital"] + options["capital"], 0)
        totals["day_pnl"] = round(totals["day_pnl"] + options["day_pnl"], 0)
        totals["pnl_pct"] = round((totals["equity"] / totals["capital"] - 1) * 100, 2) \
            if totals["capital"] else 0.0
        # timestamped grand-total curve for the P&L graph (persistent memory).
        # Prefer the recorded live log; otherwise seed from the daily backtest
        # track record (real dates at the 15:30 close, options flat at capital) so
        # the graph shows history from the first load. Always ends at the live tip.
        if self.equity_log:
            curve_ts = list(self.equity_log)
        else:
            longest = max(histories, key=len, default=[])
            dates = [h.get("date", "") for h in longest]
            opt_cap = self.options.starting_capital
            curve_ts = [{"t": (dates[i] + " 15:30") if i < len(dates) and dates[i]
                         else "pt%d" % (i + 1), "v": round(v + opt_cap, 0)}
                        for i, v in enumerate(daily)]
        tip_t = self._ist_now().strftime("%Y-%m-%d %H:%M")
        if not curve_ts or curve_ts[-1]["t"] != tip_t:
            curve_ts = curve_ts + [{"t": tip_t, "v": totals["equity"]}]
        else:
            curve_ts = curve_ts[:-1] + [{"t": tip_t, "v": totals["equity"]}]
        totals["curve_ts"] = curve_ts
        if base_changed:                     # persist today's baseline across restarts
            self._save_day_base()
        from .market import HOLIDAYS
        return {"live": self.feed.live, "profiles": profs, "totals": totals,
                "options": options, "lab": _lab_state(),
                "lab_discover": _discover_state(),
                "lab_movers": self.movers_radar(),
                "swaminatha": self.swaminatha_state(),
                "news": self.news.items((self._swami_raw() or {}).get("trades",
                                                                      [])[::-1]),
                "index": self.index,
                "market_open": is_market_open(), "market_status": market_status(),
                "holidays": sorted(HOLIDAYS),
                "last_scan": self.last_scan_date, "today": _today()}


def _wins_closed(trades, sides=("SELL",)):
    """(wins, closed) over a trade log — the raw material for every win rate."""
    closed = [t for t in trades
              if t.get("side") in sides and isinstance(t.get("pnl"), (int, float))]
    return sum(1 for t in closed if t["pnl"] > 0), len(closed)


def _live_stats(pf):
    """(win%, profit factor, closed-count) from CLOSED trades only. win%/PF are
    None below 5 closed trades (too thin to headline); the count always returns
    so the combined rate can weight every book by its true sample size."""
    closed = [t for t in pf.trades if t.get("side") == "SELL" and "pnl" in t]
    if len(closed) < 5:
        return (None, None, len(closed))
    wins = [t["pnl"] for t in closed if t["pnl"] > 0]
    gl = -sum(t["pnl"] for t in closed if t["pnl"] <= 0)
    return (round(len(wins) / len(closed) * 100),
            round(sum(wins) / gl, 2) if gl > 0 else None, len(closed))

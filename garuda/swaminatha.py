"""Swaminatha — the news-driven paper book (Garuda's 8th "book", its own tab).

Ported from Mayura's "Guru" face. Swaminatha scans today's NSE/BSE corporate
announcements **market-wide**, lets **Gemini read the full filing** and judge
whether it is a genuine, **MATERIAL bullish catalyst on a financially-sound
company**, safety-gates it, and only then places a (paper) buy. Cost is
controlled by a funnel where Gemini is the LAST, most-filtered step:

    fetch  ->  keyword pre-filter  ->  dedupe (seen)  ->  ₹-value floor
           ->  safety gate (real, priced, not a penny stock)  ->  🤖 Gemini
           ->  BUY (material + sound + confidence >= NEWS_MIN_CONFIDENCE)

Exits are event-driven and tight (news can reverse fast): a hard stop, a trailing
profit-lock that arms after a gain, and a time exit after `hold_days`.

PAPER ONLY — no real order is ever placed. It degrades safely: with no
GEMINI_API_KEY it never buys (no confident read = no trade); with no Kite feed it
still renders (holdings marked at their entry price). Mirrors OptionsBook so the
live orchestrator and dashboard treat it like any other book.
"""

from __future__ import annotations

import json
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from . import config


LABEL = "News catalysts · Gemini reads the full NSE filing · material events only"
RULES = ("Scan market-wide NSE/BSE announcements; a keyword + ₹-value funnel feeds "
         "only big, fresh, liquid catalysts to Gemini, which buys (paper) a stock "
         "only on a MATERIAL bullish event on a financially-sound company. "
         "Exit: -8% stop · trail +10%/10% · 15-day hold.")


def _today() -> str:
    ist = timezone(timedelta(hours=5, minutes=30))
    return datetime.now(ist).date().isoformat()


class SwaminathaBook:
    """A persistent, self-learning-free paper book driven purely by corporate
    news. Same shape as OptionsBook (load / save / step / state) so GarudaLive
    can fold it into the grand-total P&L and render it in its own tab."""

    def __init__(self, capital=1_000_000.0, alloc_pct=0.10, max_positions=8,
                 stop=0.08, trail_arm=0.10, trail_give=0.10, hold_days=15,
                 cash=None, holdings=None, realized=0.0, trades=None,
                 history=None, seen=None, gemini_day=None, gemini_count=0,
                 news_log=None):
        self.starting_capital = capital
        self.capital = capital
        self.cash = capital if cash is None else cash
        self.alloc_pct = alloc_pct
        self.max_positions = max_positions
        self.stop = stop
        self.trail_arm = trail_arm
        self.trail_give = trail_give
        self.hold_days = hold_days
        self.holdings = holdings or {}      # sym -> {qty, entry_price, entry_date, peak, event, conf}
        self.realized = realized
        self.trades = trades or []
        self.history = history or []        # [{date, equity}]
        self.seen = seen or {}              # ann_id -> iso date (dedupe: judge each filing once)
        self.gemini_day = gemini_day        # iso date the gemini_count belongs to
        self.gemini_count = gemini_count    # gemini calls already spent today (hard daily cap)
        self.news_log = news_log or []      # recent judged buys, for the dashboard

    # --- persistence -------------------------------------------------------
    @classmethod
    def load(cls, path, **kw):
        p = Path(path)
        if p.exists():
            try:
                d = json.loads(p.read_text())
            except (ValueError, OSError):
                d = {}
            # config (capital/exits) always wins over the saved copy so tuning
            # takes effect on the next run; the LEDGER (cash/holdings/…) is kept.
            d.update(kw)
            return cls(**d)
        return cls(**kw)

    def save(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(json.dumps({
            "capital": self.starting_capital, "alloc_pct": self.alloc_pct,
            "max_positions": self.max_positions, "stop": self.stop,
            "trail_arm": self.trail_arm, "trail_give": self.trail_give,
            "hold_days": self.hold_days, "cash": self.cash,
            "holdings": self.holdings, "realized": self.realized,
            "trades": self.trades[-500:], "history": self.history[-800:],
            "seen": self.seen, "gemini_day": self.gemini_day,
            "gemini_count": self.gemini_count, "news_log": self.news_log[-40:],
        }, indent=2))

    # --- exits (event-driven, tight) ---------------------------------------
    def _stop_price(self, h):
        """Binding stop for a held name: the higher (closer) of the hard stop
        below entry and the trailing stop below the running peak (once armed)."""
        floors = [h["entry_price"] * (1 - self.stop)]
        peak = h.get("peak") or h["entry_price"]
        if peak >= h["entry_price"] * (1 + self.trail_arm):   # trail armed
            floors.append(peak * (1 - self.trail_give))
        return max(floors)

    def _days_held(self, h, today):
        try:
            y, m, d = (int(x) for x in h["entry_date"].split("-"))
            ty, tm, td = (int(x) for x in today.split("-"))
            return (date(ty, tm, td) - date(y, m, d)).days
        except (ValueError, KeyError):
            return 0

    def _sell(self, sym, price, reason, today):
        h = self.holdings.pop(sym)
        proceeds = h["qty"] * price
        pnl = proceeds - h["qty"] * h["entry_price"]
        self.cash += proceeds
        self.realized += pnl
        self.trades.append({"date": today, "side": "SELL", "symbol": sym,
                            "qty": h["qty"], "price": round(price, 2),
                            "reason": reason, "pnl": round(pnl, 0)})

    def _apply_exits(self, prices, today):
        """Sell any held name that hit its stop, trailing stop or hold-time cap."""
        for sym in list(self.holdings):
            h = self.holdings[sym]
            ltp = prices.get(sym)
            if not ltp or ltp <= 0:
                continue
            if ltp > (h.get("peak") or 0):
                h["peak"] = ltp
            if ltp <= self._stop_price(h):
                armed = (h.get("peak") or ltp) >= h["entry_price"] * (1 + self.trail_arm)
                self._sell(sym, ltp, "trail" if armed else "stop", today)
            elif self._days_held(h, today) >= self.hold_days:
                self._sell(sym, ltp, "time", today)

    # --- news funnel (the expensive Gemini step is last & capped) ----------
    def _reset_gemini_if_new_day(self, today):
        if self.gemini_day != today:
            self.gemini_day = today
            self.gemini_count = 0

    def _prune_seen(self, today):
        cutoff = (date.fromisoformat(today) - timedelta(days=config.NEWS_SEEN_KEEP_DAYS))
        self.seen = {k: v for k, v in self.seen.items()
                     if not v or v >= cutoff.isoformat()}

    def poll_news(self, feed, today):
        """Run the funnel and return a list of Gemini-approved buy candidates:
        [{symbol, price, confidence, reason}]. Fail-safe: returns [] whenever the
        news can't be fetched or Gemini isn't configured (no confident read =
        no trade). Marks every filing it inspects 'seen' so later polls skip it."""
        from . import filings, gemini
        if not gemini.configured():
            return []
        self._reset_gemini_if_new_day(today)
        self._prune_seen(today)

        anns = filings.fetch_market_announcements(config.NEWS_DAYS_BACK)
        if not anns:
            return []
        # keyword pre-filter + dedupe + one event per symbol
        cands, sym_seen = [], set(self.holdings)
        for a in anns:
            if a.symbol in sym_seen or not filings.is_candidate(a):
                continue
            if filings.ann_id(a) in self.seen:
                continue
            sym_seen.add(a.symbol)
            cands.append(a)
        # cheap ₹-value floor (no AI): drop small orders, mark them seen
        priced = []
        for a in cands:
            if filings.passes_value_floor(a, config.NEWS_MIN_ORDER_CR):
                priced.append(a)
            else:
                self.seen[filings.ann_id(a)] = today

        out, calls = [], 0
        for a in priced:
            if self.gemini_count >= config.NEWS_MAX_GEMINI_CALLS_DAILY:
                break                                   # hard daily cost ceiling
            if calls >= config.NEWS_MAX_GEMINI_CALLS:
                break
            aid = filings.ann_id(a)
            price = self._last_price(feed, a.symbol)
            if price is None:                           # bad/untradeable symbol
                self.seen[aid] = today
                continue
            if price < config.NEWS_MIN_PRICE:           # penny stock — safety gate
                self.seen[aid] = today
                continue
            news = f"{a.subject}. {a.detail}".strip()
            verdict = gemini.judge_news(a.symbol, a.detail.split(".")[0], news)
            calls += 1
            self.gemini_count += 1
            if verdict is None:                         # transient error — retry next poll
                continue
            self.seen[aid] = today                      # judged once; never re-judge
            if not gemini.is_buy(verdict):
                continue
            out.append({"symbol": a.symbol, "price": price,
                        "confidence": round(verdict["confidence"] * 100, 1),
                        "reason": verdict["reason"][:120]})
        return out

    def _last_price(self, feed, sym):
        """Best-effort live/last price for any market-wide symbol via the Kite
        feed. None if the symbol can't be priced (untradeable / feed offline)."""
        if feed is None:
            return None
        try:
            q = feed.ltp([sym]) or {}
            if q.get(sym):
                return float(q[sym])
            bars = feed.ohlc_daily(sym, 5) or []
            if bars:
                return float(bars[-1]["c"])
        except Exception:  # noqa: BLE001
            return None
        return None

    def _buy(self, sym, price, event, conf, today):
        alloc = self.starting_capital * self.alloc_pct
        qty = int(alloc // price)
        cost = qty * price
        if qty <= 0 or cost > self.cash:
            return False
        self.cash -= cost
        self.holdings[sym] = {"qty": qty, "entry_price": price, "entry_date": today,
                              "peak": price, "event": event, "conf": conf}
        self.trades.append({"date": today, "side": "BUY", "symbol": sym,
                            "qty": qty, "price": round(price, 2), "reason": event})
        self.news_log.append({"date": today, "symbol": sym, "conf": conf,
                              "event": event})
        return True

    # --- the daily/interval step -------------------------------------------
    def step(self, feed, today=None, market_open=True):
        """Advance the book: price + exit existing holdings, then poll the news
        and paper-buy fresh Gemini-approved catalysts with spare cash. No-op when
        the market is shut (paper, but timed like live trading)."""
        if not market_open:
            return {"status": "market closed — Swaminatha rests"}
        today = today or _today()
        prices = self._price_holdings(feed)
        self._apply_exits(prices, today)
        buys = self.poll_news(feed, today)
        placed = []
        for b in buys:
            if len(self.holdings) >= self.max_positions:
                break
            if self._buy(b["symbol"], b["price"], "📰 " + b["reason"],
                         b["confidence"], today):
                placed.append(b["symbol"])
        return {"status": f"{len(placed)} news buy(s)", "buys": placed}

    def _price_holdings(self, feed):
        if feed is None or not self.holdings:
            return {}
        try:
            return {s: float(v) for s, v in (feed.ltp(list(self.holdings)) or {}).items() if v}
        except Exception:  # noqa: BLE001
            return {}

    def record_close(self, feed, today=None):
        """Append a dated equity point (for the track record / P&L curve)."""
        today = today or _today()
        prices = self._price_holdings(feed)
        eq = self._equity(lambda s: prices.get(s))
        if self.history and self.history[-1].get("date") == today:
            self.history[-1]["equity"] = round(eq, 0)
        else:
            self.history.append({"date": today, "equity": round(eq, 0)})

    # --- reporting ---------------------------------------------------------
    def _equity(self, price_of):
        held = sum(h["qty"] * (price_of(s) or h["entry_price"])
                   for s, h in self.holdings.items())
        return self.cash + held

    def state(self, price_of):
        """Dashboard view: positions with live P&L, plus book equity + a short
        log of the most recent news buys so the tab explains its trades."""
        today = _today()
        positions = []
        for s, h in self.holdings.items():
            ltp = price_of(s) or h["entry_price"]
            chg = (ltp - h["entry_price"]) / h["entry_price"] * 100 if h["entry_price"] else 0.0
            pnl = (ltp - h["entry_price"]) * h["qty"]
            sp = self._stop_price(h)
            positions.append({
                "sym": s, "qty": h["qty"], "entry": round(h["entry_price"], 2),
                "ltp": round(ltp, 2), "chg": round(chg, 2), "pnl": round(pnl, 0),
                "conf": h.get("conf"), "event": h.get("event", ""),
                "days": self._days_held(h, today),
                "peak": round(h["peak"], 2) if h.get("peak") else None,
                "stop_px": round(sp, 2),
                "stop_pct": round((ltp / sp - 1) * 100, 1) if sp and ltp else None,
            })
        positions.sort(key=lambda x: x["pnl"], reverse=True)
        equity = self._equity(price_of)
        return {
            "positions": positions, "cash": round(self.cash, 0),
            "realized": round(self.realized, 0), "equity": round(equity, 0),
            "pnl_pct": round((equity / self.starting_capital - 1) * 100, 2),
            "n": len(positions),
            "gemini_today": self.gemini_count,
            "gemini_cap": config.NEWS_MAX_GEMINI_CALLS_DAILY,
            "gemini_ok": _gemini_configured(),
            "news_log": list(reversed(self.news_log[-10:])),
        }


def _gemini_configured() -> bool:
    try:
        from . import gemini
        return gemini.configured()
    except Exception:  # noqa: BLE001
        return False


def _news_dry_run():
    """`python -m garuda.swaminatha --news` — run the funnel once and print what
    it would buy (no trades). Needs GEMINI_API_KEY + a live Kite token to be
    meaningful; prints a clear notice otherwise."""
    from .feed import KiteFeed
    book = SwaminathaBook(capital=config.SWAMINATHA_CAPITAL)
    if not _gemini_configured():
        print("GEMINI_API_KEY not set — Swaminatha can't read news (no buys). "
              "Set it in the droplet's .env, then re-run.")
        return
    feed = KiteFeed()
    buys = book.poll_news(feed, _today())
    if not buys:
        print("No material-bullish catalysts right now (or NSE unreachable).")
        return
    print(f"{len(buys)} Gemini-approved catalyst(s):")
    for b in buys:
        print(f"  ✅ {b['symbol']:<14} ~₹{b['price']:.1f}  conf {b['confidence']}%  {b['reason']}")


if __name__ == "__main__":
    import sys
    if "--news" in sys.argv:
        _news_dry_run()
    else:
        print("usage: python -m garuda.swaminatha --news   "
              "(dry-run the news funnel; needs GEMINI_API_KEY + Kite token)")

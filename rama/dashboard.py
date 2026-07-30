"""Rama's live dashboard — the Claude×Quant look, wired to REAL paper numbers.

Renders a self-contained dark HTML page from the persistent portfolio + the
honest scorecard. It refreshes itself (meta refresh), so if you regenerate it on
a schedule (cron / after each `trade` run) it behaves as a live wall-board.

Every number here is Rama's ACTUAL paper track record — there are no invented
returns. If the run used synthetic prices, the page says so in bold. It also
shows the verdict from scorecard.py: is Rama actually beating a Nifty index fund
after costs? That honesty is the whole point.
"""

from html import escape

from . import config
from .portfolio import Portfolio
from .scorecard import compute_scorecard


def _price_context():
    """Return (price_of, real_data). Uses live Kite prices if available, else
    values holdings at cost (avg price) and flags the page as not-real."""
    try:
        from .datasource import PaperDataSource, get_datasource
        ds = get_datasource()
        real = not isinstance(ds, PaperDataSource)
        if real:
            return (lambda s: _safe(ds, s)), True
    except Exception:  # noqa: BLE001
        pass
    return None, False


def _safe(ds, symbol):
    try:
        p = ds.last_price(symbol)
        return float(p) if p and p > 0 else 0.0
    except Exception:  # noqa: BLE001
        return 0.0


def _tile(label, value, sub="", tone="") -> str:
    return (f'<div class="tile {tone}"><div class="lbl">{escape(label)}</div>'
            f'<div class="val">{escape(str(value))}</div>'
            f'<div class="sub">{escape(sub)}</div></div>')


def _pct(v):
    return f"{v:+.2f}%" if isinstance(v, (int, float)) else "—"


def generate(out=None) -> str:
    pf = Portfolio.load()
    sc = compute_scorecard(pf)
    price_of, real = _price_context()
    if price_of is None:
        price_of = lambda s: pf.holdings.get(s, {}).get("avg_price", 0.0)

    equity = pf.equity(price_of)
    total_pct = (equity / pf.starting_capital - 1) * 100 if pf.starting_capital else 0.0

    verdict = sc["verdict"]
    vtone = ("good" if verdict in ("PROMISING", "POSITIVE (no index yet)")
             else "bad" if verdict in ("LOSING", "LAGGING THE INDEX") else "warn")
    pnl_tone = "good" if total_pct >= 0 else "bad"

    wr = f"{sc['win_rate_pct']:.0f}%" if sc["win_rate_pct"] is not None else "—"
    pf_ = f"{sc['profit_factor']:.2f}" if sc["profit_factor"] is not None else "—"
    edge = _pct(sc["edge_vs_index_pct"]) if sc["edge_vs_index_pct"] is not None else "—"

    tiles = "".join([
        _tile("EQUITY (PAPER)", f"Rs {equity:,.0f}", "starting Rs "
              f"{pf.starting_capital:,.0f}"),
        _tile("TOTAL P&L", _pct(total_pct), "since inception", pnl_tone),
        _tile("EDGE vs NIFTY", edge, "the number that matters",
              "good" if isinstance(sc["edge_vs_index_pct"], (int, float))
              and sc["edge_vs_index_pct"] >= 0 else "bad"
              if sc["edge_vs_index_pct"] is not None else ""),
        _tile("WIN RATE", wr, f"profit factor {pf_}"),
        _tile("MAX DRAWDOWN", f"{sc['max_drawdown_pct']:.2f}%", "worst peak-to-dip"),
        _tile("SHARPE (rough)", f"{sc['sharpe']:.2f}", f"vol {sc['volatility_pct']:.2f}%"),
        _tile("CLOSED TRADES", sc["closed_trades"], f"{sc['days']} days tracked"),
        _tile("VERDICT", verdict, sc["explanation"][:60] + "…", vtone),
    ])

    # holdings
    rows = ""
    for s, h in pf.holdings.items():
        ltp = price_of(s) or h["avg_price"]
        chg = (ltp - h["avg_price"]) / h["avg_price"] * 100 if h["avg_price"] else 0
        cls = "up" if chg >= 0 else "dn"
        rows += (f"<tr><td>{escape(s)}</td><td>{h['qty']}</td>"
                 f"<td>{h['avg_price']:,.2f}</td><td>{ltp:,.2f}</td>"
                 f"<td class='{cls}'>{chg:+.2f}%</td><td>{escape(h['entry_date'])}</td></tr>")
    if not rows:
        rows = "<tr><td colspan=6 class='muted'>No open positions yet.</td></tr>"

    # recent trades
    trs = ""
    for t in reversed(pf.trades[-10:]):
        pnl = t.get("pnl")
        pnl_s = f"{pnl:+,.0f}" if pnl is not None else "—"
        cls = "up" if (pnl or 0) >= 0 else "dn"
        trs += (f"<tr><td>{escape(t['date'])}</td><td>{escape(t['side'])}</td>"
                f"<td>{escape(t['symbol'])}</td><td>{t['qty']}</td>"
                f"<td>{t['price']:,.2f}</td><td class='{cls}'>{pnl_s}</td>"
                f"<td class='muted'>{escape(str(t.get('reason','')))}</td></tr>")
    if not trs:
        trs = "<tr><td colspan=7 class='muted'>No trades yet.</td></tr>"

    pipeline = " ".join(
        f'<span class="step">{i+1:02d} · {s}</span>'
        for i, s in enumerate(["Scan", "Detect", "Validate", "Size(Kelly)",
                               "Audit", "Fill", "Settle"]))

    data_flag = ("REAL Kite prices" if real
                 else "SYNTHETIC prices — NOT real market data")
    mode_note = ("LIVE_TRADING OFF · paper only" if not config.LIVE_TRADING
                 else "LIVE_TRADING ON")

    html = _TEMPLATE.format(
        name=escape(config.BOT_NAME), tagline=escape(config.BOT_TAGLINE),
        tiles=tiles, rows=rows, trs=trs, pipeline=pipeline,
        data_flag=escape(data_flag), mode_note=escape(mode_note),
        sizing=escape(config.SIZING_MODE), max_ops=config.MAX_ORDERS_PER_SEC,
    )
    out = out or config.DASHBOARD_HTML
    from pathlib import Path
    Path(out).write_text(html, encoding="utf-8")
    return str(out)


_TEMPLATE = """<!doctype html><html lang=en><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<meta http-equiv=refresh content=30>
<title>{name} · Quant</title>
<style>
:root{{--bg:#0a0e14;--panel:#121821;--line:#1f2a37;--txt:#e6edf3;--mut:#7d8998;
--grn:#2ecc71;--red:#ff5c5c;--amb:#f5a623;--acc:#39d98a}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--txt);
font:14px/1.5 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}}
.wrap{{max-width:1100px;margin:0 auto;padding:20px}}
.top{{display:flex;justify-content:space-between;align-items:center;
border-bottom:1px solid var(--line);padding-bottom:12px;flex-wrap:wrap;gap:8px}}
.brand{{font-size:22px;font-weight:700;letter-spacing:1px}}
.brand b{{color:var(--acc)}}.tag{{color:var(--mut);font-size:12px}}
.live{{background:var(--red);color:#fff;padding:2px 8px;border-radius:4px;
font-size:11px;font-weight:700;animation:blink 1.6s infinite}}
@keyframes blink{{50%{{opacity:.45}}}}
.flag{{margin:12px 0;padding:8px 12px;border:1px dashed var(--amb);color:var(--amb);
border-radius:6px;font-size:12px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px;margin:16px 0}}
.tile{{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:14px}}
.tile .lbl{{color:var(--mut);font-size:11px;letter-spacing:.5px}}
.tile .val{{font-size:24px;font-weight:700;margin:4px 0}}
.tile .sub{{color:var(--mut);font-size:11px}}
.tile.good .val{{color:var(--grn)}}.tile.bad .val{{color:var(--red)}}
.tile.warn .val{{color:var(--amb)}}
.pipe{{margin:8px 0 20px;color:var(--mut);font-size:12px;display:flex;gap:6px;flex-wrap:wrap}}
.step{{background:var(--panel);border:1px solid var(--line);border-radius:20px;padding:3px 10px}}
h3{{margin:20px 0 8px;font-size:13px;color:var(--mut);letter-spacing:1px;text-transform:uppercase}}
.scroll{{overflow-x:auto}}
table{{width:100%;border-collapse:collapse;font-size:13px}}
th,td{{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line);white-space:nowrap}}
th{{color:var(--mut);font-weight:600;font-size:11px}}
.up{{color:var(--grn)}}.dn{{color:var(--red)}}.muted{{color:var(--mut)}}
.foot{{margin-top:24px;color:var(--mut);font-size:11px;border-top:1px solid var(--line);padding-top:12px}}
</style></head><body><div class=wrap>
<div class=top>
  <div><div class=brand><b>{name}</b> · QUANT</div><div class=tag>{tagline}</div></div>
  <div style=text-align:right>
    <span class=live>● LIVE</span>
    <div class=tag>sizing: {sizing} · OPS cap: {max_ops}/s (SEBI &lt;10)</div>
  </div>
</div>
<div class=flag>⚠ {data_flag} · {mode_note} · numbers are Rama's own paper track record — not advice, not a prediction.</div>
<div class=pipe>{pipeline}</div>
<div class=grid>{tiles}</div>
<h3>Holdings</h3><div class=scroll><table>
<tr><th>Symbol</th><th>Qty</th><th>Entry</th><th>LTP</th><th>Chg</th><th>Since</th></tr>
{rows}</table></div>
<h3>Recent trades</h3><div class=scroll><table>
<tr><th>Date</th><th>Side</th><th>Symbol</th><th>Qty</th><th>Price</th><th>P&amp;L</th><th>Reason</th></tr>
{trs}</table></div>
<div class=foot>Rama · paper simulation · auto-refresh 30s · regenerate via
<code>python -m rama livedash</code> (e.g. from cron after each run). Going live
requires Kite Connect + your broker Algo-ID + static IP per SEBI's Feb-2025
retail-algo framework; Rama caps order rate under 10/sec and ships a kill switch.</div>
</div></body></html>"""

"""Generate a simple HTML dashboard (dashboard.html) for my-first-site.

Shows the ranked industries and the latest paper-trading simulation so you can
see everything in the browser. Pure standard library -- no templating deps.
"""

import html
from datetime import date

from . import config
from .bot import run_simulation
from .screener import score_industries, load_industries


def _rank_rows(limit=20) -> str:
    rows = []
    for i, ind in enumerate(score_industries(load_industries())[:limit], 1):
        pe = f"{ind.pe:.1f}" if ind.pe is not None else "—"
        hot = " 🔥" if ind.pe and ind.pe > config.MAX_PORTFOLIO_PE else ""
        rows.append(
            f"<tr><td>{i}</td><td>{html.escape(ind.name)}{hot}</td>"
            f"<td>{html.escape(ind.sector)}</td>"
            f"<td class='num'>{ind.score:.1f}</td>"
            f"<td class='num'>{ind.qtr_change:.1f}</td>"
            f"<td class='num'>{ind.year_change:.1f}</td>"
            f"<td class='num'>{pe}</td></tr>"
        )
    return "\n".join(rows)


def _pick_rows(result) -> str:
    rows = []
    for p in result["picks"]:
        rows.append(
            f"<tr><td>{html.escape(p.industry.name)}</td>"
            f"<td class='num'>{p.industry.score:.1f}</td>"
            f"<td>{html.escape(', '.join(p.symbols[:5]))}</td></tr>"
        )
    return "\n".join(rows)


def generate(path=None) -> str:
    path = path or config.DASHBOARD_HTML
    result = run_simulation(verbose=False)
    pnl_class = "pos" if result["pnl"] >= 0 else "neg"

    doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SectorBot Dashboard</title>
<style>
  body {{ font-family: -apple-system, sans-serif; max-width: 980px; margin: 40px auto;
         padding: 20px; background: #f5f5f5; color: #222; line-height: 1.5; }}
  h1 {{ color: #764ba2; }}
  .box {{ background: #fff; padding: 24px; border-radius: 12px;
          box-shadow: 0 2px 10px rgba(0,0,0,0.08); margin-bottom: 24px; }}
  .warn {{ background: #fff8e1; border-left: 5px solid #f4b400; padding: 14px 18px;
           border-radius: 8px; font-size: 0.95em; }}
  table {{ width: 100%; border-collapse: collapse; font-size: 0.92em; }}
  th, td {{ padding: 8px 10px; border-bottom: 1px solid #eee; text-align: left; }}
  th {{ color: #555; font-weight: 600; }}
  td.num {{ text-align: right; font-variant-numeric: tabular-nums; }}
  .kpi {{ font-size: 1.6em; font-weight: 700; }}
  .pos {{ color: #0a8f3c; }} .neg {{ color: #c62828; }}
  .pill {{ display:inline-block; background:#ede7f6; color:#5e35b1; padding:2px 10px;
           border-radius: 999px; font-size:0.8em; }}
</style>
</head>
<body>
  <div class="box">
    <h1>SectorBot Dashboard</h1>
    <span class="pill">{'LIVE' if config.LIVE_TRADING else 'PAPER · SIMULATION'}</span>
    <span class="pill">generated {date.today().isoformat()}</span>
    <div class="warn" style="margin-top:14px;">
      <b>Not investment advice.</b> Rankings summarise the data you provided; they
      do not predict the future. The P&amp;L below uses <b>synthetic prices and fake
      money</b>. Past/illustrative performance does not imply real profit.
    </div>
  </div>

  <div class="box">
    <h2>Simulated portfolio</h2>
    <p>Starting capital: <b>Rs {result['broker'].starting_capital:,.0f}</b> &nbsp;·&nbsp;
       Ending equity: <b>Rs {result['equity']:,.0f}</b></p>
    <p class="kpi {pnl_class}">P&amp;L: Rs {result['pnl']:,.0f} ({result['pnl_pct']:+.2f}%)</p>
    <p>{len(result['broker'].trades)} simulated trades across {len(result['picks'])} industries.</p>
  </div>

  <div class="box">
    <h2>Industries the bot selected &amp; traded</h2>
    <table>
      <tr><th>Industry</th><th>Score</th><th>Representative NSE symbols</th></tr>
      {_pick_rows(result)}
    </table>
  </div>

  <div class="box">
    <h2>Full ranking from your data (top 20)</h2>
    <p style="color:#777;font-size:0.9em;">🔥 = PE above {config.MAX_PORTFOLIO_PE} (looks overheated, skipped by the bot)</p>
    <table>
      <tr><th>#</th><th>Industry</th><th>Sector</th><th>Score</th><th>Qtr%</th><th>1Yr%</th><th>PE</th></tr>
      {_rank_rows()}
    </table>
  </div>
</body>
</html>"""

    with open(path, "w", encoding="utf-8") as f:
        f.write(doc)
    return str(path)


if __name__ == "__main__":
    out = generate()
    print(f"Dashboard written to: {out}")

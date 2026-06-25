"""Email alerts: send the daily picks + simulated exits.

Uses only the standard library (smtplib + email). Credentials are read from
environment variables (see config.py). If SMTP isn't configured the email is
printed to the console instead of sent -- so this is always safe to run.
"""

import smtplib
import ssl
from datetime import date
from email.message import EmailMessage

from . import config
from .backtest import run_backtest
from .bot import run_simulation
from .data_loader import resolve_csv


def _backtest_section() -> tuple[list[str], str]:
    """Build the backtest part of the email as (plain_lines, html)."""
    bt = run_backtest(verbose=False)
    if not bt["ok"]:
        msg = f"Backtest: building history ({bt['days']} day snapshot saved, need 2+)."
        return ["", msg], f"<h3>Backtest</h3><p style='color:#555'>{msg}</p>"

    strat = bt["strategy_return_pct"]
    bench = bt["benchmark_return_pct"]
    edge = strat - bench
    lines = [
        "",
        f"Backtest over {bt['days']} day(s):",
        f"  Strategy (top picks): {strat:+.2f}%",
        f"  Benchmark (all)     : {bench:+.2f}%",
        f"  Edge vs benchmark   : {edge:+.2f}%",
        f"  Days beating bench  : {bt['win_rate_pct']:.0f}%",
    ]
    color = "#0a8f3c" if edge >= 0 else "#c62828"
    html = (
        "<h3>Backtest "
        f"({bt['days']} day(s))</h3>"
        "<table cellpadding='6' style='border-collapse:collapse'>"
        f"<tr><td>Strategy (top picks)</td><td style='text-align:right'>{strat:+.2f}%</td></tr>"
        f"<tr><td>Benchmark (all industries)</td><td style='text-align:right'>{bench:+.2f}%</td></tr>"
        f"<tr><td><b>Edge vs benchmark</b></td>"
        f"<td style='text-align:right;color:{color}'><b>{edge:+.2f}%</b></td></tr>"
        f"<tr><td>Days beating benchmark</td><td style='text-align:right'>{bt['win_rate_pct']:.0f}%</td></tr>"
        "</table>"
        "<p style='font-size:0.8em;color:#777'>Coarse test on reported day-moves, "
        f"{'net of trading costs/slippage' if bt.get('costs_included') else 'costs OFF'}. "
        "Not advice.</p>"
    )
    return lines, html


def build_email(result: dict, csv_path=None) -> tuple[str, str, str]:
    """Return (subject, plain_text, html) for the day's simulation result."""
    pnl = result["pnl"]
    pnl_pct = result["pnl_pct"]
    src = resolve_csv(csv_path).name
    subject = (
        f"SectorBot {date.today().isoformat()} · "
        f"paper P&L {pnl:+,.0f} ({pnl_pct:+.2f}%)"
    )

    lines = [
        "SectorBot daily summary (PAPER / simulation — not advice)",
        f"Data file: {src}",
        f"Capital mode: {config.CAPITAL_MODE.upper()} | "
        f"Gross deployed: Rs {result['invested']:,.0f}",
        f"Simulated P&L: Rs {pnl:,.0f} ({pnl_pct:+.2f}%)",
        "",
        "Top industries selected:",
    ]
    pick_html = []
    for p in result["picks"]:
        i = p.industry
        lines.append(
            f"  • {i.name} (score {i.score:.1f} = fund {i.fundamental_score:.1f} "
            f"+ breadth {i.sector_breadth_score:.0f}, PE {i.pe}) -> {', '.join(p.symbols)}"
        )
        pick_html.append(
            f"<tr><td>{i.name}</td><td style='text-align:right'>{i.score:.1f}</td>"
            f"<td style='text-align:right'>{i.fundamental_score:.1f}</td>"
            f"<td style='text-align:right'>{i.sector_breadth_score:.0f}</td>"
            f"<td>{', '.join(p.symbols)}</td></tr>"
        )

    exits = [t for t in result["broker"].trades if t.side == "SELL"]
    lines.append("")
    lines.append(f"Simulated exits today: {len(exits)}")
    exit_html = []
    for t in exits:
        lines.append(f"  SELL {t.symbol} @ {t.price:.2f} [{t.reason}]")
        exit_html.append(
            f"<tr><td>{t.symbol}</td><td style='text-align:right'>{t.price:.2f}</td>"
            f"<td>{t.reason}</td></tr>"
        )
    bt_lines, bt_html = _backtest_section()
    lines.extend(bt_lines)
    plain = "\n".join(lines)

    color = "#0a8f3c" if pnl >= 0 else "#c62828"
    html = f"""<html><body style="font-family:-apple-system,sans-serif;color:#222">
    <h2 style="color:#764ba2">SectorBot · {date.today().isoformat()}</h2>
    <p style="background:#fff8e1;border-left:5px solid #f4b400;padding:10px">
      <b>Paper simulation — not investment advice.</b> Data file: {src}</p>
    <p style="font-size:1.3em;color:{color}"><b>P&amp;L: Rs {pnl:,.0f} ({pnl_pct:+.2f}%)</b><br>
      <span style="font-size:0.7em;color:#555">Capital {config.CAPITAL_MODE.upper()},
      deployed Rs {result['invested']:,.0f}</span></p>
    <h3>Top industries</h3>
    <table cellpadding="6" style="border-collapse:collapse">
      <tr><th align="left">Industry</th><th>Score</th><th>Fund</th><th>Breadth</th><th align="left">Symbols</th></tr>
      {''.join(pick_html)}
    </table>
    <h3>Simulated exits ({len(exits)})</h3>
    <table cellpadding="6" style="border-collapse:collapse">
      {''.join(exit_html) or '<tr><td>none today</td></tr>'}
    </table>
    {bt_html}
    </body></html>"""
    return subject, plain, html


def send_email(subject: str, plain: str, html: str) -> bool:
    """Send via SMTP, or print to console if SMTP isn't configured.

    Returns True if an email was actually sent.
    """
    if not (config.SMTP_HOST and config.SMTP_USER and config.SMTP_PASSWORD):
        print("\n[email dry-run] SMTP not configured — would have sent:\n")
        print(f"To: {config.EMAIL_TO}\nSubject: {subject}\n")
        print(plain + "\n")
        print("Set SMTP_HOST/SMTP_USER/SMTP_PASSWORD env vars to actually send.")
        return False

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = config.EMAIL_FROM or config.SMTP_USER
    msg["To"] = config.EMAIL_TO
    msg.set_content(plain)
    msg.add_alternative(html, subtype="html")

    # Email must never crash the run. The portfolio has already been saved by
    # the time we get here; a delivery failure is just logged.
    try:
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL(config.SMTP_HOST, config.SMTP_PORT,
                              context=context, timeout=30) as server:
            server.login(config.SMTP_USER, config.SMTP_PASSWORD)
            server.send_message(msg)
        print(f"Email sent to {config.EMAIL_TO}")
        return True
    except OSError as exc:
        print(f"[email] WARNING: could not send ({exc}).")
        print("[email] If this is 'Network is unreachable' on a VPS, your host "
              "likely blocks outbound SMTP (DigitalOcean blocks 25/465/587 by "
              "default). Ask support to unblock it, or switch to an HTTP email "
              "API. The portfolio run itself succeeded.")
        return False
    except Exception as exc:  # noqa: BLE001
        print(f"[email] WARNING: send failed ({exc}). Portfolio run still OK.")
        return False


def send_daily(csv_path=None) -> bool:
    result = run_simulation(verbose=False, csv_path=csv_path)
    subject, plain, html = build_email(result, csv_path)
    return send_email(subject, plain, html)


def build_portfolio_email(result: dict) -> tuple[str, str, str]:
    """Email for a persistent paper-portfolio session (engine.run_paper_session)."""
    pf = result["portfolio"]
    real = result["real_data"]
    tag = "REAL Kite prices" if real else "SYNTHETIC prices — NOT real"
    subject = (
        f"SectorBot portfolio {date.today().isoformat()} · "
        f"equity Rs {result['equity']:,.0f} ({result['total_pnl_pct']:+.2f}%)"
    )

    lines = [
        f"SectorBot paper portfolio ({tag}) — not investment advice",
        f"Starting capital: Rs {pf.starting_capital:,.0f}",
        f"Equity now: Rs {result['equity']:,.0f} ({result['total_pnl_pct']:+.2f}%)",
        f"Cash: Rs {result['cash']:,.0f} | Holdings: Rs {result['holdings_value']:,.0f}",
        f"Unrealised P&L: Rs {result['unrealized']:,.0f} | "
        f"Realised P&L: Rs {result['realized']:,.0f}",
        "",
        f"Holdings ({len(pf.holdings)}):",
    ]
    hold_html = []
    for s, h in pf.holdings.items():
        ltp = result["price_of"](s)
        pnl = (ltp - h["avg_price"]) * h["qty"]
        lines.append(f"  {s} x{h['qty']} @ {h['avg_price']:.2f} -> {ltp:.2f} "
                     f"(P&L {pnl:+,.0f}, since {h['entry_date']})")
        hold_html.append(
            f"<tr><td>{s}</td><td style='text-align:right'>{h['qty']}</td>"
            f"<td style='text-align:right'>{h['avg_price']:.2f}</td>"
            f"<td style='text-align:right'>{ltp:.2f}</td>"
            f"<td style='text-align:right'>{pnl:+,.0f}</td><td>{h['entry_date']}</td></tr>"
        )

    exits = result["exits"]
    lines.append("")
    lines.append(f"Exits this run: {len(exits)}")
    for s, ltp, reason, pnl in exits:
        lines.append(f"  SELL {s} @ {ltp:.2f} [{reason}] P&L {pnl:+,.0f}")
    plain = "\n".join(lines)

    color = "#0a8f3c" if result["total_pnl"] >= 0 else "#c62828"
    warn = ("" if real else
            "<b>These are SYNTHETIC prices — set Kite keys for real data.</b> ")
    html = f"""<html><body style="font-family:-apple-system,sans-serif;color:#222">
    <h2 style="color:#764ba2">SectorBot portfolio · {date.today().isoformat()}</h2>
    <p style="background:#fff8e1;border-left:5px solid #f4b400;padding:10px">
      {warn}Paper trading ({tag}). Not investment advice.</p>
    <p style="font-size:1.3em;color:{color}"><b>Equity Rs {result['equity']:,.0f}
      ({result['total_pnl_pct']:+.2f}%)</b><br>
      <span style="font-size:0.7em;color:#555">Cash Rs {result['cash']:,.0f} ·
      Unrealised {result['unrealized']:+,.0f} · Realised {result['realized']:+,.0f}</span></p>
    <h3>Holdings ({len(pf.holdings)})</h3>
    <table cellpadding="6" style="border-collapse:collapse">
      <tr><th align="left">Stock</th><th>Qty</th><th>Entry</th><th>LTP</th><th>P&amp;L</th><th align="left">Since</th></tr>
      {''.join(hold_html) or '<tr><td>no holdings</td></tr>'}
    </table>
    <h3>Exits this run ({len(exits)})</h3>
    <ul>{''.join(f"<li>{s} @ {ltp:.2f} [{reason}] P&L {pnl:+,.0f}</li>" for s, ltp, reason, pnl in exits) or '<li>none</li>'}</ul>
    </body></html>"""
    return subject, plain, html


def write_portfolio_report(result: dict) -> tuple[str, str]:
    """Write the latest portfolio summary to plain + HTML files on disk.

    Returns (txt_path, html_path). Use this instead of email when the host
    blocks SMTP -- view with `cat portfolio_report.txt` or open the HTML.
    """
    _, plain, html = build_portfolio_email(result)
    config.PORTFOLIO_REPORT_TXT.write_text(plain, encoding="utf-8")
    config.PORTFOLIO_REPORT_HTML.write_text(html, encoding="utf-8")
    return str(config.PORTFOLIO_REPORT_TXT), str(config.PORTFOLIO_REPORT_HTML)


def _telegram_portfolio_summary(result: dict) -> str:
    """Short, phone-friendly summary of a portfolio run for Telegram."""
    real = result["real_data"]
    tag = "REAL Kite prices" if real else "SYNTHETIC prices — NOT real"
    exits = result["exits"]
    lines = [
        f"<b>📊 SectorBot · {date.today().isoformat()}</b>",
        f"<i>Paper trading ({tag})</i>",
        f"Equity: <b>Rs {result['equity']:,.0f}</b> "
        f"({result['total_pnl_pct']:+.2f}%)",
        f"Cash Rs {result['cash']:,.0f} · "
        f"Unrealised {result['unrealized']:+,.0f} · "
        f"Realised {result['realized']:+,.0f}",
        f"Holdings: {len(result['portfolio'].holdings)} · Exits: {len(exits)}",
    ]
    if result.get("data_stale"):
        lines.insert(1, f"⚠️ <b>STALE DATA</b> (file {result.get('data_date')}) "
                        f"— upload today's CSV!")
    elif result.get("data_date"):
        lines.append(f"Data: {result['data_date']}")
    if result.get("regime_blocked"):
        lines.append("🛑 Market downtrend — holding cash, no new buys")
    for s, ltp, reason, pnl in exits[:8]:
        lines.append(f"  SELL {s} @ {ltp:.2f} [{reason}] P&amp;L {pnl:+,.0f}")
    return "\n".join(lines)


def send_portfolio(result=None, csv_path=None) -> bool:
    if result is None:
        from .engine import run_paper_session
        result = run_paper_session(verbose=False, csv_path=csv_path)
    if result.get("aborted"):
        print("Portfolio run aborted — no email sent.")
        return False
    subject, plain, html = build_portfolio_email(result)
    sent = send_email(subject, plain, html)
    # Telegram is a separate, independent channel: a phone push that works even
    # when the host blocks outbound SMTP. Safe no-op if it isn't configured.
    from .telegram import send_telegram
    tg = send_telegram(_telegram_portfolio_summary(result))
    return sent or tg


if __name__ == "__main__":
    send_daily()

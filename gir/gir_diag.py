#!/usr/bin/env python3
"""GIR Diagnostic - Read-Only Truth Report"""
import argparse, json, os, re, subprocess, sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

DATA_DIR = Path("/home/globalbot/data")
EQUITY_TRADES = DATA_DIR / "equity_trades.json"
EQUITY_POSITIONS = DATA_DIR / "equity_positions.json"
EQUITY_RISK = DATA_DIR / "risk_equity.json"
FNO_TRADES = DATA_DIR / "fno_trades.json"
FNO_POSITIONS = DATA_DIR / "fno_positions.json"
SYSTEMD_UNIT = "globaleye"

STT_DELIVERY = 0.001
EXCHANGE_TXN = 0.0000297
GST = 0.18
SEBI_CHARGE = 0.000001
STAMP_DUTY_BUY = 0.00015

def load_json(path, default):
    try:
        with open(path) as f: return json.load(f)
    except: return default

def parse_dt(s):
    if not s: return None
    for fmt in ("%Y-%m-%dT%H:%M:%S.%f%z","%Y-%m-%dT%H:%M:%S%z","%Y-%m-%dT%H:%M:%S.%f","%Y-%m-%dT%H:%M:%S","%Y-%m-%d %H:%M:%S","%Y-%m-%d"):
        try:
            dt = datetime.strptime(s, fmt)
            if dt.tzinfo is not None: dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
            return dt
        except: continue
    return None

def estimate_costs(entry, exit_p, qty):
    buy_val = entry * qty; sell_val = exit_p * qty
    stt = STT_DELIVERY * sell_val
    exch = EXCHANGE_TXN * (buy_val + sell_val)
    sebi = SEBI_CHARGE * (buy_val + sell_val)
    stamp = STAMP_DUTY_BUY * buy_val
    gst = GST * exch
    return stt + exch + sebi + stamp + gst

def pct(n, d): return 0.0 if not d else 100.0*n/d

def fmt_inr(x):
    sign = "-" if x < 0 else ""; x = abs(x)
    if x >= 1e7: return f"{sign}Rs{x/1e7:.2f}Cr"
    if x >= 1e5: return f"{sign}Rs{x/1e5:.2f}L"
    if x >= 1e3: return f"{sign}Rs{x/1e3:.1f}k"
    return f"{sign}Rs{x:.0f}"

def hr(c="-", n=78): print(c*n)

def header(t):
    print(); hr("="); print(f"  {t}"); hr("=")

def analyze_trades(trades, days, label="EQUITY"):
    cutoff = datetime.now() - timedelta(days=days)
    in_w = [t for t in trades if (et := parse_dt(t.get("exit_time",""))) and et >= cutoff]
    header(f"{label} - Last {days} Days")
    if not in_w:
        print(f"  No closed trades in window. Total ever: {len(trades)}")
        if trades:
            last = trades[-1]
            print(f"  Last trade ever: {last.get('symbol','?')} exit={last.get('exit_time','?')} pnl=Rs{last.get('pnl',0):.0f} reason={last.get('reason','?')}")
        return None
    wins = [t for t in in_w if t.get("pnl",0) > 0]
    losses = [t for t in in_w if t.get("pnl",0) < 0]
    flat = [t for t in in_w if t.get("pnl",0) == 0]
    gross = sum(t.get("pnl",0) for t in in_w)
    win_pnl = sum(t.get("pnl",0) for t in wins)
    loss_pnl = sum(t.get("pnl",0) for t in losses)
    cost = sum(estimate_costs(t.get("entry_price",0), t.get("exit_price",0), t.get("qty",0)) for t in in_w)
    net = gross - cost
    print(f"  Trades closed       : {len(in_w)}")
    print(f"    Wins              : {len(wins)}")
    print(f"    Losses            : {len(losses)}")
    print(f"    Flat              : {len(flat)}")
    print(f"  Win rate            : {pct(len(wins),len(in_w)):.1f}%")
    if wins: print(f"  Avg win             : {fmt_inr(win_pnl/len(wins))}")
    if losses: print(f"  Avg loss            : {fmt_inr(loss_pnl/len(losses))}")
    if wins and losses:
        rr = (win_pnl/len(wins))/abs(loss_pnl/len(losses))
        print(f"  Win/Loss ratio      : {rr:.2f}  (>1.5 healthy)")
    print(f"  Gross P&L           : {fmt_inr(gross)}")
    print(f"  Est costs           : {fmt_inr(cost)}")
    print(f"  NET P&L             : {fmt_inr(net)}")
    if gross > 0:
        print(f"  Cost % of gross     : {pct(cost,gross):.1f}%  ({'HIGH' if cost > 0.3*gross else 'OK'})")
    print(); print("  Exit reasons:")
    reasons = Counter(t.get("reason","UNKNOWN") for t in in_w)
    rpnl = defaultdict(float)
    for t in in_w: rpnl[t.get("reason","UNKNOWN")] += t.get("pnl",0)
    for r,n in reasons.most_common():
        print(f"    {r:<22} {n:>3}  pnl={fmt_inr(rpnl[r]):>12}  avg={fmt_inr(rpnl[r]/n):>10}")
    print(); print("  Catalyst source attribution:")
    src_n = Counter(t.get("source","UNKNOWN") for t in in_w)
    src_pnl = defaultdict(float); src_wins = defaultdict(int)
    for t in in_w:
        s = t.get("source","UNKNOWN"); src_pnl[s] += t.get("pnl",0)
        if t.get("pnl",0) > 0: src_wins[s] += 1
    for s,n in src_n.most_common():
        print(f"    {s:<22} {n:>3}  pnl={fmt_inr(src_pnl[s]):>12}  win%={pct(src_wins[s],n):>5.1f}")
    print(); holds = []
    for t in in_w:
        et = parse_dt(t.get("entry_time","")); xt = parse_dt(t.get("exit_time",""))
        if et and xt: holds.append((xt-et).total_seconds()/86400)
    if holds:
        holds.sort(); med = holds[len(holds)//2]
        print(f"  Hold (days): min={min(holds):.1f} median={med:.1f} max={max(holds):.1f} avg={sum(holds)/len(holds):.1f}")
    print(); s = sorted(in_w, key=lambda t: t.get("pnl",0))
    print("  Worst 3:")
    for t in s[:3]:
        print(f"    {t.get('symbol','?'):<14} pnl={fmt_inr(t.get('pnl',0)):>10} reason={t.get('reason','?'):<18} src={t.get('source','?')}")
    print("  Best 3:")
    for t in s[-3:][::-1]:
        print(f"    {t.get('symbol','?'):<14} pnl={fmt_inr(t.get('pnl',0)):>10} reason={t.get('reason','?'):<18} src={t.get('source','?')}")
    return {"n":len(in_w),"wins":len(wins),"losses":len(losses),"gross":gross,"net":net,"cost":cost}

def analyze_positions(pf, label="EQUITY"):
    header(f"{label} - Open Positions (GIR view)")
    data = load_json(pf, {})
    if isinstance(data, dict) and "positions" in data and isinstance(data["positions"], dict):
        positions = data["positions"]
    elif isinstance(data, dict): positions = data
    else: positions = {}
    if not positions:
        print("  No open positions tracked."); return positions
    print(f"  Total tracked: {len(positions)}")
    print(f"  {'Symbol':<14} {'Qty':>6} {'Entry':>10} {'Source':<18} {'SL':>10}")
    for sym, p in positions.items():
        print(f"  {sym:<14} {p.get('qty',0):>6} {p.get('entry_price',0):>10.2f} {p.get('source','?'):<18} {p.get('stop_loss', p.get('sl_price',0)):>10.2f}")
    return positions

def compare_kite(gir_pos):
    header("KITE GROUND TRUTH (live)")
    try: from kiteconnect import KiteConnect
    except ImportError:
        print("  kiteconnect not installed. pip3 install --break-system-packages kiteconnect"); return
    api_key = os.getenv("KITE_API_KEY","")
    if not api_key:
        print("  KITE_API_KEY not in env. Did you source .env?"); return
    tok = load_json(DATA_DIR/"kite_token.json", {})
    at = tok.get("access_token","")
    if not at: print("  No access_token. Bot may not have logged in today."); return
    try:
        k = KiteConnect(api_key=api_key); k.set_access_token(at)
        h = k.holdings() or []
    except Exception as e: print(f"  Kite error: {e}"); return
    kh = {x["tradingsymbol"]:x for x in h if x.get("quantity",0)>0}
    print(f"  Kite holdings (CNC): {len(kh)}")
    for sym,x in kh.items():
        q=x.get("quantity",0); a=x.get("average_price",0); l=x.get("last_price",0)
        print(f"    {sym:<14} qty={q:>4} avg={a:>9.2f} ltp={l:>9.2f} unrealised={fmt_inr((l-a)*q):>10}")
    gs = set(gir_pos.keys()); ks = set(kh.keys())
    og = gs - ks; ok_ = ks - gs
    print()
    if og: print(f"  WARN: Tracked by GIR but NOT in Kite: {sorted(og)} - stale state")
    if ok_: print(f"  WARN: In Kite but NOT tracked by GIR: {sorted(ok_)} - unprotected!")
    if not og and not ok_: print("  OK: GIR state matches Kite.")

def funnel(days):
    header(f"FUNNEL - last {days} days from journal")
    try:
        r = subprocess.run(["journalctl","-u",SYSTEMD_UNIT,"--since",f"{days} days ago","--no-pager","-o","cat"],capture_output=True,text=True,timeout=120)
        lines = r.stdout.splitlines()
    except Exception as e: print(f"  Cannot read journal: {e}"); return
    if not lines: print(f"  No journal entries for {SYSTEMD_UNIT}"); return
    print(f"  Scanned {len(lines):,} log lines"); print()
    pats = {
        "News scout raw":        r"news.*scout|scout.*candidate|news_scout",
        "NewsBrain validated":   r"PATCH_V6[38]|validate_scout|NewsBrain.*validated|read_and_decide",
        "NewsBrain rejected":    r"NewsBrain.*reject|brain.*reject|llm.*reject",
        "Trendlyne pass":        r"Trendlyne.*pass|DVM.*pass|StratQ.*ok",
        "Trendlyne fail":        r"Trendlyne.*fail|Trendlyne.*skip|DVM.*fail|StratQ.*fail",
        "ExpertPanel APPROVE":   r"ExpertPanel.*APPROVE|panel.*approve|EXPERT.*PASS",
        "ExpertPanel VETO":      r"ExpertPanel.*VETO|panel.*veto|EXPERT.*REJECT",
        "RSI/Vol blocked":       r"RSI.*block|volume.*block|overbought|low.*volume",
        "SafetyFilter blocked":  r"SafetyFilter.*block|safety.*reject",
        "OrderGuard blocked":    r"OrderGuard.*block|guard.*reject|already.*held",
        "Risk halted":           r"risk.*halt|max.*loss|circuit",
        "ENTRY placed":          r"entry placed|ENTRY|equity.*entered|enter\(",
        "GTT placed":            r"GTT.*place|gtt_id.*created",
        "GTT FAILED":            r"GTT.*fail|gtt.*error",
        "Exit triggered":        r"SL_BREACHED|SL_LOSS|SL_TRAIL_TAKE|dead.*money|thesis.*invalid",
    }
    c = {}
    for n,p in pats.items():
        rgx = re.compile(p, re.IGNORECASE)
        c[n] = sum(1 for ln in lines if rgx.search(ln))
    mx = max(c.values()) if c.values() else 1
    print("  Funnel (top=many, bottom=few):")
    for n in pats:
        bar = "#" * min(50, c[n] // max(1, mx // 50 or 1))
        print(f"    {n:<24} {c[n]:>6}  {bar}")
    print(); print("  Interpretation:")
    if c["News scout raw"]>0 and c["NewsBrain validated"]==0: print("    WARN: Scouts firing but NewsBrain not validating")
    if c["NewsBrain rejected"]>5*max(1,c["NewsBrain validated"]): print("    WARN: NewsBrain rejecting >5x more than approving")
    if c["ExpertPanel VETO"]>2*max(1,c["ExpertPanel APPROVE"]): print("    WARN: ExpertPanel vetoing >2x more than approving")
    if c["ENTRY placed"]==0 and c["News scout raw"]>50: print("    WARN: Many signals but ZERO entries - funnel broken")
    if c["GTT FAILED"]>0: print(f"    WARN: {c['GTT FAILED']} GTT failures - unprotected positions possible")
    if c["ENTRY placed"]>0 and c["GTT placed"]<c["ENTRY placed"]:
        print(f"    WARN: {c['ENTRY placed']-c['GTT placed']} entries without matching GTT")

def show_risk():
    header("EQUITY - Risk State")
    d = load_json(EQUITY_RISK, {})
    if not d: print("  No risk state file."); return
    for k,v in d.items(): print(f"    {k:<24} : {v}")

def verdict(eq, fno):
    header("VERDICT")
    if not eq and not fno:
        print("  No closed trades in window. Bot not trading or window short.")
        print("  Try: python3 gir_diag.py --days 180"); return
    print()
    if eq:
        g,n,cs,nn = eq["gross"],eq["net"],eq["cost"],eq["n"]
        print(f"  EQUITY: {nn} trades, gross {fmt_inr(g)}, costs {fmt_inr(cs)}, NET {fmt_inr(n)}")
        if n<0 and g>0: print("    -> Has edge but costs eating it. Increase size or reduce frequency.")
        elif n<0 and g<0: print("    -> Negative edge before costs. Find worst catalyst source, kill it.")
        elif n>0 and n<0.01*abs(g): print("    -> Marginal. One bad week wipes year.")
        elif n>0: print("    -> Positive net. Scale cautiously.")
    print(); print("  WHERE TO LOOK:")
    print("    - Catalyst source table: kill worst, keep best 1-2")
    print("    - Exit reasons: SL_LOSS dominating = stops too tight")
    print("    - Funnel: NewsBrain reject >> approve = loosen it")
    print("    - Hold period: median < 2 days on swing = panic-exiting winners")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=60)
    ap.add_argument("--no-kite", action="store_true")
    ap.add_argument("--no-journal", action="store_true")
    ap.add_argument("--fno", action="store_true")
    a = ap.parse_args()
    print(); hr("=")
    print(f"  GIR DIAGNOSTIC")
    print(f"  Generated: {datetime.now().isoformat(timespec='seconds')}")
    print(f"  Window: last {a.days} days")
    hr("=")
    print(); print("  File presence:")
    for p in (EQUITY_TRADES, EQUITY_POSITIONS, EQUITY_RISK):
        st = "OK" if p.exists() else "MISSING"
        sz = f"{p.stat().st_size:,}b" if p.exists() else ""
        print(f"    {st:<8} {p} {sz}")
    raw = load_json(EQUITY_TRADES, {"trades":[]})
    trades = raw.get("trades",[]) if isinstance(raw,dict) else []
    eq = analyze_trades(trades, a.days, "EQUITY")
    pos = analyze_positions(EQUITY_POSITIONS, "EQUITY")
    if not a.no_kite: compare_kite(pos)
    show_risk()
    fno = None
    if a.fno:
        fraw = load_json(FNO_TRADES, {"trades":[]})
        ft = fraw.get("trades",[]) if isinstance(fraw,dict) else []
        fno = analyze_trades(ft, a.days, "F&O")
        analyze_positions(FNO_POSITIONS, "F&O")
    if not a.no_journal: funnel(a.days)
    verdict(eq, fno)
    print(); hr("="); print("  Done. No files modified."); hr("="); print()

if __name__ == "__main__": main()

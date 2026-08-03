import gir_eq_floor as m
kite = m.get_kite()
instr = m.load_instruments(kite)
syms = list(instr.keys())
print(f"scanning {len(syms)} NSE EQ for liquidity ranking...", flush=True)
ranked = []
for i, s in enumerate(syms):
    try:
        df = m.daily_ohlc(kite, instr[s]["token"], bars=25)
        if len(df) < 20: continue
        if df["close"].iloc[-1] < m.MIN_PRICE: continue
        turn = (df["close"]*df["volume"]).tail(20).mean()
        if turn < m.MIN_TURNOVER: continue
        ranked.append((s, turn))
    except Exception:
        pass
    if i % 200 == 0:
        print(f"  {i}/{len(syms)} scanned, {len(ranked)} liquid so far", flush=True)
ranked.sort(key=lambda x: -x[1])
top = [s for s, _ in ranked[:1000]]
with open(m.UNIVERSE_CSV, "w") as f:
    f.write("\n".join(top) + "\n")
print(f"DONE: WROTE {len(top)} liquid names to universe.csv", flush=True)
print("top 10:", top[:10], flush=True)

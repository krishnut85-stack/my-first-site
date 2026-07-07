#!/usr/bin/env python3
"""V60_TICK_REPAIR — standalone GTT tick-violation fixer."""
import os, sys, json, math
from kiteconnect import KiteConnect

DRY = os.environ.get("DRY_RUN", "0") == "1"

with open("/home/globalbot/data/kite_token.json") as f:
    s = json.load(f)
k = KiteConnect(api_key=s.get("api_key") or "m8yzn5cyjs71jq78")
k.set_access_token(s["access_token"])

print(f"[V60_TICK_REPAIR] mode={'DRY-RUN' if DRY else 'LIVE'}")

tick_map = {}
for i in k.instruments("NFO"):
    tick_map[("NFO", i["tradingsymbol"])] = float(i.get("tick_size") or 0.05)
for i in k.instruments("NSE"):
    tick_map[("NSE", i["tradingsymbol"])] = float(i.get("tick_size") or 0.05)
print(f"[V60_TICK_REPAIR] tick_map: {len(tick_map)} symbols")

gtts = k.get_gtts()
active = [g for g in gtts if g.get("status") == "active"]
print(f"[V60_TICK_REPAIR] active GTTs: {len(active)}")

violations = []
for g in active:
    tsym = g["condition"]["tradingsymbol"]
    exch = g["condition"]["exchange"]
    tick = tick_map.get((exch, tsym), 0.05)
    bad = False
    for tv in g["condition"]["trigger_values"]:
        if abs(round(tv/tick)*tick - tv) > 0.001:
            bad = True; break
    if not bad:
        for o in g["orders"]:
            p = float(o["price"])
            if abs(round(p/tick)*tick - p) > 0.001:
                bad = True; break
    if bad:
        violations.append((g, tick))

print(f"[V60_TICK_REPAIR] violations: {len(violations)}")
if not violations:
    print("[V60_TICK_REPAIR] nothing to fix")
    sys.exit(0)

ok = fail = 0
for g, tick in violations:
    tsym = g["condition"]["tradingsymbol"]
    exch = g["condition"]["exchange"]
    order = g["orders"][0]
    ttype = order.get("transaction_type", "SELL")
    old_trig = float(g["condition"]["trigger_values"][0])
    old_price = float(order["price"])
    ltp_key = f"{exch}:{tsym}"
    try:
        ltp = float(k.ltp([ltp_key])[ltp_key]["last_price"])
    except Exception as e:
        print(f"  [SKIP] {tsym} ltp fail: {e}"); fail += 1; continue
    if ttype == "SELL":
        new_trig = round(math.ceil(old_trig / tick) * tick, 4)
        new_price = round(math.floor(old_price / tick) * tick, 4)
    else:
        new_trig = round(math.floor(old_trig / tick) * tick, 4)
        new_price = round(math.ceil(old_price / tick) * tick, 4)
    gap = abs(new_trig - ltp) / ltp * 100
    if gap < 0.26:
        print(f"  [SKIP] {tsym} gap {gap:.3f}% < 0.26%"); fail += 1; continue
    print(f"  [FIX] {exch}:{tsym} {ttype} trig {old_trig}->{new_trig} price {old_price}->{new_price}")
    if DRY:
        ok += 1; continue
    try:
        r = k.modify_gtt(
            trigger_id=g["id"],
            trigger_type=g["type"],
            tradingsymbol=tsym,
            exchange=exch,
            trigger_values=[new_trig],
            last_price=ltp,
            orders=[{
                "transaction_type": ttype,
                "quantity": int(order["quantity"]),
                "order_type": "LIMIT",
                "product": order.get("product", "NRML"),
                "price": new_price,
            }],
        )
        print(f"        OK id={r.get('trigger_id')}"); ok += 1
    except Exception as e:
        print(f"        FAIL: {e}"); fail += 1

print(f"\n[V60_TICK_REPAIR] done. fixed={ok} failed={fail}")

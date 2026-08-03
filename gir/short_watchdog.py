"""
Independent watchdog. Runs alongside gir.py. Does not touch bot code.
Monitors for accidental naked short positions and force-closes them.
Logs every action. Never opens new positions, only closes shorts.
"""
import json, time, os
from datetime import datetime
from kiteconnect import KiteConnect

LOG_PATH = '/home/globalbot/logs/short_watchdog.log'
os.makedirs('/home/globalbot/logs', exist_ok=True)

def log(msg):
    line = f"{datetime.now().isoformat()} {msg}"
    print(line)
    with open(LOG_PATH, 'a') as f:
        f.write(line + '\n')

def get_kite():
    api_key = None
    with open('/home/globalbot/.env') as f:
        for line in f:
            if line.startswith('KITE_API_KEY') or line.startswith('API_KEY'):
                api_key = line.split('=', 1)[1].strip().strip('"').strip("'")
                break
    with open('/home/globalbot/data/kite_token.json') as f:
        tok = json.load(f)
    k = KiteConnect(api_key=api_key)
    k.set_access_token(tok['access_token'])
    return k

# Symbols already closed this session — don't retry forever
already_closed = set()

log("=== Short watchdog started ===")

while True:
    try:
        kite = get_kite()
        positions = kite.positions().get('net', [])
        
        for p in positions:
            sym = p['tradingsymbol']
            qty = p['quantity']
            
            # Only F&O shorts (NFO segment), qty < 0
            if qty < 0 and p.get('exchange') == 'NFO' and sym not in already_closed:
                exposure = abs(qty) * p.get('last_price', 0)
                log(f"🚨 DETECTED SHORT: {sym} qty={qty} ltp={p.get('last_price')} exposure≈₹{exposure:,.0f}")
                
                try:
                    # Place BUY order to close the short
                    order_id = kite.place_order(
                        variety=kite.VARIETY_REGULAR,
                        exchange=kite.EXCHANGE_NFO,
                        tradingsymbol=sym,
                        transaction_type=kite.TRANSACTION_TYPE_BUY,
                        quantity=abs(qty),
                        product=kite.PRODUCT_NRML,
                        order_type=kite.ORDER_TYPE_MARKET
                    )
                    log(f"✅ CLOSE order placed for {sym} qty={abs(qty)} order_id={order_id}")
                    already_closed.add(sym)
                except Exception as e:
                    log(f"❌ Failed to close {sym}: {e}")
        
        time.sleep(30)
    except Exception as e:
        log(f"Watchdog error: {e}")
        time.sleep(60)

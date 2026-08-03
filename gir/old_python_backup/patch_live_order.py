filepath = "/home/globalbot/griffin_bot.py"
with open(filepath, "r") as f:
    content = f.read()

old_block = '''        send_telegram(msg)
        return pos'''

new_block = '''        send_telegram(msg)

        # v25.6.1: ACTUALLY PLACE THE ORDER ON KITE
        try:
            _live_kite = KiteSession.get()
            if _live_kite and TRADING_MODE == "LIVE":
                _ts = self._build_tradingsymbol_simple(symbol, K, opt, exp)
                if _ts:
                    _limit_price = None
                    try:
                        _qk = f"NFO:{_ts}"
                        _qd = _live_kite.quote([_qk])
                        if _qk in _qd:
                            _q = _qd[_qk]
                            _ltp = _q.get("last_price", 0)
                            _depth = _q.get("depth", {})
                            _best_ask = 0
                            _best_bid = 0
                            if _depth.get("sell") and _depth["sell"][0].get("price", 0) > 0:
                                _best_ask = _depth["sell"][0]["price"]
                            if _depth.get("buy") and _depth["buy"][0].get("price", 0) > 0:
                                _best_bid = _depth["buy"][0]["price"]
                            # Spread safety check: 5% max
                            if _best_ask > 0 and _best_bid > 0:
                                _spread_pct = (_best_ask - _best_bid) / _best_bid * 100
                                if _spread_pct > 5.0:
                                    logger.warning(f"F&O WIDE SPREAD: {_ts} bid={_best_bid} ask={_best_ask} spread={_spread_pct:.1f}% > 5% — ABORTING")
                                    self.book["positions"].pop(key, None)
                                    self.book["available"] = round(self.book["available"] + cost, 2)
                                    self._save()
                                    return pos
                            # Smart limit price
                            if _best_ask > 0:
                                _limit_price = round(_best_ask * 1.005, 2)
                                _max_price = round(_ltp * 1.20, 2) if _ltp > 0 else _limit_price
                                _limit_price = min(_limit_price, _max_price)
                            elif _ltp > 0:
                                _limit_price = round(_ltp * 1.01, 2)
                    except Exception as _pe:
                        logger.debug(f"F&O quote fetch: {_pe}")

                    if _limit_price and _limit_price > 0:
                        _oid = safe_place_order(
                            _live_kite,
                            tradingsymbol=_ts,
                            exchange="NFO",
                            transaction_type="BUY",
                            quantity=lot,
                            price=_limit_price,
                            order_type="LIMIT",
                            product="NRML",
                            variety="regular",
                            tag=f"FNO_{source[:6]}",
                        )
                        if _oid:
                            pos["order_id"] = _oid
                            self.book["positions"][key] = pos
                            self._save()
                            logger.info(f"KITE ORDER PLACED: {_ts} BUY x{lot} @ limit Rs{_limit_price} | order_id={_oid}")
                        else:
                            logger.warning(f"KITE ORDER FAILED: {_ts} — order blocked or rejected")
                            self.book["positions"].pop(key, None)
                            self.book["available"] = round(self.book["available"] + cost, 2)
                            self._save()
                    else:
                        logger.warning(f"F&O NO PRICE: {_ts} — could not get limit price, paper-only")
                else:
                    logger.warning(f"F&O NO TRADINGSYMBOL: {symbol} {K} {opt} {exp}")
        except Exception as _live_err:
            logger.error(f"F&O LIVE ORDER ERROR: {_live_err}")

        return pos'''

count = content.count(old_block)
if count == 0:
    print("ERROR: Pattern not found")
    import re
    for m in re.finditer(r'send_telegram\(msg\)', content):
        ctx = content[m.start()-20:m.end()+40]
        print(f"  Found at pos {m.start()}: ...{ctx}...")
else:
    content = content.replace(old_block, new_block, 1)
    with open(filepath, "w") as f:
        f.write(content)
    print(f"Patch applied ({count} match). FNOTrader.enter() now places LIVE Kite orders with 5% spread limit")


"""The three isolation/alert features:
  A) Mayura's OWN env vars (MAYURA_BOT_TOKEN / MAYURA_CHAT_ID / MAYURA_TOPIC_*)
     always WIN over the generic TELEGRAM_* ones, so Mayura can never share a
     token/group with the main equity bot.
  B) Every trade is alerted: _mayura_telegram lists each BUY and each SELL.
  C) The EOD report renders per-position and total P&L.
"""

import importlib

import mayura
from sectorbot.portfolio import Portfolio


# --- A) MAYURA_* env precedence -------------------------------------------
def test_config_prefers_mayura_token(monkeypatch):
    monkeypatch.setenv("MAYURA_BOT_TOKEN", "mayura-tok")
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "main-tok")
    monkeypatch.setenv("MAYURA_CHAT_ID", "-100999")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "-100111")
    from sectorbot import config
    importlib.reload(config)          # re-read os.environ at import time
    try:
        assert config.TELEGRAM_BOT_TOKEN == "mayura-tok"
        assert config.TELEGRAM_CHAT_ID == "-100999"
    finally:
        importlib.reload(config)      # restore from the real environment


def test_config_falls_back_to_telegram_token(monkeypatch):
    monkeypatch.delenv("MAYURA_BOT_TOKEN", raising=False)
    monkeypatch.delenv("MAYURA_CHAT_ID", raising=False)
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "main-tok")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "-100111")
    from sectorbot import config
    importlib.reload(config)
    try:
        assert config.TELEGRAM_BOT_TOKEN == "main-tok"
        assert config.TELEGRAM_CHAT_ID == "-100111"
    finally:
        importlib.reload(config)


def test_topic_id_prefers_mayura(monkeypatch):
    mayura.CURRENT = {"key": "dandapani"}
    monkeypatch.setenv("MAYURA_TOPIC_DANDAPANI", "7")
    monkeypatch.setenv("TELEGRAM_TOPIC_DANDAPANI", "3")
    assert mayura._topic_id() == "7"
    monkeypatch.delenv("MAYURA_TOPIC_DANDAPANI")
    assert mayura._topic_id() == "3"          # legacy fallback still works


# --- B) every trade alerted -----------------------------------------------
def _result(entries, exits):
    pf = Portfolio(1_000_000, 900_000, holdings={"AAA": {"qty": 1, "avg_price": 1}})
    return {
        "real_data": True, "equity": 1_010_000, "cash": 900_000,
        "total_pnl_pct": 1.0, "unrealized": 5_000, "realized": 5_000,
        "portfolio": pf, "entries": entries, "exits": exits,
    }


def test_telegram_lists_each_buy_and_sell():
    mayura.CURRENT = {"key": "dandapani", "name": "Dandapani", "emoji": "🌄"}
    msg = mayura._mayura_telegram(_result(
        entries=[("RELIANCE", 100.0, 5), ("TCS", 200.0, 3)],
        exits=[("WIPRO", 50.0, "stop", -1234)],
    ))
    assert "BUY RELIANCE ×5 @ 100.00" in msg
    assert "BUY TCS ×3 @ 200.00" in msg
    assert "SELL WIPRO @ 50.00 [stop]" in msg
    assert "Buys: 2" in msg and "Exits: 1" in msg


def test_telegram_no_trades_is_clean():
    mayura.CURRENT = {"key": "senthil", "name": "Senthil", "emoji": "🌊"}
    msg = mayura._mayura_telegram(_result(entries=[], exits=[]))
    assert "BUY" not in msg and "SELL" not in msg
    assert "Buys: 0" in msg and "Exits: 0" in msg

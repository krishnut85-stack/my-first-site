"""Tests for Mayura's stock-level smart scoring (more Trendlyne data)."""

from sectorbot import config, instruments
from sectorbot.stocks import resolve_columns, score_row


def test_resolve_columns_matches_aliases():
    cols = resolve_columns(["NSE Code", "Industry", "Durability Score",
                            "Valuation", "Momentum Score", "PE TTM",
                            "Delivery Volume %", "RSI"])
    assert cols["durability"] == "Durability Score"
    assert cols["valuation"] == "Valuation"
    assert cols["momentum"] == "Momentum Score"
    assert cols["pe"] == "PE TTM"
    assert cols["delivery"] == "Delivery Volume %"
    assert cols["rsi"] == "RSI"


def test_score_row_uses_dvm():
    cols = resolve_columns(["Durability", "Valuation", "Momentum"])
    strong = score_row({"Durability": "90", "Valuation": "80", "Momentum": "95"}, cols)
    weak = score_row({"Durability": "20", "Valuation": "30", "Momentum": "10"}, cols)
    assert strong is not None and weak is not None
    assert strong > weak
    assert 0 <= weak <= 100 and 0 <= strong <= 100


def test_score_row_none_when_no_signals():
    cols = resolve_columns(["Symbol", "Industry"])  # nothing scoreable
    assert score_row({"Symbol": "X", "Industry": "Y"}, cols) is None


def test_stock_universe_ranks_by_smart_score(tmp_path, monkeypatch):
    # A stock export WITH DVM columns: stocks must rank by smart score, not by
    # file order — the high-DVM name comes first even if listed last.
    csv = tmp_path / "universe.csv"
    csv.write_text(
        "NSE Code,Industry,Durability,Valuation,Momentum\n"
        "WEAKO,Banks,20,25,15\n"
        "MIDO,Banks,55,50,60\n"
        "STRONGO,Banks,95,85,98\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(config, "UNIVERSE_CSV", csv)
    instruments.reload_universe()
    assert instruments.universe_source() == "universe.csv"
    assert instruments.has_stock_signals() is True
    assert instruments.symbols_for("Banks") == ["STRONGO", "MIDO", "WEAKO"]
    assert instruments.stock_score("STRONGO") > instruments.stock_score("WEAKO")
    instruments.reload_universe()  # reset cache for other tests


def test_liquidity_sort_still_works_without_signals(tmp_path, monkeypatch):
    # No DVM/technical columns -> must fall back to liquidity sort (unchanged).
    csv = tmp_path / "universe.csv"
    csv.write_text(
        "Symbol,Industry,Market Cap\n"
        "SMALLB,Banks,100\nBIGBANK,Banks,900\nMIDBANK,Banks,500\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(config, "UNIVERSE_CSV", csv)
    instruments.reload_universe()
    assert instruments.has_stock_signals() is False
    assert instruments.symbols_for("Banks") == ["BIGBANK", "MIDBANK", "SMALLB"]
    instruments.reload_universe()


def test_breakout_watchlist_loads_ranks_and_filters(tmp_path):
    from sectorbot.stocks import load_breakout_watchlist
    csv = tmp_path / "universe.csv"
    csv.write_text(
        '"Stock","% Distance from 52W high","Day SMA50","Day SMA200",'
        '"Delivery% Vol  Avg Month","Delivery% Vol  Avg 6M",'
        '"Returns vs Nifty500 quarter%","NSE Code"\n'
        '"Strong Co","2","100","80","60","20","80","STRONG"\n'
        '"Weak Co","19","100","99","21","20","1","WEAK"\n'
        '"No Symbol","5","100","80","50","20","30",""\n'
        '"Some ETF","1","100","80","50","20","5","GILT10BETA"\n',
        encoding="utf-8",
    )
    wl = load_breakout_watchlist(csv)
    syms = [d["symbol"] for d in wl]
    assert "STRONG" in syms and "WEAK" in syms      # real stocks kept
    assert "" not in syms                            # no-symbol row dropped
    assert "GILT10BETA" not in syms                  # ETF dropped
    assert syms[0] == "STRONG"                       # ranked best-first
    assert wl[0]["score"] > wl[-1]["score"]
    assert wl[0]["sma50"] is not None                # breakout level captured


def test_breakout_watchlist_empty_for_non_breakout_csv(tmp_path):
    from sectorbot.stocks import load_breakout_watchlist
    csv = tmp_path / "u.csv"
    csv.write_text("Symbol,Industry\nAAA,Banks\n", encoding="utf-8")
    assert load_breakout_watchlist(csv) == []   # no breakout signals

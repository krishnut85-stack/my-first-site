"""Measuring what each sector actually did, month by month.

The point of the study is that it is evidence, so these tests build histories
whose answers are known in advance and check the numbers come back.
"""

import json
from datetime import date

import pytest

from garuda import cycle_study as cs


def series(monthly_pct, start_year=2015, months=120, extra=None):
    """A daily-ish series that moves `monthly_pct` each month.

    `extra` is {month: additional pct} — the planted seasonal effect.
    """
    out, price = [], 100.0
    y, m = start_year, 1
    for _ in range(months):
        bump = monthly_pct + (extra or {}).get(m, 0.0)
        price *= (1 + bump / 100.0)
        # two candles a month: the later one is the month-end close
        out.append({"t": f"{y:04d}-{m:02d}-15", "c": round(price * 0.99, 4)})
        out.append({"t": f"{y:04d}-{m:02d}-28", "c": round(price, 4)})
        m += 1
        if m > 12:
            m, y = 1, y + 1
    return out


def test_month_end_close_is_the_last_close_of_the_month():
    c = [{"t": "2020-01-02", "c": 10}, {"t": "2020-01-31", "c": 12},
         {"t": "2020-01-15", "c": 11}]
    assert cs.month_end_closes(c) == {(2020, 1): 12.0}


def test_returns_are_month_end_to_month_end():
    c = [{"t": "2020-01-31", "c": 100}, {"t": "2020-02-29", "c": 110}]
    assert cs.monthly_returns(c) == [(2020, 2, pytest.approx(10.0))]


def test_a_gap_in_the_data_is_not_a_return():
    """Jan then April is missing data, not a 3-month move booked as one."""
    c = [{"t": "2020-01-31", "c": 100}, {"t": "2020-04-30", "c": 130}]
    assert cs.monthly_returns(c) == []


def test_summarise_reports_hit_rate_and_sample_size():
    s = cs.summarise([2.0, -1.0, 4.0, -3.0])
    assert s["n"] == 4 and s["hit"] == 50
    assert s["mean"] == pytest.approx(0.5)


def test_empty_bucket_says_so_rather_than_guessing():
    assert cs.summarise([]) == {"n": 0, "mean": None, "median": None, "hit": None}


def test_a_planted_september_effect_is_recovered_as_excess():
    """The whole study in one test: sector beats the market only in September."""
    bench = cs.monthly_returns(series(1.0))
    sect = cs.monthly_returns(series(1.0, extra={9: 3.0}))
    t = cs.monthly_table(sect, bench)
    assert t[9]["excess"]["mean"] == pytest.approx(3.0, abs=0.05)
    assert t[9]["excess"]["hit"] == 100
    assert t[4]["excess"]["mean"] == pytest.approx(0.0, abs=0.05)
    # raw return alone would NOT isolate this — it carries the market too
    assert t[9]["raw"]["mean"] > t[9]["excess"]["mean"]


def test_ranking_puts_the_seasonal_winner_first_in_its_month():
    bench = cs.monthly_returns(series(1.0))
    tables = {
        "AUTO": cs.monthly_table(cs.monthly_returns(series(1.0, extra={11: 4.0})), bench),
        "IT": cs.monthly_table(cs.monthly_returns(series(1.0)), bench),
        "FMCG": cs.monthly_table(cs.monthly_returns(series(1.0, extra={11: -2.0})), bench),
    }
    nov = cs.rank_by_month(tables)[11]
    assert nov[0]["sector"] == "AUTO"
    assert nov[-1]["sector"] == "FMCG"          # the month's worst is named too
    assert nov[0]["n"] >= 5


def test_coverage_reports_the_span_actually_obtained():
    rets = {"AUTO": cs.monthly_returns(series(1.0, start_year=2018, months=36))}
    cov = cs.coverage(rets)
    assert cov["first_year"] == 2018 and cov["last_year"] == 2020
    assert cov["years"] == 3
    assert cov["observations"] == 35        # 36 months -> 35 returns


def test_build_produces_the_json_the_dashboard_reads():
    data = {"_BENCH": series(1.0),
            "AUTO": series(1.0, extra={11: 4.0}),
            "IT": series(1.0, extra={7: 2.0})}
    study = cs.build(data)
    assert study["benchmark"] == cs.BENCHMARK
    assert set(study["sectors"]) == {"AUTO", "IT"}
    assert len(study["months"]) == 12
    assert study["ranked"]["11"][0]["sector"] == "AUTO"
    assert study["ranked"]["7"][0]["sector"] == "IT"
    assert study["coverage"]["years"] == 10
    json.dumps(study)          # must be serialisable as-is


def test_no_history_yields_no_false_confidence():
    study = cs.build({"_BENCH": [], "AUTO": []})
    assert study["sectors"] == []
    assert study["coverage"]["years"] == 0


def test_sector_names_match_the_rest_of_the_system():
    from garuda import macro
    known = set(cs.SECTOR_INDICES)
    for phase in macro.PHASES:
        assert macro.PHASE_SECTORS[phase] <= known
        assert macro.PHASE_AVOID[phase] <= known


# ------------------------------------------- industries, not indices ----

def test_universe_csv_maps_stocks_to_industries(tmp_path):
    p = tmp_path / "u.csv"
    p.write_text("NSE Code,Stock Name,Industry,Sector\n"
                 "ACC,ACC Ltd,Cement,Construction Materials\n"
                 "ULTRACEMCO,UltraTech,Cement,Construction Materials\n"
                 "TITAN,Titan,Gems & Jewellery,Consumer Discretionary\n")
    u = cs.load_universe([p])
    assert u["ACC"] == ("Cement", "Construction Materials")
    g = cs.by_industry(u)
    assert g["Cement"]["members"] == ["ACC", "ULTRACEMCO"]
    assert g["Cement"]["sector"] == "Construction Materials"


def test_universe_accepts_a_plain_symbol_column(tmp_path):
    p = tmp_path / "u.csv"
    p.write_text("SYMBOL,Industry\nDLF,Realty\n")
    assert cs.load_universe([p])["DLF"][0] == "Realty"


def test_missing_or_unreadable_universe_files_are_skipped(tmp_path):
    assert cs.load_universe([tmp_path / "nope.csv"]) == {}
    bad = tmp_path / "bad.csv"
    bad.write_text("\x00 not a csv")
    cs.load_universe([bad])            # must not raise


def test_industry_is_equal_weight_on_returns_not_prices():
    """A 2000-rupee stock must not outvote a 20-rupee one."""
    stocks = {
        "BIG": [{"t": "2024-01-01", "c": 2000}, {"t": "2024-01-02", "c": 2020}],   # +1%
        "MID": [{"t": "2024-01-01", "c": 200}, {"t": "2024-01-02", "c": 220}],     # +10%
        "SMALL": [{"t": "2024-01-01", "c": 20}, {"t": "2024-01-02", "c": 24}],     # +20%
    }
    s = cs.industry_series(["BIG", "MID", "SMALL"], stocks)
    # mean of +1, +10, +20 = +10.33%, NOT the price-weighted +1.1%
    assert s[-1]["c"] == pytest.approx(100 * 1.10333, abs=0.01)


def test_a_thin_day_is_dropped_rather_than_averaged():
    """Two companies is not an industry — MIN_MEMBERS guards the average."""
    stocks = {
        "A": [{"t": "2024-01-01", "c": 100}, {"t": "2024-01-02", "c": 110},
              {"t": "2024-01-03", "c": 121}],
        "B": [{"t": "2024-01-01", "c": 100}, {"t": "2024-01-02", "c": 110}],
        "C": [{"t": "2024-01-01", "c": 100}, {"t": "2024-01-02", "c": 110}],
    }
    s = cs.industry_series(["A", "B", "C"], stocks)
    assert [r["t"] for r in s] == ["2024-01-02"]      # the 3rd has only A


def test_a_late_listing_joins_the_average_from_its_own_start():
    stocks = {
        "OLD1": [{"t": f"2024-01-0{d}", "c": 100 + d} for d in range(1, 6)],
        "OLD2": [{"t": f"2024-01-0{d}", "c": 200 + d} for d in range(1, 6)],
        "OLD3": [{"t": f"2024-01-0{d}", "c": 300 + d} for d in range(1, 6)],
        "NEW": [{"t": f"2024-01-0{d}", "c": 50 + d} for d in range(4, 6)],
    }
    s = cs.industry_series(["OLD1", "OLD2", "OLD3", "NEW"], stocks)
    assert len(s) == 4          # days 2..5; NEW only contributes from day 5


def test_an_industry_with_no_data_is_absent_not_zero():
    assert cs.industry_series(["GHOST"], {}) == []


def test_build_carries_industry_metadata_through():
    bench = series(1.0)
    data = {"_BENCH": bench, "Cement": series(1.0, extra={2: 3.0})}
    meta = {"Cement": {"sector": "Construction Materials", "members": 12,
                       "with_data": 11}}
    study = cs.build(data, meta)
    assert study["meta"]["Cement"]["sector"] == "Construction Materials"
    assert study["ranked"]["2"][0]["sector"] == "Cement"


def test_a_missing_kite_session_names_the_missing_piece(monkeypatch, tmp_path):
    """'no live session' is useless; say which of the three things is absent."""
    for var in ("KITE_API_KEY", "KITE_ACCESS_TOKEN", "KITE_TOKEN_FILE"):
        monkeypatch.delenv(var, raising=False)
    said = " ".join(cs.why_no_kite())
    assert "KITE_API_KEY" in said and "KITE_TOKEN_FILE" in said

    monkeypatch.setenv("KITE_API_KEY", "abc")
    monkeypatch.setenv("KITE_TOKEN_FILE", str(tmp_path / "gone.json"))
    said = " ".join(cs.why_no_kite())
    assert "does not exist" in said
    assert "KITE_API_KEY is not set" not in said      # that one is satisfied now

    empty = tmp_path / "tok.json"
    empty.write_text('{"date": "2026-01-01"}')
    monkeypatch.setenv("KITE_TOKEN_FILE", str(empty))
    assert "no access_token" in " ".join(cs.why_no_kite())


def test_scan_reports_what_each_file_yields(tmp_path):
    """Answer 'will this find my stocks?' offline, before any Kite call."""
    good = tmp_path / "constituents.csv"
    good.write_text("Company Name,Industry,Symbol,Series\n"
                    "ACC Ltd,Cement,ACC,EQ\n"
                    "UltraTech,Cement,ULTRACEMCO,EQ\n"
                    "Titan,Consumer Durables,TITAN,EQ\n")
    prices = tmp_path / "strength_daily.csv"
    prices.write_text("date,close\n2024-01-01,100\n")     # no industry column
    rows = cs.scan_universe([good, prices])
    assert len(rows) == 1                      # the price file is ignored
    assert rows[0][1] == 3 and rows[0][2] == 2


def test_discovery_looks_in_the_dashboards_csv_dir(tmp_path):
    """The NSE constituent lists live wherever --csv-dir points, not in the repo."""
    (tmp_path / "ind_nifty50list.csv").write_text("Symbol,Industry\nINFY,IT\n")
    files = cs.find_universe_files(csv_dir=tmp_path)
    assert any(f.name == "ind_nifty50list.csv" for f in files)
    assert cs.load_universe(files)["INFY"][0] == "IT"


def test_discovery_ignores_its_own_price_cache(tmp_path, monkeypatch):
    """The cache is hundreds of CSVs with no industry column — never scan it."""
    monkeypatch.setattr(cs, "STOCK_DIR", tmp_path / "stock_history")
    monkeypatch.setattr(cs, "HISTORY_DIR", tmp_path / "sector_history")
    (tmp_path / "stock_history").mkdir()
    (tmp_path / "stock_history" / "INFY.csv").write_text("t,c\n2024-01-01,100\n")
    (tmp_path / "ind_nifty50list.csv").write_text("Symbol,Industry\nINFY,IT\n")
    files = cs.find_universe_files(csv_dir=tmp_path)
    names = [f.name for f in files]
    assert "ind_nifty50list.csv" in names
    assert "INFY.csv" not in names


def test_one_bad_print_cannot_move_a_whole_industry():
    """A stock printing 50 -> 5000 -> 50 must not lift its industry 900%."""
    stocks = {f"OK{i}": [{"t": f"2020-01-{d:02d}", "c": 100.0}
                         for d in range(1, 6)] for i in range(10)}
    stocks["BAD"] = [{"t": "2020-01-01", "c": 50.0}, {"t": "2020-01-02", "c": 50.0},
                     {"t": "2020-01-03", "c": 5000.0},
                     {"t": "2020-01-04", "c": 50.0}, {"t": "2020-01-05", "c": 50.0}]
    diag = {}
    s = cs.industry_series(list(stocks), stocks, diag=diag)
    assert all(r["c"] == pytest.approx(100.0) for r in s)
    assert diag["dropped"] == 2          # the spike and its mirror


def test_a_split_lets_the_stock_rejoin_at_its_new_price():
    """A 1:10 split is not a -90% return; the shareholder lost nothing."""
    stocks = {f"OK{i}": [{"t": f"2020-01-{d:02d}", "c": 100.0}
                         for d in range(1, 5)] for i in range(3)}
    stocks["SPLIT"] = [{"t": "2020-01-01", "c": 1000.0},
                       {"t": "2020-01-02", "c": 100.0},    # 1:10
                       {"t": "2020-01-03", "c": 105.0},    # +5%, real
                       {"t": "2020-01-04", "c": 105.0}]
    s = cs.industry_series(list(stocks), stocks)
    lvls = [r["c"] for r in s]
    assert lvls[0] == pytest.approx(100.0)       # split day contributes nothing
    assert lvls[1] > lvls[0]                     # the real +5% still counts


def test_a_real_move_inside_the_band_is_kept():
    stocks = {f"S{i}": [{"t": "2020-01-01", "c": 100.0},
                        {"t": "2020-01-02", "c": 118.0}] for i in range(4)}
    s = cs.industry_series(list(stocks), stocks)
    assert s[0]["c"] == pytest.approx(118.0)     # +18% is a real day


# ------------------------------------------- what is running right now ----

def rising(step, n=300):
    out, lvl = [], 100.0
    for i in range(n):
        lvl *= (1 + step / 100)
        out.append({"t": f"2026-{i % 12 + 1:02d}-{i % 28 + 1:02d}",
                    "c": round(lvl, 6)})
    return out


def test_trailing_now_measures_to_the_latest_close():
    s = [{"t": f"2026-01-{i:02d}", "c": 100.0} for i in range(1, 30)]
    s.append({"t": "2026-02-01", "c": 121.0})
    got = cs.trailing_now(s, {"21d": 21})
    assert got["21d"] == pytest.approx(21.0)


def test_a_window_longer_than_the_history_says_none_not_zero():
    s = [{"t": "2026-01-01", "c": 100.0}, {"t": "2026-01-02", "c": 110.0}]
    assert cs.trailing_now(s, {"12m": 252})["12m"] is None


def test_the_fastest_riser_ranks_first_on_the_quarter():
    """The aluminium case: a big quarter must surface at the top."""
    data = {"Aluminium": rising(0.8), "Cement": rising(0.2),
            "Sugar": rising(-0.1), "_BENCH": rising(0.15)}
    rows = cs.momentum_now(data, {"Aluminium": {"sector": "Metals",
                                                "members": 9}})
    assert [r["industry"] for r in rows] == ["Aluminium", "Cement", "Sugar"]
    assert "_BENCH" not in [r["industry"] for r in rows]
    assert rows[0]["3m"] > 50 and rows[0]["sector"] == "Metals"
    assert rows[0]["as_of"] == data["Aluminium"][-1]["t"]


def test_industries_without_enough_history_still_rank_last_not_first():
    data = {"Old": rising(0.5), "New": rising(5.0, n=10)}
    rows = cs.momentum_now(data)
    assert rows[0]["industry"] == "Old"      # New has no 3m figure yet
    assert rows[-1]["3m"] is None


def test_build_carries_the_now_ranking():
    data = {"_BENCH": series(1.0), "Metals": series(1.0, extra={5: 4.0})}
    study = cs.build(data)
    assert "now" in study and "now_windows" in study
    assert study["now"][0]["industry"] == "Metals"


def test_an_explicit_universe_is_not_merged_with_the_broad_lists(tmp_path):
    """--universe means use THAT. Otherwise a coarse label overwrites a fine one."""
    fine = tmp_path / "fine"
    fine.mkdir()
    (fine / "trendlyne.csv").write_text("NSE Code,Industry\nHINDALCO,Aluminium\n")
    coarse = tmp_path / "broad"
    coarse.mkdir()
    (coarse / "ind_nifty500list.csv").write_text(
        "Symbol,Industry\nHINDALCO,Metals & Mining\n")
    files = cs.find_universe_files(extra=fine, csv_dir=coarse)
    assert all("trendlyne" in f.name for f in files)
    assert cs.load_universe(files)["HINDALCO"][0] == "Aluminium"

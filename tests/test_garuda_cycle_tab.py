"""The CYCLE tab: the rate cycle, rendered where the trading actually happens."""

from datetime import date
from pathlib import Path

import pytest

from garuda import config, macro
from garuda.live import GarudaLive

DASH = Path(__file__).resolve().parent.parent / "garuda" / "dashboard_live.html"


def test_server_exposes_the_macro_state(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    st = GarudaLive(csv_dir=str(tmp_path)).build_state()
    m = st["macro"]
    for k in ("phase", "suggested", "why", "signals", "sectors", "avoid",
              "order", "calendar", "month", "stale"):
        assert k in m, k
    assert m["order"] == list(macro.PHASES)
    assert len(m["calendar"]) == 12


def test_dashboard_wires_the_tab(tmp_path):
    html = DASH.read_text()
    assert "data-f=cycle" in html                 # the tab exists
    assert "setFilter('cycle'" in html            # it is clickable
    assert "FILTER==='cycle'" in html             # it routes to a panel
    assert "function cyclePanel" in html          # the panel exists
    # every phase is directly labelled, so colour is never the only encoding
    assert "cyclab" in html and "PHNAME" in html


def test_missing_gir_files_do_not_break_the_dashboard(tmp_path, monkeypatch):
    """Garuda reads GIR's files; if that box is not there the tab still renders."""
    monkeypatch.setattr(macro, "GIR_HOME", tmp_path / "nowhere")
    monkeypatch.setattr(macro.config, "BASE_DIR", tmp_path)
    st = macro.state()
    assert st["phase"] == macro.UNKNOWN
    assert st["signals"]["repo"]["vote"] is None
    assert len(st["calendar"]) == 12          # the calendar layer is static


def test_calendar_layer_is_flat_except_the_two_real_patterns():
    cal = {c["m"]: c["mult"] for c in macro.state(date(2026, 9, 5))["calendar"]}
    assert cal[3] == macro.MARCH_MULT                 # March, every sector
    assert cal[10] == cal[11] == macro.AUTO_FESTIVE_MULT   # festive autos
    assert [m for m, v in cal.items() if v != 1.0] == [3, 10, 11]


def test_phase_sectors_are_named_the_way_the_index_map_names_them():
    known = {"BANKING", "IT", "PHARMA", "FMCG", "AUTO", "METALS", "ENERGY",
             "REALTY", "SERVICES", "HEALTHCARE", "CONSUMPTION", "PSUBANK",
             "PVTBANK", "MEDIA", "INFRA", "OILGAS"}
    for phase in macro.PHASES:
        assert macro.PHASE_SECTORS[phase] <= known
        assert not (macro.PHASE_SECTORS[phase] & macro.PHASE_AVOID[phase])

"""The macro rate cycle drives sector choice; the calendar may only size.

Layer 1 is a state machine that rotates on two of three signals. Layer 2 is a
sizing multiplier that is exactly 1.0 everywhere the evidence is thin — the
tests below pin both properties, because the whole design rests on them.
"""

import importlib.util
import json
from datetime import date
from pathlib import Path

import pytest


@pytest.fixture(scope="module")
def mc():
    path = Path(__file__).resolve().parent.parent / "gir" / "macro_cycle.py"
    spec = importlib.util.spec_from_file_location("gir_macro_cycle", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


TODAY = date(2026, 9, 5)


def sig(**kw):
    base = {"as_of": TODAY.isoformat(), "repo_direction": "holding_after_cuts",
            "gsec_10y_slope_3m_bps": -8, "credit_growth_yoy_trend": "accelerating"}
    base.update(kw)
    return base


# ------------------------------------------------------------- layer 1 ----

def test_three_agreeing_signals_set_the_phase(mc):
    phase, why = mc.advance(mc.UNKNOWN, sig(), TODAY)
    assert phase == mc.EXPANSION
    assert "3/3" in why


def test_one_signal_flipping_does_not_rotate(mc):
    """The rule that makes this a state machine and not a lookup."""
    # repo turns hawkish alone; gsec and credit still say expansion
    phase, why = mc.advance(mc.EXPANSION, sig(repo_direction="hiking"), TODAY)
    assert phase == mc.EXPANSION
    assert "noise" in why or "confirm" in why


def test_two_of_three_rotate(mc):
    phase, why = mc.advance(mc.EXPANSION,
                            sig(repo_direction="hiking",
                                credit_growth_yoy_trend="decelerating"), TODAY)
    assert phase == mc.SLOWDOWN
    assert "rotate" in why and "2/3" in why


def test_easing_reads_as_easing(mc):
    phase, _ = mc.advance(mc.UNKNOWN,
                          sig(repo_direction="cutting",
                              gsec_10y_slope_3m_bps=-40,
                              credit_growth_yoy_trend="flat"), TODAY)
    assert phase == mc.EASING


def test_stale_signals_cannot_move_the_phase(mc):
    old = sig(as_of="2026-06-01", repo_direction="hiking",
              credit_growth_yoy_trend="decelerating")
    phase, why = mc.advance(mc.EXPANSION, old, TODAY)
    assert phase == mc.EXPANSION            # would have rotated if fresh
    assert "refresh" in why


def test_undated_signals_are_stale(mc):
    s = sig()
    s.pop("as_of")
    assert mc.is_stale(s, TODAY)


def test_empty_or_broken_signals_hold_the_phase(mc):
    for bad in ({}, {"repo_direction": "wobbling"}, {"as_of": "not-a-date"}):
        phase, why = mc.advance(mc.EASING, bad, TODAY)
        assert phase == mc.EASING
        assert "holding" in why


def test_missing_file_returns_empty_not_an_exception(mc, tmp_path):
    assert mc.read_signals(tmp_path / "nope.json") == {}


def test_corrupt_file_returns_empty_not_an_exception(mc, tmp_path):
    p = tmp_path / "macro_signals.json"
    p.write_text("{not json")
    assert mc.read_signals(p) == {}


def test_shipped_signals_file_is_valid_and_current(mc):
    """The committed reading must parse and classify — it seeds the machine."""
    path = Path(__file__).resolve().parent.parent / "gir" / "macro_signals.json"
    data = json.loads(path.read_text())
    phase, _ = mc.advance(mc.UNKNOWN, data, date.fromisoformat(data["as_of"]))
    assert phase in mc.PHASES


@pytest.mark.parametrize("bps,expected", [
    (-40, "EASING"), (-15, "EASING"), (-8, "EXPANSION"),
    (0, "EXPANSION"), (24, "EXPANSION"), (25, "SLOWDOWN"), (80, "SLOWDOWN"),
])
def test_gsec_slope_thresholds(mc, bps, expected):
    assert mc.vote_gsec({"gsec_10y_slope_3m_bps": bps}) == expected


def test_sector_tilt_follows_the_phase(mc):
    assert mc.sector_tilt("INFRA", mc.EXPANSION) == 1
    assert mc.sector_tilt("BANKING", mc.EXPANSION) == -1   # easing run is behind it
    assert mc.sector_tilt("BANKING", mc.EASING) == 1
    assert mc.sector_tilt("MEDIA", mc.EXPANSION) == 0      # no view
    assert mc.sector_tilt("INFRA", mc.UNKNOWN) == 0        # no phase, no opinion
    assert mc.sector_tilt(None, mc.EXPANSION) == 0


def test_phase_sectors_use_gir_index_names(mc):
    """Sector names must match SECTOR_INDICES_MAP or the tilt silently no-ops."""
    known = {"BANKING", "IT", "PHARMA", "FMCG", "AUTO", "METALS", "ENERGY",
             "REALTY", "SERVICES", "HEALTHCARE", "CONSUMPTION", "PSUBANK",
             "PVTBANK", "MEDIA", "INFRA", "OILGAS"}
    for phase in mc.PHASES:
        assert mc.PHASE_SECTORS[phase] <= known, phase
        assert mc.PHASE_AVOID[phase] <= known, phase
        # a sector cannot both lead and be avoided in the same phase
        assert not (mc.PHASE_SECTORS[phase] & mc.PHASE_AVOID[phase]), phase


# ------------------------------------------------------------- layer 2 ----

def test_only_two_calendar_patterns_move_sizing(mc):
    """Everything the evidence does not support must multiply by exactly 1.0."""
    sectors = ["AUTO", "INFRA", "IT", "BANKING", "FMCG", "PHARMA"]
    moved = set()
    for month in range(1, 13):
        for s in sectors:
            m = mc.size_multiplier(s, date(2026, month, 15))
            if m != 1.0:
                moved.add((month, s, m))
    assert {(m, s) for m, s, _ in moved} == {
        (3, "AUTO"), (3, "INFRA"), (3, "IT"),
        (3, "BANKING"), (3, "FMCG"), (3, "PHARMA"),   # March, every sector
        (10, "AUTO"), (11, "AUTO"),                    # festive auto
    }


def test_sizing_multiplier_is_bounded_and_never_zero(mc):
    for month in range(1, 13):
        for s in ("AUTO", "IT", None, ""):
            m = mc.size_multiplier(s, date(2026, month, 15))
            assert mc.MULT_FLOOR <= m <= mc.MULT_CEILING
            assert m > 0          # the calendar can shrink a trade, never veto it


def test_march_beats_the_festive_bonus(mc):
    assert mc.size_multiplier("AUTO", date(2026, 3, 15)) == mc.MARCH_MULT


def test_calendar_note_is_text_only(mc):
    note = mc.calendar_note(date(2026, 11, 3))
    assert isinstance(note, str) and note
    # nothing numeric leaks out of the note into sizing
    assert mc.size_multiplier("IT", date(2026, 11, 3)) == 1.0


def test_describe_reads_cleanly(mc):
    line = mc.describe(mc.EXPANSION, date(2026, 9, 5))
    assert "EXPANSION" in line and "INFRA" in line and "sizing only" in line
    assert "UNKNOWN" in mc.describe(mc.UNKNOWN, date(2026, 9, 5))


def test_phase_persists_and_cache_follows_the_file(mc, tmp_path):
    """Scoring reads this per symbol, so it is cached — but must not go stale."""
    f = tmp_path / "macro_phase.json"
    assert mc.load_phase(f) == mc.UNKNOWN          # nothing recorded yet
    mc.save_phase(mc.EXPANSION, f, "3/3", TODAY)
    assert mc.load_phase(f) == mc.EXPANSION
    assert mc.load_phase(f) == mc.EXPANSION        # served from cache
    mc.save_phase(mc.SLOWDOWN, f, "2/3", TODAY)
    assert mc.load_phase(f) == mc.SLOWDOWN         # cache invalidated on write
    f.write_text("{garbage")
    assert mc.load_phase(f) == mc.UNKNOWN          # never raises into the caller


def test_save_phase_never_raises_on_a_bad_path(mc, tmp_path):
    mc.save_phase(mc.EASING, tmp_path / "no" / "such" / "dir" / "p.json", "x", TODAY)


# ----------------------------------------------------------------- CLI ----

@pytest.mark.parametrize("words,expected", [
    (["hold", "-8", "up"],
     ("holding_after_cuts", -8, "accelerating")),
    (["cut", "-40", "flat"], ("cutting", -40, "flat")),
    (["hike", "40", "down"], ("hiking", 40, "decelerating")),
    (["HOLD", "0", "UP"], ("holding_after_cuts", 0, "accelerating")),
    (["hold", "-7.6", "up"], ("holding_after_cuts", -8, "accelerating")),
])
def test_cli_parses_phone_shorthand(mc, words, expected):
    got = mc.parse_set(words)
    assert (got["repo_direction"], got["gsec_10y_slope_3m_bps"],
            got["credit_growth_yoy_trend"]) == expected


@pytest.mark.parametrize("words", [
    [], ["hold"], ["hold", "-8"], ["hold", "-8", "up", "extra"],
    ["banana", "-8", "up"], ["hold", "sideways", "up"], ["hold", "-8", "maybe"],
])
def test_cli_rejects_junk_rather_than_guessing(mc, words):
    with pytest.raises(ValueError):
        mc.parse_set(words)


def test_cli_set_refreshes_the_date_and_drops_the_stale_note(mc, tmp_path,
                                                             monkeypatch):
    p = tmp_path / "macro_signals.json"
    p.write_text(json.dumps({"as_of": "2026-01-01", "note": "old conditions",
                             "repo_direction": "cutting",
                             "gsec_10y_slope_3m_bps": -40,
                             "credit_growth_yoy_trend": "flat"}))
    monkeypatch.setattr(mc, "_bases", lambda: [tmp_path])
    assert mc._cli(["set", "hike", "40", "down"]) == 0
    written = json.loads(p.read_text())
    assert written["repo_direction"] == "hiking"
    assert written["as_of"] == date.today().isoformat()
    assert "note" not in written


def test_cli_status_survives_a_missing_file(mc, tmp_path, monkeypatch):
    monkeypatch.setattr(mc, "_bases", lambda: [tmp_path])
    assert mc._cli([]) == 1          # tells you what to run, does not crash


def test_cli_where_always_works(mc):
    assert mc._cli(["where"]) == 0
    assert len(mc.SOURCES) == 3


def test_phase_path_finds_the_bots_data_dir_first(mc, tmp_path, monkeypatch):
    """gir.py persists the phase under DATA_DIR — the CLI must read that one."""
    monkeypatch.setattr(mc, "_bases", lambda: [tmp_path])
    assert mc.phase_path() == tmp_path / "data" / "macro_phase.json"   # default
    (tmp_path / "data").mkdir()
    mc.save_phase(mc.EXPANSION, tmp_path / "data" / "macro_phase.json", "3/3", TODAY)
    assert mc.load_phase(mc.phase_path()) == mc.EXPANSION

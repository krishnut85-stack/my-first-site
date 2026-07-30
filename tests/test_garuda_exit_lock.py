"""EXIT LOCK — every book's validated exit settings, frozen in one place.

If any of these numbers changes without a new validation run, this test fails
loudly. That is the point: exits are the half of every strategy that the
sweeps actually validated, so they must never drift silently.
"""

from garuda.live import GarudaLive
from garuda.strategy import PROFILES


def test_dip_books_exits():
    mc = PROFILES["microcap"]            # original quick-exit contract
    assert mc.exit_rsi == 85             # sell the relief
    assert mc.max_hold == 30             # 30-day time stop
    assert mc.hard_stop == 0.20          # validated catastrophe floor
    sc = PROFILES["smallcap"]            # DIP EXAM + DIP RACE retune (patient)
    assert sc.exit_rsi >= 100            # RSI-recovery exit disabled
    assert sc.trail == 0.25 and sc.max_hold == 180
    assert sc.hard_stop == 0.0           # the trail is the disaster floor


def test_trend_books_exits():
    assert PROFILES["next50"].trail == 0.15 and PROFILES["next50"].max_hold == 120
    assert PROFILES["strength"].trail == 0.12 and PROFILES["strength"].max_hold == 90
    assert PROFILES["leaders"].trail == 0.20 and PROFILES["leaders"].max_hold == 180


def test_scalein_exits():
    p = PROFILES["scalein"]
    assert p.exit_rsi == 50 and p.max_hold == 60
    assert p.stop == 0.25 and p.max_units == 4


def test_lab_discovered_books_exits():
    hi = PROFILES["hi52"]                # exit-sweep validated
    assert hi.trail == 0.15 and hi.max_hold == 120
    cr = PROFILES["crash"]               # exit-sweep winner (25%/180 HELD on TEST)
    assert cr.trail == 0.25 and cr.max_hold == 180
    assert cr.hard_stop == 0.0           # no extra stop — the trail IS the exit


def test_chakra_exits_by_rotation_only():
    p = PROFILES["chakra"]
    assert p.mom_days == 189 and p.max_units == 20
    assert p.trail == 0.15               # unused by the chakra engine (rotation
    assert p.hard_stop == 0.0            # exits) — asserted so a future engine
                                         # change is forced to re-look here


def test_qmom_exits_by_annual_rotation_only():
    p = PROFILES["qmom"]                 # SCREEN LAB winner — forward paper trial
    assert p.mom_days == 189             # the backtested momentum horizon
    assert p.hard_stop == 0.0            # no stop: 12-month hold, as backtested
    assert "July" in p.rules             # the July turn IS the exit


def test_captain_exits_by_list_edits_only():
    p = PROFILES["captain"]              # the discretionary seat
    assert p.hard_stop == 0.0            # no stops by design —
    assert "exits" in p.rules            # the captain's edits are the exits


def test_options_book_risk_settings():
    g = GarudaLive(csv_dir="/nonexistent")
    ob = g.options
    assert ob.dist == 0.025              # +/-2.5% short strikes
    assert ob.wing == 0.01               # 1% wings -> defined risk
    assert ob.alloc_pct == 0.02          # max loss = 2% of book per week
    assert ob.credit_frac == 0.30        # modelled premium (flagged assumption)


def test_every_equity_book_has_a_stop_path():
    """No book may hold a loser forever: each needs a trail, a hard stop, an
    RSI/time exit, or (chakra/qmom) the rotation itself."""
    rotation = ("chakra", "qmom", "captain")   # the rotation IS the exit
    for k, p in PROFILES.items():
        has_exit = (p.trail > 0 or p.hard_stop > 0 or p.stop > 0
                    or p.exit_rsi < 100 or p.strategy in rotation)
        assert has_exit, f"{k} has no exit path!"
        if p.strategy not in rotation:
            assert p.max_hold > 0, f"{k} has no time stop!"

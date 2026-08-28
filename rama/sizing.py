"""Position sizing — flat cap or fractional Kelly from Rama's OWN measured edge.

The Kelly criterion answers "what fraction of capital should I stake given my
edge?" For a bet that wins with probability W and pays reward/risk R (avg win /
avg loss), the growth-optimal fraction is:

    f* = W - (1 - W) / R

Full Kelly is famously too aggressive — it assumes you know W and R exactly,
which you never do, and it produces gut-wrenching drawdowns. So Rama uses
*fractional* Kelly (half by default) and hard-caps the result.

Crucially, the edge (W, R) is measured from Rama's OWN closed-trade history — so
the bot only sizes up after it has actually demonstrated an edge on paper, and
falls back to the flat cap until it has enough trades to trust the numbers.
This keeps the "prove it on paper first" discipline intact.

PAPER ONLY — this decides quantities in the simulation; no real orders.
"""

from statistics import mean

from . import config


def kelly_fraction(win_rate: float, reward_risk: float,
                   fraction: float = 1.0) -> float:
    """Fractional Kelly stake as a fraction of capital (never negative).

    win_rate      : probability of a winning trade, 0..1
    reward_risk   : average win / average loss (R). Must be > 0.
    fraction      : Kelly multiplier (e.g. 0.5 = half-Kelly).
    """
    if reward_risk <= 0:
        return 0.0
    f_star = win_rate - (1.0 - win_rate) / reward_risk
    return max(0.0, f_star) * fraction


def measure_edge(pf) -> tuple[float, float, int]:
    """Measure (win_rate, reward_risk, n_closed_trades) from the portfolio's
    OWN closed trades. Before any trades exist, return the configured defaults
    so early sizing is sane (and clearly flagged as an assumption)."""
    closed = [t for t in pf.trades if t.get("side") == "SELL" and "pnl" in t]
    n = len(closed)
    if n == 0:
        return (config.KELLY_DEFAULT_WIN_RATE, config.KELLY_DEFAULT_RR, 0)
    wins = [t["pnl"] for t in closed if t["pnl"] > 0]
    losses = [-t["pnl"] for t in closed if t["pnl"] <= 0]
    win_rate = len(wins) / n
    avg_win = mean(wins) if wins else 0.0
    avg_loss = mean(losses) if losses else 0.0
    reward_risk = (avg_win / avg_loss) if avg_loss > 0 else config.KELLY_DEFAULT_RR
    return (win_rate, reward_risk, n)


def _flat_fraction() -> float:
    return config.MAX_ALLOCATION_PER_NAME


def target_fraction(pf) -> tuple[float, str]:
    """The fraction of capital to allocate to a NEW name, plus a short label
    explaining how it was chosen (for reporting)."""
    if config.SIZING_MODE != "kelly":
        return _flat_fraction(), "flat cap"

    win_rate, reward_risk, n = measure_edge(pf)
    if n < config.KELLY_MIN_TRADES:
        return (_flat_fraction(),
                f"flat cap (only {n}/{config.KELLY_MIN_TRADES} trades — "
                "not enough to trust Kelly yet)")

    f = kelly_fraction(win_rate, reward_risk, config.KELLY_FRACTION)
    if f <= 0:
        # measured edge is zero/negative -> Kelly says don't press; use the
        # flat cap as a conservative floor rather than sizing to zero.
        return (_flat_fraction(),
                f"flat cap (no measured edge: W={win_rate:.0%}, R={reward_risk:.2f})")
    frac = min(f, config.KELLY_MAX_ALLOCATION)
    return (frac,
            f"{config.KELLY_FRACTION:g}x-Kelly {frac:.1%} "
            f"(W={win_rate:.0%}, R={reward_risk:.2f}, n={n})")


def position_budget(pf, capital: float | None = None) -> float:
    """Rupee budget for a single new name. Never exceeds an equal split across
    MAX_POSITIONS (so Kelly can't over-concentrate the whole book)."""
    capital = capital if capital is not None else config.PAPER_CAPITAL
    frac, _ = target_fraction(pf)
    per_name = capital * frac
    equal_split = capital / max(config.MAX_POSITIONS, 1)
    return min(per_name, equal_split)

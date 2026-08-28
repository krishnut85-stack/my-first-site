"""Markov next-move predictor — the screenshot's 'MARKOV · SELF-LEARN' pillar.

The 'state' is the tuple of the last `order` bar-directions (1 = up, 0 = down).
For each state we keep counts of how often the NEXT bar went up vs down, with
Laplace smoothing so an unseen state predicts a neutral 50/50. `prob_up(state)`
is just up_count / total for that state. `update(state, up)` learns online — so
the model keeps adapting as new bars arrive ("self-learn").

This is deliberately simple and transparent: no black box, no fabricated Sharpe.
Whether it has any edge is an empirical question the backtester answers honestly.
"""

from dataclasses import dataclass, field


@dataclass
class MarkovPredictor:
    order: int = 3
    # state (tuple of 0/1) -> [down_count, up_count], both seeded at 1 (Laplace)
    counts: dict = field(default_factory=dict)

    def _key(self, state) -> tuple:
        return tuple(state[-self.order:])

    def prob_up(self, state) -> float:
        """P(next bar up | state). Returns 0.5 for an unseen/short state."""
        if len(state) < self.order:
            return 0.5
        c = self.counts.get(self._key(state))
        if c is None:
            return 0.5
        down, up = c
        return up / (down + up)

    def update(self, state, up: bool) -> None:
        """Record that, after `state`, the next bar went up (True) or down."""
        if len(state) < self.order:
            return
        c = self.counts.setdefault(self._key(state), [1, 1])
        c[1 if up else 0] += 1

    def states_seen(self) -> int:
        return len(self.counts)

"""Garuda — the screenshot's fast, directional model, applied to Indian equity.

A SEPARATE bot (its own package; nothing shared with sectorbot or Rama). It
mirrors the viral dashboard's *engine* — a Markov next-move predictor that
self-learns, Kelly sizing, and an audit gate — but trades **legal NSE
instruments on short (e.g. 5-minute) bars**, long and short, instead of the
screenshot's (illegal-in-India) crypto binaries.

Design intent, in order:
  1. markov.py   — the directional predictor (self-learning transition counts)
  2. backtest.py — replay bars and measure, HONESTLY (costs in), whether the
                   model has any edge vs buy & hold. This runs FIRST — before
                   any execution is built — because a fast directional model
                   must earn its keep on real data before risking anything.

Paper / research only. No live-order path in this package yet.
"""

__all__ = ["config", "markov", "backtest", "data"]

# UPGRADE 8 - CALENDAR EFFECTS (measured on discovery years, checked on unseen years) - 2026-11-21

'holds' = same sign and |t| >= 2 in BOTH the discovery and the unseen years (in-window days vs all other days). Long NIFTY: discovery 2010-2018, unseen 2019-2026. Returns are close-to-close %, unless 'gap'.

| effect | unseen n | unseen mean in / out | unseen up-share in / out | unseen abs in / out | t (disc / unseen) | t abs (disc / unseen) | verdict |
|---|---|---|---|---|---|---|---|
| NIFTY in the monthly expiry week (to expiry day) | 452 | 0.013 / 0.061 | 0.489 / 0.553 | 0.76 / 0.717 | -1.66 / -0.76 | -0.11 / 0.88 | does not hold |
| NIFTY on monthly expiry day | 95 | 0.001 / 0.053 | 0.463 / 0.542 | 0.75 / 0.725 | -0.24 / -0.45 | 0.88 / 0.29 | does not hold |
| NIFTY on the day before an NSE holiday (weekday closure) | 118 | 0.089 / 0.048 | 0.525 / 0.539 | 0.752 / 0.725 | 2.05 / 0.39 | -1.28 / 0.35 | does not hold |
| NIFTY on the day after an NSE holiday | 119 | -0.091 / 0.06 | 0.487 / 0.541 | 0.994 / 0.709 | 1.85 / -1.12 | 3.23 / 2.91 | HOLDS (size only) |
| NIFTY gap after an NSE holiday (open vs previous close) | 119 | 0.177 / 0.1 | 0.622 / 0.651 | 0.582 / 0.415 | 2.76 / 0.94 | 3.22 / 2.63 | HOLDS (size only) |
| NIFTY on the first 2 sessions of a month | 190 | 0.161 / 0.038 | 0.589 / 0.533 | 0.866 / 0.712 | 0.91 / 1.32 | 0.64 / 2.3 | does not hold |
| NIFTY in results season (10th of Jan/Apr/Jul/Oct to 15th of the next month) | 788 | 0.047 / 0.053 | 0.523 / 0.549 | 0.683 / 0.756 | -0.84 / -0.13 | -1.13 / -2.08 | does not hold |
| NIFTY budget day +-1 session | 30 | 0.298 / 0.046 | 0.5 / 0.539 | 1.045 / 0.722 | 0.74 / 0.95 | 2.23 / 1.71 | does not hold |
| NIFTY on Monday | 387 | -0.07 / 0.08 | 0.561 / 0.533 | 0.877 / 0.689 | 0.78 / -2.0 | 0.67 / 3.26 | does not hold |
| NIFTY on Tuesday | 390 | 0.164 / 0.022 | 0.546 / 0.536 | 0.672 / 0.74 | -0.9 / 2.44 | -0.73 / -1.55 | does not hold |
| NIFTY on Wednesday | 389 | 0.099 / 0.038 | 0.55 / 0.535 | 0.649 / 0.746 | 0.81 / 1.09 | -2.82 / -2.37 | HOLDS (size only) |
| NIFTY on Thursday | 393 | 0.008 / 0.061 | 0.527 / 0.541 | 0.7 / 0.733 | -0.61 / -0.89 | 0.74 / -0.76 | does not hold |
| NIFTY on Friday | 385 | 0.055 / 0.049 | 0.509 / 0.545 | 0.74 / 0.723 | -0.04 / 0.1 | 1.85 / 0.39 | does not hold |
| AUTO minus NIFTY on the first 2 sessions of a month (auto sales) | 70 | 0.099 / 0.035 | 0.5 / 0.534 | 0.685 / 0.594 | -3.31 / 0.57 | 1.06 / 1.26 | does not hold |
| BANKNIFTY on RBI MPC decision days | 23 | 0.391 / 0.039 | 0.609 / 0.53 | 0.805 / 0.688 | 1.44 / 1.23 | -0.78 / 0.48 | does not hold |

Notes: NIFTY budget day +-1 session: hand list of budget dates · AUTO minus NIFTY on the first 2 sessions of a month (auto sales): Kite AUTO Nov 2021 ->: discovery 2021-2023, unseen 2024-2026 · BANKNIFTY on RBI MPC decision days: 42 MPC days parsed from RBI press-release lists 2020-2026; discovery 2020-2022, unseen 2023-2026

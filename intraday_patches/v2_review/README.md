# v2 review bundles (for the independent panel)

One folder per test run of the GIR v2 engine with the real AI (NSE stock options, CE / PE ideas only - no orders).
Each folder: `calls.jsonl` / `calls.csv` (every call: time, share, side, action, lane, who decided, strike, expiry,
trigger / stop / targets, reason, 30 / 60 min outcome), `ai_log.jsonl` (every AI call: kind, model, tokens, cost,
latency when logged, answer), `test_log.jsonl` + `flags.jsonl` (the test observer's per-decision log and flags),
`scorecard.md` / `.json`, `run_report.txt`. Field notes are in each folder's README.md.

| run | replayed day | triage version |
|---|---|---|
| TEST_ai_full_1116 / _1118 | 16 / 18 Nov 2026 | AI-led triage, first version (too timid) |
| TEST_ai_full2_1116 / _1118 | 16 / 18 Nov 2026 | after fix 2 (money agreeing with price, WATCH re-reads) |

Scrubbed: no keys, tokens, account, position or P&L data, no personal data. Latency is "not logged" in the first two runs.

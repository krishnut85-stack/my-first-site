#!/usr/bin/env python3
"""GIR desk cost calculator (DESK_TEAM.md section 4.8 / 4.9).

Every token size and call count below is a panel ESTIMATE [E]. Replace them with the
real counts from the F29 ai_calls log (median tokens per seat) and re-run:
    python3 intraday_patches/design_v3/desk_cost.py
Prices per million tokens: Opus 5.5 $4 in / $20 out / $0.20 cache read; Sonnet 5.5 $2 / $10 / $0.10;
Haiku 5.5 $0.10 / $0.50 (prompts under 100K; cache read here is a guess [G]).
Cache writes: 5-minute = 1.25x input, 1-hour = 2x input. Opus thinking is billed as output.
Budget day = 15:40 to 15:40 of the next trading session (DESK_TEAM 4.7).
"""
P = {'O': dict(i=4, o=20, cr=.20, w5=5, w1=8),
     'S': dict(i=2, o=10, cr=.10, w5=2.5, w1=4),
     'H': dict(i=.10, o=.50, cr=.01, w5=.125, w1=.20)}


def per_call(m, cached, fresh, out):
    p = P[m]
    return (cached * p['cr'] + fresh * p['i'] + out * p['o']) / 1e6


def run(name, rows, writes, reserve=0.30, cap=5.00):
    print('==', name)
    tot = 0
    by = {'O': 0, 'S': 0, 'H': 0}
    buckets = {}
    for seat, m, n, ca, fr, ou, bucket in rows:
        c = per_call(m, ca, fr, ou)
        t = c * n
        tot += t
        by[m] += t
        buckets[bucket] = buckets.get(bucket, 0) + t
        print(f"  {seat:46s} {m} {n:5d} calls  ${c:.4f}/call  ${t:.2f}")
    w = 0
    for m, tok, ttl, k, bucket in writes:
        x = tok * P[m]['w1' if ttl == '1h' else 'w5'] / 1e6 * k
        w += x
        by[m] += x
        buckets[bucket] = buckets.get(bucket, 0) + x
    tot += w
    print(f"  cache writes ${w:.2f}")
    print('  by model', {k: round(v, 2) for k, v in by.items()})
    print('  by bucket', {k: round(v, 2) for k, v in sorted(buckets.items())})
    print(f"  ESTIMATE ${tot:.2f} + Ask reserve ${reserve:.2f} = ${tot + reserve:.2f}"
          f"  (headroom under ${cap:.2f}: ${cap - tot - reserve:.2f})")
    return tot


# bucket: MEET = protected meetings (19:45 / 07:15 / 09:05 Connections + Devil + head briefs, 15:45 score)
#         LIVE = protected live head + BUY NOW chain (head looks, Devil on candidates, second read)
#         POOL = everything else (readers, seats); this is what the ladder trims first
READERS = [
    ('R1 filings reader ~1,200 items, 8/call',   'H', 150, 8000, 4800, 1600, 'POOL'),
    ('R2 wires / blogs reader ~1,500, 8/call',   'H', 190, 8000, 4800, 1600, 'POOL'),
    ('R3 TV reader 2 ch, 1 call/min',            'H', 510, 8000, 1000, 400, 'POOL'),
    ('R4 policy reader ~300, 8/call',            'H', 40, 8000, 4800, 1600, 'POOL'),
    ('38 trader reads (H part)',                 'H', 10, 8000, 2000, 400, 'POOL'),
]
WORLD_READERS = [
    ('R5 world reader ~800, 8/call',             'H', 100, 8000, 4800, 1600, 'POOL'),
    ('R6 story matcher + second read',           'H', 200, 8000, 1500, 300, 'POOL'),
]
PROTECTED = [
    ('35 CONNECTIONS 19:45 / 07:15 / 09:05',     'O', 3, 30000, 15000, 4000, 'MEET'),
    ('36 DEVIL at the 3 meetings',               'S', 3, 20000, 5000, 700, 'MEET'),
    ('H head briefs 19:45 / 07:15 / 09:08',      'O', 3, 30000, 18000, 4500, 'MEET'),
    ('H head 15:45 scorecard',                   'O', 1, 30000, 12000, 2500, 'MEET'),
    ('H head live looks (cap 8 + 2 trigger)',    'O', 10, 30000, 7000, 2000, 'LIVE'),
    ('36 DEVIL on BUY NOW candidates (<= 4)',    'S', 4, 20000, 4000, 600, 'LIVE'),
    ('15 second read / news confirm wt >= 4',    'S', 15, 20000, 3000, 500, 'LIVE'),
]
MON_SEATS = [
    ('35 Connections Sonnet re-check on shock',  'S', 2, 20000, 6000, 900, 'POOL'),
    ('Global macro + FLOWS + EM (one call)',     'S', 5, 20000, 4500, 800, 'POOL'),
    ('Sector seats x3 (19:45, 07:15 + events)',  'S', 12, 20000, 4500, 700, 'POOL'),
    ('39 risk notes (when holding)',             'S', 6, 20000, 3000, 400, 'POOL'),
    ('36 DEVIL 22:45 / 15:45 if a theme moved',  'S', 2, 20000, 5000, 700, 'POOL'),
]
W1_SEATS = [   # benches share one call each (a bench call writes one card per seat)
    ('35 Connections Sonnet re-check on shock',  'S', 2, 20000, 6000, 900, 'POOL'),
    ('World bench 1-5 (19:45, 22:45*, 07:15 + shocks)', 'S', 5, 20000, 9000, 1800, 'POOL'),
    ('Commodities 6-7 (one call, meetings)',     'S', 2, 20000, 5000, 900, 'POOL'),
    ('Money 9-10 (17:30-21:00 once, 07:15)',     'S', 3, 20000, 6000, 900, 'POOL'),
    ('Policy 11-13 (each weight >= 3 item)',     'S', 5, 20000, 4000, 700, 'POOL'),
    ('Company 16-17 (results / deals, events)',  'S', 6, 20000, 4000, 700, 'POOL'),
    ('Sector bench, 9 seats in 3 calls x 2 meetings', 'S', 6, 20000, 8000, 1800, 'POOL'),
    ('Sector seat on events (R49 / F27)',        'S', 6, 20000, 4500, 700, 'POOL'),
    ('31 derivatives (hourly in session + 1)',   'S', 7, 20000, 5000, 800, 'POOL'),
    ('37 history (on demand)',                   'S', 2, 20000, 4000, 600, 'POOL'),
    ('39 risk notes (when holding)',             'S', 6, 20000, 3000, 400, 'POOL'),
    ('36 DEVIL 22:45 / 15:45 if a theme moved',  'S', 2, 20000, 5000, 700, 'POOL'),
]
WRITES = [('O', 30000, '1h', 1, 'MEET'), ('O', 30000, '5m', 1, 'LIVE'),
          ('S', 20000, '1h', 2, 'POOL'), ('H', 8000, '1h', 2, 'POOL')]

if __name__ == '__main__':
    run('LEAN-MON (Monday 23 Nov subset)', READERS + PROTECTED + MON_SEATS, WRITES)
    run('LEAN-W1 (full week-1 roster, speak on change)',
        READERS + WORLD_READERS + PROTECTED + W1_SEATS, WRITES)

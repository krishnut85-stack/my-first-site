# R51 table: every control row (name, page, viewport, inside / outside, PASS / FAIL / NOT RUN, evidence) -> md + json
import json, sys, os, datetime, subprocess
out_dir = '/home/globalbot/girdata/review/drilldown'
os.makedirs(out_dir, exist_ok=True)
rows = []
for f in sys.argv[1:]:
    if os.path.exists(f):
        rows += json.load(open(f))
now = subprocess.run(['date', '+%d %b %Y %H:%M IST'], capture_output=True, text=True, env={'TZ': 'Asia/Kolkata'}).stdout.strip()
cnt = {}
for r in rows:
    k = (r.get('where', ''), r['result']); cnt[k] = cnt.get(k, 0) + 1
tot = {}
for r in rows: tot[r['result']] = tot.get(r['result'], 0) + 1
md = ['# R51 controls test - SECTOR DRILL-DOWN (R50) on the real /preview pages', '',
      'Run %s. Real input only: mouse clicks, drags of scrollbar thumbs and wheel, keyboard on the desk (1366x768 and 1600x900, deviceScaleFactor 1);' % now,
      'finger touches on the phone (390x844, hasTouch + isMobile, CDP touchStart / touchMove / touchEnd). No forced states: the page state is only read to check what the input did.',
      'Inside = http://127.0.0.1:8100/preview/... ; outside = https://girtrader.com/preview/... through the login (cookie made by sitelogin, never printed).',
      'Data = the live store with the close of the day of the run (market closed). NOT RUN = the control needs a live market state that does not exist tonight (named in the row).', '',
      '**Totals:** ' + ' · '.join('%s %s' % (v, k) for k, v in sorted(tot.items())), '',
      '| where | result | n |', '|---|---|---|'] + ['| %s | %s | %s |' % (k[0], k[1], v) for k, v in sorted(cnt.items())] + ['']
fails = [r for r in rows if r['result'] == 'FAIL']
md += ['## FAIL rows (%d)' % len(fails), ''] + (['| control | page | viewport | where | evidence |', '|---|---|---|---|---|'] + ['| %s | %s | %s | %s | %s |' % (r['control'], r['page'], r['viewport'], r.get('where', ''), r['evidence'].replace('|', '/')) for r in fails] if fails else ['none']) + ['']
md += ['## Every row', '', '| # | control | page | viewport | where | result | evidence |', '|---|---|---|---|---|---|---|']
for i, r in enumerate(rows, 1):
    md.append('| %d | %s | %s | %s | %s | %s | %s |' % (i, r['control'].replace('|', '/'), r['page'], r['viewport'], r.get('where', ''), r['result'], r['evidence'].replace('|', '/').replace('\n', ' ')))
open(os.path.join(out_dir, 'R51_controls.md'), 'w').write('\n'.join(md) + '\n')
json.dump({'run': now, 'totals': tot, 'rows': rows}, open(os.path.join(out_dir, 'R51_controls.json'), 'w'), indent=1, ensure_ascii=False)
print(tot, len(rows))

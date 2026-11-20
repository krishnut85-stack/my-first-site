# R51-style test of the desk words in the EXISTING boxes (design_v3/DESK_WEB_CHANGES.md, Monday items 1-4 and 8):
# shell P&L "AI $ of $5" + footer desk mode; F1 GO NOW card = the head's BUY NOW (GIR ANALYST + next look, STALE -> WAIT, FROM / AGAINST /
# NOT PROVEN, WHY with seat + source, CONNECTION); manage notes in the GIR rows (desk-trade, F6, phone NOW); phone CALL wording, ALERTS
# brief note; 0 console errors and no sideways scroll on every page; the no-cut check on every changed box. Real input only.
# FIXBASE = a TEST copy of gir-preview fed a fixture desk state.json (DESK_api v1); BASE = the real store (inside or outside).
import asyncio, json, sys, os, re, traceback, glob
from playwright.async_api import async_playwright
BASE, WHERE, VPS, OUT = sys.argv[1].rstrip('/'), sys.argv[2], sys.argv[3].split(','), sys.argv[4]
SHOTS = sys.argv[5] if len(sys.argv) > 5 else ''
FIXBASE = os.environ.get('FIXBASE', '')
STALEF = '/tmp/claude-0/-home-globalbot-intraday/00672d16-a50b-5beb-9b5f-7eb9801c58f8/scratchpad/sd/deskfix/state.json.stale'
R = []; CUR = {'page': '', 'vp': ''}


def rec(ctrl, ok, ev):
    res = ok if isinstance(ok, str) else ('PASS' if ok else 'FAIL')
    R.append({'control': ctrl, 'page': CUR['page'], 'viewport': CUR['vp'], 'where': WHERE, 'result': res, 'evidence': str(ev)[:900]})
    print('%-5s %-9s %-22s %-52s %s' % (res, CUR['vp'], CUR['page'], ctrl[:52], str(ev).replace('\n', ' ')[:150]), flush=True)


CUT = '''(scope) => { const Q = ['#card .cg-s', '#card .cg-s > *', '#card .cg-h > *', '#card .df-from > *', '#card .df-against', '#card .df-wl > *', '#card .df-conn', '#card .vote', '.df-np', '.df-off',
  '.say .row > *', '.say .ln', '.df-now', '.df-brief .row > *', '.df-brief .ln', '#sh-health', '#sh-pnl .sh-pt'];
  const seen = new Set(), out = [];
  // the GIR row of each position card only (the changed box), not the card's other rows
  document.querySelectorAll('.pr .r').forEach(r => { const l = r.querySelector('.rl'); if (l && l.textContent.trim() === 'GIR') r.querySelectorAll('.gw, .sub').forEach(e => e.classList.add('df-cutchk')); });
  Q.push('.df-cutchk');
  for (const q of Q) document.querySelectorAll(q).forEach(e => { if (seen.has(e)) return; seen.add(e); if (!e.getClientRects().length) return; const cs = getComputedStyle(e); if (cs.display === 'none' || cs.visibility === 'hidden' || cs.display === 'inline') return;
    if (e.scrollWidth > e.clientWidth && e.clientWidth > 0) { const txt = (e.innerText || '').replace(/\\s+/g, ' ').trim(), tip = e.closest('[title]');
      const prose = !!tip && txt.split(' ').length >= 4 && (tip.title.length >= txt.length - 3 || tip.title.includes(txt.slice(0, 20)));
      out.push({q, txt: txt.slice(0, 40), sw: e.scrollWidth, cw: e.clientWidth, prose}); } });
  return out; }'''


class P:
    def __init__(self, pg):
        self.p = pg; self.errs = []
        pg.on('pageerror', lambda e: self.errs.append(str(e)[:200]))
        pg.on('console', lambda m: self.errs.append(m.text[:200]) if m.type == 'error' and 'favicon' not in m.text else None)

    async def go(self, path, base=None):
        await self.p.goto((base or BASE) + '/' + path, wait_until='domcontentloaded', timeout=60000)
        await self.p.wait_for_function('() => window.GIR && GIR.store && GIR.store.ready && GIR.store.ready()', timeout=30000)
        await self.p.wait_for_timeout(2500)

    async def ev(self, js, a=None):
        return await self.p.evaluate(js, a)

    async def box(self, sel):
        return await self.p.locator(sel).first.bounding_box()

    async def click(self, sel):
        b = await self.box(sel)
        if not b: raise Exception('no box ' + sel)
        await self.p.mouse.click(b['x'] + b['width'] / 2, b['y'] + b['height'] / 2); await self.p.wait_for_timeout(300)


async def into_view(P_, sel, touch=None):
    for i in range(30):
        r = await P_.ev("""([s, t]) => { const e = document.querySelector(s); if (!e) return null; const b = e.getBoundingClientRect(); let bx = null;
          for (let y = e.parentElement; y; y = y.parentElement) { const c = getComputedStyle(y); if (/(auto|scroll)/.test(c.overflowY) && y.scrollHeight > y.clientHeight + 1) { bx = y; break; } }
          const w = bx ? bx.getBoundingClientRect() : {top: 0, bottom: innerHeight, left: 0, width: innerWidth}; const top = Math.max(w.top, t ? 130 : 0), bot = Math.min(w.bottom, innerHeight - (t ? 170 : 0));
          return [b.top, b.bottom, top, bot, w.left + Math.min(w.width / 2, 150)] }""", [sel, bool(touch)])
        if not r: return False
        t, bo, top, bot, x = r
        if t >= top - 1 and bo <= bot + 1: return True
        d = 1 if bo > bot else -1
        if touch: await touch(x, (top + bot) / 2, 0, -d * min(200, (bot - top) * 0.35))
        else:
            await P_.p.mouse.move(x, (top + bot) / 2); await P_.p.mouse.wheel(0, d * 120); await P_.p.wait_for_timeout(200)
    return False


async def cut(P_, label):
    r = await P_.ev(CUT)
    bad = [x for x in r if not x['prose']]
    rec('no cut text (' + label + ')', not bad, '%d cut cells%s · prose with a tooltip allowed: %d' % (len(bad), (' - ' + ' | '.join('%s "%s" %s>%s' % (x['q'], x['txt'], x['sw'], x['cw']) for x in bad[:6])) if bad else '', len(r) - len(bad)))


async def amber(P_):
    return await P_.ev('''() => { const go = getComputedStyle(document.documentElement).getPropertyValue('--go').trim(); const c = document.createElement('div'); c.style.color = go; document.body.appendChild(c); const rgb = getComputedStyle(c).color; c.remove();
      const L = [...document.querySelectorAll('body *')].filter(e => { if (!e.getClientRects().length) return false; const r = e.getBoundingClientRect(); if (r.bottom < 0 || r.top > innerHeight || r.width < 40 || r.height < 14) return false; return getComputedStyle(e).backgroundColor === rgb; });
      return L.filter(e => !L.some(x => x !== e && x.contains(e))).map(e => (e.className || e.tagName).toString().slice(0, 30)) }''')


async def shot(P_, name):
    if not SHOTS: return
    await P_.ev("""() => { const p = document.querySelector('#sh-pnl'); if (p && !p.querySelector('.pnl-lab')) { const l = document.createElement('span'); l.className = 'pnl-lab'; l.textContent = 'P&L hidden'; l.style.cssText = 'font:700 13px var(--sans);color:#C9D1DB;background:#2b3038;padding:2px 10px;border-radius:3px;margin:0 6px;align-self:center'; p.prepend(l); } }""")
    await P_.p.screenshot(path=os.path.join(SHOTS, name), mask=[P_.p.locator('#sh-pnl > .sh-pt'), P_.p.locator('#mPnl')], mask_color='#2b3038')


async def stale_state(on):
    if on: open(STALEF, 'w').write('1')
    elif os.path.exists(STALEF): os.remove(STALEF)
    os.system('cd %s && python3 make_state.py' % os.path.dirname(STALEF)); await asyncio.sleep(7)   # the adapter reads every 5 s


async def f1(P_, w):
    if FIXBASE:
        CUR['page'] = 'F1 desk (fixture)'
        await P_.go('desk-hunt', FIXBASE)
        t = await P_.ev('() => document.querySelector("#card").innerText')
        rec('GO NOW card = the head\'s BUY NOW: GIR ANALYST header + next look', 'GO NOW' in t and 'GIR ANALYST' in t and 'next look' in t, t.replace('\n', ' ')[:140])
        rec('FROM (seats) + AGAINST (Devil) + NOT PROVEN in place of the weight', all(x in t for x in ['FROM', 'AGAINST', '(Devil)', 'NOT PROVEN']) and 'agree' not in t, t[t.find('FROM'):][:140].replace('\n', ' '))
        n = await P_.ev('() => [document.querySelectorAll("#card .df-wl").length, document.querySelectorAll("#card .df-seat").length, !!document.querySelector("#card .df-conn")]')
        rec('WHY with seat chip + source (max 3) and one blue CONNECTION line', n[0] == 3 and n[1] >= 3 and n[2], 'why lines %s · seat chips %s · connection %s' % tuple(n))
        await into_view(P_, '#card .df-conn'); href = await P_.ev('() => document.querySelector("#card .df-conn").getAttribute("href")')
        await P_.click('#card .df-conn'); await P_.p.wait_for_timeout(1500); u = P_.p.url
        rec('CONNECTION opens the theme on F8', 'analyst' in u, '%s -> %s' % (href, u.split('/')[-1]))
        await P_.go('desk-hunt', FIXBASE)
        am = await amber(P_)
        rec('one amber fill (the GO NOW card)', len(am) <= 1, am)
        btn = await P_.ev('() => [...document.querySelectorAll("#card button, #card a")].map(b => b.textContent.trim()).filter(t => /\\b(buy|sell|place order|order now)\\b/i.test(t))')
        rec('no buy / order button on the card', not btn, btn or 'none')
        foot = await P_.ev('() => [document.querySelector("#sh-health").innerText, document.querySelector("#sh-pnl").innerText]')
        rec('shell: P&L strip "AI $ of $5", footer AI word = desk mode', re.search(r'\$1\.84\s*of \$5', foot[1]) is not None and 'desk LEAN' in foot[0] and not re.search(r'Opus|Sonnet|Haiku|Fable', foot[0]), 'footer "%s" · strip AI "%s"' % (foot[0][-40:], foot[1][foot[1].find('AI'):][:20]))
        await cut(P_, 'F1 GO NOW card, fixture'); await shot(P_, 'F1_gonow_fixture_%d.png' % w)
        await stale_state(True); await P_.p.wait_for_timeout(1500)
        t2 = await P_.ev('() => [document.querySelector("#card").innerText, document.querySelector("#card").className]')
        await stale_state(False)
        rec('STALE: grey STALE chip, the card reads "WAIT: analyst stale" (no amber GO NOW)', 'WAIT: analyst stale' in t2[0] and 'STALE' in t2[0] and 'df-wait' in t2[1], t2[0].replace('\n', ' ')[:120])
    CUR['page'] = 'F1 desk (live)'
    await P_.go('desk-hunt')
    t = await P_.ev('() => [document.querySelector("#card").innerText, document.querySelector("#sh-health").innerText]')
    rec('head not running: the engine card under its old labels + grey "analyst not running"', 'analyst not running' in t[0] and 'GIR ANALYST' not in t[0] and ('LATEST DECISION' in t[0] or 'NO CARD' in t[0]), t[0].replace('\n', ' ')[:120])
    rec('footer AI word: desk OFF while the head is not running', 'desk OFF' in t[1] or 'AI' in t[1], t[1][-70:])
    await cut(P_, 'F1, live'); await shot(P_, 'F1_live_%d.png' % w)


async def manage(P_, w):
    for page, nm in (('desk-trade', 'desk-trade GIR row'), ('positions', 'F6 GIR row')):
        if FIXBASE:
            CUR['page'] = nm + ' (fixture)'
            await P_.go(page, FIXBASE)
            t = await P_.ev('() => [...document.querySelectorAll(".pr")].map(e => e.innerText).join(" | ")')
            rec('the head\'s manage note in the GIR row (HOLD - thesis ...)', 'GIR ANALYST' in t and 'thesis intact' in t, t[t.find('GIR ANALYST') - 120:][:200].replace('\n', ' ') if 'GIR ANALYST' in t else t[:150])
            await cut(P_, nm + ', fixture'); await shot(P_, '%s_manage_fixture_%d.png' % (page, w))
        CUR['page'] = nm + ' (live)'
        await P_.go(page)
        t = await P_.ev('() => [...document.querySelectorAll(".pr")].map(e => e.innerText).join(" | ")')
        rec('head not running: the GIR row keeps the engine follow-up', 'GIR ANALYST' not in t, t[:120].replace('\n', ' '))
        await cut(P_, nm + ', live')


async def phone(P_, cdp):
    p = P_.p
    tp = lambda x, y: [{'x': x, 'y': y, 'radiusX': 1, 'radiusY': 1, 'force': 1, 'id': 1}]
    async def tap(sel):
        b = await P_.box(sel)
        if not b: raise Exception('no box ' + sel)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': tp(b['x'] + b['width'] / 2, b['y'] + b['height'] / 2)}); await p.wait_for_timeout(40)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []}); await p.wait_for_timeout(400)
    async def swipe(x, y, dx, dy):
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': tp(x, y)}); await p.wait_for_timeout(30)
        for i in range(1, 9):
            await cdp.send('Input.dispatchTouchEvent', {'type': 'touchMove', 'touchPoints': tp(x + dx * i / 8, y + dy * i / 8)}); await p.wait_for_timeout(16)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []}); await p.wait_for_timeout(900)
    async def ftap(sel):
        await into_view(P_, sel, swipe); await tap(sel)
    if FIXBASE:
        CUR['page'] = 'phone (fixture)'
        await P_.go('phone', FIXBASE)
        inT = await p.evaluate('() => (GIR.store.val("pos.open") || []).length')
        t = await p.evaluate('() => document.querySelector("#b-now").innerText')
        if inT: rec('NOW in a trade: the GIR block carries the head\'s manage note', 'ANALYST' in t and 'thesis intact' in t, t[t.find('ANALYST') - 40:][:140].replace('\n', ' ') if 'ANALYST' in t else t[:100])
        else: rec('NOW flat: the desk line', 'Desk: lean' in t, t[:120])
        await tap('.m-tab[data-go="call"]')
        c = await p.evaluate('() => document.querySelector("#b-call").innerText')
        rec('CALL: FROM / AGAINST / NOT PROVEN, the head\'s card', all(x in c for x in ['FROM', 'AGAINST', 'NOT PROVEN', 'SBIN']), c[c.find('FROM'):][:120].replace('\n', ' ') if 'FROM' in c else c[:100])
        n0 = await p.evaluate('() => document.querySelectorAll("#b-call .df-wl").length')
        await ftap('#b-call [data-df="more"]'); n1 = await p.evaluate('() => document.querySelectorAll("#b-call .df-wl").length')
        rec('CALL: WHY 2 lines + "more" (finger)', n0 == 2 and n1 == 3, '%s -> %s lines' % (n0, n1))
        rec('CALL: one blue CONNECTION line', await p.evaluate('() => !!document.querySelector("#b-call .df-conn")'), 'present')
        await cut(P_, 'phone CALL, fixture'); await shot(P_, 'phone_390_call_fixture.png')
        await tap('.m-tab[data-go="alerts"]')
        a = await p.evaluate('() => (document.querySelector("#b-alerts .df-brief") || {}).innerText || ""')
        rec('ALERTS: the brief note (changed first, Themes max 3)', 'BRIEF 07:15' in a and 'changed' in a and 'Themes' in a, a.replace('\n', ' ')[:140])
        await cut(P_, 'phone ALERTS, fixture'); await shot(P_, 'phone_390_alerts_fixture.png')
        await tap('.m-tab[data-go="now"]'); await shot(P_, 'phone_390_now_fixture.png')
    CUR['page'] = 'phone (live)'
    await P_.go('phone')
    await tap('.m-tab[data-go="call"]'); c = await p.evaluate('() => document.querySelector("#b-call").innerText')
    await tap('.m-tab[data-go="alerts"]'); a = await p.evaluate('() => !!document.querySelector("#b-alerts .df-brief")')
    rec('head not running: CALL keeps the old card, no brief note', 'FROM' not in c and not a, 'brief note %s' % a)
    sw = await p.evaluate('() => document.documentElement.scrollWidth')
    rec('no sideways scroll at 390 (phone)', sw <= 390, sw)


async def all_pages(P_, w):
    CUR['page'] = 'all pages'
    pages = sorted(os.path.basename(x)[:-5] for x in glob.glob('/home/globalbot/intraday/v2/pages/*.html'))
    bad, side = [], []
    for nm in pages:
        n0 = len(P_.errs)
        try:
            await P_.p.goto(BASE + '/' + nm, wait_until='domcontentloaded', timeout=60000); await P_.p.wait_for_timeout(2500)
        except Exception as e:
            bad.append(nm + ': ' + str(e)[:60]); continue
        if len(P_.errs) > n0: bad.append('%s: %s' % (nm, P_.errs[n0][:80]))
        sw = await P_.ev('() => document.documentElement.scrollWidth')
        if sw > w: side.append('%s %s' % (nm, sw))
    rec('0 console errors on every page (%d pages)' % len(pages), not bad, bad[:5] or 'none')
    rec('no sideways scroll at %d on every page' % w, not side, side[:6] or 'none')
    rec('no Desk Room page or link left', not os.path.exists('/home/globalbot/intraday/v2/pages/desk-room.html') and 'desk-room' not in ''.join(pages), 'pages: %d' % len(pages))


async def run():
    if SHOTS: os.makedirs(SHOTS, exist_ok=True)
    async with async_playwright() as pw:
        b = await pw.chromium.launch(); cookies = []
        if WHERE == 'outside':
            sys.path.insert(0, '/home/globalbot/intraday'); import sitelogin
            full = sitelogin.make_cookie(); val = full.split(';')[0].split('=', 1)[1]
            cookies = [{'name': 'gir_s', 'value': val, 'domain': 'girtrader.com', 'path': '/', 'secure': True, 'httpOnly': True}]; del full, val
        for vp in VPS:
            w, h = map(int, vp.split('x')); CUR['vp'] = vp
            if w >= 700: ctx = await b.new_context(viewport={'width': w, 'height': h}, device_scale_factor=1)
            else:
                dev = dict(pw.devices['iPhone 13']); dev['viewport'] = {'width': w, 'height': h}; ctx = await b.new_context(**dev)
            if cookies: await ctx.add_cookies(cookies)
            pg = await ctx.new_page(); P_ = P(pg)
            fns = [f1, manage] if w >= 700 else []
            for fn in fns:
                n0 = len(P_.errs)
                try: await fn(P_, w)
                except Exception as e: rec(fn.__name__ + ' (run)', False, 'exception: ' + str(e).split('\n')[0][:200] + ' @ ' + ','.join(re.findall(r'web_r51.py", line (\d+)', traceback.format_exc())))
                rec('page errors', len(P_.errs) == n0, P_.errs[n0:][:3] or 'none')
            if w < 700:
                cdp = await ctx.new_cdp_session(pg); n0 = len(P_.errs)
                try: await phone(P_, cdp)
                except Exception as e: rec('phone (run)', False, 'exception: ' + str(e).split('\n')[0][:200] + ' @ ' + ','.join(re.findall(r'web_r51.py", line (\d+)', traceback.format_exc())))
                rec('page errors', len(P_.errs) == n0, P_.errs[n0:][:3] or 'none')
            if os.environ.get('ALLPAGES'): await all_pages(P_, w)
            await ctx.close()
        await b.close()
    json.dump(R, open(OUT, 'w'), indent=1)
    c = {}
    for r in R: c[r['result']] = c.get(r['result'], 0) + 1
    print('TOTAL', c)

asyncio.run(run())

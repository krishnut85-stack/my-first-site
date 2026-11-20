# R51-style controls test of the NEW desk screens (DESK_TEAM 6.5 items 1-5): Desk F1, Morning brief, Desk Room F8, phone /m, footer.
# Real input only (mouse / keyboard / wheel / native scrollbar drag on the desk; CDP finger touches on the phone). Two data states:
# FIXTURE (?fixture=desk, the test data under its red banner - exercises every component) and LIVE (the real store: today the desk
# publishes nothing, so every place must say "head analyst not running" and keep the engine's own view). Plus the no-cut check.
# usage: python desk_r51.py <base> <inside|outside> <viewports> <out.json> [shots_dir]
import asyncio, json, sys, os, re, traceback
from playwright.async_api import async_playwright
BASE, WHERE, VPS, OUT = sys.argv[1].rstrip('/'), sys.argv[2], sys.argv[3].split(','), sys.argv[4]
FIXBASE = os.environ.get('FIXBASE', '')   # a TEST copy of gir-preview fed a fixture v2/data/desk/state.json (DESK_api v1 shape); inside only
SHOTS = sys.argv[5] if len(sys.argv) > 5 else ''
R = []; CUR = {'page': '', 'vp': ''}


def rec(ctrl, ok, ev):
    res = ok if isinstance(ok, str) else ('PASS' if ok else 'FAIL')
    R.append({'control': ctrl, 'page': CUR['page'], 'viewport': CUR['vp'], 'where': WHERE, 'result': res, 'evidence': str(ev)[:900]})
    print('%-5s %-9s %-16s %-52s %s' % (res, CUR['vp'], CUR['page'], ctrl[:52], str(ev)[:150]), flush=True)


CUT = '''() => { const Q = ['.dh-strip .dh-l1 > *', '.dh-strip .dh-l2', '.dh-mrow > *', '.dh-bh > *', '.dh-kv > *', '.dh-wl > *', '.dh-line > *', '.dh-foot > *', '.dh-ir .dh-i1 > *', '.dh-i2',
  '.dh-hh', '.dh-wn > *', '.dh-th1 > *', '.dh-nm', '.dh-bi .dh-i1 > *', '.dh-head', '.dh-chg > *', '.dh-ver', '.dh-sr1 > *', '.dh-sr2 > *', '.dh-c1 > *', '.dh-c2', '.dh-c3 > *', '.dh-c4', '.dh-obj > *',
  '.dh-cv > *', '.dh-pir > *', '.dh-tchip', '.dh-pbtn .btn', 'body.page-desk-room #purp > *', '#cols .ph > *', '.dr-filt > *', '#sh-health'];
  const seen = new Set(), out = [];
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
        await self.p.wait_for_timeout(2200)

    async def ev(self, js, a=None):
        return await self.p.evaluate(js, a)

    async def box(self, sel, nth=0):
        return await self.p.locator(sel).nth(nth).bounding_box()

    async def click(self, sel, nth=0, dx=0.5):
        b = await self.box(sel, nth)
        if not b: raise Exception('no box ' + sel)
        await self.p.mouse.click(b['x'] + b['width'] * dx, b['y'] + b['height'] / 2); await self.p.wait_for_timeout(300); return b


async def into_view(P_, sel, touch=None):
    for i in range(30):
        r = await P_.ev("""([s, touch]) => { const e = document.querySelector(s); if (!e) return null; const b = e.getBoundingClientRect(); let bx = null;
          for (let y = e.parentElement; y; y = y.parentElement) { const c = getComputedStyle(y); if (/(auto|scroll)/.test(c.overflowY) && y.scrollHeight > y.clientHeight + 1) { bx = y; break; } }
          const w = bx ? bx.getBoundingClientRect() : {top: 0, bottom: innerHeight, left: 0, width: innerWidth}; const top = Math.max(w.top, touch ? 130 : 0), bot = Math.min(w.bottom, innerHeight - (touch ? 170 : 0));
          return [b.top, b.bottom, top, bot, w.left + Math.min(w.width / 2, 150)] }""", [sel, bool(touch)])
        if not r: return False
        t, bo, top, bot, x = r
        if t >= top - 1 and bo <= bot + 1: return True
        d = 1 if bo > bot else -1
        if touch:
            y0 = (top + bot) / 2; await touch(x, y0, 0, -d * min(200, (bot - top) * 0.35))
        else:
            await P_.p.mouse.move(x, (top + bot) / 2); await P_.p.mouse.wheel(0, d * 120); await P_.p.wait_for_timeout(200)
    return False


async def cut(P_, label):
    r = await P_.ev(CUT)
    bad = [x for x in r if not x['prose']]
    rec('no cut text (' + label + ')', not bad, '%d cut cells%s · prose with a tooltip allowed: %d' % (len(bad), (' - ' + ' | '.join('%s "%s" %s>%s' % (x['q'], x['txt'], x['sw'], x['cw']) for x in bad[:6])) if bad else '', len(r) - len(bad)))


async def amber(P_):
    n = await P_.ev('''() => { const go = getComputedStyle(document.documentElement).getPropertyValue('--go').trim(); const c = document.createElement('div'); c.style.color = go; document.body.appendChild(c); const rgb = getComputedStyle(c).color; c.remove();
      return [...document.querySelectorAll('body *')].filter(e => { if (!e.getClientRects().length) return false; const r = e.getBoundingClientRect(); if (r.bottom < 0 || r.top > innerHeight || r.width < 8) return false; return getComputedStyle(e).backgroundColor === rgb; }).map(e => e.className || e.tagName).slice(0, 6) }''')
    return n


async def scrollbar(P_, sel, label):
    m = await P_.ev('s => { const e = document.querySelector(s); return e ? e.scrollHeight - e.clientHeight : -1 }', sel)
    if m <= 0:
        rec(label + ' - scroll', 'PASS', 'everything fits (nothing to scroll)'); return
    b = await P_.box(sel)
    await P_.p.mouse.move(b['x'] + b['width'] / 2, b['y'] + b['height'] / 2); await P_.p.mouse.wheel(0, 150); await P_.p.wait_for_timeout(300)
    a = await P_.ev('s => document.querySelector(s).scrollTop', sel)
    await P_.p.mouse.wheel(0, -3000); await P_.p.wait_for_timeout(300); z = await P_.ev('s => document.querySelector(s).scrollTop', sel)
    # the native scrollbar thumb (visible, 12 px): mouse down on it near the top of the bar, drag down
    await P_.p.mouse.move(b['x'] + b['width'] - 6, b['y'] + 10); await P_.p.mouse.down(); await P_.p.mouse.move(b['x'] + b['width'] - 6, b['y'] + b['height'] - 10, steps=10); await P_.p.mouse.up(); await P_.p.wait_for_timeout(300)
    c = await P_.ev('s => document.querySelector(s).scrollTop', sel)
    rec(label + ' - wheel and scrollbar drag', a > 0 and z == 0 and c > 0, 'wheel down -> %s, up -> %s · thumb drag -> %s (max %s)' % (a, z, c, m))


async def desk_f1(P_, w):
    CUR['page'] = 'F1 desk (fixture state)'
    if not FIXBASE: return await desk_f1_live(P_, w)
    await P_.go('desk-hunt', FIXBASE)
    st = await P_.ev('() => [document.querySelector("#dhStrip") && document.querySelector("#dhStrip").innerText, !!document.querySelector("#dhBuy .dh-buy"), getComputedStyle(document.querySelector("#card")).display, document.querySelectorAll("#dhIdeas .dh-ir").length]')
    rec('DESK VIEW strip (lean, theme, looked / next)', st[0] and 'DESK VIEW' in st[0] and 'looked' in st[0] and 'next' in st[0], (st[0] or '').replace('\n', ' ')[:140])
    rec('BUY NOW card (hero) replaces the engine card while the head is live', st[1] and st[2] == 'none', 'BUY NOW tag %s · engine card display %s' % (st[1], st[2]))
    rec("TODAY'S IDEAS: CE and PE halves", st[3] == 4 and await P_.ev('() => document.querySelectorAll("#dhIdeas .dh-hh").length') == 2, '%s idea rows' % st[3])
    fields = await P_.ev('() => document.querySelector("#dhBuy").innerText')
    need = ['ENTER', 'STOP', 'TARGET', 'R:R', 'LOTS', 'WHY', 'FROM', 'AGAINST', 'CANCEL IF', 'NOT PROVEN', 'APPROVED', 'GIR never places orders']
    rec('BUY NOW fields (enter, stop, target, R:R, lots, why, from, against, cancel, connection, NOT PROVEN, risk stamp)', all(n in fields for n in need) and await P_.ev('() => !!document.querySelector("#dhBuy .dh-conn")'), 'missing: %s' % [n for n in need if n not in fields])
    am = await amber(P_)
    rec('one amber fill on the screen (BUY NOW only)', len(am) <= 1, am)
    m = await P_.ev('() => (document.querySelector(".dh-man") || {}).innerText || ""')
    rec('MANAGE line under the position', 'HOLD' in m, m.replace('\n', ' ')[:120])
    await P_.ev('() => navigator.clipboard.writeText("-")'); await into_view(P_, '#dhBuy .dh-copy'); await P_.click('#dhBuy .dh-copy'); await P_.p.wait_for_timeout(300); clip = await P_.ev('() => navigator.clipboard.readText()')
    rec('Copy contract (clipboard only, plan.contract)', clip == 'SBIN Dec 1000 CE (ATM, exp 2026-12-29)', 'clipboard "%s"' % clip)
    await into_view(P_, '#dhBuy .dh-conn'); await P_.click('#dhBuy .dh-conn'); a = await P_.ev('() => !!document.querySelector("#dhTheme.on")')
    await P_.click('#dhTheme [data-dh="x"]'); b = await P_.ev('() => !!document.querySelector("#dhTheme.on")')
    rec('CONNECTION line opens the chain (read only), ✕ closes', a and not b, 'open %s · closed %s' % (a, not b))
    await P_.click('#dhBuy .dh-conn'); await P_.p.mouse.click(8, 400); await P_.p.wait_for_timeout(300); c = await P_.ev('() => !!document.querySelector("#dhTheme.on")')
    rec('chain sheet closes on a click outside', not c, 'open after outside click: %s' % c)
    await into_view(P_, '#dhIdeas [data-dh="whynot"]'); await P_.click('#dhIdeas [data-dh="whynot"]'); a = await P_.ev('() => document.querySelectorAll("#dhIdeas .dh-wn").length'); await P_.click('#dhIdeas [data-dh="whynot"]'); b = await P_.ev('() => document.querySelectorAll("#dhIdeas .dh-wn").length')
    rec('WHY NOT fold (open, close)', a == 2 and b == 0, '%s rows open, %s after close' % (a, b))
    await scrollbar(P_, '#dhBuy', 'BUY NOW card')
    await scrollbar(P_, '#dhIdeas', "TODAY'S IDEAS")
    btn = await P_.ev('() => [...document.querySelectorAll("#dhStrip button, #dhBuy button, #dhIdeas button, #dhBuy a")].map(b => b.textContent).filter(t => /\\b(buy|sell|place order|order now)\\b/i.test(t) && !/BUY NOW/.test(t))')
    rec('signal only: no buy / order button', not btn, btn or 'none')
    foot = await P_.ev('() => document.querySelector("#sh-health").innerText')
    rec('footer: AI $ of $5 · ladder step · desk · head looked (no model names)', re.search(r'AI \$1\.84 of \$5(\.0)? · NORMAL · desk live · head looked \d\d:\d\d', foot) is not None and not re.search(r'Opus|Sonnet|Haiku|Fable', foot), foot[-120:])
    await cut(P_, 'F1 desk components, fixture')
    if SHOTS: await shot(P_, 'F1_desk_fixture_%d.png' % w)
    await desk_f1_live(P_, w)


async def desk_f1_live(P_, w):
    CUR['page'] = 'F1 desk (live)'
    await P_.go('desk-hunt')
    st = await P_.ev('() => [document.querySelector("#dhStrip").innerText, !!document.querySelector("#dhBuy"), getComputedStyle(document.querySelector("#card")).display]')
    rec('no desk facts: "head analyst not running", engine card kept under its old labels', 'head analyst not running' in st[0] and not st[1] and st[2] != 'none', st[0].replace('\n', ' ')[:140])
    await cut(P_, 'F1 desk, live (not running)')
    if SHOTS: await shot(P_, 'F1_desk_live_%d.png' % w)


async def morning(P_, w):
    CUR['page'] = 'Morning (fixture state)'
    if not FIXBASE: return await morning_live(P_, w)
    await P_.go('morning', FIXBASE)
    t = await P_.ev('() => document.querySelector("#dhBrief").innerText')
    rec('brief board: headline, what changed, CE / PE columns', all(x in t for x in ['MORNING BRIEF 07:15', 'CHANGED', 'CE · calls', 'PE · puts', 'NOT PROVEN', 'TCS PE CANCELLED']), t.replace('\n', ' ')[:140])
    l = await P_.ev('() => (document.querySelector("#dhLanes") || {}).innerText || ""')
    rec('themes lane (winners and losers), what would change the view, flows, coverage', all(x in l for x in ['THEMES', 'WINNERS', 'LOSERS', 'WHAT WOULD CHANGE', 'FLOWS', 'coverage counts']), l.replace('\n', ' ')[:140])
    hid = await P_.ev('() => getComputedStyle(document.querySelector("#p-plan")).display')
    for i in range(6):
        if await P_.ev('() => { const b = document.querySelector("[data-dh=c1]"), h = document.querySelector("#dhBrief").getBoundingClientRect(), r = b.getBoundingClientRect(); return r.top >= h.top && r.bottom <= h.bottom }'): break
        hb = await P_.box('#dhBrief'); await P_.p.mouse.move(hb['x'] + 200, hb['y'] + 100); await P_.p.mouse.wheel(0, 300); await P_.p.wait_for_timeout(250)
    await into_view(P_, '[data-dh="c1"]'); await P_.click('[data-dh="c1"]'); sh = await P_.ev('() => [getComputedStyle(document.querySelector("#p-plan")).display, !!document.querySelector("#pbOv.on")]')
    if sh[1]: await P_.click('#pbOv .x')
    await into_view(P_, '[data-dh="c1"]'); await P_.click('[data-dh="c1"]'); h2 = await P_.ev('() => getComputedStyle(document.querySelector("#p-plan")).display')
    rec('C1 candidate table in a closed fold (open, close)', hid == 'none' and sh[0] != 'none' and h2 == 'none', 'before %s · open %s (prediction board %s) · closed %s' % (hid, sh[0], sh[1], h2))
    await scrollbar(P_, '#dhBrief', 'brief board')
    am = await amber(P_)
    rec('no amber fill on the brief (BUY NOW only on F1 / CALL)', len(am) <= 1, am)
    await cut(P_, 'Morning brief, fixture')
    if SHOTS: await shot(P_, 'Morning_brief_fixture_%d.png' % w)
    await morning_live(P_, w)


async def morning_live(P_, w):
    CUR['page'] = 'Morning (live)'
    await P_.go('morning')
    t = await P_.ev('() => document.querySelector("#dhBrief").innerText')
    vis = await P_.ev('() => getComputedStyle(document.querySelector("#p-plan")).display')
    rec('no brief in the store: "head analyst not running", old Morning kept', 'head analyst not running' in t and vis != 'none', t.replace('\n', ' ')[:140])
    await cut(P_, 'Morning, live')


async def room(P_, w):
    CUR['page'] = 'Desk Room (fixture state)'
    if not FIXBASE: return await room_live(P_, w)
    await P_.go('desk-room', FIXBASE)
    n = await P_.ev('() => [document.querySelectorAll("#drRoster .dh-seatrow").length, document.querySelectorAll("#drRoster .dh-bench").length, document.querySelectorAll("#drBoard .dh-card").length]')
    rec('SEAT ROSTER by bench, honest status per seat', n[0] == 9 and n[1] >= 6, '%s seats in %s benches' % (n[0], n[1]))
    rec('DESK BOARD: latest card per seat, strength 3+ by default', n[2] == 3, '%s cards' % n[2])
    await P_.p.select_option('#fKind', 'OBJECTION'); await P_.p.wait_for_timeout(300); k = await P_.ev('() => [...document.querySelectorAll("#drBoard .dh-kind")].map(e => e.textContent)')
    await P_.p.select_option('#fKind', ''); await P_.p.wait_for_timeout(200)
    rec('filter: kind (select)', k == ['OBJECTION'], k)
    await P_.click('#fSym'); await P_.p.keyboard.type('KOREA'); await P_.p.wait_for_timeout(300); sy = await P_.ev('() => document.querySelectorAll("#drBoard .dh-card").length')
    for _ in range(5): await P_.p.keyboard.press('Backspace')
    await P_.p.wait_for_timeout(200)
    rec('filter: symbol / word typed', sy == 1, '%s cards name KOREA' % sy)
    await P_.click('#fStrong'); a = await P_.ev('() => document.querySelectorAll("#drBoard .dh-card").length'); await P_.click('#fStrong')
    rec('strength 3+ toggle (off shows the weak cards)', a == 4, '%s cards with the toggle off' % a)
    if await P_.ev('() => document.querySelector("#fBench").options.length') > 1:
        await P_.p.select_option('#fBench', 'Reasoning'); await P_.p.wait_for_timeout(300); b = await P_.ev('() => document.querySelectorAll("#drBoard .dh-card").length'); await P_.p.select_option('#fBench', '')
        rec('filter: bench (select)', b == 2, '%s cards from the Reasoning bench' % b)
    r = await P_.ev('() => document.querySelector("#drRight").innerText')
    rec('THEMES, OBJECTIONS (verdict per idea), COVERAGE MAP (named as not in the contract)', all(x in r for x in ['THEMES', 'OBJECTIONS', 'AGAINST STRONGER', 'COVERAGE MAP', 'not in the desk contract']), r.replace('\n', ' ')[:120])
    for sel, lab in (('#drRoster', 'roster'), ('#drBoard', 'board'), ('#drRight', 'themes column')):
        await scrollbar(P_, sel, lab)
    await cut(P_, 'Desk Room, fixture')
    if SHOTS: await shot(P_, 'DeskRoom_fixture_%d.png' % w)
    await room_live(P_, w)


async def room_live(P_, w):
    CUR['page'] = 'Desk Room (live)'
    await P_.go('desk-room')
    t = await P_.ev('() => [document.querySelector("#drState").innerText, document.querySelector("#drRoster").innerText, document.querySelector("#drBoard").innerText]')
    rows = await P_.ev('() => document.querySelectorAll("#drRoster .dh-seatrow").length')
    rec('head not running: the state line says why; the roster shows the seats it has (or why not)', 'head analyst not running' in t[0] and len(t[0]) > 30 and (rows > 0 or 'desk' in t[1]) and len(t[2]) > 10, '%s · %s seat rows' % (t[0][:120].replace('\n', ' '), rows))
    await P_.go('sectors'); await P_.p.keyboard.press('F8'); await P_.p.wait_for_timeout(2500)
    rec('F8 opens the Desk Room (tab and key)', P_.p.url.endswith('/desk-room') and await P_.ev('() => !!document.querySelector(".sh-tab[data-tab=desk-room]")'), P_.p.url.split('/')[-1])
    await cut(P_, 'Desk Room, live')
    if SHOTS: await shot(P_, 'DeskRoom_live_%d.png' % w)


async def shot(P_, name):
    await P_.ev("""() => { const p = document.querySelector('#sh-pnl'); if (p && !p.querySelector('.pnl-lab')) { const l = document.createElement('span'); l.className = 'pnl-lab'; l.textContent = 'P&L hidden'; l.style.cssText = 'font:700 13px var(--sans);color:#C9D1DB;background:#2b3038;padding:2px 10px;border-radius:3px;margin:0 6px;align-self:center'; p.prepend(l); } }""")
    await P_.p.screenshot(path=os.path.join(SHOTS, name), mask=[P_.p.locator('#sh-pnl > .sh-pt'), P_.p.locator('#mPnl')], mask_color='#2b3038')


async def phone(P_, cdp):
    p = P_.p
    tp = lambda x, y: [{'x': x, 'y': y, 'radiusX': 1, 'radiusY': 1, 'force': 1, 'id': 1}]
    async def tap(sel, nth=0):
        b = await P_.box(sel, nth)
        if not b: raise Exception('no box ' + sel)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': tp(b['x'] + b['width'] / 2, b['y'] + b['height'] / 2)}); await p.wait_for_timeout(40)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []}); await p.wait_for_timeout(350)
    async def swipe(x, y, dx, dy):
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': tp(x, y)}); await p.wait_for_timeout(30)
        for i in range(1, 9):
            await cdp.send('Input.dispatchTouchEvent', {'type': 'touchMove', 'touchPoints': tp(x + dx * i / 8, y + dy * i / 8)}); await p.wait_for_timeout(16)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []}); await p.wait_for_timeout(900)
    async def ftap(sel):
        await into_view(P_, sel, swipe); await tap(sel)
    CUR['page'] = 'phone (fixture state)'
    if not FIXBASE: return await phone_live(P_, tap)
    await P_.go('phone', FIXBASE)
    inT = await p.evaluate('() => (GIR.store.val("pos.open") || []).length')
    t = await p.evaluate('() => (document.querySelector("#b-now .dh-pbr") || {}).innerText || ""')
    if inT:
        rec('NOW in a trade: unchanged + the MANAGE line', 'MANAGE' in t and 'HOLD' in t, t.replace('\n', ' ')[:120])
    else:
        rec('NOW flat: the brief card', 'BRIEF' in t, t.replace('\n', ' ')[:120])
    await tap('.m-tab[data-go="call"]')
    c = await p.evaluate('() => (document.querySelector("#b-call .dh-pcall") || {}).innerText || ""')
    rec('CALL: BUY NOW card read-only with FROM / AGAINST / NOT PROVEN', all(x in c for x in ['BUY NOW', 'FROM', 'AGAINST', 'NOT PROVEN']), c.replace('\n', ' ')[:140])
    await p.evaluate('() => navigator.clipboard.writeText("-")'); await ftap('#b-call .dh-copy'); clip = await p.evaluate('() => navigator.clipboard.readText()')
    toast = await p.evaluate('() => { const t = document.querySelector("#dhToast"); return t ? t.className + ": " + t.textContent : "no toast" }')
    rec('Copy contract (finger)', clip == 'SBIN Dec 1000 CE (ATM, exp 2026-12-29)', clip + ' · ' + toast)
    if await p.evaluate('() => !!document.querySelector("#b-call [data-dh=more]")'):
        await ftap('#b-call [data-dh="more"]'); n = await p.evaluate('() => document.querySelectorAll("#b-call .dh-why .dh-wl").length')
        rec('WHY "more" (finger)', n == 3, '%s why lines after more' % n)
    await ftap('#b-call [data-dh="taken"]'); a = await p.evaluate('() => document.querySelector("#b-call .dh-note").textContent')
    rec('TAKEN (finger)', 'TAKEN' in a, a)
    await ftap('#b-call [data-dh="skip"]'); await ftap('#b-call [data-dh="skipw"][data-w="late"]'); b = await p.evaluate('() => document.querySelector("#b-call .dh-note").textContent')
    rec('SKIP with one word (finger)', 'SKIP: late' in b, b)
    k = await p.evaluate('() => (document.querySelector("#b-call .dh-pbtn a") || {}).href || ""')
    rec('Open Kite link (he places the order)', 'kite.zerodha.com' in k, k)
    await ftap('#b-call .dh-conn'); a = await p.evaluate('() => !!document.querySelector("#dhTheme.on")'); await tap('#dhTheme [data-dh="x"]'); b2 = await p.evaluate('() => !!document.querySelector("#dhTheme.on")')
    rec('CONNECTION opens the read-only chain card, ✕ closes (finger)', a and not b2, 'open %s · closed %s' % (a, not b2))
    sw = await p.evaluate('() => document.documentElement.scrollWidth')
    rec('no sideways scroll at 390', sw <= 390, 'scrollWidth %s' % sw)
    await cut(P_, 'phone, fixture')
    if SHOTS: await shot(P_, 'phone_390_call_fixture.png')
    await tap('.m-tab[data-go="now"]')
    if SHOTS: await shot(P_, 'phone_390_now_fixture.png')
    await phone_live(P_, tap)


async def phone_live(P_, tap):
    p = P_.p
    CUR['page'] = 'phone (live)'
    await P_.go('phone')
    t = await p.evaluate('() => (document.querySelector("#b-now .dh-pbr") || {}).innerText || ""')
    await tap('.m-tab[data-go="call"]'); c = await p.evaluate('() => !!document.querySelector("#b-call .dh-pcall")')
    rec('no desk facts: NOW says so, CALL has no desk card', ('not running' in t) and not c, t.replace('\n', ' ')[:120])


async def all_pages(P_, w):
    CUR['page'] = 'all 23 pages + desk-room'
    names = await P_.ev('() => 0') if False else None
    import glob
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


async def run():
    if SHOTS: os.makedirs(SHOTS, exist_ok=True)
    async with async_playwright() as pw:
        b = await pw.chromium.launch(); cookies = []
        if WHERE == 'outside':
            sys.path.insert(0, '/home/globalbot/intraday'); import sitelogin
            full = sitelogin.make_cookie(); val = full.split(';')[0].split('=', 1)[1]
            cookies = [{'name': 'gir_s', 'value': val, 'domain': 'girtrader.com', 'path': '/', 'secure': True, 'httpOnly': True}]; del full, val
        origin = re.match(r'https?://[^/]+', BASE).group(0)
        for vp in VPS:
            w, h = map(int, vp.split('x')); CUR['vp'] = vp
            if w >= 700: ctx = await b.new_context(viewport={'width': w, 'height': h}, device_scale_factor=1)
            else:
                dev = dict(pw.devices['iPhone 13']); dev['viewport'] = {'width': w, 'height': h}; ctx = await b.new_context(**dev)
            if cookies: await ctx.add_cookies(cookies)
            await ctx.grant_permissions(['clipboard-read', 'clipboard-write'], origin=origin)
            if FIXBASE: await ctx.grant_permissions(['clipboard-read', 'clipboard-write'], origin=re.match(r'https?://[^/]+', FIXBASE).group(0))
            pg = await ctx.new_page(); P_ = P(pg)
            fns = [desk_f1, morning, room] if w >= 700 else []
            if os.environ.get('ALLPAGES'): fns.append(all_pages)
            for fn in fns:
                n0 = len(P_.errs)
                try: await fn(P_, w)
                except Exception as e: rec(fn.__name__ + ' (run)', False, 'exception: ' + str(e).split('\n')[0][:200] + ' @ ' + ','.join(re.findall(r'desk_r51.py", line (\d+)', traceback.format_exc())))
                if fn is not all_pages: rec('page errors', len(P_.errs) == n0, P_.errs[n0:][:3] or 'none')
            if w < 700:
                cdp = await ctx.new_cdp_session(pg); n0 = len(P_.errs)
                try: await phone(P_, cdp)
                except Exception as e: rec('phone (run)', False, 'exception: ' + str(e).split('\n')[0][:200] + ' @ ' + ','.join(re.findall(r'desk_r51.py", line (\d+)', traceback.format_exc())))
                rec('page errors', len(P_.errs) == n0, P_.errs[n0:][:3] or 'none')
                if os.environ.get('ALLPAGES'): await all_pages(P_, w)
            await ctx.close()
        await b.close()
    json.dump(R, open(OUT, 'w'), indent=1)
    c = {}
    for r in R: c[r['result']] = c.get(r['result'], 0) + 1
    print('TOTAL', c)

asyncio.run(run())

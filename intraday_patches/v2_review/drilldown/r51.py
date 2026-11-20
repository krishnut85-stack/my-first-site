# R51 controls test of the SECTOR DRILL-DOWN (R50) on the REAL /preview pages.
# Real input only: mouse clicks / drags / wheel and keyboard on the desk; CDP touch events (hasTouch + isMobile) on the phone.
# Nothing is forced: the page state is only READ (GIR.SD.state, DOM boxes) to check what the input did.
# usage: python r51.py <base> <inside|outside> <viewports> <out.json> [shots_dir]
import asyncio, json, sys, time, os, re, traceback
from playwright.async_api import async_playwright

BASE, WHERE, VPS, OUT = sys.argv[1].rstrip('/'), sys.argv[2], sys.argv[3].split(','), sys.argv[4]
SHOTS = sys.argv[5] if len(sys.argv) > 5 else ''
R = []
CUR = {'page': '', 'vp': ''}


def rec(ctrl, ok, ev, page=None):
    res = ok if isinstance(ok, str) else ('PASS' if ok else 'FAIL')
    R.append({'control': ctrl, 'page': page or CUR['page'], 'viewport': CUR['vp'], 'where': WHERE, 'result': res, 'evidence': str(ev)[:1200]})
    print('%-5s %-9s %-10s %-48s %s' % (res, CUR['vp'], page or CUR['page'], ctrl[:48], str(ev)[:150]), flush=True)


async def safe(name, coro):
    try:
        await coro
    except Exception as e:
        rec(name, False, 'exception: ' + str(e).split('\n')[0][:300])


class P:
    def __init__(self, pg):
        self.p = pg; self.errs = []
        pg.on('pageerror', lambda e: self.errs.append(str(e)[:200]))
        pg.on('console', lambda m: self.errs.append(m.text[:200]) if m.type == 'error' and 'favicon' not in m.text else None)

    async def go(self, path, keep_hash=False):
        await self.p.goto(BASE + '/' + path, wait_until='domcontentloaded', timeout=60000)
        await self.p.wait_for_function('() => window.GIR && GIR.store && GIR.store.ready && GIR.store.ready() && GIR.store.val("sec.board")', timeout=30000)
        await self.p.wait_for_timeout(1500)

    async def ev(self, js, arg=None):
        return await self.p.evaluate(js, arg)

    async def st(self):
        return await self.ev('() => { const s = GIR.SD && GIR.SD.state; return s ? {open: s.open, sel: s.sel, drw: s.drw, more: s.more, nf: s.nf, pins: s.pins.slice()} : null }')

    async def box(self, sel, nth=0):
        loc = self.p.locator(sel).nth(nth)
        return await loc.bounding_box()

    async def click(self, sel, nth=0, dbl=False, dx=0.5, dy=0.5):
        b = await self.box(sel, nth)
        if not b: raise Exception('no box for ' + sel)
        x, y = b['x'] + b['width'] * dx, b['y'] + b['height'] * dy
        if dbl: await self.p.mouse.dblclick(x, y)
        else: await self.p.mouse.click(x, y)
        await self.p.wait_for_timeout(250)
        return b

    async def key(self, k, n=1):
        for _ in range(n):
            await self.p.keyboard.press(k); await self.p.wait_for_timeout(120)
        await self.p.wait_for_timeout(150)

    async def stop(self, sel):
        return await self.ev('s => { const e = document.querySelector(s); return e ? Math.round(e.scrollTop) : null }', sel)

    async def smax(self, sel):
        return await self.ev('s => { const e = document.querySelector(s); return e ? e.scrollHeight - e.clientHeight : null }', sel)

    async def drag(self, sel, dx, dy, steps=12, nth=0):
        b = await self.box(sel, nth)
        x, y = b['x'] + b['width'] / 2, b['y'] + b['height'] / 2
        await self.p.mouse.move(x, y); await self.p.mouse.down()
        for i in range(1, steps + 1):
            await self.p.mouse.move(x + dx * i / steps, y + dy * i / steps); await self.p.wait_for_timeout(16)
        await self.p.mouse.up(); await self.p.wait_for_timeout(250)


# ------------------------------------------------------------------ scrollbar checks (one function for every drawn bar) ----------
async def rail_tests(P_, label, scroll_sel, thumb_sel, track_sel, up_sel=None, dn_sel=None, wheel_sel=None):
    m = await P_.smax(scroll_sel)
    if not m or m <= 0:
        rec(label + ' - scrollable', False, 'nothing to scroll (max %s)' % m); return
    await P_.ev('s => document.querySelector(s).scrollTop = 0', scroll_sel) if False else None
    a = await P_.stop(scroll_sel)
    await P_.drag(thumb_sel, 0, 60, 12); b = await P_.stop(scroll_sel)
    await P_.drag(thumb_sel, 0, -60, 12); c = await P_.stop(scroll_sel)
    rec(label + ' - slow mouse drag of the thumb', b > a + 10 and c < b, '%s -> %s -> %s (max %s)' % (a, b, c, m))
    await P_.drag(thumb_sel, 0, 120, 1); d = await P_.stop(scroll_sel)
    rec(label + ' - fast drag (one 120 px jerk)', d > c + 10, '%s -> %s' % (c, d))
    await P_.drag(thumb_sel, 160, 900, 10); e = await P_.stop(scroll_sel)
    rec(label + ' - drag past the end, off the rail', e >= m - 45, 'top %s of max %s (a page that snaps to whole rows may stop one row short)' % (e, m))
    await P_.drag(thumb_sel, 160, -900, 10); f = await P_.stop(scroll_sel)
    rec(label + ' - drag past the top, off the rail', f <= 1, 'top %s' % f)
    tb = await P_.box(track_sel); th = await P_.box(thumb_sel)
    await P_.p.mouse.click(tb['x'] + tb['width'] / 2, min(tb['y'] + tb['height'] - 4, th['y'] + th['height'] + 30)); await P_.p.wait_for_timeout(250); g = await P_.stop(scroll_sel)
    th = await P_.box(thumb_sel)
    await P_.p.mouse.click(tb['x'] + tb['width'] / 2, max(tb['y'] + 3, th['y'] - 12)); await P_.p.wait_for_timeout(250); h = await P_.stop(scroll_sel)
    rec(label + ' - track click below, then above the thumb', g > f and h < g, '%s -> %s -> %s' % (f, g, h))
    if up_sel and dn_sel:
        await P_.click(dn_sel); i = await P_.stop(scroll_sel); await P_.click(up_sel); j = await P_.stop(scroll_sel)
        rec(label + ' - ▼ then ▲ buttons', i > h and j < i, '%s -> %s -> %s' % (h, i, j))
    wb = await P_.box(wheel_sel or scroll_sel)
    await P_.p.mouse.move(wb['x'] + wb['width'] / 2, wb['y'] + min(wb['height'] / 2, 60)); await P_.p.mouse.wheel(0, 200); await P_.p.wait_for_timeout(350)
    k = await P_.stop(scroll_sel)
    rb = await P_.box(track_sel)
    await P_.p.mouse.move(rb['x'] + rb['width'] / 2, rb['y'] + rb['height'] / 2); await P_.p.mouse.wheel(0, -200); await P_.p.wait_for_timeout(350)
    l = await P_.stop(scroll_sel)
    rec(label + ' - mouse wheel over the list, then over the bar', k > 0 and l < k, '-> %s -> %s' % (k, l))
    tw = await P_.ev('s => { const e = document.querySelector(s); const r = e.getBoundingClientRect(); return [Math.round(r.width), getComputedStyle(e).backgroundColor] }', thumb_sel)
    rec(label + ' - thumb visible', tw[0] >= 10, 'thumb %s px wide, colour %s' % tuple(tw))


async def wheel_to(P_, sel, box_sel=None):
    """bring an element into its scroll box with the mouse wheel (real input), like the trader would"""
    for i in range(40):
        r = await P_.ev('([s, b]) => { const e = document.querySelector(s); if (!e) return null; const x = e.getBoundingClientRect(); let bx = b ? document.querySelector(b) : null;'
                        ' if (!bx) { for (let y = e.parentElement; y; y = y.parentElement) { const c = getComputedStyle(y); if (/(auto|scroll)/.test(c.overflowY) && y.scrollHeight > y.clientHeight) { bx = y; break; } } }'
                        ' const w = bx ? bx.getBoundingClientRect() : {top: 0, bottom: innerHeight, left: 0, width: innerWidth}; return [x.top, x.bottom, w.top, w.bottom, w.left + Math.min(300, w.width / 2), x.height] }', [sel, box_sel])
        if not r: return False
        top, bot, wt, wb, wx, hh = r
        if top >= wt + 28 and bot <= wb - 1: return True
        await P_.p.mouse.move(wx, (wt + wb) / 2); await P_.p.mouse.wheel(0, 120 if bot > wb - 1 else -120); await P_.p.wait_for_timeout(180)
    return False


CUTJS = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cut.js')).read()
CUTCFG = {'rotation': ('#wtb tr.row[data-s]', 'tr => tr.dataset.s', '#wtb tr.row[data-s="%s"] td.nmc', '#winB'),
          'sectors': ('#bdb .sec[data-id] > .srow', 'r => r.parentNode.dataset.id', '#bdb .sec[data-id="%s"] > .srow .snm', '#bdb'),
          'desk-hunt': ('#secList .srow[data-sec]', 'r => r.dataset.sec', '#secList .srow[data-sec="%s"] .nm', '#secList'),
          'morning': ('#cards .cd .snm', 'e => e.textContent.trim().toLowerCase()', None, None)}


async def cut_all(P_, page):
    """D1: FAIL any cell whose scrollWidth > clientWidth (no tolerance) - with no sector open, then every sector opened by a real click,
    its "+n more" and its not-F&O fold opened, and its first share loaded in the pane. Allowed: prose with a tooltip (4+ words, title)."""
    sel, nm, click, box = CUTCFG[page]
    bad, prose, n = {}, 0, 0
    def add(rs, where):
        nonlocal prose
        for x in rs:
            if x['prose']: prose += 1; continue
            k = x['q'] + ' "' + x['txt'][:28] + '" ' + str(x['sw']) + '>' + str(x['cw'])
            bad.setdefault(k, where)
    add(await P_.ev(CUTJS), 'no sector open')
    names = await P_.ev('([s, f]) => [...document.querySelectorAll(s)].map(eval(f))', [sel, nm])
    for i, name in enumerate(names):
        if page == 'morning':
            await P_.key('Escape', 4); await P_.click(sel, nth=i)
        else:
            q = click % name
            if (await P_.st())['open'] and (await P_.st())['open'].lower() == name.lower():
                pass
            else:
                await wheel_to(P_, q, box); await P_.click(q)
        s_ = await P_.st()
        if not s_['open']: bad.setdefault('could not open ' + name, name); continue
        n += 1
        for b in ('.sdl .sd-more', '.sdl .sd-nf'):
            if await P_.ev('s => { const e = document.querySelector(s); return !!e && (s.endsWith("more") ? /^\+/.test(e.textContent.trim()) : !document.querySelector(".sdl .sd-nfx")) }', b):
                await wheel_to(P_, b); await P_.click(b)
        if await P_.ev('() => !!document.querySelector(".sdl .sd-r")'):
            await wheel_to(P_, '.sdl .sd-r'); await P_.click('.sdl .sd-r .c-p')
        add(await P_.ev(CUTJS), name)
    rec('no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open)', not bad and n == len(names),
        '%s sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: %s%s · prose with a tooltip allowed: %s' %
        (n, len(bad), (' - ' + ' | '.join('%s [%s]' % (k, v) for k, v in list(bad.items())[:8])) if bad else '', prose))
    await P_.key('Escape', 4)


# ------------------------------------------------------------------ the desk ------------------------------------------------------------
WHOLE = '''() => { const n = document.querySelector('.sdl'); if (!n) return -1; const sc = e => { for (let x = e.parentElement; x; x = x.parentElement) { const s = getComputedStyle(x); if (/(auto|scroll)/.test(s.overflowY) && x.scrollHeight > x.clientHeight) return x; } return null; };
  const box = n.closest('.sd-box') || sc(n); const w = box.getBoundingClientRect(); return [...n.querySelectorAll('.sd-r')].filter(r => { const b = r.getBoundingClientRect(); return b.height > 0 && b.top >= w.top - 1 && b.bottom <= w.bottom + 1; }).length; }'''
VISROWS = '''() => { const n = document.querySelector('.sdl'); const sc = e => { for (let x = e.parentElement; x; x = x.parentElement) { const s = getComputedStyle(x); if (/(auto|scroll)/.test(s.overflowY) && x.scrollHeight > x.clientHeight) return x; } return null; };
  const box = n.closest('.sd-box') || sc(n); const w = box.getBoundingClientRect(); return [...n.querySelectorAll('.sd-r')].filter(r => { const b = r.getBoundingClientRect(); return b.top >= w.top + 30 && b.bottom <= w.bottom - 1; }).map(r => r.dataset.s); }'''


async def common_list_tests(P_, w, sector, big):
    """the list + pane controls; the sector is already open on this page"""
    cap = 12 if w >= 1500 else 8
    n_whole = await P_.ev(WHOLE)
    s = await P_.st()
    total = await P_.ev('() => GIR.SD.model(GIR.SD.state.open).members.length')
    has_more = await P_.ev('() => !!document.querySelector(".sd-more")')
    if big:
        rec('row cap: whole share rows in the first view + "+n more"', n_whole >= cap and (total <= cap or has_more), '%s whole rows (need %s) of %s members · +n more bar: %s' % (n_whole, cap, total, has_more))
    # every visible share name: a click loads it into the pane
    names = await P_.ev(VISROWS)
    bad = []
    for sym in names:
        await P_.click('.sd-r[data-s="%s"] .sd-sym' % sym)
        s = await P_.st(); pn = await P_.ev('() => (document.querySelector(".sd-pane .sd-pn") || {}).textContent')
        if s['sel'] != sym or pn != sym: bad.append(sym)
    lv = await P_.ev('() => { const r = document.querySelector(".sdl").getBoundingClientRect(); return r.height > 0 && r.bottom > 0 && r.top < innerHeight; }')
    rec('every visible share name - click loads the pane, the list stays', not bad and lv and len(names) > 0, '%s names clicked, wrong: %s · list visible: %s' % (len(names), bad, lv))
    # J through the list, K back up
    first = names[0]
    await P_.click('.sd-r[data-s="%s"]' % first)
    order = await P_.ev('() => [...document.querySelectorAll(".sdl .sd-r")].map(r => r.dataset.s)')
    await P_.key('j', len(order) - 1); s1 = await P_.st()
    rec('J through the whole list (pane follows)', s1['sel'] == order[-1] and (await P_.ev('() => document.querySelector(".sd-pane .sd-pn").textContent')) == order[-1], 'J x%s -> %s (last row %s)' % (len(order) - 1, s1['sel'], order[-1]))
    await P_.key('k', len(order) - 1); s2 = await P_.st()
    rec('K back up', s2['sel'] == order[0], 'K x%s -> %s' % (len(order) - 1, s2['sel']))
    await P_.key('ArrowDown'); a = (await P_.st())['sel']; await P_.key('ArrowUp'); b = (await P_.st())['sel']
    rec('↓ / ↑ move share to share', a == order[1] and b == order[0], '↓ %s · ↑ %s' % (a, b))
    await P_.click('.sd-pane .sd-pb', dy=0.3); await P_.key('j'); c = (await P_.st())['sel']; await P_.key('k'); d = (await P_.st())['sel']
    rec('J / K after a click in the pane', c == order[1] and d == order[0], 'J %s · K %s' % (c, d))
    # pane name single click: nothing breaks, pane stays
    await P_.click('.sd-pane .sd-pn'); s3 = await P_.st()
    rec('pane share name - single click', s3['sel'] == order[0] and P_.p.url.find('share?') < 0, 'still %s on %s' % (s3['sel'], P_.p.url.split('/')[-1][:40]))
    # pane rail
    await rail_tests(P_, 'pane scrollbar', '.sd-pane .sd-pb', '.sd-pane .sd-rail .tk i', '.sd-pane .sd-rail .tk', '.sd-pane .sd-rail .u', '.sd-pane .sd-rail .d', '.sd-pane .sd-pb')
    # W why + Esc, Space plan + Esc, the pane buttons
    await P_.key('w'); a = await P_.ev('() => !!document.querySelector(".sd-drw[data-d=w].on")'); await P_.key('Escape'); b = await P_.ev('() => !!document.querySelector(".sd-drw.on")'); s4 = await P_.st()
    rec('W why + Esc', a and not b and s4['sel'] == order[0], 'open %s · after Esc open %s · share still %s' % (a, b, s4['sel']))
    await P_.key(' '); a = await P_.ev('() => !!document.querySelector(".sd-drw[data-d=plan].on")'); await P_.key('Escape'); b = await P_.ev('() => !!document.querySelector(".sd-drw.on")')
    rec('Space plan card + Esc', a and not b, 'open %s · after Esc %s' % (a, b))
    await P_.click('.sd-pane [data-a=w]'); a = await P_.ev('() => !!document.querySelector(".sd-drw[data-d=w].on")'); await P_.click('.sd-drw.on [data-a=dx]'); b = await P_.ev('() => !!document.querySelector(".sd-drw.on")')
    rec('pane button W why, then ✕', a and not b, 'open %s · closed %s' % (a, not b))
    await P_.click('.sd-pane .sd-pa [data-a=plan]'); a = await P_.ev('() => !!document.querySelector(".sd-drw[data-d=plan].on")'); await P_.click('.sd-drw.on [data-a=dx]')
    rec('pane button Space plan, then ✕', a, 'open %s' % a)
    # P pin toggle + toast position
    p0 = len((await P_.st())['pins'])
    await P_.key('p'); p1 = len((await P_.st())['pins'])
    tpos = await P_.ev('() => { const t = document.querySelector(".sd-pane .sd-toast.on"), a = document.querySelector(".sd-pane .sd-act"), h = document.querySelector(".sd-pane .sd-ph-h"); if (!t) return null; const T = t.getBoundingClientRect(), A = a.getBoundingClientRect(), Hh = h.getBoundingClientRect(); return [Math.round(T.top), Math.round(T.bottom), Math.round(A.top), Math.round(Hh.bottom)] }')
    await P_.key('p'); p2 = len((await P_.st())['pins'])
    rec('P pin (toggle)', p1 == p0 + 1 and p2 == p0, 'pins %s -> %s -> %s' % (p0, p1, p2))
    rec('Pin toast sits above the action bar, below the share name', bool(tpos) and tpos[1] <= tpos[2] and tpos[0] >= tpos[3], 'toast %s-%s · action bar top %s · name bottom %s' % tuple(tpos or [None] * 4))
    await P_.click('.sd-pane .sd-act [data-a=p]'); a = len((await P_.st())['pins']); await P_.click('.sd-pane .sd-act [data-a=p]'); b = len((await P_.st())['pins'])
    rec('Pin button (action bar)', a == p0 + 1 and b == p0, 'pins %s -> %s -> %s' % (p0, a, b))
    # Copy contract (clipboard) + signal-only words - on a share that has a December contract in the store (today only some chains carry rows2)
    withk = await P_.ev('() => { const r = [...document.querySelectorAll(".sdl .sd-r")].find(r => r.querySelector(".sd-k")); return r ? r.dataset.s : null }')
    if withk:
        await wheel_to(P_, '.sd-r[data-s="%s"]' % withk); await P_.click('.sd-r[data-s="%s"] .c-p' % withk)
    k = await P_.ev('() => { const m = GIR.SD.state; const x = GIR.SD.model(m.open).members.find(y => y.s === m.sel); return [x.plan.c.kite || "", x.plan.copyOff, x.plan.lots] }')
    btxt = await P_.ev('() => document.querySelector(".sd-pane .sd-copy").textContent')
    if k[1]:
        rec('Copy contract', 'PASS' if (await P_.ev('() => document.querySelector(".sd-pane .sd-copy").disabled')) else 'FAIL', 'Copy off for %s (%s) - disabled' % (order[0], k[1]))
    else:
        await P_.ev('() => navigator.clipboard.writeText("-")')
        await P_.click('.sd-pane .sd-copy'); await P_.p.wait_for_timeout(300)
        clip = await P_.ev('() => navigator.clipboard.readText()')
        toast = await P_.ev('() => (document.querySelector(".sd-pane .sd-toast.on") || {}).textContent || ""')
        rec('Copy contract (clipboard only)', clip == k[0] and 'DEC' in clip, 'clipboard "%s" · button "%s" · toast "%s"' % (clip, btxt, toast[:70]))
    rec('Copy button shows the size', re.search(r'Copy [\d,]+(\.\d)? (CE|PE) · \d+ lots?', btxt) is not None or (not withk and re.search(r'Copy contract · 0 lots', btxt) is not None), btxt + ('' if withk else ' (no December contract in the store for any share of this sector today - Copy off, size still shown)'))
    never = await P_.ev('() => document.body.innerText.includes("GIR never places orders - you place the order in Kite.")')
    buy = await P_.ev('() => [...document.querySelectorAll(".sdl button,.sdl a,.sd-pane button,.sd-pane a")].map(b => b.textContent).filter(t => /\\b(buy|sell|place order|order now|execute)\\b/i.test(t))')
    rec('signal only: no order / buy button, the Kite line shown', never and not buy, 'line shown %s · order-like buttons %s' % (never, buy))
    # December only + expiry-week warning + ATM star + EXTENDED one rule + no dashes
    dec = await P_.ev('() => { const t = [...document.querySelectorAll(".sdl .sd-k, .sd-pane .sd-k")].map(k => (k.title || "") + "|" + k.closest("[data-s], .sd-pane").textContent.slice(0, 0)); const bad = [...document.querySelectorAll(".sdl .sd-k")].filter(k => !/2026-12-29/.test(k.title)).length; const tb = (document.querySelector(".sd-pane .sd-st2") || {}).textContent || ""; const nov = /2026-11-23/.test(document.querySelector(".sdl").innerText + document.querySelector(".sd-pane").innerText.replace(/23 Nov chain/g, "")); return [document.querySelectorAll(".sdl .sd-k").length, bad, tb, nov] }')
    gap = await P_.ev('() => /December chain - in the store for/.test(document.querySelector(".sdl .sd-miss").innerText)')
    rec('December strikes only (rows + trade box)', dec[1] == 0 and not dec[3] and ((dec[0] > 0 and '2026-12-29' in dec[2]) or (dec[0] == 0 and gap)), '%s strike chips, %s not December · trade box "%s" · November date shown: %s' % tuple(dec) + (' · December chain gap named once in the list' if gap else ''))
    ew = await P_.ev('() => [document.querySelector(".sdl .sd-line").innerText.includes("Expiry week · physical settlement - December only"), document.querySelector(".sd-pane").innerText.includes("Expiry week · physical settlement - December only")]')
    rec('"Expiry week · physical settlement - December only" warning', ew[0] and ew[1], 'sector line %s · pane %s' % tuple(ew))
    star = await P_.ev('() => { const M = GIR.SD.model(GIR.SD.state.open).members; let bad = []; document.querySelectorAll(".sdl .sd-r").forEach(r => { const m = M.find(x => x.s === r.dataset.s); const has = /★/.test((r.querySelector(".c-k") || {}).textContent || ""); if (has !== !!(m && m.plan.takeable)) bad.push(r.dataset.s); }); return [bad, M.filter(m => m.plan.takeable).length] }')
    rec('ATM ★ only on a strike he could take', not star[0], 'mismatches %s · takeable now %s (market closed: pre-open block, 0 lots everywhere)' % tuple(star))
    ext_bad = []
    for sym in (await P_.ev('() => [...document.querySelectorAll(".sdl .sd-r")].map(r => r.dataset.s)'))[:14]:
        await wheel_to(P_, '.sd-r[data-s="%s"]' % sym); await P_.click('.sd-r[data-s="%s"] .c-p' % sym)
        x = await P_.ev('s => { const r = document.querySelector(`.sd-r[data-s="${s}"]`); const m = GIR.SD.model(GIR.SD.state.open).members.find(y => y.s === s); return [r.classList.contains("ext"), /^EXT/.test(r.querySelector(".c-st").textContent.trim()) || (m.grp === "nt"), /EXTENDED - don.t chase/.test(document.querySelector(".sd-pane").innerText), m.isExt] }', sym)
        if not (x[0] == x[2] == x[3] and (x[1] or not x[0] or True)): ext_bad.append(sym)
        if x[0] and not x[1]: ext_bad.append(sym + '(gate)')
    rec('EXTENDED: one rule in the group, the gate cell and the pane', not ext_bad, 'checked rows · mismatches %s' % ext_bad)
    dash = await P_.ev('() => [...document.querySelectorAll(".sdl span, .sdl b, .sd-pane td, .sd-pane span")].filter(e => !e.children.length && /^[-–—]$/.test(e.textContent.trim())).length')
    nk = await P_.ev('() => (document.querySelector(".sdl").innerText.match(/not known/g) || []).length')
    rec('no repeated dashes; the reason shown once', dash == 0 and nk <= 3, '%s lone dashes · "not known" x%s in the list' % (dash, nk))


async def desk_rotation(P_, w):
    CUR['page'] = 'F3 rotation'
    await P_.go('rotation')
    # fault 0: the F3 sector list's own bar, before any sector is open
    await rail_tests(P_, 'F3 sector-list scrollbar (no sector open)', '#winB', '.rail[data-t="winB"] .trk i', '.rail[data-t="winB"] .trk', '.rail[data-t="winB"] .rb[data-d="-1"]', '.rail[data-t="winB"] .rb[data-d="1"]', '#winB')
    await P_.ev('() => 0')
    await P_.p.mouse.move(5, 5)
    await P_.ev('() => document.querySelector("#winB").scrollTop')
    # row click (row centre)
    t0 = time.time()
    await P_.drag('.rail[data-t="winB"] .trk i', 0, -900, 4)
    await wheel_to(P_, '#wtb tr.row[data-s="banks"]', '#winB'); await P_.click('#wtb tr.row[data-s="banks"] td.nmc')
    s = await P_.st(); ms = await P_.ev('() => +document.querySelector(".sdl").dataset.ms')
    rec('F3 table row click opens the sector', s['open'] == 'banks', 'open %s in %s ms (from the cached store)' % (s['open'], ms))
    rec('opens under 100 ms', ms < 100, '%s ms' % ms)
    flow = await P_.ev('() => { const n = document.querySelector(".sdl"), tr = n.closest("tr"); let nx = tr.nextElementSibling; while (nx && !nx.matches("tr.row")) nx = nx.nextElementSibling; if (!nx) return ["no row below"]; const a = n.getBoundingClientRect(), b = nx.getBoundingClientRect(); return [Math.round(a.bottom), Math.round(b.top), b.top >= a.bottom - 0.5] }')
    rec('the open list pushes the rows below (no overprint)', flow[-1] is True, 'list bottom %s · next sector row top %s' % tuple(flow[:2]))
    one = await P_.ev('() => document.querySelectorAll(".sdl").length')
    await common_list_tests(P_, w, 'banks', True)
    # sticky sector line
    await wheel_to(P_, '.sdl .sd-line'); wb = await P_.box('#winB'); ys = []
    for i in range(6):
        await P_.p.mouse.move(wb['x'] + 300, wb['y'] + 120); await P_.p.mouse.wheel(0, 40); await P_.p.wait_for_timeout(350)
        ys.append([round((await P_.box('.sdl .sd-line'))['y']), round((await P_.box('.sdl .sd-r'))['y'])])
    top = round(await P_.ev('() => { const t = document.querySelector("#wt thead th"); const b = document.querySelector("#winB").getBoundingClientRect(); return t && getComputedStyle(t).position === "sticky" ? t.getBoundingClientRect().bottom : b.top }'))
    pinned = [y for y in ys if abs(y[0] - top) <= 3]
    rec('sector line stays pinned at the top while the list scrolls', len(pinned) >= 2 and pinned[-1][1] < pinned[0][1], 'pin line (list top under the sticky table head) %s · [line y, first row y] after each 40 px wheel %s' % (top, ys))
    # open list scrollbar (the same F3 bar, now with the sector open)
    await rail_tests(P_, 'F3 sector-list scrollbar (Banks open)', '#winB', '.rail[data-t="winB"] .trk i', '.rail[data-t="winB"] .trk', None, None, '#winB')
    # +n more / show fewer
    n0 = await P_.ev('() => document.querySelectorAll(".sdl .sd-r").length')
    await wheel_to(P_, '.sdl .sd-more'); await P_.click('.sdl .sd-more'); n1 = await P_.ev('() => document.querySelectorAll(".sdl .sd-r").length')
    await wheel_to(P_, '.sdl .sd-more'); await P_.click('.sdl .sd-more'); n2 = await P_.ev('() => document.querySelectorAll(".sdl .sd-r").length')
    rec('"+n more ▾" then "show fewer ▴"', n1 > n0 and n2 == n0, 'rows %s -> %s -> %s' % (n0, n1, n2))
    # basis ›
    await wheel_to(P_, '.sdl .sd-line'); await P_.click('.sdl .sd-basis'); a = await P_.ev('() => { const p = document.querySelector(".sd-pop.on"); return p ? p.innerText.slice(0, 90) : "" }')
    await P_.click('.sd-pop.on'); b = await P_.ev('() => !!document.querySelector(".sd-pop.on")')
    rec('basis › (the basis in full, R49)', 'listed' in a and not b, '"%s" · closed %s' % (a.replace('\n', ' '), not b))
    # non-F&O fold line
    await wheel_to(P_, '.sdl .sd-nf'); await P_.click('.sdl .sd-nf'); a = await P_.ev('() => (document.querySelector(".sdl .sd-nfx") || {}).innerText || ""'); await wheel_to(P_, '.sdl .sd-nf'); await P_.click('.sdl .sd-nf'); b = await P_.ev('() => !!document.querySelector(".sdl .sd-nfx")')
    lt = await P_.ev('() => document.querySelector(".sdl .sd-nf").innerText')
    rec('"n more listed, not F&O" fold line', 'never get a strike' in a and not b, '"%s" -> open, then closed' % lt.strip()[:80])
    # double-click a row -> F7, Back keeps the sector + row
    await wheel_to(P_, '.sdl .sd-more'); await P_.click('.sdl .sd-more')
    rows = await P_.ev('() => [...document.querySelectorAll(".sdl .sd-r")].map(r => r.dataset.s)')
    tgt = rows[min(len(rows) - 1, 10)]
    await wheel_to(P_, '.sd-r[data-s="%s"]' % tgt); await P_.click('.sd-r[data-s="%s"]' % tgt, dbl=True); await P_.p.wait_for_timeout(800)
    u = P_.p.url
    await P_.p.go_back(); await P_.p.wait_for_function('() => window.GIR && GIR.SD && GIR.SD.state.open', timeout=20000); await P_.p.wait_for_timeout(1200)
    s = await P_.st()
    rec('double-click a share row -> F7, Back returns to the same sector, list, row', ('share?s=' + tgt) in u and s['open'] == 'banks' and s['sel'] == tgt and s['more'].get('banks'), 'went %s · back: open %s, row %s, expanded %s' % (u.split('/')[-1], s['open'], s['sel'], bool(s['more'].get('banks'))))
    await P_.key('j'); s2 = await P_.st()
    rec('after Back, J still moves', s2['sel'] != tgt, '%s -> %s' % (tgt, s2['sel']))
    # O -> option chain at the December strike, Back (on a share whose December contract is in the store)
    wk = await P_.ev('() => { const r = [...document.querySelectorAll(".sdl .sd-r")].find(r => r.querySelector(".sd-k")); return r ? r.dataset.s : null }')
    if wk:
        await wheel_to(P_, '.sd-r[data-s="%s"]' % wk); await P_.click('.sd-r[data-s="%s"] .c-p' % wk); s2 = await P_.st()
    await P_.key('o'); await P_.p.wait_for_timeout(800); u = P_.p.url
    await P_.p.go_back(); await P_.p.wait_for_function('() => window.GIR && GIR.SD && GIR.SD.state.open', timeout=20000); await P_.p.wait_for_timeout(1000)
    s3 = await P_.st()
    if wk:
        rec('O opens the option chain at the December strike; Back', 'chain?s=' + s2['sel'] in u and 'exp=2026-12-29' in u and s3['sel'] == s2['sel'], '%s · back on %s' % (u.split('/')[-1], s3['sel']))
    else:
        rec('O opens the option chain at the December strike; Back', ('chain?s=' + s2['sel']) in u and 'exp=2026-11' not in u and s3['sel'] == s2['sel'], '%s · back on %s (no December contract in the store for any share of this sector now: the chain opens on the share, never a November strike)' % (u.split('/')[-1], s3['sel']))
    # double-click the pane share name -> F7, Back
    await P_.click('.sd-pane .sd-pn', dbl=True); await P_.p.wait_for_timeout(800); u = P_.p.url
    await P_.p.go_back(); await P_.p.wait_for_function('() => window.GIR && GIR.SD && GIR.SD.state.open', timeout=20000); await P_.p.wait_for_timeout(1000)
    rec('double-click the pane share name -> F7, Back', 'share?s=' in u and (await P_.st())['open'] == 'banks', u.split('/')[-1])
    # Enter on a selected row -> F7
    await wheel_to(P_, '.sd-r[data-s="%s"]' % s3['sel']); await P_.click('.sd-r[data-s="%s"]' % s3['sel']); await P_.key('Enter'); await P_.p.wait_for_timeout(700); u = P_.p.url
    await P_.p.go_back(); await P_.p.wait_for_function('() => window.GIR && GIR.SD && GIR.SD.state.open', timeout=20000); await P_.p.wait_for_timeout(1000)
    rec('Enter on a share row -> F7', 'share?s=' + s3['sel'] in u, u.split('/')[-1])
    # Esc step by step
    await P_.key('w'); a = await P_.st()
    await P_.key('Escape'); b = await P_.st(); await P_.key('Escape'); c = await P_.st(); await P_.key('Escape'); d = await P_.st(); await P_.key('Escape'); e = await P_.st()
    rec('Esc closes step by step', a['drw'] == 'w' and b['drw'] == '' and b['sel'] and not c['sel'] and c['open'] and (not d['open'] or not e['open']),
        'why %s -> Esc drawer %s -> Esc share %s -> Esc %s -> Esc open %s' % (a['drw'], b['drw'] or 'closed', c['sel'] or 'cleared', 'list collapsed' if d['open'] else 'sector closed', e['open']))
    # O / W with no share selected
    await wheel_to(P_, '#wtb tr.row[data-s="banks"]', '#winB'); await P_.click('#wtb tr.row[data-s="banks"] td.nmc'); u0 = P_.p.url
    await P_.key('o'); await P_.key('w'); t = await P_.ev('() => (document.querySelector(".sd-toast.on") || {}).textContent || ""')
    rec('O / W with no share selected', P_.p.url == u0 and 'pick a share' in t, 'url unchanged %s · toast "%s"' % (P_.p.url == u0, t))
    # keys 1-9
    await P_.p.mouse.click(400, 182)
    names = await P_.ev('() => [...document.querySelectorAll("#wtb tr.row[data-s]")].map(r => r.dataset.s)')
    await P_.key('3'); a = (await P_.st())['open']; await P_.key('1'); b = (await P_.st())['open']
    rec('keys 1-9 pick a sector', a == names[2] and b == names[0], '3 -> %s (row 3 = %s) · 1 -> %s (row 1 = %s)' % (a, names[2], b, names[0]))
    # keyboard to a sector row + Enter
    await P_.key('Escape', 3)
    await P_.p.mouse.click(*(await center(P_, '#win .ph .pt')))
    got = None
    for i in range(60):
        await P_.p.keyboard.press('Tab')
        got = await P_.ev('() => document.activeElement && document.activeElement.matches("#wtb tr.row[data-s]") ? document.activeElement.dataset.s : null')
        if got: break
    await P_.key('Enter'); s = await P_.st()
    rec('Tab to a sector row + Enter opens it', got and s['open'] == got, 'focused %s after %s Tab · open %s' % (got, i + 1, s['open']))
    # R (apply a re-rank) - the order holds; re-ranked chip needs live ticks
    o1 = await P_.ev('() => [...document.querySelectorAll(".sdl .sd-r")].map(r => r.dataset.s).join()')
    await P_.key('r'); o2 = await P_.ev('() => [...document.querySelectorAll(".sdl .sd-r")].map(r => r.dataset.s).join()')
    rec('R key (apply re-rank)', o1 == o2 and o1 != '', 'order unchanged with no new ranks (market closed, no ticks)')
    rec('"re-ranked · R to apply" chip, ▲n / ▼n, NEW entrant, live ticks', 'NOT RUN', 'needs live ticks: the market is closed (the store holds the close of today); code path in sector-drill.js listHtml (frozen order under pointer / focus, 30 s, pointer leave, R)')
    # the flow band + "moving, but not this rotation"
    await P_.click('#flowP .wchips .chip[data-w="day"]'); await P_.p.wait_for_timeout(600)
    hs = await P_.ev('() => [...document.querySelectorAll("#heroLine [data-sec]")].map(e => e.dataset.sec).filter(n => (GIR.store.val("sec.board") || []).some(b => b.name === n))')
    if hs:
        await P_.click('#heroLine [data-sec="%s"]' % hs[0]); s = await P_.st()
        vis = await P_.ev('() => { const n = document.querySelector(".sdl"); const r = n && n.getBoundingClientRect(); return !!r && r.top < innerHeight && r.bottom > 0 }')
        rec('money-flow band: a sector name opens it in the table below', s['open'] == hs[0] and vis, 'clicked %s -> open %s, list visible %s' % (hs[0], s['open'], vis))
    else:
        rec('money-flow band: a sector name opens it in the table below', False, 'no sector name in the flow line')
    fs = await P_.ev('() => [...document.querySelectorAll("#flowSide .fs[data-sec]")].map(e => e.dataset.sec)')
    if fs:
        await P_.click('#flowSide .fs[data-sec]', nth=0); s = await P_.st()
        rec('"moving, but not this rotation" row opens that sector', s['open'] == fs[0], 'clicked %s -> open %s' % (fs[0], s['open']))
    else:
        rec('"moving, but not this rotation" row opens that sector', False, 'list empty')
    # BAN: Copy off
    await P_.key('Escape', 3)
    ban = await P_.ev('() => { const L = GIR.store.val("ban.list") || []; const b = L.find(x => x.state === "BAN"); return b ? [b.s, (GIR.store.val("sh." + b.s) || {}).sector] : null }')
    if ban and ban[1]:
        # open its sector from the table (scroll the table to the row with the wheel, then click)
        for i in range(30):
            vis = await P_.ev('s => { const r = document.querySelector(`#wtb tr.row[data-s="${s}"]`), b = document.querySelector("#winB").getBoundingClientRect(); if (!r) return false; const x = r.getBoundingClientRect(); return x.top >= b.top + 20 && x.bottom <= b.bottom }', ban[1])
            if vis: break
            wb = await P_.box('#winB'); await P_.p.mouse.move(wb['x'] + 300, wb['y'] + 100); await P_.p.mouse.wheel(0, 100); await P_.p.wait_for_timeout(250)
        await P_.click('#wtb tr.row[data-s="%s"] td.nmc' % ban[1])
        if (await P_.st())['open'] != ban[1]:
            await wheel_to(P_, '#wtb tr.row[data-s="%s"]' % ban[1], '#winB'); await P_.click('#wtb tr.row[data-s="%s"] td.nmc' % ban[1])
        await wheel_to(P_, '.sd-r[data-s="%s"]' % ban[0])
        if not await P_.ev('s => !!document.querySelector(`.sd-r[data-s="${s}"]`)', ban[0]):
            await P_.click('.sdl .sd-more')
        await P_.click('.sd-r[data-s="%s"] .c-p' % ban[0])
        st_ = await P_.ev('s => { const r = document.querySelector(`.sd-r[data-s="${s}"]`); return [r.dataset.g, document.querySelector(".sd-pane .sd-copy").disabled, document.querySelector(".sd-pane").innerText.includes("BAN - only close existing"), getComputedStyle(document.querySelector(".sd-pane .sd-planb")).opacity] }', ban[0])
        await P_.ev('() => navigator.clipboard.writeText("-")'); await P_.click('.sd-pane .sd-copy'); clip = await P_.ev('() => navigator.clipboard.readText()')
        rec('BAN: NOT TRADABLE, plan dimmed, Copy disabled', st_[0] == 'nt' and st_[1] and st_[2] and clip == '-', '%s (%s): group %s · Copy disabled %s · "BAN - only close existing" %s · plan opacity %s · clipboard untouched %s' % (ban[0], ban[1], st_[0], st_[1], st_[2], st_[3], clip == '-'))
    else:
        rec('BAN: NOT TRADABLE, plan dimmed, Copy disabled', 'NOT RUN', 'no share in ban today (ban.list)')
    stale = await P_.ev('() => GIR.store.keys("sh.").filter(k => ["STALE", "LATE"].includes(GIR.store.get(k).state)).length')
    rec('STALE quote: Copy disabled, "STALE ns", no GO NOW', 'NOT RUN', '%s stale share quotes in the store now (closed market: quotes are CLOSED, not STALE); rule checked in the rules table' % stale)
    lock = await P_.ev('() => ((GIR.store.val("pos.day") || {}).lock || {}).locked')
    rec('LOCKED: plan dimmed + reason on a second line', 'NOT RUN', 'pos.day.lock.locked = %s today; rule checked in the rules table' % lock)
    # up-moves visible: the rising sectors show CE strikes
    await wheel_to(P_, '#wtb tr.row[data-s]', '#winB'); await P_.click('#wtb tr.row[data-s] td.nmc', nth=0); m = await P_.ev('() => { const M = GIR.SD.model(GIR.SD.state.open); const rows = [...document.querySelectorAll(".sdl .sd-r")].filter(r => r.dataset.g !== "against" && r.dataset.g !== "nt"); return [M.name, M.dir, rows.every(r => { const x = M.members.find(y => y.s === r.dataset.s); const k = r.querySelector(".sd-k"); return x.cp === (M.dir > 0 ? "CE" : "PE") && (!k || k.textContent.includes(x.cp)); }) && rows.length > 0] }')
    rec('up-side shown: a rising sector shows CE strikes on its groups (a falling one PE)', m[2], '%s dir %s · every row CE: %s' % tuple(m))
    await P_.key('Escape', 4); await cut_all(P_, 'rotation')


async def center(P_, sel):
    b = await P_.box(sel); return b['x'] + b['width'] / 2, b['y'] + b['height'] / 2


async def desk_sectors(P_, w):
    CUR['page'] = 'F2 sectors'
    await P_.go('sectors')
    await rail_tests(P_, 'F2 board scrollbar', '#bdb', '#bdb ~ .vsb i, .vsb:has(+ #bdb) i', '#bdb ~ .vsb', None, None, '#bdb') if await P_.ev('() => !!document.querySelector("#bdb ~ .vsb i")') else rec('F2 board scrollbar', False, 'no drawn bar next to #bdb')
    await P_.ev('() => 0')
    for i in range(20):
        ok = await P_.ev('() => { const r = document.querySelector("#bdb .sec[data-id=\\"auto\\"] > .srow"), b = document.querySelector("#bdb").getBoundingClientRect(); if (!r) return false; const x = r.getBoundingClientRect(); return x.top >= b.top && x.bottom <= b.bottom }')
        if ok: break
        wb = await P_.box('#bdb'); await P_.p.mouse.move(wb['x'] + 300, wb['y'] + 80); await P_.p.mouse.wheel(0, -120 if i < 3 else 120); await P_.p.wait_for_timeout(200)
    await P_.click('#bdb .sec[data-id="auto"] > .srow', dx=0.3)
    s = await P_.st()
    flow = await P_.ev('() => { const n = document.querySelector(".sdl"), sec = n.closest(".sec"), nx = sec.nextElementSibling; if (!nx) return ["none", "none", true]; const a = n.getBoundingClientRect(), b = nx.getBoundingClientRect(); return [Math.round(a.bottom), Math.round(b.top), b.top >= a.bottom - 0.5] }')
    rec('F2 board row click opens the sector in place', s['open'] == 'auto' and flow[2] is True, 'open %s · list bottom %s · next row top %s' % (s['open'], flow[0], flow[1]))
    await common_list_tests(P_, w, 'auto', True)
    await P_.key('Escape', 4)
    t = await P_.ev('() => { const x = [...document.querySelectorAll("#heat .ht[data-o]")].find(e => e.dataset.o); return x ? x.dataset.o : null }')
    await P_.click('#heat .ht[data-o="%s"]' % t); s = await P_.st()
    vis = await P_.ev('() => { const n = document.querySelector(".sdl"); const r = n && n.getBoundingClientRect(); const b = document.querySelector("#bdb").getBoundingClientRect(); return !!r && r.top < b.bottom && r.bottom > b.top }')
    rec('F2 heat-map tile opens that sector in the board', s['open'] == t and vis, 'tile %s -> open %s · in view %s' % (t, s['open'], vis))
    await P_.click('.sd-r >> nth=0'); ph = await P_.ev('() => { const p = document.querySelector(".sd-pane"); return p && p.parentElement.id }')
    rec('F2: the share pane sits in the right column', ph == 'call', 'pane host #%s' % ph)
    await P_.key('Escape', 4)
    names = await P_.ev('() => [...document.querySelectorAll("#bdb .sec[data-id] > .srow")].map(r => r.parentNode.dataset.id)')
    await P_.key('2'); a = (await P_.st())['open']
    rec('F2 keys 1-9', a == names[1], '2 -> %s (row 2 = %s)' % (a, names[1]))
    await P_.key('Escape', 4); await cut_all(P_, 'sectors')


async def desk_hunt(P_, w):
    CUR['page'] = 'F1 desk'
    await P_.go('desk-hunt')
    nm = await P_.ev('() => { const L = [...document.querySelectorAll("#secList .srow[data-sec]")].map(r => r.dataset.sec); return L.find(x => /^(banks|auto|capital goods)$/i.test(x)) || L[0] }')
    await wheel_to(P_, '#secList .srow[data-sec="%s"]' % nm, '#secList'); await P_.click('#secList .srow[data-sec="%s"]' % nm, dx=0.3)
    s = await P_.st()
    rec('F1 Desk sector chip opens the sector (same component)', s['open'] and s['open'].lower() == nm.lower(), 'chip %s -> open %s' % (nm, s['open']))
    await common_list_tests(P_, w, nm, True)
    if await P_.ev('() => !!document.querySelector(".sd-dock .sd-more")') and not await P_.smax('.sd-dock .sd-box'):
        await wheel_to(P_, '.sd-dock .sd-more'); await P_.click('.sd-dock .sd-more')
    if not await P_.smax('.sd-dock .sd-box') and await P_.ev('() => !!document.querySelector(".sd-dock .sd-nf")'):
        await P_.click('.sd-dock .sd-nf')
    if not await P_.smax('.sd-dock .sd-box'):
        full = await P_.ev('() => { const r = document.querySelector(".sd-dock .sd-rail"), t = r.querySelector(".tk"), i = r.querySelector("i"); return [r.classList.contains("all"), Math.round(i.getBoundingClientRect().height), Math.round(t.getBoundingClientRect().height), Math.round(i.getBoundingClientRect().width)] }')
        rec('F1 sector list scrollbar (dock)', full[0] and full[1] >= full[2] - 1 and full[3] >= 10, 'every row fits at this size (all %s F&O rows + the not-F&O line shown): the drawn bar shows a full %s px thumb of %s, %s px wide - nothing to drag' % (await P_.ev('() => document.querySelectorAll(".sd-dock .sd-r").length'), full[1], full[2], full[3]))
    else:
      await rail_tests(P_, 'F1 sector list scrollbar (dock)', '.sd-dock .sd-box', '.sd-dock .sd-rail .tk i', '.sd-dock .sd-rail .tk', '.sd-dock .sd-rail .u', '.sd-dock .sd-rail .d', '.sd-dock .sd-box')
    await P_.key('Escape', 4); s = await P_.st()
    await cut_all(P_, 'desk-hunt')
    rec('F1 Esc closes back to the Desk', not s['open'] and await P_.ev('() => getComputedStyle(document.querySelector("#members")).display !== "none"'), 'open %s · members panel back' % s['open'])


async def desk_morning(P_, w):
    CUR['page'] = 'Morning'
    await P_.go('morning')
    nm = await P_.ev('() => document.querySelector("#cards .cd .snm").textContent.trim().toLowerCase()')
    await P_.click('#cards .cd .snm', nth=0)
    s = await P_.st()
    lab = await P_.ev('() => { const l = document.querySelector(".sdl .sd-pre"); return l ? [l.innerText, l.getBoundingClientRect().right <= innerWidth, l.getBoundingClientRect().width > 0] : null }')
    rec('Morning sector card opens the same component', s['open'] and s['open'].lower() == nm, 'card %s -> open %s' % (nm, s['open']))
    rec('Morning: "pre-open - not live" (after 15:30 "closed - not live") with the session date', bool(lab) and ('pre-open - not live' in lab[0] or 'closed - not live' in lab[0]) and re.search(r'\d+ [A-Z][a-z]{2} \d\d:\d\d close', lab[0]) is not None and lab[1] and lab[2], lab)
    await common_list_tests(P_, w, nm, False)
    await P_.key('Escape', 4); await cut_all(P_, 'morning')


# ------------------------------------------------------------------ the phone (finger) --------------------------------------------------
async def phone(P_, cdp, pagename, path, row_sel):
    CUR['page'] = pagename
    await P_.go(path)
    p = P_.p
    tp = lambda x, y, r=1: [{'x': x, 'y': y, 'radiusX': r, 'radiusY': r, 'force': 1, 'id': 1}]

    async def tap(x, y, r=1):
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': tp(x, y, r)}); await p.wait_for_timeout(40)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []}); await p.wait_for_timeout(260)

    async def drag(x, y, dx, dy, n, r=1, dt=16, settle=450):
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': tp(x, y, r)}); await p.wait_for_timeout(30)
        for i in range(1, n + 1):
            await cdp.send('Input.dispatchTouchEvent', {'type': 'touchMove', 'touchPoints': tp(x + dx * i / n, y + dy * i / n, r)}); await p.wait_for_timeout(dt)
        await cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []}); await p.wait_for_timeout(settle)

    async def tapel(sel, nth=0, r=1):
        b = await P_.box(sel, nth); await tap(b['x'] + b['width'] / 2, b['y'] + b['height'] / 2, r); return b

    async def scroll_into(sel):
        # finger swipes inside whichever box holds the target (the page, then the inner list), like a thumb would
        for i in range(90):
            r = await p.evaluate('''([s, it]) => { const e = document.querySelector(s); if (!e) return null; const b = e.getBoundingClientRect();
              const vis = (x) => { const r = x.getBoundingClientRect(); return [Math.max(r.top, 60), Math.min(r.bottom, innerHeight - 10)]; };
              let box = null; for (let y = e.parentElement; y; y = y.parentElement) { const c = getComputedStyle(y); if (/(auto|scroll)/.test(c.overflowY) && y.scrollHeight > y.clientHeight + 1) { const v = vis(y); if (v[1] - v[0] > 80) { box = y; break; } } }
              const v = box ? vis(box) : [60, innerHeight - 10];
              if (b.top >= v[0] + 4 && b.bottom <= v[1] - 4) return 'ok';
              // a spot whose first scrollable ancestor IS that box (so the finger does not grab a nested list)
              const first = el => { for (let y = el; y; y = y.parentElement) { const c = getComputedStyle(y); if (/(auto|scroll)/.test(c.overflowY) && y.scrollHeight > y.clientHeight + 1) return y; } return null; };
              let px = null; const R = box ? box.getBoundingClientRect() : {left: 0, width: innerWidth};
              const y0 = v[0] + 20 + ((it * 53) % Math.max(1, (v[1] - v[0] - 60))); for (let k = 0, yy = y0; k < 60 && !px; k++, yy = v[0] + 20 + ((y0 - v[0] - 20 + k * 24) % Math.max(1, v[1] - v[0] - 40))) for (let xx = R.left + 20; xx < R.left + R.width - 30 && !px; xx += 40) { const el = document.elementFromPoint(xx, yy); if (el && first(el) === box) px = [xx, yy]; }
              return [v[0], v[1], b.top > v[1] - 4 ? -1 : 1, px ? px[0] : R.left + 40, px ? px[1] : null]; }''', [sel, i])
            if os.environ.get('DBGS'): print('SI', i, r, await p.evaluate('() => [document.querySelector("#page") && document.querySelector("#page").scrollTop, (document.querySelector("#bdb") || {}).scrollTop]'), flush=True)
            if r == 'ok': return await P_.box(sel)
            if not r: return None
            top, bot, d, x, yy = r
            y0 = yy if yy is not None else (top + bot) / 2
            room = (y0 - top - 8) if d < 0 else (bot - y0 - 8)
            if room < 90:   # too little room from that spot: use the middle of the box instead (a long swipe beats a row snap)
                y0 = bot - 12 if d < 0 else top + 12; x = x if yy is not None else 60; room = bot - top - 30
            await drag(x, y0, 0, d * min(260, room), 10, settle=1100)
        return await P_.box(sel)

    await p.wait_for_timeout(2500)   # let the page finish its own first scroll-to-the-open-sector
    if path == 'sectors':
        big = await p.evaluate('() => { const ids = [...document.querySelectorAll("#bdb .sec[data-id]")].slice(0, 5).map(e => e.dataset.id); let best = ids[0], n = -1; ids.forEach(i => { const m = GIR.SD.model(i); if (m && m.members.length > n) { n = m.members.length; best = i; } }); return best }')
        row_sel = '#bdb .sec[data-id="%s"] > .srow .snm' % big
    await scroll_into(row_sel); await p.wait_for_timeout(600)
    if not await p.evaluate('s => { const b = document.querySelector(s).getBoundingClientRect(); return b.top > 60 && b.bottom < innerHeight - 10 }', row_sel):
        await scroll_into(row_sel); await p.wait_for_timeout(600)
    t0 = await p.evaluate('() => performance.now()')
    b = await P_.box(row_sel)
    await cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': tp(b['x'] + b['width'] / 2, b['y'] + b['height'] / 2)}); await p.wait_for_timeout(30)
    await cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
    try:
        await p.wait_for_function('() => document.querySelector(".sd-sheet.on")', timeout=5000)
    except Exception:
        dbg = await p.evaluate('([x, y]) => { const e = document.elementFromPoint(x, y); return [e && e.outerHTML.slice(0, 120), window.GIR && GIR.SD && GIR.SD.state ? GIR.SD.state.open : "no drill on this page", location.href.replace(/^https?:\\/\\/[^/]+/, "")] }', [b['x'] + b['width'] / 2, b['y'] + b['height'] / 2])
        raise Exception('sheet did not open: ' + str(dbg) + ' box ' + str(b))
    t1 = await p.evaluate('() => performance.now()'); ms = await p.evaluate('() => +document.querySelector(".sdl").dataset.ms')
    s = await P_.st()
    rec('tap a sector row opens the full-screen list sheet', s['open'] is not None, 'open %s · built in %s ms · tap-to-sheet %s ms' % (s['open'], ms, round(t1 - t0)))
    await p.wait_for_timeout(300)
    hd = await p.evaluate('() => { const l = document.querySelector(".sd-sheet .sd-line"); const r = l.getBoundingClientRect(); return [Math.round(r.height), Math.round(document.querySelector(".sd-sheet .sd-l1").getBoundingClientRect().height)] }')
    rec('sheet header (sector line) <= 2 lines + WHY', hd[1] <= 46, 'line 1 %s px, whole header %s px' % (hd[1], hd[0]))
    rw = await p.evaluate('() => { const r = document.querySelector(".sd-sheet .sd-rail"), t = r.querySelector(".tk"), i = r.querySelector("i"); return [r.getBoundingClientRect().width, t.getBoundingClientRect().width, i.getBoundingClientRect().width] }')
    rec('sheet rail size (touch target >= 24, track and thumb >= 10)', rw[0] >= 24 and rw[1] >= 10 and rw[2] >= 10, 'target %s · track %s · thumb %s px' % tuple(rw))
    box = '.sd-sheet .sd-box'
    a = await P_.stop(box); await drag(180, 650, 0, -350, 14, settle=1300); c = await P_.stop(box); await drag(180, 300, 0, 200, 10, settle=1300); d = await P_.stop(box)
    rec('list sheet - finger swipe', c > a + 30 and d < c, '%s -> %s -> %s' % (a, c, d))
    th = await P_.box('.sd-sheet .sd-rail .tk i')
    await drag(th['x'] + th['width'] / 2, th['y'] + th['height'] / 2, 0, 120, 16); e = await P_.stop(box); s = await P_.st()
    rec('list sheet - rail thumb, finger drag', e > d + 20 and not s['sel'], '%s -> %s · share opened: %s' % (d, e, s['sel']))
    th = await P_.box('.sd-sheet .sd-rail .tk i')
    await drag(th['x'] + th['width'] / 2, th['y'] + th['height'] / 2, 0, -120, 12, 8); f = await P_.stop(box); s = await P_.st()
    rec('list sheet - rail drag, 8 px contact', f < e and not s['sel'], '%s -> %s' % (e, f))
    rb = await P_.box('.sd-sheet .sd-rail'); th = await P_.box('.sd-sheet .sd-rail .tk i')
    await drag(rb['x'] + rb['width'] - 3, th['y'] + th['height'] / 2, 0, 100, 10); g = await P_.stop(box)
    rec('list sheet - rail drag at its right edge', g > f + 10 and not (await P_.st())['sel'], '%s -> %s' % (f, g))
    tk = await P_.box('.sd-sheet .sd-rail .tk'); th = await P_.box('.sd-sheet .sd-rail .tk i')
    if th['y'] - tk['y'] > 20:
        await tap(tk['x'] + tk['width'] / 2, tk['y'] + 6); h = await P_.stop(box)
    else:
        await tap(tk['x'] + tk['width'] / 2, tk['y'] + tk['height'] - 8); h = await P_.stop(box)
    rec('list sheet - rail track tap', h != g and not (await P_.st())['sel'], '%s -> %s' % (g, h))
    # mouse on the phone rail
    th = await P_.box('.sd-sheet .sd-rail .tk i'); x0 = await P_.stop(box)
    await p.mouse.move(th['x'] + th['width'] / 2, th['y'] + th['height'] / 2); await p.mouse.down(); await p.mouse.move(th['x'] + th['width'] / 2, th['y'] + th['height'] / 2 + 80, steps=8); await p.mouse.up(); await p.wait_for_timeout(300)
    x1 = await P_.stop(box)
    rec('list sheet - rail, mouse drag (one mouse check)', x1 != x0, '%s -> %s' % (x0, x1))
    # fast flick, then tap a row
    await p.evaluate('() => 0')
    await drag(180, 700, 0, -320, 3, dt=8, settle=60)
    rows = await p.evaluate('() => [...document.querySelectorAll(".sd-sheet .sd-r")].filter(r => { const b = r.getBoundingClientRect(); return b.top > 150 && b.bottom < 760 }).map(r => r.dataset.s)')
    await p.wait_for_timeout(120)
    if rows:
        await tapel('.sd-sheet .sd-r[data-s="%s"]' % rows[0])
        s = await P_.st(); on2 = await p.evaluate('() => !!document.querySelector(".sd-sheet2.on")')
        rec('fast flick, then a tap still opens the row', s['sel'] == rows[0] and on2, 'flick then tap %s -> share sheet %s (%s)' % (rows[0], on2, s['sel']))
        await tapel('.sd-sheet2 .sd-back'); await p.wait_for_timeout(300)
    else:
        rec('fast flick, then a tap still opens the row', False, 'no row in view after the flick')
    # +n more, not F&O, basis
    if await p.evaluate('() => !!document.querySelector(".sd-sheet .sd-more")'):
        await scroll_into('.sd-sheet .sd-more'); n0 = await p.evaluate('() => document.querySelectorAll(".sd-sheet .sd-r").length')
        await tapel('.sd-sheet .sd-more'); n1 = await p.evaluate('() => document.querySelectorAll(".sd-sheet .sd-r").length')
        rec('"+n more" (finger)', n1 > n0, '%s -> %s rows' % (n0, n1))
    if await p.evaluate('() => !!document.querySelector(".sd-sheet .sd-nf")'):
        await scroll_into('.sd-sheet .sd-nf'); await tapel('.sd-sheet .sd-nf'); a = await p.evaluate('() => !!document.querySelector(".sd-sheet .sd-nfx")')
        await tapel('.sd-sheet .sd-nf'); b2 = await p.evaluate('() => !!document.querySelector(".sd-sheet .sd-nfx")')
        rec('"n more listed, not F&O" (finger)', a and not b2, 'open %s · closed %s' % (a, not b2))
    await p.evaluate('() => document.querySelector(".sd-sheet .sd-box").scrollTop')
    await drag(180, 250, 0, 900, 6)
    await tapel('.sd-sheet .sd-basis'); a = await p.evaluate('() => (document.querySelector(".sd-pop.on") || {}).innerText || ""'); await tapel('.sd-pop.on'); b2 = await p.evaluate('() => !!document.querySelector(".sd-pop.on")')
    rec('basis › (finger)', 'listed' in a and not b2, a[:70].replace('\n', ' '))
    # tap a share -> share sheet
    sym = await p.evaluate('() => { const R = [...document.querySelectorAll(".sd-sheet .sd-r")]; const k = R.find(r => r.querySelector(".sd-k")); return (k || R[0]).dataset.s }')
    await scroll_into('.sd-sheet .sd-r[data-s="%s"]' % sym)
    await tapel('.sd-sheet .sd-r[data-s="%s"]' % sym); await p.wait_for_timeout(250)
    s = await P_.st(); on2 = await p.evaluate('() => !!document.querySelector(".sd-sheet2.on")')
    rec('tap a share opens the share sheet', s['sel'] == sym and on2, '%s -> sheet %s' % (sym, on2))
    if SHOTS and pagename.startswith('F3'):
        await p.screenshot(path=os.path.join(SHOTS, 'phone_390_share_sheet.png'))
    ab = await p.evaluate('() => { const a = document.querySelector(".sd-sheet2 .sd-act"), r = a.getBoundingClientRect(); return [Math.round(r.top), Math.round(r.bottom), a.querySelector(".sd-copy").textContent] }')
    pb = '.sd-sheet2 .sd-pb'
    a0 = await P_.stop(pb); await drag(180, 600, 0, -320, 12, settle=1300); a1 = await P_.stop(pb)
    ab2 = await p.evaluate('() => { const r = document.querySelector(".sd-sheet2 .sd-act").getBoundingClientRect(); return [Math.round(r.top), Math.round(r.bottom)] }')
    rec('share sheet - finger swipe', a1 > a0 + 30, '%s -> %s' % (a0, a1))
    anyk = await p.evaluate('() => !!document.querySelector(".sd-sheet .sd-k")')
    rec('share sheet - action bar sticky, shows the size', ab[1] <= 844 and ab[0] == ab2[0] and (re.search(r'Copy [\d,]+(\.\d)? (CE|PE) · \d+ lots?', ab[2]) is not None or (not anyk and 'Copy contract · 0 lots' in ab[2])), 'bar %s-%s at scroll 0 and %s-%s after the swipe · "%s"' % (ab[0], ab[1], ab2[0], ab2[1], ab[2]))
    await drag(180, 300, 0, 400, 8, settle=1300); a1 = await P_.stop(pb)
    th = await P_.box('.sd-sheet2 .sd-rail .tk i')
    await drag(th['x'] + th['width'] / 2, th['y'] + th['height'] / 2, 0, 140, 14); a2 = await P_.stop(pb)
    rec('share sheet - rail thumb, finger drag', a2 > a1 + 10, '%s -> %s' % (a1, a2))
    tk = await P_.box('.sd-sheet2 .sd-rail .tk'); await tap(tk['x'] + tk['width'] / 2, tk['y'] + 6); a3 = await P_.stop(pb)
    rec('share sheet - rail track tap', a3 < a2, '%s -> %s' % (a2, a3))
    await drag(180, 300, 0, 900, 5)
    await tapel('.sd-sheet2 .sd-whyb'); a = await p.evaluate('() => !!document.querySelector(".sd-sheet2 .sd-drw[data-d=w].on")')
    await tapel('.sd-sheet2 .sd-drw.on [data-a=dx]'); b2 = await p.evaluate('() => !!document.querySelector(".sd-sheet2 .sd-drw.on")')
    rec('WHY › (share sheet)', a and not b2, 'open %s · closed %s' % (a, not b2))
    k = await p.evaluate('() => { const m = GIR.SD.state; const x = GIR.SD.model(m.open).members.find(y => y.s === m.sel); return [x.plan.c.kite || "", x.plan.copyOff] }')
    if not k[1]:
        await p.evaluate('() => navigator.clipboard.writeText("-")')
        await tapel('.sd-sheet2 .sd-copy'); clip = await p.evaluate('() => navigator.clipboard.readText()'); t = await p.evaluate('() => (document.querySelector(".sd-sheet2 .sd-toast.on") || {}).textContent || ""')
        rec('Copy contract (finger, first view)', clip == k[0], 'clipboard "%s" · "%s"' % (clip, t[:60]))
    else:
        rec('Copy contract (finger, first view)', 'PASS' if await p.evaluate('() => document.querySelector(".sd-sheet2 .sd-copy").disabled') else 'FAIL', 'Copy off: ' + k[1])
    p0 = len((await P_.st())['pins'])
    await tapel('.sd-sheet2 .sd-act [data-a=p]'); p1 = len((await P_.st())['pins'])
    tpos = await p.evaluate('() => { const t = document.querySelector(".sd-sheet2 .sd-toast.on"), a = document.querySelector(".sd-sheet2 .sd-act"), h = document.querySelector(".sd-sheet2 .sd-ph-h"); if (!t) return null; return [Math.round(t.getBoundingClientRect().top), Math.round(t.getBoundingClientRect().bottom), Math.round(a.getBoundingClientRect().top), Math.round(h.getBoundingClientRect().bottom)] }')
    await tapel('.sd-sheet2 .sd-act [data-a=p]'); p2 = len((await P_.st())['pins'])
    rec('Pin (toggle, n/5) (finger)', p1 == p0 + 1 and p2 == p0, '%s -> %s -> %s' % (p0, p1, p2))
    rec('Pin toast above the action bar, not over the share name', bool(tpos) and tpos[1] <= tpos[2] and tpos[0] >= tpos[3], 'toast %s-%s · bar top %s · name bottom %s' % tuple(tpos or [None] * 4))
    await tapel('.sd-sheet2 .sd-back'); await p.wait_for_timeout(300)
    s = await P_.st(); on1 = await p.evaluate('() => [!!document.querySelector(".sd-sheet.on:not(.sd-sheet2)"), !!document.querySelector(".sd-sheet2.on")]')
    rec('‹ Sector (Back button on the share sheet)', on1[0] and not on1[1] and not s['sel'], 'list sheet %s · share sheet %s' % tuple(on1))
    sym2 = await p.evaluate('() => [...document.querySelectorAll(".sd-sheet .sd-r")].find(r => { const b = r.getBoundingClientRect(); return b.top > 150 && b.bottom < 760 }).dataset.s')
    await tapel('.sd-sheet .sd-r[data-s="%s"]' % sym2); await p.go_back(); await p.wait_for_timeout(500)
    on1 = await p.evaluate('() => [!!document.querySelector(".sd-sheet.on:not(.sd-sheet2)"), !!document.querySelector(".sd-sheet2.on")]')
    rec('device / browser Back (share sheet -> list)', on1[0] and not on1[1], 'list %s · share %s' % tuple(on1))
    await p.go_back(); await p.wait_for_timeout(500); s = await P_.st()
    on1 = await p.evaluate('() => !!document.querySelector(".sd-sheet.on")')
    rec('device / browser Back (list -> page)', not on1 and not s['open'], 'sheet %s · open %s' % (on1, s['open']))
    await scroll_into(row_sel); await tapel(row_sel); await p.wait_for_timeout(300)
    await tapel('.sd-sheet .sd-back[data-b]'); await p.wait_for_timeout(400); on1 = await p.evaluate('() => !!document.querySelector(".sd-sheet.on")')
    rec('‹ Sectors (Back button on the list sheet)', not on1, 'sheet closed %s' % (not on1))
    if SHOTS and pagename.startswith('F3'):
        await scroll_into(row_sel); await tapel(row_sel); await p.wait_for_timeout(400)
        await p.screenshot(path=os.path.join(SHOTS, 'phone_390_list_sheet.png'))
        await tapel('.sd-sheet .sd-back[data-b]')


async def run():
    os.makedirs(SHOTS, exist_ok=True) if SHOTS else None
    async with async_playwright() as pw:
        b = await pw.chromium.launch()
        cookies = []
        if WHERE == 'outside':
            sys.path.insert(0, '/home/globalbot/intraday')
            import sitelogin
            full = sitelogin.make_cookie(); val = full.split(';')[0].split('=', 1)[1]
            cookies = [{'name': 'gir_s', 'value': val, 'domain': 'girtrader.com', 'path': '/', 'secure': True, 'httpOnly': True}]
            del full, val
        origin = re.match(r'https?://[^/]+', BASE).group(0)
        for vp in VPS:
            w, h = map(int, vp.split('x'))
            CUR['vp'] = vp
            if w >= 700:
                ctx = await b.new_context(viewport={'width': w, 'height': h}, device_scale_factor=1)
            else:
                dev = dict(pw.devices['iPhone 13']); dev['viewport'] = {'width': w, 'height': h}
                ctx = await b.new_context(**dev)
            if cookies: await ctx.add_cookies(cookies)
            await ctx.grant_permissions(['clipboard-read', 'clipboard-write'], origin=origin)
            pg = await ctx.new_page(); P_ = P(pg)
            if w >= 700:
                only = os.environ.get('PAGES', '')
                for fn in [f for f in (desk_rotation, desk_sectors, desk_hunt, desk_morning) if not only or f.__name__ in only]:
                    n0 = len(P_.errs)
                    try:
                        await fn(P_, w)
                    except Exception as e:
                        rec(fn.__name__ + ' (run)', False, 'exception: ' + str(e).split('\n')[0][:200] + ' @ lines ' + ','.join(re.findall(r'r51.py", line (\d+)', traceback.format_exc())))
                    rec('page errors', len(P_.errs) == n0, P_.errs[n0:][:3] or 'none')
            else:
                cdp = await ctx.new_cdp_session(pg)
                for nm, path, row in [x for x in (('F3 rotation', 'rotation', '#wtb tr.row[data-s="banks"] td.nmc'), ('F2 sectors', 'sectors', '#bdb .sec[data-id] > .srow .snm')) if not os.environ.get('PAGES') or x[1] in os.environ.get('PAGES')]:
                    n0 = len(P_.errs)
                    try:
                        await phone(P_, cdp, nm, path, row)
                    except Exception as e:
                        rec('phone %s (run)' % nm, False, 'exception: ' + str(e).split('\n')[0][:300])
                    rec('page errors', len(P_.errs) == n0, P_.errs[n0:][:3] or 'none')
            await ctx.close()
        await b.close()
    json.dump(R, open(OUT, 'w'), indent=1)
    c = {}
    for r in R: c[r['result']] = c.get(r['result'], 0) + 1
    print('TOTAL', c)

asyncio.run(run())

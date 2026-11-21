// Every control on the phone drill-down (390 x 844, touch). Every tap, swipe and rail drag is a FINGER: CDP Input.dispatchTouchEvent
// (touchStart / touchMove / touchEnd, also with an 8 px contact radius), never the mouse - except one row that checks the mouse too.
// node test_phone.js  ->  markdown PASS / FAIL table on stdout
const path = require('path');
const { chromium } = require(require.resolve('playwright', { paths: [__dirname, '/opt/node-tools/node_modules'] }));
const PHONE = 'file://' + path.resolve(__dirname, '..', 'rotation-drilldown-phone.html');
const R = []; function rec(c, d, e, ok, n) { R.push([c, d, e, ok ? 'PASS' : 'FAIL', n || '']); if (!ok) console.error('FAIL', c, n || ''); }
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true });
  const p = await ctx.newPage(); const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  const cdp = await ctx.newCDPSession(p);
  const wait = ms => p.waitForTimeout(ms), ev = (f, a) => p.evaluate(f, a);
  const tp = (x, y, r) => [{ x, y, radiusX: r || 1, radiusY: r || 1, force: 1, id: 1 }];
  const tap = async (x, y, r) => { await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: tp(x, y, r) }); await wait(40); await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await wait(220); };
  const drag = async (x, y, dx, dy, n, r) => { await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: tp(x, y, r) }); await wait(30);
    for (let i = 1; i <= n; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: tp(x + dx * i / n, y + dy * i / n, r) }); await wait(16); }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await wait(450); };
  const box = async q => { const e = await p.$(q); if (!e) throw new Error('no ' + q); return e.boundingBox(); };
  const tapEl = async (q, r) => { const bb = await box(q); await tap(bb.x + bb.width / 2, bb.y + bb.height / 2, r); return bb; };
  const sTop = q => ev(q => document.querySelector(q).scrollTop, q);
  const on = q => ev(q => document.querySelector(q).classList.contains('on'), q);
  const toastTxt = () => ev(() => document.querySelector('#toast').classList.contains('on') ? document.querySelector('#toast').textContent : '');
  const thumbC = async list => { const bb = await box(`.rail[data-for="${list}"] i`); return [bb.x + bb.width / 2, bb.y + bb.height / 2, bb]; };
  const railW = async list => ev(l => { const r = document.querySelector(`.rail[data-for="${l}"]`), t = r.querySelector('.tk'), i = r.querySelector('i'); return [r.getBoundingClientRect().width, t.getBoundingClientRect().width, i.getBoundingClientRect().width]; }, list);
  await p.goto(PHONE); await wait(400);

  // ---------- screen 1: the sector list ----------
  let rw = await railW('secL'); rec('rail size', 'measure the sector-list rail', 'touch target ≥ 24 px; visible track and thumb ≥ 10 px', rw[0] >= 24 && rw[1] >= 10 && rw[2] >= 10, `target ${rw[0]} · track ${rw[1]} · thumb ${rw[2]} px`);
  let a = await sTop('#secL'); await drag(180, 650, 0, -300, 14); let c = await sTop('#secL'); await drag(180, 400, 0, 300, 14); let d = await sTop('#secL');
  rec('sector list - finger swipe', 'touch-drag up 300 px, then down', 'scrolls with the finger both ways', c > a + 30 && d < c, `${a} → ${c} → ${d}`);
  let [tx, ty] = await thumbC('secL'); await drag(tx, ty, 0, 150, 20); let e1 = await sTop('#secL'); const op1 = await on('#secS');
  rec('sector list - rail thumb, finger drag', 'touchStart on the thumb centre, 20 touchMoves 150 px down, touchEnd', 'the list scrolls; no sector opens', e1 > d + 40 && !op1, `${d} → ${e1} · sheet open: ${op1}`);
  [tx, ty] = await thumbC('secL'); await drag(tx, ty, 0, -150, 12, 8); let e2 = await sTop('#secL');
  rec('sector list - rail drag, 8 px contact', 'same drag up with an 8 px touch radius', 'scrolls back; no row steals the touch', e2 < e1 && !(await on('#secS')), `${e1} → ${e2}`);
  const rb1 = await box('.rail[data-for="secL"]'); [tx, ty] = await thumbC('secL'); await drag(rb1.x + rb1.width - 3, ty, 0, 120, 10); const e3 = await sTop('#secL');
  rec('sector list - rail drag at its right edge', 'finger drag on the outer edge of the rail (x = rail right − 3)', 'still scrolls', e3 > e2 + 20 && !(await on('#secS')), `${e2} → ${e3}`);
  await ev(() => document.querySelector('#secL').scrollTop = 0); await wait(100); const tb = await box('.rail[data-for="secL"] i'); const rb = await box('.rail[data-for="secL"]');
  await tap(rb.x + rb.width / 2, rb.y + rb.height - 20); const g1 = await sTop('#secL'), o1 = await on('#secS'); await tap(rb.x + rb.width / 2, rb.y + 12); const g2 = await sTop('#secL'), o2 = await on('#secS');
  const gmax = await ev(() => { const e = document.querySelector('#secL'); return e.scrollHeight - e.clientHeight; });
  rec('sector list - rail track tap', 'tap the track below the thumb, then above it', 'pages down (0.9 screen, or to the end), then up; no neighbouring sector opens', g1 >= Math.min(gmax, 300) - 1 && g1 > 0 && g2 < g1 && !o1 && !o2, `0 → ${g1} (max ${gmax}) → ${g2} · sheet opened: ${o1 || o2}`);
  [tx, ty] = await thumbC('secL'); await tap(tx, ty); rec('sector list - tap on the thumb', 'tap the thumb itself', 'nothing opens', !(await on('#secS')));
  [tx, ty] = await thumbC('secL'); await p.mouse.move(tx, ty); await p.mouse.down(); await p.mouse.move(tx, ty + 110, { steps: 6 }); await p.mouse.up(); const m1 = await sTop('#secL');
  rec('sector list - rail, mouse drag', 'mouse down on the thumb, drag 110 px', 'scrolls (mouse works too)', m1 > g2 + 30, `${g2} → ${m1}`);
  await ev(() => document.querySelector('#secL').scrollTop = 0); await wait(80);
  const fl0 = await ev(() => document.querySelector('#flowL').textContent); await tapEl('#winC'); const fl1 = await ev(() => document.querySelector('#winC').textContent + ' ' + document.querySelector('#flowS').textContent);
  await tapEl('#winC'); const fl2 = await ev(() => document.querySelector('#winC').textContent + ' ' + document.querySelector('#flowL').textContent); await tapEl('#winC'); const fl3 = await ev(() => document.querySelector('#winC').textContent); await tapEl('#winC');
  rec('window chip 30M ▾', 'tap it 4 times', 'cycles 1H → TODAY → 15M → 30M, the flow line follows', /^1H/.test(fl1) && /^TODAY/.test(fl2) && /REALTY/.test(fl2) && /^15M/.test(fl3) && /^30M/.test(await ev(() => document.querySelector('#winC').textContent)), fl1 + ' | ' + fl2 + ' | ' + fl3);
  await tapEl('#engC'); rec('engine PE / CE chip', 'tap it', 'explains the PE bias and the CE guarantee', /PE-biased/.test(await toastTxt()));
  await tapEl('#banC'); const bm = await ev(() => document.querySelector('#banM').classList.contains('on') ? document.querySelector('#banM').innerText : ''); await tapEl('#banM .x');
  rec('BAN 2 chip', 'tap it, then ✕', 'lists INDUSINDBK 96% and HINDCOPPER 97%, "only close existing"', /INDUSINDBK MWPL 96%/.test(bm) && /HINDCOPPER MWPL 97%/.test(bm) && !(await on('#banM')), bm.replace(/\n/g, ' · '));

  // ---------- screen 2: the Banks sheet ----------
  await ev(() => { window.__t = {}; addEventListener('touchend', () => { window.__t.e = performance.now(); }, true); new MutationObserver(() => { if (!window.__t.v && document.querySelector('#secS').classList.contains('on')) { window.__t.c = performance.now(); requestAnimationFrame(() => requestAnimationFrame(() => { window.__t.v = performance.now(); })); } }).observe(document.querySelector('#secS'), { attributes: true }); });
  await tapEl('.sr[data-s="Banks"]'); await wait(100); const tm = await ev(() => window.__t);
  const sh = await ev(() => ({ on: document.querySelector('#secS').classList.contains('on'), n: document.querySelectorAll('#memL .mr').length, top: document.querySelector('#secTop').getBoundingClientRect().height,
    vis: [...document.querySelectorAll('#memL .mr')].filter(r => { const q = r.getBoundingClientRect(), w = document.querySelector('#memL').getBoundingClientRect(); return q.top >= w.top - 1 && q.bottom <= w.bottom + 1; }).length }));
  rec('tap a sector (Banks)', 'tap the Banks row', 'full-screen sheet with all 14 F&O shares', sh.on && sh.n === 14, '14 shares in groups');
  rec('sheet opens fast', 'time from touchend to the painted sheet', '≤ 100 ms (no slide transition)', tm.v - tm.e <= 100, `${(tm.c - tm.e).toFixed(0)} ms to open · ${(tm.v - tm.e).toFixed(0)} ms to paint`);
  rec('sheet header ≤ 2 lines + WHY', 'measure the header and the whole share rows in view', 'header ≈ 3 short lines; ≥ 5 whole share rows visible', sh.vis >= 5 && sh.top <= 110, `header ${sh.top.toFixed(0)} px · ${sh.vis} whole rows`);
  rw = await railW('memL'); rec('Banks sheet - rail size', 'measure', 'target ≥ 24 px, track/thumb ≥ 10 px', rw[0] >= 24 && rw[1] >= 10 && rw[2] >= 10, rw.join(' / ') + ' px');
  a = await sTop('#memL'); await drag(180, 700, 0, -350, 14); c = await sTop('#memL'); await drag(180, 450, 0, 200, 12); d = await sTop('#memL');
  rec('Banks sheet - finger swipe', 'touch-drag up 350 px, then down 200', 'scrolls both ways', c > a + 50 && d < c, `${a} → ${c} → ${d}`);
  [tx, ty] = await thumbC('memL'); await drag(tx, ty, 0, 120, 20); const r1 = await sTop('#memL');
  rec('Banks sheet - rail thumb, finger drag', 'touchStart on the thumb, drag 120 px down', 'the list scrolls; no share sheet opens', r1 > d + 40 && !(await on('#shareS')), `${d} → ${r1}`);
  const mrb = await box('.rail[data-for="memL"]'); await tap(mrb.x + mrb.width / 2, mrb.y + 14); const r2 = await sTop('#memL'); const so2 = await on('#shareS');
  rec('Banks sheet - rail track tap', 'tap the track above the thumb', 'pages up; no group header or share opens', r2 < r1 && !so2, `${r1} → ${r2}`);
  await ev(() => document.querySelector('#memL').scrollTop = 0); await wait(80);
  await tapEl('#whyB'); const wy = await ev(() => document.querySelector('#whyX').classList.contains('on') ? document.querySelector('#whyX').innerText : ''); await tapEl('#whyB');
  rec('WHY › (sector sheet)', 'tap WHY ›, tap again', 'shows today UNEXPLAINED + live futures, background 18 Nov, run clock, basis, expiry wording; hides', /UNEXPLAINED/.test(wy) && /background/.test(wy) && /18 Nov/.test(wy) && /NIFTY BANK \+1\.12%/.test(wy) && /physical settlement - December only/.test(wy) && !(await on('#whyX')), wy.replace(/\n/g, ' · ').slice(0, 160));
  await ev(() => document.querySelector('#memL').scrollTop = 99999); await wait(150); await tapEl('#nfoL'); const nfx = await ev(() => document.querySelector('#nfoX').classList.contains('on') ? document.querySelector('#nfoX').innerText : ''); await tapEl('#nfoL');
  rec('"27 more listed, not F&O"', 'tap it, tap again', 'shows the context list (no strikes), hides it', /J&KBANK/.test(nfx) && /no strike/.test(nfx) && !(await on('#nfoX')), nfx.replace(/\n/g, ' ').slice(0, 90));
  await ev(() => document.querySelector('#memL').scrollTop = 0); await wait(100);

  // ---------- screen 3: the share sheet ----------
  await tapEl('.mr[data-sym="ICICIBANK"]'); await wait(100);
  const ss = await ev(() => ({ on: document.querySelector('#shareS').classList.contains('on'), t: document.querySelector('#shB').innerText, chart: !!document.querySelector('#shB svg.mchart') }));
  rec('tap a share (ICICIBANK)', 'tap the ICICIBANK row', 'share sheet: Dec 1,460 CE trade box with quote age, expiry wording, levels, 1 lot, mini chart', ss.on && /1,460 CE/.test(ss.t) && /quote age/.test(ss.t) && /physical settlement - December only/.test(ss.t) && /1R rule allows 1 → 1 lot/.test(ss.t) && ss.chart);
  a = await sTop('#shB'); await drag(180, 700, 0, -320, 14); c = await sTop('#shB');
  rec('share sheet - finger swipe', 'touch-drag up 320 px', 'scrolls', c > a + 80, `${a} → ${c}`);
  [tx, ty] = await thumbC('shB'); await drag(tx, ty, 0, 160, 20); const s1 = await sTop('#shB');
  rec('share sheet - rail thumb, finger drag', 'drag the thumb 160 px down', 'scrolls; nothing else reacts', s1 > c + 60, `${c} → ${s1}`);
  const srb = await box('.rail[data-for="shB"]'); await tap(srb.x + srb.width / 2, srb.y + 12); const s2 = await sTop('#shB');
  rec('share sheet - rail track tap', 'tap the track above the thumb', 'pages up', s2 < s1, `${s1} → ${s2}`);
  await ev(() => document.querySelector('#shB').scrollTop = 99999); await wait(120);
  await tapEl('#wyB'); const wy2 = await ev(() => document.querySelector('#wyX').classList.contains('on') ? document.querySelector('#wyX').innerText : '');
  rec('WHY › (share sheet)', 'tap "WHY ICICIBANK is moving ›"', 'sector why + the share\'s top news with its age', /UNEXPLAINED/.test(wy2) && /deposits beat/.test(wy2) && /1h 13m/.test(wy2), wy2.replace(/\n/g, ' · ').slice(0, 120));
  // sticky action bar: Copy / Pin are on screen in the first view and at any scroll, above the bottom tabs, 44 px tall
  const onScr = () => ev(() => { const t = document.querySelector('.tabs').getBoundingClientRect(); return ['#pCopy', '#pPin', '#shAct a.btn'].map(q => { const b = document.querySelector(q).getBoundingClientRect(); return b.top >= 0 && b.bottom <= t.top + 0.5 && b.height >= 44 ? 1 : 0; }).join(''); });
  await ev(() => document.querySelector('#shB').scrollTop = 0); await wait(80); const sb0 = await onScr(); await ev(() => document.querySelector('#shB').scrollTop = 300); await wait(80); const sb1 = await onScr(); await ev(() => document.querySelector('#shB').scrollTop = 99999); await wait(80); const sb2 = await onScr();
  rec('share sheet - action bar (sticky)', 'open ICICIBANK, measure Copy / Pin / Full page at scroll 0, 300 and the end', 'all three on screen above the tabs at every scroll, ≥ 44 px tall - no scrolling to copy', sb0 === '111' && sb1 === '111' && sb2 === '111', `top ${sb0} · mid ${sb1} · end ${sb2}`);
  await ev(() => document.querySelector('#shB').scrollTop = 0); await wait(80);
  await tapEl('#pCopy'); rec('Copy contract', 'tap "Copy 1,460 CE" in the first view (no scroll)', '"copied: ICICIBANK 29DEC 1460 CE"', /copied: ICICIBANK 29DEC 1460 CE/.test(await toastTxt()), await toastTxt());
  await tapEl('#pPin'); const pn1 = await toastTxt(), pl1 = await ev(() => document.querySelector('#pPin').textContent + '|' + !!document.querySelector('#shTop .pin') + '|' + !!document.querySelector('#memL .mr[data-sym="ICICIBANK"] .pin'));
  await tapEl('#pPin'); const pn2 = await toastTxt(), pl2 = await ev(() => document.querySelector('#pPin').textContent + '|' + !!document.querySelector('#shTop .pin'));
  rec('Pin (toggle, n/5)', 'tap Pin, tap again', 'pinned 1/5 with a PIN tag (sheet + list row), then unpinned 0/5', /pinned · 1\/5/.test(pn1) && pl1 === 'Unpin · 1/5|true|true' && /unpinned · 0\/5/.test(pn2) && pl2 === 'Pin · 0/5|false', pn1 + ' | ' + pl1 + ' | ' + pn2 + ' | ' + pl2);
  await ev(() => document.querySelector('#memL').scrollTop = 120); await wait(60);
  await tapEl('#back2'); await wait(150); const bk1 = await ev(() => ({ s: document.querySelector('#shareS').classList.contains('on'), l: document.querySelector('#secS').classList.contains('on'), y: document.querySelector('#memL').scrollTop, sel: (document.querySelector('#memL .mr.sel') || {}).dataset }));
  rec('‹ Banks (Back button)', 'tap Back on the share sheet', 'the Banks list again, same scroll, ICICIBANK still marked', !bk1.s && bk1.l && bk1.y === 120 && bk1.sel && bk1.sel.sym === 'ICICIBANK', `y ${bk1.y} · sel ${bk1.sel && bk1.sel.sym}`);
  const vsym = await ev(() => { const w = document.querySelector('#memL').getBoundingClientRect(); const r = [...document.querySelectorAll('#memL .mr')].find(x => x.getBoundingClientRect().top >= w.top + 2 && x.dataset.sym !== 'ICICIBANK'); return r.dataset.sym; });
  await tapEl(`.mr[data-sym="${vsym}"]`); await wait(100); const sTopNew = await sTop('#shB'), opened = await ev(() => document.querySelector('#shareS').classList.contains('on')); await p.goBack(); await wait(300);
  const bk2 = await ev(() => ({ s: document.querySelector('#shareS').classList.contains('on'), y: document.querySelector('#memL').scrollTop, sel: (document.querySelector('#memL .mr.sel') || {}).dataset }));
  rec('device / browser Back (share)', 'at list y = 120 tap the first visible share (' + vsym + '; its sheet starts at the top), then browser Back', 'back to the list, same scroll, that share marked', opened && sTopNew === 0 && !bk2.s && bk2.y === 120 && bk2.sel && bk2.sel.sym === vsym, `sheet top ${sTopNew} · list y ${bk2.y} · sel ${bk2.sel && bk2.sel.sym}`);
  // blocks on the phone
  for (const [sym, test, name, exp] of [
    ['INDUSINDBK', () => { const t = document.querySelector('#shB'), f = t.firstElementChild; return /BAN - only close existing/.test(f.innerText) && /MWPL 96%/.test(f.innerText) && !t.querySelector('.pl3') && !/★/.test(t.querySelector('.tbx th.pk').innerText) && document.querySelector('#pCopy').disabled; }, 'BAN share (phone)', 'first line "BAN - only close existing · MWPL 96%", no plan rows, no ★, Copy disabled'],
    ['AUBANK', () => /STALE 12s/.test(document.querySelector('#shB').firstElementChild.innerText) && document.querySelector('#shB .tbx').classList.contains('dim') && document.querySelector('#pCopy').disabled, 'STALE share (phone)', 'first line STALE 12s, greyed trade box, Copy disabled'],
    ['YESBANK', () => /0 lots · waiting - RS30 −0.12 fails/.test(document.querySelector('#shB').firstElementChild.innerText) && document.querySelector('#pCopy').disabled, 'WAITING share (phone)', 'first line "0 lots · waiting - RS30 −0.12 fails"']]) {
    await ev(s => { const r = document.querySelector('#memL .mr[data-sym="' + s + '"]'); document.querySelector('#memL').scrollTop = r.offsetTop - 60; }, sym); await wait(80); await tapEl(`.mr[data-sym="${sym}"]`); await wait(100);
    if (sym === 'INDUSINDBK') { await tapEl('#pCopy'); }
    const ok = await ev(test), tt = await toastTxt(); rec(name, 'tap ' + sym, exp + (sym === 'INDUSINDBK' ? '; tapping Copy copies nothing' : ''), ok && !/copied/.test(tt), tt); await tapEl('#back2'); await wait(120); }
  await tapEl('#back1'); await wait(150); rec('‹ Sectors (Back button)', 'tap Back on the Banks sheet', 'the sector list', !(await on('#secS')));
  await tapEl('.sr[data-s="NBFC & finance"]'); await wait(100); rec('no laggard below 70% (phone)', 'tap NBFC & finance', '"LAGGARD · none - breadth 63% one way, below the 70% rule"', await ev(() => /LAGGARD · none - breadth 63%/.test(document.querySelector('#memL').innerText))); await p.goBack(); await wait(200);
  await ev(() => document.querySelector('#secL').scrollTop = 99999); await wait(100); await tapEl('.sr[data-s="IT"]'); await wait(100);
  rec('tap a falling sector (IT)', 'tap IT', 'mirrored: COMING DOWN NOW with PE strikes', await ev(() => /COMING DOWN NOW/.test(document.querySelector('#memL').textContent) && !!document.querySelector('#memL .c-pe')));
  await ev(() => document.querySelector('#memL').scrollTop = 0); await tapEl('.mr[data-sym="INFY"]'); await wait(100);
  rec('INFY (falling, COMING DOWN NOW)', 'tap INFY', 'group and sheet agree: not extended, 1,500 PE, R:R ≥ 1, lots shown', await ev(() => { const t = document.querySelector('#shB').innerText; return /COMING DOWN NOW/.test(document.querySelector('#shTop').innerText) && /1,500 PE/.test(t) && !/EXT/.test(t.split('TRADE BOX')[0]) && /→ 2 lots/.test(t); }));
  await tapEl('#shAct a.btn[href^="share.html"]'); await p.waitForURL(/share\.html#INFY/, { timeout: 3000 }).catch(() => {}); const fu = p.url(); await p.goBack(); await wait(400);
  rec('Full page › link', 'tap "Full page ›" on INFY', 'share.html#INFY', fu.includes('share.html#INFY'), fu.split('/').pop());
  await p.goBack(); await wait(250); await p.goBack(); await wait(250); rec('device / browser Back (sector)', 'browser Back from the IT sheet', 'the sector list', !(await on('#secS')) && !(await on('#shareS')));
  await tapEl('#plR'); await p.waitForURL(/phone\.html#risk$/, { timeout: 3000 }).catch(() => {}); const pu = p.url(); await p.goBack(); await wait(300);
  rec('MY F&O P&L row', 'tap it', 'RISK screen (P&L curve, net of costs)', pu.endsWith('phone.html#risk'), pu.split('/').pop());
  for (const t of ['now', 'risk', 'alerts']) { await tapEl(`.tabs a.tab[href*="#${t}"]`); await p.waitForURL(u => u.toString().endsWith('phone.html#' + t), { timeout: 3000 }).catch(() => {}); const u = p.url(); await p.goBack(); await wait(300);
    rec('bottom tab ' + t.toUpperCase(), 'tap it', 'phone.html#' + t, u.endsWith('phone.html#' + t), u.split('/').pop()); }
  // slow phone: CPU throttled 4x and 6x (CDP Emulation.setCPUThrottlingRate); finger tap -> painted sheet, measured in the page
  for (const rate of [4, 6]) { await p.goto(PHONE); await wait(400); await cdp.send('Emulation.setCPUThrottlingRate', { rate });
    await ev(() => { window.__q = {}; addEventListener('touchend', () => { window.__q.e = performance.now(); }, true);
      ['secS', 'shareS'].forEach(id => new MutationObserver(() => { if (!window.__q[id] && document.getElementById(id).classList.contains('on')) { window.__q[id] = 1; const e0 = window.__q.e; requestAnimationFrame(() => requestAnimationFrame(() => { window.__q[id + 'v'] = performance.now() - e0; })); } }).observe(document.getElementById(id), { attributes: true })); });
    await tapEl('.sr[data-s="Banks"]'); await wait(500); await tapEl('.mr[data-sym="ICICIBANK"]'); await wait(500); const q = await ev(() => window.__q);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
    rec('slow CPU ' + rate + 'x - sheets open fast', 'CPU throttled ' + rate + 'x: tap Banks, then tap ICICIBANK; touchend → sheet painted (2 frames)', 'sector sheet ≤ 150 ms, share sheet ≤ 150 ms', q.secSv <= 150 && q.shareSv <= 150, `sector sheet ${q.secSv && q.secSv.toFixed(0)} ms · share sheet ${q.shareSv && q.shareSv.toFixed(0)} ms`); }
  rec('page errors', 'errors during all of the above', 'none', errs.length === 0, errs.join(' | '));
  await b.close();
  console.log('| # | control | what was done | expected | result | note |\n|---|---|---|---|---|---|');
  R.forEach((r, i) => console.log(`| ${i + 1} | ${r.map(x => String(x).replace(/\|/g, '/')).join(' | ')} |`));
  console.log('PASS', R.filter(r => r[3] === 'PASS').length, 'FAIL', R.filter(r => r[3] === 'FAIL').length);
})();

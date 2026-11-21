// Screenshots (1600x900, 1366x768, phone strip) + a measured report: clipped text, font minimums (CONFERENCE 1.4),
// overlapping text in the mini chart, pane header buttons inside the panel for every share, whole rows in the first view.
// Run from anywhere: node shot.js   (exit code 1 if any check fails)
const path = require('path'), fs = require('fs');
const { chromium } = require(require.resolve('playwright', { paths: [__dirname, '/opt/node-tools/node_modules'] }));
const OUT = path.resolve(__dirname, '..') + '/', PAGE = 'file://' + OUT + 'rotation-drilldown.html', PHONE = 'file://' + OUT + 'rotation-drilldown-phone.html';
let bad = 0; const log = (ok, msg) => { if (!ok) bad++; console.log((ok ? 'ok   ' : 'FAIL ') + msg); };
// CHECK - run inside the page. NO tolerance: any element that clips its text (scrollWidth > clientWidth, overflow not visible) is a
// FAIL, unless it is prose that is meant to end in '…' and carries the full text in a tooltip. A number cell, a column head, a
// sector-row cell or a chip may never be cut. Also: a chip or cell that is painted past the edge of a clipping box (the
// 'ROT CONFIRMED 22m' case, where the chip itself has no overflow) is a FAIL.
const CHECK = () => {
  const r = { clip: [], ell: [], font: [], chart: [], rows: 0, rail: [] };
  const vis = e => { const cs = getComputedStyle(e); if (cs.display === 'none' || cs.visibility === 'hidden') return false; const b = e.getBoundingClientRect(); return b.width > 0 && b.height > 0; };
  const PROSE = '.ell, .nw, .how, .morebar, .hbn span, .wl, #spSym, .whyb .tx, .sl .t3.ell, .sl .t2.ell, .sl .sn.ell, .sl .rn';
  const NEVER = '.num, .mhd, .shd, .srow, .sh-c, .c-op, .c-gt, .c-rm, .c-bu, .c-wt, .c-ag, .c-sd, .c-sh, .c-ai, .tbx, .pl3, .rk3, .p1, .p2';
  const nm = e => (e.id ? '#' + e.id : '') + (typeof e.className === 'string' && e.className ? '.' + e.className.trim().split(/\s+/).join('.') : e.tagName);
  const where = e => { const row = e.closest('[data-sym],[data-s]'); return row ? (row.dataset.sym || row.dataset.s) + ' ' : ''; };
  document.querySelectorAll('#page *').forEach(e => { if (!vis(e) || e.closest('svg') || !e.textContent.trim()) return; const cs = getComputedStyle(e);
    if (cs.overflowX !== 'visible' && e.clientWidth > 0 && e.scrollWidth > e.clientWidth) {
      if (e.matches('.scb, #wb, #pb, #rb')) return;   // the scrolling lists themselves
      const prose = cs.textOverflow === 'ellipsis' && (e.title || e.closest('[title]')) && e.matches(PROSE) && !e.matches(NEVER) && !e.closest('.num, .sh-c, .mhd');
      (prose ? r.ell : r.clip).push(where(e) + nm(e) + ': "' + e.textContent.trim().slice(0, 40) + '" ' + e.scrollWidth + '>' + e.clientWidth); } });
  document.querySelectorAll('#page .sh-c, #page .mrow > span, #page .srow > span, #page .mhd > span, #page .shd > span, #page .tbx th, #page .tbx td').forEach(e => { if (!vis(e)) return;
    const b = e.getBoundingClientRect();
    for (let a = e.parentElement; a && a.id !== 'page'; a = a.parentElement) { const cs = getComputedStyle(a); if (cs.overflowX === 'visible') continue;
      if (a.matches(PROSE) && (a.title || a.closest('[title]'))) break;   // inside prose that is meant to ellipsize
      const q = a.getBoundingClientRect(); if (b.right > q.right + 0.5 || b.left < q.left - 0.5) r.clip.push(where(e) + nm(e) + ' "' + e.textContent.trim().slice(0, 30) + '" painted past ' + nm(a) + ' (' + b.right.toFixed(1) + ' > ' + q.right.toFixed(1) + ')');
      break; } });
  // font minimums (CONFERENCE 1.4): share name and its % >= 14; every chip, acted-on number and table cell >= 12
  const need = [['#wb .mrow .lk', 14], ['#wb .mrow .num.pc', 14], ['#page .sh-c', 12], ['#wb .mrow .c-op .pr', 12], ['#wb .mrow .c-op .sp', 12], ['#wb .mrow .c-gt span', 12], ['#wb .mrow .c-ai span', 12],
    ['#wb .srow .ce span', 12], ['#wb .srow .nm b', 14], ['#wb .srow .pc', 14], ['.blk .sl', 12], ['.blk .sl b', 12], ['#wb .mrow .num', 12], ['#wb .mrow .c-rm', 12], ['#wb .mrow .c-bu', 12], ['#wb .mrow .c-sd', 12], ['#pb .tbx td', 12], ['#pb .tbx th', 12], ['#pb .pl3 .v', 13], ['#pb .rk3', 12], ['#pb .p2 b', 12], ['#pb .p1 .px', 14]];
  need.forEach(([q, min]) => document.querySelectorAll(q).forEach(e => { if (!vis(e)) return; const f = parseFloat(getComputedStyle(e).fontSize); if (f < min - 0.01) r.font.push(q + ' ' + f + 'px < ' + min + ': "' + e.textContent.trim().slice(0, 20) + '"'); }));
  const ch = document.querySelector('#pb .mchart'); if (ch) { const t = [...ch.querySelectorAll('text')].map(x => [x, x.getBoundingClientRect()]);
    for (let i = 0; i < t.length; i++) for (let j = i + 1; j < t.length; j++) { const a = t[i][1], b = t[j][1]; if (a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1) r.chart.push('"' + t[i][0].textContent + '" x "' + t[j][0].textContent + '"'); }
    const svb = ch.getBoundingClientRect(); t.forEach(([x, b]) => { if (b.right > svb.right + 1 || b.left < svb.left - 1) r.chart.push('outside: "' + x.textContent + '"'); });
    // the OR label may not sit on the OR box border
    const orT = ch.querySelector('text.orl'), orR = ch.querySelector('rect'); if (orT && orR) { const a = orT.getBoundingClientRect(), q = orR.getBoundingClientRect();
      [q.top, q.bottom].forEach(y => { if (a.top < y + 0.5 && a.bottom > y - 0.5) r.chart.push('OR label on the OR box border'); }); }
    if ([...ch.querySelectorAll('text')].some(x => /^[TSG] \d/.test(x.textContent))) r.chart.push('one-letter level label (use TRIG / STOP / TGT)'); }
  const wb = document.querySelector('#wb').getBoundingClientRect(); r.rows = [...document.querySelectorAll('#wb .mrow')].filter(x => { const q = x.getBoundingClientRect(); return q.top >= wb.top - 1 && q.bottom <= wb.bottom + 1; }).length;
  document.querySelectorAll('.rail').forEach(rl => { if (!vis(rl)) return; const tk = rl.querySelector('.trk').getBoundingClientRect(); if (tk.width < 10) r.rail.push('track ' + tk.width + ' px');
    rl.querySelectorAll('.rb').forEach(x => { const q = x.getBoundingClientRect(); if (q.width < 16 || q.height < 16) r.rail.push(x.textContent + ' ' + q.width + 'x' + q.height); }); });
  return r; };
(async () => {
  const b = await chromium.launch();
  for (const [w, h, f, need] of [[1600, 900, 'rotation-drilldown.png', 12], [1366, 768, 'rotation-drilldown_1366.png', 8]]) {
    const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
    await p.goto(PAGE); await p.waitForTimeout(500);
    await p.screenshot({ path: OUT + f });
    const r = await p.evaluate(CHECK);
    log(r.clip.length === 0, w + ' clipped text (no ellipsis/tooltip): ' + r.clip.length + (r.clip.length ? ' · ' + r.clip.join(' | ') : ''));
    console.log('     ' + w + ' intended ellipsis with a tooltip: ' + r.ell.length + (r.ell.length ? ' · ' + r.ell.slice(0, 6).join(' | ') : ''));
    log(r.font.length === 0, w + ' font minimums: ' + (r.font.length ? r.font.slice(0, 12).join(' | ') : 'all met'));
    log(r.chart.length === 0, w + ' mini chart text overlaps: ' + (r.chart.join(' | ') || 'none'));
    log(r.rows >= need, w + ' whole share rows in the first view: ' + r.rows + ' (need ' + need + ')');
    log(r.rail.length === 0, w + ' scrollbars: track >= 10 px, up / down buttons >= 16 x 16 px' + (r.rail.length ? ': ' + r.rail.join(' | ') : ''));
    // pane header and pane body for every share (long symbols, BAN, STALE, option-stale, extended, laggard, against, falling)
    const syms = await p.evaluate(() => GD.SECTORS.flatMap(s => s.members.map(m => m.sym)));
    const hdr = [], chart = [], clip = [];
    for (const sym of syms) { await p.evaluate(x => { const f = GD.find(x); GIRDD.st.open = f.s.id; GIRDD.st.sel = x; GIRDD.openSector(f.s.id, true); GIRDD.selShare(x); }, sym);
      const q = await p.evaluate(() => { const pn = document.querySelector('#sp').getBoundingClientRect(); return [...document.querySelectorAll('#sp .ph button')].filter(x => x.getBoundingClientRect().right > pn.right - 1).map(x => x.textContent); });
      const r2 = await p.evaluate(CHECK); const pc = r2.clip.filter(x => !/^\S+ \.mrow|^\S+ \.srow/.test(x) || true);
      if (q.length) hdr.push(sym + ':' + q.join(',')); if (r2.chart.length) chart.push(sym + ': ' + r2.chart.join(', ')); if (pc.length || r2.font.length) clip.push(sym + ': ' + pc.concat(r2.font).slice(0, 3).join(', ')); }
    log(hdr.length === 0, w + ' pane header buttons inside the panel for all ' + syms.length + ' shares' + (hdr.length ? ': ' + hdr.join(' | ') : ''));
    log(chart.length === 0, w + ' mini chart: no overlapping text for all ' + syms.length + ' shares' + (chart.length ? ': ' + chart.slice(0, 5).join(' | ') : ''));
    log(clip.length === 0, w + ' every share loaded in the pane: nothing clipped (no tolerance), all fonts met, ' + syms.length + ' shares' + (clip.length ? ': ' + clip.slice(0, 6).join(' | ') : ''));
    // every sector open: clipped text in its block
    const sc = [], ell = new Set(); let cells = 0;
    for (const s of await p.evaluate(() => GD.SECTORS.map(x => x.id))) { await p.evaluate(x => { GIRDD.st.sel = null; GIRDD.st.more[x] = 1; GIRDD.st.nfo[x] = 1; GIRDD.openSector(x, true); }, s); await p.evaluate(() => GIRDD.selShare(null));
      const r3 = await p.evaluate(CHECK); cells += await p.evaluate(() => document.querySelectorAll('#wb .mrow > span, #wb .srow > span, #wb .mhd > span').length);
      r3.ell.forEach(x => ell.add(x)); if (r3.clip.length || r3.font.length) sc.push(s + ': ' + r3.clip.length + ' cut · ' + r3.clip.concat(r3.font).slice(0, 4).join(', ')); }
    log(sc.length === 0, w + ' every sector open, "+n more" and "not F&O" folds open: no cut cell (no tolerance), fonts met (' + cells + ' cells checked)' + (sc.length ? ': ' + sc.join(' | ') : ''));
    console.log('     ' + w + ' prose that ends in … with a tooltip (intended): ' + ell.size + (ell.size ? ' · ' + [...ell].slice(0, 4).join(' | ') : ''));
    // every mockup state (live / forming / manage / locked / held / pre-open): nothing cut, and the strip agrees with the pane
    const mk = [];
    for (const k of ['forming', 'manage', 'locked', 'held', 'preopen', 'live']) { await p.evaluate(k => { GIRDD.st.more = {}; GIRDD.st.nfo = {}; GIRDD.st.sel = 'ICICIBANK'; GIRDD.openSector('Banks', true); GIRDD.selShare('ICICIBANK'); GIRDD.setMock(k); }, k); await p.waitForTimeout(60);
      const r4 = await p.evaluate(CHECK), agree = await p.evaluate(() => { const t = document.querySelector('#sh-pnl').innerText.replace(/\s+/g, ' '), pn = document.querySelector('#pb').innerText.replace(/\s+/g, ' ');
        const a = (t.match(/trades (\d) of 3/i) || [])[1], b = (pn.match(/trades (\d) of 3/) || [])[1]; return a === b ? '' : 'strip trades ' + a + ' of 3 vs pane ' + b + ' of 3'; });
      if (r4.clip.length || r4.font.length || agree) mk.push(k + ': ' + r4.clip.concat(r4.font).slice(0, 3).join(', ') + agree); }
    log(mk.length === 0, w + ' every mockup state: nothing cut, P&L strip trades = pane trades' + (mk.length ? ': ' + mk.join(' | ') : ''));
    log(errs.length === 0, w + ' page errors: ' + (errs.join(' | ') || 'none'));
    await p.close();
  }
  // phone: four states side by side
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true });
  const shots = [];
  for (const [hash, lab, js] of [['', '1 Sectors list - Banks UP (tap Banks)'], ['#s=Banks', '2 Banks sheet - 2-line header, groups'], ['#s=Banks', '3 same sheet, WAITING + BAN rows', 'document.querySelector("#memL").scrollTop=430'], ['#s=Banks&r=ICICIBANK', '4 tap ICICIBANK - share sheet (Back = list)']]) {
    const p = await ctx.newPage(); const errs = []; p.on('pageerror', e => errs.push(e.message)); await p.goto(PHONE + hash); await p.waitForTimeout(400); if (js) { await p.evaluate(js); await p.waitForTimeout(200); }
    const f = OUT + 'drilldown_src/_ph' + shots.length + '.png'; await p.screenshot({ path: f }); shots.push([f, lab]);
    const pr = await p.evaluate(() => { const out = []; document.querySelectorAll('#ph *').forEach(e => { const cs = getComputedStyle(e); if (cs.display === 'none' || !e.getBoundingClientRect().width) return; const fz = parseFloat(cs.fontSize); if (e.childNodes.length && [...e.childNodes].some(n => n.nodeType === 3 && n.textContent.trim()) && fz < 13 && !e.closest('.mock') && !e.closest('svg')) out.push('font ' + fz + ': ' + e.textContent.trim().slice(0, 20));
      if (e.scrollWidth > e.clientWidth && e.clientWidth > 0 && cs.overflowX !== 'visible' && !e.classList.contains('scb') && !(cs.textOverflow === 'ellipsis' && (e.title || e.closest('[title]'))) && !(cs.webkitLineClamp && cs.webkitLineClamp !== 'none')) out.push('clip: ' + (e.className || e.tagName) + ' ' + e.textContent.trim().slice(0, 30)); });
      return [...new Set(out)]; });
    log(pr.length === 0 && !errs.length, 'phone ' + lab + ': fonts >= 13 px, no clipped text' + (pr.length ? ': ' + pr.slice(0, 8).join(' | ') : '') + (errs.length ? ' errors: ' + errs.join(' | ') : ''));
    await p.close(); }
  { const p = await ctx.newPage(); const bad2 = [], bad3 = []; const all = await (async () => { await p.goto(PHONE); return p.evaluate(() => GD.SECTORS.flatMap(s => s.members.map(m => [s.id, m.sym]))); })();
    for (const [sid, sym] of all) { await p.goto(PHONE + '?v=' + encodeURIComponent(sym) + '#s=' + encodeURIComponent(sid) + '&r=' + encodeURIComponent(sym)); await p.waitForTimeout(120);
      const r = await p.evaluate(() => { const ch = document.querySelector('#shB .mchart'); if (!ch) return ['no chart']; const t = [...ch.querySelectorAll('text')].map(x => [x.textContent, x.getBoundingClientRect()]), o = [];
        for (let i = 0; i < t.length; i++) for (let j = i + 1; j < t.length; j++) { const a = t[i][1], c = t[j][1]; if (a.left < c.right - 1 && c.left < a.right - 1 && a.top < c.bottom - 1 && c.top < a.bottom - 1) o.push(t[i][0] + ' x ' + t[j][0]); }
        const sv = ch.getBoundingClientRect(); t.forEach(([x, q]) => { if (q.right > sv.right + 1 || q.left < sv.left - 1) o.push('outside ' + x); }); return o; });
      // strict clip check of the whole share sheet + its action bar, and Copy / Pin on screen without scrolling
      const c = await p.evaluate(() => { const o = []; document.querySelectorAll('#shareS *').forEach(e => { const cs = getComputedStyle(e); if (cs.display === 'none' || !e.getBoundingClientRect().width || e.closest('svg') || !e.textContent.trim()) return;
          if (e.scrollWidth > e.clientWidth && e.clientWidth > 0 && cs.overflowX !== 'visible' && !e.classList.contains('scb') && !(cs.textOverflow === 'ellipsis' && (e.title || e.closest('[title]')) && !e.closest('.n, .c, .btn')) && !(cs.webkitLineClamp && cs.webkitLineClamp !== 'none')) o.push('clip ' + (e.className || e.tagName) + ' "' + e.textContent.trim().slice(0, 24) + '" ' + e.scrollWidth + '>' + e.clientWidth); });
        const tabs = document.querySelector('.tabs').getBoundingClientRect(); ['#pCopy', '#pPin'].forEach(q => { const b = document.querySelector(q).getBoundingClientRect(); if (b.top < 0 || b.bottom > tabs.top + 0.5 || b.height < 44) o.push(q + ' not on screen / under 44 px'); });
        return o; });
      if (r.length) bad2.push(sym + ': ' + r.join(', ')); if (c.length) bad3.push(sym + ': ' + c.join(', ')); }
    log(bad2.length === 0, 'phone mini chart: no overlapping / outside text for all ' + all.length + ' shares' + (bad2.length ? ': ' + bad2.slice(0, 5).join(' | ') : ''));
    log(bad3.length === 0, 'phone share sheet for all ' + all.length + ' shares: nothing clipped (no tolerance), Copy and Pin on screen in the first view (sticky bar, 44 px)' + (bad3.length ? ': ' + bad3.slice(0, 5).join(' | ') : ''));
    // every sector sheet: strict clip check, top of the list and scrolled to the end
    const sids = await p.evaluate(() => GD.SECTORS.map(s => s.id)), bad4 = [];
    for (const sid of sids) { await p.goto(PHONE + '?q=' + encodeURIComponent(sid) + '#s=' + encodeURIComponent(sid)); await p.waitForTimeout(120);
      for (const y of [0, 99999]) { const c = await p.evaluate(y => { const L = document.querySelector('#memL'); L.scrollTop = y; const o = []; document.querySelectorAll('#secS *').forEach(e => { const cs = getComputedStyle(e); if (cs.display === 'none' || !e.getBoundingClientRect().width || e.closest('svg') || !e.textContent.trim()) return;
          if (e.scrollWidth > e.clientWidth && e.clientWidth > 0 && cs.overflowX !== 'visible' && !e.classList.contains('scb') && !(cs.textOverflow === 'ellipsis' && (e.title || e.closest('[title]')) && !e.closest('.n, .c')) && !(cs.webkitLineClamp && cs.webkitLineClamp !== 'none')) o.push((e.className || e.tagName) + ' "' + e.textContent.trim().slice(0, 24) + '" ' + e.scrollWidth + '>' + e.clientWidth); }); return o; }, y);
        if (c.length) bad4.push(sid + ': ' + c.slice(0, 3).join(', ')); } }
    log(bad4.length === 0, 'phone every sector sheet (' + sids.length + '), top and end of the list: nothing clipped (no tolerance)' + (bad4.length ? ': ' + bad4.slice(0, 5).join(' | ') : ''));
    await p.close(); }
  const sp = await b.newPage({ viewport: { width: 1640, height: 880 } });
  await sp.setContent('<body style="margin:0;background:#05070A;display:flex;gap:16px;padding:0 16px;font:600 15px Inter,system-ui;color:#E7EAEE">' + shots.map(([f, l]) => '<div><div style="height:32px;line-height:32px">' + l + '</div><img src="data:image/png;base64,' + fs.readFileSync(f).toString('base64') + '" style="display:block;width:390px;height:844px;zoom:.98"></div>').join('') + '</body>');
  await sp.screenshot({ path: OUT + 'rotation-drilldown-phone.png' }); shots.forEach(([f]) => fs.unlinkSync(f));
  await b.close();
  console.log(bad ? bad + ' check(s) FAILED' : 'all checks passed'); process.exit(bad ? 1 : 0);
})();

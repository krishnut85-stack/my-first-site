// Screenshots (1600x900, 1366x768, phone strip) + a measured report: clipped text, font minimums (CONFERENCE 1.4),
// overlapping text in the mini chart, pane header buttons inside the panel for every share, whole rows in the first view.
// Run from anywhere: node shot.js   (exit code 1 if any check fails)
const path = require('path'), fs = require('fs');
const { chromium } = require(require.resolve('playwright', { paths: [__dirname, '/opt/node-tools/node_modules'] }));
const OUT = path.resolve(__dirname, '..') + '/', PAGE = 'file://' + OUT + 'rotation-drilldown.html', PHONE = 'file://' + OUT + 'rotation-drilldown-phone.html';
let bad = 0; const log = (ok, msg) => { if (!ok) bad++; console.log((ok ? 'ok   ' : 'FAIL ') + msg); };
const CHECK = () => {
  const r = { clip: [], ell: [], font: [], chart: [], rows: 0 };
  const vis = e => { const cs = getComputedStyle(e); if (cs.display === 'none' || cs.visibility === 'hidden') return false; const b = e.getBoundingClientRect(); return b.width > 0 && b.height > 0; };
  document.querySelectorAll('#page *').forEach(e => { if (!vis(e)) return; const cs = getComputedStyle(e);
    if (e.scrollWidth > e.clientWidth + 1 && e.clientWidth > 0 && cs.overflowX !== 'visible' && e.textContent.trim() && !e.closest('svg')) {
      const intended = cs.textOverflow === 'ellipsis' && (e.title || e.closest('[title]'));
      (intended ? r.ell : r.clip).push((e.id || e.className || e.tagName) + ': "' + e.textContent.trim().slice(0, 48) + '" ' + e.scrollWidth + '>' + e.clientWidth); } });
  // font minimums: share name and its % >= 14; acted-on numbers / chips >= 12
  const need = [['#wb .mrow .lk', 14], ['#wb .mrow .num.pc', 14], ['#wb .mrow .c-op .sh-c', 12], ['#wb .mrow .c-op .pr', 12], ['#wb .mrow .c-op .sp', 12], ['#wb .mrow .c-gt span', 12], ['#wb .mrow .c-ai span', 12],
    ['#wb .srow .ce span', 12], ['#wb .srow .nm b', 14], ['#wb .srow .pc', 14], ['.blk .sl', 12], ['.blk .sl b', 12], ['#wb .mrow .num', 12], ['#wb .mrow .c-rm', 12], ['#wb .mrow .c-bu', 12], ['#wb .mrow .c-sd', 12], ['#pb .tbx td', 12], ['#pb .pl3 .v', 13], ['#pb .rk3', 12]];
  need.forEach(([q, min]) => document.querySelectorAll(q).forEach(e => { if (!vis(e)) return; const f = parseFloat(getComputedStyle(e).fontSize); if (f < min - 0.01) r.font.push(q + ' ' + f + 'px < ' + min + ': "' + e.textContent.trim().slice(0, 20) + '"'); }));
  const ch = document.querySelector('#pb .mchart'); if (ch) { const t = [...ch.querySelectorAll('text')].map(x => [x, x.getBoundingClientRect()]);
    for (let i = 0; i < t.length; i++) for (let j = i + 1; j < t.length; j++) { const a = t[i][1], b = t[j][1]; if (a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1) r.chart.push('"' + t[i][0].textContent + '" x "' + t[j][0].textContent + '"'); }
    const svb = ch.getBoundingClientRect(); t.forEach(([x, b]) => { if (b.right > svb.right + 1 || b.left < svb.left - 1) r.chart.push('outside: "' + x.textContent + '"'); }); }
  const wb = document.querySelector('#wb').getBoundingClientRect(); r.rows = [...document.querySelectorAll('#wb .mrow')].filter(x => { const q = x.getBoundingClientRect(); return q.top >= wb.top - 1 && q.bottom <= wb.bottom + 1; }).length;
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
    // pane header and pane body for every share (long symbols, BAN, STALE, option-stale, extended, laggard, against, falling)
    const syms = await p.evaluate(() => GD.SECTORS.flatMap(s => s.members.map(m => m.sym)));
    const hdr = [], chart = [], clip = [];
    for (const sym of syms) { await p.evaluate(x => { const f = GD.find(x); GIRDD.st.open = f.s.id; GIRDD.st.sel = x; GIRDD.openSector(f.s.id, true); GIRDD.selShare(x); }, sym);
      const q = await p.evaluate(() => { const pn = document.querySelector('#sp').getBoundingClientRect(); const o = [...document.querySelectorAll('#sp .ph button')].filter(x => x.getBoundingClientRect().right > pn.right - 1).map(x => x.textContent);
        const c = []; document.querySelectorAll('#pb *').forEach(e => { const cs = getComputedStyle(e); if (cs.display === 'none') return; if (e.scrollWidth > e.clientWidth + 1 && e.clientWidth > 0 && cs.overflowX !== 'visible' && !(cs.textOverflow === 'ellipsis' && (e.title || e.closest('[title]'))) && !e.closest('svg') && !e.classList.contains('scb')) c.push((e.className || e.tagName) + ':' + e.textContent.trim().slice(0, 30)); });
        return { o, c }; });
      const r2 = await p.evaluate(CHECK);
      if (q.o.length) hdr.push(sym + ':' + q.o.join(',')); if (r2.chart.length) chart.push(sym + ': ' + r2.chart.join(', ')); if (q.c.length) clip.push(sym + ': ' + q.c.join(', ')); }
    log(hdr.length === 0, w + ' pane header buttons inside the panel for all ' + syms.length + ' shares' + (hdr.length ? ': ' + hdr.join(' | ') : ''));
    log(chart.length === 0, w + ' mini chart: no overlapping text for all ' + syms.length + ' shares' + (chart.length ? ': ' + chart.slice(0, 5).join(' | ') : ''));
    log(clip.length === 0, w + ' pane: no clipped text for all ' + syms.length + ' shares' + (clip.length ? ': ' + clip.slice(0, 6).join(' | ') : ''));
    // every sector open: clipped text in its block
    const sc = []; for (const s of await p.evaluate(() => GD.SECTORS.map(x => x.id))) { await p.evaluate(x => { GIRDD.st.sel = null; GIRDD.openSector(x, true); GIRDD.st.more[x] = 1; }, s); await p.evaluate(() => GIRDD.selShare(null)); const r3 = await p.evaluate(CHECK); if (r3.clip.length || r3.font.length) sc.push(s + ': ' + r3.clip.concat(r3.font).slice(0, 4).join(', ')); }
    log(sc.length === 0, w + ' every sector open (expanded): no clipped text, fonts met' + (sc.length ? ': ' + sc.join(' | ') : ''));
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
      if (e.scrollWidth > e.clientWidth + 1 && e.clientWidth > 0 && cs.overflowX !== 'visible' && !e.classList.contains('scb') && !(cs.textOverflow === 'ellipsis' && (e.title || e.closest('[title]'))) && !(cs.webkitLineClamp && cs.webkitLineClamp !== 'none')) out.push('clip: ' + (e.className || e.tagName) + ' ' + e.textContent.trim().slice(0, 30)); });
      return [...new Set(out)]; });
    log(pr.length === 0 && !errs.length, 'phone ' + lab + ': fonts >= 13 px, no clipped text' + (pr.length ? ': ' + pr.slice(0, 8).join(' | ') : '') + (errs.length ? ' errors: ' + errs.join(' | ') : ''));
    await p.close(); }
  const sp = await b.newPage({ viewport: { width: 1640, height: 880 } });
  await sp.setContent('<body style="margin:0;background:#05070A;display:flex;gap:16px;padding:0 16px;font:600 15px Inter,system-ui;color:#E7EAEE">' + shots.map(([f, l]) => '<div><div style="height:32px;line-height:32px">' + l + '</div><img src="data:image/png;base64,' + fs.readFileSync(f).toString('base64') + '" style="display:block;width:390px;height:844px;zoom:.98"></div>').join('') + '</body>');
  await sp.screenshot({ path: OUT + 'rotation-drilldown-phone.png' }); shots.forEach(([f]) => fs.unlinkSync(f));
  await b.close();
  console.log(bad ? bad + ' check(s) FAILED' : 'all checks passed'); process.exit(bad ? 1 : 0);
})();

// Every control on the laptop drill-down page, at 1366 x 768 (and the layout checks at 1600 x 900). PASS / FAIL table.
const { chromium } = require('playwright');
const U = 'file:///home/user/my-first-site/intraday_patches/design_v3/pages/rotation-drilldown.html';
const R = [];
function rec(ctrl, did, ok, note) { R.push([ctrl, did, ok ? 'PASS' : 'FAIL', note || '']); }
(async () => {
  const b = await chromium.launch();
  for (const [W, H] of [[1366, 768], [1600, 900]]) {
    const p = await b.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
    const errs = []; p.on('pageerror', e => errs.push(e.message));
    await p.goto(U); await p.waitForTimeout(300);
    const tag = W + ': ';
    const ev = f => p.evaluate(f);
    const st = () => ev(() => ({ open: GIRDD.st.open, sel: GIRDD.st.sel }));
    const top = () => ev(() => document.querySelector('#wb').scrollTop);
    // layout: open list pushes the rows below; no overlap; rows whole; count visible
    let lay = await ev(() => { const blk = document.querySelector('.blk'), nx = blk.nextElementSibling, a = blk.getBoundingClientRect(), c = nx.getBoundingClientRect();
      const rows = [...document.querySelectorAll('#wb .mrow')]; let ov = 0; for (let i = 1; i < rows.length; i++) if (rows[i].getBoundingClientRect().top < rows[i - 1].getBoundingClientRect().bottom - 0.5) ov++;
      const wb = document.querySelector('#wb').getBoundingClientRect(); const vis = rows.filter(r => { const q = r.getBoundingClientRect(); return q.top >= wb.top - 1 && q.bottom <= wb.bottom + 1; }).length;
      return { pushed: c.top >= a.bottom - 0.5, ov, vis, nextVisible: c.bottom <= wb.bottom + 1, more: !!document.querySelector('.gl .more') }; });
    rec(tag + 'open list layout', 'Banks open at load: next sector row below the block, member rows never overprint', lay.pushed && lay.ov === 0, `pushed=${lay.pushed} overlaps=${lay.ov}`);
    rec(tag + 'row cap', `whole share rows in first view (need ${W > 1500 ? 12 : 8})`, lay.vis >= (W > 1500 ? 12 : 8), `visible=${lay.vis} · next sector row visible=${lay.nextVisible} · "+n more" shown=${lay.more}`);
    if (W > 1500) { await p.close(); continue; }

    // 1 share row click -> pane
    await p.click('.mrow[data-sym="AXISBANK"] .c-dy, .mrow[data-sym="AXISBANK"] .num'); await p.waitForTimeout(150);
    rec('share row click', 'click AXISBANK row', (await ev(() => document.querySelector('#spSym').textContent)) === 'AXISBANK');
    await p.click('.mrow[data-sym="ICICIBANK"] .num'); await p.waitForTimeout(150);
    rec('share row click (2)', 'click ICICIBANK row', (await ev(() => document.querySelector('#spSym').textContent)) === 'ICICIBANK');
    // 2 keys J K arrows
    await p.keyboard.press('j'); let s1 = (await st()).sel; await p.keyboard.press('ArrowDown'); let s2 = (await st()).sel; await p.keyboard.press('k'); let s3 = (await st()).sel; await p.keyboard.press('ArrowUp'); let s4 = (await st()).sel;
    const pane4 = await ev(() => document.querySelector('#spSym').textContent);
    rec('J / ↓ / K / ↑', 'press J, ↓, K, ↑ from ICICIBANK', s1 === 'AXISBANK' && s2 === 'BANKBARODA' && s3 === 'AXISBANK' && s4 === 'ICICIBANK' && pane4 === 'ICICIBANK', [s1, s2, s3, s4].join(' → ') + ' · pane follows');
    // 3 W why / Esc
    await p.keyboard.press('w'); const wOn = await ev(() => document.querySelector('#whyD').classList.contains('on'));
    await p.keyboard.press('Escape'); const wOff = await ev(() => !document.querySelector('#whyD').classList.contains('on'));
    rec('W (why) + Esc', 'press W, then Esc', wOn && wOff);
    // 4 Space plan
    await p.keyboard.press(' '); const plOn = await ev(() => document.querySelector('#planD').classList.contains('on')); await p.keyboard.press('Escape');
    rec('Space (plan card)', 'press Space, then Esc', plOn && await ev(() => !document.querySelector('#planD').classList.contains('on')));
    // 5 P pin
    await p.keyboard.press('p'); const pin1 = await ev(() => document.querySelector('#pinN').textContent + '|' + !!document.querySelector('.mrow[data-sym="ICICIBANK"] .pin'));
    await p.keyboard.press('p'); const pin0 = await ev(() => document.querySelector('#pinN').textContent);
    rec('P (pin)', 'press P twice', pin1 === '1|true' && pin0 === '0', 'pinned 1/5 + PIN tag, then unpinned');
    // 6 scrollbar drag on the sector list
    const thumb = await p.$('.rail[data-for="wb"] .trk i'); let bb = await thumb.boundingBox(); const t0 = await top();
    await p.mouse.move(bb.x + bb.width / 2, bb.y + bb.height / 2); await p.mouse.down(); await p.mouse.move(bb.x + bb.width / 2, bb.y + bb.height / 2 + 60, { steps: 6 }); await p.mouse.up();
    const t1 = await top(); bb = await thumb.boundingBox();
    await p.mouse.move(bb.x + bb.width / 2, bb.y + bb.height / 2); await p.mouse.down(); await p.mouse.move(bb.x + bb.width / 2, bb.y + bb.height / 2 - 200, { steps: 6 }); await p.mouse.up();
    const t2 = await top();
    rec('sector list scrollbar thumb', 'mouse down on thumb, drag 60 px down, release; drag up, release', t1 > t0 + 20 && t2 < t1, `scrollTop ${t0} → ${t1} → ${t2}`);
    // 7 track click
    const trk = await (await p.$('.rail[data-for="wb"] .trk')).boundingBox(); await p.mouse.click(trk.x + trk.width / 2, trk.y + trk.height - 4); await p.waitForTimeout(120); const t3 = await top();
    await p.mouse.click(trk.x + trk.width / 2, trk.y + 3); await p.waitForTimeout(120); const t4 = await top();
    rec('sector list track click', 'click the track below / above the thumb', t3 > t2 && t4 < t3, `${t2} → ${t3} → ${t4}`);
    // 8 rail buttons
    await p.click('.rail[data-for="wb"] .rb.d'); const t5 = await top(); await p.click('.rail[data-for="wb"] .rb.u'); const t6 = await top();
    rec('sector list ▲ ▼ buttons', 'click ▼ then ▲', t5 > t4 && t6 < t5, `${t4} → ${t5} → ${t6}`);
    await p.click('.rail[data-for="wb"] .rb.d');
    // 9 wheel on list and on rail
    await p.mouse.move(400, 600); await p.mouse.wheel(0, 200); await p.waitForTimeout(150); const t7 = await top();
    const rl = await (await p.$('.rail[data-for="wb"]')).boundingBox(); await p.mouse.move(rl.x + 5, rl.y + 60); await p.mouse.wheel(0, -120); await p.waitForTimeout(150); const t8 = await top();
    rec('mouse wheel', 'wheel down over the list, wheel up over the scrollbar', t7 > t6 && t8 < t7, `${t6} → ${t7} → ${t8}`);
    // 10 PageDown / End / Home / PageUp with focus
    await p.focus('#wb'); await p.keyboard.press('PageDown'); await p.waitForTimeout(150); const k1 = await top(); await p.keyboard.press('End'); await p.waitForTimeout(150); const k2 = await top();
    await p.keyboard.press('PageUp'); await p.waitForTimeout(150); const k3 = await top(); await p.keyboard.press('Home'); await p.waitForTimeout(150); const k4 = await top();
    rec('PageDown / End / PageUp / Home', 'focus the list, press each', k1 > t8 - 1 && k2 >= k1 && k3 < k2 && k4 === 0, `${t8} → ${k1} → ${k2} → ${k3} → ${k4}`);
    // 11 pane scrollbar + arrow keys with focus in the pane
    const ptop = () => ev(() => document.querySelector('#pb').scrollTop);
    const pt = await (await p.$('.rail[data-for="pb"] .trk i')).boundingBox(); const q0 = await ptop();
    await p.mouse.move(pt.x + pt.width / 2, pt.y + 10); await p.mouse.down(); await p.mouse.move(pt.x + pt.width / 2, pt.y + 90, { steps: 5 }); await p.mouse.up(); const q1 = await ptop();
    rec('share pane scrollbar thumb', 'drag the pane thumb 80 px down', q1 > q0 + 20, `${q0} → ${q1}`);
    await p.focus('#pb'); await p.keyboard.press('Home'); await p.waitForTimeout(100); await p.keyboard.press('ArrowDown'); await p.keyboard.press('ArrowDown'); await p.waitForTimeout(250); const q2 = await ptop(); await p.keyboard.press('PageDown'); await p.waitForTimeout(250); const q3 = await ptop();
    rec('share pane keys (focus)', 'focus the pane, ↓ ↓ then PageDown', q2 > 0 && q3 > q2, `0 → ${q2} → ${q3}`);
    await p.mouse.move(1200, 500); await p.mouse.wheel(0, -400); await p.waitForTimeout(150);
    rec('share pane wheel', 'wheel up over the pane', (await ptop()) < q3, `→ ${await ptop()}`);
    await p.click('#lc .shd');
    // 12 +n more / less
    await p.click('.gl .more'); const all = await ev(() => document.querySelectorAll('#wb .mrow').length); await p.click('.gl .more'); const cap = await ev(() => document.querySelectorAll('#wb .mrow').length);
    rec('"+n more ▾" / "less ▴"', 'click +6 more, then less', all === 14 && cap === 8, `rows ${all} → ${cap}`);
    // 13 not-F&O grey line
    await p.click('.nonfo'); const nf = await ev(() => getComputedStyle(document.querySelector('.nfx')).display); await p.click('.nonfo');
    rec('"27 more listed, not F&O" line', 'click it (context list), click again', nf === 'flex' && await ev(() => getComputedStyle(document.querySelector('.nfx')).display === 'none'));
    // 14 basis ›
    await p.click('[data-bas]'); const bp = await ev(() => document.querySelector('#basP').classList.contains('on')); await p.click('#basP .x');
    rec('basis ›', 'click basis ›, then ✕', bp && await ev(() => !document.querySelector('#basP').classList.contains('on')));
    // 15 re-ranked chip (click) and R key
    await p.click('#rrChip'); const rr = await ev(() => { const r = [...document.querySelectorAll('#wb .mrow')].map(x => x.dataset.sym); return r.indexOf('AXISBANK') < r.indexOf('ICICIBANK') && !document.querySelector('#rrChip'); });
    rec('"re-ranked · R apply" chip', 'click the chip', rr, 'AXISBANK moves above ICICIBANK, ▲1 and chip gone');
    await p.evaluate(() => { GIRDD.st.applied = {}; GIRDD.openSector('Banks', true); }); await p.keyboard.press('r');
    rec('R key (apply re-rank)', 'press R', await ev(() => !document.querySelector('#rrChip')));
    // 16 window chips
    for (const [w, rng] of [['0', '10:50-11:05'], ['2', '10:05-11:05'], ['3', '09:15-11:05'], ['1', '10:35-11:05']]) { await p.click(`#wch .chip[data-w="${w}"]`); const r = await ev(() => document.querySelector('#wrng').textContent);
      rec('window chip ' + ['15M', '30M', '1H', 'TODAY'][+w], 'click it', r === rng, 'flow range ' + r); }
    // 17 view chips
    await p.click('#win .vchips .chip[data-v="run"]'); const rv = await ev(() => getComputedStyle(document.querySelector('#runV')).display !== 'none' && document.querySelectorAll('#rb .rr').length);
    await p.click('#rb .rr[data-s="IT"]'); const rvIT = (await st()).open;
    rec('RUN CLOCK chip + run row click', 'click RUN CLOCK, click the IT run row', rv > 0 && rvIT === 'IT', `${rv} run rows · IT opened, table view back`);
    await p.click('#win .vchips .chip[data-v="tbl"]'); rec('TABLE chip', 'click TABLE', await ev(() => getComputedStyle(document.querySelector('#tblV')).display !== 'none'));
    // 18 falling sector mirrors (IT open): COMING DOWN + PE
    rec('falling sector mirror', 'IT open: groups read COMING DOWN NOW with PE strikes', await ev(() => /COMING DOWN/.test(document.querySelector('.gl').textContent) && !!document.querySelector('.mrow .c-op .sh-c-pe')));
    // 19 sector row click: open another, pushes; click again closes
    await p.click('.srow[data-s="Metals"]'); let m1 = await ev(() => { const blk = document.querySelector('.blk'); return blk.dataset.s + '|' + (blk.nextElementSibling.getBoundingClientRect().top >= blk.getBoundingClientRect().bottom - 0.5) + '|' + document.querySelectorAll('.blk').length; });
    rec('sector row click (open)', 'click Metals', m1 === 'Metals|true|1', 'only one open, rows below pushed down');
    await p.click('.blk .srow'); rec('sector row click (close)', 'click the open Metals row', await ev(() => !document.querySelector('.blk')));
    // 20 keys 1-9
    await p.keyboard.press('3'); rec('key 3 (pick sector)', 'press 3', (await st()).open === 'Realty');
    await p.keyboard.press('1'); rec('key 1 (pick sector)', 'press 1', (await st()).open === 'Banks');
    // 21 Esc step by step
    await p.click('.mrow[data-sym="HDFCBANK"] .num'); await p.keyboard.press('w');
    await p.keyboard.press('Escape'); const e1 = await ev(() => !document.querySelector('#whyD').classList.contains('on') && GIRDD.st.sel === 'HDFCBANK');
    await p.keyboard.press('Escape'); const e2 = await ev(() => GIRDD.st.sel === null && GIRDD.st.open === 'Banks' && document.querySelector('.cmp') !== null);
    await p.keyboard.press('Escape'); const e3 = await ev(() => GIRDD.st.open === null);
    rec('Esc step by step', 'Why open → Esc ×3', e1 && e2 && e3, 'closes Why → clears the share (pane shows the compare table) → closes the list');
    // 22 hero: flow svg label, headline word, side list, new entrant
    await p.click('#flowSvg g.hit[data-s="NBFC & finance"]'); rec('flow arrow label click', 'click NBFC in the flow picture', (await st()).open === 'NBFC & finance');
    await p.click('#heroLine .s[data-s="IT"]'); rec('headline word click', 'click IT in the hero line', (await st()).open === 'IT');
    await p.click('.fs2 [data-s="Realty"]'); rec('"moving, not this rotation" click', 'click Realty', (await st()).open === 'Realty');
    await p.click('.ne[data-r="BAJFINANCE"]'); const ne = await st(); rec('new-entrant chip', 'click BAJFINANCE', ne.open === 'NBFC & finance' && ne.sel === 'BAJFINANCE', 'opens NBFC and loads BAJFINANCE');
    // 23 compare table row (pane with no share)
    await p.keyboard.press('Escape'); await p.click('.cmp td[data-sym]'); rec('compare table row', 'Esc, then click the first share in the compare table', !!(await st()).sel);
    // 24 pane buttons
    await p.keyboard.press('1'); await p.click('.mrow[data-sym="ICICIBANK"] .num');
    await p.click('#bW'); const bw = await ev(() => document.querySelector('#whyD').classList.contains('on')); await p.click('#whyD .x'); rec('pane button W why', 'click it, then ✕', bw && await ev(() => !document.querySelector('#whyD').classList.contains('on')));
    await p.click('#bP'); const bpn = await ev(() => document.querySelector('#pinN').textContent); await p.click('#bP'); rec('pane button P pin', 'click twice', bpn === '1' && (await ev(() => document.querySelector('#pinN').textContent)) === '0');
    await p.click('#bCopy'); rec('Copy contract', 'click it', await ev(() => /copied: ICICIBANK 29DEC 1460 CE/.test(document.querySelector('#toast').textContent)));
    await p.click('#ddAll'); rec('ALL SECTORS chip', 'click it', await ev(() => document.querySelector('#toast').classList.contains('on')));
    await p.click('#pinC'); rec('pinned chip', 'click it', await ev(() => /no pins|pinned/.test(document.querySelector('#toast').textContent)));
    // 25 navigation: dblclick, Enter, O, F7 button, chain button, then Back restores sector + row
    async function navBack(action, expect, label, did) { await action(); await p.waitForURL(u => u.toString().includes(expect), { timeout: 4000 }).catch(() => {}); const u = p.url();
      await p.goBack(); await p.waitForTimeout(400); const s = await st(); rec(label, did, u.includes(expect) && s.open === 'Banks' && s.sel === 'ICICIBANK', 'went to ' + u.split('/').pop() + ' · Back → ' + s.open + ' / ' + s.sel); }
    await navBack(() => p.dblclick('.mrow[data-sym="ICICIBANK"] .num'), 'share.html#ICICIBANK', 'double-click share → F7, Back', 'double-click ICICIBANK, then browser Back');
    await navBack(() => p.keyboard.press('Enter'), 'share.html#ICICIBANK', 'Enter → F7, Back', 'press Enter, then Back');
    await navBack(() => p.keyboard.press('o'), 'chain.html#ICICIBANK-1460CE', 'O → option chain, Back', 'press O, then Back');
    await navBack(() => p.click('#bF7'), 'share.html#ICICIBANK', 'pane button Enter F7', 'click it, then Back');
    await navBack(() => p.click('#bO'), 'chain.html#ICICIBANK', 'pane button O chain', 'click it, then Back');
    await navBack(() => p.click('.mrow[data-sym="ICICIBANK"] .c-bu a'), 'futures-oi.html#bu=LB', 'build-up chip link (F10)', 'click the LB chip, then Back');
    // 26 shell tabs and footer
    for (const [sel, exp, name] of [['#sh-tabs a[data-tab="sectors"]', 'sectors.html', 'tab F2 Sectors'], ['#sh-tabs a[data-tab="share"]', 'share.html', 'tab F7 Share'], ['#sh-tabs a[data-tab="morning"]', 'morning.html', 'tab ⇧F1 Morning'], ['#sh-tabs a[data-tab="rotation"]', 'rotation.html', 'tab F3 Rotation'], ['#sh-pnl', 'positions.html', 'P&L strip → F6'], ['#sh-foot a[href="health.html"]', 'health.html', 'footer health link']]) {
      await p.click(sel); await p.waitForURL(u => u.toString().includes(exp), { timeout: 4000 }).catch(() => {}); const u = p.url(); await p.goBack(); await p.waitForTimeout(300);
      rec(name, 'click it, then Back', u.includes(exp), u.split('/').pop()); }
    // 27 mouse-leave applies a pending re-rank (after 30 s or on leave)
    await p.evaluate(() => { GIRDD.st.applied = {}; GIRDD.st.autoRR = true; GIRDD.openSector('Banks', true); }); await p.mouse.move(400, 600); await p.mouse.move(700, 190); await p.waitForTimeout(150);
    rec('pointer leaves list → re-rank applies', 'hover the list, move the pointer out', await ev(() => !document.querySelector('#rrChip')));
    rec('page errors', 'console / page errors during all of the above', errs.length === 0, errs.join(' | '));
    await p.close();
  }
  await b.close();
  console.log('| # | control | what was done | result | note |\n|---|---|---|---|---|');
  R.forEach((r, i) => console.log(`| ${i + 1} | ${r[0]} | ${r[1]} | ${r[2]} | ${r[3]} |`));
  console.log('PASS', R.filter(r => r[2] === 'PASS').length, 'FAIL', R.filter(r => r[2] === 'FAIL').length);
})();

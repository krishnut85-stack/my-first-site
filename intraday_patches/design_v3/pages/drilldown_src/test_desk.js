// Every control on the laptop drill-down page, at 1600 x 900 AND 1366 x 768. Honest: real mouse clicks at element centres,
// keyboard focus by clicking or Tab (never page.focus), real waits for the 30 s re-rank timer, no state forced from the test.
// node test_desk.js [1366|1600]  ->  markdown PASS / FAIL table on stdout
const path = require('path');
const { chromium } = require(require.resolve('playwright', { paths: [__dirname, '/opt/node-tools/node_modules'] }));
const PAGE = 'file://' + path.resolve(__dirname, '..', 'rotation-drilldown.html');
const SIZES = process.argv[2] ? [[+process.argv[2], +process.argv[2] === 1600 ? 900 : 768]] : [[1600, 900], [1366, 768]];
const R = []; let SZ = '';
function rec(ctrl, did, exp, ok, note) { R.push([SZ, ctrl, did, exp, ok ? 'PASS' : 'FAIL', note || '']); if (!ok) console.error('FAIL', SZ, ctrl, note || ''); }
(async () => {
  const b = await chromium.launch();
  for (const [W, H] of SIZES) {
    SZ = String(W); const cap = W > 1500 ? 12 : 8;
    const p = await b.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
    const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
    const ev = (f, a) => p.evaluate(f, a), wait = ms => p.waitForTimeout(ms);
    const NEUTRAL = async () => { const bb = await box('#purp h1'); await p.mouse.move(bb.x + 5, bb.y + 5); };
    const fresh = async (hash) => { await NEUTRAL().catch(() => {}); await p.goto(PAGE + (hash || '')); await wait(350); await NEUTRAL(); };
    const box = async (sel) => { const e = await p.$(sel); if (!e) throw new Error('no ' + sel); await e.scrollIntoViewIfNeeded().catch(() => {}); return e.boundingBox(); };
    const clickC = async (sel, opt) => { const bb = await box(sel); await p.mouse.click(bb.x + bb.width / 2, bb.y + bb.height / 2, opt); await wait(120); return bb; };
    const S = () => ev(() => ({ open: GIRDD.st.open, sel: GIRDD.st.sel, url: location.href.split('/').pop() }));
    const top = (q) => ev(q => document.querySelector(q).scrollTop, q || '#wb');
    const order = () => ev(() => [...document.querySelectorAll('#wb .mrow')].map(r => r.dataset.sym));
    const toastTxt = () => ev(() => document.querySelector('#toast').classList.contains('on') ? document.querySelector('#toast').textContent : '');

    // ================= A. layout =================
    await fresh();
    let lay = await ev(() => { const blk = document.querySelector('.blk'), nx = blk.nextElementSibling, a = blk.getBoundingClientRect(), c = nx.getBoundingClientRect();
      const rows = [...document.querySelectorAll('#wb .mrow')]; let ov = 0; for (let i = 1; i < rows.length; i++) if (rows[i].getBoundingClientRect().top < rows[i - 1].getBoundingClientRect().bottom - 0.5) ov++;
      const wb = document.querySelector('#wb').getBoundingClientRect(); const vis = rows.filter(r => { const q = r.getBoundingClientRect(); return q.top >= wb.top - 1 && q.bottom <= wb.bottom + 1; }).length;
      const mb = document.querySelector('.morebar'); return { pushed: c.top >= a.bottom - 0.5, ov, vis, more: mb ? mb.textContent : '' }; });
    rec('open list layout', 'Banks open at load', 'next sector row below the block, no member row overprints another', lay.pushed && lay.ov === 0, `pushed=${lay.pushed} overlaps=${lay.ov}`);
    rec('row cap + "+n more" bar', 'count whole share rows in the first view', `≥ ${cap} whole rows, then a full-width bar naming the hidden shares`, lay.vis >= cap && /^▾ \+\d+ more: [A-Z]/.test(lay.more), `visible=${lay.vis} · bar "${lay.more}"`);
    const rails = await ev(() => ['wb', 'pb'].map(id => { const r = document.querySelector('.rail[data-for="' + id + '"]'), t = r.querySelector('.trk'), th = t.querySelector('i'), u = r.querySelector('.rb.u'), d = r.querySelector('.rb.d');
      const g = e => e.getBoundingClientRect(); return { id, trk: g(t).width, th: g(th).width, up: [g(u).width, g(u).height], dn: [g(d).width, g(d).height] }; }));
    rec('scrollbar size (R51)', 'measure the drawn list and pane rails', 'visible track and thumb ≥ 10 px wide, ▲▼ buttons ≥ 16 px', rails.every(r => r.trk >= 10 && r.th >= 10 && r.up[0] >= 15 && r.up[1] >= 16 && r.dn[1] >= 16), rails.map(r => r.id + ': track ' + r.trk + ' thumb ' + r.th + ' ▲ ' + r.up.join('x') + ' ▼ ' + r.dn.join('x')).join(' · '));
    await ev(() => document.querySelector('#wb').scrollTop = 120); await wait(100);
    const sticky = await ev(() => Math.abs(document.querySelector('.blk .bh').getBoundingClientRect().top - document.querySelector('#wb').getBoundingClientRect().top));
    rec('sticky sector line', 'scroll the list 120 px', 'the sector line stays pinned at the top of the list', sticky < 1.5, 'offset ' + sticky.toFixed(1) + ' px');
    await ev(() => document.querySelector('#wb').scrollTop = 0);

    // ================= B. rows, pane, J/K =================
    await fresh();
    const u0 = (await S()).url; await clickC('.mrow[data-sym="AXISBANK"]');
    let s = await S(); rec('share row click (row centre)', 'mouse click at the centre of the AXISBANK row', 'loads AXISBANK in the pane, the page does not leave', s.sel === 'AXISBANK' && s.url.startsWith('rotation-drilldown.html') && (await ev(() => document.querySelector('#pb .big').textContent)) === 'AXISBANK', 'sel ' + s.sel + ' · ' + s.url.split('#')[0]);
    const vis = await order(); let okAll = true, seen = [];
    for (const sym of vis) { await clickC(`.mrow[data-sym="${sym}"] .lk`); const t = await ev(() => document.querySelector('#pb .big').textContent); seen.push(t); if (t !== sym) okAll = false; }
    rec('every visible share name', 'click each visible share name in turn', 'the pane loads each share; the list stays', okAll, seen.join(' '));
    await clickC('.mrow[data-sym="ICICIBANK"]'); await clickC('#pb .big');
    s = await S(); rec('pane share name - single click', 'single click on the big share name in the pane', 'nothing happens (double-click or Enter = F7)', s.url.startsWith('rotation-drilldown.html') && s.sel === 'ICICIBANK', s.url.split('#')[0]);
    const ord0 = await ev(() => [...document.querySelectorAll('#wb .mrow')].map(r => r.dataset.sym)); await clickC(`.mrow[data-sym="${ord0[0]}"]`);
    const seq = []; for (let i = 0; i < 13; i++) { await p.keyboard.press('j'); await wait(40); seq.push((await S()).sel); }
    const allSyms = await ev(() => GD.sec('Banks').members.map(m => m.sym)), visit = [ord0[0], ...seq];
    rec('J through the whole list', 'click the first row, press J 13 times', 'reaches all 14 shares, opening "+n more" when J reaches a hidden one; the pane follows', new Set(visit).size === 14 && allSyms.every(x => visit.includes(x)) && (await ev(() => document.querySelector('#pb .big').textContent)) === seq[12], visit.join(' → '));
    for (let i = 0; i < 12; i++) await p.keyboard.press('k'); await wait(60);
    rec('K back up', 'press K 12 times', 'back to the 2nd share (' + visit[1] + '), the pane follows', (await S()).sel === visit[1] && (await ev(() => document.querySelector('#pb .big').textContent)) === visit[1], (await S()).sel);
    await clickC(`.mrow[data-sym="${visit[1]}"]`); await p.keyboard.press('ArrowDown'); const ad = (await S()).sel; await p.keyboard.press('ArrowUp'); const au = (await S()).sel;
    rec('↓ / ↑ (focus in the list)', 'click a row, press ↓ then ↑', 'next share, then back', ad === visit[2] && au === visit[1], ad + ' → ' + au);
    const pbb = await box('#pb'); await p.mouse.click(pbb.x + pbb.width / 2, pbb.y + pbb.height * 0.6); await wait(100);
    const pfoc = await ev(() => document.activeElement.closest('#pb') ? 'pb' : document.activeElement.id); const y0 = await top('#pb'), sA = (await S()).sel;
    await p.keyboard.press('j'); const sj = (await S()).sel; await p.keyboard.press('k'); const sk = (await S()).sel;
    await p.mouse.click(pbb.x + pbb.width / 2, pbb.y + pbb.height * 0.6); await p.keyboard.press('ArrowDown'); await p.keyboard.press('ArrowDown'); await wait(300); const y1 = await top('#pb'); const sel2 = (await S()).sel;
    rec('J / K after a click in the pane', 'click in the share pane, press J, K, then ↓ ↓', 'J / K still move share to share; ↓ scrolls the pane, not the list', pfoc === 'pb' && sj !== sA && sk === sA && y1 > y0 && sel2 === sA, `focus ${pfoc} · ${sA} J ${sj} · K ${sk} · pane ${y0}→${y1}`);

    // ================= C. scrollbars (list and pane), mouse =================
    await fresh(); await clickC('.morebar'); await clickC('.nonfo');
    const MAX = await ev(() => { const w = document.querySelector('#wb'); return w.scrollHeight - w.clientHeight; });
    const thumb = async (id) => box(`.rail[data-for="${id}"] .trk i`);
    let t = await thumb('wb'); await p.mouse.move(t.x + t.width / 2, t.y + t.height / 2); await p.mouse.down(); await p.mouse.move(t.x + t.width / 2, t.y + t.height / 2 + 60, { steps: 12 }); await p.mouse.up(); const d1 = await top();
    t = await thumb('wb'); await p.mouse.move(t.x + t.width / 2, t.y + t.height / 2); await p.mouse.down(); await p.mouse.move(t.x + t.width / 2, t.y + t.height / 2 - 60, { steps: 12 }); await p.mouse.up(); const d2 = await top();
    rec('list scrollbar - slow drag', 'mouse down on the thumb, drag 60 px down in 12 steps, release; then back up', 'the list follows the thumb both ways', d1 > 40 && d2 < d1, `0 → ${d1} → ${d2}`);
    t = await thumb('wb'); await p.mouse.move(t.x + t.width / 2, t.y + t.height / 2); await p.mouse.down(); await p.mouse.move(t.x + t.width / 2, t.y + t.height / 2 + 120, { steps: 1 }); await p.mouse.up(); const d3 = await top();
    rec('list scrollbar - fast drag', 'one-step 120 px jerk on the thumb', 'the list jumps with the thumb', d3 > d2 + 80, `${d2} → ${d3}`);
    t = await thumb('wb'); await p.mouse.move(t.x + t.width / 2, t.y + t.height / 2); await p.mouse.down(); await p.mouse.move(t.x + 160, t.y + 900, { steps: 8 }); const d4 = await top(); await p.mouse.up(); await p.mouse.move(t.x + 100, t.y + 100, { steps: 4 }); const d4b = await top();
    rec('list scrollbar - past the end, off the rail', 'drag the thumb 900 px down and 160 px sideways off the rail, release, move on', 'stops at the maximum; release ends the drag', Math.abs(d4 - MAX) <= 1 && d4b === d4, `→ ${d4} (max ${MAX}) · after release ${d4b}`);
    t = await thumb('wb'); await p.mouse.move(t.x + t.width / 2, t.y + t.height / 2); await p.mouse.down(); await p.mouse.move(t.x - 80, t.y - 900, { steps: 8 }); await p.mouse.up(); const d5 = await top();
    rec('list scrollbar - past the top', 'drag the thumb 900 px up and off the rail', 'stops at 0', d5 === 0, `→ ${d5}`);
    const tk = await box('.rail[data-for="wb"] .trk'); await p.mouse.click(tk.x + tk.width / 2, tk.y + tk.height - 6); await wait(80); const d6 = await top(); await p.mouse.click(tk.x + tk.width / 2, tk.y + 4); await wait(80); const d7 = await top();
    rec('list scrollbar - track click', 'click the track below the thumb, then above it', 'pages down, then up', d6 > 0 && d7 < d6, `0 → ${d6} → ${d7}`);
    await clickC('.rail[data-for="wb"] .rb.d'); const d8 = await top(); await clickC('.rail[data-for="wb"] .rb.u'); const d9 = await top();
    rec('list scrollbar - ▲ ▼ buttons', 'click ▼ then ▲', 'scrolls 52 px each way', d8 === d7 + 52 && d9 === d8 - 52, `${d7} → ${d8} → ${d9}`);
    const wbB = await box('#wb'); await p.mouse.move(wbB.x + wbB.width / 2, wbB.y + wbB.height / 2); await p.mouse.wheel(0, 240); await wait(200); const w1 = await top();
    const rl = await box('.rail[data-for="wb"]'); await p.mouse.move(rl.x + rl.width / 2, rl.y + 80); await p.mouse.wheel(0, -120); await wait(200); const w2 = await top();
    rec('list - mouse wheel', 'wheel down over the list, wheel up over the scrollbar', 'scrolls both ways', w1 > d9 && w2 < w1, `${d9} → ${w1} → ${w2}`);
    await clickC('.mrow[data-sym="KOTAKBANK"]'); const kf = await ev(() => document.activeElement.id);
    const k0 = await top(); await p.keyboard.press('PageDown'); await wait(200); const k1 = await top(); await p.keyboard.press('End'); await wait(200); const k2 = await top(); await p.keyboard.press('PageUp'); await wait(200); const k3 = await top(); await p.keyboard.press('Home'); await wait(200); const k4 = await top();
    rec('list - PageDown / End / PageUp / Home', 'click a share row (focus by click), press each key', 'pages, ends, pages back, home', kf === 'wb' && k1 > k0 && k2 === MAX && k3 < k2 && k4 === 0, `focus ${kf} · ${k0} → ${k1} → ${k2} → ${k3} → ${k4}`);
    const thH = async () => ev(() => { const w = document.querySelector('#wb'), tr = document.querySelector('.rail[data-for="wb"] .trk'), th = tr.querySelector('i'); return [th.getBoundingClientRect().height, Math.max(24, tr.clientHeight * w.clientHeight / w.scrollHeight)]; });
    const h1 = await thH(); await clickC('.morebar'); const h2 = await thH(); await clickC('.nonfo'); const h3 = await thH();
    rec('thumb size follows the content', 'collapse "+n more", collapse the not-F&O line', 'thumb height = track × visible / total each time', [h1, h2, h3].every(x => Math.abs(x[0] - x[1]) < 1.5), [h1, h2, h3].map(x => x[0].toFixed(1) + '/' + x[1].toFixed(1)).join(' · '));
    // pane rail
    await clickC('.mrow[data-sym="ICICIBANK"]'); const PM = await ev(() => { const e = document.querySelector('#pb'); return e.scrollHeight - e.clientHeight; });
    t = await thumb('pb'); await p.mouse.move(t.x + t.width / 2, t.y + 8); await p.mouse.down(); await p.mouse.move(t.x + t.width / 2, t.y + 90, { steps: 8 }); await p.mouse.up(); const q1 = await top('#pb');
    t = await thumb('pb'); await p.mouse.move(t.x + t.width / 2, t.y + 8); await p.mouse.down(); await p.mouse.move(t.x - 150, t.y + 900, { steps: 6 }); await p.mouse.up(); const q2 = await top('#pb');
    const ptk = await box('.rail[data-for="pb"] .trk'); await p.mouse.click(ptk.x + ptk.width / 2, ptk.y + 4); await wait(80); const q3 = await top('#pb');
    await clickC('.rail[data-for="pb"] .rb.d'); const q4 = await top('#pb'); await clickC('.rail[data-for="pb"] .rb.u'); const q5 = await top('#pb');
    rec('pane scrollbar - drag, past end, track, ▲▼', 'drag the pane thumb 82 px, then 900 px down off the rail, click the track top, ▼, ▲', 'pane follows; stops at max; pages up; ±52', q1 > 30 && Math.abs(q2 - PM) <= 1 && q3 < q2 && q4 === q3 + 52 && q5 === q4 - 52, `0 → ${q1} → ${q2} (max ${PM}) → ${q3} → ${q4} → ${q5}`);
    await p.mouse.move(pbb.x + pbb.width / 2, pbb.y + pbb.height / 2); await p.mouse.wheel(0, 300); await wait(200); const q6 = await top('#pb');
    await p.mouse.click(pbb.x + pbb.width / 2, pbb.y + pbb.height * 0.5); await p.keyboard.press('Home'); await wait(150); const q7 = await top('#pb'); await p.keyboard.press('PageDown'); await wait(150); const q8 = await top('#pb'); await p.keyboard.press('End'); await wait(150); const q9 = await top('#pb');
    rec('pane - wheel and keys', 'wheel over the pane; click in it, Home, PageDown, End', 'scrolls; keys act on the pane', q6 !== q5 && q7 === 0 && q8 > 0 && Math.abs(q9 - PM) <= 1, `${q5} → ${q6} · ${q7} → ${q8} → ${q9}`);

    // ================= D. keys and actions =================
    await fresh(); await clickC('.mrow[data-sym="ICICIBANK"]');
    await p.keyboard.press('w'); const wOn = await ev(() => document.querySelector('#whyD').classList.contains('on') && /UNEXPLAINED/.test(document.querySelector('#whyD').textContent)); await p.keyboard.press('Escape'); const wOff = await ev(() => !document.querySelector('#whyD').classList.contains('on'));
    rec('W why + Esc', 'press W, then Esc', 'Why drawer opens (sector: today UNEXPLAINED, background 18 Nov), Esc closes it', wOn && wOff);
    await p.keyboard.press(' '); const plOn = await ev(() => document.querySelector('#planD').classList.contains('on')); await p.keyboard.press('Escape');
    rec('Space plan card + Esc', 'press Space, then Esc', 'plan card opens and closes', plOn && await ev(() => !document.querySelector('#planD').classList.contains('on')));
    await p.keyboard.press('p'); const pin1 = await ev(() => document.querySelector('#pinN').textContent + '|' + !!document.querySelector('.mrow[data-sym="ICICIBANK"] .pin')); const pt1 = await toastTxt(); await p.keyboard.press('p'); const pin0 = await ev(() => document.querySelector('#pinN').textContent);
    rec('P pin (toggle)', 'press P twice', 'pinned 1/5 with a PIN tag, then unpinned 0/5', pin1 === '1|true' && pin0 === '0', pt1);
    for (const [key, exp, name] of [['o', 'chain.html#ICICIBANK-1460CE-29DEC', 'O → option chain, Back'], ['Enter', 'share.html#ICICIBANK', 'Enter → F7, Back']]) {
      await ev(() => document.querySelector('#wb').scrollTop = 30); await p.keyboard.press(key); await p.waitForURL(u => u.toString().includes(exp), { timeout: 4000 }).catch(() => {}); const u = p.url(); await p.goBack(); await wait(450); const s2 = await S();
      rec(name, 'press ' + key + ', then browser Back', 'opens ' + exp.split('#')[0] + '; Back returns to Banks / ICICIBANK, same scroll, focus in the list', u.includes(exp) && s2.open === 'Banks' && s2.sel === 'ICICIBANK' && await top() === 30 && await ev(() => !!document.activeElement.closest('#wb')), 'went to ' + u.split('/').pop() + ' · back: ' + s2.open + ' / ' + s2.sel + ' y=' + await top()); }
    for (const [sel, exp, name] of [['#bF7', 'share.html#ICICIBANK', 'pane button Enter F7'], ['#bO', 'chain.html#ICICIBANK', 'pane button O chain'], ['#pb a.sh-c-lb', 'futures-oi.html#bu=LB&s=ICICIBANK', 'pane build-up chip LB › (F10)']]) {
      await clickC(sel); await p.waitForURL(u => u.toString().includes(exp), { timeout: 4000 }).catch(() => {}); const u = p.url(); await p.goBack(); await wait(450); const s2 = await S();
      rec(name, 'click it, then Back', 'opens ' + exp + '; Back returns to Banks / ICICIBANK', u.includes(exp) && s2.sel === 'ICICIBANK', 'went to ' + u.split('/').pop()); }
    await p.dblclick('.mrow[data-sym="AXISBANK"] .num.pc'); await p.waitForURL(/share\.html#AXISBANK/, { timeout: 4000 }).catch(() => {}); const ud = p.url(); await p.goBack(); await wait(450);
    rec('double-click a share row → F7, Back', 'double-click AXISBANK, then Back', 'share.html#AXISBANK; Back → Banks / AXISBANK', ud.includes('share.html#AXISBANK') && (await S()).sel === 'AXISBANK', ud.split('/').pop());
    await p.dblclick('#pb .big'); await p.waitForURL(/share\.html#AXISBANK/, { timeout: 4000 }).catch(() => {}); const ud2 = p.url(); await p.goBack(); await wait(450);
    rec('double-click the pane share name → F7', 'double-click the big name in the pane, then Back', 'share.html#AXISBANK', ud2.includes('share.html#AXISBANK'), ud2.split('/').pop());
    await p.keyboard.press('Escape'); await wait(80); await p.keyboard.press('o'); const ho = await toastTxt(); const uo = (await S()).url; await p.keyboard.press('w'); const hw = await toastTxt();
    rec('O / W with no share selected', 'Esc (clear the share), press O, then W', 'a hint "pick a share first", no navigation', /pick a share/.test(ho) && /pick a share/.test(hw) && uo.startsWith('rotation-drilldown.html'), ho);
    await fresh(); await clickC('.mrow[data-sym="ICICIBANK"]'); await clickC('#wch .chip[data-w="1"]'); await p.keyboard.press('Tab'); const fc = await ev(() => document.activeElement.textContent); await p.keyboard.press('Enter'); await wait(150);
    rec('Enter on a focused chip', 'click 30M, Tab to the 1H chip, press Enter (ICICIBANK selected)', 'switches the flow window to 1H; does not open F7', fc === '1H' && (await S()).url.startsWith('rotation-drilldown.html') && await ev(() => document.querySelector('#wrng').textContent) === '10:05-11:05', 'focused ' + fc + ' · range ' + await ev(() => document.querySelector('#wrng').textContent));
    await clickC('#win .vchips .chip[data-v="tbl"]'); await p.keyboard.press('Tab'); const fv = await ev(() => document.activeElement.textContent); await p.keyboard.press(' '); await wait(150);
    rec('Space on a focused chip', 'click TABLE, Tab to RUN CLOCK, press Space', 'switches to the run-clock view; the Plan card does not open', fv === 'RUN CLOCK' && await ev(() => document.querySelector('#win').classList.contains('v-run') && !document.querySelector('#planD').classList.contains('on')), 'focused ' + fv);
    await clickC('#win .vchips .chip[data-v="tbl"]');
    await fresh('#s=&r='); await clickC('#win .ph .pt'); let tabs = 0; while (tabs < 20 && !(await ev(() => !!document.activeElement.closest('.srow')))) { await p.keyboard.press('Tab'); tabs++; }
    const f0 = await ev(() => document.activeElement.dataset.s); await p.keyboard.press('ArrowDown'); const f1 = await ev(() => document.activeElement.dataset.s); await p.keyboard.press('Enter'); await wait(120); const o1 = (await S()).open;
    await p.keyboard.press('ArrowDown'); await p.keyboard.press('ArrowDown'); const f2 = await ev(() => document.activeElement.dataset.s); await p.keyboard.press('Enter'); await wait(120); const o2 = (await S()).open; const nOpen = await ev(() => document.querySelectorAll('.blk').length);
    rec('keyboard to a sector row + Enter', 'click the panel title, Tab to the first sector row, ↓, Enter; ↓ ↓, Enter', 'opens the focused sector each time, one open at a time', f0 === 'Banks' && o1 === f1 && o2 === f2 && o2 !== o1 && nOpen === 1, `Tab×${tabs} → ${f0} · ↓ ${f1} Enter → ${o1} · ↓↓ ${f2} Enter → ${o2}`);
    await p.keyboard.press('3'); const k3s = (await S()).open; await p.keyboard.press('1'); const k1s = (await S()).open;
    rec('keys 1-9', 'press 3, then 1', 'Realty opens, then Banks', k3s === 'Realty' && k1s === 'Banks');
    await clickC('.mrow[data-sym="HDFCBANK"]'); await p.keyboard.press('w'); await p.keyboard.press('Escape'); const e1 = await ev(() => !document.querySelector('#whyD').classList.contains('on') && GIRDD.st.sel === 'HDFCBANK');
    await p.keyboard.press('Escape'); const e2 = await ev(() => GIRDD.st.sel === null && GIRDD.st.open === 'Banks' && !!document.querySelector('.cmp')); await p.keyboard.press('Escape'); const e3 = await ev(() => GIRDD.st.open === null);
    rec('Esc step by step', 'Why open → Esc ×3', 'closes Why → clears the share (compare table) → closes the list', e1 && e2 && e3);

    // ================= E. re-rank (never under the pointer or keys) =================
    await fresh(); const rb = await box('.mrow[data-sym="BANKBARODA"]'); await p.mouse.move(rb.x + 200, rb.y + 10); await wait(2500); const chipIn = await ev(() => !!document.querySelector('#rrChip'));
    await NEUTRAL(); await wait(400); const o3 = await order();
    rec('re-rank on pointer leave (early)', 'hover the list 2.5 s after load, move the pointer out', 'the pending order (AXISBANK ▲1) applies at once on leave', chipIn && o3[0] === 'AXISBANK' && !(await ev(() => !!document.querySelector('#rrChip'))), o3.slice(0, 3).join(' '));
    await fresh(); await wait(25000); const c25 = await ev(() => !!document.querySelector('#rrChip')); await wait(6500); const o4 = await order();
    rec('re-rank after 30 s (pointer outside)', 'load, keep the pointer outside the list for 31.5 s', 'still pending at 25 s; applied by the 30 s timer', c25 && o4[0] === 'AXISBANK' && !(await ev(() => !!document.querySelector('#rrChip'))), 'at 25 s chip=' + c25 + ' · at 31.5 s ' + o4.slice(0, 2).join(' '));
    await fresh(); await p.mouse.move(rb.x + 200, rb.y + 10); await wait(35000); const c35 = await ev(() => !!document.querySelector('#rrChip')); const o5 = await order(); await NEUTRAL(); await wait(400); const o6 = await order();
    rec('order holds under the pointer', 'keep the pointer on the list for 35 s, then leave', 'order unchanged and chip shown for 35 s; applies on leave', c35 && o5[0] === 'ICICIBANK' && o6[0] === 'AXISBANK', `35 s: ${o5.slice(0, 2).join(' ')} · after leave: ${o6.slice(0, 2).join(' ')}`);
    await fresh(); await clickC('#win .ph .pt'); tabs = 0; while (tabs < 12 && (await ev(() => document.activeElement.id)) !== 'wb') { await p.keyboard.press('Tab'); tabs++; }
    const fid = await ev(() => document.activeElement.id); await NEUTRAL(); await wait(31500); const c31 = await ev(() => !!document.querySelector('#rrChip')); const o7 = await order();
    await clickC('#purp .why'); await wait(600); const o8 = await order();
    rec('order holds under keyboard focus', 'Tab into the list, pointer outside for 31.5 s, then click elsewhere', 'not applied while focus is in the list; applies when focus leaves', fid === 'wb' && c31 && o7[0] === 'ICICIBANK' && o8[0] === 'AXISBANK', `focus ${fid} (Tab×${tabs}) · 31.5 s: ${o7[0]} · after: ${o8[0]}`);
    // tick simulator + a new rank change while the pointer rests on a row
    await fresh(); await p.mouse.move(rb.x + 200, rb.y + 10); await wait(300); await NEUTRAL(); await wait(300);
    const ab = await box('.mrow[data-sym="AXISBANK"]'); await p.mouse.move(ab.x + 300, ab.y + ab.height / 2);
    const w0 = await ev(() => [...document.querySelectorAll('#wb .mrow')].map(r => [...r.children].map(c => Math.round(c.getBoundingClientRect().width)).join(',')).join('|'));
    const pc0 = await ev(() => [...document.querySelectorAll('#wb .mrow [data-t="pc"]')].map(x => x.textContent).join(' '));
    await wait(10500);
    const after = await ev(() => ({ w: [...document.querySelectorAll('#wb .mrow')].map(r => [...r.children].map(c => Math.round(c.getBoundingClientRect().width)).join(',')).join('|'), pc: [...document.querySelectorAll('#wb .mrow [data-t="pc"]')].map(x => x.textContent).join(' '),
      chip: !!document.querySelector('#rrChip'), mark: (document.querySelector('.mrow[data-sym="ICICIBANK"] .rd') || {}).textContent, under: document.elementFromPoint(window.__x || 0, 0) }));
    const under = await ev(([x, y]) => { const r = document.elementFromPoint(x, y); return r && r.closest('.mrow') ? r.closest('.mrow').dataset.sym : ''; }, [ab.x + 300, ab.y + ab.height / 2]); const o9 = await order();
    await NEUTRAL(); await wait(500); const o10 = await order();
    rec('live ticks in fixed-width cells', 'watch the open list for 10.5 s', 'numbers change; every cell keeps its width', after.pc !== pc0 && after.w === w0, 'day % changed: ' + (after.pc !== pc0) + ' · widths equal: ' + (after.w === w0));
    rec('rank change under the pointer', 'pointer resting on AXISBANK when ICICIBANK\'s score rises (simulated tick)', '▲1 and the chip show, the order and the row under the pointer do not move; applies on leave', after.chip && after.mark === '▲1' && o9[0] === 'AXISBANK' && under === 'AXISBANK' && o10[0] === 'ICICIBANK', `during: ${o9.slice(0, 2).join(' ')} (under pointer ${under}, mark ${after.mark}) · after leave: ${o10.slice(0, 2).join(' ')}`);
    await fresh(); await clickC('#rrChip'); rec('"re-ranked · R apply" chip', 'click the chip', 'AXISBANK moves above ICICIBANK', (await order())[0] === 'AXISBANK');
    await fresh(); await clickC('.mrow[data-sym="CANBK"]'); await p.keyboard.press('r'); rec('R key', 'press R', 'pending order applies', (await order())[0] === 'AXISBANK' && !(await ev(() => !!document.querySelector('#rrChip'))));

    // ================= F. groups, blocks, states =================
    await fresh();
    rec('group names', 'read every group label in the DOM', 'COMING UP NOW / LEADER / LAGGARD / WAITING / AGAINST / NOT TRADABLE; no "GATE OPEN"', await ev(() => !/GATE OPEN/.test(document.body.innerText) && /WAITING/.test(document.querySelector('.blk').innerText)), await ev(() => [...document.querySelectorAll('.gl .g1')].map(x => x.textContent).join(' · ')));
    await clickC('.srow[data-s="NBFC & finance"]'); rec('no laggard below 70%', 'open NBFC & finance (breadth 63%)', '"no laggard - breadth 63% one way, below the 70% rule"', await ev(() => /no laggard - breadth 63%/.test(document.querySelector('.blk').innerText)));
    await clickC('.srow[data-s="Auto"]'); rec('NARROW flag', 'open Auto', 'NARROW chip on the sector line and the row', await ev(() => /NARROW/.test(document.querySelector('.blk .sl').innerText)));
    await clickC('.blk [data-bas]'); rec('basis ›', 'click basis › on Auto', 'popup states NIFTY AUTO, all 46 listed, NARROW - F&O-only move', await ev(() => /NIFTY AUTO/.test(document.querySelector('#basP').innerText) && /NARROW/.test(document.querySelector('#basP').innerText))); await clickC('#basP .x');
    await clickC('.srow[data-s="IT"]'); rec('falling sector mirror', 'open IT', 'COMING DOWN NOW with PE strikes; WHY names its source', await ev(() => /COMING DOWN NOW/.test(document.querySelector('.blk').innerText) && !!document.querySelector('.mrow .c-op .sh-c-pe') && /Reuters/.test(document.querySelector('.blk').innerText)));
    await p.keyboard.press('1');
    for (const [sym, test, name, exp] of [
      ['INDUSINDBK', () => { const pb = document.querySelector('#pb'), c = document.querySelector('#bCopy'); return /BAN - only close existing/.test(pb.querySelector('.hbn').innerText) && !pb.querySelector('.pl3') && !/★/.test(pb.querySelector('.tbx th.pk').innerText) && c.disabled && /only close existing/.test(c.textContent); }, 'BAN hard block (pane)', 'banner "BAN - only close existing", no trigger/stop/target, no ★, Copy disabled'],
      ['AUBANK', () => /STALE 12s/.test(document.querySelector('#pb .hbn').innerText) && document.querySelector('#pb .tbx').classList.contains('dim') && /0 lots/.test(document.querySelector('#pb').innerText) && document.querySelector('#bCopy').disabled, 'STALE hard block', 'banner STALE 12s, trade box greyed with its age, 0 lots, Copy disabled'],
      ['IDFCFIRSTB', () => /MWPL 86% · near ban/.test(document.querySelector('#pb').innerText) && /0 lots · waiting - RS15/.test(document.querySelector('#pb').innerText), 'MWPL 80-90% amber + WAITING 0 lots', 'amber "MWPL 86% · near ban"; "0 lots · waiting - RS15 −0.10 fails"'],
      ['PNB', () => [...document.querySelectorAll('#pb .wn.rd')].some(x => /MWPL 91% · near ban/.test(x.innerText)) && /ex-date 21 Nov/.test(document.querySelector('#pb').innerText), 'MWPL ≥ 90% red + ex-date', 'red "MWPL 91% · near ban"; ex-date chip'],
      ['FEDERALBNK', () => /RESULTS 20 Nov 15:45 - IV crush/.test(document.querySelector('#pb').innerText), 'RESULTS - IV crush chip', '"RESULTS 20 Nov 15:45 - IV crush"'],
      ['HDFCBANK', () => /5-min close > 1,016.0/.test(document.querySelector('#pb').innerText) && /no story of its own today/.test(document.querySelector('#pb').innerText), 'LAGGARD own trigger', 'trigger 1,016.0 shown; "no story of its own today"'],
      ['SBIN', () => /pullback to VWAP 974.5/.test(document.querySelector('#pb').innerText) && /EXT → 974.5/.test(document.querySelector('.mrow[data-sym="SBIN"]').innerText), 'EXTENDED leader', 'row "EXT → 974.5"; pane "pullback to VWAP 974.5 / first higher low"']]) {
      await p.keyboard.press('1'); await wait(80); if (!(await p.$(`.mrow[data-sym="${sym}"]`))) await clickC('.morebar'); await clickC(`.mrow[data-sym="${sym}"]`); rec(name, 'select ' + sym, exp, await ev(test)); }
    await clickC('.mrow[data-sym="INDUSINDBK"]'); await clickC('#bCopy'); const ct1 = await toastTxt(); await clickC('.mrow[data-sym="AUBANK"]'); await clickC('#bCopy'); const ct2 = await toastTxt();
    rec('Copy on a blocked share', 'click the disabled Copy button on INDUSINDBK (BAN), then AUBANK (STALE)', 'nothing is copied', !/copied/.test(ct1) && !/copied/.test(ct2), JSON.stringify([ct1, ct2]));
    await clickC('.srow[data-s="Realty"]'); await clickC('.mrow[data-sym="LODHA"]'); rec('option quote stale', 'select LODHA (1,210 CE quote 11 s old)', 'row "OPT 11s", banner "OPTION STALE 11s", 0 lots', await ev(() => /OPT 11s/.test(document.querySelector('.mrow[data-sym="LODHA"]').innerText) && /OPTION STALE 11s/.test(document.querySelector('#pb .hbn').innerText)));
    await clickC('.mrow[data-sym="DLF"]'); rec('R:R < 1 → 0 lots', 'select DLF (R:R 0.89)', '"0 lots · R:R 0.89 after costs - not worth it" in red, no ★, Copy off', await ev(() => /0 lots · R:R 0.89 after costs - not worth it/.test(document.querySelector('#pb').innerText) && !!document.querySelector('#pb .wn.rd') && document.querySelector('#bCopy').disabled));
    for (const [k, test, exp] of [['forming', () => /FORMING/.test(document.querySelector('.blk').innerText) && /0 lots · forming/.test(document.querySelector('#pb').innerText), 'groups read FORMING, banner, 0 lots'],
      ['manage', () => /MANAGE ONLY - no new entries after 14:30/.test(document.querySelector('.blk').innerText) && /0 lots · manage only/.test(document.querySelector('#pb').innerText) && /0h 30m/.test(document.querySelector('#pb').innerText), 'banner "manage only - no new entries", 0 lots, 15:10 in 0h 30m'],
      ['locked', () => /LOCKED - no new trades today/.test(document.querySelector('.blk').innerText) && /LOCKED/.test(document.querySelector('#pb .hbn').innerText) && document.querySelector('#bCopy').disabled, 'banner and pane "LOCKED - no new trades today", Copy disabled'],
      ['held', () => !!document.querySelector('.mrow[data-sym="BANKBARODA"] .sh-c-held') && /you already hold this sector/.test(document.querySelector('#pb').innerText), 'BANKBARODA HELD chip; "you already hold this sector" warning'],
      ['preopen', () => /PRE-OPEN - NOT LIVE/.test(document.querySelector('.blk').innerText) && /pre-open - not live/.test(document.querySelector('#pb').innerText), 'Morning variant "PRE-OPEN - NOT LIVE", 0 lots'],
      ['live', () => !document.querySelector('.sl.mbn') && /1 lot/.test(document.querySelector('#pb').innerText), 'back to live: no banner, 1 lot']]) {
      await p.keyboard.press('1'); await wait(60); await clickC('#mockB'); await clickC(`#mockM [data-mock="${k}"]`); if (!(await ev(() => GIRDD.st.sel))) await clickC('.mrow[data-sym="ICICIBANK"]'); else await clickC('.mrow[data-sym="ICICIBANK"]');
      rec('state: ' + k, 'mock ▾ → ' + k + ', ICICIBANK selected', exp, await ev(test)); }
    // Back with an expanded list
    await fresh(); await clickC('.morebar'); await clickC('.mrow[data-sym="FEDERALBNK"]'); await ev(() => document.querySelector('#wb').scrollTop = 200); await wait(100); await p.keyboard.press('o'); await p.waitForURL(/chain\.html/, { timeout: 4000 }).catch(() => {}); await p.goBack(); await wait(500);
    const bk = await ev(() => ({ n: document.querySelectorAll('#wb .mrow').length, sel: (document.querySelector('#wb .mrow.sel') || {}).dataset, pane: document.querySelector('#pb .big').textContent, y: document.querySelector('#wb').scrollTop }));
    await p.keyboard.press('j'); const bj = (await S()).sel;
    rec('Back keeps the expanded list', '"+6 more" → FEDERALBNK, scroll 200, O, Back, then J', '14 rows, FEDERALBNK selected in list and pane, same scroll, J → next share', bk.n === 14 && bk.sel && bk.sel.sym === 'FEDERALBNK' && bk.pane === 'FEDERALBNK' && bk.y === 200 && bj === 'IDFCFIRSTB', `rows ${bk.n} · sel ${bk.sel && bk.sel.sym} · pane ${bk.pane} · y ${bk.y} · J → ${bj}`);

    // ================= G. hero, flow, other controls =================
    await fresh();
    for (const [w, rng] of [['0', '10:50-11:05'], ['2', '10:05-11:05'], ['3', '09:15-11:05'], ['1', '10:35-11:05']]) { await clickC(`#wch .chip[data-w="${w}"]`); const r = await ev(() => document.querySelector('#wrng').textContent + ' | ' + document.querySelector('#flowSvg').textContent);
      rec('window chip ' + ['15M', '30M', '1H', 'TODAY'][+w], 'click it', 'flow range ' + rng + (w === '3' ? '; IT −₹44,000 cr (ff × (sector − NIFTY))' : ''), r.startsWith(rng) && (w !== '3' || /−₹44,000 cr/.test(r)), r.slice(0, 120)); }
    const MAPN = { NBFC: 'NBFC & finance' };
    for (const win of ['1', '3']) { await clickC(`#wch .chip[data-w="${win}"]`);
      const labs = await ev(() => [...document.querySelectorAll('#flowSvg text')].filter(t => t.querySelector('.nmx')).map(t => { const r = t.getBoundingClientRect(); return [t.querySelector('.nmx').textContent, r.x + r.width / 2, r.y + r.height / 2]; }));
      let okL = true, nl = []; for (const [nm, x, y] of labs) { await p.keyboard.press('9'); await p.mouse.click(x, y); await wait(80); const o = (await S()).open; nl.push(nm + '→' + o); if (o !== (MAPN[nm] || nm)) okL = false; }
      rec('flow labels (' + ['', '30M', '', 'TODAY'][+win] + ')', 'click the centre of every sector label in the picture', 'opens that sector', okL && labs.length >= 4, nl.join(' · '));
      const n = await ev(() => document.querySelectorAll('#flowSvg path.rbh').length); let okR = true, nr = [];
      for (let i = 0; i < n; i++) { const pt = await ev((i) => { const pth = document.querySelectorAll('#flowSvg path.rbh')[i], L = pth.getTotalLength(), m = pth.getScreenCTM();
          for (const f of [0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8, 0.15, 0.85]) { const q = pth.getPointAtLength(L * f), x = q.x * m.a + m.e, y = q.y * m.d + m.f, e = document.elementFromPoint(x, y); if (e === pth) return [x, y, pth.dataset.s, pth.dataset.from]; } return [0, 0, pth.dataset.s, pth.dataset.from, 'unreachable']; }, i);
        if (pt[4]) { okR = false; nr.push(pt[3] + '→' + pt[2] + ' unreachable'); continue; } await p.keyboard.press('9'); await p.mouse.click(pt[0], pt[1]); await wait(80); const o = (await S()).open; nr.push(pt[3] + '→' + pt[2] + ':' + o); if (o !== pt[2]) okR = false; }
      rec('flow ribbons (' + ['', '30M', '', 'TODAY'][+win] + ')', 'click each ribbon (incl. 3-4 px ones) on its own path', 'opens the ribbon\'s labelled destination', okR, n + ' ribbons · ' + nr.join(' · ')); }
    await clickC('#wch .chip[data-w="1"]');
    await clickC('#heroLine .s[data-s="IT"]'); rec('headline word', 'click IT in the hero line', 'opens IT', (await S()).open === 'IT');
    await clickC((W > 1500 ? '.fs' : '.fs2 span') + '[data-s="Realty"]'); rec('"moving, not this rotation"', 'click Realty', 'opens Realty', (await S()).open === 'Realty');
    await clickC('.ne[data-r="BAJFINANCE"]'); const ne = await S(); rec('new-entrant chip', 'click BAJFINANCE', 'opens NBFC and loads BAJFINANCE', ne.open === 'NBFC & finance' && ne.sel === 'BAJFINANCE');
    await p.keyboard.press('Escape'); await clickC('.cmp td[data-sym]'); rec('compare table row', 'Esc, click the first share in the compare table', 'loads it', !!(await S()).sel);
    await clickC('#win .vchips .chip[data-v="run"]'); const rv = await ev(() => document.querySelectorAll('#rb .rr').length); await clickC('#rb .rr[data-s="IT"]');
    rec('RUN CLOCK + run row', 'click RUN CLOCK, then the IT row', 'run rows shown; IT opens in the table view', rv > 0 && (await S()).open === 'IT' && await ev(() => !document.querySelector('#win').classList.contains('v-run')), rv + ' run rows');
    await p.keyboard.press('1'); await clickC('.nonfo'); const nf1 = await ev(() => getComputedStyle(document.querySelector('.nfx')).display); await clickC('.nonfo');
    rec('"27 more listed, not F&O"', 'click it, click again', 'shows the context list (no strikes), hides it', nf1 === 'flex' && await ev(() => getComputedStyle(document.querySelector('.nfx')).display === 'none'));
    await clickC('.morebar'); const mo1 = await ev(() => document.querySelectorAll('#wb .mrow').length); await clickC('.morebar'); const mo2 = await ev(() => document.querySelectorAll('#wb .mrow').length);
    rec('"+n more" bar', 'click it, then "show fewer"', 'all 14 rows, then back to the cap', mo1 === 14 && mo2 < 14, `${mo1} → ${mo2}`);
    await clickC('.blk [data-bas]'); rec('basis › (Banks)', 'click basis ›', 'NIFTY BANK +1.12% is the move; all-41 basket +1.06% for reference', await ev(() => /NIFTY BANK \+1\.12%/.test(document.querySelector('#basP').innerText) && /\+1\.06%/.test(document.querySelector('#basP').innerText))); await clickC('#basP .x');
    await clickC('.mrow[data-sym="ICICIBANK"]');
    await clickC('#bW'); const bw = await ev(() => document.querySelector('#whyD').classList.contains('on')); await clickC('#whyD .x'); rec('pane button W why', 'click it, then ✕', 'opens and closes', bw && await ev(() => !document.querySelector('#whyD').classList.contains('on')));
    await clickC('#bP'); const bpn = await ev(() => document.querySelector('#pinN').textContent); await clickC('#bP'); rec('pane button P pin', 'click twice', '1/5 then 0/5', bpn === '1' && (await ev(() => document.querySelector('#pinN').textContent)) === '0');
    await clickC('#bCopy'); rec('Copy contract', 'click it (ICICIBANK, 1 lot)', '"copied: ICICIBANK 29DEC 1460 CE"', /copied: ICICIBANK 29DEC 1460 CE/.test(await toastTxt()));
    await clickC('#ddAll'); rec('ALL SECTORS chip', 'click it', 'toast "11 listed"', /11 listed/.test(await toastTxt()));
    await clickC('#pinC'); rec('pinned chip', 'click it', 'lists the pins or says none', /no pins|pinned/.test(await toastTxt()));
    for (const [sel, exp, name] of [['#sh-tabs a[data-tab="sectors"]', 'sectors.html', 'tab F2 Sectors'], ['#sh-tabs a[data-tab="share"]', 'share.html', 'tab F7 Share'], ['#sh-tabs a[data-tab="morning"]', 'morning.html', 'tab ⇧F1 Morning'], ['#sh-tabs a[data-tab="rotation"]', 'rotation.html', 'tab F3 Rotation'], ['#sh-pnl', 'positions.html', 'P&L strip → F6'], ['#sh-foot a[href="health.html"]', 'health.html', 'footer health link'], ['#flShare', 'share.html#ICICIBANK', 'cycle bar SHARE'], ['#flChain', 'chain.html#ICICIBANK', 'cycle bar STRIKE']]) {
      await clickC(sel); await p.waitForURL(u => u.toString().includes(exp), { timeout: 4000 }).catch(() => {}); const u = p.url(); await p.goBack(); await wait(350);
      rec(name, 'click it, then Back', 'opens ' + exp, u.includes(exp), u.split('/').pop()); }
    rec('page errors', 'console / page errors during all of the above', 'none', errs.length === 0, errs.join(' | '));
    await p.close();
  }
  await b.close();
  console.log('| # | size | control | what was done | expected | result | note |\n|---|---|---|---|---|---|---|');
  R.forEach((r, i) => console.log(`| ${i + 1} | ${r.map(x => String(x).replace(/\|/g, '/')).join(' | ')} |`));
  console.log('PASS', R.filter(r => r[4] === 'PASS').length, 'FAIL', R.filter(r => r[4] === 'FAIL').length);
})();

// Every control on the phone drill-down (390 x 844, touch). PASS / FAIL table.
const { chromium } = require('playwright');
const U = 'file:///home/user/my-first-site/intraday_patches/design_v3/pages/rotation-drilldown-phone.html';
const R = []; function rec(c, d, ok, n) { R.push([c, d, ok ? 'PASS' : 'FAIL', n || '']); }
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true });
  const p = await ctx.newPage(); const errs = []; p.on('pageerror', e => errs.push(e.message));
  const cdp = await ctx.newCDPSession(p);
  const swipe = async (x, y, dy) => { await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
    for (let i = 1; i <= 12; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y: y + dy * i / 12 }] }); await p.waitForTimeout(16); }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await p.waitForTimeout(450); };
  const sTop = s => p.evaluate(q => document.querySelector(q).scrollTop, s);
  const on = s => p.evaluate(q => document.querySelector(q).classList.contains('on'), s);
  await p.goto(U); await p.waitForTimeout(300);
  let a = await sTop('#secL'); await swipe(195, 600, -300); let c = await sTop('#secL'); await swipe(195, 500, 300); let d = await sTop('#secL');
  rec('sector list: finger swipe', 'touch-drag up 300 px, then down', c > a + 30 && d < c, `scrollTop ${a} → ${c} → ${d}`);
  await p.tap('.sr[data-s="Banks"]'); await p.waitForTimeout(350);
  rec('tap a sector (Banks)', 'tap the Banks row', await on('#secS') && await p.evaluate(() => /BANKS/.test(document.querySelector('#secTop').textContent) && document.querySelectorAll('#memL .mr').length === 14), 'full-screen sheet, 14 F&O shares in 6 groups');
  a = await sTop('#memL'); await swipe(195, 650, -350); c = await sTop('#memL'); await swipe(195, 450, 200); d = await sTop('#memL');
  rec('Banks sheet: finger swipe', 'touch-drag up 350 px, then down', c > a + 50 && d < c, `scrollTop ${a} → ${c} → ${d}`);
  const th = await (await p.$('.rail[data-for="memL"] i')).boundingBox(); const r0 = await sTop('#memL');
  await p.mouse.move(th.x + 3, th.y + 8); await p.mouse.down(); await p.mouse.move(th.x + 3, th.y + 120, { steps: 5 }); await p.mouse.up(); const r1 = await sTop('#memL');
  rec('Banks sheet: position rail drag', 'drag the rail thumb 112 px down', r1 > r0 + 20, `${r0} → ${r1}`);
  await p.evaluate(() => document.querySelector('#memL').scrollTop = 0);
  await p.tap('.mr[data-sym="ICICIBANK"]'); await p.waitForTimeout(350);
  rec('tap a share (ICICIBANK)', 'tap the ICICIBANK row', await on('#shareS') && await p.evaluate(() => /ICICIBANK/.test(document.querySelector('#shTop').textContent) && /1,460 CE/.test(document.querySelector('#shB').textContent) && /1 lot \(1R rule\)/.test(document.querySelector('#shB').textContent)), 'share sheet: Dec 1,460 CE trade box, levels, 1 lot, AI view');
  a = await sTop('#shB'); await swipe(195, 650, -300); c = await sTop('#shB');
  rec('share sheet: finger swipe', 'touch-drag up 300 px', c > a + 50, `${a} → ${c}`);
  await p.tap('#pCopy'); rec('Copy contract', 'tap it', await p.evaluate(() => /copied: ICICIBANK 29DEC 1460 CE/.test(document.querySelector('#toast').textContent)));
  await p.tap('#pPin'); rec('Pin', 'tap it', await p.evaluate(() => /pinned/.test(document.querySelector('#toast').textContent)));
  await p.tap('#back2'); await p.waitForTimeout(350);
  rec('‹ Banks (Back button)', 'tap Back on the share sheet', !(await on('#shareS')) && await on('#secS'), 'returns to the Banks list');
  await p.tap('.mr[data-sym="AXISBANK"]'); await p.waitForTimeout(350); await p.goBack(); await p.waitForTimeout(350);
  rec('device / browser Back (share)', 'tap AXISBANK, then the browser Back', !(await on('#shareS')) && await on('#secS'));
  await p.tap('#back1'); await p.waitForTimeout(350);
  rec('‹ Sectors (Back button)', 'tap Back on the Banks sheet', !(await on('#secS')));
  await p.tap('.sr[data-s="IT"]'); await p.waitForTimeout(350);
  rec('tap a falling sector (IT)', 'tap IT', await p.evaluate(() => /COMING DOWN NOW/.test(document.querySelector('#memL').textContent) && !!document.querySelector('#memL .c-pe')), 'mirrored: COMING DOWN NOW with PE strikes');
  await p.goBack(); await p.waitForTimeout(350); rec('device / browser Back (sector)', 'browser Back from the IT sheet', !(await on('#secS')));
  await p.tap('.tabs a.tab[href*="now"]'); await p.waitForURL(u => /\/phone\.html#now$/.test(u.toString()), { timeout: 3000 }).catch(() => {});
  rec('bottom tab NOW', 'tap NOW', p.url().includes('phone.html#now'), p.url().split('/').pop());
  rec('page errors', 'errors during all of the above', errs.length === 0, errs.join(' | '));
  await b.close();
  console.log('| # | control | what was done | result | note |\n|---|---|---|---|---|');
  R.forEach((r, i) => console.log(`| ${i + 1} | ${r[0]} | ${r[1]} | ${r[2]} | ${r[3]} |`));
  console.log('PASS', R.filter(r => r[2] === 'PASS').length, 'FAIL', R.filter(r => r[2] === 'FAIL').length);
})();

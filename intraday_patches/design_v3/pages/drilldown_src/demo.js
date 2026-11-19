// Controls demo videos (Playwright recordVideo, slowMo) + labelled step strips, laptop 1366 x 768 and phone 390 x 844.
// Mouse on the laptop; FINGER (CDP touch events) on the phone, including the rail drag he complained about.
// node demo.js  ->  ../demo_laptop.webm, ../demo_phone.webm, ../demo_laptop_steps.png, ../demo_phone_steps.png
const fs = require('fs'), path = require('path'), os = require('os');
const { chromium } = require(require.resolve('playwright', { paths: [__dirname, '/opt/node-tools/node_modules'] }));
const OUT = path.resolve(__dirname, '..') + '/', TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'gir-dd-demo-'));
const PAGE = 'file://' + OUT + 'rotation-drilldown.html', PHONE = 'file://' + OUT + 'rotation-drilldown-phone.html';
// a visible pointer / finger dot and a caption, for the video only (the page itself has neither)
const OVERLAY = `(() => { addEventListener('DOMContentLoaded', () => {
  const c = document.createElement('div'); c.id = '__cur'; c.style.cssText = 'position:fixed;z-index:99999;width:16px;height:16px;margin:-8px 0 0 -8px;border-radius:50%;background:rgba(255,214,10,.85);box-shadow:0 0 0 3px rgba(0,0,0,.6);pointer-events:none;left:-20px;top:-20px;transition:transform .08s';
  const cap = document.createElement('div'); cap.id = '__cap'; cap.style.cssText = 'position:fixed;z-index:99999;left:50%;transform:translateX(-50%);bottom:8px;max-width:92%;background:rgba(10,12,16,.92);border:1px solid #F5C518;color:#F5C518;font:600 14px Inter,system-ui;padding:6px 10px;border-radius:4px;pointer-events:none;display:none;white-space:nowrap';
  document.body.append(c, cap);
  const mv = e => { const t = e.touches ? e.touches[0] : e; if (!t) return; c.style.left = t.clientX + 'px'; c.style.top = t.clientY + 'px'; };
  addEventListener('pointermove', mv, true); addEventListener('pointerdown', mv, true); addEventListener('touchstart', mv, true); addEventListener('touchmove', mv, true);
  addEventListener('pointerdown', () => c.style.transform = 'scale(1.7)', true); addEventListener('pointerup', () => c.style.transform = '', true);
  window.__caption = t => { cap.textContent = t; cap.style.display = t ? 'block' : 'none'; };
}); })();`;
async function strip(b, steps, file, w, h, cols, scale) {
  const p = await b.newPage({ viewport: { width: 100, height: 100 } });
  const cw = Math.round(w * scale), ch = Math.round(h * scale);
  await p.setContent('<body style="margin:0;background:#05070A;font:600 15px Inter,system-ui;color:#E7EAEE"><div style="display:grid;grid-template-columns:repeat(' + cols + ',' + cw + 'px);gap:14px;padding:14px">' +
    steps.map(([f, l]) => '<div><div style="height:26px;line-height:26px;color:#F5C518;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;width:' + cw + 'px">' + l.replace(/&/g, '&amp;').replace(/</g, '&lt;') + '</div><img src="data:image/png;base64,' + fs.readFileSync(f).toString('base64') + '" style="display:block;width:' + cw + 'px;height:' + ch + 'px;border:1px solid #323A45"></div>').join('') + '</div></body>');
  const bb = await (await p.$('body > div')).boundingBox(); await p.setViewportSize({ width: Math.ceil(bb.width), height: Math.ceil(bb.height) });
  await p.screenshot({ path: file, fullPage: true }); await p.close(); }
(async () => {
  const b = await chromium.launch({ slowMo: 250 });
  // ---------------- laptop ----------------
  const LS = [];
  {
    const ctx = await b.newContext({ viewport: { width: 1366, height: 768 }, deviceScaleFactor: 1, recordVideo: { dir: TMP, size: { width: 1366, height: 768 } } });
    await ctx.addInitScript(OVERLAY);
    const p = await ctx.newPage(); const cap = t => p.evaluate(x => window.__caption && window.__caption(x), t);
    const shot = async label => { await cap(''); const f = path.join(TMP, 'L' + LS.length + '.png'); await p.screenshot({ path: f }); LS.push([f, LS.length + '  ' + label]); await cap(label); };
    const pause = ms => p.waitForTimeout(ms); const bx = async q => (await p.$(q)).boundingBox();
    const moveClick = async q => { await p.$eval(q, e => e.scrollIntoView({ block: 'nearest' })); await pause(150); const bb = await bx(q); await p.mouse.move(bb.x + Math.min(160, bb.width / 2), bb.y + bb.height / 2, { steps: 12 }); await p.mouse.click(bb.x + Math.min(160, bb.width / 2), bb.y + bb.height / 2); await pause(500); };
    await p.goto(PAGE + '#s=&r='); await pause(500); await p.mouse.move(300, 190);
    await cap('F3 Rotation · no sector open'); await shot('start: no sector open'); await pause(600);
    await cap('click the Banks sector row'); await moveClick('.srow[data-s="Banks"]'); await shot('click Banks: its F&O shares open in place, rows below pushed down');
    await cap('drag the scrollbar thumb with the mouse'); let th = await bx('.rail[data-for="wb"] .trk i');
    await p.mouse.move(th.x + th.width / 2, th.y + 12, { steps: 10 }); await p.mouse.down(); await p.mouse.move(th.x + th.width / 2, th.y + 130, { steps: 14 }); await shot('drag the list scrollbar (12 px thumb) down with the mouse'); await p.mouse.up(); await pause(300);
    th = await bx('.rail[data-for="wb"] .trk i'); await p.mouse.move(th.x + th.width / 2, th.y + 12, { steps: 6 }); await p.mouse.down(); await p.mouse.move(th.x + 120, th.y - 300, { steps: 12 }); await p.mouse.up(); await cap('…and back up, even off the rail'); await pause(500);
    await cap('click the track, then ▼'); const tk = await bx('.rail[data-for="wb"] .trk'); await p.mouse.move(tk.x + 5, tk.y + tk.height - 10, { steps: 8 }); await p.mouse.click(tk.x + 5, tk.y + tk.height - 10); await pause(400); await moveClick('.rail[data-for="wb"] .rb.u'); await pause(200); await p.mouse.click(tk.x + 5, tk.y + 4); await pause(300);
    await cap('click ICICIBANK: the pane loads'); await moveClick('.mrow[data-sym="ICICIBANK"]'); await shot('ICICIBANK: 2.1▲ RVOL, +0.92↗ vs sec in full at 1366; 1,460 CE chip 12 px, 1 lot');
    await cap('PageDown / End / Home on the list (after a click)'); await p.keyboard.press('PageDown'); await pause(300); await p.keyboard.press('End'); await pause(300); await shot('PageDown, End: the list pages; the thumb follows'); await p.keyboard.press('Home'); await pause(300);
    await cap('the pane chart: TRIG / STOP / TGT, OR inside its box'); await p.$eval('#pb .mchart', e => e.scrollIntoView({ block: 'center' })); await pause(400); await shot('pane chart: TRIG / STOP / TGT labels, OR label clear of the box border'); await p.$eval('#pb', e => e.scrollTop = 0); await pause(200);
    await cap('the pointer leaves the list: the pending re-rank applies'); await p.mouse.move(300, 190, { steps: 10 }); await pause(700); await shot('pointer leaves the list: AXISBANK ▲1 applies (never under the pointer)');
    await cap('J J J … into the "+6 more" fold'); for (let i = 0; i < 6; i++) { await p.keyboard.press('j'); await pause(260); } await shot('J reaches the hidden shares: the fold opens, the pane follows');
    await cap('W: why it is moving'); await p.keyboard.press('w'); await pause(500); await shot('W: Why - today UNEXPLAINED, background 18 Nov'); await p.keyboard.press('Escape'); await pause(300);
    await cap('O: the option chain at the December strike'); await p.keyboard.press('o'); await p.waitForURL(/chain\.html/); await pause(700); await shot('O: option chain at the Dec strike');
    await p.goBack(); await pause(700); await cap('Back: same sector, same expanded list, same row'); await shot('Back: same sector, same (expanded) list, same row');
    await cap('a banned share: no plan, Copy disabled'); await p.keyboard.press('1'); await pause(200); const ib = await p.$('.mrow[data-sym="INDUSINDBK"]'); if (!ib) await moveClick('.morebar'); await moveClick('.mrow[data-sym="INDUSINDBK"]'); await shot('INDUSINDBK: "BAN - only close existing", no plan, no ★, Copy off');
    await cap('the flow: every ribbon opens its own sector'); await moveClick('#wch .chip[data-w="3"]'); const rbn = await p.$$('#flowSvg path.rb2[data-s="Realty"]'); const rr = await rbn[0].boundingBox(); await p.mouse.move(rr.x + rr.width * 0.6, rr.y + rr.height / 2, { steps: 12 }); await p.mouse.click(rr.x + rr.width * 0.6, rr.y + rr.height / 2); await pause(600);
    await shot('TODAY: mcap vs NIFTY ₹cr (IT −₹44,000 cr); the thin Realty ribbon opens Realty');
    await cap('mockup states: loss LOCKED'); await moveClick('#mockB'); await moveClick('#mockM [data-mock="locked"]'); await p.keyboard.press('1'); await pause(200); await moveClick('.mrow[data-sym="ICICIBANK"]'); await shot('LOCKED: strip TODAY −₹10,000 · TRADES 3 of 3 · lock ₹0 = banner = pane; Copy off');
    await moveClick('#mockB'); await moveClick('#mockM [data-mock="live"]'); await pause(600);
    const v = await p.video(); await ctx.close(); fs.copyFileSync(await v.path(), OUT + 'demo_laptop.webm');
  }
  // ---------------- phone ----------------
  const PS = [];
  {
    const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true, recordVideo: { dir: TMP, size: { width: 390, height: 844 } } });
    await ctx.addInitScript(OVERLAY);
    const p = await ctx.newPage(); const cdp = await ctx.newCDPSession(p); const cap = t => p.evaluate(x => window.__caption && window.__caption(x), t);
    const shot = async label => { await cap(''); const f = path.join(TMP, 'P' + PS.length + '.png'); await p.screenshot({ path: f }); PS.push([f, PS.length + '  ' + label]); await cap(label); };
    const T = (x, y) => [{ x, y, radiusX: 6, radiusY: 6, force: 1, id: 1 }];
    const tap = async (x, y) => { await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: T(x, y) }); await p.waitForTimeout(80); await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await p.waitForTimeout(500); };
    const drag = async (x, y, dy, mid) => { await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: T(x, y) }); for (let i = 1; i <= 16; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: T(x, y + dy * i / 16) }); await p.waitForTimeout(30); if (mid && i === 12) await mid(); }
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await p.waitForTimeout(500); };
    const bx = async q => (await p.$(q)).boundingBox(), tapEl = async q => { const bb = await bx(q); await tap(bb.x + bb.width / 2, bb.y + bb.height / 2); };
    const thumb = async l => { const bb = await bx(`.rail[data-for="${l}"] i`); return [bb.x + bb.width / 2, bb.y + bb.height / 2]; };
    await p.goto(PHONE); await p.waitForTimeout(600); await shot('sector list (Banks UP, CE 5)');
    await cap('finger on the scrollbar: drag it'); let [x, y] = await thumb('secL'); await drag(x, y, 110, () => shot('FINGER drag on the 12 px thumb (28 px rail): the list scrolls')); await p.waitForTimeout(300);
    [x, y] = await thumb('secL'); await drag(x, y, -110); await cap('tap Banks'); await tapEl('.sr[data-s="Banks"]'); await shot('tap Banks: full-screen sheet at once, 7 shares in view');
    await cap('tap WHY ›'); await tapEl('#whyB'); await shot('WHY ›: today UNEXPLAINED · background 18 Nov · expiry wording'); await tapEl('#whyB');
    await cap('drag the sheet scrollbar with a finger'); [x, y] = await thumb('memL'); await drag(x, y, 150, () => shot('finger drag on the Banks sheet rail')); await p.waitForTimeout(200);
    const rb = await bx('.rail[data-for="memL"]'); await cap('tap the track: pages up, nothing else opens'); await tap(rb.x + rb.width / 2, rb.y + 12); await p.waitForTimeout(300);
    await cap('tap ICICIBANK'); await p.evaluate(() => document.querySelector('#memL').scrollTop = 0); await p.waitForTimeout(200); await tapEl('.mr[data-sym="ICICIBANK"]'); await shot('tap ICICIBANK: the share sheet');
    await cap('Copy from the action bar - no scrolling'); await tapEl('#pCopy'); await p.waitForTimeout(200); await shot('Copy 1,460 CE in the first view: "copied: ICICIBANK 29DEC 1460 CE"');
    await cap('swipe the share sheet: the action bar stays'); await drag(180, 650, -420); await shot('swipe: plan, lots, chart - Copy / Pin stay on screen'); await drag(180, 300, 420);
    await cap('‹ Back: the same list, same row'); await tapEl('#back2'); await shot('Back: the Banks list again, ICICIBANK marked');
    await cap('a banned share'); await p.evaluate(() => { const r = document.querySelector('#memL .mr[data-sym="INDUSINDBK"]'); document.querySelector('#memL').scrollTop = r.offsetTop - 80; }); await p.waitForTimeout(300); await tapEl('.mr[data-sym="INDUSINDBK"]'); await shot('INDUSINDBK: "BAN - only close existing" first, no plan');
    await tapEl('#back2'); await tapEl('#back1'); await cap('‹ Back again: the sector list'); await shot('Back: the sector list'); await p.waitForTimeout(600);
    const v = await p.video(); await ctx.close(); fs.copyFileSync(await v.path(), OUT + 'demo_phone.webm');
  }
  await strip(b, LS, OUT + 'demo_laptop_steps.png', 1366, 768, 3, 0.42);
  await strip(b, PS, OUT + 'demo_phone_steps.png', 390, 844, 6, 0.55);
  await b.close();
  fs.rmSync(TMP, { recursive: true, force: true });
  console.log('videos + strips done:', LS.length, 'laptop steps,', PS.length, 'phone steps');
})();

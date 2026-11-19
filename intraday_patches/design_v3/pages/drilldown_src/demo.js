// Controls demo videos (Playwright recordVideo, slowMo 400) + labelled step screenshots for the laptop (1366 x 768) and phone.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const OUT = '/home/user/my-first-site/intraday_patches/design_v3/pages/', TMP = __dirname + '/vid';
const PAGE = 'file://' + OUT + 'rotation-drilldown.html', PHONE = 'file://' + OUT + 'rotation-drilldown-phone.html';
// a visible pointer / finger dot and a caption, for the video only (the page itself has neither)
const OVERLAY = `(() => { addEventListener('DOMContentLoaded', () => {
  const c = document.createElement('div'); c.id = '__cur'; c.style.cssText = 'position:fixed;z-index:99999;width:14px;height:14px;margin:-7px 0 0 -7px;border-radius:50%;background:rgba(255,214,10,.85);box-shadow:0 0 0 3px rgba(0,0,0,.6);pointer-events:none;left:-20px;top:-20px;transition:transform .08s';
  const cap = document.createElement('div'); cap.id = '__cap'; cap.style.cssText = 'position:fixed;z-index:99999;right:12px;bottom:28px;max-width:60%;background:rgba(10,12,16,.92);border:1px solid #F5C518;color:#F5C518;font:600 14px Inter,system-ui;padding:6px 10px;border-radius:4px;pointer-events:none;display:none';
  document.body.append(c, cap);
  const mv = e => { const t = e.touches ? e.touches[0] : e; if (!t) return; c.style.left = t.clientX + 'px'; c.style.top = t.clientY + 'px'; };
  addEventListener('mousemove', mv, true); addEventListener('touchstart', mv, true); addEventListener('touchmove', mv, true);
  addEventListener('mousedown', () => c.style.transform = 'scale(1.6)', true); addEventListener('mouseup', () => c.style.transform = '', true);
  addEventListener('touchstart', () => c.style.transform = 'scale(1.8)', true); addEventListener('touchend', () => c.style.transform = '', true);
  window.__caption = t => { cap.textContent = t; cap.style.display = t ? 'block' : 'none'; };
}); })();`;
(async () => {
  fs.rmSync(TMP, { recursive: true, force: true }); fs.mkdirSync(TMP, { recursive: true });
  const b = await chromium.launch({ slowMo: 400 });
  // ---------------- laptop ----------------
  {
    const ctx = await b.newContext({ viewport: { width: 1366, height: 768 }, deviceScaleFactor: 1, recordVideo: { dir: TMP, size: { width: 1366, height: 768 } } });
    await ctx.addInitScript(OVERLAY);
    const p = await ctx.newPage(); const steps = [];
    const cap = t => p.evaluate(x => window.__caption && window.__caption(x), t);
    const shot = async label => { await cap(''); const f = TMP + '/L' + steps.length + '.png'; await p.screenshot({ path: f }); steps.push([f, label]); await cap(label); };
    const pause = ms => p.waitForTimeout(ms);
    await p.goto(PAGE + '#s=&r='); await pause(600); await p.mouse.move(683, 500);
    await cap('F3 Rotation · no sector open'); await shot('0  start: no sector open'); await pause(800);
    await cap('click the Banks sector row'); const br = await p.$('.srow[data-s="Banks"]'); const bb = await br.boundingBox(); await p.mouse.move(bb.x + 200, bb.y + bb.height / 2, { steps: 12 }); await p.mouse.click(bb.x + 200, bb.y + bb.height / 2); await pause(700);
    await shot('1  click Banks: its F&O shares open, rows below pushed down'); await pause(900);
    await cap('drag the scrollbar thumb down with the mouse'); let th = await (await p.$('.rail[data-for="wb"] .trk i')).boundingBox();
    await p.mouse.move(th.x + th.width / 2, th.y + 12, { steps: 10 }); await p.mouse.down(); await p.mouse.move(th.x + th.width / 2, th.y + 140, { steps: 14 }); await shot('2  drag the list scrollbar thumb down (mouse)'); await p.mouse.up(); await pause(500);
    await cap('…and back up'); th = await (await p.$('.rail[data-for="wb"] .trk i')).boundingBox(); await p.mouse.move(th.x + th.width / 2, th.y + 12, { steps: 6 }); await p.mouse.down(); await p.mouse.move(th.x + th.width / 2, th.y - 200, { steps: 14 }); await p.mouse.up(); await pause(500);
    await cap('mouse wheel down / up over the list'); await p.mouse.move(420, 600, { steps: 10 }); for (let i = 0; i < 3; i++) { await p.mouse.wheel(0, 60); await pause(150); } await shot('3  mouse wheel scrolls the list'); for (let i = 0; i < 4; i++) { await p.mouse.wheel(0, -80); await pause(150); }
    await cap('click ICICIBANK: the share pane loads'); const ic = await (await p.$('.mrow[data-sym="ICICIBANK"]')).boundingBox(); await p.mouse.move(ic.x + 60, ic.y + ic.height / 2, { steps: 12 }); await p.mouse.click(ic.x + 60, ic.y + ic.height / 2); await pause(700);
    await shot('4  click ICICIBANK: the pane loads (Dec 1,460 CE, 1 lot)'); await pause(900);
    await cap('J: next share, the pane follows'); await p.keyboard.press('j'); await pause(600); await shot('5  J: AXISBANK, the pane follows'); await cap('↓ next · K / ↑ back'); await p.keyboard.press('ArrowDown'); await pause(500); await p.keyboard.press('k'); await pause(500); await p.keyboard.press('ArrowUp'); await pause(700);
    await cap('W: why it is moving'); await p.keyboard.press('w'); await pause(700); await shot('6  W: the Why drawer'); await pause(700);
    await cap('Esc closes the drawer'); await p.keyboard.press('Escape'); await pause(600);
    await cap('O: the option chain at the December strike'); await p.keyboard.press('o'); await p.waitForURL(/chain\.html/); await pause(900); await shot('7  O: option chain (chain.html#ICICIBANK-1460CE-29DEC)'); await pause(600);
    await p.goBack(); await pause(800); await cap('Back: same sector, same list, same row'); await shot('8  Back: same sector, list and row'); await pause(900);
    await cap('Esc: clears the share (pane shows the compare table)'); await p.keyboard.press('Escape'); await pause(800); await shot('9  Esc: share cleared - compare on the option'); await pause(600);
    await cap('Esc: closes the list'); await p.keyboard.press('Escape'); await pause(800); await shot('10  Esc again: the list closes');
    await cap('click another sector: IT (falling) opens with PE'); const it = await (await p.$('.srow[data-s="IT"]')).boundingBox(); await p.mouse.move(it.x + 200, it.y + it.height / 2, { steps: 12 }); await p.mouse.click(it.x + 200, it.y + it.height / 2); await pause(900);
    await shot('11  click IT: COMING DOWN NOW with PE strikes'); await pause(1200);
    const v = await p.video(); await ctx.close(); fs.copyFileSync(await v.path(), OUT + 'demo_laptop.webm');
    fs.writeFileSync(TMP + '/laptop.json', JSON.stringify(steps));
  }
  // ---------------- phone ----------------
  {
    const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true, recordVideo: { dir: TMP, size: { width: 390, height: 844 } } });
    await ctx.addInitScript(OVERLAY);
    const p = await ctx.newPage(); const cdp = await ctx.newCDPSession(p); const steps = [];
    const cap = t => p.evaluate(x => window.__caption && window.__caption(x), t);
    const shot = async label => { await cap(''); const f = TMP + '/P' + steps.length + '.png'; await p.screenshot({ path: f }); steps.push([f, label]); await cap(label); };
    const swipe = async (x, y, dy) => { await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
      for (let i = 1; i <= 14; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y: y + dy * i / 14 }] }); await p.waitForTimeout(30); }
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await p.waitForTimeout(500); };
    await p.goto(PHONE); await p.waitForTimeout(700); await shot('0  sector list (Banks UP, CE 5)'); await p.waitForTimeout(600);
    await cap('tap Banks'); await p.tap('.sr[data-s="Banks"]'); await p.waitForTimeout(700); await shot('1  tap Banks: full-screen sheet in groups');
    await cap('swipe the list with a finger'); await swipe(195, 680, -380); await shot('2  finger swipe: the list scrolls'); await swipe(195, 420, 380);
    await cap('tap ICICIBANK'); await p.tap('.mr[data-sym="ICICIBANK"]'); await p.waitForTimeout(700); await shot('3  tap ICICIBANK: the share sheet');
    await cap('swipe the share sheet'); await swipe(195, 680, -330); await shot('4  swipe: trade box, levels, lots'); await swipe(195, 400, 330);
    await cap('‹ Back returns to the list'); await p.tap('#back2'); await p.waitForTimeout(700); await shot('5  Back: the Banks list again');
    await cap('‹ Back again: the sector list'); await p.tap('#back1'); await p.waitForTimeout(700); await shot('6  Back: the sector list'); await p.waitForTimeout(800);
    const v = await p.video(); await ctx.close(); fs.copyFileSync(await v.path(), OUT + 'demo_phone.webm');
    fs.writeFileSync(TMP + '/phone.json', JSON.stringify(steps));
  }
  await b.close();
  console.log('videos done');
})();

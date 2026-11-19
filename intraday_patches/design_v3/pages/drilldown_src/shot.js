const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const out = '/home/user/my-first-site/intraday_patches/design_v3/pages/';
  for (const [w, h, f] of [[1600, 900, 'rotation-drilldown.png'], [1366, 768, 'rotation-drilldown_1366.png']]) {
    const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
    await p.goto('file://' + out + 'rotation-drilldown.html'); await p.waitForTimeout(400);
    await p.screenshot({ path: out + f });
    // clip / overlap check inside main
    const rep = await p.evaluate(() => {
      const bad = [];
      document.querySelectorAll('#page *').forEach(e => { const cs = getComputedStyle(e); if (cs.display === 'none' || cs.visibility === 'hidden') return;
        if (e.children.length === 0 && e.textContent.trim() && (e.scrollWidth > e.clientWidth + 1) && e.clientWidth > 0 && cs.overflow !== 'visible') bad.push('clip:' + (e.id || e.className) + ':' + e.textContent.trim().slice(0, 40) + ' ' + e.scrollWidth + '>' + e.clientWidth);
      });
      // row cells whose content overflows the cell
      document.querySelectorAll('.mrow>span,.srow>span,.shd>span,.mhd>span,.sl,.p2,.rk3,.how,.nw,.ai,.nent,.fs,#purp,.fh,.pf,.ph').forEach(e => { if (e.scrollWidth > e.clientWidth + 1) bad.push('ovf:' + (e.className || e.id) + ':' + e.textContent.trim().slice(0, 50) + ' ' + e.scrollWidth + '>' + e.clientWidth); });
      const vis = [...document.querySelectorAll('#wb .mrow')].filter(r => { const a = r.getBoundingClientRect(), c = document.querySelector('#wb').getBoundingClientRect(); return a.top >= c.top - 1 && a.bottom <= c.bottom + 1; }).length;
      return { bad, vis, rows: document.querySelectorAll('#wb .mrow').length };
    });
    console.log(w, JSON.stringify(rep, null, 0).slice(0, 3000), errs.join(' | '));
    await p.close();
  }
  await b.close();
})();

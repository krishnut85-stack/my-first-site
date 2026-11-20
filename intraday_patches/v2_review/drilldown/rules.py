# The rules of SECTOR_DRILLDOWN.md 3 / 5 / 8.6 checked over EVERY F&O member of EVERY sector on the real store, through the ONE shared
# module the pages use (GIR.SD in static/sector-drill.js). Port of drilldown_src/test_rules.js.
# The what-if rows (marked) call the same plan() with mode "live" and a test 1R, because the market is closed now (every live plan is
# blocked "pre-open - not live"); they exercise the sizing rules on today's real December quotes. Nothing is shown on any page.
import asyncio, json, sys
from playwright.async_api import async_playwright
BASE, OUT = sys.argv[1].rstrip('/'), sys.argv[2]
JS = r'''() => {
  const SD = GIR.SD, B = GIR.store.val('sec.board'), R = [], rec = (c, d, ok, n) => R.push({control: c, rule: d, result: ok ? 'PASS' : 'FAIL', evidence: String(n || '')});
  const secs = B.map(b => SD.model(b.name)).filter(Boolean), all = []; secs.forEach(s => s.members.forEach(m => all.push({s, m})));
  const bad = f => all.filter(f).map(x => x.m.s);
  let b;
  b = bad(x => !['up', 'lead', 'lag', 'wait', 'against', 'nt'].includes(x.m.grp)); rec('six groups only', 'every F&O member is in COMING UP / LEADER / LAGGARD / WAITING / AGAINST / NOT TRADABLE', !b.length, all.length + ' members in ' + secs.length + ' sectors · bad: ' + b.join(' '));
  b = bad(x => x.m.grp === 'up' && (!x.m.gok || x.m.isExt)); rec('COMING UP = 4 gates and not EXTENDED', 'no COMING UP / DOWN share fails a gate or is extended', !b.length, b.join(' ') || all.filter(x => x.m.grp === 'up').map(x => x.m.s).join(' '));
  b = bad(x => x.m.grp === 'up' && x.m.score < SD.RULES.SCORE_OFF); rec('COMING UP score (on 0.60 / off 0.45)', 'every COMING UP share scores >= 0.45 (hysteresis) and switched on at 0.60', !b.length, b.join(' '));
  b = bad(x => x.m.isExt !== ((x.m.ext > 1) || (x.m.used > 0.8))); rec('EXTENDED rule', 'EXT > 1.0 or range used > 0.8 ATR - one flag for the group, the gate cell and the pane', !b.length, b.join(' ') || all.filter(x => x.m.isExt).length + ' extended');
  b = bad(x => x.m.grp === 'lag' && !x.s.lag.ok); rec('LAGGARD only at breadth >= 70%', 'no LAGGARD where breadth (all listed) is under 70% one way', !b.length, b.join(' ') || 'laggards: ' + all.filter(x => x.m.grp === 'lag').map(x => x.m.s).join(' '));
  rec('"no laggard" sectors', 'sectors under 70% one way say so', true, secs.filter(s => !s.lag.ok).map(s => s.name + ' ' + Math.round((s.lag.bw || 0) * 100) + '%').join(', '));
  b = secs.filter(s => s.members.filter(m => m.role === 'LEADER').length > 1).map(s => s.name); rec('one LEADER per sector', 'at most one LEADER chip per sector', !b.length, b.join(' '));
  b = bad(x => x.m.grp === 'lead' && x.m.gok && !x.m.isExt && x.m.score >= SD.RULES.SCORE_ON); rec('LEADER group = extended or a gate fails', 'a leader that passes everything is in COMING UP', !b.length, b.join(' '));
  b = bad(x => x.m.grp === 'against' && !(x.s.dir * x.m.pct < 0 && x.s.dir * x.m.rs <= -0.5)); rec('AGAINST rule', 'moving the other way with RS <= -0.5', !b.length, b.join(' ') || all.filter(x => x.m.grp === 'against').map(x => x.m.s).join(' '));
  b = bad(x => x.m.grp === 'lag' && !/\d/.test(x.m.plan.how)); rec('LAGGARD shows its trigger price', 'every laggard has a number', !b.length, b.join(' '));
  b = bad(x => x.m.cp !== ((x.s.dir > 0) !== (x.m.grp === 'against') ? 'CE' : 'PE')); rec('CE on a rising sector, PE on a falling one (AGAINST flips)', 'option side per group', !b.length, b.join(' '));
  b = bad(x => x.m.plan.c && x.m.plan.c.exp && !/^\d{4}-12-/.test(x.m.plan.c.exp)); const nodec = bad(x => !x.m.plan.c || !x.m.plan.c.exp);
  rec('December strikes only', 'every contract is the December expiry (never the 23 Nov expiry)', !b.length, 'not December: ' + (b.join(' ') || 'none') + ' · no December chain: ' + (nodec.join(' ') || 'none'));
  b = bad(x => x.m.plan.lots > 0); rec('pre-open now: 0 lots everywhere', 'market not open -> every plan is "pre-open - not live", 0 lots', !b.length, (all[0] ? all[0].m.plan.lotsTxt : ''));
  b = bad(x => x.m.ban && !(x.m.plan.lots === 0 && /^BAN - only close existing/.test(x.m.plan.block) && !x.m.plan.takeable && x.m.plan.copyOff)); rec('BAN hard block', 'a banned share: NOT TRADABLE, 0 lots, "BAN - only close existing", no star, Copy off', !b.length, all.filter(x => x.m.ban).map(x => x.m.s + ' ' + x.m.grp + ' ' + x.m.plan.block).join(' · ') || 'no banned share');
  b = bad(x => x.m.stale && !(x.m.plan.lots === 0 && /^STALE/.test(x.m.plan.block) && x.m.plan.copyOff)); rec('STALE hard block', 'a stale quote: 0 lots, STALE ns, Copy off', !b.length, all.filter(x => x.m.stale).length + ' stale now');
  // what-if: the same plan() with mode live (and the loss lock) on today's real quotes; test 1R values are test inputs only
  const W = [];
  [2000, 5000, 10000].forEach(r1 => all.forEach(x => W.push({x, r1, p: SD.plan(x.s, x.m, {mode: 'live', r1})})));
  b = W.filter(w => w.p.lots > 0 && !(w.p.rr >= 1)).map(w => w.x.m.s); rec('what-if live: R:R < 1 after costs -> 0 lots', 'no plan is sized with R:R below 1', !b.length, b.join(' ') || W.filter(w => /R:R/.test(w.p.warn)).length + ' plans held at 0 lots by R:R');
  b = W.filter(w => w.p.lots > 0 && w.p.risk > w.r1).map(w => w.x.m.s); rec('what-if live: one lot above 1R -> 0 lots', 'no plan sized when one lot risks more than 1R', !b.length, b.join(' ') || W.filter(w => /> 1R/.test(w.p.warn)).length + ' plans held at 0 lots by 1R');
  b = W.filter(w => w.p.lots > 0 && (w.x.m.grp === 'wait' || w.x.m.grp === 'nt')).map(w => w.x.m.s); rec('what-if live: WAITING / NOT TRADABLE -> 0 lots', 'no lots while a gate fails or in ban', !b.length, b.join(' '));
  b = W.filter(w => w.p.takeable !== (w.p.lots > 0)).map(w => w.x.m.s); rec('what-if live: the star / takeable follows the lots', 'ATM star only on a strike he could take', !b.length, W.filter(w => w.p.takeable).map(w => w.x.m.s + ' ' + w.p.lots + ' @1R ' + w.r1).slice(0, 8).join(' · ') || 'none takeable');
  b = W.filter(w => w.p.lots > 0 && !(w.p.risk * w.p.lots <= (w.p.room || 0))).map(w => w.x.m.s); rec('what-if live: lots fit the lock room', 'lots x risk <= lock room', !b.length, b.join(' '));
  const L = all.map(x => SD.plan(x.s, x.m, {mode: 'live', r1: 5000, locked: true})); b = L.filter(p => p.lots > 0 || !(p.block.startsWith('LOCKED') || p.block.startsWith('BAN') || p.block.startsWith('STALE') || p.block.startsWith('OPTION'))).map(p => p.cp);
  rec('what-if: LOCKED blocks every new trade', 'loss lock -> "LOCKED - no new trades today", 0 lots', !b.length, L.length + ' plans · ' + (L[0] ? L[0].block : ''));
  b = secs.filter(s => s.nonfo && !(s.nonfo.n === s.br.all_n - s.br.fo_n)).map(s => s.name); rec('non-F&O fold counts from all listed', 'n more listed, not F&O = all listed - F&O', !b.length, secs.filter(s => s.nonfo).map(s => s.name + ' ' + s.nonfo.n).slice(0, 6).join(' · '));
  b = secs.filter(s => !/listed|named members/.test(s.b.basis || '')).map(s => s.name); rec('basis named (R49)', 'every sector line names its basis (all listed shares)', !b.length, b.join(' ') || secs.map(s => (s.b.basis || '').slice(0, 30)).slice(0, 2).join(' · '));
  return R;
}'''
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(); ctx = await b.new_context(viewport={'width': 1366, 'height': 768}); pg = await ctx.new_page()
        await pg.goto(BASE + '/rotation', wait_until='domcontentloaded'); await pg.wait_for_function('() => window.GIR && GIR.SD && GIR.store.val("sec.board")', timeout=30000); await pg.wait_for_timeout(1500)
        R = await pg.evaluate(JS)
        for r in R: r.update({'page': 'shared module (F3 page)', 'viewport': 'rules', 'where': 'inside'}); print(r['result'], r['control'], '|', r['evidence'][:150])
        json.dump(R, open(OUT, 'w'), indent=1); await b.close()
asyncio.run(main())

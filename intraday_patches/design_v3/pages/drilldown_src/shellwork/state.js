// SHELL STATE PRESETS - CONFERENCE.md section 4 states, values only (the markup stays the shell's). ONE source, so no page
// hand-types a strip value. The shell.html default IS state S3 (11:40:30, in trade).
//   const ST = require('../shellwork/state.js');
//   ({ top, foot } = ST.apply(top, foot, 'S2'));                      // HUNT 10:05:12 (desk-hunt, plan-card)
//   ({ top, foot } = ST.apply(top, foot, 'S4', { clock: '11:44:20' })); // SHOCK 11:42:40-11:44:20, positions still open
//   ({ top, foot } = ST.apply(top, foot, 'S5', { clock: '15:46:10' })); // CLOSE (= state_close19.js)
// S1 PREP 08:52:10 (morning) changes the market strip to the 18 Nov close; the Morning page sets those itself (SHELL.md 6).
const CLOSE = require('./state_close19.js');
function rep(s, a, b, label) {
  const n = s.split(a).length - 1;
  if (n !== 1) throw new Error(`state.js: "${label || a.slice(0, 60)}" matched ${n} times`);
  return s.replace(a, b);
}
function toExit(clock) { // "ENTRY · 5h 05m to 15:10" countdown, rounded to the minute
  const [h, m, s] = clock.split(':').map(Number); const left = Math.round((15 * 3600 + 10 * 60 - (h * 3600 + m * 60 + (s || 0))) / 60);
  return `${Math.floor(left / 60)}h ${String(left % 60).padStart(2, '0')}m`;
}
function clockOnly(top, clock, phaseWord = 'ENTRY') {
  top = rep(top, '<span class="sh-clock">11:40:30</span>', `<span class="sh-clock">${clock}</span>`);
  top = rep(top, '<span class="sh-phase"><b>ENTRY</b> · <span class="n">3h 30m</span> to 15:10</span>',
    `<span class="sh-phase"><b>${phaseWord}</b> · <span class="n">${toExit(clock)}</span> to 15:10</span>`);
  return top;
}
function apply(top, foot, state, o = {}) {
  if (state === 'S3') return { top, foot };
  if (state === 'S5') return CLOSE.apply(top, foot, o);
  if (state === 'S4') return { top: clockOnly(top, o.clock || '11:42:40'), foot }; // S3 = S4 market and P&L (section 4)
  if (state !== 'S2') throw new Error('state.js: unknown state ' + state);
  // S2 HUNT 10:05:12 - flat, 0 of 3, week / month before today (section 4 P&L table)
  const clock = o.clock || '10:05:12';
  top = clockOnly(top, clock);
  top = rep(top, '<span class="sh-big dn">−₹650</span><span class="n dn">−0.1R</span>', '<span class="sh-big" style="color:var(--text)">₹0</span><span class="n" style="color:var(--text-2)">0.0R</span>');
  top = rep(top, 'realised <span class="n">₹0</span> · open <span class="n">−₹650</span> net of <span class="n">₹840</span> costs', 'realised <span class="n">₹0</span> · open <span class="n">₹0</span>');
  top = rep(top, 'real <span class="n">₹0</span> · open <span class="n">−₹650</span> · costs <span class="n">₹840</span>', 'real <span class="n">₹0</span> · open <span class="n">₹0</span>');
  top = top.replace(/title="TODAY = realised \+ open\. Open is valued[^"]*"/g, 'title="TODAY = realised + open, net of costs (costs = charges + est. exit slippage, split here once a position is open). Flat: no trade yet today."');
  const openRe = /title="Open positions \(max 2\)\. If every open position[^"]*"><span class="sh-lb">open<\/span><span class="n" style="color:var\(--text\);font-weight:600">2<\/span><span>· at share stops<\/span><span class="n" style="color:var\(--text\)">−₹8,020<\/span>/;
  if (!openRe.test(top)) throw new Error('state.js: open / at share stops not found');
  top = top.replace(openRe, 'title="Open positions (max 2): none"><span class="sh-lb">open</span><span class="n" style="color:var(--text);font-weight:600">0</span><span>· at share stops</span><span class="n" style="color:var(--text)">₹0</span>');
  top = rep(top, '<span class="n" style="color:var(--text);font-weight:600">2 of 3</span>', '<span class="n" style="color:var(--text);font-weight:600">0 of 3</span>');
  top = rep(top, '<span class="n dn">−₹4,755</span><span class="n dn" style="font-size:12px">−0.95R</span>', '<span class="n dn">−₹4,105</span><span class="n dn" style="font-size:12px">−0.82R</span>');
  top = rep(top, '<span class="n up">+₹5,045</span><span class="n up" style="font-size:12px">+1.01R</span>', '<span class="n up">+₹5,695</span><span class="n up" style="font-size:12px">+1.14R</span>');
  top = rep(top, '<span class="n" style="color:var(--text);font-weight:600">₹9,350</span><span>left</span><span class="sh-meter"><i style="width:7%"></i>', '<span class="n" style="color:var(--text);font-weight:600">₹10,000</span><span>left</span><span class="sh-meter"><i style="width:0%"></i>');
  top = rep(top, '<span class="n" style="color:var(--text)">$4.10</span><span>of $20</span><span class="sh-meter sh-wide"><i style="width:21%"></i>', '<span class="n" style="color:var(--text)">$2.35</span><span>of $20</span><span class="sh-meter sh-wide"><i style="width:12%"></i>');
  top = rep(top, 'title="Put-call ratio of open interest, as of 11:39"><span class="sh-t2l"><span class="sh-lb">PCR (OI)</span><span class="sh-age">11:39</span>', 'title="Put-call ratio of open interest, as of 10:04"><span class="sh-t2l"><span class="sh-lb">PCR (OI)</span><span class="sh-age">10:04</span>');
  return { top, foot };
}
module.exports = { apply, toExit };

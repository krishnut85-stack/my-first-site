// SHELL STATE PRESET · "19 Nov after the close" = CONFERENCE section 4 state S5 (SHELL.md section 6). Conference build 19 Nov:
// default clock 15:46:10, AI $7.69 (S5), matches the new strip wording (costs, at share stops, READY health).
// ONE source for every page that shows the 19 Nov close (Journal ⇧F6, Scorecard ⇧F8 15:46, Calendar / Morning "yesterday", Replay
// "REAL TODAY" line). Values only - the markup stays the shell's. The day: 3 trades, all closed, net of each trade's charges from the
// ONE charges table: #48 MANAPPURAM +₹2,725 (₹125) · #49 HINDALCO −₹2,746 (₹86) · #50 TITAN +₹5,408 (₹87) = +₹5,387 = +1.08R,
// charges ₹298. Week 16-19 Nov +₹1,282 (+0.26R, 8 trades). November +₹11,082 (+2.22R). Lock not hit today (18 Nov: LOCKED 11:31,
// 2 losses in a row). The 1366 fixes (P1 / P2 always visible, "real · open · chg" kept) are in build.js itself, not here.
// Usage:  const S = require('../shellwork/state_close19.js');  ({ top, foot } = S.apply(top, foot, { clock: '15:46:10' }));
const CLOSE19 = {
  today: '+₹5,387', todayR: '+1.08R', realised: '+₹5,387', open: '₹0', charges: '₹298',
  chargesWhy: '#48 MANAPPURAM ₹125 + #49 HINDALCO ₹86 + #50 TITAN ₹87 = ₹298 (GIR estimate until the 19 Nov contract note ~18:00)',
  week: '+₹1,282', weekR: '+0.26R', month: '+₹11,082', monthR: '+2.22R', trades: '3 of 3',
};
function rep(s, a, b, label) {
  const n = s.split(a).length - 1;
  if (n !== 1) throw new Error(`state_close19: "${label || a.slice(0, 60)}" matched ${n} times`);
  return s.replace(a, b);
}
function apply(top, foot, o = {}) {
  const clock = o.clock || '15:46:10', phase = o.phase || '<b>REVIEW</b> · day <span class="n">16:00</span>', ai = o.ai || ['$7.69', 38];
  const G3 = ' style="color:var(--text-3)"', C = CLOSE19;
  const IX = [ // 19 Nov close (as of 15:30) in --text-3; change vs 18 Nov close
    ['NIFTY 50', '24,486.20', '−152.76', '▼ −0.62%', '24,431.95', '−207.00', '▼ −0.84%'],
    ['BANKNIFTY', '52,140.50', '−109.73', '▼ −0.21%', '52,078.40', '−171.85', '▼ −0.33%'],
    ['SENSEX', '80,412.65', '−469.11', '▼ −0.58%', '80,212.30', '−669.45', '▼ −0.83%'],
    ['FINNIFTY', '23,905.40', '−38.31', '▼ −0.16%', '23,861.15', '−82.55', '▼ −0.34%'],
    ['MIDCPNIFTY', '12,640.15', '−131.55', '▼ −1.03%', '12,598.40', '−173.30', '▼ −1.36%'],
  ];
  for (const [nm, p, c, pc, p2, c2, pc2] of IX) {
    top = rep(top, `<span class="sh-px n">${p}</span><span class="sh-ch n dn sh-wide">${c}</span><span class="sh-pc n dn">${pc}</span>`,
      `<span class="sh-px n"${G3}>${p2}</span><span class="sh-ch n dn sh-wide">${c2}</span><span class="sh-pc n dn">${pc2}</span>`, nm);
    top = rep(top, `title="${nm}: price · change from previous close · % · sparkline since 09:15. Click = MARKET screen"`,
      `title="${nm}: 19 Nov close, as of 15:30 (market closed) · change from 18 Nov close · % · sparkline 09:15-15:30. Click = MARKET screen"`, nm + ' title');
  }
  top = rep(top, '<span class="sh-px n">14.82</span><span class="sh-pc n up">▲ +2.84%</span>', `<span class="sh-px n"${G3}>14.95</span><span class="sh-pc n up">▲ +3.75%</span>`);
  top = rep(top, 'title="India VIX, change from previous close"', 'title="India VIX: 19 Nov close (as of 15:30), change from 18 Nov close 14.41"');
  top = rep(top, '<span class="sh-age">prem +44</span>', '<span class="sh-age">prem +20</span>');
  top = rep(top, '<span class="sh-px n">24,530.5</span><span class="sh-pc n dn">▼ −0.55%</span>', '<span class="sh-px n">24,452.0</span><span class="sh-pc n dn">▼ −0.87%</span>');
  top = rep(top, '<span class="sh-mstate">OPEN</span>', '<span class="sh-mstate" style="border-color:var(--line-2);color:var(--text-3)">CLOSED</span>');
  top = rep(top, '<span class="sh-phase"><b>ENTRY</b> · <span class="n">3h 30m</span> to 15:10</span>', `<span class="sh-phase">${phase}</span>`);
  top = rep(top, '<span class="sh-clock">11:40:30</span>', `<span class="sh-clock">${clock}</span>`);
  top = rep(top, '<span class="sh-dot"></span><span class="sh-age" style="color:var(--text-2)">data 0.4s</span>',
    '<span class="sh-dot" style="background:var(--text-3)"></span><span class="sh-age" style="color:var(--text-2)">as of 15:30</span>');
  top = rep(top, '<span class="sh-t2v"><span class="n v">88.94</span><span class="n up">▲ +0.08%</span>', '<span class="sh-t2v"><span class="n v">88.97</span><span class="n up">▲ +0.11%</span>');
  top = rep(top, '<span class="sh-age">$/bbl · 1m</span></span><span class="sh-t2v"><span class="n v">63.84</span><span class="n dn">▼ −1.10%</span>',
    '<span class="sh-age">$/bbl · 1m</span></span><span class="sh-t2v"><span class="n v">63.62</span><span class="n dn">▼ −1.44%</span>');
  top = rep(top, '<span class="n v">1,24,610</span><span class="n dn">▼ −1.62%</span>', '<span class="n v">1,24,560</span><span class="n dn">▼ −1.66%</span>');
  top = rep(top, 'title="Put-call ratio of open interest, as of 11:39"><span class="sh-t2l"><span class="sh-lb">PCR (OI)</span><span class="sh-age">11:39</span></span><span class="sh-t2v"><span>NIFTY</span><span class="n v">0.92</span><span>· BANKNIFTY</span><span class="n v">1.08</span>',
    'title="Put-call ratio of open interest at the 15:30 close"><span class="sh-t2l"><span class="sh-lb">PCR (OI)</span><span class="sh-age">15:30</span></span><span class="sh-t2v"><span>NIFTY</span><span class="n v">0.88</span><span>· BANKNIFTY</span><span class="n v">1.04</span>');
  top = rep(top, '<span class="n v">▲ 61</span><span class="n v">▼ 157</span>', '<span class="n v">▲ 54</span><span class="n v">▼ 165</span>');
  top = rep(top, 'title="Advancing / declining F&amp;O shares (unchanged 4)"', 'title="Advancing / declining F&amp;O shares at the 15:30 close (unchanged 3)"');
  top = rep(top, '<span class="n v">3</span><span>sessions left</span>', '<span class="n v">2</span><span>sessions left</span>');
  // MY F&O P&L
  top = rep(top, '<span class="sh-big dn">−₹650</span><span class="n dn">−0.1R</span>', `<span class="sh-big up">${C.today}</span><span class="n up">${C.todayR}</span>`);
  const why = `TODAY = realised + open. 19 Nov: 3 trades, all closed, so realised uses actual fills and charges (no slippage estimate left). Charges ${C.chargesWhy} - from the ONE charges table (Settings › Charges, dated)`;
  top = top.replace(/title="TODAY = realised \+ open\. Open is valued[^"]*"/g, `title="${why}"`);
  top = rep(top, 'realised <span class="n">₹0</span> · open <span class="n">−₹650</span> net of <span class="n">₹840</span> costs', `realised <span class="n">${C.realised}</span> · open <span class="n">${C.open}</span> · charges <span class="n">${C.charges}</span>`);
  top = rep(top, 'real <span class="n">₹0</span> · open <span class="n">−₹650</span> · costs <span class="n">₹840</span>', `real <span class="n">${C.realised}</span> · open <span class="n">${C.open}</span> · chg <span class="n">${C.charges}</span>`);
  top = rep(top, 'title="Open positions (max 2). If every open position hit its SHARE stop now: −₹8,020 net of costs (HINDALCO −₹4,060 + MANAPPURAM −₹3,960 = −1.6R) - lock room ₹1,980. At the Kite backstops (SL-L): −₹9,090 (−1.8R) - lock room ₹910"><span class="sh-lb">open</span><span class="n" style="color:var(--text);font-weight:600">2</span><span>· at share stops</span><span class="n" style="color:var(--text)">−₹8,020</span>',
    'title="Open positions (max 2): none - flat since 13:52 (#50 TITAN out 13:52)"><span class="sh-lb">open</span><span class="n" style="color:var(--text);font-weight:600">0</span><span>· at share stops</span><span class="n" style="color:var(--text)">₹0</span>');
  top = rep(top, '<span class="n" style="color:var(--text);font-weight:600">2 of 3</span>', `<span class="n" style="color:var(--text);font-weight:600">${C.trades}</span>`);
  top = rep(top, '<span class="n dn">−₹4,755</span><span class="n dn" style="font-size:12px">−0.95R</span>', `<span class="n up">${C.week}</span><span class="n up" style="font-size:12px">${C.weekR}</span>`);
  top = rep(top, '<span class="n up">+₹5,045</span><span class="n up" style="font-size:12px">+1.01R</span>', `<span class="n up">${C.month}</span><span class="n up" style="font-size:12px">${C.monthR}</span>`);
  top = rep(top, 'title="Rupees left before the day loss lock (−2% = −₹10,000; also 2 losses in a row, weekly −6%). Lock room = what is left if every open position hits its share stop. Meter amber from 75%, LOCKED chip at 100%. Exits always stay usable."><span class="sh-lb sh-wide">loss lock</span><span class="sh-lb sh-n1366">lock</span><span class="n" style="color:var(--text);font-weight:600">₹9,350</span><span>left</span><span class="sh-meter"><i style="width:7%"></i>',
    'title="Day loss lock at −2% = −₹10,000 (also: 2 losses in a row, weekly −6%). 19 Nov: not hit, day closed +₹5,387. Last lock: 18 Nov 11:31 - 2 losses in a row. Resets 09:00."><span class="sh-lb sh-wide">loss lock</span><span class="sh-lb sh-n1366">lock</span><span class="n" style="color:var(--text);font-weight:600">₹10,000</span><span>left</span><span class="sh-meter"><i style="width:0%"></i>');
  top = rep(top, '<span class="n" style="color:var(--text)">$4.10</span><span>of $20</span><span class="sh-meter sh-wide"><i style="width:21%"></i>', `<span class="n" style="color:var(--text)">${ai[0]}</span><span>of $20</span><span class="sh-meter sh-wide"><i style="width:${ai[1]}%"></i>`);
  top = rep(top, 'P1 <span class="n">0</span> · P2 <span class="n">1</span>', 'P1 <span class="n">0</span> · P2 <span class="n">0</span>');
  foot = rep(foot, 'health READY · worst K3 <span class="n">1.2s</span> · AI full', 'health READY · feeds closed 15:30 · AI full');
  return { top, foot };
}
module.exports = { CLOSE19, apply };

// Builds pages/rotation-drilldown.html: shell CSS / top / footer copied VERBATIM from v3/shell.html, state values only (SHELL.md 6):
// the S2 preset (flat, 0 of 3) at clock 11:05:00 via shellwork/state.js, then the illustrative 19 Nov 11:05 market values.
const fs = require('fs'), path = require('path');
const V3 = '/home/user/my-first-site/intraday_patches/design_v3', HERE = __dirname;
const ST = require(path.join(HERE, '../design/v3/shellwork/state.js'));
const shell = fs.readFileSync(V3 + '/shell.html', 'utf8');
const cut = (a, b) => { const i = shell.indexOf(a), j = shell.indexOf(b, i); if (i < 0 || j < 0) throw new Error('marker ' + a); return shell.slice(i, j + b.length); };
const css = cut('/* ===================== SHELL CSS START', 'SHELL CSS END ===================== */');
let top = cut('<!-- ===================== SHELL TOP START', 'SHELL TOP END ===================== -->');
let foot = cut('<!-- ===================== SHELL FOOTER START', 'SHELL FOOTER END ===================== -->');
({ top, foot } = ST.apply(top, foot, 'S2', { clock: '11:05:00' }));
function rep(s, a, b) { const n = s.split(a).length - 1; if (n !== 1) throw new Error('rep ' + n + 'x: ' + a.slice(0, 80)); return s.replace(a, b); }
// rising sparklines for the illustrative up day
function spark(seed, endHi) { let s = seed, y = 10, pts = []; for (let i = 0; i < 30; i++) { s = (s * 16807) % 2147483647; const r = s / 2147483647; y += (r - 0.5) * 2.2 - (endHi ? 0.32 : 0.08); y = Math.max(2, Math.min(12, y)); pts.push([(2 + i * 40 / 29).toFixed(1), y.toFixed(1)]); }
  pts[29][1] = endHi ? '2.4' : pts[29][1]; return pts; }
function setIdx(name, px, ch, pc, seed, hi) {
  const a = top.indexOf('href="market.html#' + name + '"'), b = top.indexOf('</a>', a); let blk = top.slice(a, b);
  const pts = spark(seed, hi); blk = blk.replace(/points="[^"]*"/, 'points="' + pts.map(p => p.join(',')).join(' ') + '"').replace(/cx="[^"]*" cy="[^"]*"/, 'cx="' + pts[29][0] + '" cy="' + pts[29][1] + '"');
  blk = blk.replace(/<span class="sh-l2">[\s\S]*<\/span>\s*$/, `<span class="sh-l2"><span class="sh-px n">${px}</span><span class="sh-ch n up sh-wide">${ch}</span><span class="sh-pc n up">▲ ${pc}</span></span>\n      `);
  top = top.slice(0, a) + blk + top.slice(b);
}
setIdx('NIFTY', '25,514.35', '+182.40', '+0.72%', 11, true);
setIdx('BANKNIFTY', '59,842.60', '+662.81', '+1.12%', 23, true);
setIdx('SENSEX', '83,702.15', '+551.30', '+0.66%', 37, true);
setIdx('FINNIFTY', '27,486.90', '+247.70', '+0.91%', 41, true);
setIdx('MIDCPNIFTY', '13,402.70', '+38.85', '+0.29%', 53, false);
top = rep(top, '<span class="sh-px n">14.82</span><span class="sh-pc n up">▲ +2.84%</span>', '<span class="sh-px n">11.86</span><span class="sh-pc n dn">▼ −3.42%</span>');
top = rep(top, '<span class="sh-age">prem +44</span></span>\n      <span class="sh-l2"><span class="sh-px n">24,530.5</span><span class="sh-pc n dn">▼ −0.55%</span>', '<span class="sh-age">prem +27</span></span>\n      <span class="sh-l2"><span class="sh-px n">25,541.5</span><span class="sh-pc n up">▲ +0.69%</span>');
top = rep(top, '<span class="n v">88.94</span><span class="n up">▲ +0.08%</span>', '<span class="n v">88.71</span><span class="n dn">▼ −0.12%</span>');
top = rep(top, '<span class="n v">63.84</span><span class="n dn">▼ −1.10%</span>', '<span class="n v">64.22</span><span class="n up">▲ +0.42%</span>');
top = rep(top, '<span class="n v">1,24,610</span><span class="n dn">▼ −1.62%</span>', '<span class="n v">1,23,980</span><span class="n dn">▼ −0.51%</span>');
top = rep(top, '<span>FII</span><span class="n v">−1,842</span><span>· DII</span><span class="n v">+1,315</span>', '<span>FII</span><span class="n v">+1,486</span><span>· DII</span><span class="n v">+905</span>');
top = rep(top, 'index futures −2,110 · stock futures +640', 'index futures +1,240 · stock futures +890');
top = rep(top, '<span>idx fut</span><span class="n v">−2,110</span>', '<span>idx fut</span><span class="n v">+1,240</span>');
top = rep(top, '· stk fut <span class="n v">+640</span>', '· stk fut <span class="n v">+890</span>');
top = rep(top, '· stk <span class="n v">+640</span>', '· stk <span class="n v">+890</span>');
top = top.replace(/as of 10:04"><span class="sh-t2l"><span class="sh-lb">PCR \(OI\)<\/span><span class="sh-age">10:04/, 'as of 11:04"><span class="sh-t2l"><span class="sh-lb">PCR (OI)</span><span class="sh-age">11:04');
top = rep(top, '<span>NIFTY</span><span class="n v">0.92</span><span>· BANKNIFTY</span><span class="n v">1.08</span>', '<span>NIFTY</span><span class="n v">1.12</span><span>· BANKNIFTY</span><span class="n v">1.31</span>');
top = rep(top, '<span class="n v">▲ 61</span><span class="n v">▼ 157</span>', '<span class="n v">▲ 148</span><span class="n v">▼ 70</span>');
top = rep(top, '$2.35</span>', '$2.60</span>');
top = top.replace('Values illustrative (Thu 19 Nov 2026, 11:40:30)', 'Values illustrative (Thu 19 Nov 2026, 11:05:00, banks day)');
if (!top.includes('11:05:00') || !top.includes('4h 05m')) throw new Error('clock not applied');

const pcss = fs.readFileSync(HERE + '/desk.css', 'utf8') + '\n.nr{display:none}\n@media (max-width:1499px){.nr{display:inline}}\n';
const main = fs.readFileSync(HERE + '/desk.main.html', 'utf8');
const data = fs.readFileSync(HERE + '/data.js', 'utf8'), js = fs.readFileSync(HERE + '/desk.js', 'utf8');
const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>GIR · F3 Rotation · Banks drill-down</title>
<!-- GIR v3 · F3 ROTATION with the SECTOR DRILL-DOWN open (SECTOR_DRILLDOWN.md = R50): Banks clicked open, ICICIBANK loaded in the share pane.
     Thu 19 Nov 2026 11:05:00 · design mockup - illustrative values (a banks day: NIFTY 25,514, BANKNIFTY record).
     Shell copied verbatim from v3/shell.html (state values only: S2 preset at 11:05:00 + this day's market strip). All controls work. -->
<style>
${css}

${pcss}
</style>
</head>
<body class="page-rotation">

${top}

${main}

${foot}
<script>
${data}
</script>
<script>
${js}
</script>
</body>
</html>
`;
fs.writeFileSync(V3 + '/pages/rotation-drilldown.html', html);
console.log('wrote', html.length, 'bytes');
// phone page
const ph = fs.readFileSync(HERE + '/phone.html', 'utf8').replace('/*DATA*/', () => data).replace('/*PHONE*/', () => fs.readFileSync(HERE + '/phone.js', 'utf8'));
fs.writeFileSync(V3 + '/pages/rotation-drilldown-phone.html', ph);
console.log('wrote phone', ph.length);

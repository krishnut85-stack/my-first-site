// F3 ROTATION · SECTOR DRILL-DOWN behaviour (mockup, works in the browser): one open sector at a time, the list pushes rows
// down, groups in fixed order, order never changes under the pointer (re-rank chip), share pane follows ↑↓/J/K, drawn scrollbars
// that drag / wheel / page, hash state so Back returns to the same sector, list and row.
(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); }, $$ = function (s, r) { return [].slice.call((r || document).querySelectorAll(s)); };
  var G = GD, F = G.fmt, S = G.SECTORS;
  var wide = function () { return window.innerWidth >= 1500; };
  var st = { open: 'Banks', sel: 'ICICIBANK', more: {}, nfo: {}, pins: {}, win: 1, rr: { Banks: { AXISBANK: 1 } }, applied: {}, kf: -1, view: 'tbl' };
  var D2 = function (x) { return x < 100 ? 2 : (x < 1000 ? 2 : 1); };
  function px(x) { return F(x, x < 1000 ? 2 : 2); }
  function lv(x) { return F(x, x < 200 ? 2 : 1); }
  function sec(id) { for (var i = 0; i < S.length; i++) if (S[i].id === id) return S[i]; return null; }
  function pct(m) { return (m.ltp / m.prev - 1) * 100; }
  function sgp(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(2) + '%'; }
  function sg1(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(1); }
  function sg2(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(2); }
  function mins(t) { var h = t.match(/(\d+)h/), m = t.match(/(\d+)m/); return (h ? +h[1] * 60 : 0) + (m ? +m[1] : 0); }
  function esc(t) { return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;'); }

  // ---------------- hash state (Back returns to the same sector, list and row) ----------------
  function readHash() { var h = location.hash.replace(/^#/, ''); if (!h) return; var p = {}; h.split('&').forEach(function (kv) { var a = kv.split('='); p[a[0]] = decodeURIComponent(a[1] || ''); });
    if ('s' in p) st.open = p.s || null; if ('r' in p) st.sel = p.r || null; if (p.y) st.restoreY = +p.y; }
  function writeHash() { var h = '#s=' + encodeURIComponent(st.open || '') + '&r=' + encodeURIComponent(st.sel || '') + '&y=' + Math.round($('#wb').scrollTop); try { history.replaceState(null, '', h); } catch (e) {} }

  // ---------------- flows per window ----------------
  var FLOWS = [
    { rng: '10:50-11:05', out: [['IT', 2050, 'SB', '52/74', -1.04], ['FMCG', 980, 'SB', '39/60', -0.71], ['others', 210]], inn: [['Banks', 2760, 'LB', '31/41', 1.06], ['NBFC & finance', 480, 'LB', '58/92', 0.64]], st: 'ROT CONFIRMED 22m' },
    { rng: '10:35-11:05', out: [['IT', 4120, 'SB', '52/74', -1.04], ['FMCG', 2380, 'SB', '39/60', -0.71], ['others', 640]], inn: [['Banks', 5860, 'LB', '31/41', 1.06], ['NBFC & finance', 1280, 'LB', '58/92', 0.64]], st: 'ROT CONFIRMED 22m' },
    { rng: '10:05-11:05', out: [['IT', 6940, 'SB', '52/74', -1.04], ['FMCG', 3110, 'SB', '39/60', -0.71], ['Pharma', 1420, 'LU', '58/88', -0.62], ['others', 830]], inn: [['Banks', 9450, 'LB', '31/41', 1.06], ['NBFC & finance', 1930, 'LB', '58/92', 0.64], ['Realty', 920, 'LB', '29/40', 1.38]], st: 'ROT CONFIRMED 22m' },
    { rng: '09:15-11:05', out: [['IT', 8800, 'SB', '52/74', -1.04], ['FMCG', 4260, 'SB', '39/60', -0.71], ['Pharma', 2050, 'LU', '58/88', -0.62], ['others', 1190]], inn: [['Banks', 12400, 'LB', '31/41', 1.06], ['Realty', 2140, 'LB', '29/40', 1.38], ['NBFC & finance', 1760, 'LB', '58/92', 0.64]], st: 'ROT CONFIRMED 22m' }
  ];
  var SIDE = [['Realty', '+₹940 cr', 'LB', 'fading 33→29'], ['Metals', '+₹610 cr', 'SC', 'shorts leave'], ['Pharma', '−₹310 cr', 'LU', 'PE 2 · own story']];
  var NEWE = [['11:01', 'BANKBARODA', 'Banks'], ['10:56', 'BAJFINANCE', 'NBFC & finance'], ['10:52', 'DLF', 'Realty']];
  var short = { 'NBFC & finance': 'NBFC' };

  function drawHero() {
    var f = FLOWS[st.win], up = function (a) { return '<span class="s i" data-s="' + a[0] + '">' + (short[a[0]] || a[0]).toUpperCase() + '</span>'; };
    var outs = f.out.filter(function (a) { return a[0] !== 'others'; });
    $('#heroLine').innerHTML = '<span class="o">money OUT of</span> ' + outs.map(function (a) { return '<span class="s o" data-s="' + a[0] + '">' + a[0] + '</span>'; }).join('<span class="ar">·</span>') +
      ' <span class="ar">→</span> <span class="i">INTO</span> ' + f.inn.map(up).join('<span class="ar">·</span>') + ' <span class="sh-c sh-c-info" style="margin-left:6px">' + f.st + '</span>';
    $('#wrng').textContent = f.rng; $('#rkW').textContent = ['15M', '30M', '1H', 'TODAY'][st.win];
    $$('#wch .chip').forEach(function (c) { c.classList.toggle('on', +c.dataset.w === st.win); });
    var svg = $('#flowSvg'), W = svg.clientWidth || 600, H = svg.clientHeight || 60, Lw = wide() ? 210 : 178, Rw = wide() ? 210 : 168, x0 = Lw + 6, x1 = W - Rw - 6;
    var tot = 0; f.out.forEach(function (a) { tot += a[1]; }); var gap = 3, avail = H - 4 - gap * (Math.max(f.out.length, f.inn.length) - 1), k = avail / tot, h = '';
    h += '<defs><linearGradient id="gF" x1="0" x2="1"><stop offset="0" stop-color="rgb(' + getComputedStyle(document.documentElement).getPropertyValue('--down-rgb') + ')" stop-opacity=".75"/><stop offset="1" stop-color="rgb(' + getComputedStyle(document.documentElement).getPropertyValue('--up-rgb') + ')" stop-opacity=".8"/></linearGradient></defs>';
    var ly = 2, ry = [], ryy = 2; f.inn.forEach(function (a) { ry.push(ryy); ryy += a[1] * k + gap; });
    var rfill = f.inn.map(function () { return 0; });
    f.out.forEach(function (o) { var oh = o[1] * k, oy = ly; ly += oh + gap;
      f.inn.forEach(function (inn, j) { var part = o[1] * inn[1] / tot, ph = part * k, sy = oy, ty = ry[j] + rfill[j]; rfill[j] += ph; oy += ph;
        var mx = (x0 + x1) / 2; h += '<path class="rb2" data-s="' + inn[0] + '" d="M' + x0 + ',' + sy + ' C' + mx + ',' + sy + ' ' + mx + ',' + ty + ' ' + x1 + ',' + ty + ' L' + x1 + ',' + (ty + ph) + ' C' + mx + ',' + (ty + ph) + ' ' + mx + ',' + (sy + ph) + ' ' + x0 + ',' + (sy + ph) + ' Z" fill="url(#gF)" opacity="' + (o[0] === 'others' ? .35 : .7) + '"><title>' + o[0] + ' → ' + inn[0] + ' ≈ ₹' + F(part, 0) + ' cr (click = open ' + inn[0] + ')</title></path>'; });
      var cy = (ly - gap - oh / 2) + 4;
      h += '<g class="hit" data-s="' + (o[0] === 'others' ? '' : o[0]) + '"><rect x="' + (x0 - 4) + '" y="' + (ly - gap - oh) + '" width="3" height="' + oh + '" fill="var(--down)"/>' +
        '<text x="' + (x0 - 10) + '" y="' + cy + '" text-anchor="end">' + (o[0] === 'others' ? (oh < 11 ? '' : '<tspan>others ₹' + F(o[1], 0) + ' cr</tspan>') : '<tspan class="nmx" style="font-weight:700;fill:var(--text);font-size:13px">' + o[0] + '</tspan><tspan fill="var(--down)" dx="5">' + sgp(o[4]) + '</tspan><tspan dx="5">₹' + F(o[1], 0) + ' cr</tspan><tspan dx="5" fill="var(--sb)" font-weight="700">' + o[2] + '</tspan>' + (wide() ? '<tspan dx="4">' + o[3] + '</tspan>' : '')) + '</text></g>';
    });
    f.inn.forEach(function (a, j) { var ih = a[1] * k, cy = ry[j] + ih / 2 + 4;
      h += '<g class="hit" data-s="' + a[0] + '"><rect x="' + (x1 + 1) + '" y="' + ry[j] + '" width="3" height="' + ih + '" fill="var(--up)"/><text x="' + (x1 + 10) + '" y="' + cy + '"><tspan style="font-weight:700;fill:var(--text);font-size:13px">' + (short[a[0]] || a[0]) + '</tspan><tspan fill="var(--up)" dx="5">' + sgp(a[4]) + '</tspan><tspan dx="5">₹' + F(a[1], 0) + ' cr</tspan><tspan dx="5" fill="var(--lb)" font-weight="700">' + a[2] + '</tspan>' + (wide() ? '<tspan dx="4">' + a[3] + '</tspan>' : '') + '</text></g>'; });
    svg.innerHTML = h;
    if (!wide()) { $('#flowSide').innerHTML = '<div class="fs fst">moving, not this rotation</div><div class="fs fs2">' + SIDE.slice(0, 2).map(function (a) { var s = sec(a[0]), id = G.ideas(s);
      return '<span data-s="' + a[0] + '" title="click = open ' + a[0] + ' · ' + a[1] + ' ' + a[2] + '"><b>' + a[0] + '</b> <span class="pc up" style="font-size:11.5px">' + sgp(s.pct) + '</span> <span class="up">CE ' + id.ce + '</span>' + (s.run && s.run.fade ? ' <span class="dn">fading</span>' : '') + '</span>'; }).join('<span class="t3"> · </span>') + '</div>'; }
    else $('#flowSide').innerHTML = '<div class="fs fst">moving, not this rotation</div>' + SIDE.slice(0, 2).map(function (a) { var s = sec(a[0]), id = G.ideas(s);
      return '<div class="fs" data-s="' + a[0] + '" title="click = open ' + a[0] + ' in the table"><b>' + a[0] + '</b><span class="pc ' + (s.pct >= 0 ? 'up' : 'dn') + '" style="font-size:12px">' + sgp(s.pct) + '</span><span class="n wd">' + a[1] + '</span><span class="sh-c sh-c-' + a[2].toLowerCase() + '">' + a[2] + '</span><span class="sh-c ' + (s.dir > 0 ? 'out-up' : 'out-dn') + '">' + (s.dir > 0 ? 'CE ' + id.ce : 'PE ' + id.pe) + '</span>' + (s.run && s.run.fade ? '<span class="dn" style="font-size:11px" title="breadth ' + s.run.br + ' in 15 min">fading</span>' : '') + '</div>'; }).join('');
    $('#nent').innerHTML = '<span class="lab" style="color:var(--up)">new entrants</span><span class="t3">COMING UP in the last 15 min · all sectors · silent</span>' + NEWE.map(function (a) { return '<span class="ne" data-s="' + a[2] + '" data-r="' + a[1] + '" title="click = open ' + a[2] + ' and load ' + a[1] + '"><span class="age">' + a[0] + '</span><b>' + a[1] + '</b><span class="t3">' + (short[a[2]] || a[2]) + '</span></span>'; }).join('');
  }

  // ---------------- members of a sector, groups in fixed order, folded to the row cap ----------------
  function orderOf(s) { var a = s.members.slice(); if (st.applied[s.id] && s.id === 'Banks') { // re-rank applied: AXISBANK above ICICIBANK
      var i = a.findIndex(function (m) { return m.sym === 'AXISBANK'; }), j = a.findIndex(function (m) { return m.sym === 'ICICIBANK'; }); if (i > j) { var t = a[i]; a.splice(i, 1); a.splice(j, 0, t); } } return a; }
  function visibleGroups(s) {
    var cap = wide() ? 12 : 8, gs = []; G.GORDER.forEach(function (g) { var a = orderOf(s).filter(function (m) { return m.grp === g; }); if (a.length) gs.push({ g: g, items: a, shown: a.slice(), hidden: [] }); });
    // NEW entrants go to the bottom of their group
    gs.forEach(function (x) { x.items.sort(function (a, b) { return (a.neu ? 1 : 0) - (b.neu ? 1 : 0); }); x.shown = x.items.slice(); });
    var total = 0; gs.forEach(function (x) { total += x.items.length; });
    if (total > cap && !st.more[s.id]) { var w = gs.find(function (x) { return x.g === 'with'; }); if (w) { var other = total - w.items.length, keep = Math.max(1, cap - other); w.shown = w.items.slice(0, keep); w.hidden = w.items.slice(keep); } }
    return gs;
  }
  function bestPick(s) { var best = null, bv = -1; s.members.forEach(function (m) { if (m.grp !== 'up' || m.stale || m.ban) return; var p = G.plan(s, m); if (p.rr > bv) { bv = p.rr; best = m.sym; } }); return best; }

  function roleChip(m) { var c = { LEADER: 'sh-c-leader', LAGGARD: 'sh-c-lag', DEPENDENT: 'sh-c-dep', FOLLOWER: 'fol' }[m.role]; var ab = { LEADER: 'LEAD', LAGGARD: 'LAG', DEPENDENT: 'DEP', FOLLOWER: 'FOLL' }[m.role]; return '<span class="sh-c ' + c + '" title="' + m.role + '"><span class="r16">' + m.role + '</span><span class="r13">' + ab + '</span></span>'; }
  function buChip(bu) { return bu ? '<a class="sh-c sh-c-' + bu.toLowerCase() + '" href="futures-oi.html#bu=' + bu + '" title="' + { LB: 'long build-up', SB: 'short build-up', SC: 'short covering - fades fast', LU: 'long unwinding' }[bu] + ', all months · opens F10 build-up filtered ' + bu + '">' + bu + '</a>' : '<span class="sh-c nt" style="width:24px;justify-content:center">-</span>'; }
  function sideCell(m, s) { var t = G.sideTxt(m), up = /above|reclaim/.test(t); var c = m.side === 'reclaim' ? 'tx' : (up ? 'up' : 'dn'); var g = m.side === 'reclaim' ? '↺' : (up ? '▲' : '▼');
    var short1366 = { 'above both': 'abv both', 'above VWAP': 'abv VWAP', 'above OR': 'abv OR', 'reclaiming': 'reclaim', 'below both': 'blw both' }[t] || t;
    var sh = { 'above both': 'both', 'above VWAP': 'VWAP', 'above OR': 'OR', 'reclaiming': 'reclaim', 'below both': 'both' }[t] || t;
    return '<span class="c-sd ' + c + '" title="VWAP ' + lv(m.vwap) + ' · OR ' + lv(m.orL) + '-' + lv(m.orH) + ' · ' + t + '">' + g + ' ' + sh + '</span>'; }
  function gateCell(m) { var g = m.gate, h;
    if (m.ban) h = '<span class="sh-c sh-c-exit" title="F&amp;O ban, MWPL ' + m.mwpl + '% (ban at 95%): only close existing positions">BAN</span><span class="t2" title="only close existing positions"><span class="r16">close only</span><span class="r13">close</span></span>';
    else if (m.stale) h = '<span class="sh-c sh-c-stale" title="last tick 12 s ago: no GO NOW until it ticks">STALE 12s</span>';
    else if (m.gok) h = '<span class="ok" title="all 4 gates pass: RS15 &gt; 0 · RS30 ≥ +0.5 · RVOL ≥ 1.5 · above VWAP 2 closed 5-min bars · no SB / LU">✓ 4/4</span>' + (m.neu ? '<span class="sh-c sh-c-info" title="new entrant ' + m.neu + ', added at the bottom of its group">NEW</span>' : '');
    else if (m.ext) h = '<span class="ex" title="EXTENDED - don\'t chase: range used ' + G.room(m).used.toFixed(2) + ' ATR &gt; 0.8 · enter on the pullback to VWAP / first higher low, 1 lot">EXT → VWAP</span>';
    else if (/^VWAP 1\/2/.test(g)) h = '<span class="no" title="above VWAP for 1 of the 2 closed 5-min bars needed">VWAP 1/2</span>';
    else if (/^trig/.test(g)) h = '<span class="tx">' + g.replace('trig', 'trig') + '</span>';
    else if (/^own/.test(g)) h = '<span class="tx" title="against its sector on its own story: ' + g + '">own news</span>';
    else h = '<span class="no" title="the gate that failed">' + g + '</span>';
    return '<span class="c-gt">' + h + '</span>'; }
  function aiCell(m) { return '<span class="c-ai">' + (m.ai ? '<span class="sh-c sh-c-ready" title="GIR ' + m.ai + ' ' + m.aiT + '">' + m.ai + '</span>' : '<span class="sil">AI silent</span>') + '</span>'; }
  function optCell(s, m, best) { var c = G.contract(s, m, 'atm'), wsp = c.sprPct > 1.2;
    return '<span class="c-op" title="December ' + F(c.K, c.K < 100 ? 1 : 0) + ' ' + c.cp + ' (ATM) · bid/ask ' + px(c.bid) + '/' + px(c.ask) + ' · spread ' + c.sprPct.toFixed(1) + '% = ₹' + F(c.sprLot, 0) + '/lot · lot ' + m.lot + '">' + '<span class="sh-c sh-c-' + c.cp.toLowerCase() + '">' + F(c.K, c.K % 1 ? 1 : 0) + ' ' + c.cp + '</span><span>' + px(c.ask) + '</span><span class="sp' + (wsp ? ' w' : '') + '">' + c.sprPct.toFixed(1) + '%</span></span>'; }
  function mrow(s, m, best) { var p = pct(m), r = G.room(m), heat = (m.grp === 'up' || m.grp === 'against') ? ' sh-heat-' + (p >= 0 ? 'up' : 'dn') : '';
    var rd = st.rr[s.id] && st.rr[s.id][m.sym] && !st.applied[s.id] ? '<span class="rd" title="rank change: score now above the row over it; the order holds while your pointer is in the list">▲' + st.rr[s.id][m.sym] + '</span>' : '';
    return '<div class="mrow' + heat + (m.sym === st.sel ? ' sel' : '') + (m.stale ? ' stale' : '') + (m.ban ? ' ban' : '') + (rd ? ' rrf' : '') + '" data-sym="' + m.sym + '" style="--m:' + Math.min(2, Math.abs(p)).toFixed(2) + '">' +
      '<span class="c-sh"><a class="lk" data-sym="' + m.sym + '">' + m.sym + '</a>' + rd + (st.pins[m.sym] ? '<span class="pin">PIN</span>' : '') + roleChip(m) + (best ? '<span class="st" style="color:var(--action)" title="best option R:R in COMING UP">★</span>' : '') + '</span>' +
      '<span class="num pc ' + (p >= 0 ? 'up' : 'dn') + '">' + sgp(p) + '</span>' +
      '<span class="num" title="RS30 vs sector; arrow = 15-min slope">' + sg2(m.rs30) + '<small class="' + (m.sl === '↗' ? 'up' : m.sl === '↘' ? 'dn' : 't3') + '">' + m.sl + '</small></span>' +
      '<span class="num" title="RVOL vs the 20-session median to this minute; arrow = rising">' + m.rvol.toFixed(1) + '<small class="' + (m.rvUp ? 'up' : 't3') + '">' + (m.rvUp ? '▲' : '→') + '</small></span>' +
      sideCell(m, s) +
      '<span class="c-rm' + (r.used > 0.8 ? ' am' : '') + '" title="ATR used ' + r.used.toFixed(2) + ' · ATR left ' + r.left.toFixed(2) + ' (ATR14 ' + m.atr + ')">' + r.used.toFixed(1) + '<span class="t3">·</span>' + r.left.toFixed(1) + '</span>' +
      '<span class="c-bu">' + buChip(m.bu) + (m.oi > 0 ? '+' : '') + m.oi.toFixed(1) + '%</span>' +
      '<span class="c-wt" title="weight in the sector (all listed, free-float)"><span class="wtb"><i style="width:' + Math.min(100, m.wt / 31 * 100) + '%"></i></span>' + m.wt.toFixed(1) + '</span>' +
      optCell(s, m, best) + gateCell(m) + aiCell(m) + '<span class="c-ag">' + m.age + '</span></div>'; }

  function sline(s) { var fo = G.fo(s), run = s.run, w = s.why, up = s.dir > 0;
    var l1 = '<div class="sl"><b class="snm">' + s.id.toUpperCase() + '</b><b class="pc ' + (up ? 'up' : 'dn') + '">' + (up ? '▲ ' : '▼ ') + sgp(s.pct) + '</b><span class="sep">·</span>' +
      '<span>all ' + s.n + ' listed</span><button class="lkx" data-bas="' + s.id + '" title="' + s.basis + (s.idx ? ' · ' + s.idx : '') + '">basis ›</button><span class="sep">·</span>' +
      '<span><span class="r16">breadth </span><b class="up">▲' + s.up + '</b> <b class="dn">▼' + s.dn + '</b></span><span class="sep">·</span><span>F&amp;O <b class="up">▲' + fo.up + '</b> <b class="dn">▼' + fo.dn + '</b></span><span class="sep">·</span>' +
      '<span>RS30 <b>' + sg2(s.rs30) + '</b></span>' + (s.conf ? '<span class="sh-c sh-c-info" title="rotation confirmed ' + s.conf + '"><span class="r16">CONFIRMED</span><span class="r13">CONF</span> ' + s.conf + '</span>' : '') +
      (run ? '<span class="sep">·</span><span title="sector run clock: how long this move has run vs the typical run of such moves (n = past runs)">' + (up ? 'up' : 'down') + ' since <b>' + run.since + '</b> · <b>' + run.len + '</b></span><span class="runb' + (up ? '' : ' dn') + '"><i style="width:' + Math.min(100, mins(run.len) / mins(run.typ) * 100).toFixed(0) + '%"></i></span><span>typ ' + run.typ.replace(' ', '') + ' n=' + run.nn + '</span><span class="' + (run.fade ? 'dn' : 't2') + '" title="breadth now vs 15 min ago">' + (run.fade ? 'FADING ' : '') + run.br + (run.fade ? '' : ' ▲') + '</span>' : '') + '</div>';
    var why = w ? '<span class="whyl">WHY</span>' + '<b style="font-family:var(--sans);flex:none">' + esc(w.drv) + '</b>' + (w.live ? '<span class="t2" style="flex:none">' + esc(w.live) + '</span>' : '') + (w.story ? '<span class="t3">·</span><b class="ell" style="font-family:var(--sans);flex:0 1 auto">' + esc(w.story) + ' <span class="t3" style="font-weight:400">(' + esc(w.src) + ' · ' + w.sage + ')</span></b>' : '')
      : '<span class="whyl">WHY</span><b style="font-family:var(--sans);color:var(--action)">UNEXPLAINED</b><span class="t3">no driver or story found (checked 11:05)</span>';
    var rrc = st.rr[s.id] && !st.applied[s.id] ? '<button class="chip rrc" id="rrChip" title="the order never changes under your pointer or keys: the new order applies when the pointer leaves the list, after 30 s, or on R">re-ranked <kbd>R</kbd> apply</button>' : '';
    var l2 = '<div class="sl">' + why + '<span class="gr"><span class="sh-c sh-c-info" title="Nov expiry is Mon 23 Nov (Tue 24 holiday); ITM stock options are physically settled - December is the default month">Expiry week · Dec only</span>' + rrc + '</span></div>';
    return l1 + l2; }

  function srow(s, i, open) { var id = G.ideas(s), fo = G.fo(s), up = s.dir > 0, p = s.pct;
    var stc = { 'ROT CONFIRMED': 'sh-c-info', 'IN': 'out-up', 'OUT': 'out-dn', 'NOT THIS ROT': 'nt', 'SHORTS LEAVE': 'sh-c-sc' }[s.st] || 'nt';
    var stt = s.st ? '<span class="sh-c ' + stc + '">' + s.st + (s.stAge ? ' ' + s.stAge : '') + '</span>' : '<span class="t3">-</span>';
    if (s.run && s.run.fade) stt = '<span class="sh-c sh-c-stale" title="breadth slipping ' + s.run.br + ' in 15 min">FADING ' + s.run.br + '</span>';
    return '<div class="srow sh-heat-' + (p >= 0 ? 'up' : 'dn') + (open ? ' open' : '') + '" data-s="' + s.id + '" data-i="' + i + '" style="--m:' + Math.min(2, Math.abs(p)).toFixed(2) + '" title="click = ' + (open ? 'close' : 'open its F&amp;O shares') + ' · key ' + (i + 1) + '">' +
      '<span class="rk">' + (i + 1) + '</span><span class="nm"><span class="cv">' + (open ? '▾' : '▸') + '</span><b>' + s.id + '</b><span class="bas">' + s.basis + '</span></span>' +
      '<span class="ce" title="F&amp;O ideas in this sector: ' + id.ce + ' CE · ' + id.pe + ' PE (the up-side is never collapsed)">' + (up ? '<span class="sh-c sh-c-ce">CE ' + id.ce + '</span><span class="t3" style="font-size:11px">PE ' + id.pe + '</span>' : '<span class="sh-c sh-c-pe">PE ' + id.pe + '</span><span class="t3" style="font-size:11px">CE ' + id.ce + '</span>') + '</span>' +
      '<span class="num' + (i === 0 ? ' hl' : '') + '">' + sg2(s.rs30) + '</span><span class="num">#' + s.today + '</span>' +
      '<span class="dy"><b class="pc ' + (p >= 0 ? 'up' : 'dn') + '">' + sgp(p) + '</b><span class="hb2"><i class="' + (p >= 0 ? 'p' : 'n') + '" style="width:' + Math.min(50, Math.abs(p) / 1.5 * 50) + '%"></i></span></span>' +
      '<span class="br">' + (up ? s.up : s.dn) + '/' + s.n + (up ? ' <span class="up">▲</span>' : ' <span class="dn">▼</span>') + ' <span>·</span> ' + (up ? fo.up : fo.dn) + '/' + fo.n + '</span>' +
      '<span class="cr">' + (s.cr > 0 ? '+' : '') + F(s.cr, 0) + (s.bu ? '<span class="sh-c sh-c-' + s.bu.toLowerCase() + '">' + s.bu + '</span>' : '<span class="sh-c nt">-</span>') + '</span>' +
      '<span class="st">' + stt + '</span></div>'; }

  function drawTable() {
    var wb = $('#wb'), h = '';
    S.forEach(function (s, i) {
      if (s.id !== st.open) { h += srow(s, i, false); return; }
      var gs = visibleGroups(s), best = bestPick(s);
      h += '<div class="blk' + (st.nfo[s.id] ? ' nfo' : '') + '" data-s="' + s.id + '"><div class="bh">' + srow(s, i, true) + sline(s) +
        '<div class="mhd"><span>group</span><span>share · role</span><span class="r">day %</span><span class="r" title="RS30 vs sector, 15-min slope">vs sec</span><span class="r">RVOL</span><span>VWAP/OR</span><span title="ATR used · ATR left">room</span><span title="build-up, all months · OI chg">B/U · OI</span><span class="r">wt %</span><span title="December strike · ask premium · bid/ask spread %">Dec strike · prem · %</span><span>state / gate</span><span>AI</span><span class="r">age</span></div></div>';
      gs.forEach(function (x) { var L = G.gLabel(s, x.g, x.items.length);
        var g2 = x.g === 'lead' && x.items[0].ext ? 'extended' : x.g === 'nt' ? (x.items[0].ban ? 'F&amp;O ban' : L[1]) : x.g === 'against' ? '<span class="r13">(' + x.items.length + ') ' + (s.dir > 0 ? 'PE' : 'CE') + ' strike</span>' : x.g === 'lag' ? '<span class="r16">' + L[1] + '</span><span class="r13">' + (s.dir > 0 ? 'catch-up' : 'catch-down') + '</span>' : L[1];
        var g1 = x.g === 'against' ? '<span class="r16">' + L[0] + '</span><span class="r13">AGAINST</span>' : x.g === 'with' ? '<span class="r16">' + L[0] + '</span><span class="r13">GATE OPEN</span>' : L[0];
        var w16 = (x.g === 'with' || x.g === 'nt') ? ' w16' : '';
        h += '<div class="grp g-' + x.g + '"><div class="gl" title="' + L[0] + ' · ' + L[1] + '"><span class="g1">' + g1 + '</span>' + (g2 ? '<span class="g2' + w16 + '">' + g2 + '</span>' : '') +
          (x.hidden.length ? '<button class="more" data-more="' + s.id + '" title="' + x.hidden.map(function (m) { return m.sym; }).join(' · ') + '">+' + x.hidden.length + ' more ▾</button>' : (st.more[s.id] && x.g === 'with' ? '<button class="more" data-more="' + s.id + '">less ▴</button>' : '')) + '</div><div class="gi">' +
          x.shown.map(function (m) { return mrow(s, m, m.sym === best); }).join('') + '</div></div>'; });
      var nf = s.nonfo;
      h += '<div class="nonfo" data-nfo="' + s.id + '" title="context only - they never get a strike"><span>' + (st.nfo[s.id] ? '▾' : '▸') + '</span><b>' + nf.n + '</b> more listed, not F&amp;O <span>·</span> <b class="up">▲' + nf.up + '</b> <b class="dn">▼' + nf.dn + '</b> <span>·</span> wt <b>' + nf.wt + '%</b> <span>· context only, no strike</span></div>' +
        '<div class="nfx">' + (nf.ex.length ? nf.ex.map(function (a) { return '<span><b>' + a[0] + '</b> <span class="' + (a[1] >= 0 ? 'up' : 'dn') + '">' + sgp(a[1]) + '</span></span>'; }).join('') + '<span>and ' + (nf.n - nf.ex.length) + ' more · F2 board for all</span>' : '<span>' + nf.n + ' shares · F2 board for all</span>') + '</div></div>';
    });
    var y = wb.scrollTop; wb.innerHTML = h; wb.scrollTop = y;
    $('#openTxt').textContent = st.open ? st.open + ' open' : 'click a sector';
    rails.forEach(function (r) { r.upd(); });
  }

  // ---------------- the share pane ----------------
  function chartSvg(s, m, p) {
    var W = $('#pb').clientWidth - (wide() ? 22 : 18), Hp = wide() ? 112 : 92, Hq = wide() ? 38 : 32, padL = 4, padR = 52, b = G.bars(m), n = b.length;
    var lo = Math.min(m.lo, p.stop, m.vwap) , hi = Math.max(m.hi, p.tgt, p.trig); var pad = (hi - lo) * 0.08; lo -= pad; hi += pad;
    var X = function (i) { return padL + (i + 0.5) * (W - padL - padR) / n; }, Y = function (v) { return 4 + (hi - v) / (hi - lo) * (Hp - 8); }, bw = Math.max(3, (W - padL - padR) / n - 3);
    var h = '<svg id="chart" width="' + W + '" height="' + (Hp + Hq + 18) + '" viewBox="0 0 ' + W + ' ' + (Hp + Hq + 18) + '">';
    var orY1 = Y(m.orH), orY2 = Y(m.orL); h += '<rect x="' + padL + '" y="' + orY1 + '" width="' + (X(2) + bw / 2 - padL) + '" height="' + (orY2 - orY1) + '" fill="var(--info-bg)" stroke="var(--info-line)"/><text class="lb" x="' + (padL + 2) + '" y="' + (orY1 - 2) + '">OR</text>';
    // VWAP line: cumulative typical price, tied to the reported VWAP at the end
    var cum = 0, v = [], vols = b.map(function (x, i) { return 1 + (i < 3 ? 1.2 : 0) + (i > 15 ? 0.6 : 0); }), cv = 0; b.forEach(function (x, i) { cum += (x.h + x.l + x.c) / 3 * vols[i]; cv += vols[i]; v.push(cum / cv); });
    var adj = m.vwap - v[n - 1]; h += '<polyline fill="none" stroke="var(--info)" stroke-width="1.5" points="' + v.map(function (x, i) { return X(i).toFixed(1) + ',' + Y(x + adj * i / (n - 1)).toFixed(1); }).join(' ') + '"/>';
    function hl(val, col, lab, dash) { var y = Y(val); h += '<line x1="' + padL + '" x2="' + (W - padR + 2) + '" y1="' + y + '" y2="' + y + '" stroke="' + col + '" stroke-dasharray="' + (dash || '4 3') + '" stroke-width="1"/><text x="' + (W - padR + 4) + '" y="' + (y + 4) + '" fill="' + col + '">' + lab + '</text>'; }
    b.forEach(function (x, i) { var c = x.c >= x.o ? 'var(--up)' : 'var(--down)'; h += '<line x1="' + X(i) + '" x2="' + X(i) + '" y1="' + Y(x.h) + '" y2="' + Y(x.l) + '" stroke="' + c + '"/><rect x="' + (X(i) - bw / 2) + '" y="' + Math.min(Y(x.o), Y(x.c)) + '" width="' + bw + '" height="' + Math.max(1, Math.abs(Y(x.o) - Y(x.c))) + '" fill="' + c + '"/>'; });
    hl(p.trig, 'var(--action)', 'T ' + lv(p.trig)); hl(p.stop, 'var(--down)', 'S ' + lv(p.stop)); hl(p.tgt, 'var(--up)', 'G ' + lv(p.tgt));
    // premium pane: the suggested December contract, mid with a bid/ask band
    var K = p.K, cp = p.cp, prem = b.map(function (x, i) { return G.bs(x.c, K, G.T + (n - 1 - i) * 5 / 60 / 24 / 365, m.iv, cp); }), c0 = G.contract(s, m, 'atm');
    var pl = Math.min.apply(null, prem) - c0.sp, ph = Math.max.apply(null, prem) + c0.sp, y0 = Hp + 12, PY = function (v) { return y0 + 2 + (ph - v) / (ph - pl) * (Hq - 4); };
    h += '<line x1="' + padL + '" x2="' + (W - padR) + '" y1="' + (y0 - 4) + '" y2="' + (y0 - 4) + '" stroke="var(--line)"/>';
    h += '<polygon fill="var(--up-bg)" points="' + prem.map(function (q, i) { return X(i).toFixed(1) + ',' + PY(q + c0.sp / 2).toFixed(1); }).join(' ') + ' ' + prem.slice().reverse().map(function (q, j) { var i = n - 1 - j; return X(i).toFixed(1) + ',' + PY(q - c0.sp / 2).toFixed(1); }).join(' ') + '"/>';
    h += '<polyline fill="none" stroke="var(--' + (cp === 'CE' ? 'up' : 'down') + ')" stroke-width="1.4" points="' + prem.map(function (q, i) { return X(i).toFixed(1) + ',' + PY(q).toFixed(1); }).join(' ') + '"/>';
    h += '<text x="' + (W - padR + 4) + '" y="' + (y0 + 10) + '" fill="var(--text-2)">' + px(c0.ask) + '</text><text class="lb" x="' + (padL + 2) + '" y="' + (y0 + Hq + 2) + '">' + F(K, K % 1 ? 1 : 0) + ' ' + cp + ' Dec mid · bid/ask band · premium confirms the move</text>';
    h += '<text x="' + padL + '" y="' + (Hp + Hq + 16) + '">09:15</text><text x="' + (X(n - 1) - 30) + '" y="' + (Hp + Hq + 16) + '">11:05</text></svg>';
    return h; }

  function paneSector(s) {
    var rows = s.members.filter(function (m) { return m.grp === 'up' || m.grp === 'lead' || m.grp === 'lag'; }), best = bestPick(s);
    var h = '<div class="ps"><div class="stt">pick a share · ↑ ↓ or click</div><div class="p2">' + s.id + ' stays open on the left · the pane loads your pick</div></div>' +
      '<div class="ps"><div class="stt">compare on the option · Dec ATM ' + (s.dir > 0 ? 'CE' : 'PE') + '</div><table class="cmp"><colgroup>' + (wide() ? '<col style="width:24%"><col style="width:11%"><col style="width:11%"><col style="width:10%"><col style="width:9%"><col style="width:10%"><col style="width:9%"><col style="width:8%"><col style="width:8%">' : '<col style="width:26%"><col style="width:12%"><col style="width:13%"><col style="width:10%"><col style="width:9%"><col style="width:11%"><col style="width:10%"><col style="width:9%">') + '</colgroup><tr><th>share</th><th>strike</th><th>ask</th><th title="bid/ask spread in %">sprd</th><th>Δ</th><th>₹k/lot</th><th>room</th>' + (wide() ? '<th>IV</th>' : '') + '<th>R:R</th></tr>' +
      rows.map(function (m) { var c = G.contract(s, m, 'atm'), p = G.plan(s, m), r = G.room(m); return '<tr class="' + (m.sym === best ? 'best' : '') + '"><td data-sym="' + m.sym + '" title="click = load ' + m.sym + '">' + m.sym + '</td><td>' + F(c.K, c.K % 1 ? 1 : 0) + '</td><td>' + px(c.ask) + '</td><td>' + c.sprPct.toFixed(1) + '</td><td>' + Math.abs(c.d).toFixed(2) + '</td><td title="₹' + F(c.lotCost, 0) + '">' + (c.lotCost / 1000).toFixed(1) + '</td><td>' + r.left.toFixed(2) + '</td>' + (wide() ? '<td>' + (c.iv * 100).toFixed(1) + '</td>' : '') + '<td>' + p.rr.toFixed(2) + '</td></tr>'; }).join('') + '</table><div class="how" style="margin-top:4px">★ best R:R after costs · sprd in % · room = ATR left</div></div>';
    return h; }

  function drawPane() {
    var pb = $('#pb'), y = pb.scrollTop;
    var f = st.sel ? G.find(st.sel) : null, s = f ? f.s : sec(st.open);
    $('#spSym').textContent = f ? f.m.sym : (s ? s.id : '');
    if (!f) { pb.innerHTML = s ? paneSector(s) : '<div class="ps"><div class="stt">no sector open</div><div class="p2">click a sector row, a flow arrow or press 1-9</div></div>'; rails.forEach(function (r) { r.upd(); }); return; }
    var m = f.m, p = G.plan(s, m), a = G.contract(s, m, 'atm'), i = G.contract(s, m, 'itm'), r = G.room(m), pc = pct(m), ce = p.cp === 'CE';
    $('#flShare').href = 'share.html#' + m.sym; $('#flChain').href = 'chain.html#' + m.sym + '-' + a.K + a.cp;
    var dV = (m.ltp - m.vwap) / m.atr, gl = G.gLabel(s, m.grp, 1)[0].replace(/ \(\d+\)$/, '');
    var h = '<div class="ps"><div class="p1"><a class="lk big" data-f7="' + m.sym + '" title="double-click or Enter = full F7 Share page">' + m.sym + '</a>' + roleChip(m) + '<span class="px">' + px(m.ltp) + '</span><span class="pc ' + (pc >= 0 ? 'up' : 'dn') + '">' + sgp(pc) + '</span><span class="age">' + m.age + '</span></div>' +
      '<div class="p1b">' + '<span class="sh-c ' + (m.grp === 'up' ? 'sh-c-ce' : m.grp === 'against' ? 'sh-c-pe' : 'nt') + '">' + gl + '</span>' + '<span>lot <b>' + F(m.lot, 0) + '</b> · weight <b>' + m.wt.toFixed(1) + '%</b> of sector</span></div>' + '<div class="p2">VWAP <b>' + lv(m.vwap) + '</b> <span class="' + (dV >= 0 ? 'up' : 'dn') + '">' + (dV >= 0 ? '▲ ' : '▼ ') + (dV >= 0 ? '+' : '−') + Math.abs(dV).toFixed(2) + ' ATR</span> · OR <b>' + lv(m.orL) + '-' + lv(m.orH) + '</b> ' + (m.ltp > m.orH ? '<span class="up">▲</span>' : m.ltp < m.orL ? '<span class="dn">▼</span>' : 'inside') + '</div>' +
      '<div class="p2">vs sector RS30 <b>' + sg2(m.rs30) + ' ' + m.sl + '</b> · RVOL <b>' + m.rvol.toFixed(1) + (m.rvUp ? ' ▲ rising' : ' → flat') + '</b></div>' +
      '<div class="p2">room: ATR used <b>' + r.used.toFixed(2) + '</b> · left <b>' + r.left.toFixed(2) + '</b> · ATR14 <b>' + lv(m.atr) + '</b>' + (r.used > 0.8 ? ' · <span style="color:var(--action)">EXTENDED - don\'t chase</span>' : '') + '</div>' +
      '<div class="p2">OI build-up ' + buChip(m.bu) + ' Nov <b>' + sg1(m.buN) + '%</b> · Dec <b>' + sg1(m.buD) + '%</b> · all <b>' + sg1(m.oi) + '%</b></div></div>';
    // trade box
    var warn = [];
    if (m.ban) warn.push('<span class="wn rd">BAN - only close existing · MWPL ' + m.mwpl + '%</span>');
    if (m.stale) warn.push('<span class="wn gy">STALE 12s - no GO NOW until it ticks</span>');
    if (a.sprPct > 1.2) { var alt = i.sprPct < a.sprPct ? (F(i.K, i.K % 1 ? 1 : 0) + ' ' + i.cp + ' has ' + i.sprPct.toFixed(1) + '%') : 'no better strike - wait or skip'; warn.push('<span class="wn am">SPREAD ' + a.sprPct.toFixed(1) + '% = ₹' + F(a.sprLot, 0) + ' lost on entry; ' + alt + '</span>'); }
    if (a.dep < 5) warn.push('<span class="wn am">THIN depth: ' + a.dep + ' lots at bid</span>');
    if (m.mwpl >= 80 && !m.ban) warn.push('<span class="wn ' + (m.mwpl >= 90 ? 'rd' : 'am') + '">MWPL ' + m.mwpl + '% · near ban</span>');
    if (!warn.length) warn.push('<span class="wn ok">spread ' + a.sprPct.toFixed(1) + '%</span><span class="wn ok">depth ' + a.dep + ' lots</span><span class="wn ok">IV/20d ' + (a.iv / a.iv20).toFixed(2) + '</span><span class="wn ok">MWPL ' + m.mwpl + '%</span><span class="wn ok">data ' + m.age + '</span>');
    h += '<div class="ps"><div class="stt" style="color:var(--' + (ce ? 'up' : 'down') + ')">trade box · December 29 Dec<span class="sh-c sh-c-info">Expiry week · Dec only</span></div>' +
      '<table class="tbx"><colgroup><col style="width:36%"><col><col></colgroup><tr><th></th><th class="pk"><span class="sh-c sh-c-' + a.cp.toLowerCase() + '">' + F(a.K, a.K % 1 ? 1 : 0) + ' ' + a.cp + '</span> ATM ★</th><th><span class="sh-c sh-c-' + i.cp.toLowerCase() + '">' + F(i.K, i.K % 1 ? 1 : 0) + ' ' + i.cp + '</span> 1 ITM</th></tr>' +
      [['bid / ask', px(a.bid) + ' / ' + px(a.ask), px(i.bid) + ' / ' + px(i.ask)], ['spread per lot', '₹' + F(a.sprLot, 0) + ' · ' + a.sprPct.toFixed(1) + '%', '₹' + F(i.sprLot, 0) + ' · ' + i.sprPct.toFixed(1) + '%'], ['depth at bid', a.dep + ' lots', i.dep + ' lots'],
        ['Δ · θ ₹/h per lot', Math.abs(a.d).toFixed(2) + ' · −₹' + F(a.thh, 0), Math.abs(i.d).toFixed(2) + ' · −₹' + F(i.thh, 0)], ['IV vs 20-day', (a.iv * 100).toFixed(1) + ' / ' + (a.iv20 * 100).toFixed(1), (i.iv * 100).toFixed(1) + ' / ' + (i.iv20 * 100).toFixed(1)],
        ['lot cost = max loss', '₹' + F(a.lotCost, 0), '₹' + F(i.lotCost, 0)], ['break-even 15:10', lv(a.be) + ' (' + (ce ? '+' : '−') + a.bePts.toFixed(1) + ')', lv(i.be) + ' (' + (ce ? '+' : '−') + i.bePts.toFixed(1) + ')']]
        .map(function (rw) { return '<tr><td>' + rw[0] + '</td><td class="pk">' + rw[1] + '</td><td>' + rw[2] + '</td></tr>'; }).join('') + '</table><div class="warns">' + warn.join('') + '</div></div>';
    // plan
    h += '<div class="ps"><div class="pl3"><span></span><span class="hd">share</span><span class="hd">premium</span>' +
      '<span class="l">trigger</span><span class="v">' + lv(p.trig) + '</span><span class="v"><small>≈</small>' + px(p.pT) + '</span>' +
      '<span class="l">stop</span><span class="v dn">' + lv(p.stop) + '</span><span class="v dn"><small>≈</small>' + px(p.pS) + '</span>' +
      '<span class="l">target</span><span class="v up">' + lv(p.tgt) + '</span><span class="v up"><small>≈</small>' + px(p.pG) + '</span></div>' +
      '<div class="how" title="' + esc(p.how) + '">' + esc(p.how) + '</div>' +
      '<div class="rk3">risk 1 lot <b>₹' + F(p.risk, 0) + '</b> = ' + (p.risk / G.R1).toFixed(2) + 'R · R:R <b>' + p.rr.toFixed(2) + '</b> after costs</div><div class="rk3 t3">costs ₹' + p.costs + ' = charges ₹' + p.charges + ' + slippage ₹' + p.slip + '</div>' +
      '<div class="rk3">lock room <b>₹' + F(G.LOCK, 0) + '</b> → fits ' + p.fitLock + ' → <span class="lots">' + p.lotsTxt + '</span></div>' +
      '<div class="rk3">trades <b>0 of 3</b> · 15:10 in <b>4h 05m</b> · you hold no ' + s.id + ' trade</div></div>';
    h += '<div class="ps"><div class="wl">5-min · VWAP ' + lv(m.vwap) + ' · OR · CE wall ' + F(m.wallC, 0) + ' ↑ · PE wall ' + F(m.wallP, 0) + ' ↓</div>' + chartSvg(s, m, p) + '</div>';
    h += '<div class="ps"><div class="ai"><span class="lab">AI</span>' + (m.aiv ? '<span class="sh-c sh-c-ready">GET READY</span><span class="ell">' + esc(m.aiv.replace(/^GET READY /, '')) + '</span>' : '<b>AI silent</b><span class="t3">- your read</span>') + '</div></div>';
    h += '<div class="ps"><div class="evs"><span class="ev">' + esc(m.res) + '</span><span class="ev">' + m.exd + '</span><span class="ev" style="' + (m.mwpl >= 90 ? 'color:var(--danger);border-color:var(--danger)' : m.mwpl >= 80 ? 'color:var(--action);border-color:var(--action-line)' : '') + '">MWPL ' + m.mwpl + '%</span></div></div>';
    if (m.news.length) h += '<div class="ps">' + m.news.slice(0, 2).map(function (n) { return '<div class="nw" title="' + esc(n[2]) + '"><span class="tm">' + n[0] + ' · ' + n[3] + '</span><b>' + n[1] + '</b> · ' + esc(n[2]) + '</div>'; }).join('') + '</div>';
    h += '<div class="ps" style="border-bottom:0"><div class="kt"><span class="sig t3">GIR never places orders - you place the order in Kite.</span><button class="btn" id="bCopy" title="copy the contract name for Kite">Copy contract</button><span class="n t2" id="ctr">' + m.sym + ' 29DEC ' + F(a.K, a.K % 1 ? 1 : 0).replace(/,/g, '') + ' ' + a.cp + '</span></div></div>';
    pb.innerHTML = h; pb.scrollTop = st.keepPaneY ? y : 0; st.keepPaneY = false;
    $('#bP').innerHTML = '<kbd>P</kbd>' + (st.pins[m.sym] ? 'pinned' : 'pin');
    rails.forEach(function (r) { r.upd(); });
  }

  function drawRun() { $('#rb').innerHTML = S.filter(function (s) { return s.run; }).map(function (s) { var r = s.run, up = s.dir > 0;
      var mins = function (t) { var h = t.match(/(\d+)h/), m = t.match(/(\d+)m/); return (h ? +h[1] * 60 : 0) + (m ? +m[1] : 0); }, L = mins(r.len), Ty = mins(r.typ), max = 150;
      return '<div class="rr" data-s="' + s.id + '"><span><b>' + s.id + '</b> <span class="pc ' + (up ? 'up' : 'dn') + '" style="font-size:12px">' + sgp(s.pct) + '</span></span><span class="rbar"><i style="left:0;width:' + (L / max * 100) + '%;background:var(--' + (up ? 'up' : 'down') + ')"></i><u style="left:' + (Ty / max * 100) + '%"></u></span><span>' + (up ? 'up' : 'down') + ' since ' + r.since + ' · ' + r.len + ' / typ ' + r.typ + ' n=' + r.nn + ' · <span class="' + (r.fade ? 'dn' : '') + '">' + (r.fade ? 'FADING ' : '') + r.br + '</span></span></div>'; }).join(''); }

  // ---------------- drawn, draggable scrollbars ----------------
  var rails = [];
  function Rail(rail) {
    var scb = document.getElementById(rail.dataset.for), trk = $('.trk', rail), th = $('i', trk);
    function upd() { var sh = scb.scrollHeight, ch = scb.clientHeight, H = trk.clientHeight; if (!H) return; if (sh <= ch + 1) { rail.classList.add('all'); th.style.top = '0px'; th.style.height = H + 'px'; return; }
      rail.classList.remove('all'); var hh = Math.max(18, H * ch / sh); th.style.height = hh + 'px'; th.style.top = ((H - hh) * scb.scrollTop / (sh - ch)) + 'px'; }
    scb.addEventListener('scroll', upd); if (window.ResizeObserver) new ResizeObserver(upd).observe(scb);
    th.addEventListener('pointerdown', function (e) { if (e.button !== 0) return; e.preventDefault(); e.stopPropagation(); try { th.setPointerCapture(e.pointerId); } catch (x) {}
      var y0 = e.clientY, s0 = scb.scrollTop, k = (scb.scrollHeight - scb.clientHeight) / Math.max(1, trk.clientHeight - th.offsetHeight); rail.classList.add('drag');
      function mv(ev) { scb.scrollTop = s0 + (ev.clientY - y0) * k; }
      function up() { th.removeEventListener('pointermove', mv); th.removeEventListener('pointerup', up); th.removeEventListener('pointercancel', up); rail.classList.remove('drag'); }
      th.addEventListener('pointermove', mv); th.addEventListener('pointerup', up); th.addEventListener('pointercancel', up); });
    trk.addEventListener('pointerdown', function (e) { if (e.target === th) return; upd(); var r = th.getBoundingClientRect(); scb.scrollTop += (e.clientY < r.top ? -1 : 1) * scb.clientHeight * 0.9; upd(); });
    $('.rb.u', rail).addEventListener('click', function () { scb.scrollTop -= 52; upd(); });
    $('.rb.d', rail).addEventListener('click', function () { scb.scrollTop += 52; upd(); });
    rail.addEventListener('wheel', function (e) { scb.scrollTop += e.deltaY; upd(); e.preventDefault(); }, { passive: false });
    var o = { upd: upd, scb: scb }; rails.push(o); return o;
  }

  // ---------------- actions ----------------
  function toast(t) { var e = $('#toast'); e.textContent = t; e.classList.add('on'); clearTimeout(toast.t); toast.t = setTimeout(function () { e.classList.remove('on'); }, 1600); }
  function closePops() { var any = false; ['#whyD', '#planD', '#basP'].forEach(function (q) { if ($(q).classList.contains('on')) { $(q).classList.remove('on'); any = true; } }); return any; }
  function openSector(id, keepSel) { closePops(); if (st.open === id && !keepSel) { st.open = null; st.sel = null; } else { st.open = id; if (!keepSel) st.sel = null; }
    drawTable(); drawPane(); if (st.open) { var b = $('.blk', $('#wb')); if (b) $('#wb').scrollTop = Math.max(0, b.offsetTop - 0); } writeHash(); }
  function selShare(sym, scrollIn) { st.sel = sym; $$('#wb .mrow').forEach(function (r) { r.classList.toggle('sel', r.dataset.sym === sym); }); drawPane(); writeHash();
    if (scrollIn) { var r = $('#wb .mrow.sel'), wb = $('#wb'); if (r) { var top = r.offsetTop - wb.offsetTop, bh = $('.bh', wb) ? $('.bh', wb).offsetHeight : 0, rt = r.getBoundingClientRect(), wt = wb.getBoundingClientRect();
      if (rt.top < wt.top + bh) wb.scrollTop -= (wt.top + bh - rt.top); else if (rt.bottom > wt.bottom) wb.scrollTop += rt.bottom - wt.bottom; } } }
  function moveSel(d) { var rows = $$('#wb .mrow'); if (!rows.length) return false; var i = rows.findIndex(function (r) { return r.dataset.sym === st.sel; }); i = i < 0 ? (d > 0 ? 0 : rows.length - 1) : Math.max(0, Math.min(rows.length - 1, i + d)); selShare(rows[i].dataset.sym, true); return true; }
  function goF7(sym) { writeHash(); location.href = 'share.html#' + sym; }
  function goChain() { var f = st.sel && G.find(st.sel); if (!f) return; var c = G.contract(f.s, f.m, 'atm'); writeHash(); location.href = 'chain.html#' + f.m.sym + '-' + c.K + c.cp + '-29DEC'; }
  function showWhy() { var f = st.sel && G.find(st.sel); if (!f) return; var d = $('#whyD'), s = f.s, w = s.why, m = f.m;
    if (d.classList.contains('on')) { d.classList.remove('on'); return; }
    d.innerHTML = '<div class="tt">why ' + m.sym + ' is moving<span class="x" data-close="whyD">✕ Esc</span></div>' + '<div><b>Sector:</b> ' + (w ? esc(w.drv) + (w.live ? ' · ' + esc(w.live) : '') + (w.story ? ' · ' + esc(w.story) + ' (' + esc(w.src) + ', ' + w.sage + ')' : '') : 'UNEXPLAINED') + '</div>' +
      '<div><b>Share:</b> RS30 ' + sg2(m.rs30) + ' vs sector, RVOL ' + m.rvol.toFixed(1) + ', ' + G.sideTxt(m) + ', build-up ' + (m.bu || 'none') + ' ' + sg2(m.oi) + '%</div>' + (m.news.length ? m.news.map(function (n) { return '<div class="nw"><span class="tm">' + n[0] + '</span><b>' + n[1] + '</b> · ' + esc(n[2]) + ' <span class="t3">· ' + n[3] + '</span></div>'; }).join('') : '<div class="t3">no story of its own today</div>') + '<div style="margin-top:4px"><a class="lkx" href="news.html#' + m.sym + '">all stories · F4 ›</a></div>';
    $('#planD').classList.remove('on'); d.classList.add('on'); }
  function showPlan() { var f = st.sel && G.find(st.sel); if (!f) return; var d = $('#planD'); if (d.classList.contains('on')) { d.classList.remove('on'); return; } var p = G.plan(f.s, f.m), a = G.contract(f.s, f.m, 'atm');
    d.innerHTML = '<div class="tt">plan card · ' + f.m.sym + ' ' + F(a.K, a.K % 1 ? 1 : 0) + ' ' + a.cp + ' Dec<span class="x" data-close="planD">✕ Esc</span></div><div>trigger <b>' + lv(p.trig) + '</b> (≈' + px(p.pT) + ') · stop <b>' + lv(p.stop) + '</b> (≈' + px(p.pS) + ') · target <b>' + lv(p.tgt) + '</b> (≈' + px(p.pG) + ')</div><div>' + p.lotsTxt + ' · max loss ₹' + F(p.risk, 0) + ' · R:R ' + p.rr.toFixed(2) + ' · hold until stop / target or 15:10</div><div style="margin-top:4px"><a class="lkx" href="plan-card.html#' + f.m.sym + '">full plan card ›</a></div>';
    $('#whyD').classList.remove('on'); d.classList.add('on'); }
  function togglePin() { if (!st.sel) return; if (st.pins[st.sel]) delete st.pins[st.sel]; else { if (Object.keys(st.pins).length >= 5) { toast('5 pins max - unpin one first'); return; } st.pins[st.sel] = 1; }
    $('#pinN').textContent = Object.keys(st.pins).length; st.keepPaneY = true; drawTable(); drawPane(); toast(st.pins[st.sel] ? st.sel + ' pinned to the Desk watchlist' : st.sel + ' unpinned'); }
  function applyRR() { if (!st.open || !st.rr[st.open] || st.applied[st.open]) return; st.applied[st.open] = 1; drawTable(); }
  function basis(btn) { var s = sec(btn.dataset.bas), p = $('#basP'); if (p.classList.contains('on')) { p.classList.remove('on'); return; } var r = btn.getBoundingClientRect(), pg = $('#pg').getBoundingClientRect();
    p.innerHTML = '<span class="x" data-close="basP">✕</span><b>Basis (R49)</b><br>' + s.id + ' % = free-float weighted move of ALL ' + s.n + ' listed shares' + (s.idx ? ' (' + s.idx + ' covers only its index members)' : '') + '.<br>Breadth over all ' + s.n + ': ▲' + s.up + ' ▼' + s.dn + '. The F&amp;O list (' + s.members.length + ') is the tradable part; the other ' + s.nonfo.n + ' (▲' + s.nonfo.up + ' ▼' + s.nonfo.dn + ', ' + s.nonfo.wt + '% weight) are context only.<br>Not NARROW: the non-F&amp;O shares move with it.';
    p.style.left = (r.left - pg.left) + 'px'; p.style.top = (r.bottom - pg.top + 4) + 'px'; p.style.width = '380px'; p.classList.add('on'); }

  // ---------------- events ----------------
  document.addEventListener('click', function (e) { var t = e.target;
    var cl = t.closest('[data-close]'); if (cl) { $('#' + cl.dataset.close).classList.remove('on'); return; }
    if (t.closest('#rrChip')) { applyRR(); return; }
    var bb = t.closest('[data-bas]'); if (bb) { basis(bb); return; }
    var mo = t.closest('[data-more]'); if (mo) { st.more[mo.dataset.more] = !st.more[mo.dataset.more]; drawTable(); return; }
    var nf = t.closest('[data-nfo]'); if (nf) { st.nfo[nf.dataset.nfo] = !st.nfo[nf.dataset.nfo]; drawTable(); return; }
    if (t.closest('.sh-c[href]')) return;
    var mr = t.closest('.mrow'); if (mr) { selShare(mr.dataset.sym); return; }
    var sr = t.closest('.srow'); if (sr) { openSector(sr.dataset.s); return; }
    var ne = t.closest('.ne'); if (ne) { st.open = null; openSector(ne.dataset.s); selShare(ne.dataset.r, true); return; }
    var hs = t.closest('#flowSvg [data-s], #heroLine [data-s], .fs[data-s], .fs2 [data-s], .rr[data-s]'); if (hs && hs.getAttribute('data-s')) { if (st.view === 'run') setView('tbl'); if (st.open !== hs.getAttribute('data-s')) openSector(hs.getAttribute('data-s')); else { var b = $('.blk', $('#wb')); if (b) $('#wb').scrollTop = b.offsetTop; } return; }
    var cm = t.closest('.cmp td[data-sym]'); if (cm) { selShare(cm.dataset.sym, true); return; }
    var wc = t.closest('#wch .chip'); if (wc) { st.win = +wc.dataset.w; drawHero(); return; }
    var vc = t.closest('#win .vchips .chip'); if (vc) { setView(vc.dataset.v); return; }
    if (t.closest('#bF7') || t.closest('[data-f7]')) { if (st.sel) goF7(st.sel); return; }
    if (t.closest('#bO')) { goChain(); return; }
    if (t.closest('#bW')) { showWhy(); return; }
    if (t.closest('#bP')) { togglePin(); return; }
    if (t.closest('#bCopy')) { var c = $('#ctr').textContent; try { var pr = navigator.clipboard && navigator.clipboard.writeText(c); if (pr && pr.catch) pr.catch(function () {}); } catch (x) {} toast('copied: ' + c); return; }
    if (t.closest('#ddAll')) { toast('ALL SECTORS: 11 listed (no filter set)'); return; }
    if (t.closest('#pinC')) { toast(Object.keys(st.pins).length ? 'pinned: ' + Object.keys(st.pins).join(' · ') : 'no pins yet · P pins the share in the pane'); return; }
  });
  document.addEventListener('dblclick', function (e) { var mr = e.target.closest('.mrow'); if (mr) goF7(mr.dataset.sym); });
  function setView(v) { st.view = v; $('#win').classList.toggle('v-run', v === 'run'); $$('#win .vchips .chip').forEach(function (c) { c.classList.toggle('on', c.dataset.v === v); }); if (v === 'run') drawRun(); rails.forEach(function (r) { r.upd(); }); }
  // the order never changes under the pointer: a pending re-rank applies when the pointer leaves the list, or after 30 s
  $('#wb').addEventListener('mouseleave', function () { if (st.open && st.rr[st.open] && !st.applied[st.open] && st.autoRR) applyRR(); });
  setTimeout(function () { st.autoRR = true; }, 30000);
  document.addEventListener('keydown', function (e) {
    if (e.target.closest && e.target.closest('input,textarea')) return; var k = e.key, inPane = e.target.closest && e.target.closest('#pb');
    if (/^[1-9]$/.test(k)) { var s = S[+k - 1]; if (s) { if (st.view === 'run') setView('tbl'); if (st.open !== s.id) openSector(s.id); } e.preventDefault(); return; }
    if ((k === 'ArrowDown' || k === 'j' || k === 'J') && !inPane) { if (st.open && moveSel(1)) { e.preventDefault(); return; } if (!st.open) { st.kf = Math.min(S.length - 1, st.kf + 1); kf(); e.preventDefault(); } return; }
    if ((k === 'ArrowUp' || k === 'k' || k === 'K') && !inPane) { if (st.open && moveSel(-1)) { e.preventDefault(); return; } if (!st.open) { st.kf = Math.max(0, st.kf - 1); kf(); e.preventDefault(); } return; }
    if (k === 'Enter') { if (st.sel) { goF7(st.sel); e.preventDefault(); } else if (st.kf >= 0 && !st.open) { openSector(S[st.kf].id); e.preventDefault(); } return; }
    if (k === 'o' || k === 'O') { goChain(); return; }
    if (k === 'w' || k === 'W') { showWhy(); return; }
    if (k === ' ') { if (st.sel) { showPlan(); e.preventDefault(); } return; }
    if (k === 'p' || k === 'P') { togglePin(); return; }
    if (k === 'r' || k === 'R') { applyRR(); return; }
    if (k === 'Escape') { if (closePops()) return; if (st.sel) { st.sel = null; $$('#wb .mrow.sel').forEach(function (r) { r.classList.remove('sel'); }); drawPane(); writeHash(); return; } if (st.open) { openSector(st.open); return; } return; }
    if ((k === 'PageDown' || k === 'PageUp' || k === 'Home' || k === 'End') && !(e.target.classList && e.target.classList.contains('scb'))) { var sc = $('#wb'); sc.scrollTop = k === 'Home' ? 0 : k === 'End' ? sc.scrollHeight : sc.scrollTop + (k === 'PageDown' ? 1 : -1) * sc.clientHeight * 0.9; e.preventDefault(); }
  });
  function kf() { $$('#wb .srow').forEach(function (r) { r.classList.toggle('kf', +r.dataset.i === st.kf); }); }

  // ---------------- boot ----------------
  readHash();
  $$('.rail').forEach(Rail);
  drawHero(); drawTable(); drawPane();
  if (st.restoreY != null) $('#wb').scrollTop = st.restoreY;
  window.addEventListener('resize', function () { drawHero(); drawTable(); drawPane(); });
  window.GIRDD = { st: st, openSector: openSector, selShare: selShare, applyRR: applyRR };
})();

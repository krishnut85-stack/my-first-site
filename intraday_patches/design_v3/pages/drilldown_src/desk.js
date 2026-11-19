// F3 ROTATION · SECTOR DRILL-DOWN behaviour (mockup, works in the browser). Round 2.
// One open sector at a time; the list pushes rows down; groups computed by GD (data.js); the order never changes under the pointer
// or keyboard focus (pending re-rank applies on pointer-leave, or after 30 s with the pointer and focus outside the list, or on R);
// a tick simulator keeps numbers moving in fixed-width cells; drawn scrollbars (>= 10 px track) drag / page / wheel / keys;
// hash state (#s=&r=&y=&m=) so Back returns to the same sector, the same open (or expanded) list and the same row.
(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); }, $$ = function (s, r) { return [].slice.call((r || document).querySelectorAll(s)); };
  var G = GD, F = G.fmt, S = G.SECTORS, lv = G.lv, kT = G.kTxt;
  var wide = function () { return window.innerWidth >= 1500; };
  var st = { open: 'Banks', sel: 'ICICIBANK', more: {}, nfo: {}, pins: {}, win: 1, kf: -1, view: 'tbl', inList: false, rrSince: {}, simAt: 0 };
  var RR_MS = 30000;
  function px(x) { return F(x, 2); }
  var sec = G.sec, pct = G.pctOf;
  function sgp(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(2) + '%'; }
  function sg1(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(1); }
  function sg2(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(2); }
  function mins(t) { var h = t.match(/(\d+)h/), m = t.match(/(\d+)m/); return (h ? +h[1] * 60 : 0) + (m ? +m[1] : 0); }
  function esc(t) { return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;'); }
  var MOCK = { live: 'live 11:05', forming: 'forming 09:24', manage: 'manage only 14:40', locked: 'loss LOCKED', held: 'holding Banks', preopen: 'pre-open (Morning)' };
  var mode = function () { return G.MODE.k; };

  // ---------------- hash state ----------------
  function readHash() { var h = location.hash.replace(/^#/, ''); if (!h) return; var p = {}; h.split('&').forEach(function (kv) { var a = kv.split('='); p[a[0]] = decodeURIComponent(a[1] || ''); });
    if ('s' in p) st.open = p.s || null; if ('r' in p) st.sel = p.r || null; if (p.y) st.restoreY = +p.y; if (p.m && st.open) st.more[st.open] = 1; if (p.mock && MOCK[p.mock]) G.MODE.k = p.mock; if (p.f) st.restoreFocus = 1; }
  function writeHash(f) { var h = '#s=' + encodeURIComponent(st.open || '') + '&r=' + encodeURIComponent(st.sel || '') + '&y=' + Math.round($('#wb').scrollTop) + (st.open && st.more[st.open] ? '&m=1' : '') + (mode() !== 'live' ? '&mock=' + mode() : '') + (f ? '&f=1' : '');
    try { history.replaceState(null, '', h); } catch (e) {} }

  // ---------------- the flow (Rs cr = free-float mcap of all listed shares × (sector % − NIFTY %) in the window) ----------------
  var SIDE = ['Realty', 'Metals'];
  var NEWE = [['11:01', 'BANKBARODA', 'Banks'], ['10:56', 'BAJFINANCE', 'NBFC & finance'], ['10:52', 'DLF', 'Realty']];
  var short = { 'NBFC & finance': 'NBFC', 'Oil & gas': 'Oil & gas' };
  function crTip(r) { return r[0] === 'others' ? 'others: ' + (r[7] || []).join(', ') : r[0] + ': free-float mcap ₹' + r[5] + ' lakh cr × ' + (r[6] / r[5] / 1000).toFixed(3) + '% vs NIFTY = ' + (r[6] > 0 ? '+' : '−') + '₹' + F(r[1], 0) + ' cr'; }
  function drawHero() {
    var f = G.flows(st.win), outs = f.out.filter(function (a) { return a[0] !== 'others'; }).slice(0, 2), ins = f.inn.slice(0, 2);
    $('#heroLine').innerHTML = '<span class="o">money OUT of</span> ' + outs.map(function (a) { return '<span class="s o" data-s="' + a[0] + '" tabindex="0">' + (short[a[0]] || a[0]) + '</span>'; }).join('<span class="ar">·</span>') +
      ' <span class="ar">→</span> <span class="i">INTO</span> ' + ins.map(function (a) { return '<span class="s i" data-s="' + a[0] + '" tabindex="0">' + (short[a[0]] || a[0]).toUpperCase() + '</span>'; }).join('<span class="ar">·</span>') +
      ' <span class="sh-c sh-c-info" style="margin-left:6px">' + f.st + '</span>';
    $('#wrng').textContent = f.rng;
    $$('#wch .chip').forEach(function (c) { c.classList.toggle('on', +c.dataset.w === st.win); });
    var svg = $('#flowSvg'), W = svg.clientWidth || 600, H = svg.clientHeight || 60, Lw = wide() ? 232 : 196, Rw = wide() ? 226 : 186, x0 = Lw + 6, x1 = W - Rw - 6, mx = (x0 + x1) / 2;
    var gap = 2, nmax = Math.max(f.out.length, f.inn.length), avail = H - 4 - gap * (nmax - 1), k = avail / Math.max(f.so, f.si), h = '';
    var root = getComputedStyle(document.documentElement);
    h += '<defs><linearGradient id="gF" x1="0" x2="1"><stop offset="0" stop-color="rgb(' + root.getPropertyValue('--down-rgb') + ')" stop-opacity=".75"/><stop offset="1" stop-color="rgb(' + root.getPropertyValue('--up-rgb') + ')" stop-opacity=".8"/></linearGradient></defs>';
    var ly = 2, oy = [], ry = [], ryy = 2; f.out.forEach(function (a) { oy.push(ly); ly += a[1] * k + gap; }); f.inn.forEach(function (a) { ry.push(ryy); ryy += a[1] * k + gap; });
    var rfill = f.inn.map(function () { return 0; });
    f.out.forEach(function (o, i) { var sy = oy[i];
      f.inn.forEach(function (inn, j) { var lh = o[1] * inn[1] / f.si * k, rh = inn[1] * o[1] / f.so * k, ty = ry[j] + rfill[j]; rfill[j] += rh;
        h += '<path class="rb2" d="M' + x0 + ',' + sy + ' C' + mx + ',' + sy + ' ' + mx + ',' + ty + ' ' + x1 + ',' + ty + ' L' + x1 + ',' + (ty + rh) + ' C' + mx + ',' + (ty + rh) + ' ' + mx + ',' + (sy + lh) + ' ' + x0 + ',' + (sy + lh) + ' Z" fill="url(#gF)" opacity="' + (o[0] === 'others' ? .3 : .62) + '"/>'; sy += lh; }); });
    // labels: at the bar centre, spread so no two overlap; bars as 3 px edges
    function lab(list, ys, left) { var last = -99, out = '', fsz = 13, minG = wide() ? 16 : 15;
      list.forEach(function (a, i) { var bh = Math.max(1, a[1] * k), c = ys[i] + bh / 2 + 4.5, y = Math.max(c, last + minG); y = Math.min(y, H - 2); last = y; a._y = y;
        out += '<rect x="' + (left ? x0 - 4 : x1 + 1) + '" y="' + ys[i] + '" width="3" height="' + bh + '" fill="var(--' + (left ? 'down' : 'up') + ')"/>';
        var t = a[0] === 'others' ? '<tspan>others ₹' + F(a[1], 0) + ' cr</tspan>' : '<tspan class="nmx">' + (short[a[0]] || a[0]) + '</tspan><tspan fill="var(--' + (left ? 'down' : 'up') + ')" dx="5">' + sgp(a[4]) + '</tspan><tspan dx="5">' + (left ? '−' : '+') + '₹' + F(a[1], 0) + ' cr</tspan>' + (a[2] && a[2] !== '-' ? '<tspan dx="5" fill="var(--' + a[2].toLowerCase() + ')" font-weight="700">' + a[2] + '</tspan>' : '') + (wide() && a[3] ? '<tspan dx="4">' + a[3] + '</tspan>' : '');
        out += '<text x="' + (left ? x0 - 10 : x1 + 10) + '" y="' + y + '"' + (left ? ' text-anchor="end"' : '') + '>' + t + '</text>'; }); return out; }
    h += lab(f.out, oy, true) + lab(f.inn, ry, false);
    // hit zones: one per label, never overlapping (split at the midpoints between labels); ribbons themselves are not targets
    function zones(list, left) { var out = ''; list.forEach(function (a, i) { var y1 = i === 0 ? 0 : (list[i - 1]._y + a._y) / 2 - 4, y2 = i === list.length - 1 ? H : (a._y + list[i + 1]._y) / 2 - 4;
      out += '<rect class="hz' + (a[0] === 'others' ? ' oth' : '') + '" data-s="' + (a[0] === 'others' ? '' : a[0]) + '" x="' + (left ? 0 : mx) + '" y="' + y1 + '" width="' + (left ? mx : W - mx) + '" height="' + Math.max(1, y2 - y1) + '" fill="transparent"><title>' + esc(crTip(a)) + (a[0] === 'others' ? '' : ' · click = open ' + a[0]) + '</title></rect>'; }); return out; }
    h += zones(f.out, true) + zones(f.inn, false);
    svg.innerHTML = h;
    $('#flowTot').textContent = 'OUT −₹' + F(f.so, 0) + ' cr · IN +₹' + F(f.si, 0) + ' cr';
    $('#flowSide').innerHTML = '<div class="fs fst">moving, not this rotation</div>' + SIDE.map(function (id) { var s = sec(id), ix = G.ideas(s);
      return '<div class="fs" data-s="' + id + '" tabindex="0" title="click = open ' + id + ' in the table"><b>' + id + '</b><span class="pc ' + (s.pct >= 0 ? 'up' : 'dn') + '">' + sgp(s.pct) + '</span><span class="n wd">' + (s.cr > 0 ? '+' : '−') + '₹' + F(Math.abs(s.cr), 0) + ' cr</span><span class="sh-c sh-c-' + s.bu.toLowerCase() + '">' + s.bu + '</span><span class="sh-c ' + (s.dir > 0 ? 'out-up' : 'out-dn') + '">' + (s.dir > 0 ? 'CE ' + ix.ce : 'PE ' + ix.pe) + '</span>' + (s.run && s.run.fade ? '<span class="dn" title="breadth ' + s.run.br + ' in 15 min">fading</span>' : '') + '</div>'; }).join('');
    $('#nent').innerHTML = '<span class="lab" style="color:var(--up)">new entrants</span><span class="t3">COMING UP in the last 15 min · all sectors · silent</span>' + NEWE.map(function (a) { return '<span class="ne" data-s="' + a[2] + '" data-r="' + a[1] + '" tabindex="0" title="click = open ' + a[2] + ' and load ' + a[1] + '"><span class="age">' + a[0] + '</span><b>' + a[1] + '</b><span class="t3">' + (short[a[2]] || a[2]) + '</span></span>'; }).join('');
  }

  // ---------------- members, groups in fixed order, folded to the row cap ----------------
  function applied(s) { return !G.pendingRR(s); }
  function visibleGroups(s) {
    var cap = wide() ? 12 : 8, ord = G.displayOrder(s, false), gs = [];
    G.GORDER.forEach(function (g) { var a = ord.filter(function (m) { return m.grp === g; }); if (a.length) gs.push({ g: g, items: a, shown: a.slice(), hidden: [] }); });
    var total = ord.length;
    if (total > cap) { var w = gs.find(function (x) { return x.g === 'wait'; }); if (w) { var other = total - w.items.length, keep = Math.max(1, cap - other); if (!st.more[s.id]) { w.shown = w.items.slice(0, keep); w.hidden = w.items.slice(keep); } w.cap = keep; } }
    return gs;
  }
  function flatOrder(s) { return G.displayOrder(s, false).map(function (m) { return m.sym; }); }
  function bestPick(s) { var best = null, bv = -1; s.members.forEach(function (m) { if (m.grp !== 'up') return; var p = G.plan(s, m); if (!p.takeable) return; if (p.rr > bv) { bv = p.rr; best = m.sym; } }); return best; }
  function held(m) { return mode() === 'held' && m.sym === 'BANKBARODA'; }

  function roleChip(m) { var c = { LEADER: 'sh-c-leader', LAGGARD: 'sh-c-lag', DEPENDENT: 'sh-c-dep', FOLLOWER: 'fol' }[m.role]; var ab = { LEADER: 'LEAD', LAGGARD: 'LAG', DEPENDENT: 'DEP', FOLLOWER: 'FOLL' }[m.role]; return '<span class="sh-c rc ' + c + '" title="' + m.role + '"><span class="r16">' + m.role + '</span><span class="r13">' + ab + '</span></span>'; }
  var BUT = { LB: 'long build-up', SB: 'short build-up', SC: 'short covering - fades fast', LU: 'long unwinding' };
  // in a row the build-up chip is NOT a link (a row click only loads the share); the F10 link lives in the pane
  function buChip(bu) { return bu ? '<span class="sh-c sh-c-' + bu.toLowerCase() + '" title="' + BUT[bu] + ', all months">' + bu + '</span>' : '<span class="sh-c nt bu0">-</span>'; }
  function buLink(bu, sym) { return bu ? '<a class="sh-c sh-c-' + bu.toLowerCase() + '" href="futures-oi.html#bu=' + bu + '&amp;s=' + sym + '" title="' + BUT[bu] + ' · opens F10 for ' + sym + '">' + bu + ' ›</a>' : '<span class="sh-c nt">-</span>'; }
  function sideCell(m) { var t = G.sideTxt(m), up = /above|reclaim/.test(t); var c = m.side === 'reclaim' ? 'tx' : (up ? 'up' : 'dn'); var g = m.side === 'reclaim' ? '↺' : (up ? '▲' : '▼');
    var sh = { 'above both': 'both', 'above VWAP': 'VWAP', 'above OR': 'OR', 'reclaiming': 'reclaim', 'below both': 'both', 'below VWAP': 'VWAP', 'below OR': 'OR' }[t] || t;
    return '<span class="c-sd ' + c + '" title="VWAP ' + lv(m.vwap) + ' · OR ' + lv(m.orL) + '-' + lv(m.orH) + ' · ' + t + ' · ' + (m.vb || 0) + '/2 closed 5-min bars on the side">' + g + ' ' + sh + '</span>'; }
  function gateCell(s, m, p) { var h, f = m.fails[0] || '';
    if (m.ban) h = '<span class="sh-c sh-c-exit" title="F&amp;O ban, MWPL ' + m.mwpl + '% (ban at 95%): only close existing positions">BAN</span><span class="t2">close only</span>';
    else if (m.stale) h = '<span class="sh-c sh-c-stale" title="last tick ' + m.stale + ' s ago: no GO NOW until it ticks">STALE ' + m.stale + 's</span>';
    else if (/OPTION STALE/.test(p.block)) h = '<span class="sh-c sh-c-stale" title="the option bid/ask is old: no GO NOW until it ticks">OPT ' + G.contract(s, m, 'atm').oage + 's</span>';
    else if (m.grp === 'lag') h = '<span class="tx" title="laggard trigger: ' + esc(p.how) + '">trig ' + (s.dir > 0 ? '&gt;' : '&lt;') + ' ' + F(p.trig, p.trig < 200 ? 2 : 1) + '</span>';
    else if (m.grp === 'against') h = '<span class="tx" title="against its sector' + (m.own ? ': ' + esc(m.own) : '') + '">' + (m.own ? esc(m.own.replace(/^own:? ?/, 'own: ')) : 'vs sector ' + sg2(m.rs30)) + '</span>';
    else if (m.ext && m.gok) h = '<span class="ex" title="EXTENDED - don\'t chase: EXT ' + G.extOf(m).toFixed(2) + ' ATR · range used ' + G.room(m).used.toFixed(2) + ' ATR &gt; 0.8 · ' + esc(p.how) + '">EXT → ' + F(p.trig, p.trig < 200 ? 2 : 1) + '</span>';
    else if (m.gok) h = '<span class="ok" title="all 4 gates pass: RS15 &gt; 0 · RS30 ≥ +0.5 · RVOL ≥ 1.5 · 2 closed 5-min bars on the VWAP side · no build-up against · score ' + m.score.toFixed(2) + '">✓ 4/4</span>' + (m.neu ? '<span class="sh-c sh-c-info" title="new entrant ' + m.neu + ', added at the bottom of its group">NEW</span>' : '');
    else h = '<span class="no" title="the gate that failed' + (m.fails.length > 1 ? ' (+' + (m.fails.length - 1) + ' more: ' + esc(m.fails.slice(1).join(', ')) + ')' : '') + '">' + esc(f) + '</span>';
    return '<span class="c-gt">' + h + '</span>'; }
  function aiCell(m) { return '<span class="c-ai">' + (m.ai && mode() === 'live' ? '<span class="sh-c sh-c-ready" title="GIR ' + m.ai + ' ' + m.aiT + '">' + m.ai + '</span>' : '<span class="sil">AI silent</span>') + '</span>'; }
  function optCell(s, m) { var c = G.contract(s, m, 'atm'), wsp = c.sprPct > 1.2;
    return '<span class="c-op" title="December ' + kT(c.K) + ' ' + c.cp + ' (ATM) · bid/ask ' + px(c.bid) + '/' + px(c.ask) + ' (' + c.oage + 's) · spread ' + c.sprPct.toFixed(1) + '% = ₹' + F(c.sprLot, 0) + '/lot · lot ' + m.lot + '"><span class="sh-c sh-c-' + c.cp.toLowerCase() + '">' + kT(c.K) + ' ' + c.cp + '</span><span class="pr">' + px(c.ask) + '</span><span class="sp' + (wsp ? ' w' : '') + '">' + c.sprPct.toFixed(1) + '%</span></span>'; }
  function mrow(s, m, best, pend) { var p = pct(m), r = G.room(m), pl = G.plan(s, m), heat = (m.grp === 'up' || m.grp === 'against') ? ' sh-heat-' + (p >= 0 ? 'up' : 'dn') : '';
    var rd = pend && pend[m.sym] ? '<span class="rd" title="rank change: score now above the row over it; the order holds while your pointer or keys are in the list">▲' + pend[m.sym] + '</span>' : '';
    return '<div class="mrow' + heat + (m.sym === st.sel ? ' sel' : '') + (m.stale ? ' stale' : '') + (m.ban ? ' ban' : '') + (rd ? ' rrf' : '') + '" data-sym="' + m.sym + '" style="--m:' + Math.min(2, Math.abs(p)).toFixed(2) + '">' +
      '<span class="c-sh"><a class="lk" data-sym="' + m.sym + '">' + m.sym + '</a>' + rd + (st.pins[m.sym] ? '<span class="pin">PIN</span>' : '') + (held(m) ? '<span class="sh-c sh-c-held">HELD</span>' : '') + roleChip(m) + (best ? '<span class="st" title="best option R:R after costs among the COMING UP shares you could take">★</span>' : '') + '</span>' +
      '<span class="num pc ' + (p >= 0 ? 'up' : 'dn') + '" data-t="pc">' + sgp(p) + '</span>' +
      '<span class="num" title="RS30 vs sector; arrow = 15-min slope">' + sg2(m.rs30) + '<small class="' + (m.sl === '↗' ? 'up' : m.sl === '↘' ? 'dn' : 't3') + '">' + m.sl + '</small></span>' +
      '<span class="num" title="RVOL vs the 20-session median to this minute; arrow = rising">' + m.rvol.toFixed(1) + '<small class="' + (m.rvUp ? 'up' : 't3') + '">' + (m.rvUp ? '▲' : '→') + '</small></span>' +
      sideCell(m) +
      '<span class="c-rm' + (r.used > 0.8 ? ' am' : '') + '" title="ATR used ' + r.used.toFixed(2) + ' · ATR left ' + r.left.toFixed(2) + ' (ATR14 ' + lv(m.atr) + ')">' + r.used.toFixed(1) + '<span class="t3">·</span>' + r.left.toFixed(1) + '</span>' +
      '<span class="c-bu">' + buChip(m.bu) + (m.oi > 0 ? '+' : '') + m.oi.toFixed(1) + '%</span>' +
      '<span class="c-wt" title="weight in the sector (all listed, free-float)"><span class="wtb"><i style="width:' + Math.min(100, m.wt / 31 * 100) + '%"></i></span>' + m.wt.toFixed(1) + '</span>' +
      optCell(s, m) + gateCell(s, m, pl) + aiCell(m) + '<span class="c-ag" data-t="ag" title="share quote age · option quote ' + G.contract(s, m, 'atm').oage + 's">' + (mode() === 'preopen' ? 'close' : m.age) + '</span></div>'; }

  function whyHtml(s, long) { var w = s.why;
    if (!w) return '<span class="whyl">WHY</span><b class="un">UNEXPLAINED</b><span class="t3 ell">no driver or story found today (checked 11:05)</span>';
    var a = [];
    if (w.drv) a.push('<b class="sn">' + esc(w.drv) + ' <span class="up2">' + esc(w.live) + '</span></b>');
    else a.push('<span class="t2">today:</span><b class="un">UNEXPLAINED</b>' + (w.live ? '<span class="t3">·</span><span class="t2" title="a live market fact, not a driver">live: <b class="sn">' + esc(w.live) + '</b></span>' : ''));
    if (w.story) a.push('<span class="t3">·</span><b class="sn ell">' + esc(w.story) + ' <span class="t3" style="font-weight:400">(' + esc(w.src) + ' · ' + w.sage + ')</span></b>');
    if (w.note) a.push('<span class="t3">·</span><span class="t2 ell">' + esc(w.note) + '</span>');
    if (w.bg) a.push('<span class="t3">·</span><span class="t3 ell" title="background, earlier sessions - not today\'s driver">background · ' + esc(w.bg.join(' · ')) + '</span>');
    if (!w.drv && w.story) a[0] = '<span class="t2">no live driver</span>';
    return '<span class="whyl">WHY</span>' + a.join(''); }
  function sline(s) { var fo = G.fo(s), run = s.run, up = s.dir > 0, nar = G.narrow(s), pend = G.pendingRR(s);
    var l1 = '<div class="sl"><b class="snm">' + s.id.toUpperCase() + '</b><b class="pc ' + (up ? 'up' : 'dn') + '">' + (up ? '▲ ' : '▼ ') + sgp(s.pct) + '</b>' +
      '<span class="t2">' + (s.idx ? s.idx : 'basket all ' + s.n) + '</span>' + (s.idx && s.bpct != null ? '<span class="r16 t3">(basket ' + sgp(s.bpct) + ')</span>' : '') + '<button class="lkx" data-bas="' + s.id + '" title="the basis of this move (R49)">basis ›</button><span class="sep">·</span>' +
      '<span><span class="r16">breadth </span>all ' + s.n + ' <b class="up">▲' + s.up + '</b> <b class="dn">▼' + s.dn + '</b></span><span class="sep">·</span><span>F&amp;O <b class="up">▲' + fo.up + '</b> <b class="dn">▼' + fo.dn + '</b></span><span class="sep">·</span>' +
      '<span>RS30 <b>' + sg2(s.rs30) + '</b></span>' + (s.conf ? '<span class="sh-c sh-c-info" title="rotation confirmed ' + s.conf + '"><span class="r16">CONFIRMED</span><span class="r13">CONF</span> ' + s.conf + '</span>' : '') + (nar ? '<span class="sh-c sh-c-stale" title="NARROW - F&amp;O-only move: F&amp;O ' + Math.round(nar.fo * 100) + '% one way, the other listed shares only ' + Math.round(nar.nf * 100) + '%">NARROW</span>' : '') +
      (run ? '<span class="sep">·</span><span title="sector run clock: how long this move has run vs the typical run of such moves (n = past runs)">' + (up ? 'up' : 'down') + ' since <b>' + run.since + '</b> · <b>' + run.len + '</b></span><span class="runb' + (up ? '' : ' dn') + '"><i style="width:' + Math.min(100, mins(run.len) / mins(run.typ) * 100).toFixed(0) + '%"></i></span><span>typ ' + run.typ.replace(' ', '') + ' n=' + run.nn + '</span><span class="' + (run.fade ? 'dn' : 't2') + '" title="breadth now vs 15 min ago">' + (run.fade ? 'FADING ' : '') + run.br + (run.fade ? '' : ' ▲') + '</span>' : '') + '</div>';
    var rrc = pend ? '<button class="chip rrc" id="rrChip" title="the order never changes under your pointer or keys: the new order applies when the pointer leaves the list, after 30 s with the pointer and focus outside the list, or on R">re-ranked <kbd>R</kbd> apply</button>' : '';
    var l2 = '<div class="sl">' + whyHtml(s) + '<span class="gr"><span class="sh-c sh-c-info" title="Expiry week: Nov expires Mon 23 Nov (Tue 24 holiday); in-the-money stock options are physically settled, so December (Tue 29 Dec) is the only month offered">Expiry week · physical - Dec only</span>' + rrc + '</span></div>';
    var mb = { forming: ['info', 'FORMING · before 09:30 - the list settles on closed bars at 09:30, no new entries from it'], manage: ['ready', 'MANAGE ONLY - no new entries after 14:30 · exits by 15:10'], locked: ['exit', 'LOCKED - no new trades today · loss lock ₹10,000 hit'], preopen: ['info', 'PRE-OPEN - NOT LIVE · levels and groups from the 18 Nov close'], held: ['held', 'you already hold Banks: BANKBARODA 275 CE · 1 lot · trades 1 of 3'] }[mode()];
    var l3 = mb && (mode() !== 'held' || s.id === 'Banks') ? '<div class="sl mbn mb-' + mb[0] + '">' + mb[1] + '</div>' : '';
    return l1 + l2 + l3; }

  function srow(s, i, open) { var ix = G.ideas(s), fo = G.fo(s), up = s.dir > 0, p = s.pct;
    var stc = { 'ROT CONFIRMED': 'sh-c-info', 'IN': 'out-up', 'OUT': 'out-dn', 'NOT THIS ROT': 'nt', 'SHORTS LEAVE': 'sh-c-sc' }[s.st] || 'nt';
    var stt = s.st ? '<span class="sh-c ' + stc + '">' + s.st + (s.stAge ? ' ' + s.stAge : '') + '</span>' : '<span class="t3">-</span>';
    if (s.run && s.run.fade) stt = '<span class="sh-c sh-c-stale" title="breadth slipping ' + s.run.br + ' in 15 min">FADING ' + s.run.br + '</span>';
    if (G.narrow(s)) stt = '<span class="sh-c sh-c-stale" title="NARROW - F&amp;O-only move">NARROW</span>';
    return '<div class="srow sh-heat-' + (p >= 0 ? 'up' : 'dn') + (open ? ' open' : '') + '" data-s="' + s.id + '" data-i="' + i + '" tabindex="0" style="--m:' + Math.min(2, Math.abs(p)).toFixed(2) + '" title="click or Enter = ' + (open ? 'close' : 'open its F&amp;O shares') + ' · key ' + (i + 1) + '">' +
      '<span class="rk">' + (i + 1) + '</span><span class="nm"><span class="cv">' + (open ? '▾' : '▸') + '</span><b>' + s.id + '</b><span class="bas">' + s.basis + '</span></span>' +
      '<span class="ce" title="F&amp;O ideas in this sector: ' + ix.ce + ' CE · ' + ix.pe + ' PE (the up-side is never collapsed)">' + (up ? '<span class="sh-c sh-c-ce">CE ' + ix.ce + '</span><span class="t3">PE ' + ix.pe + '</span>' : '<span class="sh-c sh-c-pe">PE ' + ix.pe + '</span><span class="t3">CE ' + ix.ce + '</span>') + '</span>' +
      '<span class="num' + (i === 0 ? ' hl' : '') + '">' + sg2(s.rs30) + '</span><span class="num">#' + s.today + '</span>' +
      '<span class="dy"><b class="pc ' + (p >= 0 ? 'up' : 'dn') + '">' + sgp(p) + '</b><span class="hb2"><i class="' + (p >= 0 ? 'p' : 'n') + '" style="width:' + Math.min(50, Math.abs(p) / 1.5 * 50) + '%"></i></span></span>' +
      '<span class="br">' + (up ? s.up : s.dn) + '/' + s.n + (up ? '<span class="up">▲</span>' : '<span class="dn">▼</span>') + '<span>·</span>' + (up ? fo.up : fo.dn) + '/' + fo.n + '</span>' +
      '<span class="cr" title="free-float mcap ₹' + s.ff + ' lakh cr (all listed) × 30-min move vs NIFTY">' + (s.cr > 0 ? '+' : '') + F(s.cr, 0) + (s.bu ? '<span class="sh-c sh-c-' + s.bu.toLowerCase() + '">' + s.bu + '</span>' : '<span class="sh-c nt">-</span>') + '</span>' +
      '<span class="st">' + stt + '</span></div>'; }

  function drawTable() {
    var wb = $('#wb'), h = '';
    S.forEach(function (s, i) {
      if (s.id !== st.open) { h += srow(s, i, false); return; }
      var gs = visibleGroups(s), best = bestPick(s), pend = G.pendingRR(s), hasLag = gs.some(function (x) { return x.g === 'lag'; });
      h += '<div class="blk' + (st.nfo[s.id] ? ' nfo' : '') + '" data-s="' + s.id + '"><div class="bh">' + srow(s, i, true) + sline(s) +
        '<div class="mhd"><span>group</span><span>share · role</span><span class="r">day %</span><span class="r" title="RS30 vs sector, 15-min slope">vs sec</span><span class="r">RVOL</span><span>VWAP/OR</span><span title="ATR used · ATR left">room</span><span title="build-up, all months · OI chg">B/U · OI</span><span class="r">wt %</span><span title="December strike · ask premium · bid/ask spread %">Dec strike · prem · %</span><span>state / gate</span><span>AI</span><span class="r">age</span></div></div>';
      gs.forEach(function (x, gi) { var L = G.gLabel(s, x.g, x.items.length);
        if (x.g !== 'up' && x.g !== 'lead' && !hasLag && (gi === 0 || gs[gi - 1].g === 'up' || gs[gi - 1].g === 'lead')) h += nolag(s);
        var g2 = x.g === 'lead' ? (x.items[0].ext ? 'extended · pullback' : 'a gate fails') : x.g === 'nt' ? (x.items[0].ban ? 'F&amp;O ban' : L[1]) : L[1];
        h += '<div class="grp g-' + x.g + '"><div class="gl" title="' + L[0] + ' · ' + L[1] + '"><span class="g1">' + L[0] + '</span><span class="g2">' + g2 + '</span></div><div class="gi">' +
          x.shown.map(function (m) { return mrow(s, m, m.sym === best, pend); }).join('') +
          (x.hidden.length ? '<button class="morebar" data-more="' + s.id + '" title="show the ' + x.hidden.length + ' hidden shares (J also opens it)">▾ +' + x.hidden.length + ' more: ' + x.hidden.map(function (m) { return m.sym; }).join(' · ') + '</button>' : (st.more[s.id] && x.g === 'wait' && x.cap ? '<button class="morebar" data-more="' + s.id + '">▴ show fewer (' + (x.items.length - x.cap) + ')</button>' : '')) + '</div></div>'; });
      if (!hasLag && gs.every(function (x) { return x.g === 'up' || x.g === 'lead'; })) h += nolag(s);
      var nf = s.nonfo;
      h += '<div class="nonfo" data-nfo="' + s.id + '" tabindex="0" title="context only - they never get a strike"><span>' + (st.nfo[s.id] ? '▾' : '▸') + '</span><b>' + nf.n + '</b> more listed, not F&amp;O <span>·</span> <b class="up">▲' + nf.up + '</b> <b class="dn">▼' + nf.dn + '</b> <span>·</span> wt <b>' + nf.wt + '%</b> <span>· context only, no strike</span></div>' +
        '<div class="nfx">' + (nf.ex.length ? nf.ex.map(function (a) { return '<span><b>' + a[0] + '</b> <span class="' + (a[1] >= 0 ? 'up' : 'dn') + '">' + sgp(a[1]) + '</span></span>'; }).join('') + '<span>and ' + (nf.n - nf.ex.length) + ' more · F2 board for all</span>' : '<span>' + nf.n + ' shares · F2 board for all</span>') + '</div></div>';
    });
    var y = wb.scrollTop; wb.innerHTML = h; wb.scrollTop = y;
    $('#openTxt').textContent = st.open ? st.open + ' open' : 'click a sector';
    rails.forEach(function (r) { r.upd(); });
  }
  function nolag(s) { var b = Math.round(s.lagRule.bw * 100); return s.lagRule.ok ? '' : '<div class="grp g-lag nolag"><div class="gl"><span class="g1">LAGGARD</span></div><div class="gi"><div class="nl">no laggard - breadth ' + b + '% one way, below the 70% rule</div></div></div>'; }

  // ---------------- the share pane ----------------
  function paneSector(s) {
    var rows = s.members.filter(function (m) { return m.grp === 'up' || m.grp === 'lead' || m.grp === 'lag'; }), best = bestPick(s);
    var h = '<div class="ps"><div class="stt">pick a share · J / K or click</div><div class="p2">' + s.id + ' stays open on the left · the pane loads your pick</div></div>' +
      '<div class="ps"><div class="stt">compare on the option · Dec ATM ' + (s.dir > 0 ? 'CE' : 'PE') + '</div><table class="cmp"><colgroup>' + (wide() ? '<col style="width:23%"><col style="width:11%"><col style="width:11%"><col style="width:9%"><col style="width:8%"><col style="width:10%"><col style="width:9%"><col style="width:8%"><col style="width:11%">' : '<col style="width:27%"><col style="width:13%"><col style="width:13%"><col style="width:10%"><col style="width:9%"><col style="width:11%"><col style="width:7%"><col style="width:10%">') + '</colgroup><tr><th>share</th><th>strike</th><th>ask</th><th title="bid/ask spread in %">sprd</th><th>Δ</th><th>₹k/lot</th><th>room</th>' + (wide() ? '<th>IV</th>' : '') + '<th>R:R</th></tr>' +
      rows.map(function (m) { var c = G.contract(s, m, 'atm'), p = G.plan(s, m), r = G.room(m); return '<tr class="' + (m.sym === best ? 'best' : '') + '"><td data-sym="' + m.sym + '" title="click = load ' + m.sym + '">' + m.sym + (m.sym === best ? ' ★' : '') + '</td><td>' + kT(c.K) + '</td><td>' + px(c.ask) + '</td><td>' + c.sprPct.toFixed(1) + '</td><td>' + Math.abs(c.d).toFixed(2) + '</td><td title="₹' + F(c.lotCost, 0) + '">' + (c.lotCost / 1000).toFixed(1) + '</td><td>' + r.left.toFixed(1) + '</td>' + (wide() ? '<td>' + (c.iv * 100).toFixed(1) + '</td>' : '') + '<td class="' + (p.rr < 1 ? 'dn' : '') + '">' + p.rr.toFixed(2) + '</td></tr>'; }).join('') + '</table><div class="how" style="margin-top:4px">★ best R:R after costs that you could take · room = ATR left</div></div>';
    return h; }

  function drawPane() {
    var pb = $('#pb'), y = pb.scrollTop;
    var f = st.sel ? G.find(st.sel) : null, s = f ? f.s : sec(st.open);
    $('#spSym').textContent = f ? f.m.sym : (s ? s.id : '');
    if (!f) { pb.innerHTML = s ? paneSector(s) : '<div class="ps"><div class="stt">no sector open</div><div class="p2">click a sector row, a flow label or press 1-9</div></div>'; rails.forEach(function (r) { r.upd(); }); return; }
    var m = f.m, p = G.plan(s, m), a = G.contract(s, m, 'atm'), i = G.contract(s, m, 'itm'), r = G.room(m), pc = pct(m), ce = p.cp === 'CE';
    $('#flShare').href = 'share.html#' + m.sym; $('#flChain').href = 'chain.html#' + m.sym + '-' + a.K + a.cp;
    var dV = (m.ltp - m.vwap) / m.atr, gl = G.gLabel(s, m.grp, 1)[0].replace(/ \(\d+\)$/, '');
    var hard = /^(BAN|LOCKED|STALE|OPTION STALE)/.test(p.block), hb = '';
    if (hard || p.block) hb = '<div class="hbn ' + (/^BAN|LOCKED/.test(p.block) ? 'rd' : 'gy') + '"><b>' + esc(p.block) + '</b><span>' + esc(p.why) + '</span></div>';
    var h = hb + '<div class="ps"><div class="p1"><a class="lk big" data-f7="' + m.sym + '" title="double-click or Enter = full F7 Share page (a single click does nothing)">' + m.sym + '</a>' + roleChip(m) + '<span class="px" data-t="px">' + px(m.ltp) + '</span><span class="pc ' + (pc >= 0 ? 'up' : 'dn') + '" data-t="ppc">' + sgp(pc) + '</span><span class="age" data-t="pag">' + m.age + '</span></div>' +
      '<div class="p1b"><span class="sh-c ' + (m.grp === 'up' ? (ce ? 'sh-c-ce' : 'sh-c-pe') : m.grp === 'against' ? (ce ? 'sh-c-ce' : 'sh-c-pe') : 'nt') + '">' + gl + '</span><span>lot <b>' + F(m.lot, 0) + '</b> · weight <b>' + m.wt.toFixed(1) + '%</b> of sector</span></div>' +
      '<div class="p2">VWAP <b>' + lv(m.vwap) + '</b> <span class="' + (dV >= 0 ? 'up' : 'dn') + '">' + (dV >= 0 ? '▲ +' : '▼ −') + Math.abs(dV).toFixed(2) + ' ATR</span> · OR <b>' + lv(m.orL) + '-' + lv(m.orH) + '</b> ' + (m.ltp > m.orH ? '<span class="up">▲</span>' : m.ltp < m.orL ? '<span class="dn">▼</span>' : 'inside') + '</div>' +
      '<div class="p2">vs sector RS30 <b>' + sg2(m.rs30) + ' ' + m.sl + '</b> · RVOL <b>' + m.rvol.toFixed(1) + (m.rvUp ? ' ▲ rising' : ' → flat') + '</b> · score <b>' + m.score.toFixed(2) + '</b></div>' +
      '<div class="p2">room: ATR used <b>' + r.used.toFixed(2) + '</b> · left <b>' + r.left.toFixed(2) + '</b> · EXT <b>' + G.extOf(m).toFixed(2) + '</b>' + (m.ext ? ' · <span style="color:var(--action)">EXTENDED - don\'t chase</span>' : '') + '</div>' +
      '<div class="p2">OI build-up ' + buLink(m.bu, m.sym) + ' Nov <b>' + sg1(m.buN) + '%</b> · Dec <b>' + sg1(m.buD) + '%</b> · all <b>' + sg1(m.oi) + '%</b></div></div>';
    // warnings in plain words, each with the fix
    var warn = [];
    if (a.sprPct > 1.2) { var alt = i.sprPct < a.sprPct ? (kT(i.K) + ' ' + i.cp + ' has ' + i.sprPct.toFixed(1) + '%') : 'no better strike - wait or skip'; warn.push('<span class="wn am">SPREAD ' + a.sprPct.toFixed(1) + '% = ₹' + F(a.sprLot, 0) + ' lost on entry; ' + alt + '</span>'); }
    if (a.dep < 5) warn.push('<span class="wn am">THIN depth: ' + a.dep + ' lots at bid</span>');
    if (m.mwpl >= 80 && !m.ban) warn.push('<span class="wn ' + (m.mwpl >= 90 ? 'rd' : 'am') + '">MWPL ' + m.mwpl + '% · near ban (ban at 95%)</span>');
    if (m.resT) warn.push('<span class="wn am">RESULTS ' + m.resT + ' - IV crush</span>');
    if (/^ex-date/.test(m.exd)) warn.push('<span class="wn am">' + esc(m.exd) + '</span>');
    if (mode() === 'held' && s.id === 'Banks') warn.push('<span class="wn am">you already hold this sector: BANKBARODA 275 CE</span>');
    if (p.warn) warn.unshift('<span class="wn rd">' + esc(p.warn) + '</span>');
    if (!warn.length && !p.block) warn.push('<span class="wn ok">spread ' + a.sprPct.toFixed(1) + '%</span><span class="wn ok">depth ' + a.dep + ' lots</span><span class="wn ok">IV/20d ' + (a.iv / a.iv20).toFixed(2) + '</span><span class="wn ok">MWPL ' + m.mwpl + '%</span><span class="wn ok">data ' + m.age + ' / opt ' + a.oage + 's</span>');
    var star = p.takeable ? ' ★' : '', dim = (m.stale || a.ostale) ? ' dim' : '';
    h += '<div class="ps"><div class="stt" style="color:var(--' + (ce ? 'up' : 'down') + ')">trade box · December 29 Dec</div><div class="xw" title="Nov expires Mon 23 Nov (Tue 24 holiday); in-the-money stock options are physically settled">Expiry week · physical settlement - December only</div>' +
      '<table class="tbx' + dim + '"><colgroup><col style="width:36%"><col><col></colgroup><tr><th></th><th class="pk"><span class="sh-c sh-c-' + a.cp.toLowerCase() + '">' + kT(a.K) + ' ' + a.cp + '</span> ATM' + star + '</th><th><span class="sh-c sh-c-' + i.cp.toLowerCase() + '">' + kT(i.K) + ' ' + i.cp + '</span> 1 ITM</th></tr>' +
      [['bid / ask', px(a.bid) + ' / ' + px(a.ask), px(i.bid) + ' / ' + px(i.ask)], ['quote age', '<span class="' + (a.ostale ? 'dn' : '') + '">' + a.oage + 's</span>', '<span class="' + (i.ostale ? 'dn' : '') + '">' + i.oage + 's</span>'], ['spread per lot', '₹' + F(a.sprLot, 0) + ' · ' + a.sprPct.toFixed(1) + '%', '₹' + F(i.sprLot, 0) + ' · ' + i.sprPct.toFixed(1) + '%'], ['depth at bid', a.dep + ' lots', i.dep + ' lots'],
        ['Δ · θ ₹/h per lot', Math.abs(a.d).toFixed(2) + ' · −₹' + F(a.thh, 0), Math.abs(i.d).toFixed(2) + ' · −₹' + F(i.thh, 0)], ['IV vs 20-day', (a.iv * 100).toFixed(1) + ' / ' + (a.iv20 * 100).toFixed(1), (i.iv * 100).toFixed(1) + ' / ' + (i.iv20 * 100).toFixed(1)],
        ['lot cost = max loss', '₹' + F(a.lotCost, 0), '₹' + F(i.lotCost, 0)], ['break-even 15:10', lv(a.be) + ' (' + (ce ? '+' : '−') + a.bePts.toFixed(1) + ')', lv(i.be) + ' (' + (ce ? '+' : '−') + i.bePts.toFixed(1) + ')']]
        .map(function (rw) { return '<tr><td>' + rw[0] + '</td><td class="pk">' + rw[1] + '</td><td>' + rw[2] + '</td></tr>'; }).join('') + '</table>' + (warn.length ? '<div class="warns">' + warn.join('') + '</div>' : '') + '</div>';
    // the plan: hidden for a banned share (only close existing); every other block shows the levels but 0 lots and the reason
    if (m.ban) h += '<div class="ps"><div class="rk3"><b class="dn">BAN - only close existing.</b> No entry plan for a share in the F&amp;O ban.</div><div class="rk3">you hold no ' + m.sym + ' position · nothing to close</div></div>';
    else h += '<div class="ps"><div class="pl3"><span></span><span class="hd">share</span><span class="hd">premium</span>' +
      '<span class="l">trigger</span><span class="v">' + lv(p.trig) + '</span><span class="v"><small>≈</small>' + px(p.pT) + '</span>' +
      '<span class="l">stop</span><span class="v dn">' + lv(p.stop) + '</span><span class="v dn"><small>≈</small>' + px(p.pS) + '</span>' +
      '<span class="l">target</span><span class="v up">' + lv(p.tgt) + '</span><span class="v up"><small>≈</small>' + px(p.pG) + '</span></div>' +
      '<div class="how" title="' + esc(p.how) + '">' + esc(p.how) + '</div>' +
      '<div class="rk3">risk 1 lot <b>₹' + F(p.risk, 0) + '</b> = ' + (p.risk / G.R1).toFixed(2) + 'R · R:R <b class="' + (p.rr < 1 ? 'dn' : '') + '">' + p.rr.toFixed(2) + '</b> after costs</div><div class="rk3 t3">costs ₹' + p.costs + ' = charges ₹' + p.charges + ' + slippage ₹' + p.slip + '</div>' +
      '<div class="rk3" title="lock room ₹' + F(G.LOCK, 0) + ' (if all stops hit) and the 1R rule (₹' + F(G.R1, 0) + ')">' + esc(p.sizeTxt) + '</div><div class="rk3"><span class="lots' + (p.lots ? '' : ' z') + '">' + esc(p.lotsTxt) + '</span></div>' +
      '<div class="rk3">trades <b>' + (mode() === 'held' ? '1' : '0') + ' of 3</b> · 15:10 in <b>' + G.MODES[mode()].left + '</b> · ' + (mode() === 'held' && s.id === 'Banks' ? 'you hold BANKBARODA 275 CE' : 'you hold no ' + s.id + ' trade') + '</div></div>';
    h += '<div class="ps"><div class="wl">5-min · VWAP ' + lv(m.vwap) + ' · OR · walls CE ' + F(m.wallC, 0) + ' / PE ' + F(m.wallP, 0) + '</div>' + G.chartSvg(s, m, p, $('#pb').clientWidth - (wide() ? 24 : 20), { hp: wide() ? 112 : 92, hq: wide() ? 38 : 32 }) + '</div>';
    h += '<div class="ps"><div class="ai"><span class="lab">AI</span>' + (m.aiv && mode() === 'live' ? '<span class="sh-c sh-c-ready">GET READY</span><span class="ell">' + esc(m.aiv.replace(/^GET READY /, '')) + '</span>' : '<b>AI silent</b><span class="t3">- your read</span>') + '</div></div>';
    h += '<div class="ps"><div class="evs"><span class="ev' + (m.resT ? ' am' : '') + '">' + esc(m.res) + '</span><span class="ev' + (/^ex-date/.test(m.exd) ? ' am' : '') + '">' + esc(m.exd) + '</span><span class="ev ' + (m.mwpl >= 90 ? 'rd' : m.mwpl >= 80 ? 'am' : '') + '">MWPL ' + m.mwpl + '%</span></div></div>';
    h += '<div class="ps">' + (m.news.length ? m.news.slice(0, 2).map(function (n) { return '<div class="nw" title="' + esc(n[2]) + '"><span class="tm">' + n[0] + ' · ' + n[3] + '</span><b>' + n[1] + '</b> · ' + esc(n[2]) + '</div>'; }).join('') : '<div class="nw t3">no story of its own today</div>') + '</div>';
    var canCopy = p.takeable, copyLbl = canCopy ? 'Copy contract' : (m.ban ? 'BAN - only close existing' : 'Copy off · 0 lots');
    h += '<div class="ps" style="border-bottom:0"><div class="kt"><span class="sig t3">GIR never places orders - you place the order in Kite.</span><button class="btn" id="bCopy"' + (canCopy ? '' : ' disabled aria-disabled="true"') + ' title="' + (canCopy ? 'copy the contract name for Kite' : 'no contract to copy: ' + esc(p.lotsTxt)) + '">' + copyLbl + '</button><span class="n t2" id="ctr">' + m.sym + ' 29DEC ' + kT(a.K).replace(/,/g, '') + ' ' + a.cp + '</span></div></div>';
    pb.innerHTML = h; pb.scrollTop = st.keepPaneY ? y : 0; st.keepPaneY = false;
    $('#bP').innerHTML = '<kbd>P</kbd>' + (st.pins[m.sym] ? 'pinned' : 'pin');
    rails.forEach(function (r) { r.upd(); });
  }

  function drawRun() { $('#rb').innerHTML = S.filter(function (s) { return s.run; }).map(function (s) { var r = s.run, up = s.dir > 0, L = mins(r.len), Ty = mins(r.typ), max = 150;
      return '<div class="rr" data-s="' + s.id + '" tabindex="0"><span><b>' + s.id + '</b> <span class="pc ' + (up ? 'up' : 'dn') + '">' + sgp(s.pct) + '</span></span><span class="rbar"><i style="left:0;width:' + (L / max * 100) + '%;background:var(--' + (up ? 'up' : 'down') + ')"></i><u style="left:' + (Ty / max * 100) + '%"></u></span><span>' + (up ? 'up' : 'down') + ' since ' + r.since + ' · ' + r.len + ' / typ ' + r.typ + ' n=' + r.nn + ' · <span class="' + (r.fade ? 'dn' : '') + '">' + (r.fade ? 'FADING ' : '') + r.br + '</span></span></div>'; }).join(''); }

  // ---------------- drawn, draggable scrollbars (track >= 10 px, buttons 16 px) ----------------
  var rails = [];
  function Rail(rail) {
    var scb = document.getElementById(rail.dataset.for), trk = $('.trk', rail), th = $('i', trk);
    function upd() { var sh = scb.scrollHeight, ch = scb.clientHeight, H = trk.clientHeight; if (!H) return; if (sh <= ch + 1) { rail.classList.add('all'); th.style.top = '0px'; th.style.height = H + 'px'; return; }
      rail.classList.remove('all'); var hh = Math.max(24, H * ch / sh); th.style.height = hh + 'px'; th.style.top = ((H - hh) * scb.scrollTop / (sh - ch)) + 'px'; }
    scb.addEventListener('scroll', upd); if (window.ResizeObserver) new ResizeObserver(upd).observe(scb);
    th.addEventListener('pointerdown', function (e) { if (e.button !== 0) return; e.preventDefault(); e.stopPropagation(); try { th.setPointerCapture(e.pointerId); } catch (x) {}
      var y0 = e.clientY, s0 = scb.scrollTop, k = (scb.scrollHeight - scb.clientHeight) / Math.max(1, trk.clientHeight - th.offsetHeight); rail.classList.add('drag');
      function mv(ev) { scb.scrollTop = s0 + (ev.clientY - y0) * k; }
      function up() { th.removeEventListener('pointermove', mv); th.removeEventListener('pointerup', up); th.removeEventListener('pointercancel', up); rail.classList.remove('drag'); }
      th.addEventListener('pointermove', mv); th.addEventListener('pointerup', up); th.addEventListener('pointercancel', up); });
    trk.addEventListener('pointerdown', function (e) { if (e.target === th) return; upd(); var r = th.getBoundingClientRect(); scb.scrollTop += (e.clientY < r.top ? -1 : 1) * scb.clientHeight * 0.9; upd(); });
    $('.rb.u', rail).addEventListener('click', function (e) { e.stopPropagation(); scb.scrollTop -= 52; upd(); });
    $('.rb.d', rail).addEventListener('click', function (e) { e.stopPropagation(); scb.scrollTop += 52; upd(); });
    rail.addEventListener('wheel', function (e) { scb.scrollTop += e.deltaY; upd(); e.preventDefault(); }, { passive: false });
    var o = { upd: upd, scb: scb }; rails.push(o); return o;
  }

  // ---------------- re-rank: never under the pointer or keys ----------------
  function applyRR() { var s = st.open && sec(st.open); if (!s || !G.pendingRR(s)) return false; s.members.forEach(function (m) { m.s0 = m.score; }); delete st.rrSince[s.id]; drawTable(); if (!st.simAt) st.simAt = Date.now() + 8000; return true; }
  function focusInList() { var a = document.activeElement; return !!(a && a.closest && a.closest('#wb')); }
  setInterval(function () { var s = st.open && sec(st.open); if (!s) return; var pend = G.pendingRR(s);
    if (!pend) { delete st.rrSince[s.id]; return; } if (!st.rrSince[s.id]) st.rrSince[s.id] = Date.now();
    if (!st.inList && !focusInList() && Date.now() - st.rrSince[s.id] >= RR_MS) applyRR(); }, 250);
  // tick simulator: numbers keep ticking in fixed-width cells (the order and the open row never move); 8 s after the first
  // applied re-rank ICICIBANK's score rises again, so a new rank change is pending while the pointer / keys are in the list
  var tickN = 0;
  setInterval(function () { tickN++; if (mode() === 'preopen') return; var s = st.open && sec(st.open); if (!s) return;
    $$('#wb .mrow').forEach(function (row, j) { var f = G.find(row.dataset.sym); if (!f || f.m.stale) return; var m = f.m, tk = G.tickOf(m.ltp), w = ((tickN + j) % 3) - 1, l = m.ltp + w * tk, p = (l / m.prev - 1) * 100;
      var pc = $('[data-t="pc"]', row); if (pc) pc.textContent = sgp(p); var ag = $('[data-t="ag"]', row); if (ag) ag.textContent = (0.2 + ((tickN * 7 + j * 3) % 8) / 10).toFixed(1) + 's';
      if (m.sym === st.sel) { var x = $('#pb [data-t="px"]'); if (x) x.textContent = px(l); var y = $('#pb [data-t="ppc"]'); if (y) y.textContent = sgp(p); var z = $('#pb [data-t="pag"]'); if (z) z.textContent = ag ? ag.textContent : m.age; } });
    if (st.simAt && Date.now() >= st.simAt && s.id === 'Banks') { st.simAt = -1; var ic = G.find('ICICIBANK').m, ax = G.find('AXISBANK').m; ic.score = ax.score + 0.03; markRR(); }
  }, 1000);
  function markRR() { var s = st.open && sec(st.open); if (!s) return; var pend = G.pendingRR(s);
    $$('#wb .mrow').forEach(function (row) { var on = !!(pend && pend[row.dataset.sym]), rd = $('.rd', row); row.classList.toggle('rrf', on);
      if (on && !rd) { var a = $('.lk', row); a.insertAdjacentHTML('afterend', '<span class="rd" title="rank change pending">▲' + pend[row.dataset.sym] + '</span>'); } else if (!on && rd) rd.remove(); });
    var gr = $('.blk .sl .gr'); if (gr && pend && !$('#rrChip')) gr.insertAdjacentHTML('beforeend', '<button class="chip rrc" id="rrChip" title="applies when the pointer leaves the list, after 30 s, or on R">re-ranked <kbd>R</kbd> apply</button>'); }

  // ---------------- actions ----------------
  function toast(t) { var e = $('#toast'); e.textContent = t; e.classList.add('on'); clearTimeout(toast.t); toast.t = setTimeout(function () { e.classList.remove('on'); }, 1800); }
  function closePops() { var any = false; ['#whyD', '#planD', '#basP', '#mockM'].forEach(function (q) { var e = $(q); if (e && e.classList.contains('on')) { e.classList.remove('on'); any = true; } }); return any; }
  function openSector(id, keepSel) { closePops(); if (st.open === id && !keepSel) { st.open = null; st.sel = null; } else { st.open = id; if (!keepSel) st.sel = null; }
    drawTable(); drawPane(); if (st.open) { var b = $('.blk', $('#wb')); if (b) $('#wb').scrollTop = Math.max(0, b.offsetTop); } writeHash(); }
  function scrollSelIn() { var r = $('#wb .mrow.sel'), wb = $('#wb'); if (!r) return; var bh = $('.bh', wb) ? $('.bh', wb).offsetHeight : 0, rt = r.getBoundingClientRect(), wt = wb.getBoundingClientRect();
    if (rt.top < wt.top + bh) wb.scrollTop -= (wt.top + bh - rt.top); else if (rt.bottom > wt.bottom) wb.scrollTop += rt.bottom - wt.bottom; }
  function selShare(sym, scrollIn) { st.sel = sym; var s = st.open && sec(st.open);
    if (s && !$('#wb .mrow[data-sym="' + sym + '"]') && flatOrder(s).indexOf(sym) >= 0) { st.more[s.id] = 1; drawTable(); }   // a share behind "+n more": open the fold
    $$('#wb .mrow').forEach(function (r) { r.classList.toggle('sel', r.dataset.sym === sym); }); drawPane(); writeHash(); if (scrollIn) scrollSelIn(); }
  function moveSel(d) { var s = st.open && sec(st.open); if (!s) return false; var o = flatOrder(s); if (!o.length) return false; var i = o.indexOf(st.sel);
    i = i < 0 ? (d > 0 ? 0 : o.length - 1) : Math.max(0, Math.min(o.length - 1, i + d)); selShare(o[i], true); return true; }
  function goF7(sym) { writeHash(true); location.href = 'share.html#' + sym; }
  function needShare() { toast('pick a share first - click a row or press J'); }
  function goChain() { var f = st.sel && G.find(st.sel); if (!f) { needShare(); return; } var c = G.contract(f.s, f.m, 'atm'); writeHash(true); location.href = 'chain.html#' + f.m.sym + '-' + c.K + c.cp + '-29DEC'; }
  function showWhy() { var f = st.sel && G.find(st.sel); if (!f) { needShare(); return; } var d = $('#whyD'), s = f.s, m = f.m;
    if (d.classList.contains('on')) { d.classList.remove('on'); return; }
    d.innerHTML = '<div class="tt">why ' + m.sym + ' is moving<span class="x" data-close="whyD">✕ Esc</span></div><div class="wy"><b>Sector:</b> ' + whyHtml(s) + '</div>' +
      '<div><b>Share:</b> RS30 ' + sg2(m.rs30) + ' vs sector, RVOL ' + m.rvol.toFixed(1) + ', ' + G.sideTxt(m) + ', build-up ' + (m.bu || 'none') + ' ' + sg2(m.oi) + '%, score ' + m.score.toFixed(2) + '</div>' +
      (m.news.length ? m.news.map(function (n) { return '<div class="nw"><span class="tm">' + n[0] + '</span><b>' + n[1] + '</b> · ' + esc(n[2]) + ' <span class="t3">· ' + n[3] + '</span></div>'; }).join('') : '<div class="t3">no story of its own today</div>') + '<div style="margin-top:4px"><a class="lkx" href="news.html#' + m.sym + '">all stories · F4 ›</a></div>';
    $('#planD').classList.remove('on'); d.classList.add('on'); }
  function showPlan() { var f = st.sel && G.find(st.sel); if (!f) { needShare(); return; } var d = $('#planD'); if (d.classList.contains('on')) { d.classList.remove('on'); return; } var p = G.plan(f.s, f.m), a = G.contract(f.s, f.m, 'atm');
    d.innerHTML = '<div class="tt">plan card · ' + f.m.sym + ' ' + kT(a.K) + ' ' + a.cp + ' Dec<span class="x" data-close="planD">✕ Esc</span></div>' + (f.m.ban ? '<div><b class="dn">BAN - only close existing</b> · no entry plan</div>' : '<div>trigger <b>' + lv(p.trig) + '</b> (≈' + px(p.pT) + ') · stop <b>' + lv(p.stop) + '</b> (≈' + px(p.pS) + ') · target <b>' + lv(p.tgt) + '</b> (≈' + px(p.pG) + ')</div><div>' + esc(p.lotsTxt) + ' · max loss ₹' + F(p.risk, 0) + ' · R:R ' + p.rr.toFixed(2) + ' · hold until stop / target or 15:10</div>') + '<div style="margin-top:4px"><a class="lkx" href="plan-card.html#' + f.m.sym + '">full plan card ›</a></div>';
    $('#whyD').classList.remove('on'); d.classList.add('on'); }
  function togglePin() { if (!st.sel) { needShare(); return; } if (st.pins[st.sel]) delete st.pins[st.sel]; else { if (Object.keys(st.pins).length >= 5) { toast('5 pins max - unpin one first'); return; } st.pins[st.sel] = 1; }
    $('#pinN').textContent = Object.keys(st.pins).length; st.keepPaneY = true; drawTable(); drawPane(); toast(st.pins[st.sel] ? st.sel + ' pinned to the Desk watchlist (' + Object.keys(st.pins).length + '/5)' : st.sel + ' unpinned'); }
  function basis(btn) { var s = sec(btn.dataset.bas), p = $('#basP'); if (p.classList.contains('on')) { p.classList.remove('on'); return; } var r = btn.getBoundingClientRect(), pg = $('#pg').getBoundingClientRect(), nar = G.narrow(s);
    p.innerHTML = '<span class="x" data-close="basP">✕</span><b>Basis (R49)</b><br>Move: ' + (s.idx ? '<b>' + s.idx + ' ' + sgp(s.pct) + '</b> (the NSE sectoral index; it exists, so it is the move)' + (s.bpct != null ? '. For reference, the free-float basket of all ' + s.n + ' listed shares: ' + sgp(s.bpct) : '') : 'free-float weighted basket of <b>all ' + s.n + ' listed shares</b> ' + sgp(s.pct) + ' (no NSE index for this sector)') + '.<br>Breadth and weights: always over all ' + s.n + ' listed: ▲' + s.up + ' ▼' + s.dn + '. The F&amp;O list (' + s.members.length + ') is the tradable part; the other ' + s.nonfo.n + ' (▲' + s.nonfo.up + ' ▼' + s.nonfo.dn + ', ' + s.nonfo.wt + '% weight) are context only.<br>₹cr flow: free-float mcap ₹' + s.ff + ' lakh cr × the window move vs NIFTY.<br>' + (nar ? '<b>NARROW - F&amp;O-only move</b>: F&amp;O ' + Math.round(nar.fo * 100) + '% one way, the other listed ' + Math.round(nar.nf * 100) + '%.' : 'Not NARROW: the non-F&amp;O shares move with it.');
    p.style.left = Math.min(r.left - pg.left, pg.width - 400) + 'px'; p.style.top = (r.bottom - pg.top + 4) + 'px'; p.style.width = '390px'; p.classList.add('on'); }
  function setMock(k) { G.MODE.k = k; $('#mockB').innerHTML = 'mock: ' + MOCK[k] + ' ▾'; $('#mockM').classList.remove('on'); drawHero(); drawTable(); drawPane(); writeHash(); toast('mockup state: ' + MOCK[k]); }

  // ---------------- events ----------------
  document.addEventListener('click', function (e) { var t = e.target;
    var cl = t.closest('[data-close]'); if (cl) { $('#' + cl.dataset.close).classList.remove('on'); return; }
    if (t.closest('#rrChip')) { applyRR(); return; }
    if (t.closest('#mockB')) { $('#mockM').classList.toggle('on'); return; }
    var mk = t.closest('#mockM [data-mock]'); if (mk) { setMock(mk.dataset.mock); return; }
    var bb = t.closest('[data-bas]'); if (bb) { basis(bb); return; }
    var mo = t.closest('[data-more]'); if (mo) { st.more[mo.dataset.more] = !st.more[mo.dataset.more]; drawTable(); writeHash(); return; }
    var nf = t.closest('[data-nfo]'); if (nf) { st.nfo[nf.dataset.nfo] = !st.nfo[nf.dataset.nfo]; drawTable(); return; }
    if (t.closest('a[href]')) return;
    var mr = t.closest('.mrow'); if (mr) { selShare(mr.dataset.sym); return; }
    var sr = t.closest('.srow'); if (sr) { openSector(sr.dataset.s); return; }
    var ne = t.closest('.ne'); if (ne) { st.open = null; openSector(ne.dataset.s); selShare(ne.dataset.r, true); return; }
    var hz = t.closest('#flowSvg .hz.oth'); if (hz) { toast(hz.textContent.replace(/^others: /, 'others: ')); return; }
    var hs = t.closest('#flowSvg [data-s], #heroLine [data-s], .fs[data-s], .rr[data-s]'); if (hs && hs.getAttribute('data-s')) { var id = hs.getAttribute('data-s'); if (st.view === 'run') setView('tbl'); if (st.open !== id) openSector(id); else { var b = $('.blk', $('#wb')); if (b) $('#wb').scrollTop = b.offsetTop; } return; }
    var cm = t.closest('.cmp td[data-sym]'); if (cm) { selShare(cm.dataset.sym, true); return; }
    var wc = t.closest('#wch .chip'); if (wc) { st.win = +wc.dataset.w; drawHero(); return; }
    var vc = t.closest('#win .vchips .chip'); if (vc) { setView(vc.dataset.v); return; }
    if (t.closest('#bF7')) { if (st.sel) goF7(st.sel); else needShare(); return; }
    if (t.closest('#bO')) { goChain(); return; }
    if (t.closest('#bW')) { showWhy(); return; }
    if (t.closest('#bP')) { togglePin(); return; }
    if (t.closest('#bCopy')) { var bc = $('#bCopy'); if (bc.disabled) return; var c = $('#ctr').textContent; try { var pr = navigator.clipboard && navigator.clipboard.writeText(c); if (pr && pr.catch) pr.catch(function () {}); } catch (x) {} toast('copied: ' + c); return; }
    if (t.closest('#ddAll')) { toast('ALL SECTORS: 11 listed (no filter set)'); return; }
    if (t.closest('#pinC')) { toast(Object.keys(st.pins).length ? 'pinned: ' + Object.keys(st.pins).join(' · ') : 'no pins yet · P pins the share in the pane'); return; }
  });
  document.addEventListener('dblclick', function (e) { var mr = e.target.closest('.mrow') || e.target.closest('[data-f7]'); if (mr) goF7(mr.dataset.sym || mr.dataset.f7); });
  function setView(v) { st.view = v; $('#win').classList.toggle('v-run', v === 'run'); $$('#win .vchips .chip').forEach(function (c) { c.classList.toggle('on', c.dataset.v === v); }); if (v === 'run') drawRun(); rails.forEach(function (r) { r.upd(); }); }
  var wbEl = $('#wb');
  wbEl.addEventListener('pointerenter', function () { st.inList = true; });
  wbEl.addEventListener('pointerleave', function () { st.inList = false; if (st.open && G.pendingRR(sec(st.open))) applyRR(); });
  document.addEventListener('keydown', function (e) {
    var t = e.target, k = e.key, tag = t.closest ? t.closest('input,textarea,select') : null; if (tag) return;
    var ctl = t.closest && t.closest('button,a[href],[role="button"]');
    if (ctl && (k === 'Enter' || k === ' ')) return;                       // a focused control keeps Enter / Space for itself
    var inPane = t.closest && t.closest('#pb'), srowF = t.closest && t.closest('.srow'), other = t.closest && t.closest('.nonfo,.fs,.ne,#heroLine .s,.rr');
    if (other && (k === 'Enter' || k === ' ')) { other.click(); e.preventDefault(); return; }
    if (srowF && (k === 'Enter' || k === ' ')) { var sid = srowF.dataset.s; openSector(sid); var nf = $('.srow[data-s="' + sid.replace(/"/g, '') + '"]'); if (nf) nf.focus(); e.preventDefault(); return; }
    if (srowF && (k === 'ArrowDown' || k === 'ArrowUp')) { var rows = $$('#wb .srow'), ix = rows.indexOf(srowF), nx = rows[Math.max(0, Math.min(rows.length - 1, ix + (k === 'ArrowDown' ? 1 : -1)))]; if (nx) nx.focus(); e.preventDefault(); return; }
    if (/^[1-9]$/.test(k)) { var s = S[+k - 1]; if (s) { if (st.view === 'run') setView('tbl'); if (st.open !== s.id) openSector(s.id); } e.preventDefault(); return; }
    if (k === 'j' || k === 'J' || (k === 'ArrowDown' && !inPane)) { if (st.open && moveSel(1)) { e.preventDefault(); return; } if (!st.open) { st.kf = Math.min(S.length - 1, st.kf + 1); kf(); e.preventDefault(); } return; }
    if (k === 'k' || k === 'K' || (k === 'ArrowUp' && !inPane)) { if (st.open && moveSel(-1)) { e.preventDefault(); return; } if (!st.open) { st.kf = Math.max(0, st.kf - 1); kf(); e.preventDefault(); } return; }
    if (k === 'Enter') { if (st.sel) { goF7(st.sel); e.preventDefault(); } else if (st.kf >= 0 && !st.open) { openSector(S[st.kf].id); e.preventDefault(); } return; }
    if (k === 'o' || k === 'O') { goChain(); return; }
    if (k === 'w' || k === 'W') { showWhy(); return; }
    if (k === ' ') { if (st.sel) { showPlan(); e.preventDefault(); } else needShare(); return; }
    if (k === 'p' || k === 'P') { togglePin(); return; }
    if (k === 'r' || k === 'R') { applyRR(); return; }
    if (k === 'Escape') { if (closePops()) return; if (st.sel) { st.sel = null; $$('#wb .mrow.sel').forEach(function (r) { r.classList.remove('sel'); }); drawPane(); writeHash(); return; } if (st.open) { openSector(st.open); return; } return; }
    if ((k === 'PageDown' || k === 'PageUp' || k === 'Home' || k === 'End') && !(t.classList && t.classList.contains('scb'))) { var sc = $('#wb'); sc.scrollTop = k === 'Home' ? 0 : k === 'End' ? sc.scrollHeight : sc.scrollTop + (k === 'PageDown' ? 1 : -1) * sc.clientHeight * 0.9; e.preventDefault(); }
  });
  function kf() { $$('#wb .srow').forEach(function (r) { r.classList.toggle('kf', +r.dataset.i === st.kf); }); }

  // ---------------- boot ----------------
  readHash();
  $$('.rail').forEach(Rail);
  $('#mockB').innerHTML = 'mock: ' + MOCK[mode()] + ' ▾';
  $('#mockM').innerHTML = '<div class="tt">design mockup states</div>' + Object.keys(MOCK).map(function (k) { return '<button class="mi" data-mock="' + k + '">' + MOCK[k] + '</button>'; }).join('');
  drawHero(); drawTable(); drawPane();
  if (st.restoreY != null) $('#wb').scrollTop = st.restoreY;
  if (st.restoreFocus) { wbEl.focus({ preventScroll: true }); writeHash(); }
  window.addEventListener('resize', function () { drawHero(); drawTable(); drawPane(); });
  window.GIRDD = { st: st, openSector: openSector, selShare: selShare, applyRR: applyRR, setMock: setMock, RR_MS: RR_MS };
})();

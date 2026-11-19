// Phone drill-down (round 2): sector list -> full-screen sector sheet (groups) -> share sheet. Back (button or the device/browser
// Back) returns step by step and keeps the list position and the selected row. Every list scrolls by finger swipe AND by its rail:
// a 28 px touch target (12 px visible track and thumb) that nothing sits under - drag the thumb, or tap the track to page.
(function () {
  'use strict';
  var $ = function (s) { return document.querySelector(s); }, $$ = function (s) { return [].slice.call(document.querySelectorAll(s)); };
  var G = GD, F = G.fmt, S = G.SECTORS, kT = G.kTxt, lv = G.lv;
  var st = { open: null, sel: null, win: 1, pins: {}, nfo: false };
  var pct = G.pctOf, sec = G.sec;
  function sgp(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(2) + '%'; }
  function sg2(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(2); }
  function px(x) { return F(x, 2); }
  function esc(t) { return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;'); }
  var short = { 'NBFC & finance': 'NBFC' };
  function role(m, full) { return '<span class="c c-' + { LEADER: 'leader', LAGGARD: 'lag', DEPENDENT: 'dep', FOLLOWER: 'fol' }[m.role] + '" title="' + m.role + '">' + (full ? m.role : { LEADER: 'LEAD', LAGGARD: 'LAG', DEPENDENT: 'DEP', FOLLOWER: 'FOLL' }[m.role]) + '</span>'; }
  function toast(t) { var e = $('#toast'); e.textContent = t; e.classList.add('on'); clearTimeout(toast.t); toast.t = setTimeout(function () { e.classList.remove('on'); }, 1800); }
  function whyTxt(s) { var w = s.why; if (!w) return '<span class="un">UNEXPLAINED</span> - no driver or story found today';
    var a = w.drv ? '<b>' + esc(w.drv) + '</b> ' + esc(w.live) : (w.story ? 'no live driver' : '<span class="un">UNEXPLAINED</span>' + (w.live ? ' · live: ' + esc(w.live) : ''));
    if (w.story) a += ' · ' + esc(w.story) + ' (' + esc(w.src) + ' · ' + w.sage + ')'; if (w.note) a += ' · ' + esc(w.note); return a; }

  // ---------------- screen 1: the sector list ----------------
  function drawFlow() { var f = G.flows(st.win), o = f.out.filter(function (a) { return a[0] !== 'others'; }).slice(0, 2), i = f.inn.filter(function (a) { return a[0] !== 'others'; }).slice(0, 2);
    $('#winC').textContent = ['15M', '30M', '1H', 'TODAY'][st.win] + ' ▾';
    $('#flowL').innerHTML = '<span class="o">OUT of ' + o.map(function (a) { return short[a[0]] || a[0]; }).join(' · ') + '</span> <span class="a">→</span> <span class="i">INTO ' + i.map(function (a) { return (short[a[0]] || a[0]).toUpperCase(); }).join(' · ') + '</span>';
    $('#flowS').innerHTML = 'mcap vs NIFTY <b class="dn">−₹' + F(f.so, 0) + '</b> → <b class="up">+₹' + F(f.si, 0) + ' cr</b> · ' + f.rng; }
  function drawSectors() {
    $('#secL').innerHTML = S.map(function (s, i) { var ix = G.ideas(s), fo = G.fo(s), up = s.dir > 0, p = s.pct, nar = G.narrow(s);
      var stt = nar ? '<span class="t3">NARROW</span>' : s.run && s.run.fade ? '<span class="dn">FADING ' + s.run.br + '</span>' : s.st ? '<span style="color:' + (s.st === 'OUT' ? 'var(--down)' : 'var(--info)') + '">' + ({ 'ROT CONFIRMED': 'CONF', 'NOT THIS ROT': 'not this rot' }[s.st] || s.st) + (s.stAge ? ' ' + s.stAge : '') + '</span>' : '';
      return '<div class="sr heat-' + (up ? 'up' : 'dn') + '" data-s="' + s.id + '" style="--m:' + Math.min(2, Math.abs(p)).toFixed(2) + '"><div class="r1"><span class="rk">' + (i + 1) + '</span><span class="nm">' + s.id + '</span>' +
        (up ? '<span class="c c-ce">CE ' + ix.ce + '</span>' : '<span class="c c-pe">PE ' + ix.pe + '</span>') + '<span class="pc ' + (up ? 'up' : 'dn') + '">' + (up ? '▲' : '▼') + sgp(p) + '</span></div>' +
        '<div class="r2">' + (up ? s.up : s.dn) + '/' + s.n + ' · F&amp;O ' + (up ? fo.up : fo.dn) + '/' + fo.n + ' · RS ' + sg2(s.rs30) + (stt ? ' · ' + stt : '') + '</div></div>'; }).join('');
  }
  // ---------------- screen 2: the open sector (2-line header; WHY behind a tap) ----------------
  function drawSector() { var s = sec(st.open); if (!s) return; var fo = G.fo(s), up = s.dir > 0, r = s.run, nar = G.narrow(s);
    $('#secTop').innerHTML = '<div class="tl"><button class="back" id="back1"><span class="ar">‹</span>Sectors</button><span class="nm">' + (short[s.id] || s.id).toUpperCase() + '</span><span class="pc ' + (up ? 'up' : 'dn') + '">' + (up ? '▲ ' : '▼ ') + sgp(s.pct) + '</span>' + (s.conf ? '<span class="c c-info">CONF ' + s.conf + '</span>' : '') + '</div>' +
      '<div class="ln">' + (s.idx || 'ff basket') + ' · <b class="up">▲' + s.up + '</b> <b class="dn">▼' + s.dn + '</b> of ' + s.n + ' · F&amp;O <b class="up">▲' + fo.up + '</b> <b class="dn">▼' + fo.dn + '</b>' + (nar ? ' · NARROW' : '') + '</div>' +
      '<div class="whyb" id="whyB" role="button" title="tap = the full why, run clock and basis"><span class="w">WHY ›</span><span class="tx">' + whyTxt(s) + '</span></div>' +
      '<div class="whyx" id="whyX"><div><b>WHY</b> ' + whyTxt(s) + '</div>' + (s.why && s.why.bg ? '<div class="t3">background · ' + esc(s.why.bg.join(' · ')) + '</div>' : '') +
      '<div>RS30 <b>' + sg2(s.rs30) + '</b>' + (r ? ' · ' + (up ? 'up' : 'down') + ' since <b>' + r.since + '</b> · ' + r.len + ' / typ ' + r.typ + ' n=' + r.nn + ' · ' + (r.fade ? '<span class="dn">FADING ' + r.br + '</span>' : r.br + ' ▲') : '') + '</div>' +
      '<div>basis: ' + (s.idx ? s.idx + ' ' + sgp(s.pct) + (s.bpct != null ? ' · all-' + s.n + ' basket ' + sgp(s.bpct) : '') : 'free-float basket of all ' + s.n + ' listed') + ' · breadth over all listed' + (nar ? ' · <b>NARROW - F&amp;O-only move</b>' : '') + '</div>' +
      '<div><span class="xw">Expiry week · physical settlement - December only</span></div></div>';
    var h = '', best = bestPick(s), hasLag = s.members.some(function (m) { return m.grp === 'lag'; }), lagDone = false;
    G.GORDER.forEach(function (g) { var a = G.displayOrder(s, false).filter(function (m) { return m.grp === g; });
      if (!lagDone && !hasLag && g !== 'up' && g !== 'lead' && !s.lagRule.ok && (a.length || g === 'nt')) { h += '<div class="nolag">LAGGARD · none - breadth ' + Math.round(s.lagRule.bw * 100) + '% one way, below the 70% rule</div>'; lagDone = true; }
      if (!a.length) return; var L = G.gLabel(s, g, a.length);
      h += '<div class="gh g-' + g + '">' + L[0] + ' <span>' + (g === 'lead' ? (a[0].ext ? 'extended - pullback entry' : 'a gate fails') : g === 'nt' ? (a[0].ban ? 'F&amp;O ban' : L[1]) : L[1]) + '</span></div>';
      a.forEach(function (m) { var c = G.contract(s, m, 'atm'), p = pct(m), pl = G.plan(s, m), f0 = m.fails[0] || '';
        var gate = m.ban ? '<span class="c c-ban">BAN</span>' : m.stale ? '<span class="c c-stale">STALE ' + m.stale + 's</span>' : /OPTION STALE/.test(pl.block) ? '<span class="c c-stale">OPT ' + c.oage + 's</span>' : m.grp === 'lag' ? 'trig ' + (s.dir > 0 ? '&gt;' : '&lt;') + ' ' + F(pl.trig, pl.trig < 200 ? 2 : 1) : m.grp === 'against' ? (m.own ? (/news/.test(m.own) ? 'own news' : 'own story') : 'vs sector') : m.ext && m.gok ? '<b>EXT → ' + F(pl.trig, pl.trig < 200 ? 2 : 1) + '</b>' : m.gok ? '<span class="ok">✓ 4/4</span>' + (m.neu ? ' <span class="c c-info">NEW</span>' : '') : '✕ ' + esc(f0.replace(' bars', '').replace(' build-up', ''));
        h += '<div class="mr' + (m.ban ? ' ban' : '') + (m.stale ? ' stale' : '') + (m.sym === st.sel ? ' sel' : '') + '" data-sym="' + m.sym + '"><div class="r1"><span class="nm">' + m.sym + '</span>' + role(m) + (st.pins[m.sym] ? '<span class="pin">PIN</span>' : '') + (m.ai ? '<span class="c c-ready">' + m.ai + '</span>' : '') + '<span class="pc ' + (p >= 0 ? 'up' : 'dn') + '">' + sgp(p) + '</span></div>' +
          '<div class="r2"><span class="c c-' + c.cp.toLowerCase() + '">' + kT(c.K) + ' ' + c.cp + '</span><span class="n">' + px(c.ask) + '</span><span>' + c.sprPct.toFixed(1) + '%</span>' + (m.sym === best ? '<span style="color:var(--action)">★</span>' : '') + gate + '<span class="ag">' + m.age + '</span></div></div>'; }); });
    var nf = s.nonfo; h += '<div class="nfo" id="nfoL" role="button">' + (st.nfo ? '▾' : '▸') + ' ' + nf.n + ' more listed, not F&amp;O · ▲' + nf.up + ' ▼' + nf.dn + ' · wt ' + nf.wt + '% · context only</div>' +
      '<div class="nfx' + (st.nfo ? ' on' : '') + '" id="nfoX">' + (nf.ex.length ? nf.ex.map(function (a) { return '<span><b>' + a[0] + '</b> <span class="' + (a[1] >= 0 ? 'up' : 'dn') + '">' + sgp(a[1]) + '</span></span>'; }).join('') + '<span>and ' + (nf.n - nf.ex.length) + ' more · no strike (not F&amp;O)</span>' : '<span>' + nf.n + ' shares · no strike (not F&amp;O)</span>') + '</div><div style="height:12px"></div>';
    $('#memL').innerHTML = h; }
  function bestPick(s) { var best = null, bv = -1; s.members.forEach(function (m) { if (m.grp !== 'up') return; var p = G.plan(s, m); if (p.takeable && p.rr > bv) { bv = p.rr; best = m.sym; } }); return best; }

  // ---------------- screen 3: the share sheet ----------------
  function drawShare() { var f = G.find(st.sel); if (!f) return; var s = f.s, m = f.m, a = G.contract(s, m, 'atm'), i = G.contract(s, m, 'itm'), p = G.plan(s, m), r = G.room(m), pc = pct(m), ce = a.cp === 'CE';
    $('#shTop').innerHTML = '<div class="tl"><button class="back" id="back2"><span class="ar">‹</span>' + (short[s.id] || s.id) + '</button><span class="nm">' + m.sym + '</span><span class="px">' + px(m.ltp) + '</span><span class="pc ' + (pc >= 0 ? 'up' : 'dn') + '">' + sgp(pc) + '</span></div>' +
      '<div class="ln">' + role(m, 1) + ' <span class="c c-' + (m.grp === 'up' || m.grp === 'against' ? a.cp.toLowerCase() : 'fol') + '">' + G.gLabel(s, m.grp, 1)[0].replace(/ \(\d+\)$/, '') + '</span> <span class="n t3">' + m.age + '</span>' + (st.pins[m.sym] ? ' <span class="pin">PIN</span>' : '') + '</div>';
    var dV = (m.ltp - m.vwap) / m.atr, h = '';
    if (p.block) h += '<div class="mbn ' + (/^BAN|LOCKED/.test(p.block) ? 'rd' : 'gy') + '">' + esc(p.block) + '<span>' + esc(p.why) + '</span></div>';
    else if (p.warn) h += '<div class="mbn rd">0 lots · ' + esc(p.warn) + '<span>' + esc(p.why) + '</span></div>';
    h += '<div class="sec"><div class="txt">VWAP <b>' + lv(m.vwap) + '</b> <span class="' + (dV >= 0 ? 'up' : 'dn') + '">' + (dV >= 0 ? '▲ +' : '▼ −') + Math.abs(dV).toFixed(2) + ' ATR</span> · OR <b>' + F(m.orL, m.orL < 1000 ? 1 : 0) + '-' + F(m.orH, m.orH < 1000 ? 1 : 0) + '</b></div>' +
      '<div class="txt">RS30 <b>' + sg2(m.rs30) + ' ' + m.sl + '</b> · RVOL <b>' + m.rvol.toFixed(1) + '</b>' + (m.rvUp ? ' ▲' : '') + ' · ATR used <b>' + r.used.toFixed(2) + '</b>' + (m.ext ? ' <span style="color:var(--action)">EXT</span>' : '') + '</div>' +
      '<div class="txt">OI <span class="c c-' + (m.bu || 'fol').toLowerCase() + '" style="height:20px">' + (m.bu || '-') + '</span> Nov <b>' + sg2(m.buN) + '%</b> · Dec <b>' + sg2(m.buD) + '%</b></div></div>';
    h += '<div class="sec"><div class="stt" style="color:var(--' + (ce ? 'up' : 'down') + ')">TRADE BOX · DECEMBER 29 Dec</div><div class="xw">Expiry week · physical settlement - December only</div><table class="tbx' + (m.stale || a.ostale ? ' dim' : '') + '"><colgroup><col style="width:38%"><col><col></colgroup><tr><th></th><th class="pk"><span class="c c-' + a.cp.toLowerCase() + '" style="height:20px">' + kT(a.K) + ' ' + a.cp + '</span>' + (p.takeable ? ' ★' : '') + '</th><th><span class="c c-' + i.cp.toLowerCase() + '" style="height:20px">' + kT(i.K) + ' ' + i.cp + '</span></th></tr>' +
      [['bid / ask', px(a.bid) + '/' + px(a.ask), px(i.bid) + '/' + px(i.ask)], ['quote age', a.oage + 's', i.oage + 's'], ['spread / lot', '₹' + F(a.sprLot, 0), '₹' + F(i.sprLot, 0)], ['spread %', a.sprPct.toFixed(1) + '%', i.sprPct.toFixed(1) + '%'], ['depth at bid', a.dep + ' lots', i.dep + ' lots'], ['Δ', Math.abs(a.d).toFixed(2), Math.abs(i.d).toFixed(2)], ['θ ₹/h per lot', '−₹' + F(a.thh, 0), '−₹' + F(i.thh, 0)], ['IV / 20-day', (a.iv * 100).toFixed(1) + '/' + (a.iv20 * 100).toFixed(1), (i.iv * 100).toFixed(1) + '/' + (i.iv20 * 100).toFixed(1)], ['lot cost = max loss', '₹' + F(a.lotCost, 0), '₹' + F(i.lotCost, 0)], ['break-even 15:10', lv(a.be), lv(i.be)], ['pts needed', (ce ? '+' : '−') + a.bePts.toFixed(1), (ce ? '+' : '−') + i.bePts.toFixed(1)]]
        .map(function (rw) { return '<tr><td>' + rw[0] + '</td><td class="pk">' + rw[1] + '</td><td>' + rw[2] + '</td></tr>'; }).join('') + '</table></div>';
    if (m.ban) h += '<div class="sec"><div class="txt"><b class="dn" style="font-family:var(--sans)">BAN - only close existing.</b> No entry plan. You hold no ' + m.sym + ' position.</div></div>';
    else h += '<div class="sec"><div class="pl3"><span></span><span class="h">share</span><span class="h">premium</span><span class="l">trigger</span><span class="v">' + lv(p.trig) + '</span><span class="v">≈' + px(p.pT) + '</span><span class="l">stop</span><span class="v dn">' + lv(p.stop) + '</span><span class="v dn">≈' + px(p.pS) + '</span><span class="l">target</span><span class="v up">' + lv(p.tgt) + '</span><span class="v up">≈' + px(p.pG) + '</span></div>' +
      '<div class="txt" style="margin-top:4px">' + esc(p.how) + '</div><div class="txt">risk 1 lot <b>₹' + F(p.risk, 0) + '</b> = ' + (p.risk / G.R1).toFixed(2) + 'R · R:R <b class="' + (p.rr < 1 ? 'dn' : '') + '">' + p.rr.toFixed(2) + '</b> after costs</div>' +
      '<div class="txt">' + (p.lots && !m.ext ? esc(p.sizeTxt) : '<span class="lots' + (p.lots ? '' : ' z') + '">' + esc(p.lotsTxt) + '</span>') + '</div><div class="txt">trades <b>0 of 3</b> · 15:10 in <b>' + G.MODES[G.MODE.k].left + '</b></div></div>';
    var W = $('#shB').clientWidth - 24;
    h += '<div class="sec"><div class="stt">5-MIN · VWAP · OR · WALLS</div>' + G.chartSvg(s, m, p, W, { hp: 120, hq: 40, fs: 13, padR: 84 }) + '</div>';
    h += '<div class="sec"><button class="wybtn" id="wyB">WHY ' + m.sym + ' is moving ›</button><div class="whyx" id="wyX"><div><b>Sector:</b> ' + whyTxt(s) + '</div>' + (s.why && s.why.bg ? '<div class="t3">background · ' + esc(s.why.bg.join(' · ')) + '</div>' : '') +
      (m.news.length ? m.news.slice(0, 2).map(function (n) { return '<div><b>' + n[1] + '</b> · ' + esc(n[2]) + ' <span class="t3">(' + n[0] + ' · ' + n[3] + ')</span></div>'; }).join('') : '<div class="t3">no story of its own today</div>') + '</div></div>';
    h += '<div class="sec"><div class="stt">AI</div><div class="txt">' + (m.aiv ? '<span class="c c-ready">GET READY</span> ' + m.aiv.replace(/^GET READY /, '') : '<b style="font-family:var(--sans)">AI silent</b> - your read') + '</div></div>';
    var w = [];
    if (a.sprPct > 1.2) w.push('<span class="wn am">SPREAD ' + a.sprPct.toFixed(1) + '%; ' + (i.sprPct < a.sprPct ? kT(i.K) + ' ' + i.cp + ' has ' + i.sprPct.toFixed(1) + '%' : 'no better strike') + '</span>');
    if (m.mwpl >= 80 && !m.ban) w.push('<span class="wn ' + (m.mwpl >= 90 ? 'rd' : 'am') + '">MWPL ' + m.mwpl + '% near ban</span>');
    if (m.resT) w.push('<span class="wn am">RESULTS ' + m.resT + ' - IV crush</span>');
    if (/^ex-date/.test(m.exd)) w.push('<span class="wn am">' + esc(m.exd) + '</span>');
    if (!w.length && !p.block && !p.warn) w.push('<span class="wn">spread ' + a.sprPct.toFixed(1) + '%</span><span class="wn">depth ' + a.dep + ' lots</span><span class="wn">MWPL ' + m.mwpl + '%</span>');
    h += '<div class="sec">' + w.join('') + '<span class="wn" style="border-style:dashed">' + esc(m.res) + '</span></div>';
    var can = p.takeable;
    h += '<div class="sec"><div class="txt t3">GIR never places orders - you place the order in Kite.</div><div style="display:flex;gap:8px;margin-top:6px;flex-wrap:wrap"><button class="btn" id="pCopy"' + (can ? '' : ' disabled') + '>' + (can ? 'Copy contract' : m.ban ? 'BAN - close only' : 'Copy off · 0 lots') + '</button><button class="btn" id="pPin">' + (st.pins[m.sym] ? 'Unpin · ' : 'Pin · ') + Object.keys(st.pins).length + '/5</button><a class="btn" href="share.html#' + m.sym + '">Full page ›</a></div></div><div style="height:16px"></div>';
    $('#shB').innerHTML = h; }

  // ---------------- the rails: 28 px touch target; drag the thumb or tap the track (finger or mouse) ----------------
  var rails = [];
  $$('.rail').forEach(function (rail) { var scb = document.getElementById(rail.dataset.for), th = rail.querySelector('i');
    function geo() { var H = rail.clientHeight - 8, sh = scb.scrollHeight, ch = scb.clientHeight, hh = sh <= ch + 1 ? H : Math.max(40, H * ch / sh); return { H: H, hh: hh, max: Math.max(0, sh - ch) }; }
    function upd() { var g = geo(); if (g.H <= 0) return; th.style.height = g.hh + 'px'; th.style.top = (4 + (g.max > 0 ? (g.H - g.hh) * scb.scrollTop / g.max : 0)) + 'px'; }
    scb.addEventListener('scroll', upd); if (window.ResizeObserver) new ResizeObserver(upd).observe(scb);
    rail.addEventListener('pointerdown', function (e) { e.preventDefault(); e.stopPropagation(); var g = geo(), r = rail.getBoundingClientRect(), y = e.clientY - r.top, t0 = parseFloat(th.style.top) || 4;
      try { rail.setPointerCapture(e.pointerId); } catch (x) {}
      if (y >= t0 - 8 && y <= t0 + g.hh + 8) { var y0 = e.clientY, s0 = scb.scrollTop, k = g.max / Math.max(1, g.H - g.hh); rail.classList.add('drag');
        var mv = function (ev) { scb.scrollTop = s0 + (ev.clientY - y0) * k; }, up = function () { rail.removeEventListener('pointermove', mv); rail.removeEventListener('pointerup', up); rail.removeEventListener('pointercancel', up); rail.classList.remove('drag'); };
        rail.addEventListener('pointermove', mv); rail.addEventListener('pointerup', up); rail.addEventListener('pointercancel', up); }
      else { scb.scrollTop += (y < t0 ? -1 : 1) * scb.clientHeight * 0.9; upd(); } });
    rail.addEventListener('click', function (e) { e.stopPropagation(); e.preventDefault(); });
    rail.addEventListener('wheel', function (e) { scb.scrollTop += e.deltaY; e.preventDefault(); }, { passive: false });
    rails.push(upd); });
  function updAll() { rails.forEach(function (u) { u(); }); requestAnimationFrame(function () { rails.forEach(function (u) { u(); }); }); }

  // ---------------- navigation (history: Back steps share -> list -> sectors) ----------------
  function openSector(id, push) { st.open = id; st.sel = null; st.nfo = false; drawSector(); $('#memL').scrollTop = 0; $('#secS').classList.add('on'); if (push !== false) history.pushState({ s: id }, '', '#s=' + encodeURIComponent(id)); updAll(); }
  function openShare(sym, push) { st.sel = sym; drawShare(); $('#shB').scrollTop = 0; $$('#memL .mr').forEach(function (r) { r.classList.toggle('sel', r.dataset.sym === sym); }); $('#shareS').classList.add('on'); if (push !== false) history.pushState({ s: st.open, r: sym }, '', '#s=' + encodeURIComponent(st.open) + '&r=' + sym); updAll(); }
  function apply(state) { state = state || {}; if (state.r) { if (st.open !== state.s) { st.open = state.s; drawSector(); } $('#secS').classList.add('on'); openShare(state.r, false); return; }
    $('#shareS').classList.remove('on'); if (state.s) { if (st.open !== state.s) { st.open = state.s; drawSector(); } $('#secS').classList.add('on'); } else { $('#secS').classList.remove('on'); st.open = null; } updAll(); }
  window.addEventListener('popstate', function (e) { apply(e.state); });
  document.addEventListener('click', function (e) { var t = e.target;
    if (t.closest('#back1') || t.closest('#back2')) { history.back(); return; }
    if (t.closest('#banM .x')) { $('#banM').classList.remove('on'); return; }
    if (t.closest('#banC')) { var bn = []; S.forEach(function (s) { s.members.forEach(function (m) { if (m.ban) bn.push('<b>' + m.sym + '</b> MWPL ' + m.mwpl + '% (' + s.id + ')'); }); });
      $('#banM').innerHTML = '<span class="x">✕</span><b>F&amp;O ban today (2)</b><br>' + bn.join('<br>') + '<br>In ban: only close existing positions. Ban at 95% MWPL.'; $('#banM').classList.toggle('on'); return; }
    if (t.closest('#plR')) { location.href = 'phone.html#risk'; return; }
    if (t.closest('#winC')) { st.win = (st.win + 1) % 4; drawFlow(); toast('window ' + ['15M', '30M', '1H', 'TODAY'][st.win] + ' · ' + G.flows(st.win).rng); return; }
    if (t.closest('#whyB')) { $('#whyX').classList.toggle('on'); updAll(); return; }
    if (t.closest('#wyB')) { $('#wyX').classList.toggle('on'); updAll(); return; }
    if (t.closest('#nfoL')) { st.nfo = !st.nfo; $('#nfoX').classList.toggle('on', st.nfo); $('#nfoL').innerHTML = $('#nfoL').innerHTML.replace(/^[▸▾]/, st.nfo ? '▾' : '▸'); updAll(); return; }
    var sr = t.closest('.sr'); if (sr) { openSector(sr.dataset.s); return; }
    var mr = t.closest('.mr'); if (mr) { openShare(mr.dataset.sym); return; }
    if (t.closest('#pCopy')) { if ($('#pCopy').disabled) return; var f = G.find(st.sel), c = G.contract(f.s, f.m, 'atm'); toast('copied: ' + f.m.sym + ' 29DEC ' + c.K + ' ' + c.cp); return; }
    if (t.closest('#pPin')) { var on = !st.pins[st.sel]; if (on && Object.keys(st.pins).length >= 5) { toast('5 pins max - unpin one first'); return; } if (on) st.pins[st.sel] = 1; else delete st.pins[st.sel];
      var y = $('#shB').scrollTop; drawShare(); $('#shB').scrollTop = y; var my = $('#memL').scrollTop; drawSector(); $('#memL').scrollTop = my; $$('#memL .mr').forEach(function (r) { r.classList.toggle('sel', r.dataset.sym === st.sel); });
      toast(st.sel + (on ? ' pinned' : ' unpinned') + ' · ' + Object.keys(st.pins).length + '/5 on the Desk watchlist'); return; }
  });
  drawFlow(); drawSectors(); updAll();
  // deep link (e.g. #s=Banks&r=ICICIBANK) for the screenshots
  var hs = location.hash.replace(/^#/, ''), q = {}; hs.split('&').forEach(function (kv) { var a = kv.split('='); if (a[0]) q[a[0]] = decodeURIComponent(a[1] || ''); });
  if (q.mock && G.MODES[q.mock]) G.MODE.k = q.mock;
  history.replaceState({}, '', location.pathname);
  if (q.s) { openSector(q.s); if (q.r) openShare(q.r); }
  window.GIRPH = { st: st };
})();

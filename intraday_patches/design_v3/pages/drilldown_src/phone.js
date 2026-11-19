// Phone drill-down: sector list -> full-screen sector sheet (groups) -> share sheet. Back (button or the device/browser Back)
// returns step by step. Lists scroll by finger drag (native touch scrolling) and show a thin position rail.
(function () {
  'use strict';
  var $ = function (s) { return document.querySelector(s); }, G = GD, F = G.fmt, S = G.SECTORS;
  var st = { open: null, sel: null };
  function pct(m) { return (m.ltp / m.prev - 1) * 100; }
  function sgp(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(2) + '%'; }
  function sg2(x) { return (x > 0 ? '+' : x < 0 ? '−' : '') + Math.abs(x).toFixed(2); }
  function px(x) { return F(x, 2); } function lv(x) { return F(x, x < 200 ? 2 : 1); }
  function sec(id) { for (var i = 0; i < S.length; i++) if (S[i].id === id) return S[i]; }
  function role(m) { return '<span class="c c-' + { LEADER: 'leader', LAGGARD: 'lag', DEPENDENT: 'dep', FOLLOWER: 'fol' }[m.role] + '">' + m.role + '</span>'; }
  function toast(t) { var e = $('#toast'); e.textContent = t; e.classList.add('on'); clearTimeout(toast.t); toast.t = setTimeout(function () { e.classList.remove('on'); }, 1500); }

  function drawSectors() {
    $('#secL').innerHTML = S.map(function (s, i) { var id = G.ideas(s), fo = G.fo(s), up = s.dir > 0, p = s.pct;
      return '<div class="sr heat-' + (up ? 'up' : 'dn') + '" data-s="' + s.id + '" style="--m:' + Math.min(2, Math.abs(p)).toFixed(2) + '"><div class="r1"><span class="rk">' + (i + 1) + '</span><span class="nm">' + s.id + '</span>' +
        (up ? '<span class="c c-ce">CE ' + id.ce + '</span>' : '<span class="c c-pe">PE ' + id.pe + '</span>') + '<span class="pc ' + (up ? 'up' : 'dn') + '">' + (up ? '▲' : '▼') + sgp(p) + '</span></div>' +
        '<div class="r2">' + (up ? s.up : s.dn) + '/' + s.n + ' · F&amp;O ' + (up ? fo.up : fo.dn) + '/' + fo.n + ' · RS ' + sg2(s.rs30) + (s.run && s.run.fade ? ' · <span class="dn">FADING ' + s.run.br + '</span>' : s.st ? ' · <span style="color:' + (s.st === 'OUT' ? 'var(--down)' : 'var(--info)') + '">' + s.st + (s.stAge ? ' ' + s.stAge : '') + '</span>' : '') + '</div></div>'; }).join('');
  }
  function drawSector() { var s = sec(st.open); if (!s) return; var fo = G.fo(s), up = s.dir > 0, w = s.why, r = s.run;
    $('#secTop').innerHTML = '<div class="sh1"><span class="nm">' + s.id.toUpperCase() + '</span><span class="pc ' + (up ? 'up' : 'dn') + '">' + (up ? '▲ ' : '▼ ') + sgp(s.pct) + '</span>' + (s.conf ? '<span class="c c-info" style="margin-left:auto">CONFIRMED ' + s.conf + '</span>' : '') + '</div>' +
      '<div class="ln">all ' + s.n + ' listed · breadth <b class="up">▲' + s.up + '</b> <b class="dn">▼' + s.dn + '</b> · F&amp;O <b class="up">▲' + fo.up + '</b> <b class="dn">▼' + fo.dn + '</b> · RS30 <b>' + sg2(s.rs30) + '</b></div>' +
      (r ? '<div class="ln">' + (up ? 'up' : 'down') + ' since <b>' + r.since + '</b> · <b>' + r.len + '</b> / typ ' + r.typ + ' n=' + r.nn + ' · ' + (r.fade ? '<span class="dn">FADING ' + r.br + '</span>' : r.br + ' ▲') + '</div>' : '') +
      '<div class="ln wrap"><span class="w">WHY</span> ' + (w ? '<b style="font-family:var(--sans)">' + w.drv + '</b> ' + (w.live || '') + (w.story ? ' · ' + w.story + ' (' + w.src + ' · ' + w.sage + ')' : '') : '<b style="color:var(--action);font-family:var(--sans)">UNEXPLAINED</b>') + '</div>' +
      '<div class="ln"><span class="c c-info" style="height:20px">Expiry week · December only</span> <span class="t3">· tap a share</span></div>';
    var h = ''; G.GORDER.forEach(function (g) { var a = s.members.filter(function (m) { return m.grp === g; }); if (!a.length) return; var L = G.gLabel(s, g, a.length);
      a.sort(function (x, y) { return (x.neu ? 1 : 0) - (y.neu ? 1 : 0); });
      h += '<div class="gh g-' + g + '">' + L[0] + ' <span>' + (g === 'lead' && a[0].ext ? 'extended' : g === 'nt' ? 'F&amp;O ban' : L[1]) + '</span></div>';
      a.forEach(function (m) { var c = G.contract(s, m, 'atm'), p = pct(m);
        var gate = m.ban ? '<span class="c c-ban">BAN</span> close only' : m.stale ? '<span class="c c-stale">STALE 12s</span>' : m.gok ? '<span class="ok">✓ 4/4</span>' + (m.neu ? ' <span class="c c-info">NEW</span>' : '') : m.ext ? '<b>EXT → VWAP</b>' : (/^(trig|own)/.test(m.gate) ? m.gate : '✕ ' + m.gate);
        h += '<div class="mr' + (m.ban ? ' ban' : '') + (m.stale ? ' stale' : '') + (m.sym === st.sel ? ' sel' : '') + '" data-sym="' + m.sym + '"><div class="r1"><span class="nm">' + m.sym + '</span>' + role(m) + '<span class="pc ' + (p >= 0 ? 'up' : 'dn') + '">' + sgp(p) + '</span></div>' +
          '<div class="r2"><span class="c c-' + c.cp.toLowerCase() + '">' + F(c.K, c.K % 1 ? 1 : 0) + ' ' + c.cp + '</span><span class="n">' + px(c.ask) + '</span><span>' + c.sprPct.toFixed(1) + '%</span><span>·</span>' + gate + (m.ai ? ' <span class="c c-ready">' + m.ai + '</span>' : '') + '<span class="ag">' + m.age + '</span></div></div>'; }); });
    var nf = s.nonfo; h += '<div class="nfo">▸ ' + nf.n + ' more listed, not F&amp;O · ▲' + nf.up + ' ▼' + nf.dn + ' · wt ' + nf.wt + '% · context only</div><div style="height:12px"></div>';
    $('#memL').innerHTML = h; }
  function drawShare() { var f = G.find(st.sel); if (!f) return; var s = f.s, m = f.m, a = G.contract(s, m, 'atm'), i = G.contract(s, m, 'itm'), p = G.plan(s, m), r = G.room(m), pc = pct(m), ce = a.cp === 'CE';
    $('#back2t').textContent = s.id;
    $('#shTop').innerHTML = '<div class="sh1"><span class="nm">' + m.sym + '</span><span class="px">' + px(m.ltp) + '</span><span class="pc ' + (pc >= 0 ? 'up' : 'dn') + '">' + sgp(pc) + '</span></div>' +
      '<div class="ln">' + role(m) + ' <span class="c c-' + (m.grp === 'up' ? 'ce' : m.grp === 'against' ? 'pe' : 'fol') + '">' + G.gLabel(s, m.grp, 1)[0].replace(/ \(\d+\)$/, '') + '</span> <span class="n t3">' + m.age + '</span></div>';
    var dV = (m.ltp - m.vwap) / m.atr;
    var h = '<div class="sec"><div class="txt">VWAP <b>' + lv(m.vwap) + '</b> <span class="' + (dV >= 0 ? 'up' : 'dn') + '">' + (dV >= 0 ? '▲ +' : '▼ −') + Math.abs(dV).toFixed(2) + ' ATR</span> · OR <b>' + lv(m.orL) + '-' + lv(m.orH) + '</b></div>' +
      '<div class="txt">vs sector RS30 <b>' + sg2(m.rs30) + ' ' + m.sl + '</b> · RVOL <b>' + m.rvol.toFixed(1) + '</b>' + (m.rvUp ? ' ▲' : '') + ' · ATR used <b>' + r.used.toFixed(2) + '</b></div>' +
      '<div class="txt">OI build-up <span class="c c-' + (m.bu || 'fol').toLowerCase() + '" style="height:20px">' + (m.bu || '-') + '</span> Nov <b>' + sg2(m.buN) + '%</b> · Dec <b>' + sg2(m.buD) + '%</b></div></div>';
    h += '<div class="sec"><div class="stt" style="color:var(--' + (ce ? 'up' : 'down') + ')">TRADE BOX · DECEMBER 29 Dec</div><table class="tbx"><colgroup><col style="width:38%"><col><col></colgroup><tr><th></th><th class="pk"><span class="c c-' + a.cp.toLowerCase() + '" style="height:20px">' + F(a.K, a.K % 1 ? 1 : 0) + ' ' + a.cp + '</span> ★</th><th><span class="c c-' + i.cp.toLowerCase() + '" style="height:20px">' + F(i.K, i.K % 1 ? 1 : 0) + ' ' + i.cp + '</span></th></tr>' +
      [['bid / ask', px(a.bid) + '/' + px(a.ask), px(i.bid) + '/' + px(i.ask)], ['spread / lot', '₹' + F(a.sprLot, 0), '₹' + F(i.sprLot, 0)], ['spread %', a.sprPct.toFixed(1) + '%', i.sprPct.toFixed(1) + '%'], ['depth at bid', a.dep + ' lots', i.dep + ' lots'], ['Δ', Math.abs(a.d).toFixed(2), Math.abs(i.d).toFixed(2)], ['θ ₹/h per lot', '−₹' + F(a.thh, 0), '−₹' + F(i.thh, 0)], ['IV / 20-day', (a.iv * 100).toFixed(1) + '/' + (a.iv20 * 100).toFixed(1), (i.iv * 100).toFixed(1) + '/' + (i.iv20 * 100).toFixed(1)], ['lot cost = max loss', '₹' + F(a.lotCost, 0), '₹' + F(i.lotCost, 0)], ['break-even 15:10', lv(a.be), lv(i.be)]]
        .map(function (rw) { return '<tr><td>' + rw[0] + '</td><td class="pk">' + rw[1] + '</td><td>' + rw[2] + '</td></tr>'; }).join('') + '</table></div>';
    h += '<div class="sec"><div class="pl3"><span></span><span class="h">share</span><span class="h">premium</span><span class="l">trigger</span><span class="v">' + lv(p.trig) + '</span><span class="v">≈' + px(p.pT) + '</span><span class="l">stop</span><span class="v dn">' + lv(p.stop) + '</span><span class="v dn">≈' + px(p.pS) + '</span><span class="l">target</span><span class="v up">' + lv(p.tgt) + '</span><span class="v up">≈' + px(p.pG) + '</span></div>' +
      '<div class="txt" style="margin-top:4px">' + p.how + '</div><div class="txt">risk 1 lot <b>₹' + F(p.risk, 0) + '</b> = ' + (p.risk / G.R1).toFixed(2) + 'R · R:R <b>' + p.rr.toFixed(2) + '</b></div><div class="txt">lock room <b>₹10,000</b> → fits ' + p.fitLock + ' → <span class="lots">' + p.lotsTxt + '</span></div><div class="txt">trades <b>0 of 3</b> · 15:10 in <b>4h 05m</b></div></div>';
    h += '<div class="sec"><div class="stt">AI</div><div class="txt">' + (m.aiv ? '<span class="c c-ready">GET READY</span> ' + m.aiv.replace(/^GET READY /, '') : '<b style="font-family:var(--sans)">AI silent</b> - your read') + '</div></div>';
    h += '<div class="sec"><span class="wn">spread ' + a.sprPct.toFixed(1) + '%</span><span class="wn">depth ' + a.dep + ' lots</span><span class="wn">MWPL ' + m.mwpl + '%</span><span class="wn">' + m.res + '</span></div>';
    h += '<div class="sec"><div class="txt t3">GIR never places orders - you place the order in Kite.</div><div style="display:flex;gap:8px;margin-top:6px"><button class="btn" id="pCopy">Copy contract</button><button class="btn" id="pPin">Pin</button><a class="btn" href="share.html#' + m.sym + '">Full page ›</a></div></div><div style="height:16px"></div>';
    $('#shB').innerHTML = h; $('#shB').scrollTop = 0; }

  // a thin rail that shows the position and can be dragged with a finger or the mouse
  var rails = [];
  document.querySelectorAll('.rail').forEach(function (rail) { var scb = document.getElementById(rail.dataset.for), th = rail.querySelector('i');
    function upd() { var sh = scb.scrollHeight, ch = scb.clientHeight, H = rail.clientHeight; if (!H) return; if (sh <= ch + 1) { th.style.top = '0px'; th.style.height = H + 'px'; return; } var hh = Math.max(24, H * ch / sh); th.style.height = hh + 'px'; th.style.top = ((H - hh) * scb.scrollTop / (sh - ch)) + 'px'; }
    scb.addEventListener('scroll', upd); if (window.ResizeObserver) new ResizeObserver(upd).observe(scb);
    th.addEventListener('pointerdown', function (e) { e.preventDefault(); try { th.setPointerCapture(e.pointerId); } catch (x) {} var y0 = e.clientY, s0 = scb.scrollTop, k = (scb.scrollHeight - scb.clientHeight) / Math.max(1, rail.clientHeight - th.offsetHeight);
      function mv(ev) { scb.scrollTop = s0 + (ev.clientY - y0) * k; } function up() { th.removeEventListener('pointermove', mv); th.removeEventListener('pointerup', up); }
      th.addEventListener('pointermove', mv); th.addEventListener('pointerup', up); });
    rails.push(upd); });
  function updAll() { setTimeout(function () { rails.forEach(function (u) { u(); }); }, 240); rails.forEach(function (u) { u(); }); }

  function openSector(id, push) { st.open = id; st.sel = null; drawSector(); $('#memL').scrollTop = 0; $('#secS').classList.add('on'); if (push !== false) history.pushState({ s: id }, '', '#s=' + encodeURIComponent(id)); updAll(); }
  function openShare(sym, push) { st.sel = sym; drawShare(); document.querySelectorAll('#memL .mr').forEach(function (r) { r.classList.toggle('sel', r.dataset.sym === sym); }); $('#shareS').classList.add('on'); if (push !== false) history.pushState({ s: st.open, r: sym }, '', '#s=' + encodeURIComponent(st.open) + '&r=' + sym); updAll(); }
  function apply(state) { state = state || {}; if (state.r) { if (st.open !== state.s) { st.open = state.s; drawSector(); } $('#secS').classList.add('on'); openShare(state.r, false); return; }
    $('#shareS').classList.remove('on'); st.sel = null; if (state.s) { if (st.open !== state.s) { st.open = state.s; drawSector(); } $('#secS').classList.add('on'); } else { $('#secS').classList.remove('on'); st.open = null; } updAll(); }
  window.addEventListener('popstate', function (e) { apply(e.state); });
  document.addEventListener('click', function (e) { var t = e.target;
    if (t.closest('#back1') || t.closest('#back2')) { history.back(); return; }
    var sr = t.closest('.sr'); if (sr) { openSector(sr.dataset.s); return; }
    var mr = t.closest('.mr'); if (mr) { openShare(mr.dataset.sym); return; }
    if (t.closest('#pCopy')) { var f = G.find(st.sel), c = G.contract(f.s, f.m, 'atm'); toast('copied: ' + f.m.sym + ' 29DEC ' + c.K + ' ' + c.cp); return; }
    if (t.closest('#pPin')) { toast(st.sel + ' pinned to the Desk watchlist'); return; }
  });
  drawSectors(); updAll();
  // deep link (e.g. #s=Banks&r=ICICIBANK) for the screenshots
  var h = location.hash.replace(/^#/, ''), q = {}; h.split('&').forEach(function (kv) { var a = kv.split('='); if (a[0]) q[a[0]] = decodeURIComponent(a[1] || ''); });
  history.replaceState({}, '', location.pathname);
  if (q.s) { $('#secS').style.transition = 'none'; $('#shareS').style.transition = 'none'; openSector(q.s); if (q.r) openShare(q.r); setTimeout(function () { $('#secS').style.transition = ''; $('#shareS').style.transition = ''; }, 50); }
  window.GIRPH = { st: st };
})();

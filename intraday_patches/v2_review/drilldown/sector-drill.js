/* SECTOR DRILL-DOWN (R50, design_v3/SECTOR_DRILLDOWN.md) - ONE component for every page: openSector = SectorMembers + SharePane.
   Used from: F3 table row, money-flow band and "moving, but not this rotation" list · F2 board row and heat tile · F1 Desk sector chip ·
   Morning (pre-open view, "pre-open - not live"). The group rules (COMING UP NOW / LEADER / LAGGARD / WAITING / AGAINST / NOT TRADABLE)
   and the lot / risk rules live HERE ONLY (RULES + groupOf + plan). Pages only include this file; it wires itself per page (CFG).
   Data: the real store only (sec.board, sec.rot, sh.*, fut.*, oc.* rows2 = the December chain, ban.list, pos.day, calls.feed, news.list,
   strip.expiry, mkt.*). Anything the store lacks is named once ("not known - <why>"), never a dash, never a mock value.
   Signal only: no order button anywhere; "Copy contract" puts the Kite symbol on the clipboard. GIR never places orders. */
(function () {
  'use strict';
  if (!window.GIR || !GIR.store || !GIR.h) return;
  const S = GIR.store, H = GIR.h, {esc, num, sgn} = H, M = '−';
  const $ = (s, r) => (r || document).querySelector(s), $$ = (s, r) => [...(r || document).querySelectorAll(s)];
  const PAGE = ((document.body.className.match(/page-([\w-]+)/) || [])[1]) || '';
  const PHONE = () => innerWidth < 700;
  const UP = s => String(s == null ? '' : s).toUpperCase(), cap = s => String(s || '').replace(/^./, c => c.toUpperCase());
  const isN = v => typeof v === 'number' && isFinite(v);
  const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
  const p2 = v => isN(v) ? (v > 0 ? '+' : v < 0 ? M : '') + Math.abs(v).toFixed(2) + '%' : '';
  const s2 = v => isN(v) ? (v > 0 ? '+' : v < 0 ? M : '') + Math.abs(v).toFixed(2) : '';
  const k0 = v => isN(v) ? num(v, v % 1 ? 1 : 0) : '';
  const nn = (v, dp) => isN(v) ? num(v, dp == null ? 2 : dp) : 'n/k';
  const rsI = v => isN(v) ? (v < 0 ? M : '') + '₹' + Math.abs(Math.round(v)).toLocaleString('en-IN') : '';
  const nkc = (why, txt) => `<span class="sd-nk" title="not known - ${esc(why)}">${txt || 'n/k'}</span>`;
  const BAD = {STALE: 1, LATE: 1, SUSPECT: 1, CONFLICT: 1, INCOMPLETE: 1, MISSING: 1};
  const MON = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  /* =====================================================================================================================
     RULES - the ONE place (SECTOR_DRILLDOWN.md 3 + 5 + 8.6). Thresholds are starting points (re-tuned only when n >= 30).
     ===================================================================================================================== */
  const RULES = {RS_ON: 0.5, RVOL_ON: 1.5, SCORE_ON: 0.60, SCORE_OFF: 0.45, EXT: 1.0, USED: 0.8, LAG_BW: 0.70, FLAT: 0.25, AGAINST: -0.5,
    STALE_S: 10, CHG_FIX: 40, CHG_PCT: 0.0021, TH_HOURS: 6.25, FORM_END: 9 * 60 + 30, MANAGE: 14 * 60 + 30, LAST: 15 * 60 + 10};
  const GORDER = ['up', 'lead', 'lag', 'wait', 'against', 'nt'];
  const nowS = () => S.now ? S.now() : Date.now() / 1000;
  const istMin = () => { const d = new Date((nowS() + 19800) * 1000); return d.getUTCHours() * 60 + d.getUTCMinutes(); };
  const hm = ts => { if (!ts) return ''; const d = new Date((ts + 19800) * 1000); return d.toISOString().slice(11, 16); };
  const dhm = ts => { if (!ts) return ''; const d = new Date((ts + 19800) * 1000); return d.getUTCDate() + ' ' + cap(MON[d.getUTCMonth()].toLowerCase()) + ' ' + d.toISOString().slice(11, 16); };
  /* market mode: preopen (market not open: the numbers are the last session's), forming (< 09:30), manage (> 14:30), live; locked = loss lock */
  function mode() {
    const st = UP(S.val('mkt.status')), lock = (S.val('pos.day') || {}).lock || {};
    const open = /OPEN|LIVE|NORMAL/.test(st) && !/PRE|CLOS/.test(st), t = istMin();
    const m = !open ? 'preopen' : t < RULES.FORM_END ? 'forming' : t > RULES.MANAGE ? 'manage' : 'live';
    return {k: m, locked: !!lock.locked, lockWhy: lock.why || '', open, st};
  }
  const notLive = () => istMin() >= 15 * 60 + 30 ? 'closed - not live' : 'pre-open - not live';
  const lastSession = () => { const f = S.get('sh.RELIANCE') || S.get('idx.NIFTY'); return f && f.src_ts ? dhm(f.src_ts) : ''; };
  const board = () => { const v = S.val('sec.board'); return Array.isArray(v) ? v : []; };
  const secByName = n => { const k = String(n || '').trim().toLowerCase(), B = board(); if (!k) return null;
    return B.find(s => s.name.toLowerCase() === k) || B.find(s => s.name.toLowerCase() === k + ' group') || B.find(s => s.name.toLowerCase().replace(/ group$/, '') === k.replace(/ group$/, '')) || null; };
  const banOf = s => { const L = S.val('ban.list'); return Array.isArray(L) ? L.find(x => x.s === s) || null : null; };
  const buSigned = (dir, b) => dir > 0 ? ({LB: 1, SC: 0.5, SB: -1, LU: -1}[b] || 0) : ({SB: 1, LU: 0.5, LB: -1, SC: -1}[b] || 0);
  /* one member's inputs. RS15 / RS30 and closed 5-min bars are not in the store: the day RS vs the sector (share % − sector %, all listed)
     stands in for both and is named in the list; the side uses the last price vs VWAP (the opening range is not in the store). */
  function inputs(sec, sym, bs) {
    const f = S.get('sh.' + sym), v = f && f.v || {}, dir = sec.dir;
    const px = v.px, pctv = v.pct, vwap = v.vwap, atr = v.atr;
    const rs = isN(pctv) && isN(sec.pct) ? pctv - sec.pct : null;
    const open = isN(px) && isN(v.open_pct) ? px / (1 + v.open_pct / 100) : null;
    const ext = isN(px) && isN(vwap) && isN(atr) && atr > 0 ? Math.abs(px - vwap) / atr : null;
    const used = isN(px) && isN(open) && isN(atr) && atr > 0 ? Math.abs(px - open) / atr : null;
    const side = isN(px) && isN(vwap) ? (px > vwap ? 'above' : px < vwap ? 'below' : 'at') : null;
    const age = f && (f.src_ts || f.seen) ? nowS() - (f.src_ts || f.seen) : null;
    const md = mode(), stale = !!(f && BAD[f.state]) || (md.open && isN(age) && age > RULES.STALE_S);
    const ban = banOf(sym);
    return {s: sym, f, v, px, pct: pctv, vwap, atr, rvol: isN(v.rvol) ? v.rvol : null, bu: v.bu || null, oi: v.oi_pct, lot: v.lot, mwpl: v.mwpl,
      rs, ext, used, left: isN(used) ? Math.max(0, 1 - used) : null, side, age, stale, staleS: isN(age) ? Math.round(age) : null,
      ban: !!(ban && UP(ban.state) === 'BAN'), banRow: ban, wt: bs && isN(bs.weight) ? bs.weight : null, bs: bs || null,
      isExt: (isN(ext) && ext > RULES.EXT) || (isN(used) && used > RULES.USED), dir};
  }
  function gates(m) { // the four COMING UP gates, mirrored for a falling sector; the failing ones by name
    const d = m.dir, out = [];
    if (!(isN(m.rs) && d * m.rs > 0 && d * m.rs >= RULES.RS_ON)) out.push(isN(m.rs) ? 'RS ' + s2(m.rs) : 'RS not known');
    if (!(isN(m.rvol) && m.rvol >= RULES.RVOL_ON)) out.push(isN(m.rvol) ? 'RVOL ' + m.rvol.toFixed(1) : 'RVOL not known');
    const onSide = d > 0 ? m.side === 'above' : m.side === 'below';
    if (!onSide) out.push(m.side ? (d > 0 ? 'below VWAP' : 'above VWAP') : 'VWAP not known');
    if (buSigned(d, m.bu) < 0) out.push(m.bu + ' build-up');
    return out;
  }
  function score(m) { // 0.30·RS30 + 0.20·RS15 + 0.20·min(RVOL,3)/3 + 0.15·build-up + 0.15·side (RS as day RS, capped at ±1)
    const r = isN(m.rs) ? clamp(m.dir * m.rs, -1, 1) : 0, rv = isN(m.rvol) ? Math.min(m.rvol, 3) / 3 : 0;
    const side = m.side ? ((m.dir > 0 ? m.side === 'above' : m.side === 'below') ? 1 : 0) : 0;
    return 0.30 * r + 0.20 * r + 0.20 * rv + 0.15 * buSigned(m.dir, m.bu) + 0.15 * side;
  }
  const WAS = {}; // hysteresis memory: COMING UP switches on at 0.60 and off below 0.45
  const comingUp = (m) => WAS[m.s] ? m.score >= RULES.SCORE_OFF : m.score >= RULES.SCORE_ON;
  /* the sector model: every F&O member (sh.* of this sector + the board's members), grouped by the ONE rule set */
  function model(name) {
    const b = secByName(name); if (!b) return null;
    const rot = S.val('sec.rot'), rd = rot && Array.isArray(rot.day) ? rot.day.find(x => x.name === b.name) : null;
    const pctv = isN(b.day_pct) ? b.day_pct : rd && isN(rd.pct) ? rd.pct : null;
    const dir = isN(pctv) && pctv !== 0 ? Math.sign(pctv) : (b.dir || 1);
    const sec = {name: b.name, b, pct: pctv, dir, br: b.breadth || {}};
    const bsh = {}; (b.shares || []).forEach(x => bsh[x.s] = x);
    const syms = new Set(Object.keys(bsh)); S.keys('sh.').forEach(k => { const v = S.val(k); if (v && String(v.sector || '').toLowerCase() === b.name.toLowerCase()) syms.add(k.slice(3)); });
    const mem = [...syms].map(s => inputs(sec, s, bsh[s]));
    const br = sec.br, bw = isN(br.all_n) && br.all_n > 0 ? (dir > 0 ? br.all_up : br.all_dn) / br.all_n : null;
    sec.lag = {bw, ok: isN(bw) && bw >= RULES.LAG_BW};
    const sp = m => isN(m.pct) ? dir * m.pct : -9;
    let lead = null; mem.forEach(m => { if (!m.ban && sp(m) > 0 && (!lead || sp(m) > sp(lead))) lead = m; });
    mem.forEach(m => {
      m.fails = gates(m); m.gok = !m.fails.length; m.score = score(m);
      const flat = isN(m.pct) && Math.abs(m.pct) < RULES.FLAT, against = buSigned(dir, m.bu) < 0, own = ownNews(m.s);
      m.role = m === lead ? 'LEADER' : null;
      if (m.ban) m.grp = 'nt';
      else if (isN(m.pct) && sp(m) < 0 && isN(m.rs) && dir * m.rs <= RULES.AGAINST) m.grp = 'against';
      else if (m === lead) m.grp = m.gok && !m.isExt && comingUp(m) ? 'up' : 'lead';
      else if (m.gok && !m.isExt && comingUp(m)) m.grp = 'up';
      else if (flat && sec.lag.ok && !own && !against) { m.grp = 'lag'; m.role = 'LAGGARD'; }
      else m.grp = 'wait';
      if (m.gok && !m.isExt && m.grp === 'wait') m.fails = ['score ' + m.score.toFixed(2) + ' < ' + RULES.SCORE_ON.toFixed(2)];
      if (!m.role) m.role = bsh[m.s] && bsh[m.s].role ? UP(bsh[m.s].role) : (isN(m.rs) && dir * m.rs > 0 ? 'FOLLOWER' : 'DEPENDENT');
      if (/LEADER/.test(m.role) && m !== lead) m.role = 'FOLLOWER';
      WAS[m.s] = m.grp === 'up';
      m.cp = optSide(sec, m); m.plan = plan(sec, m);
    });
    mem.sort((a, c) => GORDER.indexOf(a.grp) - GORDER.indexOf(c.grp) || (a.grp === 'lead' ? 0 : 0) || (c.score - a.score) || (sp(c) - sp(a)));
    sec.members = mem; sec.lead = lead;
    const fo = {up: 0, dn: 0, n: mem.length}; mem.forEach(m => { if (isN(m.pct)) { if (m.pct >= 0) fo.up++; else fo.dn++; } }); sec.fo = fo;
    sec.nonfo = isN(br.all_n) && isN(br.fo_n) ? {n: br.all_n - br.fo_n, up: br.all_up - br.fo_up, dn: br.all_dn - br.fo_dn,
      wt: mem.length && mem.every(m => isN(m.wt)) ? Math.max(0, 100 - mem.reduce((a, m) => a + m.wt, 0)) : null} : null;
    const fa = isN(br.fo_n) && br.fo_n ? (dir > 0 ? br.fo_up : br.fo_dn) / br.fo_n : null, na = sec.nonfo && sec.nonfo.n ? (dir > 0 ? sec.nonfo.up : sec.nonfo.dn) / sec.nonfo.n : null;
    sec.narrow = isN(fa) && isN(na) && fa >= 0.75 && na < 0.60 ? {fo: fa, nf: na} : null;
    sec.ce = mem.filter(m => m.cp === 'CE' && m.grp !== 'nt' && m.grp !== 'wait').length; sec.pe = mem.filter(m => m.cp === 'PE' && m.grp !== 'nt' && m.grp !== 'wait').length;
    return sec;
  }
  function ownNews(s) { const L = S.val('news.list'); return Array.isArray(L) && L.some(n => n.s === s && n.side && n.side * 1 < 0 && (nowS() - n.t) < 86400); }
  function optSide(sec, m) { let ce = sec.dir > 0; if (m.grp === 'against') ce = !ce; return ce ? 'CE' : 'PE'; }
  /* December only (November expires with physical settlement): oc.<SYM>.rows2 when exp2 is the next month */
  function decChain(sym) {
    const f = S.get('oc.' + sym), o = f && f.v; if (!o) return {why: 'oc.' + sym + ' not in the store'};
    const near = o.exp, e2 = o.exp2 || (o.exp2_info || {}).exp;
    if (!e2 || !Array.isArray(o.rows2) || !o.rows2.length) return {why: 'oc.' + sym + '.rows2 (the ' + (e2 || 'next-month') + ' chain) not in the store'};
    return {exp: e2, near, rows: o.rows2, lot: o.lot, info: o.exp2_info || {}, roof: o.roof, floor: o.floor, f, age: f.src_ts ? nowS() - f.src_ts : null, state: f.state};
  }
  function kite(sym, exp, K, cp) { const m = /^(\d{4})-(\d\d)/.exec(exp || ''); return m ? sym + m[1].slice(2) + MON[+m[2] - 1] + k0(K).replace(/,/g, '') + cp : ''; }
  function contract(m, which) {
    const ch = decChain(m.s); if (!ch.rows) return {why: ch.why};
    const ks = ch.rows.map(r => r.k).filter(isN).sort((a, b) => a - b); if (!ks.length || !isN(m.px)) return {why: 'no strike / no share price'};
    let atm = ks.reduce((a, k) => Math.abs(k - m.px) < Math.abs(a - m.px) ? k : a, ks[0]);
    const i = ks.indexOf(atm), K = which === 'itm' ? (m.cp === 'CE' ? ks[i - 1] : ks[i + 1]) : atm;
    if (!isN(K)) return {why: 'no in-the-money strike in the pinned December strikes'};
    const row = ch.rows.find(r => r.k === K), q = row && row[m.cp.toLowerCase()];
    if (!q) return {K, exp: ch.exp, why: 'no ' + m.cp + ' quote at ' + k0(K)};
    const lot = m.lot || ch.lot, bid = q.bid, ask = q.ask, mid = isN(q.mid) ? q.mid : isN(bid) && isN(ask) ? (bid + ask) / 2 : q.ltp;
    const sp = isN(bid) && isN(ask) ? ask - bid : null;
    // B9 (21 Nov): yesterday's premium between 09:15 and 09:25 = "premium loading (09:15 sweep)", not STALE (still no GO NOW);
    // F2: key 3 failed today's Kite check = the quote is STALE with that reason
    const oo = (ch.f && ch.f.v && ch.f.v.opt) || {}, odeg = oo.degraded || '', im = istMin();
    const oload = !odeg && im >= 555 && im < 565 && (!!oo.loading || (isN(q.q_ts) && nowS() - q.q_ts > (im - 555 + 1) * 60));
    const ostale = !oload && (!!odeg || !!BAD[ch.state] || (mode().open && isN(ch.age) && ch.age > RULES.STALE_S));
    const thh = isN(q.theta) ? q.theta / RULES.TH_HOURS : null;
    return {K, exp: ch.exp, near: ch.near, cp: m.cp, q, lot, bid, ask, mid, sp, sprLot: isN(sp) && lot ? sp * lot : null, sprPct: isN(q.spr_pct) ? q.spr_pct : null,
      depLots: isN(q.depth_bid) && lot ? Math.floor(q.depth_bid / lot) : null, delta: q.delta, gamma: q.gamma, iv: q.iv, thh: isN(thh) && lot ? thh * lot : null,
      lotCost: isN(ask) && lot ? ask * lot : null, kite: kite(m.s, ch.exp, K, m.cp), ostale, oload, odeg, oage: ch.age, info: ch.info, roof: ch.roof, floor: ch.floor};
  }
  const hrsLeft = () => { const t = istMin(), md = mode(); return md.open ? Math.max(0, (RULES.LAST - t) / 60) : (RULES.LAST - (9 * 60 + 15)) / 60; };
  /* the plan: trigger / stop / target (share + premium), costs, R:R, lots. Hard blocks first (BAN, LOCKED, STALE, OPTION STALE), then
     the time rules, then sizing: R:R < 1 after costs -> 0 lots; one lot above 1R -> 0 lots; lots = min(1R rule, lock room). */
  function plan(sec, m, wi) {
    const md = wi && wi.mode ? Object.assign({}, mode(), {k: wi.mode, open: true, locked: !!wi.locked}) : mode(), c = contract(m, 'atm'), rising = m.cp === 'CE', at = m.atr;
    const out = {cp: m.cp, c, lots: 0, takeable: false, block: '', warn: '', why: '', how: '', trig: null, stop: null, tgt: null};
    const day = S.val('pos.day') || {}, lock = day.lock || {}, room = isN(lock.left) ? lock.left : null; let r1 = isN(day.r1) ? day.r1 : isN(day.r) ? day.r : null;
    if (wi && isN(wi.r1)) r1 = wi.r1; out.room = room; out.r1 = r1;
    if (isN(m.px) && isN(m.vwap) && isN(at)) {
      const tk = m.px < 250 ? 0.05 : m.px < 1000 ? 0.05 : 0.1, rd = x => +(Math.round(x / tk) * tk).toFixed(2), dg = 2;
      if (m.isExt) { out.trig = rd(m.vwap); out.stop = rd(rising ? m.vwap - 0.35 * at : m.vwap + 0.35 * at); out.tgt = rd(m.px);
        out.how = 'EXTENDED - don\'t chase: enter on the ' + (rising ? 'pullback to VWAP ' + num(out.trig, dg) + ' / first higher low' : 'bounce to VWAP ' + num(out.trig, dg) + ' / first lower high') + ', half size'; }
      else if (m.grp === 'lag') { out.trig = rd(rising ? m.vwap + 0.1 * at : m.vwap - 0.1 * at); out.stop = rd(rising ? m.vwap - 0.25 * at : m.vwap + 0.25 * at); out.tgt = rd(rising ? out.trig + 0.6 * at : out.trig - 0.6 * at);
        out.how = 'trig: 5-min close ' + (rising ? '>' : '<') + ' ' + num(out.trig, dg) + ' (VWAP ' + (rising ? '+' : M) + ' 0.1 ATR; its opening range is not in the store)'; }
      else { out.trig = rd(rising ? m.px + 0.05 * at : m.px - 0.05 * at); out.stop = rd(rising ? m.vwap - 0.1 * at : m.vwap + 0.1 * at); out.tgt = rd(rising ? out.trig + 0.6 * at : out.trig - 0.6 * at);
        out.how = '5-min close ' + (rising ? '>' : '<') + ' ' + num(out.trig, dg) + ' (now ' + (rising ? '+' : M) + ' 0.05 ATR; day high / low not in the store)'; }
    } else out.how = 'levels not known - ' + (!isN(m.vwap) ? 'VWAP' : !isN(at) ? 'ATR' : 'price') + ' missing';
    const prem = S1 => { if (!isN(c.mid) || !isN(c.delta) || !isN(S1)) return null; const d = S1 - m.px; return Math.max(0.05, c.mid + c.delta * d + 0.5 * (isN(c.gamma) ? c.gamma : 0) * d * d); };
    if (isN(c.sp) && isN(out.trig)) {
      const hs = c.sp / 2; out.pT = prem(out.trig) + hs; out.pS = prem(out.stop) - hs; out.pG = prem(out.tgt) - hs;
      out.charges = Math.round((RULES.CHG_FIX + RULES.CHG_PCT * (c.lotCost || 0)) / 10) * 10; out.slip = Math.round(hs * c.lot / 10) * 10; out.costs = out.charges + out.slip;
      out.risk = Math.round((out.pT - Math.max(0.05, out.pS)) * c.lot + out.costs); out.reward = Math.round((out.pG - out.pT) * c.lot - out.costs); out.rr = out.risk > 0 ? out.reward / out.risk : null;
      out.fitLock = isN(room) && out.risk > 0 ? Math.floor(room / out.risk) : null; out.fitR = isN(r1) && out.risk > 0 ? Math.floor(r1 / out.risk) : null;
      if (isN(c.thh) && isN(c.delta) && c.delta) { const pts = (Math.abs(c.thh / c.lot) * hrsLeft() + c.sp) / Math.abs(c.delta); out.be = rising ? m.px + pts : m.px - pts; out.bePts = pts; }
    }
    if (m.ban) { out.block = 'BAN - only close existing'; out.why = 'F&O ban · MWPL ' + (m.banRow && m.banRow.mwpl) + '%'; }
    else if (md.locked) { out.block = 'LOCKED - no new trades today'; out.why = md.lockWhy || 'day loss lock hit (pos.day.lock)'; }
    else if (m.stale) { out.block = 'STALE ' + (m.staleS != null ? m.staleS + 's' : ''); out.why = 'share quote ' + (m.f ? m.f.state : '') + ' - no GO NOW until it ticks'; }
    else if (c.odeg) { out.block = 'OPTION STALE - key 3 down'; out.why = c.odeg + ' - no GO NOW on its quotes'; }
    else if (c.oload) { out.block = 'premium loading'; out.why = 'premium loading (09:15 sweep) - today\'s first December quote is not in yet; no GO NOW until it arrives'; }
    else if (c.ostale) { out.block = 'OPTION STALE ' + Math.round(c.oage || 0) + 's'; out.why = 'option bid / ask old - no GO NOW until it ticks'; }
    else if (md.k === 'preopen') { out.block = notLive(); out.why = 'market not open: levels from the ' + lastSession() + ' close'; }
    else if (md.k === 'forming') { out.block = 'forming - before 09:30'; out.why = 'groups settle on closed bars at 09:30'; }
    else if (md.k === 'manage') { out.block = 'manage only - no new entries'; out.why = 'after 14:30'; }
    else if (m.grp === 'nt' || m.grp === 'wait' || (m.grp === 'lead' && !m.gok)) { out.warn = 'waiting - ' + (m.fails[0] || 'a gate') + ' fails'; out.why = 'not a trade until every gate passes'; }
    else if (!isN(out.risk)) { out.warn = 'risk not known - ' + (c.why || 'December quote missing'); }
    else if (!isN(out.rr) || out.rr < 1) { out.warn = 'R:R ' + (isN(out.rr) ? out.rr.toFixed(2) : 'n/k') + ' after costs - not worth it'; out.why = out.warn; }
    else if (!isN(r1)) { out.warn = '1R not known (pos.day.r1 not in the store) - the 1R rule cannot be checked'; out.why = out.warn; }
    else if (out.risk > r1) { out.warn = '1 lot = ' + (out.risk / r1).toFixed(2) + 'R > 1R'; out.why = out.warn; }
    else if (!isN(out.fitLock) || out.fitLock < 1) { out.block = 'lock room'; out.why = 'lock room ' + rsI(room) + ' < max loss ' + rsI(out.risk); }
    if (out.block || out.warn) { out.lots = 0; out.lotsTxt = '0 lots · ' + (out.block || out.warn); }
    else if (m.isExt) { out.lots = 1; out.lotsTxt = '1 lot (minimum) · extended, half size'; }
    else { out.lots = Math.max(0, Math.min(out.fitR, out.fitLock)); out.lotsTxt = out.lots + (out.lots === 1 ? ' lot' : ' lots'); }
    out.takeable = out.lots > 0;
    out.copyOff = m.ban ? 'BAN - only close existing' : m.stale ? 'STALE quote' : c.odeg ? 'option quote STALE (key 3 down)' : c.oload ? 'premium loading (09:15 sweep)' : c.ostale ? 'option quote STALE' : !c.kite ? (c.why || 'no December contract') : '';
    return out;
  }
  /* ===================================================== end of RULES ===================================================== */

  /* ---------- labels ---------- */
  function gLabel(sec, g, n, md) { const up = sec.dir > 0, cp = up ? 'CE' : 'PE', ocp = up ? 'PE' : 'CE';
    return {up: [md.k === 'forming' ? 'FORMING' : up ? 'COMING UP NOW' : 'COMING DOWN NOW', n + ' · ' + cp], lead: ['LEADER', 'pullback if EXT'],
      lag: ['LAGGARD', up ? 'may catch up' : 'may catch down'], wait: ['WAITING', 'a gate fails'], against: ['AGAINST (' + n + ')', ocp + ' strike'], nt: ['NOT TRADABLE', 'reason in row']}[g]; }
  const roleChip = r => { r = UP(r); const k = /LEADER/.test(r) ? 'lead' : /LAG/.test(r) ? 'lag' : /DEP/.test(r) ? 'dep' : 'fol';
    return `<i class="sd-role sd-role-${k}" title="${{lead: 'LEADER - the biggest mover with the sector', lag: 'LAGGARD - flat, may catch up', dep: 'DEPENDENT - moves with its driver', fol: 'FOLLOWER - moves with the sector'}[k]}">${{lead: 'LDR', lag: 'LAG', dep: 'DEP', fol: 'FOL'}[k]}</i>`; };
  function stateCell(m) {
    const p = m.plan;
    if (m.ban) return `<b class="sd-ban">BAN</b> close only`;
    if (m.stale) return `<b class="sd-warn">STALE ${m.staleS != null ? m.staleS + 's' : ''}</b>`;
    if (m.isExt) return `<span class="sd-ext" title="${esc(p.how)}">EXT ↩ ${nn(p.trig, p.trig >= 1000 ? 0 : 1)}</span>`;
    if (m.grp === 'lag') return `<span title="${esc(p.how)}">trig ${m.dir > 0 ? '>' : '<'} ${nn(p.trig, p.trig >= 1000 ? 0 : 1)}</span>`;
    if (m.gok) return `<span class="sd-ok">✓ 4/4</span>`;
    return `<span class="sd-fail" title="failing gates: ${esc(m.fails.join(' · '))}">✕ ${esc(String(m.fails[0]).replace(/ not known$/, ' n/k').replace(/^score /, 'sc ').replace(/ build-up$/, ''))}${m.fails.length > 1 ? ' +' + (m.fails.length - 1) : ''}</span>`;
  }
  function aiCell(m) {
    const C = S.val('calls.feed'), c = Array.isArray(C) ? C.find(x => x.s === m.s && x.engine !== 'old') : null;
    if (c && /GO NOW|GET READY/.test(c.action || '')) return `<span class="sd-ai ${/GO NOW/.test(c.action) ? 'go' : 'rd'}" title="${esc((c.t || '') + ' ' + (c.why || ''))}">${esc(c.action)}</span>`;
    if (c && c.action) return `<span class="t3" title="the engine's last word on ${esc(m.s)}: ${esc((c.t || '') + ' ' + c.action + ' · ' + (c.why || ''))}">AI silent</span>`;
    if (m.bs && m.bs.call) return `<span class="sd-ai rd" title="sector board · ${esc(m.bs.why || '')}">${esc(m.bs.call)}</span>`;
    return '<span class="t3">AI silent</span>';
  }
  const ageTxt = m => isN(m.age) ? H.ago(m.age) : '';

  /* ---------- state ---------- */
  const st = {open: null, sel: null, more: {}, nf: false, drw: '', pins: [], order: {}, pend: null, hover: false, rrT: 0, sec: null, sheet: 0};
  try { st.pins = JSON.parse(localStorage.getItem('girv2_pins') || '[]').slice(0, 5); } catch (e) { st.pins = []; }
  const node = document.createElement('div'); node.className = 'sdl'; node.setAttribute('aria-label', 'sector F&O shares');
  const pane = document.createElement('section'); pane.className = 'sd-pane'; pane.setAttribute('aria-label', 'share pane');
  const CAP = () => PHONE() ? 999 : innerWidth >= 1500 ? 12 : 8;

  /* ---------- page wiring (where it opens, where it mounts) ---------- */
  const lc = s => String(s || '').trim().toLowerCase();
  const CFG = {
    rotation: {anchors: () => $$('#wtb tr.row[data-s]'), nameOf: a => a.dataset.s, mode: 'flow', paneHost: () => $('#rcol'),
      clicks: [['#wtb tr.row[data-s]', a => a.dataset.s, 1], ['#heroLine [data-sec]', a => a.dataset.sec], ['#flowSide .fs[data-sec]', a => a.dataset.sec]],
      insert: a => { let tr = $('#wtb tr.sd-tr'); if (!tr) { tr = document.createElement('tr'); tr.className = 'sd-tr'; tr.innerHTML = '<td></td>'; } tr.firstChild.colSpan = Math.max(1, $$('#wt thead th').filter(t => getComputedStyle(t).display !== 'none').length); a.after(tr); tr.firstChild.appendChild(node); }},
    sectors: {anchors: () => $$('#bdb .sec[data-id] > .srow'), nameOf: a => a.parentNode.dataset.id, mode: 'flow', paneHost: () => $('#call'),
      clicks: [['#bdb .sec[data-id] > .srow', a => a.parentNode.dataset.id, 1], ['#heat .ht[data-o]', a => a.dataset.o], ['#bdb .nt[data-o]', a => a.dataset.o]],
      insert: a => a.after(node)},
    'desk-hunt': {anchors: () => $$('#secList .srow[data-sec]'), nameOf: a => a.dataset.sec, mode: 'dock', paneHost: () => $('#colR'), dockHost: () => $('#colC'),
      clicks: [['#secList .srow[data-sec]', a => a.dataset.sec, 1], ['#memT', () => (S.val('sec.board') || []).length && ($('#secList .srow.on[data-sec]') || $('#secList .srow[data-sec]') || {dataset: {}}).dataset.sec]]},
    morning: {anchors: () => $$('#cards .cd').filter(c => $('.snm', c)), nameOf: a => lc($('.snm', a).textContent), mode: 'dock', paneHost: () => $('#p-tabs'), dockHost: () => $('#p-drv'),
      clicks: [['#cards .cd', a => $('.snm', a) ? lc($('.snm', a).textContent) : null, 1]]},
  };
  const cfg = CFG[PAGE];
  if (!cfg) { window.GIR.SD = {model, plan, contract, RULES}; return; }
  document.body.classList.add('sd-pg');
  let dock = null;
  function mount() {
    if (!st.open) return;
    if (PHONE()) { sheetMount(); return; }
    if (cfg.mode === 'dock') {
      const h = cfg.dockHost(); if (!h) return;
      if (!dock) { dock = document.createElement('section'); dock.className = 'pn sd-dock'; dock.innerHTML = '<div class="sd-dsc"><div class="sd-box" tabindex="-1"></div><div class="sd-rail" data-for="dock"></div></div>'; }
      if (!dock.isConnected) { const ph = $(':scope > .ph', h); if (ph && h.id === 'p-drv') ph.after(dock); else h.prepend(dock); }
      const box = $('.sd-box', dock); if (node.parentNode !== box) box.appendChild(node); railFor(box, $('.sd-rail', dock));
    } else if (!node.isConnected) { const a = anchorOf(st.open); if (a) cfg.insert(a); }
    const ph = cfg.paneHost(); if (ph && st.sel && pane.parentNode !== ph) { ph.classList.add('sd-ph'); ph.appendChild(pane); }
  }
  const anchorOf = name => cfg.anchors().find(a => lc(cfg.nameOf(a)) === lc(name)) || null;
  new MutationObserver(() => { if (st.open && !PHONE() && (!node.isConnected || (cfg.mode === 'dock' && dock && !dock.isConnected))) mount(); markAnchors(); }).observe(document.getElementById('page') || document.body, {childList: true, subtree: true});
  function fixSpan() { const td = node.parentElement; if (td && td.tagName === 'TD' && td.parentElement.classList.contains('sd-tr')) {
      const n = Math.max(1, $$('#wt thead th').filter(t => getComputedStyle(t).display !== 'none').length); if (td.colSpan !== n) td.colSpan = n; } }
  function markAnchors() { fixSpan(); cfg.anchors().forEach((a, i) => { if (!a.hasAttribute('tabindex')) a.tabIndex = 0; const on = !!st.open && lc(cfg.nameOf(a)) === lc(st.open); if (a.classList.contains('sd-anchor') !== on) a.classList.toggle('sd-anchor', on); }); }

  /* ---------- open / close ---------- */
  function openSector(name, o) {
    o = o || {};
    if (!name) return;
    const b = secByName(name); if (!b) { toast('sector "' + name + '" is not on the sector board (sec.board)'); return; }
    if (st.open && lc(st.open) === lc(b.name) && o.toggle) { closeSector(); return; }
    const t0 = performance.now();
    if (!st.open || lc(st.open) !== lc(b.name)) { st.sel = o.sel || null; st.drw = ''; st.order = {}; st.pend = null; }
    st.open = b.name; document.body.classList.add('sd-on');
    if (node.parentNode) node.remove();
    render(true); mount(); markAnchors();
    st.ms = Math.round(performance.now() - t0); node.dataset.ms = st.ms;
    if (!PHONE() && cfg.mode === 'flow' && !o.noScroll) requestAnimationFrame(() => toTop());
    if (PHONE()) pushSheet(1);
    writeHash(); fire();
  }
  function toTop() { const a = anchorOf(st.open); if (!a) return; const sc = scroller(a); if (!sc) return;
    const th = sc.querySelector('thead'), pad = th && /sticky/.test(getComputedStyle(th).position + getComputedStyle(th.querySelector('th') || th).position) ? th.offsetHeight : 0; node.style.setProperty('--sdtop', pad + 'px');
    sc.scrollTop += node.getBoundingClientRect().top - sc.getBoundingClientRect().top - pad; }
  function scroller(el) { for (let e = el.parentElement; e; e = e.parentElement) { const s = getComputedStyle(e); if (/(auto|scroll)/.test(s.overflowY) && e.scrollHeight > e.clientHeight) return e; } return null; }
  function closeSector() {
    st.open = null; st.sel = null; st.drw = ''; document.body.classList.remove('sd-on', 'sd-sel');
    node.remove(); pane.remove(); if (dock) dock.remove(); const etr = document.querySelector('#wtb tr.sd-tr'); if (etr) etr.remove(); /* an empty spanning row would squeeze the table's columns */ $$('.sd-ph').forEach(e => e.classList.remove('sd-ph')); sheetClose(); markAnchors(); writeHash(); fire();
  }
  function select(sym, o) {
    o = o || {}; if (!st.open) return;
    st.sel = sym; st.drw = ''; document.body.classList.toggle('sd-sel', !!sym);
    $$('.sd-r', node).forEach(r => r.classList.toggle('on', r.dataset.s === sym));
    if (!sym) { pane.remove(); $$('.sd-ph').forEach(e => e.classList.remove('sd-ph')); if (PHONE()) shareSheetClose(); writeHash(); return; }
    renderPane(); if (!PHONE()) mount(); else shareSheetOpen(!o.noPush);
    const r = $(`.sd-r[data-s="${CSS.escape(sym)}"]`, node); if (r && o.focus !== false) { r.focus({preventScroll: true}); keepVisible(r); }
    writeHash();
  }
  function keepVisible(r) { const sc = PHONE() ? $('.sd-sheet .sd-box') : (cfg.mode === 'dock' ? $('.sd-box', dock) : scroller(r)); if (!sc) return;
    const a = r.getBoundingClientRect(), b = sc.getBoundingClientRect(), hd = $('.sd-line', node), top = b.top + (hd && !PHONE() ? hd.offsetHeight : 0) + 2;
    if (a.top < top) sc.scrollTop -= top - a.top; else if (a.bottom > b.bottom) sc.scrollTop += a.bottom - b.bottom; }
  const fire = () => document.dispatchEvent(new CustomEvent('gir-sd', {detail: {open: st.open, sel: st.sel}}));

  /* ---------- hash (Back returns to the same sector, the same open list and the same row) ---------- */
  function writeHash() {
    const sc = st.open && !PHONE() ? (cfg.mode === 'dock' ? $('.sd-box', dock || document) : (node.isConnected ? scroller(node) : null)) : null;
    const h = st.open ? '#sd=' + encodeURIComponent(st.open) + (st.sel ? '&r=' + encodeURIComponent(st.sel) : '') + (st.more[st.open] ? '&m=1' : '') + (st.nf ? '&nf=1' : '') + (sc ? '&y=' + Math.round(sc.scrollTop) : '') : '';
    try { history.replaceState(history.state, '', location.pathname + location.search + h); } catch (e) {}
  }
  function readHash() {
    const m = /[#&]sd=([^&]*)/.exec(location.hash); if (!m) return;
    const g = k => { const x = new RegExp('[#&]' + k + '=([^&]*)').exec(location.hash); return x ? decodeURIComponent(x[1]) : null; };
    const name = decodeURIComponent(m[1]); if (g('m')) st.more[name] = 1; if (g('nf')) st.nf = true;
    const r = g('r'), y = g('y');
    const go = () => { if (!secByName(name)) return false; openSector(name, {noScroll: !!y, sel: r}); if (r) select(r, {noPush: true});
      if (y) requestAnimationFrame(() => { const sc = cfg.mode === 'dock' ? $('.sd-box', dock || document) : scroller(node); if (sc) sc.scrollTop = +y; }); return true; };
    if (!go()) { const un = S.subscribe('sec.board', () => { if (go()) un(); }); }
  }

  /* ---------- the list (SectorMembers) ---------- */
  function lineHtml(sec, md) {
    const b = sec.b, br = sec.br, ups = sec.dir > 0, fresh = md.k === 'preopen';
    const basis = String(b.basis || '').replace(/,.*$/, '');
    const C = S.val('calls.feed'), ce = Array.isArray(C) ? C.filter(c => c.side === 'CE' && c.engine !== 'old').length : null, pe = Array.isArray(C) ? C.filter(c => c.side === 'PE' && c.engine !== 'old').length : null;
    const rot = S.val('sec.rot'), n = S.val('idx.NIFTY'), rsn = isN(sec.pct) && n && isN(n.pct) ? sec.pct - n.pct : null;
    const why = (b.reason || (b.news || [])[0] || '').replace(/\s+/g, ' ');
    const exp = S.val('strip.expiry'), ew = exp && exp.date && isN(exp.sessions_left) && exp.sessions_left <= 5;
    const bf = S.get('sec.board');
    return `<div class="sd-line sr" data-sec="${esc(sec.name)}">
      <div class="sd-l1"><button class="sd-x" title="close (Esc)" aria-label="close">✕</button><b class="sd-sn">${esc(cap(sec.name))}</b><b class="${ups ? 'up' : 'dn'}">${ups ? '▲' : '▼'} ${p2(sec.pct)}</b>
        <span class="t3">${esc(basis.replace(/^whole sector:\s*/i, 'all '))}</span><button class="sd-lk sd-basis" title="the basis in full">basis ›</button>
        <span>breadth <b class="up">▲${esc(br.all_up)}</b> <b class="dn">▼${esc(br.all_dn)}</b> <span class="t3">all ${esc(br.all_n)} listed</span></span>
        <span>F&amp;O <b class="up">▲${sec.fo.up}</b> <b class="dn">▼${sec.fo.dn}</b></span>
        ${isN(rsn) ? `<span title="sector day % − NIFTY day % (RS30 needs 1-min sector bars, not in the store)">RS day ${s2(rsn)}</span>` : ''}
        <span class="sd-st">${esc(UP(b.status || ''))}${b.since ? ' ' + esc(b.since) : ''}</span>${sec.narrow ? '<span class="sd-chip sd-nar" title="F&amp;O names move one way, the other listed shares do not (R49)">NARROW</span>' : ''}
        <span class="sd-chip sd-ce" title="CE ideas in this sector now · engine calls today by side (calls.feed)">CE ${sec.ce} · PE ${sec.pe}${ce !== null ? ` · engine today PE ${pe} / CE ${ce}` : ''}</span>
</div>
      <div class="sd-l2">${fresh ? `<span class="sd-chip sd-pre" title="the market is not open: every number is from the last session">${notLive()} · ${esc(lastSession())} close</span>` : md.k === 'forming' ? '<span class="sd-chip sd-pre">forming - groups settle at 09:30</span>' : md.k === 'manage' ? '<span class="sd-chip sd-pre">manage only - no new entries</span>' : ''}
        ${ew ? `<span class="sd-chip sd-exp" title="${esc(exp.date)} is the November expiry, ${exp.sessions_left} sessions left, physical settlement">Expiry week · physical settlement - December only</span>` : ''}<span class="sd-why" title="${esc(why || 'UNEXPLAINED')}"><b>WHY</b> ${why ? esc(why) + (bf && bf.src_ts ? ' <span class="t3">(' + H.ago(nowS() - bf.src_ts) + ' old)</span>' : '') : '<b class="am">UNEXPLAINED</b>'}</span>
        ${b.since ? `<span class="t3" title="run clock: since the sector board's ${esc(b.status || '')} time; the typical run length (n) is not in the store">${ups ? 'up' : 'down'} since ${esc(b.since)}</span>` : ''}
        ${st.reranked ? '<button class="sd-chip sd-rr" title="the order is held while your pointer or focus is on the list">re-ranked · R to apply</button>' : ''}</div>
    </div>`;
  }
  const HEAD = `<div class="sd-h sr"><span class="c-g">group</span><span class="c-n" title="role: LDR leader · FOL follower · DEP dependent · LAG laggard">share · role</span><span class="c-p r">day %</span><span class="c-rs r" title="share day % − sector day % (RS30 / RS15 need 1-min bars, not in the store)">vs sec</span><span class="c-rv r">RVOL</span><span class="c-vw" title="last price vs VWAP (the opening range is not in the store)">VWAP</span><span class="c-rm r" title="ATR used since the open · ATR left (day high / low not in the store)">room</span><span class="c-bu" title="futures build-up, all months, and OI change %">B/U · OI</span><span class="c-wt r" title="weight in the sector (sec.board)">wt %</span><span class="c-k" title="the suggested December strike, its ask premium and its spread %">Dec strike · prem · spr</span><span class="c-st" title="✓ 4/4 = every gate passes · ✕ = the gate that fails (+n more) · EXT ↩ = extended, enter on the pullback to VWAP at that price · trig = the laggard's own trigger">state / gate</span><span class="c-ai">AI</span><span class="c-ag r">age</span></div>`;
  function rowHtml(sec, m, first, n, md, newIn, mv) {
    const c = m.plan.c, gl = first ? gLabel(sec, m.grp, n, md) : null, star = m.plan.takeable;
    const kc = c.kite ? `<b class="sd-k ${m.cp === 'CE' ? 'ce' : 'pe'}${m.grp === 'nt' ? ' off' : ''}" title="${esc(c.kite)} · ${esc(c.exp)}${star ? ' · ★ takeable' : ''}">${k0(c.K)} ${m.cp}${star ? ' ★' : ''}</b> <span class="n">${nn(c.ask)}</span> <span class="t3 n">${isN(c.sprPct) ? c.sprPct.toFixed(1) + '%' : ''}</span>` : nkc(c.why, 'Dec n/k');
    const rs = isN(m.rs) ? `<span class="${m.rs * sec.dir >= 0 ? 'up2' : 'dn2'}">${s2(m.rs)}</span>` : nkc('share or sector % missing');
    return (gl ? `<div class="sd-gh sr g-${m.grp}"><b>${esc(gl[0])}</b><small>${esc(gl[1])}</small></div>` : '') + `<div class="sd-r sr g-${m.grp}${first ? ' g1' : ''}${st.sel === m.s ? ' on' : ''}${m.isExt ? ' ext' : ''}" data-s="${esc(m.s)}" data-g="${m.grp}" tabindex="-1" role="row">
      <span class="c-g">${gl ? `<b>${esc(gl[0])}</b><small>${esc(gl[1])}</small>` : ''}</span>
      <span class="c-n"><b class="sd-sym">${esc(m.s)}</b>${mv ? `<i class="sd-mv ${mv > 0 ? 'up' : 'dn'}">${mv > 0 ? '▲' : '▼'}${Math.abs(mv)}</i>` : ''}${roleChip(m.role)}${newIn ? '<i class="sd-new">NEW</i>' : ''}${st.pins.includes(m.s) ? '<i class="sd-pin" title="pinned">📌</i>' : ''}</span>
      <span class="c-p r n ${m.pct > 0 ? 'up' : m.pct < 0 ? 'dn' : ''}">${isN(m.pct) ? p2(m.pct) : nkc('sh.' + m.s + '.pct')}</span>
      <span class="c-rs r n">${rs}</span>
      <span class="c-rv r n">${isN(m.rvol) ? m.rvol.toFixed(1) : nkc('sh.' + m.s + '.rvol')}</span>
      <span class="c-vw">${m.side ? `<span class="${(m.side === 'above') === (sec.dir > 0) ? 'up2' : 'dn2'}">${m.side}</span>` : nkc('VWAP missing')}</span>
      <span class="c-rm r n">${isN(m.used) ? m.used.toFixed(1) + '·' + m.left.toFixed(1) : nkc('ATR / open missing')}</span>
      <span class="c-bu">${m.bu ? `<span class="sh-c sh-c-${m.bu.toLowerCase()} sm">${m.bu}</span>` : '<span class="t3">none</span>'} <span class="n">${isN(m.oi) ? sgn(m.oi, Math.abs(m.oi) >= 100 ? 0 : 1) : ''}</span></span>
      <span class="c-wt r n">${isN(m.wt) ? m.wt.toFixed(1) + `<i class="sd-wb" style="width:${Math.min(100, m.wt * 2).toFixed(0)}%"></i>` : nkc('sec.board lists no weight for ' + m.s)}</span>
      <span class="c-k">${kc}</span>
      <span class="c-st">${stateCell(m)}</span>
      <span class="c-ai">${aiCell(m)}</span>
      <span class="c-ag r n t3">${ageTxt(m)}</span></div>`;
  }
  function listHtml(sec) {
    const md = mode();
    let L = sec.members;
    const prev = st.order[sec.name], frozen = prev && (st.hover || node.contains(document.activeElement)) && !st.apply;
    let newSet = new Set(), moves = {};
    if (prev) { const idx = {}; L.forEach((m, i) => idx[m.s] = i);
      const changed = prev.syms.join() !== L.map(m => m.s).join();
      if (changed && frozen) { const bySym = {}; L.forEach(m => bySym[m.s] = m);
        const kept = prev.syms.filter(s => bySym[s]).map(s => Object.assign({}, bySym[s], {grp: prev.grp[s] || bySym[s].grp}));
        L.filter(m => !prev.syms.includes(m.s)).forEach(m => { newSet.add(m.s); kept.push(m); });
        kept.forEach((m, i) => { const d = (prev.syms.indexOf(m.s) >= 0 ? idx[m.s] - i : 0); if (d) moves[m.s] = -d; });
        L = kept; st.reranked = true; if (!st.rrT) st.rrT = setTimeout(() => { st.rrT = 0; if (!st.hover) { st.apply = 1; render(); st.apply = 0; } }, 30000);
      } else st.reranked = false; }
    if (!frozen || !prev) st.order[sec.name] = {syms: L.map(m => m.s), grp: Object.fromEntries(L.map(m => [m.s, m.grp]))};
    const more = !!st.more[sec.name], cap0 = CAP();
    let h = lineHtml(sec, md) + HEAD + '<div class="sd-rows">';
    const notes = [];
    if (!sec.lag.ok) notes.push(`no laggard - breadth ${isN(sec.lag.bw) ? Math.round(sec.lag.bw * 100) + '%' : 'not known'} one way, below the 70% rule`);
    if (md.k === 'forming') notes.push('forming - before 09:30 the groups are not final');
    if (md.k === 'manage') notes.push('manage only - no new entries after 14:30');
    let shown = 0; const hid = [];
    GORDER.forEach(g => { const a = L.filter(m => m.grp === g); a.forEach((m, i) => { if (!more && shown >= cap0) { hid.push(m.s); return; } shown++; h += rowHtml(sec, m, i === 0 || (shown === 1), a.length, md, newSet.has(m.s), moves[m.s]); }); });
    if (!L.length) h += '<div class="sd-empty">no F&amp;O share of this sector in the store (sh.* has no member with this sector)</div>';
    h += '</div>';
    if (hid.length) h += `<button class="sd-more sr" title="show every F&amp;O share">+${hid.length} more ▾ <span class="t3">${esc(hid.slice(0, 6).join(' · '))}${hid.length > 6 ? ' …' : ''}</span></button>`;
    else if (more && L.length > cap0) h += '<button class="sd-more sr">show fewer ▴</button>';
    if (notes.length) h += `<div class="sd-note sr">${notes.map(esc).join(' · ')}</div>`;
    const nf = sec.nonfo;
    if (nf && nf.n > 0) h += `<button class="sd-nf sr" title="the listed shares of this sector with no F&amp;O contract: context only, never a strike">${st.nf ? '▾' : '▸'} ${nf.n} more listed, not F&amp;O · <b class="up">▲${nf.up}</b> <b class="dn">▼${nf.dn}</b> · wt ${isN(nf.wt) ? nf.wt.toFixed(0) + '%' : 'not known'}<span class="t3"> · context only, no strike</span></button>` +
      (st.nf ? `<div class="sd-nfx sr">${nf.n} listed shares outside F&amp;O: ▲${nf.up} ▼${nf.dn} (from the all-listed breadth). Their names and prices are not known - sec.board names its F&amp;O shares only. They never get a strike.</div>` : '');
    const miss = [];
    const nodec = L.filter(m => !m.plan.c || !m.plan.c.kite);
    if (nodec.length) { const have = S.keys('oc.').filter(k => { const o = S.val(k); return o && Array.isArray(o.rows2) && o.rows2.length; }).length;
      miss.push('December chain - in the store for ' + have + ' of ' + S.keys('oc.').length + ' option chains now (oc.<SYM>.rows2); ' + nodec.length + ' rows here show Dec n/k'); }
    if (L.some(m => m.wt === null)) miss.push('weight % - sec.board gives weights for ' + L.filter(m => m.wt !== null).length + ' of ' + L.length + ' shares');
    miss.push('RS30 / RS15 / closed 5-min bars / opening range / day high-low - not in the store; the day RS vs the sector and the last price vs VWAP stand in');
    h += '<div class="sd-leg sr" title="legend">roles <b>LDR</b> leader · <b>FOL</b> follower · <b>DEP</b> dependent · <b>LAG</b> laggard · <b>EXT ↩ x</b> extended - enter on the pullback to VWAP x · <b>✕</b> the gate that fails · <b>★</b> a strike you could take</div>';
    h += `<div class="sd-miss sr"><b>not known</b> - ${miss.map(esc).join(' · ')}</div>`;
    return h;
  }
  let lastH = '';
  function render(force) {
    if (!st.open) return;
    const sec = model(st.open); if (!sec) { closeSector(); return; }
    st.sec = sec;
    const h = listHtml(sec);
    if (force || h !== lastH) {
      const foc = document.activeElement && node.contains(document.activeElement) ? (document.activeElement.dataset.s || '') : null;
      node.innerHTML = h; lastH = h; node.dataset.sec = sec.name;
      if (foc) { const r = $(`.sd-r[data-s="${CSS.escape(foc)}"]`, node); if (r) r.focus({preventScroll: true}); }
    }
    if (st.sel) renderPane();
    if (PHONE()) sheetMount();
    else if (cfg.mode === 'dock' && dock) railFor($('.sd-box', dock), $('.sd-rail', dock));
  }

  /* ---------- the share pane (SharePane) ---------- */
  function paneHtml(sec, m) {
    const p = m.plan, c = p.c, i2 = contract(m, 'itm'), md = mode(), v = m.v, fu = S.val('fut.' + m.s);
    const box = (lab, a, b) => `<tr><th>${lab}</th><td>${a}</td><td>${b}</td></tr>`;
    const col = (x, f) => x && !x.why ? f(x) : nkc(x ? x.why : 'no contract');
    const months = fu && Array.isArray(fu.months) ? fu.months.map(x => `${esc(cap(x.m.toLowerCase()))} ${isN(x.pct) ? sgn(x.pct, 1) + '%' : ''}`).join(' · ') + (fu.total && isN(fu.total.pct) ? ` · all ${sgn(fu.total.pct, 1)}%` : '') : nkc('fut.' + m.s);
    const blocked = !!p.block, dimmed = m.ban || md.locked;
    const news = (S.val('news.list') || []).filter(n => n.s === m.s).slice(0, 2);
    const C = S.val('calls.feed'), call = Array.isArray(C) ? C.find(x => x.s === m.s && x.engine !== 'old') : null;
    const exp = S.val('strip.expiry'), ew = exp && isN(exp.sessions_left) && exp.sessions_left <= 5;
    const lk = isN(m.mwpl) ? `<span class="sd-chip ${m.mwpl >= 90 ? 'sd-red' : m.mwpl >= 80 ? 'sd-amb' : ''}" title="market-wide position limit used${m.mwpl >= 90 ? ' - near ban' : ''}">MWPL ${m.mwpl.toFixed(0)}%</span>` : nkc('sh.' + m.s + '.mwpl', 'MWPL n/k');
    const held = (() => { const P = S.val('pos.open'); return Array.isArray(P) && P.some(x => { const s = x.s || x.sym; const sv = S.val('sh.' + s); return sv && sv.sector === sec.name; }); })();
    const spWarn = c && isN(c.sprPct) && c.sprPct > 1 ? (() => { const alt = i2 && isN(i2.sprPct) && i2.sprPct < c.sprPct ? ` · ${k0(i2.K)} ${m.cp} has ${i2.sprPct.toFixed(1)}%` : ''; return `SPREAD ${c.sprPct.toFixed(1)}% = ${rsI(c.sprLot)} lost on entry${alt}`; })() : '';
    return `<div class="sd-ph-h"><span class="sd-pn" title="double-click: the full Share page (F7)">${esc(m.s)}</span><b class="sd-px n">${nn(m.px)}</b><b class="n ${m.pct > 0 ? 'up' : 'dn'}">${p2(m.pct)}</b><span class="t3">${ageTxt(m)} ${m.f && m.f.state !== 'LIVE' ? esc(m.f.state) : ''}</span>
        <span class="sd-pa"><button class="btn sd-b" data-a="f7" title="the full Share page (F7) - same numbers"><kbd>Enter</kbd>F7</button><button class="btn sd-b" data-a="o" title="option chain at the December strike"><kbd>O</kbd>chain</button><button class="btn sd-b" data-a="w"><kbd>W</kbd>why</button><button class="btn sd-b" data-a="plan"><kbd>Space</kbd>plan</button><button class="btn sd-b" data-a="p"><kbd>P</kbd>${st.pins.includes(m.s) ? 'unpin' : 'pin'}</button><button class="btn sd-b" data-a="x" title="close the pane (Esc)">✕</button></span></div>
      <div class="sd-pbw"><div class="sd-pb" tabindex="-1">
      <button class="sd-lk sd-whyb" data-a="w">WHY ${esc(m.s)} is moving ›</button>
      <div class="sd-s1">${esc(cap(sec.name))} · <b class="sd-gn">${esc(gLabel(sec, m.grp, 1, md)[0])}</b> ${roleChip(m.role)} · lot ${esc(m.lot)}${isN(m.wt) ? ' · wt ' + m.wt.toFixed(1) + '%' : ''}</div>
      <div class="sd-s1">VWAP ${nn(m.vwap)} <b class="${(m.side === 'above') === (sec.dir > 0) ? 'up' : 'dn'}">${esc(m.side || '')}</b>${isN(m.ext) ? ' · ' + (m.px >= m.vwap ? '+' : M) + m.ext.toFixed(2) + ' ATR' : ''} · vs sector ${s2(m.rs)} · RVOL ${isN(m.rvol) ? m.rvol.toFixed(1) : 'n/k'} · score ${m.score.toFixed(2)}</div>
      <div class="sd-s1">ATR ${nn(m.atr)} · range used ${isN(m.used) ? m.used.toFixed(2) + '× ATR' : 'n/k'} · room left ${isN(m.left) ? m.left.toFixed(2) + '× ATR' : 'n/k'} · EXT ${isN(m.ext) ? m.ext.toFixed(2) : 'n/k'}${m.isExt ? ' <b class="sd-ext">EXTENDED - don\'t chase</b>' : ''}</div>
      <div class="sd-s1">build-up ${m.bu ? `<span class="sh-c sh-c-${m.bu.toLowerCase()} sm">${m.bu}</span>` : 'none'} ${months}</div>
      ${ew ? '<div class="sd-wn sd-expw">Expiry week · physical settlement - December only</div>' : ''}
      <div class="sd-sec ${dimmed ? 'sd-dim' : ''}"><div class="sd-st2">TRADE BOX · ${c && c.exp ? esc(c.exp) : 'December'} (December only)</div>
      ${c && c.why && !c.K ? `<div class="sd-s1"><span class="nk">not known</span> - ${esc(c.why)}: no December bid / ask, depth, delta, theta, IV or lot cost for ${esc(m.s)} tonight</div>` : `
      <table class="sd-tb"><tr><th></th><td class="t3">ATM</td><td class="t3">1 ITM</td></tr><tr><th>contract</th><td>${col(c, x => `<b class="sd-k ${m.cp === 'CE' ? 'ce' : 'pe'}">${k0(x.K)} ${m.cp}${p.takeable ? ' ★' : ''}</b>`)}</td><td>${col(i2, x => `<b class="sd-k ${m.cp === 'CE' ? 'ce' : 'pe'}">${k0(x.K)} ${m.cp}</b>`)}</td></tr>
      ${box('bid', col(c, x => nn(x.bid)), col(i2, x => nn(x.bid)))}${box('ask', col(c, x => nn(x.ask)), col(i2, x => nn(x.ask)))}
      ${box('spread ₹ / lot', col(c, x => rsI(x.sprLot)), col(i2, x => rsI(x.sprLot)))}${box('spread %', col(c, x => isN(x.sprPct) ? x.sprPct.toFixed(1) + '%' : 'n/k'), col(i2, x => isN(x.sprPct) ? x.sprPct.toFixed(1) + '%' : 'n/k'))}
      ${box('depth at bid', col(c, x => isN(x.depLots) ? x.depLots + ' lots' : 'n/k'), col(i2, x => isN(x.depLots) ? x.depLots + ' lots' : 'n/k'))}
      ${box('Δ · θ ₹/h per lot', col(c, x => (isN(x.delta) ? x.delta.toFixed(2) : 'n/k') + ' · ' + (isN(x.thh) ? rsI(x.thh) : 'n/k')), col(i2, x => (isN(x.delta) ? x.delta.toFixed(2) : 'n/k') + ' · ' + (isN(x.thh) ? rsI(x.thh) : 'n/k')))}
      ${box('IV · vs 20-day', col(c, x => (isN(x.iv) ? x.iv.toFixed(1) : 'n/k') + ' · ' + nkc('IV 20-day history not in the store', 'n/k')), col(i2, x => (isN(x.iv) ? x.iv.toFixed(1) : 'n/k')))}
      ${box('max loss = lot cost', col(c, x => rsI(x.lotCost)), col(i2, x => rsI(x.lotCost)))}
      ${box('break-even 15:10', isN(p.be) ? nn(p.be) : 'n/k', '')}</table>
      <div class="t3 sd-fn">θ ₹/h = the store's day theta ÷ ${RULES.TH_HOURS} h × lot · premiums at the levels ≈ delta-gamma from the December mid</div>`}</div>
      <div class="sd-sec sd-planb ${blocked || dimmed ? 'sd-dim' : ''}"><div class="sd-st2">PLAN · ${esc(m.cp)}</div>
        <table class="sd-tb"><tr><th></th><td>share</td><td>premium</td></tr>${box('trigger', nn(p.trig), isN(p.pT) ? '≈ ' + nn(p.pT) : 'n/k')}${box('stop', nn(p.stop), isN(p.pS) ? '≈ ' + nn(p.pS) : 'n/k')}${box('target', nn(p.tgt), isN(p.pG) ? '≈ ' + nn(p.pG) : 'n/k')}</table>
        <div class="sd-s1">${esc(p.how)}</div>
        <div class="sd-s1">risk / lot ${isN(p.risk) ? rsI(p.risk) : 'n/k'} (costs ${isN(p.costs) ? rsI(p.costs) : 'n/k'}) · R:R ${isN(p.rr) ? p.rr.toFixed(2) : 'n/k'} · lock room ${isN(p.room) ? rsI(p.room) : nkc('pos.day.lock.left')} · 1R ${isN(p.r1) ? rsI(p.r1) : nkc('pos.day.r1 not in the store', 'not known')}</div>
        <div class="sd-lots"><b>${esc(p.lotsTxt || '')}</b></div>
        ${p.block ? `<div class="sd-blk"><b>${esc(p.block)}</b><div class="sd-blk2">${esc(p.why || '')}</div></div>` : ''}
        ${md.locked && !p.block.startsWith('LOCKED') ? `<div class="sd-blk"><b>LOCKED - no new trades today</b><div class="sd-blk2">${esc(md.lockWhy || 'day loss lock (pos.day.lock)')}</div></div>` : ''}
        <div class="sd-s1 t3">trades ${(() => { const n = (S.val('pos.day') || {}).trades; return isN(n) && n >= 3 ? `<b style="color:var(--warn,#f59e0b)">${n} of 3 - the day's 3-trade plan is used up</b>` : esc(n ?? 'n/k') + ' of 3'; })()} · 15:10 last entry${mode().open ? ' · ' + Math.max(0, Math.round(hrsLeft() * 60)) + ' min left' : ''}</div></div>
      <div class="sd-sec"><div class="sd-st2">WARNINGS</div>${[spWarn, c && isN(c.depLots) && c.depLots < 3 ? 'THIN depth: ' + c.depLots + ' lots at the bid' : '', ew ? 'Expiry week · physical settlement - December only' : '', held ? 'you already hold this sector' : ''].filter(Boolean).map(x => `<div class="sd-wn">${esc(x)}</div>`).join('') || '<div class="t3">none from the store</div>'}
        <div class="sd-chips">${lk} ${nkc('res.calendar not in the store', 'results n/k')} ${nkc('corp.actions not in the store', 'ex-date n/k')}</div></div>
      <div class="sd-sec"><div class="sd-st2">CHART</div><div class="sd-s1">${nkc('5-min bars of ' + m.s + ' are not in the store', '5-min chart not known')} · walls (23 Nov chain): CE ${k0(c && c.roof)} · PE ${k0(c && c.floor)}</div></div>
      <div class="sd-sec"><div class="sd-st2">AI VIEW</div><div class="sd-s1">${call ? esc((call.t || '') + ' ' + (call.action || '') + ' ' + (call.side || '') + ' · ' + (call.why || '')) : m.bs && m.bs.call ? 'sector board: ' + esc(m.bs.call + ' ' + (m.bs.side || '') + ' · ' + (m.bs.why || '')) : 'AI silent - your read'}</div></div>
      <div class="sd-sec"><div class="sd-st2">NEWS</div>${news.length ? news.map(n => `<div class="sd-s1">${esc(n.h)} <span class="t3">${H.ago(nowS() - n.t)} old</span></div>`).join('') : '<div class="t3">no news item on ' + esc(m.s) + ' in news.list</div>'}</div>
      </div><div class="sd-rail" data-for="pane"></div></div>
      <div class="sd-drw" data-d="w"><div class="sd-dh"><b>WHY ${esc(m.s)} is moving</b><button class="btn sd-b" data-a="dx">✕</button></div><div class="sd-s1">sector: ${esc(sec.b.why || sec.b.reason || 'UNEXPLAINED')}</div><div class="sd-s1">share: ${esc((m.bs && (m.bs.why || m.bs.money)) || 'no reason in the store')}${m.bu ? ' · futures ' + esc(m.bu) : ''}</div><div class="sd-s1">gates: ${m.gok ? 'all four pass' : esc(m.fails.join(' · '))} · score ${m.score.toFixed(2)}</div></div>
      <div class="sd-drw" data-d="plan"><div class="sd-dh"><b>PLAN CARD · ${esc(m.s)} ${c && c.kite ? esc(c.kite) : ''}</b><button class="btn sd-b" data-a="dx">✕</button></div><div class="sd-s1">${esc(p.how)}</div><div class="sd-s1">${esc(p.lotsTxt || '')}</div><div class="sd-s1"><a href="plan-card?s=${encodeURIComponent(m.s)}">open the full plan card ›</a></div></div>
      <div class="sd-toast" role="status"></div>
      <div class="sd-act"><button class="btn pri sd-copy" data-a="copy" ${p.copyOff ? 'disabled' : ''} title="${esc(p.copyOff ? 'Copy is off: ' + p.copyOff : 'puts ' + (c.kite || '') + ' on the clipboard')}">Copy ${c && c.K ? k0(c.K) + ' ' + m.cp : 'contract'} · ${p.lots} ${p.lots === 1 ? 'lot' : 'lots'}</button><button class="btn sd-b" data-a="p">${st.pins.includes(m.s) ? 'Unpin' : 'Pin'} ${st.pins.length}/5</button><button class="btn sd-b" data-a="f7">Full page ›</button>
        <span class="sd-never">GIR never places orders - you place the order in Kite.</span></div>`;
  }
  function renderPane() {
    if (!st.sel || !st.sec) return;
    const m = st.sec.members.find(x => x.s === st.sel); if (!m) { pane.innerHTML = `<div class="sd-s1">${esc(st.sel)} is not an F&amp;O member of ${esc(st.sec.name)}</div>`; return; }
    const pb = $('.sd-pb', pane), y = pb ? pb.scrollTop : 0, h = paneHtml(st.sec, m);
    if (pane._h !== h) { pane.innerHTML = h; pane._h = h; const nb = $('.sd-pb', pane); if (nb) nb.scrollTop = y; }
    pane.dataset.s = m.s; if (st.drw) { const d = $(`.sd-drw[data-d="${st.drw}"]`, pane); if (d) d.classList.add('on'); }
    requestAnimationFrame(() => railFor($('.sd-pb', pane), $('.sd-rail[data-for="pane"]', pane)));
  }
  function drawer(k) { st.drw = st.drw === k ? '' : k; $$('.sd-drw', pane).forEach(d => d.classList.toggle('on', d.dataset.d === st.drw)); }
  let tT = 0;
  function toast(t) { const el = $('.sd-toast', pane.isConnected ? pane : document) || (() => { const x = document.createElement('div'); x.className = 'sd-toast sd-toast-g'; document.body.appendChild(x); return x; })();
    const act = el.parentElement && $('.sd-act', el.parentElement); if (act && act.offsetHeight) el.style.bottom = (act.offsetHeight + 6) + 'px';
    el.textContent = t; el.classList.add('on'); clearTimeout(tT); tT = setTimeout(() => el.classList.remove('on'), 2600); }
  function pin(sym) { if (!sym) return; const i = st.pins.indexOf(sym); if (i >= 0) st.pins.splice(i, 1); else if (st.pins.length >= 5) { toast('5 shares pinned already (the most) - unpin one first'); return; } else st.pins.push(sym);
    try { localStorage.setItem('girv2_pins', JSON.stringify(st.pins)); } catch (e) {}
    pane._h = ''; render(true); toast((i >= 0 ? 'unpinned ' : 'pinned ') + sym + ' · ' + st.pins.length + '/5 (kept in this browser; the Desk watchlist key is not in the store)'); }
  function copyContract() {
    const m = st.sec && st.sec.members.find(x => x.s === st.sel); if (!m) return; const p = m.plan;
    if (p.copyOff) { toast('Copy is off - ' + p.copyOff); return; }
    const t = p.c.kite, done = ok => { st.copied = ok ? t : ''; toast(ok ? 'Copied ' + t + ' · ' + p.lots + (p.lots === 1 ? ' lot' : ' lots') + ' - you place the order in Kite' : 'copy failed - select ' + t + ' by hand'); };
    const fb = () => { try { const ta = document.createElement('textarea'); ta.value = t; ta.style.position = 'fixed'; ta.style.opacity = '0'; document.body.appendChild(ta); ta.select(); const ok = document.execCommand('copy'); ta.remove(); done(ok); } catch (e) { done(false); } };
    if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(t).then(() => done(true), fb); else fb();
  }
  const f7 = s => { writeHash(); location.href = 'share?s=' + encodeURIComponent(s); };
  function chainAt() { const m = st.sec && st.sec.members.find(x => x.s === st.sel); if (!m) { toast('pick a share first (click a row)'); return; } const c = m.plan.c; writeHash();
    location.href = 'chain?s=' + encodeURIComponent(m.s) + (c && c.exp ? '&exp=' + c.exp + '&k=' + c.K + '&side=' + m.cp : ''); }

  /* ---------- drawn scrollbars (R51): visible, draggable by mouse and finger, track click / tap, ▲ ▼, wheel ---------- */
  function railFor(box, rail) {
    if (!box || !rail) return;
    if (!rail._on) { rail._on = 1; rail.innerHTML = '<button class="u" tabindex="-1" title="scroll up">▲</button><div class="tk"><i></i></div><button class="d" tabindex="-1" title="scroll down">▼</button>';
      rail._box = box; dragWire($('.tk', rail), $('i', rail), () => rail._box);
      $$('button', rail).forEach(b => b.addEventListener('mousedown', e => e.preventDefault()));
      $('.u', rail).addEventListener('click', () => { rail._box.scrollTop -= 66; });
      $('.d', rail).addEventListener('click', () => { rail._box.scrollTop += 66; });
      rail.addEventListener('wheel', e => { e.preventDefault(); rail._box.scrollTop += e.deltaY; }, {passive: false});
    }
    rail._box = box;
    if (!box._rl) { box._rl = 1; box.addEventListener('scroll', () => { thumb(box, rail._box === box ? rail : null); if (box.classList.contains('sd-box')) writeHash(); }, {passive: true}); }
    box._rail = rail; thumb(box, rail);
  }
  function thumb(box, rail) { rail = rail || box._rail; if (!rail) return; const tk = $('.tk', rail), i = $('i', rail), H0 = tk.clientHeight, sh = box.scrollHeight, ch = box.clientHeight, all = sh <= ch + 1;
    const th = Math.max(PHONE() ? 28 : 18, all ? H0 : H0 * ch / sh); i.style.height = th + 'px'; i.style.top = (all ? 0 : (H0 - th) * box.scrollTop / Math.max(1, sh - ch)) + 'px'; rail.classList.toggle('all', all); }
  let dragged = 0;
  function dragWire(tk, th, boxOf, after) {
    const jump = y => { const b = boxOf(); if (!b) return; const r = tk.getBoundingClientRect(), t = th.getBoundingClientRect(); b.scrollTop += (y < t.top ? -1 : 1) * b.clientHeight * 0.9; after && after(b); };
    const start = (y0, move, up) => { const b = boxOf(); if (!b) return; const top0 = b.scrollTop, k = (b.scrollHeight - b.clientHeight) / Math.max(1, tk.clientHeight - th.offsetHeight);
      return y => { b.scrollTop = top0 + (y - y0) * k; after && after(b); }; };
    tk.addEventListener('pointerdown', e => { if (e.pointerType === 'touch') return; e.preventDefault(); e.stopPropagation();
      if (e.target !== th) { jump(e.clientY); return; }
      const mv = start(e.clientY); if (!mv) return; th.classList.add('drag'); dragged = 1; tk.setPointerCapture(e.pointerId);
      const pm = ev => mv(ev.clientY), pu = () => { th.classList.remove('drag'); tk.removeEventListener('pointermove', pm); tk.removeEventListener('pointerup', pu); tk.removeEventListener('pointercancel', pu); setTimeout(() => dragged = 0, 0); };
      tk.addEventListener('pointermove', pm); tk.addEventListener('pointerup', pu); tk.addEventListener('pointercancel', pu); });
    /* fingers: touch events with preventDefault (8.2 - the rail never lets a flick turn into a row tap) */
    const rail = tk.parentElement;
    rail.addEventListener('touchstart', e => { e.preventDefault(); e.stopPropagation(); const t0 = e.touches[0], tr = th.getBoundingClientRect();
      const onThumb = t0.clientY >= tr.top - 8 && t0.clientY <= tr.bottom + 8; if (!onThumb) { if (e.target.closest('button')) { e.target.click(); return; } jump(t0.clientY); return; }
      const mv = start(t0.clientY); th.classList.add('drag');
      const tm = ev => { ev.preventDefault(); mv(ev.touches[0].clientY); }, te = () => { th.classList.remove('drag'); rail.removeEventListener('touchmove', tm); rail.removeEventListener('touchend', te); rail.removeEventListener('touchcancel', te); };
      rail.addEventListener('touchmove', tm, {passive: false}); rail.addEventListener('touchend', te); rail.addEventListener('touchcancel', te); }, {passive: false});
  }
  /* the pages' own drawn bars become draggable too (fault 0): F3 .rail[data-t] thumbs, shell .trk thumbs, Morning / F2 .vsb */
  function pageRails() {
    $$('.rail[data-t] .trk').forEach(tk => { if (tk._sd) return; tk._sd = 1; const th = $('i', tk); if (!th) return;
      dragWire(tk, th, () => document.getElementById(tk.parentElement.dataset.t));
      tk.parentElement.addEventListener('wheel', e => { const b = document.getElementById(tk.parentElement.dataset.t); if (!b) return; e.preventDefault(); b.scrollTop += e.deltaY; }, {passive: false}); });
    $$('.trk').forEach(tk => { if (tk._sd || tk.closest('.rail')) return; const th = $('i', tk); if (!th) return; const owner = $$('.pb,.scb,.sc,.lst .sc').find(x => x._trk === tk); if (!owner) return; tk._sd = 1; tk.classList.add('sd-drag');
      dragWire(tk, th, () => owner, b => H.track(b)); tk.addEventListener('wheel', e => { e.preventDefault(); owner.scrollTop += e.deltaY; }, {passive: false}); });
    $$('.vsb').forEach(v => { if (v._sd) return; const th = $('i', v); if (!th) return; const own = v.dataset.for ? document.getElementById(v.dataset.for) : $$('.pb').find(x => x._trk === v); if (!own) return; v._sd = 1; v.classList.add('sd-drag'); dragWire(v, th, () => own); v.addEventListener('wheel', e => { e.preventDefault(); own.scrollTop += e.deltaY; }, {passive: false}); });
  }
  document.addEventListener('click', e => { if (dragged && e.target.closest('.trk,.rail,.vsb,.sd-rail')) { e.stopPropagation(); e.preventDefault(); dragged = 0; } }, true);

  /* ---------- events: capture the sector clicks before the page's own handlers (one behaviour everywhere) ---------- */
  document.addEventListener('click', e => {
    const t = e.target;
    if (tapEl && Date.now() - tapT < 500) { e.stopPropagation(); e.preventDefault(); tapEl = null; return; } // the click of a tap already routed (or its ghost on the sheet that just opened)
    if (PHONE() && t.closest('.sd-sheet')) return; // the sheet handles its own taps
    for (const [sel, nm, tog] of cfg.clicks) { const a = t.closest(sel); if (!a) continue; if (t.closest('a[href]') && !t.closest('.sd-x')) return; const name = nm(a); if (!name || !secByName(name)) return;
      e.preventDefault(); e.stopPropagation(); openSector(name, {toggle: !!tog}); return; }
  }, true);
  /* 8.2 phone fast flick: a tap that lands while a list is still flinging gives no click in Chrome - so a short finger tap
     (pointerdown -> pointerup, < 10 px, < 350 ms) opens the sector / the row itself, and the click that may follow is dropped */
  let pd = null, tapEl = null, tapT = 0;
  function tapRoute(t) {
    if (t.closest('.sd-rail,.trk,.vsb,.rail')) return null;
    if (!t.closest('.sd-sheet') || !PHONE()) for (const [sel, nm, tog] of cfg.clicks) { const a = t.closest(sel); if (!a) continue; if (t.closest('a[href]')) return null; const name = nm(a); if (!name || !secByName(name)) return null; openSector(name, {toggle: !!tog}); return a; }
    const r = t.closest('.sdl .sd-r'); if (r && !t.closest('a[href],button')) { select(r.dataset.s); return r; }
    return null;
  }
  document.addEventListener('pointerdown', e => { pd = e.pointerType === 'touch' ? {x: e.clientX, y: e.clientY, t: Date.now(), el: e.target} : null; }, true);
  let td = null; // the same short tap from touch events too (a tap that stops a fling can lose its pointerup)
  document.addEventListener('touchstart', e => { tapEl = null; const t = e.touches[0]; td = e.touches.length === 1 ? {x: t.clientX, y: t.clientY, t: Date.now(), el: e.target} : null; }, {capture: true, passive: true});
  document.addEventListener('touchend', e => { const q = td; td = null; if (!q || (tapEl && Date.now() - tapT < 500)) return; const c = e.changedTouches[0];
    if (!c || Math.hypot(c.clientX - q.x, c.clientY - q.y) > 10 || Date.now() - q.t > 350) return; const el = tapRoute(q.el); if (el) { tapEl = el; tapT = Date.now(); } }, {capture: true, passive: true});
  document.addEventListener('pointerup', e => { if (e.pointerType !== 'touch' || !pd) return; const q = pd; pd = null; if (tapEl && Date.now() - tapT < 500) return;
    if (Math.hypot(e.clientX - q.x, e.clientY - q.y) > 10 || Date.now() - q.t > 350) return;
    const el = tapRoute(q.el); if (el) { tapEl = el; tapT = Date.now(); } }, true);
  
  node.addEventListener('click', e => {
    const t = e.target;
    if (t.closest('.sd-x')) { closeSector(); return; }
    if (t.closest('.sd-basis')) { const b = st.sec && st.sec.b; basisPop(t.closest('.sd-basis'), b); return; }
    if (t.closest('.sd-rr')) { applyRR(); return; }
    if (t.closest('.sd-more')) { st.more[st.open] = !st.more[st.open]; render(true); writeHash(); return; }
    if (t.closest('.sd-nf')) { st.nf = !st.nf; render(true); writeHash(); return; }
    if (t.closest('a[href]')) return;
    const r = t.closest('.sd-r'); if (r) { if (PHONE() && Date.now() - flickT < 0) return; select(r.dataset.s); }
  });
  node.addEventListener('dblclick', e => { const r = e.target.closest('.sd-r'); if (r) f7(r.dataset.s); });
  node.addEventListener('pointerenter', () => { st.hover = true; });
  node.addEventListener('pointerleave', () => { st.hover = false; if (st.reranked) applyRR(); });
  function applyRR() { st.apply = 1; st.reranked = false; clearTimeout(st.rrT); st.rrT = 0; render(true); st.apply = 0; }
  let flickT = 0;
  pane.addEventListener('click', e => {
    const b = e.target.closest('[data-a]'); if (!b || b.disabled) { if (e.target.closest('.sd-copy[disabled]')) toast('Copy is off - ' + (e.target.closest('.sd-copy').title || '').replace(/^Copy is off: /, '')); return; }
    const a = b.dataset.a, m = st.sel;
    if (a === 'f7') f7(m); else if (a === 'o') chainAt(); else if (a === 'w') drawer('w'); else if (a === 'plan') drawer('plan'); else if (a === 'p') pin(m);
    else if (a === 'x') select(null); else if (a === 'dx') drawer(''); else if (a === 'copy') copyContract(); else if (a === 'back') history.back();
  });
  pane.addEventListener('dblclick', e => { if (e.target.closest('.sd-pn')) f7(st.sel); });
  function basisPop(btn, b) {
    let p = $('.sd-pop'); if (p && p.classList.contains('on')) { p.classList.remove('on'); return; }
    if (!p) { p = document.createElement('div'); p.className = 'sd-pop'; document.body.appendChild(p); p.addEventListener('click', () => p.classList.remove('on')); }
    p.innerHTML = `<b>basis (R49)</b><div>${esc(b.basis || 'not known')}</div><div class="t3">breadth: all ${esc(b.breadth && b.breadth.all_n)} listed shares; F&amp;O ${esc(b.breadth && b.breadth.fo_n)}. The move and breadth use every listed share; the list below is only the tradable (F&amp;O) part.</div><div class="t3">click to close</div>`;
    const r = btn.getBoundingClientRect(); p.style.left = Math.max(8, Math.min(r.left, innerWidth - 380)) + 'px'; p.style.top = (r.bottom + 4) + 'px'; p.classList.add('on');
  }

  /* ---------- keyboard (spec 1): 1-9 sector · Enter · ↑ ↓ J K · O · W · Space · P · R · Esc step by step ---------- */
  addEventListener('keydown', e => {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    const tag = (e.target.tagName || '').toLowerCase(); if (tag === 'input' || tag === 'textarea' || tag === 'select' || e.target.isContentEditable || document.body.classList.contains('typing')) return;
    const k = e.key, stop = () => { e.preventDefault(); e.stopImmediatePropagation(); };
    if (/^[1-9]$/.test(k)) { const A = cfg.anchors(); const a = A[+k - 1]; if (a) { stop(); openSector(cfg.nameOf(a)); } return; }
    const onAnchor = e.target.closest && cfg.anchors().includes(e.target);
    if (k === 'Enter' && onAnchor) { stop(); openSector(cfg.nameOf(e.target), {toggle: true}); return; }
    if (!st.open) return;
    const rows = $$('.sd-r', node), i = rows.findIndex(r => r.dataset.s === st.sel);
    if (k === 'ArrowDown' || k === 'j' || k === 'J') { if (!rows.length) return; if ((k === 'ArrowDown') && !st.sel && !node.contains(e.target) && !pane.contains(e.target)) return; stop(); select(rows[Math.min(rows.length - 1, i + 1)].dataset.s); return; }
    if (k === 'ArrowUp' || k === 'k' || k === 'K') { if (!rows.length) return; if ((k === 'ArrowUp') && !st.sel && !node.contains(e.target) && !pane.contains(e.target)) return; stop(); select(rows[Math.max(0, i < 0 ? 0 : i - 1)].dataset.s); return; }
    if (k === 'Enter' && st.sel && (node.contains(e.target) || pane.contains(e.target) || e.target === document.body)) { if (e.target.closest('button,a,.chip')) return; stop(); f7(st.sel); return; }
    if (k === 'o' || k === 'O') { stop(); chainAt(); return; }
    if (k === 'w' || k === 'W') { stop(); if (!st.sel) { toast('pick a share first (click a row)'); return; } drawer('w'); return; }
    if (k === ' ' && st.sel) { if (e.target.closest('button,a,.chip') && !e.target.closest('.sd-rail,.sd-pane .sd-b')) return; stop(); drawer('plan'); return; }
    if (k === 'p' || k === 'P') { if (!st.sel) return; stop(); pin(st.sel); return; }
    if (k === 'r' || k === 'R') { stop(); applyRR(); return; }
    if (k === 'Escape') { stop(); escStep(); }
  }, true);
  function escStep() {
    const pop = $('.sd-pop.on'); if (pop) { pop.classList.remove('on'); return; }
    if (st.drw) { drawer(''); return; }
    if (st.sel) { if (PHONE()) { history.back(); return; } select(null); const a = $('.sd-line .sd-x', node); return; }
    if (st.more[st.open]) { st.more[st.open] = 0; render(true); writeHash(); return; }
    if (PHONE()) { history.back(); return; }
    closeSector();
  }

  /* ---------- phone: the list is a full-screen sheet; a tap opens the share sheet; Back returns ---------- */
  let sheet = null, sheet2 = null;
  function sheetMount() {
    if (!sheet) { sheet = document.createElement('div'); sheet.className = 'sd-sheet'; sheet.innerHTML = '<div class="sd-shh"><button class="btn sd-back" data-b="1">‹ Sectors</button><span class="sd-sht"></span></div><div class="sd-dsc"><div class="sd-box"></div><div class="sd-rail" data-for="sheet"></div></div>';
      document.body.appendChild(sheet); $('.sd-back', sheet).addEventListener('click', () => history.back()); }
    $('.sd-sht', sheet).textContent = st.open ? cap(st.open) : '';
    const box = $('.sd-box', sheet); if (node.parentNode !== box) box.appendChild(node); sheet.classList.add('on'); document.body.classList.add('sd-lock');
    railFor(box, $('.sd-rail', sheet));
  }
  function sheetClose() { if (sheet) sheet.classList.remove('on'); shareSheetClose(); document.body.classList.remove('sd-lock'); }
  function shareSheetOpen(push) {
    if (!sheet2) { sheet2 = document.createElement('div'); sheet2.className = 'sd-sheet sd-sheet2'; sheet2.innerHTML = '<div class="sd-shh"><button class="btn sd-back">‹ </button><span class="sd-sht"></span></div><div class="sd-p2"></div>'; document.body.appendChild(sheet2);
      $('.sd-back', sheet2).addEventListener('click', () => history.back()); }
    $('.sd-back', sheet2).textContent = '‹ ' + cap(st.open || ''); $('.sd-sht', sheet2).textContent = st.sel || '';
    const h = $('.sd-p2', sheet2); if (pane.parentNode !== h) h.appendChild(pane); sheet2.classList.add('on');
    if (push) pushSheet(2);
  }
  function shareSheetClose() { if (sheet2) sheet2.classList.remove('on'); }
  function pushSheet(n) { try { if (history.state && history.state.sd === n) return; history.pushState({sd: n}, '', location.pathname + location.search + location.hash); } catch (e) {} }
  addEventListener('popstate', e => {
    if (!PHONE()) { const m = /[#&]sd=/.test(location.hash); if (!m && st.open) closeSector(); return; }
    /* D1: Back follows the history entry, not what happens to be on screen: level 2 = share sheet, 1 = list sheet, none = the page */
    const lv = e.state && e.state.sd ? e.state.sd : 0;
    if (lv >= 2) return;
    if (sheet2 && sheet2.classList.contains('on')) { st.sel = null; shareSheetClose(); $$('.sd-r.on', node).forEach(r => r.classList.remove('on')); document.body.classList.remove('sd-sel'); writeHash(); }
    if (lv === 0 && st.open) closeSector();
  });

  /* ---------- live: numbers tick in place; the order is held under the pointer / focus (re-ranked chip, R, pointer leave, 30 s) ---------- */
  let lt = 0, tmr = 0;
  const soon = () => { const d = Date.now() - lt; if (d >= 1000) { lt = Date.now(); render(); } else if (!tmr) tmr = setTimeout(() => { tmr = 0; lt = Date.now(); render(); }, 1000 - d); };
  S.subscribe('*', ch => { if (st.open && ch.some(k => /^(sec\.board|sec\.rot|sh\.|oc\.|fut\.|ban\.|pos\.|calls\.|mkt\.status|news\.list|strip\.expiry)/.test(k))) soon(); });
  setInterval(() => { if (st.open) { $$('.sd-r', node).forEach(r => { const m = st.sec && st.sec.members.find(x => x.s === r.dataset.s); const c = $('.c-ag', r); if (m && c) { const t = ageTxt(Object.assign({}, m, {age: m.f && (m.f.src_ts || m.f.seen) ? nowS() - (m.f.src_ts || m.f.seen) : null})); if (c.textContent !== t) c.textContent = t; } }); } pageRails(); }, 1000);
  addEventListener('resize', () => { if (!st.open) return; if (PHONE()) sheetMount(); else { sheetClose(); if (sheet && node.parentNode === $('.sd-box', sheet)) node.remove(); mount(); } render(true); });
  document.addEventListener('gir-esc', () => {});

  window.GIR.SD = {openSector, close: closeSector, select, model, plan, contract, RULES, state: st, gates, score};
  const boot = () => { markAnchors(); pageRails(); readHash(); };
  if (S.ready && S.ready()) boot(); else { let done = 0; const un = S.subscribe('*', () => { if (done) return; done = 1; setTimeout(() => { boot(); un && un(); }, 50); }); setTimeout(() => { if (!done) { done = 1; boot(); } }, 3000); }
})();

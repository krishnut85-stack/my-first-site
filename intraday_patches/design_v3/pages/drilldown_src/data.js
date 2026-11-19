// GIR · sector drill-down · ONE data + maths module shared by the laptop page and the phone page (inlined at build).
// Illustrative day: Thu 19 Nov 2026 11:05:00 (design mockup - illustrative values). December expiry Tue 29 Dec 15:30.
// Round 2: groups, gates, LEADER, LAGGARD, EXTENDED, lots and blocks are COMPUTED here by the rules of SECTOR_DRILLDOWN.md 3 / 5
// (no hand-typed group or gate), so the list, the gate cell, the pane and the phone can never disagree.
var GD = (function () {
  'use strict';
  var CLOCK = '11:05:00', HRS_LEFT = 4 + 5 / 60;            // to 15:10
  var T = (40 + (15.5 - (11 + 5 / 60)) / 24) / 365;          // 19 Nov 11:05 -> 29 Dec 15:30, years
  var R1 = 5000, LOCK = 10000, NIFTY = 0.72;
  // mock states (design review only): live (default) · forming (09:24) · manage (14:40) · locked · held · preopen
  var MODE = { k: 'live' };
  var MODES = { live: { clock: '11:05:00', left: '4h 05m' }, forming: { clock: '09:24:00', left: '5h 46m' }, manage: { clock: '14:40:00', left: '0h 30m' },
    locked: { clock: '11:05:00', left: '4h 05m' }, held: { clock: '11:05:00', left: '4h 05m' }, preopen: { clock: '08:52:10', left: '-' } };
  function erf(x) { var s = x < 0 ? -1 : 1; x = Math.abs(x); var t = 1 / (1 + 0.3275911 * x);
    var y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-x * x); return s * y; }
  function N(x) { return 0.5 * (1 + erf(x / Math.SQRT2)); }
  function bs(S, K, t, v, cp) { var sd = v * Math.sqrt(t), d1 = (Math.log(S / K) + 0.5 * v * v * t) / sd, d2 = d1 - sd;
    var c = S * N(d1) - K * N(d2); return cp === 'CE' ? c : c - S + K; }
  function delta(S, K, t, v, cp) { var sd = v * Math.sqrt(t), d1 = (Math.log(S / K) + 0.5 * v * v * t) / sd; return cp === 'CE' ? N(d1) : N(d1) - 1; }
  function r05(x) { return Math.round(x * 20) / 20; }
  function r10(x) { return Math.round(x / 10) * 10; }
  function fmt(x, d) { if (d === undefined) d = 2; var s = Math.abs(x).toFixed(d).split('.'), i = s[0], o = '';
    if (i.length > 3) { var last = i.slice(-3), rest = i.slice(0, -3); rest = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ','); i = rest + ',' + last; }
    o = i + (s[1] ? '.' + s[1] : ''); return (x < 0 ? '−' : '') + o; }
  function sg(x, d) { return (x > 0 ? '+' : '') + fmt(x, d); }
  function rs(x) { return '₹' + fmt(x, 0); }
  function tickOf(S) { return S < 100 ? 0.05 : S < 500 ? 0.1 : 0.5; }
  function lv(x) { return fmt(x, x < 200 ? 2 : 1); }

  // ---------------- sectors ----------------
  // R49 / spec 2: the MOVE = the NSE sectoral index where one exists, else a free-float basket of ALL listed shares. Breadth and
  // weights are always over all listed shares. ff = free-float mcap of all listed shares, Rs lakh crore (for the Rs cr flow).
  // why: drv = a LIVE driver with its live move (today's session only) · story = today's story with source and age · bg = background
  // (earlier sessions, labelled with the date; never in the live slot). No drv and no story = UNEXPLAINED.
  var SECTORS = [
    { id: 'Banks', basis: 'NIFTY BANK', idx: 'NIFTY BANK', bpct: 1.06, rs30: 0.72, today: 2, pct: 1.12, up: 31, dn: 10, n: 41, ff: 42, cr: 5860, bu: 'LB', st: 'ROT CONFIRMED', stAge: '22m', conf: '10:20',
      run: { since: '10:05', len: '1h 00m', typ: '1h 40m', nn: 28, br: '27→31', fade: false },
      why: { drv: '', live: 'BANKNIFTY fut LB · OI +6.2% since 10:05', story: '', src: '', sage: '', bg: ['FII cash +₹1,486 cr (18 Nov prov)', 'Goldman: India banks to OW (CNBC-TV18, 18 Nov 12:44 · 22h)'] },
      nonfo: { n: 27, up: 19, dn: 8, wt: 8.6, ex: [['J&KBANK', 2.14], ['KARURVYSYA', 1.86], ['CUB', 1.62], ['DCBBANK', 1.40], ['SOUTHBANK', 0.92], ['UJJIVANSFB', -0.41], ['EQUITASBNK', -0.63], ['CENTRALBK', 1.12]] } },
    { id: 'NBFC & finance', basis: 'all 92 listed · ff-wtd', rs30: 0.41, today: 4, pct: 0.64, up: 58, dn: 34, n: 92, ff: 16, cr: 1280, bu: 'LB', st: 'IN', stAge: '14m', conf: '10:51',
      run: { since: '10:40', len: '25m', typ: '1h 10m', nn: 19, br: '52→58', fade: false },
      why: { drv: '', live: '', story: '', src: '', sage: '', note: 'moves with Banks - no driver of its own found' },
      nonfo: { n: 87, up: 54, dn: 33, wt: 31.0, ex: [['CREDITACC', 1.2], ['IIFL', 0.9], ['FIVESTAR', 0.6]] } },
    { id: 'Realty', basis: 'NIFTY REALTY', idx: 'NIFTY REALTY', rs30: 0.38, today: 1, pct: 1.38, up: 29, dn: 11, n: 40, ff: 2.6, cr: 940, bu: 'LB', st: 'NOT THIS ROT', stAge: '', conf: '10:31',
      run: { since: '09:50', len: '1h 15m', typ: '55m', nn: 22, br: '33→29', fade: true },
      why: null, nonfo: { n: 34, up: 23, dn: 11, wt: 18.0, ex: [['SOBHA', 1.9], ['BRIGADE', 1.4]] } },
    { id: 'Metals', basis: 'NIFTY METAL', idx: 'NIFTY METAL', rs30: 0.22, today: 3, pct: 0.84, up: 30, dn: 12, n: 42, ff: 8, cr: 610, bu: 'SC', st: 'SHORTS LEAVE', stAge: '', conf: '',
      run: { since: '10:25', len: '40m', typ: '1h 05m', nn: 31, br: '26→30', fade: false },
      why: { drv: 'LME copper', live: '+1.2% (live)', story: 'China stimulus talk', src: 'Reuters 09:20', sage: '1h 45m' },
      nonfo: { n: 35, up: 25, dn: 10, wt: 14.0, ex: [['JINDALSTEL', 1.1], ['WELCORP', 0.7]] } },
    { id: 'Auto', basis: 'NIFTY AUTO', idx: 'NIFTY AUTO', rs30: 0.04, today: 5, pct: 0.21, up: 24, dn: 22, n: 46, ff: 14, cr: 120, bu: 'LB', st: '', stAge: '', conf: '',
      run: null, why: null, nonfo: { n: 41, up: 21, dn: 20, wt: 22.0, ex: [] } },
    { id: 'Cement', basis: 'all 24 listed · ff-wtd', rs30: -0.02, today: 6, pct: 0.12, up: 13, dn: 11, n: 24, ff: 5, cr: -40, bu: '', st: '', stAge: '', conf: '',
      run: null, why: null, nonfo: { n: 21, up: 12, dn: 9, wt: 19.0, ex: [] } },
    { id: 'Power', basis: 'all 31 listed · ff-wtd', rs30: -0.08, today: 7, pct: 0.05, up: 16, dn: 15, n: 31, ff: 10, cr: -160, bu: '', st: '', stAge: '', conf: '',
      run: null, why: null, nonfo: { n: 28, up: 15, dn: 13, wt: 24.0, ex: [] } },
    { id: 'Oil & gas', basis: 'NIFTY OIL & GAS', idx: 'NIFTY OIL & GAS', rs30: -0.11, today: 8, pct: -0.18, up: 6, dn: 9, n: 15, ff: 20, cr: -290, bu: 'LU', st: '', stAge: '', conf: '',
      run: null, why: { drv: 'Brent', live: '+0.42% (live)', story: '', src: '', sage: '' }, nonfo: { n: 11, up: 5, dn: 6, wt: 9.0, ex: [] } },
    { id: 'Pharma', basis: 'NIFTY PHARMA', idx: 'NIFTY PHARMA', rs30: -0.18, today: 9, pct: -0.62, up: 30, dn: 58, n: 88, ff: 12, cr: -310, bu: 'LU', st: '', stAge: '', conf: '',
      run: { since: '10:15', len: '50m', typ: '1h 20m', nn: 17, br: '50→58', fade: false },
      why: { drv: '', live: '', story: 'US FDA warning letter to a peer plant', src: 'ET 09:31', sage: '1h 34m' }, nonfo: { n: 83, up: 29, dn: 54, wt: 34.0, ex: [] } },
    { id: 'FMCG', basis: 'NIFTY FMCG', idx: 'NIFTY FMCG', rs30: -0.36, today: 10, pct: -0.71, up: 21, dn: 39, n: 60, ff: 17, cr: -2380, bu: 'SB', st: 'OUT', stAge: '22m', conf: '10:20',
      run: { since: '10:05', len: '1h 00m', typ: '1h 30m', nn: 24, br: '34→39', fade: false },
      why: { drv: '', live: '', story: 'Nomura: rural demand slowing', src: 'Nomura note 08:50', sage: '2h 15m' }, nonfo: { n: 55, up: 20, dn: 35, wt: 21.0, ex: [] } },
    { id: 'IT', basis: 'NIFTY IT', idx: 'NIFTY IT', rs30: -0.58, today: 11, pct: -1.04, up: 22, dn: 52, n: 74, ff: 25, cr: -4120, bu: 'SB', st: 'OUT', stAge: '22m', conf: '10:20',
      run: { since: '09:40', len: '1h 25m', typ: '2h 05m', nn: 33, br: '47→52', fade: false },
      why: { drv: 'USD/INR', live: '−0.12% (live, rupee firmer)', story: 'Accenture cuts FY guidance', src: 'Reuters 18 Nov 21:10', sage: '13h 55m' }, nonfo: { n: 68, up: 20, dn: 48, wt: 16.0, ex: [] } }
  ];

  // ---------------- F&O members (the facts; group, role LEADER / LAGGARD, gates and lots are derived below) ----------------
  // vb = closed 5-min bars on the sector's side of VWAP (0-2) · oage = option quote age (s) · own = own-story note (against / bad news)
  var M = {};
  M['Banks'] = [
    { sym: 'ICICIBANK', role: 'FOLLOWER', prev: 1444.50, ltp: 1462.40, vwap: 1456.2, orL: 1450.0, orH: 1458.0, lo: 1450.0, hi: 1463.0, atr: 25, rs30: 0.92, rs15: 0.74, s0: 0.876, sl: '↗', rvol: 2.1, rvUp: 1, side: 'both', vb: 2, bu: 'LB', oi: 4.1, buN: 3.2, buD: 7.9, wt: 20.5, lot: 700, iv: 0.234, iv20: 0.218, step: 10, spr: 5, sprI: 6, dep: 18, depI: 9, ai: 'GET READY', aiT: '11:04', age: '0.3s', oage: 0.6, wallC: 1500, wallP: 1440, mwpl: 18, res: 'results ~24 Jan · no IV-crush risk now', exd: 'no ex-date',
      news: [['09:52', 'ET', 'ICICI Bank: deposits beat system growth, 3rd month', '1h 13m']],
      aiv: 'GET READY 11:04 · 1,460 CE Dec · 4 of 5 agree' },
    { sym: 'AXISBANK', role: 'FOLLOWER', prev: 1226.80, ltp: 1248.30, vwap: 1240.1, orL: 1232.0, orH: 1239.0, lo: 1232.0, hi: 1249.0, atr: 24, rs30: 0.81, rs15: 0.88, s0: 0.850, sl: '↗', rvol: 2.6, rvUp: 1, side: 'both', vb: 2, bu: 'LB', oi: 6.3, buN: 4.0, buD: 11.6, wt: 7.9, lot: 625, iv: 0.245, iv20: 0.229, step: 10, spr: 5, sprI: 6, dep: 14, depI: 7, ai: '', age: '0.4s', oage: 0.8, wallC: 1300, wallP: 1200, mwpl: 22, res: 'results ~22 Jan', exd: 'no ex-date',
      news: [['10:31', 'Moneycontrol', 'Axis Bank: card spends up 18% YoY in October', '34m']] },
    { sym: 'BANKBARODA', role: 'FOLLOWER', prev: 268.40, ltp: 274.65, vwap: 272.6, orL: 270.2, orH: 272.4, lo: 270.2, hi: 274.9, atr: 6.6, rs30: 0.74, rs15: 0.91, sl: '↗', rvol: 3.0, rvUp: 1, side: 'both', vb: 2, bu: 'LB', oi: 8.8, buN: 6.1, buD: 14.2, wt: 2.4, lot: 2925, iv: 0.29, iv20: 0.27, step: 2.5, spr: 2, sprI: 2, dep: 22, depI: 11, ai: '', age: '0.5s', oage: 0.9, neu: '11:01', wallC: 280, wallP: 270, mwpl: 31, res: 'results ~30 Jan', exd: 'no ex-date',
      news: [['10:12', 'BS', 'PSU banks: Q3 credit growth seen at 13%', '53m']] },
    { sym: 'SBIN', role: 'FOLLOWER', prev: 958.20, ltp: 987.80, vwap: 974.6, orL: 958.0, orH: 966.5, lo: 958.0, hi: 989.4, atr: 18.5, rs30: 0.64, rs15: 0.12, sl: '→', rvol: 3.4, rvUp: 1, side: 'both', vb: 2, bu: 'LB', oi: 11.2, buN: 8.4, buD: 17.0, wt: 10.8, lot: 750, iv: 0.26, iv20: 0.24, step: 5, spr: 4, sprI: 4, dep: 25, depI: 14, ai: '', age: '0.3s', oage: 0.5, wallC: 1000, wallP: 960, mwpl: 27, res: 'results ~6 Feb', exd: 'no ex-date',
      news: [['09:47', 'CNBC-TV18', 'SBI at record high; m-cap crosses ₹9 lakh cr', '1h 18m']] },
    { sym: 'HDFCBANK', role: 'FOLLOWER', prev: 1011.40, ltp: 1012.05, vwap: 1011.6, orL: 1006.2, orH: 1015.5, lo: 1006.2, hi: 1015.5, atr: 17, rs30: -0.42, rs15: 0.18, sl: '↗', rvol: 0.9, rvUp: 1, side: 'reclaim', vb: 1, bu: '', oi: 0.4, buN: 0.2, buD: 0.9, wt: 31.0, lot: 550, iv: 0.20, iv20: 0.195, step: 10, spr: 3, sprI: 4, dep: 30, depI: 16, ai: '', age: '0.3s', oage: 0.7, wallC: 1040, wallP: 1000, mwpl: 12, res: 'results ~17 Jan', exd: 'no ex-date', news: [] },
    { sym: 'KOTAKBANK', role: 'FOLLOWER', prev: 2086.00, ltp: 2108.90, vwap: 2101.4, orL: 2088.0, orH: 2099.0, lo: 2088.0, hi: 2112.0, atr: 38, rs30: 0.21, rs15: 0.30, sl: '→', rvol: 1.2, rvUp: 1, side: 'both', vb: 2, bu: 'LB', oi: 2.2, buN: 1.4, buD: 4.6, wt: 8.2, lot: 400, iv: 0.21, iv20: 0.205, step: 20, spr: 6, sprI: 8, dep: 9, depI: 5, ai: '', age: '0.4s', oage: 1.1, wallC: 2200, wallP: 2060, mwpl: 15, res: 'results ~24 Jan', exd: 'no ex-date', news: [] },
    { sym: 'CANBK', role: 'FOLLOWER', prev: 118.62, ltp: 120.86, vwap: 120.70, orL: 118.9, orH: 120.1, lo: 118.9, hi: 121.2, atr: 3.2, rs30: 0.58, rs15: 0.40, sl: '↗', rvol: 2.0, rvUp: 1, side: 'reclaim', vb: 1, bu: 'LB', oi: 5.0, buN: 3.1, buD: 9.4, wt: 1.7, lot: 6750, iv: 0.30, iv20: 0.28, step: 1, spr: 1, sprI: 1, dep: 12, depI: 6, ai: '', age: '0.6s', oage: 1.0, wallC: 125, wallP: 118, mwpl: 41, res: 'results ~29 Jan', exd: 'no ex-date', news: [] },
    { sym: 'PNB', role: 'FOLLOWER', prev: 112.40, ltp: 113.98, vwap: 113.40, orL: 112.6, orH: 113.5, lo: 112.6, hi: 114.2, atr: 2.9, rs30: 0.33, rs15: 0.20, sl: '→', rvol: 1.6, rvUp: 1, side: 'both', vb: 2, bu: 'LB', oi: 3.1, buN: 2.0, buD: 5.8, wt: 1.9, lot: 8000, iv: 0.31, iv20: 0.29, step: 1, spr: 1, sprI: 1, dep: 10, depI: 5, ai: '', age: '0.5s', oage: 1.2, wallC: 120, wallP: 110, mwpl: 91, res: 'results ~28 Jan', exd: 'ex-date 21 Nov (dividend ₹1.50)', news: [] },
    { sym: 'AUBANK', role: 'FOLLOWER', prev: 742.30, ltp: 751.20, vwap: 748.0, orL: 741.0, orH: 747.5, lo: 741.0, hi: 753.0, atr: 19, rs30: 0.12, rs15: 0.10, sl: '→', rvol: 1.3, rvUp: 0, side: 'vwap', vb: 2, bu: 'SC', oi: -2.4, buN: -3.0, buD: -1.1, wt: 1.1, lot: 1000, iv: 0.27, iv20: 0.26, step: 10, spr: 6, sprI: 7, dep: 6, depI: 3, stale: 12, ai: '', age: '12s', oage: 14, wallC: 780, wallP: 740, mwpl: 24, res: 'results ~21 Jan', exd: 'no ex-date', news: [] },
    { sym: 'FEDERALBNK', role: 'FOLLOWER', prev: 228.10, ltp: 230.85, vwap: 229.9, orL: 228.0, orH: 229.6, lo: 228.0, hi: 231.4, atr: 5.2, rs30: 0.15, rs15: 0.08, sl: '→', rvol: 1.1, rvUp: 0, side: 'both', vb: 2, bu: 'LB', oi: 1.8, buN: 1.0, buD: 3.9, wt: 1.2, lot: 5000, iv: 0.27, iv20: 0.26, step: 2.5, spr: 2, sprI: 2, dep: 8, depI: 4, ai: '', age: '0.7s', oage: 1.4, wallC: 240, wallP: 225, mwpl: 19, res: 'RESULTS 20 Nov 15:45 · IV crush', resT: '20 Nov 15:45', exd: 'no ex-date', news: [] },
    { sym: 'IDFCFIRSTB', role: 'FOLLOWER', prev: 78.40, ltp: 78.95, vwap: 78.90, orL: 78.2, orH: 78.8, lo: 78.2, hi: 79.3, atr: 2.1, rs30: 0.05, rs15: -0.10, sl: '↘', rvol: 1.4, rvUp: 0, side: 'vwap', vb: 2, bu: 'LB', oi: 1.2, buN: 0.8, buD: 2.4, wt: 1.3, lot: 9275, iv: 0.30, iv20: 0.29, step: 1, spr: 1, sprI: 1, dep: 7, depI: 4, ai: '', age: '0.5s', oage: 1.3, wallC: 80, wallP: 75, mwpl: 86, res: 'results ~24 Jan', exd: 'no ex-date', news: [] },
    { sym: 'YESBANK', role: 'FOLLOWER', prev: 22.10, ltp: 22.21, vwap: 22.16, orL: 22.0, orH: 22.25, lo: 22.0, hi: 22.3, atr: 0.55, rs30: -0.12, rs15: 0.02, sl: '→', rvol: 0.8, rvUp: 0, side: 'or', vb: 2, bu: '', oi: 0.3, buN: 0.1, buD: 0.6, wt: 0.9, lot: 31100, iv: 0.32, iv20: 0.31, step: 1, spr: 1, sprI: 1, dep: 40, depI: 20, ai: '', age: '0.8s', oage: 2.1, wallC: 25, wallP: 20, mwpl: 29, res: 'results ~22 Jan', exd: 'no ex-date', news: [] },
    { sym: 'BANDHANBNK', role: 'DEPENDENT', prev: 172.30, ltp: 170.32, vwap: 171.4, orL: 170.1, orH: 172.9, lo: 169.9, hi: 173.2, atr: 4.6, rs30: -1.10, rs15: -0.80, sl: '↘', rvol: 1.9, rvUp: 1, side: 'below', vb: 0, bu: 'SB', oi: 6.4, buN: 5.0, buD: 9.8, wt: 0.6, lot: 3600, iv: 0.33, iv20: 0.31, step: 2.5, spr: 2, sprI: 2, dep: 9, depI: 5, ai: '', age: '0.4s', oage: 0.9, own: 'own news 09:40', wallC: 180, wallP: 165, mwpl: 48, res: 'results ~30 Jan', exd: 'no ex-date',
      news: [['09:40', 'ET', 'Bandhan: MFI collection efficiency slips in Assam', '1h 25m']] },
    { sym: 'INDUSINDBK', role: 'FOLLOWER', prev: 802.40, ltp: 799.05, vwap: 800.2, orL: 797.0, orH: 803.5, lo: 796.1, hi: 804.0, atr: 22, rs30: -0.60, rs15: -0.20, sl: '→', rvol: 1.0, rvUp: 0, side: 'below', vb: 0, bu: 'SB', oi: 1.1, buN: 0.6, buD: 2.2, wt: 1.9, lot: 700, iv: 0.36, iv20: 0.33, step: 10, spr: 8, sprI: 9, dep: 4, depI: 2, ban: 1, ai: '', age: '0.4s', oage: 1.0, wallC: 840, wallP: 780, mwpl: 96, res: 'results ~26 Jan', exd: 'no ex-date', news: [] }
  ];
  // compact members for the other sectors: [sym, -, role, prev, pct, rvol, rs30, bu, oi, wt, lot, step, iv, note, extra]
  var C = {
    'NBFC & finance': [['BAJFINANCE', '', 'FOLLOWER', 1018.40, 1.62, 2.4, 0.71, 'LB', 5.2, 22.0, 750, 10, 0.27, '', { neu: '10:56' }], ['SHRIRAMFIN', '', 'FOLLOWER', 712.30, 2.85, 3.1, 0.66, 'LB', 9.1, 8.0, 825, 10, 0.31, ''], ['CHOLAFIN', '', 'FOLLOWER', 1612.00, 0.08, 0.9, -0.31, '', 0.3, 7.0, 625, 20, 0.28, ''], ['MUTHOOTFIN', '', 'DEPENDENT', 3240.0, 0.71, 1.1, 0.18, 'LB', 1.4, 3.0, 275, 50, 0.29, ''], ['LICHSGFIN', '', 'DEPENDENT', 584.20, -0.92, 1.7, -0.95, 'SB', 4.4, 2.0, 1000, 5, 0.30, '']],
    'Realty': [['DLF', '', 'FOLLOWER', 742.50, 2.10, 2.8, 0.82, 'LB', 6.6, 24.0, 825, 10, 0.32, '', { neu: '10:52' }], ['LODHA', '', 'FOLLOWER', 1185.0, 1.75, 2.2, 0.68, 'LB', 4.9, 14.0, 450, 10, 0.34, '', { oage: 11 }], ['GODREJPROP', '', 'FOLLOWER', 2210.0, 3.20, 3.3, 0.52, 'LB', 8.0, 11.0, 275, 20, 0.36, ''], ['OBEROIRLTY', '', 'FOLLOWER', 1712.0, 0.10, 0.8, -0.38, '', 0.2, 8.0, 350, 20, 0.30, ''], ['PRESTIGE', '', 'FOLLOWER', 1598.0, 0.92, 1.3, 0.21, 'LB', 1.9, 6.0, 450, 20, 0.35, ''], ['PHOENIXLTD', '', 'FOLLOWER', 1702.0, 0.85, 1.6, 0.14, 'SC', -1.2, 8.0, 350, 20, 0.31, '']],
    'Metals': [['TATASTEEL', '', 'FOLLOWER', 172.40, 1.50, 2.0, 0.64, 'LB', 3.9, 18.0, 5500, 2.5, 0.29, ''], ['HINDALCO', '', 'FOLLOWER', 812.0, 1.90, 2.6, 0.55, 'SC', -1.9, 14.0, 1400, 10, 0.27, ''], ['JSWSTEEL', '', 'FOLLOWER', 1152.0, 0.60, 1.2, 0.12, 'LB', 1.1, 13.0, 675, 10, 0.26, ''], ['VEDL', '', 'FOLLOWER', 488.0, 0.05, 0.9, -0.30, '', 0.4, 10.0, 1150, 5, 0.31, ''], ['SAIL', '', 'DEPENDENT', 132.50, 0.90, 1.4, 0.20, 'LB', 2.0, 4.0, 4700, 1, 0.33, ''], ['NMDC', '', 'DEPENDENT', 74.20, -0.60, 1.5, -0.88, 'SB', 2.8, 4.0, 6750, 1, 0.32, 'own: ore price cut'], ['HINDCOPPER', '', 'DEPENDENT', 312.0, 0.40, 1.2, -0.20, 'SB', 0.9, 2.0, 2650, 2.5, 0.38, '', { ban: 1, mwpl: 97 }]],
    'Auto': [['BAJAJ-AUTO', '', 'FOLLOWER', 9110.0, 1.10, 1.4, 0.40, 'LB', 2.4, 12.0, 75, 100, 0.24, ''], ['M&M', '', 'FOLLOWER', 3612.0, 0.60, 1.1, 0.10, 'LB', 1.0, 20.0, 200, 20, 0.25, ''], ['EICHERMOT', '', 'FOLLOWER', 7050.0, 0.40, 1.0, 0.02, '', 0.3, 8.0, 175, 50, 0.24, ''], ['MARUTI', '', 'FOLLOWER', 16240.0, 0.02, 0.8, -0.20, '', 0.1, 18.0, 50, 100, 0.22, ''], ['TMPV', '', 'FOLLOWER', 412.0, -0.80, 1.6, -0.70, 'SB', 3.1, 9.0, 800, 5, 0.30, '']],
    'Cement': [['ULTRACEMCO', '', 'FOLLOWER', 11920.0, 0.30, 1.0, 0.05, '', 0.2, 30.0, 50, 100, 0.22, ''], ['AMBUJACEM', '', 'FOLLOWER', 562.0, -0.10, 0.9, -0.15, '', 0.1, 12.0, 1050, 5, 0.25, ''], ['SHREECEM', '', 'FOLLOWER', 28900.0, -0.50, 1.2, -0.55, 'LU', -0.8, 9.0, 25, 250, 0.23, '']],
    'Power': [['NTPC', '', 'FOLLOWER', 334.0, 0.40, 1.1, 0.08, '', 0.5, 26.0, 1500, 2.5, 0.24, ''], ['POWERGRID', '', 'FOLLOWER', 288.0, -0.05, 0.9, -0.10, '', 0.1, 20.0, 1900, 2.5, 0.23, ''], ['TATAPOWER', '', 'FOLLOWER', 398.0, -0.60, 1.4, -0.52, 'SB', 1.9, 8.0, 1450, 5, 0.29, '']],
    'Oil & gas': [['ONGC', '', 'FOLLOWER', 242.0, -0.90, 1.8, -0.60, 'SB', 3.2, 14.0, 2250, 2.5, 0.27, ''], ['BPCL', '', 'FOLLOWER', 338.0, -1.20, 2.0, -0.55, 'SB', 4.0, 6.0, 1975, 2.5, 0.29, ''], ['IOC', '', 'FOLLOWER', 148.0, -0.30, 1.1, -0.10, '', 0.4, 5.0, 4875, 1, 0.27, ''], ['RELIANCE', '', 'FOLLOWER', 1512.0, 0.05, 0.9, 0.20, '', 0.2, 48.0, 500, 10, 0.20, '']],
    'Pharma': [['SUNPHARMA', '', 'FOLLOWER', 1712.0, -1.10, 2.1, -0.70, 'SB', 3.6, 16.0, 350, 20, 0.24, ''], ['DRREDDY', '', 'FOLLOWER', 1240.0, -1.60, 2.5, -0.81, 'SB', 5.3, 8.0, 625, 10, 0.26, ''], ['CIPLA', '', 'FOLLOWER', 1522.0, -0.40, 1.2, -0.10, 'LU', -0.6, 9.0, 375, 20, 0.23, ''], ['DIVISLAB', '', 'FOLLOWER', 6420.0, 0.10, 0.8, 0.30, '', 0.2, 7.0, 100, 50, 0.25, ''], ['LUPIN', '', 'FOLLOWER', 2060.0, 0.40, 1.3, 0.62, 'LB', 1.8, 6.0, 425, 20, 0.27, 'own: US approval']],
    'FMCG': [['HINDUNILVR', '', 'FOLLOWER', 2412.0, -1.20, 2.0, -0.66, 'SB', 3.0, 22.0, 300, 20, 0.21, ''], ['NESTLEIND', '', 'FOLLOWER', 1182.0, -1.70, 2.2, -0.74, 'SB', 4.1, 9.0, 500, 10, 0.22, ''], ['ITC', '', 'FOLLOWER', 402.0, -0.50, 1.0, -0.12, 'LU', -0.4, 26.0, 1600, 5, 0.19, ''], ['BRITANNIA', '', 'FOLLOWER', 5890.0, 0.00, 0.8, 0.25, '', 0.1, 7.0, 125, 50, 0.21, ''], ['DABUR', '', 'FOLLOWER', 512.0, 0.30, 1.3, 0.55, 'LB', 1.2, 4.0, 1250, 5, 0.22, 'own: price hike']],
    'IT': [['INFY', '', 'FOLLOWER', 1522.0, -1.60, 2.3, -0.72, 'SB', 4.4, 29.0, 400, 20, 0.25, ''], ['HCLTECH', '', 'FOLLOWER', 1612.0, -1.30, 2.0, -0.61, 'SB', 3.7, 12.0, 350, 20, 0.24, ''], ['TCS', '', 'FOLLOWER', 3060.0, -2.30, 2.8, -0.58, 'SB', 6.2, 26.0, 175, 20, 0.24, ''], ['TECHM', '', 'FOLLOWER', 1512.0, -0.10, 0.9, 0.35, '', 0.2, 5.0, 600, 20, 0.26, ''], ['WIPRO', '', 'FOLLOWER', 246.0, -0.70, 1.2, -0.20, 'SB', 1.1, 7.0, 3000, 2.5, 0.25, ''], ['COFORGE', '', 'FOLLOWER', 1820.0, 0.60, 1.5, 0.70, 'LB', 2.2, 3.0, 375, 20, 0.30, 'own: deal win']]
  };
  function expand(c, dir) {
    var o = c[14] || {}, prev = c[3], pct = c[4], ltp = Math.round(prev * (1 + pct / 100) * 100) / 100, atr = +(ltp * 0.021).toFixed(2);
    var up = pct >= 0, open = prev * (1 + 0.4 * pct / 100), lo, hi, vwap, orL, orH;
    if (up) { lo = open * 0.998; hi = ltp * 1.002; vwap = lo + (ltp - lo) * 0.55; orL = lo; orH = lo + (hi - lo) * 0.45; }
    else { hi = open * 1.002; lo = ltp * 0.998; vwap = hi - (hi - ltp) * 0.55; orH = hi; orL = hi - (hi - lo) * 0.45; }
    var side = ltp > vwap ? (ltp > orH ? 'both' : 'vwap') : (ltp < orL ? 'below' : 'bvwap');
    var onSide = dir > 0 ? ltp > vwap : ltp < vwap;
    var m = { sym: c[0], role: c[2], prev: prev, ltp: ltp, lo: +lo.toFixed(2), hi: +hi.toFixed(2), vwap: +vwap.toFixed(2), orL: +orL.toFixed(2), orH: +orH.toFixed(2), atr: atr,
      rvol: c[5], rvUp: c[5] >= 1.5 ? 1 : 0, rs30: c[6], rs15: +(c[6] * 0.8).toFixed(2), sl: Math.abs(c[6]) > 0.4 ? (c[6] > 0 ? '↗' : '↘') : '→', side: side, vb: onSide ? 2 : 0,
      bu: c[7], oi: c[8], buN: +(c[8] * 0.7).toFixed(1), buD: +(c[8] * 1.9).toFixed(1), wt: c[9], lot: c[10], step: c[11], iv: c[12], iv20: +(c[12] - 0.015).toFixed(3),
      spr: 3, sprI: 4, dep: 10, depI: 5, own: /^own/.test(c[13]) ? c[13] : '', ai: '', age: '0.4s', oage: 0.8,
      wallC: Math.ceil(ltp * 1.03 / c[11]) * c[11], wallP: Math.floor(ltp * 0.97 / c[11]) * c[11], mwpl: 20, res: 'results in Jan', exd: 'no ex-date', news: [] };
    for (var k in o) m[k] = o[k];
    return m;
  }
  SECTORS.forEach(function (s) { var dir = s.pct >= 0 ? 1 : -1; s.dir = dir; if (!M[s.id]) M[s.id] = (C[s.id] || []).map(function (c) { return expand(c, dir); }); s.members = M[s.id]; });

  // ---------------- the rules (SECTOR_DRILLDOWN.md 3) ----------------
  var GORDER = ['up', 'lead', 'lag', 'wait', 'against', 'nt'];
  var BU = { LB: 1, SC: 0.5, '': 0, SB: -1, LU: -1 };
  function pctOf(m) { return (m.ltp / m.prev - 1) * 100; }
  function room(m) { var used = (m.hi - m.lo) / m.atr; return { used: used, left: Math.max(0, 1 - used) }; }
  function extOf(m) { return Math.abs(m.ltp - m.vwap) / m.atr; }
  function isExt(m) { return extOf(m) > 1.0 || room(m).used > 0.8; }
  function breadthOneWay(s) { return (s.dir > 0 ? s.up : s.dn) / s.n; }
  function sideScore(s, m) { var t = m.side; if (s.dir > 0) return t === 'both' ? 1 : (t === 'vwap' || t === 'or' || t === 'reclaim') ? 0.5 : 0; return t === 'below' ? 1 : (t === 'bvwap' || t === 'bor') ? 0.5 : 0; }
  function buSigned(s, m) { var b = BU[m.bu || ''] || 0; return s.dir > 0 ? b : (m.bu === 'SB' ? 1 : m.bu === 'LU' ? 0.5 : m.bu === 'LB' || m.bu === 'SC' ? -1 : 0); }
  // Score = 0.30·RS30 + 0.20·RS15 + 0.20·min(RVOL,3)/3 + 0.15·build-up + 0.15·side (in the sector's direction)
  function score(s, m) { var d = s.dir; return 0.30 * d * m.rs30 + 0.20 * d * m.rs15 + 0.20 * Math.min(m.rvol, 3) / 3 + 0.15 * buSigned(s, m) + 0.15 * sideScore(s, m); }
  // the four gates, in the sector's direction; returns the first failing gate (named) or null
  function gates(s, m) { var d = s.dir, out = [];
    if (!(d * m.rs15 > 0)) out.push('RS15 ' + sg(m.rs15, 2)); else if (!(d * m.rs30 >= 0.5)) out.push('RS30 ' + sg(m.rs30, 2));
    if (!(m.rvol >= 1.5)) out.push('RVOL ' + m.rvol.toFixed(1));
    var onSide = d > 0 ? /^(both|vwap)$/.test(m.side) : /^(below|bvwap)$/.test(m.side);
    if (!onSide || m.vb < 2) out.push(onSide || m.side === 'reclaim' ? 'VWAP ' + (m.vb || 1) + '/2 bars' : (d > 0 ? 'below VWAP' : 'above VWAP'));
    if (d > 0 ? (m.bu === 'SB' || m.bu === 'LU') : (m.bu === 'LB' || m.bu === 'SC')) out.push(m.bu + ' build-up');
    return out; }
  // hysteresis: COMING UP switches on at a score of 0.60 and off below 0.45 (wasUp = in COMING UP at the last 30 s re-rank)
  function comingUp(sc, wasUp) { return wasUp ? sc >= 0.45 : sc >= 0.60; }
  function classify(s) {
    var d = s.dir, sp = function (m) { return d * pctOf(m); }, bw = breadthOneWay(s);
    var cand = s.members.filter(function (m) { return !m.ban && sp(m) > 0; }), lead = null;
    cand.forEach(function (m) { if (!lead || sp(m) > sp(lead)) lead = m; });
    s.lagRule = { bw: bw, ok: bw >= 0.70 };
    s.members.forEach(function (m) {
      var g = gates(s, m), ext = isExt(m), sc = score(s, m); m.score = sc; m.ext = ext ? 1 : 0; m.fails = g; m.gok = g.length === 0 ? 1 : 0;
      if (m.role === 'LEADER' || m.role === 'LAGGARD') m.role = 'FOLLOWER';
      if (m === lead) m.role = 'LEADER';
      var flat = Math.abs(pctOf(m)) < 0.25, buAgainst = buSigned(s, m) < 0;
      if (m.ban) m.grp = 'nt';
      else if (sp(m) < 0 && d * m.rs30 <= -0.5) m.grp = 'against';
      else if (m === lead) m.grp = (m.gok && !ext && comingUp(sc, m.wasUp)) ? 'up' : 'lead';
      else if (m.gok && !ext && comingUp(sc, m.wasUp)) m.grp = 'up';
      else if (flat && bw >= 0.70 && !m.own && !buAgainst) { m.grp = 'lag'; m.role = 'LAGGARD'; }
      else m.grp = 'wait';
      if (m.gok && !ext && m.grp === 'wait' && !comingUp(sc, m.wasUp)) m.fails = ['score ' + sc.toFixed(2) + ' < 0.60'];
    });
  }
  SECTORS.forEach(classify);

  // ---------------- per-member maths (all numbers derive from here, so the pane, F7 and the phone agree) ----------------
  function optSide(s, m) { var ce = s.dir > 0; if (m.grp === 'against') ce = !ce; return ce ? 'CE' : 'PE'; }
  function strikes(m, cp) { var atm = Math.round(m.ltp / m.step) * m.step; var itm = cp === 'CE' ? atm - m.step : atm + m.step; return [atm, itm]; }
  function quote(m, K, cp, ticks, S) { S = S || m.ltp; var mid = bs(S, K, T, m.iv, cp), sp = ticks * 0.05; var bid = r05(mid - sp / 2); if (bid < 0.05) bid = 0.05; return { mid: mid, bid: bid, ask: +(bid + sp).toFixed(2), sp: sp }; }
  function thetaDay(m, K, cp) { return bs(m.ltp, K, T, m.iv, cp) - bs(m.ltp, K, T - 1 / 365, m.iv, cp); }
  function contract(s, m, which) {
    var cp = optSide(s, m), ks = strikes(m, cp), K = which === 'itm' ? ks[1] : ks[0], ticks = which === 'itm' ? m.sprI : m.spr;
    var q = quote(m, K, cp, ticks), d = delta(m.ltp, K, T, m.iv, cp), th = thetaDay(m, K, cp), thh = th / 6.25;
    var lotCost = q.ask * m.lot, sprLot = q.sp * m.lot, sprPct = q.sp / ((q.bid + q.ask) / 2) * 100;
    var bePts = (thh * HRS_LEFT + q.sp) / Math.abs(d), be = cp === 'CE' ? m.ltp + bePts : m.ltp - bePts;
    var ivK = m.iv - (which === 'itm' ? 0.003 : 0), oage = which === 'itm' ? +(m.oage * 1.3).toFixed(1) : m.oage;
    return { cp: cp, K: K, bid: q.bid, ask: q.ask, mid: q.mid, sp: q.sp, sprLot: sprLot, sprPct: sprPct, dep: which === 'itm' ? m.depI : m.dep, d: d, thh: thh * m.lot, iv: ivK, iv20: m.iv20, lotCost: lotCost, be: be, bePts: bePts, oage: oage, ostale: oage >= 5 };
  }
  function kTxt(K) { return fmt(K, K % 1 ? 1 : 0); }
  // hard blocks first (ban, loss lock, stale share or option quote), then the time rules, then the sizing rules
  function plan(s, m) {
    var cp = optSide(s, m), ce = cp === 'CE', tk = tickOf(m.ltp), trig, stop, tgt, how, rising = ce;
    function rd(x) { return +(Math.round(x / tk) * tk).toFixed(2); }
    var dg = tk < 0.1 ? 2 : 1;
    if (m.grp === 'lead' && m.ext) { trig = rd(m.vwap); stop = rd(rising ? m.vwap - 0.35 * m.atr : m.vwap + 0.35 * m.atr); tgt = rising ? m.hi : m.lo;
      how = 'EXTENDED - don\'t chase: enter on the ' + (rising ? 'pullback to VWAP ' + fmt(trig, dg) + ' / first higher low' : 'bounce to VWAP ' + fmt(trig, dg) + ' / first lower high') + ', 1 lot (minimum)'; }
    else if (m.ext) { trig = rd(m.vwap); stop = rd(rising ? m.vwap - 0.35 * m.atr : m.vwap + 0.35 * m.atr); tgt = rising ? m.hi : m.lo;
      how = 'EXTENDED - don\'t chase: wait for the ' + (rising ? 'pullback to VWAP ' : 'bounce to VWAP ') + fmt(trig, dg) + ', 1 lot (minimum)'; }
    else if (m.grp === 'lag') { trig = rising ? rd(m.orH + tk) : rd(m.orL - tk); stop = rd(rising ? m.vwap - 0.25 * m.atr : m.vwap + 0.25 * m.atr); tgt = rd(rising ? trig + 0.6 * m.atr : trig - 0.6 * m.atr); how = '5-min close ' + (rising ? '>' : '<') + ' ' + fmt(trig, dg) + ' (its OR ' + (rising ? 'high' : 'low') + ')'; }
    else if (rising) { trig = rd(m.hi + tk); stop = rd(Math.floor((m.vwap - 0.1) / tk) * tk); var t0 = Math.min(m.lo + m.atr, m.wallC * 0.995); if (t0 - trig < 0.45 * m.atr) t0 = Math.min(trig + 0.45 * m.atr, m.wallC * 0.995); tgt = rd(t0); how = '5-min close > ' + fmt(trig, dg) + ' (day high)'; }
    else { trig = rd(m.lo - tk); stop = rd(Math.ceil((m.vwap + 0.1) / tk) * tk); var t1 = Math.max(m.hi - m.atr, m.wallP * 1.005); if (trig - t1 < 0.45 * m.atr) t1 = Math.max(trig - 0.45 * m.atr, m.wallP * 1.005); tgt = rd(t1); how = '5-min close < ' + fmt(trig, dg) + ' (day low)'; }
    var c = contract(s, m, 'atm'), K = c.K, hs = c.sp / 2;
    var pT = r05(bs(trig, K, T, m.iv, cp) + hs), pS = r05(bs(stop, K, T, m.iv, cp) - hs), pG = r05(bs(tgt, K, T, m.iv, cp) - hs);
    var charges = r10(40 + 0.0021 * c.lotCost), slip = r10(hs * m.lot), costs = charges + slip;
    var risk = Math.round((pT - pS) * m.lot + costs), reward = Math.round((pG - pT) * m.lot - costs), rr = reward / risk;
    var fitLock = Math.floor(LOCK / risk), fitR = Math.floor(R1 / risk), lots = 0, why = '', block = '', warn = '';
    var mode = MODE.k;
    if (m.ban) { block = 'BAN - only close existing'; why = 'F&O ban · MWPL ' + m.mwpl + '% (ban at 95%)'; }
    else if (mode === 'locked') { block = 'LOCKED - no new trades today'; why = 'loss lock hit'; }
    else if (m.stale) { block = 'STALE ' + m.stale + 's'; why = 'share quote ' + m.stale + 's old - no GO NOW until it ticks'; }
    else if (c.ostale) { block = 'OPTION STALE ' + c.oage + 's'; why = 'option bid/ask ' + c.oage + 's old - no GO NOW until it ticks'; }
    else if (mode === 'preopen') { block = 'pre-open - not live'; why = 'levels from the 18 Nov close'; }
    else if (mode === 'forming') { block = 'forming - before 09:30'; why = 'groups settle on closed bars at 09:30'; }
    else if (mode === 'manage') { block = 'manage only - no new entries'; why = 'after 14:30'; }
    else if (m.grp === 'wait' || (m.grp === 'lead' && !m.gok)) { warn = 'waiting - ' + (m.fails[0] || 'a gate') + ' fails'; why = 'not a trade until every gate passes'; }
    else if (fitLock < 1) { block = 'lock room'; why = 'lock room ₹' + fmt(LOCK, 0) + ' < max loss ₹' + fmt(risk, 0); }
    else if (rr < 1) { warn = 'R:R ' + rr.toFixed(2) + ' after costs - not worth it'; why = warn; }
    else if (risk > R1) { warn = '1 lot = ' + (risk / R1).toFixed(2) + 'R > 1R'; why = warn; }
    var lotsTxt;
    if (block || warn) { lots = 0; lotsTxt = '0 lots · ' + (block || warn); }
    else if (m.ext) { lots = 1; lotsTxt = '1 lot (minimum) = ' + (risk / R1).toFixed(2) + 'R · extended, about half normal risk'; }
    else { lots = Math.min(fitR, fitLock); lotsTxt = lots + (lots > 1 ? ' lots' : ' lot'); }
    var sizeTxt = 'lock room allows ' + fitLock + ' · 1R rule allows ' + fitR + ' → ' + (lots ? lots + (lots > 1 ? ' lots' : ' lot') : '0 lots');
    return { cp: cp, trig: trig, stop: stop, tgt: tgt, how: how, pT: pT, pS: pS, pG: pG, charges: charges, slip: slip, costs: costs, risk: risk, reward: reward, rr: rr, fitLock: fitLock, fitR: fitR,
      lots: lots, lotsTxt: lotsTxt, sizeTxt: sizeTxt, block: block, warn: warn, why: why, K: K, takeable: lots > 0 };
  }
  function groups(s) { var out = []; GORDER.forEach(function (g) { var a = s.members.filter(function (m) { return m.grp === g; }); if (a.length) out.push({ g: g, items: a }); }); return out; }
  // ONE group vocabulary (desk 1600, desk 1366 and phone)
  function gLabel(s, g, n) { var up = s.dir > 0, cp = up ? 'CE' : 'PE', ocp = up ? 'PE' : 'CE';
    return { up: [MODE.k === 'forming' ? 'FORMING' : up ? 'COMING UP NOW' : 'COMING DOWN NOW', n + ' · ' + cp], lead: ['LEADER', 'extended - pullback entry'], lag: ['LAGGARD', up ? 'may catch up' : 'may catch down'],
      wait: ['WAITING', 'a gate fails'], against: ['AGAINST (' + n + ')', ocp + ' strike'], nt: ['NOT TRADABLE', 'reason shown'] }[g]; }
  function ideas(s) { var ce = 0, pe = 0; s.members.forEach(function (m) { if (m.grp === 'nt' || m.grp === 'wait') return; if (optSide(s, m) === 'CE') ce++; else pe++; }); return { ce: ce, pe: pe }; }
  function fo(s) { var u = 0, d = 0; s.members.forEach(function (m) { if (m.ltp >= m.prev) u++; else d++; }); return { up: u, dn: d, n: s.members.length }; }
  // NARROW (R49): the F&O names move one way (75%+) while the other listed shares do not (under 60% one way)
  function narrow(s) { var f = fo(s), a = (s.dir > 0 ? f.up : f.dn) / f.n, nf = s.nonfo, b = (s.dir > 0 ? nf.up : nf.dn) / nf.n; return a >= 0.75 && b < 0.60 ? { fo: a, nf: b } : null; }
  function sideTxt(m) { return { both: 'above both', vwap: 'above VWAP', or: 'above OR', reclaim: 'reclaiming', below: 'below both', bvwap: 'below VWAP', bor: 'below OR' }[m.side] || m.side; }
  function find(sym) { for (var i = 0; i < SECTORS.length; i++) { var a = SECTORS[i].members; for (var j = 0; j < a.length; j++) if (a[j].sym === sym) return { s: SECTORS[i], m: a[j] }; } return null; }
  function sec(id) { for (var i = 0; i < SECTORS.length; i++) if (SECTORS[i].id === id) return SECTORS[i]; return null; }
  // the display order: the order at the last applied re-rank (s0 = score then) - a new score order is only pending
  function displayOrder(s, applied) { var a = s.members.slice(); var key = function (m) { return applied ? m.score : (m.s0 != null ? m.s0 : m.score); };
    var o = []; GORDER.forEach(function (g) { var x = a.filter(function (m) { return m.grp === g; }); x.sort(function (p, q) { return (p.neu ? 1 : 0) - (q.neu ? 1 : 0) || key(q) - key(p); }); o = o.concat(x); }); return o; }
  function pendingRR(s) { var a = displayOrder(s, false), b = displayOrder(s, true), d = {}; a.forEach(function (m, i) { var j = b.indexOf(m); if (j < i) d[m.sym] = i - j; }); return Object.keys(d).length ? d : null; }

  // ---------------- flows: Rs cr = free-float mcap (all listed) × (sector % − NIFTY %) in the window ----------------
  // excess % vs NIFTY per window (15M / 30M / 1H); TODAY uses the day % − NIFTY +0.72%
  // window values (Rs cr) for 15M / 30M / 1H; the implied excess % = cr / (ff × 1000) is shown in each tooltip. TODAY = ff × (day % − NIFTY %).
  var WCR = [{ Banks: 2760, 'NBFC & finance': 480, IT: -2050, FMCG: -980, _o: -210 },
    { Banks: 5860, 'NBFC & finance': 1280, IT: -4120, FMCG: -2380, _o: -640 },
    { Banks: 9450, 'NBFC & finance': 1930, Realty: 920, IT: -6940, FMCG: -3110, Pharma: -1420, _o: -830 }];
  function crOf(s, w) { if (w === 3) return Math.round(s.ff * (s.pct - NIFTY) * 1000); var e = WCR[w][s.id]; return e == null ? null : e; }
  // the picture names the top 2 each side; the rest are summed as "others" (named in its tooltip)
  function flows(w) { var RNG = ['10:50-11:05', '10:35-11:05', '10:05-11:05', '09:15-11:05'][w], out = [], inn = [];
    SECTORS.forEach(function (s) { var c = crOf(s, w); if (c == null) return; var row = [s.id, Math.abs(c), s.bu || '-', (s.dir > 0 ? s.up : s.dn) + '/' + s.n, s.pct, s.ff, c];
      if (c < 0) out.push(row); else inn.push(row); });
    out.sort(function (a, b) { return b[1] - a[1]; }); inn.sort(function (a, b) { return b[1] - a[1]; });
    function fold(list, extra) { if (list.length <= 2 && !extra) return list; var rest = list.slice(2), sum = extra || 0, names = rest.map(function (r) { return r[0]; });
      rest.forEach(function (r) { sum += r[1]; }); var o = list.slice(0, 2); if (sum) o.push(['others', sum, '', '', 0, 0, sum, names.length ? names : ['other sectors']]); return o; }
    out = fold(out, w < 3 ? -WCR[w]._o : 0); inn = fold(inn, 0);
    var so = 0, si = 0; out.forEach(function (r) { so += r[1]; }); inn.forEach(function (r) { si += r[1]; });
    return { rng: RNG, out: out, inn: inn, so: so, si: si, st: 'ROT CONFIRMED 22m' }; }

  // ---------------- synthetic 5-min bars 09:15 -> 11:05 (seeded by symbol) and the mini chart (pane + phone) ----------------
  function bars(m) {
    var seed = 0; for (var i = 0; i < m.sym.length; i++) seed = (seed * 31 + m.sym.charCodeAt(i)) % 2147483647;
    function rnd() { seed = (seed * 16807) % 2147483647; return seed / 2147483647; }
    var n = 23, up = m.ltp >= m.prev, open = up ? m.lo + (m.orH - m.lo) * 0.2 : m.hi - (m.hi - m.orL) * 0.2;
    var loAt = up ? 1 : 15, hiAt = up ? 20 : 1, path = [];
    for (var k = 0; k <= n; k++) { var base;
      if (up) base = k <= loAt ? open + (m.lo - open) * (k / loAt) : k <= hiAt ? m.lo + (m.hi - m.lo) * Math.pow((k - loAt) / (hiAt - loAt), 0.9) : m.hi + (m.ltp - m.hi) * ((k - hiAt) / (n - hiAt));
      else base = k <= hiAt ? open + (m.hi - open) * (k / hiAt) : k <= loAt ? m.hi + (m.lo - m.hi) * ((k - hiAt) / (loAt - hiAt)) : m.lo + (m.ltp - m.lo) * ((k - loAt) / (n - loAt));
      path.push(base); }
    var out = [], amp = (m.hi - m.lo) * 0.07;
    for (var b = 0; b < n; b++) { var o = path[b], c = path[b + 1]; if (b > 1 && b < n - 1 && b !== loAt && b !== hiAt) c += (rnd() - 0.5) * amp;
      var h = Math.max(o, c) + rnd() * amp * 0.6, l = Math.min(o, c) - rnd() * amp * 0.6; h = Math.min(h, m.hi); l = Math.max(l, m.lo);
      if (b === hiAt - 1 && up) h = m.hi; if (b === loAt - 1 && !up) l = m.lo; if (b === 0) { if (up) l = m.lo; else h = m.hi; }
      out.push({ o: o, h: h, l: l, c: c }); path[b + 1] = c; }
    out[n - 1].c = m.ltp; out[n - 1].h = Math.max(out[n - 1].h, m.ltp); out[n - 1].l = Math.min(out[n - 1].l, m.ltp);
    return out;
  }
  // price pane (candles, VWAP, OR box, trigger / stop / target, CE wall above and PE wall below) + a premium pane under it.
  // Layout top to bottom: price pane · premium caption · premium pane · time axis - nothing prints on anything else.
  function chartSvg(s, m, p, W, o) {
    o = o || {}; var Hp = o.hp || 100, Hq = o.hq || 34, fs = o.fs || 11, padL = 4, padR = o.padR || 56, b = bars(m), n = b.length;
    var lo = Math.min(m.lo, p.stop, m.vwap, p.tgt, p.trig), hi = Math.max(m.hi, p.tgt, p.trig, p.stop); var pad = (hi - lo) * 0.10; lo -= pad; hi += pad;
    var X = function (i) { return padL + (i + 0.5) * (W - padL - padR) / n; }, Y = function (v) { return 4 + (hi - v) / (hi - lo) * (Hp - 8); }, bw = Math.max(3, (W - padL - padR) / n - 3);
    var capY = Hp + fs + 4, y0 = capY + 4, axY = y0 + Hq + fs + 3, H = axY + 3;
    var h = '<svg class="mchart" width="' + W + '" height="' + H + '" viewBox="0 0 ' + W + ' ' + H + '" style="font-size:' + fs + 'px">';
    var orY1 = Y(m.orH), orY2 = Y(m.orL); h += '<rect x="' + padL + '" y="' + orY1 + '" width="' + (X(2) + bw / 2 - padL) + '" height="' + Math.max(1, orY2 - orY1) + '" fill="var(--info-bg)" stroke="var(--info-line)"/><text class="lb" x="' + (padL + 2) + '" y="' + (orY1 - 2) + '">OR</text>';
    var cum = 0, v = [], cv = 0; b.forEach(function (x, i) { var vol = 1 + (i < 3 ? 1.2 : 0) + (i > 15 ? 0.6 : 0); cum += (x.h + x.l + x.c) / 3 * vol; cv += vol; v.push(cum / cv); });
    var adj = m.vwap - v[n - 1]; h += '<polyline fill="none" stroke="var(--info)" stroke-width="1.5" points="' + v.map(function (x, i) { return X(i).toFixed(1) + ',' + Y(x + adj * i / (n - 1)).toFixed(1); }).join(' ') + '"/>';
    var labs = [];
    function hl(val, col, lab, dash) { var y = Y(val); h += '<line x1="' + padL + '" x2="' + (W - padR + 2) + '" y1="' + y + '" y2="' + y + '" stroke="' + col + '" stroke-dasharray="' + (dash || '4 3') + '" stroke-width="1"/>'; labs.push([y + 4, col, lab]); }
    b.forEach(function (x, i) { var c = x.c >= x.o ? 'var(--up)' : 'var(--down)'; h += '<line x1="' + X(i) + '" x2="' + X(i) + '" y1="' + Y(x.h) + '" y2="' + Y(x.l) + '" stroke="' + c + '"/><rect x="' + (X(i) - bw / 2) + '" y="' + Math.min(Y(x.o), Y(x.c)) + '" width="' + bw + '" height="' + Math.max(1, Math.abs(Y(x.o) - Y(x.c))) + '" fill="' + c + '"/>'; });
    if (!p.block || /STALE/.test(p.block)) { hl(p.trig, 'var(--action)', 'T ' + lv(p.trig)); hl(p.stop, 'var(--down)', 'S ' + lv(p.stop)); hl(p.tgt, 'var(--up)', 'G ' + lv(p.tgt)); }
    // walls: drawn as lines when inside the price range, else as an edge marker with the distance
    [['C', m.wallC, 'var(--down)'], ['P', m.wallP, 'var(--up)']].forEach(function (wl) { var val = wl[1], inR = val <= hi && val >= lo, lab = (wl[0] === 'C' ? 'CE wall ' : 'PE wall ') + fmt(val, val % 1 ? 1 : 0);
      if (inR) { var y = Y(val); h += '<line x1="' + padL + '" x2="' + (W - padR + 2) + '" y1="' + y + '" y2="' + y + '" stroke="' + wl[2] + '" stroke-width="2" opacity=".55"/>'; labs.push([y + 4, wl[2], lab.replace(' wall', 'w')]); }
      else { var ye = wl[0] === 'C' ? 4 : Hp - 4; h += '<line x1="' + padL + '" x2="' + (W - padR + 2) + '" y1="' + ye + '" y2="' + ye + '" stroke="' + wl[2] + '" stroke-width="2" stroke-dasharray="1 3" opacity=".7"/>' +
        '<text x="' + (W - padR - 2) + '" y="' + (wl[0] === 'C' ? ye + fs + 1 : ye - 3) + '" text-anchor="end" fill="' + wl[2] + '">' + lab + (wl[0] === 'C' ? ' ↑ ' : ' ↓ ') + (Math.abs(val / m.ltp - 1) * 100).toFixed(1) + '%</text>'; } });
    // right-hand labels: no two overlap
    labs.sort(function (a, c) { return a[0] - c[0]; }); var last = -99; labs.forEach(function (l) { var y = Math.max(l[0], last + fs + 1); y = Math.min(y, Hp + 2); last = y; h += '<text x="' + (W - padR + 4) + '" y="' + y + '" fill="' + l[1] + '">' + l[2] + '</text>'; });
    var K = p.K, cp = p.cp, prem = b.map(function (x, i) { return bs(x.c, K, T + (n - 1 - i) * 5 / 60 / 24 / 365, m.iv, cp); }), c0 = contract(s, m, 'atm');
    var pl = Math.min.apply(null, prem) - c0.sp, ph = Math.max.apply(null, prem) + c0.sp, PY = function (q) { return y0 + 2 + (ph - q) / (ph - pl) * (Hq - 4); };
    h += '<text class="lb" x="' + padL + '" y="' + capY + '">' + kTxt(K) + ' ' + cp + ' Dec premium · mid + bid/ask band</text><text x="' + (W - padR + 4) + '" y="' + capY + '" fill="var(--text-2)">' + fmt(c0.ask, 2) + '</text>';
    h += '<line x1="' + padL + '" x2="' + (W - padR) + '" y1="' + y0 + '" y2="' + y0 + '" stroke="var(--line)"/>';
    h += '<polygon fill="var(--up-bg)" points="' + prem.map(function (q, i) { return X(i).toFixed(1) + ',' + PY(q + c0.sp / 2).toFixed(1); }).join(' ') + ' ' + prem.slice().reverse().map(function (q, j) { var i = n - 1 - j; return X(i).toFixed(1) + ',' + PY(q - c0.sp / 2).toFixed(1); }).join(' ') + '"/>';
    h += '<polyline fill="none" stroke="var(--' + (cp === 'CE' ? 'up' : 'down') + ')" stroke-width="1.4" points="' + prem.map(function (q, i) { return X(i).toFixed(1) + ',' + PY(q).toFixed(1); }).join(' ') + '"/>';
    h += '<text x="' + padL + '" y="' + axY + '">09:15</text><text x="' + X(n - 1) + '" y="' + axY + '" text-anchor="end">11:05</text></svg>';
    return h; }

  return { CLOCK: CLOCK, T: T, HRS_LEFT: HRS_LEFT, R1: R1, LOCK: LOCK, NIFTY: NIFTY, MODE: MODE, MODES: MODES, SECTORS: SECTORS, GORDER: GORDER, bs: bs, fmt: fmt, sg: sg, rs: rs, lv: lv, kTxt: kTxt,
    contract: contract, plan: plan, room: room, extOf: extOf, isExt: isExt, groups: groups, gLabel: gLabel, ideas: ideas, fo: fo, narrow: narrow, sideTxt: sideTxt, find: find, sec: sec, bars: bars, chartSvg: chartSvg,
    optSide: optSide, tickOf: tickOf, score: score, gates: gates, comingUp: comingUp, classify: classify, pctOf: pctOf, displayOrder: displayOrder, pendingRR: pendingRR, flows: flows, crOf: crOf, breadthOneWay: breadthOneWay };
})();
if (typeof module !== 'undefined') module.exports = GD;

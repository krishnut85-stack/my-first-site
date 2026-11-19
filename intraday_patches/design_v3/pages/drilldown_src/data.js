// GIR · sector drill-down · ONE data + maths module shared by the laptop page and the phone page (inlined at build).
// Illustrative day: Thu 19 Nov 2026 11:05:00 (design mockup - illustrative values). December expiry Tue 29 Dec 15:30.
var GD = (function () {
  'use strict';
  var CLOCK = '11:05:00', HRS_LEFT = 4 + 5 / 60;            // to 15:10
  var T = (40 + (15.5 - (11 + 5 / 60)) / 24) / 365;          // 19 Nov 11:05 -> 29 Dec 15:30, years
  var R1 = 5000, LOCK = 10000;
  function erf(x) { var s = x < 0 ? -1 : 1; x = Math.abs(x); var t = 1 / (1 + 0.3275911 * x);
    var y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-x * x); return s * y; }
  function N(x) { return 0.5 * (1 + erf(x / Math.SQRT2)); }
  function bs(S, K, t, v, cp) { var sd = v * Math.sqrt(t), d1 = (Math.log(S / K) + 0.5 * v * v * t) / sd, d2 = d1 - sd;
    var c = S * N(d1) - K * N(d2); return cp === 'CE' ? c : c - S + K; }
  function delta(S, K, t, v, cp) { var sd = v * Math.sqrt(t), d1 = (Math.log(S / K) + 0.5 * v * v * t) / sd; return cp === 'CE' ? N(d1) : N(d1) - 1; }
  function r05(x) { return Math.round(x * 20) / 20; }
  function r10(x) { return Math.round(x / 10) * 10; }
  function fmt(x, d) { if (d === undefined) d = 2; var s = Math.abs(x).toFixed(d).split('.'), i = s[0], o = '';
    // Indian grouping
    if (i.length > 3) { var last = i.slice(-3), rest = i.slice(0, -3); rest = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ','); i = rest + ',' + last; }
    o = i + (s[1] ? '.' + s[1] : ''); return (x < 0 ? '−' : '') + o; }
  function sg(x, d) { return (x > 0 ? '+' : x < 0 ? '' : '') + fmt(x, d); }
  function rs(x) { return '₹' + fmt(x, 0); }
  function tickOf(S) { return S < 100 ? 0.05 : S < 500 ? 0.1 : 0.5; }

  // ---------------- sectors (30M window, ranked by RS 30M over ALL listed shares - R49) ----------------
  var SECTORS = [
    { id: 'Banks', basis: 'all 41 listed · ff-wtd', idx: 'NIFTY BANK +1.12%', rs30: 0.72, today: 2, pct: 1.06, up: 31, dn: 10, n: 41, cr: 5860, bu: 'LB', st: 'ROT CONFIRMED', stAge: '22m', conf: '10:20',
      run: { since: '10:05', len: '1h 00m', typ: '1h 40m', nn: 28, br: '27→31', fade: false },
      why: { drv: 'FII buying 13 sessions', live: '+₹1,486 cr 18 Nov', story: 'Goldman: India banks to OW', src: 'CNBC-TV18 TV, 18 Nov 12:44', sage: '22h' },
      nonfo: { n: 27, up: 19, dn: 8, wt: 8.6, ex: [['J&KBANK', 2.14], ['KARURVYSYA', 1.86], ['CUB', 1.62], ['DCBBANK', 1.40], ['SOUTHBANK', 0.92], ['UJJIVANSFB', -0.41], ['EQUITASBNK', -0.63], ['CENTRALBK', 1.12]] } },
    { id: 'NBFC & finance', basis: 'all 92 listed · ff-wtd', rs30: 0.41, today: 4, pct: 0.64, up: 58, dn: 34, n: 92, cr: 1280, bu: 'LB', st: 'IN', stAge: '14m', conf: '10:51',
      run: { since: '10:40', len: '25m', typ: '1h 10m', nn: 19, br: '52→58', fade: false },
      why: { drv: 'with Banks - same FII flow', live: 'FINNIFTY +0.91%', story: '', src: '', sage: '' },
      nonfo: { n: 87, up: 54, dn: 33, wt: 31.0, ex: [['CREDITACC', 1.2], ['MANAPPURAM', 0.6], ['IIFL', 0.9]] } },
    { id: 'Realty', basis: 'NIFTY REALTY', rs30: 0.38, today: 1, pct: 1.38, up: 29, dn: 11, n: 40, cr: 940, bu: 'LB', st: 'NOT THIS ROT', stAge: '', conf: '10:31',
      run: { since: '09:50', len: '1h 15m', typ: '55m', nn: 22, br: '33→29', fade: true },
      why: null, nonfo: { n: 34, up: 23, dn: 11, wt: 18.0, ex: [['SOBHA', 1.9], ['BRIGADE', 1.4]] } },
    { id: 'Metals', basis: 'NIFTY METAL', rs30: 0.22, today: 3, pct: 0.84, up: 30, dn: 12, n: 42, cr: 610, bu: 'SC', st: 'SHORTS LEAVE', stAge: '', conf: '',
      run: { since: '10:25', len: '40m', typ: '1h 05m', nn: 31, br: '26→30', fade: false },
      why: { drv: 'LME copper +1.2% (live)', live: '', story: 'China stimulus talk', src: 'Reuters 09:20', sage: '1h 45m' },
      nonfo: { n: 36, up: 25, dn: 11, wt: 14.0, ex: [['JINDALSTEL', 1.1], ['WELCORP', 0.7]] } },
    { id: 'Auto', basis: 'NIFTY AUTO', rs30: 0.04, today: 5, pct: 0.21, up: 24, dn: 22, n: 46, cr: 120, bu: 'LB', st: '', stAge: '', conf: '',
      run: null, why: null, nonfo: { n: 41, up: 21, dn: 20, wt: 22.0, ex: [] } },
    { id: 'Cement', basis: 'all 24 listed · ff-wtd', rs30: -0.02, today: 6, pct: 0.12, up: 13, dn: 11, n: 24, cr: -40, bu: '', st: '', stAge: '', conf: '',
      run: null, why: null, nonfo: { n: 21, up: 12, dn: 9, wt: 19.0, ex: [] } },
    { id: 'Power', basis: 'all 31 listed · ff-wtd', rs30: -0.08, today: 7, pct: 0.05, up: 16, dn: 15, n: 31, cr: -160, bu: '', st: '', stAge: '', conf: '',
      run: null, why: null, nonfo: { n: 28, up: 15, dn: 13, wt: 24.0, ex: [] } },
    { id: 'Oil & gas', basis: 'NIFTY OIL & GAS', rs30: -0.11, today: 8, pct: -0.18, up: 6, dn: 9, n: 15, cr: -290, bu: 'LU', st: '', stAge: '', conf: '',
      run: null, why: { drv: 'Brent +0.42% (live)', live: '', story: '', src: '', sage: '' }, nonfo: { n: 11, up: 5, dn: 6, wt: 9.0, ex: [] } },
    { id: 'Pharma', basis: 'NIFTY PHARMA', rs30: -0.18, today: 9, pct: -0.62, up: 30, dn: 58, n: 88, cr: -310, bu: 'LU', st: '', stAge: '', conf: '',
      run: { since: '10:15', len: '50m', typ: '1h 20m', nn: 17, br: '50→58', fade: false },
      why: { drv: 'peer US FDA warning letter', live: '', story: 'FDA letter to a peer plant', src: 'ET 09:31', sage: '1h 34m' }, nonfo: { n: 83, up: 29, dn: 54, wt: 34.0, ex: [] } },
    { id: 'FMCG', basis: 'NIFTY FMCG', rs30: -0.36, today: 10, pct: -0.71, up: 21, dn: 39, n: 60, cr: -2380, bu: 'SB', st: 'OUT', stAge: '22m', conf: '10:20',
      run: { since: '10:05', len: '1h 00m', typ: '1h 30m', nn: 24, br: '34→39', fade: false },
      why: { drv: 'money to banks', live: '', story: 'rural demand note', src: 'Nomura 08:50', sage: '2h 15m' }, nonfo: { n: 55, up: 20, dn: 35, wt: 21.0, ex: [] } },
    { id: 'IT', basis: 'NIFTY IT', rs30: -0.58, today: 11, pct: -1.04, up: 22, dn: 52, n: 74, cr: -4120, bu: 'SB', st: 'OUT', stAge: '22m', conf: '10:20',
      run: { since: '09:40', len: '1h 25m', typ: '2h 05m', nn: 33, br: '47→52', fade: false },
      why: { drv: 'USD/INR −0.12% (live)', live: '', story: 'Accenture guidance cut', src: 'overnight wires', sage: '14h' }, nonfo: { n: 68, up: 20, dn: 48, wt: 16.0, ex: [] } }
  ];

  // ---------------- F&O members ----------------
  // grp: up (COMING UP / DOWN NOW) · lead · lag · with (gate open) · against · nt (NOT TRADABLE)
  var M = {};
  M['Banks'] = [
    { sym: 'ICICIBANK', role: 'FOLLOWER', grp: 'up', prev: 1444.50, ltp: 1462.40, vwap: 1456.2, orL: 1450.0, orH: 1458.0, lo: 1450.0, hi: 1463.0, atr: 25, rs30: 0.92, rs15: 0.74, sl: '↗', rvol: 2.1, rvUp: 1, side: 'both', bu: 'LB', oi: 4.1, buN: 3.2, buD: 7.9, wt: 20.5, lot: 700, iv: 0.234, iv20: 0.218, step: 10, spr: 5, sprI: 6, dep: 18, depI: 9, gate: '✓ 4 of 4', gok: 1, ai: 'GET READY', aiT: '11:04', age: '0.3s', wallC: 1500, wallP: 1440, mwpl: 18, res: 'results ~24 Jan · no IV-crush risk now', exd: 'no ex-date',
      news: [['09:52', 'ET', 'ICICI Bank: deposits beat system growth, 3rd month', '1h 13m'], ['18 Nov 12:44', 'CNBC-TV18', 'Goldman: India banks OW, ICICI top pick', '22h']],
      aiv: 'GET READY 11:04 · 1,460 CE Dec · 4 of 5 agree' },
    { sym: 'AXISBANK', role: 'FOLLOWER', grp: 'up', prev: 1226.80, ltp: 1248.30, vwap: 1240.1, orL: 1232.0, orH: 1239.0, lo: 1232.0, hi: 1249.0, atr: 24, rs30: 0.81, rs15: 0.88, sl: '↗', rvol: 2.6, rvUp: 1, side: 'both', bu: 'LB', oi: 6.3, buN: 4.0, buD: 11.6, wt: 7.9, lot: 625, iv: 0.245, iv20: 0.229, step: 10, spr: 5, sprI: 6, dep: 14, depI: 7, gate: '✓ 4 of 4', gok: 1, ai: '', age: '0.4s', rr: 1, wallC: 1300, wallP: 1200, mwpl: 22, res: 'results ~22 Jan', exd: 'no ex-date',
      news: [['10:31', 'Moneycontrol', 'Axis Bank: card spends up 18% YoY in October', '34m']] },
    { sym: 'BANKBARODA', role: 'FOLLOWER', grp: 'up', prev: 268.40, ltp: 274.65, vwap: 272.6, orL: 270.2, orH: 272.4, lo: 270.2, hi: 274.9, atr: 6.6, rs30: 0.74, rs15: 0.91, sl: '↗', rvol: 3.0, rvUp: 1, side: 'both', bu: 'LB', oi: 8.8, buN: 6.1, buD: 14.2, wt: 2.4, lot: 2925, iv: 0.29, iv20: 0.27, step: 2.5, spr: 2, sprI: 2, dep: 22, depI: 11, gate: '✓ 4 of 4', gok: 1, ai: '', age: '0.5s', neu: '11:01', wallC: 280, wallP: 270, mwpl: 31, res: 'results ~30 Jan', exd: 'no ex-date',
      news: [['10:12', 'BS', 'PSU banks: Q3 credit growth seen at 13%', '53m']] },
    { sym: 'SBIN', role: 'LEADER', grp: 'lead', prev: 958.20, ltp: 987.80, vwap: 974.6, orL: 958.0, orH: 966.5, lo: 958.0, hi: 989.4, atr: 18.5, rs30: 0.64, rs15: 0.12, sl: '→', rvol: 3.4, rvUp: 1, side: 'both', bu: 'LB', oi: 11.2, buN: 8.4, buD: 17.0, wt: 10.8, lot: 750, iv: 0.26, iv20: 0.24, step: 5, spr: 4, sprI: 4, dep: 25, depI: 14, gate: 'EXTENDED', gok: 0, ext: 1, ai: '', age: '0.3s', wallC: 1000, wallP: 960, mwpl: 27, res: 'results ~6 Feb', exd: 'no ex-date',
      news: [['09:47', 'CNBC-TV18', 'SBI at record high; m-cap crosses ₹9 lakh cr', '1h 18m']] },
    { sym: 'HDFCBANK', role: 'LAGGARD', grp: 'lag', prev: 1011.40, ltp: 1012.05, vwap: 1011.6, orL: 1006.2, orH: 1015.5, lo: 1006.2, hi: 1015.5, atr: 17, rs30: -0.42, rs15: 0.18, sl: '↗', rvol: 0.9, rvUp: 1, side: 'reclaim', bu: '', oi: 0.4, buN: 0.2, buD: 0.9, wt: 31.0, lot: 550, iv: 0.20, iv20: 0.195, step: 10, spr: 3, sprI: 4, dep: 30, depI: 16, gate: 'trig > 1,016.0', gok: 0, ai: '', age: '0.3s', wallC: 1040, wallP: 1000, mwpl: 12, res: 'results ~17 Jan', exd: 'no ex-date',
      news: [['18 Nov 17:05', 'ET', 'HDFC Bank: no bad news; flows went to PSU names', '18h']] },
    { sym: 'KOTAKBANK', role: 'FOLLOWER', grp: 'with', prev: 2086.00, ltp: 2108.90, vwap: 2101.4, orL: 2088.0, orH: 2099.0, lo: 2088.0, hi: 2112.0, atr: 38, rs30: 0.21, rs15: 0.30, sl: '→', rvol: 1.2, rvUp: 1, side: 'both', bu: 'LB', oi: 2.2, buN: 1.4, buD: 4.6, wt: 8.2, lot: 400, iv: 0.21, iv20: 0.205, step: 20, spr: 6, sprI: 8, dep: 9, depI: 5, gate: 'RS30 +0.21', gok: 0, ai: '', age: '0.4s', wallC: 2200, wallP: 2060, mwpl: 15, res: 'results ~24 Jan', exd: 'no ex-date', news: [] },
    { sym: 'CANBK', role: 'FOLLOWER', grp: 'with', prev: 118.62, ltp: 120.86, vwap: 120.70, orL: 118.9, orH: 120.1, lo: 118.9, hi: 121.2, atr: 3.2, rs30: 0.58, rs15: 0.40, sl: '↗', rvol: 2.0, rvUp: 1, side: 'reclaim', bu: 'LB', oi: 5.0, buN: 3.1, buD: 9.4, wt: 1.7, lot: 6750, iv: 0.30, iv20: 0.28, step: 1, spr: 1, sprI: 1, dep: 12, depI: 6, gate: 'VWAP 1/2 bars', gok: 0, ai: '', age: '0.6s', wallC: 125, wallP: 118, mwpl: 41, res: 'results ~29 Jan', exd: 'no ex-date', news: [] },
    { sym: 'PNB', role: 'FOLLOWER', grp: 'with', prev: 112.40, ltp: 113.98, vwap: 113.40, orL: 112.6, orH: 113.5, lo: 112.6, hi: 114.2, atr: 2.9, rs30: 0.33, rs15: 0.20, sl: '→', rvol: 1.6, rvUp: 1, side: 'both', bu: 'LB', oi: 3.1, buN: 2.0, buD: 5.8, wt: 1.9, lot: 8000, iv: 0.31, iv20: 0.29, step: 1, spr: 1, sprI: 1, dep: 10, depI: 5, gate: 'RS30 +0.33', gok: 0, ai: '', age: '0.5s', wallC: 120, wallP: 110, mwpl: 36, res: 'results ~28 Jan', exd: 'no ex-date', news: [] },
    { sym: 'AUBANK', role: 'FOLLOWER', grp: 'with', prev: 742.30, ltp: 751.20, vwap: 748.0, orL: 741.0, orH: 747.5, lo: 741.0, hi: 753.0, atr: 19, rs30: 0.12, rs15: 0.10, sl: '→', rvol: 1.3, rvUp: 0, side: 'vwap', bu: 'SC', oi: -2.4, buN: -3.0, buD: -1.1, wt: 1.1, lot: 1000, iv: 0.27, iv20: 0.26, step: 10, spr: 6, sprI: 7, dep: 6, depI: 3, gate: 'STALE 12s', gok: 0, stale: 1, ai: '', age: '12s', wallC: 780, wallP: 740, mwpl: 24, res: 'results ~21 Jan', exd: 'no ex-date', news: [] },
    { sym: 'FEDERALBNK', role: 'FOLLOWER', grp: 'with', prev: 228.10, ltp: 230.85, vwap: 229.9, orL: 228.0, orH: 229.6, lo: 228.0, hi: 231.4, atr: 5.2, rs30: 0.15, rs15: 0.08, sl: '→', rvol: 1.1, rvUp: 0, side: 'both', bu: 'LB', oi: 1.8, buN: 1.0, buD: 3.9, wt: 1.2, lot: 5000, iv: 0.27, iv20: 0.26, step: 2.5, spr: 2, sprI: 2, dep: 8, depI: 4, gate: 'RVOL 1.1', gok: 0, ai: '', age: '0.7s', wallC: 240, wallP: 225, mwpl: 19, res: 'results ~16 Jan', exd: 'no ex-date', news: [] },
    { sym: 'IDFCFIRSTB', role: 'FOLLOWER', grp: 'with', prev: 78.40, ltp: 78.95, vwap: 78.90, orL: 78.2, orH: 78.8, lo: 78.2, hi: 79.3, atr: 2.1, rs30: 0.05, rs15: -0.10, sl: '↘', rvol: 1.4, rvUp: 0, side: 'vwap', bu: 'LB', oi: 1.2, buN: 0.8, buD: 2.4, wt: 1.3, lot: 9275, iv: 0.30, iv20: 0.29, step: 1, spr: 1, sprI: 1, dep: 7, depI: 4, gate: 'RS15 −0.10', gok: 0, ai: '', age: '0.5s', wallC: 80, wallP: 75, mwpl: 44, res: 'results ~24 Jan', exd: 'no ex-date', news: [] },
    { sym: 'YESBANK', role: 'FOLLOWER', grp: 'with', prev: 22.10, ltp: 22.21, vwap: 22.16, orL: 22.0, orH: 22.25, lo: 22.0, hi: 22.3, atr: 0.55, rs30: -0.12, rs15: 0.02, sl: '→', rvol: 0.8, rvUp: 0, side: 'or', bu: '', oi: 0.3, buN: 0.1, buD: 0.6, wt: 0.9, lot: 31100, iv: 0.32, iv20: 0.31, step: 1, spr: 1, sprI: 1, dep: 40, depI: 20, gate: 'RVOL 0.8', gok: 0, ai: '', age: '0.8s', wallC: 25, wallP: 20, mwpl: 29, res: 'results ~22 Jan', exd: 'no ex-date', news: [] },
    { sym: 'BANDHANBNK', role: 'DEPENDENT', grp: 'against', prev: 172.30, ltp: 170.32, vwap: 171.4, orL: 170.1, orH: 172.9, lo: 169.9, hi: 173.2, atr: 4.6, rs30: -1.10, rs15: -0.80, sl: '↘', rvol: 1.9, rvUp: 1, side: 'below', bu: 'SB', oi: 6.4, buN: 5.0, buD: 9.8, wt: 0.6, lot: 3600, iv: 0.33, iv20: 0.31, step: 2.5, spr: 2, sprI: 2, dep: 9, depI: 5, gate: 'own news 09:40', gok: 0, ai: '', age: '0.4s', wallC: 180, wallP: 165, mwpl: 48, res: 'results ~30 Jan', exd: 'no ex-date',
      news: [['09:40', 'ET', 'Bandhan: MFI collection efficiency slips in Assam', '1h 25m']] },
    { sym: 'INDUSINDBK', role: 'FOLLOWER', grp: 'nt', prev: 802.40, ltp: 799.05, vwap: 800.2, orL: 797.0, orH: 803.5, lo: 796.1, hi: 804.0, atr: 22, rs30: -0.60, rs15: -0.20, sl: '→', rvol: 1.0, rvUp: 0, side: 'below', bu: 'SB', oi: 1.1, buN: 0.6, buD: 2.2, wt: 1.9, lot: 700, iv: 0.36, iv20: 0.33, step: 10, spr: 8, sprI: 9, dep: 4, depI: 2, gate: 'BAN · close only', gok: 0, ban: 1, ai: '', age: '0.4s', wallC: 840, wallP: 780, mwpl: 96, res: 'results ~26 Jan', exd: 'no ex-date', news: [] }
  ];
  // compact members for the other sectors: [sym, grp, role, prev, pct, rvol, rs30, bu, oi, wt, lot, step, iv, gate, extra]
  var C = {
    'NBFC & finance': [['BAJFINANCE', 'up', 'FOLLOWER', 1018.40, 1.62, 2.4, 0.71, 'LB', 5.2, 22.0, 750, 10, 0.27, '✓ 4 of 4', { neu: '10:56' }], ['SHRIRAMFIN', 'lead', 'LEADER', 712.30, 2.85, 3.1, 0.66, 'LB', 9.1, 8.0, 825, 10, 0.31, 'EXTENDED', { ext: 1 }], ['CHOLAFIN', 'lag', 'LAGGARD', 1612.00, 0.08, 0.9, -0.31, '', 0.3, 7.0, 625, 20, 0.28, 'trig > OR high'], ['MUTHOOTFIN', 'with', 'DEPENDENT', 3240.0, 0.71, 1.1, 0.18, 'LB', 1.4, 3.0, 275, 50, 0.29, 'RVOL 1.1'], ['LICHSGFIN', 'against', 'DEPENDENT', 584.20, -0.92, 1.7, -0.95, 'SB', 4.4, 2.0, 1000, 5, 0.30, 'below VWAP']],
    'Realty': [['DLF', 'up', 'LEADER', 742.50, 2.10, 2.8, 0.82, 'LB', 6.6, 24.0, 825, 10, 0.32, '✓ 4 of 4', { neu: '10:52' }], ['LODHA', 'up', 'FOLLOWER', 1185.0, 1.75, 2.2, 0.68, 'LB', 4.9, 14.0, 450, 10, 0.34, '✓ 4 of 4'], ['GODREJPROP', 'lead', 'LEADER', 2210.0, 3.20, 3.3, 0.52, 'LB', 8.0, 11.0, 275, 20, 0.36, 'EXTENDED', { ext: 1 }], ['OBEROIRLTY', 'lag', 'LAGGARD', 1712.0, 0.10, 0.8, -0.38, '', 0.2, 8.0, 350, 20, 0.30, 'trig > OR high'], ['PRESTIGE', 'with', 'FOLLOWER', 1598.0, 0.92, 1.3, 0.21, 'LB', 1.9, 6.0, 450, 20, 0.35, 'RVOL 1.3'], ['PHOENIXLTD', 'with', 'FOLLOWER', 1702.0, 0.85, 1.6, 0.14, 'SC', -1.2, 8.0, 350, 20, 0.31, 'RS30 +0.14']],
    'Metals': [['TATASTEEL', 'up', 'FOLLOWER', 172.40, 1.50, 2.0, 0.64, 'LB', 3.9, 18.0, 5500, 2.5, 0.29, '✓ 4 of 4'], ['HINDALCO', 'lead', 'LEADER', 812.0, 1.90, 2.6, 0.55, 'SC', -1.9, 14.0, 1400, 10, 0.27, 'SC · fades fast'], ['JSWSTEEL', 'with', 'FOLLOWER', 1152.0, 0.60, 1.2, 0.12, 'LB', 1.1, 13.0, 675, 10, 0.26, 'RVOL 1.2'], ['VEDL', 'lag', 'LAGGARD', 488.0, 0.05, 0.9, -0.30, '', 0.4, 10.0, 1150, 5, 0.31, 'trig > OR high'], ['SAIL', 'with', 'DEPENDENT', 132.50, 0.90, 1.4, 0.20, 'LB', 2.0, 4.0, 4700, 1, 0.33, 'RVOL 1.4'], ['NMDC', 'against', 'DEPENDENT', 74.20, -0.60, 1.5, -0.88, 'SB', 2.8, 4.0, 6750, 1, 0.32, 'own: ore price cut']],
    'Auto': [['BAJAJ-AUTO', 'lead', 'LEADER', 9110.0, 1.10, 1.4, 0.40, 'LB', 2.4, 12.0, 75, 100, 0.24, 'RVOL 1.4'], ['M&M', 'with', 'FOLLOWER', 3612.0, 0.60, 1.1, 0.10, 'LB', 1.0, 20.0, 200, 20, 0.25, 'RVOL 1.1'], ['EICHERMOT', 'with', 'FOLLOWER', 7050.0, 0.40, 1.0, 0.02, '', 0.3, 8.0, 175, 50, 0.24, 'RS30 +0.02'], ['MARUTI', 'lag', 'LAGGARD', 16240.0, 0.02, 0.8, -0.20, '', 0.1, 18.0, 50, 100, 0.22, 'trig > OR high'], ['TMPV', 'against', 'FOLLOWER', 412.0, -0.80, 1.6, -0.70, 'SB', 3.1, 9.0, 800, 5, 0.30, 'below VWAP']],
    'Cement': [['ULTRACEMCO', 'with', 'LEADER', 11920.0, 0.30, 1.0, 0.05, '', 0.2, 30.0, 50, 100, 0.22, 'RVOL 1.0'], ['AMBUJACEM', 'lag', 'LAGGARD', 562.0, -0.10, 0.9, -0.15, '', 0.1, 12.0, 1050, 5, 0.25, 'trig > OR high'], ['SHREECEM', 'against', 'FOLLOWER', 28900.0, -0.50, 1.2, -0.40, 'LU', -0.8, 9.0, 25, 250, 0.23, 'below VWAP']],
    'Power': [['NTPC', 'with', 'LEADER', 334.0, 0.40, 1.1, 0.08, '', 0.5, 26.0, 1500, 2.5, 0.24, 'RVOL 1.1'], ['POWERGRID', 'lag', 'LAGGARD', 288.0, -0.05, 0.9, -0.10, '', 0.1, 20.0, 1900, 2.5, 0.23, 'trig > OR high'], ['TATAPOWER', 'against', 'FOLLOWER', 398.0, -0.60, 1.4, -0.52, 'SB', 1.9, 8.0, 1450, 5, 0.29, 'below VWAP']],
    'Oil & gas': [['ONGC', 'up', 'FOLLOWER', 242.0, -0.90, 1.8, -0.60, 'SB', 3.2, 14.0, 2250, 2.5, 0.27, '✓ 4 of 4'], ['BPCL', 'lead', 'LEADER', 338.0, -1.20, 2.0, -0.55, 'SB', 4.0, 6.0, 1975, 2.5, 0.29, '✓ 4 of 4'], ['IOC', 'with', 'FOLLOWER', 148.0, -0.30, 1.1, -0.10, '', 0.4, 5.0, 4875, 1, 0.27, 'RVOL 1.1'], ['RELIANCE', 'lag', 'LAGGARD', 1512.0, 0.05, 0.9, 0.20, '', 0.2, 48.0, 500, 10, 0.20, 'trig < OR low']],
    'Pharma': [['SUNPHARMA', 'up', 'FOLLOWER', 1712.0, -1.10, 2.1, -0.70, 'SB', 3.6, 16.0, 350, 20, 0.24, '✓ 4 of 4'], ['DRREDDY', 'lead', 'LEADER', 1240.0, -1.60, 2.5, -0.81, 'SB', 5.3, 8.0, 625, 10, 0.26, '✓ 4 of 4'], ['CIPLA', 'with', 'FOLLOWER', 1522.0, -0.40, 1.2, -0.10, 'LU', -0.6, 9.0, 375, 20, 0.23, 'RVOL 1.2'], ['DIVISLAB', 'lag', 'LAGGARD', 6420.0, 0.10, 0.8, 0.30, '', 0.2, 7.0, 100, 50, 0.25, 'trig < OR low'], ['LUPIN', 'against', 'FOLLOWER', 2060.0, 0.40, 1.3, 0.62, 'LB', 1.8, 6.0, 425, 20, 0.27, 'own: US approval']],
    'FMCG': [['HINDUNILVR', 'up', 'LEADER', 2412.0, -1.20, 2.0, -0.66, 'SB', 3.0, 22.0, 300, 20, 0.21, '✓ 4 of 4'], ['NESTLEIND', 'lead', 'LEADER', 1182.0, -1.70, 2.2, -0.74, 'SB', 4.1, 9.0, 500, 10, 0.22, '✓ 4 of 4'], ['ITC', 'with', 'FOLLOWER', 402.0, -0.50, 1.0, -0.12, 'LU', -0.4, 26.0, 1600, 5, 0.19, 'RVOL 1.0'], ['BRITANNIA', 'lag', 'LAGGARD', 5890.0, 0.00, 0.8, 0.25, '', 0.1, 7.0, 125, 50, 0.21, 'trig < OR low'], ['DABUR', 'against', 'FOLLOWER', 512.0, 0.30, 1.3, 0.55, 'LB', 1.2, 4.0, 1250, 5, 0.22, 'own: price hike']],
    'IT': [['INFY', 'up', 'FOLLOWER', 1522.0, -1.60, 2.3, -0.72, 'SB', 4.4, 29.0, 400, 20, 0.25, '✓ 4 of 4'], ['HCLTECH', 'up', 'FOLLOWER', 1612.0, -1.30, 2.0, -0.61, 'SB', 3.7, 12.0, 350, 20, 0.24, '✓ 4 of 4'], ['TCS', 'lead', 'LEADER', 3060.0, -2.30, 2.8, -0.58, 'SB', 6.2, 26.0, 175, 20, 0.24, 'EXTENDED', { ext: 1 }], ['TECHM', 'lag', 'LAGGARD', 1512.0, -0.10, 0.9, 0.35, '', 0.2, 5.0, 600, 20, 0.26, 'trig < OR low'], ['WIPRO', 'with', 'FOLLOWER', 246.0, -0.70, 1.2, -0.20, 'SB', 1.1, 7.0, 3000, 2.5, 0.25, 'RVOL 1.2'], ['COFORGE', 'against', 'FOLLOWER', 1820.0, 0.60, 1.5, 0.70, 'LB', 2.2, 3.0, 375, 20, 0.30, 'own: deal win']]
  };
  function expand(c, dir) {
    var o = c[14] || {}, prev = c[3], pct = c[4], ltp = Math.round(prev * (1 + pct / 100) * 100) / 100, atr = +(ltp * 0.021).toFixed(2);
    var up = pct >= 0, lo = up ? prev * 0.999 : ltp * 0.998, hi = up ? ltp * 1.002 : prev * 1.001;
    var vwap = up ? lo + (ltp - lo) * 0.55 : hi - (hi - ltp) * 0.55;
    var m = { sym: c[0], grp: c[1], role: c[2], prev: prev, ltp: ltp, lo: +lo.toFixed(2), hi: +hi.toFixed(2), vwap: +vwap.toFixed(2), orL: +lo.toFixed(2), orH: +(lo + (hi - lo) * 0.45).toFixed(2), atr: atr,
      rvol: c[5], rvUp: c[5] >= 1.5 ? 1 : 0, rs30: c[6], rs15: c[6] * 0.8, sl: Math.abs(c[6]) > 0.4 ? (c[6] > 0 ? '↗' : '↘') : '→', bu: c[7], oi: c[8], buN: +(c[8] * 0.7).toFixed(1), buD: +(c[8] * 1.9).toFixed(1), wt: c[9], lot: c[10], step: c[11], iv: c[12], iv20: +(c[12] - 0.015).toFixed(3),
      spr: 3, sprI: 4, dep: 10, depI: 5, gate: c[13], gok: c[13].charAt(0) === '✓' ? 1 : 0, ai: '', age: '0.4s', side: (dir > 0 ? (ltp > vwap ? 'both' : 'below') : (ltp < vwap ? 'belowboth' : 'vwap')),
      wallC: Math.ceil(ltp * 1.03 / c[11]) * c[11], wallP: Math.floor(ltp * 0.97 / c[11]) * c[11], mwpl: 20, res: 'results in Jan', exd: 'no ex-date', news: [] };
    for (var k in o) m[k] = o[k];
    return m;
  }
  SECTORS.forEach(function (s) { var dir = s.pct >= 0 ? 1 : -1; s.dir = dir; if (!M[s.id]) M[s.id] = (C[s.id] || []).map(function (c) { return expand(c, dir); }); s.members = M[s.id]; });

  // ---------------- per-member maths (all numbers derive from here, so the pane and F7 agree) ----------------
  var GORDER = ['up', 'lead', 'lag', 'with', 'against', 'nt'];
  function optSide(s, m) { var ce = s.dir > 0; if (m.grp === 'against') ce = !ce; return ce ? 'CE' : 'PE'; }
  function strikes(m, cp) { var atm = Math.round(m.ltp / m.step) * m.step; var itm = cp === 'CE' ? atm - m.step : atm + m.step; return [atm, itm]; }
  function quote(m, K, cp, ticks, S) { S = S || m.ltp; var mid = bs(S, K, T, m.iv, cp), sp = ticks * 0.05; var bid = r05(mid - sp / 2); if (bid < 0.05) bid = 0.05; return { mid: mid, bid: bid, ask: +(bid + sp).toFixed(2), sp: sp }; }
  function thetaDay(m, K, cp) { return bs(m.ltp, K, T, m.iv, cp) - bs(m.ltp, K, T - 1 / 365, m.iv, cp); }
  function contract(s, m, which) {
    var cp = optSide(s, m), ks = strikes(m, cp), K = which === 'itm' ? ks[1] : ks[0], ticks = which === 'itm' ? m.sprI : m.spr;
    var q = quote(m, K, cp, ticks), d = delta(m.ltp, K, T, m.iv, cp), th = thetaDay(m, K, cp), thh = th / 6.25;
    var lotCost = q.ask * m.lot, sprLot = q.sp * m.lot, sprPct = q.sp / ((q.bid + q.ask) / 2) * 100;
    var bePts = (thh * HRS_LEFT + q.sp) / Math.abs(d), be = cp === 'CE' ? m.ltp + bePts : m.ltp - bePts;
    var ivK = m.iv - (which === 'itm' ? 0.003 : 0);
    return { cp: cp, K: K, bid: q.bid, ask: q.ask, mid: q.mid, sp: q.sp, sprLot: sprLot, sprPct: sprPct, dep: which === 'itm' ? m.depI : m.dep, d: d, thh: thh * m.lot, iv: ivK, iv20: m.iv20, lotCost: lotCost, be: be, bePts: bePts };
  }
  function plan(s, m) {
    var cp = optSide(s, m), ce = cp === 'CE', tk = tickOf(m.ltp), trig, stop, tgt, how;
    var rising = ce; // option direction
    function rd(x) { return +(Math.round(x / tk) * tk).toFixed(2); }
    if (m.grp === 'lead' && m.ext) { trig = rd(m.vwap); stop = rd(rising ? m.vwap - 0.35 * m.atr : m.vwap + 0.35 * m.atr); tgt = rising ? m.hi : m.lo; how = 'pullback to VWAP ' + fmt(trig, tk < 0.1 ? 2 : 1) + ' / first higher low, 1 lot (minimum)'; if (!rising) how = 'bounce to VWAP ' + fmt(trig, tk < 0.1 ? 2 : 1) + ' / first lower high, 1 lot (minimum)'; }
    else if (m.grp === 'lag') { trig = rising ? rd(m.orH + tk) : rd(m.orL - tk); stop = rd(rising ? m.vwap - 0.25 * m.atr : m.vwap + 0.25 * m.atr); tgt = rd(rising ? trig + 0.6 * m.atr : trig - 0.6 * m.atr); how = '5-min close ' + (rising ? '>' : '<') + ' ' + fmt(trig, tk < 0.1 ? 2 : 1) + ' (OR ' + (rising ? 'high' : 'low') + ')'; }
    else if (rising) { trig = rd(m.hi + tk); stop = rd(Math.floor((m.vwap - 0.1) / tk) * tk); tgt = rd(Math.min(m.lo + m.atr, m.wallC * 0.995)); if (tgt <= trig) tgt = rd(trig + 0.5 * m.atr); how = '5-min close > ' + fmt(trig, tk < 0.1 ? 2 : 1) + ' (day high)'; }
    else { trig = rd(m.lo - tk); stop = rd(Math.ceil((m.vwap + 0.1) / tk) * tk); tgt = rd(Math.max(m.hi - m.atr, m.wallP * 1.005)); if (tgt >= trig) tgt = rd(trig - 0.5 * m.atr); how = '5-min close < ' + fmt(trig, tk < 0.1 ? 2 : 1) + ' (day low)'; }
    var c = contract(s, m, 'atm'), K = c.K, hs = c.sp / 2;
    var pT = r05(bs(trig, K, T, m.iv, cp) + hs), pS = r05(bs(stop, K, T, m.iv, cp) - hs), pG = r05(bs(tgt, K, T, m.iv, cp) - hs);
    var charges = r10(40 + 0.0021 * c.lotCost), slip = r10(hs * m.lot), costs = charges + slip;
    var risk = Math.round((pT - pS) * m.lot + costs), reward = Math.round((pG - pT) * m.lot - costs);
    var fitLock = Math.floor(LOCK / risk), fitR = Math.floor(R1 / risk), lots, lotsTxt;
    if (m.ban) { lots = 0; lotsTxt = '0 lots · BAN - only close existing'; }
    else if (m.stale) { lots = 0; lotsTxt = '0 lots · STALE quote - no GO NOW'; }
    else if (fitLock < 1) { lots = 0; lotsTxt = '0 lots · lock room'; }
    else if (m.ext) { lots = 1; lotsTxt = '1 lot (minimum) - extended'; }
    else if (fitR >= 1) { lots = Math.min(fitR, fitLock); lotsTxt = lots + (lots > 1 ? ' lots' : ' lot') + ' (1R rule)'; }
    else { lots = 1; lotsTxt = '1 lot (minimum) = ' + (risk / R1).toFixed(1) + 'R'; }
    return { cp: cp, trig: trig, stop: stop, tgt: tgt, how: how, pT: pT, pS: pS, pG: pG, charges: charges, slip: slip, costs: costs, risk: risk, reward: reward, rr: reward / risk, fitLock: fitLock, fitR: fitR, lots: lots, lotsTxt: lotsTxt, K: K };
  }
  function room(m) { var used = (m.hi - m.lo) / m.atr; return { used: used, left: Math.max(0, 1 - used) }; }
  function groups(s) { var out = []; GORDER.forEach(function (g) { var a = s.members.filter(function (m) { return m.grp === g; }); if (a.length) out.push({ g: g, items: a }); }); return out; }
  function gLabel(s, g, n) { var up = s.dir > 0, cp = up ? 'CE' : 'PE', ocp = up ? 'PE' : 'CE';
    return { up: [up ? 'COMING UP NOW' : 'COMING DOWN NOW', n + ' · ' + cp], lead: ['LEADER', 'extended ok'], lag: ['LAGGARD', up ? 'may catch up' : 'may catch down'], with: ['WITH SECTOR', 'a gate open'], against: ['AGAINST THE SECTOR (' + n + ')', ocp + ' strike'], nt: ['NOT TRADABLE', 'reason shown'] }[g]; }
  function ideas(s) { var ce = 0, pe = 0; s.members.forEach(function (m) { if (m.grp === 'nt' || m.grp === 'with') return; if (optSide(s, m) === 'CE') ce++; else pe++; }); return { ce: ce, pe: pe }; }
  function fo(s) { var u = 0, d = 0; s.members.forEach(function (m) { if (m.ltp >= m.prev) u++; else d++; }); return { up: u, dn: d, n: s.members.length }; }
  function sideTxt(m) { return { both: 'above both', vwap: 'above VWAP', or: 'above OR', reclaim: 'reclaiming', below: 'below both', belowboth: 'below both' }[m.side] || m.side; }
  function find(sym) { for (var i = 0; i < SECTORS.length; i++) { var a = SECTORS[i].members; for (var j = 0; j < a.length; j++) if (a[j].sym === sym) return { s: SECTORS[i], m: a[j] }; } return null; }
  // synthetic 5-min bars 09:15 -> 11:05 that respect open / low / high / last (seeded by symbol)
  function bars(m) {
    var seed = 0; for (var i = 0; i < m.sym.length; i++) seed = (seed * 31 + m.sym.charCodeAt(i)) % 2147483647;
    function rnd() { seed = (seed * 16807) % 2147483647; return seed / 2147483647; }
    var n = 23, up = m.ltp >= m.prev, open = up ? m.lo + (m.orH - m.lo) * 0.2 : m.hi - (m.hi - m.orL) * 0.2;
    var loAt = up ? 1 : 15, hiAt = up ? 20 : 1, path = [];
    for (var k = 0; k <= n; k++) { var t = k / n, base;
      if (up) base = k <= loAt ? open + (m.lo - open) * (k / loAt) : k <= hiAt ? m.lo + (m.hi - m.lo) * Math.pow((k - loAt) / (hiAt - loAt), 0.9) : m.hi + (m.ltp - m.hi) * ((k - hiAt) / (n - hiAt));
      else base = k <= hiAt ? open + (m.hi - open) * (k / hiAt) : k <= loAt ? m.hi + (m.lo - m.hi) * ((k - hiAt) / (loAt - hiAt)) : m.lo + (m.ltp - m.lo) * ((k - loAt) / (n - loAt));
      path.push(base); }
    var out = [], amp = (m.hi - m.lo) * 0.07;
    for (var b = 0; b < n; b++) { var o = path[b], c = path[b + 1]; if (b > 1 && b < n - 1 && b !== loAt && b !== hiAt) c += (rnd() - 0.5) * amp;
      var h = Math.max(o, c) + rnd() * amp * 0.6, l = Math.min(o, c) - rnd() * amp * 0.6; h = Math.min(h, m.hi); l = Math.max(l, m.lo);
      if (b === hiAt - 1 && up) h = m.hi; if (b === loAt - 1 && !up) l = m.lo; if (b === 0) { up ? (l = m.lo) : (h = m.hi); }
      out.push({ o: o, h: h, l: l, c: c }); path[b + 1] = c; }
    out[n - 1].c = m.ltp; out[n - 1].h = Math.max(out[n - 1].h, m.ltp); out[n - 1].l = Math.min(out[n - 1].l, m.ltp);
    return out;
  }
  return { CLOCK: CLOCK, T: T, HRS_LEFT: HRS_LEFT, R1: R1, LOCK: LOCK, SECTORS: SECTORS, GORDER: GORDER, bs: bs, fmt: fmt, sg: sg, rs: rs, contract: contract, plan: plan, room: room, groups: groups, gLabel: gLabel, ideas: ideas, fo: fo, sideTxt: sideTxt, find: find, bars: bars, optSide: optSide, tickOf: tickOf };
})();
if (typeof module !== 'undefined') module.exports = GD;

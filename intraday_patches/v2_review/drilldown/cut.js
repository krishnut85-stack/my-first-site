() => {
  // every visible leaf-ish cell of the drill-down and of the host sector lists: scrollWidth > clientWidth = cut (no tolerance).
  // Allowed: prose with a tooltip (element or its cell carries a title) - the trader's rule.
  const Q = ['.sdl .sd-r > span', '.sdl .sd-h > span', '.sdl .sd-gh', '.sdl .sd-l1 > *', '.sdl .sd-l2 > *', '.sdl .sd-more', '.sdl .sd-nf', '.sdl .sd-r .sd-role', '.sdl .sd-r .sd-k',
    '.sd-pane .sd-tb td', '.sd-pane .sd-tb th', '.sd-pane .sd-st2', '.sd-pane .sd-act .btn', '.sd-pane .sd-pa .btn',
    '#wt thead th', '#wtb tr.row > td', '#wtb tr.row > td > div', '#bdb .srow > span', '#bdb .srow > span > *', '#secList .srow > span', '#cards .cd3 > *',
    '#flowP .h1', '#flowP .h1 > *', '#flowSide .fs', '#flowSide .fs > *'];
  const seen = new Set(), out = [];
  for (const q of Q) document.querySelectorAll(q).forEach(e => {
    if (seen.has(e)) return; seen.add(e);
    if (!e.getClientRects().length) return; const cs = getComputedStyle(e); if (cs.display === 'none' || cs.visibility === 'hidden') return;
    if (e.closest('[hidden]')) return;
    if (e.scrollWidth > e.clientWidth && e.clientWidth > 0 || (e.clientWidth === 0 && e.scrollWidth > 0 && cs.display !== 'inline')) {
      const txt = (e.innerText || '').replace(/\s+/g, ' ').trim(); const tip = e.closest('[title]');
      const prose = !!(tip && tip.title.length >= txt.length - 3 || tip && e.closest('.sd-why')) && txt.split(' ').length >= 4;
      out.push({q, cls: (e.className || '').toString().slice(0, 30), txt: txt.slice(0, 50), sw: e.scrollWidth, cw: e.clientWidth, prose});
    }
  });
  return out;
}

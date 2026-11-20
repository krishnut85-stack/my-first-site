#!/usr/bin/env python3
"""build_fo_xlsx.py - builds the trader's editable Excel of ALL F&O shares from rallyscan.csv (+ optional pe.json):
zones (overbought / oversold, from editable thresholds), 52-week low / high, move since the NIFTY low, market cap at the low and now,
value added, and - when pe.json is present - VALUATION: P/E now (TTM), sector P/E, EPS (TTM, = close / P/E), P/E at the 52-week high,
P/E at the 52-week low and at the NIFTY low (each = that price / today's TTM EPS), P/E vs sector.
pe.json = {"SBIN": {"pe": 9.8, "sector_pe": 11.2}, ...}  (NSE quote JSON metadata.pdSymbolPe / pdSectorPe; loss-making = null)
  python3 build_fo_xlsx.py <rallyscan.csv> [pe.json] <out.xlsx>"""
import csv, json, sys
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.formatting.rule import FormulaRule

args = sys.argv[1:]
src, out = args[0], args[-1]
PE = json.load(open(args[1])) if len(args) == 3 else {}
R = list(csv.DictReader(open(src)))
F = 'Arial'; hdr = Font(name=F, bold=True, color='FFFFFF'); hfill = PatternFill('solid', fgColor='1F3864')
base = Font(name=F); blue = Font(name=F, color='0000FF'); yel = PatternFill('solid', fgColor='FFFF00')
thin = Side(style='thin', color='BFBFBF'); bd = Border(top=thin, bottom=thin, left=thin, right=thin)
pct = '+0.0%;-0.0%;0.0%'


def f(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


wb = Workbook()
A = wb.active; A.title = 'All F&O shares'
cols = [('Share', 12), ('Sector', 14), ('Zone', 21), ('RSI (14, daily)', 8), ('% above 20-day avg', 10), ('% above 50-day avg', 10),
        ('% from 52-week high', 10), ('Own 52-week low', 10), ('Date of own low', 11), ('Move from own low', 10),
        ('Close at NIFTY low (8 Oct)', 11), ('Last close (19 Nov)', 10), ('Move since NIFTY low', 10), ('Mcap at NIFTY low (Rs cr)', 13),
        ('Mcap now (Rs cr)', 13), ('Mcap added (Rs cr)', 12), ('Shares issued', 14), ('Own 52-week high', 10),
        ('P/E now (TTM)', 9), ('Sector P/E', 9), ('EPS (TTM) = close / P/E', 10), ('P/E at 52-week HIGH', 10),
        ('P/E at 52-week LOW', 10), ('P/E at NIFTY low (8 Oct)', 10), ('P/E vs sector', 9),
        ('My plan (CE / PE / watch)', 16), ('My notes', 28)]
for j, (h, w) in enumerate(cols, start=1):
    c = A.cell(1, j, h); c.font = hdr; c.fill = hfill; c.alignment = Alignment(wrap_text=True, vertical='center'); c.border = bd
    A.column_dimensions[get_column_letter(j)].width = w
A.row_dimensions[1].height = 44; A.freeze_panes = 'D2'
for i, r in enumerate(sorted(R, key=lambda r: -(f(r['rsi14']) or 0)), start=2):
    pe = PE.get(r['share'], {}) or {}
    vals = {1: r['share'], 2: r['sector'], 4: f(r['rsi14']), 5: f(r['pct_above_20dma']) / 100, 6: f(r['pct_above_50dma']) / 100,
            7: f(r['pct_from_52w_high']) / 100, 8: f(r['own_52w_low']), 9: r['own_52w_low_date'],
            10: f(r['move_from_own_52w_low_pct']) / 100, 11: f(r['close_at_nifty_low']), 12: f(r['last_close']),
            13: f(r['move_since_nifty_low_pct']) / 100, 14: f(r['mcap_at_nifty_low_cr']), 15: f(r['mcap_now_cr']),
            17: int(r['shares_issued']) if r['shares_issued'] else None, 18: f(r['own_52w_high']),
            19: f(pe.get('pe')), 20: f(pe.get('sector_pe'))}
    for j, v in vals.items():
        c = A.cell(i, j, v); c.border = bd; c.font = base if j in (1, 2, 9) else blue
        if j in (5, 6, 7, 10, 13): c.number_format = pct
        elif j == 4: c.number_format = '0.0'
        elif j in (8, 11, 12, 18): c.number_format = '#,##0.00'
        elif j in (14, 15, 17): c.number_format = '#,##0'
        elif j in (19, 20): c.number_format = '0.0'
    c = A.cell(i, 3, f'=IF(D{i}="","",IF(OR(D{i}>=Settings!$B$5,E{i}>=Settings!$B$6),"EXTREME OVERBOUGHT",IF(D{i}>=Settings!$B$4,'
                     f'"OVERBOUGHT",IF(D{i}<=Settings!$B$8,"EXTREME OVERSOLD",IF(D{i}<=Settings!$B$7,"OVERSOLD","NEUTRAL")))))')
    c.font = Font(name=F, bold=True); c.border = bd
    c = A.cell(i, 16, f'=IF(OR(N{i}="",O{i}=""),"",O{i}-N{i})'); c.number_format = '+#,##0;-#,##0;0'; c.border = bd; c.font = base
    for j, fm, nf in ((21, f'=IF(OR(S{i}="",S{i}<=0),"",L{i}/S{i})', '#,##0.00'), (22, f'=IF(U{i}="","",R{i}/U{i})', '0.0'),
                      (23, f'=IF(U{i}="","",H{i}/U{i})', '0.0'), (24, f'=IF(U{i}="","",K{i}/U{i})', '0.0'),
                      (25, f'=IF(OR(S{i}="",T{i}="",T{i}<=0),"",S{i}/T{i})', '0.00"x"')):
        c = A.cell(i, j, fm); c.number_format = nf; c.border = bd; c.font = base
    for j in (26, 27):
        c = A.cell(i, j, ''); c.fill = yel; c.border = bd
n = len(R) + 1
A.auto_filter.ref = f'A1:AA{n}'
for txt, col in (('EXTREME OVERBOUGHT', 'F4B183'), ('OVERBOUGHT', 'FCE4D6'), ('EXTREME OVERSOLD', '9BC2E6'), ('OVERSOLD', 'DDEBF7')):
    A.conditional_formatting.add(f'C2:C{n}', FormulaRule(formula=[f'$C2="{txt}"'], fill=PatternFill('solid', fgColor=col)))

S = wb.create_sheet('Sectors')
sc = [('Sector', 16), ('Shares', 8), ('Extreme OB', 9), ('Overbought', 10), ('Neutral', 8), ('Oversold', 9), ('Avg move since NIFTY low', 11),
      ('Mcap at NIFTY low (Rs cr)', 14), ('Mcap now (Rs cr)', 14), ('Mcap added (Rs cr)', 13), ('% of all value added', 10),
      ('Avg P/E (profitable shares)', 10), ('My notes', 26)]
for j, (h, w) in enumerate(sc, start=1):
    c = S.cell(1, j, h); c.font = hdr; c.fill = hfill; c.alignment = Alignment(wrap_text=True, vertical='center'); c.border = bd
    S.column_dimensions[get_column_letter(j)].width = w
S.row_dimensions[1].height = 44; S.freeze_panes = 'B2'
secs = sorted({r['sector'] for r in R}); t = len(secs) + 2
rng = lambda col: f"'All F&O shares'!${col}$2:${col}${n}"
for i, s in enumerate(secs, start=2):
    S.cell(i, 1, s).font = base
    fm = {2: f'=COUNTIF({rng("B")},A{i})', 3: f'=COUNTIFS({rng("B")},A{i},{rng("C")},"EXTREME OVERBOUGHT")',
          4: f'=COUNTIFS({rng("B")},A{i},{rng("C")},"OVERBOUGHT")', 5: f'=COUNTIFS({rng("B")},A{i},{rng("C")},"NEUTRAL")',
          6: f'=COUNTIFS({rng("B")},A{i},{rng("C")},"OVERSOLD")+COUNTIFS({rng("B")},A{i},{rng("C")},"EXTREME OVERSOLD")',
          7: f'=IFERROR(AVERAGEIF({rng("B")},A{i},{rng("M")}),"")', 8: f'=SUMIF({rng("B")},A{i},{rng("N")})',
          9: f'=SUMIF({rng("B")},A{i},{rng("O")})', 10: f'=I{i}-H{i}', 11: f'=IF($J${t}=0,"",J{i}/$J${t})',
          12: f'=IFERROR(AVERAGEIFS({rng("S")},{rng("B")},A{i},{rng("S")},">0"),"")'}
    for j, v in fm.items():
        c = S.cell(i, j, v); c.font = base; c.border = bd
        if j == 7: c.number_format = pct
        elif j in (8, 9, 10): c.number_format = '#,##0'
        elif j == 11: c.number_format = '0.0%'
        elif j == 12: c.number_format = '0.0'
    c = S.cell(i, 13, ''); c.fill = yel; c.border = bd
S.cell(t, 1, 'ALL F&O SHARES').font = Font(name=F, bold=True)
for j, col in ((2, 'B'), (3, 'C'), (4, 'D'), (5, 'E'), (6, 'F'), (8, 'H'), (9, 'I'), (10, 'J')):
    c = S.cell(t, j, f'=SUM({col}2:{col}{t - 1})'); c.font = Font(name=F, bold=True); c.border = bd
    if j >= 8: c.number_format = '#,##0'
S.auto_filter.ref = f'A1:M{t - 1}'

T = wb.create_sheet('Settings')
T['A1'] = 'Overbought / oversold filter - settings (edit the yellow cells; the Zone column updates)'
T['A1'].font = Font(name=F, bold=True, size=12)
for r_, k, v, fmt in ((4, 'OVERBOUGHT: RSI at or above', 70, '0'), (5, 'EXTREME OVERBOUGHT: RSI at or above', 80, '0'),
                      (6, 'EXTREME OVERBOUGHT: or % above 20-day avg', 0.10, '0%'), (7, 'OVERSOLD: RSI at or below', 30, '0'),
                      (8, 'EXTREME OVERSOLD: RSI at or below', 20, '0')):
    T.cell(r_, 1, k).font = base; c = T.cell(r_, 2, v); c.font = blue; c.fill = yel; c.number_format = fmt; c.border = bd
notes = ['HOW TO USE: on "All F&O shares" use the filter arrow on the Zone column; sort by any column. "My plan" / "My notes" are yours.',
         'Data: server scan rallyscan.py, minute store to Thu 19 Nov 2026 close, 218 F&O shares; NIFTY low = Thu 8 Oct 2026 close 22,232.',
         'Market cap = shares issued (NSE) x close. "Mcap added" is the RISE IN VALUE since the NIFTY low, not money actually put in.',
         'P/E: "P/E now" and "Sector P/E" are NSE\'s trailing-12-month figures (blank = loss-making or not available). EPS = close / P/E.',
         '  P/E at the 52-week HIGH / LOW / NIFTY low = that price / TODAY\'S EPS - shows how expensive the share was at each price on',
         '  current earnings (earnings also changed over the year, so it is a guide, not the historical P/E). P/E vs sector > 1 = dearer.',
         'Blue = data from the scan; black = formulas; yellow = yours to edit.',
         'HISTORY (obscan.py, 3 years, 318 cases of RSI >= 80): 81% corrected within 20 trading days (median worst pullback -7.6%),',
         '  yet 62% were higher after 20 days. No fresh breakout CE on EXTREME names; PE only on the turn. Not advice - you decide.']
for i, x in enumerate(notes, start=10):
    T.cell(i, 1, x).font = Font(name=F, italic=True, size=9)
T.column_dimensions['A'].width = 46; T.column_dimensions['B'].width = 10
wb.save(out); print(out, len(R), 'shares,', sum(1 for r in R if (PE.get(r['share']) or {}).get('pe')), 'with P/E')

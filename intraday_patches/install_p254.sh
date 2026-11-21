#!/bin/bash
# PATCH 254 - the F&O ban % on NSE's own measure (13 Nov: "near the ban: BDL 155% · PIIND 146%" - impossible). NSE's combineoi file has
#   "Open Interest" AND "Future Equivalent Open Interest"; the ban is measured on the second (BDL 58.7%, KAYNES 80.1% - in the ban until it falls
#   under 80%). GIR read the first. Now the second (older files without it: as before); the last 90 days are read again.
#   Tested: 3 cases. No restart (the evening study run reads it fresh) - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
cp $D/nsextra.py $D/nsextra.py.bak$TS; cp $D/data/extra.db $D/data/extra.db.bak$TS 2>/dev/null
back(){ cp $D/nsextra.py.bak$TS $D/nsextra.py; [ -f $D/data/extra.db.bak$TS ] && cp $D/data/extra.db.bak$TS $D/data/extra.db; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p254_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p254_patch.py - PATCH 254: the F&O ban % on NSE's own measure (13 Nov: THE WEEK showed "near the ban: BDL 155% · PIIND 146%" - impossible,
the ban is at 95%). NSE's combineoi file now has two columns: "Open Interest" and "Future Equivalent Open Interest" - the ban is measured on
the second (BDL 8,091,424 of 13,786,716 = 58.7%; KAYNES 80.1% - in the ban until it falls under 80%). GIR read the first. Now it reads the
Future Equivalent column when the file has one (older files without it: as before). Usage: python3 p254_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "nsextra.py"); s = open(p, encoding="utf-8").read()
OLD = '''        oi = num(next((r[k] for k in r if "open interest" in k), None))'''
NEW = '''        oi = num(next((r[k] for k in r if "future equivalent" in k or "futeq" in k.replace(" ", "")), None))   # patch 254: NSE's ban measure
        if oi is None:
            oi = num(next((r[k] for k in r if "open interest" in k), None))'''
if NEW in s:
    print("  nsextra.py: the ban % on Future Equivalent OI - already in")
elif s.count(OLD) != 1:
    print("❌ nsextra.py: anchor found %d times" % s.count(OLD)); sys.exit(1)
else:
    open(p, "w", encoding="utf-8").write(s.replace(OLD, NEW)); print("  nsextra.py: the ban % on Future Equivalent OI")
print("patch 254 in")
PY_PATCH
cat > $W/p254test.py <<'PY_TEST'
import sys, os
sys.path.insert(0, os.path.abspath(sys.argv[1]))
import types
for m in ("core",):
    if m not in sys.modules:
        x = types.ModuleType(m); x.BASE = "/tmp"; sys.modules[m] = x
import nsextra as N
NEW = ("Date, ISIN, Scrip Name, NSE Symbol, MWPL, Open Interest, Future Equivalent Open Interest, Limit for Next Day\n"
       "12-NOV-2026,INE918Z01012,KAYNES TECHNOLOGY IND LTD,KAYNES,4679418,5289300,3748774.35974115,No Fresh Positions\n"
       "12-NOV-2026,INE171Z01026,BHARAT DYNAMICS LIMITED,BDL,13786716,21380900,8091424.2304892,5005955\n")
OLD = ("Date, ISIN, Scrip Name, NSE Symbol, MWPL, Open Interest, Limit for Next Day\n"
       "12-NOV-2024,INE918Z01012,KAYNES TECHNOLOGY IND LTD,KAYNES,4679418,4500000,No Fresh Positions\n")
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)))
m = N.parse_mwpl(NEW)
chk("BDL: 58.7% (Future Equivalent OI) - was 155%", round(m["BDL"][2], 1) == 58.7, m.get("BDL"))
chk("KAYNES: 80.1% - in the ban until it falls under 80%", round(m["KAYNES"][2], 1) == 80.1, m.get("KAYNES"))
o = N.parse_mwpl(OLD)
chk("an older file without the Future Equivalent column: read as before (96.2%)", round(o["KAYNES"][2], 1) == 96.2, o.get("KAYNES"))
print("BAN %% test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p254_patch.py $D || back
cd $D && python3 -m py_compile nsextra.py || back
echo "=== test"
python3 $W/p254test.py $D || back
echo "=== the last 90 days read again from NSE (about a minute)"
cd $D && timeout 600 python3 -c "
import sys, sqlite3, datetime as dt; sys.path.insert(0, '$D')
import nsextra
d1 = dt.date.today(); d0 = d1 - dt.timedelta(days=90)
c = nsextra.db(); c.execute(\"delete from fetched where src='mwpl' and d>=?\", (str(d0),)); c.execute('delete from mwpl where d>=?', (str(d0),)); c.commit(); c.close()
print('   files read:', nsextra.fetch_extra(d0, d1, quiet=True, sources=('mwpl',)))
c = nsextra.db(); d = c.execute('select max(d) from mwpl').fetchone()[0]
r = c.execute('select sym, pct from mwpl where d=? and pct>=80 order by pct desc', (d,)).fetchall()
print('   %s - 80%%+ of the limit: %s' % (d, ' · '.join('%s %d%%' % (s, round(p)) for s, p in r) or 'none'))
print('   the highest now: %d%% (was up to 155%%)' % round(c.execute('select max(pct) from mwpl where d=?', (d,)).fetchone()[0] or 0))
" || back
echo "✅ patch 254 done - the ban % is NSE's own measure; THE WEEK and the desk show the right near-ban shares from tomorrow 08:30."
echo "   undo: cp $D/nsextra.py.bak$TS $D/nsextra.py; cp $D/data/extra.db.bak$TS $D/data/extra.db"

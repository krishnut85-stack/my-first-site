#!/bin/bash
# PATCH 383 - 🧭 A RULE STORY THAT NAMES NO COMPANY STILL HITS SHARES (Rama, 17 Nov, ANGELONE: "SEBI may limit bets on leveraged / MTF stock
#   trading - negative for broker stocks"). GIR's market desk had it at 12:59 (Business Today, NDTV Profit; ET Now 13:10, Business Standard
#   13:37) but it names SEBI, not a company - nothing linked it to ANGELONE / BSE / CDSL; the one copy filed under a share came through Google
#   at 13:13, under BSE, read UP. policymap.py (service gir-policymap, every 30 s, 07:00-22:30) reads the market desk's headlines; a
#   regulator / government story on margin trading & F&O rules (brokers, exchanges, depositories), mutual-fund rules (AMCs, registrars),
#   insurance rules, telecom tariffs / dues, RBI rules for lenders, gold-loan or microfinance rules -> each F&O share of that group (at most
#   6) is read by Claude for THAT share (the same reader as every news alert) -> the alert as any news: 🚨 / 📰 rings, 📄 quiet - with
#   "🧭 POLICY ... why this share" and the other shares it touches; filed under the share in news.db with the AI's reading.
#   Once per theme and share in 3 hours, unless the words turn (a denial, a clarification) - those are read again. Needs patch 381.
#   A new service; nothing else restarted. Safe at any hour.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; W=$(mktemp -d)
if grep -q "patch 383" $D/policymap.py 2>/dev/null && [ -f $U/gir-policymap.service ]; then echo "patch 383 - already in"; exit 0; fi
grep -q "def remember" $D/newsalert.py && grep -q "def fresh_since_close" $D/newsalert.py && [ -f $D/data/macro.json ] || { echo "patch 381 (newsalert.remember) or the market desk (data/macro.json) not found - nothing done"; exit 1; }
git -C $R show $B:intraday_patches/policymap.py > $W/policymap.py 2>/dev/null && [ -s $W/policymap.py ] && grep -q "patch 383" $W/policymap.py && python3 -m py_compile $W/policymap.py || { echo "❌ policymap.py not in $B or does not compile - run the git fetch line first; nothing done"; exit 1; }
cp $W/policymap.py $D/policymap.py
back(){ rm -f $D/policymap.py; systemctl disable --now gir-policymap >/dev/null 2>&1; rm -f $U/gir-policymap.service; systemctl daemon-reload; echo "❌ removed again - nothing changed"; exit 1; }
echo "== the test (today's SEBI headlines, the AI and Telegram replaced by stand-ins; news.db not touched)"
cd $D && python3 - <<'PY_TEST' || back
import os, sys, time, tempfile
sys.path.insert(0, os.getcwd())
import policymap as PM, newsalert, newsroom
PM.STATE = os.path.join(tempfile.mkdtemp(), "policymap.json")
OK = []
def chk(n, c):
    OK.append(bool(c)); print("  %s %s" % ("✓" if c else "✗", n))
m = PM.match("SEBI mulls limits on margin trading as retail leverage hits Rs 1.53 lakh crore, says report")
chk("the 12:59 SEBI margin-trading story reaches ANGELONE (%s)" % (", ".join(PM.fo_shares(m[2])) if m else "-"), bool(m) and "ANGELONE" in PM.fo_shares(m[2]))
chk("'SEBI may raise FPI ownership threshold' reaches no group", PM.match("SEBI may raise FPI ownership threshold to 25 per cent") is None)
chk("'Sensex opens higher, Nifty slips' reaches no group", PM.match("Sensex opens higher, Nifty slips marginally despite strong FPI inflows") is None)
chk("'RBI raises risk weights on unsecured loans' reaches the lenders", bool(PM.match("RBI raises risk weights on unsecured consumer loans")))
reads, stored = [], []
def mr(sym, text, src="", when="", kind="", name=""):
    reads.append(sym); up = "not looking to curb" in text
    return {"relevant": True, "side": 1 if up else -1, "level": "important", "known": False, "conf": 0.8, "reason": "test", "watch": "", "model": "test"}
newsalert.model_read = mr; newsalert.remember = lambda *a, **k: []
newsroom.store = lambda con, sym, rows, src="": stored.append((sym, src))
class _C:
    def close(self): pass
newsroom.db = lambda: _C()
sent = []; now = time.time()
out = PM.tick([{"t": now - 600, "src": "Business Today Markets", "h": "SEBI mulls limits on margin trading as retail leverage hits Rs 1.53 lakh crore, says report"},
               {"t": now - 500, "src": "NDTV Profit", "h": "SEBI May Tighten Rules On Leveraged Stock Bets As Margin Funding Hits Record Levels: Report"}], sent.append)
chk("one alert per share of the group, read BEARISH (%d)" % len(out), out and all(s == -1 for _, s, _ in out) and len(out) == len({x[0] for x in out}))
chk("each alert says why the share is linked and what else it touches", all("🧭 POLICY" in t and "the same story touches" in t for _, _, t in out))
chk("each is filed under its share in news.db as POLICY", len(stored) == len(out) and all(s == "POLICY" for _, s in stored))
n1 = len(reads)
out2 = PM.tick([{"t": now - 60, "src": "ET Now", "h": "SEBI may tighten MTF rules, cap leveraged stock bets to curb volatility: Report"}], sent.append)
chk("the same story from another source within 3 h: no alert, no new AI read", not out2 and len(reads) == n1)
out3 = PM.tick([{"t": now - 30, "src": "Moneycontrol", "h": "SEBI is not looking to curb the use of MTF, says chairman"}], sent.append)
chk("SEBI's denial is read again and comes through UP", out3 and all(s == 1 for _, s, _ in out3))
print("  %d of %d checks passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $U/gir-policymap.service <<'UNIT'
[Unit]
Description=GIR policy map - rule stories that name no company -> the F&O shares they hit (policymap.py, patch 383)
After=network-online.target
[Service]
Type=simple
Nice=5
Restart=always
RestartSec=20
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && exec python3 policymap.py run >> data/policymap.log 2>&1'
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable gir-policymap >/dev/null 2>&1 && systemctl restart gir-policymap || back
sleep 4; echo "  gir-policymap: $(systemctl is-active gir-policymap)"; [ "$(systemctl is-active gir-policymap)" = "active" ] || back
echo "✅ patch 383 done - from now, a SEBI / RBI / IRDAI / TRAI / government story on margin trading, F&O rules, mutual funds, insurance, telecom,"
echo "   lending, gold loans or microfinance reaches the F&O shares it hits, read for each share by the AI.   its log: tail -5 $D/data/policymap.log"
echo "   a headline check, nothing sent:  cd $D && python3 policymap.py test \"SEBI may tighten MTF rules\""
echo "   undo: systemctl disable --now gir-policymap; rm $U/gir-policymap.service $D/policymap.py; systemctl daemon-reload"

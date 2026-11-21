#!/bin/bash
# PATCH 257 - the share screen, cleaner (Rama, 13 Nov: "who is pushing comes on top and bottom"; "I need a more professional way"). In a share's own
#   tab on the laptop: the bottom copy of WHO IS PUSHING / IN SIMPLE WORDS is gone; a header band, the desk / ticket / pushing lines and the four
#   panels as rounded cards with space between, readable titles. Nothing moves, no reading changes. Tested in a browser. Page only - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 256" $D/home.html || { echo "patch 256 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p257_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p257_patch.py - PATCH 257: the share screen, cleaner (Rama, 13 Nov: "who is pushing comes on top AND bottom"; "not looking good - I need a more
professional way"). In a share's own tab on the laptop:
  - the bottom copy of WHO IS PUSHING + IN SIMPLE WORDS is gone (the top strip has it, "all 12 ▾" opens the 12)
  - a calm look: a header band (big name and price), the desk / ticket / pushing lines as rounded cards, the four panels as cards with space
    between them, readable panel titles, the numbers in one monospace font, the info boxes at the bottom as cards
Nothing moves and no reading changes - only how it looks. The home tab and the phone are unchanged. Page only. Usage: python3 p257_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
CSS = '''/* patch 257: the share screen, cleaner (laptop, a share's own tab) */
@media(min-width:900px){
  body.solo #focus{background:#0A0E15;padding-bottom:16px}
  body.solo #focus .hd{padding:14px 20px;gap:14px;background:#0D121B;border-bottom:1px solid #1C2433;box-shadow:none;align-items:center}
  body.solo #focus .hd>b{font:700 26px/1.1 var(--ui);letter-spacing:.02em;color:#F2F5F9}
  body.solo #focus .hd .px{font:600 24px/1.1 var(--mono)}
  body.solo #focus .hd .dim{font-size:12px}
  body.solo #focus .hd .sct{font-size:13px;padding:5px 10px;border:1px solid #1C2433;border-radius:999px;background:#121826}
  body.solo #focus>.m,body.solo #focus>.tk,body.solo #focus>.scn,body.solo #focus>[class*="scn"],body.solo #focus>#ppStrip{margin:10px 16px 0}
  body.solo #focus>.m{border:1px solid #1C2433;border-radius:10px;background:#121826;padding:10px 14px;font:600 14px/1.4 var(--ui)}
  body.solo #focus>.tk{border:1px solid #3A2D12;border-left:4px solid var(--amber);border-radius:10px;background:#17130A;padding:10px 14px;font:500 14px/1.4 var(--mono)}
  body.solo #focus .pps{border:1px solid #1C2433;border-radius:10px;background:#121826;padding:10px 14px;margin:0;font-size:13px}
  body.solo #focus .ppp{border-radius:8px;padding:10px 14px;font-size:14px}
  body.solo #focus .ws{gap:12px;background:transparent;padding:12px 16px 0;box-sizing:border-box}
  body.solo #focus .ws>div{background:#121826;border:1px solid #1C2433;border-radius:12px;overflow:auto;min-width:0}
  body.solo #focus .wsh{padding:10px 14px;font:700 12px/1.2 var(--ui);letter-spacing:.06em;background:#0F1520;border-bottom:1px solid #1C2433}
  body.solo #focus .wsh span{font-weight:500;letter-spacing:0;color:#8C96A8}
  body.solo #wsDesk{padding:0 16px}
  body.solo #focus .shi{gap:10px;background:transparent;border:0;margin-top:12px}
  body.solo #focus .shi>div{background:#121826;border:1px solid #1C2433;border-radius:10px;padding:10px 14px;font-size:12.5px;line-height:1.5}
  body.solo #focus .shi>div small{display:block;color:#8C96A8;font:700 11px var(--ui);letter-spacing:.06em;margin-bottom:4px}
  body.solo #focus .shi .pwb{display:none !important}   /* the copy of WHO IS PUSHING - the top strip has it */
}
</style>'''
if "patch 257" in s:
    print("  home.html: the share screen, cleaner - already in")
elif s.count("</style>") != 1:
    print("❌ home.html: </style> found %d times" % s.count("</style>")); sys.exit(1)
else:
    open(p, "w", encoding="utf-8").write(s.replace("</style>", CSS)); print("  home.html: the share screen, cleaner · the bottom WHO IS PUSHING copy gone")
print("patch 257 in")
PY_PATCH
python3 $W/p257_patch.py $D || back
echo "✅ patch 257 done - reload the share tab (Ctrl + Shift + R)."
echo "   don't like it? undo: cp $D/home.html.bak$TS $D/home.html"

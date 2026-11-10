#!/bin/bash
# PATCH 162 - 📺 TV WATCH: GIR listens to CNBC-TV18 live all session (09:00-15:40, NSE trading days), reads the speech every 20 s, and when a
#   company is named with shock-type news (regulator, fraud, boss quits, order, deal, approval, policy) says it at once as ⚠️ SHOCK WATCH
#   (Box Picks, rings) / 📰 SHOCK WATCH (News topic, quiet), with the words heard on air. ~40-70 s from the words on air to Telegram.
#   + SHOCK WATCH's first line now reads "▲ SHARE · REASON" (the page files it under the share, not under "ORDER").
#   Uses the tool folder set up by tvprobe.sh (/home/globalbot/tvenv + cookies). No GIR restart. Safe any time.
set -u
D=/home/globalbot/intraday; V=/home/globalbot/tvenv; U=/etc/systemd/system
[ -x $V/bin/python ] && $V/bin/python -c "import faster_whisper" 2>/dev/null || { echo "the TV tool folder is not ready - run tvprobe.sh first"; exit 1; }
[ -f $D/shockwatch.py ] || { echo "run shocks.sh (patch 161) first"; exit 1; }
[ -f $V/cookies.txt ] || echo "   note: no YouTube cookies in $V/cookies.txt - YouTube may refuse the server"
echo "== 1. the files"
for f in shockwatch.py p161test.py; do cp $D/$f $D/$f.bak162 2>/dev/null; done
cat > $D/tvstt.py <<'TVSTT_PY'
#!/usr/bin/env python3
"""tvstt.py - patch 162: the speech reader for 📺 TV WATCH. Runs in /home/globalbot/tvenv (faster-whisper). Loads the model ONCE, then
reads one line per recording on stdin ("path<TAB>lang") and writes one JSON line per recording on stdout:
  {"path": ..., "text": ..., "secs": length, "took": seconds, "level": loudness}
  tvstt.py <model> <threads> <prompt file>"""
import sys, json, time, wave
import numpy as np
from faster_whisper import WhisperModel

size, threads = sys.argv[1], int(sys.argv[2])
try:
    prompt = open(sys.argv[3]).read().strip()[:600]
except Exception:
    prompt = ""
m = WhisperModel(size, device="cpu", compute_type="int8", cpu_threads=threads)
print(json.dumps({"ready": size}), flush=True)
for line in sys.stdin:
    try:
        path, lang = line.rstrip("\n").split("\t")
        w = wave.open(path)
        a = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768.0
        lv = float(np.sqrt(np.mean(a ** 2))) if len(a) else 0.0
        t0 = time.time()
        txt = ""
        if lv >= 0.004:
            segs, _ = m.transcribe(a, language=lang, task="translate" if lang == "hi" else "transcribe", vad_filter=True, beam_size=1,
                                   initial_prompt=prompt or None, condition_on_previous_text=False)
            txt = " ".join(s.text.strip() for s in segs)
        print(json.dumps({"path": path, "text": txt, "secs": round(len(a) / 16000.0, 1), "took": round(time.time() - t0, 1), "level": round(lv, 4)}), flush=True)
    except Exception as ex:
        print(json.dumps({"path": line.strip(), "error": str(ex)[:200]}), flush=True)
TVSTT_PY
cat > $D/tvwatch.py <<'TVWATCH_PY'
#!/usr/bin/env python3
"""tvwatch.py - patch 162: 📺 TV WATCH (Rama: "make someone watch the live TV" · "how fast can the bot find these"). Listens to business
TV live on YouTube all session (09:00-15:40 on NSE trading days) and turns the speech into text every 20 seconds:
  CNBC-TV18 (English) by default; CNBC Awaaz / Zee Business (Hindi -> English) / ET Now / Sansad TV can be added in data/tvwatch.json
When the anchors or a reporter name an F&O company together with the kind of news that moved F&O shares 8%+ in the last years
(circuits.py: a regulator acting, governance trouble, a boss quitting, an order / deal / approval, a policy) it says it at once as a
⚠️ SHOCK WATCH (GIR Box Picks, rings) or 📰 SHOCK WATCH (News topic, quiet) - the same rules as the news / filings watcher, with the
words heard on air. Every transcript is kept in data/tv.db (the page can show it). About 40-70 s from the words on air to Telegram.
  python3 tvwatch.py run        the service (gir-tvwatch) - restarts the stream by itself when YouTube drops it
  python3 tvwatch.py once       one 20-second listen of each channel now, printed (nothing sent) - a check
data/tvwatch.json: {"channels": ["CNBC-TV18"], "model": "base", "threads": 2, "always": false}  ("always": true = listen outside hours)"""
import os, re, sys, json, time, glob, signal, sqlite3, subprocess, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
V = os.environ.get("GIR_TVENV", "/home/globalbot/tvenv")
TMP = "/tmp/tvwatch"
DB = os.path.join(BASE, "data", "tv.db")
CONF = os.path.join(BASE, "data", "tvwatch.json")
STATUS = os.path.join(BASE, "data", "tvwatch_status.json")
LOG = os.path.join(BASE, "data", "tvwatch.log")
SEG = 20
CHANNELS = {"CNBC-TV18": ("https://www.youtube.com/@cnbc-tv18/live", "en"), "CNBC AWAAZ": ("https://www.youtube.com/@CNBCAwaaz/live", "hi"),
            "ZEE BUSINESS": ("https://www.youtube.com/@ZeeBusiness/live", "hi"), "ET NOW": ("https://www.youtube.com/@etnow/live", "en"),
            "SANSAD TV": ("https://www.youtube.com/@SansadTV/live", "hi")}
DEFAULT = {"channels": ["CNBC-TV18"], "model": "base", "threads": 2, "always": False}
FLASH = re.compile(r"breaking|just in|news flash|newsflash|sources (?:say|said|tell)|according to sources|exclusive|we are just getting|this just in", re.I)
TV_KEEP = ("REGULATOR", "GOVERNANCE", "MGMT", "ORDER", "DEAL", "POLICY")


def log(msg):
    line = "%s %s" % (dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"), msg)
    print(line, flush=True)
    try:
        open(LOG, "a").write(line + "\n")
    except Exception:
        pass


def conf():
    c = dict(DEFAULT)
    try:
        c.update(json.load(open(CONF)))
    except Exception:
        pass
    c["channels"] = [x for x in c["channels"] if x in CHANNELS] or ["CNBC-TV18"]
    return c


def window(now, c):
    """listen on NSE trading days 08:55-15:40 (or always, when asked)"""
    if c.get("always"):
        return True
    if now.weekday() >= 5 or not (dt.time(8, 55) <= now.time() <= dt.time(15, 40)):
        return False
    try:
        import holidays
        return not holidays.holiday(now.date())
    except Exception:
        return True


# ---------------------------------------------------------------- what was said -> findings
def scan(ch, text, prev, match, now):
    """-> [finding] for one 20-s transcript (with the end of the one before, so a sentence cut in two is still read)"""
    import circuits as C
    whole = ((prev or "")[-240:] + " " + (text or "")).strip()
    out = []
    for s in match(whole):
        pos = []
        for n in (NM.get(s) or [s]):
            fl = 0 if (n.isupper() and len(n) <= 5) else re.I
            pos += [m.start() for m in re.finditer(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(n), whole, fl)]
        i = max(pos) if pos else 0
        win = whole[max(0, i - 220): i + 260]
        r = C.reason_of(win)
        if r not in TV_KEEP:
            continue
        sd = C.side_of(win)
        if sd == 0:
            if r in ("REGULATOR", "GOVERNANCE"):
                sd = -1                                   # a regulator / governance story with no word either way: trouble until it says otherwise
            else:
                continue
        flash = bool(FLASH.search(win))
        out.append({"key": "TV:%s:%s" % (s, r), "sym": s, "reason": r, "side": sd, "head": "on air: “%s”" % re.sub(r"\s+", " ", win).strip()[:300],
                    "src": "TV %s" % ch, "link": "", "circ": flash})
    return out


NM = {}


def fo_names():
    import circuits as C, shockwatch as W
    fo = W.fo_syms()
    NM.clear(); NM.update(C.names(fo))
    return W.matcher(NM)


def prompt_text():
    names = []
    for s, L in sorted(NM.items()):
        if L:
            names.append(L[0])
    return ("Indian stock market news on business TV. Nifty, Sensex, Bank Nifty, F&O, crore, RBI, SEBI, IRDAI, USFDA. Companies: " + ", ".join(names))[:600]


# ---------------------------------------------------------------- the stream -> 20-s recordings
def stream_url(url):
    cmd = [os.path.join(V, "bin", "yt-dlp"), "-q", "--no-warnings", "-f", "bestaudio/best", "-g"]
    if os.path.exists(os.path.join(V, "bin", "deno")):
        cmd += ["--js-runtimes", "deno:" + os.path.join(V, "bin", "deno")]
    if os.path.exists(os.path.join(V, "cookies.txt")):
        cmd += ["--cookies", os.path.join(V, "cookies.txt")]
    env = dict(os.environ, PATH=os.path.join(V, "bin") + ":" + os.environ.get("PATH", ""))
    r = subprocess.run(cmd + [url], capture_output=True, text=True, timeout=90, env=env)
    u = (r.stdout or "").strip().split("\n")[0]
    if not u:
        raise RuntimeError((r.stderr or "no stream")[-160:].replace("\n", " "))
    return u


class Feed:
    def __init__(self, ch):
        self.ch, (self.url, self.lang) = ch, CHANNELS[ch]
        self.tag = re.sub(r"\W+", "", ch).lower()
        self.proc, self.fails, self.next_try = None, 0, 0.0

    def start(self):
        os.makedirs(TMP, exist_ok=True)
        for f in glob.glob(os.path.join(TMP, self.tag + "_*.wav")):
            os.remove(f)
        u = stream_url(self.url)
        self.proc = subprocess.Popen(["nice", "-n", "12", "ffmpeg", "-nostdin", "-loglevel", "error", "-i", u, "-vn", "-ac", "1", "-ar", "16000",
                                      "-c:a", "pcm_s16le", "-f", "segment", "-segment_time", str(SEG), "-reset_timestamps", "1",
                                      os.path.join(TMP, self.tag + "_%06d.wav")], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        log("%s: listening" % self.ch)

    def alive(self):
        return self.proc is not None and self.proc.poll() is None

    def stop(self):
        if self.alive():
            self.proc.terminate()
            try:
                self.proc.wait(5)
            except Exception:
                self.proc.kill()
        self.proc = None

    def chunks(self):
        """finished recordings, oldest first (the newest is still being written)"""
        fs = sorted(glob.glob(os.path.join(TMP, self.tag + "_*.wav")))
        return fs[:-1] if self.alive() else fs


class Worker:
    """the speech reader in the tool folder's Python, kept running (the model loads once)"""
    def __init__(self, c, cmd=None):
        pf = os.path.join(TMP, "prompt.txt")
        os.makedirs(TMP, exist_ok=True)
        open(pf, "w").write(prompt_text())
        py = os.path.join(V, "bin", "python")
        self.p = subprocess.Popen(cmd or ["nice", "-n", "10", py, os.path.join(BASE, "tvstt.py"), c["model"], str(c["threads"]), pf],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(os.path.join(TMP, "tvstt.err"), "w"), text=True, bufsize=1)
        first = json.loads(self.p.stdout.readline() or "{}")
        if not first.get("ready"):
            try:
                err = open(os.path.join(TMP, "tvstt.err")).read().strip().splitlines()[-1:]
            except Exception:
                err = []
            raise RuntimeError("the speech reader did not start: %s" % (err[0][:200] if err else "no answer"))

    def read(self, path, lang):
        self.p.stdin.write("%s\t%s\n" % (path, lang)); self.p.stdin.flush()
        return json.loads(self.p.stdout.readline() or "{}")

    def stop(self):
        try:
            self.p.terminate()
        except Exception:
            pass


def keep(ch, ts, r):
    try:
        os.makedirs(os.path.dirname(DB), exist_ok=True)
        c = sqlite3.connect(DB, timeout=5)
        c.execute("create table if not exists tv(ts real, ch text, text text, secs real, took real, level real)")
        c.execute("insert into tv values(?,?,?,?,?,?)", (ts, ch, r.get("text") or "", r.get("secs") or 0, r.get("took") or 0, r.get("level") or 0))
        c.execute("delete from tv where ts < ?", (ts - 10 * 86400,))
        c.commit(); c.close()
    except Exception as ex:
        log("tv.db: %s" % ex)


def run(send=None):
    import shockwatch as W
    signal.signal(signal.SIGTERM, lambda *a: sys.exit(0))
    match = fo_names()
    try:
        H = json.load(open(W.HIST))
    except Exception:
        H = {}
    feeds, worker, prev, said = {}, None, {}, {}
    st = {}
    while True:
        c = conf()
        now = dt.datetime.now(IST)
        if not window(now, c):
            if feeds or worker:
                for f in feeds.values():
                    f.stop()
                feeds = {}
                if worker:
                    worker.stop(); worker = None
                log("outside market hours - not listening")
            time.sleep(60)
            continue
        if worker is None:
            worker = Worker(c)
            log("speech reader ready (%s, %d threads)" % (c["model"], c["threads"]))
        for ch in c["channels"]:
            f = feeds.setdefault(ch, Feed(ch))
            if not f.alive() and time.time() >= f.next_try:
                try:
                    f.start(); f.fails = 0
                except Exception as ex:
                    f.fails += 1; f.next_try = time.time() + min(600, 30 * f.fails)
                    log("%s: no stream (%s) - again in %d s" % (ch, str(ex)[:120], min(600, 30 * f.fails)))
                    if f.fails == 5 and send:                # say it once, so a dead TV feed is never silent
                        hint = " - the YouTube sign-in may have expired: export the cookies again" if re.search(r"sign in|bot|cookies", str(ex), re.I) else ""
                        send("📋 TV WATCH: %s - no stream since %s (%s)%s" % (ch, now.strftime("%H:%M"), str(ex)[:120], hint))
        for ch, f in list(feeds.items()):
            if ch not in c["channels"]:
                f.stop(); del feeds[ch]; continue
            fs = f.chunks()
            if len(fs) > 4:                                  # behind: drop the old ones, stay live
                for x in fs[:-2]:
                    os.remove(x)
                log("%s: %d recordings behind - skipped to live" % (ch, len(fs) - 2))
                fs = fs[-2:]
            for path in fs:
                ts = time.time()
                try:
                    r = worker.read(path, f.lang)
                except Exception as ex:
                    log("speech reader: %s - restarting it" % ex); worker.stop(); worker = None; break
                try:
                    os.remove(path)
                except Exception:
                    pass
                txt = (r.get("text") or "").strip()
                keep(ch, ts, r)
                st[ch] = {"t": now.strftime("%H:%M:%S"), "took": r.get("took"), "level": r.get("level"), "said": txt[:160]}
                if txt:
                    log("%s %.0fs read in %.0fs: %s" % (ch, r.get("secs") or 0, r.get("took") or 0, txt[:150]))
                    for x in scan(ch, txt, prev.get(ch), match, now):
                        k = (x["sym"], x["reason"])
                        if time.time() - said.get(k, 0) < 1800:
                            continue
                        said[k] = time.time()
                        msg = W.line(x, H, dt.datetime.now(IST))
                        log("ALERT " + msg.split("\n")[0])
                        if send:
                            send(msg)
                prev[ch] = txt
            if worker is None:
                break
        try:
            json.dump({"at": now.strftime("%H:%M:%S"), "channels": st}, open(STATUS, "w"))
        except Exception:
            pass
        time.sleep(2)


def once():
    """one 20-s listen of each channel now (a check - nothing sent)"""
    c = conf()
    fo_names()
    w = Worker(c)
    print("speech reader ready (%s)" % c["model"])
    os.makedirs(TMP, exist_ok=True)
    for ch in c["channels"]:
        url, lang = CHANNELS[ch]
        try:
            u = stream_url(url)
        except Exception as ex:
            print("%s: no stream - %s" % (ch, str(ex)[:120])); continue
        p = os.path.join(TMP, "once.wav")
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", u, "-t", str(SEG), "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", p], timeout=90)
        r = w.read(p, lang)
        print("%s: %.0f s of TV read in %.0f s · loudness %.3f%s" % (ch, r.get("secs") or 0, r.get("took") or 0, r.get("level") or 0, "" if (r.get("level") or 0) >= 0.004 else " (silent)"))
        print("  heard: %s" % ((r.get("text") or "-")[:400]))
    w.stop()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "once"
    if cmd == "once":
        once()
    elif cmd == "run":
        snd = None
        if "--send" in sys.argv:
            import opencall
            snd = opencall.send_tg
        run(snd)
TVWATCH_PY
cat > $D/shockwatch.py <<'SHOCKWATCH_PY'
#!/usr/bin/env python3
"""shockwatch.py - patch 161: ⚠️ SHOCK WATCH (Rama, 10 Nov: "if the same kind of thing is brewing, alert me and I will keep a watch on
that share"). Every 5 minutes, day and night, it looks for the kinds of news that sent F&O shares 8-20% in a day in the last 3 years
(circuits.py), BOTH WAYS:
  ▼ a regulator acting (RBI / SEBI / IRDAI / USFDA / CCI / ED / tax), a governance problem (fraud, auditor quits, short seller,
    accounting), a top boss leaving, a "lower circuit" story
  ▲ a regulator approval (USFDA approval / clean EIR), an open offer / buyback / stake buy, an order of Rs 1,000 crore+, an "upper circuit" story
  * the share's own NSE filings, already read by GIR's EXCHANGE DIRECT (filings.db) - a REG / MGMT filing against the company
  * Google News: a set of searches for those words in the last hour, kept only when the headline names an F&O company
Each one is said ONCE with that share's own past shocks and what such news did to F&O shares: ⚠️ in GIR Box Picks (rings);
the smaller ▲ ones (an order under Rs 1,000 crore, a deal story) as 📰 in the News topic (quiet).
The first run only remembers what is there (no flood).
  python3 shockwatch.py probe      what it would say now (nothing sent, nothing remembered)
  python3 shockwatch.py --send     one pass (the timer runs this every 5 minutes)"""
import os, re, sys, json, time, html, sqlite3, datetime as dt
from urllib.parse import quote

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import circuits as C

IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
SEEN = os.path.join(BASE, "data", "shockwatch.json")
HIST = os.path.join(BASE, "data", "h3", "circuits.json")
QUERIES = ["RBI imposes", "RBI bars", "RBI restrictions bank", "SEBI order", "SEBI bans", "SEBI show cause", "IRDAI", "USFDA warning letter",
           "import alert USFDA", "Form 483", "OAI USFDA", "CCI penalty", "ED raid company", "income tax search company", "GST demand notice",
           "auditor resigns", "forensic audit", "short seller report", "fraud shares", "accounting lapses", "CEO resigns shares", "shares crash regulator",
           "lower circuit", "upper circuit", "bags order worth crore", "wins order worth crore", "USFDA approval", "EIR USFDA",
           "open offer shares", "buyback shares", "acquire stake", "shares zoom order"]
KEEP = ("REGULATOR", "GOVERNANCE", "MGMT")
KEEP_UP = ("REGULATOR", "ORDER", "DEAL", "POLICY")
PER_RUN = 8                                   # searches per pass: all of them every 15 minutes (Google is not asked too often)


def fo_syms():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True)
        v = [r[0] for r in c.execute("select sym from fo_list")]
        c.close()
        return v
    except Exception:
        return []


def matcher(NM):
    """-> f(title) -> [syms named in it]"""
    pats = []
    for s, L in NM.items():
        for n in L:
            n = n.strip()
            if len(n) < 3:
                continue
            flags = 0 if (n.isupper() and len(n) <= 5) else re.I        # short tickers (SBI, HAL, LIC) only in capitals
            pats.append((s, re.compile(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(n), flags)))
    def f(t):
        out = []
        for s, rx in pats:
            if s not in out and rx.search(t or ""):
                out.append(s)
        return out
    return f


def gnews(q, get=None):
    url = "https://news.google.com/rss/search?q=%s&hl=en-IN&gl=IN&ceid=IN:en" % quote(q + " when:1h")
    if get:
        txt = get(url)
    else:
        import requests
        r = requests.get(url, headers=C.UA, timeout=(5, 10))
        txt = r.text if r.status_code == 200 else ""
    out = []
    for m in re.finditer(r"<item>(.*?)</item>", txt or "", re.S):
        t = re.search(r"<title>(.*?)</title>", m.group(1), re.S)
        l = re.search(r"<link>(.*?)</link>", m.group(1), re.S)
        if t:
            out.append((html.unescape(re.sub(r"<!\[CDATA\[|\]\]>", "", t.group(1))).strip(), l.group(1).strip() if l else ""))
    return out


def filings_new(since, fo):
    p = os.path.join(BASE, "filings.db")
    if not os.path.exists(p):
        return []
    try:
        c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=3)
        rows = c.execute("select key, sym, kind, side, subject, detail, link, t_exch from filings where t_seen > ? and kind in ('REG','MGMT','OTHER','BOARD')",
                         (since,)).fetchall()
        c.close()
    except Exception:
        return []
    out = []
    for key, s, kind, side, subj, det, link, te in rows:
        if s not in fo:
            continue
        txt = "%s %s" % (subj or "", (det or "")[:300])
        r = "REGULATOR" if kind == "REG" else "MGMT" if kind == "MGMT" else ("GOVERNANCE" if C.reason_of(txt) == "GOVERNANCE" else None)
        if not r or (kind in ("REG", "MGMT") and (side or 0) > 0 and r != "REGULATOR"):
            continue
        out.append({"key": "F:" + str(key), "sym": s, "reason": r, "side": side or C.side_of(txt) or -1, "head": (subj or "")[:200],
                    "src": "NSE filing", "link": link or ""})
    return out


def history_lines(H, sym, reason, side):
    L = []
    H = dict(H or {}); H["from"] = (H.get("from") or "")[:4] or "2022"
    mine = (H.get("by_sym") or {}).get(sym) or []
    if mine:
        L.append("%s's own shocks since %s: %d · %s" % (sym, (H.get("from") or "")[:4], len(mine), " · ".join("%s %+.0f%% %s" % (x["d"], x["mv"], x["reason"]) for x in mine[-3:])))
    else:
        L.append("%s: no 8%%+ shock since %s" % (sym, (H.get("from") or "")[:4]))
    b = (H.get("by_reason") or {}).get("%s:%d" % (reason, -1 if side < 0 else 1))
    if b and b.get("n"):
        L.append("%s news behind %d F&O shocks %s since %s · avg %+.1f%% that day, %+.1f%% the next" % (reason, b["n"], "▼" if side < 0 else "▲", (H.get("from") or "")[:4], b["mv"], b["next"]))
    return L


def rings(x):
    """▼ always rings; ▲ rings for an approval, an open offer / buyback, an upper-circuit story, an order of Rs 1,000 crore+"""
    if x["side"] < 0 or x.get("circ") or x["reason"] == "REGULATOR":
        return True
    if x["reason"] == "DEAL" and re.search(r"open offer|buy-?back|acquire|stake", x["head"], re.I):
        return True
    if x["reason"] == "ORDER":
        amt = 0.0
        try:
            import exchange
            amt = exchange.amount_cr(x["head"])
        except Exception:
            pass
        for m in re.finditer(r"([\d,]+(?:\.\d+)?)\s*(?:crore|cr\b)", x["head"], re.I):      # spoken: "2,500 crore rupees"
            try:
                amt = max(amt, float(m.group(1).replace(",", "")))
            except ValueError:
                pass
        return amt >= 1000
    return False


def line(x, H, now):
    arrow = "▼" if x["side"] < 0 else "▲"
    hint = ("bearish news: PE side only if the price confirms (breaks the first 15-min low); no fresh CE" if x["side"] < 0
            else "bullish news: CE side only if the price confirms (holds above the first 15-min high)")
    return "\n".join(["%s SHOCK WATCH · %s %s · %s · %s %s" % ("⚠️" if rings(x) else "📰", arrow, x["sym"], x["reason"], x["src"], now.strftime("%H:%M")), x["head"][:300]]
                     + history_lines(H, x["sym"], x["reason"], x["side"]) + ["watch: " + hint] + ([x["link"]] if x.get("link") else []))


def run(send=None, get=None, now=None, probe=False, fo=None):
    now = now or dt.datetime.now(IST)
    try:
        Sx = json.load(open(SEEN))
    except Exception:
        Sx = {"seen": [], "first": True, "since": time.time() - 3600}
    seen = set(Sx.get("seen") or [])
    try:
        H = json.load(open(HIST))
    except Exception:
        H = {}
    fo = fo if fo is not None else fo_syms()
    NM = C.names(fo, get)
    match = matcher(NM)
    found = filings_new(Sx.get("since") or 0, set(fo))
    qi = int(Sx.get("qi") or 0) % len(QUERIES)
    batch = (QUERIES + QUERIES)[qi:qi + PER_RUN]
    Sx["qi"] = (qi + PER_RUN) % len(QUERIES)
    for q in batch:
        try:
            items = gnews(q, get)
        except Exception:
            continue
        for t, l in items[:15]:
            circ = re.search(r"(upper|lower) circuit", t, re.I)
            r, sd = C.reason_of(t), C.side_of(t)
            if circ:
                sd = -1 if circ.group(1).lower() == "lower" else 1
            if not circ and not ((sd < 0 and r in KEEP) or (sd > 0 and r in KEEP_UP)):
                continue
            for s in match(t)[:2]:
                found.append({"key": "N:%s:%s" % (s, re.sub(r"\W+", "", t.lower())[:80]), "sym": s, "reason": r or "MOVE", "side": sd,
                              "head": t, "src": "news", "link": l, "circ": bool(circ)})
    out, report = [], []
    for x in found:
        k = x["key"]
        report.append("%s %s %s: %s" % (x["sym"], x["reason"], x["src"], x["head"][:90]))
        if k in seen:
            continue
        seen.add(k)
        if not Sx.get("first"):
            out.append(line(x, H, now))
    if probe:
        return report or ["nothing found now (%d F&O names watched, %d searches)" % (len(NM), len(QUERIES))]
    Sx["first"] = False
    Sx["since"] = time.time()
    Sx["seen"] = list(seen)[-4000:]
    os.makedirs(os.path.dirname(SEEN), exist_ok=True)
    json.dump(Sx, open(SEEN, "w"))
    if send:
        for x in out[:6]:
            send(x)
    return out


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "probe":
        print("\n".join(run(probe=True)))
        sys.exit(0)
    snd = None
    if "--send" in sys.argv:
        import opencall
        snd = opencall.send_tg
    for x in run(snd):
        print(x + "\n")
SHOCKWATCH_PY
cat > $D/p161test.py <<'P161TEST_PY'
#!/usr/bin/env python3
"""p161test.py - patch 161: the shock-day study and SHOCK WATCH on made-up data (no network, nothing sent, real files untouched)"""
import os, sys, json, shutil, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import circuits as C, shockwatch as W

ok = True
def check(name, cond):
    global ok
    print(("  ok   " if cond else "  FAIL ") + name)
    ok = ok and bool(cond)

T = tempfile.mkdtemp()
C.CACHE = os.path.join(T, "shock_reasons.json"); C.NAMES = os.path.join(T, "fo_names.json")
W.SEEN = os.path.join(T, "shockwatch.json"); W.HIST = os.path.join(T, "circuits.json")
C.S.H3 = T
W.PER_RUN = len(W.QUERIES)

# 60 trading days; PBFINTECH falls 20% on day 40 (an IRDAI penalty filed that morning), TCS rises 9% on day 45 (results), NIFTY flat
d0 = dt.date(2025, 3, 3)
days = []
d = d0
while len(days) < 60:
    if d.weekday() < 5:
        days.append(str(d))
    d += dt.timedelta(days=1)
def series(jumps):
    out, c = {}, 100.0
    for i, k in enumerate(days):
        pc = c
        c = c * (1 + jumps.get(i, 0.0))
        out[k] = (pc, max(pc, c) * 1.002, min(pc, c) * 0.998, c, 1000.0 * (3 if i == 39 else 1))
    return out
DAY = {"PBFINTECH": series({40: -0.20, 36: -0.012, 37: -0.015, 38: -0.01, 39: -0.02}), "TCS": series({45: 0.09}), "INFY": series({}), "NIFTY 50": series({})}
syms = ["PBFINTECH", "TCS", "INFY"]
shocks, base, tot = C.find(syms, DAY, {})
check("find: 2 shocks (PBFINTECH ▼ -20%, TCS ▲ +9%)", sorted((x["sym"], x["side"]) for x in shocks) == [("PBFINTECH", -1), ("TCS", 1)])
pb = [x for x in shocks if x["sym"] == "PBFINTECH"][0]
check("the signs before PBFINTECH's fall: fell 5%+ in 5 days, volume 2x+", "fell 5%+ in the 5 days before" in pb["signs"] and "volume 2x+ the day before" in pb["signs"])
check("the next day / 5 days filled", pb["next"] is not None and pb["n5"] is not None)

D40 = dt.date.fromisoformat(days[40])
def getj(path):
    if "PBFINTECH" in path:
        return [{"symbol": "PBFINTECH", "desc": "Action(s) taken or orders passed", "attchmntText": "IRDAI has imposed a penalty of Rs 5 crore on Policybazaar Insurance Brokers",
                 "an_dt": D40.strftime("%d-%b-%Y") + " 08:10:00"},
                {"symbol": "PBFINTECH", "desc": "Action(s) taken or orders passed", "attchmntText": "IRDAI inspection observations and show cause notice received",
                 "an_dt": (D40 - dt.timedelta(days=20)).strftime("%d-%b-%Y") + " 18:00:00"}]
    if "TCS" in path:
        return [{"symbol": "TCS", "desc": "Bagging/Receiving of orders/contracts", "attchmntText": "TCS has secured an order worth Rs 2,000 crore from a European bank",
                 "an_dt": (dt.date.fromisoformat(days[45]) - dt.timedelta(days=10)).strftime("%d-%b-%Y") + " 17:00:00"}]
    return []
def get(url):
    if "EQUITY_L" in url:
        return "SYMBOL,NAME OF COMPANY\nPBFINTECH,PB Fintech Limited\nTCS,Tata Consultancy Services Limited\nINFY,Infosys Limited\n"
    if "news.google.com" in url and "Tata" in url:
        return "<item><title>TCS Q4 results: net profit jumps 12%, shares surge</title><link>x</link></item>"
    return ""
C.S.result_days = lambda s, R, BM, ds: [days[45]] if s == "TCS" else []
Cx = C.reasons(shocks, syms, DAY, getj=getj, get=get, pause=0, log=lambda m: None, stop=None)
r_pb, r_tcs = Cx["PBFINTECH:" + days[40]], Cx["TCS:" + days[45]]
check("PBFINTECH's fall -> REGULATOR from the NSE filing (IRDAI penalty)", r_pb["reason"] == "REGULATOR" and "IRDAI" in r_pb["line"] and r_pb["src"] == "NSE filing")
check("the IRDAI show-cause notice 20 days before is kept as the warning", len(r_pb["warn"]) == 1 and "show cause" in r_pb["warn"][0][2])
check("TCS's rise -> RESULTS", r_tcs["reason"] == "RESULTS")
check("a second run reads nothing again (cached)", json.dumps(C.reasons(shocks, syms, DAY, getj=lambda p: 1 / 0, get=get, pause=0, log=lambda m: None, stop=None), sort_keys=True) == json.dumps(Cx, sort_keys=True))
L, J = C.report(shocks, base, tot, Cx)
txt = "\n".join(L)
print(txt)
check("report: the falls by reason, the biggest falls, the warning filed first", "REGULATOR" in txt and "THE 15 BIGGEST FALLS" in txt and "A WARNING FILED FIRST" in txt)
check("report: UP as well - the rises by reason, the 15 biggest rises, the order filed 10 days before TCS's jump", "▲ UP SHOCKS" in txt and "THE 15 BIGGEST RISES" in txt
      and "GOOD NEWS FILED FIRST" in txt and "TCS +9.0% <-" in txt)
check("report: year by year, up and down", "YEAR BY YEAR" in txt and "2025  ▲    1  ▼    1" in txt)
check("circuits.json: per share and per reason", J["by_sym"]["PBFINTECH"][0]["reason"] == "REGULATOR" and J["by_reason"]["REGULATOR:-1"]["n"] == 1)
json.dump(J, open(W.HIST, "w"))
check("refine: an election-day fall (NIFTY -5.9%) blamed on a CEO appointment -> MARKET",
      C.refine({"reason": "MGMT", "line": "Asirvad MFI appoints Satish Nair as CEO", "nifty": -5.93, "side": -1, "news": []}, 300)[0] == "MARKET")
check("refine: a CEO appointment on a quiet day is not MGMT; a CEO quitting is", C.refine({"reason": "MGMT", "line": "X appoints new CEO", "nifty": 0.1, "side": -1,
      "news": []}, 1)[0] == "UNKNOWN" and C.refine({"reason": "MGMT", "line": "X CEO resigns with immediate effect", "nifty": 0.1, "side": -1, "news": []}, 1)[0] == "MGMT")
check("refine: a regulator fall stays REGULATOR even on a market day", C.refine({"reason": "REGULATOR", "line": "RBI bars", "nifty": -3, "side": -1}, 40)[0] == "REGULATOR")

# a 1:1 bonus (opens at half the price and stays) is not a crash
DB = {"BONUS": series({30: -0.5}), "NIFTY 50": DAY["NIFTY 50"]}
DB["BONUS"][days[30]] = (DB["BONUS"][days[30]][3],) + DB["BONUS"][days[30]][1:]          # it opened at the new price
check("a bonus / split day (opened -50% and stayed) is not counted as a shock", C.find(["BONUS"], DB, {})[0] == [])

# the year before from NSE's own daily files (Kite not there): TESTSYM's old prices were half (a 1:1 bonus since) -> joined at the seam
import io, zipfile, numpy as np, hist3y as Hh
os.makedirs(os.path.join(T, "day"), exist_ok=True)
t0 = [dt.datetime(2023, 1, 23 + i, tzinfo=C.IST).timestamp() for i in range(5)]
np.savez(os.path.join(T, "day", "TESTSYM.npz"), ts=np.array(t0), o=np.full(5, 200.0), h=np.full(5, 202.0), l=np.full(5, 198.0), c=np.full(5, 200.0), v=np.full(5, 1e5))
np.savez(os.path.join(T, "day", "NIFTY_50.npz"), ts=np.array(t0), o=np.full(5, 18000.0), h=np.full(5, 18100.0), l=np.full(5, 17900.0), c=np.full(5, 18000.0), v=np.zeros(5))
def get3(url):
    if "bhav.csv.zip" in url:
        b = io.BytesIO(); z = zipfile.ZipFile(b, "w")
        z.writestr("x.csv", "SYMBOL,SERIES,OPEN,HIGH,LOW,CLOSE,LAST,PREVCLOSE,TOTTRDQTY\nTESTSYM,EQ,100,101,99,100,100,100,50000\nOTHER,EQ,5,5,5,5,5,5,1\n"); z.close()
        return b.getvalue()
    if "ind_close_all" in url:
        return b"Index Name,Index Date,Open Index Value,High Index Value,Low Index Value,Closing Index Value\nNifty 50,x,17900,18050,17850,18000\n"
    return None
C.extend_nse(["TESTSYM"], dt.date(2023, 1, 2), log=lambda m: None, get=get3)
a = np.load(os.path.join(T, "day", "TESTSYM.npz")); nf = np.load(os.path.join(T, "day", "NIFTY_50.npz"))
check("NSE files: TESTSYM taken back to 2 Jan 2023 (15 more days), the old prices put on today's scale (x2)",
      len(a["ts"]) == 20 and abs(float(a["c"][0]) - 200) < 1 and dt.datetime.fromtimestamp(float(a["ts"].min()), C.IST).date() == dt.date(2023, 1, 2))
check("NSE files: NIFTY 50 taken back too", len(nf["ts"]) == 20)

# ---- SHOCK WATCH
feed = {"q": []}
def get2(url):
    if "EQUITY_L" in url:
        return get(url)
    if "news.google.com" in url and "IRDAI" in url:
        return "".join("<item><title>%s</title><link>http://n/%d</link></item>" % (t, i) for i, t in enumerate(feed["q"]))
    return ""
SENT = []
W.run(SENT.append, get2, fo=syms)
check("the first run only remembers (nothing sent)", SENT == [])
feed["q"] = ["IRDAI issues show cause notice to Policybazaar over violations", "IRDAI releases annual report", "Infosys wins large deal in Europe",
             "Cochin Shipyard bags Rs 2,500 crore order from Indian Navy"]
allout = W.run(SENT.append, get2, fo=syms + ["COCHINSHIP"], now=dt.datetime(2026, 11, 11, 10, 5, tzinfo=W.IST))
for x in allout:
    print(x, "\n")
out = [x for x in allout if "PBFINTECH" in x]
up_big = [x for x in allout if "COCHINSHIP" in x]; up_small = [x for x in allout if "INFY" in x]
check("▲ a Rs 2,500 crore order -> ⚠️ SHOCK WATCH COCHINSHIP ▲ ORDER (rings)", len(up_big) == 1 and up_big[0].startswith("⚠️ SHOCK WATCH · ▲ COCHINSHIP · ORDER"))
check("▲ a deal story with no size -> 📰 SHOCK WATCH INFY (quiet, News topic)", len(up_small) == 1 and up_small[0].startswith("📰 SHOCK WATCH · ▲ INFY ·"))
check("▼ PBFINTECH REGULATOR (the plain IRDAI report is not news)", len(out) == 1 and "▼ PBFINTECH · REGULATOR" in out[0] and len(allout) == 3)
check("it carries PBFINTECH's own past shock and the 3-year REGULATOR record", "own shocks since 2025: 1" in out[0] and "REGULATOR news behind 1 F&O shocks ▼ since 2025" in out[0])
check("a second pass: nothing again", W.run(None, get2, fo=syms + ["COCHINSHIP"]) == [])
m = W.matcher({"SBIN": ["SBI", "State Bank of India"], "HAL": ["HAL"]})
check("names: 'SBI' and 'HAL' only as words in capitals ('Halol', 'hal' are not HAL)", m("RBI fines SBI Rs 2 crore") == ["SBIN"] and m("plant at Halol shut") == [] and m("HAL bags order") == ["HAL"])
try:
    import alertword, tglanes
    check("⚠️ SHOCK WATCH rings in GIR Box Picks (▼ and the big ▲)", all(tglanes.lane(x) == "critical" and alertword.tier(x) != "read" for x in out + up_big))
    check("📰 SHOCK WATCH goes quiet to the News topic", tglanes.topic(up_small[0]) == "news" and alertword.tier(up_small[0]) == "read")
except Exception as ex:
    check("routing check (%s)" % ex, False)
shutil.rmtree(T)
print("P161 SHOCK DAYS TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
P161TEST_PY
cat > $D/p162test.py <<'P162TEST_PY'
#!/usr/bin/env python3
"""p162test.py - patch 162: 📺 TV WATCH on made-up speech (no stream, no model, nothing sent)"""
import os, sys, json, wave, shutil, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import tvwatch as T, shockwatch as W, circuits as C

ok = True
def check(name, cond):
    global ok
    print(("  ok   " if cond else "  FAIL ") + name)
    ok = ok and bool(cond)

D = tempfile.mkdtemp()
T.TMP = D; T.DB = os.path.join(D, "tv.db")
T.NM.clear(); T.NM.update({"COCHINSHIP": ["Cochin Shipyard"], "MANAPPURAM": ["Manappuram"], "HAL": ["HAL", "Hindustan Aeronautics"], "INFY": ["Infosys"],
                           "SBIN": ["SBI", "State Bank of India"]})
match = W.matcher(T.NM)
now = dt.datetime(2026, 11, 11, 10, 42, tzinfo=T.IST)
f1 = T.scan("CNBC-TV18", "Breaking news coming in. Sources say Cochin Shipyard has bagged an order worth 2,500 crore rupees from the Indian Navy.", "", match, now)
check("on air: Cochin Shipyard bags a 2,500 crore order -> COCHINSHIP ▲ ORDER", len(f1) == 1 and f1[0]["sym"] == "COCHINSHIP" and f1[0]["reason"] == "ORDER" and f1[0]["side"] == 1)
a1 = W.line(f1[0], {}, now)
print(a1, "\n")
check("it rings: ⚠️ SHOCK WATCH · ▲ COCHINSHIP · ORDER · TV CNBC-TV18, with the words heard", a1.startswith("⚠️ SHOCK WATCH · ▲ COCHINSHIP · ORDER · TV CNBC-TV18") and "on air:" in a1)
f2 = T.scan("CNBC-TV18", "has imposed restrictions on Manappuram Finance's gold loan business with immediate effect.", "and just in, the Reserve Bank of India", match, now)
check("a sentence cut across two recordings: RBI ... restrictions on Manappuram -> MANAPPURAM ▼ REGULATOR", len(f2) == 1 and f2[0]["sym"] == "MANAPPURAM" and f2[0]["side"] == -1 and f2[0]["reason"] == "REGULATOR")
check("market chatter (Nifty flat, IT mixed, Infosys up half a percent) -> nothing", T.scan("CNBC-TV18", "Nifty is trading flat, IT stocks are mixed, Infosys up half a percent.", "", match, now) == [])
check("'shall' is not HAL; 'SBI' is", T.scan("X", "we shall see a penalty imposed soon", "", match, now) == [] and [x["sym"] for x in T.scan("X", "RBI imposes a penalty on SBI", "", match, now)] == ["SBIN"])
c0 = dict(T.DEFAULT)
check("listens on a trading day 09:30, not at 16:00, not on Saturday", T.window(dt.datetime(2026, 11, 11, 9, 30, tzinfo=T.IST), c0)
      and not T.window(dt.datetime(2026, 11, 11, 16, 0, tzinfo=T.IST), c0) and not T.window(dt.datetime(2026, 11, 14, 10, 0, tzinfo=T.IST), c0))
# recordings: the newest is still being written
f = T.Feed("CNBC-TV18")
for i in range(3):
    open(os.path.join(D, "cnbctv18_%06d.wav" % i), "w").write("x")
class P:
    def poll(self): return None
f.proc = P()
check("the finished recordings, oldest first, not the one being written", [os.path.basename(x) for x in f.chunks()] == ["cnbctv18_000000.wav", "cnbctv18_000001.wav"])
f.proc = None
# the speech reader protocol, with a stand-in reader
fake = os.path.join(D, "fake_stt.py")
open(fake, "w").write('import sys, json\nprint(json.dumps({"ready": "fake"}), flush=True)\nfor l in sys.stdin:\n    p, lang = l.rstrip("\\n").split("\\t")\n    print(json.dumps({"path": p, "text": "heard " + lang, "secs": 20, "took": 1, "level": 0.05}), flush=True)\n')
w = T.Worker(T.DEFAULT, cmd=[sys.executable, fake])
r = w.read("/x.wav", "hi"); w.stop()
check("the speech reader answers one line per recording", r.get("text") == "heard hi" and r.get("secs") == 20)
T.keep("CNBC-TV18", 1.0e9, {"text": "hello", "secs": 20, "took": 3, "level": 0.1})
import sqlite3
check("every transcript is kept in tv.db", sqlite3.connect(T.DB).execute("select count(*) from tv").fetchone()[0] == 1)
try:
    import alertword, tglanes
    check("a TV ⚠️ rings in Box Picks", tglanes.lane(a1) == "critical" and alertword.tier(a1) != "read")
except Exception as ex:
    check("routing (%s)" % ex, False)
shutil.rmtree(D)
print("P162 TV WATCH TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
P162TEST_PY
[ -f $D/data/tvwatch.json ] || echo '{"channels": ["CNBC-TV18"], "model": "base", "threads": 2, "always": false}' > $D/data/tvwatch.json
echo "   tvwatch.py · tvstt.py · shockwatch.py written · channels: $(cat $D/data/tvwatch.json)"
echo "== 2. the tests (made-up speech and news, nothing sent)"
cd $D && python3 -m py_compile tvwatch.py shockwatch.py p161test.py p162test.py && $V/bin/python -m py_compile tvstt.py || { echo "   does not compile"; exit 1; }
if timeout 180 python3 p161test.py > /tmp/p161test.log 2>&1 && timeout 120 python3 p162test.py > /tmp/p162test.log 2>&1; then echo "   p161test.py + p162test.py passed"; else
  echo "   TEST FAILED - undone:"; grep -hE "FAIL|Error" /tmp/p161test.log /tmp/p162test.log | head -6 | sed 's/^/     /'
  for f in shockwatch.py p161test.py; do cp $D/$f.bak162 $D/$f 2>/dev/null; done; rm -f $D/tvwatch.py $D/tvstt.py; exit 1; fi
echo "== 3. a live check: 20 s of each channel now, read with the real model (today may be holiday programming)"
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 300 nice -n 10 python3 tvwatch.py once 2>&1 | sed 's/^/   /'
echo "== 4. the service"
cat > $U/gir-tvwatch.service <<'UNIT'
[Unit]
Description=GIR TV WATCH (live business TV -> text -> SHOCK WATCH)
After=network-online.target
[Service]
Type=simple
Nice=10
CPUQuota=150%
Restart=always
RestartSec=30
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && exec python3 tvwatch.py run --send >> data/tvwatch_service.log 2>&1'
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable gir-tvwatch >/dev/null 2>&1 && systemctl restart gir-tvwatch && sleep 3 && systemctl is-active --quiet gir-tvwatch \
  && echo "   gir-tvwatch running: listens 09:00-15:40 on trading days (sleeps now - today is a holiday), at most 1.5 CPUs so GIR is never starved" \
  || echo "   gir-tvwatch did not start: journalctl -u gir-tvwatch -n 20"
echo "   what it hears, live: tail -f $D/data/tvwatch.log"
echo "== 5. how late is the news now (GIR's own measure, last 7 days)"
timeout 300 nice -n 10 python3 newslag.py --days=7 2>/dev/null | grep -iE "^[A-C] |median|minutes|before the move|never|lag" | head -16 | sed 's/^/   /' || echo "   (newslag.py not available)"
echo
echo "PATCH 162 APPLIED. Send Claude a screenshot of sections 3 to 5."

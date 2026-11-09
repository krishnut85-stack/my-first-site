#!/bin/bash
# TV PROBE - can the droplet read live business TV from YouTube, fast enough? (a test only - GIR is not touched)
#   1. the droplet's size   2. installs ffmpeg + a separate tool folder /home/globalbot/tvenv (yt-dlp, faster-whisper)
#   3. finds which channels are live on YouTube   4. records 60 s of each of two channels and turns the speech into text,
#   timing it: under ~40 s for 60 s of TV = the droplet can keep up live.
#   Runs at low priority. Run it after 15:35 (the channels are live in the evening too).  Takes ~5-10 min the first time.
set -u
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash tvprobe.sh now)"; exit 1; fi
V=/home/globalbot/tvenv; T=/tmp/tvprobe; mkdir -p $T
echo "== 1. the droplet"; echo "   CPUs: $(nproc) · memory: $(free -m | awk '/Mem:/{print $2" MB, free "$7" MB"}') · disk free: $(df -h / | awk 'NR==2{print $4}')"
echo "== 2. the tools"
command -v ffmpeg >/dev/null || { apt-get update -qq && apt-get install -y -qq ffmpeg >/dev/null; }
command -v ffmpeg >/dev/null && echo "   ffmpeg ok" || { echo "   ffmpeg could not be installed"; exit 1; }
[ -x $V/bin/python ] || python3 -m venv $V || { echo "   python venv missing: apt-get install -y python3-venv, then run again"; exit 1; }
$V/bin/pip install -q --upgrade pip yt-dlp faster-whisper >/dev/null 2>&1 && echo "   yt-dlp + faster-whisper ok (in $V)" || { echo "   pip install failed"; exit 1; }
echo "== 3. which channels are live on YouTube"
LIVE=()
for c in "CNBC-TV18|https://www.youtube.com/@cnbc-tv18/live|en" "CNBC-TV18 (id)|https://www.youtube.com/channel/UCmRbHAgG2k2vDUvb3xsEunQ/live|en" "ET NOW|https://www.youtube.com/@ETNOWlive/live|en" "ET NOW (2)|https://www.youtube.com/@etnow/live|en" "ZEE BUSINESS|https://www.youtube.com/@ZeeBusiness/live|hi" "CNBC AWAAZ|https://www.youtube.com/@CNBCAwaaz/live|hi" "SANSAD TV|https://www.youtube.com/@SansadTV/live|hi"; do
  n=${c%%|*}; r=${c#*|}; u=${r%|*}; lang=${r##*|}
  s=$(timeout 60 $V/bin/yt-dlp -q --no-warnings -f "bestaudio/best" -g "$u" 2>$T/err.txt | head -1)
  if [ -n "$s" ]; then echo "   LIVE   $n"; LIVE+=("$n|$lang|$s"); else echo "   no     $n  ($(head -c 150 $T/err.txt | tr '\n' ' '))"; fi
done
[ ${#LIVE[@]} -gt 0 ] || { echo "no channel could be read from the droplet - if the errors say 'Sign in to confirm you're not a bot', YouTube blocks server addresses: send me this output"; exit 1; }
echo "== 4. 60 s of TV -> text (English channel: as spoken · Hindi channel: translated to English)"
cat > $T/stt.py <<'PY'
import sys, time
from faster_whisper import WhisperModel
wav, lang, size = sys.argv[1], sys.argv[2], sys.argv[3]
t0 = time.time(); m = WhisperModel(size, device="cpu", compute_type="int8"); t1 = time.time()
segs, info = m.transcribe(wav, language=lang, task="translate" if lang == "hi" else "transcribe", vad_filter=True, beam_size=1)
txt = " ".join(s.text.strip() for s in segs); t2 = time.time()
print("   model %s loaded in %.0f s · 60 s of TV read in %.0f s -> %s" % (size, t1 - t0, t2 - t1, "KEEPS UP LIVE" if t2 - t1 < 40 else "TOO SLOW for live"))
print("   text: " + txt[:700])
PY
done_en=0; done_hi=0
for x in "${LIVE[@]}"; do
  n=${x%%|*}; r=${x#*|}; lang=${r%%|*}; s=${r#*|}
  [ $lang = en ] && [ $done_en = 1 ] && continue; [ $lang = hi ] && [ $done_hi = 1 ] && continue
  echo "-- $n"
  timeout 90 nice -n 19 ffmpeg -nostdin -loglevel error -y -i "$s" -t 60 -vn -ac 1 -ar 16000 $T/a.wav || { echo "   could not record"; continue; }
  for size in base small; do nice -n 19 $V/bin/python $T/stt.py $T/a.wav $lang $size 2>/dev/null || echo "   model $size failed"; done
  [ $lang = en ] && done_en=1; [ $lang = hi ] && done_hi=1
done
rm -f $T/a.wav
echo "== done - send me this whole output"

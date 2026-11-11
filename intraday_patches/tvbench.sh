#!/bin/bash
# tvbench.sh - WHICH SPEECH MODEL FOR 📺 TV WATCH? Read-only for GIR: the TV service is not touched (run it outside 09:00-15:40).
#   1 the server: CPUs, memory, swap, disk, what TV WATCH uses now
#   2 records 60 s of CNBC-TV18 live now (3 pieces of 20 s, the same as TV WATCH)
#   3 reads the same 3 pieces with each model - base (today), small, distil-small.en, distil-medium.en, large-v3-turbo (when memory allows),
#     with GIR's company-name hint and without it - and prints for each: seconds per 20 s of TV, memory used, and what it heard
#   The models download once (0.2-1.6 GB each, to the TV tool folder's cache). Takes 10-20 minutes. Nothing is sent, no setting changed.
#   bash tvbench.sh            bash tvbench.sh quick   (base + small + distil-small.en only)
D=/home/globalbot/intraday; V=/home/globalbot/tvenv; T=/tmp/tvbench
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0855 ] && [ "$H" -le 1545 ]; then echo "TV WATCH is listening now - run it after 15:45 (it would slow the live reading)"; exit 1; fi
[ -x $V/bin/python ] || { echo "the TV tool folder $V is missing"; exit 1; }
mkdir -p $T
echo "=== 1 · THE SERVER"
echo "   CPUs: $(nproc) · $(free -h | awk '/Mem:/{print "memory "$2" total, "$7" free"} /Swap:/{print "· swap "$3" of "$2" used"}' | tr '\n' ' ')"
echo "   disk free: $(df -h /home | awk 'NR==2{print $4}') · TV WATCH now: $(cat $D/data/tvwatch.json 2>/dev/null || echo 'default: base, 2 threads')"
echo "   the busiest programs now:"; ps -eo rss,pcpu,comm --sort=-rss | head -n 6 | awk 'NR>1{printf "     %5.0f MB  %4s%% cpu  %s\n", $1/1024, $2, $3}'
echo "=== 2 · 60 s OF CNBC-TV18 LIVE NOW"
cd $D && python3 - <<'PY' || { echo "   could not record (YouTube) - try again in a few minutes"; exit 1; }
import sys, subprocess
sys.path.insert(0, "/home/globalbot/intraday")
import tvwatch as W
u = W.stream_url(W.CHANNELS["CNBC-TV18"][0])
subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", u, "-t", "60", "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le",
                "/tmp/tvbench/all.wav"], timeout=180, check=True)
for i in range(3):
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", "/tmp/tvbench/all.wav", "-ss", str(i * 20), "-t", "20",
                    "-c:a", "pcm_s16le", "/tmp/tvbench/p%d.wav" % i], timeout=60, check=True)
print("   recorded 3 x 20 s")
PY
cd $D && python3 - <<'PY' > $T/prompt.txt 2>/dev/null
import sys; sys.path.insert(0, "/home/globalbot/intraday")
import tvwatch as W
W.fo_names(); print(W.prompt_text())
PY
cat > $T/one.py <<'PY'
import sys, json, time, wave, resource
import numpy as np
from faster_whisper import WhisperModel
size, threads, use_prompt = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "1"
prompt = open("/tmp/tvbench/prompt.txt").read().strip()[:600] if use_prompt else None
t0 = time.time()
m = WhisperModel(size, device="cpu", compute_type="int8", cpu_threads=threads)
load = time.time() - t0
took, texts = [], []
for i in range(3):
    w = wave.open("/tmp/tvbench/p%d.wav" % i)
    a = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768.0
    t1 = time.time()
    segs, _ = m.transcribe(a, language="en", vad_filter=True, beam_size=1, initial_prompt=prompt, condition_on_previous_text=False)
    texts.append(" ".join(s.text.strip() for s in segs))
    took.append(time.time() - t1)
mem = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024
print(json.dumps({"load": round(load), "per20": round(sum(took) / 3, 1), "mem": round(mem), "text": " | ".join(texts)}))
PY
MODELS="base small distil-small.en distil-medium.en large-v3-turbo"
[ "${1:-}" = "quick" ] && MODELS="base small distil-small.en"
FREE=$(free -m | awk '/Mem:/{print $7}')
echo "=== 3 · THE SAME 60 s, EACH MODEL (2 threads, as TV WATCH runs) - live needs well under 20 s per 20 s"
for M in $MODELS; do
  if [ "$M" = "large-v3-turbo" ] && [ "$FREE" -lt 2500 ]; then echo "   $M: skipped - only ${FREE} MB memory free (it needs ~2 GB)"; continue; fi
  for P in 1 0; do
    R=$(timeout 1200 $V/bin/python $T/one.py $M 2 $P 2>$T/err.txt)
    if [ -z "$R" ]; then echo "   $M: did not run - $(tail -n 1 $T/err.txt | cut -c1-120)"; break; fi
    echo "$R" | python3 -c "
import sys, json
r = json.loads(sys.stdin.read()); m, p = sys.argv[1], sys.argv[2]
ok = '✅ live OK' if r['per20'] <= 8 else '⚠️ tight' if r['per20'] <= 15 else '❌ too slow'
print('   %-17s %s  %5.1f s per 20 s · %5d MB · %s' % (m, 'with hint  ' if p == '1' else 'no hint    ', r['per20'], r['mem'], ok))
print('       heard: ' + r['text'][:330])
" $M $P
  done
done
echo "=== done - nothing changed. Send a screenshot; the choice is one setting (data/tvwatch.json) and a restart."
rm -f $T/p*.wav $T/all.wav

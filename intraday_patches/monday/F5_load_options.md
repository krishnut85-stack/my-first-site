# F5 - two ways to keep the live page fast on Monday (prepared 20 Nov; NOTHING done - the trader decides)

Why: Fri 20 Nov the 4-CPU server reached load 15 at 12:37 and one /login answer took 3.0-3.6 s at 11:21. The biggest users were
NOT GIR v2: gircrypto window2_news (~68% of a CPU), the old engine2 (~68%, it goes silent on Monday), falcon (~48%), plus a burst of
old timers at the same minute (falcon, crosscheck, govwatch, raven-manage). The new system's recorders use ~3.5% of one CPU.

## Option A - pause gircrypto + falcon in market hours only (needs his yes: gircrypto is his other project)
Pause Monday 08:55 (timers only - running jobs finish their current pass; nothing deleted, nothing disabled for good):

    systemctl stop falcon.timer gir-crypto-window2.timer gir-crypto-window3.timer gir-crypto-window4.timer \
                   gir-crypto-meme-discovery.timer gir-crypto-market-snapshot.timer

Resume (automatically at 15:36 the same day, set up together with the pause):

    systemd-run --on-calendar="2026-11-23 15:36:00 Asia/Kolkata" --unit=gir-resume-1123 \
      systemctl start falcon.timer gir-crypto-window2.timer gir-crypto-window3.timer gir-crypto-window4.timer \
                      gir-crypto-meme-discovery.timer gir-crypto-market-snapshot.timer

Not touched unless he says: gir-crypto-iv-rank and gir-crypto-options-feed (long-running services), gir-watchdog, paper_exit_monitor.
Every day instead of Monday only: the same two commands as a daily timer pair (Mon-Fri trading days, holiday calendar from J3).

## Option B - resize the server (paid, needs his yes)
- Today: 4 vCPU / 16 GB (load 6-15 in market hours). Target: 8 vCPU / 16 GB Basic ($96 a month list) or 8 dedicated vCPU CPU-Optimized
  ($168 a month list) - PAID.md item 13; the difference to today's bill depends on the current plan (DigitalOcean bill).
- How (Sunday, any time before 16:00 so J13 restart proof runs on the new size): DigitalOcean control panel -> the droplet -> Resize
  -> "CPU and RAM only" (keeps the disk, so it can be undone) -> pick the size -> Resize. The droplet is switched off for a few minutes.
  The 200 GB volume stays attached. After boot: every gir-* service comes back by itself (J13 checks it), then the outside uptime check.
- Who: only the trader can do it (his DigitalOcean account). The server checks everything after it comes back and pushes the proof.

Recommendation: B if he accepts the cost (it also covers the old system running silent beside the new one); otherwise A on Monday.

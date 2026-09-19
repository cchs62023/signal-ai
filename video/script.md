# Signal AI — narration script, timed to the cut

Picture-locked cut: `signal_demo_youtube.mp4` — **2:53**, 1920x1080, silent.
All source footage had no usable audio, so record over this and the timings line up.

Each chapter opens with a **2.5s title card**. Start speaking when the card clears.

| # | Chapter | Card | Speak from | to | Window | Words that fit |
|---|---|---|---|---|---|---|
| 1 | The problem | 0:00 | 0:02.5 | 0:20 | 17.5s | ~40 |
| 2 | Signal in the background | 0:20 | 0:22.5 | 0:49 | 26.5s | ~62 |
| 3 | One decision | 0:49 | 0:51.5 | 1:03 | 11.5s | ~27 |
| 4 | Where the info came from | 1:03 | 1:05.5 | 1:23 | 17.5s | ~40 |
| 5 | Ask and decide | 1:23 | 1:25.5 | 1:53 | 27.5s | ~64 |
| 6 | Who decides what | 1:53 | 1:55.5 | 2:10 | 14.5s | ~34 |
| 7 | The call is yours | 2:10 | 2:12.5 | 2:25 | 12.5s | ~29 |
| 8 | How it was built | 2:25 | 2:27.5 | 2:53 | 25.5s | ~59 |

"Words that fit" is at 140 wpm — a natural pace with room to breathe.

> **Your sections 4 and 5 are swapped here.** In the footage you ask Sarah and apply her
> reply *first* (0:50–1:17 of the source), and the stakeholder map comes *after* (1:17–1:32).
> I kept the footage order rather than re-cutting, because at 1:11 the project flips to
> "BLOCKED — VERIFIED" and the banner changes to "Security has now answered directly" —
> showing the stakeholder view before the ask would display a state that hasn't happened yet.

---

## 1. The problem — 0:02.5, 17.5s *(new — you had no script for this)*

> A manager doesn't lack information. They're drowning in it.
> Jira, Gmail, Slack, a Zoom call — every one of them carries a piece of the same decision.
> None of them carries the decision itself.

38 words.

---

## 2. Signal in the background — 0:22.5, 26.5s

> Let me start by connecting my work tools. I'll add Zoom, and Gmail.
> Signal only sees what I already have access to.
> Now it moves to the corner and stays out of the way.
> When I'm in a meeting, it listens.
> As I go through email, Jira and Slack, it picks up anything related to my projects.
> See the number going up? That's Signal collecting updates.

66 words — 149 wpm. Brisk. If it feels rushed, cut
*"Signal only sees what I already have access to"* — section 5 makes the same trust point
by showing Signal can't send without your approval.

---

## 3. One decision — 0:51.5, 11.5s

> Let's see what it found. It's flagging one decision, whether to approve this storage project.
> It's on hold because security hasn't signed off yet.

24 words — comfortable.

---

## 4. Where the info came from — 1:05.5, 17.5s

> Here's the part I care about most. Jira says security is fine.
> But let's check where that came from. The security lead said something in a meeting,
> someone repeated it, and then someone else wrote it down.
> She never actually approved it.

42 words. This section is **slowed to 0.7x** so the provenance chain is readable —
let the last line land before the cut.

---

## 5. Ask and decide — 1:25.5, 27.5s

> Let's fix that. Signal writes the message for me, but it can't send it on its own.
> I approve it, and it goes out.
> While we wait, I can keep working. And here's her reply.
> The project updates everywhere at once.

47 words — comfortable, room to pause on the reply.

*(Your original had "Signal suggests keeping it on hold, but the final call is mine" here.
That line moved to section 7, where the Decision tab is actually on screen.)*

---

## 6. Who decides what — 1:55.5, 14.5s

> So who actually decides? The CEO has the final say on priorities, but not on security.
> Only the security lead can approve that.
> Down here, Signal shows who hasn't weighed in yet.

32 words — comfortable.

---

## 7. The call is yours — 2:12.5, 12.5s

> Signal suggests keeping it on hold — with the reason, and the person, on the record.
> But the final call is mine.

24 words.

---

## 8. How it was built — 2:27.5, 25.5s *(new — you had no script for this)*

> The concept started on paper, then moved into Figma —
> the decision authority map, source distance, voice coverage.
> The design system came out of a conversation with ChatGPT,
> and the working prototype was built in Claude Code.
> Start to finish, the tools that made it are the same kind of tools it reads.

57 words.

---

## Recording notes

- Record each section as its own file, named `01.wav` … `08.wav` — reshoot one, not all eight
- Phone earbuds are fine; 15cm from your mouth, in a room without echo
- Watch the cut while you read so your pace matches what's on screen
- Leave the room tone running 2s before and after each take — makes cleanup easier

## Putting the voiceover on

```bash
# after recording, concatenate in order with the right silence between sections
# (or just record one continuous take against the video)
ffmpeg -i signal_demo_youtube.mp4 -i narration.wav \
  -map 0:v -map 1:a -c:v copy -c:a aac -b:a 384k -shortest with_vo.mp4

# subtitles straight from the narration, then attach as a soft track
python3 ../.claude/skills/video-edit/scripts/transcribe.py with_vo.mp4 --model small --lang en
bash ../.claude/skills/video-youtube/scripts/soft-subs.sh with_vo.mp4 final.mp4 with_vo.srt eng
```

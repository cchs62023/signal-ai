---
name: demo-video
description: Records a narrated-pace screen-capture demo video of the Signal Room prototype as a YouTube-ready 16:9 1920x1080 MP4, by driving the real page in headless Chromium and encoding with ffmpeg. Use this whenever the user wants a demo video, a screen recording, a walkthrough clip, a YouTube upload, a submission video, a "3 minute video", a product demo reel, or asks to "record the prototype" — including when they only mention a duration or an aspect ratio and not the word "video". Also use it when they want to re-cut the demo at a different length or change which parts of the flow are shown.
---

# Demo video for the Signal Room prototype

The prototype is a clickable page, so the only honest way to make a demo of it
is to drive the real thing and film the result. `scripts/record_demo.py` does
that: it opens `index.html` in headless Chromium, performs the walkthrough on a
timed beat sheet, captures video, and encodes an MP4 at exactly 1920×1080.

## Running it

```bash
python3 scripts/record_demo.py --out signal-room-demo.mp4
```

Useful flags:

| flag | default | |
|---|---|---|
| `--out` | `signal-room-demo.mp4` | output path |
| `--seconds` | `180` | target length; beats scale proportionally |
| `--url` | the repo's `index.html` | record the live site instead |
| `--no-cursor` | off | drop the synthetic pointer |
| `--no-fill-bars` | off | leave the pillarbox bars flat instead of filling them |

The script prints the beat sheet with real timings as it records, then reports
the finished file's duration and resolution. Read that output — if a beat ran
short the pacing is visible there before anyone watches the file.

## The aspect-ratio problem, and what the script does about it

The prototype's desktop is **1440×900, which is 16:10, not 16:9**. Scaled into a
1920×1080 frame it becomes 1728×1080, leaving 96px bars down each side — 10% of
the width. The video is still a true 16:9 file, so it satisfies YouTube; the
bars are a cosmetic matter.

Rather than leave two flat dark strips, the script fills them with the desktop
wallpaper, scaled to cover and blurred, so the frame reads as one continuous
image instead of a boxed-in recording. That is injected at record time only —
it never touches the prototype.

If someone wants genuinely edge-to-edge 16:9, the real fix is to widen the
prototype's stage to 1600×900 (same height, +160px). That means changing the
handful of fixed-width pieces — the root, the wallpaper, the menu bar, the app
window's left offset, the Signal Room's left offset, and the `fly` keyframe —
plus the `1440` constants in `runtime.js`. It is a contained change but it
alters the design canvas, so raise it rather than doing it silently.

## Changing what the video shows

The walkthrough lives in `BEATS` near the top of the script: a list of
`(label, seconds, action)` entries. `seconds` is the hold *after* the action, so
a viewer has time to read what just changed. Durations are relative — the script
normalises them to `--seconds`, so adding a beat re-paces the rest automatically
rather than pushing the video over length.

When adding a beat, give the action a real selector rather than a coordinate.
The prototype re-renders on every state change, and while it now patches the DOM
in place, selectors survive edits to the layout in a way that coordinates do not.

## Things worth knowing before re-recording

- **Fonts.** The page loads Archivo from Google Fonts. If the network blocks it,
  the recording falls back to the system sans and the typography will not match
  the design. The script warns when the font request fails — do not ship a take
  that carries that warning without saying so.
- **The orb never stops moving.** Its orbits run on 8–20 second cycles, so holds
  shorter than a few seconds can make it look static. That is expected.
- **Timed content.** Asking Security takes about 4.5 seconds of simulated
  round-trip before Sarah's reply lands. The beat sheet already allows for it;
  if you shorten that beat the reply will not be on screen when the next one
  starts.
- **Headless has no real cursor.** The script draws a synthetic one and glides it
  to each target before clicking, so the video shows intent rather than elements
  changing on their own.

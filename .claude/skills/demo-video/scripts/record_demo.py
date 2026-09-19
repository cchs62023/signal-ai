#!/usr/bin/env python3
"""Record the Signal Room prototype as a 16:9 1920x1080 MP4.

Drives the real page in headless Chromium on a timed beat sheet, captures
video, then encodes to H.264. See ../SKILL.md for the why behind the
aspect-ratio handling and the beat sheet.
"""
import argparse, pathlib, re, shutil, subprocess, sys, tempfile, time

REPO = pathlib.Path(__file__).resolve().parents[4]   # scripts/ demo-video/ skills/ .claude/ -> repo root
STAGE_W, STAGE_H = 1440, 900          # the prototype's own canvas (16:10)
FRAME_W, FRAME_H = 1920, 1080         # what YouTube wants (16:9)

# (label, relative hold after the action, action)
# The hold is what gives a viewer time to read the change, so it carries most
# of the pacing. Relative units are normalised to --seconds.
BEATS = [
    ("Setup screen",              6,  None),
    ("Connect Gmail",             3,  ("click", 'button:has-text("Connect")', 0)),
    ("Connect Zoom",              4,  ("click", 'button:has-text("Connect")', 0)),
    ("Continue - Signal docks",   7,  ("click", 'button:has-text("Continue")')),
    ("On ear, in Zoom",           6,  None),
    ("Switch to Jira",            7,  ("click", '[aria-label="Switch to Jira"]')),
    ("Switch to Slack",           6,  ("click", '[aria-label="Switch to Slack"]')),
    ("Switch to Gmail - 3",       8,  ("click", '[aria-label="Switch to Gmail"]')),
    ("Open Signal",               7,  ("click", 'svg.sig')),
    ("Open project",              8,  ("click", 'button:has-text("Open project")')),
    ("Overview: intent vs reality", 13, None),
    ("Timeline",                 12,  ("role", "Timeline")),
    ("Evidence: source distance",14,  ("role", "Evidence")),
    ("Stakeholders: authority",  13,  ("role", "Stakeholders")),
    ("Ask Security",              7,  ("click", 'button:has-text("Ask Security")')),
    ("Approve & Send",           11,  ("click", 'button:has-text("Approve & Send")')),
    ("Sarah replies",             7,  None),
    ("Apply to project",          9,  ("click", 'button:has-text("Apply to project")')),
    ("Decision tab",             11,  ("role", "Decision")),
    ("Keep Pending",              6,  ("click", 'button:has-text("Keep Pending")')),
    ("Decision recorded",        10,  None),
]

CURSOR_JS = """
(() => {
  const c = document.createElement('div');
  c.id = '__cursor';
  c.style.cssText = 'position:fixed;z-index:2147483647;width:22px;height:22px;' +
    'margin:-3px 0 0 -3px;pointer-events:none;transition:transform .45s cubic-bezier(.4,0,.2,1);' +
    'transform:translate(960px,540px)';
  c.innerHTML = '<svg viewBox="0 0 22 22" width="22" height="22">' +
    '<path d="M3 2l7.4 17.2 2.3-6.9 6.9-2.3z" fill="#fff" stroke="#111" stroke-width="1.4" stroke-linejoin="round"/></svg>';
  document.body.appendChild(c);
  window.__moveCursor = (x, y) => { c.style.transform = `translate(${x}px,${y}px)`; };
  window.__clickPulse = () => {
    const p = document.createElement('div');
    const m = /translate\\(([\\d.]+)px,\\s*([\\d.]+)px\\)/.exec(c.style.transform) || [0, 0, 0];
    p.style.cssText = 'position:fixed;z-index:2147483646;width:34px;height:34px;margin:-17px 0 0 -17px;' +
      'border-radius:50%;border:2px solid rgba(255,255,255,.9);pointer-events:none;' +
      `left:${m[1]}px;top:${m[2]}px;animation:__pulse .5s ease-out forwards`;
    document.body.appendChild(p);
    setTimeout(() => p.remove(), 520);
  };
  const st = document.createElement('style');
  st.textContent = '@keyframes __pulse{from{transform:scale(.4);opacity:1}to{transform:scale(1.5);opacity:0}}';
  document.head.appendChild(st);
})();
"""

# A negative z-index paints behind the body's own background, so the fill has
# to sit at 0 with the stage lifted above it.
FILL_BARS_CSS = """
html,body{background:#0b1117}
body::before{content:'';position:fixed;inset:0;z-index:0;
  background:url('%s') center/cover no-repeat;
  filter:blur(52px) saturate(.8) brightness(.45);transform:scale(1.2)}
#fit{z-index:1}
"""


def ffmpeg_bin():
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        sys.exit("ffmpeg not found. pip install imageio-ffmpeg")


def chromium_path():
    for p in sorted(pathlib.Path("/opt/pw-browsers").glob("chromium-*/chrome-linux/chrome"), reverse=True):
        return str(p)
    return None


def describe(path):
    """ffprobe is not bundled with imageio-ffmpeg, so read ffmpeg's own report."""
    r = subprocess.run([ffmpeg_bin(), "-hide_banner", "-i", str(path)],
                       capture_output=True, text=True)
    txt = r.stderr
    dur = re.search(r"Duration:\s*(\d+):(\d+):([\d.]+)", txt)
    dim = re.search(r"Video:.*?,\s*(\d{3,5})x(\d{3,5})", txt)
    bits = []
    if dim:
        w, h = int(dim.group(1)), int(dim.group(2))
        ratio = w / h
        bits.append(f"{w}x{h}  {ratio:.3f} "
                    f"({'16:9' if abs(ratio - 16 / 9) < 0.01 else 'NOT 16:9'})")
    if dur:
        total = int(dur.group(1)) * 3600 + int(dur.group(2)) * 60 + float(dur.group(3))
        bits.append(f"{int(total // 60)}m{total % 60:04.1f}s")
    bits.append(f"{path.stat().st_size / 1e6:.1f} MB")
    return "  ".join(bits)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="signal-room-demo.mp4")
    ap.add_argument("--seconds", type=float, default=180.0)
    ap.add_argument("--url", default=None)
    ap.add_argument("--no-cursor", action="store_true")
    ap.add_argument("--no-fill-bars", action="store_true")
    args = ap.parse_args()

    url = args.url or ("file://" + str(REPO / "index.html"))
    from playwright.sync_api import sync_playwright

    scale = args.seconds / sum(b[1] for b in BEATS)
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="signal-rec-"))
    warnings, overruns, elapsed = [], [], 0.0
    print(f"  recording {url}\n  target {args.seconds:.0f}s -> {FRAME_W}x{FRAME_H}\n")

    with sync_playwright() as p:
        launch = {"args": ["--no-sandbox", "--force-device-scale-factor=1"]}
        cp = chromium_path()
        if cp:
            launch["executable_path"] = cp
        browser = p.chromium.launch(**launch)
        ctx = browser.new_context(
            viewport={"width": FRAME_W, "height": FRAME_H},
            record_video_dir=str(tmp),
            record_video_size={"width": FRAME_W, "height": FRAME_H},
        )
        pg = ctx.new_page()
        pg.on("requestfailed", lambda r: warnings.append(r.url.split("/")[-1])
              if "fonts.googleapis" in r.url else None)
        pg.goto(url)
        pg.wait_for_timeout(900)

        if not args.no_fill_bars:
            wall = pg.evaluate("()=>{const i=document.querySelector('img[src*=wallpaper]');return i?i.src:null}")
            if wall:
                pg.add_style_tag(content=FILL_BARS_CSS % wall)
        if not args.no_cursor:
            pg.evaluate(CURSOR_JS)

        def glide_and_click(sel, index=None):
            loc = pg.locator(sel)
            loc = loc.nth(index) if index is not None else loc
            box = loc.bounding_box()
            if box and not args.no_cursor:
                pg.evaluate("([x,y])=>window.__moveCursor(x,y)",
                            [box["x"] + box["width"] / 2, box["y"] + box["height"] / 2])
                pg.wait_for_timeout(520)
                pg.evaluate("()=>window.__clickPulse()")
            loc.click()

        # Schedule against wall-clock cumulative targets rather than sleeping for
        # each hold: the cursor glide and the click itself take real time, and
        # sleeping the full hold on top of them pushed the last take 13s long.
        t0 = time.monotonic()
        cumulative = 0.0
        for label, rel, action in BEATS:
            cumulative += rel * scale
            if action:
                kind = action[0]
                if kind == "click":
                    glide_and_click(action[1], action[2] if len(action) > 2 else None)
                elif kind == "role":
                    btn = pg.get_by_role("button", name=action[1], exact=True)
                    box = btn.bounding_box()
                    if box and not args.no_cursor:
                        pg.evaluate("([x,y])=>window.__moveCursor(x,y)",
                                    [box["x"] + box["width"] / 2, box["y"] + box["height"] / 2])
                        pg.wait_for_timeout(520)
                        pg.evaluate("()=>window.__clickPulse()")
                    btn.click()
            remaining = cumulative - (time.monotonic() - t0)
            if remaining > 0:
                pg.wait_for_timeout(int(remaining * 1000))
            else:
                overruns.append((label, -remaining))
            elapsed = time.monotonic() - t0
            print(f"  {int(elapsed // 60)}:{elapsed - 60 * int(elapsed // 60):04.1f}  {label}")

        video = pg.video
        ctx.close()
        browser.close()
        raw = pathlib.Path(video.path())

    out = pathlib.Path(args.out).resolve()
    subprocess.run([ffmpeg_bin(), "-y", "-loglevel", "error", "-i", str(raw),
                    "-vf", f"scale={FRAME_W}:{FRAME_H}:force_original_aspect_ratio=decrease,"
                           f"pad={FRAME_W}:{FRAME_H}:(ow-iw)/2:(oh-ih)/2:color=0x0b1117,fps=30",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "20",
                    "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(out)], check=True)
    shutil.rmtree(tmp, ignore_errors=True)

    print(f"\n  {out}")
    print("  " + describe(out))

    if overruns:
        print("\n  beats that ran past their slot (the action itself took longer "
              "than the hold allowed):")
        for label, over in overruns:
            print(f"    {label}: +{over:.1f}s")
    if warnings:
        print("\n  WARNING: the webfont did not load, so the typography in this take "
              "is the system fallback, not Archivo.")


if __name__ == "__main__":
    main()

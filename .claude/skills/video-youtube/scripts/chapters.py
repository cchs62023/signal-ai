#!/usr/bin/env python3
"""YouTube 章節（Chapters）：從字幕推薦切點、驗證規則、產出說明欄文字並嵌進 mp4。

YouTube 認定章節有效的條件（任一不符就整個章節功能不會出現）：
  1. 第一個時間戳一定要是 0:00
  2. 至少 3 個章節
  3. 每個章節至少 10 秒
  4. 時間必須由小到大排

用法:
  # 從 SRT 推薦切點（依說話停頓），輸出成可以直接編輯的章節檔
  chapters.py suggest subs.srt --count 6 -o chapters.txt

  # 驗證章節檔並印出可貼到 YouTube 說明欄的文字
  chapters.py build chapters.txt --duration 180

  # 把章節嵌進 mp4（YouTube 讀說明欄，但本地播放器和其他平台讀這個）
  chapters.py embed chapters.txt in.mp4 out.mp4

章節檔格式，一行一個「時間 標題」:
  0:00 開場
  0:35 安裝設定
  1:20 實際操作
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

MIN_CHAPTER_SEC = 10
MIN_CHAPTERS = 3


def parse_ts(text):
    """'1:23' / '01:23' / '1:02:03' / '83' -> 秒"""
    text = text.strip()
    if re.fullmatch(r"\d+(\.\d+)?", text):
        return float(text)
    parts = text.split(":")
    if not all(re.fullmatch(r"\d+(\.\d+)?", p.strip()) for p in parts):
        raise ValueError(f"看不懂的時間格式: {text}")
    secs = 0.0
    for p in parts:
        secs = secs * 60 + float(p)
    return secs


def fmt_ts(seconds):
    """秒 -> YouTube 說明欄用的 0:00 / 1:02:03"""
    seconds = int(round(seconds))
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def read_srt(path):
    """回傳 [(start, end, text), ...]"""
    raw = Path(path).read_text(encoding="utf-8-sig")
    out = []
    for block in re.split(r"\n\s*\n", raw.strip()):
        lines = [l for l in block.splitlines() if l.strip()]
        if len(lines) < 2:
            continue
        m = re.search(r"(\d+:\d+:\d+[,.]\d+)\s*-->\s*(\d+:\d+:\d+[,.]\d+)", block)
        if not m:
            continue
        def to_sec(t):
            t = t.replace(",", ".")
            hh, mm, ss = t.split(":")
            return int(hh) * 3600 + int(mm) * 60 + float(ss)
        text = " ".join(l for l in lines
                        if "-->" not in l and not re.fullmatch(r"\d+", l.strip()))
        out.append((to_sec(m.group(1)), to_sec(m.group(2)), text.strip()))
    return out


def read_chapters(path):
    """章節檔 -> [(秒, 標題)]"""
    rows = []
    for n, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^([\d:.]+)\s+(.+)$", line)
        if not m:
            sys.exit(f"第 {n} 行格式不對（要「時間 標題」）: {line}")
        rows.append((parse_ts(m.group(1)), m.group(2).strip()))
    return rows


def validate(rows, duration=None):
    """回傳錯誤訊息清單，空的就是通過"""
    errs = []
    if not rows:
        return ["章節檔是空的"]
    if len(rows) < MIN_CHAPTERS:
        errs.append(f"只有 {len(rows)} 個章節，YouTube 至少要 {MIN_CHAPTERS} 個")
    if abs(rows[0][0]) > 0.001:
        errs.append(f"第一個章節必須從 0:00 開始（目前是 {fmt_ts(rows[0][0])}）")
    unsorted_ = False
    for i in range(1, len(rows)):
        if rows[i][0] <= rows[i - 1][0]:
            errs.append(f"時間沒有由小到大: {fmt_ts(rows[i-1][0])} -> {fmt_ts(rows[i][0])}")
            unsorted_ = True
    # 順序壞掉時每章長度算出來會是負的，再報一次只是雜訊，先修順序再說
    if unsorted_:
        return errs
    # 章節時間超過影片長度時直接講清楚，不要讓它變成一個看不懂的負秒數
    if duration:
        over = [(t, title) for t, title in rows if t >= duration]
        if over:
            for t, title in over:
                errs.append(f"「{title}」的時間 {fmt_ts(t)} 已經超過影片長度 {fmt_ts(duration)}")
            return errs
    ends = [rows[i + 1][0] for i in range(len(rows) - 1)]
    ends.append(duration if duration else rows[-1][0] + MIN_CHAPTER_SEC)
    for (start, title), end in zip(rows, ends):
        if end - start < MIN_CHAPTER_SEC:
            errs.append(f"「{title}」只有 {end-start:.0f} 秒，每章至少要 {MIN_CHAPTER_SEC} 秒")
    return errs


def cmd_suggest(args):
    subs = read_srt(args.srt)
    if not subs:
        sys.exit("SRT 裡沒有讀到字幕")
    total = subs[-1][1]

    # 依「說完一句到下一句的停頓」排序，停頓越久越可能是換段落
    gaps = []
    for i in range(1, len(subs)):
        gaps.append((subs[i][0] - subs[i - 1][1], i))
    gaps.sort(reverse=True)

    picked, wanted = [], max(MIN_CHAPTERS, args.count) - 1
    min_spacing = max(MIN_CHAPTER_SEC, total / (wanted + 1) * 0.4)
    for _, i in gaps:
        t = subs[i][0]
        if t < MIN_CHAPTER_SEC or total - t < MIN_CHAPTER_SEC:
            continue
        if all(abs(t - p) >= min_spacing for p in picked):
            picked.append(t)
        if len(picked) >= wanted:
            break
    picked.sort()

    lines = ["# 這是自動推薦的切點，標題請自己改成看得懂的名字",
             "# 規則: 第一個要是 0:00、至少 3 個、每章至少 10 秒", "",
             "0:00 開場"]
    for t in picked:
        nxt = next((s[2] for s in subs if s[0] >= t), "")
        lines.append(f"{fmt_ts(t)} {nxt[:20] or '待命名'}")

    text = "\n".join(lines) + "\n"
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
        print(f"==> 推薦 {len(picked)+1} 個章節 -> {args.output}", file=sys.stderr)
        print(f"    影片長 {fmt_ts(total)}，請編輯標題後再跑 build", file=sys.stderr)
    print(text)


def cmd_build(args):
    rows = read_chapters(args.chapters)
    errs = validate(rows, args.duration)
    if errs:
        print("章節不符合 YouTube 規則:", file=sys.stderr)
        for e in errs:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)
    print("# 貼到 YouTube 說明欄（要放在最前面幾行）", file=sys.stderr)
    for t, title in rows:
        print(f"{fmt_ts(t)} {title}")


def cmd_embed(args):
    rows = read_chapters(args.chapters)
    duration = float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", args.input],
        capture_output=True, text=True, check=True).stdout.strip())
    errs = validate(rows, duration)
    if errs:
        print("章節不符合 YouTube 規則:", file=sys.stderr)
        for e in errs:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)

    # ffmetadata 的時間單位用毫秒
    meta = [";FFMETADATA1"]
    bounds = [r[0] for r in rows[1:]] + [duration]
    for (start, title), end in zip(rows, bounds):
        meta += ["[CHAPTER]", "TIMEBASE=1/1000",
                 f"START={int(start*1000)}", f"END={int(end*1000)}",
                 f"title={title}"]
    mfile = Path(args.output).with_suffix(".ffmeta")
    mfile.write_text("\n".join(meta) + "\n", encoding="utf-8")

    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", args.input, "-i", str(mfile),
         "-map_metadata", "1", "-map_chapters", "1",
         "-c", "copy", "-movflags", "+faststart", args.output],
        check=True)
    mfile.unlink(missing_ok=True)
    print(f"==> 已嵌入 {len(rows)} 個章節", file=sys.stderr)
    print(args.output)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("suggest", help="從 SRT 推薦章節切點")
    s.add_argument("srt"); s.add_argument("--count", type=int, default=6)
    s.add_argument("-o", "--output"); s.set_defaults(func=cmd_suggest)

    b = sub.add_parser("build", help="驗證並印出說明欄文字")
    b.add_argument("chapters"); b.add_argument("--duration", type=float)
    b.set_defaults(func=cmd_build)

    e = sub.add_parser("embed", help="把章節寫進 mp4")
    e.add_argument("chapters"); e.add_argument("input"); e.add_argument("output")
    e.set_defaults(func=cmd_embed)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

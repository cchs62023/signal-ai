#!/usr/bin/env python3
"""工具 7 — 從 Pexels 找並下載 B-roll 空鏡。需要環境變數 PEXELS_API_KEY (免費申請)。

用法:
    broll.py "coding laptop" --count 3 --out-dir broll/      # 下載
    broll.py "startup office" --count 5 --dry-run            # 只列出不下載
預設只抓直式 (portrait) 素材，因為目標是 9:16 短影音。
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.pexels.com/videos/search"


def key():
    k = os.environ.get("PEXELS_API_KEY")
    if not k:
        sys.exit("未設定 PEXELS_API_KEY。到 https://www.pexels.com/api/ 免費申請後:\n"
                 "  export PEXELS_API_KEY=xxx")
    return k


def get(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"Pexels API {e.code}: {e.read().decode('utf-8', 'replace')[:300]}")
    except urllib.error.URLError as e:
        sys.exit(f"連不到 Pexels: {e.reason}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("query", help="英文關鍵字效果最好")
    ap.add_argument("--count", type=int, default=3)
    ap.add_argument("--out-dir", default="broll")
    ap.add_argument("--orientation", default="portrait",
                    choices=["portrait", "landscape", "square"])
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    qs = urllib.parse.urlencode({
        "query": args.query,
        "per_page": args.count,
        "orientation": args.orientation,
    })
    data = json.loads(get(f"{API}?{qs}", headers={"Authorization": key()}))
    videos = data.get("videos", [])
    if not videos:
        sys.exit(f"找不到 \"{args.query}\" 的素材，換個英文關鍵字試試")

    out_dir = Path(args.out_dir)
    if not args.dry_run:
        out_dir.mkdir(parents=True, exist_ok=True)

    for v in videos:
        # 挑解析度最高但不超過 1080 寬的檔，太大的下載很慢也用不到
        files = sorted(
            (f for f in v["video_files"] if f.get("width")),
            key=lambda f: (f["width"] > 1200, -f["width"]),
        )
        best = files[0]
        name = f"pexels_{v['id']}_{best['width']}x{best['height']}.mp4"
        # Pexels 授權免費商用免標示，但標示作者是好習慣
        print(f"{name}  {v['duration']}s  by {v['user']['name']}  {v['url']}")
        if args.dry_run:
            continue
        dest = out_dir / name
        if dest.exists():
            print(f"  已存在，跳過", file=sys.stderr)
            continue
        print(f"  下載中...", file=sys.stderr)
        dest.write_bytes(get(best["link"]))
        print(f"  -> {dest}", file=sys.stderr)


if __name__ == "__main__":
    main()

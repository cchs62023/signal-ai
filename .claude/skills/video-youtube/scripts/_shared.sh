#!/usr/bin/env bash
# 共用的小工具函式 + 找出 video-edit skill 的腳本目錄。
# 快剪、語音轉文字、配樂混音這三關兩個 skill 完全一樣，直接共用同一份，
# 不另外複製一份以免日後兩邊改到不同步。

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../video-edit/scripts" 2>/dev/null && pwd || true)"

need_shared() { # $1 = 檔名
  if [ -z "$SHARED_DIR" ] || [ ! -f "$SHARED_DIR/$1" ]; then
    echo "找不到共用腳本 video-edit/scripts/$1" >&2
    echo "video-youtube 的快剪/轉文字/混音是共用 video-edit skill 的，兩個要放在一起。" >&2
    return 1
  fi
  printf '%s\n' "$SHARED_DIR/$1"
}

need_bin() { command -v "$1" >/dev/null 2>&1 || { echo "$1 未安裝，先跑 scripts/setup.sh" >&2; return 1; }; }

vdims() { ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$1" | tr ',' ' '; }
vdur()  { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }
vfps()  { ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$1" | awk -F/ '{printf "%.0f", ($2?$1/$2:$1)}'; }
has_audio() { [ -n "$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1" | head -1)" ]; }

# 挑一個存在的中文字型檔（給 ImageMagick 用檔案路徑最可靠）
cjk_font_file() {
  local f
  f="$(fc-match -f "%{file}" "Noto Sans CJK TC:style=Bold" 2>/dev/null || true)"
  [ -f "${f:-}" ] || f="$(fc-match -f "%{file}" "sans-serif:lang=zh-tw:style=Bold" 2>/dev/null || true)"
  [ -f "${f:-}" ] && printf '%s\n' "$f"
}

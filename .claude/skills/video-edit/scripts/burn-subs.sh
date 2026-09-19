#!/usr/bin/env bash
# 工具 2 — 把 SRT 燒進畫面 (硬字幕；IG/TikTok 不吃軟字幕)。
# 用法: burn-subs.sh <input> <output> <subs.srt> [font-size] [font-name]
#
# 為什麼不直接 subtitles=xxx.srt:force_style=...？
# ffmpeg 把 SRT 轉 ASS 時會寫死 PlayResX=384 PlayResY=288，force_style 裡的
# FontSize / MarginV 都會被當成那個座標系的值再放大 6.7 倍 -> 字大到爆框。
# 所以這裡自己轉 ASS 並把 PlayRes 改成真實解析度，數字才是真的像素。
set -euo pipefail

IN="${1:?用法: burn-subs.sh <input> <output> <subs.srt> [size] [font]}"
OUT="${2:?缺少 output 路徑}"
SRT="${3:?缺少 .srt 路徑}"

[ -f "$IN" ]  || { echo "找不到影片: $IN" >&2; exit 1; }
[ -f "$SRT" ] || { echo "找不到字幕: $SRT" >&2; exit 1; }

read -r VW VH < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -of csv=p=0 "$IN" | tr ',' ' ')
[ -n "${VH:-}" ] || { echo "讀不到影片解析度" >&2; exit 1; }

# 字級預設抓畫面高度的 3.3%（1920 -> 約 64px），直式短影音這個大小最好讀
SIZE="${4:-$(python3 -c "print(max(24, round($VH * 0.033)))")}"
# 字幕底部留白：避開 IG/TikTok 底部的 UI，抓高度 17%
MARGINV="$(python3 -c "print(round($VH * 0.17))")"
MARGINH="$(python3 -c "print(round($VW * 0.06))")"
OUTLINE="$(python3 -c "print(max(2, round($SIZE * 0.09)))")"

# 挑一個真的存在的中文字型，避免豆腐字
FONT="${5:-}"
if [ -z "$FONT" ]; then
  for f in "Noto Sans CJK TC" "Noto Sans TC" "PingFang TC" "Heiti TC" "Microsoft JhengHei"; do
    if fc-list 2>/dev/null | grep -qF "$f"; then FONT="$f"; break; fi
  done
  [ -z "$FONT" ] && [ "$(uname -s)" = "Darwin" ] && FONT="PingFang TC"
  FONT="${FONT:-Noto Sans CJK TC}"
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ASS="$TMP/subs.ass"

ffmpeg -y -v error -i "$SRT" "$ASS"

# 1) PlayRes 改成真實解析度  2) 換掉 Default 樣式
python3 - "$ASS" "$VW" "$VH" "$FONT" "$SIZE" "$OUTLINE" "$MARGINH" "$MARGINV" <<'PY'
import re, sys
path, vw, vh, font, size, outline, mh, mv = sys.argv[1:9]
s = open(path, encoding="utf-8").read()
s = re.sub(r"(?m)^PlayResX:.*$", f"PlayResX: {vw}", s)
s = re.sub(r"(?m)^PlayResY:.*$", f"PlayResY: {vh}", s)
# &HAABBGGRR：白字、黑邊、半透明黑底
style = (f"Style: Default,{font},{size},&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,"
         f"1,0,0,0,100,100,0,0,1,{outline},2,2,{mh},{mh},{mv},1")
s = re.sub(r"(?m)^Style:\s*Default,.*$", style, s)
open(path, "w", encoding="utf-8").write(s)
PY

echo "==> 燒字幕 ${VW}x${VH} font=$FONT size=${SIZE}px marginV=${MARGINV}px"
ESC="$(printf '%s' "$ASS" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g" -e 's/:/\\:/g')"
ffmpeg -y -v error -stats -i "$IN" \
  -vf "subtitles='${ESC}'" \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
  -c:a copy -movflags +faststart "$OUT"

echo "$OUT"

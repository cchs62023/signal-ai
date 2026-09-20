#!/usr/bin/env bash
# 9:16 直式轉換 (1080x1920)。短影音的核心步驟。
# 用法: vertical.sh <input> <output> [mode]
#   blur  (預設) 整個畫面縮進去，上下用模糊背景補滿 — 螢幕錄影/demo 最安全，不會切到 UI
#   crop  中央裁切填滿 — 人像/特寫用，畫面兩側會被切掉
#   top   畫面靠上 + 下方留 35% 空間放字幕/字卡 — 講解型 demo 最好用
set -euo pipefail

IN="${1:?用法: vertical.sh <input> <output> [blur|crop|top]}"
OUT="${2:?缺少 output 路徑}"
MODE="${3:-blur}"
W=1080; H=1920

[ -f "$IN" ] || { echo "找不到檔案: $IN" >&2; exit 1; }

case "$MODE" in
  blur)
    # 背景先縮到 1/4 再模糊再放大 — 視覺一樣但快十幾倍
    VF="[0:v]scale=${W}:-2[fg];\
[0:v]scale=$((W/4)):$((H/4)):force_original_aspect_ratio=increase,crop=$((W/4)):$((H/4)),\
gblur=sigma=10,scale=${W}:${H},eq=brightness=-0.12[bg];\
[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1" ;;
  crop)
    VF="[0:v]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},setsar=1" ;;
  top)
    # 影片縮到 1080 寬，貼在上方 12% 處，下面留白給字幕。
    # color 是無限長的來源，overlay 一定要加 shortest=1，否則會無止境地輸出。
    VF="[0:v]scale=${W}:-2[fg];\
color=c=0x111318:s=${W}x${H}:r=30[bg];\
[bg][fg]overlay=(W-w)/2:H*0.12:shortest=1,setsar=1" ;;
  *) echo "mode 只能是 blur / crop / top" >&2; exit 1 ;;
esac

echo "==> 9:16 轉換 mode=$MODE"
ffmpeg -y -v error -stats -i "$IN" \
  -filter_complex "$VF" \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart "$OUT"

ffprobe -v error -show_entries stream=width,height -select_streams v:0 -of csv=p=0 "$OUT"
echo "$OUT"

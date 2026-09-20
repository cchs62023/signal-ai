#!/usr/bin/env bash
# 輸出成 YouTube 建議的上傳規格（母片品質，YouTube 收到後還會自己再壓一次）。
# 用法: export-youtube.sh <input> <output> [height=1080] [crf=18]
#   會做響度標準化到 -14 LUFS（YouTube 的播放基準），太大聲的影片上傳後會被壓，
#   自己先normalize好，聽起來比較穩。
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_shared.sh"

IN="${1:?用法: export-youtube.sh <input> <output> [height=1080] [crf=18]}"
OUT="${2:?缺少 output 路徑}"
H="${3:-1080}"
CRF="${4:-18}"
W="$(python3 -c "print(int($H*16/9//2*2))")"

[ -f "$IN" ] || { echo "找不到檔案: $IN" >&2; exit 1; }
need_bin ffmpeg || exit 1

FPS="$(vfps "$IN")"; FPS="${FPS:-30}"
GOP=$((FPS * 2))   # 關鍵影格每 2 秒一個，YouTube 的建議值

AF="loudnorm=I=-14:TP=-1.5:LRA=11"
has_audio "$IN" || AF=""

echo "==> 輸出 ${W}x${H} crf=$CRF fps=$FPS"
# shellcheck disable=SC2086
ffmpeg -nostdin -y -v error -stats -i "$IN" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,\
pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1" \
  -c:v libx264 -profile:v high -level 4.2 -preset slow -crf "$CRF" \
  -pix_fmt yuv420p -g "$GOP" -keyint_min "$FPS" -sc_threshold 0 \
  ${AF:+-af "$AF"} \
  -c:a aac -b:a 384k -ar 48000 -ac 2 \
  -movflags +faststart "$OUT"

echo "==> $OUT  $(python3 -c "print(round($(vdur "$OUT")))")s  $(du -h "$OUT" | cut -f1)"
echo "$OUT"

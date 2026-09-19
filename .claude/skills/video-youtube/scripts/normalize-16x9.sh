#!/usr/bin/env bash
# 把任何來源整理成 YouTube 的 16:9 標準規格 (預設 1920x1080)。
# 用法: normalize-16x9.sh <input> <output> [mode] [height]
#   pad  (預設) 等比縮放後補黑邊 — 不裁切任何畫面，螢幕錄影最安全
#   blur 補模糊背景而不是黑邊 — 來源是直式/方形時比黑邊好看
#   crop 裁切填滿 — 只有來源比例接近 16:9 時才用，否則會切掉東西
#   height 1080(預設) / 1440 / 2160
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_shared.sh"

IN="${1:?用法: normalize-16x9.sh <input> <output> [pad|blur|crop] [height=1080]}"
OUT="${2:?缺少 output 路徑}"
MODE="${3:-pad}"
H="${4:-1080}"
W="$(python3 -c "print(int($H * 16 / 9 // 2 * 2))")"

[ -f "$IN" ] || { echo "找不到檔案: $IN" >&2; exit 1; }
need_bin ffmpeg || exit 1

read -r SW SH < <(vdims "$IN")
echo "==> 16:9 轉換 ${SW}x${SH} -> ${W}x${H} mode=$MODE"

case "$MODE" in
  pad)
    VF="[0:v]scale=${W}:${H}:force_original_aspect_ratio=decrease,\
pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[v]" ;;
  blur)
    # 背景先縮小再模糊再放大，比直接在 full res 上 gblur 快十幾倍
    VF="[0:v]scale=${W}:${H}:force_original_aspect_ratio=decrease[fg];\
[0:v]scale=$((W/4)):$((H/4)):force_original_aspect_ratio=increase,crop=$((W/4)):$((H/4)),\
gblur=sigma=10,scale=${W}:${H},eq=brightness=-0.12[bg];\
[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[v]" ;;
  crop)
    VF="[0:v]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},setsar=1[v]" ;;
  *) echo "mode 只能是 pad / blur / crop" >&2; exit 1 ;;
esac

ffmpeg -y -v error -stats -i "$IN" \
  -filter_complex "$VF" -map "[v]" -map 0:a? \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 256k -movflags +faststart "$OUT"

read -r OW OH < <(vdims "$OUT")
echo "==> ${OW}x${OH}"
echo "$OUT"

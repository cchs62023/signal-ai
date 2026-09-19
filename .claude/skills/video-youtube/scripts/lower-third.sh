#!/usr/bin/env bash
# 下方名條（lower third）：在畫面左下角秀一段說明文字，橫式影片的標準作法。
# 用法: lower-third.sh <input> <output> "<主文>" ["<副文>"] [起秒] [持續秒]
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_shared.sh"

IN="${1:?用法: lower-third.sh <input> <output> \"主文\" [\"副文\"] [start=1] [dur=4]}"
OUT="${2:?缺少 output 路徑}"
TEXT="${3:?缺少文字}"
SUB="${4:-}"
START="${5:-1}"
DUR="${6:-4}"

[ -f "$IN" ] || { echo "找不到檔案: $IN" >&2; exit 1; }
need_bin ffmpeg || exit 1
IM=magick; command -v magick >/dev/null 2>&1 || IM=convert

read -r W H < <(vdims "$IN")
FPS="$(vfps "$IN")"; FPS="${FPS:-30}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

FONT_FILE="$(cjk_font_file || true)"
fa=(); [ -n "${FONT_FILE:-}" ] && fa=(-font "$FONT_FILE")
PT=$((W*28/1000)); SPT=$((W*17/1000)); BOXW=$((W*45/100))

render() { # 文字 字級 顏色 輸出
  local sw; sw="$(python3 -c "print(max(2,round($2*0.1)))")"
  "$IM" -background none "${fa[@]}" -pointsize "$2" -size "${BOXW}x" -gravity west \
    -fill '#0B0D12' -stroke '#0B0D12' -strokewidth "$sw" caption:"$1" +repage "PNG32:$TMP/_o.png"
  "$IM" -background none "${fa[@]}" -pointsize "$2" -size "${BOXW}x" -gravity west \
    -fill "$3" -stroke none caption:"$1" +repage "PNG32:$TMP/_f.png"
  "$IM" "$TMP/_o.png" "$TMP/_f.png" -gravity west -composite +repage "PNG32:$4"
}

render "$TEXT" "$PT" white "$TMP/t.png"
if [ -n "$SUB" ]; then
  render "$SUB" "$SPT" '#9FB4D0' "$TMP/s.png"
  "$IM" "$TMP/t.png" "$TMP/s.png" -background none -gravity west -append +repage "PNG32:$TMP/txt.png"
else cp "$TMP/t.png" "$TMP/txt.png"; fi

# 左側加一條亮色直條，是名條的常見視覺語彙
"$IM" "$TMP/txt.png" -bordercolor none -border 24x18 +repage \
  \( +clone -background '#000000' -shadow 60x12+0+0 \) +swap -background none -layers merge +repage "$TMP/sh.png"
"$IM" "$TMP/sh.png" \( -size "6x$(identify -format '%h' "$TMP/sh.png")" xc:'#4C8DFF' \) \
  -gravity west -composite +repage "PNG32:$TMP/card.png"

END="$(python3 -c "print(round($START+$DUR,3))")"
FO="$(python3 -c "print(round(max($START,$END-0.4),3))")"

echo "==> 名條 [${START}s~${END}s] \"$TEXT\""
# 圖片輸入一定要 -loop 1，單張 PNG 只有 t=0 一格，fade 的 st>0 會讓它整個變透明
ffmpeg -nostdin -y -v error -stats -i "$IN" -loop 1 -framerate "$FPS" -i "$TMP/card.png" \
  -filter_complex "[1:v]format=rgba,fade=t=in:st=${START}:d=0.4:alpha=1,\
fade=t=out:st=${FO}:d=0.4:alpha=1[ov];\
[0:v][ov]overlay=W*0.055:H*0.76:enable='between(t,${START},${END})':shortest=1[v]" \
  -map "[v]" -map 0:a? -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a copy -movflags +faststart "$OUT"

echo "$OUT"

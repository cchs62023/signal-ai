#!/usr/bin/env bash
# 工具 4 — 上字卡：ImageMagick 產透明 PNG，再用 ffmpeg 疊上去（含淡入淡出）。
# 用法: titlecard.sh <input> <output> "<主標>" ["<副標>"] [起秒] [持續秒] [位置]
#   位置: top(預設) / center / bottom
#
# 兩個踩過的雷，改動前先看懂：
#  1) -fill 白 + -stroke 深色 同時下，描邊會「吃進」筆劃，中文字會糊成一團。
#     正解是描邊層和填色層分開畫，再把填色疊在描邊上。
#  2) 圖片輸入要加 -loop 1。單張 PNG 只有 t=0 一格，fade 的 st>0 會把那格
#     算成 alpha=0，整張字卡就永遠透明（畫面上什麼都看不到）。
#  3) 每個 ImageMagick 步驟後面要 +repage。-append / -composite 會留下舊的
#     page offset，不清掉的話圖層會錯位，主標下面跑出一個黑色殘影。
set -euo pipefail

IN="${1:?用法: titlecard.sh <input> <output> \"主標\" [\"副標\"] [start=0] [dur=3] [pos=top]}"
OUT="${2:?缺少 output 路徑}"
TITLE="${3:?缺少標題文字}"
SUB="${4:-}"
START="${5:-0}"
DUR="${6:-3}"
POS="${7:-top}"

[ -f "$IN" ] || { echo "找不到影片: $IN" >&2; exit 1; }
IM=magick; command -v magick >/dev/null 2>&1 || IM=convert
command -v "$IM" >/dev/null || { echo "imagemagick 未安裝，先跑 scripts/setup.sh" >&2; exit 1; }

read -r VW VH < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -of csv=p=0 "$IN" | tr ',' ' ')
FPS="$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
  -of csv=p=0 "$IN" | awk -F/ '{printf "%.0f", ($2?$1/$2:$1)}')"
FPS="${FPS:-30}"

# 餵字型「檔案路徑」給 ImageMagick，比用字型名稱可靠（名稱常常對不上）
FONT_FILE="$(fc-match -f "%{file}" "Noto Sans CJK TC:style=Bold" 2>/dev/null || true)"
[ -f "${FONT_FILE:-}" ] || FONT_FILE="$(fc-match -f "%{file}" "sans-serif:lang=zh-tw:style=Bold" 2>/dev/null || true)"
FONT_ARG=(); [ -f "${FONT_FILE:-}" ] && FONT_ARG=(-font "$FONT_FILE")

MAIN_PT="$(python3 -c "print(round($VW * 0.085))")"
SUB_PT="$(python3 -c "print(round($VW * 0.045))")"
BOXW="$(python3 -c "print(round($VW * 0.88))")"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
CARD="$TMP/card.png"

# 描邊層 + 填色層分開畫再疊
render_text() { # $1=文字 $2=字級 $3=填色 $4=輸出
  local txt="$1" pt="$2" fill="$3" out="$4"
  local sw; sw="$(python3 -c "print(max(2, round($pt * 0.11)))")"
  "$IM" -background none "${FONT_ARG[@]}" -pointsize "$pt" -size "${BOXW}x" -gravity center \
        -fill '#0D1117' -stroke '#0D1117' -strokewidth "$sw" caption:"$txt" +repage "PNG32:$TMP/_o.png"
  "$IM" -background none "${FONT_ARG[@]}" -pointsize "$pt" -size "${BOXW}x" -gravity center \
        -fill "$fill" -stroke none caption:"$txt" +repage "PNG32:$TMP/_f.png"
  "$IM" "$TMP/_o.png" "$TMP/_f.png" -gravity center -composite +repage "PNG32:$out"
}

render_text "$TITLE" "$MAIN_PT" white "$TMP/main.png"
if [ -n "$SUB" ]; then
  render_text "$SUB" "$SUB_PT" '#FFD966' "$TMP/sub.png"
  "$IM" "$TMP/main.png" "$TMP/sub.png" -background none -gravity center \
        -append +repage "PNG32:$CARD"
else
  cp "$TMP/main.png" "$CARD"
fi

case "$POS" in
  top)    Y="H*0.08" ;;
  center) Y="(H-h)/2" ;;
  bottom) Y="H*0.72" ;;
  *) echo "位置只能是 top / center / bottom" >&2; exit 1 ;;
esac

END="$(python3 -c "print(round($START + $DUR, 3))")"
FADE_OUT="$(python3 -c "print(round(max($START, $END - 0.4), 3))")"

echo "==> 上字卡 [${START}s~${END}s] pos=$POS \"$TITLE\""
ffmpeg -y -v error -stats -i "$IN" -loop 1 -framerate "$FPS" -i "$CARD" \
  -filter_complex "[1:v]format=rgba,\
fade=t=in:st=${START}:d=0.4:alpha=1,fade=t=out:st=${FADE_OUT}:d=0.4:alpha=1[ov];\
[0:v][ov]overlay=(W-w)/2:${Y}:enable='between(t,${START},${END})':shortest=1[v]" \
  -map "[v]" -map 0:a? \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p \
  -c:a copy -movflags +faststart "$OUT"

echo "$OUT"

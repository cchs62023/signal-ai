#!/usr/bin/env bash
# YouTube 封面縮圖：從影片抓一格做成 1280x720 封面，可加大字。
# 用法: thumbnail.sh <input> <output.jpg> [抓第幾秒] ["主標"] ["副標"] [位置]
#   位置: left(預設) / right / center
# YouTube 規格: 1280x720、16:9、JPG/PNG/GIF、2MB 以內。
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_shared.sh"

IN="${1:?用法: thumbnail.sh <input> <out.jpg> [秒=3] [\"主標\"] [\"副標\"] [left|right|center]}"
OUT="${2:?缺少 output 路徑}"
AT="${3:-3}"
TITLE="${4:-}"
SUB="${5:-}"
POS="${6:-left}"
W=1280; H=720

[ -f "$IN" ] || { echo "找不到檔案: $IN" >&2; exit 1; }
need_bin ffmpeg || exit 1
IM=magick; command -v magick >/dev/null 2>&1 || IM=convert
need_bin "$IM" || exit 1

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# 抓一格並補成 1280x720
ffmpeg -y -v error -ss "$AT" -i "$IN" -frames:v 1 \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,\
pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1" \
  -q:v 2 "$TMP/base.jpg"
[ -s "$TMP/base.jpg" ] || { echo "抓不到影格，${AT}s 可能超過影片長度" >&2; exit 1; }

if [ -n "$TITLE" ]; then
  FONT_FILE="$(cjk_font_file || true)"
  FONT_ARG=(); [ -n "${FONT_FILE:-}" ] && FONT_ARG=(-font "$FONT_FILE")
  BOXW=$((W * 46 / 100))

  # 描邊層和填色層要分開畫再疊；同時下 -fill 和 -stroke 會把中文筆劃吃掉。
  # 每步都要 +repage，否則 -composite 之後會留下錯位殘影。
  render() { # $1文字 $2字級 $3顏色 $4輸出
    local sw; sw="$(python3 -c "print(max(3, round($2 * 0.13)))")"
    "$IM" -background none "${FONT_ARG[@]}" -pointsize "$2" -size "${BOXW}x" -gravity west \
          -fill '#0B0D12' -stroke '#0B0D12' -strokewidth "$sw" caption:"$1" +repage "PNG32:$TMP/_o.png"
    "$IM" -background none "${FONT_ARG[@]}" -pointsize "$2" -size "${BOXW}x" -gravity west \
          -fill "$3" -stroke none caption:"$1" +repage "PNG32:$TMP/_f.png"
    "$IM" "$TMP/_o.png" "$TMP/_f.png" -gravity west -composite +repage "PNG32:$4"
  }

  render "$TITLE" 96 white "$TMP/t.png"
  if [ -n "$SUB" ]; then
    render "$SUB" 48 '#FFD966' "$TMP/s.png"
    "$IM" "$TMP/t.png" "$TMP/s.png" -background none -gravity west -append +repage "PNG32:$TMP/txt.png"
  else
    cp "$TMP/t.png" "$TMP/txt.png"
  fi

  case "$POS" in
    left)   GRAV=west;   OFF="+64+0" ;;
    right)  GRAV=east;   OFF="+64+0" ;;
    center) GRAV=center; OFF="+0+0"  ;;
    *) echo "位置只能是 left / right / center" >&2; exit 1 ;;
  esac

  # 文字那側壓一層深色漸層，字才不會被背景吃掉。
  # 注意: ImageMagick 的 gradient: 只會由上往下，要做左右漸層得先轉 90 度；
  # 而且帶 alpha 的顏色轉完會掉透明度，所以改成「純黑 + 灰階遮罩當 alpha」。
  GW=$((W * 55 / 100))
  "$IM" -size "${GW}x${H}" xc:black \
    \( -size "${H}x${GW}" gradient:black-gray80 -rotate 90 +repage \) \
    -alpha off -compose CopyOpacity -composite +repage "PNG32:$TMP/scrim.png"
  [ "$POS" = right ] && "$IM" "$TMP/scrim.png" -flop +repage "PNG32:$TMP/scrim.png"
  if [ "$POS" = center ]; then
    "$IM" "$TMP/base.jpg" -fill black -colorize 35% "$TMP/dim.jpg"
  else
    "$IM" "$TMP/base.jpg" "$TMP/scrim.png" \
      -gravity "$([ "$POS" = right ] && echo east || echo west)" -composite +repage "$TMP/dim.jpg"
  fi

  "$IM" "$TMP/dim.jpg" "$TMP/txt.png" -gravity "$GRAV" -geometry "$OFF" \
        -composite +repage -quality 92 "$OUT"
else
  cp "$TMP/base.jpg" "$OUT"
fi

# 壓到 2MB 以內（YouTube 的硬限制）
for q in 92 85 78 70 60; do
  BYTES=$(wc -c < "$OUT")
  [ "$BYTES" -le 2000000 ] && break
  "$IM" "$OUT" -quality "$q" "$OUT"
done

BYTES=$(wc -c < "$OUT")
echo "==> 封面 $(identify -format '%wx%h' "$OUT" 2>/dev/null) $((BYTES/1024))KB"
[ "$BYTES" -gt 2000000 ] && echo "   警告: 超過 YouTube 的 2MB 上限" >&2
echo "$OUT"

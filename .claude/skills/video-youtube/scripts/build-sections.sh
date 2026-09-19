#!/usr/bin/env bash
# 把多段素材依「章節設定檔」組成一支完整影片，並自動產生章節時間表。
# 專門給「一支影片分成好幾個功能段落」的 demo 用。
#
# 用法: build-sections.sh <sections.txt> <output.mp4> [選項]
#   --no-cards      不要插入章節標題卡
#   --card-sec N    標題卡秒數 (預設 2.5)
#   --height N      輸出高度 (預設 1080)
#   --chapters FILE 章節表輸出路徑 (預設 <output>.chapters.txt)
#   --keep          保留中間檔
#
# sections.txt 每行一段，用 | 分隔，# 開頭是註解:
#   影片檔 | 章節標題 | 開始秒 | 結束秒 | 副標
#   開始/結束/副標 可留空
# 例:
#   onboarding.mp4 | 建立學習檔案 | 0 | 32 | 系統先問你怎麼學
#   sequencing.mp4 | 循序提問     | 4 | 48 |
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_shared.sh"

SPEC=""; OUT=""; CARDS=1; CARD_SEC=2.5; H=1080; CHAP=""; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-cards)  CARDS=0; shift ;;
    --card-sec)  CARD_SEC="$2"; shift 2 ;;
    --height)    H="$2"; shift 2 ;;
    --chapters)  CHAP="$2"; shift 2 ;;
    --keep)      KEEP=1; shift ;;
    -h|--help)   sed -n '2,22p' "$0"; exit 0 ;;
    -*) echo "不認識的選項: $1" >&2; exit 1 ;;
    *) if [ -z "$SPEC" ]; then SPEC="$1"; else OUT="$1"; fi; shift ;;
  esac
done

[ -n "$SPEC" ] && [ -n "$OUT" ] || { sed -n '2,22p' "$0"; exit 1; }
[ -f "$SPEC" ] || { echo "找不到設定檔: $SPEC" >&2; exit 1; }
need_bin ffmpeg || exit 1
CHAP="${CHAP:-${OUT%.*}.chapters.txt}"

W="$(python3 -c "print(int($H*16/9//2*2))")"
FPS=30
WORK="$(mktemp -d)"
cleanup(){ [ "$KEEP" -eq 1 ] && echo "中間檔: $WORK" || rm -rf "$WORK"; }
trap cleanup EXIT

FONT_FILE="$(cjk_font_file || true)"
IM=magick; command -v magick >/dev/null 2>&1 || IM=convert

# 所有段落都轉成完全一致的規格，concat 才不會出問題
norm_args=(-c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p
           -r "$FPS" -c:a aac -b:a 256k -ar 48000 -ac 2)

make_card() { # $1標題 $2副標 $3輸出
  local title="$1" sub="$2" out="$3"
  local fa=(); [ -n "${FONT_FILE:-}" ] && fa=(-font "$FONT_FILE")
  local boxw=$((W*80/100)) pt=$((W*62/1000)) spt=$((W*30/1000))
  render() { # 文字 字級 顏色 輸出  (描邊層和填色層分開畫，否則中文筆劃會被吃掉)
    local sw; sw="$(python3 -c "print(max(3,round($2*0.12)))")"
    "$IM" -background none "${fa[@]}" -pointsize "$2" -size "${boxw}x" -gravity center \
      -fill '#0B0D12' -stroke '#0B0D12' -strokewidth "$sw" caption:"$1" +repage "PNG32:$WORK/_o.png"
    "$IM" -background none "${fa[@]}" -pointsize "$2" -size "${boxw}x" -gravity center \
      -fill "$3" -stroke none caption:"$1" +repage "PNG32:$WORK/_f.png"
    "$IM" "$WORK/_o.png" "$WORK/_f.png" -gravity center -composite +repage "PNG32:$4"
  }
  render "$title" "$pt" white "$WORK/_t.png"
  if [ -n "$sub" ]; then
    render "$sub" "$spt" '#9FB4D0' "$WORK/_s.png"
    "$IM" "$WORK/_t.png" "$WORK/_s.png" -background none -gravity center -append +repage "PNG32:$WORK/_c.png"
  else cp "$WORK/_t.png" "$WORK/_c.png"; fi
  "$IM" -size "${W}x${H}" xc:'#0B0D12' "$WORK/_c.png" -gravity center -composite +repage "$WORK/_card.png"

  # 靜音音軌一定要補，否則 concat 時音訊軌對不齊會爆
  ffmpeg -nostdin -y -v error -loop 1 -i "$WORK/_card.png" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
    -t "$CARD_SEC" -vf "fade=t=in:st=0:d=0.3,fade=t=out:st=$(python3 -c "print(max(0,$CARD_SEC-0.3))"):d=0.3,setsar=1" \
    "${norm_args[@]}" -shortest "$out"
}

# 注意: 迴圈是用 stdin 讀 $SPEC 的，ffmpeg 預設也會吃 stdin，
# 不加 -nostdin 的話它會把設定檔剩下的行全部吞掉，結果只處理到第一段。
LIST="$WORK/list.txt"; : > "$LIST"
: > "$CHAP"
ACC=0; N=0

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  IFS='|' read -r CLIP TITLE SS TO SUB <<< "$line"
  CLIP="$(echo "$CLIP" | xargs)"; TITLE="$(echo "${TITLE:-}" | xargs)"
  SS="$(echo "${SS:-}" | xargs)"; TO="$(echo "${TO:-}" | xargs)"; SUB="$(echo "${SUB:-}" | xargs)"
  [ -f "$CLIP" ] || { echo "找不到素材: $CLIP" >&2; exit 1; }
  N=$((N+1))

  # 章節時間 = 標題卡開始的位置（觀眾點章節會從卡片看起，比較順）
  printf '%s %s\n' "$(python3 -c "
s=int(round($ACC)); h,r=divmod(s,3600); m,x=divmod(r,60)
print(f'{h}:{m:02d}:{x:02d}' if h else f'{m}:{x:02d}')")" "${TITLE:-段落 $N}" >> "$CHAP"

  if [ "$CARDS" -eq 1 ] && [ -n "$TITLE" ]; then
    echo "  [$N] 標題卡「$TITLE」"
    make_card "$TITLE" "$SUB" "$WORK/seg_${N}_card.mp4"
    printf "file '%s'\n" "$WORK/seg_${N}_card.mp4" >> "$LIST"
    ACC="$(python3 -c "print($ACC + $CARD_SEC)")"
  fi

  TRIM=()
  [ -n "$SS" ] && TRIM+=(-ss "$SS")
  [ -n "$TO" ] && TRIM+=(-to "$TO")
  echo "  [$N] $CLIP ${SS:+從 ${SS}s}${TO:+ 到 ${TO}s}"
  # -ss 放在 -i 前面是快速定位，但要精準切就得重新編碼（本來就要轉檔所以沒差）
  ffmpeg -nostdin -y -v error "${TRIM[@]}" -i "$CLIP" \
    -filter_complex "[0:v]scale=${W}:${H}:force_original_aspect_ratio=decrease,\
pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=${FPS}[v]" \
    -map "[v]" -map 0:a? -map_metadata -1 "${norm_args[@]}" "$WORK/seg_${N}.mp4"

  # 原始素材沒有聲音的話補一軌靜音，不然 concat 會少一軌
  if ! has_audio "$WORK/seg_${N}.mp4"; then
    ffmpeg -nostdin -y -v error -i "$WORK/seg_${N}.mp4" \
      -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
      -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest "$WORK/seg_${N}_a.mp4"
    mv "$WORK/seg_${N}_a.mp4" "$WORK/seg_${N}.mp4"
  fi

  printf "file '%s'\n" "$WORK/seg_${N}.mp4" >> "$LIST"
  ACC="$(python3 -c "print($ACC + $(vdur "$WORK/seg_${N}.mp4"))")"
done < "$SPEC"

[ "$N" -gt 0 ] || { echo "設定檔裡沒有任何段落" >&2; exit 1; }

echo "==> 串接 $N 段"
ffmpeg -nostdin -y -v error -stats -f concat -safe 0 -i "$LIST" \
  -c copy -movflags +faststart "$OUT"

echo "==> $OUT  ($(python3 -c "print(round($(vdur "$OUT")))")s, $(vdims "$OUT" | tr ' ' 'x'))"
echo "==> 章節表 $CHAP"
cat "$CHAP"

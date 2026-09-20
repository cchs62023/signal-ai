#!/usr/bin/env bash
# 一條龍：素材 -> 可以直接上傳 YouTube 的 16:9 影片 + 字幕 + 章節 + 封面。
#
# 用法:
#   make-youtube.sh <input.mp4> [選項]          單一檔案
#   make-youtube.sh --sections sections.txt [選項]   多段素材（會自動產生章節）
#
# 選項:
#   -o, --output FILE   輸出檔 (預設 <input>_youtube.mp4)
#   --title "文字"       封面主標（有給才會做封面）
#   --sub "文字"         封面副標
#   --thumb-at N        封面抓第幾秒 (預設 5)
#   --no-subs           跳過語音轉文字/字幕
#   --no-cut            跳過自動快剪（多段模式預設就不快剪）
#   --cut               多段模式也要快剪
#   -w, --whisper M     whisper 模型 (預設 small)
#   -l, --lang L        語言 (預設 zh)
#   --height N          輸出高度 (預設 1080)
#   --keep              保留中間檔
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_shared.sh"

IN=""; SECTIONS=""; OUT=""; TITLE=""; SUB=""; THUMB_AT=5
DO_SUBS=1; DO_CUT=-1; WMODEL="small"; LANG_="zh"; H=1080; KEEP=0

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output)  OUT="$2"; shift 2 ;;
    --sections)   SECTIONS="$2"; shift 2 ;;
    --title)      TITLE="$2"; shift 2 ;;
    --sub)        SUB="$2"; shift 2 ;;
    --thumb-at)   THUMB_AT="$2"; shift 2 ;;
    --no-subs)    DO_SUBS=0; shift ;;
    --no-cut)     DO_CUT=0; shift ;;
    --cut)        DO_CUT=1; shift ;;
    -w|--whisper) WMODEL="$2"; shift 2 ;;
    -l|--lang)    LANG_="$2"; shift 2 ;;
    --height)     H="$2"; shift 2 ;;
    --keep)       KEEP=1; shift ;;
    -h|--help)    sed -n '2,24p' "$0"; exit 0 ;;
    -*) echo "不認識的選項: $1" >&2; exit 1 ;;
    *) IN="$1"; shift ;;
  esac
done

[ -n "$IN" ] || [ -n "$SECTIONS" ] || { sed -n '2,24p' "$0"; exit 1; }
# 單檔模式預設會快剪；多段模式預設不剪（段落已經自己挑好了）
[ "$DO_CUT" -eq -1 ] && { [ -n "$SECTIONS" ] && DO_CUT=0 || DO_CUT=1; }

BASE="$(basename "${IN:-${SECTIONS%.*}}")"; BASE="${BASE%.*}"
OUT="${OUT:-${BASE}_youtube.mp4}"
STEM="${OUT%.*}"

WORK="$(mktemp -d)"
cleanup(){ [ "$KEEP" -eq 1 ] && echo "中間檔: $WORK" || rm -rf "$WORK"; }
trap cleanup EXIT

STEP=0
# 一定會跑的兩關: 整理成 16:9、輸出
TOTAL=2
[ -n "$SECTIONS" ] && TOTAL=$((TOTAL+1))
[ "$DO_CUT" -eq 1 ] && TOTAL=$((TOTAL+1))
[ "$DO_SUBS" -eq 1 ] && TOTAL=$((TOTAL+2))
[ -n "$TITLE" ] && TOTAL=$((TOTAL+1))
step(){ STEP=$((STEP+1)); printf '\n\033[1;36m[%s/%s] %s\033[0m\n' "$STEP" "$TOTAL" "$1"; }

CHAPTERS=""

# 1 多段素材先組起來
if [ -n "$SECTIONS" ]; then
  step "組合多段素材"
  bash "$HERE/build-sections.sh" "$SECTIONS" "$WORK/joined.mp4" \
    --height "$H" --chapters "$WORK/chapters.txt" >/dev/null
  CUR="$WORK/joined.mp4"; CHAPTERS="$WORK/chapters.txt"
else
  CUR="$IN"
fi

# 2 自動快剪
if [ "$DO_CUT" -eq 1 ]; then
  step "自動快剪"
  AE="$(need_shared autocut.sh)" || exit 1
  # 長片的 margin 放寬一點，切太緊聽起來會很趕
  bash "$AE" "$CUR" "$WORK/cut.mp4" "4%" "0.35s" >/dev/null
  CUR="$WORK/cut.mp4"
fi

# 3 統一成 16:9
step "整理成 16:9"
bash "$HERE/normalize-16x9.sh" "$CUR" "$WORK/norm.mp4" pad "$H" >/dev/null
CUR="$WORK/norm.mp4"

# 4+5 字幕（YouTube 用軟字幕，不燒進畫面）
if [ "$DO_SUBS" -eq 1 ]; then
  step "語音轉文字 (whisper $WMODEL)"
  TR="$(need_shared transcribe.py)" || exit 1
  if python3 "$TR" "$CUR" --out-dir "$WORK" --model "$WMODEL" --lang "$LANG_" >/dev/null; then
    step "掛上軟字幕"
    LANG3=zho; [ "$LANG_" = "en" ] && LANG3=eng
    bash "$HERE/soft-subs.sh" "$CUR" "$WORK/subbed.mp4" "$WORK/norm.srt" "$LANG3" >/dev/null
    CUR="$WORK/subbed.mp4"
    cp -f "$WORK/norm.srt" "${STEM}.srt"
    cp -f "$WORK/norm.txt" "${STEM}.txt"
  else
    step "轉文字失敗，跳過字幕"
  fi
fi

# 6 封面
if [ -n "$TITLE" ]; then
  step "做封面縮圖"
  bash "$HERE/thumbnail.sh" "$CUR" "${STEM}_thumb.jpg" "$THUMB_AT" "$TITLE" "$SUB" left >/dev/null
fi

# 7 輸出
step "輸出 YouTube 規格"
bash "$HERE/export-youtube.sh" "$CUR" "$OUT" "$H" 18 >/dev/null

# 章節：寫進 mp4，並留一份給說明欄
if [ -n "$CHAPTERS" ] && [ -s "$CHAPTERS" ]; then
  cp -f "$CHAPTERS" "${STEM}.chapters.txt"
  if python3 "$HERE/chapters.py" embed "$CHAPTERS" "$OUT" "$WORK/ch.mp4" >/dev/null 2>&1; then
    mv "$WORK/ch.mp4" "$OUT"
  else
    echo "  （章節不符合 YouTube 規則，沒有嵌進檔案；${STEM}.chapters.txt 仍可自己調整）" >&2
  fi
fi

DUR="$(python3 -c "print(round($(vdur "$OUT")))")"
printf '\n\033[1;32m完成\033[0m %s  (%ss, %s, %s)\n' \
  "$OUT" "$DUR" "$(vdims "$OUT" | tr ' ' 'x')" "$(du -h "$OUT" | cut -f1)"
echo "上傳時記得一起用:"
[ -f "${STEM}.srt" ]           && echo "  字幕   ${STEM}.srt"
[ -f "${STEM}_thumb.jpg" ]     && echo "  封面   ${STEM}_thumb.jpg"
[ -f "${STEM}.chapters.txt" ]  && echo "  章節   ${STEM}.chapters.txt （貼到說明欄最前面）"

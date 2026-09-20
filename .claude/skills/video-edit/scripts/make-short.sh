#!/usr/bin/env bash
# 一條龍：原始 demo 影片 -> 9:16 短影音（快剪 + 字幕 + 字卡 + 配樂）。
# 用法:
#   make-short.sh <input.mp4> [options]
# 選項:
#   -o, --output FILE     輸出檔 (預設 <input>_short.mp4)
#   -t, --title "文字"     開頭字卡主標
#   -s, --subtitle "文字"  開頭字卡副標
#   -m, --mode MODE       9:16 模式 blur|crop|top (預設 top)
#   -b, --bgm FILE        配樂檔
#   -w, --whisper MODEL   whisper 模型 (預設 small)
#   -l, --lang LANG       語言 (預設 zh)
#   --threshold VAL       快剪靜音門檻 (預設 4%)
#   --no-cut              跳過自動快剪
#   --no-subs             跳過字幕
#   --keep                保留中間檔（除錯用）
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IN=""; OUT=""; TITLE=""; SUBTITLE=""; MODE="top"; BGM=""
WMODEL="small"; LANG_="zh"; THRESH="4%"
DO_CUT=1; DO_SUBS=1; KEEP=0

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output)   OUT="$2"; shift 2 ;;
    -t|--title)    TITLE="$2"; shift 2 ;;
    -s|--subtitle) SUBTITLE="$2"; shift 2 ;;
    -m|--mode)     MODE="$2"; shift 2 ;;
    -b|--bgm)      BGM="$2"; shift 2 ;;
    -w|--whisper)  WMODEL="$2"; shift 2 ;;
    -l|--lang)     LANG_="$2"; shift 2 ;;
    --threshold)   THRESH="$2"; shift 2 ;;
    --no-cut)      DO_CUT=0; shift ;;
    --no-subs)     DO_SUBS=0; shift ;;
    --keep)        KEEP=1; shift ;;
    -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
    -*) echo "不認識的選項: $1" >&2; exit 1 ;;
    *)  IN="$1"; shift ;;
  esac
done

[ -n "$IN" ] || { sed -n '2,20p' "$0"; exit 1; }
[ -f "$IN" ] || { echo "找不到檔案: $IN" >&2; exit 1; }
BASE="$(basename "${IN%.*}")"
OUT="${OUT:-${BASE}_short.mp4}"

WORK="$(mktemp -d)"
cleanup() { [ "$KEEP" -eq 1 ] && echo "中間檔留在 $WORK" || rm -rf "$WORK"; }
trap cleanup EXIT

STEP=0
# 快剪、9:16、字卡 這三關不管做不做都會印一行；字幕開啟時是兩關(轉文字+燒字幕)
TOTAL=3
[ "$DO_SUBS" -eq 1 ] && TOTAL=$((TOTAL + 2)) || TOTAL=$((TOTAL + 1))
[ -n "$BGM" ] && TOTAL=$((TOTAL + 1))
step() { STEP=$((STEP + 1)); printf '\n\033[1;36m[%s/%s] %s\033[0m\n' "$STEP" "$TOTAL" "$1"; }

CUR="$IN"

# 1 快剪 — 一定要在轉字幕之前，不然字幕時間軸會對不上剪過的畫面
if [ "$DO_CUT" -eq 1 ]; then
  step "自動快剪"
  bash "$HERE/autocut.sh" "$CUR" "$WORK/cut.mp4" "$THRESH" >/dev/null
  CUR="$WORK/cut.mp4"
else
  step "跳過快剪"
fi

# 2 轉 9:16
step "轉 9:16 ($MODE)"
bash "$HERE/vertical.sh" "$CUR" "$WORK/vert.mp4" "$MODE" >/dev/null
CUR="$WORK/vert.mp4"

# 3 轉文字 + 4 燒字幕
if [ "$DO_SUBS" -eq 1 ]; then
  step "語音轉文字 (whisper $WMODEL)"
  if python3 "$HERE/transcribe.py" "$CUR" --out-dir "$WORK" \
       --model "$WMODEL" --lang "$LANG_" >/dev/null; then
    step "燒字幕"
    bash "$HERE/burn-subs.sh" "$CUR" "$WORK/subbed.mp4" "$WORK/vert.srt" >/dev/null
    CUR="$WORK/subbed.mp4"
    cp "$WORK/vert.srt" "${OUT%.*}.srt" 2>/dev/null || true
    cp "$WORK/vert.txt" "${OUT%.*}.txt" 2>/dev/null || true
  else
    echo "  轉文字失敗，跳過字幕（其他步驟照跑）" >&2
  fi
else
  step "跳過字幕"
fi

# 5 字卡
if [ -n "$TITLE" ]; then
  step "上字卡"
  bash "$HERE/titlecard.sh" "$CUR" "$WORK/titled.mp4" "$TITLE" "$SUBTITLE" 0.5 3.5 top >/dev/null
  CUR="$WORK/titled.mp4"
else
  step "沒給標題，跳過字卡"
fi

# 6 配樂
if [ -n "$BGM" ]; then
  step "配樂混音"
  bash "$HERE/mix-audio.sh" "$CUR" "$WORK/mixed.mp4" "$BGM" >/dev/null
  CUR="$WORK/mixed.mp4"
fi

cp "$CUR" "$OUT"
DUR="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" | cut -d. -f1)"
SIZE="$(du -h "$OUT" | cut -f1)"
printf '\n\033[1;32m完成\033[0m %s  (%ss, %s, 1080x1920)\n' "$OUT" "$DUR" "$SIZE"

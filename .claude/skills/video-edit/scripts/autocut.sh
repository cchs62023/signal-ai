#!/usr/bin/env bash
# 工具 3 — 自動快剪：用 auto-editor 砍掉靜音/廢話段落。
# 用法: autocut.sh <input> <output> [threshold] [margin]
#   threshold 靜音判定門檻，預設 4%。錄音底噪大就調高 (6~8%)，講話小聲就調低 (2~3%)。
#   margin    每段前後保留的緩衝，預設 0.2s。太小會切掉字頭字尾。
set -euo pipefail

IN="${1:?用法: autocut.sh <input> <output> [threshold=4%] [margin=0.2s]}"
OUT="${2:?缺少 output 路徑}"
THRESH="${3:-4%}"
MARGIN="${4:-0.2s}"

[ -f "$IN" ] || { echo "找不到檔案: $IN" >&2; exit 1; }
command -v auto-editor >/dev/null || { echo "auto-editor 未安裝，先跑 scripts/setup.sh" >&2; exit 1; }

dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null | cut -d. -f1; }
BEFORE="$(dur "$IN")"

echo "==> 自動快剪 threshold=$THRESH margin=$MARGIN"
auto-editor "$IN" \
  --edit "audio:threshold=$THRESH" \
  --margin "$MARGIN" \
  --when-silent cut \
  --no-open --progress none \
  -o "$OUT"

AFTER="$(dur "$OUT")"
echo "==> ${BEFORE}s -> ${AFTER}s (省下 $(( BEFORE - AFTER ))s)"
echo "$OUT"

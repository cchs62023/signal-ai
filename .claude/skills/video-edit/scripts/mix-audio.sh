#!/usr/bin/env bash
# 工具 6 — 配樂混音：BGM 疊在人聲底下，用 sidechaincompress 自動閃避 (講話時音樂自動變小)。
# 用法: mix-audio.sh <input> <output> <bgm> [bgm音量=0.18] [淡出秒=2]
set -euo pipefail

IN="${1:?用法: mix-audio.sh <input> <output> <bgm.mp3> [vol=0.18] [fade=2]}"
OUT="${2:?缺少 output 路徑}"
BGM="${3:?缺少 BGM 檔}"
VOL="${4:-0.18}"
FADE="${5:-2}"

[ -f "$IN" ]  || { echo "找不到影片: $IN" >&2; exit 1; }
[ -f "$BGM" ] || { echo "找不到配樂: $BGM" >&2; exit 1; }

# 影片有沒有音軌？沒有的話直接把 BGM 當唯一音軌
HAS_AUDIO="$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$IN" | head -1)"
DUR="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$IN")"
FADE_ST="$(python3 -c "print(max(0, $DUR - $FADE))")"

if [ -z "$HAS_AUDIO" ]; then
  echo "==> 影片無音軌，直接鋪 BGM"
  ffmpeg -y -v error -stats -i "$IN" -stream_loop -1 -i "$BGM" \
    -filter_complex "[1:a]volume=${VOL},afade=t=out:st=${FADE_ST}:d=${FADE}[a]" \
    -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -shortest \
    -movflags +faststart "$OUT"
else
  echo "==> 混音 人聲 + BGM(${VOL}) 自動閃避"
  ffmpeg -y -v error -stats -i "$IN" -stream_loop -1 -i "$BGM" \
    -filter_complex "\
[0:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,dynaudnorm=f=200:g=5[voice];\
[1:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,volume=${VOL}[music];\
[voice]asplit=2[voice_out][sc];\
[music][sc]sidechaincompress=threshold=0.05:ratio=8:attack=20:release=400[ducked];\
[voice_out][ducked]amix=inputs=2:duration=first:dropout_transition=0,\
afade=t=out:st=${FADE_ST}:d=${FADE},alimiter=limit=0.95[a]" \
    -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k \
    -movflags +faststart "$OUT"
fi

echo "$OUT"

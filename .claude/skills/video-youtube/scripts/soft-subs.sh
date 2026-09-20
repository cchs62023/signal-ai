#!/usr/bin/env bash
# 把 SRT 掛成「軟字幕」軌道（YouTube 用軟字幕，不要燒死在畫面上）。
# 用法: soft-subs.sh <input> <output> <subs.srt> [語言碼=zho]
#
# 為什麼 YouTube 不要燒字幕：
#  - 觀眾可以自己開關，手機/電視上不會和播放器 UI 打架
#  - YouTube 會索引字幕內容，對搜尋有幫助
#  - 之後要改錯字只要重傳字幕檔，不用重新編碼整支影片
# 真正建議的做法是「上傳影片時另外上傳 .srt」，這支只是順便把字幕也存進 mp4。
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_shared.sh"

IN="${1:?用法: soft-subs.sh <input> <output> <subs.srt> [lang=zho]}"
OUT="${2:?缺少 output 路徑}"
SRT="${3:?缺少 .srt 路徑}"
LANG3="${4:-zho}"

[ -f "$IN" ]  || { echo "找不到影片: $IN" >&2; exit 1; }
[ -f "$SRT" ] || { echo "找不到字幕: $SRT" >&2; exit 1; }
need_bin ffmpeg || exit 1

echo "==> 掛軟字幕 ($LANG3)"
# mp4 的字幕格式是 mov_text；影音都 copy，不重新編碼所以沒有畫質損失
ffmpeg -y -v error -stats -i "$IN" -i "$SRT" \
  -map 0:v -map 0:a? -map 1:0 \
  -c:v copy -c:a copy -c:s mov_text \
  -metadata:s:s:0 language="$LANG3" \
  -metadata:s:s:0 handler_name="$LANG3 subtitles" \
  -movflags +faststart "$OUT"

# 同時把 .srt 放到輸出檔旁邊，上傳 YouTube 時用這個
cp -f "$SRT" "${OUT%.*}.srt"
echo "==> 軟字幕已掛上；上傳時請另外選 ${OUT%.*}.srt"
echo "$OUT"

#!/usr/bin/env bash
# 工具鏈和 video-edit skill 完全一樣，直接沿用同一支安裝腳本，避免兩邊裝的版本不同。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="$HERE/../../video-edit/scripts/setup.sh"

if [ -f "$SHARED" ]; then
  exec bash "$SHARED"
fi

echo "找不到 $SHARED" >&2
echo "video-youtube 的安裝是共用 video-edit skill 的，請確認兩個 skill 都在 .claude/skills/ 底下。" >&2
echo "或手動安裝: ffmpeg imagemagick fonts-noto-cjk + pip install auto-editor faster-whisper" >&2
exit 1

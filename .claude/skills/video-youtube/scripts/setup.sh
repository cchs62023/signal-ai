#!/usr/bin/env bash
# 工具鏈和 video-edit skill 完全一樣，直接沿用同一支安裝腳本，避免兩邊裝的版本不同。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="$HERE/../../video-edit/scripts/setup.sh"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "偵測到 Windows (Git Bash)。" >&2
    echo "安裝請改用 PowerShell 跑:" >&2
    echo "  powershell -ExecutionPolicy Bypass -File .claude\\skills\\video-youtube\\scripts\\setup.ps1" >&2
    echo "詳細說明看 .claude/skills/video-youtube/WINDOWS.md" >&2
    exit 1 ;;
esac

if [ -f "$SHARED" ]; then
  exec bash "$SHARED"
fi

echo "找不到 $SHARED" >&2
echo "video-youtube 的安裝是共用 video-edit skill 的，請確認兩個 skill 都在 .claude/skills/ 底下。" >&2
echo "或手動安裝: ffmpeg imagemagick fonts-noto-cjk + pip install auto-editor faster-whisper" >&2
exit 1

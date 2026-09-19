#!/usr/bin/env bash
# 安裝影片剪輯工具鏈 (7 個工具)。可重複執行，已安裝的會跳過。
set -uo pipefail

OS="$(uname -s)"
FAIL=0
note() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
miss() { printf '  \033[31mfail\033[0m %s\n' "$*"; FAIL=1; }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---- 系統套件: ffmpeg (工具 2/6) + imagemagick (工具 4) + CJK 字型 ----
note "系統套件 ffmpeg / imagemagick / 中文字型"
if [ "$OS" = "Darwin" ]; then
  have brew || { miss "需要 Homebrew: https://brew.sh"; exit 1; }
  for p in ffmpeg imagemagick; do
    have "${p/imagemagick/magick}" || brew install "$p"
  done
  brew list --cask font-noto-sans-cjk >/dev/null 2>&1 || brew install --cask font-noto-sans-cjk 2>/dev/null || warn "字型請自行安裝 (系統內建 PingFang 也可用)"
else
  SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
  $SUDO apt-get update -qq
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq ffmpeg imagemagick fonts-noto-cjk
fi

# ---- Python 套件: auto-editor (工具 3) + faster-whisper (工具 1/2) ----
note "Python 套件 auto-editor / faster-whisper"
PIPFLAGS="--quiet"
python3 -c 'import sys; sys.exit(0)' 2>/dev/null || { miss "找不到 python3"; exit 1; }
# Debian/Ubuntu 的 PEP668 需要這個旗標
pip3 install $PIPFLAGS --break-system-packages auto-editor faster-whisper 2>/dev/null \
  || pip3 install $PIPFLAGS auto-editor faster-whisper

# auto-editor 首次執行會下載平台 binary，先觸發
have auto-editor && auto-editor --version >/dev/null 2>&1

# ---- 驗證 ----
note "驗證"
have ffmpeg      && ok "1,2,6 ffmpeg  $(ffmpeg -version | head -1 | cut -d' ' -f3)"   || miss "ffmpeg"
have ffprobe     && ok "    ffprobe"                                                  || miss "ffprobe"
have auto-editor && ok "3   auto-editor $(auto-editor --version 2>/dev/null | tail -1)" || miss "auto-editor"
if have magick; then ok "4   imagemagick $(magick -version | head -1 | cut -d' ' -f3)"
elif have convert; then ok "4   imagemagick $(convert -version | head -1 | cut -d' ' -f3)"
else miss "imagemagick"; fi
python3 -c "import faster_whisper" 2>/dev/null && ok "1,2 faster-whisper" || miss "faster-whisper"

# 中文字型 (燒字幕必需)
if fc-list 2>/dev/null | grep -qiE "CJK TC|PingFang|Heiti"; then ok "    中文字型"
elif [ "$OS" = "Darwin" ]; then ok "    中文字型 (macOS 內建)"
else warn "找不到中文字型，燒中文字幕會變成豆腐字"; fi

# ---- 需要 API key 的工具 (選用) ----
note "選用 API (沒有 key 就跳過該步驟，其他照跑)"
[ -n "${ELEVENLABS_API_KEY:-}" ] && ok "5   ElevenLabs 配音" || warn "5   未設定 ELEVENLABS_API_KEY -> 配音不可用"
[ -n "${PEXELS_API_KEY:-}" ]     && ok "7   Pexels B-roll"   || warn "7   未設定 PEXELS_API_KEY -> 自動找 B-roll 不可用"

echo
[ "$FAIL" -eq 0 ] && note "工具鏈就緒 ✅" || { note "有工具沒裝成功 ❌"; exit 1; }

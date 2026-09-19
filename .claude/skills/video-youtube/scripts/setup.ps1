# Windows 安裝腳本。在 PowerShell 裡跑:
#   powershell -ExecutionPolicy Bypass -File .claude\skills\video-youtube\scripts\setup.ps1
#
# 裝 ffmpeg / ImageMagick / Git(含 Git Bash) / Python 套件。
# 剪輯腳本本身是 bash，要用 Git Bash 執行（這支會一併把 Git 裝好）。

$ErrorActionPreference = "Continue"
function Note($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  ok   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  warn $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "  fail $m" -ForegroundColor Red }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Fail "找不到 winget。請先從 Microsoft Store 更新「應用程式安裝程式」(App Installer)，"
  Write-Host "     或改用 WSL: 在 PowerShell 跑  wsl --install -d Ubuntu" -ForegroundColor Yellow
  exit 1
}

Note "安裝 ffmpeg / ImageMagick / Git"
foreach ($pkg in @(
    @{id="Gyan.FFmpeg";                 name="ffmpeg"},
    @{id="ImageMagick.ImageMagick";     name="ImageMagick"},
    @{id="Git.Git";                     name="Git (含 Git Bash)"},
    @{id="Python.Python.3.12";          name="Python 3.12"}
)) {
  Write-Host "  - $($pkg.name)"
  winget install --id $($pkg.id) --accept-source-agreements --accept-package-agreements --silent --disable-interactivity 2>&1 | Out-Null
}

# winget 裝完的東西要重新讀 PATH 才找得到
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

Note "安裝 Python 套件 auto-editor / faster-whisper"
$py = (Get-Command python -ErrorAction SilentlyContinue)
if ($py) {
  & python -m pip install --quiet --upgrade pip 2>&1 | Out-Null
  & python -m pip install --quiet auto-editor faster-whisper 2>&1 | Out-Null
} else {
  Warn "找不到 python，請關掉這個視窗重開再跑一次（PATH 還沒更新）"
}

Note "驗證"
$fail = $false
foreach ($c in @(
    @{cmd="ffmpeg";      label="1,2,6 ffmpeg"},
    @{cmd="ffprobe";     label="    ffprobe"},
    @{cmd="magick";      label="4   ImageMagick"},
    @{cmd="bash";        label="    Git Bash"},
    @{cmd="auto-editor"; label="3   auto-editor"}
)) {
  if (Get-Command $c.cmd -ErrorAction SilentlyContinue) { Ok $c.label }
  else { Fail "$($c.label)  (找不到 $($c.cmd))"; $fail = $true }
}
& python -c "import faster_whisper" 2>$null
if ($LASTEXITCODE -eq 0) { Ok "1,2 faster-whisper" } else { Fail "faster-whisper"; $fail = $true }

Write-Host ""
if ($fail) {
  Warn "有東西沒裝好。最常見的原因是 PATH 還沒更新 —— 關掉 PowerShell 重開再跑一次這支就好。"
  exit 1
} else {
  Note "工具鏈就緒。接下來請用 Git Bash（不是 PowerShell）執行剪輯指令:"
  Write-Host '  & "C:\Program Files\Git\bin\bash.exe" -l' -ForegroundColor White
}

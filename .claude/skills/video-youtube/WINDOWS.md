# Windows 怎麼跑

剪輯腳本是 bash 寫的，**PowerShell 不能直接執行**。兩條路，選一條就好。

---

## 路線 A：Git Bash（不用重開機，推薦先試這個）

**1. 裝工具** —— 在 PowerShell 跑一次：

```powershell
powershell -ExecutionPolicy Bypass -File .claude\skills\video-youtube\scripts\setup.ps1
```

裝完**把 PowerShell 關掉重開**（PATH 要重新載入），再跑一次上面那行確認全綠。

**2. 開 Git Bash**（不是 PowerShell）：

開始功能表搜尋「Git Bash」，或在 PowerShell 打：

```powershell
& "C:\Program Files\Git\bin\bash.exe" -l
```

**3. 之後所有指令都在 Git Bash 裡打**，路徑用斜線 `/`：

```bash
cd /c/Users/month/signal-ai/video

bash ../.claude/skills/video-youtube/scripts/make-youtube.sh \
  --sections sections.txt -o signal_demo_youtube.mp4 \
  --title "Signal AI" --sub "Decisions, traced back to the source"
```

---

## 路線 B：WSL（要重開機，但環境跟我測試的一模一樣）

```powershell
wsl --install -d Ubuntu
```

重開機，設好帳號密碼，然後在 Ubuntu 視窗裡：

```bash
cd /mnt/c/Users/month/signal-ai
bash .claude/skills/video-youtube/scripts/setup.sh
```

之後照 `README.md` 的指令跑就好，跟 Linux 完全一樣。

WSL 讀 Windows 磁碟的路徑是 `/mnt/c/...`，例如
`C:\Users\month\signal-ai` 就是 `/mnt/c/Users/month/signal-ai`。

---

## PowerShell 語法的三個坑

如果你堅持要在 PowerShell 裡串指令，注意這些（但剪輯腳本還是得用 bash）：

| bash | PowerShell |
|---|---|
| `a && b` | `a; if ($?) { b }`（PowerShell 7 以上才支援 `&&`） |
| 換行接續 `\` | 用反引號 `` ` `` |
| `$(cmd)` | `$(cmd)` 一樣，但 `$()` 裡是 PowerShell 語法 |

你剛才遇到的錯就是這三個：`bash` 不存在、`&&` 在 PowerShell 5.1 不合法、
`\` 不是 PowerShell 的換行符號。

---

## 常見狀況

**「找不到 winget」** —— 到 Microsoft Store 更新「應用程式安裝程式 / App Installer」，
或直接走路線 B 用 WSL。

**setup.ps1 跑完還是說找不到 ffmpeg** —— 幾乎都是 PATH 沒更新。
關掉 PowerShell 重開，再跑一次。

**中文字卡變成方框** —— Windows 內建的「微軟正黑體」(msjh.ttc) 會被自動抓到。
如果還是不行，直接指定字型檔：腳本的字型偵測在
`scripts/_shared.sh` 的 `cjk_font_file()`。

**還沒把 repo 抓下來** —— 先 clone：

```bash
cd /c/Users/month
git clone https://github.com/cchs62023/signal-ai.git
cd signal-ai
git checkout claude/lucid-babbage-begu3k
```

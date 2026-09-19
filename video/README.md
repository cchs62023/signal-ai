# Signal AI — YouTube demo

**成品：`signal_demo_youtube.mp4` — 2:53, 1920x1080, 30fps, H.264 High, 30MB, 8 章節已嵌入**

| 檔案 | 用途 |
|---|---|
| `signal_demo_youtube.mp4` | 影片本體（**無聲**，等你的旁白） |
| `signal_demo_thumb.jpg` | 1280x720 封面 |
| `cut.chapters.txt` | 貼到 YouTube 說明欄**最前面** |
| `script.md` | 對好秒數的旁白稿 |
| `sections.txt` | 段落設定，要改剪輯就改這個 |
| `raw/` | 原始素材（已 gitignore，從 release 抓的） |

## 章節

```
0:00 The problem
0:20 Signal in the background
0:49 One decision
1:03 Where the info came from
1:23 Ask and decide
1:53 Who decides what
2:10 The call is yours
2:25 How it was built
```

## 這支影片怎麼組出來的

素材是逐格看過畫面後對出來的時間點，不是憑檔案長度猜的：

| 段落 | 來源 | 原片區間 | 速度 |
|---|---|---|---|
| The problem | `1.signal.handdrawing` | 4–56s | 2.9x 縮時 |
| Signal in the background | `5.final.prototype.demo` | 0–26s | 原速 |
| One decision | 同上 | 26–38s | 原速 |
| Where the info came from | 同上 | 38–50s | **0.7x 放慢**（讓人讀得完那條來源鏈） |
| Ask and decide | 同上 | 50–77s | 原速 |
| Who decides what | 同上 | 77–92s | 原速 |
| The call is yours | 同上 | 92–104s | 原速 |
| How it was built | `2.figma` / `3.chatgpt` / `4.claude.code` | 各自開頭 | 1.6x / 1.3x / 1.6x |

`5.final.prototype.demo` 的最後 4 秒（回到 Gmail）沒有用到，那是錄影的收尾。
`OTHERS-.SIGNAL.status-motion.mp4` 也沒用到 —— 它是 orb 的狀態動畫素材，
如果想放在開頭當 logo 動畫可以加進 `sections.txt`。

## 要改剪輯

改 `sections.txt` 的秒數或順序，然後重跑：

```bash
bash ../.claude/skills/video-youtube/scripts/build-sections.sh sections.txt cut.mp4 --card-sec 2.5
```

## 錄好旁白之後

看 `script.md` 最後一段，兩行指令就能把旁白和字幕都接上去。

## 重新下載素材

```bash
mkdir -p raw && cd raw
B=https://github.com/cchs62023/signal-ai/releases/download/video-assets
for f in 1.signal.handdrawing 2.signal.process.in.figma 3.signal.process.in.chatgpt \
         4.signal.process.in.claude.code 5.signal.final.prototype.demo; do
  curl -sSLO "$B/$f.mp4"
done
```

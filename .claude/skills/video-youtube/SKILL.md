---
name: video-youtube
description: 把 demo / 教學 / 產品影片剪成 16:9 橫式 YouTube 影片。多段素材自動組合並產生章節（Chapters）、語音轉軟字幕、封面縮圖、下方名條、輸出 YouTube 建議規格。當使用者要做 YouTube 影片、剪 16:9 橫式影片、把多段 demo 接成一支完整影片、需要章節或封面、或要上傳前的規格轉檔時使用。短影音直式 9:16 請改用 video-edit skill。
---

# YouTube 16:9 影片剪輯

把素材做成可以直接上傳 YouTube 的橫式影片，連字幕、章節、封面一起產出。

**要做直式短影音（IG Reels / TikTok / Shorts）請用 `video-edit` skill，不要用這個。**

## 第一次使用

```bash
bash .claude/skills/video-youtube/scripts/setup.sh
```

工具鏈和 `video-edit` 共用同一份（ffmpeg、ImageMagick、auto-editor、faster-whisper、中文字型），
所以兩個 skill 要放在一起。快剪和語音轉文字是直接呼叫 `video-edit` 的腳本，不重複維護。

## 多段素材（最常見的 demo 情境）

一支影片分成好幾個功能段落時，寫一個章節設定檔就好：

```
# sections.txt — 影片檔 | 章節標題 | 開始秒 | 結束秒 | 副標
onboarding.mp4  | 建立學習檔案 | 0 | 32 | 系統先問你怎麼學
sequencing.mp4  | 循序提問     | 4 | 48 |
format.mp4      | 調整輸出格式 | 0 | 30 |
```

開始/結束/副標可以留空。然後一行跑完：

```bash
bash .claude/skills/video-youtube/scripts/make-youtube.sh \
  --sections sections.txt -o demo_youtube.mp4 \
  --title "Signal AI" --sub "學習型 AI 助理"
```

會產出：

| 檔案 | 用途 |
|---|---|
| `demo_youtube.mp4` | 影片本體（章節已嵌入） |
| `demo_youtube.srt` | 上傳時另外選這個當字幕 |
| `demo_youtube.chapters.txt` | 貼到說明欄最前面，章節才會出現 |
| `demo_youtube_thumb.jpg` | 1280x720 封面 |
| `demo_youtube.txt` | 逐字稿 |

每段前面會自動插一張標題卡，章節時間點就對在卡片上，觀眾點章節會從標題看起。

## 單一檔案

```bash
bash .claude/skills/video-youtube/scripts/make-youtube.sh demo.mp4 \
  --title "Signal AI Demo"
```

單檔模式預設會自動快剪（砍掉靜音），多段模式預設不剪（段落你已經自己挑好了）。
要反過來就加 `--no-cut` 或 `--cut`。

常用選項：

| 選項 | 說明 |
|---|---|
| `-o FILE` | 輸出檔名 |
| `--title` / `--sub` | 封面主標 / 副標（有給才會做封面） |
| `--thumb-at N` | 封面抓第幾秒，預設 5 |
| `--height N` | 1080(預設) / 1440 / 2160 |
| `-w MODEL` | whisper 模型，預設 `small`，要更準用 `medium` |
| `-l LANG` | 語言，預設 `zh` |
| `--no-subs` | 跳過字幕 |
| `--keep` | 保留中間檔，出問題時看是哪一關壞的 |

## 拆開來跑

```bash
S=.claude/skills/video-youtube/scripts

# 組合多段 + 產章節表
bash $S/build-sections.sh sections.txt joined.mp4

# 統一成 16:9（pad 補黑邊 / blur 補模糊背景 / crop 裁切）
bash $S/normalize-16x9.sh in.mp4 norm.mp4 pad 1080

# 語音轉文字（共用 video-edit 的腳本）
python3 .claude/skills/video-edit/scripts/transcribe.py norm.mp4 --model small --lang zh

# 掛軟字幕（YouTube 用軟字幕，不要燒進畫面）
bash $S/soft-subs.sh norm.mp4 subbed.mp4 norm.srt zho

# 下方名條
bash $S/lower-third.sh subbed.mp4 lt.mp4 "循序提問" "Sequential Question Handling" 12 4

# 封面
bash $S/thumbnail.sh lt.mp4 thumb.jpg 5 "Signal AI" "學習型 AI 助理" left

# 章節
python3 $S/chapters.py suggest norm.srt --count 6 -o chapters.txt   # 從字幕推薦切點
python3 $S/chapters.py build chapters.txt --duration 180            # 驗證 + 印說明欄文字
python3 $S/chapters.py embed chapters.txt in.mp4 out.mp4            # 寫進 mp4

# 輸出上傳規格
bash $S/export-youtube.sh lt.mp4 final.mp4 1080 18
```

## YouTube 的幾個硬規則

**字幕不要燒進畫面。** YouTube 吃軟字幕，觀眾可以自己開關、平台會索引內容對搜尋有幫助、
之後改錯字只要重傳 `.srt` 不用重壓影片。`soft-subs.sh` 會把字幕掛進 mp4，
但**上傳時請另外把 `.srt` 也選進去**，那個才是 YouTube 真正會用的。

**章節有四個條件，任一不符整個章節功能就不會出現：**

1. 第一個時間戳一定要是 `0:00`
2. 至少 3 個章節
3. 每個章節至少 10 秒
4. 時間由小到大排

`chapters.py` 每次都會驗這四條，不合會直接擋下來並告訴你是哪一條。

**封面** 1280x720、2MB 以內。`thumbnail.sh` 會自動降品質壓到 2MB 以下。

**長度** 3 分鐘以內的 demo 很適合 YouTube 一般影片。
但如果成品剛好 60 秒以內又是直式，YouTube 會判定成 Shorts —— 要避免的話別做成直式。

## 決定用哪個 16:9 模式

| 模式 | 適合 | 代價 |
|---|---|---|
| `pad` | 螢幕錄影、來源本來就接近 16:9（**預設**） | 左右或上下有黑邊 |
| `blur` | 來源是直式或方形 | 一樣有邊，但填了模糊背景比較不空 |
| `crop` | 來源比例很接近 16:9 時微調用 | **會裁掉畫面**，直式素材用這個會切掉一大半 |

## 參數調整

- **字幕有錯字** → 直接改 `.srt` 再跑 `soft-subs.sh`，不用重跑 whisper（而且上傳的是 `.srt`，改完重傳就好）
- **章節被擋下來** → 照它印的原因改 `chapters.txt`，最常見的是最後一段不到 10 秒
- **封面字被背景吃掉** → 換 `--thumb-at` 抓別的時間點，或把位置改成 `right`
- **檔案太大** → `export-youtube.sh in out 1080 21`，crf 調大一點
- **中文變豆腐字（□□□）** → 沒有中文字型，重跑 `setup.sh`
- **多段組合失敗** → 加 `--keep` 看中間檔，通常是某段素材路徑錯或檔案壞了

## 注意

- 每一關都會重新編碼。要微調就改參數重跑，不要把輸出再餵回去疊。
- whisper 第一次執行會從 HuggingFace 下載模型（`small` 約 500MB），要能連外網。
- 中文轉錄務必帶 `--lang zh`。
- `build-sections.sh` 會把所有素材統一成同樣的解析度/fps/音訊規格再串接，
  所以不同來源、不同尺寸、甚至沒有音軌的素材可以混著用。

細部的 ffmpeg 寫法和踩過的雷看 `reference.md`。

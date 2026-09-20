---
name: video-edit
description: 把錄好的 demo / 教學 / 說話影片剪成 9:16 直式短影音（IG Reels、TikTok、YouTube Shorts）。自動快剪去掉靜音、語音轉字幕並燒進畫面、上標題字卡、配樂混音、抓 B-roll 空鏡。當使用者要剪影片、做短影音、上字幕、把橫式影片轉直式、壓縮 demo 長度、或問 ffmpeg / whisper / auto-editor 怎麼用時使用。
---

# 短影音自動剪輯

把一段錄好的影片變成可以直接發的 9:16 短影音。全部用 CLI 工具，不用開剪輯軟體。

## 第一次使用

```bash
bash .claude/skills/video-edit/scripts/setup.sh
```

裝 ffmpeg、ImageMagick、auto-editor、faster-whisper 和中文字型，可重複執行。
最後會印一份檢查表，哪個沒裝好會標紅。

## 最快的做法

一行把整條流程跑完：

```bash
bash .claude/skills/video-edit/scripts/make-short.sh demo.mp4 \
  -t "30 秒看懂 Signal AI" \
  -s "AI 自動剪輯 Demo" \
  -b bgm.mp3
```

輸出 `demo_short.mp4`（1080x1920）外加 `demo_short.srt`、`demo_short.txt`。

常用選項：

| 選項 | 說明 |
|---|---|
| `-o FILE` | 輸出檔名 |
| `-t / -s` | 開頭字卡的主標 / 副標 |
| `-m MODE` | 9:16 模式 `top`(預設) / `blur` / `crop` |
| `-b FILE` | 配樂 |
| `-w MODEL` | whisper 模型，預設 `small`，要更準用 `medium` |
| `-l LANG` | 語言，預設 `zh` |
| `--threshold` | 快剪靜音門檻，預設 `4%` |
| `--no-cut` / `--no-subs` | 跳過快剪 / 字幕 |
| `--keep` | 保留中間檔，出問題時拿來看是哪一關壞的 |

## 拆開來跑

要微調某一關時，各步驟可以單獨執行。**順序有差**，照這個來：

```bash
S=.claude/skills/video-edit/scripts

# 1 快剪：砍掉靜音。一定要在轉字幕之前做，否則字幕時間軸對不上剪過的畫面
bash $S/autocut.sh demo.mp4 cut.mp4 4% 0.2s

# 2 轉 9:16
bash $S/vertical.sh cut.mp4 vert.mp4 top

# 3 轉文字 -> 產生 vert.srt 和 vert.txt（先看過稿子再燒，錯字現在改最省事）
python3 $S/transcribe.py vert.mp4 --model small --lang zh

# 4 燒字幕（硬字幕，IG/TikTok 不吃軟字幕）
bash $S/burn-subs.sh vert.mp4 subbed.mp4 vert.srt

# 5 上字卡
bash $S/titlecard.sh subbed.mp4 titled.mp4 "主標" "副標" 0.5 3.5 top

# 6 配樂（BGM 自動閃避人聲）
bash $S/mix-audio.sh titled.mp4 final.mp4 bgm.mp3

# 7 找 B-roll 空鏡（選用，要 PEXELS_API_KEY）
python3 $S/broll.py "coding laptop" --count 3 --out-dir broll/

# 配音（選用，要 ELEVENLABS_API_KEY）
python3 $S/voiceover.py --file script.txt vo.mp3
```

## 3 分鐘 demo 要怎麼剪

三分鐘對短影音來說太長了，平台和觀眾都吃不下。實際要做的是**選段**，不是把三分鐘壓縮：

1. 先轉文字拿到全文，**用逐字稿決定要留哪 30～60 秒**，不要憑印象選
   ```bash
   python3 $S/transcribe.py demo.mp4 --model small
   cat demo.txt
   ```
2. 用 `ffmpeg -ss/-to` 把要的段落切出來（時間點從 SRT 上抓）
   ```bash
   ffmpeg -i demo.mp4 -ss 00:00:42 -to 00:01:18 -c copy part1.mp4
   ```
   多段就切多個檔再接起來，`reference.md` 有無損接片的寫法。
3. 接好之後再跑 `make-short.sh`

前 3 秒決定觀眾走不走，把最有結果的畫面放最前面，不要從「大家好我是」開始。

## 決定用哪個 9:16 模式

| 模式 | 適合 | 代價 |
|---|---|---|
| `top` | 螢幕錄影、demo、教學（**預設**） | 畫面變小，下面是留白 |
| `blur` | 想填滿整個畫面、風格化 | 一樣變小，但背景有模糊襯底 |
| `crop` | 人像、特寫 | **左右會被裁掉**，螢幕錄影用這個會切掉 UI |

demo 影片基本上不要用 `crop`，程式碼和介面一定會被切掉。

## 參數調整

- **快剪切掉了字頭字尾** → 加大 margin：`autocut.sh in out 4% 0.4s`
- **該切的沒切掉** → 提高門檻到 `6%`～`8%`（底噪大時）
- **句子被切碎** → 降到 `2%`～`3%`
- **字幕有錯字** → 直接改 `.srt` 再跑 `burn-subs.sh`，不用重跑 whisper
- **字幕太大/太小** → `burn-subs.sh in out subs.srt 72`（第四個參數是像素）
- **中文變成豆腐字（□□□）** → 沒有中文字型，重跑 `setup.sh`
- **配樂蓋過人聲** → 調低音量：`mix-audio.sh in out bgm.mp3 0.10`

## 注意

- 每一關都會重新編碼，畫質會累積損失。要微調就改參數重跑，不要把輸出再餵回去疊。
- whisper 第一次執行會從 HuggingFace 下載模型權重（`small` 約 500MB），要能連外網。
- 中文轉錄務必帶 `--lang zh`，不指定有機會被當成別的語言。
- Pexels 素材可免費商用且不用標示，但標作者是好習慣。ElevenLabs 和 Pexels 都要自己申請 key。

細部的 ffmpeg 寫法（切片、接片、轉場、封面、平台規格、壓縮）看 `reference.md`。

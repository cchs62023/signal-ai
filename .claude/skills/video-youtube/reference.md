# YouTube 相關細節

## 上傳規格

YouTube 收到檔案後一定會自己再壓一次，所以你上傳的是「母片」，品質給好一點不吃虧。

| 項目 | 建議 |
|---|---|
| 容器 | MP4，`-movflags +faststart` |
| 視訊 | H.264 High profile，CRF 18（或 1080p 約 8–12 Mbps） |
| 像素格式 | `yuv420p`（不是這個的話很多播放器會色偏或不能播） |
| 關鍵影格 | 每 2 秒一個（`-g` 設成 fps×2） |
| 音訊 | AAC-LC 384 kbps、48 kHz、立體聲 |
| 響度 | -14 LUFS（YouTube 的播放基準，太大聲會被它壓下來） |

`export-youtube.sh` 就是照這張表做的。

## 解析度

| 高度 | 尺寸 | 用途 |
|---|---|---|
| 1080 | 1920x1080 | 標準，絕大多數情況用這個 |
| 1440 | 2560x1440 | YouTube 會給 1440p 更好的 bitrate，畫質敏感的可以用 |
| 2160 | 3840x2160 | 4K，檔案大很多，螢幕錄影通常沒必要 |

小技巧：上傳 1440p 以上時 YouTube 會用 VP9 編碼，同樣畫質下位元率更高，
所以即使來源只有 1080p，放大到 1440p 上傳有時反而比較清楚。代價是檔案和上傳時間變大。

## 章節（Chapters）

四個條件缺一不可：

1. 第一個時間戳是 `0:00`
2. 至少 3 個
3. 每個至少 10 秒
4. 由小到大排

格式就是說明欄裡每行 `0:00 標題`，**要放在說明欄最前面幾行**。
影片超過 1 小時要寫成 `1:02:03`，一小時內寫 `2:03` 就好。

`chapters.py embed` 另外會把章節寫進 mp4 檔本身。YouTube 不讀這個（它讀說明欄），
但本地播放器、Vimeo、podcast 平台會讀，所以順手做了沒壞處。

## 字幕

上傳影片時在「字幕」那邊另外選 `.srt`。**不要燒進畫面**，原因：

- 觀眾可以自己開關；電視和手機上不會和播放器 UI 打架
- YouTube 會索引字幕內容，對搜尋有幫助
- 改錯字只要重傳字幕檔，不用重壓整支影片
- 之後要做多語言，加一個 `.srt` 就好

自動翻譯也是靠這份字幕，所以原文字幕品質好，翻譯出來才會好。

## 封面縮圖

1280x720、16:9、JPG/PNG、**2MB 以內**。

字要大到在手機上的小方塊裡也看得懂 —— 實際檢查方法是把圖縮到 320x180 再看一眼，
看不清楚就是字太小或對比不夠。字最多 4~6 個字，多了在手機上就是一團糊。

## 常用 ffmpeg

```bash
# 精準切片（重編碼，時間準）
ffmpeg -i in.mp4 -ss 00:00:42 -to 00:01:18 -c:v libx264 -crf 18 -c:a aac part.mp4

# 無損切片（快，但只能切在關鍵影格，可能差零點幾秒）
ffmpeg -i in.mp4 -ss 00:00:42 -to 00:01:18 -c copy part.mp4

# 接片（規格要一致；不一致就先各自 normalize）
printf "file '%s'\n" a.mp4 b.mp4 > list.txt
ffmpeg -f concat -safe 0 -i list.txt -c copy joined.mp4

# 交叉溶接 0.5 秒（offset = 第一段長度 - 0.5）
ffmpeg -i a.mp4 -i b.mp4 -filter_complex \
  "[0:v][1:v]xfade=transition=fade:duration=0.5:offset=9.5[v];[0:a][1:a]acrossfade=d=0.5[a]" \
  -map "[v]" -map "[a]" -c:v libx264 -crf 18 out.mp4

# 響度標準化
ffmpeg -i in.mp4 -af loudnorm=I=-14:TP=-1.5:LRA=11 -c:v copy out.mp4

# 換掉整條音軌（例如換成配音）
ffmpeg -i in.mp4 -i vo.mp3 -map 0:v -map 1:a -c:v copy -c:a aac -shortest out.mp4

# 檢查規格
ffprobe -v error -show_entries format=duration,size:stream=codec_name,profile,width,height,r_frame_rate \
  -of default=noprint_wrappers=1 out.mp4
```

## 踩過的雷

這幾個都是實際做的時候咬到的，改腳本前先看：

- **ffmpeg 會吃 stdin**。用 `while read` 迴圈讀設定檔、迴圈裡又呼叫 ffmpeg 時，
  ffmpeg 會把設定檔剩下的行全部吞掉，結果只處理到第一行。所有在迴圈裡的 ffmpeg
  都要加 `-nostdin`。
- **concat 的素材規格必須完全一致**：解析度、fps、pixel format、音訊取樣率、聲道數。
  少一項都可能接出爛檔或沒聲音。素材沒有音軌時要用 `anullsrc` 補一軌靜音，
  否則串接後整段音訊會錯位。
- **單張 PNG 疊圖 + `fade`**：圖片輸入沒加 `-loop 1` 的話只有 t=0 一格，
  `fade` 的 `st>0` 會把那格算成 alpha=0，整張圖就永遠透明。
- **無限長的來源**（`color=`、`-loop 1` 的圖）：`overlay` 要加 `shortest=1`，
  否則 ffmpeg 不會停。
- **ImageMagick 同時給 `-fill` 和 `-stroke`**：描邊會吃進筆劃，中文字糊成一團。
  描邊層和填色層要分開畫再疊。
- **ImageMagick `-append` / `-composite` 之後要 `+repage`**，
  不然舊的 page offset 會讓圖層錯位、跑出殘影。
- **`gblur` 直接在 full res 上跑很慢**：先縮到 1/4 模糊完再放大，視覺一樣但快十幾倍。

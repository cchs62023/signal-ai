# ffmpeg 常用寫法

`make-short.sh` 沒涵蓋到的手動操作放這裡。

## 切片與接片

無損切片（`-c copy` 不重編碼，但只能切在關鍵影格上，時間點可能差個零點幾秒）：

```bash
ffmpeg -i in.mp4 -ss 00:00:42 -to 00:01:18 -c copy part.mp4
```

要精準切在指定時間就得重編碼：

```bash
ffmpeg -i in.mp4 -ss 00:00:42 -to 00:01:18 -c:v libx264 -crf 20 -c:a aac part.mp4
```

接片（所有檔案的解析度、fps、編碼要一致）：

```bash
printf "file '%s'\n" part1.mp4 part2.mp4 part3.mp4 > list.txt
ffmpeg -f concat -safe 0 -i list.txt -c copy joined.mp4
```

規格不一致時，先統一再接：

```bash
for f in a.mp4 b.mp4; do
  ffmpeg -i "$f" -vf "scale=1080:1920:force_original_aspect_ratio=decrease,\
pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30" \
    -c:v libx264 -crf 20 -c:a aac -ar 48000 "norm_$f"
done
```

## 轉場

交叉溶接 0.5 秒（`offset` 是第一段開始淡出的時間點 = 第一段長度 - 0.5）：

```bash
ffmpeg -i a.mp4 -i b.mp4 -filter_complex \
  "[0:v][1:v]xfade=transition=fade:duration=0.5:offset=9.5[v];\
   [0:a][1:a]acrossfade=d=0.5[a]" \
  -map "[v]" -map "[a]" -c:v libx264 -crf 20 out.mp4
```

其他 transition：`wipeleft` `slideup` `circleopen` `dissolve`。
短影音別用太花的轉場，`fade` 和硬切最耐看。

## 速度

```bash
# 畫面和聲音一起加速 1.5 倍
ffmpeg -i in.mp4 -filter_complex "[0:v]setpts=PTS/1.5[v];[0:a]atempo=1.5[a]" \
  -map "[v]" -map "[a]" out.mp4
```

`atempo` 單次只吃 0.5～2.0，要更快就串接：`atempo=2.0,atempo=1.5`（= 3 倍）。

## 靜態畫面 / 封面

```bash
# 抽某一格當封面
ffmpeg -ss 3 -i in.mp4 -frames:v 1 -q:v 2 cover.jpg

# 圖片轉成 3 秒影片（記得 -loop 1，否則只有一格）
ffmpeg -loop 1 -i cover.jpg -t 3 -vf "scale=1080:1920,setsar=1" \
  -c:v libx264 -pix_fmt yuv420p -r 30 cover.mp4
```

## 音訊

```bash
# 抽出音軌
ffmpeg -i in.mp4 -vn -c:a pcm_s16le audio.wav

# 換掉音軌（例如換成 ElevenLabs 配音）
ffmpeg -i in.mp4 -i vo.mp3 -map 0:v -map 1:a -c:v copy -c:a aac -shortest out.mp4

# 響度標準化到 -14 LUFS（社群平台的常見基準）
ffmpeg -i in.mp4 -af loudnorm=I=-14:TP=-1.5:LRA=11 -c:v copy out.mp4

# 降噪（先抓一段純噪音算出 profile 的做法較準，這是簡易版）
ffmpeg -i in.mp4 -af "highpass=f=80,afftdn=nf=-25" -c:v copy out.mp4
```

## 平台規格

| 平台 | 長度 | 尺寸 | 備註 |
|---|---|---|---|
| IG Reels | ≤ 90s | 1080x1920 | 上下各留約 250px 給 UI |
| TikTok | ≤ 10min（建議 ≤ 60s） | 1080x1920 | 右側有按鈕，字別貼右邊 |
| YouTube Shorts | ≤ 60s | 1080x1920 | 超過 60 秒會變成一般影片 |

安全區：字幕和字卡的水平邊界留 6%，底部留 17%（`burn-subs.sh` 已經是這個設定）。

## 壓縮

```bash
# 控制檔案大小，crf 越大檔越小畫質越差；23 是肉眼堪用的上限
ffmpeg -i in.mp4 -c:v libx264 -crf 23 -preset slow \
  -c:a aac -b:a 128k -movflags +faststart out.mp4
```

`-movflags +faststart` 讓 moov atom 移到檔案開頭，網頁上可以邊載邊播，
所有要上傳的檔案都該加。

## 檢查

```bash
ffprobe -v error -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate \
  -of default=noprint_wrappers=1 out.mp4

# 音量有沒有爆掉：max_volume 接近 0 dB 就是削波了
ffmpeg -i out.mp4 -af volumedetect -f null - 2>&1 | grep volume
```

## 踩過的雷

這幾個都實際咬過，改腳本前先看：

- **`color=` / `-loop 1` 之外的無限來源**：`overlay` 要加 `shortest=1`，
  否則 ffmpeg 會一直輸出下去不會停。
- **單張 PNG 疊圖 + `fade`**：圖片輸入沒有 `-loop 1` 的話只有 t=0 一格，
  `fade` 的 `st>0` 會把那格算成 alpha=0，結果整張圖永遠透明。
- **`subtitles=xxx.srt:force_style=...`**：ffmpeg 轉 ASS 時寫死
  `PlayResX=384 PlayResY=288`，`FontSize` 和 `MarginV` 會被當成那個座標系的值
  再放大 6.7 倍。要自己把 PlayRes 改成真實解析度（`burn-subs.sh` 就是這樣做的）。
- **ImageMagick 同時給 `-fill` 和 `-stroke`**：描邊會吃進筆劃，中文字糊成一團。
  描邊層和填色層要分開畫再疊。
- **ImageMagick `-append` / `-composite` 之後**：要 `+repage` 清掉舊的 page offset，
  不然圖層會錯位、跑出殘影。
- **`gblur` 直接在 1080x1920 上跑很慢**：先縮到 1/4 模糊完再放大，視覺一樣但快十幾倍。

# Signal AI — YouTube 3 分鐘 Demo

16:9、2 分 58 秒、五個功能段落，用 `video-youtube` skill 產出。

## 步驟

**1. 把素材放進這個資料夾**

Drive 的 `video demo/` 裡那五個檔（或 `final demo video/` 的 001–005，內容一樣）：

```
onboarding.mp4  sequencing.mp4  format.mp4  trust.mp4  reflection.mp4
```

**2. 裝工具（只要一次）**

```bash
bash ../.claude/skills/video-youtube/scripts/setup.sh
```

**3. 量一下每段實際多長，把 `sections.txt` 的秒數調準**

```bash
for f in *.mp4; do
  printf "%-22s %ss\n" "$f" "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" | cut -d. -f1)"
done
```

`sections.txt` 裡目前的秒數是「3 分鐘怎麼分配」的建議值，不是量出來的。
哪一段實際比較短就把結束秒改小，總長會跟著縮。

**4. 產出**

```bash
bash ../.claude/skills/video-youtube/scripts/make-youtube.sh \
  --sections sections.txt \
  -o signal_demo_youtube.mp4 \
  --title "Signal AI" \
  --sub "The assistant that learns how you learn"
```

會產出：

| 檔案 | 用途 |
|---|---|
| `signal_demo_youtube.mp4` | 影片本體，1920x1080，章節已嵌入 |
| `signal_demo_youtube.srt` | 上傳時在「字幕」另外選這個 |
| `signal_demo_youtube.chapters.txt` | 貼到說明欄**最前面**，章節才會出現 |
| `signal_demo_youtube_thumb.jpg` | 1280x720 封面 |
| `signal_demo_youtube.txt` | 逐字稿 |

## 講稿

`script.md` 是五段的英文講稿初稿。第 5 段請換成你手上已有的那份。

錄好旁白之後，把音軌換上去再跑一次輸出：

```bash
# 先把旁白接成一條（或每段各自對）
ffmpeg -i signal_demo_youtube.mp4 -i narration.mp3 \
  -map 0:v -map 1:a -c:v copy -c:a aac -b:a 384k -shortest with_vo.mp4

# 字幕重新產生（這次是照旁白，會比原始素材準很多）
python3 ../.claude/skills/video-edit/scripts/transcribe.py with_vo.mp4 --model small --lang en
bash ../.claude/skills/video-youtube/scripts/soft-subs.sh with_vo.mp4 final.mp4 with_vo.srt eng
```

## 目前的時間分配

| 段落 | 長度 | 累計 |
|---|---|---|
| 標題卡 ×5 | 2.5s each = 12.5s | |
| Learns how you learn | 30s | 0:32 |
| Follows your train of thought | 45s | 1:20 |
| Your format, your call | 28s | 1:50 |
| Every claim, checkable | 32s | 2:25 |
| It asks you back | 30s | 2:58 |

`sequencing` 給了最多時間，因為那是產品的核心；其他段落盡量壓短，
讓整支片的節奏不要平。

## 兩個提醒

- YouTube 章節規則：第一個要 `0:00`、至少 3 個、每個至少 10 秒。
  `make-youtube.sh` 會自動檢查，不合會告訴你是哪一條。
- **不要把字幕燒進畫面。** YouTube 吃軟字幕，觀眾能自己開關、平台會索引內容，
  之後改錯字只要重傳 `.srt` 不用重壓影片。

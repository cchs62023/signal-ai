#!/usr/bin/env python3
"""工具 1+2 — 錄音轉文字，輸出 SRT (給燒字幕用) 和純文字稿。

用法:
    transcribe.py <input.mp4|wav> [--out-dir DIR] [--model small] [--lang zh] [--max-chars 16]

模型大小 tiny < base < small < medium < large-v3，越大越準也越慢。
中文 demo 建議 small 起跳，要精準就 medium。首次執行會從 HuggingFace 下載權重。
--max-chars 控制每行字幕最長幾個字；直式短影音一行別超過 16 個中文字。
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path


def ts(seconds: float) -> str:
    """秒數 -> SRT 時間碼 00:00:00,000"""
    ms = int(round(seconds * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def split_segment(text, start, end, max_chars):
    """把過長的字幕段落依標點切成多行，時間按字數比例分配。"""
    text = text.strip()
    if len(text) <= max_chars:
        return [(start, end, text)]

    # 優先在標點切，其次硬切
    chunks, buf = [], ""
    for ch in text:
        buf += ch
        if ch in "，。！？、,.!?;；" and len(buf) >= max_chars * 0.6:
            chunks.append(buf.strip(" ，。!?"))
            buf = ""
        elif len(buf) >= max_chars:
            chunks.append(buf.strip())
            buf = ""
    if buf.strip():
        chunks.append(buf.strip())
    chunks = [c for c in chunks if c]
    if not chunks:
        return [(start, end, text)]

    total = sum(len(c) for c in chunks)
    out, cur = [], start
    for c in chunks:
        span = (end - start) * (len(c) / total)
        out.append((cur, min(cur + span, end), c))
        cur += span
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("--out-dir", default=None)
    ap.add_argument("--model", default="small")
    ap.add_argument("--lang", default="zh", help="zh / en / ja ... 留空自動偵測")
    ap.add_argument("--max-chars", type=int, default=16)
    args = ap.parse_args()

    src = Path(args.input)
    if not src.exists():
        sys.exit(f"找不到檔案: {src}")

    out_dir = Path(args.out_dir) if args.out_dir else src.parent
    out_dir.mkdir(parents=True, exist_ok=True)
    srt_path = out_dir / f"{src.stem}.srt"
    txt_path = out_dir / f"{src.stem}.txt"

    # 先抽成 16k 單聲道 wav，whisper 吃這個最快最穩
    wav = out_dir / f"{src.stem}.16k.wav"
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(src),
         "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", str(wav)],
        check=True,
    )

    try:
        from faster_whisper import WhisperModel
    except ImportError:
        sys.exit("faster-whisper 未安裝，先跑 scripts/setup.sh")

    print(f"==> 載入模型 {args.model} (首次會下載權重)", file=sys.stderr)
    model = WhisperModel(args.model, device="cpu", compute_type="int8")

    segments, info = model.transcribe(
        str(wav),
        language=args.lang or None,
        vad_filter=True,                      # 濾掉靜音，字幕不會飄
        vad_parameters={"min_silence_duration_ms": 500},
        beam_size=5,
    )
    print(f"==> 語言={info.language} 長度={info.duration:.1f}s", file=sys.stderr)

    lines, full_text, idx = [], [], 1
    for seg in segments:
        for s, e, text in split_segment(seg.text, seg.start, seg.end, args.max_chars):
            if not text:
                continue
            lines.append(f"{idx}\n{ts(s)} --> {ts(e)}\n{text}\n")
            idx += 1
        full_text.append(seg.text.strip())
        print(f"  [{seg.start:6.1f}s] {seg.text.strip()}", file=sys.stderr)

    srt_path.write_text("\n".join(lines), encoding="utf-8")
    txt_path.write_text("\n".join(full_text), encoding="utf-8")
    wav.unlink(missing_ok=True)

    print(f"==> {idx - 1} 句字幕", file=sys.stderr)
    print(srt_path)


if __name__ == "__main__":
    main()

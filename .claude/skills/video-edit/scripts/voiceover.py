#!/usr/bin/env python3
"""工具 5 — ElevenLabs 配音 (TTS)。需要環境變數 ELEVENLABS_API_KEY。

用法:
    voiceover.py "要念的稿子" out.mp3 [--voice VOICE_ID] [--model eleven_multilingual_v2]
    voiceover.py --file script.txt out.mp3
列出可用聲音:
    voiceover.py --list-voices
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

API = "https://api.elevenlabs.io/v1"
# ElevenLabs 公開預設聲音 "Rachel"；中文請用 eleven_multilingual_v2 模型
DEFAULT_VOICE = "21m00Tcm4TlvDq8ikWAM"


def key():
    k = os.environ.get("ELEVENLABS_API_KEY")
    if not k:
        sys.exit("未設定 ELEVENLABS_API_KEY。到 https://elevenlabs.io 拿 key 後:\n"
                 "  export ELEVENLABS_API_KEY=xxx")
    return k


def request(url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"ElevenLabs API {e.code}: {e.read().decode('utf-8', 'replace')[:400]}")
    except urllib.error.URLError as e:
        sys.exit(f"連不到 ElevenLabs: {e.reason}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("text", nargs="?")
    ap.add_argument("output", nargs="?")
    ap.add_argument("--file", help="從檔案讀稿子")
    ap.add_argument("--voice", default=DEFAULT_VOICE)
    ap.add_argument("--model", default="eleven_multilingual_v2")
    ap.add_argument("--list-voices", action="store_true")
    args = ap.parse_args()

    if args.list_voices:
        body = request(f"{API}/voices", headers={"xi-api-key": key()})
        for v in json.loads(body).get("voices", []):
            print(f"{v['voice_id']}  {v['name']:<20} {v.get('labels', {})}")
        return

    text = open(args.file, encoding="utf-8").read() if args.file else args.text
    if not text or not args.output:
        sys.exit("用法: voiceover.py \"稿子\" out.mp3   或   voiceover.py --file s.txt out.mp3")

    api_key = key()   # 先驗 key，不要印了進度才失敗

    payload = json.dumps({
        "text": text,
        "model_id": args.model,
        "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
    }).encode()

    print(f"==> 配音 {len(text)} 字 voice={args.voice}", file=sys.stderr)
    audio = request(
        f"{API}/text-to-speech/{args.voice}",
        data=payload,
        headers={"xi-api-key": api_key, "Content-Type": "application/json",
                 "Accept": "audio/mpeg"},
    )
    with open(args.output, "wb") as f:
        f.write(audio)
    print(args.output)


if __name__ == "__main__":
    main()

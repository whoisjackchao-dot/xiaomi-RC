#!/usr/bin/env python3
"""Resident voice-input daemon for Xiaomi RC003 + Zhipu GLM-ASR.

Reads the Windows default microphone (exposed by WSLg as RDPSource), detects a
spoken segment, transcribes it with Zhipu GLM-ASR-2512, and injects the text
into the foreground Windows window via SendInput (Unicode, no IME required).
"""

import array
import os
import subprocess
import time
import wave

import requests

os.environ.setdefault("PULSE_SERVER", "unix:/mnt/wslg/PulseServer")

SR = 16000
CH = 1
THRESH = 500
SILENCE_SEC = 1.5
PREROLL_SEC = 0.4
MIN_SPEECH_SEC = 0.25
MAX_UTTER_SEC = 29
BLOCK_MS = 100
BLOCK_SAMPLES = SR * BLOCK_MS // 1000

WIN_TOOLS = os.environ.get("ZHIPU_WIN_TOOLS", "/mnt/c/Users/Public/Tools")
TEXTFILE = os.path.join(WIN_TOOLS, "voice-text.txt")
INJECT = os.environ.get(
    "ZHIPU_INJECT_PS1", r"C:\Users\Public\Tools\inject-text.ps1"
)
KEYFILE = os.path.expanduser("~/.config/zhipu/asr.key")
WAV = "/tmp/zhipu-voice-daemon.wav"
URL = "https://open.bigmodel.cn/api/paas/v4/audio/transcriptions"

POWERSHELL_CANDIDATES = [
    os.environ.get("ZHIPU_POWERSHELL", ""),
    "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
    "/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe",
]


def log(*args):
    print(time.strftime("%H:%M:%S"), *args, flush=True)


def powershell():
    for candidate in POWERSHELL_CANDIDATES:
        if candidate and os.path.exists(candidate):
            return candidate
    return "powershell.exe"


def transcribe(samples):
    w = wave.open(WAV, "wb")
    w.setnchannels(CH)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(array.array("h", samples).tobytes())
    w.close()

    try:
        key = open(KEYFILE, encoding="utf-8").read().strip()
        with open(WAV, "rb") as audio:
            response = requests.post(
                URL,
                headers={"Authorization": f"Bearer {key}"},
                data={"model": "glm-asr-2512", "stream": "false"},
                files={"file": ("voice.wav", audio, "audio/wav")},
                timeout=90,
            )
        response.raise_for_status()
        return (response.json().get("text") or "").strip()
    except Exception as error:
        log("asr error:", repr(error))
        return ""


def inject(text):
    if not text:
        return
    try:
        os.makedirs(WIN_TOOLS, exist_ok=True)
        with open(TEXTFILE, "w", encoding="utf-8", newline="") as handle:
            handle.write(text.replace("\n", "\r"))
        subprocess.run(
            [
                powershell(),
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-WindowStyle",
                "Hidden",
                "-File",
                INJECT,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=30,
        )
    except Exception as error:
        log("inject error:", repr(error))


def main():
    process = subprocess.Popen(
        [
            "parec",
            "--device=RDPSource",
            "--format=s16le",
            "--rate",
            str(SR),
            "--channels",
            str(CH),
            "--raw",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    log("daemon started, pid", os.getpid())

    pre = array.array("h")
    buffer = array.array("h")
    speaking = False
    silence = 0.0
    speech_time = 0.0

    while True:
        data = process.stdout.read(BLOCK_SAMPLES * 2)
        if not data or len(data) < BLOCK_SAMPLES * 2:
            log("stream ended")
            break

        block = array.array("h")
        block.frombytes(data)
        peak = max(abs(sample) for sample in block)

        if not speaking:
            pre.extend(block)
            max_pre = int(SR * PREROLL_SEC)
            if len(pre) > max_pre:
                pre = pre[-max_pre:]
            if peak > THRESH:
                speaking = True
                silence = 0.0
                speech_time = BLOCK_MS / 1000.0
                buffer = array.array("h", pre)
                log("speech start, peak", peak)
        else:
            buffer.extend(block)
            speech_time += BLOCK_MS / 1000.0
            if peak > THRESH:
                silence = 0.0
            else:
                silence += BLOCK_MS / 1000.0

            if silence >= SILENCE_SEC or speech_time >= MAX_UTTER_SEC:
                keep = len(buffer) - int(silence * SR) + int(0.2 * SR)
                segment = buffer[: max(keep, 0)]
                log("speech end,", round(len(buffer) / SR, 2), "s")
                if len(segment) > int(MIN_SPEECH_SEC * SR):
                    text = transcribe(segment)
                    log("text:", text)
                    inject(text)
                speaking = False
                pre = array.array("h")
                buffer = array.array("h")

    process.terminate()


if __name__ == "__main__":
    main()

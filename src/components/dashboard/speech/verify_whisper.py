from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

def get_runtime_root() -> Path:
    configured = os.environ.get("OBSIDIAN_GLASS_SPEECH_ROOT")
    if configured:
        return Path(configured)
    local_app_data = os.environ.get("LOCALAPPDATA", str(Path.home()))
    return Path(local_app_data) / "ObsidianGlassDesktop" / "runtime" / "speech"


CUDA_LIBS = get_runtime_root() / "cuda" / "libs"
CUDA_DLL_DIRECTORY = None
if CUDA_LIBS.joinpath("cublas64_12.dll").exists():
    os.environ["PATH"] = str(CUDA_LIBS) + os.pathsep + os.environ.get("PATH", "")
    if hasattr(os, "add_dll_directory"):
        CUDA_DLL_DIRECTORY = os.add_dll_directory(str(CUDA_LIBS))

from faster_whisper import WhisperModel

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache-dir", required=True)
    parser.add_argument("--audio", required=True)
    args = parser.parse_args()

    started = time.perf_counter()
    device = "GPU"
    fallback = ""
    try:
        model = WhisperModel(
            "large-v3-turbo",
            device="cuda",
            compute_type="float16",
            download_root=str(Path(args.cache_dir)),
        )
        segments, info = model.transcribe(
            args.audio,
            language="zh",
            beam_size=5,
            vad_filter=True,
            initial_prompt="简体中文听写。常用词：Codex、ChatGPT、Visual Studio Code、PowerShell、微信。",
        )
        text = "".join(segment.text for segment in segments).strip()
    except Exception as error:
        fallback = str(error)
        device = "CPU"
        model = WhisperModel(
            "large-v3-turbo",
            device="cpu",
            compute_type="int8",
            download_root=str(Path(args.cache_dir)),
        )
        segments, info = model.transcribe(
            args.audio,
            language="zh",
            beam_size=5,
            vad_filter=True,
            initial_prompt="简体中文听写。常用词：Codex、ChatGPT、Visual Studio Code、PowerShell、微信。",
        )
        text = "".join(segment.text for segment in segments).strip()

    result = {
        "passed": bool(text),
        "device": device,
        "text": text,
        "language": getattr(info, "language", ""),
        "elapsed_seconds": round(time.perf_counter() - started, 2),
        "gpu_fallback_reason": fallback[:260],
    }
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

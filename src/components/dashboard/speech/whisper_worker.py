from __future__ import annotations

import argparse
import collections
import json
import math
import os
import queue
import sys
import threading
import time
from pathlib import Path

import numpy as np
import sounddevice as sd


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


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


SAMPLE_RATE = 16000
FRAME_SECONDS = 0.10
MIN_SPEECH_SECONDS = 0.35
END_SILENCE_SECONDS = 1.0
MAX_UTTERANCE_SECONDS = 18.0
PRE_ROLL_SECONDS = 0.65
MODEL_NAME = "large-v3-turbo"
HOTWORDS = (
    "Codex ChatGPT Visual Studio Code VS Code Chrome Edge PowerShell GitHub "
    "MyDockFinder 微信 文件资源管理器 天禧个人超级智能体 待办事项"
)
INITIAL_PROMPT = (
    "以下是简体中文会议、通话和电脑操作记录。请准确添加中文标点。"
    "常用词包括：Codex、ChatGPT、Visual Studio Code、VS Code、Chrome、Edge、"
    "PowerShell、GitHub、MyDockFinder、微信、文件资源管理器、天禧个人超级智能体。"
)


class WhisperWorker:
    def __init__(self, cache_dir: Path) -> None:
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.output_lock = threading.Lock()
        self.state_lock = threading.RLock()
        self.stop_event = threading.Event()
        self.desired_listening = False
        self.listening = False
        self.model = None
        self.model_device = ""
        self.model_thread: threading.Thread | None = None
        self.transcribe_thread: threading.Thread | None = None
        self.audio_queue: queue.Queue[np.ndarray | None] = queue.Queue(maxsize=12)
        self.stream: sd.InputStream | None = None
        self.source_rate = SAMPLE_RATE
        self.pre_roll: collections.deque[np.ndarray] = collections.deque()
        self.current_audio: list[np.ndarray] = []
        self.speech_seconds = 0.0
        self.silence_seconds = 0.0
        self.noise_floor = 0.003
        self.in_speech = False

    def emit(self, event: str, **payload: object) -> None:
        message = {"event": event, **payload}
        with self.output_lock:
            print(json.dumps(message, ensure_ascii=False), flush=True)

    def probe(self) -> dict[str, object]:
        default_input = sd.default.device[0]
        device = sd.query_devices(default_input, "input")
        return {
            "input_device": str(device.get("name", "默认麦克风")),
            "input_channels": int(device.get("max_input_channels", 0)),
            "sample_rate": int(float(device.get("default_samplerate", SAMPLE_RATE))),
        }

    def ensure_model(self) -> None:
        with self.state_lock:
            if self.model is not None:
                if self.desired_listening and not self.listening:
                    self.start_capture()
                return
            if self.model_thread is not None and self.model_thread.is_alive():
                return
            self.model_thread = threading.Thread(target=self._load_model, daemon=True)
            self.model_thread.start()

    def _load_model(self) -> None:
        self.emit("status", state="loading", text="正在加载 Whisper 大模型")
        try:
            from faster_whisper import WhisperModel

            try:
                model = WhisperModel(
                    MODEL_NAME,
                    device="cuda",
                    compute_type="float16",
                    download_root=str(self.cache_dir),
                )
                # Force CUDA libraries to initialize now so fallback is reliable.
                list(model.transcribe(np.zeros(SAMPLE_RATE, dtype=np.float32), language="zh", vad_filter=True)[0])
                device = "GPU"
            except Exception as cuda_error:
                self.emit(
                    "status",
                    state="fallback",
                    text="GPU 运行库不可用，切换 CPU 高精度模式",
                    detail=str(cuda_error)[:240],
                )
                model = WhisperModel(
                    MODEL_NAME,
                    device="cpu",
                    compute_type="int8",
                    download_root=str(self.cache_dir),
                )
                device = "CPU"

            with self.state_lock:
                self.model = model
                self.model_device = device
            self.emit("status", state="ready", text=f"Whisper Turbo 已就绪 · {device}")
            self.transcribe_thread = threading.Thread(target=self._transcribe_loop, daemon=True)
            self.transcribe_thread.start()
            if self.desired_listening:
                self.start_capture()
        except Exception as error:
            self.emit("error", text="Whisper 模型加载失败", detail=str(error))

    def start_capture(self) -> None:
        with self.state_lock:
            if self.listening or self.model is None or not self.desired_listening:
                return
            try:
                device_info = self.probe()
                self.source_rate = int(device_info["sample_rate"])
                blocksize = max(256, int(self.source_rate * FRAME_SECONDS))
                self._reset_vad()
                self.stream = sd.InputStream(
                    samplerate=self.source_rate,
                    channels=1,
                    dtype="float32",
                    blocksize=blocksize,
                    latency="low",
                    callback=self._audio_callback,
                )
                self.stream.start()
                self.listening = True
                self.emit(
                    "status",
                    state="listening",
                    text="正在听写 · 自动分句",
                    device=device_info["input_device"],
                )
            except Exception as error:
                self.desired_listening = False
                self.listening = False
                self.emit("error", text="麦克风无法启动", detail=str(error))

    def stop_capture(self) -> None:
        with self.state_lock:
            self.desired_listening = False
            stream = self.stream
            self.stream = None
            self.listening = False
        if stream is not None:
            try:
                stream.stop()
                stream.close()
            except Exception:
                pass
        self._flush_current_audio(force=True)
        self.emit("status", state="stopped", text="已停止并释放麦克风")

    def _reset_vad(self) -> None:
        self.pre_roll.clear()
        self.current_audio = []
        self.speech_seconds = 0.0
        self.silence_seconds = 0.0
        self.noise_floor = 0.003
        self.in_speech = False

    def _audio_callback(self, indata: np.ndarray, frames: int, _time, status) -> None:
        if status:
            self.emit("status", state="audio", text="音频输入有短暂丢帧", detail=str(status))
        if not self.listening:
            return

        frame = np.asarray(indata[:, 0], dtype=np.float32).copy()
        frame_seconds = frames / float(self.source_rate)
        rms = float(np.sqrt(np.mean(np.square(frame)) + 1e-12))
        threshold = max(0.0042, self.noise_floor * 2.55)
        is_voice = rms >= threshold

        if not self.in_speech:
            self.noise_floor = (self.noise_floor * 0.96) + (min(rms, 0.03) * 0.04)
            self.pre_roll.append(frame)
            max_pre_roll = max(1, int(PRE_ROLL_SECONDS / max(frame_seconds, 0.01)))
            while len(self.pre_roll) > max_pre_roll:
                self.pre_roll.popleft()
            if is_voice:
                self.in_speech = True
                self.current_audio = list(self.pre_roll)
                self.pre_roll.clear()
                self.speech_seconds = frame_seconds
                self.silence_seconds = 0.0
            return

        self.current_audio.append(frame)
        if is_voice:
            self.speech_seconds += frame_seconds
            self.silence_seconds = 0.0
        else:
            self.silence_seconds += frame_seconds

        total_seconds = sum(len(part) for part in self.current_audio) / float(self.source_rate)
        should_flush = (
            total_seconds >= MAX_UTTERANCE_SECONDS
            or (self.speech_seconds >= MIN_SPEECH_SECONDS and self.silence_seconds >= END_SILENCE_SECONDS)
        )
        if should_flush:
            self._flush_current_audio(force=False)

    def _flush_current_audio(self, force: bool) -> None:
        if not self.current_audio:
            self._reset_vad()
            return
        if not force and self.speech_seconds < MIN_SPEECH_SECONDS:
            self._reset_vad()
            return

        audio = np.concatenate(self.current_audio).astype(np.float32, copy=False)
        if self.source_rate != SAMPLE_RATE and len(audio) > 1:
            target_length = max(1, int(len(audio) * SAMPLE_RATE / float(self.source_rate)))
            source_x = np.linspace(0.0, 1.0, num=len(audio), endpoint=False)
            target_x = np.linspace(0.0, 1.0, num=target_length, endpoint=False)
            audio = np.interp(target_x, source_x, audio).astype(np.float32)

        # Remove microphone DC offset and gently normalize quiet speech. The gain
        # is capped so keyboard noise and room ambience are not amplified heavily.
        audio = audio - np.mean(audio)
        speech_level = float(np.percentile(np.abs(audio), 95))
        if speech_level > 0.002:
            gain = min(3.0, 0.16 / speech_level)
            audio = np.clip(audio * gain, -1.0, 1.0).astype(np.float32)

        try:
            self.audio_queue.put_nowait(audio)
            self.emit("status", state="recognizing", text="正在识别这一句")
        except queue.Full:
            self.emit("status", state="busy", text="识别队列繁忙，已跳过过短片段")
        self._reset_vad()

    def _transcribe_loop(self) -> None:
        while not self.stop_event.is_set():
            try:
                audio = self.audio_queue.get(timeout=0.25)
            except queue.Empty:
                continue
            if audio is None:
                return
            try:
                beam_size = 8 if self.model_device == "GPU" else 5
                segments, info = self.model.transcribe(
                    audio,
                    language="zh",
                    task="transcribe",
                    beam_size=beam_size,
                    best_of=beam_size,
                    patience=1.15,
                    temperature=0.0,
                    vad_filter=True,
                    vad_parameters={
                        "min_silence_duration_ms": 350,
                        "speech_pad_ms": 260,
                    },
                    condition_on_previous_text=True,
                    initial_prompt=INITIAL_PROMPT,
                    hotwords=HOTWORDS,
                    repetition_penalty=1.08,
                    no_repeat_ngram_size=3,
                    no_speech_threshold=0.58,
                    compression_ratio_threshold=2.4,
                    log_prob_threshold=-1.0,
                    hallucination_silence_threshold=1.2,
                )
                segment_list = list(segments)
                text = "".join(segment.text for segment in segment_list).strip()
                text = " ".join(text.split())
                if text and any(character.isalnum() or "\u4e00" <= character <= "\u9fff" for character in text):
                    probabilities = [math.exp(min(0.0, float(segment.avg_logprob))) for segment in segment_list]
                    confidence = sum(probabilities) / len(probabilities) if probabilities else 0.0
                    self.emit(
                        "transcript",
                        text=text,
                        confidence=round(confidence, 3),
                        language=getattr(info, "language", "zh"),
                        device=self.model_device,
                    )
                else:
                    self.emit("status", state="no_speech", text="没有检测到清晰语音")
            except Exception as error:
                self.emit("error", text="语音识别失败", detail=str(error))
            finally:
                self.audio_queue.task_done()
                if self.listening:
                    self.emit("status", state="listening", text="正在听写 · 自动分句")

    def handle_command(self, command: dict[str, object]) -> bool:
        action = str(command.get("command", "")).lower()
        if action == "start":
            self.desired_listening = True
            self.ensure_model()
            return True
        if action == "stop":
            self.stop_capture()
            return True
        if action == "probe":
            self.emit("probe", **self.probe())
            return True
        if action == "quit":
            self.stop_capture()
            self.stop_event.set()
            try:
                self.audio_queue.put_nowait(None)
            except queue.Full:
                pass
            return False
        self.emit("error", text="未知语音命令", detail=action)
        return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache-dir", required=True)
    parser.add_argument("--probe", action="store_true")
    args = parser.parse_args()
    worker = WhisperWorker(Path(args.cache_dir))

    if args.probe:
        print(json.dumps(worker.probe(), ensure_ascii=False))
        return 0

    worker.emit("status", state="idle", text="Whisper 服务待机")
    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue
        try:
            command = json.loads(line)
            if not worker.handle_command(command):
                break
        except Exception as error:
            worker.emit("error", text="语音命令解析失败", detail=str(error))
    worker.stop_event.set()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

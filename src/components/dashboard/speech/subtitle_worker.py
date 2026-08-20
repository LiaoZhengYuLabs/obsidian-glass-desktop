from __future__ import annotations

import argparse
import collections
import json
import math
import os
import queue
import sys
import threading
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np

try:
    import pyaudiowpatch as pyaudio
except ImportError:
    pyaudio = None


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
MIN_SPEECH_SECONDS = 0.45
END_SILENCE_SECONDS = 0.65
MAX_UTTERANCE_SECONDS = 6.5
PRE_ROLL_SECONDS = 0.45
MODEL_NAME = "large-v3-turbo"
MEDIA_PROMPTS = {
    "video": (
        "This is dialogue from a movie, TV show, online video, or live stream. Preserve the "
        "original language and transcribe names, numbers, punctuation, and mixed-language dialogue accurately."
    ),
    "music": (
        "This is singing or spoken audio from music playback. Preserve the original language and "
        "transcribe names, lyrics, numbers, punctuation, and mixed-language audio accurately."
    ),
}
SUPPORTED_LANGUAGES = {
    "auto": None,
    "en": "en",
    "ja": "ja",
    "ko": "ko",
    "es": "es",
    "fr": "fr",
    "de": "de",
    "ru": "ru",
    "th": "th",
    "zh": "zh",
    "it": "it",
    "pt": "pt",
    "ar": "ar",
    "hi": "hi",
    "vi": "vi",
    "id": "id",
    "ms": "ms",
    "tr": "tr",
    "pl": "pl",
    "nl": "nl",
}
LANGUAGE_LABELS = {
    "auto": "自动识别",
    "en": "英语",
    "ja": "日语",
    "ko": "韩语",
    "es": "西班牙语",
    "fr": "法语",
    "de": "德语",
    "ru": "俄语",
    "th": "泰语",
    "zh": "中文",
    "it": "意大利语",
    "pt": "葡萄牙语",
    "ar": "阿拉伯语",
    "hi": "印地语",
    "vi": "越南语",
    "id": "印尼语",
    "ms": "马来语",
    "tr": "土耳其语",
    "pl": "波兰语",
    "nl": "荷兰语",
}


def has_readable_text(text: str) -> bool:
    return any(character.isalnum() or "\u3400" <= character <= "\u9fff" for character in text)


def normalize_text(text: str) -> str:
    return " ".join(text.strip().split())


def is_chinese_language(language: str) -> bool:
    return language.lower().startswith(("zh", "yue"))


def translate_online(text: str, target: str, source: str = "auto") -> str:
    if not text.strip():
        return ""
    query = urllib.parse.urlencode(
        {
            "client": "gtx",
            "sl": source or "auto",
            "tl": target,
            "dt": "t",
            "q": text,
        }
    )
    request = urllib.request.Request(
        "https://translate.googleapis.com/translate_a/single?" + query,
        headers={"User-Agent": "Mozilla/5.0"},
    )
    with urllib.request.urlopen(request, timeout=4.5) as response:
        payload = json.loads(response.read().decode("utf-8"))
    translated = "".join(part[0] for part in payload[0] if part and part[0])
    return normalize_text(translated)


class SubtitleWorker:
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
        self.audio_queue: queue.Queue[np.ndarray | None] = queue.Queue(maxsize=4)
        self.audio = None
        self.stream = None
        self.source_rate = SAMPLE_RATE
        self.source_channels = 2
        self.pre_roll: collections.deque[np.ndarray] = collections.deque()
        self.current_audio: list[np.ndarray] = []
        self.speech_seconds = 0.0
        self.silence_seconds = 0.0
        self.noise_floor = 0.004
        self.in_speech = False
        self.language_mode = "auto"
        self.language_hint: str | None = None
        self.content_mode = "video"

    def set_language(self, language: object) -> None:
        language_code = str(language or "auto").strip().lower()
        if language_code not in SUPPORTED_LANGUAGES:
            language_code = "auto"
        self.language_mode = language_code
        self.language_hint = SUPPORTED_LANGUAGES[language_code]
        self.emit(
            "status",
            state="language",
            text=f"原声语言：{LANGUAGE_LABELS[language_code]} → 简体中文",
            language_mode=language_code,
        )

    def set_content_mode(self, content_mode: object) -> None:
        mode = str(content_mode or "video").strip().lower()
        if mode not in {"video", "music"}:
            mode = "video"
        self.content_mode = mode
        label = "视频 / 电影" if mode == "video" else "音乐"
        self.emit("status", state="content_mode", text=f"字幕来源：{label}", content_mode=mode)

    def emit(self, event: str, **payload: object) -> None:
        message = {"event": event, "mode": "subtitle", **payload}
        with self.output_lock:
            print(json.dumps(message, ensure_ascii=False), flush=True)

    def probe(self) -> dict[str, object]:
        if pyaudio is None:
            raise RuntimeError("PyAudioWPatch is not installed in the dashboard runtime.")
        audio = pyaudio.PyAudio()
        try:
            device = audio.get_default_wasapi_loopback()
            return {
                "output_device": str(device.get("name", "默认扬声器回录")),
                "input_channels": int(device.get("maxInputChannels", 0)),
                "sample_rate": int(float(device.get("defaultSampleRate", SAMPLE_RATE))),
                "device_index": int(device.get("index", -1)),
            }
        finally:
            audio.terminate()

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
        self.emit("status", state="loading", text="正在加载本地双语字幕模型")
        try:
            from faster_whisper import WhisperModel

            try:
                model = WhisperModel(
                    MODEL_NAME,
                    device="cuda",
                    compute_type="float16",
                    download_root=str(self.cache_dir),
                )
                list(
                    model.transcribe(
                        np.zeros(SAMPLE_RATE, dtype=np.float32),
                        language="en",
                        vad_filter=True,
                    )[0]
                )
                device = "GPU"
            except Exception as cuda_error:
                self.emit(
                    "status",
                    state="fallback",
                    text="GPU 不可用，字幕切换 CPU 模式",
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
            self.emit("status", state="ready", text=f"双语字幕已就绪 · {device}")
            self.transcribe_thread = threading.Thread(target=self._transcribe_loop, daemon=True)
            self.transcribe_thread.start()
            if self.desired_listening:
                self.start_capture()
        except Exception as error:
            self.desired_listening = False
            self.emit("error", text="字幕模型加载失败", detail=str(error))

    def start_capture(self) -> None:
        with self.state_lock:
            if self.listening or self.model is None or not self.desired_listening:
                return
            try:
                if pyaudio is None:
                    raise RuntimeError("PyAudioWPatch is not installed.")
                self.audio = pyaudio.PyAudio()
                device = self.audio.get_default_wasapi_loopback()
                self.source_rate = int(float(device["defaultSampleRate"]))
                self.source_channels = max(1, min(2, int(device["maxInputChannels"])))
                blocksize = max(256, int(self.source_rate * FRAME_SECONDS))
                self._reset_vad()
                self.stream = self.audio.open(
                    format=pyaudio.paFloat32,
                    channels=self.source_channels,
                    rate=self.source_rate,
                    input=True,
                    input_device_index=int(device["index"]),
                    frames_per_buffer=blocksize,
                    stream_callback=self._audio_callback,
                    start=False,
                )
                self.listening = True
                self.stream.start_stream()
                self.emit(
                    "status",
                    state="listening",
                    text=("视频字幕监听中 · 系统声音" if self.content_mode == "video" else "音乐字幕监听中 · 系统声音"),
                    device=str(device.get("name", "默认扬声器回录")),
                )
            except Exception as error:
                self.desired_listening = False
                self.listening = False
                self._close_audio()
                self.emit("error", text="系统声音回录无法启动", detail=str(error))

    def _close_audio(self) -> None:
        stream = self.stream
        audio = self.audio
        self.stream = None
        self.audio = None
        if stream is not None:
            try:
                stream.stop_stream()
            except Exception:
                pass
            try:
                stream.close()
            except Exception:
                pass
        if audio is not None:
            try:
                audio.terminate()
            except Exception:
                pass

    def stop_capture(self, emit_status: bool = True) -> None:
        with self.state_lock:
            self.desired_listening = False
            self.listening = False
        self._close_audio()
        self._flush_current_audio(force=True)
        if emit_status:
            self.emit("status", state="stopped", text="双语字幕已暂停")

    def _reset_vad(self) -> None:
        self.pre_roll.clear()
        self.current_audio = []
        self.speech_seconds = 0.0
        self.silence_seconds = 0.0
        self.noise_floor = 0.004
        self.in_speech = False

    def _audio_callback(self, in_data: bytes, frame_count: int, _time_info, status_flags):
        if status_flags:
            self.emit("status", state="audio", text="字幕音频有短暂丢帧", detail=str(status_flags))
        if not self.listening:
            return (None, pyaudio.paContinue)

        samples = np.frombuffer(in_data, dtype=np.float32)
        if self.source_channels > 1:
            usable = len(samples) - (len(samples) % self.source_channels)
            samples = samples[:usable].reshape(-1, self.source_channels).mean(axis=1)
        frame = np.asarray(samples, dtype=np.float32).copy()
        self._consume_frame(frame, frame_count / float(self.source_rate))
        return (None, pyaudio.paContinue)

    def _consume_frame(self, frame: np.ndarray, frame_seconds: float) -> None:
        if frame.size == 0:
            return
        rms = float(np.sqrt(np.mean(np.square(frame)) + 1e-12))
        base_threshold = 0.0032 if self.content_mode == "video" else 0.0035
        threshold = max(base_threshold, self.noise_floor * 1.75)
        is_voice = rms >= threshold

        if not self.in_speech:
            self.noise_floor = (self.noise_floor * 0.95) + (min(rms, 0.04) * 0.05)
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
        minimum_speech = 0.35 if self.content_mode == "video" else MIN_SPEECH_SECONDS
        end_silence = 0.48 if self.content_mode == "video" else END_SILENCE_SECONDS
        maximum_utterance = 4.8 if self.content_mode == "video" else MAX_UTTERANCE_SECONDS
        if total_seconds >= maximum_utterance or (
            self.speech_seconds >= minimum_speech and self.silence_seconds >= end_silence
        ):
            self._flush_current_audio(force=False)

    def _flush_current_audio(self, force: bool) -> None:
        if not self.current_audio:
            self._reset_vad()
            return
        minimum_speech = 0.35 if self.content_mode == "video" else MIN_SPEECH_SECONDS
        if not force and self.speech_seconds < minimum_speech:
            self._reset_vad()
            return

        audio = np.concatenate(self.current_audio).astype(np.float32, copy=False)
        if self.source_rate != SAMPLE_RATE and len(audio) > 1:
            target_length = max(1, int(len(audio) * SAMPLE_RATE / float(self.source_rate)))
            source_x = np.linspace(0.0, 1.0, num=len(audio), endpoint=False)
            target_x = np.linspace(0.0, 1.0, num=target_length, endpoint=False)
            audio = np.interp(target_x, source_x, audio).astype(np.float32)

        audio = audio - np.mean(audio)
        level = float(np.percentile(np.abs(audio), 95))
        if level > 0.002:
            audio = np.clip(audio * min(2.2, 0.18 / level), -1.0, 1.0).astype(np.float32)

        try:
            self.audio_queue.put_nowait(audio)
            self.emit("status", state="recognizing", text="正在生成原文和简体中文字幕")
        except queue.Full:
            try:
                discarded = self.audio_queue.get_nowait()
                if discarded is not None:
                    self.audio_queue.task_done()
                self.audio_queue.put_nowait(audio)
                self.emit("status", state="busy", text="字幕追赶当前声音")
            except (queue.Empty, queue.Full):
                pass
        self._reset_vad()

    def _run_whisper(self, audio: np.ndarray, task: str, language: str | None = None):
        if self.content_mode == "video":
            beam_size = 3 if self.model_device == "GPU" else 2
        else:
            beam_size = 5 if self.model_device == "GPU" else 3
        segments, info = self.model.transcribe(
            audio,
            language=language,
            task=task,
            beam_size=beam_size,
            best_of=beam_size,
            temperature=0.0,
            vad_filter=False,
            condition_on_previous_text=False,
            initial_prompt=MEDIA_PROMPTS[self.content_mode],
            repetition_penalty=1.08,
            no_repeat_ngram_size=3,
            no_speech_threshold=0.45,
            compression_ratio_threshold=2.4,
            log_prob_threshold=-1.0,
        )
        segment_list = list(segments)
        text = normalize_text("".join(segment.text for segment in segment_list))
        probabilities = [math.exp(min(0.0, float(segment.avg_logprob))) for segment in segment_list]
        confidence = sum(probabilities) / len(probabilities) if probabilities else 0.0
        return text, str(getattr(info, "language", language or "")), confidence

    def _transcribe_loop(self) -> None:
        while not self.stop_event.is_set():
            try:
                audio = self.audio_queue.get(timeout=0.25)
            except queue.Empty:
                continue
            if audio is None:
                return
            try:
                original, language, confidence = self._run_whisper(
                    audio,
                    task="transcribe",
                    language=None,
                )
                if (
                    self.language_hint is not None
                    and (not original or not has_readable_text(original) or confidence < 0.18)
                ):
                    hinted_original, hinted_language, hinted_confidence = self._run_whisper(
                        audio,
                        task="transcribe",
                        language=self.language_hint,
                    )
                    if hinted_confidence > confidence and has_readable_text(hinted_original):
                        original = hinted_original
                        language = hinted_language
                        confidence = hinted_confidence
                if not original or not has_readable_text(original) or confidence < 0.18:
                    self.emit("status", state="no_speech", text="等待清晰对白")
                    continue

                chinese = ""
                translation_source = "local"
                if is_chinese_language(language):
                    chinese = original
                else:
                    try:
                        translation_language = language or self.language_hint or "auto"
                        chinese = translate_online(original, "zh-CN", source=translation_language)
                        translation_source = "online"
                    except Exception as translation_error:
                        self.emit(
                            "status",
                            state="translation_fallback",
                            text="中文翻译暂不可用，保留原语言字幕",
                            detail=str(translation_error)[:240],
                        )

                if not chinese:
                    chinese = original if is_chinese_language(language) else "中文翻译暂不可用"

                self.emit(
                    "subtitle",
                    original=original,
                    chinese=chinese,
                    english=original,
                    language=language,
                    confidence=round(confidence, 3),
                    device=self.model_device,
                    translation=translation_source,
                    language_mode=self.language_mode,
                )
            except Exception as error:
                self.emit("error", text="双语字幕识别失败", detail=str(error))
            finally:
                self.audio_queue.task_done()
                if self.listening:
                    self.emit(
                        "status",
                        state="listening",
                        text=f"双语字幕监听中 · {LANGUAGE_LABELS[self.language_mode]}",
                        language_mode=self.language_mode,
                    )

    def handle_command(self, command: dict[str, object]) -> bool:
        action = str(command.get("command", "")).lower()
        if action == "start":
            self.set_language(command.get("language", self.language_mode))
            self.set_content_mode(command.get("content_mode", self.content_mode))
            self.desired_listening = True
            self.ensure_model()
            return True
        if action == "warmup":
            self.set_language(command.get("language", self.language_mode))
            self.set_content_mode(command.get("content_mode", self.content_mode))
            self.desired_listening = False
            self.ensure_model()
            return True
        if action == "set_language":
            self.set_language(command.get("language", "auto"))
            return True
        if action == "stop":
            self.stop_capture()
            return True
        if action == "probe":
            self.emit("probe", **self.probe())
            return True
        if action == "quit":
            self.stop_capture(emit_status=False)
            self.stop_event.set()
            try:
                self.audio_queue.put_nowait(None)
            except queue.Full:
                pass
            return False
        self.emit("error", text="未知字幕命令", detail=action)
        return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache-dir", required=True)
    parser.add_argument("--probe", action="store_true")
    args = parser.parse_args()
    worker = SubtitleWorker(Path(args.cache_dir))

    if args.probe:
        print(json.dumps(worker.probe(), ensure_ascii=False))
        return 0

    worker.emit("status", state="idle", text="双语字幕服务待机")
    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue
        try:
            command = json.loads(line)
            if not worker.handle_command(command):
                break
        except Exception as error:
            worker.emit("error", text="字幕命令解析失败", detail=str(error))
    worker.stop_event.set()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path


USER_AGENT = "ObsidianAIDashboard/1.0 (Windows desktop lyrics widget)"
LRC_PATTERN = re.compile(r"^\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\](.*)$")


def request_json(url: str, timeout: float = 15.0):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def normalize(value: str) -> str:
    return " ".join((value or "").casefold().split())


def find_synced_record(title: str, artist: str, duration: float):
    query = urllib.parse.urlencode({"track_name": title, "artist_name": artist})
    records = request_json("https://lrclib.net/api/search?" + query)
    candidates = [record for record in records if str(record.get("syncedLyrics") or "").strip()]
    if not candidates:
        raise RuntimeError("No synchronized lyrics were found for this track.")

    wanted_title = normalize(title)
    wanted_artist = normalize(artist)

    def score(record) -> float:
        record_title = normalize(str(record.get("trackName") or ""))
        record_artist = normalize(str(record.get("artistName") or ""))
        title_penalty = 0.0 if record_title == wanted_title else 18.0
        artist_penalty = 0.0 if wanted_artist in record_artist or record_artist in wanted_artist else 14.0
        record_duration = float(record.get("duration") or 0.0)
        duration_penalty = abs(record_duration - duration) if duration > 0 and record_duration > 0 else 6.0
        return title_penalty + artist_penalty + duration_penalty

    return min(candidates, key=score)


def parse_synced_lyrics(raw: str) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    for line in raw.splitlines():
        match = LRC_PATTERN.match(line.strip())
        if not match:
            continue
        minutes = int(match.group(1))
        seconds = int(match.group(2))
        fraction = match.group(3) or "0"
        milliseconds = int(fraction.ljust(3, "0")[:3])
        text = " ".join(match.group(4).strip().split())
        timestamp = (minutes * 60.0) + seconds + (milliseconds / 1000.0)
        if not text:
            entries.append(
                {
                    "time": round(timestamp, 3),
                    "original": "",
                    "chinese": "",
                    "clear": True,
                }
            )
            continue
        if entries and abs(float(entries[-1]["time"]) - timestamp) < 0.01 and entries[-1]["original"] == text:
            continue
        entries.append({"time": round(timestamp, 3), "original": text})
    if not entries:
        raise RuntimeError("The synchronized lyrics response did not contain timed lines.")
    return entries


def translate_line(text: str) -> str:
    query = urllib.parse.urlencode(
        {"client": "gtx", "sl": "auto", "tl": "zh-CN", "dt": "t", "q": text}
    )
    request = urllib.request.Request(
        "https://translate.googleapis.com/translate_a/single?" + query,
        headers={"User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=8.0) as response:
        payload = json.loads(response.read().decode("utf-8"))
    translated = "".join(part[0] for part in payload[0] if part and part[0])
    return " ".join(translated.strip().split()) or text


def translate_entries(entries: list[dict[str, object]]) -> None:
    unique_lines = list(
        dict.fromkeys(str(entry["original"]) for entry in entries if str(entry["original"]).strip())
    )
    translations: dict[str, str] = {}

    def translate_safely(line: str) -> tuple[str, str]:
        for attempt in range(3):
            try:
                return line, translate_line(line)
            except Exception:
                if attempt < 2:
                    time.sleep(0.35 * (attempt + 1))
        return line, line

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        for original, chinese in executor.map(translate_safely, unique_lines):
            translations[original] = chinese

    for entry in entries:
        if entry.get("clear"):
            entry["chinese"] = ""
            continue
        original = str(entry["original"])
        entry["chinese"] = translations.get(original, original)


def write_cache(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary_name = tempfile.mkstemp(prefix=path.stem + "-", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(payload, stream, ensure_ascii=False, separators=(",", ":"))
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--title", required=True)
    parser.add_argument("--artist", required=True)
    parser.add_argument("--duration", type=float, default=0.0)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    try:
        record = find_synced_record(args.title, args.artist, args.duration)
        entries = parse_synced_lyrics(str(record.get("syncedLyrics") or ""))
        translate_entries(entries)
        payload = {
            "version": 2,
            "title": str(record.get("trackName") or args.title),
            "artist": str(record.get("artistName") or args.artist),
            "duration": float(record.get("duration") or args.duration or 0.0),
            "sourceId": int(record.get("id") or 0),
            "entries": entries,
        }
        write_cache(Path(args.output), payload)
        print(json.dumps({"ok": True, "count": len(entries), "sourceId": payload["sourceId"]}))
        return 0
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

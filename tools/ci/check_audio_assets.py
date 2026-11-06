#!/usr/bin/env python3
"""Portable preflight for AUDIO-01 files (no Godot required)."""
import hashlib
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "assets/audio/music"
RADIO = tuple(sorted((DIR / "radio").glob("*.ogg")))
OGGS = RADIO + tuple(DIR / n for n in ("menu.ogg", "garage.ogg", "day_end.ogg"))
WAVS = (("opening_sting.wav", 7.5), ("achievement_sting.wav", 3.3))


def check_ogg(path):
    data = path.read_bytes()
    if len(data) < 1024 or data[:4] != b"OggS":
        raise ValueError("invalid Ogg signature/length")
    p = data.find(b"\x01vorbis", 0, 4096)
    if p < 0 or p + 16 > len(data):
        raise ValueError("Vorbis identification packet not found")
    channels = data[p + 11]
    sample_rate = struct.unpack_from("<I", data, p + 12)[0]
    if not 1 <= channels <= 8 or not 8000 <= sample_rate <= 384000:
        raise ValueError("invalid Vorbis channel count / rate")
    tail = data.rfind(b"OggS")
    if tail < 0 or tail + 27 > len(data):
        raise ValueError("Ogg final page missing")
    granule = struct.unpack_from("<Q", data, tail + 6)[0]
    duration = granule / sample_rate
    if not 0.2 < duration < 3600:
        raise ValueError("invalid granule duration")
    print("OK", path.relative_to(ROOT), sample_rate, "Hz", channels, "ch", f"{duration:.2f}s",
          hashlib.sha256(data).hexdigest())


def check_wav(name, expected_seconds):
    path = DIR / name
    with wave.open(str(path), "rb") as wav:
        if (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) != (22050, 1, 2):
            raise ValueError("invalid 22.05 kHz / mono / 16-bit format")
        if abs(wav.getnframes() / wav.getframerate() - expected_seconds) > 0.01:
            raise ValueError("unexpected duration")
    print("OK", path.relative_to(ROOT), expected_seconds, "seconds")


def main():
    errors = []
    if len(RADIO) != 10:
        errors.append(f"expected 10 radio OGGs, found {len(RADIO)}")
    for path in OGGS:
        try:
            check_ogg(path)
        except (OSError, ValueError, struct.error) as exc:
            errors.append(f"{path.relative_to(ROOT)}: {exc}")
    for name, length in WAVS:
        try:
            check_wav(name, length)
        except (OSError, ValueError, EOFError, wave.Error) as exc:
            errors.append(f"{name}: {exc}")
    if errors:
        for error in errors:
            print("FAIL:", error, file=sys.stderr)
        return 1
    print("PASS: 15 AUDIO-01 files pass structural checks (not a listening test)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

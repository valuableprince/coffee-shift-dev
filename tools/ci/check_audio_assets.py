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

# P0: these verified CC0 tracks replace untraceable or composition-risk recordings.
# Verify byte identity before Godot import. Unexpected old files are forbidden.
P0_HASHES = {
    "radio_01_jazz_improv.ogg": "e0125d6efee5cec8c5c10745ed884530e42c33bde36922ea880df3c1d22220dd",
    "radio_09_sunset_walk.ogg": "1d230721e6200276065b913e44943d0e0503af88fc2dd793be1249738e06d98c",
    "radio_10_etirwer.ogg": "382c02bfb3d9abe1c9f432606dd95f27bcef28ac22097ccdcef12a8c608b421b",
}
BANNED_P0_NAMES = ("radio_01_jazz.ogg", "radio_09_ambient_space.ogg", "radio_10_dreamy.ogg")



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
    for forbidden in BANNED_P0_NAMES:
        if (DIR / "radio" / forbidden).exists():
            errors.append(f"P0 prohibited file present: {forbidden}")
    for filename, expected_hash in P0_HASHES.items():
        candidate = DIR / "radio" / filename
        if not candidate.is_file():
            errors.append(f"P0 licensed track missing: {filename}")
            continue
        actual_hash = hashlib.sha256(candidate.read_bytes()).hexdigest()
        if actual_hash != expected_hash:
            errors.append(f"P0 SHA-256 mismatch: {filename}; expected {expected_hash}, got {actual_hash}")
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

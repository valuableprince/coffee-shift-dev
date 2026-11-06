#!/usr/bin/env python3
"""Rebuild two AUDIO-01 original short musical cues with no external samples.
Usage: python tools/audio01_stings.py [destination-directory]
"""
from __future__ import annotations
import math
import struct
import sys
from pathlib import Path

RATE = 22050
TRACKS = {
    "opening_sting.wav": (7.5, [(0,1.8,60,.095),(0,1.8,64,.072),(0,1.8,67,.06),(1.5,1.9,65,.082),(1.5,1.9,69,.076),(3.0,1.8,67,.1),(3.0,1.8,71,.07),(4.5,2.8,72,.11),(4.5,2.8,76,.073),(4.5,2.8,79,.055)]),
    "achievement_sting.wav": (3.3, [(0,.95,72,.105),(.52,1.1,76,.095),(1.05,2.1,79,.115),(1.05,2.1,84,.085)]),
}

def render(path: Path, duration: float, notes: list[tuple]) -> None:
    count = round(duration * RATE)
    data = bytearray(44 + count * 2)
    struct.pack_into("<4sI4s4sIHHIIHH4sI", data, 0,
        b"RIFF", 36+count*2, b"WAVE", b"fmt ", 16, 1, 1, RATE, RATE*2, 2, 16, b"data", count*2)
    for i in range(count):
        t = i / RATE
        sound = 0.
        for start, length, midi, amp in notes:
            elapsed = t-start
            if not (0 <= elapsed <= length):
                continue
            freq = 440 * 2**((midi-69)/12)
            envelope = min(1, elapsed / .016) * max(0, 1-elapsed/length)**1.7
            tone = math.sin(2*math.pi*freq*elapsed) + .18*math.sin(4*math.pi*freq*elapsed)
            sound += amp * envelope * tone
        edge = min(1, t/.035, (duration-t)/.12)
        sample = max(-32767, min(32767, math.floor(sound*edge*32767 + .5)))
        struct.pack_into("<h", data, 44+i*2, sample)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)

if __name__ == "__main__":
    directory = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/audio/music")
    for filename, (duration, notes) in TRACKS.items():
        render(directory / filename, duration, notes)
        print(directory / filename)

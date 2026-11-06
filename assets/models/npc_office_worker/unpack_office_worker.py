#!/usr/bin/env python3
"""Expand the exact PS2+ office-worker GLB from its losslessly compressed source."""
from pathlib import Path
import hashlib
import lzma

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "npc_office_worker_ps2plus.glb.xz"
TARGET = ROOT / "npc_office_worker_ps2plus.glb"
EXPECTED_SHA256 = "7827bcafd23c3d3affc14785fdbb080d6482c200ae14e60d23ec1cd7e405def0"
EXPECTED_SIZE = 207752

def main() -> None:
    data = lzma.decompress(SOURCE.read_bytes())
    digest = hashlib.sha256(data).hexdigest()
    if len(data) != EXPECTED_SIZE or digest != EXPECTED_SHA256 or data[:4] != b"glTF":
        raise RuntimeError(f"GLB integrity check failed: size={len(data)}, sha256={digest}")
    TARGET.write_bytes(data)
    print(f"Restored {TARGET.name}: {len(data)} bytes, SHA256 {digest}")

if __name__ == "__main__":
    main()

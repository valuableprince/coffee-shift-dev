"""Verify the integrity of the Coffee Shift milk pitcher GLB using Python stdlib.
Usage: python assets/models/milk_pitcher/test_asset.py
"""
import json
import math
import struct
from pathlib import Path

source = Path(__file__).with_name("coffee_shift_milk_pitcher.glb")
raw = source.read_bytes()
assert len(raw) >= 28
magic, version, length = struct.unpack_from("<III", raw, 0)
assert (magic, version, length) == (0x46546C67, 2, len(raw))
jlen, jtype = struct.unpack_from("<II", raw, 12)
assert jtype == 0x4E4F534A
data = json.loads(raw[20:20 + jlen].decode("utf-8"))
bin_start = 20 + jlen
blen, btype = struct.unpack_from("<II", raw, bin_start)
assert btype == 0x004E4942 and bin_start + 8 + blen == len(raw)
assert data["buffers"][0]["byteLength"] == blen
names = {mesh["name"] for mesh in data["meshes"]}
assert {"Pitcher_Outer_Tapered_Body", "Pitcher_Inner_Brushed_Wall",
        "Rolled_Pouring_Lip_and_Spout", "Handle_C_Shaped_Ergonomic_Loop"} <= names
assert len(data["materials"]) >= 4
positions = []
for accessor in data["accessors"]:
    if accessor["type"] != "VEC3":
        continue
    lo = accessor.get("min")
    hi = accessor.get("max")
    if lo and hi:
        assert all(math.isfinite(v) for v in lo + hi)
        positions.append((lo, hi))
assert positions
low = [min(p[0][i] for p in positions) for i in range(3)]
high = [max(p[1][i] for p in positions) for i in range(3)]
assert low[1] >= -0.001 and 0.12 < high[1] < 0.13
assert low[2] < -0.10 and high[2] > 0.064
print("OK:", source.name, "bytes:", len(raw),
      "meshes:", len(data["meshes"]), "bounds:", low, high)

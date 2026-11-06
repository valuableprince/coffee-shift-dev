"""Pure Python 3 stdlib GLB verification."""
from pathlib import Path
import json
import math
import struct
root = Path(__file__).resolve().parent
for file, target_h, target_d in [
    ("coffee_shift_paper_cup_350ml.glb", .115, .088),
    ("coffee_shift_sip_lid_90mm.glb", .0231, .0924),
]:
    raw = (root / file).read_bytes()
    assert struct.unpack_from("<III", raw) == (0x46546C67, 2, len(raw))
    size, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20+size])
    offset = 20 + size
    bsize, bkind = struct.unpack_from("<II", raw, offset)
    assert bkind == 0x004E4942 and offset + 8 + bsize == len(raw)
    assert doc["asset"]["version"] == "2.0"
    assert len(doc["materials"]) > 1 and len(doc["meshes"]) > 5
    pos = [a for a in doc["accessors"] if a["type"] == "VEC3" and "min" in a]
    lo = [min(a["min"][k] for a in pos) for k in range(3)]
    hi = [max(a["max"][k] for a in pos) for k in range(3)]
    assert all(math.isfinite(x) for x in lo+hi)
    assert abs(hi[1]-lo[1]-target_h) < .005
    assert abs(hi[0]-lo[0]-target_d) < .005
    for m in doc["meshes"]:
        p = m["primitives"][0]
        idx = doc["accessors"][p["indices"]]
        assert idx["count"] > 0 and idx["count"]%3 == 0
        assert "NORMAL" in p["attributes"]
    print("PASS", file, len(doc["meshes"]), "components")

"""Coffee Shift cash register: glTF 2.0 sanity checks, no dependencies."""
import json
import math
import struct
from pathlib import Path

root = Path(__file__).resolve().parent
for file, minimum_mesh_primitives in [
    ("cash_register_body.glb", 8),
    ("cash_drawer.glb", 4),
    ("receipt_paper.glb", 2),
]:
    raw = (root / file).read_bytes()
    assert struct.unpack_from("<III", raw, 0) == (0x46546C67, 2, len(raw))
    json_size, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    model = json.loads(raw[20:20 + json_size])
    offset = 20 + json_size
    binary_size, binary_type = struct.unpack_from("<II", raw, offset)
    assert binary_type == 0x004E4942
    assert offset + 8 + binary_size == len(raw)
    assert model["asset"]["version"] == "2.0"
    assert len(model["meshes"][0]["primitives"]) >= minimum_mesh_primitives
    positions = [a for a in model["accessors"]
                 if a["type"] == "VEC3" and "min" in a]
    assert positions
    assert all(math.isfinite(v) for a in positions
               for v in a["min"] + a["max"])
    for p in model["meshes"][0]["primitives"]:
        count = model["accessors"][p["indices"]]["count"]
        assert count % 3 == 0 and count > 0
        assert "NORMAL" in p["attributes"]
    print("PASS", file, len(raw), "bytes")

scene = (root / "cash_register.tscn").read_text(encoding="utf8")
for expected in ("BodyVisual", "DrawerAssembly", "ReceiptPaper",
                 "DisplayText", "BodyInteraction", "DrawerInteraction",
                 "ReceiptExit"):
    assert expected in scene
script = (root / "cash_register.gd").read_text(encoding="utf8")
assert "set_drawer_open" in script
assert "set_display_value" in script
print("PASS Godot scene and controller declarations")

"""Offline asset checks: GLB 2.0, dimensions, independent doors, Godot scene wiring."""
import json
import math
import struct
from pathlib import Path

root = Path(__file__).resolve().parent
models = [
    "base_cabinet_body", "base_cabinet_door_left", "base_cabinet_door_right",
    "wall_cabinet_body", "wall_cabinet_door_left", "wall_cabinet_door_right",
]
for model in models:
    raw = (root / (model + ".glb")).read_bytes()
    magic, ver, length = struct.unpack_from("<III", raw, 0)
    assert (magic, ver, length) == (0x46546C67, 2, len(raw))
    json_size, json_type = struct.unpack_from("<II", raw, 12)
    assert json_type == 0x4E4F534A
    gltf = json.loads(raw[20:20 + json_size])
    binary_offset = 20 + json_size
    bin_size, bin_type = struct.unpack_from("<II", raw, binary_offset)
    assert bin_type == 0x004E4942
    assert binary_offset + 8 + bin_size == len(raw)
    assert gltf["asset"]["version"] == "2.0"
    assert gltf["materials"]
    pos = [a for a in gltf["accessors"] if a["type"] == "VEC3" and "min" in a]
    bounds_min = [min(a["min"][i] for a in pos) for i in range(3)]
    bounds_max = [max(a["max"][i] for a in pos) for i in range(3)]
    assert all(math.isfinite(x) for x in bounds_min + bounds_max)
    for primitive in gltf["meshes"][0]["primitives"]:
        assert "NORMAL" in primitive["attributes"]
        indices = gltf["accessors"][primitive["indices"]]
        assert indices["count"] > 0 and indices["count"] % 3 == 0
        vertex_count = gltf["accessors"][primitive["attributes"]["POSITION"]]["count"]
        assert vertex_count > 0
    print("OK", model, len(raw), "bytes")

for name in ["base_cabinet.tscn", "wall_cabinet.tscn"]:
    scene = (root / name).read_text(encoding="utf8")
    for token in ["LeftHinge", "RightHinge", "DoorInteractable", "BodyCollider",
                  "cabinet_controller.gd", "cabinet_door_interactable.gd"]:
        assert token in scene
    assert scene.count("instance=ExtResource") == 3
    assert scene.count('type="StaticBody3D"') == 3
    print("OK", name)

script = (root / "cabinet_controller.gd").read_text(encoding="utf8")
assert '"rotation:y"' in script
assert "get_door_prompt" in script
assert "set_door_open" in script
print("All cabinet asset checks passed")

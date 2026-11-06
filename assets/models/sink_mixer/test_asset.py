"""Validate four original Coffee Shift sink GLBs with pure Python standard library."""
import json
import math
import struct
from pathlib import Path

folder = Path(__file__).resolve().parent
names = [
    "stainless_sink_basin.glb",
    "gooseneck_mixer_body.glb",
    "mixer_lever.glb",
    "drain_strainer.glb",
]
for name in names:
    raw = (folder / name).read_bytes()
    assert struct.unpack_from("<III", raw, 0) == (0x46546C67, 2, len(raw))
    json_length, json_type = struct.unpack_from("<II", raw, 12)
    assert json_type == 0x4E4F534A
    obj = json.loads(raw[20:20 + json_length])
    bin_length, bin_type = struct.unpack_from("<II", raw, 20 + json_length)
    assert bin_type == 0x004E4942
    assert 28 + json_length + bin_length == len(raw)
    assert obj["asset"]["version"] == "2.0"
    assert obj["materials"] and obj["meshes"]
    mins = [float("inf")] * 3
    maxs = [-float("inf")] * 3
    tris = 0
    dv = memoryview(raw)
    for mesh in obj["meshes"]:
        for primitive in mesh["primitives"]:
            position = obj["accessors"][primitive["attributes"]["POSITION"]]
            normal = obj["accessors"][primitive["attributes"]["NORMAL"]]
            indices = obj["accessors"][primitive["indices"]]
            assert indices["count"] % 3 == 0 and indices["count"] > 0
            assert position["count"] == normal["count"]
            assert all(math.isfinite(x) for x in position["min"] + position["max"])
            for k in range(3):
                mins[k] = min(mins[k], position["min"][k])
                maxs[k] = max(maxs[k], position["max"][k])
            buffer_start = 28 + json_length
            iv = obj["bufferViews"][indices["bufferView"]]
            for j in range(indices["count"]):
                v = struct.unpack_from("<H", dv, buffer_start + iv["byteOffset"] + j * 2)[0]
                assert v < position["count"]
            tris += indices["count"] // 3
    if name.startswith("stainless_sink"):
        assert .43 < (maxs[0] - mins[0]) < .45
        assert .47 < (maxs[2] - mins[2]) < .49
        assert mins[1] < -.17 and maxs[1] > 0
        mesh_names = {m["name"] for m in obj["meshes"]}
        assert "Basin_Inner_Continuous" in mesh_names
        assert "Basin_Outer_Stainless_Underside" in mesh_names
    if name.startswith("gooseneck"):
        assert maxs[1] > .29
    print("PASS", name, "triangles:", tris, "file bytes:", len(raw))

scene = (folder / "sink_with_mixer.tscn").read_text(encoding="utf8")
assert scene.count("instance=ExtResource") == 4
assert "LeverPivot" in scene and "WaterOutlet" in scene and "DrainCenter" in scene
assert "mixer_lever.glb" in scene
assert "sink_mixer.gd" in scene
print("PASS Godot scene resource and interaction declarations")

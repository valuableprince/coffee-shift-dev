"""Offline GLB 2.0 integrity, bounding-box and roof consistency checks."""
import json
import math
import struct
from pathlib import Path

root = Path(__file__).resolve().parent
names = [
    "coffee_trailer_shell.glb",
    "coffee_trailer_chassis.glb",
    "coffee_trailer_window_hatch.glb",
    "coffee_trailer_rear_door.glb",
]
overall = {}
for name in names:
    data = (root / name).read_bytes()
    assert struct.unpack_from("<III", data, 0) == (0x46546C67, 2, len(data))
    json_len, json_type = struct.unpack_from("<II", data, 12)
    assert json_type == 0x4E4F534A
    obj = json.loads(data[20:20 + json_len])
    offset = 20 + json_len
    binary_len, binary_type = struct.unpack_from("<II", data, offset)
    assert binary_type == 0x004E4942 and offset + 8 + binary_len == len(data)
    assert obj["asset"]["version"] == "2.0" and obj["materials"]
    bbmin, bbmax = [float("inf")]*3, [float("-inf")]*3
    triangles = 0
    for mesh in obj["meshes"]:
        for primitive in mesh["primitives"]:
            p = obj["accessors"][primitive["attributes"]["POSITION"]]
            n = obj["accessors"][primitive["attributes"]["NORMAL"]]
            ix = obj["accessors"][primitive["indices"]]
            assert p["count"] == n["count"]
            assert ix["count"] % 3 == 0
            assert ix["count"] >= 3
            assert all(map(math.isfinite, p["min"] + p["max"]))
            for j in range(3):
                bbmin[j] = min(bbmin[j], p["min"][j])
                bbmax[j] = max(bbmax[j], p["max"][j])
            triangles += ix["count"] // 3
    overall[name] = (bbmin, bbmax, triangles)
    print("PASS", name, len(data), "bytes", triangles, "triangles")

smin, smax, _ = overall["coffee_trailer_shell.glb"]
assert 2.35 < smax[0] - smin[0] < 2.60
assert abs(smax[1] - 2.70) < 0.005
assert 5.45 < smax[2] - smin[2] < 5.60
# The roof top and inside ceiling must be on their intended parallel profiles.
s = (root / "coffee_trailer_shell.glb").read_bytes()
ln = struct.unpack_from("<I", s, 12)[0]
g = json.loads(s[20:20 + ln])
ys = [a["max"][1] for a in g["accessors"] if a["type"] == "VEC3" and "min" in a]
assert any(abs(y - 2.64) < 0.002 for y in ys)
assert any(abs(y - 2.70) < 0.002 for y in ys)

hmin, hmax, _ = overall["coffee_trailer_window_hatch.glb"]
assert -.92 < hmin[1] < -.86 and -.01 < hmax[1] < .03
dmin, dmax, _ = overall["coffee_trailer_rear_door.glb"]
assert -.01 <= dmin[0] < .05 and .91 < dmax[0] < .98
assert 1.85 < dmax[1] < 1.95
scene = (root / "coffee_trailer.tscn").read_text(encoding="utf8")
for marker in [
    "EquipmentAnchor_CoffeeMachine", "EquipmentAnchor_Grinder",
    "EquipmentAnchor_CashRegister", "EquipmentAnchor_Sink",
    "EquipmentAnchor_Fridge", "PlayerSpawn_Interior",
    "WindowHinge", "RearDoorHinge", "FixedShellCollision",
]:
    assert marker in scene
assert (root / "trailer_asset.gd").exists()
print("PASS trailer dimensions, roof profiles and Godot scene references")


# Decode the active primitives, not stale/unreferenced accessor bounds.
def read_accessor(obj, binary, index):
    a = obj['accessors'][index]
    v = obj['bufferViews'][a['bufferView']]
    count = {'SCALAR': 1, 'VEC3': 3}[a['type']]
    fmt = '<' + {5126:'f',5123:'H',5125:'I'}[a['componentType']] * count
    stride = v.get('byteStride', struct.calcsize(fmt))
    start = v.get('byteOffset',0) + a.get('byteOffset',0)
    return [struct.unpack_from(fmt,binary,start+i*stride) for i in range(a['count'])]

def cross(a,b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])

seen = set()
active_triangles = 0
profile_ends = {}
for name in names:
    data=(root/name).read_bytes()
    length=struct.unpack_from('<I',data,12)[0]
    obj=json.loads(data[20:20+length]);binary=data[28+length:]
    for mesh in obj['meshes']:
        for primitive in mesh['primitives']:
            positions=read_accessor(obj,binary,primitive['attributes']['POSITION'])
            normals=read_accessor(obj,binary,primitive['attributes']['NORMAL'])
            indices=[i[0] for i in read_accessor(obj,binary,primitive['indices'])]
            assert all(math.isfinite(v) for p in positions+normals for v in p)
            assert all(0 <= i < len(positions) for i in indices)
            assert all(abs(sum(v*v for v in n)-1) < 1e-4 for n in normals)
            for i in range(0,len(indices),3):
                ids=indices[i:i+3];points=[positions[j] for j in ids]
                u=tuple(points[1][j]-points[0][j] for j in range(3))
                v=tuple(points[2][j]-points[0][j] for j in range(3))
                face=cross(u,v)
                assert sum(v*v for v in face)>1e-16, (name,mesh['name'],'degenerate')
                normal=normals[ids[0]]
                assert sum(face[j]*normal[j] for j in range(3))>0, (name,mesh['name'],'winding')
                if name == names[0]:
                    key=tuple(sorted(tuple(round(v,6) for v in p) for p in points))
                    assert key not in seen, ('duplicate shell triangle',mesh['name'])
                    seen.add(key);active_triangles += 1
            if name == names[0] and mesh['name']=='Rubber_Floor':
                assert abs(max(p[1] for p in positions)-.4)<1e-6
            if name == names[0] and mesh['name']=='Inner_Ceiling':
                # Same inner roof profile at the two longitudinal ends; end caps
                # use +/-Z normals and are deliberately excluded from this test.
                front=set();rear=set()
                for p,n in zip(positions,normals):
                    if abs(n[2])<.1:
                        assert n[0]*(-p[0]) + n[1]*(1.4-p[1]) > 0, 'ceiling normal faces room'
                        pair=(round(p[0],5),round(p[1],5))
                        if p[2]<-2.69:front.add(pair)
                        if p[2]>2.69:rear.add(pair)
                assert front==rear and len(front)>=30, 'ceiling profile varies along Z'
                assert any(abs(y-2.64)<1e-5 for x,y in front)
assert active_triangles==1880
print('PASS 1880 unique nondegenerate shell triangles; finite unit normals and winding; level .4 floor; invariant inward ceiling profile')

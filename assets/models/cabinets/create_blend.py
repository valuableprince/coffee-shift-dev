"""Create editable Coffee Shift cabinets .blend from six game GLBs.
Run: blender --background --python assets/models/cabinets/create_blend.py
Requires Blender 3.6+; generates one assembled scene and preserves door objects.
"""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system = 'METRIC'

def import_piece(name, parent, shift=(0, 0, 0)):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(root / (name + ".glb")))
    imported = set(bpy.data.objects) - before
    for obj in imported:
        if obj.parent not in imported:
            obj.parent = parent
            obj.location = shift
    return imported

for prefix, xshift, lift, left_x, right_x in [
    ("base", -0.75, 0.0, -0.520, 0.520),
    ("wall", 0.86, 1.07, -0.461, 0.461),
]:
    root_obj = bpy.data.objects.new(prefix + "_cabinet", None)
    bpy.context.collection.objects.link(root_obj)
    root_obj.location = (xshift, lift, 0)
    import_piece(prefix + "_cabinet_body", root_obj)
    for side, hinge_x in [("left", left_x), ("right", right_x)]:
        hinge = bpy.data.objects.new(prefix + "_" + side + "_hinge", None)
        bpy.context.collection.objects.link(hinge)
        hinge.parent = root_obj
        hinge.location = (hinge_x, 0.0, 0.020)
        import_piece(prefix + "_cabinet_door_" + side, hinge)
bpy.ops.wm.save_as_mainfile(filepath=str(root / "coffee_shift_cabinets.blend"))
print("Created editable coffee_shift_cabinets.blend")

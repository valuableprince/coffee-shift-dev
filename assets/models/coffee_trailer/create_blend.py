"""Import four shipped Coffee Shift GLBs into an editable Blender .blend.
Usage: blender --background --python assets/models/coffee_trailer/create_blend.py
Blender 3.6+, 4.x preferred. Materials and GLB geometry remain unchanged.
"""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system = "METRIC"

def add_group(name, parent=None, position=(0, 0, 0)):
    empty = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(empty)
    if parent is not None:
        empty.parent = parent
    empty.location = position
    return empty

trailer = add_group("Trailer_Assembly")
for part, parent in [
    ("coffee_trailer_shell", trailer),
    ("coffee_trailer_chassis", trailer),
]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(root / (part + ".glb")))
    imported = set(bpy.data.objects) - before
    for obj in imported:
        if obj.parent not in imported:
            obj.parent = parent

hatch = add_group("WindowHinge", trailer, (1.237, 2.105, 0))
door = add_group("RearDoorHinge", trailer, (-0.480, 0.400, 2.785))
for part, parent in [
    ("coffee_trailer_window_hatch", hatch),
    ("coffee_trailer_rear_door", door),
]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(root / (part + ".glb")))
    imported = set(bpy.data.objects) - before
    for obj in imported:
        if obj.parent not in imported:
            obj.parent = parent

output = root / "coffee_trailer.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print("Saved", output)

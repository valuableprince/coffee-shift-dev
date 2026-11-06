"""Prepare an editable Blender file from Coffee Shift milk pitcher GLB.
Usage:
  blender --background --python assets/models/milk_pitcher/create_blend.py
Requires Blender 3.6+ (Blender 4.x preferred).
"""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parent
source = root / "coffee_shift_milk_pitcher.glb"
dest = root / "coffee_shift_milk_pitcher.blend"
if not source.is_file():
    raise FileNotFoundError(source)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
models = [obj for obj in bpy.data.objects if obj.type == "MESH"]
if len(models) < 5:
    raise RuntimeError("Milk pitcher import did not produce enough editable mesh objects")
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0
bpy.ops.wm.save_as_mainfile(filepath=str(dest))
print(f"Saved {dest} with {len(models)} mesh objects")

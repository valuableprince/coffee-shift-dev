"""Create editable Blender scene from the source GLB (Blender 3.6+).
Usage: blender --background --python assets/models/portafilter/create_blend.py
"""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parent
source = root / "coffee_shift_portafilter.glb"
target = root / "coffee_shift_portafilter.blend"
if not source.exists():
    raise FileNotFoundError(source)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
if not meshes:
    raise RuntimeError("Import produced no mesh objects")
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0
bpy.ops.wm.save_as_mainfile(filepath=str(target))
print(f"Saved {target} with {len(meshes)} meshes")

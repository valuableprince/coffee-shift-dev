"""Import the Coffee Shift tamper GLB and save an editable Blender .blend.
Requires Blender 3.6+; use Blender 4.x when possible.
Usage: blender --background --python assets/models/tamper/create_blend.py
"""
from pathlib import Path
import bpy

base = Path(__file__).resolve().parent
source = base / "coffee_shift_tamper.glb"
output = base / "coffee_shift_tamper.blend"
if not source.is_file():
    raise FileNotFoundError(f"Tamper GLB is missing: {source}")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [ob for ob in bpy.data.objects if ob.type == "MESH"]
if len(meshes) < 2:
    raise RuntimeError("Tamper GLB did not import its named mesh parts")
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print(f"Saved {output}: {len(meshes)} editable meshes")

"""Import Coffee Shift GLBs into Blender and save a scene.
Run: blender --background --python assets/models/takeaway_cup/create_blend.py
"""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
for name in ("coffee_shift_paper_cup_350ml.glb", "coffee_shift_sip_lid_90mm.glb"):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(root / name))
    if "sip_lid" in name:
        imported = set(bpy.data.objects) - before
        for obj in imported:
            if obj.parent not in imported:
                obj.location.y += .114
bpy.ops.wm.save_as_mainfile(filepath=str(root / "coffee_shift_cup_and_lid.blend"))

"""Rebuild an editable Blender scene from the three shipped GLB assets.
Run: blender --background --python assets/models/cash_register/create_blend.py
Blender 3.6+ / 4.x. Geometry and materials are not regenerated.
"""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system = 'METRIC'
collection = bpy.context.collection
parent = bpy.data.objects.new("CashRegister_Assembly", None)
collection.objects.link(parent)
for name in ("cash_register_body", "cash_drawer", "receipt_paper"):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(root / (name + ".glb")))
    imported = set(bpy.data.objects) - before
    for obj in imported:
        if obj.parent not in imported:
            obj.parent = parent
bpy.ops.wm.save_as_mainfile(filepath=str(root / "coffee_shift_cash_register.blend"))
print("Saved editable coffee_shift_cash_register.blend")

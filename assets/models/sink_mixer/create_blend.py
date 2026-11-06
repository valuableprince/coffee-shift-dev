"""Import original sink, mixer, lever and drain GLBs into an editable Blender file.
Usage: blender --background --python assets/models/sink_mixer/create_blend.py
No re-generated substitute meshes; the shipped GLBs remain authoritative.
"""
from pathlib import Path
import bpy

folder = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system = "METRIC"

def empty(name, parent=None, position=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    obj.location = position
    return obj

root = empty("CoffeeShift_SinkAssembly")
lever_hinge = empty("LeverPivot", root, (.103, .035, -.186))

for filename, parent in (
    ("stainless_sink_basin.glb", root),
    ("gooseneck_mixer_body.glb", root),
    ("mixer_lever.glb", lever_hinge),
    ("drain_strainer.glb", root),
):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(folder / filename))
    imported = set(bpy.data.objects) - before
    for obj in imported:
        if obj.parent not in imported:
            obj.parent = parent

output = folder / "coffee_shift_sink_mixer.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print("Created", output)

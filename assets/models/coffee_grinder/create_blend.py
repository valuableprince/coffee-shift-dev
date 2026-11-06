"""Import the Coffee Shift electric grinder GLB into Blender and save an editable .blend.
Usage: blender --background --python create_blend.py
Optional: blender --background --python create_blend.py -- --source /path/model.glb --output /path/model.blend
Blender 3.6+; Blender 4.x recommended.
"""
import argparse
import sys
from pathlib import Path
import bpy

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path(__file__).with_name("coffee_grinder.glb"))
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("coffee_grinder.blend"))
    args = parser.parse_args(argv)
    src, out = args.source.resolve(), args.output.resolve()
    if not src.is_file():
        raise FileNotFoundError(f"GLB asset was not found: {src}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src))
    if not any(o.type == "MESH" for o in bpy.data.objects):
        raise RuntimeError("GLB import produced no mesh objects")
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.name = ob.name.replace(".", "_") if ob.name.startswith(".") else ob.name
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.scene.render.resolution_x = 1280
    bpy.context.scene.render.resolution_y = 1280
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print(f"Saved editable Blender project: {out} ({len(bpy.data.objects)} objects)")

if __name__ == "__main__":
    main()

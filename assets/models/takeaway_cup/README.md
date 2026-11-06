# Coffee Shift — paper takeaway cup and sip lid (PS2+)

Two original independent 3D assets for Godot 4.3+ (Windows) and Blender 3.6+/4.x, unified PS2+ / Cozy Realism style. No external textures, third-party models or licensing dependencies.

- `coffee_shift_paper_cup_350ml.glb`: hollow tapered paper cup, rolled lip, inset base, kraft sleeve, muted orange stripe and coffee-bean logo.
- `coffee_shift_sip_lid_90mm.glb`: detachable dark plastic snap-on lid with a real open sipping cutout toward +Z and vent indentation.
- `cup.tscn`, `lid.tscn`: independent Godot scenes with placeholder collisions and interaction markers.
- `cup_with_lid.tscn`: preassembled example, with independent cup and lid nodes.
- `create_blend.py`: generate an editable Blender file by importing the two GLBs.
- `test_asset.py`: check GLB format, materials, dimensions, and primitive counts using stdlib Python.

## Scale and orientation
All measurements are in meters, with Y up. Cup origin at its base, rim at Y=0.114 m, diameter ~87.6 mm at top and ~61.4 mm at bottom. The Fill350ml marker is at Y=0.095 m (the working fill level, below the rim). Lid outer diameter ~92.4 mm, vertical range -0.007..+0.0161 m in its own GLB. Place lid origin at (0, 0.114, 0) relative to the cup; drinking port points toward +Z.

Godot scene paths:
`res://assets/models/takeaway_cup/cup.tscn`
`res://assets/models/takeaway_cup/lid.tscn`
`res://assets/models/takeaway_cup/cup_with_lid.tscn`

Assets do not automatically change existing game cup placeholders, brewing mechanics, serving or recipes. Collision geometry is approximate, not a liquid simulation.

Blender import:
```sh
blender --background --python assets/models/takeaway_cup/create_blend.py
```

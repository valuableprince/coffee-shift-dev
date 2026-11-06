# Coffee Shift — modular trailer shell PS2+

**Original 3D game asset** for the 5.5 m Russian takeaway coffee trailer (early 2010s), Godot 4.3+, Windows. Simple stylized PS2+ / Cozy Realism geometry, no third-party assets, PBR materials embedded in each GLB.

## Delivered files

| File | Content |
|---|---|
| `coffee_trailer_shell.glb` | Outer aluminium body, interior walls and **smooth inner roof**, floor, actual service opening and staff door opening, frames, trim |
| `coffee_trailer_chassis.glb` | Steel frame, axle, wheels, tow hitch, jockey wheel, rear step |
| `coffee_trailer_window_hatch.glb` | Separate service hatch ready for top-hinge rotation |
| `coffee_trailer_rear_door.glb` | Separate rear staff door ready for side-hinge rotation |
| `coffee_trailer.tscn` | Assembled modular Godot scene with independent hinges, mesh-aligned static collision and equipment anchors |
| `trailer_asset.gd`, `trailer_target.gd` | Optional interaction adapter for hatch and rear door |
| `preview.tscn`, `preview.gd` | Standalone preview scene with two cameras and opening controls |
| `create_blend.py` | Blender GLB importer, creates editable `coffee_trailer.blend` |
| `test_asset.py` | GLB integrity / bounding boxes / roof consistency tests |

## Approved dimensions and coordinates

**Units are metres, Y up**; centre of trailer body at X/Z = 0, Y = ground.

- Main body length **5.5 m** (from Z ≈ -2.75 to +2.75), width **2.4 m** (X ±1.2).
- Ground-to-floor **0.40 m**; roof peak **2.70 m**; room height above floor **2.30 m**.
- Right side **+X** is the 1.60 × 0.90 m serving window, from Y=1.20 to 2.10.
- Rear entry at **+Z**, ~0.95 × 1.90 m (lower edge Y=0.40).
- Towing hitch projects ahead toward **-Z** (outside the 5.5 m body envelope).

### Roof geometry and correction of ceiling defect

The outer profile is a continuous centre flat **Y=2.70 m for |X|≤0.65**, smoothly meeting 0.55 m radius shoulders down to sidewalls at **X=±1.20, Y=2.15**. Along the Z direction this profile is **identical**, preventing the earlier procedural roof "wave".

Interior ceiling is an independent parallel surface: **Y=2.64 m at the flat centre** and a 0.49 m radius inner curve meeting the inner sidewall at approximately X=±1.14. The gap between the two skins is approximately 60 mm. Inner surfaces and exterior skin are distinct materials. The end gables are built explicitly; the rear opening remains open and the side window is genuinely cut out.

## Godot scene and movement

Place `res://assets/models/coffee_trailer/coffee_trailer.tscn` as a standalone packed scene.

Hinges:
- `WindowHinge` at local `(1.237, 2.105, 0)`: opens +77° around Z, ~0.85 s.
- `RearDoorHinge` at local `(-0.480, 0.400, 2.785)`: opens -100° around Y, ~0.68 s.

```gdscript
$Trailer.set_hatch_open(true)
$Trailer.set_rear_door_open(true)
$Trailer.toggle_hatch()
$Trailer.set_rear_door_open(false, false) # restore save state instantly
```

First-person E interaction uses separate ray targets (collision layer 2); labels only appear on interaction prompts. This asset DOES NOT alter the game's current input router or `scripts/trailer/trailer_shell.gd`.

Equipment anchors include coffee machine, grinder, cash register, sink, fridge, both work lines, window, entry and player spawn.

## Preview and validation

Open `assets/models/coffee_trailer/preview.tscn`, run F6. Enter/Space toggles the hatch, right arrow toggles the door, **C** switches exterior/interior camera.

```sh
python assets/models/coffee_trailer/test_asset.py
blender --background --python assets/models/coffee_trailer/create_blend.py
```

**Blender is required to generate the editable .blend**; source shipped models are actual glTF 2.0 Binary and can be edited by importing in Blender even without a pre-generated .blend.

## Integration in the real game

`TrailerShell.build()` now instances this PackedScene inside the existing
`CoffeeTrailer`. There are no procedural walls, roof, floor, frames or chassis.
The existing interior, two work lines, portable lamp and removable entry ramp
remain separate nodes. The trade scene retains PR #70 lighting and PR #73 assets.

The integration fixes the malformed `DoorVisual` scene header and replaces the
inaccurate graybox collisions with one concave collider made from the active
shell triangles (including the actual curved roof). The door visual is reparented
to the existing `StaffDoor` controller: saved state, safe reversal and one E route
remain unchanged. The imported hatch delegates to the existing window workstation
and `CoffeeShiftSession.window_open`; the standalone input adapter is disabled.
The closed hatch blocks the player; its motion and open position use ray targets
without pushing the player. Save loading cancels in-flight hatch motion and
restores the authoritative endpoint immediately.

The original shell needed localized geometry repairs. `repair_asset.py` reproduces
them from the PR #74 GLB: the visible floor is lowered 49.5 mm to Y=.400, its support
plate is lowered 60 mm, the rubber finish is extended 52 mm at both ends to meet
the threshold, the rear threshold is lowered 47 mm, and intersecting rear gable /
header triangles are clipped to the .98 x 1.90 m entry. The longitudinal roof and
all materials remain original. Shell: 1880 triangles instead of 1860. The other
three GLBs are byte-identical to PR #74.

For roof clearance, the two wall cabinets move 40 mm toward the aisle (X=-.81 ->
-.77); their heights and Z positions remain unchanged. The opposite menu board
and its text move down 20 mm. No other equipment coordinates change.

See `docs/TRAILER_INTEGRATION_REPORT.md` for the real Godot 4.3 screenshots,
commands, source hashes, checklist and platform limitations.

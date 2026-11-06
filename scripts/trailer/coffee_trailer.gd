class_name CoffeeTrailer
extends Node3D
## Reusable trailer scene. Non-approved dimensions below are prototype values.

const G := preload("res://scripts/prototype/prototype_geometry.gd")
const Shell := preload("res://scripts/trailer/trailer_shell.gd")
const BODY_LENGTH := 5.5
const BODY_WIDTH := 2.4
const ROOF_HEIGHT := 2.7
const FLOOR_HEIGHT := 0.4
const AISLE_WIDTH := 0.95
const WINDOW_SIZE := Vector2(1.6, 0.9)
const WINDOW_SILL := 1.2
const PROTOTYPE_DOOR_WIDTH := 0.95
const PROTOTYPE_DOOR_HEIGHT := 1.9
const LINE_INNER_EDGE := AISLE_WIDTH / 2.0
const LINE_DEPTH := 1.14 - LINE_INNER_EDGE

@export var trailer_id: StringName = &"trailer_01"
@export var build_restoration := true

var shell: CoffeeShiftTrailerAsset

func _ready() -> void:
	shell = Shell.build(self)
	# Keep the established TrailerDoor API and save path; only replace its leaf.
	var hinge: Node3D = shell.get_node("RearDoorHinge")
	$StaffDoor.position = hinge.position
	hinge.get_node("DoorVisual").reparent($StaffDoor, false)
	hinge.get_node("DoorInteraction").free()
	if build_restoration:
		# The existing glass/dirt task remains accessible in the garage.
		shell.set_hatch_open(true, false)
	_interior()
	_access()
	if build_restoration:
		RestorationCatalog.build_parts(self)

func _interior() -> void:
	var line_x := LINE_INNER_EDGE + LINE_DEPTH / 2.0
	# Opposed work lines; every closed equipment part stays outside +/-0.475 m.
	# Leave the existing fridge bay open; the work-line envelope is unchanged.
	G.box(self, "OppositeCabinetsFront", Vector3(-line_x, .815, -1.16), Vector3(LINE_DEPTH,.83,1.33), Color("8b8c75"))
	G.box(self, "OppositeCabinetsRear", Vector3(-line_x, .815, 1.04), Vector3(LINE_DEPTH,.83,1.57), Color("8b8c75"))
	G.box(self, "OppositeWorktop", Vector3(-line_x, 1.27, 0), Vector3(LINE_DEPTH, 0.06, 3.7), Color("b7b4a0"), true, 0.15)
	for z in [-1.4, 1.4]:
		G.box(self, "PreparationCabinet", Vector3(line_x, 0.815, z), Vector3(LINE_DEPTH, 0.83, 1.1), Color("8b8c75"))
		G.box(self, "PreparationWorktop", Vector3(line_x, 1.27, z), Vector3(LINE_DEPTH, 0.06, 1.1), Color("b7b4a0"), true, 0.15)
	G.box(self, "ServingBase", Vector3(line_x, 0.76, 0), Vector3(LINE_DEPTH, 0.72, 1.6), Color("8b8c75"))
	G.box(self, "ServingWorktop", Vector3(line_x, 1.17, 0), Vector3(LINE_DEPTH, 0.06, 1.6), Color("b7b4a0"), true, 0.15)
	# Temporary workshop battery lamp; does not establish a final power system.
	G.box(self, "PrototypePortableLamp", Vector3(0, 2.43, 0), Vector3(0.42, 0.045, 0.12), Color("e0dab7"), false)
	var lamp := OmniLight3D.new()
	lamp.name = "PortableWorkLight"
	lamp.position = Vector3(0, 2.32, 0)
	lamp.light_color = Color("f1e4bc")
	lamp.light_energy = 1.0
	lamp.omni_range = 4.0
	lamp.shadow_enabled = true
	add_child(lamp)

func _access() -> void:
	# Temporary removable ramp: continuous slope, no jump/teleport needed.
	var ramp := PackedVector3Array()
	G.quad(ramp, Vector3(-0.47, 0.4, 2.68), Vector3(0.47, 0.4, 2.68),
		Vector3(0.47, 0.008, 4.15), Vector3(-0.47, 0.008, 4.15))
	G.surface(self, "PrototypeAccessRamp", ramp, Color("8e8769"))

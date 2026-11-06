@tool
extends Node3D
## Unlabelled 1.5 L PET bottle. Metres, base at Y=0.
const A := preload("res://scripts/prototype/asset_geometry.gd")
const G := preload("res://scripts/prototype/prototype_geometry.gd")
@export var opened := false

func _ready() -> void:
	_rebuild()

func set_opened(value: bool) -> void:
	opened = value
	if is_inside_tree(): _rebuild()

func _rebuild() -> void:
	var root := A.reset(self)
	var outline := A.round_outline()
	var body: Array[Vector3] = [Vector3(.004,.032,.032), Vector3(.014,.044,.044)]
	for y in [.04, .075, .11, .145, .18, .215]:
		body.append(Vector3(y-.005,.043,.043))
		body.append(Vector3(y,.045,.045))
		body.append(Vector3(y+.005,.043,.043))
	body.append_array([Vector3(.25,.041,.041), Vector3(.279,.031,.031), Vector3(.301,.018,.018), Vector3(.319,.018,.018)])
	var plastic := A.material(Color(.79,.90,.94,.14), true)
	A.loft(root, "ClearPET", body, outline, plastic)
	A.loft(root, "Water", [Vector3(.018,.038,.038), Vector3(.238,.038,.038), Vector3(.258,.035,.035)], outline, A.material(Color(.59,.81,.89,.12), true))
	var cap := G.cylinder(root, "BlueCap", Vector3(0,.325,0), .021, .023, Color("32629c"), false)
	cap.visible = not opened
	for i in range(12):
		var angle := TAU * i / 12
		var grip := G.box(cap, "Grip", Vector3(sin(angle)*.021,0,cos(angle)*.021), Vector3(.003,.017,.002), Color("254e85"), false)
		grip.rotation.y = angle
	G.cylinder(root, "NeckRing", Vector3(0,.309,0), .022, .004, Color("b3cbd1"), false)
	A.collider(root, Vector3(.09,.338,.09))

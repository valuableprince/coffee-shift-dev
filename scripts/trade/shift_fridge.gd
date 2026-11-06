class_name ShiftFridge
extends Node3D
## Hollow undercounter fridge, front faces +X. Milk is physically inside.
signal door_changed(opened: bool)
const G := preload("res://scripts/prototype/prototype_geometry.gd")
const OPEN_ANGLE := deg_to_rad(105)
var opened := false
var moving := false
var hinge: Node3D
var milk: Node3D
var _motion: Tween

func _ready() -> void:
	name = "WorkingFridge"
	var outside := Color("b8c5bb")
	var inside := Color("e0e5d8")
	G.box(self,"Back",Vector3(-.266,0,0),Vector3(.026,.72,.62),outside)
	for z in [-.297,.297]:
		G.box(self,"Side",Vector3(0,0,z),Vector3(.55,.72,.026),outside)
	for y in [-.345,.345]:
		G.box(self,"InsulatedPanel",Vector3(0,y,0),Vector3(.55,.03,.62),outside)
	G.box(self,"InsideBack",Vector3(-.248,0,0),Vector3(.009,.65,.55),inside,false)
	G.box(self,"LowerShelf",Vector3(-.005,-.282,0),Vector3(.47,.018,.55),inside,false)
	G.box(self,"UpperShelf",Vector3(-.005,.14,0),Vector3(.47,.012,.55),inside,false)
	hinge = Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(.285,0,.30)
	add_child(hinge)
	G.box(hinge,"Door",Vector3(0,0,-.30),Vector3(.035,.68,.60),Color("d3ddd0"),false)
	G.box(hinge,"Seal",Vector3(-.023,0,-.30),Vector3(.009,.64,.56),Color("6d8174"),false)
	G.box(hinge,"Handle",Vector3(.044,.16,-.52),Vector3(.025,.20,.03),Color("506e60"),false)
	G.box(hinge,"LowerTrim",Vector3(.024,-.27,-.30),Vector3(.015,.04,.55),Color("81978a"),false)
	milk = load("res://assets/models/utrenniy_lug/milk_carton.tscn").instantiate()
	milk.name = "MilkStock"
	milk.position = Vector3(.18,-.271,-.14)
	milk.rotation.y = PI/2
	add_child(milk)
	# The carton itself is an interaction target managed by ShiftWorld.
	# Its visual-only embedded collider must not occlude that raycast target.
	for body in milk.find_children("*", "StaticBody3D", true, false): body.collision_layer = 0
	var light := OmniLight3D.new()
	light.name = "InteriorLight"
	light.position = Vector3(.10,.22,0)
	light.omni_range = .8
	light.light_energy = .25
	light.light_color = Color("e3f2e9")
	light.visible = false
	add_child(light)

func toggle() -> void:
	if moving: return
	opened = not opened
	moving = true
	_motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(hinge,"rotation:y",-OPEN_ANGLE if opened else 0.0,.45)
	get_node("InteriorLight").visible = opened
	# Publish the destination state now so saves during movement stay consistent.
	door_changed.emit(opened)
	_motion.finished.connect(func() -> void: moving = false)

func restore_opened(value: bool) -> void:
	if _motion != null: _motion.kill()
	opened = value
	moving = false
	hinge.rotation.y = -OPEN_ANGLE if opened else 0.0
	get_node("InteriorLight").visible = opened
	door_changed.emit(opened)

func milk_accessible() -> bool:
	return opened and not moving

class_name FirstPersonTools
extends Node3D
## Short procedural holster/draw motion plus cloth/brush strokes and wrist turns.
const G := preload("res://scripts/prototype/prototype_geometry.gd")
var belt: ToolBelt
var holder: Node3D
var model: Node3D
var working := false
var work_kind := "clean"
var switching := false
var _tween: Tween
var _time := 0.0
const REST := Vector3(.29,-.30,-.52)

func _ready() -> void:
	holder = Node3D.new()
	holder.position = REST
	add_child(holder)
	# Sleeve, forearm, palm and wrapped fingers; no disembodied floating tool.
	G.box(holder,"Sleeve",Vector3(.035,-.12,.20),Vector3(.10,.11,.22),Color("4b645e"),false)
	G.box(holder,"Wrist",Vector3(.015,-.07,.065),Vector3(.068,.072,.11),Color("c3a381"),false)
	G.box(holder,"Palm",Vector3(0,-.04,.015),Vector3(.074,.085,.052),Color("c6a785"),false)
	for i in range(4):
		var finger := G.box(holder,"Finger",Vector3(-.027+float(i)*.018,-.014,-.021),Vector3(.015,.046,.028),Color("bd9a79"),false)
		finger.rotation.x = -.5
	G.box(holder,"Thumb",Vector3(.045,-.035,-.01),Vector3(.033,.026,.032),Color("c6a785"),false)
	_view_materials(holder)
	holder.hide()

func bind(tool_belt: ToolBelt) -> void:
	belt = tool_belt
	belt.selected_changed.connect(_switch)
	_switch()

func _switch() -> void:
	working = false
	if _tween != null:
		_tween.kill()
	switching = true
	_tween = create_tween()
	_tween.tween_property(holder,"position",REST+Vector3(0,-.32,.1),.12)
	_tween.tween_callback(_replace_model)
	_tween.tween_property(holder,"position",REST,.18).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: switching = false)

func _replace_model() -> void:
	if model != null:
		model.free()
	model = null
	var id := belt.active_tool()
	if id != &"":
		model = ToolVisual.build(holder,id)
		model.rotation = Vector3(-.25,0,.15)
		_view_materials(model)
		holder.show()
	else:
		holder.hide()

func _process(delta: float) -> void:
	_time += delta
	if switching:
		return
	if working:
		var turn := work_kind in ["repair","equipment","seal"]
		holder.position = REST+Vector3(sin(_time*16)*(.015 if turn else .07),cos(_time*16)*.012,-.04)
		holder.rotation.z = sin(_time*15)*(.30 if turn else .06)
	else:
		holder.position = holder.position.lerp(REST,delta*12)
		holder.rotation = holder.rotation.lerp(Vector3.ZERO,delta*12)

func _view_materials(root: Node3D) -> void:
	# A view model stays readable under the close inspection light and casts no
	# oversized first-person shadow on the actual work surface.
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := mesh.material_override as StandardMaterial3D
		if material != null:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

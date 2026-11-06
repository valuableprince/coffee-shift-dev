class_name RepairablePart
extends InspectablePart
## Data-driven dirt, seals, small repairs and surface preparation.

const G := preload("res://scripts/prototype/prototype_geometry.gd")
var definition: Dictionary
var dimensions := Vector3.ONE
var kind := "clean"
var target_offset := Vector3.ZERO
var dirt: MeshInstance3D
var highlight: MeshInstance3D
var old_piece: Node3D
var new_piece: Node3D
var socket: Node3D

func configure(data: Dictionary) -> void:
	definition = data
	part_key = StringName(data.id)
	name = str(part_key).to_pascal_case()
	position = RestorationCatalog.vector(data.position)
	dimensions = RestorationCatalog.vector(data.size)
	kind = str(data.kind)
	task = RestorationTask.from_data(data)

func _ready() -> void:
	super._ready()
	# Work surfaces can be targeted without becoming obstacles in the aisle.
	collision_layer = 2
	collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = dimensions.max(Vector3(.045, .035, .045))
	collision.shape = shape
	add_child(collision)
	_build_visual()
	highlight = _mesh_box("Highlight", dimensions + Vector3(.016,.016,.016), Color("edbf63"))
	var material := G.material(Color(.93,.75,.39,.19))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color("edbf63")
	material.emission_energy_multiplier = .45
	highlight.material_override = material
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.hide()

func _mesh_box(label: String, size: Vector3, tint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = G.material(tint)
	add_child(instance)
	return instance

func _build_visual() -> void:
	if kind == "healthy":
		G.box(self,"SoundFrame",Vector3.ZERO,dimensions,Color("89998f"),false,.45)
	elif kind == "clean" or kind == "prepare":
		dirt = _mesh_box("Dirt", dimensions, Color("918068"))
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/window_dirt.gdshader")
		dirt.material_override = material
		dirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind == "prepare":
			new_piece = G.box(self,"PreparedEdge",Vector3.ZERO,dimensions,Color("b9c2b7"),false,.55)
			new_piece.hide()
	elif kind == "seal":
		socket = G.box(self,"SealGroove",Vector3.ZERO,dimensions*.92,Color("9d977e"),false)
		old_piece = Node3D.new()
		old_piece.name = "OldSeal"
		add_child(old_piece)
		# Separate dry, misaligned fragments contrast with a continuous new strip.
		var axis := Vector3.RIGHT if dimensions.x > dimensions.z else Vector3.BACK
		var length := maxf(dimensions.x,dimensions.z)
		for i in range(5):
			var piece_size := dimensions
			if dimensions.x > dimensions.z:
				piece_size.x = length*.17
			else:
				piece_size.z = length*.17
			var piece := G.box(old_piece,"DryRubber",axis*(float(i)-2)*length*.2,piece_size,Color("635944"),false)
			piece.rotation.y = .08 if i%2 == 0 else -.10
		new_piece = G.box(self,"NewSeal",Vector3.ZERO,dimensions,Color("242e2b"),false)
		new_piece.hide()
	else:
		old_piece = G.box(self,"LoosePart",Vector3.ZERO,dimensions,Color("947652"),false,.35)
		old_piece.rotation.x = .19
		new_piece = G.box(self,"FixedPart",Vector3.ZERO,dimensions,Color("aab6ac"),false,.55)
		for offset in [-.04,.04]:
			G.box(new_piece,"Fastener",Vector3(.02,offset,0),Vector3(.01,.014,.05),Color("4b5751"),false)
		new_piece.hide()

func _apply_status(status: int) -> void:
	var completed := status == RestorationState.Status.RESTORED or status == RestorationState.Status.INSPECTED
	if dirt != null:
		dirt.visible = not completed
		_apply_progress(work_progress)
	if old_piece != null:
		old_piece.visible = not completed and (kind != "seal" or state.phase_of(element_id) == 0)
	if new_piece != null:
		new_piece.visible = completed or (kind == "seal" and state.phase_of(element_id) >= 2)

func _apply_progress(progress: float) -> void:
	if dirt != null:
		(dirt.material_override as ShaderMaterial).set_shader_parameter("cleaned",progress)
	if old_piece != null and kind == "repair":
		old_piece.rotation.x = .19*(1-progress)

func _update_highlight() -> void:
	if highlight == null:
		return
	highlight.visible = inspection_enabled
	if state == null:
		return
	var status := state.status_of(element_id)
	var tint := Color("92bd98") if status in [RestorationState.Status.RESTORED,RestorationState.Status.INSPECTED] else Color("edbf63")
	var material := highlight.material_override as StandardMaterial3D
	material.albedo_color = Color(tint,.19)
	material.emission = tint

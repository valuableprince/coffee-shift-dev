class_name EquipmentInstallation
extends RepairablePart
## NOT_INSTALLED -> INSTALLED -> CHECKED -> READY are the task's 0..3 phases.

var equipment: Node3D
var indicator: MeshInstance3D

func _build_visual() -> void:
	socket = _mesh_box("MountingOutline", dimensions, Color(.6,.64,.55,.14))
	var ghost_material := G.material(Color(.7,.75,.65,.12))
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	socket.material_override = ghost_material
	equipment = Node3D.new()
	equipment.name = "InstalledEquipment"
	add_child(equipment)
	var body := G.box(equipment,"Housing",Vector3.ZERO,dimensions,Color("b3b9a8"),false,.3)
	var device := str(definition.device)
	if device == "machine":
		body.free()
		var model: Node3D = load("res://assets/models/espresso_machine/coffee_machine.tscn").instantiate()
		model.position.y = 1.30 - position.y
		model.scale = Vector3.ONE * .80
		model.rotation.y = -PI / 2
		equipment.add_child(model)
	elif device == "grinder":
		body.free()
		# Original approved GLB from PR #61, not a procedural replacement.
		var model: Node3D = load("res://assets/models/coffee_grinder/coffee_grinder.tscn").instantiate()
		model.position.y = 1.30 - position.y
		model.scale = Vector3.ONE * .60
		model.rotation.y = -PI / 2 # Model front +Z faces the central aisle (-X).
		equipment.add_child(model)
	elif device == "cash":
		G.box(body,"Keys",Vector3(-.23,.025,0),Vector3(.025,.10,.32),Color("465b50"),false)
		for z in [-.10,0,.10]:
			G.box(body,"Key",Vector3(-.245,.03,z),Vector3(.02,.025,.05),Color("d3c6a0"),false)
		G.box(body,"DrawerHandle",Vector3(-.25,-.07,0),Vector3(.025,.025,.16),Color("4a554c"),false)
		G.box(body,"Display",Vector3(0,.16,0),Vector3(.14,.08,.24),Color("36584b"),false)
	elif device == "fridge":
		G.box(body,"Door",Vector3(.28,0,0),Vector3(.025,.66,.57),Color("d6d8c4"),false,.2)
		G.box(body,"Handle",Vector3(.31,.15,.22),Vector3(.028,.24,.035),Color("4d6258"),false)
	elif device == "sink":
		G.box(body,"Basin",Vector3(0,.005,0),Vector3(.33,.015,.38),Color("536d69"),false,.7)
		G.cylinder(body,"TapStem",Vector3(-.16,.13,0),.018,.25,Color("b7c4b7"),false)
		G.box(body,"TapSpout",Vector3(-.09,.245,0),Vector3(.16,.035,.035),Color("b7c4b7"),false,.6)
		G.cylinder(body,"Drain",Vector3(0,.018,0),.035,.01,Color("202f2b"),false)
	indicator = _mesh_box("ReadyIndicator",Vector3(.012,.035,.045),Color("c69748"))
	indicator.position = Vector3(-dimensions.x/2-.015,dimensions.y/4,dimensions.z/3)
	# Keep the existing interaction volume without an artificial nameplate.
	var side := -1.0 if position.x > 0 else 1.0
	target_offset = Vector3(-side*.455-position.x,-.15 if definition.device != "fridge" else .10,0)
	target_offset.z = {"machine":-.26,"grinder":0.0,"fridge":0.0,"sink":.30,"cash":.34}[definition.device]
	var collision := get_node("CollisionShape3D") as CollisionShape3D
	(collision.shape as BoxShape3D).size = Vector3(.055,.16,.24)
	collision.position = target_offset
	set_equipment_visible(false)

func set_equipment_visible(value: bool) -> void:
	equipment.visible = value
	for body in equipment.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 3 if value else 0
		body.collision_mask = 0

func get_interaction_name() -> String:
	return str({"machine":"Кофемашина", "grinder":"Кофемолка", "fridge":"Холодильник", "sink":"Мойка", "cash":"Касса"}[definition.device])

func _apply_status(_status: int) -> void:
	var phase := state.phase_of(element_id)
	set_equipment_visible(phase >= 1)
	socket.visible = phase == 0
	indicator.visible = phase >= 1
	var material := indicator.material_override as StandardMaterial3D
	material.albedo_color = Color("87c28e") if phase == 3 else Color("d0ac64")
	material.emission_enabled = true
	material.emission = material.albedo_color

func _apply_progress(progress: float) -> void:
	if equipment != null and state != null and state.phase_of(element_id) >= 1:
		equipment.position.y = sin(progress*PI)*.008


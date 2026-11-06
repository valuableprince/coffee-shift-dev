class_name TradingLocation
extends RefCounted
const G := preload("res://scripts/prototype/prototype_geometry.gd")

static func build(parent: Node3D) -> void:
	G.box(parent, "Asphalt", Vector3(0, -.17, 0), Vector3(36, .3, 32), Color("777a70"))
	G.box(parent, "Sidewalk", Vector3(3.7, -.035, 0), Vector3(4.8, .05, 21), Color("aaa79a"))
	for z in range(-10, 12, 2):
		G.box(parent, "PavingJoint", Vector3(3.7, -.005, z), Vector3(4.8, .002, .015), Color("969889"), false)
	G.box(parent, "Road", Vector3(8.9, -.015, 0), Vector3(4.6, .02, 30), Color("636f6c"))
	for z in range(-12, 14, 4):
		G.box(parent, "RoadMarking", Vector3(9.2, .002, z), Vector3(.10, .01, 1.6), Color("ddd9bc"), false)
	for z in [-6, 5, 10]:
		_tree(parent, Vector3(-4.5 if z == 5 else 5.3, 0, z))
		_lamp(parent, Vector3(6.1, 0, z - .7))
	for z in [-5, 5]:
		G.box(parent, "BenchSeat", Vector3(4.5, .47, z), Vector3(1.5, .10, .46), Color("92795a"))
		G.box(parent, "BenchBack", Vector3(4.5, .80, z + .25), Vector3(1.5, .48, .065), Color("92795a"))
		for x in [3.95, 5.05]:
			G.box(parent, "BenchLeg", Vector3(x, .22, z), Vector3(.08, .44, .4), Color("405654"))
	G.box(parent, "OutsideBin", Vector3(5.2, .5, 1.3), Vector3(.8, 1, .8), Color("526c60"))
	G.box(parent, "BinLid", Vector3(5.2, 1.02, 1.3), Vector3(.85, .08, .86), Color("355348"))
	for i in range(5):
		var x := -12.0 + i * 6.5
		var height := 5.5 + (i % 3) * 1.2
		G.box(parent, "Building", Vector3(x, height / 2, -13), Vector3(5.8, height, 4), Color("adab95") if i % 2 else Color("b5a58c"))
		for row in range(2):
			for column in range(3):
				G.box(parent, "ApartmentWindow", Vector3(x - 1.8 + column * 1.8, 1.7 + row * 2.0, -10.98), Vector3(.8, 1.1, .025), Color("667c7c"), false)
	G.box(parent, "Fence", Vector3(-6, .65, 1), Vector3(.08, 1.3, 18), Color("60766a"))
	for z in range(-8, 11):
		G.box(parent, "FenceSlat", Vector3(-5.93, .75, z), Vector3(.10, 1.5, .12), Color("738675"), false)
	# Compact bounds keep the prototype walkable, no unseen open world.
	for x in [-17, 17]:
		G.box(parent, "Boundary", Vector3(x, 1, 0), Vector3(.2, 2, 32), Color("8a927d"))
	for z in [-15, 15]:
		G.box(parent, "Boundary", Vector3(0, 1, z), Vector3(34, 2, .2), Color("8a927d"))
	var environment := WorldEnvironment.new()
	environment.name = "OutdoorEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("becdd3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dae2e4")
	env.ambient_light_energy = .42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	parent.add_child(environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.name = "Daylight"
	sunlight.rotation_degrees = Vector3(-45, -35, 0)
	sunlight.light_color = Color("fff0d5")
	sunlight.light_energy = .62
	sunlight.shadow_enabled = true
	# Spend the existing shadow map on this small location, not 100 m of sky.
	sunlight.directional_shadow_max_distance = 18
	sunlight.shadow_opacity = .35
	sunlight.shadow_bias = .035
	sunlight.shadow_normal_bias = .8
	parent.add_child(sunlight)

static func light_workspace(trailer: Node3D) -> void:
	var overhead := trailer.get_node("PortableWorkLight") as OmniLight3D
	overhead.light_energy = .65
	overhead.light_color = Color("ffe4bf")
	overhead.light_specular = .35
	# The nearby point source produced a second, jagged wall silhouette.
	# Rebalance the existing lamp instead of adding another light or map.
	overhead.shadow_enabled = false
	for side in [-1, 1]:
		var point := Vector3(side * .72, 2.30, -1.05)
		G.box(trailer, "WorktopLightFixture", point, Vector3(.10, .035, .8), Color("eadac1"), false)
		var task := OmniLight3D.new()
		task.name = "WarmWorktopLight"
		task.position = point - Vector3(0, .08, 0)
		task.light_color = Color("ffe4bc")
		task.light_energy = .22
		task.light_specular = .25
		task.omni_range = 1.8
		trailer.add_child(task)

static func update_lighting(parent: Node3D, clock: float) -> void:
	# Follow the existing saved clock; menus and loads keep the same time of day.
	var hour := fmod(clock / 3600.0, 24.0)
	var day := minf(smoothstep(6.0, 9.0, hour), 1.0 - smoothstep(16.0, 21.0, hour))
	var env: Environment = parent.get_node("OutdoorEnvironment").environment
	env.background_color = Color("77899d").lerp(Color("becdd3"), day)
	env.ambient_light_color = Color("c3cbd9").lerp(Color("dae2e4"), day)
	env.ambient_light_energy = lerpf(.34, .42, day)
	var sun := parent.get_node("Daylight") as DirectionalLight3D
	sun.light_energy = lerpf(.06, .62, day)
	sun.light_color = Color("ffd0a3").lerp(Color("fff0d5"), day)
	sun.rotation_degrees.x = lerpf(-12.0, -45.0, day)
	for lamp in parent.get_tree().get_nodes_in_group("street_lamps"):
		if parent.is_ancestor_of(lamp): lamp.light_energy = 1.1 * (1.0 - day)

static func _tree(parent: Node3D, point: Vector3) -> void:
	G.cylinder(parent, "Trunk", point + Vector3(0, 1.2, 0), .16, 2.4, Color("7b6e50"))
	for i in range(3):
		var crown := G.cylinder(parent, "Crown", point + Vector3(0, 2.1 + .5 * i, 0), 1.15 - i * .24, 1.3, Color("7e925f"), false)
		(crown.get_child(0).mesh as CylinderMesh).radial_segments = 7
		(crown.get_child(0).mesh as CylinderMesh).top_radius *= .55

static func _lamp(parent: Node3D, point: Vector3) -> void:
	G.cylinder(parent, "LampPost", point + Vector3(0, 1.65, 0), .045, 3.3, Color("48605a"))
	G.box(parent, "Lantern", point + Vector3(0, 3.35, 0), Vector3(.3, .35, .3), Color("e2d3a6"), false)
	var lamp := OmniLight3D.new()
	lamp.name = "StreetLamp"
	lamp.position = point + Vector3(0, 3.15, 0)
	lamp.light_color = Color("ffdbab")
	lamp.light_energy = 0.0
	lamp.omni_range = 5.5
	parent.add_child(lamp)
	lamp.add_to_group("street_lamps")

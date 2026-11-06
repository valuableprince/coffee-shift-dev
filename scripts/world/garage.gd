extends Node3D
## Independent rented workshop graybox, 10.5 x 12 x 4.2 m (prototype layout).

const G := preload("res://scripts/prototype/prototype_geometry.gd")

func _ready() -> void:
	_shell()
	_furniture()
	_lighting()
	_restoration_supplies()

func _shell() -> void:
	G.box(self, "ConcreteFloor", Vector3(0, -0.15, 0), Vector3(10.5, 0.3, 12), Color("666b61"))
	G.box(self, "Ceiling", Vector3(0, 4.3, 0), Vector3(10.7, 0.2, 12.2), Color("7d7d6c"))
	for x in [-5.35, 5.35]:
		G.box(self, "Wall", Vector3(x, 2.1, 0), Vector3(0.2, 4.2, 12.2), Color("aba58c"))
		G.box(self, "PaintedWallBase", Vector3(x * 0.979, 0.7, 0), Vector3(0.015, 1.4, 12), Color("627064"), false)
	G.box(self, "RearWall", Vector3(0, 2.1, 6.1), Vector3(10.7, 4.2, 0.2), Color("aaa48c"))
	G.box(self, "GateLeftPier", Vector3(-3.77, 2.1, -6.1), Vector3(2.76, 4.2, 0.2), Color("aaa48c"))
	G.box(self, "GateRightPier", Vector3(3.77, 2.1, -6.1), Vector3(2.76, 4.2, 0.2), Color("aaa48c"))
	G.box(self, "GateHeader", Vector3(0, 3.85, -6.1), Vector3(4.8, 0.7, 0.2), Color("aaa48c"))
	for x in [-1.2, 1.2]:
		G.box(self, "SteelGate", Vector3(x, 1.30, -6.06), Vector3(2.38, 2.6, 0.14), Color("4e686a"), true, 0.15)
		# Clerestory openings admit daylight above the closed lower gate leaves.
		G.box(self, "GateWindowFrame", Vector3(x, 2.65, -6.06), Vector3(2.38, .10, .14), Color("344e50"), false)
		G.box(self, "GateWindowMullion", Vector3(x, 3.1, -6.06), Vector3(.06, .8, .14), Color("344e50"), false)
		for dx in [-0.95, 0.95]:
			G.box(self, "GateReinforcement", Vector3(x + dx, 1.75, -5.97), Vector3(0.05, 3.35, 0.05), Color("344e50"), false)
	for z in [-4.5, 0, 4.5]:
		G.box(self, "CeilingBeam", Vector3(0, 4.03, z), Vector3(10.5, 0.22, 0.16), Color("595f54"))
	# Concrete joints and dry stains; no danger/decay beyond an ordinary workshop.
	for z in [-3.5, 0, 3.5]:
		G.box(self, "FloorJoint", Vector3(0, 0.001, z), Vector3(10.45, 0.002, 0.018), Color("50594f"), false)
	G.box(self, "OldOilMark", Vector3(-3.3, 0.002, -1.8), Vector3(0.65, 0.002, 0.9), Color("575c50"), false)

func _furniture() -> void:
	# Workbench is adjacent to the service side, with an unobstructed approach.
	G.box(self, "WorkbenchTop", Vector3(4.35, 0.92, -0.7), Vector3(1.25, 0.12, 2.8), Color("8b7754"))
	for z in [-1.85, 0.45]:
		for x in [3.9, 4.8]:
			G.box(self, "WorkbenchLeg", Vector3(x, 0.43, z), Vector3(0.09, 0.86, 0.09), Color("44544a"))
	G.box(self, "ToolBoard", Vector3(5.19, 1.95, -0.8), Vector3(0.06, 1.25, 2.9), Color("7f755c"))
	G.box(self, "Toolbox", Vector3(4.36, 1.13, -1.65), Vector3(0.62, 0.3, 0.45), Color("745348"))
	G.box(self, "Radio", Vector3(4.62, 1.13, 0.35), Vector3(0.32, 0.30, 0.46), Color("575c4f"))
	G.box(self, "RadioDial", Vector3(4.45, 1.14, 0.35), Vector3(0.012, 0.09, 0.32), Color("b7ae7b"), false)
	for z in [-3.8, 2.7]:
		G.box(self, "ShelfBack", Vector3(-4.8, 1.25, z), Vector3(0.12, 2.5, 1.9), Color("4c5a50"))
		for y in [0.18, 0.95, 1.72, 2.45]:
			G.box(self, "Shelf", Vector3(-4.48, y, z), Vector3(0.72, 0.08, 1.9), Color("757b65"))
		for dz in [-0.6, 0, 0.58]:
			G.cylinder(self, "PaintTin", Vector3(-4.4, 1.15, z + dz), 0.15, 0.32, Color("9a9473"))
		G.box(self, "CardboardBox", Vector3(-4.4, 1.98, z + 0.2), Vector3(0.53, 0.44, 0.6), Color("9f8a5e"))
	G.cylinder(self, "Bucket", Vector3(3.95, 0.20, 1.0), 0.20, 0.4, Color("737e72"))
	G.box(self, "SpareTimber", Vector3(-3.9, 0.10, 0), Vector3(0.34, 0.20, 2.5), Color("9a845d"))
	G.box(self, "Stool", Vector3(3.7, 0.46, 2.3), Vector3(0.42, 0.08, 0.42), Color("857354"))
	for x in [3.54, 3.86]:
		G.box(self, "StoolLeg", Vector3(x, 0.22, 2.3), Vector3(0.06, 0.44, 0.32), Color("5a6253"))
	G.sign_text(self, "МАСТЕРСКАЯ\nПОСЛЕ РАБОТЫ УБЕРИ ИНСТРУМЕНТ", Vector3(0, 2.8, 5.97), Vector3(0, PI, 0), 34)
	G.sign_text(self, "ПЛАН РАБОТ\nОсмотр · Уборка · Подготовка", Vector3(-2.7, 1.7, 5.97), Vector3(0, PI, 0), 26)

func _lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("bbcbd2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce3e4")
	environment.ambient_light_energy = 0.46
	world.environment = environment
	add_child(world)
	for z in [-3.5, 0, 3.5]:
		G.box(self, "FluorescentFixture", Vector3(0, 3.94, z), Vector3(2.0, 0.08, 0.3), Color("d6d6bb"), false)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 3.65, z)
		lamp.light_color = Color("f1ebda")
		lamp.light_energy = 1.2
		lamp.omni_range = 7.0
		lamp.shadow_enabled = is_zero_approx(float(z))
		lamp.shadow_opacity = .35
		add_child(lamp)
	var daylight := SpotLight3D.new()
	daylight.name = "GateDaylight"
	daylight.position = Vector3(0, 3.14, -5.95)
	daylight.rotation_degrees = Vector3(-22, 180, 0)
	daylight.light_color = Color("dceaf3")
	daylight.light_energy = 1.15
	daylight.spot_range = 11.0
	daylight.spot_angle = 65.0
	daylight.shadow_enabled = true
	daylight.shadow_opacity = .30
	add_child(daylight)
	var task_lamp := OmniLight3D.new()
	task_lamp.position = Vector3(3.7, 2.5, -0.6)
	task_lamp.light_color = Color("ffdd9f")
	task_lamp.light_energy = 1.2
	task_lamp.omni_range = 4.0
	add_child(task_lamp)
	G.box(self, "TaskLampShade", Vector3(3.7, 2.57, -.6), Vector3(.30, .08, .20), Color("627064"), false)

func _restoration_supplies() -> void:
	var ids := ["brush", "scraper", "screwdriver", "wrench", "roller"]
	for i in range(ids.size()):
		var pickup := WorkshopPickup.new()
		pickup.tool_id = StringName(ids[i])
		pickup.name = "Tool_" + ids[i]
		pickup.position = [Vector3(3.96,1.12,-1.8),Vector3(3.96,1.12,-1.2),Vector3(3.96,1.12,.02),Vector3(3.96,1.12,.6),Vector3(5.05,1.9,-1.2)][i]
		_build_pickup(pickup, false)
		ToolVisual.build(pickup,pickup.tool_id)
	for data in RestorationCatalog.data().sources:
		var pickup := WorkshopPickup.new()
		pickup.tool_id = &""
		pickup.material_id = data.material
		pickup.source_id = data.id
		pickup.title = data.title
		pickup.amount = int(data.amount)
		pickup.name = data.id
		pickup.position = RestorationCatalog.vector(data.position)
		_build_pickup(pickup, true)
		G.box(pickup,"Package",Vector3.ZERO,Vector3(.24,.22,.29),Color("a8976d"),false)

func _build_pickup(pickup: WorkshopPickup, _on_shelf: bool) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.26,.30,.28)
	collision.shape = shape
	pickup.add_child(collision)
	add_child(pickup)


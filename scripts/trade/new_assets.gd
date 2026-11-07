class_name ShiftNewAssets
extends Node3D
## Scene adapters for the original GLBs. Trade rules stay in CoffeeShiftSession.
const CUP := preload("res://assets/models/takeaway_cup/cup.tscn")
const LID := preload("res://assets/models/takeaway_cup/lid.tscn")
const CAPPED_CUP := preload("res://assets/models/takeaway_cup/cup_with_lid.tscn")
const BASE := preload("res://assets/models/cabinets/base_cabinet.tscn")
const WALL := preload("res://assets/models/cabinets/wall_cabinet.tscn")
const REGISTER := preload("res://assets/models/cash_register/cash_register.tscn")
const G := preload("res://scripts/prototype/prototype_geometry.gd")
var world: Node3D
var cabinets: Dictionary = {}
var register: CoffeeShiftCashRegister
var cup_stack: Node3D
var lid_stack: Node3D
var sink: CoffeeShiftSinkMixer
var _restoring_sink := false

func configure(owner_world: Node3D) -> void:
	world = owner_world
	name = "NewAssets"
	# Replace only the five existing cabinet envelopes. Worktops stay intact.
	for old in world.trailer.get_children():
		if str(old.name).begins_with("OppositeCabinets") or str(old.name).begins_with("PreparationCabinet") or old.name == "ServingBase":
			old.free()
	# Fit cabinet depth under the existing tops, including protruding handles.
	# Closed handle-to-handle clearance stays above the approved 0.95 m aisle.
	_cabinet("BaseOppositeFront", Vector3(-.585,.4,-1.16), PI/2, Vector3(1.31/1.08,.84/.82,.925))
	_cabinet("BaseOppositeRear", Vector3(-.585,.4,1.04), PI/2, Vector3(1.55/1.08,.84/.82,.925))
	_cabinet("BasePreparationFront", Vector3(.585,.4,-1.4), -PI/2, Vector3(1,.84/.82,.925))
	_cabinet("BasePreparationRear", Vector3(.585,.4,1.4), -PI/2, Vector3(1,.84/.82,.925))
	_cabinet("BaseServing", Vector3(.585,.4,0), -PI/2, Vector3(1.58/1.08,.74/.82,.925))
	# Bottom raised to 1.70 m to clear the existing syrup bottle (top 1.62).
	# Move 40 mm inward so the back/top clears the original roof's curved shoulder.
	# Height and lengthwise positions stay fixed; the staff aisle stays clear.
	for z in [.55,1.55]:
		_cabinet("WallFront" if z < 1 else "WallRear", Vector3(-.77,1.70,z), PI/2, Vector3.ONE, true)
	register = REGISTER.instantiate()
	register.name = "CashRegister"
	register.crosshair_interaction_enabled = false
	register.position = Vector3(.80,1.3005,1.38)
	register.rotation.y = -PI/2
	add_child(register)
	for target in [register.get_node("BodyInteraction"), register.get_node("DrawerAssembly/DrawerInteraction")]:
		# Put the target's origin at the actual surface, also used by the ray tests.
		var shape: CollisionShape3D = target.get_node("Shape")
		target.position = shape.position
		shape.position = Vector3.ZERO
		target.world = world
		target.action = "cash"
		target.caption = "Кассовый аппарат"
		target.set_meta("action", "cash")
	register.drawer_state_changed.connect(func(_opened: bool) -> void: _checkpoint("Денежный ящик"))
	# Original sink/lever asset from PR #76, not a procedural placeholder.
	sink = ShiftSinkInstallation.install(world.trailer)
	if sink != null:
		# The rear base cabinet has its own upper shelf under the old solid top.
		# Clear that visual/physical slab before using the recessed sink basin.
		ShiftSinkInstallation.open_cabinet_beneath_bowl(cabinets["BaseOppositeRear"])
		sink.faucet_state_changed.connect(func(_opened: bool) -> void:
			if not _restoring_sink: _checkpoint("Рычаг смесителя"))

func _cabinet(id: String, point: Vector3, yaw: float, fit: Vector3, wall: bool = false) -> void:
	var cabinet: CoffeeShiftCabinet = (WALL if wall else BASE).instantiate()
	cabinet.name = id
	cabinet.position = point
	cabinet.rotation.y = yaw
	cabinet.allow_first_person_interaction = false
	add_child(cabinet)
	# Fit mesh instances and jamb positions, keeping hinge bases unscaled.
	# A nonuniform scale above a rotating hinge would skew its opening angle.
	cabinet.get_node("BodyVisual").scale = fit
	for hinge_name in ["LeftHinge","RightHinge"]:
		var hinge: Node3D = cabinet.get_node(hinge_name)
		hinge.position *= fit
		hinge.get_node("DoorVisual").scale = fit
		var target_shape: CollisionShape3D = hinge.get_node("DoorInteractable/Shape")
		target_shape.position *= fit
		target_shape.scale = fit
	cabinets[id] = cabinet
	# Hollow shell collision leaves the actual interior accessible to the ray.
	var body: StaticBody3D = cabinet.get_node("BodyCollider")
	body.get_node("Shape").free()
	var width := .96 if wall else 1.08
	var height := .60 if wall else .82
	var depth := .33 if wall else .60
	for side in [-1,1]:
		_shape(body, Vector3(side*(width/2-.009),height/2,-depth/2)*fit, Vector3(.018,height,depth)*fit)
	_shape(body, Vector3(0,height/2,-depth+.009)*fit, Vector3(width-.036,height,.018)*fit)
	for y in ([.009,.30,.591] if wall else [.105,.44,.811]):
		_shape(body, Vector3(0,y,-depth/2)*fit, Vector3(width-.036,.018,depth-.018)*fit)
	cabinet.door_state_changed.connect(func(_side: StringName, _opened: bool) -> void: _checkpoint("Дверца шкафчика"))

func _shape(body: StaticBody3D, point: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = point
	body.add_child(collision)

func _checkpoint(reason: String) -> void:
	if world.save_manager != null: world.save_manager.mark_checkpoint(reason)

func _disable_bodies(model: Node3D) -> void:
	for body in model.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0

func cup(parent: Node3D, id: String, contact: Vector3, capped: bool = false, occludes: bool = false) -> Node3D:
	var model: Node3D = (CAPPED_CUP if capped else CUP).instantiate()
	model.name = id
	# The source's lowest mesh vertex is 3 mm above its origin.
	model.position = contact - Vector3.UP * .003
	model.rotation.y = -PI/2
	parent.add_child(model)
	_disable_bodies(model)
	if occludes:
		for body in model.find_children("*","StaticBody3D",true,false): body.collision_layer = 2
	return model

func build_stock() -> void:
	cup_stack = Node3D.new()
	cup_stack.name = "CupStock"
	add_child(cup_stack)
	lid_stack = Node3D.new()
	lid_stack.name = "LidStock"
	add_child(lid_stack)
	for i in range(4):
		cup(cup_stack, "Cup%d" % i, Vector3(-.78,1.30+i*.018,.62))
		var lid: Node3D = LID.instantiate()
		lid.position = Vector3(-.78,1.307+i*.011,.85)
		lid.rotation.y = -PI/2
		lid_stack.add_child(lid)
		_disable_bodies(lid)
	# Existing E targets cover the visible stock rather than an empty aisle.
	world.stations.cups.position = Vector3(-.78,1.395,.62)
	(world.stations.cups.get_child(0).shape as BoxShape3D).size = Vector3(.09,.19,.09)
	world.stations.cups.caption = "Стаканчик"
	world.stations.lids.position = Vector3(-.78,1.326,.85)
	(world.stations.lids.get_child(0).shape as BoxShape3D).size = Vector3(.096,.07,.096)
	world.stations.lids.caption = "Крышка"

# Placement on the existing left worktop, away from the grinder and the
# stock stacks. Coordinates are relative to the original trailer scene.
const COUNTERTOP_CUP_POINT := Vector3(-.78, 1.315, -.50)


func _fill_cup(model: Node3D, parent: Node3D, point: Vector3, amount: float, extract_stream: bool) -> void:
	if amount <= 0.0: return
	var fill := lerpf(.014, .095, clampf(amount / 350.0, 0.0, 1.0))
	var radius := lerpf(.030, .040, clampf(fill / .114, 0.0, 1.0))
	G.cylinder(model, "CoffeeSurface", Vector3(0, fill, 0), radius, .0015, Color("554231"), false)
	if extract_stream:
		var nozzle: Vector3 = world.trailer.to_local(world.machine_visual.spout())
		var surface: Vector3 = point + Vector3.UP * (fill - .003)
		G.cylinder(parent, "CoffeeStream", (nozzle + surface) / 2.0, .003, maxf(.001, nozzle.y - surface.y), Color("74553b"), false)


func preparation(parent: Node3D, hand: Node3D) -> void:
	var current: Dictionary = world.session.preparation.current
	if current.is_empty(): return
	var sequence: Array = world.session.catalog.steps(current.item)
	var index := int(current.step)
	var stage := str(current.get("handling", ""))
	var cup_index := sequence.find("cup")
	if stage == "cup_held":
		cup(hand, "HeldEmptyCup", Vector3(-.025, -.105, -.055))
		return
	if index <= cup_index: return
	var amount := float(current.consumed.get("water", 0))
	if "pour" in sequence and index > sequence.find("pour"):
		amount += float(current.consumed.get("milk", 0))
	if stage == "cup_full_held":
		var handheld := cup(hand, "HeldFilledCup", Vector3(-.025, -.105, -.055))
		_fill_cup(handheld, hand, Vector3.ZERO, amount, false)
		return
	if stage in ["cup_on_counter", "lid_held", "lid_attached"]:
		var capped := stage == "lid_attached"
		var cup_on_worktop := cup(parent, "CappedCupOnCounter" if capped else "CupOnCounter", COUNTERTOP_CUP_POINT, capped)
		if not capped: _fill_cup(cup_on_worktop, parent, COUNTERTOP_CUP_POINT, amount, false)
		if stage == "lid_held":
			var lid: Node3D = LID.instantiate()
			lid.name = "HeldLid"
			lid.position = Vector3(-.03, -.08, -.065)
			hand.add_child(lid)
			_disable_bodies(lid)
		return
	# Legacy saved in-progress cups without a handling field stay compatible,
	# and the ordinary running recipe remains on the machine's drip tray.
	var lid_done := index > sequence.find("lid")
	if lid_done:
		cup(hand, "CupWithLid", Vector3(0, -.06, 0), true)
		return
	var base: Vector3 = world.trailer.to_local(world.machine_visual.cup_base())
	var model := cup(parent, "CupUnderGroup", base, false, true)
	_fill_cup(model, parent, base, amount if index > sequence.find("extract") else 0.0, current.running == "extract")

func sync_register() -> void:
	var payment: Dictionary = world.session.cash.payment
	var selected: Dictionary = world.session.order_by_id(world.session.selected_order)
	register.set_display_value(float(payment.get("total",selected.get("total",0))))

func snapshot() -> Dictionary:
	var doors := {}
	for id in cabinets:
		var cabinet: CoffeeShiftCabinet = cabinets[id]
		doors[id] = {"left":cabinet.left_open,"right":cabinet.right_open}
	return {"doors":doors,"drawer_open":register.drawer_open,"faucet_on":sink.faucet_on if sink != null else false}

func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not data.get("drawer_open") is bool or not data.get("doors") is Dictionary: return false
	if data.has("faucet_on") and not data.faucet_on is bool: return false
	for id in data.doors:
		if not id in cabinets or not data.doors[id] is Dictionary: return false
		for side in ["left","right"]:
			if not data.doors[id].get(side) is bool: return false
	return true

func restore(data: Dictionary = {}) -> void:
	for id in cabinets:
		for side in ["left","right"]:
			cabinets[id].set_door_open(StringName(side),bool(data.get("doors",{}).get(id,{}).get(side,false)),false)
	register.set_drawer_open(bool(data.get("drawer_open",not world.session.cash.payment.is_empty())),false)
	_restoring_sink = true
	if sink != null: sink.set_faucet_on(bool(data.get("faucet_on",false)),false)
	_restoring_sink = false
	sync_register()

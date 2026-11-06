class_name EquipmentInspection
extends Node3D
## Presentation transaction: only natural AnimationPlayer completion commits.
## Animations use surface-space contacts so the hand follows the real fridge handle.
signal finished(device: String, completed: bool)
const CLIPS := {
	"machine": preload("res://assets/animations/inspection/machine.tres"),
	"grinder": preload("res://assets/animations/inspection/grinder.tres"),
	"fridge": preload("res://assets/animations/inspection/fridge.tres"),
	"cash": preload("res://assets/animations/inspection/cash.tres")
}
var world: ShiftWorld
var animation: AnimationPlayer
var hand: Node3D
var busy := false
var device := ""
var reach := 0.0
var press := 0.0
var grip := 0.0
var sweep := 0.0
var door_fraction := 0.0
var _fridge_was_open := false
var _cue_index := 0

func configure(owner_world: ShiftWorld) -> void:
	world = owner_world
	name = "EquipmentInspection"
	hand = Node3D.new()
	hand.name = "InspectionHand"
	add_child(hand)
	BaristaHand.build(hand)
	hand.hide()
	animation = AnimationPlayer.new()
	animation.name = "AnimationPlayer"
	add_child(animation)
	var library := AnimationLibrary.new()
	for key in CLIPS: library.add_animation(key, CLIPS[key])
	animation.add_animation_library("", library)
	animation.animation_finished.connect(_animation_finished)

func start(id: String) -> bool:
	if busy or not CLIPS.has(id) or not world._active or world.session.shift_open or world.session.equipment[id]: return false
	if not world.player.controls_enabled or not world.player.mouse_captured: return false
	if world.main_menu.visible or world.save_menu.visible or world.hud.panel.visible or world._orders_editing: return false
	if world.accessories.inspected != "": return false
	device = id
	_fridge_was_open = world.fridge.opened
	busy = true
	reach = 0
	press = 0
	grip = 0
	sweep = 0
	door_fraction = 0
	_cue_index = 0
	world.player.controls_enabled = false
	world.player.velocity = Vector3.ZERO
	if id == "fridge":
		world.fridge.restore_opened(_fridge_was_open)
		world.fridge.moving = true
	world.hud.hint.text = ""
	hand.show()
	animation.play(id)
	animation.advance(0)
	_update_pose()
	return true

func _process(_delta: float) -> void:
	if not busy: return
	if not world._active or world.main_menu.visible or world.save_menu.visible or world.hud.panel.visible or not animation.is_playing():
		cancel()
		return
	_update_pose()
	var times: Array = {"machine":[.43], "grinder":[.43], "fridge":[.32,1.06], "cash":[.40,.68]}[device]
	if _cue_index < times.size() and animation.current_animation_position >= float(times[_cue_index]):
		world.audio.play_event(str({"machine":"machine", "grinder":"paper", "fridge":"window", "cash":"cash"}[device]))
		_cue_index += 1

func contact_frame() -> Transform3D:
	var point: Vector3
	var normal: Vector3
	match device:
		"machine":
			point = world.machine_visual.control_point("power")
			normal = world.machine_visual.global_basis.z.normalized()
		"grinder":
			var model: Node3D = world.grinder_visual.get_node("CoffeeGrinder")
			point = model.to_global(Vector3(.02 + sweep * .035,.72,.128))
			normal = model.global_basis.z.normalized()
		"cash":
			var register := world.new_assets.register
			# Keypad slopes upward toward the display. Contact stays above the keys.
			point = register.to_global(Vector3(-.025 + sweep * .048,.147,.107))
			normal = (register.global_basis * Vector3(0,.86,.51)).normalized()
		_:
			point = world.fridge.hinge.to_global(Vector3(.066,.16,-.52))
			normal = world.fridge.hinge.global_basis.x.normalized()
	var x_axis := Vector3.UP.cross(normal).normalized()
	var y_axis := normal.cross(x_axis).normalized()
	return Transform3D(Basis(x_axis,y_axis,normal), point)

func _update_pose() -> void:
	reach = clampf(reach,0,1)
	press = clampf(press,0,1)
	grip = clampf(grip,0,1)
	door_fraction = clampf(door_fraction,0,1)
	if device == "fridge":
		var fraction := door_fraction
		if _fridge_was_open and animation.current_animation_position < .86: fraction = 1
		# A 60-degree opening exposes the milk and keeps the handle inside view.
		var angle := ShiftFridge.OPEN_ANGLE if _fridge_was_open else deg_to_rad(60)
		world.fridge.hinge.rotation.y = -angle * fraction
		world.fridge.get_node("InteriorLight").visible = fraction > .1
	var contact := contact_frame()
	# Fingertip meets the outside surface; the hand and sleeve stay on the aisle side.
	var clearance := .100 if device in ["machine","cash"] else .058
	var touch := contact.origin + contact.basis.z * (clearance - press * .006)
	var rest: Vector3 = world.player.camera.to_global(Vector3(.23,-.40,-.30))
	hand.global_basis = world.player.camera.global_basis.slerp(contact.basis, reach)
	hand.global_position = rest.lerp(touch, reach)
	for i in range(4):
		var finger: Node3D = hand.get_node("Finger%d" % i)
		var pointing := device in ["machine","cash"] and i == 0
		finger.rotation.x = lerpf(-.2,-1.15,grip) if not pointing else -PI/2
		finger.position.z = -.070 if pointing else -.021 - .02 * grip
		finger.position.x = -.040 if pointing else -.027 + float(i) * .018
		finger.position.y = -.025 if pointing else -.014
	# Stretch the original sleeve back toward the shoulder, below the camera.
	var sleeve: Node3D = hand.get_node("Sleeve")
	var wrist := hand.to_global(Vector3(.015,-.07,.10))
	var shoulder := world.player.camera.to_global(Vector3(.32,-.60,.06))
	sleeve.global_position = (wrist + shoulder) * .5
	sleeve.global_basis = Basis.looking_at((wrist - shoulder).normalized(), Vector3.UP)
	sleeve.scale = Vector3(.65,.75,maxf(.22,wrist.distance_to(shoulder))/.22)

func saved_fridge_opened() -> bool:
	return _fridge_was_open if busy and device == "fridge" else world.fridge.opened

func _animation_finished(clip: StringName) -> void:
	if not busy or str(clip) != device: return
	var id := device
	_cleanup(true)
	var committed := world.session.prepare_equipment(id)
	finished.emit(id, committed)

func cancel() -> void:
	if not busy: return
	var id := device
	_cleanup(false)
	finished.emit(id, false)

func _cleanup(completed: bool) -> void:
	animation.stop()
	hand.hide()
	if device == "fridge": world.fridge.restore_opened(false if completed else _fridge_was_open)
	busy = false
	device = ""
	world._resume_controls()

func _exit_tree() -> void:
	if busy:
		animation.stop()
		hand.hide()
		busy = false

class_name EquipmentInspection
extends Node3D
## Presentation transaction: only natural AnimationPlayer completion commits.
## Animations use surface-space contacts so the hand follows the real fridge handle.
signal finished(device: String, completed: bool)
const UPPER_ARM := .30
const FOREARM := .26
const WRIST_ATTACH := Vector3(.015,-.07,.10)
const CLIPS := {
	"machine": preload("res://assets/animations/inspection/machine.tres"),
	"grinder": preload("res://assets/animations/inspection/grinder.tres"),
	"fridge": preload("res://assets/animations/inspection/fridge.tres"),
	"cash": preload("res://assets/animations/inspection/cash.tres")
}
var world: ShiftWorld
var animation: AnimationPlayer
var hand: Node3D
var upper_arm: Node3D
var elbow_joint: Node3D
var shoulder_point := Vector3.ZERO
var elbow_point := Vector3.ZERO
var wrist_point := Vector3.ZERO
var _camera_home := Vector3.ZERO
var _camera_rotation := Vector3.ZERO
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
	# Inspection uses a bent, metre-scale arm; garage tool geometry is untouched.
	var forearm_mesh := CylinderMesh.new()
	forearm_mesh.height = FOREARM
	forearm_mesh.top_radius = .033
	forearm_mesh.bottom_radius = .043
	forearm_mesh.radial_segments = 8
	(hand.get_node("Sleeve/Mesh") as MeshInstance3D).mesh = forearm_mesh
	upper_arm = PrototypeGeometry.cylinder(hand,"UpperArm",Vector3.ZERO,.046,UPPER_ARM,Color("4b645e"),false)
	(upper_arm.get_child(0).mesh as CylinderMesh).radial_segments = 8
	elbow_joint = Node3D.new()
	hand.add_child(elbow_joint)
	var elbow_mesh := MeshInstance3D.new()
	var joint_shape := SphereMesh.new()
	joint_shape.radius = .043
	joint_shape.height = .086
	joint_shape.radial_segments = 8
	joint_shape.rings = 4
	elbow_mesh.mesh = joint_shape
	elbow_mesh.material_override = PrototypeGeometry.material(Color("4b645e"))
	elbow_joint.add_child(elbow_mesh)
	for mesh in hand.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	if not can_reach(id): return false
	device = id
	_camera_home = world.player.camera.position
	_camera_rotation = world.player.camera.rotation
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
	return busy

func _process(_delta: float) -> void:
	if not busy: return
	if not world._active or world.main_menu.visible or world.save_menu.visible or world.hud.panel.visible or not animation.is_playing():
		cancel()
		return
	_update_pose()
	if not busy: return
	var times: Array = {"machine":[.43], "grinder":[.43], "fridge":[.32,1.06], "cash":[.40,.68]}[device]
	if _cue_index < times.size() and animation.current_animation_position >= float(times[_cue_index]):
		world.audio.play_event(str({"machine":"machine", "grinder":"paper", "fridge":"window", "cash":"cash"}[device]))
		_cue_index += 1

func contact_frame(id: String = "", fridge_angle: float = INF) -> Transform3D:
	if id == "": id = device
	var point: Vector3
	var normal: Vector3
	match id:
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
			var hinge_frame := world.fridge.hinge.global_transform
			if is_finite(fridge_angle):
				hinge_frame = world.fridge.global_transform * Transform3D(Basis(Vector3.UP,fridge_angle),world.fridge.hinge.position)
			point = hinge_frame * Vector3(.066,.16,-.52)
			normal = hinge_frame.basis.x.normalized()
	var x_axis := Vector3.UP.cross(normal).normalized()
	var y_axis := normal.cross(x_axis).normalized()
	return Transform3D(Basis(x_axis,y_axis,normal), point)

func _shoulder(id: String, amount: float, contact: Vector3 = Vector3.INF) -> Vector3:
	# Shoulder belongs to the body, so looking down cannot stretch the arm.
	var point := world.player.to_global(Vector3(-.16 if id == "fridge" else .16,1.43 - (.67 * amount if id == "fridge" else 0.0),-.12 * amount))
	if id == "fridge" and contact.is_finite():
		var lean := contact - point
		lean.y = 0
		point += lean.normalized() * .08 * amount
	return point

func _wrist_attach(id: String) -> Vector3:
	return Vector3(-WRIST_ATTACH.x if id == "fridge" else WRIST_ATTACH.x,WRIST_ATTACH.y,WRIST_ATTACH.z)

func can_reach(id: String) -> bool:
	var angles: Array = [INF]
	if id == "fridge": angles = [0.0,-deg_to_rad(30),-deg_to_rad(60),-ShiftFridge.OPEN_ANGLE] if world.fridge.opened else [0.0,-deg_to_rad(30),-deg_to_rad(60)]
	for angle in angles:
		var contact := contact_frame(id,angle)
		var clearance := .100 if id in ["machine","cash"] else .058
		var wrist := contact * (_wrist_attach(id) + Vector3(0,0,clearance))
		if wrist.distance_to(_shoulder(id,1,wrist)) > UPPER_ARM + FOREARM - .01: return false
	return true

func _align_segment(segment: Node3D, start_point: Vector3, end_point: Vector3) -> void:
	var y_axis := (end_point - start_point).normalized()
	var x_axis := world.player.global_basis.z.cross(y_axis).normalized()
	if x_axis.length_squared() < .01: x_axis = Vector3.RIGHT
	segment.global_transform = Transform3D(Basis(x_axis,y_axis,x_axis.cross(y_axis).normalized()),(start_point+end_point)*.5)

func _pose_arm() -> bool:
	wrist_point = hand.to_global(_wrist_attach(device))
	# FPS view-model attachment stays below the frame. World-space reach is
	# checked separately against the body, while both visible bones stay rigid.
	var side := -1.0 if device == "fridge" else 1.0
	var shoulder_x := clampf(world.player.camera.to_local(wrist_point).x,-.28,-.04) if device == "fridge" else .12
	shoulder_point = world.player.camera.to_global(Vector3(shoulder_x,-.30,-.25))
	var offset := wrist_point - shoulder_point
	var distance := offset.length()
	if not is_finite(distance) or distance < .0001: return false
	# The camera/view-model shoulder is a presentation anchor, not the physical
	# shoulder used by can_reach(). During the fridge door swing the world-space
	# handle can move beyond that temporary camera anchor by more than the arm
	# length. Re-anchor the visible shoulder instead of cancelling a valid
	# inspection mid-animation. Physical reach was already checked at start().
	var maximum_span := UPPER_ARM + FOREARM - .001
	if distance > maximum_span:
		shoulder_point += offset / distance * (distance - maximum_span)
		offset = wrist_point - shoulder_point
		distance = offset.length()
	var span := clampf(distance,absf(UPPER_ARM-FOREARM)+.001,maximum_span)
	var axis := offset.normalized()
	var pole := world.player.camera.global_basis * Vector3(.8 * side,-.6,0)
	pole = (pole - axis * pole.dot(axis)).normalized()
	if pole.length_squared() < .01: pole = world.player.global_basis.z
	var along := (UPPER_ARM*UPPER_ARM - FOREARM*FOREARM + span*span) / (2*span)
	var bend := sqrt(maxf(0,UPPER_ARM*UPPER_ARM - along*along))
	elbow_point = shoulder_point + axis * along + pole * bend
	_align_segment(upper_arm,shoulder_point,elbow_point)
	_align_segment(hand.get_node("Sleeve"),elbow_point,wrist_point)
	elbow_joint.global_position = elbow_point
	return true

func _update_pose() -> void:
	reach = clampf(reach,0,1)
	press = clampf(press,0,1)
	grip = clampf(grip,0,1)
	door_fraction = clampf(door_fraction,0,1)
	# Step the viewpoint back for the door's outward swing and keep the grip
	# inside the view while crouching. Other devices use a small forward lean.
	world.player.camera.position = _camera_home + Vector3(0,-.54 * reach if device == "fridge" else 0.0,(.10 if device == "fridge" else -.12) * reach)
	world.player.camera.rotation = _camera_rotation + (Vector3(.10,.30,0) * reach if device == "fridge" else Vector3.ZERO)
	if device == "fridge" and _fridge_was_open:
		# When starting at the swung-out handle, turn toward the fridge for the
		# closing push rather than continuing to stare at the initial handle pose.
		var focus := world.fridge.to_global(Vector3(.18,.27,0))
		var looking := Basis.looking_at(focus-world.player.camera.global_position)
		var local_look := world.player.global_basis.inverse() * looking
		var home_basis := Basis.from_euler(_camera_rotation,world.player.camera.rotation_order)
		world.player.camera.quaternion = home_basis.get_rotation_quaternion().slerp(local_look.get_rotation_quaternion(),reach)
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
	var side := -1.0 if device == "fridge" else 1.0
	var rest: Vector3 = world.player.camera.to_global(Vector3(.23 * side,-.40,-.30))
	hand.global_basis = world.player.camera.global_basis.slerp(contact.basis, reach)
	hand.global_position = rest.lerp(touch, reach)
	for i in range(4):
		var finger: Node3D = hand.get_node("Finger%d" % i)
		var pointing := device in ["machine","cash"] and i == 0
		finger.rotation.x = lerpf(-.2,-1.15,grip) if not pointing else -PI/2
		finger.position.z = -.070 if pointing else -.021 - .02 * grip
		finger.position.x = (-.040 if pointing else -.027 + float(i) * .018) * side
		finger.position.y = -.025 if pointing else -.014
	hand.get_node("Wrist").position.x = .015 * side
	hand.get_node("Thumb").position.x = .045 * side
	if not _pose_arm(): cancel()

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
	world.player.camera.position = _camera_home
	world.player.camera.rotation = _camera_rotation
	if device == "fridge": world.fridge.restore_opened(false if completed else _fridge_was_open)
	busy = false
	device = ""
	world._resume_controls()

func _exit_tree() -> void:
	if busy:
		animation.stop()
		hand.hide()
		busy = false

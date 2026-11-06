class_name CoffeeShiftSinkMixer
extends Node3D
## 3D asset with a separately animated single-lever mixer.
## No water / plumbing / inventory economy is implemented here.

signal faucet_state_changed(is_on: bool)

@export var faucet_starts_on: bool = false
@export_range(0.15, 0.75, 0.05) var lever_animation_seconds: float = 0.30
@export_range(15.0, 40.0, 1.0) var lever_open_angle_degrees: float = 28.0
@export var enable_fps_input_adapter: bool = false

var faucet_on: bool = false
var _lever_tween: Tween


func _ready() -> void:
	set_faucet_on(faucet_starts_on, false)


func set_faucet_on(value: bool, animated: bool = true) -> void:
	if _lever_tween != null and _lever_tween.is_running():
		_lever_tween.kill()
	faucet_on = value
	var rotation_target: float = deg_to_rad(-lever_open_angle_degrees) if value else 0.0
	if animated and is_inside_tree():
		_lever_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_lever_tween.tween_property($LeverPivot, "rotation:x", rotation_target, lever_animation_seconds)
	else:
		$LeverPivot.rotation.x = rotation_target
	faucet_state_changed.emit(faucet_on)


func toggle_faucet() -> void:
	set_faucet_on(not faucet_on)


func get_prompt() -> String:
	return "[E] Закрыть смеситель" if faucet_on else "[E] Открыть смеситель"


func _unhandled_input(event: InputEvent) -> void:
	# Disabled by default to avoid competing with the existing game router.
	# The standalone preview uses Enter/Space and the public methods.
	if not enable_fps_input_adapter or not event.is_action_pressed("interact"):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin: Vector3 = camera.global_position
	var endpoint: Vector3 = origin - camera.global_transform.basis.z * 2.35
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, endpoint, 2)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	var target: Object = hit.get("collider")
	if target is CoffeeShiftSinkMixerTarget:
		var mixer_target: CoffeeShiftSinkMixerTarget = target as CoffeeShiftSinkMixerTarget
		if mixer_target.sink() == self:
			mixer_target.interact()
			get_viewport().set_input_as_handled()

class_name CoffeeShiftCashRegister
extends Node3D
## Asset-only presentation and interaction adapter. +Z faces the cashier.
## Currency, payment validation and inventory remain in the trade system.

signal drawer_state_changed(opened: bool)
signal display_value_changed(value: float)

@export_range(0.05, 0.24, 0.01) var drawer_travel: float = 0.17
@export_range(0.1, 1.5, 0.05) var drawer_animation_seconds: float = 0.46
@export var crosshair_interaction_enabled: bool = true
@export var starting_display_value: float = 0.0

var drawer_open: bool = false
var _tween: Tween


func _ready() -> void:
	$DrawerAssembly.position.z = 0.0
	set_display_value(starting_display_value)


func set_display_value(value: float) -> void:
	$DisplayText.text = "%.2f" % maxf(0.0, value)
	display_value_changed.emit(value)


func open_drawer() -> void:
	set_drawer_open(true)


func close_drawer() -> void:
	set_drawer_open(false)


func toggle_drawer() -> void:
	set_drawer_open(not drawer_open)


func set_drawer_open(opened: bool, animated: bool = true) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	drawer_open = opened
	var target: float = drawer_travel if opened else 0.0
	if animated and is_inside_tree():
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property($DrawerAssembly, "position:z", target, drawer_animation_seconds)
	else:
		$DrawerAssembly.position.z = target
	drawer_state_changed.emit(drawer_open)


func get_prompt() -> String:
	if $BodyInteraction.world != null: return $BodyInteraction.get_prompt()
	return "[E] Закрыть денежный ящик" if drawer_open else "[E] Открыть денежный ящик"


func interact() -> void:
	$BodyInteraction.interact()


func _unhandled_input(event: InputEvent) -> void:
	# The current DEV-03 dispatcher knows only existing interaction classes.
	# This self-contained adapter reacts only to a pointed-at cash-register
	# hitbox. A captured mouse avoids opening it while game menus are active.
	if not crosshair_interaction_enabled:
		return
	if not event.is_action_pressed("interact") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin: Vector3 = camera.global_position
	var finish: Vector3 = origin - camera.global_transform.basis.z * 2.6
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, finish, 3)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var target: Object = hit.get("collider")
	if target is CoffeeShiftCashRegisterTarget:
		var cash_target: CoffeeShiftCashRegisterTarget = target as CoffeeShiftCashRegisterTarget
		if cash_target.register() == self:
			cash_target.interact()
			get_viewport().set_input_as_handled()

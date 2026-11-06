class_name CoffeeShiftPlayer
extends CharacterBody3D
## Shared FPS controller. Actions are in project.godot (legacy also registers keys).

@export var walk_speed := 4.0
@export var run_speed := 6.3
var mouse_sensitivity := 0.0022

var camera: Camera3D
var ray: RayCast3D
var pitch := 0.0
var controls_enabled := true
var mouse_captured := false

func _ready() -> void:
	add_to_group("coffee_shift_players")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	floor_snap_length = 0.25
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.near = 0.05
	camera.fov = 75
	add_child(camera)
	camera.current = true
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3)
	ray.enabled = true
	ray.collision_mask = 3
	ray.add_exception(self)
	camera.add_child(ray)
	set_mouse_capture(true)

func set_mouse_capture(captured: bool) -> void:
	# Keep the requested input state explicit; the headless driver has no cursor.
	mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.3, 1.3)
		camera.rotation.x = pitch
	elif event.is_action_pressed("ui_cancel"):
		set_mouse_capture(false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_mouse_capture(true)

func _physics_process(delta: float) -> void:
	velocity.y = -0.2 if is_on_floor() else velocity.y - 18.0 * delta
	var axis := Vector2.ZERO
	if controls_enabled and mouse_captured:
		axis = Input.get_vector("left", "right", "forward", "back")
	var direction := global_transform.basis * Vector3(axis.x, 0, axis.y)
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

func get_interactable() -> Node3D:
	ray.force_raycast_update()
	# Resolve the first physical hit only. Never skip an occluding wall to look
	# for another object. Imported models can own several nested colliders.
	var target := ray.get_collider() as Node
	while target != null:
		if target is Node3D and target.has_method("get_prompt") and target.has_method("interact"):
			return target as Node3D if target.is_visible_in_tree() else null
		target = target.get_parent()
	return null


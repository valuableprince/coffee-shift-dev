class_name TrailerDoor
extends AnimatableBody3D
## Original GLB leaf on the established safe door controller and save path.

signal openness_changed(value: bool)

var opened := false
var moving := false
var _motion: Tween

func _ready() -> void:
	set_meta("action", "staff_door")

func get_prompt() -> String:
	return InteractionPrompt.text(get_interaction_name(), get_available_action())

func get_interaction_name() -> String:
	return "Задняя дверь"

func get_available_action() -> String:
	if moving:
		return "Открывается…" if opened else "Закрывается…"
	if opened and _closing_blocked(): return "Отойдите от проёма, чтобы закрыть дверь"
	return "[E] Закрыть" if opened else "[E] Открыть"

func interact() -> void:
	if moving or (opened and _closing_blocked()):
		return
	_animate_to(not opened)

func _physics_process(_delta: float) -> void:
	if moving and not opened and _closing_blocked():
		_animate_to(true)

func _animate_to(value: bool) -> void:
	if _motion != null:
		_motion.kill()
	opened = value
	moving = true
	# Prototype motion has no sweep collision: a player standing at the handle
	# must not be pushed off the narrow access ramp by the animated leaf.
	collision_layer = 0
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion = tween
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", deg_to_rad(-100.0) if opened else 0.0, 0.68)
	tween.finished.connect(func() -> void:
		# Check once more before re-enabling the closed leaf's collider.
		if not opened and _closing_blocked():
			_animate_to(true)
			return
		moving = false
		collision_layer = 1)
	openness_changed.emit(opened)

func _closing_blocked() -> bool:
	for player in get_tree().get_nodes_in_group("coffee_shift_players"):
		var point: Vector3 = get_parent().to_local(player.global_position)
		if absf(point.x) < .79 and absf(point.z - position.z) < .38 and point.y < 2.3:
			return true
	return false

func restore_opened(value: bool) -> void:
	if _motion != null:
		_motion.kill()
	opened = value
	moving = false
	rotation.y = deg_to_rad(-100) if value else 0.0
	collision_layer = 1


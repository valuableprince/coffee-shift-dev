class_name ShiftSaveManager
extends RestorationSaveManager
## Keeps DEV-02 files untouched. Reuses verified envelope/backup/rotation code.
var legacy_reader: RestorationSaveManager
var legacy_state: RestorationState

func _init() -> void:
	directory = "user://first_shift_v2"

func _ready() -> void:
	legacy_reader = RestorationSaveManager.new()
	legacy_reader.autosave_enabled = false
	add_child(legacy_reader)
	legacy_reader.configure(Callable(), Callable(), _validate_legacy)

func _validate_legacy(data: Dictionary) -> bool:
	# Lazy, isolated validator: reuse the actual DEV-02 rules and catalog.
	if legacy_state == null:
		legacy_state = RestorationState.new()
		add_child(legacy_state)
		for definition in RestorationCatalog.data().parts:
			var task := RestorationTask.from_data(definition)
			legacy_state.register_part(StringName("trailer_01." + str(definition.id)), task)
		var window_task: RestorationTask = load("res://data/restoration/service_window.tres")
		legacy_state.register_part(&"trailer_01.service_window", window_task)
	if not data.get("restoration") is Dictionary or not legacy_state.validate(data.restoration) or not data.get("world") is Dictionary:
		return false
	var w: Dictionary = data.world
	if not CoffeeShiftSession._valid_point(w.get("position")) or not w.get("items") is Dictionary or not w.get("door_opened") is bool:
		return false
	for key in ["yaw", "pitch"]:
		if (not w.get(key) is float and not w.get(key) is int) or not is_finite(float(w[key])):
			return false
	return absf(float(w.pitch)) < 1.6

func read_slot(career_id: int, kind: String, slot: int) -> Dictionary:
	var current := super.read_slot(career_id, kind, slot)
	if not current.is_empty() or legacy_reader == null:
		return current
	var legacy := legacy_reader.read_slot(career_id, kind, slot)
	if legacy.is_empty():
		return {}
	var fresh := CoffeeShiftSession.new()
	fresh.start_mode = "dev02_migrated"
	fresh.legacy_snapshot = legacy.data.duplicate(true)
	legacy.data = {"trade": fresh.snapshot(), "world": {"position": [0, .4, .65], "yaw": -PI/2,
		"pitch": -.15}}
	legacy.reason = "Совместимая копия DEV-02; исходный гараж сохранён"
	return legacy

func occupied(career_id: int, kind: String, slot: int) -> bool:
	return super.occupied(career_id, kind, slot) or (legacy_reader != null and legacy_reader.occupied(career_id, kind, slot))

func clear_career(career_id: int) -> Error:
	# New-game confirmation clears this version only, never restoration_v1.
	return super.clear_career(career_id)

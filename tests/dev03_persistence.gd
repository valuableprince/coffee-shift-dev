extends SceneTree
var checks := 0
var failures := 0

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: ShiftWorld = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	world.new_game(1)
	var manager := world.save_manager
	check(manager.save_slot("manual", 1) == OK, "first manual point")
	var old: Dictionary = world.capture_snapshot()
	world.session.set_price("espresso_small", 90)
	check(manager.save_slot("manual", 1) == ERR_ALREADY_EXISTS, "manual overwrite protected")
	check(manager.save_slot("manual", 1, true) == OK, "explicit overwrite creates backup")
	var path := manager.slot_path(1, "manual", 1)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken JSON")
	file.close()
	var recovered := manager.read_slot(1, "manual", 1)
	check(not recovered.is_empty() and recovered.recovered, "corrupt primary recovers verified backup")
	check(manager.load_slot(1, "manual", 1), "load backup applies once")
	check(JSON.stringify(world.capture_snapshot()) == JSON.stringify(old), "backup restores old prices and cash exactly")
	check(manager.save_slot("manual", 1, true) == OK, "repaired primary does not destroy good backup")
	check(not manager._read_file(path + ".bak", 1, "manual", 1).is_empty(), "healthy backup retained")
	# P0: an occupied staging path leaves all old saves and live state intact.
	var before_failure := world.capture_snapshot()
	var preferred := world.game_settings.last_career
	var preserved := {}
	for row in manager.list_slots(1):
		for suffix in ["", ".bak"]:
			var saved_path := manager.slot_path(1, row.kind, row.slot) + str(suffix)
			if FileAccess.file_exists(saved_path): preserved[saved_path] = FileAccess.get_file_as_bytes(saved_path)
	var stage_path := manager.slot_path(1, "auto", 1).get_base_dir() + ".pending"
	file = FileAccess.open(stage_path, FileAccess.WRITE)
	file.store_string("occupied staging path")
	file.close()
	check(not world.new_game(1, true, false), "failed new game reports filesystem refusal")
	check(JSON.stringify(world.capture_snapshot()) == JSON.stringify(before_failure), "failed new game does not alter live world")
	check(manager.career == 1 and world.game_settings.last_career == preferred, "failed new game keeps selected and preferred careers")
	for saved_path in preserved:
		check(FileAccess.get_file_as_bytes(saved_path) == preserved[saved_path], "failed new game retains every primary and backup")
	check(manager.load_slot(1, "manual", 1), "Continue still loads after failed new game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage_path))
	for i in range(5): check(manager.save_auto("rotation test") == OK, "cyclic automatic point")
	var autos := 0
	for row in manager.list_slots(1):
		if row.kind == "auto" and row.valid: autos += 1
	check(autos == 3, "exactly three cyclic auto points")
	var snapshot: Dictionary = world.capture_snapshot()
	var bad: Dictionary = snapshot.duplicate(true)
	bad.trade.payment = {"order": 5}
	check(not world.apply_snapshot(bad), "malformed payment rejected without Nil")
	check(JSON.stringify(world.capture_snapshot()) == JSON.stringify(snapshot), "bad load leaves world unchanged")
	bad = snapshot.duplicate(true)
	bad.world.pitch = "not a number"
	check(not world.apply_snapshot(bad), "bad camera data rejected")
	# Build a real DEV-02 snapshot and let the original manager write it.
	var garage = load("res://scenes/main.tscn").instantiate()
	root.add_child(garage)
	await process_frame
	garage.save_manager.autosave_enabled = false
	garage.save_manager.directory = manager.legacy_reader.directory
	garage.save_manager.career = 3
	check(garage.save_manager.save_slot("manual", 1) == OK, "real DEV-02 file saved by original manager")
	check(garage.save_manager.save_slot("manual", 1, true) == OK, "legacy fixture has multiple save generations")
	var legacy_path: String = garage.save_manager.slot_path(3, "manual", 1)
	var original_bytes := FileAccess.get_file_as_bytes(legacy_path)
	var original_payload: Dictionary = garage.capture_snapshot()
	var migrated: Dictionary = manager.read_slot(3, "manual", 1)
	check(not migrated.is_empty(), "legacy format recognized")
	if not migrated.is_empty():
		check(migrated.data.trade.start_mode == "dev02_migrated", "migration distinct from completed prologue")
		check(not migrated.data.trade.prologue_completed, "migration awards no achievement")
		check(JSON.stringify(migrated.data.trade.legacy_snapshot) == JSON.stringify(original_payload), "entire legacy restoration and world retained")
		check(world.validate_snapshot(migrated.data), "migrated data compatible before apply")
		check(manager.load_slot(3, "manual", 1), "Continue accepts valid DEV-02 copy")
		check(manager.save_auto("first migrated save") == OK, "migrated save written to new namespace")
		check(FileAccess.get_file_as_bytes(legacy_path) == original_bytes, "legacy file remains byte-for-byte intact")
		check(manager.clear_career(3) == OK, "clear new version career")
		check(FileAccess.get_file_as_bytes(legacy_path) == original_bytes, "new career never deletes old DEV-02 file")
		var legacy_generation: int = manager.legacy_reader.latest(3).generation
		check(not world.new_game(3, false, false), "legacy-only career still requires overwrite confirmation")
		check(world.new_game(3, true, false), "confirmed new game can replace a migrated career")
		var fresh_point := manager.latest(3)
		check(fresh_point.generation > legacy_generation and fresh_point.data.trade.start_mode == "prototype_start", "Continue prioritizes fresh initial save over every legacy generation")
		check(manager.load_slot(3, fresh_point.kind, fresh_point.slot), "new career remains loadable with legacy files present")
		check(world.session.start_mode == "prototype_start", "Continue loads the newly created career rather than DEV-02 migration")
		check(FileAccess.get_file_as_bytes(legacy_path) == original_bytes, "new-career transaction never modifies source DEV-02 bytes")
	garage.queue_free()
	await process_frame
	# Preferences survive a fresh settings object and cannot change career data.
	var existing := FileAccess.get_file_as_bytes(CoffeeShiftSettings.PATH)
	var existed := FileAccess.file_exists(CoffeeShiftSettings.PATH)
	var settings := CoffeeShiftSettings.new()
	settings.master_volume = 35
	settings.effects_volume = 45
	settings.music_volume = 55
	settings.shadow_quality = 2
	settings.mouse_sensitivity = .0032
	check(settings.save_to_disk() == OK, "settings saved")
	var reloaded := CoffeeShiftSettings.new()
	reloaded.load_from_disk()
	check(reloaded.master_volume == 35 and reloaded.effects_volume == 45 and reloaded.music_volume == 55, "independent audio channels persist")
	check(reloaded.shadow_quality == 2 and is_equal_approx(reloaded.mouse_sensitivity, .0032), "graphics and mouse preferences persist")
	if existed:
		var restore_file := FileAccess.open(CoffeeShiftSettings.PATH, FileAccess.WRITE)
		restore_file.store_buffer(existing)
		restore_file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CoffeeShiftSettings.PATH))
	world.save_manager.autosave_enabled = false
	world.queue_free()
	await process_frame
	print("DEV03 PERSISTENCE: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

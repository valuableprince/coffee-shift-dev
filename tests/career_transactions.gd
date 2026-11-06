extends SceneTree
## Actual filesystem failures; no rendered scene or player save files required.
class Fixture extends RefCounted:
	var data := {"value": 7}
	var reject := -1
	func capture() -> Dictionary: return data.duplicate(true)
	func validate(snapshot: Dictionary) -> bool:
		return snapshot.get("value") is float or snapshot.get("value") is int
	func apply(snapshot: Dictionary) -> bool:
		if not validate(snapshot) or snapshot.value == reject: return false
		data = snapshot.duplicate(true)
		return true

class FaultManager extends RestorationSaveManager:
	var fault := ""
	var triggered := false
	func _write_snapshot(path: String, snapshot: Dictionary, career_id: int, kind: String, slot: int, generation: int, reason: String) -> Error:
		if fault == "write" and not triggered:
			triggered = true
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path + ".tmp"))
		# Exercise the real FileAccess.WRITE; never substitute an error return.
		return super._write_snapshot(path, snapshot, career_id, kind, slot, generation, reason)
	func _rename_directory(source: String, destination: String) -> Error:
		if not triggered and ((fault == "move_old" and destination.ends_with(".previous")) or (fault == "install" and source.ends_with(".pending"))):
			triggered = true
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
			var file := FileAccess.open(destination.path_join("obstacle"), FileAccess.WRITE)
			file.store_string("Nonempty destination prevents a real directory rename on Windows and Linux")
			file.close()
		return super._rename_directory(source, destination)

var checks := 0
var failures := 0
var serial := 0
var test_root := ""

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func manager_for(fixture: Fixture, path: String = "") -> FaultManager:
	var manager := FaultManager.new()
	manager.autosave_enabled = false
	serial += 1
	manager.directory = path if path != "" else test_root.path_join(str(serial))
	manager.configure(fixture.capture, fixture.apply, fixture.validate)
	root.add_child(manager)
	return manager

func seed_careers(manager: RestorationSaveManager, fixture: Fixture) -> void:
	for career_id in range(1, 4):
		manager.career = career_id
		for kind in ["auto", "manual"]:
			for slot in range(1, 4):
				fixture.data.value = career_id * 100 + slot
				check(manager.save_slot(kind, slot, true) == OK, "seed %d/%s/%d" % [career_id, kind, slot])
		fixture.data.value = career_id * 100 + 99
		check(manager.save_slot("manual", 1, true) == OK, "seed verified backup")
	manager.career = 2
	fixture.data.value = 929
	manager._pending = true
	manager._delay = .9
	manager._elapsed = 40
	manager._reason = "existing checkpoint"

func files(path: String) -> Dictionary:
	var result := {}
	for kind in ["auto", "manual"]:
		for slot in range(1, 4):
			for suffix in ["", ".bak"]:
				var name := "%s_%d.json%s" % [kind, slot, suffix]
				var full_path := path.path_join(name)
				if FileAccess.file_exists(full_path): result[name] = FileAccess.get_file_as_bytes(full_path)
	return result

func failure_case(fault: String) -> void:
	var fixture := Fixture.new()
	var manager := manager_for(fixture)
	seed_careers(manager, fixture)
	var active := manager.slot_path(1, "auto", 1).get_base_dir()
	var old := files(active)
	var second := files(manager.slot_path(2, "auto", 1).get_base_dir())
	var third := files(manager.slot_path(3, "auto", 1).get_base_dir())
	manager.fault = fault
	if fault == "prepare":
		var obstacle := FileAccess.open(active + ".pending", FileAccess.WRITE)
		obstacle.store_string("occupied staging path")
		obstacle.close()
	if fault == "apply": fixture.reject = 1
	var candidate := {"value": 1} if fault != "validate" else {"wrong": true}
	check(manager.start_career(1, candidate) != OK, fault + ": failure is reported")
	check(fixture.data.value == 929 and manager.career == 2, fault + ": world and selected career unchanged")
	check(manager._pending and manager._delay == .9 and manager._elapsed == 40 and manager._reason == "existing checkpoint", fault + ": checkpoint state unchanged")
	var preserved := active + ".previous" if fault == "install" else active
	check(files(preserved) == old, fault + ": every old primary and backup is byte-identical")
	check(files(manager.slot_path(2, "auto", 1).get_base_dir()) == second and files(manager.slot_path(3, "auto", 1).get_base_dir()) == third, fault + ": other careers untouched")
	var restarted := manager_for(fixture, manager.directory)
	check(restarted.load_slot(1, "manual", 1) and fixture.data.value == 199, fault + ": Continue reads original career through a fresh manager")
	if fault == "install":
		check(restarted.save_auto() != OK, "blocked rollback refuses writes to an unexpected destination")
		check(manager._remove_directory(active) == OK, "remove injected rename obstacle")
		check(not restarted.latest(1).is_empty() and files(active) == old, "next read completes rollback to original paths")
	if fault == "prepare": DirAccess.remove_absolute(ProjectSettings.globalize_path(active + ".pending"))
	fixture.reject = -1
	check(restarted.start_career(1, {"value": 1}) == OK, fault + ": retry succeeds after fault is removed")
	check(restarted.read_slot(1, "manual", 1).is_empty(), fault + ": staged leftovers never become old visible slots")
	manager.free()
	restarted.free()

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-mode"):
		push_error("Career transaction tests require --test-mode")
		quit(2)
		return
	test_root = "user://career_transactions_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for fault in ["validate", "prepare", "write", "apply", "move_old", "install"]:
		failure_case(fault)
	var fixture := Fixture.new()
	var manager := manager_for(fixture)
	seed_careers(manager, fixture)
	var active := manager.slot_path(1, "auto", 1).get_base_dir()
	var old := files(active)
	var previous_generation: int = manager.latest(1).generation
	# Exact original audit obstacle: it must not destroy the old career.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(manager.slot_path(1, "auto", 1) + ".tmp"))
	check(manager.start_career(1, {"value": 1}) == OK, "original audit obstacle cannot block the separate staging write")
	check(fixture.data.value == 1 and manager.career == 1, "successful commit applies and selects fresh career")
	check(files(active + ".previous") == old, "successful commit retains complete old career")
	check(files(active).size() == 1 and manager.latest(1).generation == previous_generation + 1, "new career has only its verified autosave newer than old slots")
	check(manager.read_slot(1, "manual", 1).is_empty(), "new career never mixes slots from retained archive")
	var restarted := manager_for(fixture, manager.directory)
	check(restarted.load_slot(1, "auto", 1) and fixture.data.value == 1, "restart after commit loads new career")
	check(restarted.clear_career(1) == OK and restarted.latest(1).is_empty(), "explicit clear cannot resurrect retained archive")
	manager.free()
	restarted.free()
	# Disk layout left by termination immediately between the two renames.
	manager = manager_for(fixture)
	seed_careers(manager, fixture)
	active = manager.slot_path(1, "auto", 1).get_base_dir()
	old = files(active)
	check(manager._write_snapshot((active + ".pending").path_join("auto_1.json"), {"value": 1}, 1, "auto", 1, 1, "interrupted candidate") == OK, "stage interrupted replacement")
	check(manager._rename_directory(active, active + ".previous") == OK, "simulate termination after old-directory rename")
	restarted = manager_for(fixture, manager.directory)
	check(restarted.load_slot(1, "manual", 1) and fixture.data.value == 199, "fresh manager recovers old career after interrupted replacement")
	check(files(active) == old and restarted.read_slot(1, "auto", 1).data.value == 101, "recovery never loads uncommitted candidate")
	check(restarted.start_career(1, {"value": 1}) == OK, "restart can retry after interrupted replacement")
	manager.free()
	restarted.free()
	print("CAREER TRANSACTIONS (%s): %d checks; %d failures" % [OS.get_name(), checks, failures])
	quit(0 if failures == 0 else 1)

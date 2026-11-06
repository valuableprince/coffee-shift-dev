class_name RestorationSaveManager
extends Node
## Versioned 3 careers x (3 manual + 3 cyclic autos) in a separate namespace.
## Verified temp -> verified backup of last good primary -> atomic primary rename.

signal slots_changed
signal feedback(message: String)
const FORMAT_VERSION := 1
const CAREERS := 3
const SLOTS_PER_KIND := 3
const AUTO_INTERVAL := 120.0
const CHECKPOINT_DELAY := .6
const MAX_BYTES := 4 * 1024 * 1024
var directory := "user://restoration_v1"
var career := 1
var capture: Callable
var apply_snapshot: Callable
var validate_snapshot: Callable
var autosave_enabled := true
var _pending := false
var _delay := 0.0
var _elapsed := 0.0
var _reason := "Контрольная точка"

func configure(capture_world: Callable, apply_world: Callable, validate_world: Callable) -> void:
	capture = capture_world
	apply_snapshot = apply_world
	validate_snapshot = validate_world

func slot_path(career_id: int, kind: String, slot: int) -> String:
	return "%s/career_%d/%s_%d.json" % [directory,career_id,kind,slot]

func _valid_address(career_id: int, kind: String, slot: int) -> bool:
	return career_id >= 1 and career_id <= CAREERS and kind in ["manual","auto"] and slot >= 1 and slot <= SLOTS_PER_KIND

func occupied(career_id: int, kind: String, slot: int) -> bool:
	if not _valid_address(career_id,kind,slot):
		return false
	var path := _read_directory(career_id).path_join("%s_%d.json" % [kind,slot])
	return FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak")

func _career_directory(career_id: int) -> String:
	return directory.path_join("career_%d" % career_id)

func _has_valid_save(path: String, career_id: int) -> bool:
	for kind in ["manual", "auto"]:
		for slot in range(1, SLOTS_PER_KIND + 1):
			for suffix in ["", ".bak"]:
				if not _read_file(path.path_join("%s_%d.json%s" % [kind, slot, suffix]), career_id, kind, slot).is_empty():
					return true
	return false

func _rename_directory(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))

func _recover_career(career_id: int) -> Error:
	var active := _career_directory(career_id)
	var previous := active + ".previous"
	if not DirAccess.dir_exists_absolute(previous):
		return OK
	if not DirAccess.dir_exists_absolute(active) and not FileAccess.file_exists(active):
		# An interruption between the two renames keeps the old career authoritative.
		return _rename_directory(previous, active)
	if not _has_valid_save(active, career_id) and _has_valid_save(previous, career_id):
		# Do not overwrite an unexpected filesystem obstacle during recovery.
		return ERR_FILE_CORRUPT
	return OK

func _read_directory(career_id: int) -> String:
	var active := _career_directory(career_id)
	if _recover_career(career_id) != OK and _has_valid_save(active + ".previous", career_id):
		# Even if a filesystem error prevents rollback, Continue can read the old data.
		return active + ".previous"
	return active

func _remove_directory(path: String) -> Error:
	var folder := DirAccess.open(path)
	if folder == null:
		var open_error := DirAccess.get_open_error()
		if DirAccess.dir_exists_absolute(path): return open_error
		return ERR_ALREADY_EXISTS if FileAccess.file_exists(path) else OK
	for child in folder.get_files():
		var error := DirAccess.remove_absolute(path.path_join(child))
		if error != OK: return error
	for child in folder.get_directories():
		var error := _remove_directory(path.path_join(child))
		if error != OK: return error
	folder = null # Close the directory handle before removal on Windows.
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func start_career(career_id: int, initial: Dictionary, reason: String = "Новая игра") -> Error:
	if not _valid_address(career_id, "auto", 1) or not capture.is_valid() or not apply_snapshot.is_valid() or not validate_snapshot.is_valid():
		return ERR_INVALID_PARAMETER
	if not validate_snapshot.call(initial): return ERR_INVALID_DATA
	var error := _recover_career(career_id)
	if error != OK: return error
	var active := _career_directory(career_id)
	var pending := active + ".pending"
	var previous := active + ".previous"
	# Both cleanups happen while the current career is still in its original place.
	for path in [pending, previous]:
		error = _remove_directory(path)
		if error != OK: return error
	# Legacy readers may still expose older slots; the fresh point must rank above them.
	error = _write_snapshot(pending.path_join("auto_1.json"), initial, career_id, "auto", 1, _next_generation(career_id), reason)
	if error != OK: return error
	var old_world: Dictionary = capture.call()
	var old_pending := _pending
	var old_delay := _delay
	var old_elapsed := _elapsed
	var old_reason := _reason
	var had_active := DirAccess.dir_exists_absolute(active) or FileAccess.file_exists(active)
	if not apply_snapshot.call(initial):
		error = ERR_INVALID_DATA
	elif had_active:
		error = _rename_directory(active, previous)
	if error == OK:
		error = _rename_directory(pending, active)
	if error != OK:
		# Recovery also runs on the next read/startup if the rollback rename fails.
		_recover_career(career_id)
		apply_snapshot.call(old_world)
		_pending = old_pending
		_delay = old_delay
		_elapsed = old_elapsed
		_reason = old_reason
		return error
	career = career_id
	_pending = false
	_elapsed = 0.0
	slots_changed.emit()
	return OK

func _read_file(path: String, career_id: int, kind: String, slot: int) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary or parsed.get("format") != FORMAT_VERSION:
		return {}
	if parsed.get("career") != career_id or parsed.get("kind") != kind or parsed.get("slot") != slot:
		return {}
	if not parsed.get("payload") is String or not parsed.get("checksum") is String:
		return {}
	if parsed.payload.sha256_text() != parsed.checksum:
		return {}
	var payload_parser := JSON.new()
	if payload_parser.parse(parsed.payload) != OK:
		return {}
	var data = payload_parser.data
	if not data is Dictionary or not validate_snapshot.is_valid() or not validate_snapshot.call(data):
		return {}
	var generation = parsed.get("generation",0)
	if (not generation is float and not generation is int) or generation < 1 or generation != int(generation):
		return {}
	return {"data": data,"generation":int(generation),"timestamp":str(parsed.get("timestamp","")),"reason":str(parsed.get("reason","")),"kind":kind,"slot":slot}

func read_slot(career_id: int, kind: String, slot: int) -> Dictionary:
	if not _valid_address(career_id,kind,slot):
		return {}
	var path := _read_directory(career_id).path_join("%s_%d.json" % [kind,slot])
	var result := _read_file(path,career_id,kind,slot)
	if not result.is_empty():
		result.recovered = false
		return result
	result = _read_file(path+".bak",career_id,kind,slot)
	if not result.is_empty():
		result.recovered = true
	return result

func list_slots(career_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind in ["manual","auto"]:
		for index in range(1,SLOTS_PER_KIND+1):
			var row := read_slot(career_id,kind,index)
			result.append({"kind":kind,"slot":index,"occupied":occupied(career_id,kind,index),"valid":not row.is_empty(),
				"timestamp":row.get("timestamp",""),"generation":row.get("generation",0),"recovered":row.get("recovered",false)})
	return result

func latest(career_id: int) -> Dictionary:
	var result := {}
	for row in list_slots(career_id):
		if row.valid and int(row.generation) > int(result.get("generation",0)):
			result = read_slot(career_id,row.kind,int(row.slot))
	return result

func save_slot(kind: String, slot: int, overwrite_confirmed: bool = false, reason: String = "Ручное сохранение") -> Error:
	if not _valid_address(career,kind,slot) or not capture.is_valid():
		return ERR_INVALID_PARAMETER
	var recovery := _recover_career(career)
	if recovery != OK: return recovery
	if kind == "manual" and occupied(career,kind,slot) and not overwrite_confirmed:
		return ERR_ALREADY_EXISTS
	var snapshot: Dictionary = capture.call()
	if not validate_snapshot.call(snapshot):
		return ERR_INVALID_DATA
	var error := _write_snapshot(slot_path(career,kind,slot), snapshot, career, kind, slot, _next_generation(career), reason)
	if error == OK:
		_pending = false
		_elapsed = 0.0
		slots_changed.emit()
	return error

func _next_generation(career_id: int) -> int:
	var generation := 1
	for row in list_slots(career_id):
		generation = maxi(generation, int(row.generation) + 1)
	return generation

func _write_snapshot(path: String, snapshot: Dictionary, career_id: int, kind: String, slot: int, generation: int, reason: String) -> Error:
	var payload := JSON.stringify(snapshot)
	var envelope := {"format":FORMAT_VERSION,"career":career_id,"kind":kind,"slot":slot,"generation":generation,
		"timestamp":Time.get_datetime_string_from_system(),"reason":reason,"payload":payload,"checksum":payload.sha256_text()}
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK:
		return error
	var temporary := path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope,"\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or _read_file(temporary,career_id,kind,slot).is_empty():
		return ERR_FILE_CORRUPT
	# A corrupt primary must never replace a healthy backup.
	if not _read_file(path,career_id,kind,slot).is_empty():
		var backup_temp := path+".bak.tmp"
		error = DirAccess.copy_absolute(path,backup_temp)
		if error != OK or _read_file(backup_temp,career_id,kind,slot).is_empty():
			return ERR_FILE_CANT_WRITE
		error = DirAccess.rename_absolute(backup_temp,path+".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temporary,path)

func save_auto(reason: String = "Автосохранение") -> Error:
	var chosen := 1
	var oldest := 9223372036854775807
	for index in range(1,SLOTS_PER_KIND+1):
		var row := read_slot(career,"auto",index)
		var generation := int(row.get("generation",0))
		if generation < oldest:
			oldest = generation
			chosen = index
	return save_slot("auto",chosen,true,reason)

func load_slot(career_id: int, kind: String, slot: int) -> bool:
	var saved := read_slot(career_id,kind,slot)
	if saved.is_empty():
		feedback.emit("Сохранение отсутствует, повреждено или относится к другой версии. Мир не изменён.")
		return false
	# Validation is read-only. Apply happens once, after all fields have passed.
	if not apply_snapshot.call(saved.data):
		return false
	career = career_id
	_pending = false
	_elapsed = 0
	slots_changed.emit()
	feedback.emit("Прогресс загружен" + (" из резервной копии." if saved.recovered else "."))
	return true

func clear_career(career_id: int) -> Error:
	# Used only after an explicit new-game overwrite confirmation.
	if career_id < 1 or career_id > CAREERS:
		return ERR_INVALID_PARAMETER
	var recovery := _recover_career(career_id)
	if recovery != OK: return recovery
	for suffix in [".pending", ".previous"]:
		var cleanup := _remove_directory(_career_directory(career_id) + suffix)
		if cleanup != OK: return cleanup
	for kind in ["manual","auto"]:
		for slot in range(1,SLOTS_PER_KIND + 1):
			var path := slot_path(career_id,kind,slot)
			for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
				var full_path: String = path + str(suffix)
				if FileAccess.file_exists(full_path):
					var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(full_path))
					if error != OK:
						return error
	_pending = false
	_elapsed = 0.0
	slots_changed.emit()
	return OK

func mark_checkpoint(reason: String) -> void:
	_pending = true
	_delay = CHECKPOINT_DELAY
	_reason = reason

func _process(delta: float) -> void:
	if not autosave_enabled or not capture.is_valid():
		return
	_elapsed += delta
	_delay -= delta
	if (_pending and _delay <= 0) or _elapsed >= AUTO_INTERVAL:
		var error := save_auto(_reason if _pending else "Интервал 120 секунд")
		if error != OK:
			feedback.emit("Не удалось сохранить прогресс. Проверьте доступ к диску. Код: %d" % error)
			# Back off; do not retry disk errors every frame.
			_delay = 30.0
			_elapsed = 0


extends Node3D
## Composition, input and world snapshots. Restoration rules live in the state.

@onready var player: CoffeeShiftPlayer = $Player
@onready var trailer: CoffeeTrailer = $CoffeeTrailer
@onready var state: RestorationState = $RestorationState
@onready var hud: GarageHUD = $GarageHUD
@onready var music: PrototypeMusic = $PrototypeMusic
var parts: Array[InspectablePart] = []
var pickups: Array[WorkshopPickup] = []
var inspection_enabled := false
var active_part: InspectablePart
var flashlight: SpotLight3D
var hands: FirstPersonTools
var save_manager: RestorationSaveManager
var save_menu: RestorationSaveMenu
var _capture_before_notebook := true
var _initial_snapshot: Dictionary = {}
var main_menu: CoffeeShiftMainMenu
var game_settings: CoffeeShiftSettings
var _menu_canvas: CanvasLayer
var _game_active := false
var _save_menu_from_pause := false
var _test_mode := false
var _test_menu := false

func _enter_tree() -> void:
	# Child nodes may capture mouse before the parent finishes initialization.
	# Defer the root input handler until the full UI graph has been built.
	set_process_input(false)

func _ready() -> void:
	_test_mode = OS.get_cmdline_user_args().has("--test-mode")
	_test_menu = OS.get_cmdline_user_args().has("--test-menu")
	for node in get_tree().get_nodes_in_group("inspectable_parts"):
		if not is_ancestor_of(node):
			continue
		var part := node as InspectablePart
		var ancestor := part.get_parent()
		while ancestor != null and not ancestor is CoffeeTrailer:
			ancestor = ancestor.get_parent()
		var owner_trailer := ancestor as CoffeeTrailer
		if owner_trailer == null:
			push_error("Inspectable part must belong to a CoffeeTrailer: " + str(part.get_path()))
			continue
		part.bind(state,owner_trailer.trailer_id)
		parts.append(part)
	for node in get_tree().get_nodes_in_group("workshop_pickups"):
		if is_ancestor_of(node):
			var pickup := node as WorkshopPickup
			pickup.bind(state)
			pickups.append(pickup)
	# Initialize saves before binding the optional paper UI. A HUD failure must
	# never prevent F6 from being registered and opening the save screen.
	save_manager = RestorationSaveManager.new()
	add_child(save_manager)
	save_manager.configure(capture_snapshot,apply_snapshot,validate_snapshot)
	save_manager.autosave_enabled = not OS.get_cmdline_user_args().has("--test-mode")
	save_manager.feedback.connect(hud.say)
	state.checkpoint.connect(save_manager.mark_checkpoint)
	trailer.get_node("StaffDoor").openness_changed.connect(func(_opened: bool) -> void:
		save_manager.mark_checkpoint("Дверь трейлера"))
	save_menu = RestorationSaveMenu.new()
	# Attach directly to the CanvasLayer; the menu remains independent of the
	# generated Interface subtree and receives full-viewport anchors.
	hud.add_child(save_menu)
	save_menu.bind(save_manager)
	save_menu.close_requested.connect(_set_save_menu.bind(false))
	save_menu.career_requested.connect(switch_career)
	if not is_instance_valid(hud.notebook):
		push_warning("DEV-02: paper notebook missing from HUD; rebuilding it.")
		var ui_root := hud.get_node_or_null("Interface") as Control
		if ui_root != null:
			hud.notebook = PaperNotebook.new()
			ui_root.add_child(hud.notebook)
	hud.bind(state)
	hud.reticle.bind(player)
	hud.say("Трейлер в гараже. [Q] — осмотр, [E] — обследование. Инструменты справа, материалы на полках слева. [F6] — сохранения.")
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color("ffe9ba")
	flashlight.light_energy = 1.0
	flashlight.spot_range = 5.0
	flashlight.spot_angle = 35.0
	flashlight.position = Vector3(.15,-.15,-.1)
	flashlight.visible = false
	player.camera.add_child(flashlight)
	hands = FirstPersonTools.new()
	player.camera.add_child(hands)
	hands.bind(state.belt)
	state.belt.selected_changed.connect(func() -> void: active_part = null)

	var graphics := CoffeeShiftGraphics.new()
	graphics.name = "GraphicsSettings"
	add_child(graphics)
	game_settings = CoffeeShiftSettings.new()
	if not _test_mode:
		game_settings.load_from_disk()
	music.preferences_changed.connect(_on_music_preferences_changed)
	_menu_canvas = CanvasLayer.new()
	_menu_canvas.layer = 30
	add_child(_menu_canvas)
	main_menu = CoffeeShiftMainMenu.new()
	_menu_canvas.add_child(main_menu)
	main_menu.configure(save_manager,game_settings)
	main_menu.continue_requested.connect(_continue_from_menu)
	main_menu.new_game_requested.connect(_new_game_from_menu)
	main_menu.settings_updated.connect(_apply_settings)
	main_menu.resume_requested.connect(_resume_game)
	main_menu.open_saves_requested.connect(_open_saves_from_pause)
	main_menu.title_requested.connect(_return_to_title)
	main_menu.exit_requested.connect(_quit_from_menu)
	_initial_snapshot = capture_snapshot().duplicate(true)
	if not _test_mode or _test_menu:
		get_tree().auto_accept_quit = false
		save_manager.autosave_enabled = false
		_show_title()
	else:
		# Preserve independent DEV-01/DEV-02 automated scene tests.
		_game_active = true
	# Applying a window size/mode may dispatch early input. Do it only after
	# the menu and its event handlers have been fully initialized.
	if not _test_mode:
		game_settings.apply_to_game(player,hud,music)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# Player._ready() captures the mouse before this parent completes _ready().
	# Godot may dispatch mouse/keyboard events while the main menu is still null.
	# Do not process input until both runtime UI components exist.
	if not is_instance_valid(main_menu) or not is_instance_valid(save_menu):
		return
	if _test_mode and not _test_menu:
		if event.is_action_pressed("save_menu") and is_instance_valid(save_menu):
			_set_save_menu(not save_menu.visible)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if main_menu.visible:
			main_menu.back()
		elif save_menu.visible:
			_set_save_menu(false)
		elif is_instance_valid(hud.notebook) and hud.notebook.visible:
			_set_notebook(false)
		elif _game_active:
			_show_pause()
		get_viewport().set_input_as_handled()
		return
	if main_menu.visible:
		return
	if event.is_action_pressed("save_menu") and _game_active and is_instance_valid(save_menu):
		_set_save_menu(not save_menu.visible)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(main_menu) and main_menu.visible:
		return
	if not is_instance_valid(save_menu) or not is_instance_valid(hud.notebook):
		return
	if save_menu.visible:
		if event.is_action_pressed("ui_cancel"):
			_set_save_menu(false)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("notebook"):
		_set_notebook(not hud.notebook.visible)
		get_viewport().set_input_as_handled()
	elif hud.notebook.visible:
		if event.is_action_pressed("ui_cancel"):
			_set_notebook(false)
		elif event.is_action_pressed("ui_right"):
			hud.notebook.turn(1)
		elif event.is_action_pressed("ui_left"):
			hud.notebook.turn(-1)
		get_viewport().set_input_as_handled()
	elif player.mouse_captured:
		for index in range(5):
			if event.is_action_pressed("tool_slot_%d" % (index+1)):
				state.belt.select_slot(index)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("tool_next"):
			state.belt.cycle(1)
		elif event.is_action_pressed("tool_previous"):
			state.belt.cycle(-1)
		elif event.is_action_pressed("inspect_mode"):
			inspection_enabled = not inspection_enabled
			for part in parts:
				part.set_inspection(inspection_enabled)
			flashlight.visible = inspection_enabled
			hud.set_inspection(inspection_enabled)
		elif event.is_action_pressed("replace_pickup"):
			_interact(player.get_interactable(),true)
		elif event.is_action_pressed("interact"):
			_interact(player.get_interactable())

func _interact(target: Node3D, replace_tool: bool = false) -> void:
	active_part = null
	if target is InspectablePart:
		if target.interact():
			active_part = target
	elif target is WorkshopPickup:
		target.interact(state,replace_tool)
	elif target is TrailerDoor:
		target.interact()

func _physics_process(delta: float) -> void:
	if is_instance_valid(main_menu) and main_menu.visible:
		return
	# Avoid per-frame Nil access when a HUD resource fails on a target machine.
	if hands == null or not is_instance_valid(hud.notebook) or not is_instance_valid(hud.hint) or not is_instance_valid(save_menu):
		return
	hands.working = false
	if hud.notebook.visible or save_menu.visible or not player.mouse_captured:
		active_part = null
		hud.set_work(0,false)
		hud.hint.text = ""
		return
	var target := player.get_interactable()
	hud.hint.text = target.get_prompt() if target != null else ""
	if active_part != null:
		if target != active_part or not Input.is_action_pressed("interact") or state.block_reason(active_part.element_id) != "":
			active_part = null
		else:
			hands.working = true
			hands.work_kind = active_part.task.category
			# Stop at each phase boundary. The next operation needs a fresh E press.
			if active_part.advance_work(delta):
				active_part = null
	hud.set_work(active_part.work_progress if active_part != null else 0.0,active_part != null)

func _set_notebook(opened: bool) -> void:
	active_part = null
	if opened:
		_capture_before_notebook = player.mouse_captured
		hud.notebook.refresh()
	hud.notebook.visible = opened
	player.controls_enabled = not opened
	player.set_mouse_capture(not opened and _capture_before_notebook)
	hands.visible = not opened

func _set_save_menu(opened: bool) -> void:
	active_part = null
	if opened:
		if hud.notebook.visible:
			_set_notebook(false)
		_capture_before_notebook = player.mouse_captured
		save_menu.refresh()
	save_menu.visible = opened
	player.controls_enabled = not opened
	player.set_mouse_capture(not opened and _capture_before_notebook)
	if is_instance_valid(hands):
		hands.visible = not opened
	if not opened and _save_menu_from_pause:
		_save_menu_from_pause = false
		_show_pause()

func _pickup_key(pickup: WorkshopPickup) -> String:
	return "tool:"+str(pickup.tool_id) if pickup.material_id == "" else "source:"+pickup.source_id

func capture_snapshot() -> Dictionary:
	var items := {}
	for pickup in pickups:
		items[_pickup_key(pickup)] = {"position":_vector_array(pickup.position),"taken":pickup.taken}
	var door: TrailerDoor = trailer.get_node("StaffDoor")
	return {"restoration":state.snapshot(),"world":{"position":_vector_array(player.position),
		"yaw":player.rotation.y,"pitch":player.camera.rotation.x,"door_opened":door.opened,
		"items":items}}

func _vector_array(vector: Vector3) -> Array:
	return [vector.x,vector.y,vector.z]

func _valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for number in value:
		if (not number is float and not number is int) or not is_finite(float(number)) or absf(float(number)) > 20:
			return false
	return true

func validate_snapshot(data: Dictionary) -> bool:
	if not data.get("restoration") is Dictionary or not state.validate(data.restoration) or not data.get("world") is Dictionary:
		return false
	var world: Dictionary = data.world
	if not _valid_vector(world.get("position")) or not world.get("items") is Dictionary or world.items.size() != pickups.size():
		return false
	var point := RestorationCatalog.vector(world.position)
	if absf(point.x)>5.05 or absf(point.z)>5.85 or point.y < -.1 or point.y > .7:
		return false
	for key in ["yaw","pitch"]:
		if (not world.get(key) is float and not world.get(key) is int) or not is_finite(float(world[key])):
			return false
	if absf(float(world.pitch))>1.6:
		return false
	if not world.get("door_opened") is bool:
		return false
	for pickup in pickups:
		var item = world.items.get(_pickup_key(pickup))
		if not item is Dictionary or not _valid_vector(item.get("position")) or not item.get("taken") is bool:
			return false
		var taken: bool = str(pickup.tool_id) in data.restoration.belt.slots if pickup.material_id == "" else pickup.source_id in data.restoration.collected
		if taken != item.taken:
			return false
	return true

func apply_snapshot(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		return false
	active_part = null
	state.restore(data.restoration)
	var world: Dictionary = data.world
	player.position = RestorationCatalog.vector(world.position)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3(0,float(world.yaw),0)
	player.pitch = float(world.pitch)
	player.camera.rotation = Vector3(player.pitch,0,0)
	trailer.get_node("StaffDoor").restore_opened(bool(world.door_opened))
	for pickup in pickups:
		pickup.position = RestorationCatalog.vector(world.items[_pickup_key(pickup)].position)
		pickup.sync()
	hud.refresh_status()
	if not _test_mode and game_settings != null:
		game_settings.apply_to_game(player,hud,music,false)
	return true

func switch_career(career_id: int) -> void:
	if career_id < 1 or career_id > 3 or career_id == save_manager.career:
		save_menu.refresh()
		return
	var latest := save_manager.latest(career_id)
	var occupied := false
	for row in save_manager.list_slots(career_id):
		occupied = occupied or row.occupied
	if latest.is_empty() and occupied:
		hud.say("У карьеры нет исправных сохранений. Существующие файлы сохранены.")
		save_menu.refresh()
		return
	var error := save_manager.save_auto("Перед сменой карьеры")
	if error != OK:
		hud.say("Смена карьеры отменена: не удалось сохранить текущий прогресс.")
		save_menu.refresh()
		return
	if not latest.is_empty():
		save_manager.load_slot(career_id,latest.kind,int(latest.slot))
	else:
		apply_snapshot(_initial_snapshot)
		save_manager.career = career_id
		save_manager.mark_checkpoint("Новая карьера")
		hud.say("Начата карьера %d. Прогресс других карьер сохранён." % career_id)
	save_menu.refresh()
	if not _test_mode and game_settings != null:
		game_settings.last_career = career_id
		game_settings.save_to_disk()
		game_settings.apply_to_game(player,hud,music,false)

func _show_title() -> void:
	active_part = null
	if is_instance_valid(hud.notebook):
		hud.notebook.hide()
	if is_instance_valid(save_menu):
		save_menu.hide()
	hud.hide()
	player.controls_enabled = false
	player.set_mouse_capture(false)
	if is_instance_valid(hands):
		hands.hide()
	save_manager.autosave_enabled = false
	main_menu.show_title()

func _show_pause() -> void:
	if not _game_active:
		return
	active_part = null
	if is_instance_valid(hud.notebook):
		hud.notebook.hide()
	if is_instance_valid(save_menu):
		save_menu.hide()
	hud.hide()
	player.controls_enabled = false
	player.set_mouse_capture(false)
	if is_instance_valid(hands):
		hands.hide()
	save_manager.autosave_enabled = false
	main_menu.show_pause()

func _resume_game() -> void:
	main_menu.hide()
	hud.show()
	player.controls_enabled = true
	player.set_mouse_capture(true)
	if is_instance_valid(hands):
		hands.show()
	_game_active = true
	save_manager.autosave_enabled = not _test_mode

func _continue_from_menu(career_id: int) -> void:
	if career_id < 1 or career_id > 3:
		main_menu.show_error("Выберите карьеру с сохранением.")
		return
	var saved := save_manager.latest(career_id)
	if saved.is_empty() or not save_manager.load_slot(career_id,str(saved.kind),int(saved.slot)):
		main_menu.show_error("Не удалось загрузить сохранение. Попробуйте другую карьеру.")
		return
	game_settings.last_career = career_id
	_save_preferences()
	_resume_game()

func _new_game_from_menu(career_id: int, overwrite: bool) -> void:
	if career_id < 1 or career_id > 3:
		main_menu.show_error("Недопустимый номер карьеры.")
		return
	var occupied := false
	for row in save_manager.list_slots(career_id):
		occupied = occupied or row.occupied
	if occupied and not overwrite:
		main_menu.show_error("Карьера занята. Требуется подтверждение перезаписи.")
		return
	var error := save_manager.start_career(career_id, _initial_snapshot)
	if error != OK:
		main_menu.show_error("Не удалось создать новую игру. Прежняя карьера сохранена. Код: %d" % error)
		return
	game_settings.last_career = career_id
	_save_preferences()
	_resume_game()

func _open_saves_from_pause() -> void:
	_save_menu_from_pause = true
	main_menu.hide()
	hud.show()
	_set_save_menu(true)

func _return_to_title() -> void:
	if _game_active:
		var error := save_manager.save_auto("Возврат в главное меню")
		if error != OK:
			main_menu.show_error("Не удалось сохранить игру. Код ошибки: %d" % error)
			return
	_game_active = false
	_show_title()

func _quit_from_menu() -> void:
	if _game_active:
		var error := save_manager.save_auto("Выход из игры")
		if error != OK:
			main_menu.show_error("Прогресс не сохранён. Выход отменён. Код: %d" % error)
			return
	get_tree().quit()

func _apply_settings() -> void:
	game_settings.apply_to_game(player,hud,music)
	_save_preferences()

func _save_preferences() -> void:
	if not _test_mode:
		var error := game_settings.save_to_disk()
		if error != OK and is_instance_valid(main_menu):
			main_menu.show_error("Не удалось сохранить настройки. Код: %d" % error)

func _on_music_preferences_changed(enabled: bool, db: float) -> void:
	if game_settings == null or _test_mode:
		return
	game_settings.music_enabled = enabled
	game_settings.music_volume = clampi(roundi((db + 40.0) / 0.4),0,100)
	_save_preferences()

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if _game_active and save_manager != null and not _test_mode:
		var error := save_manager.save_auto("Закрытие окна")
		if error != OK:
			if is_instance_valid(main_menu):
				main_menu.show_error("Не удалось сохранить игру. Код ошибки: %d" % error)
				_show_pause()
			return
	get_tree().quit()


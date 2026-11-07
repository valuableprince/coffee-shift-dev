class_name ShiftWorld
extends Node3D
## Scene composition. Physical E targets call authoritative session operations.
const G := preload("res://scripts/prototype/prototype_geometry.gd")
const STEP_HINTS := {
	"beans": "Возьмите кофе из пакета слева", "grind": "Смелите кофе в кофемолке справа",
	"filter": "Возьмите чистый рожок у кофемашины", "dose": "Наполните и утрамбуйте рожок темпером на коврике",
	"install": "Установите рожок в группу кофемашины", "cup": "Возьмите пустой стакан слева — затем сами установите его под кофемашину",
	"extract": "Запустите экстракцию на кофемашине [E] — наблюдайте секундомер", "stop": "Остановите экстракцию по секундомеру через 8–12 секунд [E]",
	"water": "Долейте горячую воду через кран на кофемашине [E]", "milk": "Откройте холодильник слева и возьмите молоко с полки",
	"pitcher": "Перелейте молоко в питчер рядом с кофемолкой", "steam": "Включите паровую трубку справа",
	"stop_steam": "Остановите паровую трубку", "pour": "Добавьте молоко из питчера к кофе",
	"sugar": "Добавьте порцию сахара из сахарницы слева", "syrup": "Добавьте ванильный сироп слева",
	"lid": "Возьмите крышку со стопки и наденьте её на стакан на столешнице", "place": "Перенесите закрытый стакан на стойку выдачи [E]"
}
var session := CoffeeShiftSession.new()
var player: CoffeeShiftPlayer
var trailer: CoffeeTrailer
var hud: ShiftHUD
var main_menu: CoffeeShiftMainMenu
var save_manager: ShiftSaveManager
var save_menu: RestorationSaveMenu
var game_settings := CoffeeShiftSettings.new()
var music: Audio01Director
var radio_receiver: CoffeeShiftRadioReceiver
var audio: ShiftAudio
var stations: Dictionary = {}
var shutter: Node3D
var _shutter_open := false
var drinks_root: Node3D
var npc_root: Node3D
var npc_visuals: Dictionary = {}
var menu_labels: Array[Label3D] = []
var held: Node3D
var cash_drawer: Node3D
var new_assets: ShiftNewAssets
var _cash_panel_opened := false
var preparation_visual: Node3D
var _active := false
var _test := false
var _ready_for_input := false
var _saves_from_pause := false
var fridge: ShiftFridge
var grinder_visual: Node3D
var machine_visual: EspressoMachineVisual
var accessories: BaristaAccessories
var inspection: EquipmentInspection
var _orders_editing := false
var _foot_distance := 0.0
var _last_foot_position := Vector3.ZERO

func _enter_tree() -> void:
	set_process_input(false)

func _ready() -> void:
	_test = OS.get_cmdline_user_args().has("--test-mode")
	TradingLocation.build(self)
	_build_trailer()
	player = CoffeeShiftPlayer.new()
	player.name = "Player"
	player.position = Vector3(0, .4, .65)
	player.rotation.y = -PI/2
	player.walk_speed = 2.2
	player.run_speed = 3.5
	add_child(player)
	player.pitch = -.15
	player.camera.rotation.x = player.pitch
	_last_foot_position = player.position
	held = Node3D.new()
	held.position = Vector3(.24, -.26, -.48)
	player.camera.add_child(held)
	accessories = BaristaAccessories.new()
	trailer.add_child(accessories)
	accessories.configure(self)
	_build_stations()
	npc_root = Node3D.new()
	npc_root.name = "Customers"
	add_child(npc_root)
	music = Audio01Director.new()
	add_child(music)
	music.attach_radio(radio_receiver, Vector3.ZERO, radio_receiver.get_node("RadioSound"))
	music.radio_power_changed.connect(radio_receiver.set_power)
	radio_receiver.set_power(music.radio_on)
	audio = ShiftAudio.new()
	add_child(audio)
	var graphics := CoffeeShiftGraphics.new()
	graphics.name = "GraphicsSettings"
	add_child(graphics)
	hud = ShiftHUD.new()
	add_child(hud)
	hud.reticle.bind(player)
	hud.panel_closed.connect(_resume_controls)
	hud.order_selected.connect(_select_order_item)
	hud.order_called.connect(_call_order_from_sidebar)
	inspection = EquipmentInspection.new()
	add_child(inspection)
	inspection.configure(self)
	save_manager = ShiftSaveManager.new()
	add_child(save_manager)
	if _test:
		save_manager.directory = "user://dev03_tests_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]
		save_manager.legacy_reader.directory = save_manager.directory + "/legacy"
	save_manager.configure(capture_snapshot, apply_snapshot, validate_snapshot)
	save_manager.autosave_enabled = false
	save_manager.feedback.connect(hud.say)
	trailer.get_node("StaffDoor").openness_changed.connect(func(_opened: bool) -> void:
		save_manager.mark_checkpoint("Дверь трейлера"))
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	save_menu = RestorationSaveMenu.new()
	canvas.add_child(save_menu)
	save_menu.bind(save_manager)
	_relabel_save_menu(save_menu)
	save_menu.close_requested.connect(_close_saves)
	save_menu.career_requested.connect(switch_career)
	main_menu = CoffeeShiftMainMenu.new()
	canvas.add_child(main_menu)
	main_menu.configure(save_manager, game_settings)
	main_menu.continue_requested.connect(continue_game)
	main_menu.new_game_requested.connect(new_game)
	main_menu.resume_requested.connect(resume_game)
	main_menu.settings_updated.connect(apply_settings)
	main_menu.open_saves_requested.connect(_open_saves_from_pause)
	main_menu.title_requested.connect(return_to_title)
	main_menu.exit_requested.connect(quit_game)
	_bind_session()
	if not _test:
		game_settings.load_from_disk()
	music.preferences_changed.connect(func(enabled: bool, db: float) -> void:
		game_settings.music_enabled = enabled
		game_settings.music_volume = clampi(roundi((db + 40) / .4), 0, 100)
		if not _test: game_settings.save_to_disk())
	apply_settings()
	get_tree().auto_accept_quit = false
	_refresh()
	show_title()
	_ready_for_input = true
	set_process_input(true)

func _relabel_save_menu(node: Node) -> void:
	if node is Label and node.text == "СОХРАНЕНИЯ ВОССТАНОВЛЕНИЯ": node.text = "СОХРАНЕНИЯ КАРЬЕРЫ"
	if node is Button and node.text == "Вернуться в гараж [F6 / Esc]": node.text = "Вернуться к смене [F6 / Esc]"
	for child in node.get_children(): _relabel_save_menu(child)

func _bind_session() -> void:
	session.changed.connect(_refresh)
	session.checkpoint.connect(save_manager.mark_checkpoint)
	session.sound_requested.connect(audio.play_event)
	session.customer_remark.connect(_show_customer_remark)

func _show_customer_remark(customer: Dictionary, text: String) -> void:
	if not _active or main_menu.visible or save_menu.visible or inspection.busy: return
	hud.show_aside(CustomerDialogue.speaker_name(customer), text)

func _build_trailer() -> void:
	trailer = load("res://scenes/trailer/coffee_trailer.tscn").instantiate()
	trailer.build_restoration = false
	trailer.get_node("ServiceWindow").free()
	add_child(trailer)
	TradingLocation.light_workspace(trailer)
	new_assets = ShiftNewAssets.new()
	trailer.add_child(new_assets)
	new_assets.configure(self)
	cash_drawer = new_assets.register.get_node("DrawerAssembly")
	for definition in RestorationCatalog.data().parts:
		if definition.kind != "equipment": continue
		if definition.device in ["cash", "sink"]: continue
		if definition.device == "fridge":
			fridge = ShiftFridge.new()
			fridge.position = RestorationCatalog.vector(definition.position)
			trailer.add_child(fridge)
			continue
		var device := EquipmentInstallation.new()
		device.configure(definition)
		trailer.add_child(device)
		device.set_equipment_visible(true)
		var visual := device.equipment
		visual.reparent(trailer, false)
		visual.position = RestorationCatalog.vector(definition.position)
		visual.show()
		if definition.device == "grinder": grinder_visual = visual
		if definition.device == "machine": machine_visual = visual.get_node("CoffeeMachine")
		device.queue_free()
	shutter = trailer.shell.get_node("WindowHinge")
	G.box(trailer, "NameSign", Vector3(1.23, 2.34, 0), Vector3(.045, .25, 1.9), Color("28584f"), false)
	var sign := _text(session.business_name.to_upper(), Vector3(1.26, 2.34, 0), PI/2, 42, .0024)
	sign.name = "BusinessSign"
	# Lower the opposite menu by 20 mm to clear the new curved roof shoulder.
	for point in [Vector3(1.25, 1.7, 1.44), Vector3(-1.12, 1.90, -.9)]:
		G.box(trailer, "MenuBoard", point, Vector3(.025, .75, 1.05), Color("264a41"), false)
		var label := _text("", point + Vector3(.02 if point.x > 0 else .03, 0, 0), PI/2, 22, .0021)
		menu_labels.append(label)
	for asset in [
		["res://assets/models/severny_coffee/coffee_bag.tscn", Vector3(-.83, 1.30, -.9)],
		["res://assets/models/water_15l/water_bottle.tscn", Vector3(-.83, 1.30, -1.55)]]:
		var model: Node3D = load(asset[0]).instantiate()
		model.position = asset[1]
		model.scale = Vector3.ONE * .8
		if "coffee_bag" in str(asset[0]): model.rotation.y = PI/2
		trailer.add_child(model)

func _text(copy: String, point: Vector3, yaw: float, font_size: int = 18, pixel: float = .0018) -> Label3D:
	var label := G.sign_text(trailer, copy, point, Vector3(0, yaw, 0), font_size)
	label.pixel_size = pixel
	label.font = preload("res://assets/fonts/paper_regular.ttf")
	return label

func _station(action: String, caption: String, point: Vector3, size: Vector3 = Vector3(.09, .19, .24)) -> ShiftWorkstation:
	var station := ShiftWorkstation.new()
	station.configure(self, action, caption, point, size)
	trailer.add_child(station)
	stations[action] = station
	return station

func _build_stations() -> void:
	_station("window", "Створка окна", Vector3(1.10, 1.97, .75), Vector3(.10, .18, .16))
	# The imported moving leaf delegates to the SAME authoritative window action.
	trailer.shell.get_node("WindowHinge/HatchInteraction").interaction_delegate = stations.window
	_station("shift", "Смена", Vector3(1.10, 1.57, .92))
	# Unlabelled working controls attached to the frame/wall, not floating tags.
	G.box(trailer, "WindowLatch", Vector3(1.15,1.97,.75), Vector3(.045,.16,.10), Color("354a41"), false)
	G.box(trailer, "ShiftSwitchHousing", Vector3(1.16,1.57,.92), Vector3(.04,.14,.12), Color("9ca99c"), false)
	G.box(trailer, "ShiftSwitch", Vector3(1.13,1.57,.92), Vector3(.025,.065,.065), Color("315c4b"), false)
	_station("counter", "Окно выдачи", Vector3(.51, 1.62, 0), Vector3(.10, .20, .24))
	stations.cash = new_assets.register.get_node("BodyInteraction")
	_station("machine", "Кофемашина", machine_visual.control_point("brew_left"), Vector3(.055, .055, .07))
	# A separate direct-E target at the cup, independent from the machine's
	# brew button: picking up or placing a cup never presses 'Start'.
	_station("cup_tray", "Стакан под группой", machine_visual.cup_base() + Vector3(-.11, .07, 0), Vector3(.14, .17, .14))
	stations.cup_tray.collision_layer = 0
	# Physical model controls resolve to the same existing machine operation.
	machine_visual.reparent(stations.machine)
	for control in ["power", "brew_right", "group"]:
		var collision := CollisionShape3D.new()
		collision.name = control
		var shape := BoxShape3D.new()
		shape.size = Vector3(.055, .055, .07)
		collision.shape = shape
		collision.position = stations.machine.to_local(machine_visual.control_point(control))
		stations.machine.add_child(collision)
	_station("grinder", "Кофемолка", Vector3(.72, 1.5, -1.0), Vector3(.065, .19, .20))
	# Embedded imported colliders resolve to this same existing E target.
	grinder_visual.reparent(stations.grinder)
	_station("filter", "Рожок", machine_visual.control_point("filter"), Vector3(.07, .045, .11))
	_station("dose", "Темпер", accessories.tamper.get_node("HandGrip").global_position, Vector3(.075, .13, .075))
	_station("water", "Горячая вода", machine_visual.control_point("water"), Vector3(.06, .035, .06))
	_station("steam", "Паровая трубка", machine_visual.control_point("steam"), Vector3(.06, .07, .08))
	_station("beans", "Кофе", Vector3(-.51, 1.47, -.93))
	_station("fridge", "Холодильник", Vector3(-.465, .98, .12), Vector3(.08, .16, .14))
	_station("milk", "Молоко", Vector3(-.54, .69, -.26), Vector3(.08, .20, .14))
	stations.milk.collision_layer = 0
	stations.fridge.reparent(fridge.hinge)
	stations.fridge.position = Vector3(.06,.16,-.52)
	_station("pitcher", "Питчер", accessories.pitcher.get_node("HandGrip").global_position, Vector3(.12, .13, .15))
	_station("cups", "Стаканы", Vector3(-.51, 1.45, .62))
	_station("lids", "Крышки", Vector3(-.51, 1.35, .85), Vector3(.08, .1, .18))
	_station("sugar", "Сахар", Vector3(-.51, 1.47, 1.03), Vector3(.08, .16, .16))
	_station("syrup", "Ваниль", Vector3(-.51, 1.55, .38), Vector3(.08, .16, .16))
	_station("countertop", "Место для стакана", Vector3(-.78, 1.38, -.50), Vector3(.20, .20, .19))
	_station("ready", "Выдача напитка", Vector3(.52, 1.30, .50), Vector3(.08, .12, .18))
	_station("carrier", "Держатель", Vector3(-.51, 1.43, .08))
	_station("bin", "Мусорное ведро", Vector3(-.44, .85, 1.93), Vector3(.08, .25, .20))
	_station("menu", "Меню / цены / запасы", Vector3(-.52, 1.95, -1.45), Vector3(.08, .28, .30))
	# A small rear wall shelf keeps the receiver clear of the sink, worktops,
	# upper cabinets and staff-door opening. Metre-scale original faces the aisle.
	G.box(trailer, "RadioShelf", Vector3(-.915, 1.415, 2.30), Vector3(.45, .03, .46), Color("b7b4a0"))
	for z in [2.14, 2.46]:
		G.box(trailer, "RadioShelfBracket", Vector3(-1.10, 1.34, z), Vector3(.035, .12, .025), Color("526358"), false)
	var mount := Node3D.new()
	mount.name = "RadioMount"
	mount.position = Vector3(-.88, 1.43, 2.30)
	mount.rotation.y = PI / 2
	trailer.add_child(mount)
	radio_receiver = preload("res://assets/models/radio_receiver/radio_receiver.tscn").instantiate()
	mount.add_child(radio_receiver)
	var radio_target := radio_receiver.get_node("StaticBody3D") as ShiftWorkstation
	radio_target.world = self
	radio_target.action = "radio"
	radio_target.caption = "Радиоприёмник"
	radio_target.set_meta("action", "radio")
	stations.radio = radio_target
	G.cylinder(trailer, "SugarBowl", Vector3(-.78, 1.38, 1.03), .075, .16, Color("c7c5ab"), false)
	G.cylinder(trailer, "SyrupBottle", Vector3(-.78, 1.46, .38), .044, .32, Color("8b784e"), false)
	G.cylinder(trailer, "Bin", Vector3(-.72, .68, 1.94), .18, .50, Color("526358"), false)
	new_assets.build_stock()
	var mat := G.box(trailer, "TampingMat", Vector3(.59, 1.311, -.97), Vector3(.19, .022, .17), Color("26332d"), false)
	var mat_top := G.box(mat, "InsetSurface", Vector3(0, .012, 0), Vector3(.178, .002, .158), Color("3a4c40"), false)
	for part in [mat, mat_top]:
		(part.get_child(0).material_override as StandardMaterial3D).roughness = .97
	G.box(trailer, "Carriers", Vector3(-.76, 1.35, .08), Vector3(.40, .09, .30), Color("b29968"), false)
	drinks_root = Node3D.new()
	drinks_root.name = "FinishedDrinks"
	trailer.add_child(drinks_root)
	preparation_visual = Node3D.new()
	preparation_visual.name = "PreparationObjects"
	trailer.add_child(preparation_visual)
	fridge.door_changed.connect(func(_opened: bool) -> void:
		_sync_fridge()
		if save_manager != null and (inspection == null or not inspection.busy): save_manager.mark_checkpoint("Дверца холодильника"))

func _refresh() -> void:
	if hud == null: return
	if _active and music != null and int(session.stats.sold) > 0 and music.play_achievement_once("first_sale"):
		save_manager.mark_checkpoint("Достижение: первая продажа")
	TradingLocation.update_lighting(self, session.clock)
	_sync_process_audio()
	_sync_fridge()
	new_assets.sync_register()
	hud.refresh(session)
	if session.last_message != "": hud.say(session.last_message)
	var menu := "МЕНЮ • КОФЕ С СОБОЙ\n"
	var available := session.available_menu()
	for recipe in session.catalog.recipes:
		var r: Dictionary = session.catalog.recipes[recipe]
		menu += "%s %s  %s\n" % [r.name, "Б" if r.size == "большой" else ("40" if r.drink == "espresso" else "С"), "%d ₽" % int(session.prices[recipe]) if recipe in available else "Нет в наличии"]
	for label in menu_labels: label.text = menu
	if _shutter_open != session.window_open:
		_shutter_open = session.window_open
		trailer.shell.set_hatch_open(_shutter_open)
	for child in drinks_root.get_children():
		drinks_root.remove_child(child)
		child.queue_free()
	var row := 0
	for order in session.active_orders():
		if order.carrier:
			G.box(drinks_root, "CardboardCarrier", Vector3(.86, 1.235, -.52 + row * .51), Vector3(.46, .07, .42), Color("b9a174"), false)
		for i in range(order.items.size()):
			if not order.items[i].ready: continue
			var point := Vector3(.67 + i * .16, 1.20, -.52 + row * .51)
			var cup := new_assets.cup(drinks_root, "Cup_%d_%d" % [int(order.id), i], point, true, true)
			cup.set_meta("order", order.id)
			cup.set_meta("item", i)
			var number := G.sign_text(cup, str(int(order.id)), Vector3(0, .053, .042), Vector3.ZERO, 18)
			number.pixel_size = .0012
			if i in order.packed: cup.position.y += .07
		row += 1
	_refresh_held()

func _sync_fridge() -> void:
	if fridge == null or not stations.has("milk"): return
	stations.milk.collision_layer = 2 if fridge.milk_accessible() and int(session.inventory.stock.milk) > 0 else 0
	var carton_in_hand := session.preparation.next_step(session.catalog) == "pitcher"
	fridge.milk.visible = int(session.inventory.stock.milk) > 0 and not carton_in_hand

func _sync_process_audio() -> void:
	if audio == null: return
	var playing := _active and is_instance_valid(main_menu) and not main_menu.visible and not save_menu.visible and not hud.panel.visible and not _orders_editing
	audio.set_process_sound(str(session.preparation.current.get("running", "")) if playing else "")

func _refresh_held() -> void:
	for root in [held,preparation_visual]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
	machine_visual.sync(session.equipment.machine, session.preparation.current)
	accessories.sync()
	if stations.has("cup_tray"):
		stations.cup_tray.collision_layer = 2 if str(session.preparation.current.get("handling", "")) in ["cup_held", "cup_ready_on_machine"] else 0
	if session.preparation.current.is_empty(): return
	var w: Dictionary = session.preparation.current
	new_assets.preparation(preparation_visual, held)
	if w.running == "steam":
		var steam_origin := trailer.to_local(accessories.pitcher.get_node("PourSpout").global_position)
		for i in range(3):
			var puff := G.cylinder(preparation_visual, "Steam", steam_origin + Vector3.UP * (.025 + i * .04), .010 + .004 * i, .020, Color(.76, .79, .74, .12), false)
			var mesh := puff.get_child(0) as MeshInstance3D
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(mesh.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var step := session.preparation.next_step(session.catalog)
	# Use the same actual paper cup / lid as the counter scene, not the old
	# placeholder cubes. The shared PS2+ hand follows the camera.
	if str(w.get("handling", "")) in ["cup_held", "cup_full_held", "lid_held"]:
		BaristaHand.build(held)
	if step == "pitcher":
		var carton: Node3D = load("res://assets/models/utrenniy_lug/milk_carton.tscn").instantiate()
		carton.scale = Vector3.ONE * .7
		carton.position.y = -.09
		held.add_child(carton)
		for body in carton.find_children("*", "StaticBody3D", true, false): body.collision_layer = 0


# A cosmetic, persisted handling phase between real recipe operations.
# The old recipe indices are unchanged, so an in-progress legacy save remains
# loadable without inventing new ingredient consumption.
static func handling_hint(work: Dictionary) -> String:
	match str(work.get("handling", "")):
		"cup_held": return "Стакан в руке. Поставьте его под группу кофемашины [E]"
		"cup_ready_on_machine": return "Напиток готов. Заберите стакан из кофемашины [E]"
		"cup_full_held": return "Стакан в руке. Поставьте его на столешницу слева [E]"
		"cup_on_counter": return "Стакан на столе. Добавьте ингредиенты или возьмите крышку слева"
		"lid_held": return "Крышка в руке. Наденьте её на стакан на столешнице [E]"
		"lid_attached": return "Стакан закрыт. Перенесите его на стойку выдачи [E]"
	return ""


func _set_cup_handling(phase: String, instruction: String) -> void:
	if session.preparation.current.is_empty(): return
	session.preparation.current["handling"] = phase
	session.notify(instruction)


# Advance recipe and prop state atomically for save checkpoint hooks.
# prepare_action() emits its checkpoint before returning; therefore the
# physical placement must already be valid when that checkpoint is taken.
func _advance_cup_recipe(action: String, phase: String, info: String) -> void:
	var work: Dictionary = session.preparation.current
	if work.is_empty(): return
	var previous := str(work.get("handling", ""))
	work["handling"] = phase
	if session.prepare_action(action):
		_set_cup_handling(phase, info)
	else:
		work["handling"] = previous
		session.changed.emit()


func _interact_cup_handling(action: String, next: String) -> bool:
	var work: Dictionary = session.preparation.current
	if work.is_empty(): return false
	var phase := str(work.get("handling", ""))
	match phase:
		"cup_held":
			if action == "cup_tray":
				_advance_cup_recipe("cup", "cup_in_machine", "Стакан под группой. Запустите экстракцию [E]")
				return true
		"cup_ready_on_machine":
			if action == "cup_tray":
				_set_cup_handling("cup_full_held", "Готовый стакан в руке. Поставьте на столешницу слева")
				return true
		"cup_full_held":
			if action == "countertop":
				_set_cup_handling("cup_on_counter", "Стакан на столешнице. Возьмите крышку после добавок")
				return true
		"cup_on_counter":
			if next == "lid" and action == "lids":
				_set_cup_handling("lid_held", "Крышка в руке. Наденьте её на стакан на столешнице")
				return true
		"lid_held":
			if action == "countertop":
				_advance_cup_recipe("lid", "lid_attached", "Крышка надета. Поставьте готовый стакан на выдачу")
				return true
	# Do not silently consume items or skip a physical transfer via E on
	# the old stock or machine target. Radio, fridge and other props remain free.
	if action in ["machine", "cup_tray", "cups", "countertop", "lids", "ready", "sugar", "syrup"] and phase in [
		"cup_held", "cup_ready_on_machine", "cup_full_held", "cup_on_counter", "lid_held", "lid_attached"
	]:
		if phase == "cup_on_counter" and action == next and next in ["sugar", "syrup"]: return false
		if phase == "lid_attached" and action == "ready" and next == "place": return false
		if phase == "cup_on_counter" and action == "lids" and next != "lid": return true
		return true
	if phase == "" and next == "cup" and action == "cups":
		_set_cup_handling("cup_held", "Стакан в руке. Установите его под кофемашину [E]")
		return true
	if phase == "cup_in_machine" and action == "cups": return true
	return false


func _input(event: InputEvent) -> void:
	if not _ready_for_input or not is_instance_valid(main_menu) or not is_instance_valid(save_menu): return
	if inspection.busy:
		if event.is_action_pressed("ui_cancel"): inspection.cancel(); show_pause()
		elif event.is_action_pressed("save_menu"): inspection.cancel(); open_saves()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if main_menu.visible: main_menu.back()
		elif save_menu.visible: _close_saves()
		elif hud.panel.visible: hud.request_close_panel()
		elif _orders_editing: _set_orders_editing(false)
		elif _active: show_pause()
		get_viewport().set_input_as_handled()
		return
	if main_menu.visible: return
	if event.is_action_pressed("save_menu") and _active:
		if save_menu.visible: _close_saves()
		else: open_saves()
		get_viewport().set_input_as_handled()
		return
	if save_menu.visible or hud.panel.visible or not _active: return
	if event.is_action_pressed("orders"):
		_set_orders_editing(not _orders_editing)
		get_viewport().set_input_as_handled()
		return
	if _orders_editing: return
	if event.is_action_pressed("interact") and not event.is_echo() and player.mouse_captured:
		var target := player.get_interactable()
		if target != null: target.interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("notebook"): show_help()
func _physics_process(delta: float) -> void:
	if not _ready_for_input: return
	TradingLocation.update_lighting(self, session.clock)
	var running := _active and not main_menu.visible and not save_menu.visible
	# Physical-time operations and NPCs pause with menus/dialogue/cash UI.
	if running and not hud.panel.visible and not _orders_editing:
		session.tick(delta)
		_sync_customers(delta)
		hud.refresh(session)
		_sync_process_audio()
		_sync_fridge()
		var target := player.get_interactable()
		hud.hint.text = target.get_prompt() if target != null and player.controls_enabled and player.mouse_captured else ""
		var travelled := Vector2(player.position.x - _last_foot_position.x, player.position.z - _last_foot_position.z).length()
		if player.controls_enabled and player.mouse_captured and player.is_on_floor() and travelled < .3:
			_foot_distance += travelled
			if _foot_distance >= .78:
				var inside := absf(player.position.x) < 1.2 and absf(player.position.z) < 2.8
				audio.play_footstep("wood" if inside else "concrete")
				_foot_distance = 0
	else:
		audio.set_process_sound("")
		hud.hint.text = ""
		if running and hud.panel.visible: _sync_customers(delta)
	_last_foot_position = player.position

func _sync_customers(delta: float) -> void:
	var alive: Array = []
	for c in session.customers:
		var id := int(c.id)
		alive.append(id)
		if not npc_visuals.has(id):
			var visual := ShiftCustomerVisual.new()
			npc_root.add_child(visual)
			visual.build(Color(session.catalog.config.customers.profiles[int(c.profile)].color), int(c.profile))
			visual.position = RestorationCatalog.vector(c.position)
			npc_visuals[id] = visual
		npc_visuals[id].sync(c, delta)
	for id in npc_visuals.keys():
		if id not in alive:
			npc_visuals[id].queue_free()
			npc_visuals.erase(id)

func station_available_action(station: ShiftWorkstation) -> String:
	if inspection != null and inspection.busy: return "Осмотр…"
	if station.action == "fridge" and fridge.moving: return "Открывается…" if fridge.opened else "Закрывается…"
	if session.equipment.has(station.action) and not session.shift_open and not session.equipment[station.action]:
		if accessories.inspected != "": return "Сначала верните предмет"
		if not inspection.can_reach(station.action): return "Подойдите ближе"
		return "[E] Осмотреть"
	var next := session.preparation.next_step(session.catalog)
	var phase := str(session.preparation.current.get("handling", ""))
	if station.action in ["machine", "cup_tray", "cups", "countertop", "lids", "ready", "sugar", "syrup"]:
		match phase:
			"cup_held":
				return "[E] Поставить стакан под группу" if station.action == "cup_tray" else ""
			"cup_ready_on_machine":
				return "[E] Взять стакан с напитком" if station.action == "cup_tray" else ""
			"cup_full_held":
				return "[E] Поставить стакан на стол" if station.action == "countertop" else ""
			"cup_on_counter":
				if station.action == "lids" and next == "lid": return "[E] Взять крышку"
				if station.action == next and next in ["sugar", "syrup"]: return "[E] Добавить"
				return ""
			"lid_held":
				return "[E] Надеть крышку на стакан" if station.action == "countertop" else ""
			"lid_attached":
				return "[E] Перенести на выдачу" if station.action == "ready" else ""
		if station.action in ["cup_tray", "countertop"]: return ""
	if station.action in ["filter", "dose", "pitcher"] and session.preparation.current.is_empty():
		if accessories.inspected == station.action: return "[E] Вернуть"
		if accessories.inspected == "": return "[E] Взять"
		return "Сначала верните предмет"
	match station.action:
		"radio": return "[E] Выключить радио" if music.radio_on else "[E] Включить радио"
		"fridge":
			return "[E] Закрыть" if fridge.opened else "[E] Открыть"
		"window":
			if session.window_open and session.shift_open: return "Сначала закройте смену"
			return "[E] Закрыть" if session.window_open else "[E] Открыть"
		"cash":
			if not session.cash.payment.is_empty(): return "[E] Продолжить расчёт"
			return "[E] Закрыть денежный ящик" if new_assets.register.drawer_open else "[E] Открыть денежный ящик"
		"menu", "shift", "carrier": return "[E] Использовать"
		"counter":
			if not _pickup_at_counter().is_empty(): return "[E] Выдать заказ"
			if not session.cash.payment.is_empty(): return "[E] Продолжить расчёт"
			if not session.counter_customer().is_empty(): return "[E] Поговорить"
		"machine":
			if not session.equipment.machine or next in ["install", "extract", "stop"]: return "[E] Использовать"
		"grinder":
			if not session.equipment.grinder or next == "grind": return "[E] Использовать"
		"milk":
			if fridge.milk_accessible() and next == "milk" and int(session.inventory.stock.milk) > 0: return "[E] Взять"
		"beans":
			var order := session.order_by_id(session.selected_order)
			if next == "beans" or (session.preparation.current.is_empty() and not order.is_empty() and order.paid and session.selected_item < order.items.size() and not order.items[session.selected_item].ready): return "[E] Взять"
		"pitcher":
			if next in ["pitcher", "pour"]: return "[E] Перелить молоко"
		"filter":
			if next == "filter": return "[E] Взять"
		"dose":
			if next == "dose": return "[E] Наполнить и утрамбовать"
		"steam":
			if next == "steam": return "[E] Включить пар"
			if next == "stop_steam": return "[E] Остановить пар"
		"cups":
			if next == "cup": return "[E] Взять"
		"lids":
			if next == "lid": return "[E] Установить"
		"ready":
			if next == "place": return "[E] Поставить стакан"
		"bin": return "[E] Выбросить напиток" if not session.preparation.current.is_empty() else "[E] Использовать"
		_:
			if next == station.action: return "[E] Использовать"
	return ""

func interact_station(station: ShiftWorkstation) -> void:
	if inspection.busy: return
	var action := station.action
	if session.equipment.has(action) and not session.shift_open and not session.equipment[action]:
		if station_available_action(station).begins_with("[E]"): inspection.start(action)
		return
	var next := session.preparation.next_step(session.catalog)
	if _interact_cup_handling(action, next): return
	if action in ["filter", "dose", "pitcher"] and session.preparation.current.is_empty():
		accessories.take_or_return(action)
		return
	match action:
		"radio":
			music.toggle_radio()
			save_manager.mark_checkpoint("Состояние радио")
		"window": session.toggle_window()
		"shift": show_shift()
		"counter": show_customer()
		"cash":
			if not session.cash.payment.is_empty(): show_cash()
			else: new_assets.register.toggle_drawer()
		"machine":
			if next in ["install", "extract", "stop"]:
				if next == "stop" and str(session.preparation.current.get("handling", "")) == "cup_in_machine" and session.catalog.recipes[session.preparation.current.recipe].drink == "espresso":
					_advance_cup_recipe("stop", "cup_ready_on_machine", "Эспрессо готов. Возьмите стакан из кофемашины")
				else: session.prepare_action(next)
			else: session.notify("Кофемашина готова. " + str(STEP_HINTS.get(next, "Выберите оплаченный заказ")))
		"grinder":
			if next == "grind": session.prepare_action("grind")
			else: session.notify("Кофемолка готова. Сначала возьмите кофе")
		"fridge":
			fridge.toggle()
			session.notify("Холодильник открыт. Молоко на нижней полке" if fridge.opened else "Холодильник закрыт")
		"milk":
			if not fridge.milk_accessible(): session.notify("Сначала откройте дверцу холодильника")
			else: session.prepare_action("milk")
		"dose":
			if next == "dose": accessories.play("dose")
			session.prepare_action(action)
		"beans", "filter", "water", "sugar", "syrup":
			if action == "water" and next == "water" and str(session.preparation.current.get("handling", "")) == "cup_in_machine":
				_advance_cup_recipe("water", "cup_ready_on_machine", "Американо готов. Возьмите стакан из кофемашины")
			else: session.prepare_action(action)
		"pitcher":
			if next == "pour": accessories.play("pour")
			if next == "pour" and str(session.preparation.current.get("handling", "")) == "cup_in_machine":
				_advance_cup_recipe("pour", "cup_ready_on_machine", "Напиток готов. Возьмите стакан из кофемашины")
			else: session.prepare_action("pour" if next == "pour" else "pitcher")
		"steam": session.prepare_action("stop_steam" if next == "stop_steam" else "steam")
		"cups": session.prepare_action("cup")
		"lids": session.prepare_action("lid")
		"ready":
			if not session.preparation.current.is_empty() and str(session.preparation.current.get("handling", "")) == "lid_attached":
				session.preparation.current["handling"] = ""
			session.prepare_action("place")
		"carrier": show_carrier()
		"bin":
			if not session.preparation.current.is_empty():
				session.discard_drink(int(session.preparation.current.order), int(session.preparation.current.index))
			else: show_discard()
		"menu": show_menu_board()

func _panel(title: String, body: String, actions: Array = [], is_dialogue: bool = false, can_close: bool = true) -> void:
	inspection.cancel()
	_set_orders_editing(false)
	hud.show_panel(title, body, actions, is_dialogue, can_close)
	player.controls_enabled = false
	player.set_mouse_capture(false)
	_sync_process_audio()

func _resume_controls() -> void:
	if _cash_panel_opened:
		new_assets.register.close_drawer()
		_cash_panel_opened = false
	if _active and not main_menu.visible and not save_menu.visible and not inspection.busy:
		player.controls_enabled = true
		player.set_mouse_capture(true)
	_sync_process_audio()

func _set_orders_editing(value: bool) -> void:
	_orders_editing = value
	hud.set_orders_editing(value)
	player.controls_enabled = not value
	player.set_mouse_capture(not value)
	_sync_process_audio()

func _select_order_item(order_id: int, index: int) -> void:
	if not _orders_editing or hud.panel.visible: return
	if session.select_item(order_id,index): _set_orders_editing(false)

func _call_order_from_sidebar(order_id: int) -> void:
	if not _orders_editing or hud.panel.visible: return
	session.call_order(order_id)
	_set_orders_editing(false)

func show_shift() -> void:
	var body := "Время открытия и закрытия выбираете вы.\nОкно: %s\nВода: %d мл · кофе: %d г · молоко: %d мл" % ["открыто" if session.window_open else "закрыто", int(session.inventory.stock.water), int(session.inventory.stock.coffee), int(session.inventory.stock.milk)]
	_panel("ТОРГОВАЯ СМЕНА", body, [
		{"label": "Закрыть смену" if session.shift_open else "Открыть смену", "call": _toggle_shift},
		{"label": "Посмотреть отчёт", "call": show_report}])

func _toggle_shift() -> void:
	var closing := session.shift_open
	var ok := session.close_shift() if closing else session.open_shift()
	if ok and closing:
		music.set_context("day_end")
		if session.report().profit > 0 and music.play_achievement_once("first_profitable_shift"):
			save_manager.mark_checkpoint("Достижение: первая прибыль")
		show_report()
	elif ok:
		music.set_context("trade")
		if music.play_opening_once():
			save_manager.mark_checkpoint("Первая смена: музыкальная заставка")
		hud.close_panel()
	else: _panel("СМЕНА", session.last_message, [{"label": "Вернуться к подготовке", "call": hud.close_panel}])

func _pickup_at_counter() -> Dictionary:
	for c in session.customers:
		if c.state == "pickup" and CoffeeShiftSession._distance(c.position, session.catalog.config.points.counter) < .15:
			return c
	return {}

func show_customer() -> void:
	var pickup := _pickup_at_counter()
	if not pickup.is_empty():
		var order_id := int(pickup.order)
		var customer_id := int(pickup.id)
		_panel(CustomerDialogue.speaker_name(pickup), "Покупатель подошёл за заказом №%03d." % order_id, [{"label": "Передать через окно", "call": func() -> void:
			session.serve_order(order_id, customer_id)
			hud.close_panel()}], true)
		return
	if not session.cash.payment.is_empty():
		show_cash()
		return
	var c := session.counter_customer()
	if c.is_empty():
		session.notify("Сейчас у окна никого нет. Готовый заказ можно вызвать справа через Tab")
		return
	var captions := PackedStringArray()
	for item in c.items:
		captions.append(session.catalog.caption(item))
	var text: String = session.catalog.config.customers.profiles[int(c.profile)].greeting + ", ".join(captions) + ".\nВсё верно?"
	var customer_id := int(c.id)
	_panel(CustomerDialogue.speaker_name(c), text, [{"label": "Повторить состав и подтвердить заказ", "call": func() -> void:
		if session.confirm_order(customer_id): show_cash()
		else: hud.close_panel()}], true)

func show_cash() -> void:
	_cash_panel_opened = true
	new_assets.register.open_drawer()
	new_assets.sync_register()
	if session.cash.payment.is_empty():
		_panel("КАССА", "Разменная касса: %d ₽. Оплаченных активных заказов: %d / 3.\nДля расчёта сначала подтвердите заказ покупателя." % [session.cash.balance(), session.paid_orders().size()])
		return
	var p: Dictionary = session.cash.payment
	var body := "Заказ №%03d\nК оплате: %d ₽\nПокупатель передал: %d ₽\nСдача: %d ₽\nВ лотке сдачи: %d ₽\n\n%s" % [int(p.order), int(p.total), int(p.tender), int(p.tender) - int(p.total), session.cash.selected_total(), session.last_message]
	var actions: Array = []
	if not p.accepted:
		actions.append({"label": "Принять купюры", "disabled": not session.cash.can_make_change(), "call": func() -> void: session.accept_cash(); show_cash()})
		if not session.cash.can_make_change():
			body += "\nВ ящике не хватает номиналов для точной сдачи."
			actions.append({"label": "Попросить оплатить без сдачи", "call": func() -> void: session.cash.request_exact(); show_cash()})
		actions.append({"label": "Отменить до приёма наличных", "call": func() -> void: session.cancel_payment(); hud.close_panel()})
	else:
		for denomination in ShiftCashRegister.DENOMINATIONS:
			var value := int(denomination)
			var count := int(session.cash.till.get(str(value), 0)) + int(p.notes.get(str(value), 0)) - int(p.selected.get(str(value), 0))
			actions.append({"label": "Ячейка %d ₽\nОсталось: %d" % [value, count], "grid": true, "disabled": count <= 0, "call": func() -> void: session.select_change(value); show_cash()})
		actions.append({"label": "Вернуть выбранное в ящик", "call": func() -> void: session.cash.reset_change(); show_cash()})
		actions.append({"label": "Передать сдачу и завершить расчёт", "call": func() -> void:
			if session.finalize_payment(): hud.close_panel()
			else: show_cash()})
	_panel("НАЛИЧНЫЙ РАСЧЁТ", body, actions)

func show_carrier() -> void:
	var actions: Array = []
	for order in session.paid_orders():
		if order.items.size() < 2: continue
		for i in range(order.items.size()):
			var id := int(order.id)
			var index := i
			actions.append({"label": "В держатель: №%03d · стакан %d" % [id, index + 1], "disabled": not order.items[index].ready or index in order.packed, "call": func() -> void:
				session.pack_cup(id, index)
				hud.close_panel()})
	_panel("КАРТОННЫЕ ДЕРЖАТЕЛИ", "По одному поместите готовые стаканы в держатель. Для одного напитка он не нужен.", actions)

func show_discard() -> void:
	var actions: Array = []
	for order in session.paid_orders():
		for i in range(order.items.size()):
			if not order.items[i].ready: continue
			var id := int(order.id)
			var index := i
			actions.append({"label": "Выбросить: №%03d · стакан %d" % [id, index + 1], "call": func() -> void:
				session.discard_drink(id, index)
				hud.close_panel()})
	_panel("ПЕРЕДЕЛКА НАПИТКА", "Выбрасывание расходует новые ингредиенты на переделку. Остальные оплаченные заказы защищены резервом.", actions)

func show_menu_board() -> void:
	var body := "Свободные запасы (с учётом оплаченных заказов):\n"
	for key in session.inventory.stock:
		body += "%s: %d\n" % [ShiftRecipeCatalog.STOCK_LABELS[key], session.inventory.available(key)]
	var actions: Array = []
	for recipe in session.prices:
		var key: String = recipe
		var item := {"recipe": key, "sugar": false, "syrup": false}
		actions.append({"label": "%s · %d ₽ → +10 ₽" % [session.catalog.caption(item), int(session.prices[key])], "call": func() -> void: session.set_price(key, int(session.prices[key]) + 10); show_menu_board()})
		actions.append({"label": "Уменьшить цену на 10 ₽", "call": func() -> void: session.set_price(key, int(session.prices[key]) - 10); show_menu_board()})
	_panel("ДОСКА МЕНЮ / ЗАПАСЫ", body, actions)

func show_report() -> void:
	var r := session.report()
	var errors := "не обнаружены"
	if not r.errors.is_empty():
		errors = ""
		for cause in r.errors: errors += "\n%s: %d" % [cause, int(r.errors[cause])]
	var body := "%s · день %d\n\nВыполнено заказов: %d\nПродано напитков: %d\nВыручка: %d ₽\nПолучено наличными: %d ₽\nВозвращено сдачи: %d ₽\nСебестоимость, включая потери: %.2f ₽\n   ингредиенты: %.2f ₽ · упаковка: %.2f ₽\nПотери от переделок: %.2f ₽\nПрибыль: %.2f ₽\nСамый популярный: %s\n\nОшибки: %s" % [r.business_name, int(r.day), int(r.completed), int(r.sold), int(r.revenue), int(r.received), int(r.change), float(r.cost)/100, float(r.ingredient_cost)/100, float(r.packaging_cost)/100, float(r.losses)/100, float(r.profit)/100, r.popular_drink, errors]
	_panel("ОТЧЁТ СМЕНЫ", body)

func show_help() -> void:
	var text := "[Tab] — выбрать оплаченный напиток. После оплаты начните с пакета кофе.\n\nРожок: зёрна → кофемолка → взять рожок → утрамбовать на коврике → установить в кофемашину.\n\nСтакан: взять из стопки [E], подойти к кофемашине и поставить под группу [E]. Запустить экстракцию [E], ориентироваться по секундомеру в верхней части экрана (8–12 с), остановить [E].\n\nАмерикано: после экстракции добавить горячую воду из крана кофемашины. Для латте и капучино: молоко → питчер → паровая трубка → остановить пар → влить молоко.\n\nПосле приготовления: взять стакан из кофемашины [E] → поставить на столешницу слева [E] → при необходимости добавить сахар/сироп → взять крышку со стопки [E] → надеть на стакан на столешнице [E] → перенести стакан на стойку выдачи [E].\n\nВЫДАЧА: справа нажать Tab → Вызвать № заказа → дождаться клиента у окна → навести на окно [E] → Передать через окно. Для 2–3 стаканов сначала заполнить держатель.\n\n[N] — открыть эту справку повторно. Капучино: 4–7 с пара, латте: 2–4 с."
	_panel("СПРАВОЧНИК БАРИСТА", text)

func capture_snapshot() -> Dictionary:
	return {"trade": session.snapshot(), "world": {"position": [player.position.x, player.position.y, player.position.z],
		"yaw": player.rotation.y, "pitch": player.pitch,
		"fridge_opened": inspection.saved_fridge_opened(), "staff_door_opened": trailer.get_node("StaffDoor").opened,
		"assets": new_assets.snapshot(), "audio": music.snapshot_audio()}}

func validate_snapshot(data: Dictionary) -> bool:
	if not data.get("trade") is Dictionary or not session.validate(data.trade) or not data.get("world") is Dictionary: return false
	var w: Dictionary = data.world
	if w.has("audio") and (not w.audio is Dictionary or not music.validate_audio(w.audio)): return false
	if w.has("assets") and not new_assets.valid_snapshot(w.assets): return false
	if not CoffeeShiftSession._valid_point(w.get("position")): return false
	for key in ["fridge_opened","staff_door_opened"]:
		if w.has(key) and not w[key] is bool: return false
	for key in ["yaw", "pitch"]:
		if (not w.get(key) is float and not w.get(key) is int) or not is_finite(float(w[key])): return false
	return absf(float(w.position[0])) < 17.2 and absf(float(w.position[2])) < 15.2 and float(w.position[1]) > -.5 and float(w.position[1]) < 2 and absf(float(w.pitch)) <= 1.4

func apply_snapshot(data: Dictionary) -> bool:
	if not validate_snapshot(data): return false
	hud.clear_aside()
	inspection.cancel()
	if not session.restore(data.trade): return false
	music.restore_audio(data.world.get("audio", {}))
	# Cancel any in-flight animation and restore the authoritative saved window immediately.
	_shutter_open = session.window_open
	trailer.shell.set_hatch_open(_shutter_open, false)
	accessories.reset()
	new_assets.restore(data.world.get("assets",{}))
	_cash_panel_opened = hud.panel.visible and not session.cash.payment.is_empty()
	player.position = RestorationCatalog.vector(data.world.position)
	player.velocity = Vector3.ZERO
	player.rotation.y = float(data.world.yaw)
	player.pitch = float(data.world.pitch)
	player.camera.rotation.x = player.pitch
	_last_foot_position = player.position
	_foot_distance = 0
	fridge.restore_opened(bool(data.world.get("fridge_opened",false)))
	var in_portal := absf(player.position.x) < .79 and absf(player.position.z-2.78) < .38
	trailer.get_node("StaffDoor").restore_opened(bool(data.world.get("staff_door_opened",in_portal)))
	for id in npc_visuals:
		npc_visuals[id].free()
	npc_visuals.clear()
	_sync_customers(0)
	hud.tasks.sync(session, true)
	_refresh()
	return true

func new_game(career_id: int, overwrite: bool = false, resume_after_start: bool = true) -> bool:
	if career_id < 1 or career_id > 3: return false
	var used := false
	for row in save_manager.list_slots(career_id): used = used or row.occupied
	if used and not overwrite:
		main_menu.show_error("Подтвердите перезапись выбранной карьеры")
		return false
	var fresh := CoffeeShiftSession.new()
	var initial := {"trade": fresh.snapshot(), "world": {"position": [0, .4, .65], "yaw": -PI/2, "pitch": -.15}}
	if not validate_snapshot(initial):
		main_menu.show_error("Начальное состояние не прошло проверку")
		return false
	if save_manager.start_career(career_id, initial, "Новая карьера: prototype_start") != OK:
		main_menu.show_error("Не удалось сохранить новую карьеру")
		return false
	game_settings.last_career = career_id
	if not _test: game_settings.save_to_disk()
	if resume_after_start: resume_game()
	return true

func continue_game(career_id: int) -> void:
	var latest := save_manager.latest(career_id)
	if latest.is_empty() or not save_manager.load_slot(career_id, str(latest.kind), int(latest.slot)):
		main_menu.show_error("Нет исправного сохранения этой карьеры")
		return
	game_settings.last_career = career_id
	if not _test: game_settings.save_to_disk()
	resume_game()

func switch_career(career_id: int) -> void:
	if career_id == save_manager.career or career_id < 1 or career_id > 3: return
	if save_manager.save_auto("Перед переключением карьеры") != OK:
		save_menu.refresh()
		save_manager.feedback.emit("Не удалось сохранить текущую карьеру. Переключение отменено.")
		return
	var latest := save_manager.latest(career_id)
	var switched := false
	if latest.is_empty():
		for row in save_manager.list_slots(career_id):
			if row.occupied:
				save_menu.refresh()
				save_manager.feedback.emit("Нет исправного сохранения этой карьеры. Файлы сохранены; новая игра доступна из главного меню.")
				return
		switched = new_game(career_id, false, false)
	else:
		switched = save_manager.load_slot(career_id, str(latest.kind), int(latest.slot))
	if switched and game_settings.last_career != career_id:
		game_settings.last_career = career_id
		if not _test: game_settings.save_to_disk()
	save_menu.refresh()
	if not switched:
		save_manager.feedback.emit("Не удалось переключить карьеру. Текущий прогресс сохранён.")

func show_title() -> void:
	inspection.cancel()
	hud.clear_aside()
	_active = false
	_saves_from_pause = false
	_orders_editing = false
	hud.set_orders_editing(false)
	hud.hide()
	player.controls_enabled = false
	player.set_mouse_capture(false)
	save_manager.autosave_enabled = false
	main_menu.show_title()
	music.set_context("menu")
	_sync_process_audio()

func show_pause() -> void:
	inspection.cancel()
	hud.clear_aside()
	_orders_editing = false
	hud.set_orders_editing(false)
	hud.hide()
	player.controls_enabled = false
	player.set_mouse_capture(false)
	save_manager.autosave_enabled = false
	main_menu.show_pause()
	_sync_process_audio()

func resume_game() -> void:
	hud.clear_aside()
	_saves_from_pause = false
	_orders_editing = false
	hud.set_orders_editing(false)
	main_menu.hide()
	hud.show()
	hud.dismiss_panel()
	save_menu.hide()
	_active = true
	music.set_context("trade")
	save_manager.autosave_enabled = not _test
	_resume_controls()

func open_saves() -> void:
	inspection.cancel()
	hud.clear_aside()
	_orders_editing = false
	hud.set_orders_editing(false)
	hud.dismiss_panel()
	player.controls_enabled = false
	player.set_mouse_capture(false)
	save_menu.refresh()
	save_menu.show()
	save_manager.autosave_enabled = false
	_sync_process_audio()

func _open_saves_from_pause() -> void:
	_saves_from_pause = true
	main_menu.hide()
	open_saves()

func _close_saves() -> void:
	save_menu.hide()
	if _saves_from_pause:
		_saves_from_pause = false
		show_pause()
	else:
		save_manager.autosave_enabled = not _test
		_resume_controls()

func apply_settings() -> void:
	game_settings.apply_to_game(player, hud, music)
	hud.set_dialogue_preferences(game_settings.dialogue_word_reveal, game_settings.dialogue_word_interval)
	if audio != null: audio.set_volume(game_settings.effects_volume)
	if not _test: game_settings.save_to_disk()

func return_to_title() -> void:
	if _active and save_manager.save_auto("Главное меню") != OK:
		main_menu.show_error("Не удалось сохранить прогресс")
		return
	show_title()

func quit_game() -> void:
	inspection.cancel()
	if _active and save_manager.save_auto("Выход") != OK:
		main_menu.show_error("Не удалось сохранить прогресс; выход отменён")
		return
	audio.stop_all()
	music.stop_all()
	await get_tree().process_frame
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _ready_for_input: quit_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _ready_for_input and inspection.busy:
		inspection.cancel()
		show_pause()

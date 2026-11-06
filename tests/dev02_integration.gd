extends SceneTree
## Real scene, input, raycasts, every physical task and pickup, on-disk saves.
## Test mode prevents production autosaves; this runner uses a fresh directory.
var checks := 0
var failures := 0
var level: Node3D
var state: RestorationState
var player: CoffeeShiftPlayer
var shots := ""
var test_directory := ""
var saved_partial := 0.0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			shots = argument.trim_prefix("--screenshots=")
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+label)
	else:
		print("PASS: "+label)

func _frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)

func _tap(action: StringName) -> void:
	_action(action,true)
	await _frames(2)
	_action(action,false)
	await _frames(2)

func _place(point: Vector3, aim: Vector3) -> void:
	player.position = point
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(aim)
	await _frames(3)

func _target(part: InspectablePart) -> void:
	var point := part.global_position
	var aim := point
	if part is RepairablePart:
		aim += part.target_offset
	var from: Vector3
	if point.x>1.2:
		from = Vector3(2.55,.02,point.z)
	elif point.x < -1.2:
		from = Vector3(-2.55,.02,point.z)
	elif point.z < -2.72:
		from = Vector3(0,.02,-4.5)
	elif point.z > 2.7:
		from = Vector3(1.2,.02,3.95) if point.x<-.3 else Vector3(0,.02,4.05)
	elif absf(point.x)<.1 and point.y<.5:
		from = Vector3(0,.41,point.z+.65)
	else:
		from = Vector3(0,.41,clampf(point.z,-1.9,1.9))
	await _place(from,aim)
	_check(player.get_interactable()==part,"ray reaches work: "+str(part.part_key))

func _pickup(tool_id: StringName) -> WorkshopPickup:
	for pickup in level.pickups:
		if pickup.tool_id==tool_id and pickup.material_id=="":
			return pickup
	return null

func _take(pickup: WorkshopPickup, replacement: bool = false) -> void:
	var point := pickup.global_position
	var from := Vector3(3.0,.02,point.z) if point.x>0 else Vector3(-3.0,.02,point.z)
	var aim := point+Vector3(0,.12,0) if pickup.tool_id==&"cleaning_kit" else point
	await _place(from,aim)
	_check(player.get_interactable()==pickup,"physical pickup reachable: "+str(pickup.name))
	await _tap("replace_pickup" if replacement else "interact")
	_check(pickup.taken and not pickup.visible,"physical pickup disappears once: "+str(pickup.name)+(" / "+level.hud.message.text if not pickup.taken else ""))

func _tool(id: StringName) -> void:
	if id==&"":
		return
	if not state.has_tool(id):
		await _take(_pickup(id),not state.belt.slots.has(""))
	var slot := state.belt.slots.find(str(id))
	if slot>=0:
		await _tap("tool_slot_%d"%(slot+1))
	_check(state.belt.active_tool()==id,"correct selected tool: "+str(id))

func _work(part: InspectablePart) -> void:
	var step := state.current_step(part.element_id)
	await _tool(StringName(step.get("tool","")))
	await _target(part)
	var phase := state.phase_of(part.element_id)
	_action("interact",true)
	# Accelerate elapsed game time; rules still run through physics and held E.
	Engine.time_scale = 8
	await _frames(ceili(float(step.get("seconds",3.0))*60/8)+4)
	Engine.time_scale = 1
	_action("interact",false)
	await _frames(3)
	_check(state.phase_of(part.element_id)==phase+1,"held E completes exactly one phase: "+str(part.part_key))

func _shot(name: String) -> void:
	if shots=="" or DisplayServer.get_name()=="headless":
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots)
	root.get_texture().get_image().save_png(shots.path_join(name+".png"))

func _new_level() -> void:
	level = load("res://scenes/main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	state = level.state
	player = level.player
	level.save_manager.autosave_enabled = false
	await _frames(4)

func _run() -> void:
	test_directory = "user://dev02_tests_"+str(OS.get_process_id())+"_"+str(int(Time.get_unix_time_from_system()*1000000))
	await _new_level()
	level.save_manager.directory = test_directory
	_check(level.hud.notebook != null and level.hud.hint != null and level.save_menu != null,"HUD and F6 menu initialized")
	_check(level.validate_snapshot(level.capture_snapshot()),"initial complete world snapshot validates")
	_check(level.parts.size()>=20 and level.pickups.size()==13,"all restoration parts and physical supplies instantiated")
	await _place(Vector3(3.2,.02,3.8),Vector3(0,1.3,0))
	await _shot("01-trailer-before")
	await _place(Vector3(0,.02,4.6),Vector3(0,1.35,2.78))
	_check(player.get_interactable() is TrailerDoor,"door accessible from ramp")
	await _tap("interact")
	await _frames(45)
	_check(level.trailer.get_node("StaffDoor").opened,"door opens before full traversal")
	await _tap("inspect_mode")
	for part in level.parts:
		await _target(part)
		await _tap("interact")
		_check(state.status_of(part.element_id)!=RestorationState.Status.UNINSPECTED,"E inspects "+str(part.part_key))
	var discovered := state.notebook_entries().size()
	_check(discovered==level.parts.size()-1,"healthy frame creates no repair task")
	await _target(level.trailer.get_node("ServiceWindow"))
	await _tap("interact")
	_check(state.notebook_entries().size()==discovered,"repeat E inspection cannot duplicate task")
	await _place(Vector3(2.5,.02,2.8),Vector3(1.18,1.3,0))
	await _shot("02-inspection")
	await _tap("notebook")
	_check(level.hud.notebook.visible and not player.controls_enabled,"paper notebook locks movement")
	if DisplayServer.get_name() != "headless":
		for spread in range(level.hud.notebook.page_count()):
			level.hud.notebook.spread = spread
			level.hud.notebook.refresh()
			await _frames(2)
			for page in [level.hud.notebook.notes,level.hud.notebook.entries]:
				_check(page.get_content_height()<=page.size.y+4,"paper text fits without scrolling: spread %d"%spread)
	else:
		print("INFO: font layout checked on GL; headless glyph metrics differ from rendered text")
	level.hud.notebook.spread = 0
	level.hud.notebook.refresh()
	var selected := state.belt.selected
	await _tap("tool_slot_5")
	_check(state.belt.selected==selected,"notebook blocks tool selection")
	await _tap("ui_right")
	await _frames(20)
	_check(level.hud.notebook.spread==1,"keyboard turns a physical paper spread")
	await _shot("05-paper-notebook")
	await _tap("notebook")
	for pickup in level.pickups:
		if pickup.material_id!="":
			await _take(pickup)
	var window: InspectablePart = level.trailer.get_node("ServiceWindow")
	await _tool(&"brush")
	await _target(window)
	var progress := state.progress_of(window.element_id)
	_action("interact",true)
	await _frames(20)
	_action("interact",false)
	_check(state.progress_of(window.element_id)==progress,"wrong held tool blocks actual window interaction")
	await _tool(&"cleaning_kit")
	await _target(window)
	_action("interact",true)
	await _frames(30)
	_action("interact",false)
	await _frames(3)
	progress = state.progress_of(window.element_id)
	_check(progress>0 and progress<1,"held E leaves visible partial window cleaning")
	await _shot("04-cleaning")
	saved_partial = progress
	_check(level.save_manager.save_slot("manual",2)==OK,"manual slot 2 saves actual partial cleaning and physical items")
	await _frames(15)
	_check(state.progress_of(window.element_id)==progress,"released E preserves partial progress")
	_action("interact",true)
	await _frames(5)
	await _tap("notebook")
	progress = state.progress_of(window.element_id)
	await _frames(10)
	_check(state.progress_of(window.element_id)==progress,"notebook interrupts held work")
	await _tap("notebook")
	await _frames(5)
	_check(state.progress_of(window.element_id)==progress,"closing notebook cannot resume a stale hold")
	_action("interact",false)
	# Fill five slots and exercise a physical sixth-tool replacement.
	for id in ["scraper","screwdriver","wrench"]:
		await _tool(StringName(id))
	_check(not state.belt.slots.has("") and state.belt.slots.size()==5,"five physical tools fill belt")
	var removed := state.belt.active_tool()
	var roller := _pickup(&"roller")
	await _take(roller,true)
	_check(not state.has_tool(removed) and _pickup(removed).visible,"replacement returns previous physical tool to its stand")
	_check(state.belt.slots.size()==5,"replacement cannot increase belt capacity")
	await _tap("tool_slot_1")
	await _frames(22)
	await _shot("03-tool-belt")
	await _tap("tool_slot_5")
	await _tap("tool_next")
	_check(state.belt.selected==0,"wheel wraps slots via InputMap")
	await _frames(180)
	_check(not level.hud.belt_panel.visible,"belt panel hides after inactivity")
	# All clean/repair tasks are independent except declared surface dependencies.
	var last: InspectablePart
	for part in level.parts:
		if part.task.healthy:
			continue
		last = part
		while state.status_of(part.element_id)!=RestorationState.Status.RESTORED:
			var old_phase := state.phase_of(part.element_id)
			if part==level.parts[-1] and old_phase==part.task.steps().size()-1:
				_check(not state.ready_for_opening,"last equipment check still gates readiness")
			await _work(part)
			if state.phase_of(part.element_id)==old_phase:
				break
	_check(state.ready_for_opening and not state.readiness().values().has(false),"all eight mandatory categories set readiness")
	_check(not window.get_node("Dirt").visible,"original 3D window remains clean")
	_check(level.hud.notebook._entry_text(state.notebook_entries()[0]).contains("[s]"),"completed paper record is automatically struck through")
	var checked: Dictionary = level.capture_snapshot()
	_check(level.validate_snapshot(checked),"fully restored world snapshot validates")
	await _place(Vector3(0,.41,1.8),Vector3(.8,1.55,-1.4))
	await _shot("06-installed-equipment")
	await _place(Vector3(3.2,.02,3.8),Vector3(0,1.3,0))
	await _tap("inspect_mode")
	await _shot("07-trailer-after")
	await _save_checks()
	level.queue_free()
	await _frames(3)
	await _new_level()
	level.save_manager.directory = test_directory
	_check(not state.ready_for_opening,"fresh scene starts unrestored without session objects")
	_check(level.save_manager.load_slot(1,"manual",1),"fresh scene loads on-disk restoration save")
	_check(state.ready_for_opening and not level.trailer.get_node("ServiceWindow/Dirt").visible,"disk load reconstructs clean 3D world and ready equipment")
	var count := state.notebook_entries().size()
	var nodes := level.find_children("*","WorkshopPickup",true,false).size()
	_check(level.save_manager.load_slot(1,"manual",1) and level.save_manager.load_slot(1,"manual",1),"same save can be loaded repeatedly")
	_check(state.notebook_entries().size()==count and level.find_children("*","WorkshopPickup",true,false).size()==nodes,"loads duplicate neither tasks nor physical items")
	level.queue_free()
	await _frames(3)
	print("DEV-02 INTEGRATION RESULT: %d checks; %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)

func _save_checks() -> void:
	var manager: RestorationSaveManager = level.save_manager
	state.checkpoint.emit("Контрольное событие")
	manager.autosave_enabled = true
	await _frames(45)
	manager.autosave_enabled = false
	_check(manager.latest(1).get("kind","")=="auto","significant checkpoint triggers a real delayed autosave")
	manager.autosave_enabled = true
	manager._process(RestorationSaveManager.AUTO_INTERVAL+.01)
	manager.autosave_enabled = false
	_check(manager.latest(1).get("reason","")=="Интервал 120 секунд","periodic clock triggers autosave independently of checkpoints")
	await _tap("save_menu")
	_check(level.save_menu.visible and not player.controls_enabled,"F6 opens career and slot menu")
	var selected := state.belt.selected
	await _tap("tool_slot_3")
	_check(state.belt.selected==selected,"save menu blocks tool changes")
	level.save_menu.careers.grab_focus()
	await _tap("save_menu")
	_check(not level.save_menu.visible and player.controls_enabled,"F6 closes save menu despite focused GUI control")
	_check(manager.save_slot("manual",1)==OK,"manual save writes a valid versioned snapshot")
	_check(manager.save_slot("manual",1)==ERR_ALREADY_EXISTS,"manual overwrite requires confirmation")
	_check(manager.save_slot("manual",1,true)==OK,"confirmed overwrite keeps a verified backup")
	level.save_menu._save(1,false)
	_check(level.save_menu.confirmation.visible,"occupied manual slot opens an overwrite confirmation")
	level.save_menu.confirmation.hide()
	var path := manager.slot_path(1,"manual",1)
	_check(FileAccess.file_exists(path+".bak"),"last good primary exists as backup")
	var original := FileAccess.get_file_as_string(path)
	_check(manager.load_slot(1,"manual",2),"partial snapshot loads from disk")
	var window: InspectablePart = level.trailer.get_node("ServiceWindow")
	_check(is_equal_approx(state.progress_of(window.element_id),saved_partial) and not state.ready_for_opening,"load restores actual partial progress without readiness")
	_check(is_equal_approx(float(window.get_node("Dirt").material_override.get_shader_parameter("cleaned")),saved_partial),"loaded fractional dirt matches the 3D shader")
	await _target(window)
	_action("interact",true)
	await _frames(4)
	_check(manager.load_slot(1,"manual",2),"load interrupts active held work")
	await _frames(8)
	_check(is_equal_approx(state.progress_of(window.element_id),saved_partial),"a stale held E cannot keep working after load")
	_action("interact",false)
	_check(manager.load_slot(1,"manual",1) and state.ready_for_opening,"complete checkpoint restores all 3D changes again")
	# Simulated interruption: an incomplete temp cannot damage either good copy.
	_write(path+".tmp","{interrupted")
	_check(manager.load_slot(1,"manual",1) and state.ready_for_opening,"interrupted temp preserves primary")
	_write(path,"{truncated")
	_check(manager.read_slot(1,"manual",1).get("recovered",false) and manager.load_slot(1,"manual",1),"corrupt primary recovers verified backup")
	_write(path,original)
	for i in range(5):
		_check(manager.save_auto("Тест ротации")==OK,"cyclic autosave %d"%i)
	var slots := manager.list_slots(1)
	var auto_count := 0
	for row in slots:
		if row.kind=="auto" and row.valid:
			auto_count+=1
	_check(slots.size()==6 and auto_count==3,"exactly three auto and three manual slot addresses per career")
	var first := state.snapshot()
	level.switch_career(2)
	_check(manager.career==2 and not state.ready_for_opening and state.notebook_entries().is_empty(),"second career begins with independent restoration")
	state.inspect(&"trailer_01.body_service")
	_check(manager.save_slot("manual",1)==OK,"career 2 owns a separate manual slot 1")
	var second := state.snapshot()
	level.switch_career(1)
	_check(manager.career==1 and state.snapshot()==first,"switching back restores career 1 exactly")
	level.switch_career(2)
	_check(state.snapshot()==second,"career 2 retains its own discovered defect")
	level.switch_career(3)
	_check(manager.career==3 and state.notebook_entries().is_empty(),"third career is independent")
	_check(manager.save_slot("manual",4)==ERR_INVALID_PARAMETER,"fourth slot rejected")
	_check(not manager.load_slot(4,"manual",1),"fourth career rejected")
	var wrong := manager.slot_path(3,"manual",1)
	_write(wrong,original)
	_check(manager.read_slot(3,"manual",1).is_empty(),"copied career-1 file cannot load as career 3")
	DirAccess.remove_absolute(wrong)
	level.switch_career(1)
	_check(state.ready_for_opening,"return to ready career 1")
	var before := state.snapshot()
	_write(path,"{bad primary")
	_write(path+".bak","{bad backup")
	_check(not manager.load_slot(1,"manual",1) and state.snapshot()==before,"two corrupt copies fail without changing the world")
	_write(path,original)
	var envelope: Dictionary = JSON.parse_string(original)
	envelope.payload += " "
	_write(path,JSON.stringify(envelope))
	_check(manager.read_slot(1,"manual",1).is_empty(),"payload checksum catches altered bytes")
	_write(path,original)

func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()

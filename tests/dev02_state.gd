extends SceneTree
## Fast domain tests without renderer or UI. No mocks of the restoration rules.
var checks := 0
var failures := 0
var state: RestorationState

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+label)
	else:
		print("PASS: "+label)

func _run() -> void:
	state = RestorationState.new()
	root.add_child(state)
	state.register_part(&"trailer_01.service_window",load("res://data/restoration/service_window.tres"))
	var ids := {}
	for data in RestorationCatalog.data().parts:
		_check(not ids.has(data.id),"stable unique id: "+data.id)
		ids[data.id] = true
		state.register_part(StringName("trailer_01."+data.id),RestorationTask.from_data(data))
	var window := &"trailer_01.service_window"
	_check(not state.finish(window),"cannot bypass inspection or work by calling finish")
	_check(state.inspect(window),"first inspection discovers defect")
	_check(not state.inspect(window) and state.notebook_entries().size()==1,"repeat inspection has one task")
	_check(not state.advance_work(window,3) and state.progress_of(window)==0,"cannot work without required tool")
	state.acquire_tool(&"brush")
	_check(not state.advance_work(window,3) and state.progress_of(window)==0,"wrong selected tool cannot clean window")
	state.acquire_tool(&"cleaning_kit")
	state.advance_work(window,.9)
	var partial := state.progress_of(window)
	_check(partial>.29 and partial<.31,"fractional work is recorded")
	var before := state.snapshot()
	_check(state.validate(before),"partial snapshot validates")
	state.reset()
	_check(state.restore(before) and is_equal_approx(state.progress_of(window),partial),"partial work survives reset and load")
	_check(state.status_of(&"trailer_01.body_service")==RestorationState.Status.UNINSPECTED,"window work does not alter another part")
	_check(not state.finish(window),"finish cannot skip remaining hold duration")
	state.advance_work(window,2.2)
	_check(state.status_of(window)==RestorationState.Status.RESTORED,"correct tool completes window")
	var finished := state.snapshot()
	_check(not state.advance_work(window,10) and not state.inspect(window),"finished work and discovery are idempotent")
	_check(state.snapshot()==finished,"repeated completed actions cannot mutate records")
	var healthy := &"trailer_01.sound_frame"
	var count := state.notebook_entries().size()
	state.inspect(healthy)
	_check(state.status_of(healthy)==RestorationState.Status.INSPECTED and state.notebook_entries().size()==count,"healthy inspection makes no repair task")
	var prep := &"trailer_01.prepare_coffee"
	state.inspect(prep)
	_check(state.block_reason(prep).begins_with("Сначала:"),"only real worktop dependency blocks preparation")
	state.inspect(&"trailer_01.body_service")
	state.belt.select_slot(state.belt.slots.find("brush"))
	_check(state.block_reason(&"trailer_01.body_service")=="","unrelated body cleaning stays available")
	var belt := ToolBelt.new()
	for id in ToolDefinition.TOOLS.keys():
		if belt.slots.has(""):
			_check(belt.take(StringName(id)),"take a tool into a free slot")
		else:
			_check(not belt.take(StringName(id)),"sixth tool cannot exceed five slots")
	_check(belt.slots.size()==5,"belt always has exactly five slots")
	_check(not belt.take(StringName(belt.slots[0])),"same physical tool cannot appear twice")
	for i in range(5):
		_check(belt.select_slot(i) and belt.selected==i,"direct slot selection %d"%(i+1))
	belt.cycle(1)
	_check(belt.selected==0,"wheel wraps fifth to first")
	belt.cycle(-1)
	_check(belt.selected==4,"wheel wraps first to fifth")
	_check(not belt.select_slot(5) and not belt.select_slot(-1),"out of range slots are rejected")
	var empty := ToolBelt.new()
	empty.select_slot(4)
	_check(empty.active_tool()==&"","empty slot selection is safe")
	var bad := state.snapshot()
	bad.belt.slots.append("wrench")
	_check(not state.restore(bad),"oversized serialized belt rejected")
	bad = state.snapshot()
	bad.records[str(window)].progress = -1
	_check(not state.restore(bad),"invalid progress rejected without mutation")
	bad = state.snapshot()
	bad.collected = ["unknown_source"]
	_check(not state.restore(bad),"unknown physical material source rejected")
	bad = state.snapshot()
	bad.materials = {"seal_strip":50}
	_check(not state.restore(bad),"materials cannot be duplicated through loading")
	_check(not state.ready_for_opening,"some completed work cannot set readiness")
	bad = state.snapshot()
	bad.ready_for_opening = true
	_check(state.restore(bad) and not state.ready_for_opening,"readiness recomputed rather than trusting saved flag")
	var incomplete := RestorationState.new()
	root.add_child(incomplete)
	incomplete.register_part(&"other.service_window",load("res://data/restoration/service_window.tres"))
	incomplete.acquire_tool(&"cleaning_kit")
	incomplete.inspect(&"other.service_window")
	incomplete.advance_work(&"other.service_window",3.1)
	_check(not incomplete.ready_for_opening,"missing mandatory categories cannot silently count as complete")
	incomplete.queue_free()
	state.queue_free()
	await process_frame
	print("DEV-02 STATE RESULT: %d checks; %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)

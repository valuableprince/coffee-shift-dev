extends "res://tests/dev03_integration.gd"
## Real menus, rendering settings and old save envelopes on the integrated scene.

func labels(node: Node) -> String:
	var result := ""
	if node is Label or node is Button: result += node.text + "\n"
	for child in node.get_children(): result += labels(child)
	return result

func run() -> void:
	root.size = Vector2i(1280,720)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	for size in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = size
		await frames(4)
		await shot("01-main-menu-%d" % size.x)
		await click("Настройки", level.main_menu)
		check(not labels(level.main_menu).to_lower().contains("vhs"), "no obsolete text anywhere in settings")
		var content: VBoxContainer = level.main_menu._content
		var scroll := content.get_parent() as ScrollContainer
		for caption in ["Яркость", "Качество теней", "Разрешение оконного режима"]:
			var label: Label = null
			for child in content.get_children():
				if child is Label and child.text == caption: label = child
			check(label != null, "live settings control exists: " + caption)
			if label != null:
				var control: Control = content.get_child(label.get_index()+1)
				scroll.ensure_control_visible(control)
				await frames(4)
				check(scroll.get_global_rect().intersection(control.get_global_rect()).size.y >= control.size.y * .9, "setting reachable at " + str(size))
				if control is HSlider:
					control.value = 110
					check(is_equal_approx(level.game_settings.brightness,1.1), "brightness slider changes game")
					control.value = 100
				elif control is OptionButton and caption == "Качество теней":
					control.select(2)
					control.item_selected.emit(2)
					check(level.game_settings.shadow_quality == 2, "shadow menu changes game")
					control.select(1)
					control.item_selected.emit(1)
				await shot("02-settings-%s-%d" % ["brightness" if caption == "Яркость" else "shadows" if caption == "Качество теней" else "display",size.x])
		await click("Назад", level.main_menu)
	check(level.new_game(1), "integrated new game starts")
	root.size = Vector2i(1280,720)
	check(not InputMap.has_action("vhs") and not InputMap.has_action("vhs_less") and not InputMap.has_action("vhs_more"), "all obsolete actions absent")
	check(not FileAccess.file_exists("res://shaders/vhs.gdshader"), "obsolete shader deleted")
	check(not labels(level.hud).to_lower().contains("vhs"), "all gameplay HUD text clean")
	var graphics: CoffeeShiftGraphics = level.get_node("GraphicsSettings")
	check(not graphics.correction.visible, "default image has no correction pass")
	var old := level.capture_snapshot()
	old.world.vhs_enabled = true
	old.world.vhs_strength = .6
	level.game_settings.brightness = 1.15
	level.game_settings.shadow_quality = 0
	level.game_settings.apply_to_game(level.player,level.hud,level.music,false)
	check(graphics.correction.visible and is_equal_approx(graphics.correction.material.get_shader_parameter("brightness"),1.15), "neutral correction is applied")
	check(not level.get_node("Daylight").shadow_enabled, "off disables designed shadows")
	check(level.apply_snapshot(old), "old save with effect fields loads")
	check(is_equal_approx(level.game_settings.brightness,1.15), "old save cannot override global preferences")
	check(not level.capture_snapshot().world.has("vhs_enabled") and not level.capture_snapshot().world.has("vhs_strength"), "new snapshots omit obsolete effect data")
	level.game_settings.shadow_quality = 2
	level.game_settings.brightness = 1.0
	level.game_settings.apply_to_game(level.player,level.hud,level.music,false)
	check(level.get_node("Daylight").shadow_enabled and not level.trailer.get_node("PortableWorkLight").shadow_enabled, "high restores designed shadow choices only")
	check(root.positional_shadow_atlas_size == 2048, "high quality uses real larger shadow atlas")
	level.show_pause()
	await click("Настройки",level.main_menu)
	check(not labels(level.main_menu).to_lower().contains("vhs"), "pause settings clean too")
	await click("Назад",level.main_menu)
	level.resume_game()
	# Disk migration drops old config keys without touching other preferences.
	var previous := FileAccess.get_file_as_bytes(CoffeeShiftSettings.PATH)
	var existed := FileAccess.file_exists(CoffeeShiftSettings.PATH)
	var config := ConfigFile.new()
	config.set_value("video","vhs_enabled",true)
	config.set_value("video","vhs_strength",.6)
	config.set_value("audio","master",55)
	config.set_value("dialogue","word_interval",.2)
	check(config.save(CoffeeShiftSettings.PATH) == OK, "write actual old config")
	var migrated := CoffeeShiftSettings.new()
	migrated.load_from_disk()
	check(migrated.master_volume == 55 and is_equal_approx(migrated.dialogue_word_interval,.2), "migration preserves audio and word speed")
	check(migrated.brightness == 1.0 and migrated.shadow_quality == 1, "old config gets neutral graphics defaults")
	check(migrated.save_to_disk() == OK, "rewrite upgraded config")
	config = ConfigFile.new()
	check(config.load(CoffeeShiftSettings.PATH) == OK and not config.has_section_key("video","vhs_enabled") and not config.has_section_key("video","vhs_strength"), "obsolete keys removed from saved file")
	if existed:
		var file := FileAccess.open(CoffeeShiftSettings.PATH,FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(CoffeeShiftSettings.PATH))
	TradingLocation.update_lighting(level,9*3600)
	var day_energy: float = level.get_node("Daylight").light_energy
	TradingLocation.update_lighting(level,20*3600)
	check(level.get_node("Daylight").light_energy < day_energy, "existing clock drives evening")
	check(level.get_tree().get_nodes_in_group("street_lamps")[0].light_energy > .8, "street lanterns light evening")
	TradingLocation.update_lighting(level,level.session.clock)
	level.save_manager.autosave_enabled = false
	level.audio.stop_all()
	level.queue_free()
	await frames(3)
	print("DEV04 INTEGRATION: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

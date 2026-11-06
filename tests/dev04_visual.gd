extends "res://tests/asset_integration.gd"
## Identical cameras in the integration before/after worktrees, real GL viewports.
func run() -> void:
	root.size = Vector2i(1280,720)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	var baseline := OS.get_cmdline_user_args().has("--baseline")
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		await frames(3)
		await shot("01-main-menu-%d" % size.x)
		await click("Настройки",level.main_menu)
		var scroll: ScrollContainer = level.main_menu._content.get_parent()
		for child in level.main_menu._content.get_children():
			if child is Label and child.text == ("Сила VHS" if baseline else "Качество теней"):
				scroll.ensure_control_visible(level.main_menu._content.get_child(child.get_index()+1))
		await frames(4)
		await shot("02-settings-%d" % size.x)
		await click("Назад",level.main_menu)
	check(level.new_game(1), "start integrated game for real screenshots")
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		await view(Vector3(.03,1.35,-.55),Vector3(0,.4,1.96),75)
		await shot("03-interior-%d" % size.x)
		await view(Vector3(.76,1.55,-1.2),Vector3(-.02,.4,-.95),65)
		await shot("04-machine-grinder-%d" % size.x)
		await view(Vector3(-.86,1.24,1.35),Vector3(0,.4,1.75),70)
		await shot("05-sink-%d" % size.x)
		await view(Vector3(.32,1.38,1.1),Vector3(0,.4,-.75),75)
		await shot("06-register-cabinets-%d" % size.x)
		await view(Vector3(0,1.4,0),Vector3(5.5,.02,5.5),70)
		await shot("07-exterior-%d" % size.x)
		level.hud.set_dialogue_preferences(false,.12)
		level._panel("ПОКУПАТЕЛЬ", "Добрый день! Один капучино, пожалуйста.", [{"label":"Подтвердить заказ", "call":func() -> void: pass}],true)
		await shot("08-dialogue-%d" % size.x)
		level.hud.close_panel()
	level.audio.stop_all()
	level.queue_free()
	await frames(4)
	var garage = load("res://scenes/main.tscn").instantiate()
	root.add_child(garage)
	current_scene = garage
	await frames(6)
	garage.player.position = Vector3(3.8,.02,4.3)
	var target := Vector3(0,1.2,-.5)
	var direction: Vector3 = target - garage.player.camera.global_position
	garage.player.rotation.y = atan2(-direction.x,-direction.z)
	garage.player.pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())
	garage.player.camera.rotation.x = garage.player.pitch
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		await shot("09-garage-%d" % size.x)
	garage.queue_free()
	await frames(3)
	print("DEV04 VISUAL: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

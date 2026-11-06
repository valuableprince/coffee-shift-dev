extends "res://tests/asset_integration.gd"

func run() -> void:
	root.size = Vector2i(1280,720)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	check(level.new_game(1), "baseline new game")
	await view(Vector3(0,2.38,-2.60), Vector3(0,.4,1.80),75)
	await shot("00-before-ceiling-front")
	await view(Vector3(0,2.38,2.60), Vector3(0,.4,-1.90),75)
	await shot("00-before-ceiling-rear")
	level.audio.stop_all()
	quit(0 if failures == 0 else 1)

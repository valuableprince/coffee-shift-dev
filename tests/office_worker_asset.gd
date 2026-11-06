extends "res://tests/asset_integration.gd"
## The original PR 53 scene is tested in the running game, independently of AI.
func run() -> void:
	root.size = Vector2i(1280,720)
	level = load("res://scenes/first_shift.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	check(level.new_game(1), "real game starts for original office asset")
	var npc: CoffeeShiftOfficeWorker = load("res://assets/models/npc_office_worker/npc_office_worker.tscn").instantiate()
	npc.position = Vector3(3,0,4)
	level.add_child(npc)
	await frames(5)
	check(npc._player != null, "original GLB animation player imported")
	check(npc.get_node("CollisionShape3D").shape is CapsuleShape3D, "original collision capsule loads")
	var box := bounds(npc)
	check(box.size.y > 1.5 and box.size.y < 2.1, "human scale and proportions in metres")
	for activity in ["idle","walk","order","receive"]:
		npc.play_activity(activity)
		await frames(15)
		check(npc._player.is_playing() and str(npc._player.current_animation).ends_with(activity), "original animation plays: " + activity)
		await view(npc.position + Vector3(0,1.0,0), Vector3(4.9,.02,6.1),55)
		await shot("office-"+activity)
	npc.queue_free()
	level.audio.stop_all()
	level.queue_free()
	await frames(3)
	print("OFFICE ASSET: %d checks; %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

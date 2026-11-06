extends SceneTree
## Two separate engine processes write then read the same global settings file.
func _initialize() -> void:
	var settings := CoffeeShiftSettings.new()
	if OS.get_cmdline_user_args().has("--write-preferences"):
		settings.brightness = 1.15
		settings.shadow_quality = 2
		settings.master_volume = 55
		settings.effects_volume = 65
		settings.music_volume = 45
		settings.fullscreen = true
		settings.resolution_index = 2
		settings.dialogue_word_reveal = false
		settings.dialogue_word_interval = .2
		if settings.save_to_disk() != OK: quit(1); return
		print("PREFERENCES WRITE: 1 checks; 0 failures")
	else:
		settings.load_from_disk()
		var valid := is_equal_approx(settings.brightness,1.15) and settings.shadow_quality == 2 and settings.master_volume == 55 and settings.effects_volume == 65 and settings.music_volume == 45 and settings.fullscreen and settings.resolution_index == 2 and not settings.dialogue_word_reveal and is_equal_approx(settings.dialogue_word_interval,.2)
		if not valid: push_error("FAIL: preferences lost across engine restart")
		print("PREFERENCES RESTART: 1 checks; %d failures" % (0 if valid else 1))
		quit(0 if valid else 1)
		return
	quit(0)

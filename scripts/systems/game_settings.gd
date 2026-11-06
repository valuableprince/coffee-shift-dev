class_name CoffeeShiftSettings
extends RefCounted
## Global player preferences. Independent from restoration career saves.

const PATH := "user://coffee_shift_settings.cfg"
const WIDTHS := [1280, 1600, 1920]
const HEIGHTS := [720, 900, 1080]

var master_volume := 80
var music_volume := 75
var effects_volume := 85
var music_enabled := true
var brightness := 1.0
var shadow_quality := 1
var dialogue_word_reveal := true
var dialogue_word_interval := 0.12
var mouse_sensitivity := 0.0022
var fullscreen := false
var resolution_index := 0
var last_career := 1

func load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	master_volume = clampi(int(config.get_value("audio","master",master_volume)),0,100)
	music_volume = clampi(int(config.get_value("audio","music",music_volume)),0,100)
	effects_volume = clampi(int(config.get_value("audio","effects",effects_volume)),0,100)
	music_enabled = bool(config.get_value("audio","music_enabled",music_enabled))
	# Rebuild the config on the next save: obsolete video keys are ignored.
	brightness = clampf(float(config.get_value("video","brightness",brightness)),0.75,1.25)
	shadow_quality = clampi(int(config.get_value("video","shadow_quality",shadow_quality)),0,2)
	dialogue_word_reveal = bool(config.get_value("dialogue","word_reveal",dialogue_word_reveal))
	dialogue_word_interval = clampf(float(config.get_value("dialogue","word_interval",dialogue_word_interval)),0.06,0.25)
	mouse_sensitivity = clampf(float(config.get_value("gameplay","mouse_sensitivity",mouse_sensitivity)),0.0008,0.005)
	fullscreen = bool(config.get_value("video","fullscreen",fullscreen))
	resolution_index = clampi(int(config.get_value("video","resolution_index",resolution_index)),0,WIDTHS.size()-1)
	last_career = clampi(int(config.get_value("gameplay","last_career",last_career)),1,3)

func save_to_disk() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio","master",master_volume)
	config.set_value("audio","music",music_volume)
	config.set_value("audio","effects",effects_volume)
	config.set_value("audio","music_enabled",music_enabled)
	config.set_value("video","brightness",brightness)
	config.set_value("video","shadow_quality",shadow_quality)
	config.set_value("video","fullscreen",fullscreen)
	config.set_value("video","resolution_index",resolution_index)
	config.set_value("dialogue","word_reveal",dialogue_word_reveal)
	config.set_value("dialogue","word_interval",dialogue_word_interval)
	config.set_value("gameplay","mouse_sensitivity",mouse_sensitivity)
	config.set_value("gameplay","last_career",last_career)
	return config.save(PATH)

func apply_to_game(player: CoffeeShiftPlayer, hud, music: PrototypeMusic, apply_window: bool = true) -> void:
	if player != null:
		player.mouse_sensitivity = mouse_sensitivity
	if hud != null:
		var graphics := hud.get_parent().get_node_or_null("GraphicsSettings") as CoffeeShiftGraphics
		if graphics != null: graphics.apply(self)
	if hud != null and hud.has_method("set_dialogue_preferences"):
		hud.set_dialogue_preferences(dialogue_word_reveal, dialogue_word_interval)
	if music != null:
		music.set_preferences(music_enabled, music_db())
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, master_volume <= 0)
		AudioServer.set_bus_volume_db(master_bus,linear_to_db(maxf(0.001,float(master_volume)/100.0)))
	if apply_window and DisplayServer.get_name() != "headless":
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(WIDTHS[resolution_index],HEIGHTS[resolution_index]))

func music_db() -> float:
	return -40.0 + 0.4 * float(music_volume)


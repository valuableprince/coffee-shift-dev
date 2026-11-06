class_name ShiftAudio
extends Node
## Original process/UI PCM plus Kenney CC0 wood/concrete footstep recordings.
var effects: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var ambient: AudioStreamPlayer
var process_player: AudioStreamPlayer
var last_process := ""
var playback_enabled := not OS.get_cmdline_user_args().has("--test-mode")
var footstep_variants: Dictionary = {}
var footstep_player: AudioStreamPlayer
var _step_index := 0

func _ready() -> void:
	if AudioServer.get_bus_index("Effects") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Effects")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for event in ["ui", "window", "machine", "grinder", "extraction", "steam", "cash", "coins", "cup", "serve", "paper", "city"]:
		effects[event] = make_sound(event)
	for surface in ["wood", "concrete"]:
		footstep_variants[surface] = []
		for i in range(5):
			var clip_path := "res://assets/audio/footsteps/footstep_%s_%03d.ogg" % [surface, i]
			if not ResourceLoader.exists(clip_path):
				continue
			var clip := load(clip_path) as AudioStreamOggVorbis
			if clip == null:
				continue
			clip.loop = false
			footstep_variants[surface].append(clip)
	footstep_player = AudioStreamPlayer.new()
	footstep_player.name = "Footsteps"
	footstep_player.bus = "Effects"
	footstep_player.volume_db = -20
	add_child(footstep_player)
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "Effects"
		p.volume_db = -17
		add_child(p)
		players.append(p)
	ambient = AudioStreamPlayer.new()
	ambient.bus = "Effects"
	ambient.volume_db = -32
	ambient.stream = effects.city
	add_child(ambient)
	if playback_enabled: ambient.play()
	process_player = AudioStreamPlayer.new()
	process_player.bus = "Effects"
	process_player.volume_db = -22
	add_child(process_player)

func set_volume(percent: int) -> void:
	var bus := AudioServer.get_bus_index("Effects")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(.001, float(percent) / 100.0)))
	AudioServer.set_bus_mute(bus, percent <= 0)

func _exit_tree() -> void:
	stop_all()
	effects.clear()
	footstep_variants.clear()

func stop_all() -> void:
	last_process = ""
	for p in players + [ambient, process_player, footstep_player]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null

func play_event(event: String) -> void:
	if not playback_enabled: return
	if not effects.has(event):
		return
	# Looping machine/steam sounds belong ONLY to process_player, never to
	# the one-shot pool. Previously extraction created a second endless loop.
	if effects[event].loop_mode != AudioStreamWAV.LOOP_DISABLED: return
	for p in players:
		if not p.playing:
			p.stream = effects[event]
			p.play()
			return

func play_footstep(surface: String) -> void:
	if not playback_enabled or not footstep_variants.has(surface): return
	var variants: Array = footstep_variants[surface]
	if variants.is_empty(): return
	footstep_player.stream = variants[_step_index % variants.size()]
	footstep_player.pitch_scale = [1.0, .97, 1.03, .99, 1.01][_step_index % 5]
	_step_index += 1
	footstep_player.play()

func set_process_sound(operation: String) -> void:
	if operation not in ["extract", "steam"]: operation = ""
	if last_process == operation:
		return
	last_process = operation
	process_player.stop()
	process_player.stream = null
	if operation != "" and playback_enabled:
		process_player.stream = effects.steam if operation == "steam" else effects.extraction
		process_player.play()

static func make_sound(event: String) -> AudioStreamWAV:
	var rate := 22050
	var looping := event in ["city", "extraction", "steam"]
	var seconds := 2.0 if looping else (.75 if event in ["grinder", "window"] else .20)
	var pcm := PackedByteArray()
	pcm.resize(int(seconds * rate) * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(event)
	var smoothed := 0.0
	for i in range(pcm.size() / 2):
		var t := float(i) / rate
		var envelope := 1.0 if looping else pow(1.0 - t / seconds, 2)
		var noise := rng.randf_range(-1, 1)
		smoothed = lerpf(smoothed, noise, .08)
		var tone := sin(TAU * (560 if event in ["cash", "ui", "serve"] else 110) * t)
		var sample := (smoothed * .6 + tone * .2) * envelope
		if event == "steam": sample = noise * .15 + smoothed * .7
		if event == "city": sample = smoothed * .4 + sin(TAU * 55 * t) * .08
		if event in ["cup", "paper", "coins"]: sample = noise * .45 * envelope
		pcm.encode_s16(i * 2, int(clampf(sample, -1, 1) * 16000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = pcm.size() / 2
	return stream

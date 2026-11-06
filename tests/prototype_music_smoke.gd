extends SceneTree
## Verifies both original prototype loops can be rendered as valid looping PCM.

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var music = load("res://scripts/audio/prototype_music.gd").new()
	root.add_child(music)
	var failed := false
	for index in range(2):
		var track: AudioStreamWAV = music.make_track(index)
		var data: PackedByteArray = track.data
		var expected := roundi(8.0 * 4.0 * (60.0 / 96.0) * 22050.0) * 2
		var valid := track.format == AudioStreamWAV.FORMAT_16_BITS and track.mix_rate == 22050
		valid = valid and track.loop_mode == AudioStreamWAV.LOOP_FORWARD and track.loop_end * 2 == data.size()
		valid = valid and data.size() == expected
		var signal_found := false
		if valid:
			var start := roundi(22050.0 * 1.3) * 2
			for offset in range(0, 2000, 2):
				if absi(data.decode_s16(start + offset)) > 50:
					signal_found = true
					break
		valid = valid and signal_found
		if not valid:
			push_error("FAIL: prototype music track %d is not a playable looping waveform" % index)
			failed = true
		else:
			print("PASS: original prototype music %d, %d bytes, loop %d frames" % [index, data.size(), track.loop_end])
	quit(1 if failed else 0)

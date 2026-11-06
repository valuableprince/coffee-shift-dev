extends Audio01Director
## Fault injection only: no project audio bytes are modified or removed.
var paths: Array = ["res://tests/nonexistent_radio_a.ogg", "res://tests/nonexistent_radio_b.ogg"]

func radio_paths() -> Array:
	return paths

func next_radio_index(_previous: int) -> int:
	return 0

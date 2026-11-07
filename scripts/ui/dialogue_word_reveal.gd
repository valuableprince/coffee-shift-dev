class_name DialogueWordReveal
extends RefCounted
## Shared word timing for conversations and non-modal remarks. No game effects.
var copy: Label
var word_ends: Array[int] = []
var index := 0
var elapsed := 0.0

func start(label: Label, enabled: bool) -> void:
	clear()
	copy = label
	if enabled:
		var words := RegEx.new()
		words.compile("\\S+")
		for word in words.search_all(copy.text): word_ends.append(word.get_end())
	copy.visible_characters = 0 if not word_ends.is_empty() else -1

func clear() -> void:
	copy = null
	word_ends.clear()
	index = 0
	elapsed = 0.0

func is_typing() -> bool:
	return is_instance_valid(copy) and index < word_ends.size()

func reveal() -> void:
	if is_instance_valid(copy): copy.visible_characters = -1
	index = word_ends.size()

func advance(delta: float, interval: float) -> void:
	if not is_typing(): return
	elapsed -= delta
	while elapsed <= 0.0 and index < word_ends.size():
		var end_char := word_ends[index]
		copy.visible_characters = end_char
		index += 1
		elapsed += interval
		var text := copy.text.substr(0, end_char).strip_edges()
		if text.ends_with(".") or text.ends_with("!") or text.ends_with("?"): elapsed += .17
		elif text.ends_with(","): elapsed += .08
	if index >= word_ends.size(): reveal()

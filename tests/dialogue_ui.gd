extends SceneTree
## Headless checks for compact customer dialogue and optional word reveal.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _run() -> void:
	var hud := ShiftHUD.new()
	root.add_child(hud)
	await process_frame

	hud.set_dialogue_preferences(true, 0.20)
	hud.show_panel("ПОКУПАТЕЛЬ", "Добрый день! Мне один капучино, пожалуйста.", [
		{"label": "Подтвердить заказ", "call": func() -> void: pass}
	], true)
	_check(hud.panel.visible and hud.panel.anchor_top == 1.0, "customer dialogue uses lower viewport anchor")
	_check(hud.panel.anchor_left > 0.0 and hud.panel.anchor_right < 1.0, "dialogue does not occupy full screen")
	_check(hud._dialogue_copy != null and hud._dialogue_copy.visible_characters == 0, "text initially hidden for word reveal")
	var confirm := hud._dialogue_buttons[0]
	_check(confirm.disabled, "response remains unavailable during reveal")
	await process_frame
	_check(hud._dialogue_copy.visible_characters > 0, "first word becomes visible over time")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	hud._input(space)
	_check(hud._dialogue_copy.visible_characters == -1 and not confirm.disabled, "Space reveals the whole line and unlocks responses")
	hud.close_panel()
	_check(not hud.panel.visible and hud.control_hints.visible, "closing dialogue restores HUD")

	hud.set_dialogue_preferences(false, 0.10)
	hud.show_panel("ПОКУПАТЕЛЬ", "Текст без анимации.", [
		{"label": "Ответить", "call": func() -> void: pass}
	], true)
	_check(hud._dialogue_copy.visible_characters == -1, "disabling effect reveals text immediately")
	_check(not hud._dialogue_buttons[0].disabled, "disabled effect does not block responses")
	hud.close_panel()

	# Deterministic elapsed-time checks, independent of renderer frame rate.
	hud.set_process(false)
	hud.set_dialogue_preferences(true, .25)
	hud.show_panel("ПОКУПАТЕЛЬ", "Первое второе третье четвёртое", [
		{"label": "Ответить", "call": func() -> void: pass},
		{"label": "Недоступный ответ", "disabled": true, "call": func() -> void: pass}
	], true)
	hud._advance_dialogue(0)
	_check(hud._word_index == 1 and hud._dialogue_copy.visible_characters == "Первое".length(), "reveal finishes a whole word")
	hud._advance_dialogue(.12)
	_check(hud._word_index == 1, "250 ms interval retains first word after 120 ms")
	hud.close_panel()
	hud._advance_dialogue(1.0)
	_check(not hud._is_typing(), "closing unfinished dialogue safely stops reveal")
	hud.set_dialogue_preferences(true, .06)
	hud.show_panel("ПОКУПАТЕЛЬ", "Первое второе третье четвёртое", [
		{"label": "Ответить", "call": func() -> void: pass}
	], true)
	hud._advance_dialogue(0)
	hud._advance_dialogue(.12)
	_check(hud._word_index >= 2 and hud._word_index < 4, "60 ms setting advances faster without revealing whole reply")
	_check(hud._dialogue_buttons[0].disabled, "unfinished fast reply still locks response")
	hud.set_dialogue_preferences(false, .12)
	_check(not hud._is_typing() and not hud._dialogue_buttons[0].disabled, "disabling effect during reply completes it immediately")
	hud.close_panel()
	hud.set_dialogue_preferences(true, .12)
	hud.show_panel("ПОКУПАТЕЛЬ", "Новая реплика", [
		{"label": "Недоступный ответ", "disabled": true, "call": func() -> void: pass},
		{"label": "Ответить", "call": func() -> void: pass}
	], true)
	_check(hud._word_index == 0 and hud._dialogue_copy.visible_characters == 0, "switching dialogue resets word reveal")
	hud._reveal_dialogue()
	var action_row := hud._dialogue_navigation[0].get_parent()
	_check((action_row.get_child(0) as Button).disabled and not (action_row.get_child(1) as Button).disabled, "reveal preserves actions disabled by game rules")
	hud.close_panel()
	hud.set_process(true)
	hud.guide.text = "Длинная очередь: позиции и подсказки\n".repeat(30)
	hud.show_panel("ПОКУПАТЕЛЬ", "Проверка занятого HUD.", [], true)
	for i in range(4): await process_frame
	_check(not hud.panel.get_global_rect().intersects(hud.orders_panel.get_global_rect()), "tall orders sidebar scrolls above centered dialogue without overlap")
	hud.close_panel()
	hud.guide.text = ""

	hud.show_panel("КАССА", "Проверка обычной панели.")
	_check(hud.panel.anchor_top != 1.0, "cash and equipment panels retain centered layout")
	hud.close_panel()

	var settings := CoffeeShiftSettings.new()
	_check(settings.dialogue_word_reveal and is_equal_approx(settings.dialogue_word_interval, 0.12), "new preferences have safe defaults")
	settings.dialogue_word_reveal = false
	settings.dialogue_word_interval = 0.18
	_check(not settings.dialogue_word_reveal and is_equal_approx(settings.dialogue_word_interval, 0.18), "dialogue preferences are independent of career state")

	hud.queue_free()
	await process_frame
	print("DIALOGUE UI RESULT: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

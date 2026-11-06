extends Node3D
## Coffee Shift v0.1: first-person, balanced brewing, cash and save loop.
const Player = preload("res://scripts/player/player_controller.gd")
const State = preload("res://scripts/systems/game_state.gd")
const MAX_ORDERS := 8
const DAILY_COST := 1200
const SUPPLY_COST := 650
const UPGRADE_COST := 2500

var game
var player
var recipes: Dictionary = {}
var open_shift := false
var order := ""
var stage := "idle"
var start_ms := 0
var quality := 100
var served := 0
var revenue := 0
var supplies_spent := 0
var hud: Label
var hint: Label
var message: Label

func _ready() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
    if typeof(raw) != TYPE_DICTIONARY:
        push_error("Invalid or missing data/recipes.json")
        return
    recipes = raw
    game = State.new()
    game.load_save()
    _inputs()
    _world()
    _interior()
    player = Player.new()
    player.position = Vector3(0, 0.1, 2.2)
    add_child(player)
    _ui()
    _say("Подойдите к кассе и нажмите E, чтобы открыть смену.")

func _inputs() -> void:
    var keys := {
        "forward": KEY_W, "back": KEY_S, "left": KEY_A,
        "right": KEY_D, "sprint": KEY_SHIFT, "interact": KEY_E
    }
    for action in keys:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var key := InputEventKey.new()
        key.keycode = keys[action]
        if not InputMap.action_has_event(action, key):
            InputMap.action_add_event(action, key)

func _world() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("342b31")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("e9c19e")
    environment.ambient_light_energy = 0.7
    world.environment = environment
    add_child(world)
    for point in [Vector3(-2, 2.6, 0), Vector3(2, 2.6, -1)]:
        var lamp := OmniLight3D.new()
        lamp.position = point
        lamp.light_color = Color("ffcb90")
        lamp.light_energy = 2.0
        lamp.omni_range = 9.0
        add_child(lamp)

func _block(label: String, point: Vector3, size: Vector3, tint: Color, action := "", detail := "") -> void:
    var body := StaticBody3D.new()
    body.name = label
    body.position = point
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.roughness = 0.7
    mesh.material_override = material
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var physics_shape := BoxShape3D.new()
    physics_shape.size = size
    collision.shape = physics_shape
    body.add_child(collision)
    if action != "":
        body.set_meta("action", action)
        body.set_meta("detail", detail)
    add_child(body)

func _interior() -> void:
    _block("Floor", Vector3(0, -0.16, 0), Vector3(9, 0.32, 7), Color("594333"))
    _block("Ceiling", Vector3(0, 3.0, 0), Vector3(9, 0.2, 7), Color("40362f"))
    _block("Back wall", Vector3(0, 1.5, -3.55), Vector3(9, 3, 0.18), Color("725b4f"))
    _block("Left wall", Vector3(-4.55, 1.5, 0), Vector3(0.18, 3, 7), Color("86695a"))
    _block("Right wall", Vector3(4.55, 1.5, 0), Vector3(0.18, 3, 7), Color("86695a"))
    _block("Window left", Vector3(-3.3, 1.5, 3.55), Vector3(2.4, 3, 0.18), Color("403c3b"))
    _block("Window right", Vector3(3.3, 1.5, 3.55), Vector3(2.4, 3, 0.18), Color("403c3b"))
    _block("Window lintel", Vector3(0, 2.7, 3.55), Vector3(4.2, 0.6, 0.18), Color("403c3b"))
    _block("Counter", Vector3(0, 0.54, -0.6), Vector3(4.3, 1.05, 1.05), Color("65452d"))
    _block("Countertop", Vector3(0, 1.11, -0.6), Vector3(4.5, 0.12, 1.12), Color("a57f61"))
    _block("Espresso machine", Vector3(-1.25, 1.4, -0.65), Vector3(0.8, 0.44, 0.55), Color("9faaa8"), "machine", "Кофемашина: экстракция")
    _block("Register", Vector3(1.25, 1.27, -0.61), Vector3(0.55, 0.22, 0.42), Color("272a30"), "register", "Касса: открыть смену")
    _block("Tray", Vector3(0, 1.23, -0.14), Vector3(0.62, 0.12, 0.25), Color("d6c4a7"), "serve", "Поднос: выдать заказ")
    _block("Fridge", Vector3(-3.55, 0.88, -2.4), Vector3(0.9, 1.7, 0.82), Color("b3b9b5"), "milk", "Холодильник: молоко")
    _block("Supplies", Vector3(3.45, 0.67, -2.5), Vector3(1.2, 1.25, 0.8), Color("ad7c48"), "supplies", "Поставки: ингредиенты")
    _block("Upgrade", Vector3(4.40, 1.5, -0.8), Vector3(0.13, 0.92, 0.95), Color("ad7453"), "upgrade", "Доска улучшений")
    _block("Clock", Vector3(3.4, 1.7, 2.7), Vector3(0.65, 0.65, 0.18), Color("e9cf99"), "close", "Часы: закрыть смену")
    for x in [-2.75, 2.75]:
        for z in [0.7, 2.1]:
            _block("Table", Vector3(x, 0.74, z), Vector3(0.95, 0.1, 0.8), Color("8d6142"))
            _block("Table leg", Vector3(x, 0.37, z), Vector3(0.13, 0.68, 0.13), Color("45403c"))

func _ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 18)
    panel.custom_minimum_size = Vector2(430, 0)
    var stylebox := StyleBoxFlat.new()
    stylebox.bg_color = Color(0.05, 0.045, 0.04, 0.83)
    stylebox.content_margin_left = 14
    stylebox.content_margin_right = 14
    stylebox.content_margin_top = 12
    stylebox.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", stylebox)
    var column := VBoxContainer.new()
    panel.add_child(column)
    hud = Label.new()
    column.add_child(hud)
    message = Label.new()
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.add_theme_color_override("font_color", Color("f4d09b"))
    column.add_child(message)
    layer.add_child(panel)
    hint = Label.new()
    hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    hint.position = Vector2(-350, -70)
    hint.custom_minimum_size = Vector2(700, 40)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layer.add_child(hint)
    var footer := Label.new()
    footer.text = "WASD — ходьба  |  Shift — бег  |  E — действие  |  Esc — курсор"
    footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    footer.position = Vector2(20, -30)
    layer.add_child(footer)

func _process(_delta: float) -> void:
    if player == null or hud == null:
        return
    var target = player.get_interactable()
    hint.text = "[E] " + str(target.get_meta("detail")) if target != null else "Наведите прицел на оборудование"
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("interact") and target != null:
        _interact(str(target.get_meta("action")))
    var current := "Кофейня закрыта. Откройте смену через кассу."
    if open_shift and order == "":
        current = "Все заказы выполнены. Закройте смену у часов."
    elif open_shift:
        var recipe: Dictionary = recipes[order]
        current = "Заказ: %s (%d ₽). %s" % [recipe["name"], recipe["price"], _step_help()]
    hud.text = "COFFEE SHIFT  |  ПРОТОТИП 0.1\nДень %d  •  Баланс %d ₽  •  Репутация %d/100\nКофе %d  •  Молоко %d  •  Стаканы %d\nЗаказы %d/%d  •  Выручка %d ₽\n%s\n" % [
        game.day, game.balance, game.reputation, game.stock["beans"], game.stock["milk"], game.stock["cups"],
        served, MAX_ORDERS, revenue, current]

func _step_help() -> String:
    match stage:
        "idle": return "Начните приготовление на кофемашине."
        "extracting": return "Остановите экстракцию через ~3 с."
        "milk_needed": return "Подойдите к холодильнику."
        "foaming": return "Завершите вспенивание через ~2 с."
        "ready": return "Выдайте готовый напиток на подносе."
    return ""

func _interact(action: String) -> void:
    match action:
        "register":
            if not open_shift:
                open_shift = true
                served = 0
                revenue = 0
                supplies_spent = 0
                _next_order()
                _say("Смена открыта. Поступил первый заказ.")
            else:
                _say("Касса открыта — приготовьте текущий заказ.")
        "machine": _brew()
        "milk": _milk()
        "serve": _serve()
        "supplies": _supplies()
        "upgrade": _upgrade()
        "close": _close()

func _next_order() -> void:
    var ids := ["espresso", "cappuccino", "latte"]
    order = ids[(served + game.day - 1) % ids.size()]
    quality = 100
    stage = "idle"

func _brew() -> void:
    if not open_shift or order == "":
        _say("Сначала откройте смену и получите заказ.")
    elif stage == "idle":
        if game.stock["beans"] <= 0 or game.stock["cups"] <= 0:
            _say("Не хватает зёрен или стаканов. Пополните склад.")
            return
        game.stock["beans"] -= 1
        game.stock["cups"] -= 1
        start_ms = Time.get_ticks_msec()
        stage = "extracting"
        _say("Экстракция запущена. Нажмите E здесь снова через ~3 секунды.")
    elif stage == "extracting":
        var seconds := float(Time.get_ticks_msec() - start_ms) / 1000.0
        var multiplier := 20.0 if game.upgraded else 28.0
        quality = clampi(int(100.0 - absf(seconds - 3.0) * multiplier), 20, 100)
        stage = "ready" if int(recipes[order]["milk"]) == 0 else "milk_needed"
        _say("Экстракция завершена за %.1f с. Качество %d/100." % [seconds, quality])
    else:
        _say(_step_help())

func _milk() -> void:
    if stage == "milk_needed":
        if game.stock["milk"] <= 0:
            _say("Молоко закончилось. Купите ингредиенты.")
            return
        game.stock["milk"] -= 1
        stage = "foaming"
        start_ms = Time.get_ticks_msec()
        _say("Вспенивание началось. Завершите примерно через 2 секунды.")
    elif stage == "foaming":
        var seconds := float(Time.get_ticks_msec() - start_ms) / 1000.0
        var milk_quality := clampi(int(100.0 - absf(seconds - 2.0) * 30.0), 20, 100)
        quality = int((quality + milk_quality) / 2.0)
        stage = "ready"
        _say("Молоко готово. Качество напитка %d/100." % quality)
    else:
        _say("Молоко пока не требуется.")

func _serve() -> void:
    if stage != "ready" or order == "":
        _say("Напиток ещё не готов.")
        return
    var price := int(recipes[order]["price"])
    game.balance += price
    revenue += price
    served += 1
    game.reputation = clampi(game.reputation + (1 if quality >= 75 else -2), 0, 100)
    _say("Заказ выдан: +%d ₽, качество %d/100." % [price, quality])
    if served >= MAX_ORDERS:
        order = ""
        stage = "idle"
    else:
        _next_order()
    game.save()

func _supplies() -> void:
    if game.balance < SUPPLY_COST:
        _say("Недостаточно денег. Поставка стоит %d ₽." % SUPPLY_COST)
        return
    game.balance -= SUPPLY_COST
    if open_shift:
        supplies_spent += SUPPLY_COST
    for item in ["beans", "milk", "cups"]:
        game.stock[item] += 10
    game.save()
    _say("Закуплено по 10 единиц ингредиентов за %d ₽." % SUPPLY_COST)

func _upgrade() -> void:
    if game.upgraded:
        _say("Улучшенная кофемолка уже установлена.")
    elif game.balance < UPGRADE_COST:
        _say("На улучшение требуется %d ₽." % UPGRADE_COST)
    else:
        game.balance -= UPGRADE_COST
        game.upgraded = true
        game.save()
        _say("Кофемолка улучшена: допуск по времени экстракции увеличен.")

func _close() -> void:
    if not open_shift:
        _say("Смена ещё не открыта.")
        return
    var result := revenue - supplies_spent - DAILY_COST
    var closed_day: int = game.day
    game.balance -= DAILY_COST
    game.day += 1
    open_shift = false
    order = ""
    stage = "idle"
    game.save()
    _say("Отчёт за день %d: заказов %d; выручка %d ₽; закупки %d ₽; расходы %d ₽; результат %+d ₽. Сохранено." % [
        closed_day, served, revenue, supplies_spent, DAILY_COST, result])

func _say(text: String) -> void:
    if message != null:
        message.text = text

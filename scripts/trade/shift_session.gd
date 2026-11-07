class_name CoffeeShiftSession
extends RefCounted
## Authoritative operations. UI and world objects never edit balances/statuses.
signal changed
signal checkpoint(reason: String)
signal sound_requested(event: String)
signal customer_remark(customer: Dictionary, text: String)

var catalog := ShiftRecipeCatalog.new()
var inventory: ShiftInventory
var cash: ShiftCashRegister
var preparation := ShiftCoffeePreparation.new()
var orders: Array = []
var customers: Array = []
var prices: Dictionary = {}
var stats: Dictionary = {}
var history: Array = []
var window_open := false
var shift_open := false
var accepting := false
var equipment := {"machine": false, "grinder": false, "fridge": false, "cash": false}
var clock := 0.0
var day := 1
var next_order := 1
var next_customer := 1
var spawn_elapsed := 35.0
var selected_order := 0
var selected_item := 0
var legacy_snapshot: Dictionary = {}
var start_mode := "prototype_start"
var business_name := "Кофе у сквера"
var last_message := ""

func _init() -> void:
	inventory = ShiftInventory.new(catalog.config.stock)
	cash = ShiftCashRegister.new(catalog.config.till)
	clock = float(catalog.config.clock_start)
	for key in catalog.recipes:
		prices[key] = int(catalog.recipes[key].price)
	stats = _empty_stats()

func _empty_stats() -> Dictionary:
	return {"revenue": 0, "received": 0, "change": 0, "cost": 0, "ingredient_cost": 0,
		"packaging_cost": 0, "losses": 0, "sold": 0, "completed": 0, "popular": {}, "errors": {}}

func notify(message: String) -> bool:
	last_message = message
	changed.emit()
	return false

func _commit(message: String, sound: String = "ui") -> bool:
	last_message = message
	sound_requested.emit(sound)
	changed.emit()
	checkpoint.emit(message)
	return true

func order_by_id(id: int) -> Dictionary:
	for order in orders:
		if int(order.id) == id:
			return order
	return {}

func customer_by_id(id: int) -> Dictionary:
	for customer in customers:
		if int(customer.id) == id:
			return customer
	return {}

func active_orders() -> Array:
	return orders.filter(func(o: Dictionary) -> bool: return o.status != "served")

func paid_orders() -> Array:
	return orders.filter(func(o: Dictionary) -> bool: return o.paid and o.status != "served")

func available_menu() -> Array:
	var result: Array = []
	for recipe in catalog.recipes:
		if inventory.can_reserve(catalog.requirements([{"recipe": recipe, "sugar": false, "syrup": false}])):
			result.append(recipe)
	return result

func toggle_window() -> bool:
	if window_open and shift_open:
		return notify("Сначала закройте смену переключателем справа от окна")
	window_open = not window_open
	return _commit("Окно выдачи открыто" if window_open else "Окно выдачи закрыто", "window")

func prepare_equipment(device: String) -> bool:
	# Only the completed animation calls this. Repeats produce no checkpoint.
	if not equipment.has(device) or equipment[device] or shift_open:
		return false
	equipment[device] = true
	return _commit("Проверено: " + str({"machine":"кофемашина", "grinder":"кофемолка", "fridge":"холодильник", "cash":"касса"}[device]), "")

func equipment_status(device: String) -> String:
	return "COMPLETED" if equipment.get(device, false) else "PENDING"

func equipment_ready() -> bool:
	return not equipment.values().has(false)

func open_shift() -> bool:
	if shift_open:
		return notify("Смена уже открыта")
	if not window_open:
		return notify("Откройте створку окна выдачи")
	if false in equipment.values():
		return notify("Проверьте кофемашину, кофемолку, холодильник и кассу")
	if available_menu().is_empty():
		return notify("Нет ингредиентов для открытия смены")
	shift_open = true
	accepting = true
	stats = _empty_stats()
	spawn_elapsed = float(catalog.config.customers.interval_seconds) - 4.0
	return _commit("Смена открыта. Можно принимать покупателей")

func close_shift() -> bool:
	if not shift_open:
		return notify("Смена закрыта")
	accepting = false
	for c in customers:
		if c.state in ["queue", "counter"] and int(c.order) == 0:
			c.state = "leaving"
	if not active_orders().is_empty() or not cash.payment.is_empty():
		return notify("Новые заказы остановлены. Завершите принятые заказы и снова закройте смену")
	shift_open = false
	history.append(report())
	# Reset only after a successful close, including a second shift on the same day.
	for device in equipment: equipment[device] = false
	return _commit("Смена закрыта. Отчёт готов", "cash")

func report() -> Dictionary:
	var result := stats.duplicate(true)
	result.profit = int(stats.revenue) * 100 - int(stats.cost)
	result.day = day
	result.business_name = business_name
	result.popular_drink = "—"
	var most := 0
	for key in stats.popular:
		if int(stats.popular[key]) > most:
			most = int(stats.popular[key])
			result.popular_drink = key
	return result

func set_price(recipe: String, value: int) -> bool:
	if not prices.has(recipe) or value < 10 or value > 500:
		return notify("Цена должна быть от 10 до 500 ₽")
	prices[recipe] = value
	return _commit("Цена на доске обновлена. Принятые заказы сохраняют прежнюю цену")

func spawn_customer() -> Dictionary:
	if not shift_open or not accepting or customers.size() >= int(catalog.config.customers.max_present) or available_menu().is_empty():
		return {}
	var profiles: Array = catalog.config.customers.profiles
	var profile: Dictionary = profiles[(next_customer - 1) % profiles.size()]
	var items: Array = []
	var available := available_menu()
	var count := 1 + (1 if next_customer % 3 == 0 else 0) + (1 if next_customer % 7 == 0 else 0)
	var combined := {}
	for index in range(count):
		var preferred: Array = profile.preferred
		var recipe: String = preferred[(next_customer + index - 1) % preferred.size()]
		if recipe not in available:
			recipe = str(available[(next_customer + index) % available.size()])
		var item := {"recipe": recipe, "sugar": next_customer % 2 == 0, "syrup": next_customer % 5 == 0}
		if not inventory.can_reserve(catalog.requirements(items + [item])):
			item.sugar = false
			item.syrup = false
		if inventory.can_reserve(catalog.requirements(items + [item])):
			items.append(item)
	if items.is_empty():
		return {}
	combined = {"id": next_customer, "profile": (next_customer - 1) % profiles.size(), "name": profile.name,
		"state": "queue", "position": catalog.config.points.spawn.duplicate(), "items": items,
		"wait": 0.0, "warned": false, "order": 0}
	next_customer += 1
	customers.append(combined)
	changed.emit()
	return combined

func counter_customer() -> Dictionary:
	for c in customers:
		if c.state == "counter" and _distance(c.position, catalog.config.points.counter) < .12:
			return c
	return {}

func confirm_order(customer_id: int) -> bool:
	var c := counter_customer()
	if c.is_empty() or int(c.id) != customer_id or not accepting or not shift_open or not window_open:
		return notify("Покупатель ещё не у окна")
	if int(c.order) != 0 or not cash.payment.is_empty() or paid_orders().size() >= 3:
		return notify("Завершите текущую оплату или освободите один из трёх заказов")
	var requirements := catalog.requirements(c.items)
	if not inventory.reserve(requirements):
		c.state = "leaving"
		return notify("Извините, ингредиенты закончились. Оплата не принята")
	var items: Array = c.items.duplicate(true)
	var total := 0
	for item in items:
		item.price = catalog.price(item, prices)
		item.ready = false
		item.cup = {}
		total += int(item.price)
	var order := {"id": next_order, "customer": c.id, "items": items, "total": total, "paid": false,
		"status": "awaiting_payment", "carrier": false, "packed": [], "payment": {}}
	orders.append(order)
	c.order = next_order
	c.state = "payment"
	cash.begin(next_order, total)
	next_order += 1
	return _commit("Заказ подтверждён. Примите наличные в кассе", "paper")

func accept_cash() -> bool:
	if not cash.accept():
		return notify("Наличные уже приняты или нет оплаты")
	return _commit("Деньги в лотке. Соберите точную сдачу", "coins")

func select_change(denomination: int) -> bool:
	if not cash.select(denomination):
		return notify("Такого номинала нет в ящике")
	sound_requested.emit("coins")
	changed.emit()
	return true

func finalize_payment() -> bool:
	if cash.payment.is_empty() or not cash.correct():
		return notify("Сдача неверна. Сверьте сумму и номиналы")
	var order := order_by_id(int(cash.payment.order))
	if order.is_empty() or order.paid or paid_orders().size() >= 3:
		return notify("Оплата этого заказа недоступна")
	var receipt := cash.payment.duplicate(true)
	if not cash.commit():
		return false
	order.paid = true
	order.status = "paid"
	order.payment = receipt
	stats.revenue = int(stats.revenue) + int(order.total)
	stats.received = int(stats.received) + int(receipt.tender)
	stats.change = int(stats.change) + int(receipt.tender) - int(order.total)
	var c := customer_by_id(int(order.customer))
	c.state = "waiting"
	if selected_order == 0:
		selected_order = int(order.id)
		selected_item = 0
	return _commit("Заказ №%03d оплачен. Выберите напиток справа [Tab]" % int(order.id), "cash")

func cancel_payment() -> bool:
	if cash.payment.is_empty() or cash.payment.accepted:
		return notify("После приёма наличных завершите расчёт со сдачей")
	var order := order_by_id(int(cash.payment.order))
	inventory.release(catalog.requirements(order.items))
	customer_by_id(int(order.customer)).state = "leaving"
	orders.erase(order)
	cash.payment = {}
	return _commit("Неоплаченный заказ отменён")

func select_item(order_id: int, index: int) -> bool:
	var order := order_by_id(order_id)
	if order.is_empty() or not order.paid or order.status == "served" or index < 0 or index >= order.items.size():
		return notify("Выберите оплаченную позицию в заказах справа [Tab]")
	if not preparation.current.is_empty():
		return notify("Сначала закончите или выбросите текущий напиток")
	selected_order = order_id
	selected_item = index
	return _commit("Выбран заказ №%03d: %s" % [order_id, catalog.caption(order.items[index])], "paper")

func begin_drink() -> bool:
	var order := order_by_id(selected_order)
	if order.is_empty() or not order.paid or order.status not in ["paid", "ready"] or selected_item >= order.items.size():
		return notify("Выберите оплаченную позицию в заказах справа [Tab]")
	var item: Dictionary = order.items[selected_item]
	if item.ready or not preparation.begin(selected_order, selected_item, item):
		return notify("Эта позиция готова или рабочее место занято")
	return _commit("Возьмите кофе для выбранного напитка")

func _record_cost(resources: Dictionary) -> void:
	for key in resources:
		var amount := catalog.cost({key: resources[key]})
		stats.cost = int(stats.cost) + amount
		var category := "packaging_cost" if str(key).begins_with("cups_") or str(key).begins_with("lids_") or key == "carriers" else "ingredient_cost"
		stats[category] = int(stats[category]) + amount

func prepare_action(action: String) -> bool:
	if preparation.current.is_empty():
		if action != "beans" or not begin_drink():
			return notify("Выберите позицию заказа, затем возьмите кофе")
	var resources := preparation.resources_for(action, catalog) if action == preparation.next_step(catalog) else {}
	var error := preparation.act(action, inventory, catalog)
	if error != "":
		return notify(error)
	_record_cost(resources)
	if action == "place":
		var work := preparation.current.duplicate(true)
		var order := order_by_id(int(work.order))
		var item: Dictionary = order.items[int(work.index)]
		work.quality = ShiftDrinkQuality.evaluate(item, work, catalog)
		item.cup = work
		item.ready = true
		var all_ready := true
		for position in order.items:
			all_ready = all_ready and position.ready
		order.status = "ready" if all_ready else "paid"
		preparation.current = {}
		return _commit(str(work.quality.hint) + ". Стакан на стойке", "cup")
	var sound: String = {"grind": "grinder", "extract": "extraction", "steam": "steam", "cup": "cup"}.get(action, "machine")
	return _commit("Следующий шаг: " + str(ShiftRecipeCatalog.STEP_LABELS.get(preparation.next_step(catalog), "готово")), sound)

func discard_drink(order_id: int, index: int) -> bool:
	var order := order_by_id(order_id)
	if order.is_empty() or not order.paid or order.status == "served" or index < 0 or index >= order.items.size():
		return false
	var item: Dictionary = order.items[index]
	var used: Dictionary = item.cup
	var in_progress := not preparation.current.is_empty() and int(preparation.current.order) == order_id and int(preparation.current.index) == index
	if in_progress:
		used = preparation.current
	if used.is_empty():
		return notify("Эта позиция ещё не готовилась")
	# Only consumed resources are reserved again. Other paid orders retain theirs.
	if not inventory.reserve(used.consumed):
		return notify("Для переделки не хватает свободных запасов. Этот напиток можно выдать")
	stats.losses = int(stats.losses) + int(used.cost)
	item.cup = {}
	item.ready = false
	order.status = "paid"
	var customer := customer_by_id(int(order.customer))
	if customer.state == "pickup": customer.state = "waiting"
	order.packed.erase(index)
	if in_progress:
		preparation.current = {}
	return _commit("Напиток выброшен. Для переделки зарезервированы новые ингредиенты", "cup")

func pack_cup(order_id: int, index: int) -> bool:
	var order := order_by_id(order_id)
	if order.is_empty() or not order.paid or order.status == "served" or order.items.size() < 2 or index < 0 or index >= order.items.size() or not order.items[index].ready or index in order.packed:
		return notify("Поставьте каждый готовый стакан в держатель")
	if not order.carrier:
		if not inventory.consume("carriers", 1):
			return notify("Нет картонного держателя")
		order.carrier = true
		_record_cost({"carriers": 1})
	order.packed.append(index)
	return _commit("Стакан установлен в держатель", "cup")

func call_order(order_id: int) -> bool:
	var order := order_by_id(order_id)
	if order.is_empty() or not order.paid or order.status != "ready":
		return notify("Сначала приготовьте все позиции заказа")
	if order.items.size() > 1 and (not order.carrier or order.packed.size() != order.items.size()):
		return notify("Соберите все стаканы в картонный держатель")
	for c in customers:
		if c.state in ["payment", "pickup"]:
			return notify("У окна другой покупатель. Завершите расчёт или выдачу")
	for c in customers:
		if c.state == "counter": c.state = "queue"
	order.status = "called"
	customer_by_id(int(order.customer)).state = "pickup"
	return _commit("Заказ №%03d, подойдите к окну!" % order_id, "ui")

func serve_order(order_id: int, customer_id: int) -> bool:
	var order := order_by_id(order_id)
	var c := customer_by_id(customer_id)
	if order.is_empty() or not order.paid or order.status != "called" or c.is_empty():
		return notify("Заказ ещё не вызван или уже выдан")
	if int(order.customer) != customer_id:
		return notify("Это не мой номер заказа")
	if c.state != "pickup" or _distance(c.position, catalog.config.points.counter) > .15:
		return notify("Дождитесь, пока покупатель подойдёт к окну")
	order.status = "served"
	c.state = "leaving"
	stats.completed = int(stats.completed) + 1
	var good := true
	for item in order.items:
		stats.sold = int(stats.sold) + 1
		var name: String = catalog.recipes[item.recipe].name
		stats.popular[name] = int(stats.popular.get(name, 0)) + 1
		for error in item.cup.quality.errors:
			stats.errors[error] = int(stats.errors.get(error, 0)) + 1
		good = good and item.cup.quality.good
	if selected_order == order_id:
		selected_order = 0
	return _commit("Спасибо, очень вкусно!" if good else "Спасибо. В следующий раз попробуйте чуть точнее по рецепту", "serve")

static func _distance(a: Array, b: Array) -> float:
	return Vector3(float(a[0]), float(a[1]), float(a[2])).distance_to(Vector3(float(b[0]), float(b[1]), float(b[2])))

func tick(delta: float) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	clock += delta * float(catalog.config.clock_scale)
	if clock >= 86400:
		day += int(clock / 86400)
		clock = fmod(clock, 86400)
	preparation.tick(delta)
	if shift_open and accepting:
		spawn_elapsed += delta
		if spawn_elapsed >= float(catalog.config.customers.interval_seconds):
			spawn_elapsed = 0
			spawn_customer()
	var busy := false
	for c in customers:
		busy = busy or c.state in ["counter", "payment", "pickup"]
	var queue_index := 0
	var remove: Array = []
	for c in customers:
		c.wait = float(c.wait) + delta
		var point: Array = catalog.config.points.queue.duplicate()
		match str(c.state):
			"queue":
				if not busy and paid_orders().size() < 3 and accepting:
					c.state = "counter"
					busy = true
					point = catalog.config.points.counter
				else:
					point[2] = -1.1 - queue_index * .85
					queue_index += 1
			"counter", "payment", "pickup": point = catalog.config.points.counter
			"waiting":
				point = catalog.config.points.waiting.duplicate()
				point[2] = float(point[2]) + (int(c.id) % 3) * .8
			"leaving": point = catalog.config.points.exit
		var position := Vector3(float(c.position[0]), float(c.position[1]), float(c.position[2]))
		var destination := Vector3(float(point[0]), float(point[1]), float(point[2]))
		position = position.move_toward(destination, delta * float(catalog.config.customers.walk_speed))
		c.position = [position.x, position.y, position.z]
		if c.state == "leaving" and position.distance_to(destination) < .1:
			remove.append(c)
		elif float(c.wait) > float(catalog.config.customers.patience_seconds) and c.state in ["counter", "queue"]:
			c.state = "leaving"
		elif float(c.wait) > float(catalog.config.customers.patience_seconds) and c.state == "waiting" and not c.warned:
			c.warned = true
			customer_remark.emit(c, "Подскажите, заказ №%03d скоро будет готов?" % int(c.order))
	for c in remove:
		customers.erase(c)

func snapshot() -> Dictionary:
	return {"schema": 2, "location": catalog.config.location, "start_mode": start_mode,
		"business_name": business_name, "prologue_completed": false,
		"inventory": {"stock": inventory.stock, "reserved": inventory.reserved}, "till": cash.till,
		"payment": cash.payment, "preparation": preparation.current, "orders": orders, "customers": customers,
		"prices": prices, "stats": stats, "history": history, "window_open": window_open,
		"shift_open": shift_open, "accepting": accepting, "equipment": equipment,
		"clock": clock, "day": day, "next_order": next_order, "next_customer": next_customer,
		"spawn_elapsed": spawn_elapsed, "selected_order": selected_order, "selected_item": selected_item,
		"legacy_snapshot": legacy_snapshot}.duplicate(true)

static func whole(value: Variant, maximum: int = 1000000000) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= 0 and value == int(value) and value <= maximum

func validate(data: Dictionary) -> bool:
	if data.get("schema") != 2 or data.get("location") != catalog.config.location or data.get("start_mode") not in ["prototype_start", "dev02_migrated"]:
		return false
	for key in ["window_open", "shift_open", "accepting", "prologue_completed"]:
		if not data.get(key) is bool:
			return false
	for key in ["inventory", "till", "payment", "preparation", "prices", "stats", "equipment", "legacy_snapshot"]:
		if not data.get(key) is Dictionary:
			return false
	for key in ["orders", "customers", "history"]:
		if not data.get(key) is Array:
			return false
	if not data.get("business_name") is String or data.business_name.length() < 1 or data.business_name.length() > 24:
		return false
	for key in ["clock", "spawn_elapsed"]:
		if (not data.get(key) is float and not data.get(key) is int) or not is_finite(float(data[key])) or data[key] < 0:
			return false
	for key in ["day", "next_order", "next_customer", "selected_order", "selected_item"]:
		if not whole(data.get(key)):
			return false
	if not data.inventory.get("stock") is Dictionary or not data.inventory.get("reserved") is Dictionary:
		return false
	for key in catalog.config.stock:
		if not whole(data.inventory.stock.get(key)) or not whole(data.inventory.reserved.get(key, 0)) or int(data.inventory.reserved.get(key, 0)) > int(data.inventory.stock[key]):
			return false
	for value in ShiftCashRegister.DENOMINATIONS:
		if not whole(data.till.get(str(value))):
			return false
	for key in catalog.recipes:
		if not whole(data.prices.get(key), 500) or data.prices[key] < 10:
			return false
	for key in equipment:
		if not data.equipment.get(key) is bool:
			return false
	for key in _empty_stats():
		if key in ["popular", "errors"]:
			if not data.stats.get(key) is Dictionary:
				return false
		elif not whole(data.stats.get(key)):
			return false
	var ids: Array = []
	var cids: Array = []
	for c in data.customers:
		if not c is Dictionary or not whole(c.get("id")) or int(c.id) in cids or not whole(c.get("profile"), catalog.config.customers.profiles.size() - 1) or not c.get("name") is String:
			return false
		if c.get("state") not in ["queue", "counter", "payment", "waiting", "pickup", "leaving"] or not c.get("items") is Array or not c.get("warned") is bool or not whole(c.get("order")):
			return false
		if not _valid_point(c.get("position")) or (not c.get("wait") is float and not c.get("wait") is int) or not is_finite(float(c.wait)) or c.wait < 0:
			return false
		cids.append(int(c.id))
		for item in c.items:
			if not item is Dictionary or not catalog.valid_item(item):
				return false
	var paid := 0
	var expected_reserved := {}
	for o in data.orders:
		if not o is Dictionary or not whole(o.get("id")) or int(o.id) in ids or not whole(o.get("customer")) or not o.get("paid") is bool or not o.get("carrier") is bool or not o.get("packed") is Array or not o.get("payment") is Dictionary:
			return false
		if o.get("status") not in ["awaiting_payment", "paid", "ready", "called", "served"] or not o.get("items") is Array or o.items.size() < 1 or o.items.size() > 3 or not whole(o.get("total")):
			return false
		ids.append(int(o.id))
		if o.status != "served" and int(o.customer) not in cids:
			return false
		if (o.status == "awaiting_payment") == o.paid:
			return false
		if o.paid and o.status != "served":
			paid += 1
		var total := 0
		for i in range(o.items.size()):
			var item = o.items[i]
			if not item is Dictionary or not catalog.valid_item(item) or not item.get("ready") is bool or not item.get("cup") is Dictionary or not whole(item.get("price")):
				return false
			total += int(item.price)
			if item.ready and not _valid_work(item.cup, o, i, true):
				return false
			if o.status in ["ready", "called", "served"] and not item.ready:
				return false
			if o.status != "served" and not item.ready:
				var remaining := catalog.ingredients(item)
				if not data.preparation.is_empty() and data.preparation.get("order") == o.id and data.preparation.get("index") == i:
					if not _valid_work(data.preparation, o, i, false):
						return false
					for key in data.preparation.consumed:
						remaining[key] = int(remaining.get(key, 0)) - int(data.preparation.consumed[key])
				for key in remaining:
					expected_reserved[key] = int(expected_reserved.get(key, 0)) + int(remaining[key])
		if total != int(o.total):
			return false
		if o.status != "served" and o.items.size() > 1 and not o.carrier:
			expected_reserved.carriers = int(expected_reserved.get("carriers", 0)) + 1
		var packed_indices: Array = []
		for index in o.packed:
			if not whole(index, o.items.size() - 1) or not o.items[int(index)].ready:
				return false
			if int(index) in packed_indices or not o.carrier: return false
			packed_indices.append(int(index))
	if paid > 3:
		return false
	for key in catalog.config.stock:
		if int(data.inventory.reserved.get(key, 0)) != int(expected_reserved.get(key, 0)):
			return false
	if not data.preparation.is_empty():
		var w: Dictionary = data.preparation
		if not whole(w.get("order")) or not whole(w.get("index")) or int(w.order) not in ids: return false
		var found := false
		for o in data.orders:
			if int(o.id) != int(w.order): continue
			if not o.paid or o.status not in ["paid", "ready"] or int(w.index) >= o.items.size() or o.items[int(w.index)].ready: return false
			if not _valid_work(w, o, int(w.index), false): return false
			found = true
		if not found: return false
	if not _valid_payment(data.payment, data.orders, data.till):
		return false
	if data.next_order <= ids.max() if not ids.is_empty() else false:
		return false
	if not cids.is_empty() and data.next_customer <= cids.max(): return false
	if data.accepting and not data.shift_open: return false
	if data.shift_open and not data.window_open: return false
	return true

static func _valid_point(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for n in value:
		if (not n is float and not n is int) or not is_finite(float(n)) or absf(float(n)) > 100:
			return false
	return true

func _valid_work(w: Dictionary, order: Dictionary, index: int, finished: bool) -> bool:
	if w.get("order") != order.id or w.get("index") != index or not w.get("item") is Dictionary or not catalog.valid_item(w.item) or w.get("recipe") != order.items[index].recipe:
		return false
	if w.item.recipe != w.recipe or w.item.sugar != order.items[index].sugar or w.item.syrup != order.items[index].syrup: return false
	if not whole(w.get("step"), catalog.steps(w.item).size()) or not w.get("consumed") is Dictionary or not whole(w.get("cost")) or w.get("running") not in ["", "extract", "steam"]:
		return false
	for key in ["elapsed", "extraction_seconds", "steam_seconds"]:
		if (not w.get(key) is float and not w.get(key) is int) or not is_finite(float(w[key])) or w[key] < 0 or w[key] > 90:
			return false
	for key in w.consumed:
		if not catalog.config.stock.has(key) or not whole(w.consumed[key]):
			return false
	var expected := {}
	var sequence := catalog.steps(w.item)
	# Optional on old saves: interstitial physical cup/lid handling does not
	# advance a recipe index or consume a second copy of any ingredient.
	var handling_value: Variant = w.get("handling", "")
	if not handling_value is String: return false
	var handling: String = handling_value
	if handling not in ["", "cup_held", "cup_in_machine", "cup_ready_on_machine",
		"cup_full_held", "cup_on_counter", "lid_held", "lid_attached"]: return false
	var upcoming := str(sequence[int(w.step)]) if int(w.step) < sequence.size() else ""
	match handling:
		"cup_held":
			if upcoming != "cup": return false
		"cup_in_machine":
			if int(w.step) <= sequence.find("cup") or upcoming == "place": return false
		"cup_ready_on_machine", "cup_full_held", "cup_on_counter":
			if upcoming not in ["sugar", "syrup", "lid"]: return false
		"lid_held":
			if upcoming != "lid": return false
		"lid_attached":
			if upcoming != "place": return false
	var probe := ShiftCoffeePreparation.new()
	probe.current = {"recipe": w.recipe, "consumed": expected}
	for step_index in range(int(w.step)):
		for key in probe.resources_for(str(sequence[step_index]), catalog):
			var resources := probe.resources_for(str(sequence[step_index]), catalog)
			expected[key] = int(expected.get(key, 0)) + int(resources[key])
	if expected.size() != w.consumed.size(): return false
	for key in expected:
		if int(expected[key]) != int(w.consumed.get(key, -1)): return false
	if int(w.cost) != catalog.cost(expected): return false
	if finished and int(w.step) != sequence.size(): return false
	if not finished and int(w.step) >= sequence.size(): return false
	var expected_running := ""
	if int(w.step) > 0 and str(sequence[int(w.step) - 1]) in ["extract", "steam"]: expected_running = str(sequence[int(w.step) - 1])
	if w.running != expected_running: return false
	if finished and (not w.get("quality") is Dictionary or not w.quality.get("good") is bool or not w.quality.get("errors") is Array):
		return false
	return true

func _valid_payment(p: Dictionary, saved_orders: Array, till: Dictionary) -> bool:
	var unpaid: Array = saved_orders.filter(func(o: Dictionary) -> bool: return not o.paid)
	if p.is_empty():
		return unpaid.is_empty()
	if unpaid.size() != 1 or unpaid[0].id != p.get("order") or unpaid[0].total != p.get("total") or not p.get("accepted") is bool or not p.get("selected") is Dictionary or not p.get("notes") is Dictionary or not whole(p.get("tender")):
		return false
	var total := 0
	for key in p.notes:
		if int(key) not in ShiftCashRegister.DENOMINATIONS or not whole(p.notes[key]):
			return false
		total += int(key) * int(p.notes[key])
	if total != int(p.tender) or total < int(p.total):
		return false
	for key in p.selected:
		if int(key) not in ShiftCashRegister.DENOMINATIONS or not whole(p.selected[key]) or int(p.selected[key]) > int(till.get(key, 0)) + int(p.notes.get(key, 0)):
			return false
	return true

func restore(data: Dictionary) -> bool:
	if not validate(data):
		return false
	var d := data.duplicate(true)
	inventory.stock = d.inventory.stock
	inventory.reserved = d.inventory.reserved
	cash.till = d.till
	cash.payment = d.payment
	preparation.current = d.preparation
	orders = d.orders
	customers = d.customers
	# JSON stores all numbers as doubles; normalize identity/array indices.
	for order in orders:
		order.id = int(order.id)
		order.customer = int(order.customer)
		order.packed = order.packed.map(func(value) -> int: return int(value))
	for customer in customers:
		customer.id = int(customer.id)
		customer.order = int(customer.order)
		customer.profile = int(customer.profile)
	prices = d.prices
	stats = d.stats
	history = d.history
	equipment = d.equipment
	legacy_snapshot = d.legacy_snapshot
	window_open = d.window_open
	shift_open = d.shift_open
	accepting = d.accepting
	clock = float(d.clock)
	day = int(d.day)
	next_order = int(d.next_order)
	next_customer = int(d.next_customer)
	spawn_elapsed = float(d.spawn_elapsed)
	selected_order = int(d.selected_order)
	selected_item = int(d.selected_item)
	start_mode = d.start_mode
	business_name = d.business_name
	changed.emit()
	return true

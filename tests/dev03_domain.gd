extends SceneTree
var checks := 0
var failures := 0

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + text)

func fixture(recipe: String = "espresso_small", number: int = 1) -> CoffeeShiftSession:
	var s := CoffeeShiftSession.new()
	s.catalog.config.customers.profiles = [{"name": "Тестовый гость", "color": "536f75", "preferred": [recipe], "greeting": "Здравствуйте"}]
	s.catalog.config.customers.interval_seconds = 99999
	check(not s.open_shift(), "closed window blocks opening")
	s.toggle_window()
	check(not s.open_shift(), "equipment preparation required")
	for key in s.equipment: s.prepare_equipment(key)
	check(s.open_shift(), "prepared trailer opens")
	check(not s.toggle_window(), "window cannot close during shift")
	for i in range(number): s.spawn_customer()
	s.tick(20)
	return s

func pay(s: CoffeeShiftSession) -> int:
	var c := s.counter_customer()
	check(not c.is_empty(), "customer physically reaches counter")
	if c.is_empty(): return 0
	check(s.confirm_order(int(c.id)), "confirm request reserves resources")
	var id := int(s.cash.payment.get("order", 0))
	check(not s.select_item(id, 0), "cannot select unpaid order for preparation")
	check(not s.finalize_payment(), "cannot pay before accepting tender")
	check(s.accept_cash(), "accept tender once")
	check(not s.accept_cash(), "duplicate tender rejected")
	var change := int(s.cash.payment.tender) - int(s.cash.payment.total)
	if change > 0:
		check(not s.finalize_payment(), "wrong change rejected")
		var rest := change
		for denomination in ShiftCashRegister.DENOMINATIONS:
			while rest >= denomination:
				check(s.select_change(denomination), "select actual denomination")
				rest -= denomination
	check(s.finalize_payment(), "exact change commits sale")
	check(not s.finalize_payment(), "payment is idempotent")
	check(s.validate(s.snapshot()), "paid snapshot validates")
	return id

func cook(s: CoffeeShiftSession, id: int, index: int = 0, bad: bool = false) -> void:
	check(s.select_item(id, index), "player chooses paper item")
	var item: Dictionary = s.order_by_id(id).items[index]
	var steps := s.catalog.steps(item)
	for step in steps:
		if step == "stop": s.tick(.2 if bad else 10.0)
		if step == "stop_steam": s.tick(5 if s.catalog.recipes[item.recipe].drink == "cappuccino" else 3)
		check(s.prepare_action(step), "manual step: " + str(step))
		check(s.validate(s.snapshot()), "safe checkpoint after " + str(step))
	check(s.order_by_id(id).items[index].ready, "physical cup ready after complete recipe")

func serve(s: CoffeeShiftSession, id: int) -> void:
	var order := s.order_by_id(id)
	if order.items.size() > 1:
		check(not s.call_order(id), "multiple cups need carrier")
		for i in range(order.items.size()): check(s.pack_cup(id, i), "pack cup individually")
	check(s.call_order(id), "call order by number")
	check(not s.serve_order(id, int(order.customer) + 100), "wrong customer rejected")
	s.tick(15)
	check(s.serve_order(id, int(order.customer)), "serve only after customer arrives")
	var revenue := int(s.stats.revenue)
	check(not s.serve_order(id, int(order.customer)), "duplicate serving blocked")
	check(int(s.stats.revenue) == revenue, "serving never credits second revenue")
	check(s.validate(s.snapshot()), "served snapshot valid")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog := ShiftRecipeCatalog.new()
	for recipe in catalog.recipes:
		var s := fixture(recipe)
		var initial := s.cash.balance()
		var id := pay(s)
		check(id > 0, "paid order created")
		if id == 0: continue
		var agreed := int(s.order_by_id(id).total)
		s.set_price(recipe, 300)
		check(int(s.order_by_id(id).total) == agreed, "agreed price immutable")
		check(not s.close_shift(), "unfinished paid orders prevent closure")
		check(not s.accepting, "closing stops new requests")
		cook(s, id)
		check(s.order_by_id(id).items[0].cup.quality.good, "correct recipe has good quality")
		serve(s, id)
		check(s.cash.balance() == initial + agreed, "cash increase equals revenue, not tender")
		check(s.close_shift(), "close after serving")
		check(s.report().profit == agreed * 100 - int(s.stats.cost), "profit uses ingredient cents exactly")
		check(s.stats.cost == s.stats.ingredient_cost + s.stats.packaging_cost, "cost breakdown reconciles")
		check(s.validate(s.snapshot()), "closed snapshot validates")
	var s := fixture("cappuccino_standard")
	var id := pay(s)
	cook(s, id, 0, true)
	check(not s.order_by_id(id).items[0].cup.quality.good, "extraction mistake affects quality")
	var used := int(s.stats.cost)
	check(s.discard_drink(id, 0), "discard permits manual remake")
	check(int(s.stats.losses) == used, "remake losses tracked once")
	cook(s, id)
	check(s.stats.cost == used * 2, "remake consumes fresh stock exactly once")
	serve(s, id)
	var saved := s.snapshot()
	var loaded := CoffeeShiftSession.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(saved))), "JSON roundtrip restores closed-out order")
	check(JSON.stringify(loaded.snapshot()) == JSON.stringify(saved), "restoration does not duplicate anything")
	check(not loaded.serve_order(id, int(loaded.order_by_id(id).customer)), "served state remains terminal after load")
	var limits := fixture("espresso_small", 5)
	for i in range(3):
		var current := pay(limits)
		check(current > 0, "paid slot admitted")
		limits.tick(4)
	check(limits.paid_orders().size() == 3, "exactly three active paid orders")
	check(limits.counter_customer().is_empty(), "fourth request held in queue")
	check(not limits.confirm_order(int(limits.customers[3].id)), "fourth payment blocked")
	check(limits.validate(limits.snapshot()), "three-order snapshot valid")
	var multi := fixture("latte_large", 3)
	for i in range(2):
		var current := pay(multi)
		cook(multi, current)
		serve(multi, current)
		multi.tick(5)
	var last := pay(multi)
	var order := multi.order_by_id(last)
	check(order.items.size() == 2, "request supports multiple drinks")
	for i in range(order.items.size()): cook(multi, last, i)
	serve(multi, last)
	var no_stock := CoffeeShiftSession.new()
	no_stock.inventory.stock.coffee = 0
	check(no_stock.available_menu().is_empty(), "stockout removes unavailable drinks")
	var corrupt := saved.duplicate(true)
	corrupt.inventory.stock.coffee = -1
	check(not loaded.restore(corrupt), "reject negative stock atomically")
	check(JSON.stringify(loaded.snapshot()) == JSON.stringify(saved), "invalid load leaves session unchanged")
	var payment_session := fixture()
	var c := payment_session.counter_customer()
	payment_session.confirm_order(int(c.id))
	payment_session.accept_cash()
	payment_session.select_change(10)
	var partial := payment_session.snapshot()
	var resumed := CoffeeShiftSession.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(partial))), "unfinished cash operation persists")
	check(resumed.cash.selected_total() == 10 and not resumed.accept_cash(), "escrow and selected change survive once")
	check(not resumed.cancel_payment(), "accepted tender cannot vanish by cancellation")
	var exact_amount := int(resumed.cash.payment.total)
	var till_before := resumed.cash.balance()
	check(resumed.finalize_payment(true), "one-step payment can settle restored old cash escrow")
	check(resumed.cash.balance() == till_before + exact_amount and resumed.stats.revenue == exact_amount and resumed.stats.change == 0, "migration posts the exact net amount once")
	check(resumed.validate(resumed.snapshot()), "legacy payment converts to a valid current career")
	var cash := ShiftCashRegister.new({"1000":0,"500":0,"100":0,"50":0,"10":0,"5":0,"2":0,"1":0})
	cash.begin(1, 60)
	check(not cash.accept(), "shortage detected before accepting tender")
	check(not cash.select(10), "cannot invent missing denominations")
	check(not cash.commit(), "insufficient change cannot commit")
	check(cash.request_exact() and cash.accept() and cash.commit(), "ask for exact payment resolves shortage without free money")
	check(cash.balance() == 60, "exact tender credited once")
	check(ShiftAudio.make_sound("grinder").data.size() > 1000, "original effects generate PCM")
	print("DEV03 DOMAIN: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

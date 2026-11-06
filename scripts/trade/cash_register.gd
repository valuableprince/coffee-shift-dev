class_name ShiftCashRegister
extends RefCounted
## Customer tender is escrow until exact, physically available change is committed.
const DENOMINATIONS := [1000, 500, 100, 50, 10, 5, 2, 1]
var till: Dictionary = {}
var payment: Dictionary = {}

func _init(initial: Dictionary = {}) -> void:
	till = initial.duplicate(true)

func balance() -> int:
	var total := 0
	for key in till:
		total += int(key) * int(till[key])
	return total

func begin(order_id: int, total: int) -> bool:
	if not payment.is_empty() or total <= 0:
		return false
	# 100-ruble notes existed in the early 2010s; no anachronistic 200/2000 note.
	var notes := ceili(float(total) / 100.0)
	payment = {"order": order_id, "total": total, "tender": notes * 100,
		"accepted": false, "selected": {}, "notes": {"100": notes}}
	return true

func accept() -> bool:
	if payment.is_empty() or payment.accepted or not can_make_change():
		return false
	payment.accepted = true
	return true

func can_make_change() -> bool:
	if payment.is_empty(): return false
	var target := int(payment.tender) - int(payment.total)
	var possible := {0: true}
	for value in DENOMINATIONS:
		var count := mini(int(till.get(str(value), 0)) + int(payment.notes.get(str(value), 0)), target / value)
		var before := possible.keys()
		for amount in before:
			for number in range(1, count + 1):
				var result: int = int(amount) + number * int(value)
				if result <= target: possible[result] = true
	return possible.has(target)

func request_exact() -> bool:
	if payment.is_empty() or payment.accepted: return false
	var remaining := int(payment.total)
	var notes := {}
	for value in DENOMINATIONS:
		var count: int = remaining / int(value)
		if count > 0:
			notes[str(value)] = count
			remaining -= count * value
	payment.tender = int(payment.total)
	payment.notes = notes
	return true

func selected_total() -> int:
	var total := 0
	for key in payment.get("selected", {}):
		total += int(key) * int(payment.selected[key])
	return total

func select(denomination: int) -> bool:
	var key := str(denomination)
	if payment.is_empty() or not payment.accepted or denomination not in DENOMINATIONS:
		return false
	var available := int(till.get(key, 0)) + int(payment.notes.get(key, 0))
	if int(payment.selected.get(key, 0)) >= available:
		return false
	payment.selected[key] = int(payment.selected.get(key, 0)) + 1
	return true

func reset_change() -> void:
	if not payment.is_empty():
		payment.selected = {}

func correct() -> bool:
	return not payment.is_empty() and payment.accepted and selected_total() == int(payment.tender) - int(payment.total)

func commit() -> bool:
	if not correct():
		return false
	for key in payment.notes:
		till[key] = int(till.get(key, 0)) + int(payment.notes[key])
	for key in payment.selected:
		till[key] = int(till.get(key, 0)) - int(payment.selected[key])
	payment = {}
	return true

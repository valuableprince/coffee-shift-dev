class_name ShiftInventory
extends RefCounted
## Paid orders hold resources. Actual use transfers reserved -> consumed once.
var stock: Dictionary = {}
var reserved: Dictionary = {}

func _init(initial: Dictionary = {}) -> void:
	stock = initial.duplicate(true)

func available(key: String) -> int:
	return int(stock.get(key, 0)) - int(reserved.get(key, 0))

func can_reserve(resources: Dictionary) -> bool:
	for key in resources:
		if available(key) < int(resources[key]):
			return false
	return true

func reserve(resources: Dictionary) -> bool:
	if not can_reserve(resources):
		return false
	for key in resources:
		reserved[key] = int(reserved.get(key, 0)) + int(resources[key])
	return true

func consume(key: String, amount: int) -> bool:
	if amount < 0 or int(reserved.get(key, 0)) < amount or int(stock.get(key, 0)) < amount:
		return false
	stock[key] = int(stock[key]) - amount
	reserved[key] = int(reserved[key]) - amount
	return true

func release(resources: Dictionary) -> void:
	for key in resources:
		reserved[key] = maxi(0, int(reserved.get(key, 0)) - int(resources[key]))

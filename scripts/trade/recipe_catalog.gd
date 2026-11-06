class_name ShiftRecipeCatalog
extends RefCounted
## Prototype balance belongs to data, independently from machines and UI.
const STOCK_LABELS := {"coffee":"Кофе, г", "milk":"Молоко, мл", "water":"Вода, мл", "sugar":"Сахар, порций", "syrup":"Сироп, мл", "cups_small":"Стаканы 40 мл", "cups_standard":"Стаканы С", "cups_large":"Стаканы Б", "lids_small":"Крышки 40 мл", "lids_standard":"Крышки С", "lids_large":"Крышки Б", "carriers":"Держатели"}
const STEP_LABELS := {"beans":"взять кофе", "grind":"смолоть кофе", "filter":"взять чистый портафильтр", "dose":"дозировать и утрамбовать кофе", "install":"установить портафильтр", "cup":"поставить стакан", "extract":"запустить экстракцию", "stop":"остановить экстракцию", "water":"добавить горячую воду", "milk":"взять молоко", "pitcher":"подготовить питчер", "steam":"включить пар", "stop_steam":"остановить пар", "pour":"добавить молоко", "sugar":"добавить сахар", "syrup":"добавить ваниль", "lid":"закрыть крышкой", "place":"поставить на выдачу"}

var config: Dictionary
var recipes: Dictionary

func _init() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/trade/prototype.json"))
	recipes = config.recipes

func valid_item(item: Dictionary) -> bool:
	return recipes.has(item.get("recipe", "")) and item.get("sugar") is bool and item.get("syrup") is bool

func ingredients(item: Dictionary) -> Dictionary:
	var result: Dictionary = recipes[item.recipe].ingredients.duplicate(true)
	if item.sugar:
		result.sugar = 1
	if item.syrup:
		result.syrup = 10
	return result

func requirements(items: Array) -> Dictionary:
	var result := {}
	for item in items:
		for key in ingredients(item):
			result[key] = int(result.get(key, 0)) + int(ingredients(item)[key])
	if items.size() > 1:
		result.carriers = 1
	return result

func steps(item: Dictionary) -> Array:
	var result: Array = recipes[item.recipe].steps.duplicate()
	var at := result.find("lid")
	if item.sugar:
		result.insert(at, "sugar")
		at += 1
	if item.syrup:
		result.insert(at, "syrup")
	return result

func caption(item: Dictionary) -> String:
	var r: Dictionary = recipes[item.recipe]
	return "%s · %s%s%s" % [r.name, r.size, " · сахар" if item.sugar else "", " · ваниль" if item.syrup else ""]

func price(item: Dictionary, prices: Dictionary) -> int:
	return int(prices[item.recipe]) + (10 if item.syrup else 0)

func cost(resources: Dictionary) -> int:
	var total := 0
	for key in resources:
		total += int(resources[key]) * int(config.unit_cost_kopecks[key])
	return total

class_name ShiftCoffeePreparation
extends RefCounted
## One physical work-in-progress, independently from finished cups on the rack.
var current: Dictionary = {}

func next_step(catalog: ShiftRecipeCatalog) -> String:
	if current.is_empty():
		return ""
	var sequence := catalog.steps(current.item)
	return str(sequence[int(current.step)]) if int(current.step) < sequence.size() else ""

func begin(order_id: int, item_index: int, item: Dictionary) -> bool:
	if not current.is_empty():
		return false
	current = {"order": order_id, "index": item_index, "item": item.duplicate(true), "recipe": item.recipe,
		"step": 0, "elapsed": 0.0, "running": "", "extraction_seconds": 0.0,
		"steam_seconds": 0.0, "consumed": {}, "cost": 0}
	return true

func tick(delta: float) -> void:
	if not current.is_empty() and current.running != "":
		current.elapsed = minf(90, float(current.elapsed) + delta)

func resources_for(step: String, catalog: ShiftRecipeCatalog) -> Dictionary:
	var recipe: Dictionary = catalog.recipes[current.recipe]
	var result := {}
	match step:
		"beans": result.coffee = int(recipe.ingredients.coffee)
		"extract": result.water = mini(60, int(recipe.ingredients.water)) if recipe.drink == "americano" else int(recipe.ingredients.water)
		"water": result.water = int(recipe.ingredients.water) - int(current.consumed.get("water", 0))
		"milk": result.milk = int(recipe.ingredients.milk)
		"sugar": result.sugar = 1
		"syrup": result.syrup = 10
		"cup", "lid":
			for key in recipe.ingredients:
				if (step == "cup" and str(key).begins_with("cups_")) or (step == "lid" and str(key).begins_with("lids_")):
					result[key] = 1
	return result

func act(step: String, inventory: ShiftInventory, catalog: ShiftRecipeCatalog) -> String:
	if current.is_empty() or step != next_step(catalog):
		return "Сначала выполните следующий шаг рецепта"
	var resources := resources_for(step, catalog)
	for key in resources:
		if int(inventory.reserved.get(key, 0)) < int(resources[key]) or int(inventory.stock.get(key, 0)) < int(resources[key]):
			return "Недостаточно: " + str(ShiftRecipeCatalog.STOCK_LABELS.get(key, key))
	for key in resources:
		inventory.consume(key, int(resources[key]))
		current.consumed[key] = int(current.consumed.get(key, 0)) + int(resources[key])
	current.cost = int(current.cost) + catalog.cost(resources)
	if step in ["extract", "steam"]:
		current.running = step
		current.elapsed = 0.0
	elif step in ["stop", "stop_steam"]:
		current["extraction_seconds" if step == "stop" else "steam_seconds"] = float(current.elapsed)
		current.running = ""
	current.step = int(current.step) + 1
	return ""

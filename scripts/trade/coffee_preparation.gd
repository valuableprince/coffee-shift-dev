class_name ShiftCoffeePreparation
extends RefCounted
## One physical work-in-progress, independently from finished cups on the rack.
const GRIND_SECONDS := .75
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

func tick(delta: float) -> bool:
	if current.is_empty() or current.running == "":
		return false
	current.elapsed = minf(90, float(current.elapsed) + delta)
	if current.running != "grind" or float(current.elapsed) < GRIND_SECONDS:
		return false
	current.running = ""
	current.elapsed = 0.0
	return true

func restore_placements(catalog: ShiftRecipeCatalog) -> void:
	if current.is_empty():
		return
	var upcoming := next_step(catalog)
	if not current.has("portafilter"):
		match upcoming:
			"beans", "grind": current.portafilter = "at_machine_storage"
			"filter": current.portafilter = "in_grinder"
			"dose", "install": current.portafilter = "in_hand"
			_: current.portafilter = "installed"
		if current.get("handling", "") == "cup_in_machine" and upcoming in ["sugar", "syrup", "lid"]:
			current.handling = "cup_ready_on_machine"
	if str(current.get("handling", "")) == "":
		var sequence := catalog.steps(current.item)
		if int(current.step) <= sequence.find("cup"):
			return
		match upcoming:
			"sugar", "syrup", "lid": current.handling = "cup_ready_on_machine"
			"place": current.handling = "capped_held"
			_: current.handling = "cup_in_machine"

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
	if current.has("portafilter") and not _at_workstation(step):
		return "Сначала подготовьте предметы для этого шага"
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
	if current.has("portafilter"):
		_update_placements(step, catalog)
	return ""

func _at_workstation(step: String) -> bool:
	var placement: String = current.portafilter
	var cup := str(current.get("handling", ""))
	match step:
		"beans", "grind", "filter": return placement == "in_grinder" and current.running == ""
		"dose": return placement == "on_tamping_mat" and current.get("tamper_held", false)
		"install": return placement == "in_hand"
		"cup": return cup == "cup_held"
		"extract": return placement == "installed" and cup == "cup_in_machine"
		"water": return cup == "cup_at_water_tap"
		"pour": return cup == "cup_in_machine"
		"sugar", "syrup": return cup == "cup_on_counter"
		"lid": return cup == "lid_held"
		"place": return cup == "capped_held"
	return true

func _update_placements(step: String, catalog: ShiftRecipeCatalog) -> void:
	match step:
		"grind":
			current.running = "grind"
			current.elapsed = 0.0
		"filter": current.portafilter = "in_hand"
		"dose": current.erase("tamper_held")
		"install": current.portafilter = "installed"
		"cup": current.handling = "cup_in_machine"
		"stop", "pour":
			if next_step(catalog) in ["sugar", "syrup", "lid"]:
				current.handling = "cup_ready_on_machine"
		"water": current.handling = "cup_ready_at_water_tap"
		"lid": current.handling = "lid_attached"
		"place":
			current.erase("handling")
			current.erase("portafilter")

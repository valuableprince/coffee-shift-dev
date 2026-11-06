class_name ShiftDrinkQuality
extends RefCounted

static func evaluate(item: Dictionary, actual: Dictionary, catalog: ShiftRecipeCatalog) -> Dictionary:
	var recipe: Dictionary = catalog.recipes[item.recipe]
	var errors: Array = []
	if actual.recipe != item.recipe:
		errors.append("Другой напиток или размер")
	var seconds := float(actual.get("extraction_seconds", 0))
	if seconds < float(recipe.extraction[0]) - 1.0:
		errors.append("Эспрессо получился водянистым")
	elif seconds > float(recipe.extraction[1]) + 2.0:
		errors.append("Эспрессо получился слишком крепким")
	if recipe.has("foam"):
		var steam := float(actual.get("steam_seconds", 0))
		if steam < float(recipe.foam[0]) - .5 or steam > float(recipe.foam[1]) + 1.0:
			errors.append("Молочная пена не соответствует рецепту")
	var expected := catalog.ingredients(item)
	var consumed: Dictionary = actual.get("consumed", {})
	for key in expected:
		if int(consumed.get(key, 0)) != int(expected[key]):
			errors.append("Нарушены пропорции или добавки")
			break
	return {"good": errors.is_empty(), "errors": errors,
		"hint": "Напиток получился хорошо" if errors.is_empty() else str(errors[0])}

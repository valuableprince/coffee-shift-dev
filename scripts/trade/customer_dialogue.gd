class_name CustomerDialogue
extends RefCounted
## Display policy only. Acquaintance is supplied by the domain, never inferred
## from a profile label or a repeat visit. Legacy saves are unknown by default.
static func speaker_name(customer: Dictionary) -> String:
	if customer.get("name_known", false) == true:
		var known := str(customer.get("name", "")).strip_edges()
		if not known.is_empty(): return known
	return "Покупатель"


## Customer speech uses the names and sizes from the recipe catalog.
static func order_request(greeting: String, items: Array, catalog: ShiftRecipeCatalog) -> String:
	var names: Array[String] = []
	for item in items:
		var recipe: Dictionary = catalog.recipes[item.recipe]
		var name := "%s %s" % [str(recipe.size).to_lower(), str(recipe.name).to_lower()]
		var extras: Array[String] = []
		if item.get("sugar", false): extras.append("сахаром")
		if item.get("syrup", false): extras.append("ванильным сиропом")
		if not extras.is_empty(): name += " с " + " и ".join(extras)
		names.append(name)
	var order_text := ""
	for i in range(names.size()):
		if i > 0: order_text += " и " if i == names.size() - 1 else ", "
		order_text += names[i]
	var prefix := greeting.strip_edges()
	return prefix + " " + order_text + ("?" if prefix.to_lower().ends_with("можно") else ".")

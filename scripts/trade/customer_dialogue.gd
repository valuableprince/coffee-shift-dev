class_name CustomerDialogue
extends RefCounted
## Display policy only. Acquaintance is supplied by the domain, never inferred
## from a profile label or a repeat visit. Legacy saves are unknown by default.
static func speaker_name(customer: Dictionary) -> String:
	if customer.get("name_known", false) == true:
		var known := str(customer.get("name", "")).strip_edges()
		if not known.is_empty(): return known
	return "Покупатель"

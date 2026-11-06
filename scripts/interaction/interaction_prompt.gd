class_name InteractionPrompt
extends RefCounted
## Shared presentation of the existing get_prompt interaction interface.
static func text(caption: String, available_action: String) -> String:
	return caption if available_action.is_empty() else caption + " — " + available_action

class_name ToolDefinition
extends RefCounted

const TOOLS := {
	"cleaning_kit": {"title": "Ветошь / средство", "shape": "cloth", "color": "9cae8e"},
	"brush": {"title": "Щётка", "shape": "brush", "color": "b49360"},
	"scraper": {"title": "Шпатель", "shape": "scraper", "color": "7b9e9c"},
	"screwdriver": {"title": "Отвёртка", "shape": "driver", "color": "bd6e45"},
	"wrench": {"title": "Ключ", "shape": "wrench", "color": "9ca6a1"},
	"roller": {"title": "Ролик для уплотнений", "shape": "roller", "color": "677e57"}
}

static func title(tool_id: StringName) -> String:
	return str(TOOLS.get(str(tool_id), {}).get("title", "Пусто"))

static func known(tool_id: StringName) -> bool:
	return TOOLS.has(str(tool_id))

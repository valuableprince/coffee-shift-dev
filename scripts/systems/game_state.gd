extends RefCounted
## Persistent player economy. Temporary shift data is kept in main.gd.

const SAVE_PATH = "user://coffee_shift_save.json"

var day := 1
var balance := 35000
var reputation := 50
var upgraded := false
var stock: Dictionary = {"beans": 20, "milk": 20, "cups": 20}

func load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var raw: Variant = JSON.parse_string(file.get_as_text())
    if typeof(raw) != TYPE_DICTIONARY:
        return
    var data: Dictionary = raw
    day = maxi(1, int(data.get("day", day)))
    balance = int(data.get("balance", balance))
    reputation = clampi(int(data.get("reputation", reputation)), 0, 100)
    upgraded = bool(data.get("upgraded", upgraded))
    var saved: Variant = data.get("stock", {})
    if typeof(saved) == TYPE_DICTIONARY:
        for ingredient in stock.keys():
            stock[ingredient] = maxi(0, int(saved.get(ingredient, stock[ingredient])))

func save() -> bool:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({
        "schema_version": 1,
        "day": day,
        "balance": balance,
        "reputation": reputation,
        "stock": stock,
        "upgraded": upgraded
    }, "  "))
    file.flush()
    return true

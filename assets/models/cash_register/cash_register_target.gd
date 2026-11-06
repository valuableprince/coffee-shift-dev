class_name CoffeeShiftCashRegisterTarget
extends ShiftWorkstation
## Compatible with CoffeeShiftPlayer.get_interactable() from DEV-03.


func _ready() -> void:
	set_meta("action", "cash_register_drawer")


func register() -> CoffeeShiftCashRegister:
	var node: Node = self
	while node != null:
		if node is CoffeeShiftCashRegister:
			return node as CoffeeShiftCashRegister
		node = node.get_parent()
	return null


func get_prompt() -> String:
	if world != null: return super.get_prompt()
	var cash: CoffeeShiftCashRegister = register()
	return cash.get_prompt() if cash != null else ""


func interact() -> void:
	if world != null:
		super.interact()
		return
	var cash: CoffeeShiftCashRegister = register()
	if cash != null:
		cash.toggle_drawer()

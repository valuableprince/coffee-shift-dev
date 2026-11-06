class_name TrailerShell
extends RefCounted
## The only shell factory. No procedural walls, floor, roof or chassis remain.

const SCENE := preload("res://assets/models/coffee_trailer/coffee_trailer.tscn")

static func build(parent: Node3D) -> CoffeeShiftTrailerAsset:
	var asset: CoffeeShiftTrailerAsset = SCENE.instantiate()
	asset.name = "Shell"
	asset.handle_first_person_input = false
	parent.add_child(asset)
	return asset

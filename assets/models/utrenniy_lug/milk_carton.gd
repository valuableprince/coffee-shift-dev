@tool
extends Node3D
## Plain white/blue gable-top milk carton, no lettering or illustrations.
const A := preload("res://scripts/prototype/asset_geometry.gd")
const G := preload("res://scripts/prototype/prototype_geometry.gd")
const W := .078
const D := .076
const H := .245
@export var opened := false

func _ready() -> void:
	_rebuild()

func set_opened(value: bool) -> void:
	opened = value
	if is_inside_tree(): _rebuild()

func _rebuild() -> void:
	var root := A.reset(self)
	var white := Color("e7e9df")
	var blue := Color("487ca3")
	G.box(root, "PaperBody", Vector3(0,.0975,0), Vector3(W,.195,D), white, false)
	G.box(root, "BlueBaseFold", Vector3(0,.013,0), Vector3(W+.0005,.026,D+.0005), blue, false)
	var roof: Array[Vector3] = [Vector3(.195,W/2,D/2), Vector3(.229,W/2,.003)]
	var outline: Array[Vector2] = [Vector2(-1,1), Vector2(1,1), Vector2(1,-1), Vector2(-1,-1)]
	A.loft(root, "GableRoof", roof, outline, A.material(blue))
	G.box(root, "SealedPaperSeam", Vector3(0,.237,0), Vector3(W+.002,.016,.009), Color("d3ddd9"), false)
	G.box(root, "SideFold", Vector3(-W/2-.0006,.10,0), Vector3(.0012,.17,.009), Color("cfd9d7"), false)
	if opened:
		var spout := G.box(root, "OpenSpout", Vector3(W/2+.006,.215,0), Vector3(.018,.012,.026), white, false)
		spout.rotation.z = -.35
	A.collider(root, Vector3(W,H,D))

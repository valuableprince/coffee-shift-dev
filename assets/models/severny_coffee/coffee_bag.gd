@tool
extends Node3D
## Closed standing kraft/foil coffee pouch; base at Y=0, all sides capped.
const A := preload("res://scripts/prototype/asset_geometry.gd")
const G := preload("res://scripts/prototype/prototype_geometry.gd")

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	var root := A.reset(self)
	var outline: Array[Vector2] = [Vector2(-.8,1),Vector2(.8,1),Vector2(1,.7),Vector2(1,-.7),Vector2(.8,-1),Vector2(-.8,-1),Vector2(-1,-.7),Vector2(-1,.7)]
	A.loft(root, "SealedPouch", [Vector3(0,.079,.041),Vector3(.014,.087,.049),Vector3(.18,.084,.046),Vector3(.24,.076,.033),Vector3(.275,.080,.006)], outline, A.material(Color("b2976f")))
	G.box(root, "BottomFold", Vector3(0,.008,0), Vector3(.15,.012,.075), Color("9a805b"), false)
	G.box(root, "HeatSealedTop", Vector3(0,.285,0), Vector3(.163,.020,.013), Color("33584b"), false)
	for y in [.279,.284,.289]:
		G.box(root, "Crimp", Vector3(0,y,.0073), Vector3(.153,.0015,.001), Color("73917a"), false)
	for side in [-1,1]:
		G.box(root, "DarkGreenBand", Vector3(0,.110,.050*side), Vector3(.134,.084,.0015), Color("345d4e"), false)
		var bean := G.cylinder(root, "CoffeeBean", Vector3(0,.112,.052*side), .023, .004, Color("c5aa7c"), false)
		bean.rotation.x = PI/2
		bean.scale = Vector3(.70,1,1.15)
		G.box(root, "BeanCrease", Vector3(0,.112,.055*side), Vector3(.002,.037,.0015), Color("6e573b"), false)
	var valve := G.cylinder(root, "DegassingValve", Vector3(.043,.206,.041), .007, .003, Color("79694f"), false)
	valve.rotation.x = PI/2
	A.collider(root, Vector3(.176,.298,.100))

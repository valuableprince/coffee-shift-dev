class_name BaristaHand
extends RefCounted
## Shared original PS2+ hand geometry used by tools and equipment inspection.
const G := preload("res://scripts/prototype/prototype_geometry.gd")

static func build(holder: Node3D) -> void:
	G.box(holder,"Sleeve",Vector3(.035,-.12,.20),Vector3(.10,.11,.22),Color("4b645e"),false)
	G.box(holder,"Wrist",Vector3(.015,-.07,.065),Vector3(.068,.072,.11),Color("c3a381"),false)
	G.box(holder,"Palm",Vector3(0,-.04,.015),Vector3(.074,.085,.052),Color("c6a785"),false)
	for i in range(4):
		var finger := G.box(holder,"Finger%d" % i,Vector3(-.027+float(i)*.018,-.014,-.021),Vector3(.015,.046,.028),Color("bd9a79"),false)
		finger.rotation.x = -.5
	G.box(holder,"Thumb",Vector3(.045,-.035,-.01),Vector3(.033,.026,.032),Color("c6a785"),false)
	for mesh in holder.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

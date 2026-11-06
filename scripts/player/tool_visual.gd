class_name ToolVisual
extends RefCounted
## Shared stylized meshes: the picked-up object and the object held are identical.
const G := preload("res://scripts/prototype/prototype_geometry.gd")

static func build(parent: Node3D, tool_id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "ToolModel"
	parent.add_child(root)
	var data: Dictionary = ToolDefinition.TOOLS.get(str(tool_id), {})
	var color := Color(str(data.get("color", "a0a88c")))
	var shape := str(data.get("shape", "cloth"))
	if shape == "cloth":
		G.box(root,"FoldedCloth",Vector3(0,.03,0),Vector3(.18,.04,.13),color,false)
		for z in [-.04,0,.04]:
			G.box(root,"Fold",Vector3(.01,.052,z),Vector3(.15,.007,.006),color.lightened(.12),false)
	elif shape == "brush":
		G.box(root,"Grip",Vector3(0,-.05,0),Vector3(.035,.18,.04),color,false)
		G.box(root,"BrushBlock",Vector3(0,.06,0),Vector3(.18,.045,.07),color,false)
		for x in [-.07,-.035,0,.035,.07]:
			G.box(root,"Bristles",Vector3(x,.09,0),Vector3(.02,.045,.065),Color("d0bc85"),false)
	elif shape == "scraper":
		G.box(root,"Grip",Vector3(0,-.06,0),Vector3(.045,.16,.035),color,false)
		G.box(root,"SteelBlade",Vector3(0,.075,0),Vector3(.13,.14,.009),Color("b3c1b8"),false,.6)
	elif shape == "wrench":
		G.box(root,"Stem",Vector3(0,-.015,0),Vector3(.035,.26,.018),color,false,.65)
		for x in [-.032,.032]:
			G.box(root,"Jaw",Vector3(x,.13,0),Vector3(.025,.065,.025),color,false,.65)
	elif shape == "roller":
		G.box(root,"Grip",Vector3(0,-.075,0),Vector3(.04,.16,.04),color,false)
		G.box(root,"Axle",Vector3(0,.05,0),Vector3(.016,.12,.02),Color("9cab9d"),false,.6)
		var roller := G.cylinder(root,"RubberRoller",Vector3(0,.12,0),.045,.14,Color("3b4a3f"),false)
		roller.rotation.z = PI/2
	else:
		G.box(root,"Grip",Vector3(0,-.08,0),Vector3(.045,.13,.045),color,false)
		G.box(root,"Shaft",Vector3(0,.055,0),Vector3(.009,.18,.009),Color("bac5b8"),false,.65)
	return root

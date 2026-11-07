class_name ShiftCustomerVisual
extends Node3D
## Cohesive temporary PS2+ set. Original geometry, shared animation rig.
const G := preload("res://scripts/prototype/prototype_geometry.gd")
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var previous := Vector3.ZERO
var phase := 0.0
var label: Label3D
var world: Node3D
var customer_id: int

func build(color: Color, profile: int) -> void:
	G.box(self, "Jacket", Vector3(0, 1.13, 0), Vector3(.42, .53, .25), color, false)
	G.cylinder(self, "Neck", Vector3(0, 1.46, 0), .065, .12, Color("b99573"), false)
	G.box(self, "Head", Vector3(0, 1.63, 0), Vector3(.25, .29, .23), Color("c7a382"), false)
	G.box(self, "Hair", Vector3(0, 1.78, -.015), Vector3(.27, .09, .25), Color("493e34"), false)
	G.box(self, "Nose", Vector3(0, 1.63, .135), Vector3(.05, .06, .05), Color("b99573"), false)
	for x in [-.065, .065]:
		G.box(self, "Eye", Vector3(x, 1.69, .121), Vector3(.03, .018, .012), Color("393934"), false)
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(side * .115, .88, 0)
		add_child(leg)
		G.box(leg, "Trouser", Vector3(0, -.36, 0), Vector3(.16, .72, .19), Color("35454c"), false)
		G.box(leg, "Shoe", Vector3(0, -.80, .04), Vector3(.18, .13, .31), Color("353a36"), false)
		var arm := Node3D.new()
		arm.position = Vector3(side * .27, 1.35, 0)
		add_child(arm)
		G.box(arm, "Sleeve", Vector3(0, -.22, 0), Vector3(.14, .44, .17), color, false)
		G.box(arm, "Hand", Vector3(0, -.49, .01), Vector3(.12, .14, .13), Color("c7a382"), false)
		if side == -1:
			left_leg = leg
			left_arm = arm
		else:
			right_leg = leg
			right_arm = arm
	if profile == 1:
		G.box(self, "Backpack", Vector3(0, 1.18, -.23), Vector3(.32, .44, .18), Color("62694e"), false)
	elif profile == 0:
		G.box(self, "Tie", Vector3(0, 1.22, .136), Vector3(.06, .30, .012), Color("baad85"), false)
	label = G.sign_text(self, "", Vector3(0, 2.02, 0), Vector3.ZERO, 24)
	label.pixel_size = .0018
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var target := StaticBody3D.new()
	target.collision_layer = 2
	target.collision_mask = 0
	add_child(target)
	for bounds in [AABB(Vector3(-.32, .08, -.17), Vector3(.64, 1.36, .34)),
		AABB(Vector3(-.14, 1.44, -.15), Vector3(.28, .38, .31))]:
		var box := BoxShape3D.new()
		box.size = bounds.size
		var collision := CollisionShape3D.new()
		collision.shape = box
		collision.position = bounds.get_center()
		target.add_child(collision)

func get_prompt() -> String:
	return world.customer_action(customer_id)

func interact() -> void:
	if get_prompt() != "":
		world.show_customer(customer_id)

func sync(customer: Dictionary, delta: float) -> void:
	var point := Vector3(float(customer.position[0]), float(customer.position[1]), float(customer.position[2]))
	var direction := point - position
	var walking := direction.length() > .002
	position = point
	if walking:
		rotation.y = atan2(direction.x, direction.z)
	else:
		rotation.y = -PI / 2
	phase += delta * (7 if walking else 1.2)
	left_leg.rotation.x = sin(phase) * .32 if walking else 0.0
	right_leg.rotation.x = -left_leg.rotation.x
	left_arm.rotation.x = -left_leg.rotation.x * .7
	right_arm.rotation.x = left_leg.rotation.x * .7
	if customer.state in ["counter", "payment", "pickup"]:
		right_arm.rotation.x = -.8 + sin(phase) * .15
	# Queue numbers remain useful; private profile names never float above heads.
	label.text = "№%03d" % int(customer.order) if int(customer.order) > 0 else ""

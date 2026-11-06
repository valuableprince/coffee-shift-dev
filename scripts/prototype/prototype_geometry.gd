class_name PrototypeGeometry
extends RefCounted
## Metre-scale graybox helpers; generated geometry belongs to the owning scene.

static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = 0.78
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

static func box(parent: Node3D, label: String, point: Vector3, size: Vector3,
		color: Color, solid: bool = true, metal: float = 0.0) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = label
	root.position = point
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material(color, metal)
	root.add_child(instance)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	parent.add_child(root, true)
	return root

static func cylinder(parent: Node3D, label: String, point: Vector3, radius: float,
		height: float, color: Color, solid: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = label
	root.position = point
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	instance.mesh = mesh
	instance.material_override = material(color)
	root.add_child(instance)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		root.add_child(collision)
	parent.add_child(root, true)
	return root

static func surface(parent: Node3D, label: String, vertices: PackedVector3Array,
		color: Color, solid: bool = true, metal: float = 0.0) -> MeshInstance3D:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in vertices:
		builder.add_vertex(vertex)
	builder.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = builder.commit()
	instance.material_override = material(color, metal)
	parent.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.name = "Collision"
		var collision := CollisionShape3D.new()
		var shape := instance.mesh.create_trimesh_shape()
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		instance.add_child(body)
	return instance

static func quad(vertices: PackedVector3Array, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3) -> void:
	vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))

static func sign_text(parent: Node3D, caption: String, point: Vector3,
		rotation: Vector3 = Vector3.ZERO, size: int = 40) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.position = point
	label.rotation = rotation
	label.font_size = size
	label.pixel_size = 0.004
	label.modulate = Color("e6d6b7")
	label.outline_modulate = Color("30342e")
	parent.add_child(label)
	return label

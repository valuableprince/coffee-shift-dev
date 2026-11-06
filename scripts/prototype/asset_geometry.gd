@tool
class_name CoffeeAssetGeometry
extends RefCounted
## Closed low-poly solids. Explicit outward normals and caps prevent missing faces.

static func material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = .24 if transparent else .80
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.disable_receive_shadows = true
	return result

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)

static func loft(parent: Node3D, label: String, rings: Array[Vector3], outline: Array[Vector2], mat: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(rings.size() - 1):
		var low := rings[level]
		var high := rings[level + 1]
		for i in range(outline.size()):
			var j := (i + 1) % outline.size()
			var a := Vector3(outline[i].x * low.y, low.x, outline[i].y * low.z)
			var b := Vector3(outline[j].x * low.y, low.x, outline[j].y * low.z)
			var c := Vector3(outline[j].x * high.y, high.x, outline[j].y * high.z)
			var d := Vector3(outline[i].x * high.y, high.x, outline[i].y * high.z)
			var normal := (b - a).cross(d - a).normalized()
			if normal.dot(Vector3(a.x + b.x, 0, a.z + b.z)) < 0: normal = -normal
			_triangle(surface, a, c, b, normal)
			_triangle(surface, a, d, c, normal)
	for level in [0, rings.size() - 1]:
		var ring := rings[level]
		var normal := Vector3.DOWN if level == 0 else Vector3.UP
		for i in range(outline.size()):
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			_triangle(surface, Vector3(0, ring.x, 0), Vector3(a.x * ring.y, ring.x, a.y * ring.z), Vector3(b.x * ring.y, ring.x, b.y * ring.z), normal)
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

static func round_outline(sides: int = 16) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in range(sides): result.append(Vector2(sin(TAU * i / sides), cos(TAU * i / sides)))
	return result

static func reset(parent: Node3D) -> Node3D:
	var previous := parent.get_node_or_null("Generated")
	if previous != null:
		parent.remove_child(previous)
		previous.queue_free()
	var root := Node3D.new()
	root.name = "Generated"
	parent.add_child(root)
	return root

static func collider(parent: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y / 2
	body.add_child(collision)
	parent.add_child(body)

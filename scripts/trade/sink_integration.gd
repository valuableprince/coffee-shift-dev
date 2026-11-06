class_name ShiftSinkInstallation
extends RefCounted
## Inserts the original PR #76 sink into a real four-piece counter opening.
## Geometry is deliberately independent from trailer shell so PR #75 can coexist.

const G := preload("res://scripts/prototype/prototype_geometry.gd")
const SINK := preload("res://assets/models/sink_mixer/sink_with_mixer.tscn")
const POSITION := Vector3(-0.86, 1.30, 1.35)
# The asset's rear is -Z, whereas the installation wall is -X. A +90° yaw
# sends -Z to -X; rotate the original rectangular opening with the whole scene.
const YAW := PI / 2.0
const CUTOUT := Vector2(0.365, 0.370)

static func install(trailer: Node3D) -> CoffeeShiftSinkMixer:
	var original := trailer.get_node_or_null("OppositeWorktop") as StaticBody3D
	if original == null:
		push_error("Sink installation: original worktop missing")
		return null
	var visual := original.get_node_or_null("Mesh") as MeshInstance3D
	if visual == null or not visual.mesh is BoxMesh:
		push_error("Sink installation: original worktop must be a box")
		return null
	var dimensions: Vector3 = (visual.mesh as BoxMesh).size
	var center: Vector3 = original.position
	var x0 := center.x - dimensions.x * 0.5
	var x1 := center.x + dimensions.x * 0.5
	var z0 := center.z - dimensions.z * 0.5
	var z1 := center.z + dimensions.z * 0.5
	var left := POSITION.x - CUTOUT.x * 0.5
	var right := POSITION.x + CUTOUT.x * 0.5
	var rear := POSITION.z - CUTOUT.y * 0.5
	var front := POSITION.z + CUTOUT.y * 0.5
	if left <= x0 or right >= x1 or rear <= z0 or front >= z1:
		push_error("Sink installation: cutout is outside worktop")
		return null
	# Replacing the entire old mesh AND box collider is mandatory: no invisible
	# physics slab may remain through the bowl. Four solid plates support the rim.
	original.free()
	_plate(trailer, "SinkWorktopBefore", x0, x1, z0, rear, center.y, dimensions.y)
	_plate(trailer, "SinkWorktopAfter", x0, x1, front, z1, center.y, dimensions.y)
	_plate(trailer, "SinkWorktopLeft", x0, left, rear, front, center.y, dimensions.y)
	_plate(trailer, "SinkWorktopRight", right, x1, rear, front, center.y, dimensions.y)
	var sink := SINK.instantiate() as CoffeeShiftSinkMixer
	sink.name = "SinkWithMixer"
	sink.position = POSITION
	sink.rotation.y = YAW
	sink.enable_fps_input_adapter = false
	trailer.add_child(sink)
	return sink

static func _plate(trailer: Node3D, id: String, x0: float, x1: float, z0: float, z1: float, height: float, thickness: float) -> void:
	G.box(trailer, id, Vector3((x0 + x1) * 0.5, height, (z0 + z1) * 0.5),
		Vector3(x1 - x0, thickness, z1 - z0), Color("b7b4a0"), true, 0.15)

## Removes only the existing cabinet's obstructing upper shelf from its runtime
## mesh/collider, leaving the original GLB on disk untouched.
static func open_cabinet_beneath_bowl(cabinet: CoffeeShiftCabinet) -> void:
	var body := cabinet.get_node("BodyCollider") as StaticBody3D
	for child in body.get_children():
		if child is CollisionShape3D and child.position.y > 0.78:
			child.free()
	var imported := cabinet.get_node("BodyVisual") as Node3D
	var meshes: Array[Node] = []
	if imported is MeshInstance3D: meshes.append(imported)
	meshes.append_array(imported.find_children("*", "MeshInstance3D", true, false))
	for node in meshes:
		var part := node as MeshInstance3D
		if part == null or part.mesh == null: continue
		var source: Mesh = part.mesh
		var filtered_mesh := ArrayMesh.new()
		for surface in range(source.get_surface_count()):
			var arrays: Array = source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty(): continue
			var retained := PackedInt32Array()
			for i in range(0, indices.size(), 3):
				# Source geometry is in metres with its upper panel at y=0.80–0.82.
				# The complete upper leaf must go so that the recessed bowl has
				# no cabinet mesh crossing it at y≈1.23 in world coordinates.
				var top_triangle := (vertices[indices[i]].y > .77
					and vertices[indices[i + 1]].y > .77
					and vertices[indices[i + 2]].y > .77)
				if not top_triangle:
					retained.append(indices[i])
					retained.append(indices[i + 1])
					retained.append(indices[i + 2])
			if retained.is_empty(): continue
			arrays[Mesh.ARRAY_INDEX] = retained
			filtered_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			filtered_mesh.surface_set_material(filtered_mesh.get_surface_count() - 1, source.surface_get_material(surface))
		part.mesh = filtered_mesh

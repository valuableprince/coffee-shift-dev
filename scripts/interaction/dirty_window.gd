extends InspectablePart
## Dirt lives on the 3D pane, on both sides. The HUD does not own its appearance.

@onready var dirt: MeshInstance3D = $Dirt
@onready var highlight: MeshInstance3D = $Highlight
@onready var border_material: StandardMaterial3D = $Highlight/Top.material_override

func _apply_status(status: int) -> void:
	dirt.visible = status != RestorationState.Status.RESTORED
	if status == RestorationState.Status.RESTORED:
		work_progress = 1.0
	_apply_progress(work_progress)

func _apply_progress(progress: float) -> void:
	var dirt_material := dirt.material_override as ShaderMaterial
	dirt_material.set_shader_parameter("cleaned", progress)

func _update_highlight() -> void:
	highlight.visible = inspection_enabled
	if state == null:
		return
	var tint := Color("edbf63")
	if state.status_of(element_id) == RestorationState.Status.RESTORED:
		tint = Color("92bd98")
	var mat := highlight.material_override as StandardMaterial3D
	mat.albedo_color = Color(tint, 0.18)
	mat.emission = tint
	border_material.albedo_color = tint
	border_material.emission = tint

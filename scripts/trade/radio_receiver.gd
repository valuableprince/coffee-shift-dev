class_name CoffeeShiftRadioReceiver
extends Node3D
## Visual adapter only. Interaction and playback remain in ShiftWorld/AUDIO-01.

var powered := false
var _indicator_material: StandardMaterial3D
var _volume_pivot: Node3D

func _ready() -> void:
	_indicator_material = StandardMaterial3D.new()
	_indicator_material.roughness = .55
	_indicator_material.emission = Color("79b56a")
	_indicator_material.emission_energy_multiplier = .65
	$PowerIndicator.material_override = _indicator_material
	_volume_pivot = Node3D.new()
	_volume_pivot.name = "VolumePivot"
	_volume_pivot.position = Vector3(.093, .110, .068)
	$Visual.add_child(_volume_pivot)
	# Source vertices use model coordinates; keep their original world placement
	# while introducing the rotary axis. The GLB itself remains byte-identical.
	for part in $Visual.find_children("2?_Volume_*", "MeshInstance3D", true, false):
		part.reparent(_volume_pivot)
	set_power(false)

func set_power(enabled: bool) -> void:
	powered = enabled
	if _indicator_material == null:
		return
	_indicator_material.albedo_color = Color("91c57e") if powered else Color("263c29")
	_indicator_material.emission_enabled = powered
	_volume_pivot.rotation.z = deg_to_rad(-60.0) if powered else 0.0

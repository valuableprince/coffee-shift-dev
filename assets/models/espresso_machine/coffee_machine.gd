class_name EspressoMachineVisual
extends Node3D
## Presentation adapter only. The supplied GLB and preparation rules stay intact.

# The source spouts leave only 13 mm over the grille. Raise the two complete
# group assemblies in the scene so the existing takeaway cup does not intersect
# them. No source mesh or material is rewritten.
const GROUP_LIFT := .155
const POWER_DROP := .075
const CONTROLS := {
	"power": Vector3(-.304, .296 - POWER_DROP, .28),
	"brew_left": Vector3(-.248, .383, .29),
	"brew_right": Vector3(.248, .383, .29),
	"group": Vector3(-.165, .213 + GROUP_LIFT, .365),
	"filter": Vector3(-.194, .174 + GROUP_LIFT, .49),
	"water": Vector3(-.294, .313, .31),
	"steam": Vector3(.294, .313, .31)
}
var _filter_parts: Array[MeshInstance3D] = []
var _power: StandardMaterial3D
var _brew: Array[StandardMaterial3D] = []
var portafilter: Node3D
var _wand_tip := Vector3(.354, .086, .342)
var _water_tip := Vector3(-.329, .147, .308)

func fit_accessories(scene: PackedScene) -> void:
	portafilter = scene.instantiate()
	portafilter.name = "WorkingPortafilter"
	add_child(portafilter)
	# Compensate for this machine's 0.8 scale: accessories remain real metres.
	portafilter.scale = Vector3.ONE / scale.x
	var lock: Marker3D = portafilter.get_node("GroupLockOrigin")
	portafilter.position = Vector3(-.165, .198 + GROUP_LIFT, .295) - portafilter.basis * lock.position
	for mesh in _filter_parts: mesh.hide()
	# Swing the existing wand outward about its own pivot. The pitcher then
	# clears the drip tray, instead of sinking through it to reach the nozzle.
	var pivot := Vector3(.32, .265, .256)
	var swing := Basis(Vector3.RIGHT, deg_to_rad(-55))
	for mesh in $Model.find_children("SteamWand_*", "MeshInstance3D", true, false):
		if mesh.name != "SteamWand_Pivot": mesh.transform = Transform3D(swing, pivot - swing * pivot)
	_wand_tip = pivot + swing * (_wand_tip - pivot)
	# Swivel the original tap over the grille with clearance for the cup.
	var tap_pivot := Vector3(-.313, .269, .256)
	var tap_swing := Basis(Vector3.RIGHT, deg_to_rad(-70))
	var tap_mount := tap_pivot + Vector3(.041, 0, -.046)
	for mesh in $Model.find_children("HotWaterTap_*", "MeshInstance3D", true, false):
		mesh.transform = Transform3D(tap_swing, tap_mount - tap_swing * tap_pivot)
	_water_tip = tap_mount + tap_swing * (_water_tip - tap_pivot)

func steam_tip() -> Vector3:
	return to_global(_wand_tip)

func water_tip() -> Vector3:
	return to_global(_water_tip)

func water_cup_base() -> Vector3:
	return to_global(Vector3(_water_tip.x, .099, _water_tip.z))

func _ready() -> void:
	for mesh in $Model.find_children("*", "MeshInstance3D", true, false):
		# Source power rocker overlaps the water knob; expose it just below.
		if mesh.name in ["PowerSwitch_Frame", "PowerSwitch", "PowerLED"]:
			mesh.position.y -= POWER_DROP
		if mesh.name.begins_with("GroupHead_") or mesh.name.begins_with("Portafilter_"):
			mesh.position.y += GROUP_LIFT
		if mesh.name.begins_with("Portafilter_Left_"):
			_filter_parts.append(mesh)
		if mesh.name == "PowerLED": _power = _indicator_material(mesh)
		if mesh.name in ["BrewButton_Left", "BrewButton_Right"]:
			_brew.append(_indicator_material(mesh))

func _indicator_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0
	mesh.material_override = material
	return material

func control_point(control: String) -> Vector3:
	if control == "filter" and portafilter != null:
		return portafilter.get_node("HandGrip").global_position
	return to_global(CONTROLS[control])

func sync(powered: bool, preparation: Dictionary) -> void:
	if _power != null: _power.emission_energy_multiplier = .65 if powered else 0.0
	for material in _brew:
		material.emission_energy_multiplier = .4 if preparation.get("running", "") == "extract" else 0.0
	# The source left geometry stays hidden when the separate asset is fitted.
	var installed := preparation.is_empty() or int(preparation.step) < 3 or int(preparation.step) >= 5
	for mesh in _filter_parts: mesh.visible = installed and portafilter == null
	if portafilter != null: portafilter.visible = installed

func cup_base() -> Vector3:
	return to_global(Vector3(-.165, .099, .316))

func spout() -> Vector3:
	if portafilter != null:
		return (portafilter.get_node("SpoutExitLeft").global_position + portafilter.get_node("SpoutExitRight").global_position) / 2
	return to_global(Vector3(-.165, .109 + GROUP_LIFT, .316))

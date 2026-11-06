extends Node3D
func _ready() -> void:
    $Camera3D.look_at(Vector3(0, 0.165, 0), Vector3.UP)

extends Node3D
## Closed and opened carton displayed side by side.
func _ready() -> void:
    $Camera3D.look_at(Vector3(0, 0.11, 0), Vector3.UP)

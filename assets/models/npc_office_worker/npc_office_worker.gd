extends CharacterBody3D
class_name CoffeeShiftOfficeWorker
## Test NPC wrapper for npc_office_worker_ps2plus.glb.
## Visual animations only; navigation, ordering and payment belong to NPC AI.

@export_enum("idle", "walk", "order", "receive") var initial_animation: String = "idle"

@onready var _visual: Node3D = $Visual
var _player: AnimationPlayer
var _current_clip := "idle"

func _ready() -> void:
    _player = _find_animation_player(_visual)
    if _player == null:
        push_warning("CoffeeShiftOfficeWorker: imported GLB AnimationPlayer not found")
        return
    _player.animation_finished.connect(_on_animation_finished)
    play_activity(initial_animation)

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child: Node in node.get_children():
        var result := _find_animation_player(child)
        if result != null:
            return result
    return null

func _resolve_name(requested: String) -> StringName:
    if _player == null:
        return &""
    for animation_name: StringName in _player.get_animation_list():
        if str(animation_name) == requested or str(animation_name).ends_with("/" + requested):
            return animation_name
    return &""

func play_activity(clip: String) -> void:
    if clip not in ["idle", "walk", "order", "receive"]:
        push_warning("CoffeeShiftOfficeWorker: unsupported activity '%s'" % clip)
        return
    _current_clip = clip
    if _player == null:
        return
    var target := _resolve_name(clip)
    if target.is_empty():
        push_warning("CoffeeShiftOfficeWorker: animation '%s' not imported" % clip)
        return
    _player.play(target)

func _on_animation_finished(_animation: StringName) -> void:
    if _current_clip in ["idle", "walk"]:
        play_activity(_current_clip)
    else:
        play_activity("idle")

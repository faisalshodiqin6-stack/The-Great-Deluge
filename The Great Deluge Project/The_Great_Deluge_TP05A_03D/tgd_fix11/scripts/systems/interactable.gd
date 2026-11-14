extends StaticBody3D
class_name Interactable

## Small reusable base for objects the player can inspect or collect.
@export var display_name: String = "Objek"
@export var interaction_prompt: String = "E - Interaksi"
@export var can_collect: bool = false
@export var interaction_distance: float = 2.0
## Resource granted when collected (empty = nothing is counted).
@export var resource_id: String = ""
@export var resource_amount: int = 1

func get_look_text() -> String:
    return display_name

func get_prompt_text() -> String:
    return interaction_prompt if can_collect else "Periksa: " + display_name

var _consumed: bool = false

## False once collected (guards against collecting the same object twice).
func is_available() -> bool:
    return not _consumed and not is_queued_for_deletion()

func interact() -> void:
    if can_collect and is_available():
        _consumed = true
        queue_free()

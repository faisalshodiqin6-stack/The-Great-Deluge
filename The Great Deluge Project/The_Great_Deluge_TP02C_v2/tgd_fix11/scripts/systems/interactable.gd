extends StaticBody3D
class_name Interactable

## Small reusable base for objects the player can inspect or collect.
@export var display_name: String = "Objek"
@export var interaction_prompt: String = "E - Interaksi"
@export var can_collect: bool = false
@export var interaction_distance: float = 2.0

func get_look_text() -> String:
    return display_name

func get_prompt_text() -> String:
    return interaction_prompt if can_collect else "Periksa: " + display_name

func interact() -> void:
    if can_collect:
        queue_free()

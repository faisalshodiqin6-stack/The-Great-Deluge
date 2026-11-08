extends Node

## Finds nearby interactable bodies on physics layer 3 (bit 4).
## A nearby item is preferred over a strict camera ray so the player does
## not need pixel-perfect aiming or pass through the item before seeing a prompt.
@export var interaction_distance: float = 1.5
@export var proximity_radius: float = 1.5
@export var camera_path: NodePath
@export var player_path: NodePath
@export var prompt_label_path: NodePath

@onready var camera: Camera3D = get_node(camera_path)
@onready var player: CharacterBody3D = get_node(player_path)
@onready var prompt_label: Label = get_node(prompt_label_path)

var _current_target: Interactable = null
var _proximity_shape: SphereShape3D
const DEFAULT_PROMPT := "WASD: Bergerak  |  Mouse: Kamera  |  E: Interaksi  |  Esc: Lepas mouse"

func _ready() -> void:
    _proximity_shape = SphereShape3D.new()
    _proximity_shape.radius = proximity_radius

func _process(_delta: float) -> void:
    _current_target = _find_target()
    if is_instance_valid(_current_target):
        prompt_label.text = _current_target.get_prompt_text()
    else:
        prompt_label.text = DEFAULT_PROMPT

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        # Re-evaluate immediately so a newly-entered target can be collected.
        _current_target = _find_target()
        if is_instance_valid(_current_target):
            var target := _current_target
            target.interact()
            _current_target = null
            prompt_label.text = DEFAULT_PROMPT
            get_viewport().set_input_as_handled()

func _find_target() -> Interactable:
    if not is_instance_valid(camera) or not is_instance_valid(player):
        return null

    var space_state := player.get_world_3d().direct_space_state
    var center := player.global_position + Vector3(0.0, 1.0, 0.0)

    # Broad, forgiving proximity check. It deliberately does not require a
    # second line-of-sight ray: low objects resting on terrain can otherwise
    # be incorrectly hidden by the terrain collider.
    var shape_query := PhysicsShapeQueryParameters3D.new()
    shape_query.shape = _proximity_shape
    shape_query.transform = Transform3D(Basis(), center)
    shape_query.collision_mask = 4 # Interactable items: physics layer 3.
    shape_query.collide_with_areas = false
    shape_query.collide_with_bodies = true

    var hits := space_state.intersect_shape(shape_query, 32)
    var best_target: Interactable = null
    var best_score := INF
    var camera_forward := -camera.global_transform.basis.z

    for hit in hits:
        var collider: Object = hit.get("collider")
        if not (collider is Interactable):
            continue
        var candidate := collider as Interactable
        if not is_instance_valid(candidate):
            continue

        var target_point := candidate.global_position + Vector3(0.0, 0.35, 0.0)
        var offset := target_point - center
        var distance := offset.length()
        if distance > interaction_distance or distance <= 0.001:
            continue

        # Prefer objects generally in front of the camera, but do not reject
        # nearby objects solely because the camera is slightly off-center.
        var direction_score := camera_forward.dot(offset / distance)
        var score := distance + (0.75 if direction_score < -0.25 else 0.0)
        if score < best_score:
            best_score = score
            best_target = candidate

    return best_target

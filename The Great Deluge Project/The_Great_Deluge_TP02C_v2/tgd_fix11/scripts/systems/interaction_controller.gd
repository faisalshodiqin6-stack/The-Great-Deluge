extends Node

## Finds interactable bodies on physics layer 3 (bit 4). Detection depends on
## the active camera:
##  - First Person: ray from the camera center along its view direction.
##  - Third Person: proximity search around the player, preferring objects in
##    front of the camera, with a line-of-sight check against world geometry.
## Each Interactable provides its own interaction_distance.
@export var interaction_distance: float = 2.0 # Fallback; objects use their own value.
@export var first_person_ray_length: float = 6.0
@export var proximity_radius: float = 2.5 # Broad query; per-object interaction_distance does the final filter.
@export var camera_path: NodePath
@export var player_path: NodePath
@export var prompt_label_path: NodePath
@export var crosshair_path: NodePath
@export var crosshair_color: Color = Color(1, 1, 1, 0.6)
@export var crosshair_target_color: Color = Color(1.0, 0.85, 0.2, 0.6)
@export var highlight_color: Color = Color(1.0, 0.85, 0.2, 0.4)

@onready var fallback_camera: Camera3D = get_node(camera_path)
@onready var player: CharacterBody3D = get_node(player_path)
@onready var prompt_label: Label = get_node(prompt_label_path)

var _current_target: Interactable = null
var _crosshair: Control = null
var _highlight_material: StandardMaterial3D
var _highlighted: Interactable = null
var _proximity_shape: SphereShape3D
const HIGHLIGHT_GROUP := "_interaction_highlight"
const WORLD_MASK := 1
const INTERACTABLE_MASK := 4
const DEFAULT_PROMPT := "WASD: Bergerak  |  Mouse: Kamera  |  E: Interaksi  |  Esc: Lepas mouse"

func _ready() -> void:
    _proximity_shape = SphereShape3D.new()
    _proximity_shape.radius = proximity_radius
    if not crosshair_path.is_empty():
        _crosshair = get_node_or_null(crosshair_path) as Control
    _highlight_material = StandardMaterial3D.new()
    _highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _highlight_material.albedo_color = highlight_color
    _update_feedback(null)

func _process(_delta: float) -> void:
    _current_target = _find_target()
    _update_feedback(_current_target)
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
            _update_feedback(null)
            target.interact()
            _current_target = null
            prompt_label.text = DEFAULT_PROMPT
            get_viewport().set_input_as_handled()

## Crosshair color and mesh highlight both follow the target chosen by _find_target().
func _update_feedback(target: Interactable) -> void:
    if not is_instance_valid(target):
        target = null
    if is_instance_valid(_crosshair):
        # Crosshair is First Person only; Third Person uses highlight alone.
        _crosshair.visible = is_instance_valid(player) and _is_first_person_active()
        _crosshair.modulate = crosshair_target_color if target else crosshair_color
    if target == _highlighted:
        return
    # Single owner of highlights: clear EVERY mesh this controller ever
    # highlighted (tracked by group, so stale ones cannot survive), then
    # highlight only the new target.
    for mesh in get_tree().get_nodes_in_group(HIGHLIGHT_GROUP):
        (mesh as MeshInstance3D).material_overlay = null
        mesh.remove_from_group(HIGHLIGHT_GROUP)
    _highlighted = target
    if target:
        var meshes: Array[MeshInstance3D] = []
        _collect_own_meshes(target, meshes)
        for mesh in meshes:
            mesh.material_overlay = _highlight_material
            mesh.add_to_group(HIGHLIGHT_GROUP)

## Meshes belonging to this Interactable only. Subtrees that are themselves
## another Interactable (e.g. items nested under one another) are skipped,
## so highlighting A never lights up B or C.
func _collect_own_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
    for child in node.get_children():
        if child is Interactable:
            continue
        if child is MeshInstance3D:
            out.append(child)
        _collect_own_meshes(child, out)

func _get_active_camera() -> Camera3D:
    var active := get_viewport().get_camera_3d()
    return active if is_instance_valid(active) else fallback_camera

func _is_first_person_active() -> bool:
    var fp := player.get_node_or_null("FirstPersonCamera")
    return fp != null and fp.has_method("is_active") and fp.is_active()

func _find_target() -> Interactable:
    if not is_instance_valid(player):
        return null
    var camera := _get_active_camera()
    if not is_instance_valid(camera):
        return null
    if _is_first_person_active():
        return _find_target_first_person(camera)
    return _find_target_third_person(camera)

## First Person: single ray from the camera center. The first thing hit wins,
## so walls and terrain between the camera and an object block selection.
func _find_target_first_person(camera: Camera3D) -> Interactable:
    var origin := camera.global_position
    var end := origin - camera.global_transform.basis.z * first_person_ray_length
    var query := PhysicsRayQueryParameters3D.create(origin, end, WORLD_MASK | INTERACTABLE_MASK, [player.get_rid()])
    query.collide_with_areas = false
    var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty() or not (hit["collider"] is Interactable):
        return null
    var candidate := hit["collider"] as Interactable
    if origin.distance_to(hit["position"]) > candidate.interaction_distance:
        return null
    return candidate

## Third Person: nearest interactable within its distance around the player,
## preferring objects in front of the camera and requiring line of sight.
func _find_target_third_person(camera: Camera3D) -> Interactable:
    var space_state := player.get_world_3d().direct_space_state
    var center := player.global_position + Vector3(0.0, 1.0, 0.0)

    var shape_query := PhysicsShapeQueryParameters3D.new()
    shape_query.shape = _proximity_shape
    shape_query.transform = Transform3D(Basis(), center)
    shape_query.collision_mask = INTERACTABLE_MASK
    shape_query.collide_with_areas = false
    shape_query.collide_with_bodies = true

    var best_target: Interactable = null
    var best_score := INF
    var camera_forward := -camera.global_transform.basis.z

    for hit in space_state.intersect_shape(shape_query, 32):
        var candidate := hit.get("collider") as Interactable
        if not is_instance_valid(candidate):
            continue
        var target_point := candidate.global_position + Vector3(0.0, 0.35, 0.0)
        var offset := target_point - center
        var distance := offset.length()
        if distance > candidate.interaction_distance or distance <= 0.001:
            continue
        if not _has_line_of_sight(space_state, center, target_point):
            continue
        var direction_score := camera_forward.dot(offset / distance)
        var score := distance + (0.75 if direction_score < -0.25 else 0.0)
        if score < best_score:
            best_score = score
            best_target = candidate
    return best_target

## Blocked only if world geometry is hit clearly before the target point
## (0.25 m tolerance so objects resting on terrain are not hidden by it).
func _has_line_of_sight(space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
    var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, [player.get_rid()])
    var hit := space_state.intersect_ray(query)
    return hit.is_empty() or hit["position"].distance_to(to) <= 0.25

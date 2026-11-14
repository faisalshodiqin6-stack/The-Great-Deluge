extends Node3D
class_name FirstPersonCamera

## First-person camera rig. Child of the Player body (not of the visual mesh),
## so animation/mesh changes never move it. Yaw rotates the Player body;
## pitch rotates only this rig. Inactive by default (Third Person stays
## current) until TP-02B calls activate().

@export var mouse_sensitivity: float = 0.0025
@export var min_pitch_degrees: float = -85.0
@export var max_pitch_degrees: float = 85.0
@export var eye_height: float = 1.65
@export var start_active: bool = false
@export var hide_body_when_active: bool = true

@onready var camera: Camera3D = $Camera3D
@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D

var _pitch: float = 0.0

func _ready() -> void:
	position = Vector3(0.0, eye_height, 0.0)
	camera.near = 0.05
	if start_active:
		activate()

func is_active() -> bool:
	return camera != null and camera.current

func get_pitch() -> float:
	return _pitch

func set_pitch(value: float) -> void:
	_pitch = clampf(value, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	rotation.x = _pitch

func activate() -> void:
	camera.make_current()
	_set_body_visible(false)

func deactivate() -> void:
	camera.current = false
	_set_body_visible(true)

func _set_body_visible(visible_body: bool) -> void:
	if not hide_body_when_active:
		return
	var visual := _body.get_node_or_null("Visual") as Node3D
	if visual:
		visual.visible = visible_body

func _unhandled_input(event: InputEvent) -> void:
	if not is_active() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		apply_look(event.relative)

## Look input in pixels (mouse or touch): yaw turns the body, pitch is clamped.
func apply_look(relative: Vector2) -> void:
	_body.rotate_y(-relative.x * mouse_sensitivity)
	_pitch = clampf(
		_pitch - relative.y * mouse_sensitivity,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)
	rotation.x = _pitch

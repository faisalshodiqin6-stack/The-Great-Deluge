extends Camera3D

## Simple observation camera: hold the right mouse button and drag to orbit.
## Use the mouse wheel to zoom in and out.

@export var target: Vector3 = Vector3(0.0, 2.0, 0.0)
@export var zoom_min: float = 42.0
@export var zoom_max: float = 160.0
@export var zoom_step: float = 8.0

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-28.0)
var _distance: float = 105.0
var _dragging: bool = false


func _ready() -> void:
	_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(zoom_min, _distance - zoom_step)
			_update_camera_transform()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(zoom_max, _distance + zoom_step)
			_update_camera_transform()

	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.005
		_pitch = clampf(
			_pitch - event.relative.y * 0.005,
			deg_to_rad(-75.0),
			deg_to_rad(-10.0)
		)
		_update_camera_transform()


func _update_camera_transform() -> void:
	var horizontal_distance := cos(_pitch) * _distance
	position = target + Vector3(
		sin(_yaw) * horizontal_distance,
		-sin(_pitch) * _distance,
		cos(_yaw) * horizontal_distance
	)
	look_at(target, Vector3.UP)

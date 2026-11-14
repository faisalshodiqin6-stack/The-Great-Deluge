extends Node
class_name PlayerInput

## Single player-input source. Combines keyboard actions with touch controls
## (virtual joystick, touch look, jump/sprint buttons). The player controller
## reads only from here, so PC and Android share one code path.
@export var touch_look_scale: float = 1.0

signal camera_toggle_requested              # From the touch camera button.
signal camera_mode_changed(first_person: bool)  # Emitted by the player after any switch (V or touch).

var touch_move: Vector2 = Vector2.ZERO   # Analog, length <= 1 (same axes as Input.get_vector).
var touch_sprint: bool = false
var touch_jump: bool = false
var _look_accum: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player_input")

func request_camera_toggle() -> void:
	camera_toggle_requested.emit()

func notify_camera_mode(first_person: bool) -> void:
	camera_mode_changed.emit(first_person)

func get_move() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (keyboard + touch_move).limit_length(1.0)

func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint") or touch_sprint

func is_jump_held() -> bool:
	return Input.is_action_pressed("jump") or touch_jump

func add_look(relative: Vector2) -> void:
	_look_accum += relative * touch_look_scale

## Touch look since last call (pixels). Reset on read.
func consume_look() -> Vector2:
	var value := _look_accum
	_look_accum = Vector2.ZERO
	return value

func clear_touch() -> void:
	touch_move = Vector2.ZERO
	touch_sprint = false
	touch_jump = false
	_look_accum = Vector2.ZERO

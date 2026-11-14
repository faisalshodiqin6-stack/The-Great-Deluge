extends CharacterBody3D

## Third-person movement. Keyboard movement follows the player's yaw,
## which is also the horizontal direction of the camera.
@export var move_speed: float = 6.0
## Sprint speed = move_speed * sprint_multiplier while Left Shift is held.
@export var sprint_multiplier: float = 1.6
@export var acceleration: float = 24.0
@export var gravity: float = 24.0
@export var jump_velocity: float = 8.5
@export var mouse_sensitivity: float = 0.003
@export var camera_distance: float = 5.0
@export var min_camera_pitch: float = -55.0
@export var max_camera_pitch: float = 25.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var third_person_camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var first_person: FirstPersonCamera = get_node_or_null("FirstPersonCamera") as FirstPersonCamera

var _camera_pitch: float = deg_to_rad(-12.0)
# Camera rigs are top-level and positioned every rendered frame from an
# interpolated body position. Otherwise they only move on physics ticks (60 Hz)
# and look stuttery on higher refresh rates while walking.
var _prev_position: Vector3
var _curr_position: Vector3
var _pivot_offset: float
var _visual_offset: float
@onready var _visual: Node3D = get_node_or_null("Visual") as Node3D

func _ready() -> void:
    _ensure_movement_actions()
    spring_arm.spring_length = camera_distance
    camera_pivot.rotation.x = _camera_pitch
    _pivot_offset = camera_pivot.position.y
    if _visual:
        # Interpolate the mesh too, or it steps at 60 Hz while the camera is smooth (visible jitter).
        _visual_offset = _visual.position.y
        _visual.top_level = true
    camera_pivot.top_level = true
    if first_person:
        first_person.top_level = true
    _prev_position = global_position
    _curr_position = global_position
    # Keep the character grounded without aggressive snap correction.
    floor_snap_length = 0.15
    floor_max_angle = deg_to_rad(60.0)
    safe_margin = 0.01
    UIState.capture_mouse()

func _ensure_movement_actions() -> void:
    var bindings := {
        "move_forward": KEY_W,
        "move_back": KEY_S,
        "move_left": KEY_A,
        "move_right": KEY_D,
        "jump": KEY_SPACE,
        "sprint": KEY_SHIFT,
        "toggle_camera": KEY_V
    }
    for action_name in bindings:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)
        var has_physical_key := false
        for existing_event in InputMap.action_get_events(action_name):
            if existing_event is InputEventKey:
                if existing_event.physical_keycode == bindings[action_name]:
                    has_physical_key = true
                    break
        if not has_physical_key:
            var key_event := InputEventKey.new()
            key_event.physical_keycode = bindings[action_name]
            InputMap.action_add_event(action_name, key_event)

var _ui_state = null

## True while an interface (inventory, crafting, ...) is open.
func _ui_blocking() -> bool:
    if _ui_state == null:
        _ui_state = get_tree().get_first_node_in_group("ui_state")
    return _ui_state != null and _ui_state.is_blocking()

func _unhandled_input(event: InputEvent) -> void:
    if _ui_blocking():
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("toggle_camera") and not event.is_echo():
        _toggle_camera()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            UIState.capture_mouse()
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        if event.device == InputEvent.DEVICE_ID_EMULATION:
            return # Touch-emulated mouse; real touch look comes via PlayerInput.
        if first_person and first_person.is_active():
            return # First Person camera handles its own mouse look.
        _apply_tp_look(event.relative)

## Third Person look (mouse or touch): yaw rotates the body, pitch tilts the pivot.
func _apply_tp_look(relative: Vector2) -> void:
    rotate_y(-relative.x * mouse_sensitivity)
    _camera_pitch = clampf(
        _camera_pitch - relative.y * mouse_sensitivity,
        deg_to_rad(min_camera_pitch),
        deg_to_rad(max_camera_pitch)
    )
    camera_pivot.rotation.x = _camera_pitch

var _survival: PlayerSurvival = null

func _get_survival() -> PlayerSurvival:
    if _survival == null:
        _survival = get_tree().get_first_node_in_group("player_survival") as PlayerSurvival
    return _survival

var _player_input: PlayerInput = null

func _get_player_input() -> PlayerInput:
    if _player_input == null:
        _player_input = get_tree().get_first_node_in_group("player_input") as PlayerInput
        if _player_input:
            # Touch camera button goes through PlayerInput; ignored while a UI is open.
            _player_input.camera_toggle_requested.connect(func() -> void:
                if not _ui_blocking():
                    _toggle_camera())
    return _player_input

## Switch First/Third Person. Yaw is shared (the body's rotation); pitch is
## copied between the two rigs (same sign convention: negative = look down).
func _toggle_camera() -> void:
    if first_person == null:
        return
    if first_person.is_active():
        _camera_pitch = clampf(first_person.get_pitch(), deg_to_rad(min_camera_pitch), deg_to_rad(max_camera_pitch))
        camera_pivot.rotation.x = _camera_pitch
        third_person_camera.make_current()
        first_person.deactivate()
    else:
        first_person.set_pitch(_camera_pitch)
        first_person.activate()
    var input_source := _get_player_input()
    if input_source:
        input_source.notify_camera_mode(first_person.is_active())

func _process(_delta: float) -> void:
    var look_source := _get_player_input()
    if look_source:
        var touch_look := look_source.consume_look()
        if touch_look != Vector2.ZERO and not _ui_blocking():
            if first_person and first_person.is_active():
                first_person.apply_look(touch_look)
            else:
                _apply_tp_look(touch_look)
    var pos := _prev_position.lerp(_curr_position, Engine.get_physics_interpolation_fraction())
    camera_pivot.global_position = pos + Vector3(0.0, _pivot_offset, 0.0)
    camera_pivot.rotation.y = global_rotation.y
    if _visual:
        _visual.global_position = pos + Vector3(0.0, _visual_offset, 0.0)
        _visual.rotation.y = global_rotation.y
    if first_person:
        first_person.global_position = pos + Vector3(0.0, first_person.eye_height, 0.0)
        first_person.rotation.y = global_rotation.y

func _read_move() -> Vector2:
    var source := _get_player_input()
    return source.get_move() if source else Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _read_sprint() -> bool:
    var source := _get_player_input()
    return source.is_sprinting() if source else Input.is_action_pressed("sprint")

func _read_jump() -> bool:
    var source := _get_player_input()
    return source.is_jump_held() if source else Input.is_action_pressed("jump")

func _physics_process(delta: float) -> void:
    var ui_blocked := _ui_blocking()
    var input_2d := Vector2.ZERO if ui_blocked else _read_move()

    # Use the character's yaw basis directly. This avoids movement depending
    # on the SpringArm/Camera collision-adjusted transform.
    var body_basis := global_transform.basis
    var move_direction := body_basis.x * input_2d.x + body_basis.z * input_2d.y
    move_direction.y = 0.0
    if move_direction.length_squared() > 1.0:
        move_direction = move_direction.normalized()

    # Sprint needs real movement input and stamina; the survival system drains it.
    var survival := _get_survival()
    var sprinting := _read_sprint() and not ui_blocked and input_2d != Vector2.ZERO \
        and (survival == null or survival.can_sprint())
    if survival:
        survival.set_activity(input_2d != Vector2.ZERO, sprinting)
    var current_speed := move_speed * (sprint_multiplier if sprinting else 1.0) \
        * (survival.get_movement_multiplier() if survival else 1.0)
    var target_x := move_direction.x * current_speed
    var target_z := move_direction.z * current_speed
    velocity.x = move_toward(velocity.x, target_x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target_z, acceleration * delta)

    if is_on_floor():
        # Held SPACE re-jumps on every landing; releasing it stops the repeat.
        if _read_jump() and not ui_blocked and (survival == null or survival.try_jump()):
            velocity.y = jump_velocity
        elif velocity.y < 0.0:
            velocity.y = 0.0
    else:
        velocity.y -= gravity * delta

    move_and_slide()
    _prev_position = _curr_position
    _curr_position = global_position

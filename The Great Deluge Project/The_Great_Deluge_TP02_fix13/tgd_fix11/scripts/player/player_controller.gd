extends CharacterBody3D

## Third-person movement. Keyboard movement follows the player's yaw,
## which is also the horizontal direction of the camera.
@export var move_speed: float = 6.0
@export var acceleration: float = 24.0
@export var gravity: float = 24.0
@export var jump_velocity: float = 8.5
@export var mouse_sensitivity: float = 0.003
@export var camera_distance: float = 5.0
@export var min_camera_pitch: float = -55.0
@export var max_camera_pitch: float = 25.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var _camera_pitch: float = deg_to_rad(-12.0)

func _ready() -> void:
    _ensure_movement_actions()
    spring_arm.spring_length = camera_distance
    camera_pivot.rotation.x = _camera_pitch
    # Keep the character grounded without aggressive snap correction.
    floor_snap_length = 0.15
    floor_max_angle = deg_to_rad(60.0)
    safe_margin = 0.01
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ensure_movement_actions() -> void:
    var bindings := {
        "move_forward": KEY_W,
        "move_back": KEY_S,
        "move_left": KEY_A,
        "move_right": KEY_D,
        "jump": KEY_SPACE
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

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        _camera_pitch = clampf(
            _camera_pitch - event.relative.y * mouse_sensitivity,
            deg_to_rad(min_camera_pitch),
            deg_to_rad(max_camera_pitch)
        )
        camera_pivot.rotation.x = _camera_pitch

func _physics_process(delta: float) -> void:
    var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

    # Use the character's yaw basis directly. This avoids movement depending
    # on the SpringArm/Camera collision-adjusted transform.
    var body_basis := global_transform.basis
    var move_direction := body_basis.x * input_2d.x + body_basis.z * input_2d.y
    move_direction.y = 0.0
    if move_direction.length_squared() > 1.0:
        move_direction = move_direction.normalized()

    var target_x := move_direction.x * move_speed
    var target_z := move_direction.z * move_speed
    velocity.x = move_toward(velocity.x, target_x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target_z, acceleration * delta)

    if is_on_floor():
        if Input.is_action_just_pressed("jump"):
            velocity.y = jump_velocity
        elif velocity.y < 0.0:
            velocity.y = 0.0
    else:
        velocity.y -= gravity * delta

    move_and_slide()

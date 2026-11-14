extends CanvasLayer
class_name TouchControls

## On-screen controls for Android: floating joystick (left), look area (right),
## Jump / Sprint / Interact / Inventory buttons. Multi-touch is handled manually
## (by touch index) so movement + look + buttons work at the same time.
## Shown only on mobile unless show_on_desktop is enabled (for testing).
@export var show_on_desktop: bool = false
@export var joystick_radius: float = 90.0

const LOOK_AREA_MIN_X := 0.45     # Fraction of screen width.
const JOYSTICK_AREA_MAX_X := 0.45
const JOYSTICK_AREA_MIN_Y := 0.35

class JoystickView extends Control:
	var active: bool = false
	var origin: Vector2 = Vector2.ZERO
	var knob: Vector2 = Vector2.ZERO
	var radius: float = 90.0
	func _draw() -> void:
		if active:
			draw_circle(origin, radius, Color(1, 1, 1, 0.12))
			draw_circle(knob, 36.0, Color(1, 1, 1, 0.35))

class CameraIcon extends Control:
	func _draw() -> void:
		var c := Color(1, 1, 1, 0.95)
		var s := size
		draw_rect(Rect2(s.x * 0.18, s.y * 0.34, s.x * 0.64, s.y * 0.38), c, false, 3.0)   # body
		draw_rect(Rect2(s.x * 0.38, s.y * 0.26, s.x * 0.24, s.y * 0.08), c, true)           # top bump
		draw_arc(s * Vector2(0.5, 0.53), s.x * 0.12, 0.0, TAU, 20, c, 3.0)                  # lens

var _mode_label: Label
var _buttons: Dictionary = {}          # name -> Panel
var _joystick: JoystickView
var _move_touch: int = -1
var _look_touch: int = -1
var _button_touches: Dictionary = {}   # touch index -> button name (or "hotbar")
var _player_input: PlayerInput = null

func _ready() -> void:
	layer = 5
	var enabled := OS.has_feature("mobile") or show_on_desktop
	visible = enabled
	set_process(enabled)
	set_process_input(enabled)
	if enabled:
		_build()

func _build() -> void:
	_joystick = JoystickView.new()
	_joystick.radius = joystick_radius
	_joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_joystick)
	_add_button("jump", "Lompat", false, 40, 40, 104)
	_add_button("sprint", "Lari", false, 165, 40, 92)
	_add_button("interact", "E", false, 40, 165, 92)
	_add_button("inventory", "Tas", true, 24, 24, 76)
	_add_camera_button()
	call_deferred("_connect_input")

## Camera toggle (FP <-> TP): below the inventory button, right edge; clear of
## Jump / Sprint / Interact, which are bottom-right.
func _add_camera_button() -> void:
	_add_button("camera", "", true, 24, 112, 76)
	var panel := _buttons["camera"] as Panel
	var icon := CameraIcon.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	_mode_label = Label.new()
	_mode_label.text = "TP"
	_mode_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_mode_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mode_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_mode_label.offset_bottom = -4.0
	_mode_label.add_theme_font_size_override("font_size", 14)
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_mode_label)

func _connect_input() -> void:
	var pi := _pi()
	if pi:
		pi.camera_mode_changed.connect(_on_camera_mode_changed)

func _on_camera_mode_changed(first_person: bool) -> void:
	if _mode_label:
		_mode_label.text = "FP" if first_person else "TP"
	_pulse(_buttons["camera"] as Control)

## Short feedback: the button swells briefly.
func _pulse(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(control, "scale", Vector2.ONE, 0.15)

## Buttons are drawn as Panels (mouse ignored); hits are tested manually.
func _add_button(button_name: String, text: String, top_right: bool, margin_x: float, margin_y: float, size: float) -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT if top_right else Control.PRESET_BOTTOM_RIGHT)
	panel.offset_right = -margin_x
	panel.offset_left = -margin_x - size
	if top_right:
		panel.offset_top = margin_y
		panel.offset_bottom = margin_y + size
	else:
		panel.offset_bottom = -margin_y
		panel.offset_top = -margin_y - size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.22)
	style.border_color = Color(1, 1, 1, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(size / 2.0))
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)
	_buttons[button_name] = panel

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.relative)

func _process(_delta: float) -> void:
	# When an interface opens, drop all gameplay touches (no stuck movement/look).
	if UIState.blocked(get_tree()) and (_move_touch != -1 or _look_touch != -1 or _button_touches.size() > 0):
		_reset_gameplay()

func _pi() -> PlayerInput:
	if _player_input == null:
		_player_input = get_tree().get_first_node_in_group("player_input") as PlayerInput
	return _player_input

func _button_at(point: Vector2) -> String:
	for button_name in _buttons:
		if (_buttons[button_name] as Control).get_global_rect().has_point(point):
			return button_name
	return ""

func _on_press(index: int, point: Vector2) -> void:
	var blocked := UIState.blocked(get_tree())
	var hit := _button_at(point)
	if hit != "":
		if blocked and hit != "inventory":
			return
		_button_touches[index] = hit
		_set_button(hit, true)
		return
	if blocked:
		return
	var hotbar_ui := get_tree().get_first_node_in_group("hotbar_ui") as HotbarUI
	if hotbar_ui and hotbar_ui.slot_at(point) >= 0:
		var hotbar := get_tree().get_first_node_in_group("hotbar") as Hotbar
		if hotbar:
			hotbar.select(hotbar_ui.slot_at(point))
		_button_touches[index] = "hotbar"
		return
	var size := get_viewport().get_visible_rect().size
	if _move_touch == -1 and point.x < size.x * JOYSTICK_AREA_MAX_X and point.y > size.y * JOYSTICK_AREA_MIN_Y:
		_move_touch = index
		_joystick.active = true
		_joystick.origin = point
		_joystick.knob = point
		_joystick.queue_redraw()
	elif _look_touch == -1 and point.x >= size.x * LOOK_AREA_MIN_X:
		_look_touch = index

func _on_drag(index: int, point: Vector2, relative: Vector2) -> void:
	if UIState.blocked(get_tree()):
		return
	if index == _move_touch:
		var offset := point - _joystick.origin
		var pi := _pi()
		if pi:
			pi.touch_move = (offset / joystick_radius).limit_length(1.0)
		_joystick.knob = _joystick.origin + offset.limit_length(joystick_radius)
		_joystick.queue_redraw()
	elif index == _look_touch:
		var pi := _pi()
		if pi:
			pi.add_look(relative)

func _on_release(index: int) -> void:
	if index == _move_touch:
		_move_touch = -1
		_joystick.active = false
		_joystick.queue_redraw()
		var pi := _pi()
		if pi:
			pi.touch_move = Vector2.ZERO
	elif index == _look_touch:
		_look_touch = -1
	elif _button_touches.has(index):
		var button_name: String = _button_touches[index]
		_button_touches.erase(index)
		if button_name != "hotbar":
			_set_button(button_name, false)

func _set_button(button_name: String, pressed: bool) -> void:
	(_buttons[button_name] as Control).modulate = Color(1, 1, 0.6) if pressed else Color(1, 1, 1)
	var pi := _pi()
	match button_name:
		"jump":
			if pi:
				pi.touch_jump = pressed
		"sprint":
			if pi:
				pi.touch_sprint = pressed
		"interact":
			if pressed:
				get_tree().call_group("interaction_controller", "try_interact")
		"inventory":
			if pressed:
				get_tree().call_group("inventory_panel", "toggle")
		"camera":
			if pressed and pi:
				pi.request_camera_toggle()

func _reset_gameplay() -> void:
	_move_touch = -1
	_look_touch = -1
	for button_name in _button_touches.values():
		if button_name != "hotbar":
			_set_button(button_name, false)
	_button_touches.clear()
	_joystick.active = false
	_joystick.queue_redraw()
	var pi := _pi()
	if pi:
		pi.clear_touch()

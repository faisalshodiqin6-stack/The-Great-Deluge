extends CanvasLayer
class_name UIPanel

## Base for toggleable UI windows (inventory, crafting, ...). Subclasses set
## ui_id / toggle_key in _init() and implement _build_ui() / _on_opened().
## Opening goes through UIState, never through SceneTree pause.
var ui_id: String = ""
var toggle_key: Key = KEY_NONE
var _open: bool = false
var _ui_state: UIState = null

func _ready() -> void:
	layer = 10
	_build_ui()
	visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			_set_open(not _open)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _open:
			_set_open(false)
			get_viewport().set_input_as_handled()

func _get_ui_state() -> UIState:
	if _ui_state == null:
		_ui_state = get_tree().get_first_node_in_group("ui_state") as UIState
		if _ui_state:
			_ui_state.close_requested.connect(_on_close_requested)
	return _ui_state

func _on_close_requested(requested_id: String) -> void:
	if requested_id == ui_id and _open:
		_set_open(false)

func _set_open(value: bool) -> void:
	var state := _get_ui_state()
	if state == null:
		return
	_open = value
	visible = value
	if value:
		state.open_ui(ui_id)
		_on_opened()
	else:
		state.close_ui(ui_id)

func _build_ui() -> void:
	pass

func _on_opened() -> void:
	pass

## Shared window frame: dim background + centered panel + vertical box. Returns the box.
func _make_window(parent_layer: CanvasLayer) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var window := PanelContainer.new()
	center.add_child(window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	window.add_child(box)
	return box

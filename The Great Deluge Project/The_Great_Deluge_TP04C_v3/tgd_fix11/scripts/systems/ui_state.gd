extends Node
class_name UIState

## Central interface state (no SceneTree pause). At most one UI is open at a
## time; opening another asks the current one to close. While any UI is open,
## gameplay input is blocked (is_blocking()) and the mouse cursor is visible.
## The world keeps simulating. Usable by inventory, crafting, map, etc.
signal close_requested(ui_id: String)
signal blocking_changed(blocking: bool)

var _current: String = ""
var _switching: bool = false

## True when some interface is open (safe to call from anywhere).
static func blocked(tree: SceneTree) -> bool:
	var state := tree.get_first_node_in_group("ui_state") as UIState
	return state != null and state.is_blocking()

## No pointer capture on touch devices.
static func capture_mouse() -> void:
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	add_to_group("ui_state")

func is_blocking() -> bool:
	return _current != ""

func current_ui() -> String:
	return _current

func open_ui(ui_id: String) -> void:
	if _current == ui_id:
		return
	var was_blocking := is_blocking()
	if was_blocking:
		_switching = true
		close_requested.emit(_current) # The open UI hides itself and calls close_ui().
		_switching = false
	_current = ui_id
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not was_blocking:
		blocking_changed.emit(true)

func close_ui(ui_id: String) -> void:
	if _current != ui_id:
		return
	_current = ""
	if _switching:
		return # Another UI is about to open; keep the cursor state.
	UIState.capture_mouse()
	blocking_changed.emit(false)

extends CanvasLayer
class_name HotbarUI

## 9-slot hotbar at the bottom of the screen (always visible while playing).
@export var hotbar_path: NodePath
@export var inventory_path: NodePath

const SLOT := 56.0

@onready var _hotbar: Hotbar = get_node_or_null(hotbar_path) as Hotbar
@onready var _inventory: Inventory = get_node_or_null(inventory_path) as Inventory

var _panels: Array[Panel] = []
var _icons: Array[ColorRect] = []
var _counts: Array[Label] = []

func _ready() -> void:
	layer = 4
	add_to_group("hotbar_ui")
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -12.0
	add_child(box)
	for i in InventoryConfig.HOTBAR_SIZE:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(SLOT, SLOT)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_slot_input.bind(i))
		var icon := ColorRect.new()
		icon.position = Vector2(13, 8)
		icon.size = Vector2(30, 30)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		var count := Label.new()
		count.position = Vector2(2, 36)
		count.size = Vector2(SLOT - 6, 18)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 13)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(count)
		var number := Label.new()
		number.text = str(i + 1)
		number.position = Vector2(4, 0)
		number.add_theme_font_size_override("font_size", 12)
		number.modulate = Color(1, 1, 1, 0.7)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(number)
		box.add_child(panel)
		_panels.append(panel)
		_icons.append(icon)
		_counts.append(count)
	if _hotbar:
		_hotbar.active_changed.connect(func(_i: int) -> void: refresh())
		_hotbar.contents_changed.connect(refresh)
	refresh()

func _on_slot_input(event: InputEvent, index: int) -> void:
	if _hotbar and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hotbar.select(index)

## Slot index under a screen point, or -1 (used by touch controls).
func slot_at(point: Vector2) -> int:
	for i in _panels.size():
		if _panels[i].get_global_rect().has_point(point):
			return i
	return -1

func refresh() -> void:
	if _inventory == null or _hotbar == null:
		return
	for i in _panels.size():
		var slot: Dictionary = _inventory.slots[i]
		var filled := not slot.is_empty()
		_icons[i].visible = filled
		_counts[i].text = str(slot["count"]) if filled else ""
		if filled:
			_icons[i].color = InventoryConfig.item_color(slot["id"])
		var style := StyleBoxFlat.new()
		var active := i == _hotbar.active_index
		style.bg_color = Color(0.2, 0.22, 0.25, 0.9) if active else Color(0.08, 0.08, 0.1, 0.7)
		style.border_color = Color(1.0, 0.85, 0.2, 1) if active else Color(0.4, 0.4, 0.45, 1)
		style.set_border_width_all(4 if active else 2)
		style.set_corner_radius_all(4)
		_panels[i].add_theme_stylebox_override("panel", style)

extends VBoxContainer
class_name InventoryView

## Inventory tab: 24-slot grid (6 columns). Slots 1-9 are the hotbar. Click a
## slot, then another slot, to move / merge / swap (Inventory.move_slot).
const SLOT_SIZE := Vector2(72, 72)
const COLUMNS := 6

var _inventory: Inventory
var _panels: Array[Panel] = []
var _icons: Array[ColorRect] = []
var _letters: Array[Label] = []
var _counts: Array[Label] = []
var _info: Label
var _selected: int = -1
var _hovered: int = -1

func setup(inventory: Inventory) -> void:
	_inventory = inventory
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for i in InventoryConfig.SLOT_COUNT:
		var panel := Panel.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_entered.connect(_on_hover.bind(i))
		panel.gui_input.connect(_on_slot_input.bind(i))
		var icon := ColorRect.new()
		icon.position = Vector2(16, 10)
		icon.size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		var letter := Label.new()
		letter.size = icon.size
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(letter)
		var count := Label.new()
		count.position = Vector2(4, 50)
		count.size = Vector2(SLOT_SIZE.x - 8, 20)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(count)
		if i < InventoryConfig.HOTBAR_SIZE:
			var number := Label.new()
			number.text = str(i + 1)
			number.position = Vector2(5, 1)
			number.modulate = Color(0.6, 0.8, 1.0)
			number.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(number)
		grid.add_child(panel)
		_panels.append(panel)
		_icons.append(icon)
		_letters.append(letter)
		_counts.append(count)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(0, 24)
	add_child(_info)
	var hint := Label.new()
	hint.text = "Slot 1-9 = hotbar. Klik slot lalu slot tujuan untuk memindahkan."
	hint.modulate = Color(1, 1, 1, 0.6)
	add_child(hint)
	_inventory.changed.connect(refresh)
	refresh()

func _on_hover(index: int) -> void:
	_hovered = index
	_update_info()

func _on_slot_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _selected == -1:
		if not _inventory.slots[index].is_empty():
			_selected = index
	elif _selected == index:
		_selected = -1
	else:
		var from := _selected
		_selected = -1
		_inventory.move_slot(from, index)  # emits changed -> refresh
	refresh()

func refresh() -> void:
	if _inventory == null or _panels.is_empty():
		return
	for i in _panels.size():
		var slot: Dictionary = _inventory.slots[i]
		var filled := not slot.is_empty()
		_icons[i].visible = filled
		_counts[i].text = str(slot["count"]) if filled else ""
		if filled:
			_icons[i].color = InventoryConfig.item_color(slot["id"])
			_letters[i].text = InventoryConfig.item_name(slot["id"]).substr(0, 1)
		_panels[i].add_theme_stylebox_override("panel", _style(i, filled))
	_update_info()

func _update_info() -> void:
	var index := _selected if _selected >= 0 else _hovered
	if _info == null or index < 0 or index >= _inventory.slots.size():
		return
	var slot: Dictionary = _inventory.slots[index]
	if slot.is_empty():
		_info.text = "Slot %d: Kosong" % (index + 1)
	else:
		_info.text = "Slot %d: %s x%d (maks %d)" % [index + 1, InventoryConfig.item_name(slot["id"]),
			slot["count"], InventoryConfig.max_stack(slot["id"])]

func _style(index: int, filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.22, 0.25, 0.95) if filled else Color(0.1, 0.1, 0.12, 0.85)
	style.border_color = Color(0.5, 0.5, 0.55, 1) if filled else Color(0.3, 0.3, 0.34, 1)
	if index < InventoryConfig.HOTBAR_SIZE:
		style.border_color = Color(0.35, 0.6, 0.9, 1)
	if index == _selected:
		style.border_color = Color(1.0, 0.85, 0.2, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style

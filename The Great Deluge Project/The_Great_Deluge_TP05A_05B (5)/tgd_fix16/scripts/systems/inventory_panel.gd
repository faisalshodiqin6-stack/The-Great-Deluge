extends UIPanel
class_name InventoryPanel

## Unified panel: tabs "Inventory", "Crafting" and "Status". Tab / Esc closes it.
@export var inventory_path: NodePath
@export var crafting_path: NodePath

@onready var _inventory: Inventory = get_node_or_null(inventory_path) as Inventory
@onready var _crafting: CraftingManager = get_node_or_null(crafting_path) as CraftingManager

var _inventory_view: InventoryView
var _crafting_view: CraftingView
var _status_view: TemperatureStatusView

func _init() -> void:
	ui_id = "inventory_panel"
	toggle_key = KEY_TAB

func toggle() -> void:
	_set_open(not _open)

func _on_opened() -> void:
	_inventory_view.refresh()
	_crafting_view.refresh()
	_status_view.refresh()

func _build_ui() -> void:
	add_to_group("inventory_panel")
	var box := _make_window(self)
	var title := Label.new()
	title.text = "Tab / Esc: tutup"
	box.add_child(title)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(880, 540)
	box.add_child(tabs)
	# Inventory tab: equipment around a 3D character (left) + 24-slot grid (right).
	var inventory_tab := HBoxContainer.new()
	inventory_tab.name = "Inventory"
	inventory_tab.add_theme_constant_override("separation", 20)
	tabs.add_child(inventory_tab)
	inventory_tab.add_child(EquipmentView.new())
	_inventory_view = InventoryView.new()
	_inventory_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inventory_tab.add_child(_inventory_view)
	_inventory_view.setup(_inventory)
	_crafting_view = CraftingView.new()
	_crafting_view.name = "Crafting"
	tabs.add_child(_crafting_view)
	_crafting_view.setup(_inventory, _crafting)
	# Status tab (scrolls on small screens): the signal-driven bars, larger, then body
	# temperature details. Content is built here, in the existing tab.
	var status_tab := ScrollContainer.new()
	status_tab.name = "Status"
	status_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(status_tab)
	var status_box := VBoxContainer.new()
	status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_theme_constant_override("separation", 12)
	status_tab.add_child(status_box)
	var bars_center := CenterContainer.new()
	status_box.add_child(bars_center)
	var status_bars := SurvivalBars.new()
	status_bars.compact = false
	bars_center.add_child(status_bars)
	status_box.add_child(HSeparator.new())
	_status_view = TemperatureStatusView.new()
	status_box.add_child(_status_view)
	tabs.tab_changed.connect(func(_index: int) -> void: _status_view.refresh())

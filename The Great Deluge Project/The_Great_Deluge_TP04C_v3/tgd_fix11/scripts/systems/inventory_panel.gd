extends UIPanel
class_name InventoryPanel

## Unified panel: tabs "Inventory" and "Crafting". Tab / Esc closes it.
@export var inventory_path: NodePath
@export var crafting_path: NodePath

@onready var _inventory: Inventory = get_node_or_null(inventory_path) as Inventory
@onready var _crafting: CraftingManager = get_node_or_null(crafting_path) as CraftingManager

var _inventory_view: InventoryView
var _crafting_view: CraftingView

func _init() -> void:
	ui_id = "inventory_panel"
	toggle_key = KEY_TAB

func toggle() -> void:
	_set_open(not _open)

func _on_opened() -> void:
	_inventory_view.refresh()
	_crafting_view.refresh()

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

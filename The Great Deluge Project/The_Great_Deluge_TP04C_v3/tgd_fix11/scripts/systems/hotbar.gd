extends Node
class_name Hotbar

## Hotbar state: which of the first HOTBAR_SIZE inventory slots is active.
## It stores NO items; everything lives in Inventory.
signal active_changed(index: int)
signal contents_changed

@export var inventory_path: NodePath
@onready var _inventory: Inventory = get_node_or_null(inventory_path) as Inventory

var active_index: int = 0

func _ready() -> void:
	add_to_group("hotbar")
	if _inventory:
		_inventory.changed.connect(func() -> void: contents_changed.emit())

## The active slot ({} when empty = player holds nothing).
func get_active_slot() -> Dictionary:
	return _inventory.slots[active_index] if _inventory else {}

## Id of the held item, "" if the active slot is empty. For interaction/tool systems.
func get_active_item_id() -> String:
	var slot := get_active_slot()
	return "" if slot.is_empty() else String(slot["id"])

func select(index: int) -> void:
	index = clampi(index, 0, InventoryConfig.HOTBAR_SIZE - 1)
	if index != active_index:
		active_index = index
		active_changed.emit(index)

func cycle(direction: int) -> void:
	select(posmod(active_index + direction, InventoryConfig.HOTBAR_SIZE))

func _unhandled_input(event: InputEvent) -> void:
	if UIState.blocked(get_tree()):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			select(event.keycode - KEY_1)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle(1)

extends Node

## Bridge between collectible objects and the Inventory. Holds NO counts of its
## own; the HUD label is rendered from the inventory's totals.
@export var inventory_path: NodePath
@export var label_path: NodePath

@onready var _inventory: Inventory = get_node_or_null(inventory_path) as Inventory
@onready var _label: Label = get_node_or_null(label_path) as Label

func _ready() -> void:
	if _inventory:
		_inventory.changed.connect(_refresh)
	_refresh()

## All-or-nothing: returns false (and changes nothing) when the stack does not fit.
func try_collect(resource_id: String, display_name: String, amount: int) -> bool:
	if _inventory == null or not _inventory.can_add(resource_id, amount):
		return false
	_inventory.add_item(resource_id, amount)
	print("[Resource] +%d %s (total %d)" % [amount, display_name, _inventory.get_total(resource_id)])
	return true

func _refresh() -> void:
	if _label == null:
		return
	var parts: PackedStringArray = []
	if _inventory:
		var totals := _inventory.get_totals()
		for id in totals:
			parts.append("%s: %d" % [InventoryConfig.item_name(id), totals[id]])
	_label.text = "Material: " + (" | ".join(parts) if parts.size() > 0 else "-")

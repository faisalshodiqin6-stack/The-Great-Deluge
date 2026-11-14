extends Node
class_name CraftingManager

## Crafting logic only: check ingredients and space, remove ingredients, add
## the result. Reads/writes the same Inventory as the HUD; keeps no counts.
@export var inventory_path: NodePath
@export var cooldown_msec: int = 250

@onready var _inventory: Inventory = get_node_or_null(inventory_path) as Inventory
var _next_craft_msec: int = 0

## Returns {"ok": bool, "reason": String}. Never modifies the inventory.
func check(recipe_id: String) -> Dictionary:
	var recipe := CraftingRecipes.find(recipe_id)
	if recipe.is_empty() or _inventory == null:
		return {"ok": false, "reason": "Resep tidak tersedia"}
	for id in recipe["ingredients"]:
		if _inventory.get_total(id) < int(recipe["ingredients"][id]):
			return {"ok": false, "reason": "Bahan tidak cukup"}
	# The result must fit AFTER the ingredients are removed (they may free slots).
	var snap := _inventory.snapshot()
	for id in recipe["ingredients"]:
		_inventory.remove_item(id, int(recipe["ingredients"][id]), true)
	var fits := _inventory.can_add(recipe["output"], int(recipe["amount"]))
	_inventory.restore(snap, true)
	if not fits:
		return {"ok": false, "reason": "Inventaris penuh"}
	return {"ok": true, "reason": ""}

func craft(recipe_id: String) -> Dictionary:
	if Time.get_ticks_msec() < _next_craft_msec:
		return {"ok": false, "reason": "Tunggu sebentar"}
	var result := check(recipe_id)
	if not result["ok"]:
		return result
	_next_craft_msec = Time.get_ticks_msec() + cooldown_msec
	var recipe := CraftingRecipes.find(recipe_id)
	# Atomic: ingredients are only consumed if the output was fully added.
	var snap := _inventory.snapshot()
	for id in recipe["ingredients"]:
		_inventory.remove_item(id, int(recipe["ingredients"][id]), true)
	if _inventory.add_item(recipe["output"], int(recipe["amount"])) > 0:
		_inventory.restore(snap)
		return {"ok": false, "reason": "Inventaris penuh"}
	print("[Crafting] %s x%d" % [recipe["name"], recipe["amount"]])
	return {"ok": true, "reason": "Berhasil membuat %s" % recipe["name"]}

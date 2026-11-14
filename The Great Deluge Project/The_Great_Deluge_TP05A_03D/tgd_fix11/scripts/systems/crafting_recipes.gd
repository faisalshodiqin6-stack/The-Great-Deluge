extends RefCounted
class_name CraftingRecipes

## Recipe data only. To add a recipe, append an entry here (and its output item
## to InventoryConfig.ITEMS). No other code needs to change.
const RECIPES := [
	{"id": "papan_kayu", "name": "Papan Kayu", "ingredients": {"kayu_apung": 2}, "output": "papan_kayu", "amount": 1},
	{"id": "tongkat_kayu", "name": "Tongkat Kayu", "ingredients": {"kayu_apung": 1}, "output": "tongkat_kayu", "amount": 1},
	{"id": "material_olahan", "name": "Material Olahan", "ingredients": {"batu": 3}, "output": "material_olahan", "amount": 1},
]

static func get_all() -> Array:
	return RECIPES

static func find(recipe_id: String) -> Dictionary:
	for recipe in RECIPES:
		if recipe["id"] == recipe_id:
			return recipe
	return {}

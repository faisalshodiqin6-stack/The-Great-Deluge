extends VBoxContainer
class_name CraftingView

## Crafting tab: recipe list, required/owned ingredients, result, craft button.
var _inventory: Inventory
var _crafting: CraftingManager
var _recipe_buttons: Array[Button] = []
var _selected: int = 0
var _result_label: Label
var _ingredient_box: VBoxContainer
var _status_label: Label
var _craft_button: Button

func setup(inventory: Inventory, crafting: CraftingManager) -> void:
	_inventory = inventory
	_crafting = crafting
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(240, 0)
	row.add_child(list)
	for i in CraftingRecipes.get_all().size():
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(_select.bind(i))
		list.add_child(button)
		_recipe_buttons.append(button)
	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(280, 0)
	row.add_child(details)
	_result_label = Label.new()
	details.add_child(_result_label)
	var header := Label.new()
	header.text = "Bahan (dimiliki / dibutuhkan):"
	details.add_child(header)
	_ingredient_box = VBoxContainer.new()
	details.add_child(_ingredient_box)
	_craft_button = Button.new()
	_craft_button.text = "Craft"
	_craft_button.custom_minimum_size = Vector2(0, 44)
	_craft_button.pressed.connect(_on_craft_pressed)
	details.add_child(_craft_button)
	_status_label = Label.new()
	details.add_child(_status_label)
	_inventory.changed.connect(refresh)
	refresh()

func _select(index: int) -> void:
	_selected = index
	_status_label.text = ""
	refresh()

func _on_craft_pressed() -> void:
	var recipe: Dictionary = CraftingRecipes.get_all()[_selected]
	var result := _crafting.craft(recipe["id"])
	_status_label.text = result["reason"]
	refresh()

func refresh() -> void:
	if _crafting == null or _inventory == null or _recipe_buttons.is_empty():
		return
	var recipes := CraftingRecipes.get_all()
	for i in recipes.size():
		var can := bool(_crafting.check(recipes[i]["id"])["ok"])
		_recipe_buttons[i].text = "%s   %s" % [recipes[i]["name"], "(siap)" if can else "(kurang)"]
		_recipe_buttons[i].modulate = Color(1.0, 0.9, 0.4) if i == _selected else Color(1, 1, 1)
	var recipe: Dictionary = recipes[_selected]
	_result_label.text = "Hasil: %s x%d" % [InventoryConfig.item_name(recipe["output"]), recipe["amount"]]
	for child in _ingredient_box.get_children():
		child.queue_free()
	for id in recipe["ingredients"]:
		var have := _inventory.get_total(id)
		var need := int(recipe["ingredients"][id])
		var label := Label.new()
		label.text = "%s: %d / %d" % [InventoryConfig.item_name(id), have, need]
		label.modulate = Color(0.6, 1.0, 0.6) if have >= need else Color(1.0, 0.5, 0.5)
		_ingredient_box.add_child(label)
	var status := _crafting.check(recipe["id"])
	_craft_button.disabled = not status["ok"]
	if _status_label.text == "" and not status["ok"]:
		_status_label.text = status["reason"]

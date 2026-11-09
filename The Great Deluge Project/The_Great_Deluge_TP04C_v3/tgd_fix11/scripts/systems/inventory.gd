extends Node
class_name Inventory

## Inventory data + stacking only (no UI, no world logic).
## A slot is {} (empty) or {"id": String, "count": int}.
signal changed

var slots: Array[Dictionary] = []

func _init() -> void:
	for i in InventoryConfig.SLOT_COUNT:
		slots.append({})

## Room (in items) available for this item: partial stacks + empty slots.
func free_space_for(id: String) -> int:
	var max_stack := InventoryConfig.max_stack(id)
	var space := 0
	for slot in slots:
		if slot.is_empty():
			space += max_stack
		elif slot["id"] == id:
			space += max_stack - int(slot["count"])
	return space

func can_add(id: String, amount: int) -> bool:
	return amount > 0 and free_space_for(id) >= amount

## Adds as many as fit (existing stacks first, then empty slots).
## Returns the leftover that did not fit.
func add_item(id: String, amount: int) -> int:
	var remaining := amount
	var max_stack := InventoryConfig.max_stack(id)
	for slot in slots:
		if remaining <= 0:
			break
		if not slot.is_empty() and slot["id"] == id and int(slot["count"]) < max_stack:
			var moved := mini(remaining, max_stack - int(slot["count"]))
			slot["count"] = int(slot["count"]) + moved
			remaining -= moved
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var moved := mini(remaining, max_stack)
			slots[i] = {"id": id, "count": moved}
			remaining -= moved
	if remaining != amount:
		changed.emit()
	return remaining

## Moves/merges/swaps slot `from` into slot `to`. Never creates or destroys items.
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= slots.size() or to >= slots.size():
		return
	var a := slots[from]
	var b := slots[to]
	if a.is_empty():
		return
	if b.is_empty():
		slots[to] = a
		slots[from] = {}
	elif a["id"] == b["id"]:
		var moved := mini(int(a["count"]), InventoryConfig.max_stack(a["id"]) - int(b["count"]))
		b["count"] = int(b["count"]) + moved
		a["count"] = int(a["count"]) - moved
		if int(a["count"]) <= 0:
			slots[from] = {}
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()

## Removes `amount` of an item (all-or-nothing), taking from the last stacks first.
func remove_item(id: String, amount: int, silent: bool = false) -> bool:
	if amount <= 0 or get_total(id) < amount:
		return false
	var remaining := amount
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var slot := slots[i]
		if not slot.is_empty() and slot["id"] == id:
			var taken := mini(remaining, int(slot["count"]))
			slot["count"] = int(slot["count"]) - taken
			remaining -= taken
			if int(slot["count"]) <= 0:
				slots[i] = {}
	if not silent:
		changed.emit()
	return true

## Copy of the slots, for safe what-if checks (see restore()).
func snapshot() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for slot in slots:
		copy.append(slot.duplicate())
	return copy

func restore(snap: Array[Dictionary], silent: bool = false) -> void:
	slots = []
	for slot in snap:
		slots.append(slot.duplicate())
	if not silent:
		changed.emit()

func get_total(id: String) -> int:
	var total := 0
	for slot in slots:
		if not slot.is_empty() and slot["id"] == id:
			total += int(slot["count"])
	return total

## id -> total count, for HUD display.
func get_totals() -> Dictionary:
	var totals := {}
	for slot in slots:
		if not slot.is_empty():
			totals[slot["id"]] = int(totals.get(slot["id"], 0)) + int(slot["count"])
	return totals

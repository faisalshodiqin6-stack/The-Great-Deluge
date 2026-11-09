extends RefCounted
class_name InventoryConfig

## Central inventory configuration. Change slot count / stack sizes here.
const SLOT_COUNT: int = 24
const HOTBAR_SIZE: int = 9   # Hotbar = the first HOTBAR_SIZE inventory slots (not extra storage).
const DEFAULT_MAX_STACK: int = 20
## "shape" is only used for the placeholder held-item model: stick / plank / ball.
const ITEMS := {
	"kayu_apung": {"name": "Kayu Apung", "max_stack": 20, "color": Color(0.62, 0.45, 0.25), "shape": "stick"},
	"batu": {"name": "Batu", "max_stack": 20, "color": Color(0.55, 0.55, 0.58), "shape": "ball"},
	"kelapa": {"name": "Kelapa", "max_stack": 10, "color": Color(0.38, 0.24, 0.12), "shape": "ball"},
	"papan_kayu": {"name": "Papan Kayu", "max_stack": 20, "color": Color(0.8, 0.62, 0.35), "shape": "plank"},
	"tongkat_kayu": {"name": "Tongkat Kayu", "max_stack": 20, "color": Color(0.5, 0.33, 0.18), "shape": "stick"},
	"material_olahan": {"name": "Material Olahan", "max_stack": 20, "color": Color(0.7, 0.72, 0.85), "shape": "plank"},
}

static func max_stack(id: String) -> int:
	return ITEMS.get(id, {}).get("max_stack", DEFAULT_MAX_STACK)

static func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)

static func item_color(id: String) -> Color:
	return ITEMS.get(id, {}).get("color", Color(0.8, 0.8, 0.8))

static func item_shape(id: String) -> String:
	return ITEMS.get(id, {}).get("shape", "ball")

extends RefCounted
class_name EquipmentConfig

## UI layout data for equipment slots (visual only, no equip logic yet).
## pos = center of the slot as a fraction (0..1) of the preview area, so the
## layout scales with the area. To add an accessory (or another category),
## append an entry here; the view builds it automatically.
## "size" is in pixels (kept >= 44 for touch).
const SLOTS := [
	{"id": "head", "label": "Head", "hint": "Perlengkapan kepala", "abbr": "HEAD", "pos": Vector2(0.50, 0.075), "size": 56.0},
	{"id": "body", "label": "Body", "hint": "Pakaian / pelindung badan", "abbr": "BODY", "pos": Vector2(0.10, 0.26), "size": 56.0},
	{"id": "backpack", "label": "Backpack", "hint": "Tas", "abbr": "PACK", "pos": Vector2(0.90, 0.26), "size": 56.0},
	{"id": "gloves", "label": "Gloves", "hint": "Sarung tangan", "abbr": "GLOV", "pos": Vector2(0.10, 0.46), "size": 56.0},
	{"id": "pants", "label": "Pants", "hint": "Celana / pelindung kaki", "abbr": "PANT", "pos": Vector2(0.90, 0.50), "size": 56.0},
	{"id": "shoes", "label": "Shoes", "hint": "Sepatu", "abbr": "SHOE", "pos": Vector2(0.10, 0.74), "size": 56.0},
	{"id": "accessory_1", "label": "Accessory 1", "hint": "Aksesori (mis. kalung)", "abbr": "ACC1", "pos": Vector2(0.30, 0.94), "size": 46.0, "accessory": true},
	{"id": "accessory_2", "label": "Accessory 2", "hint": "Aksesori (mis. gelang)", "abbr": "ACC2", "pos": Vector2(0.50, 0.94), "size": 46.0, "accessory": true},
	{"id": "accessory_3", "label": "Accessory 3", "hint": "Aksesori tambahan", "abbr": "ACC3", "pos": Vector2(0.70, 0.94), "size": 46.0, "accessory": true},
]

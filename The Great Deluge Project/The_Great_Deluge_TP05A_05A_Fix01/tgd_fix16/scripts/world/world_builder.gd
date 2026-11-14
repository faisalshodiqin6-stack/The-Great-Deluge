extends Node3D

## Places environment props on the island at runtime using the island's own
## height function. Edit LAYOUT to move/add objects: [type, x, z, yaw_deg, scale].
## Pickups (wood/rock/coconut) are Interactables; the rest are decorative
## static bodies on the world layer (they block movement and line of sight).
@export var island_path: NodePath

const SCENES := {
	"wood": preload("res://scenes/objects/driftwood.tscn"),
	"rock": preload("res://scenes/objects/rock_pickup.tscn"),
	"coconut": preload("res://scenes/objects/coconut_pickup.tscn"),
	"tree": preload("res://scenes/objects/tree.tscn"),
	"boulder": preload("res://scenes/objects/boulder.tscn"),
	"crate": preload("res://scenes/objects/crate.tscn"),
	"wall": preload("res://scenes/objects/wall.tscn"),
	"pillar": preload("res://scenes/objects/pillar.tscn"),
}
# Walls sink a little so they stay planted on slopes.
const SINK := {"wall": 0.3, "pillar": 0.2, "boulder": 0.1, "tree": 0.1, "crate": 0.05}

const LAYOUT := [
	["wood", 34, -12, 0, 1],
	["rock", 40, -4, 0, 1],
	["coconut", 46, 3, 0, 1],
	["wood", 52, -18, 40, 1],
	["rock", 38, 12, 0, 1],
	["coconut", 55, 8, 0, 1],
	["wood", 60, 0, 70, 1],
	["rock", 47, -10, 0, 1],
	["coconut", 33, 20, 0, 1],
	["wood", 50, 18, 10, 1],
	["rock", 58, -8, 0, 1],
	["wood", -60, 10, 20, 1],
	["rock", -55, -20, 0, 1],
	["coconut", -62, 22, 0, 1],
	["wood", 20, -45, 100, 1],
	["rock", -10, -50, 0, 1],
	["coconut", 60, -22, 0, 1],
	["tree", -42, -30, 0, 1.1],
	["tree", -36, -36, 0, 1.0],
	["tree", -30, -28, 0, 1.2],
	["tree", -25, -34, 0, 0.9],
	["tree", -45, -22, 0, 1.0],
	["boulder", -34, -24, 0, 1.0],
	["boulder", -22, -22, 0, 1.3],
	["crate", -28, -20, 15, 1],
	["crate", -31, -18, 40, 1],
	["wood", -33, -30, 30, 1],
	["rock", -29, -24, 0, 1],
	["coconut", -26, -30, 0, 1],
	["rock", -38, -30, 0, 1],
	["wall", 10, 32, 0, 1],
	["wall", 7, 36, 90, 1],
	["wall", 13, 36, 90, 1],
	["crate", 10, 36, 0, 1],
	["rock", 11.5, 38, 0, 1],
	["pillar", -4, 38, 0, 1],
	["pillar", -4, 44, 0, 1],
	["pillar", -12, 38, 0, 1],
	["pillar", -12, 44, 0, 1],
	["wall", -20, 34, 30, 1],
	["wall", 22, 40, 0, 1],
	["crate", 20, 34, 20, 1],
	["wood", 0, 40, 0, 1],
	["boulder", 15, -30, 0, 1.5],
	["boulder", -50, 12, 0, 1.2],
	["boulder", 45, 35, 0, 1.4],
	["tree", 22, -8, 0, 1.0],
	["tree", -20, 12, 0, 1.1],
	["tree", 60, 25, 0, 1.0],
	["tree", -55, -5, 0, 1.0],
	["tree", 5, -35, 0, 1.1]
]

func _ready() -> void:
	var island = get_node(island_path)
	for entry in LAYOUT:
		var scene: PackedScene = SCENES[entry[0]]
		var instance := scene.instantiate() as Node3D
		add_child(instance)
		var x: float = entry[1]
		var z: float = entry[2]
		instance.position = Vector3(x, island.height_at(x, z) - SINK.get(entry[0], 0.03), z)
		instance.rotation_degrees.y = entry[3]
		instance.scale = Vector3.ONE * float(entry[4])

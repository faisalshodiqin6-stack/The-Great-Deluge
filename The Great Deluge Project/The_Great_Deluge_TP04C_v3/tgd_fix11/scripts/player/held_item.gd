extends Node

## Placeholder held-item display (simple colored primitives, no real models).
## First Person: attached to the FP camera (bottom-right of the view).
## Third Person: attached next to the character body at "hand" height.
## Empty hotbar slot = nothing shown.
var _hotbar: Hotbar = null
var _fp_rig: FirstPersonCamera = null
var _fp_holder: MeshInstance3D
var _tp_holder: MeshInstance3D
var _shown_id: String = "<unset>"

func _ready() -> void:
	var parent := get_parent()
	_fp_rig = parent.get_node_or_null("FirstPersonCamera") as FirstPersonCamera
	var fp_camera := parent.get_node_or_null("FirstPersonCamera/Camera3D")
	var body_visual := parent.get_node_or_null("Visual")
	if fp_camera:
		_fp_holder = _make_holder(fp_camera, Vector3(0.28, -0.26, -0.6), Vector3(-15, 0, -10))
	if body_visual:
		_tp_holder = _make_holder(body_visual, Vector3(0.55, 0.1, -0.2), Vector3(0, 0, 0))

func _make_holder(parent: Node, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var holder := MeshInstance3D.new()
	holder.position = pos
	holder.rotation_degrees = rot_deg
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.visible = false
	parent.add_child(holder)
	return holder

func _process(_delta: float) -> void:
	if _hotbar == null:
		_hotbar = get_tree().get_first_node_in_group("hotbar") as Hotbar
		if _hotbar == null:
			return
	var id := _hotbar.get_active_item_id()
	if id != _shown_id:
		_shown_id = id
		_apply(_fp_holder, id)
		_apply(_tp_holder, id)
	# The FP model only shows while the FP camera is active.
	# (The TP model is a child of the body mesh, which is hidden in First Person.)
	if _fp_holder:
		_fp_holder.visible = id != "" and _fp_rig != null and _fp_rig.is_active()
	if _tp_holder:
		_tp_holder.visible = id != ""

func _apply(holder: MeshInstance3D, id: String) -> void:
	if holder == null:
		return
	if id == "":
		holder.mesh = null
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = InventoryConfig.item_color(id)
	material.roughness = 1.0
	var mesh: Mesh
	match InventoryConfig.item_shape(id):
		"stick":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.03
			cylinder.bottom_radius = 0.035
			cylinder.height = 0.5
			mesh = cylinder
		"plank":
			var box := BoxMesh.new()
			box.size = Vector3(0.28, 0.04, 0.12)
			mesh = box
		_:
			var ball := SphereMesh.new()
			ball.radius = 0.08
			ball.height = 0.16
			mesh = ball
	holder.mesh = mesh
	holder.material_override = material

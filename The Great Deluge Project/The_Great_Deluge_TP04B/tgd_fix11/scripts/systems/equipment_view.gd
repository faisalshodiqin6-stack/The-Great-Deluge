extends VBoxContainer
class_name EquipmentView

## Equipment slots around a rotatable 3D character preview (UI only).
## Slots are placed by fractional anchors inside the preview area, so they
## scale with it and never overlap the center column (the drag-to-rotate area).
## Not connected to any equipment system yet: show_item() only changes visuals,
## nothing is stored, taken from the inventory, or duplicated.
signal slot_selected(slot_id: String)

const AREA_MIN_SIZE := Vector2(340, 480)
const PREVIEW_BG := Color(0.12, 0.13, 0.16, 1.0)

var _area: Control
var _info: Label
var _model: Node3D
var _panels: Dictionary = {}   # slot id -> Panel
var _icons: Dictionary = {}    # slot id -> ColorRect (item icon, hidden when empty)
var _selected: String = ""

func _ready() -> void:
	_area = Control.new()
	_area.custom_minimum_size = AREA_MIN_SIZE
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_area)
	_build_preview()
	for def in EquipmentConfig.SLOTS:
		_build_slot(def)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(0, 24)
	_info.text = "Equipment (belum aktif). Geser model untuk memutar."
	add_child(_info)
	_refresh_styles()

## Visual hook for the future equipment system. Pass "" to clear.
func show_item(slot_id: String, item_id: String) -> void:
	var icon := _icons.get(slot_id) as ColorRect
	if icon:
		icon.visible = item_id != ""
		if item_id != "":
			icon.color = InventoryConfig.item_color(item_id)
		_refresh_styles()

func _build_preview() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.gui_input.connect(_on_preview_input)
	_area.add_child(container)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	container.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = PREVIEW_BG
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	viewport.add_child(light)

	# The character spans ~1.8 m; the camera frames it to ~72% of the area height.
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 0.9, 4.66)
	viewport.add_child(camera)
	camera.current = true

	_model = Node3D.new()
	viewport.add_child(_model)
	var skin := Color(0.9, 0.35, 0.18)
	_add_part(CapsuleMesh.new(), Vector3(-0.12, 0.43, 0), Vector3(0.09, 0.86, 0.09), skin)  # legs
	_add_part(CapsuleMesh.new(), Vector3(0.12, 0.43, 0), Vector3(0.09, 0.86, 0.09), skin)
	_add_part(BoxMesh.new(), Vector3(0, 1.2, 0), Vector3(0.5, 0.62, 0.26), skin.darkened(0.15))  # torso
	_add_part(CapsuleMesh.new(), Vector3(-0.36, 1.15, 0), Vector3(0.07, 0.62, 0.07), skin)       # arms
	_add_part(CapsuleMesh.new(), Vector3(0.36, 1.15, 0), Vector3(0.07, 0.62, 0.07), skin)
	_add_part(SphereMesh.new(), Vector3(0, 1.62, 0), Vector3(0.26, 0.26, 0.26), skin.lightened(0.2))  # head

## `dims` = full size for box, (radius, height, _) for capsule, diameter for sphere.
func _add_part(mesh: Mesh, pos: Vector3, dims: Vector3, color: Color) -> void:
	if mesh is CapsuleMesh:
		mesh.radius = dims.x
		mesh.height = dims.y
	elif mesh is BoxMesh:
		mesh.size = dims
	elif mesh is SphereMesh:
		mesh.radius = dims.x / 2.0
		mesh.height = dims.x
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	instance.material_override = material
	_model.add_child(instance)

func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_model.rotate_y(event.relative.x * 0.012)

func _build_slot(def: Dictionary) -> void:
	var slot_size: float = def["size"]
	var panel := Panel.new()
	panel.anchor_left = def["pos"].x
	panel.anchor_right = def["pos"].x
	panel.anchor_top = def["pos"].y
	panel.anchor_bottom = def["pos"].y
	panel.offset_left = -slot_size / 2.0
	panel.offset_right = slot_size / 2.0
	panel.offset_top = -slot_size / 2.0
	panel.offset_bottom = slot_size / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = "%s - %s" % [def["label"], def["hint"]]
	panel.mouse_entered.connect(_set_info.bind(def["id"]))
	panel.gui_input.connect(_on_slot_input.bind(def["id"]))
	# Placeholder category icon (text) shown while the slot is empty.
	var abbr := Label.new()
	abbr.text = def["abbr"]
	abbr.set_anchors_preset(Control.PRESET_FULL_RECT)
	abbr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abbr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	abbr.add_theme_font_size_override("font_size", 11)
	abbr.modulate = Color(1, 1, 1, 0.45)
	abbr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(abbr)
	var icon := ColorRect.new()
	icon.position = Vector2(slot_size * 0.22, slot_size * 0.22)
	icon.size = Vector2(slot_size * 0.56, slot_size * 0.56)
	icon.visible = false
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	_area.add_child(panel)
	_panels[def["id"]] = panel
	_icons[def["id"]] = icon

func _on_slot_input(event: InputEvent, slot_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected = "" if _selected == slot_id else slot_id
		_set_info(slot_id)
		_refresh_styles()
		slot_selected.emit(slot_id)

func _set_info(slot_id: String) -> void:
	for def in EquipmentConfig.SLOTS:
		if def["id"] == slot_id and _info:
			var empty := not (_icons[slot_id] as ColorRect).visible
			_info.text = "%s - %s%s" % [def["label"], def["hint"], " (kosong)" if empty else ""]

func _refresh_styles() -> void:
	for def in EquipmentConfig.SLOTS:
		var slot_id: String = def["id"]
		var filled := (_icons[slot_id] as ColorRect).visible
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.25, 0.3, 0.95) if filled else Color(0.07, 0.07, 0.09, 0.8)
		style.border_color = Color(0.45, 0.7, 0.45, 1) if def.get("accessory", false) else Color(0.4, 0.5, 0.65, 1)
		if slot_id == _selected:
			style.border_color = Color(1.0, 0.85, 0.2, 1)
		style.set_border_width_all(3 if slot_id == _selected else 2)
		style.set_corner_radius_all(6)
		(_panels[slot_id] as Panel).add_theme_stylebox_override("panel", style)

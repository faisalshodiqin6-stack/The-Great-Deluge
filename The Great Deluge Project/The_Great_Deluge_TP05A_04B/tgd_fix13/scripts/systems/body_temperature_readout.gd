extends HBoxContainer
class_name BodyTemperatureReadout

## One HUD row: "Suhu  36.8 °C  [Normal]". Laid out like the survival bars (name, middle,
## value) so it lines up under them. Updated only by BodyTemperature signals
## (temperature_changed / category_changed); no per-frame polling. UI only.
@export var compact: bool = true

var _value_label: Label
var _chip_label: Label
var _chip_style: StyleBoxFlat
var _shown_text := ""
var _body: BodyTemperature = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	var font_size := 15 if compact else 20
	var name_label := Label.new()
	name_label.text = "Suhu"
	name_label.custom_minimum_size.x = 62 if compact else 100
	_style_label(name_label, 14 if compact else 20)
	add_child(name_label)
	_value_label = Label.new()
	_value_label.text = "-- °C"
	_value_label.custom_minimum_size.x = 60 if compact else 96
	_style_label(_value_label, font_size)
	add_child(_value_label)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.custom_minimum_size.x = 100 if compact else 200
	_chip_style = StyleBoxFlat.new()
	_chip_style.bg_color = Color(0.3, 0.3, 0.3)
	_chip_style.set_corner_radius_all(4)
	_chip_style.content_margin_left = 4
	_chip_style.content_margin_right = 4
	_chip_style.content_margin_top = 1
	_chip_style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", _chip_style)
	add_child(chip)
	_chip_label = Label.new()
	_chip_label.text = "Tidak tersedia"
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_chip_label, 14 if compact else 20)
	chip.add_child(_chip_label)
	# BodyTemperature may be created after this node; connect once the tree is ready.
	_connect_body.call_deferred()

func _style_label(label: Label, font_size: int) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)

func _connect_body() -> void:
	_body = TemperatureUI.find_body(get_tree())
	if _body == null:
		push_warning("BodyTemperatureReadout: BodyTemperature not found.")
		return
	_body.temperature_changed.connect(_on_temperature_changed)
	_body.category_changed.connect(_on_category_changed)
	_on_temperature_changed(_body.get_temperature())
	_show_category(_body.get_category())

func _on_temperature_changed(value: float) -> void:
	var text := TemperatureUI.format_temp(value)
	if text != _shown_text:  # Rebuild the text only when the shown number changes.
		_shown_text = text
		_value_label.text = text

func _on_category_changed(category: int, _previous: int) -> void:
	_show_category(category)

func _show_category(category: int) -> void:
	_chip_label.text = BodyTemperature.CATEGORY_NAMES.get(category, "?")
	_chip_style.bg_color = TemperatureUI.chip_color(category)

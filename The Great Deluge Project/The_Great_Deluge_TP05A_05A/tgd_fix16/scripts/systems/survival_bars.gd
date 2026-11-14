extends VBoxContainer
class_name SurvivalBars

## Health / Stamina / Hunger / Thirst bars with "value/max" text. Updated only by
## PlayerSurvival signals (no per-frame polling). Used twice: compact HUD and the
## larger Status tab. UI only: it never changes survival values.
@export var compact: bool = true
## Adds a body temperature row (value + category) under the four bars. HUD only.
@export var show_temperature: bool = false

const ROWS := [
	["health", "Health", Color(0.80, 0.25, 0.25)],
	["stamina", "Stamina", Color(0.85, 0.78, 0.30)],
	["hunger", "Hunger", Color(0.88, 0.55, 0.20)],
	["thirst", "Thirst", Color(0.30, 0.62, 0.90)],
]
const EXHAUSTED_COLOR := Color(0.55, 0.30, 0.25)

var _bars := {}
var _labels := {}
var _shown := {}
var _stamina_fill: StyleBoxFlat = null
var _stamina_color := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 3 if compact else 12)
	var font_size := 14 if compact else 20
	for row in ROWS:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 6)
		add_child(line)
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.custom_minimum_size.x = 62 if compact else 100
		_style_label(name_label, font_size)
		line.add_child(name_label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = 100.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(110 if compact else 300, 12 if compact else 22)
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0, 0, 0, 0.55)
		var fill := StyleBoxFlat.new()
		fill.bg_color = row[2]
		for box in [background, fill]:
			box.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", background)
		bar.add_theme_stylebox_override("fill", fill)
		line.add_child(bar)
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 64 if compact else 96
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_style_label(value_label, font_size)
		line.add_child(value_label)
		_bars[row[0]] = bar
		_labels[row[0]] = value_label
		if row[0] == "stamina":
			_stamina_fill = fill
			_stamina_color = row[2]
	if show_temperature:
		var readout := BodyTemperatureReadout.new()
		readout.compact = compact
		add_child(readout)
	# PlayerSurvival may be created after this node; connect once the tree is ready.
	_connect_survival.call_deferred()

func _style_label(label: Label, font_size: int) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)

func _connect_survival() -> void:
	var survival := get_tree().get_first_node_in_group("player_survival") as PlayerSurvival
	if survival == null:
		push_warning("SurvivalBars: PlayerSurvival not found.")
		return
	survival.health_changed.connect(_set_value.bind("health"))
	survival.stamina_changed.connect(_set_value.bind("stamina"))
	survival.hunger_changed.connect(_set_value.bind("hunger"))
	survival.thirst_changed.connect(_set_value.bind("thirst"))
	survival.exhausted_changed.connect(_on_exhausted)
	_set_value(survival.get_health(), survival.get_max_health(), "health")
	_set_value(survival.get_stamina(), survival.get_max_stamina(), "stamina")
	_set_value(survival.get_hunger(), survival.get_max_hunger(), "hunger")
	_set_value(survival.get_thirst(), survival.get_max_thirst(), "thirst")
	_on_exhausted(survival.is_exhausted())

func _set_value(value: float, max_value: float, key: String) -> void:
	var bar: ProgressBar = _bars[key]
	bar.max_value = max_value
	bar.value = value
	var shown := Vector2i(roundi(value), roundi(max_value))
	if _shown.get(key) != shown:  # Rebuild the text only when the number changes.
		_shown[key] = shown
		(_labels[key] as Label).text = "%d/%d" % [shown.x, shown.y]

func _on_exhausted(is_exhausted: bool) -> void:
	if _stamina_fill:
		_stamina_fill.bg_color = EXHAUSTED_COLOR if is_exhausted else _stamina_color

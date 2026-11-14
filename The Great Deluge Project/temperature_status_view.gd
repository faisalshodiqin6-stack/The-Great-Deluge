extends VBoxContainer
class_name TemperatureStatusView

## Body temperature section of the Status tab (inside the existing InventoryPanel).
## Shows: temperature + category, effects on the player, heat-producing activities,
## the environment data that REALLY exists, and a short cause of the current trend.
## Read-only: it never changes survival or temperature values and invents no data.
## Updated by BodyTemperature signals while visible, and by refresh() when the tab
## opens. Activity cannot change while the panel is open (gameplay input is blocked),
## and the world clock keeps running (this panel never pauses anything).

const MUTED := "#9aa0a6"
const TEXT := "#e6e6e6"
const GOOD := "#8fd694"
const ACTIVE := "#ffd966"
const BODY_FONT := 17
## |net power| below this (W) counts as "stable" (about 0.04 °C per game hour).
const STABLE_POWER := 3.0

var _body: BodyTemperature = null
var _survival: PlayerSurvival = null
var _value_label: Label
var _chip_label: Label
var _chip_style: StyleBoxFlat
var _ladder: RichTextLabel
var _effects: RichTextLabel
var _activity: RichTextLabel
var _env: RichTextLabel
var _cause: RichTextLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_add_title("Suhu tubuh", false)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 14)
	add_child(head)
	_value_label = Label.new()
	_value_label.text = "-- °C"
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value_label.add_theme_font_size_override("font_size", 32)
	head.add_child(_value_label)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip_style = StyleBoxFlat.new()
	_chip_style.bg_color = Color(0.3, 0.3, 0.3)
	_chip_style.set_corner_radius_all(6)
	_chip_style.content_margin_left = 12
	_chip_style.content_margin_right = 12
	_chip_style.content_margin_top = 3
	_chip_style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", _chip_style)
	head.add_child(chip)
	_chip_label = Label.new()
	_chip_label.text = "Tidak tersedia"
	_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_label.add_theme_font_size_override("font_size", 20)
	chip.add_child(_chip_label)
	_ladder = _make_rich()
	add_child(_ladder)

	_add_title("Pengaruh suhu pada pemain")
	_effects = _make_rich()
	add_child(_effects)
	_add_title("Aktivitas dan produksi panas")
	_activity = _make_rich()
	add_child(_activity)
	_add_title("Data lingkungan")
	_env = _make_rich()
	add_child(_env)
	_add_title("Penyebab perubahan suhu")
	_cause = _make_rich()
	add_child(_cause)
	# BodyTemperature / PlayerSurvival may be created after this node.
	_connect_body.call_deferred()

func _add_title(text: String, with_separator: bool = true) -> void:
	if with_separator:
		var separator := HSeparator.new()
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(separator)
	var title := Label.new()
	title.text = text
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(ACTIVE))
	add_child(title)

func _make_rich() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Lets touch-drag scroll the tab.
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", BODY_FONT)
	label.add_theme_font_size_override("bold_font_size", BODY_FONT)
	return label

func _connect_body() -> void:
	_body = TemperatureUI.find_body(get_tree())
	_survival = get_tree().get_first_node_in_group("player_survival") as PlayerSurvival
	if _body == null:
		push_warning("TemperatureStatusView: BodyTemperature not found.")
		_effects.text = "[color=%s]Sistem suhu tubuh tidak ditemukan.[/color]" % MUTED
		return
	_body.temperature_changed.connect(_on_body_changed)
	_body.category_changed.connect(_on_body_changed)
	refresh()

func _on_body_changed(_a = null, _b = null) -> void:
	if is_visible_in_tree():  # Hidden tab: skip the work; refresh() runs when it opens.
		refresh()

## Rebuild all texts from the current state. Called when the panel / tab opens.
func refresh() -> void:
	if _body == null:
		return
	var category := _body.get_category()
	_value_label.text = TemperatureUI.format_temp(_body.get_temperature())
	_value_label.add_theme_color_override("font_color", TemperatureUI.text_color(category))
	_chip_label.text = _body.get_category_name()
	_chip_style.bg_color = TemperatureUI.chip_color(category)
	_ladder.text = _ladder_text(category)
	_effects.text = _effects_text()
	_activity.text = _activity_text()
	_env.text = _env_text()
	_cause.text = _cause_text()

# ---- Text builders ----------------------------------------------------------
func _ladder_text(current: int) -> String:
	var b := _body
	var entries := [
		[BodyTemperature.Category.SEVERE_HYPOTHERMIA, "< %s" % TemperatureUI.format_plain(b.severe_hypothermia_below)],
		[BodyTemperature.Category.HYPOTHERMIA, "%s-%s" % [TemperatureUI.format_plain(b.severe_hypothermia_below), TemperatureUI.format_plain(b.hypothermia_below)]],
		[BodyTemperature.Category.COLD, "%s-%s" % [TemperatureUI.format_plain(b.hypothermia_below), TemperatureUI.format_plain(b.cold_below)]],
		[BodyTemperature.Category.NORMAL, "%s-%s" % [TemperatureUI.format_plain(b.cold_below), TemperatureUI.format_plain(b.hot_from)]],
		[BodyTemperature.Category.HOT, "%s-%s" % [TemperatureUI.format_plain(b.hot_from), TemperatureUI.format_plain(b.heat_stress_from)]],
		[BodyTemperature.Category.HEAT_STRESS, "%s-%s" % [TemperatureUI.format_plain(b.heat_stress_from), TemperatureUI.format_plain(b.critical_heat_from)]],
		[BodyTemperature.Category.CRITICAL_HEAT, ">= %s" % TemperatureUI.format_plain(b.critical_heat_from)],
	]
	var parts: Array[String] = []
	for entry in entries:
		var category_name: String = BodyTemperature.CATEGORY_NAMES[entry[0]]
		var part := "%s %s" % [category_name, entry[1]]
		if entry[0] == current:
			part = "[b][color=#%s]%s[/color][/b]" % [TemperatureUI.text_color(current).to_html(false), part]
		else:
			part = "[color=%s]%s[/color]" % [MUTED, part]
		parts.append(part)
	return "  |  ".join(parts) + "  [color=%s](°C)[/color]" % MUTED

func _percent(multiplier: float) -> int:
	return roundi(absf(multiplier - 1.0) * 100.0)

func _effects_text() -> String:
	var b := _body
	var lines: Array[String] = []
	var hunger := b.get_hunger_drain_multiplier()
	var thirst := b.get_thirst_drain_multiplier()
	var cost := b.get_stamina_drain_multiplier()
	var recovery := b.get_stamina_recovery_multiplier()
	var move := b.get_movement_multiplier()
	var damage := b.get_damage_per_hour()
	if _percent(hunger) > 0:
		lines.append("Hunger turun %d%% lebih cepat." % _percent(hunger))
	if _percent(thirst) > 0:
		lines.append("Thirst turun %d%% lebih cepat." % _percent(thirst))
	if _percent(cost) > 0:
		lines.append("Stamina terkuras %d%% lebih banyak saat sprint, berenang, dan melompat." % _percent(cost))
	if _percent(recovery) > 0:
		lines.append("Stamina pulih %d%% lebih lambat." % _percent(recovery))
	if _percent(move) > 0:
		lines.append("Kecepatan gerak turun %d%%." % _percent(move))
	if damage > 0.005:
		lines.append("[color=#ff8a80]Health berkurang %.1f per jam waktu dunia.[/color]" % damage)
	if lines.is_empty():
		return "[color=%s]Tidak ada pengaruh pada suhu ini. Efek mulai muncul di bawah %s °C atau dari %s °C ke atas.[/color]" \
			% [GOOD, TemperatureUI.format_plain(b.cold_below), TemperatureUI.format_plain(b.hot_from)]
	return "\n".join(lines)

## Which activity row is active (same priority BodyTemperature uses for heat production).
func _current_activity() -> String:
	if _survival == null:
		return "rest"
	if _survival.is_swimming():
		return "swim"
	if _survival.is_sprinting():
		return "sprint"
	if _survival.is_moving():
		return "walk"
	return "rest"

func _activity_text() -> String:
	var b := _body
	var active := _current_activity()
	var rows := [
		["rest", "Diam", "+0 W"],
		["walk", "Berjalan", "+%d W" % roundi(b.walking_extra_heat)],
		["sprint", "Berlari", "+%d W" % roundi(b.sprinting_extra_heat)],
		["swim", "Berenang", "+%d W" % roundi(b.swimming_extra_heat)],
	]
	var lines: Array[String] = []
	lines.append("Panas dasar tubuh (selalu): %d W" % roundi(b.basal_heat))
	for row in rows:
		if row[0] == active:
			lines.append("[color=%s]> %s: %s (sedang aktif)[/color]" % [ACTIVE, row[1], row[2]])
		else:
			lines.append("   %s: [color=%s]%s[/color]" % [row[1], MUTED, row[2]])
	lines.append("   Melompat: [color=%s]+%d J sekali per lompatan (sekitar +%.2f °C)[/color]" \
		% [MUTED, roundi(b.jump_heat_joules), b.jump_heat_joules / maxf(b.heat_capacity, 1.0)])
	var production := b.get_heat_production()
	lines.append("Produksi panas sekarang: [b]%d W[/b]" % roundi(production))
	var s := b.get_environment_sample()
	if s.has_sun:
		var activity_heat := 0.0
		match active:
			"walk": activity_heat = b.walking_extra_heat
			"sprint": activity_heat = b.sprinting_extra_heat
			"swim": activity_heat = b.swimming_extra_heat
		var solar := production - b.basal_heat - activity_heat
		if solar > 0.5:
			lines.append("Sinar matahari menambah %d W." % roundi(solar))
	return "\n".join(lines)

func _env_line(label: String, available: bool, value: String) -> String:
	if available:
		return "%s: [color=%s]%s[/color]" % [label, GOOD, value]
	return "%s: [color=%s]belum tersedia[/color]" % [label, MUTED]

func _env_text() -> String:
	var b := _body
	var s := b.get_environment_sample()
	var status := b.get_data_status()
	var water_text := ""
	if s.has_water:
		water_text = "di dalam air, %.1f °C" % s.water_temperature if s.is_in_water else "tidak di dalam air"
	var lines: Array[String] = [
		_env_line("Suhu udara", s.has_air_temperature, "%.1f °C" % s.air_temperature),
		_env_line("Sinar matahari", s.has_sun, "%d%% dari penuh" % roundi(s.sun_intensity * 100.0)),
		_env_line("Angin", s.has_wind, "%.1f m/s" % s.wind_speed),
		_env_line("Kelembapan", s.has_humidity, "%d%%" % roundi(s.humidity * 100.0)),
		_env_line("Air", s.has_water, water_text),
		_env_line("Tempat berlindung", s.has_shelter, "melindungi matahari %d%%, angin %d%%" \
			% [roundi(s.shelter_sun_protection * 100.0), roundi(s.shelter_wind_protection * 100.0)]),
	]
	var missing := 0
	for key in ["air_temperature", "sun", "wind", "humidity", "water", "shelter"]:
		if not status[key]:
			missing += 1
	if missing > 0:
		var intro := "" if status["provider"] else "Dunia ini belum punya sistem cuaca, air, atau tempat berlindung. "
		lines.append("[color=%s]%sData yang belum tersedia tidak dikarang. Perhitungan memakai kondisi netral: udara %d °C, tanpa angin, tanpa sinar matahari, di luar air, tanpa tempat berlindung, kelembapan tidak dihitung.[/color]" \
			% [MUTED, intro, roundi(b.neutral_air_temperature)])
	return "\n".join(lines)

func _cause_text() -> String:
	var b := _body
	var s := b.get_environment_sample()
	var net := b.get_net_power()
	var production := b.get_heat_production()
	var loss := production - net
	var per_hour := net / maxf(b.heat_capacity, 1.0) * 3600.0
	var temperature := b.get_temperature()
	var lines: Array[String] = []
	if absf(net) < STABLE_POWER:
		lines.append("Suhu stabil: panas yang dihasilkan (%d W) seimbang dengan panas yang dilepas (%d W)." \
			% [roundi(production), roundi(loss)])
	elif net > 0.0:
		lines.append("[b]Menghangat[/b] (sekitar %+.2f °C per jam waktu dunia): panas yang dihasilkan (%d W) lebih besar daripada yang dilepas (%d W)." \
			% [per_hour, roundi(production), roundi(loss)])
		if temperature < b.normal_temperature:
			lines.append("Tubuh sedang kembali ke suhu normal %s °C." % TemperatureUI.format_plain(b.normal_temperature))
	else:
		lines.append("[b]Mendingin[/b] (sekitar %+.2f °C per jam waktu dunia): panas yang dilepas (%d W) lebih besar daripada yang dihasilkan (%d W)." \
			% [per_hour, roundi(loss), roundi(production)])
	if temperature > b.normal_temperature and not (s.has_water and s.is_in_water):
		lines.append("Di atas suhu normal tubuh berkeringat untuk membuang kelebihan panas.")
	if s.has_water and s.is_in_water:
		lines.append("Air membuang panas tubuh jauh lebih cepat daripada udara.")
	lines.append("[color=%s]Suhu mengikuti waktu dunia dan tetap berjalan saat panel ini terbuka.[/color]" % MUTED)
	return "\n".join(lines)

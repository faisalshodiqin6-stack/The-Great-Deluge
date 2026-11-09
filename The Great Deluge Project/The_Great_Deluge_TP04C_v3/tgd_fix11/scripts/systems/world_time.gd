extends Node
class_name WorldTime

## Central game clock. Pure logic: no UI, no lighting. Other systems (day/night
## visuals, HUD clock, later sleep / save / offline simulation) read it via the
## "world_time" group or signals.
## 1 game day = 96 real minutes  ->  1 real second = 15 game seconds.
## Time is advanced with delta, so it is frame-rate independent, and it never
## depends on SceneTree pause (UI panels do not stop it).
signal time_changed(hour: int, minute: int)  # Emitted when the game minute changes.
signal day_changed(day: int)

const REAL_SECONDS_PER_DAY: float = 96.0 * 60.0
const GAME_SECONDS_PER_DAY: float = 86400.0
const GAME_SECONDS_PER_REAL_SECOND: float = GAME_SECONDS_PER_DAY / REAL_SECONDS_PER_DAY  # 15.0

## 1.0 = normal. Raise it (e.g. 60.0 for a future sleep mechanic) to speed time up.
@export_range(0.0, 1000.0, 0.1) var time_multiplier: float = 1.0
@export_range(0, 23) var start_hour: int = 8
@export_range(0, 59) var start_minute: int = 0

var day: int = 1
var _seconds: float = 0.0       # Game seconds since 00:00 (0 .. 86400).
var _last_minute: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # The clock keeps running even if the tree is paused.
	add_to_group("world_time")
	_seconds = start_hour * 3600.0 + start_minute * 60.0
	_emit_if_minute_changed()

func _process(delta: float) -> void:
	advance(delta * GAME_SECONDS_PER_REAL_SECOND * time_multiplier)

## Advance the clock by game seconds (wraps past 23:59 back to 00:00).
func advance(game_seconds: float) -> void:
	if game_seconds <= 0.0:
		return
	_seconds += game_seconds
	var days_passed := int(floor(_seconds / GAME_SECONDS_PER_DAY))
	if days_passed > 0:
		_seconds -= days_passed * GAME_SECONDS_PER_DAY
		day += days_passed
		day_changed.emit(day)
	_emit_if_minute_changed()

func set_time(hour: int, minute: int = 0) -> void:
	_seconds = float(posmod(hour, 24)) * 3600.0 + float(clampi(minute, 0, 59)) * 60.0
	_last_minute = -1
	_emit_if_minute_changed()

func set_time_multiplier(value: float) -> void:
	time_multiplier = maxf(value, 0.0)

func get_hour() -> int:
	return int(_seconds / 3600.0) % 24

func get_minute() -> int:
	return int(_seconds / 60.0) % 60

func get_time_string() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]

## Game seconds since 00:00.
func get_seconds_of_day() -> float:
	return _seconds

## 0.0 = 00:00, 0.5 = 12:00, approaching 1.0 = 23:59 (smooth, for visuals).
func get_normalized_time() -> float:
	return _seconds / GAME_SECONDS_PER_DAY

func _emit_if_minute_changed() -> void:
	var minute_of_day := int(_seconds / 60.0)
	if minute_of_day != _last_minute:
		_last_minute = minute_of_day
		time_changed.emit(get_hour(), get_minute())

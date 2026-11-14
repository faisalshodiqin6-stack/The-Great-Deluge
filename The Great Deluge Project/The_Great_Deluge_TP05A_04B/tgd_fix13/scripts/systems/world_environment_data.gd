extends Node
class_name WorldEnvironmentData

## World air temperature (TP-05A-04A, stage 1). Answers one question: "what is the
## air temperature, in °C, at this world position (and time of day)?"
##
## Simple model (all values editable in the Inspector):
##   air = mean + region offset - lapse * altitude + swing * region scale * daily curve
## The daily curve (-1..+1) is smooth: coldest at coldest_hour, warmest at
## warmest_hour, using the in-game hour from WorldTime.
##
## LIMITATIONS (by design, see docs/WORLD_ENVIRONMENT_DATA.md):
##  - Not weather: no wind, humidity, rain, storm, cloud or sun heating.
##  - Region data: none exists in the world yet. Regions are found by a RegionLocator
##    (separate from this formula); with none configured the whole world is one neutral
##    default region. The default locator is the flat X/Z adapter of the prototype.
##  - Altitude: the world has no terrain-height query for outside callers, so altitude is
##    the Y of the queried position above sea_level_y (the caller supplies it).
##  - Values are placeholder base settings, not a final climate design.
## BodyTemperature reads it through WorldAirTemperatureProvider (an EnvironmentProvider).

@export_group("Base temperature (°C)")
## Daily mean air temperature at sea level in the default region. Default equals the
## neutral air temperature used by BodyTemperature.
@export var mean_temperature: float = 25.0
## Half of the day/night difference: air swings between mean-swing and mean+swing.
@export var daily_swing: float = 5.0
@export_range(0.0, 24.0) var coldest_hour: float = 5.0
@export_range(0.0, 24.0) var warmest_hour: float = 15.0

@export_group("Altitude")
## Y coordinate that counts as sea level.
@export var sea_level_y: float = 0.0
## Cooling per 100 m of altitude (real air: about 0.65).
@export var lapse_rate_per_100m: float = 0.65
## Altitude is limited to 0..this (below sea level = 0) so odd positions cannot give extreme values.
@export var max_altitude: float = 5000.0

@export_group("Regions (optional)")
## How regions are found. Empty = a PlanarRegionLocator without areas (neutral world).
## The temperature formula below never depends on how this works.
@export var region_locator: RegionLocator

@export_group("Safety limits (°C)")
@export var min_air_temperature: float = -60.0
@export var max_air_temperature: float = 60.0

var _time: WorldTime = null

func _ready() -> void:
	add_to_group("world_environment_data")
	if region_locator == null:
		region_locator = PlanarRegionLocator.new()

# ---- Public API -----------------------------------------------------------
## Air temperature (°C) at a world position. hour < 0 = current WorldTime hour;
## if WorldTime is missing, the daily mean (no day/night swing) is used.
func get_air_temperature_at(world_position: Vector3, hour: float = -1.0) -> float:
	var region := get_region_at(world_position)
	var offset := region.temperature_offset if region else 0.0
	var swing_scale := region.swing_scale if region else 1.0
	var altitude := clampf(world_position.y - sea_level_y, 0.0, maxf(max_altitude, 0.0))
	var temperature := mean_temperature + offset - lapse_rate_per_100m * altitude / 100.0
	var current_hour := hour if hour >= 0.0 else _current_hour()
	if current_hour >= 0.0:
		temperature += daily_swing * swing_scale * _daily_curve(current_hour)
	return _sanitize(temperature)

## Same, at a specific in-game hour (0..24), e.g. for previews or tests.
func get_air_temperature_at_hour(world_position: Vector3, hour: float) -> float:
	return get_air_temperature_at(world_position, clampf(hour, 0.0, 24.0))

## The region containing the position, or null (= default region).
func get_region_at(world_position: Vector3) -> TemperatureRegion:
	return region_locator.find_region(world_position) if region_locator else null

## What is real and what is a neutral stand-in right now.
func get_data_status() -> Dictionary:
	return {
		"time_of_day": _current_hour() >= 0.0,   # false: daily mean used, no swing.
		"regions": region_locator != null and region_locator.has_regions(),  # false: neutral default.
		"region_locator": region_locator.get_description() if region_locator else "none",
		"altitude": "world Y above sea_level_y (no terrain-height lookup yet)",
		"weather": false,                        # Not part of this system.
	}

# ---- Internals ------------------------------------------------------------
## In-game hour 0..24, or -1.0 when WorldTime does not exist.
func _current_hour() -> float:
	if _time == null:
		_time = get_tree().get_first_node_in_group("world_time") as WorldTime
		if _time == null:
			return -1.0
	return _time.get_seconds_of_day() / 3600.0

## -1 at coldest_hour, +1 at warmest_hour, cosine-eased between (asymmetric day).
func _daily_curve(hour: float) -> float:
	var cold := fposmod(coldest_hour, 24.0)
	var warm := fposmod(warmest_hour, 24.0)
	var h := fposmod(hour, 24.0)
	var rise := fposmod(warm - cold, 24.0)
	var fall := 24.0 - rise
	if rise < 0.001 or fall < 0.001:
		return 0.0  # Degenerate settings: no swing instead of a division by zero.
	var since_cold := fposmod(h - cold, 24.0)
	if since_cold <= rise:
		return -cos(PI * since_cold / rise)
	return cos(PI * (since_cold - rise) / fall)

func _sanitize(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return clampf(mean_temperature, min_air_temperature, max_air_temperature) if not (is_nan(mean_temperature) or is_inf(mean_temperature)) else 25.0
	return clampf(value, min_air_temperature, max_air_temperature)

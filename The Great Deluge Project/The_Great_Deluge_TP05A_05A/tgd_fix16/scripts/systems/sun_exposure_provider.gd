extends EnvironmentProvider
class_name SunExposureProvider

## Sun exposure data (TP-05A-04D, stage 1). It creates no sun cycle: it reads the
## DirectionalLight3D that DayNightCycle already moves every frame (the node at
## DayNightCycle.sun_path), so elevation is the REAL current sun, not a guess from
## the clock. The light shines along its local -Z, so the direction toward the sun
## is its global +Z axis (the same vector DayNightCycle gives SkyRig).
##
## Data (query with the methods below):
##   is_data_available()        false when DayNightCycle / the sun light is missing.
##   is_sun_above_horizon()     elevation > 0 (the disc is clipped at the same plane).
##   get_sun_elevation_degrees()  -90..90, negative = below the horizon.
##   get_sun_intensity()        0..1: sin(elevation) / sin(sun_max_elevation), so the
##                              daily peak is 1.0; 0 at and below the horizon; times
##                              (1 - cloud_attenuation) * weather_light_multiplier, the
##                              hooks DayNightCycle already has (neutral 0 / 1 today).
## When unavailable every getter returns 0 / false: never an invented value.
##
## Not part of this stage: shelter, clouds, damage from the sun. BodyTemperature
## has a solar-gain term (solar_gain_full_sun) that reads EnvironmentSample; since
## TP-05A-04E this provider feeds it (publish_to_environment_sample is on).

@export var day_night_cycle_path: NodePath = NodePath("../DayNightCycle")
## On (TP-05A-04E): fill_sample() writes the data into the EnvironmentSample (has_sun,
## sun_intensity, sun_elevation_deg, sun_above_horizon), which BodyTemperature reads.
## Off: data only through this node's methods and the player gets no solar heat.
@export var publish_to_environment_sample: bool = true

var _cycle: DayNightCycle = null
var _sun: DirectionalLight3D = null
var _available := false
var _elevation := 0.0
var _above := false
var _intensity := 0.0

func is_data_available() -> bool:
	_refresh()
	return _available

func is_sun_above_horizon() -> bool:
	_refresh()
	return _above

func get_sun_elevation_degrees() -> float:
	_refresh()
	return _elevation

func get_sun_intensity() -> float:
	_refresh()
	return _intensity

func fill_sample(sample: EnvironmentSample) -> void:
	if not publish_to_environment_sample:
		return
	_refresh()
	if not _available:
		return  # Flags stay false: "unavailable", not zero sun.
	sample.has_sun = true
	sample.sun_intensity = _intensity
	sample.sun_elevation_deg = _elevation
	sample.sun_above_horizon = _above

## Reads the live sun light. Cheap (one normalize, one asin); callers may call often.
func _refresh() -> void:
	_available = false
	_elevation = 0.0
	_above = false
	_intensity = 0.0
	if _cycle == null or not is_instance_valid(_cycle):
		_cycle = get_node_or_null(day_night_cycle_path) as DayNightCycle
	if _cycle == null:
		return
	if _sun == null or not is_instance_valid(_sun):
		_sun = _cycle.get_node_or_null(_cycle.sun_path) as DirectionalLight3D
	if _sun == null or not _sun.is_inside_tree():
		return
	var toward := _sun.global_transform.basis.z
	if toward.length_squared() < 1e-6:
		return
	toward = toward.normalized()
	var elevation := rad_to_deg(asin(clampf(toward.y, -1.0, 1.0)))
	if is_nan(elevation):
		return
	_available = true
	_elevation = elevation
	_above = elevation > 0.0
	if not _above:
		return
	var reference := 90.0
	if _cycle.config:
		reference = clampf(_cycle.config.sun_max_elevation, 1.0, 90.0)
	var direct := clampf(sin(deg_to_rad(elevation)) / sin(deg_to_rad(reference)), 0.0, 1.0)
	var attenuation := clampf((1.0 - _cycle.cloud_attenuation) * _cycle.weather_light_multiplier, 0.0, 1.0)
	_intensity = clampf(direct * attenuation, 0.0, 1.0)

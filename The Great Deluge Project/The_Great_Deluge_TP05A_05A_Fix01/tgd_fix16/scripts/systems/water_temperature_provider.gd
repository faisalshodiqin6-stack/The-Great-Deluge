extends EnvironmentProvider
class_name WaterTemperatureProvider

## Water temperature as an EnvironmentProvider (TP-05A-05A, foundation). Asks
## WaterTemperatureData about the player's body sample point and publishes the answer into
## the EnvironmentSample's water_profile_* fields. It calculates nothing itself.
##
## It writes ONLY the has_water_profile / water_profile_* fields. It does NOT touch
## has_water, is_in_water or water_temperature (the fields BodyTemperature reads), nor air,
## sun, wind, humidity or shelter, and never calls sample.reset(). So BodyTemperature
## behaves exactly as before until a later stage maps the profile to those fields.
##
## The sample point is the player's origin (feet) + sample_height_offset (default 0.9 m =
## the middle of the capsule). The player is "in water" when that point is at or below the
## water surface and not underground. If it is not confirmed, nothing is filled and the
## data stays "unavailable".

@export var data_path: NodePath = NodePath("../WaterTemperatureData")
@export var player_path: NodePath = NodePath("../Player")
## Height above the player's origin of the point that is tested for immersion (m).
@export var sample_height_offset: float = 0.9
## On: fill_sample() writes the water_profile_* fields. Off: data only through this node's getters.
@export var publish_to_environment_sample: bool = true

var _data: WaterTemperatureData = null
var _player: Node3D = null
var _reading := WaterTemperatureReading.new()

func is_data_available() -> bool:
	_refresh()
	return _reading.available

func get_water_temperature() -> float:
	_refresh()
	return _reading.temperature

## Meters below the water surface (0 = at the surface). 0 when unavailable.
func get_water_depth() -> float:
	_refresh()
	return _reading.depth

func get_region_id() -> StringName:
	_refresh()
	return _reading.region_id

func get_region_name() -> String:
	_refresh()
	return _reading.region_name

## Why the data is (un)available, for debugging / UI.
func get_status_reason() -> String:
	_refresh()
	return _reading.reason

func fill_sample(sample: EnvironmentSample) -> void:
	if not publish_to_environment_sample:
		return
	_refresh()
	if not _reading.available:
		return  # Flag stays false: "unavailable", not 0 °C.
	sample.has_water_profile = true
	sample.water_profile_temperature = _reading.temperature
	sample.water_profile_depth = _reading.depth
	sample.water_profile_region_id = _reading.region_id
	sample.water_profile_region_name = _reading.region_name

func _refresh() -> void:
	_reading.clear()
	if _data == null or not is_instance_valid(_data):
		_data = get_node_or_null(data_path) as WaterTemperatureData
		if _data == null:
			_data = get_tree().get_first_node_in_group("water_temperature_data") as WaterTemperatureData
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node3D
	if _data == null:
		_reading.reason = "no WaterTemperatureData"
		return
	if _player == null:
		_reading.reason = "no player"
		return
	var point := _player.global_position + Vector3(0.0, sample_height_offset, 0.0)
	_data.query_at(point, _reading)

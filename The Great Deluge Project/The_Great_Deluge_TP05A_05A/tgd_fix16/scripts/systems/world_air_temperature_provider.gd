extends EnvironmentProvider
class_name WorldAirTemperatureProvider

## The EnvironmentProvider that BodyTemperature already looks up (group
## "environment_provider"). It only forwards what WorldEnvironmentData computes for
## the player's position and the current world time into the EnvironmentSample's
## air temperature. No temperature is calculated here.
## Everything else (sun, wind, humidity, water, shelter) is NOT touched, so those
## flags stay false ("unavailable") until real systems fill them.
## If the data node or the player cannot be found, nothing is filled and air
## temperature stays "unavailable" (BodyTemperature then uses its neutral stand-in).

@export var data_path: NodePath = NodePath("../WorldEnvironmentData")
@export var player_path: NodePath = NodePath("../Player")

var _data: WorldEnvironmentData = null
var _player: Node3D = null

func fill_sample(sample: EnvironmentSample) -> void:
	if _data == null:
		_data = get_node_or_null(data_path) as WorldEnvironmentData
		if _data == null:
			_data = get_tree().get_first_node_in_group("world_environment_data") as WorldEnvironmentData
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
	if _data == null or _player == null or not is_instance_valid(_player):
		return
	var temperature := _data.get_air_temperature_at(_player.global_position)
	if is_nan(temperature) or is_inf(temperature):
		return
	sample.air_temperature = temperature
	sample.has_air_temperature = true

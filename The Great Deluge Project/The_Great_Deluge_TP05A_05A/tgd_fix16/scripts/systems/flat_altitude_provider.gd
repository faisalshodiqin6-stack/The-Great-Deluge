extends AltitudeProvider
class_name FlatAltitudeProvider

## Temporary provider for the CURRENT flat prototype world: altitude is the Y
## coordinate above sea_level_y (the former WorldEnvironmentData.sea_level_y).
## It does not read terrain height, it measures the height of the queried point itself.
@export var sea_level_y: float = 0.0

func get_altitude(world_position: Vector3) -> float:
	return world_position.y - sea_level_y

func get_description() -> String:
	return "flat world: Y - sea_level_y (prototype)"

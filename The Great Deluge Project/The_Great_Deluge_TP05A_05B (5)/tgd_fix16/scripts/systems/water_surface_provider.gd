extends Resource
class_name WaterSurfaceProvider

## Interface: "is this world position inside water, and how deep below the surface?".
## The only place that knows where water exists and how its surface is shaped. The water
## temperature formula (WaterTemperatureData) only calls get_water_depth(); it never reads
## coordinates itself, so a new water source (lakes, rivers, a round-planet ocean) needs a
## new subclass only.
##
## Contract for subclasses:
##  - Return the depth in meters BELOW the water surface (0 = exactly at the surface,
##    positive = under it).
##  - Return NAN when the position is NOT confirmed to be inside water: no water body
##    there, above the surface, underground, or not enough information. Never guess.
##  - `ground_height` is the world Y of the solid ground under the position, or NAN when
##    unknown. The caller supplies it (a resource cannot reach scene nodes).
##  - Cheap, allocation-free, tolerant of any position (never crash, never return inf).

## Override.
func get_water_depth(_world_position: Vector3, _ground_height: float) -> float:
	return NAN

## Override: short text for get_data_status().
func get_description() -> String:
	return "no water surface provider"

extends Resource
class_name AltitudeProvider

## Interface: "how high above the reference sea surface is this world position?".
## The only place that knows the shape of the world. The air-temperature formula
## (WorldEnvironmentData) only calls get_altitude() and applies the lapse rate; it
## never reads coordinates itself, so a new world shape needs a new provider only.
##
## Contract for subclasses:
##  - Return meters above the reference sea surface; below it is NEGATIVE
##    (the consumer decides how to treat negative values).
##  - Cheap, allocation-free, tolerant of any position (never crash).
##
## Future round planet (NOT built yet): a provider holding a planet center
## (Vector3) and a reference radius (m, sea level):
##   altitude = world_position.distance_to(center) - reference_radius
## Position at the center is a legal input (altitude = -radius).

## Override.
func get_altitude(_world_position: Vector3) -> float:
	return 0.0

## Override: short text for get_data_status().
func get_description() -> String:
	return "no altitude provider"

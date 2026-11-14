extends RefCounted
class_name WaterTemperatureReading

## Result of one WaterTemperatureData query. One reusable object, filled in place
## (no allocation per tick). `available` false = the position is not confirmed to be in
## water (or the data is invalid): every other field is then a neutral 0 / empty value and
## must not be used. `reason` says why, for debugging and UI only.
var available := false
var temperature := 0.0              # °C, meaningful only if available
var depth := 0.0                    # m below the water surface (0 = at the surface), only if available
var region_id: StringName = &""     # &"" = default region (no TemperatureRegion covers the position)
var region_name := ""
var reason := "not queried"

func clear(new_reason: String = "not queried") -> void:
	available = false
	temperature = 0.0
	depth = 0.0
	region_id = &""
	region_name = ""
	reason = new_reason

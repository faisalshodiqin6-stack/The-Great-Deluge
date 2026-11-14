extends RefCounted
class_name EnvironmentSample

## One snapshot of the environment around the player. Each value has a has_* flag:
## false = the data source does not exist yet, so consumers must use a NEUTRAL
## condition instead of a made-up number. A provider fills one reusable sample
## (no allocation per tick).
var has_air_temperature := false
var air_temperature := 0.0        # °C
## A provider that sets has_sun MUST also set sun_above_horizon: BodyTemperature adds no
## solar heat unless the sun is above the horizon.
var has_sun := false
var sun_intensity := 0.0          # 0 = none / night, 1 = full direct sun
var sun_elevation_deg := 0.0      # -90..90, negative = below the horizon
var sun_above_horizon := false
var has_wind := false
var wind_speed := 0.0             # m/s
var has_humidity := false
var humidity := 0.0               # 0..1
var has_water := false
var is_in_water := false          # Body immersed in water.
var water_temperature := 0.0      # °C, meaningful only if is_in_water
## Water profile (TP-05A-05A): filled by WaterTemperatureProvider, NOT read by BodyTemperature yet
## (it still reads has_water / is_in_water / water_temperature above). When has_water_profile is
## true the position is confirmed to be in water and the three values below are valid.
var has_water_profile := false
var water_profile_temperature := 0.0   # °C at the player's depth
var water_profile_depth := 0.0         # m below the water surface (0 = at the surface)
var water_profile_region_id: StringName = &""   # &"" = default region
var water_profile_region_name := ""
var has_shelter := false
var shelter_sun_protection := 0.0   # 0..1 share of sun blocked
var shelter_wind_protection := 0.0  # 0..1 share of wind blocked

func reset() -> void:
	has_air_temperature = false
	air_temperature = 0.0
	has_sun = false
	sun_intensity = 0.0
	sun_elevation_deg = 0.0
	sun_above_horizon = false
	has_wind = false
	wind_speed = 0.0
	has_humidity = false
	humidity = 0.0
	has_water = false
	is_in_water = false
	water_temperature = 0.0
	has_water_profile = false
	water_profile_temperature = 0.0
	water_profile_depth = 0.0
	water_profile_region_id = &""
	water_profile_region_name = ""
	has_shelter = false
	shelter_sun_protection = 0.0
	shelter_wind_protection = 0.0

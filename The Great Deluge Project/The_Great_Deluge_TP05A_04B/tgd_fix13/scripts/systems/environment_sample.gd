extends RefCounted
class_name EnvironmentSample

## One snapshot of the environment around the player. Each value has a has_* flag:
## false = the data source does not exist yet, so consumers must use a NEUTRAL
## condition instead of a made-up number. A provider fills one reusable sample
## (no allocation per tick).
var has_air_temperature := false
var air_temperature := 0.0        # °C
var has_sun := false
var sun_intensity := 0.0          # 0 = none / night, 1 = full direct sun
var has_wind := false
var wind_speed := 0.0             # m/s
var has_humidity := false
var humidity := 0.0               # 0..1
var has_water := false
var is_in_water := false          # Body immersed in water.
var water_temperature := 0.0      # °C, meaningful only if is_in_water
var has_shelter := false
var shelter_sun_protection := 0.0   # 0..1 share of sun blocked
var shelter_wind_protection := 0.0  # 0..1 share of wind blocked

func reset() -> void:
	has_air_temperature = false
	air_temperature = 0.0
	has_sun = false
	sun_intensity = 0.0
	has_wind = false
	wind_speed = 0.0
	has_humidity = false
	humidity = 0.0
	has_water = false
	is_in_water = false
	water_temperature = 0.0
	has_shelter = false
	shelter_sun_protection = 0.0
	shelter_wind_protection = 0.0

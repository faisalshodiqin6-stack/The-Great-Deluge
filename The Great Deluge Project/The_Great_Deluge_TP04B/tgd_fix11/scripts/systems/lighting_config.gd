extends Resource
class_name LightingConfig

## Central tunable lighting values (edit in the Inspector on the DayNightCycle
## node's "config"). Night look = ambient baseline + moonlight, kept separate.

@export_group("Ambient baseline (night)")
@export var night_ambient_color: Color = Color(0.28, 0.34, 0.5)
@export var night_ambient_energy: float = 0.45
## How much sky color contributes to ambient at night / by day (day = original 0.65).
@export_range(0.0, 1.0) var night_sky_contribution: float = 0.2
@export_range(0.0, 1.0) var day_sky_contribution: float = 0.65

@export_group("Moonlight (separate from ambient)")
@export var moonlight_color: Color = Color(0.6, 0.7, 1.0)
@export var moonlight_energy: float = 0.15
@export_range(0.0, 1.0) var moon_disc_alpha: float = 1.0

@export_group("Sun")
@export var sun_max_elevation: float = 65.0
@export var sun_base_yaw: float = -28.0

@export_group("Stars")
@export_range(0.0, 1.0) var star_max_alpha: float = 0.85

@export_group("Fog")
@export var fog_enabled: bool = true
## Multiplies the time-of-day fog density curve (0 = no fog).
@export var fog_density_scale: float = 1.0

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

@export_group("Celestial apparent size (real-world angular diameters)")
@export_range(0.05, 5.0) var sun_angular_diameter_deg: float = 0.53
@export_range(0.05, 5.0) var moon_angular_diameter_deg: float = 0.52
## 1.0 = real size. Raise only for artistic emphasis (applies to sun and moon equally).
@export_range(0.5, 6.0) var celestial_size_multiplier: float = 1.0

@export_group("Sun disc colors (independent of light energy)")
@export var sun_dawn_horizon: Color = Color(1.0, 0.72, 0.32)   # golden-orange
@export var sun_dawn_mid: Color = Color(1.0, 0.85, 0.50)
@export var sun_dusk_horizon: Color = Color(1.0, 0.40, 0.15)   # orange-red
@export var sun_dusk_mid: Color = Color(1.0, 0.68, 0.32)
@export var sun_noon: Color = Color(1.0, 0.96, 0.82)           # pale yellow-white
@export_range(0.0, 1.0) var sun_glow_strength: float = 0.30
@export_range(0.0, 1.0) var moon_glow_strength: float = 0.10

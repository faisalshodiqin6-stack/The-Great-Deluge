extends Node
class_name DayNightCycle

## Visual day/night driven ONLY by WorldTime.get_normalized_time(): sun, moon,
## stars, sky colors, ambient, fog. It owns no clock.
##
## Lighting model (all tunables live in LightingConfig, not in this code):
##   ambient   = blend(sky-lit day ambient, config night baseline)   [night_factor]
##   sunlight  = key energy * horizon fade * (1 - cloud) * weather
##   moonlight = config.moonlight_energy * horizon fade * night_factor * (1 - cloud) * weather
##   fog       = density curve * config scale * atmosphere multiplier
## cloud_attenuation / atmosphere_multiplier / weather_light_multiplier are
## runtime hooks for future cloud, atmosphere and weather systems (no weather yet).
@export var sun_path: NodePath
@export var moon_light_path: NodePath
@export var environment_path: NodePath
@export var sky_rig_path: NodePath
@export var config: LightingConfig
## Sky/ambient/fog refresh interval (seconds). A changing sky makes the engine
## regenerate ambient lighting, which is costly on mobile.
@export var environment_update_interval: float = 0.2
## Skip environment updates while the day fraction changed less than this.
@export var environment_min_time_step: float = 0.0004

@export_group("Future hooks (0 / 1 = no effect)")
@export_range(0.0, 1.0) var cloud_attenuation: float = 0.0
@export_range(0.0, 4.0) var atmosphere_multiplier: float = 1.0
@export_range(0.0, 1.0) var weather_light_multiplier: float = 1.0

## Keyframes over the day (t: 0 = 00:00, 0.5 = 12:00), blended with smoothstep.
## night = 0 (full day) .. 1 (full night); drives ambient baseline, stars, moon.
## ambient_energy applies to the sky-lit part (twilight is intentionally brighter
## than the night baseline so night reads darker than dusk).
const KEYS := [
	{"t": 0.00, "night": 1.0, "sun_color": Color(0.6, 0.7, 1.0), "sun_energy": 0.0, "ambient_energy": 0.9,
		"sky_top": Color(0.02, 0.03, 0.09), "sky_horizon": Color(0.05, 0.07, 0.15),
		"ground_horizon": Color(0.05, 0.06, 0.10), "ground_bottom": Color(0.02, 0.02, 0.04)},
	{"t": 0.20, "night": 1.0, "sun_color": Color(0.6, 0.7, 1.0), "sun_energy": 0.0, "ambient_energy": 0.9,
		"sky_top": Color(0.02, 0.03, 0.09), "sky_horizon": Color(0.05, 0.07, 0.15),
		"ground_horizon": Color(0.05, 0.06, 0.10), "ground_bottom": Color(0.02, 0.02, 0.04)},
	{"t": 0.26, "night": 0.45, "sun_color": Color(1.0, 0.6, 0.4), "sun_energy": 0.35, "ambient_energy": 0.9,
		"sky_top": Color(0.15, 0.20, 0.40), "sky_horizon": Color(0.90, 0.55, 0.40),
		"ground_horizon": Color(0.60, 0.45, 0.40), "ground_bottom": Color(0.10, 0.10, 0.12)},
	{"t": 0.33, "night": 0.0, "sun_color": Color(1.0, 0.88, 0.72), "sun_energy": 1.0, "ambient_energy": 0.65,
		"sky_top": Color(0.16, 0.38, 0.65), "sky_horizon": Color(0.70, 0.80, 0.88),
		"ground_horizon": Color(0.58, 0.63, 0.68), "ground_bottom": Color(0.12, 0.16, 0.20)},
	{"t": 0.50, "night": 0.0, "sun_color": Color(1.0, 0.91, 0.78), "sun_energy": 1.25, "ambient_energy": 0.7,
		"sky_top": Color(0.16, 0.39, 0.66), "sky_horizon": Color(0.68, 0.82, 0.91),
		"ground_horizon": Color(0.58, 0.63, 0.68), "ground_bottom": Color(0.12, 0.16, 0.20)},
	{"t": 0.67, "night": 0.0, "sun_color": Color(1.0, 0.90, 0.75), "sun_energy": 1.05, "ambient_energy": 0.68,
		"sky_top": Color(0.17, 0.38, 0.64), "sky_horizon": Color(0.72, 0.80, 0.85),
		"ground_horizon": Color(0.58, 0.62, 0.66), "ground_bottom": Color(0.12, 0.16, 0.20)},
	{"t": 0.75, "night": 0.1, "sun_color": Color(1.0, 0.50, 0.25), "sun_energy": 0.5, "ambient_energy": 0.9,
		"sky_top": Color(0.20, 0.22, 0.42), "sky_horizon": Color(0.95, 0.50, 0.30),
		"ground_horizon": Color(0.65, 0.42, 0.35), "ground_bottom": Color(0.10, 0.10, 0.12)},
	{"t": 0.80, "night": 0.55, "sun_color": Color(0.7, 0.4, 0.5), "sun_energy": 0.1, "ambient_energy": 1.6,
		"sky_top": Color(0.07, 0.08, 0.20), "sky_horizon": Color(0.35, 0.25, 0.35),
		"ground_horizon": Color(0.20, 0.18, 0.25), "ground_bottom": Color(0.04, 0.04, 0.07)},
	{"t": 0.87, "night": 1.0, "sun_color": Color(0.6, 0.7, 1.0), "sun_energy": 0.0, "ambient_energy": 0.9,
		"sky_top": Color(0.02, 0.03, 0.09), "sky_horizon": Color(0.05, 0.07, 0.15),
		"ground_horizon": Color(0.05, 0.06, 0.10), "ground_bottom": Color(0.02, 0.02, 0.04)},
	{"t": 1.00, "night": 1.0, "sun_color": Color(0.6, 0.7, 1.0), "sun_energy": 0.0, "ambient_energy": 0.9,
		"sky_top": Color(0.02, 0.03, 0.09), "sky_horizon": Color(0.05, 0.07, 0.15),
		"ground_horizon": Color(0.05, 0.06, 0.10), "ground_bottom": Color(0.02, 0.02, 0.04)},
]

## Fog density over the day: thin mist at dawn and night, nearly clear at midday.
const FOG_KEYS := [
	[0.00, 0.0020], [0.20, 0.0020], [0.26, 0.0025], [0.33, 0.0018], [0.42, 0.0003],
	[0.67, 0.0003], [0.75, 0.0006], [0.80, 0.0012], [0.87, 0.0018], [1.00, 0.0020],
]

@onready var _sun: DirectionalLight3D = get_node_or_null(sun_path) as DirectionalLight3D
@onready var _moon_light: DirectionalLight3D = get_node_or_null(moon_light_path) as DirectionalLight3D
@onready var _world_environment: WorldEnvironment = get_node_or_null(environment_path) as WorldEnvironment
@onready var _sky_rig: SkyRig = get_node_or_null(sky_rig_path) as SkyRig

var _time: WorldTime = null
var _env_timer: float = 1000.0
var _last_env_t: float = -1.0

func _ready() -> void:
	if config == null:
		config = LightingConfig.new()
	# The sun disc is drawn by SkyRig with its own color. The light must not also
	# paint the procedural sky's disc, whose brightness is light color * energy
	# (that is what made the disc go dark when the light was dimmed near the horizon).
	if _sun:
		_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY

func _process(delta: float) -> void:
	if _time == null:
		_time = get_tree().get_first_node_in_group("world_time") as WorldTime
		if _time == null:
			return
	var t := _time.get_normalized_time()
	var state := _sample(t)
	var night: float = state["night"]

	# Sun path: true elevation, so it really sets below the horizon at night.
	var sun_elevation := sin((t - 0.25) * TAU) * config.sun_max_elevation
	var yaw := config.sun_base_yaw + (t - 0.5) * 360.0
	var sun_basis := Basis.from_euler(Vector3(deg_to_rad(-sun_elevation), deg_to_rad(yaw), 0.0))
	var sky_attenuation := (1.0 - cloud_attenuation) * weather_light_multiplier
	_update_sun(sun_basis, sun_elevation, state, sky_attenuation)
	if _sky_rig:
		_sky_rig.set_angular_sizes(config.sun_angular_diameter_deg, config.moon_angular_diameter_deg, config.celestial_size_multiplier)
		_update_sun_disc(sun_basis.z, sun_elevation, t)

	# The moon is opposite the sun; it rises as the sun sets.
	var moon_elevation := -sun_elevation
	var moon_direction := -sun_basis.z  # unit vector from viewer toward the moon
	_update_moon(moon_direction, moon_elevation, night, sky_attenuation)
	if _sky_rig:
		_sky_rig.set_sky_rotation(t)

	_env_timer += delta
	if _env_timer >= environment_update_interval and absf(t - _last_env_t) >= environment_min_time_step:
		_env_timer = 0.0
		_last_env_t = t
		_update_environment(t, state, night)

func _update_sun(sun_basis: Basis, elevation: float, state: Dictionary, attenuation: float) -> void:
	if _sun == null:
		return
	_sun.basis = sun_basis
	var energy: float = state["sun_energy"] * smoothstep(-4.0, 5.0, elevation) * attenuation
	_sun.light_color = state["sun_color"]
	_sun.light_energy = energy
	_sun.visible = energy > 0.005  # Below the horizon it casts no light.

## Sun disc: color by elevation (and dawn vs dusk), full brightness, visible only
## while above the horizon (it sinks below it, clipped by the shader).
func _update_sun_disc(direction: Vector3, elevation: float, t: float) -> void:
	var morning := t < 0.5
	var horizon_color := config.sun_dawn_horizon if morning else config.sun_dusk_horizon
	var mid_color := config.sun_dawn_mid if morning else config.sun_dusk_mid
	var color: Color
	if elevation < 8.0:
		color = horizon_color.lerp(mid_color, smoothstep(0.0, 8.0, elevation))
	else:
		color = mid_color.lerp(config.sun_noon, smoothstep(8.0, 30.0, elevation))
	var alpha := smoothstep(-1.5, -0.5, elevation) * (1.0 - 0.8 * cloud_attenuation)
	_sky_rig.set_sun(direction, color, alpha, config.sun_glow_strength)

func _update_moon(direction: Vector3, elevation: float, night: float, attenuation: float) -> void:
	var horizon_fade := smoothstep(-3.0, 10.0, elevation)
	if _sky_rig:
		var disc_alpha := smoothstep(-1.5, -0.5, elevation) * (0.3 + 0.7 * night) * config.moon_disc_alpha * (1.0 - 0.8 * cloud_attenuation)
		_sky_rig.set_moon(direction, disc_alpha, config.moon_glow_strength)
		_sky_rig.set_stars(smoothstep(0.35, 0.95, night) * config.star_max_alpha * (1.0 - cloud_attenuation))
	if _moon_light:
		var energy := config.moonlight_energy * horizon_fade * night * attenuation
		_moon_light.light_color = config.moonlight_color
		_moon_light.light_energy = energy
		_moon_light.visible = energy > 0.005
		if _moon_light.visible:
			# The light travels from the moon toward the ground.
			_moon_light.basis = Basis.looking_at(-direction, Vector3.UP)

func _update_environment(t: float, state: Dictionary, night: float) -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	var environment := _world_environment.environment
	# Ambient: sky-lit part blends into the configurable night baseline.
	environment.ambient_light_color = Color(0, 0, 0).lerp(config.night_ambient_color, night)
	environment.ambient_light_sky_contribution = lerpf(config.day_sky_contribution, config.night_sky_contribution, night)
	environment.ambient_light_energy = lerpf(state["ambient_energy"], config.night_ambient_energy, night)
	if environment.sky and environment.sky.sky_material is ProceduralSkyMaterial:
		var sky := environment.sky.sky_material as ProceduralSkyMaterial
		sky.sky_top_color = state["sky_top"]
		sky.sky_horizon_color = state["sky_horizon"]
		sky.ground_horizon_color = state["ground_horizon"]
		sky.ground_bottom_color = state["ground_bottom"]
	environment.fog_enabled = config.fog_enabled
	if config.fog_enabled:
		environment.fog_light_color = state["sky_horizon"]
		environment.fog_sky_affect = 0.0
		environment.fog_density = _sample_fog(t) * config.fog_density_scale * atmosphere_multiplier

func _sample_fog(t: float) -> float:
	var index := 0
	while index < FOG_KEYS.size() - 2 and t >= FOG_KEYS[index + 1][0]:
		index += 1
	var a: Array = FOG_KEYS[index]
	var b: Array = FOG_KEYS[index + 1]
	var f := clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	return lerpf(a[1], b[1], f * f * (3.0 - 2.0 * f))

## Blend the two surrounding keyframes with smoothstep easing.
func _sample(t: float) -> Dictionary:
	var index := 0
	while index < KEYS.size() - 2 and t >= KEYS[index + 1]["t"]:
		index += 1
	var a: Dictionary = KEYS[index]
	var b: Dictionary = KEYS[index + 1]
	var f := clampf((t - a["t"]) / (b["t"] - a["t"]), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var result := {}
	for key in a:
		if key != "t":
			result[key] = lerp(a[key], b[key], f)
	return result

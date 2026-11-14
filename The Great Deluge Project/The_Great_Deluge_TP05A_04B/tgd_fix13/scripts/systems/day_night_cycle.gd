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
## How often the environment is evaluated (seconds). Applying a changed sky makes
## the engine regenerate ambient lighting, which is costly on mobile.
@export var environment_update_interval: float = 0.2
## An evaluated environment is applied only if some value (sky/ambient color
## channel, ambient energy, or fog density relative to 2%) moved by at least this.
## 0.0015 is below half of one 8-bit color step (0.0039), so the steps are not
## visible, yet static periods (midday, deep night) cost nothing. Unlike a
## time-based threshold, this adapts to how fast the colors are really changing.
@export var environment_change_threshold: float = 0.0015

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

const STATE_RESAMPLE_STEP := 0.00002   # Re-blend keyframes only after ~1.7 game seconds.
const ENV_COLOR_KEYS := ["sky_top", "sky_horizon", "ground_horizon", "ground_bottom", "ambient_color"]

@onready var _sun: DirectionalLight3D = get_node_or_null(sun_path) as DirectionalLight3D
@onready var _moon_light: DirectionalLight3D = get_node_or_null(moon_light_path) as DirectionalLight3D
@onready var _world_environment: WorldEnvironment = get_node_or_null(environment_path) as WorldEnvironment
@onready var _sky_rig: SkyRig = get_node_or_null(sky_rig_path) as SkyRig

var _time: WorldTime = null
var _env_timer: float = 1000.0
var _state: Dictionary = {}       # Cached keyframe blend for _state_t.
var _state_t: float = -1.0
var _target: Dictionary = {}      # Environment values wanted now (reused, no per-tick allocation).
var _applied: Dictionary = {}     # Values last applied to the Environment.

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
	if _state.is_empty() or absf(t - _state_t) >= STATE_RESAMPLE_STEP:
		_state = _sample(t)
		_state_t = t
	var night: float = _state["night"]

	# Every frame (cheap): true sun elevation, so it really sets below the horizon.
	var sun_elevation := sin((t - 0.25) * TAU) * config.sun_max_elevation
	var yaw := config.sun_base_yaw + (t - 0.5) * 360.0
	var sun_basis := Basis.from_euler(Vector3(deg_to_rad(-sun_elevation), deg_to_rad(yaw), 0.0))
	var attenuation := (1.0 - cloud_attenuation) * weather_light_multiplier
	_update_sun_light(sun_basis, sun_elevation, attenuation)
	# The moon is opposite the sun; it rises as the sun sets.
	var moon_elevation := -sun_elevation
	var moon_direction := -sun_basis.z  # Unit vector from viewer toward the moon.
	_update_moon_light(moon_direction, moon_elevation, night, attenuation)
	if _sky_rig:
		_sky_rig.set_sun_direction(sun_basis.z)
		_sky_rig.set_moon_direction(moon_direction)
		_sky_rig.set_sky_rotation(t)

	# At the interval: slow-changing looks and the environment.
	_env_timer += delta
	if _env_timer >= environment_update_interval:
		_env_timer = 0.0
		_update_celestial_looks(t, sun_elevation, moon_elevation, night)
		_update_environment(t, night)

func _update_sun_light(sun_basis: Basis, elevation: float, attenuation: float) -> void:
	if _sun == null:
		return
	_sun.basis = sun_basis
	var energy: float = _state["sun_energy"] * smoothstep(-4.0, 5.0, elevation) * attenuation
	_sun.light_color = _state["sun_color"]
	_sun.light_energy = energy
	_sun.visible = energy > 0.005  # Below the horizon it casts no light.

func _update_moon_light(direction: Vector3, elevation: float, night: float, attenuation: float) -> void:
	if _moon_light == null:
		return
	var energy := config.moonlight_energy * smoothstep(-3.0, 10.0, elevation) * night * attenuation
	_moon_light.light_color = config.moonlight_color
	_moon_light.light_energy = energy
	_moon_light.visible = energy > 0.005
	if _moon_light.visible:
		_moon_light.basis = Basis.looking_at(-direction, Vector3.UP)  # Travels from the moon to the ground.

## Sizes, sun disc color, moon and star visibility (shader parameters, interval-rate).
func _update_celestial_looks(t: float, sun_elevation: float, moon_elevation: float, night: float) -> void:
	if _sky_rig == null:
		return
	_sky_rig.set_angular_sizes(config.sun_angular_diameter_deg, config.moon_angular_diameter_deg, config.celestial_size_multiplier)
	# Sun disc: color by elevation (dawn vs dusk), full brightness, visible only
	# while above the horizon (the shader clips it exactly at the horizon plane).
	var morning := t < 0.5
	var horizon_color := config.sun_dawn_horizon if morning else config.sun_dusk_horizon
	var mid_color := config.sun_dawn_mid if morning else config.sun_dusk_mid
	var color: Color
	if sun_elevation < 8.0:
		color = horizon_color.lerp(mid_color, smoothstep(0.0, 8.0, sun_elevation))
	else:
		color = mid_color.lerp(config.sun_noon, smoothstep(8.0, 30.0, sun_elevation))
	var sun_alpha := smoothstep(-1.5, -0.5, sun_elevation) * (1.0 - 0.8 * cloud_attenuation)
	_sky_rig.set_sun_look(color, sun_alpha, config.sun_glow_strength)
	var moon_alpha := smoothstep(-1.5, -0.5, moon_elevation) * (0.3 + 0.7 * night) * config.moon_disc_alpha * (1.0 - 0.8 * cloud_attenuation)
	_sky_rig.set_moon_look(moon_alpha, config.moon_glow_strength)
	_sky_rig.set_stars(smoothstep(0.35, 0.95, night) * config.star_max_alpha * (1.0 - cloud_attenuation))

func _update_environment(t: float, night: float) -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	_target["sky_top"] = _state["sky_top"]
	_target["sky_horizon"] = _state["sky_horizon"]
	_target["ground_horizon"] = _state["ground_horizon"]
	_target["ground_bottom"] = _state["ground_bottom"]
	# Ambient: the sky-lit part blends into the configurable night baseline.
	_target["ambient_color"] = Color(0, 0, 0).lerp(config.night_ambient_color, night)
	_target["sky_contribution"] = lerpf(config.day_sky_contribution, config.night_sky_contribution, night)
	_target["ambient_energy"] = lerpf(_state["ambient_energy"], config.night_ambient_energy, night)
	_target["fog_density"] = _sample_fog(t) * config.fog_density_scale * atmosphere_multiplier if config.fog_enabled else 0.0
	if _env_delta() < environment_change_threshold:
		return  # Nothing visibly changed since the last application.
	var environment := _world_environment.environment
	environment.ambient_light_color = _target["ambient_color"]
	environment.ambient_light_sky_contribution = _target["sky_contribution"]
	environment.ambient_light_energy = _target["ambient_energy"]
	if environment.sky and environment.sky.sky_material is ProceduralSkyMaterial:
		var sky := environment.sky.sky_material as ProceduralSkyMaterial
		sky.sky_top_color = _target["sky_top"]
		sky.sky_horizon_color = _target["sky_horizon"]
		sky.ground_horizon_color = _target["ground_horizon"]
		sky.ground_bottom_color = _target["ground_bottom"]
	environment.fog_enabled = config.fog_enabled
	if config.fog_enabled:
		environment.fog_light_color = _target["sky_horizon"]
		environment.fog_sky_affect = 0.0
		environment.fog_density = _target["fog_density"]
	for key in _target:
		_applied[key] = _target[key]

## Largest visible change between the applied and the wanted environment.
func _env_delta() -> float:
	if _applied.is_empty():
		return INF
	var largest := 0.0
	for key in ENV_COLOR_KEYS:
		var a: Color = _applied[key]
		var b: Color = _target[key]
		largest = maxf(largest, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
	largest = maxf(largest, absf(_applied["ambient_energy"] - _target["ambient_energy"]))
	largest = maxf(largest, absf(_applied["sky_contribution"] - _target["sky_contribution"]))
	var fog_a: float = _applied["fog_density"]
	var fog_b: float = _target["fog_density"]
	largest = maxf(largest, absf(fog_a - fog_b) / maxf(fog_a, 0.0005) * 0.075)  # 2% relative = 0.0015
	return largest

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

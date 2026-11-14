extends Node
class_name BodyTemperature

## Core body temperature (TP-05A-03A), part of the survival layer: it reads the
## activity flags of PlayerSurvival and the environment through EnvironmentProvider.
## Heat balance (watts):  C * dT/dt = production - loss
##   production = basal + activity (walk / sprint / swim) + solar gain
##   loss       = conductance * (T - environment temperature)   [air or water]
##                + sweating above normal temperature
## Time base: GAME seconds from WorldTime.time_advanced, like hunger/thirst, so
## accelerated time (sleep) cools/warms the body correctly; independent of FPS and
## of UI/pause. Each step uses the exact exponential solution of the linear model,
## so large steps are stable. Effects (TP-05A-03B) are read by PlayerSurvival, which also
## drives advance(); the HUD / Status tab (TP-05A-03C) only listen to the signals.
## Not in scope yet: clothing, weather, water, shelter, shivering.

enum Category { NORMAL, COLD, HYPOTHERMIA, SEVERE_HYPOTHERMIA, HOT, HEAT_STRESS, CRITICAL_HEAT }
const CATEGORY_NAMES := {
	Category.NORMAL: "Normal",
	Category.COLD: "Dingin",
	Category.HYPOTHERMIA: "Hipotermia",
	Category.SEVERE_HYPOTHERMIA: "Hipotermia berat",
	Category.HOT: "Panas",
	Category.HEAT_STRESS: "Stres panas",
	Category.CRITICAL_HEAT: "Panas kritis",
}

signal temperature_changed(value: float)
signal category_changed(category: int, previous: int)

@export_group("Body (°C)")
@export var initial_temperature: float = 37.0
## Set point: sweating starts above it, and a resting body is in balance here.
@export var normal_temperature: float = 37.0
@export var min_temperature: float = 25.0
@export var max_temperature: float = 44.0
## Thermal mass (J/°C). ~70 kg body. Larger = slower temperature changes.
@export var heat_capacity: float = 250000.0

@export_group("Category thresholds (°C)")
@export var severe_hypothermia_below: float = 32.0
@export var hypothermia_below: float = 35.0
## At or above this (and below hot_from) = Normal.
@export var cold_below: float = 36.0
@export var hot_from: float = 37.8
@export var heat_stress_from: float = 38.5
@export var critical_heat_from: float = 40.0

@export_group("Heat production (W)")
@export var basal_heat: float = 80.0
@export var walking_extra_heat: float = 150.0
@export var sprinting_extra_heat: float = 450.0
@export var swimming_extra_heat: float = 350.0
## Heat absorbed in full direct sun (scaled by the sun intensity data).
@export var solar_gain_full_sun: float = 300.0

## Heat released by one jump (J). Added once, then dissipates like any other heat.
@export var jump_heat_joules: float = 3000.0

@export_group("Effects of temperature (initial values, tune freely)")
## Every effect ramps smoothly from 0 at the start of its stage to full at the end;
## stages never snap on at a threshold. Cold effects stay at full while colder.
## Cold (cold_below -> hypothermia_below): extra Hunger drain, slower stamina recovery.
@export var cold_hunger_drain_bonus: float = 0.4          # +40 % at full
@export_range(0.0, 1.0) var cold_stamina_recovery_loss: float = 0.15
## Hypothermia (hypothermia_below -> severe_hypothermia_below): recovery and movement.
@export_range(0.0, 1.0) var hypothermia_stamina_recovery_loss: float = 0.6
@export_range(0.0, 1.0) var hypothermia_movement_loss: float = 0.3
## Severe hypothermia: Health loss per GAME hour, full after severe_ramp_range °C below the threshold.
@export var severe_hypothermia_damage_per_hour: float = 3.0
@export var severe_ramp_range: float = 2.0
## Hot (hot_from -> heat_stress_from): extra Thirst drain.
@export var hot_thirst_drain_bonus: float = 0.5
## Heat stress (heat_stress_from -> critical_heat_from): stamina costs more, recovers slower.
@export var heat_stress_stamina_drain_bonus: float = 0.5
@export_range(0.0, 1.0) var heat_stress_stamina_recovery_loss: float = 0.4
## Critical heat: Health loss per GAME hour, full after critical_ramp_range °C above the threshold.
@export var critical_heat_damage_per_hour: float = 3.0
@export var critical_ramp_range: float = 2.0

@export_group("Heat loss")
## Air temperature at which a resting body is exactly in balance. Also the stand-in
## air temperature while no air-temperature data exists (neutral condition).
@export var neutral_air_temperature: float = 25.0
## Extra conductance per m/s of wind (0.1 = +10 % per m/s).
@export var wind_conductance_per_ms: float = 0.1
## Water carries heat away this many times faster than air.
@export var water_conductance_multiplier: float = 25.0
## Sweat cooling (W per °C above normal). Reduced by humidity when humidity data exists.
@export var sweat_cooling_per_degree: float = 300.0
@export_range(0.0, 1.0) var humidity_sweat_penalty: float = 0.8

@export_group("Simulation")
@export var max_substep_seconds: float = 300.0   # Game seconds per integration step.
@export var emit_step: float = 0.01              # °C change needed to emit a signal.

var _temperature: float = 37.0
var _category: int = Category.NORMAL
var _emitted_temperature: float = -1000.0
var _sample := EnvironmentSample.new()
var _provider: EnvironmentProvider = null
var _survival: PlayerSurvival = null
var _net_power: float = 0.0
var _last_production: float = 80.0
var _pending_heat: float = 0.0
var _hunger_mult := 1.0
var _thirst_mult := 1.0
var _stamina_drain_mult := 1.0
var _stamina_recovery_mult := 1.0
var _movement_mult := 1.0
var _damage_per_hour := 0.0

func _ready() -> void:
	add_to_group("body_temperature")
	_temperature = clampf(initial_temperature, min_temperature, max_temperature)
	_category = classify(_temperature)
	_last_production = basal_heat
	if not (severe_hypothermia_below < hypothermia_below and hypothermia_below < cold_below \
			and cold_below < hot_from and hot_from < heat_stress_from and heat_stress_from < critical_heat_from):
		push_warning("BodyTemperature: category thresholds are not in ascending order.")
	_update_effects()

# ---- Public API -----------------------------------------------------------
func get_temperature() -> float: return _temperature
func get_category() -> int: return _category
func get_category_name() -> String: return CATEGORY_NAMES[_category]
## Net heat flow in the last step (W); positive = warming.
func get_net_power() -> float: return _net_power
## Heat produced in the last step (W): basal + activity + solar gain. Read-only, for the UI.
func get_heat_production() -> float: return _last_production
## The last environment snapshot. Check its has_* flags before using a value. Read-only, for the UI.
func get_environment_sample() -> EnvironmentSample: return _sample

func set_temperature(value: float) -> void:
	_temperature = clampf(value, min_temperature, max_temperature)
	_update_effects()
	_publish()

## One-off heat from an action (a jump). Applied at the next advance().
func add_heat(joules: float) -> void:
	_pending_heat += joules

# Multipliers read by PlayerSurvival / the player. All are 1.0 at normal temperature.
func get_hunger_drain_multiplier() -> float: return _hunger_mult
func get_thirst_drain_multiplier() -> float: return _thirst_mult
func get_stamina_drain_multiplier() -> float: return _stamina_drain_mult
func get_stamina_recovery_multiplier() -> float: return _stamina_recovery_mult
func get_movement_multiplier() -> float: return _movement_mult
## Health lost per game hour because of temperature (0 unless severe cold / critical heat).
func get_damage_per_hour() -> float: return _damage_per_hour

func set_environment_provider(provider: EnvironmentProvider) -> void:
	_provider = provider

## Which environment inputs are real. False = neutral stand-in in use.
func get_data_status() -> Dictionary:
	return {
		"provider": _provider != null,
		"air_temperature": _sample.has_air_temperature,
		"sun": _sample.has_sun,
		"wind": _sample.has_wind,
		"humidity": _sample.has_humidity,
		"water": _sample.has_water,
		"shelter": _sample.has_shelter,
	}

func classify(value: float) -> int:
	if value >= critical_heat_from: return Category.CRITICAL_HEAT
	if value >= heat_stress_from: return Category.HEAT_STRESS
	if value >= hot_from: return Category.HOT
	if value < severe_hypothermia_below: return Category.SEVERE_HYPOTHERMIA
	if value < hypothermia_below: return Category.HYPOTHERMIA
	if value < cold_below: return Category.COLD
	return Category.NORMAL

# ---- Simulation -----------------------------------------------------------
## Advance by game seconds. Driven by PlayerSurvival (in lockstep with hunger /
## thirst / health), which owns the time signal, so nothing is applied twice.
func advance(game_seconds: float) -> void:
	if game_seconds <= 0.0:
		return
	if _pending_heat != 0.0:  # Heat released by one-off actions (jumps).
		_temperature = clampf(_temperature + _pending_heat / heat_capacity, min_temperature, max_temperature)
		_pending_heat = 0.0
	if _survival == null:
		_survival = get_tree().get_first_node_in_group("player_survival") as PlayerSurvival
	if _provider == null:
		_provider = get_tree().get_first_node_in_group("environment_provider") as EnvironmentProvider
	_sample.reset()
	if _provider:
		_provider.fill_sample(_sample)
	var remaining := game_seconds
	var guard := 0
	while remaining > 1e-6 and guard < 4000:
		guard += 1
		var step := minf(remaining, maxf(max_substep_seconds, 1.0))
		_integrate(step)
		remaining -= step
	_update_effects()
	_publish()

func _integrate(dt: float) -> void:
	var s := _sample
	var air := s.air_temperature if s.has_air_temperature else neutral_air_temperature
	var wind := s.wind_speed if s.has_wind else 0.0
	var sun := s.sun_intensity if s.has_sun else 0.0
	var wind_block := s.shelter_wind_protection if s.has_shelter else 0.0
	var sun_block := s.shelter_sun_protection if s.has_shelter else 0.0
	var in_water := s.has_water and s.is_in_water
	var env_temp := s.water_temperature if in_water else air

	var conductance := _base_conductance()
	if in_water:
		conductance *= water_conductance_multiplier
	else:
		conductance *= 1.0 + wind_conductance_per_ms * wind * (1.0 - wind_block)

	var production := basal_heat + _activity_heat()
	if not in_water:
		production += solar_gain_full_sun * sun * (1.0 - sun_block)
	_last_production = production

	var sweat := 0.0
	if _temperature > normal_temperature and not in_water:
		var humidity_factor := 1.0 - (humidity_sweat_penalty * s.humidity if s.has_humidity else 0.0)
		sweat = sweat_cooling_per_degree * humidity_factor
	var total_conductance := maxf(conductance + sweat, 0.001)
	var equilibrium := (production + conductance * env_temp + sweat * normal_temperature) / total_conductance
	var tau := heat_capacity / total_conductance
	var before := _temperature
	_temperature = clampf(equilibrium + (before - equilibrium) * exp(-dt / tau), min_temperature, max_temperature)
	_net_power = (_temperature - before) * heat_capacity / dt

## Conductance (W/°C) that puts a resting body in balance at neutral_air_temperature.
func _base_conductance() -> float:
	return basal_heat / maxf(normal_temperature - neutral_air_temperature, 0.1)

func _activity_heat() -> float:
	if _survival == null:
		return 0.0
	if _survival.is_swimming():
		return swimming_extra_heat
	if _survival.is_sprinting():
		return sprinting_extra_heat
	if _survival.is_moving():
		return walking_extra_heat
	return 0.0

## 0..1 smooth ramp of `amount` over `span`.
func _ramp(amount: float, span: float) -> float:
	var x := clampf(amount / maxf(span, 0.001), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _update_effects() -> void:
	var t := _temperature
	var cold := _ramp(cold_below - t, cold_below - hypothermia_below)
	var hypo := _ramp(hypothermia_below - t, hypothermia_below - severe_hypothermia_below)
	var severe := _ramp(severe_hypothermia_below - t, severe_ramp_range)
	var hot := _ramp(t - hot_from, heat_stress_from - hot_from)
	var stress := _ramp(t - heat_stress_from, critical_heat_from - heat_stress_from)
	var critical := _ramp(t - critical_heat_from, critical_ramp_range)
	_hunger_mult = 1.0 + cold_hunger_drain_bonus * cold
	_thirst_mult = 1.0 + hot_thirst_drain_bonus * hot
	_stamina_drain_mult = 1.0 + heat_stress_stamina_drain_bonus * stress
	_stamina_recovery_mult = (1.0 - cold_stamina_recovery_loss * cold) \
		* (1.0 - hypothermia_stamina_recovery_loss * hypo) \
		* (1.0 - heat_stress_stamina_recovery_loss * stress)
	_movement_mult = 1.0 - hypothermia_movement_loss * hypo
	_damage_per_hour = severe_hypothermia_damage_per_hour * severe + critical_heat_damage_per_hour * critical

func _publish() -> void:
	if absf(_temperature - _emitted_temperature) >= emit_step:
		_emitted_temperature = _temperature
		temperature_changed.emit(_temperature)
	var category := classify(_temperature)
	if category != _category:
		var previous := _category
		_category = category
		category_changed.emit(category, previous)

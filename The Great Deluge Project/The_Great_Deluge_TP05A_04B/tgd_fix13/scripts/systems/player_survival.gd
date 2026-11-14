extends Node
class_name PlayerSurvival

## Player survival needs (TP-05A-01): Health, Hunger, Thirst. Pure logic, no UI.
## Driven only by WorldTime.time_advanced (game seconds), so it is frame-rate
## independent, keeps running while UI is open / the tree is paused, and follows
## accelerated time (sleep) automatically. Large steps are split exactly at the
## moments a need hits 0 or crosses the regen threshold, so one 8-hour step gives
## the same result as many small ones.
## Body temperature effects (TP-05A-03B) are applied here, once. HUD: SurvivalBars.
## Not in scope yet: clothing, weather, death, respawn.

signal health_changed(value: float, max_value: float)
signal hunger_changed(value: float, max_value: float)
signal thirst_changed(value: float, max_value: float)
## Emitted when a need becomes empty / stops being empty (for future UI/audio).
signal hunger_depleted_changed(is_depleted: bool)
signal thirst_depleted_changed(is_depleted: bool)
signal stamina_changed(value: float, max_value: float)
## True while stamina is locked out (hit 0, not yet back to resume_threshold).
signal exhausted_changed(is_exhausted: bool)
signal drowning_changed(is_drowning: bool)

@export var world_time_path: NodePath = NodePath("../WorldTime")

@export_group("Maximums")
@export var max_health: float = 100.0
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0

@export_group("Drain (points per game day)")
@export var hunger_per_day: float = 30.0
@export var thirst_per_day: float = 40.0

@export_group("Stamina (REAL seconds, not game time)")
@export var max_stamina: float = 100.0
@export var sprint_drain_per_second: float = 12.0
@export var jump_cost: float = 8.0
@export var swim_drain_per_second: float = 15.0
@export var walk_recovery_per_second: float = 10.0
@export var idle_recovery_per_second: float = 15.0
## No recovery for this long after sprinting, jumping or swimming.
@export var recovery_delay: float = 1.0
## After reaching 0, sprint / jump / normal swimming return at this stamina.
@export var resume_threshold: float = 20.0

@export_group("Swimming exhaustion (real seconds)")
## At 0 stamina while swimming the player holds out this long before drowning.
@export var swim_exhausted_endurance_seconds: float = 30.0
## Temporary value (the brief only says "gradual"). Real seconds.
@export var drowning_damage_per_second: float = 4.0

@export_group("Damage and regeneration (per game hour)")
@export var hunger_damage_per_hour: float = 2.0
@export var thirst_damage_per_hour: float = 2.0
@export var regen_per_hour: float = 0.5
## Hunger and Thirst must both be at least this to regenerate.
@export var regen_min_need: float = 50.0

var _health: float = 100.0
var _hunger: float = 100.0
var _thirst: float = 100.0
var _hunger_empty := false
var _thirst_empty := false
var _time: WorldTime = null
var _body: BodyTemperature = null
var _stamina: float = 100.0
var _exhausted := false
var _delay_left := 0.0
var _moving := false
var _sprinting := false
var _swimming := false
var _drowning := false
var _swim_grace := 0.0
var _endurance_multiplier := 1.0
var _stamina_emitted := -1.0

func _ready() -> void:
	add_to_group("player_survival")
	_health = max_health
	_hunger = max_hunger
	_thirst = max_thirst
	_stamina = max_stamina
	_time = get_node_or_null(world_time_path) as WorldTime
	if _time == null:
		_time = get_tree().get_first_node_in_group("world_time") as WorldTime
	if _time:
		_time.time_advanced.connect(_on_time_advanced)
	else:
		push_warning("PlayerSurvival: WorldTime not found; needs will not change.")

# ---- Public API -----------------------------------------------------------
func get_health() -> float: return _health
func get_hunger() -> float: return _hunger
func get_thirst() -> float: return _thirst
func get_max_health() -> float: return max_health
func get_max_hunger() -> float: return max_hunger
func get_max_thirst() -> float: return max_thirst

func set_health(value: float) -> void:
	_set_health(value)
func set_hunger(value: float) -> void:
	_set_hunger(value)
func set_thirst(value: float) -> void:
	_set_thirst(value)

## Positive amounts only; the result is always clamped to 0..max.
func heal(amount: float) -> void:
	_set_health(_health + maxf(amount, 0.0))
func damage(amount: float) -> void:
	_set_health(_health - maxf(amount, 0.0))
func add_hunger(amount: float) -> void:   # e.g. eating: +amount, clamped
	_set_hunger(_hunger + amount)
func add_thirst(amount: float) -> void:   # e.g. drinking
	_set_thirst(_thirst + amount)

func is_hunger_depleted() -> bool: return _hunger_empty
func is_thirst_depleted() -> bool: return _thirst_empty
## True while Health is being lost to an empty need.
func is_taking_need_damage() -> bool: return _hunger_empty or _thirst_empty
func can_regenerate() -> bool:
	var body := _get_body()
	return not is_taking_need_damage() and _health < max_health \
		and (body == null or body.get_damage_per_hour() <= 0.0) \
		and _hunger > regen_min_need and _thirst > regen_min_need

# ---- Simulation -----------------------------------------------------------
func _on_time_advanced(game_seconds: float) -> void:
	# Body temperature advances in lockstep, in chunks, so its effects follow the
	# temperature as it changes during long (sleep) steps. It never listens to
	# WorldTime itself, so nothing is counted twice.
	var body := _get_body()
	if body == null:
		_simulate(game_seconds / 3600.0)
		return
	var chunk := maxf(body.max_substep_seconds, 1.0)
	var remaining := game_seconds
	var guard := 0
	while remaining > 1e-6 and guard < 4000:
		guard += 1
		var step := minf(remaining, chunk)
		body.advance(step)
		_simulate(step / 3600.0)
		remaining -= step

func _get_body() -> BodyTemperature:
	if _body == null:
		_body = get_tree().get_first_node_in_group("body_temperature") as BodyTemperature
	return _body

## Movement speed factor (1.0 normally; lower with hypothermia). Used by the player.
func get_movement_multiplier() -> float:
	var body := _get_body()
	return body.get_movement_multiplier() if body else 1.0

## Advance by game hours. Segments split at events so the result does not depend
## on step size. Inside a segment both needs are draining, so "above the regen
## threshold" is strict (a need sitting exactly on 50 is about to fall below it).
func _simulate(hours: float) -> void:
	var body := _get_body()
	var hunger_rate := hunger_per_day / 24.0 * (body.get_hunger_drain_multiplier() if body else 1.0)
	var thirst_rate := thirst_per_day / 24.0 * (body.get_thirst_drain_multiplier() if body else 1.0)
	var temperature_damage := body.get_damage_per_hour() if body else 0.0
	var health := _health
	var hunger := _hunger
	var thirst := _thirst
	var remaining := hours
	var guard := 0
	while remaining > 1e-9 and guard < 8:
		guard += 1
		var seg := remaining
		seg = _time_to(hunger, 0.0, hunger_rate, seg)
		seg = _time_to(thirst, 0.0, thirst_rate, seg)
		seg = _time_to(hunger, regen_min_need, hunger_rate, seg)
		seg = _time_to(thirst, regen_min_need, thirst_rate, seg)
		var hunger_zero := hunger <= 0.0
		var thirst_zero := thirst <= 0.0
		var rate := 0.0
		if hunger_zero:
			rate -= hunger_damage_per_hour
		if thirst_zero:
			rate -= thirst_damage_per_hour
		rate -= temperature_damage  # Distinct source from the need damage above; not applied twice.
		if rate == 0.0 and hunger > regen_min_need and thirst > regen_min_need:
			rate = regen_per_hour
		health = clampf(health + rate * seg, 0.0, max_health)
		hunger = _snap(hunger - hunger_rate * seg)
		thirst = _snap(thirst - thirst_rate * seg)
		remaining -= seg
	# Whatever is left (only if the guard tripped) is handled in the steady state.
	_set_hunger(hunger)
	_set_thirst(thirst)
	_set_health(health)

## Shortest of `limit` and the time for `value` to fall to `target` at `rate`.
func _time_to(value: float, target: float, rate: float, limit: float) -> float:
	if rate <= 0.0 or value <= target:
		return limit
	return minf(limit, (value - target) / rate)

func _snap(value: float) -> float:
	return 0.0 if value < 1e-6 else value

func _set_health(value: float) -> void:
	value = clampf(value, 0.0, max_health)
	if value == _health:
		return
	_health = value
	health_changed.emit(_health, max_health)

func _set_hunger(value: float) -> void:
	value = clampf(value, 0.0, max_hunger)
	var empty := value <= 0.0
	if value != _hunger:
		_hunger = value
		hunger_changed.emit(_hunger, max_hunger)
	if empty != _hunger_empty:
		_hunger_empty = empty
		hunger_depleted_changed.emit(empty)

func _set_thirst(value: float) -> void:
	value = clampf(value, 0.0, max_thirst)
	var empty := value <= 0.0
	if value != _thirst:
		_thirst = value
		thirst_changed.emit(_thirst, max_thirst)
	if empty != _thirst_empty:
		_thirst_empty = empty
		thirst_depleted_changed.emit(empty)

# ---- Stamina / swimming (real time; unaffected by WorldTime speed) --------
func get_stamina() -> float: return _stamina
func get_max_stamina() -> float: return max_stamina
func is_exhausted() -> bool: return _exhausted
func is_drowning() -> bool: return _drowning
func set_stamina(value: float) -> void:
	_set_stamina(value)
func add_stamina(amount: float) -> void:
	_set_stamina(_stamina + amount)

## Sprint is unavailable from 0 stamina until it is back to resume_threshold.
func can_sprint() -> bool:
	return not _exhausted

## Called by the player every physics tick. `moving` = real movement input;
## `sprinting` = sprint actually in effect (it only drains while this is true).
func set_activity(moving: bool, sprinting: bool) -> void:
	_moving = moving
	_sprinting = sprinting and not _exhausted

## Called once when a jump is about to happen. Returns false (no jump, no cost)
## while exhausted. The same exhaustion lock as sprint applies to jumping.
func try_jump() -> bool:
	if _exhausted or _stamina <= 0.0:
		return false
	_delay_left = recovery_delay
	var body := _get_body()
	_set_stamina(_stamina - jump_cost * (body.get_stamina_drain_multiplier() if body else 1.0))
	if body:
		body.add_heat(body.jump_heat_joules)
	return true

## Activity state, read by BodyTemperature (heat production).
func is_moving() -> bool: return _moving
func is_sprinting() -> bool: return _sprinting and not _exhausted
func is_swimming() -> bool: return _swimming
func get_body_temperature() -> BodyTemperature:
	return get_tree().get_first_node_in_group("body_temperature") as BodyTemperature

## Hook for a future swimming system: call with true while the player swims.
func set_swimming(value: bool) -> void:
	_swimming = value

## Hook for body temperature / fatigue / gear: scales the 30 s endurance. 1.0 = base.
func set_swim_endurance_multiplier(value: float) -> void:
	_endurance_multiplier = maxf(value, 0.0)
func get_swim_endurance_seconds() -> float:
	return swim_exhausted_endurance_seconds * _endurance_multiplier
## Seconds left before drowning while swimming at 0 stamina (full value otherwise).
func get_swim_time_left() -> float:
	return maxf(get_swim_endurance_seconds() - _swim_grace, 0.0)

## Safe ground reached or rescued: the ONLY ways to end drowning (stamina alone does not).
func notify_reached_safe_ground() -> void:
	_swim_grace = 0.0
	_set_drowning(false)
func rescue() -> void:
	notify_reached_safe_ground()

func _process(delta: float) -> void:
	_update_stamina(delta)
	_update_drowning(delta)

func _update_stamina(delta: float) -> void:
	var value := _stamina
	var body := _get_body()
	var drain_mult := body.get_stamina_drain_multiplier() if body else 1.0
	if _swimming:
		_delay_left = recovery_delay
		value -= swim_drain_per_second * drain_mult * delta
	elif _sprinting and not _exhausted:
		_delay_left = recovery_delay
		value -= sprint_drain_per_second * drain_mult * delta
	elif _delay_left > 0.0:
		_delay_left -= delta
	elif value < max_stamina:
		var recovery_mult := body.get_stamina_recovery_multiplier() if body else 1.0
		value += (walk_recovery_per_second if _moving else idle_recovery_per_second) * recovery_mult * delta
	if value != _stamina:
		_set_stamina(value)

func _update_drowning(delta: float) -> void:
	if _drowning:
		damage(drowning_damage_per_second * delta)
		return
	if _swimming and _stamina <= 0.0:
		_swim_grace += delta
		if _swim_grace >= get_swim_endurance_seconds():
			_set_drowning(true)
	else:
		_swim_grace = 0.0

func _set_stamina(value: float) -> void:
	_stamina = clampf(value, 0.0, max_stamina)
	if _stamina <= 0.0 and not _exhausted:
		_exhausted = true
		exhausted_changed.emit(true)
	elif _exhausted and _stamina >= resume_threshold:
		_exhausted = false
		exhausted_changed.emit(false)
	# Throttle: continuous drain/recovery would otherwise emit every frame.
	if absf(_stamina - _stamina_emitted) >= 0.1 or _stamina == 0.0 or _stamina == max_stamina:
		if _stamina != _stamina_emitted:
			_stamina_emitted = _stamina
			stamina_changed.emit(_stamina, max_stamina)

func _set_drowning(value: bool) -> void:
	if value != _drowning:
		_drowning = value
		drowning_changed.emit(value)

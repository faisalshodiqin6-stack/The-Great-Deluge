extends Label

## Simple HUD clock (24h, e.g. "08:30"). Only reads WorldTime; the clock keeps
## running without this label. Replace or restyle freely.
const REFRESH_SECONDS := 0.25
var _time: WorldTime = null
var _timer: float = REFRESH_SECONDS

func _process(delta: float) -> void:
	_timer += delta
	if _timer < REFRESH_SECONDS:
		return
	_timer = 0.0
	if _time == null:
		_time = get_tree().get_first_node_in_group("world_time") as WorldTime
	if _time:
		text = _time.get_time_string()

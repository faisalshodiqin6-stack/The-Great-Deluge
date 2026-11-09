extends Node
class_name AmbientAudio

## Time-of-day ambient sound layers driven by WorldTime. No audio assets exist
## in the project yet, so every stream is empty by default: assign looping
## streams (see docs) in the Inspector and it works with no code change.
## One AudioStreamPlayer per assigned layer, created once; volumes cross-fade
## smoothly and a layer only plays while audible (no stacking, no hard cuts).
@export var day_ambience: AudioStream
@export var night_insects: AudioStream
@export var night_calm: AudioStream
@export var master_volume: float = 1.0
@export var update_interval: float = 0.2
@export var fade_speed: float = 0.5   # Max gain change per second (smoothing).

## Gain (0..1) over the day per layer: [t, gain] keys, linearly blended.
const GAIN_KEYS := {
	"day": [[0.00, 0.0], [0.24, 0.0], [0.30, 1.0], [0.72, 1.0], [0.79, 0.0], [1.00, 0.0]],
	"insects": [[0.00, 0.6], [0.22, 0.6], [0.27, 0.0], [0.72, 0.0], [0.78, 0.8], [0.86, 1.0], [1.00, 0.8]],
	"calm": [[0.00, 1.0], [0.20, 1.0], [0.27, 0.0], [0.78, 0.0], [0.90, 1.0], [1.00, 1.0]],
}

var _players: Dictionary = {}   # layer name -> AudioStreamPlayer
var _gains: Dictionary = {}     # layer name -> current smoothed gain
var _time: WorldTime = null
var _timer: float = 0.0

func _ready() -> void:
	_add_layer("day", day_ambience)
	_add_layer("insects", night_insects)
	_add_layer("calm", night_calm)

func _add_layer(layer_name: String, stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -80.0
	add_child(player)
	_players[layer_name] = player
	_gains[layer_name] = 0.0

func _process(delta: float) -> void:
	if _players.is_empty():
		return
	_timer += delta
	if _timer < update_interval:
		return
	var step := _timer
	_timer = 0.0
	if _time == null:
		_time = get_tree().get_first_node_in_group("world_time") as WorldTime
		if _time == null:
			return
	var t := _time.get_normalized_time()
	for layer_name in _players:
		var target := _sample(GAIN_KEYS[layer_name], t) * master_volume
		_gains[layer_name] = move_toward(_gains[layer_name], target, fade_speed * step)
		var player: AudioStreamPlayer = _players[layer_name]
		var gain: float = _gains[layer_name]
		player.volume_db = linear_to_db(maxf(gain, 0.0001))
		if gain > 0.002 and not player.playing:
			player.play()
		elif gain <= 0.002 and player.playing:
			player.stop()

func _sample(keys: Array, t: float) -> float:
	var index := 0
	while index < keys.size() - 2 and t >= keys[index + 1][0]:
		index += 1
	var a: Array = keys[index]
	var b: Array = keys[index + 1]
	var f := clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	return lerpf(a[1], b[1], f * f * (3.0 - 2.0 * f))

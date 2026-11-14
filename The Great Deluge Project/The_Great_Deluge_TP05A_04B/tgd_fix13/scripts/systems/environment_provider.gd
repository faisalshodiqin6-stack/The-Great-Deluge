extends Node
class_name EnvironmentProvider

## Interface for future weather / water / shelter / sun systems. Extend this,
## override fill_sample(), and add the node to the scene: BodyTemperature finds it
## through the "environment_provider" group. Fill only what you really have and set
## the matching has_* flag; leave the rest untouched (it stays "unavailable").
## No provider exists yet, so BodyTemperature currently runs on neutral conditions.

func _ready() -> void:
	add_to_group("environment_provider")

## Called once per clock advance. `sample` has been reset() before the call.
func fill_sample(_sample: EnvironmentSample) -> void:
	pass

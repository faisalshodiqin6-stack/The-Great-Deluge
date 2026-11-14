extends Resource
class_name TemperatureRegion

## Temperature CHARACTER of a region. It says nothing about WHERE the region is:
## placement belongs to a RegionLocator (flat areas today, planet coordinates later),
## so this resource stays valid when the way regions are found changes.
## Optional for WorldEnvironmentData: a position with no region uses neutral values.
@export var region_id: StringName = &"region"
@export var region_name: String = "Region"
## Added to the base mean air temperature (°C).
@export var temperature_offset: float = 0.0
## Multiplies the day/night swing (1.0 = base setting, 0.5 = half the swing).
@export_range(0.0, 3.0) var swing_scale: float = 1.0
## When several regions cover a point, the highest priority wins (ties: first found).
@export var priority: int = 0

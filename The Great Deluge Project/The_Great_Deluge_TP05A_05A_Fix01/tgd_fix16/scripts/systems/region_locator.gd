extends Resource
class_name RegionLocator

## Interface: "which TemperatureRegion covers this world position?". It is the ONLY
## thing that knows how regions are placed; the temperature formula never looks at
## coordinates. To change how regions are found (e.g. planet latitude/longitude),
## write a new subclass and assign it to WorldEnvironmentData.region_locator.
##
## Contract for subclasses:
##  - find_region() returns null when no region covers the position (neutral values apply).
##  - It must be cheap, allocation-free, and tolerate any position (never crash, never NaN).
##  - Overlaps are resolved with pick_by_priority() so every locator ranks regions the same way.

## Override. `world_position` is in world space; a planet locator converts it to
## geographic coordinates itself.
func find_region(_world_position: Vector3) -> TemperatureRegion:
	return null

## Override: true when at least one region is configured (for status reporting).
func has_regions() -> bool:
	return false

## Override: short text for get_data_status().
func get_description() -> String:
	return "no locator"

## Shared tie-break: higher priority wins; on equal priority the current best is kept
## (first found).
static func pick_by_priority(best: TemperatureRegion, candidate: TemperatureRegion) -> TemperatureRegion:
	if candidate == null:
		return best
	if best == null or candidate.priority > best.priority:
		return candidate
	return best

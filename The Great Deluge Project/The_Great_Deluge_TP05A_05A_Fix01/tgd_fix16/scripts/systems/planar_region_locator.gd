extends RegionLocator
class_name PlanarRegionLocator

## Adapter for the CURRENT flat prototype world: regions are rectangles on the X/Z
## plane. Not suitable for a round planet (no wrap-around, no poles, distorted
## distances), which is why it sits behind the RegionLocator interface. With an empty
## list the whole world is one neutral default region.
@export var areas: Array[PlanarRegionArea] = []

func find_region(world_position: Vector3) -> TemperatureRegion:
	var point := Vector2(world_position.x, world_position.z)
	var best: TemperatureRegion = null
	for entry in areas:
		if entry == null or entry.region == null or not entry.area.has_point(point):
			continue
		best = pick_by_priority(best, entry.region)
	return best

func has_regions() -> bool:
	return areas.size() > 0

func get_description() -> String:
	return "planar X/Z rectangles (prototype)"

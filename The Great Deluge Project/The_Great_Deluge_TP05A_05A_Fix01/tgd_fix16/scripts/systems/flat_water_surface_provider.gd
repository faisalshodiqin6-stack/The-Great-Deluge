extends WaterSurfaceProvider
class_name FlatWaterSurfaceProvider

## Temporary provider for the CURRENT flat prototype world: one horizontal water plane at
## surface_y (the Ocean node: a 1000 x 1000 m plane at Y = 0, centered on the origin).
##
## A position counts as "in water" only when ALL of these are certain:
##  1. it is inside the plane's horizontal extent (no ocean exists beyond the mesh),
##  2. it is at or below surface_y,
##  3. it is not underground (needs a known ground height when require_ground_height is on).
## Anything else returns NAN ("not confirmed in water").
@export var surface_y: float = 0.0
## Limit water to the Ocean plane's footprint. Rect2.position = (x, z) of the corner.
@export var limit_to_extent: bool = true
@export var extent: Rect2 = Rect2(-500.0, -500.0, 1000.0, 1000.0)
## On: when the ground height is unknown, water is NOT claimed (an underground point
## below the surface could otherwise be mistaken for water). Off: trust the plane alone.
@export var require_ground_height: bool = true

func get_water_depth(world_position: Vector3, ground_height: float) -> float:
	var x := world_position.x
	var y := world_position.y
	var z := world_position.z
	if is_nan(x) or is_inf(x) or is_nan(y) or is_inf(y) or is_nan(z) or is_inf(z):
		return NAN
	if is_nan(surface_y) or is_inf(surface_y):
		return NAN
	if limit_to_extent and not extent.has_point(Vector2(x, z)):
		return NAN
	if is_nan(ground_height) or is_inf(ground_height):
		if require_ground_height:
			return NAN
	elif y < ground_height:
		return NAN  # Underground.
	var depth := surface_y - y
	if depth < 0.0:
		return NAN  # Above the surface.
	return depth

func get_description() -> String:
	return "flat ocean plane at Y=%.2f (prototype)" % surface_y

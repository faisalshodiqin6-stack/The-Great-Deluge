extends Resource
class_name PlanarRegionArea

## Placement of one TemperatureRegion on the flat prototype world.
@export var region: TemperatureRegion
## Ground-plane rectangle: Rect2.position = (x, z) of the corner, size = (width, depth), meters.
@export var area: Rect2 = Rect2(-50.0, -50.0, 100.0, 100.0)

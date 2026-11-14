extends Node
class_name WaterTemperatureData

## Water temperature data (TP-05A-05A, foundation). Answers: "if this world position is
## inside water, what is the water temperature in °C, how deep is it, and which region?"
## Nothing here is connected to BodyTemperature yet.
##
## Simple model (all values editable in the Inspector):
##   surface = surface_temperature + region water offset + temporal offset (0 for now)
##   T(depth) = surface + (deep_temperature - surface) * (1 - exp(-depth / depth_scale))
## depth 0 gives exactly `surface`; with depth the value moves smoothly and monotonically
## toward deep_temperature (never past it) and never changes direction.
##
## "In water" comes from a WaterSurfaceProvider (separate from this formula). A position
## that is not confirmed to be in water gives an UNAVAILABLE reading, never a made-up number.
##
## LIMITATIONS (by design, see docs/WATER_TEMPERATURE_DATA.md):
##  - One global surface temperature. No water region data exists yet: with no region
##    configured every position uses the base value (region id empty).
##  - Region identity reuses RegionLocator / TemperatureRegion (field water_temperature_offset).
##  - Time of day / season: not implemented; _temporal_offset() is the single hook (returns 0).
##  - Ground: only the Island's height grid area is known ground. Open sea outside it counts as
##    having no ground (the Ocean plane has no collider there, so a player cannot stand in it).
##  - Not modelled: currents, waves, weather, pressure, thermocline, deep-ocean physics.
##  - Values are placeholder base settings, not a final climate design.

@export_group("Surface temperature (°C)")
## Water temperature exactly at the surface (depth 0), in the default region. Placeholder.
@export var surface_temperature: float = 26.0

@export_group("Change with depth")
## Temperature the water approaches at great depth (depth -> infinity). Placeholder.
@export var deep_temperature: float = 14.0
## Depth (m) over which ~63 % of the surface -> deep change happens (e-folding length).
## Larger = slower change. Minimum used by the formula: 0.001.
@export var depth_scale: float = 25.0
## Depth used by the formula is limited to 0..this, so odd positions cannot give extreme values.
@export var max_depth: float = 200.0

@export_group("Water surface")
## How "inside water" is decided. Empty = a FlatWaterSurfaceProvider (Ocean plane at Y=0).
@export var surface_provider: WaterSurfaceProvider
## Node with height_at(x, z) (the Island). Used only to know the ground is not above the
## query point. Missing node -> ground unknown -> the surface provider decides what to do.
@export var terrain_path: NodePath = NodePath("../Island")
## Horizontal area (Rect2: corner x,z + width,depth) where the terrain node has real ground
## (the Island's height grid: 180 x 140 m centered on the origin). Outside it there is no
## ground at all (open sea), so ground is reported as absent instead of the terrain's
## placeholder seabed value. Keep in sync with island.gd HALF_WIDTH / HALF_DEPTH.
@export var terrain_extent: Rect2 = Rect2(-90.0, -70.0, 180.0, 140.0)

@export_group("Regions (optional)")
## How water regions are found. Empty = a PlanarRegionLocator without areas (neutral world).
@export var region_locator: RegionLocator

@export_group("Safety limits (°C)")
@export var min_water_temperature: float = -2.0
@export var max_water_temperature: float = 40.0

## "No ground here" marker passed to the surface provider (finite, far below any water).
const NO_GROUND_Y := -1.0e6

var _terrain: Node3D = null

func _ready() -> void:
	add_to_group("water_temperature_data")
	if surface_provider == null:
		surface_provider = FlatWaterSurfaceProvider.new()
	if region_locator == null:
		region_locator = PlanarRegionLocator.new()

# ---- Public API -----------------------------------------------------------
## Fills `out` for a world position. out.available is true only when the position is
## confirmed to be in water AND the resulting temperature is finite.
func query_at(world_position: Vector3, out: WaterTemperatureReading) -> void:
	out.clear("position not confirmed in water")
	if surface_provider == null:
		out.reason = "no water surface provider"
		return
	var depth := surface_provider.get_water_depth(world_position, _ground_height_at(world_position))
	if is_nan(depth) or is_inf(depth) or depth < 0.0:
		return
	var region := get_region_at(world_position)
	var temperature := get_temperature_at_depth(world_position, depth)
	if is_nan(temperature) or is_inf(temperature):
		out.reason = "invalid temperature settings"
		return
	out.available = true
	out.temperature = temperature
	out.depth = depth
	out.reason = "ok"
	if region:
		out.region_id = region.region_id
		out.region_name = region.region_name

## Surface (depth 0) water temperature at a position, °C. May be NAN if the settings
## are invalid; query_at() treats that as unavailable.
func get_surface_temperature_at(world_position: Vector3) -> float:
	var region := get_region_at(world_position)
	var offset := region.water_temperature_offset if region else 0.0
	return surface_temperature + offset + _temporal_offset()

## Temperature at a depth (m below the surface) at a position, °C. Does NOT check that the
## position is in water (use query_at for that). Depth is limited to 0..max_depth.
## The result is limited to min/max_water_temperature; NAN only if a setting is NaN/inf.
func get_temperature_at_depth(world_position: Vector3, depth: float) -> float:
	var surface := get_surface_temperature_at(world_position)
	if is_nan(depth) or is_inf(depth):
		return NAN
	if is_nan(surface) or is_inf(surface) or is_nan(deep_temperature) or is_inf(deep_temperature):
		return NAN
	var d := clampf(depth, 0.0, maxf(max_depth, 0.0))
	var mix := 1.0 - exp(-d / maxf(depth_scale, 0.001))
	var temperature := surface + (deep_temperature - surface) * mix
	return clampf(temperature, minf(min_water_temperature, max_water_temperature), maxf(min_water_temperature, max_water_temperature))

## The region containing the position, or null (= default region).
func get_region_at(world_position: Vector3) -> TemperatureRegion:
	return region_locator.find_region(world_position) if region_locator else null

## What is real and what is not right now.
func get_data_status() -> Dictionary:
	return {
		"surface_provider": surface_provider.get_description() if surface_provider else "none (no water claimed)",
		"regions": region_locator != null and region_locator.has_regions(),  # false: base value everywhere.
		"region_locator": region_locator.get_description() if region_locator else "none",
		"terrain_source": _terrain_node() != null,   # false: ground height unknown.
		"time_or_season": false,                     # Not part of this stage.
	}

# ---- Internals ------------------------------------------------------------
## Future hook for time of day / season (°C added to the surface temperature). 0 now.
func _temporal_offset() -> float:
	return 0.0

## World Y of the ground under a position. NAN = unknown (no terrain node).
## NO_GROUND_Y = the terrain node exists but has no ground there (outside terrain_extent).
func _ground_height_at(world_position: Vector3) -> float:
	var terrain := _terrain_node()
	if terrain == null:
		return NAN
	var local := terrain.to_local(world_position)
	if not terrain_extent.has_point(Vector2(local.x, local.z)):
		return NO_GROUND_Y
	var ground_local := float(terrain.call("height_at", local.x, local.z))
	if is_nan(ground_local) or is_inf(ground_local):
		return NAN
	return terrain.to_global(Vector3(local.x, ground_local, local.z)).y

func _terrain_node() -> Node3D:
	if _terrain == null or not is_instance_valid(_terrain):
		var node := get_node_or_null(terrain_path) as Node3D
		_terrain = node if node != null and node.has_method("height_at") else null
	return _terrain

# WorldEnvironmentData — air temperature (TP-05A-04A)

Node `WorldEnvironmentData` in `world.tscn` (group `world_environment_data`).

**API**
- `get_air_temperature_at(world_position: Vector3, hour := -1.0) -> float` — °C. `hour < 0` = current `WorldTime` hour.
- `get_air_temperature_at_hour(world_position, hour)` — fixed hour (0..24).
- `get_region_at(world_position) -> TemperatureRegion` (null = default region).
- `get_data_status() -> Dictionary` — which inputs are real.

**Model**: `air = mean + region offset − lapse × altitude + swing × region scale × curve(hour)`.
Curve: −1 at `coldest_hour` (5), +1 at `warmest_hour` (15), cosine-eased (smooth, asymmetric). Result is clamped to `min/max_air_temperature` (−60..60) and NaN-safe.

**Inspector parameters**: `mean_temperature` 25, `daily_swing` 5 (so 20..30 °C), `coldest_hour`, `warmest_hour`, `altitude_provider` (`sea_level_y` is on `FlatAltitudeProvider`), `lapse_rate_per_100m` 0.65, `max_altitude`, `region_locator` (see Regions).

**Limits**: no weather (wind, humidity, rain, storm, clouds, sun heating). No world regions exist yet → one neutral default region. Altitude = world Y of the position (no terrain-height lookup exists). Defaults are placeholders, not a climate design.

**Integration (stage 2)**: `WorldAirTemperatureProvider` (extends `EnvironmentProvider`, group `environment_provider`) calls `get_air_temperature_at(Player.global_position)` and writes `EnvironmentSample.air_temperature` with `has_air_temperature = true` only when a finite value was obtained (data node and player found). `BodyTemperature` finds the provider through the group, as before. Sun, wind, humidity, water and shelter are not filled and stay "unavailable". Paths (`data_path`, `player_path`) are Inspector exports.
Known limit: the air temperature is sampled once per clock step, at the current world time. For normal play (one frame = a fraction of a game second) this is exact; during very large accelerated steps (sleep) the whole step uses the end-of-step hour.

## Regions (TP-05A-04B)
**Why not Rect2 on X/Z for the planet**: a flat rectangle has no wrap-around (longitude 180° → -180°), no poles, and distorts distances on a sphere. It is fine for the flat prototype, so it is kept as one *adapter*, not as the architecture.

**Parts (each has one job)**
- `TemperatureRegion` (Resource): the *character* of a region: `region_id`, `region_name`, `temperature_offset`, `swing_scale`, `priority`. No location.
- `RegionLocator` (Resource, interface): `find_region(world_position) -> TemperatureRegion` (null = none), `has_regions()`, `get_description()`, and the shared `pick_by_priority()` (highest priority wins; ties: first found).
- `PlanarRegionLocator` + `PlanarRegionArea`: today's adapter. `areas[]`, each = a `TemperatureRegion` + a `Rect2` on X/Z (position = corner x,z; size = width, depth).
- `WorldEnvironmentData`: the temperature formula (unchanged). It only calls `region_locator.find_region()` and reads offset / swing scale.

**Add a region (no code change)**: in `WorldEnvironmentData` assign `region_locator` = new `PlanarRegionLocator`, add a `PlanarRegionArea`, give it a `TemperatureRegion` and a Rect2. No region configured → neutral (offset 0, scale 1).

**Planet later**: write `GeographicRegionLocator extends RegionLocator` that converts `world_position` to latitude/longitude and looks regions up (cells, polygons, ...); assign it to `region_locator`. `TemperatureRegion` and the formula stay as they are. Not built now (no planet, no real region placement exists).

**Migration**: `TemperatureRegion.area` and `WorldEnvironmentData.regions[]` (stage 1) were replaced by the above; no region data had been created, so nothing needed converting.

## Altitude (TP-05A-04C)
- `AltitudeProvider` (Resource, interface): `get_altitude(world_position) -> float` = meters above the reference sea surface (negative below it), `get_description()`.
- `FlatAltitudeProvider`: current prototype. `altitude = world_position.y − sea_level_y` (`sea_level_y` default 0, moved here from `WorldEnvironmentData`; the value and behavior are unchanged).
- `WorldEnvironmentData._altitude_for_formula()` is the single place that uses the altitude: provider value → limited to `0..max_altitude` → `− lapse_rate_per_100m × altitude / 100`. The temperature formula never reads coordinates.
- **Fallback**: no provider assigned → a `FlatAltitudeProvider` (sea level Y=0) is created at start. A provider that returns NaN/inf → altitude 0 (no altitude cooling). Status: `get_data_status()["altitude_provider"]`.
- **Planet later (not built)**: `PlanetAltitudeProvider extends AltitudeProvider` with `planet_center: Vector3` and `reference_radius: float`; `get_altitude = world_position.distance_to(planet_center) − reference_radius`. Assign it to `altitude_provider`; no other change.
- Not covered: terrain-height lookup (the island's height), which is a different question from the height of a point; the region system is untouched.

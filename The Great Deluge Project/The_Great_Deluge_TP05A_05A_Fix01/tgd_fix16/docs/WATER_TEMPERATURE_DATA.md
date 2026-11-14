# Water temperature data foundation (TP-05A-05A)

Data only. **Not connected to BodyTemperature** (its formula, `water_conductance_multiplier = 25`, WorldTime and DayNightCycle are untouched).

## Parts (one job each)
| File | Role |
|---|---|
| `water_surface_provider.gd` (`WaterSurfaceProvider`, Resource) | Interface: `get_water_depth(pos, ground_y)` -> m below surface, `NAN` = not confirmed in water. |
| `flat_water_surface_provider.gd` | Prototype: Ocean plane at `surface_y` (0), extent 1000x1000. |
| `water_temperature_reading.gd` | Reusable result: `available`, `temperature`, `depth`, `region_id`, `region_name`, `reason`. |
| `water_temperature_data.gd` (`WaterTemperatureData`, Node, group `water_temperature_data`) | The formula + `query_at(pos, reading)`. |
| `water_temperature_provider.gd` (`WaterTemperatureProvider`, `EnvironmentProvider`) | Tests the player's sample point and fills `EnvironmentSample.water_profile_*`. |
| `environment_sample.gd` | + `has_water_profile`, `water_profile_temperature`, `water_profile_depth`, `water_profile_region_id`, `water_profile_region_name` (all cleared in `reset()`). |
| `temperature_region.gd` | + `water_temperature_offset` (default 0). |
| `world.tscn` | + nodes `WaterTemperatureData`, `WaterTemperatureProvider`. |

The existing `has_water / is_in_water / water_temperature` fields (the ones BodyTemperature reads) are **not written**. A later stage maps the profile onto them.

## Is the player in water?
Sample point = player origin + `sample_height_offset` (0.9 m, middle of the capsule). In water only if ALL hold:
1. point inside the ocean extent (x/z in the 1000x1000 plane),
2. point Y <= `surface_y` (depth = surface_y - Y >= 0),
3. point not below the ground: ground = `Island.height_at` inside `terrain_extent` (the island grid); outside it there is no ground (open sea). If the terrain node is missing the ground is unknown and, with `require_ground_height` on, **no water is claimed**.
Anything else (or a NaN/inf position) = unavailable; all `water_profile_*` stay at the reset values.

## Formula
```
surface = surface_temperature + region.water_temperature_offset + temporal_offset (0 now)
T(d)    = surface + (deep_temperature - surface) * (1 - exp(-d / depth_scale))
d       = clamp(depth, 0, max_depth);  T clamped to [min_water_temperature, max_water_temperature]
```
d = 0 gives exactly `surface`. Monotone toward `deep_temperature`, never past it. A NaN/inf setting gives "unavailable", not a made-up value.

## Parameter validation (Fix 01)
Before any calculation `_settings_problem()` checks: `surface_temperature`, `deep_temperature` finite; `depth_scale` finite and > 0; `max_depth` finite and >= 0; `min/max_water_temperature` finite and min <= max (equal is allowed; reversed limits are rejected, not swapped). The region's `water_temperature_offset` (and the temporal hook) must be finite, and the sum / result must not overflow. Any failure = unavailable with a `reason` such as `invalid setting: depth_scale must be finite and > 0`; nothing is repaired or clamped silently. Valid settings always give a finite value inside `[min, max]`.

## Inspector (WaterTemperatureData)
`surface_temperature` 26, `deep_temperature` 14, `depth_scale` 25 m, `max_depth` 200, `surface_provider` (empty = FlatWaterSurfaceProvider), `terrain_path` ../Island, `terrain_extent` Rect2(-90,-70,180,140), `region_locator` (empty = none), `min/max_water_temperature` -2 / 40.
FlatWaterSurfaceProvider: `surface_y` 0, `limit_to_extent`, `extent`, `require_ground_height`.
WaterTemperatureProvider: `data_path`, `player_path`, `sample_height_offset` 0.9, `publish_to_environment_sample` true.
Placeholder values, not a climate design.

## Extending
- Regions: assign a `PlanarRegionLocator` with areas whose `TemperatureRegion` has `water_temperature_offset` (same locator interface as air).
- Time / season: implement `WaterTemperatureData._temporal_offset()` (single hook, returns 0).
- Other water (lakes, planet ocean): new `WaterSurfaceProvider` subclass.

## Checks (no Godot available; NOT a runtime test)
`python3 -I tools/water_temperature_sim.py` (formulas and decisions, output in `tools/water_temperature_sim_output.txt`) and `python3 -I tools/static_check_water.py <project_root>` (`tools/static_check_water_output.txt`).

## Limits
Island grid constants are duplicated in `terrain_extent`. The Ocean has no collider, so beyond the island grid a player falls; there the data says "in water" below Y=0 (the ocean plane exists). Provider results are sampled once per `fill_sample` call. No time/season, no regions with data, no deep-ocean physics.

# SunExposureProvider (TP-05A-04D, stage 1)

`SunExposureProvider` (node in `world.tscn`, extends `EnvironmentProvider`) reports the real current sun.

**Source**: the `DirectionalLight3D` that `DayNightCycle` moves (`DayNightCycle.sun_path`). Direction toward the sun = the light's global +Z axis (same vector `DayNightCycle` gives `SkyRig`); elevation = `asin(direction.y)`. No second sun cycle, no clock-based guess.

**API**: `is_data_available()`, `is_sun_above_horizon()` (elevation > 0), `get_sun_elevation_degrees()` (−90..90), `get_sun_intensity()` (0..1).
Intensity = `sin(elevation) / sin(sun_max_elevation)` (peak 1.0 at the daily maximum, falls toward the horizon, 0 at/below it) × `(1 − cloud_attenuation) × weather_light_multiplier` read from `DayNightCycle` (neutral today). Unavailable (no DayNightCycle / light) → `false / 0`, never an invented value.

**EnvironmentSample**: new fields `sun_elevation_deg`, `sun_above_horizon` (with the existing `has_sun`, `sun_intensity`), written when `publish_to_environment_sample` is on. **It is ON since TP-05A-04E**; turn it off in the Inspector to remove solar heat again.

## Integration with BodyTemperature (TP-05A-04E)
- One path: `PlayerSurvival` advances `BodyTemperature` (the only time driver) → it asks the providers for a sample → `_integrate()` adds `solar_gain_full_sun × sun_intensity × (1 − shelter_sun_protection)` to heat production. It is added in that single line, so nothing is counted twice; the air-temperature formula contains no sun term.
- Contribution is exactly 0 when: no data (`has_sun` false), the sun is not above the horizon, or the player is in water. Proportional to `sun_intensity` (0..1, clamped).
- Parameter: `BodyTemperature.solar_gain_full_sun` (Inspector, group "Heat production"), initial 300 W, **not final**.
- Simulation of the real model (3 days, 1-minute steps, air 25 ± 5 °C from WorldEnvironmentData, sun from the DayNightCycle elevation curve), core temperature range on the last day:

| solar_gain_full_sun | resting (min / max) | walking (min / max) |
|---|---|---|
| 0 W | 34.67 / 37.10 | 37.38 / 37.60 |
| 100 W | 35.01 / 37.41 | 37.38 / 37.89 |
| 150 W | 35.01 / 37.57 | 37.38 / 38.06 |
| 200 W | 35.01 / 37.73 | 37.38 / 38.22 |
| 300 W | 35.01 / 38.05 | 37.38 / 38.54 |

  With 300 W a resting player reaches Panas (>= 37.8) around noon and a continuously walking player touches Stres panas (>= 38.5). 100-150 W keeps resting at Normal. Pick the value by play-testing.
- Noticed, not changed (outside this task): even without sun, a player resting all night in the placeholder 20 °C air drops to about 34.7 °C (Hipotermia) at dawn, because the stage-1 air defaults (mean 25, swing 5) are below what a resting naked body balances at. Tune `WorldEnvironmentData` or the body parameters if that is unwanted.

**Several providers**: `BodyTemperature` used to take only the first node of group `environment_provider`; with the air-temperature provider and this one that would silently ignore one of them. It now calls every provider in the group (an explicit `set_environment_provider()` still overrides). Rule: a provider fills only its own fields and never resets the sample.

**Limits**: no clouds/weather/shelter (hooks read as neutral), no sun damage, no planet. Intensity is the direct-beam factor only (no atmospheric extinction model).

# The Great Deluge — TP-02: Player & World Interaction Foundation

## Project baseline
- Godot 4 / GDScript / Compatibility renderer (preserved from TP-01)
- Main scene: `res://scenes/world/world.tscn`

## Scene structure
- `scenes/world/world.tscn`: combines the TP-01 world, player, driftwood, HUD, interaction controller, and retained observation camera.
- `scenes/world/island.tscn` + `scripts/world/island.gd`: procedural island mesh plus a generated static HeightMapShape3D collision surface sampled from the same terrain-height function.
- `scenes/player/player.tscn` + `scripts/player/player_controller.gd`: CharacterBody3D, capsule collision, camera pivot, spring arm, and third-person camera.
- `scenes/objects/driftwood.tscn`: collectible test object.
- `scripts/systems/interactable.gd`: reusable inspect/collect object base.
- `scripts/systems/interaction_controller.gd`: center-screen raycast with nearby in-front fallback, line-of-sight check, and prompt handling. It queries only interactable layer 3 and excludes the player body.
- `scenes/ui/player_hud.tscn`: small interaction/control hint.
- `scripts/world/orbit_camera.gd`: retained TP-01 observation camera, inactive during normal play.

## Controls
- WASD: move relative to player/camera facing direction.
- Mouse: rotate player heading and camera pitch.
- Esc: release/capture mouse.
- E: collect the driftwood while looking at it within range.
- Left click: recapture mouse after releasing it.

## Notes
The player uses a capsule collider and the island generates a static concave triangle-mesh collision from its existing mesh. This follows the visible terrain surface more closely than a convex hull. Interactable objects use collision layer 3, separate from the player's layer, so the camera ray can detect them without hitting the player first. The observation camera remains in the world scene but is inactive; the player's third-person camera is active.

The driftwood is a temporary low-poly cylinder. There is no inventory: collecting it only removes it from the scene. The interaction base is deliberately small and can be extended later.

## Validation status
Files and scene references were checked statically. A Godot executable was not available in the build environment, so runtime import/play testing has not been performed here. Please run the project in the target Godot 4 editor and report any debugger errors before treating runtime validation as complete.


### TP-02 Fix 12 — Interaction radius

Jarak deteksi dan jarak interaksi dikurangi menjadi 0,85 meter. Lihat `TP02_INTERACTION_RADIUS_FIX12.md`.


### TP-02 Fix 13 — Interaction radius

Jarak deteksi dan jarak interaksi dinaikkan menjadi 1,5 meter. Mekanisme deteksi Fix 11 tetap dipertahankan. Lihat `TP02_INTERACTION_RADIUS_FIX13.md`.

## TP-02A — First Person Camera
- `scripts/player/first_person_camera.gd` + node `Player/FirstPersonCamera/Camera3D` (inactive; Third Person stays current).
- Exports: `mouse_sensitivity`, `min_pitch_degrees`, `max_pitch_degrees`, `eye_height`, `start_active`.
- Test: set `start_active = true` on the FirstPersonCamera node. Switching key comes in TP-02B (`activate()` / `deactivate()`).

## TP-02B — Camera Switching
- V (`toggle_camera`) toggles First/Third Person; Third Person is the start camera. Logic: `_toggle_camera()` in `player_controller.gd`.
- Yaw is shared via the Player body; pitch is copied between rigs on switch. Body mesh hidden in First Person.

## TP-03D — Unified panel, hotbar, touch controls
- Tab: one panel with Inventory + Crafting tabs (UIState-managed, no pause). C no longer opens crafting.
- Hotbar = inventory slots 1-9 (`hotbar.gd` keeps only the active index). Keys 1-9 / mouse wheel / touch.
- `player_input.gd` is the single input source (keyboard + touch). `touch_controls.gd` shows on mobile (or `show_on_desktop`).
- Android: `export_presets.cfg` has a debug APK preset (arm64). Needs Android SDK, JDK 17, debug keystore and export templates set in Godot Editor Settings.

## Equipment slots UI (visual only)
- Inventory tab: `equipment_view.gd` shows a rotatable 3D placeholder character with 6 equipment + 3 accessory slots around it. Layout data in `equipment_config.gd` (append an entry to add a slot). Not connected to any equip logic.

## TP-04A — World time & day/night
- `world_time.gd` (node WorldTime): 1 game day = 96 real min (15 game s per real s), `time_multiplier`, `set_time()`, `get_time_string()`, signals. Independent of UI/lighting and of pause.
- `day_night_cycle.gd`: moves SunLight and tints WorldEnvironment/sky from keyframes. `clock_hud.gd`: HUD clock (top-right).
- Testing tip: set `time_multiplier` on the WorldTime node (e.g. 60) in the Inspector.

## TP-04B — Night sky, moon, fog, audio, Android camera button
- `lighting_config.gd` (Resource on DayNightCycle.config): night ambient baseline, moonlight, stars, fog scale. Hooks: cloud_attenuation / atmosphere_multiplier / weather_light_multiplier.
- `sky_rig.gd` + `assets/materials/star_dome.gdshader`, `moon_disc.gdshader`: stars + moon (single phase), follow the camera.
- `ambient_audio.gd`: 3 optional looping layers (day, night insects, night calm). No audio assets exist yet: assign streams in the Inspector.
- Android camera button goes through `player_input.gd` (signals), top-right under the inventory button.

## TP-04C — Celestial correction
- Sun disc is now drawn by `SkyRig` (`sun_disc.gdshader`) with its own color; SunLight uses sky_mode LIGHT_ONLY so the light's energy no longer darkens the disc.
- Sun 0.53° / moon 0.52° real angular diameters (LightingConfig); `celestial_size_multiplier` for artistic scaling.

## TP-04C v3
- celestial_size_multiplier 3.5; environment is applied only when a value moved >= environment_change_threshold (0.0015); shader fixes (no reversed smoothstep, glow edge fade, star-vs-disc render order).

## TP-05A-01
PlayerSurvival (scripts/systems/player_survival.gd) node in world.tscn; WorldTime.time_advanced(game_seconds) drives Health/Hunger/Thirst. Logic only, no HUD.

## TP-05A-02
Stamina lives in PlayerSurvival (real-time, set_activity/try_jump from player_controller). SurvivalBars (HUD top-left + Status tab) is signal-driven. Swimming/drowning are hooks only (set_swimming, notify_reached_safe_ground); no swim system exists yet.

## TP-05A-03A
BodyTemperature (heat balance, game-time, 7 categories with Inspector thresholds). Environment comes only through EnvironmentProvider/EnvironmentSample; none exists yet, so neutral conditions are used and get_data_status() reports them unavailable.

## TP-05A-03B
Temperature effects: BodyTemperature computes smooth stage ramps -> multipliers/damage; PlayerSurvival applies them once (hunger/thirst drain, stamina cost/recovery, health) and drives BodyTemperature in lockstep; player speed uses get_movement_multiplier(). Jumps add heat.

## TP-05A-03C
Body temperature in the UI, using the existing HUD and Status tab (no new panel, no pause). HUD: `BodyTemperatureReadout` row under the four bars (enabled by `SurvivalBars.show_temperature`), value in °C + category chip, updated only by `temperature_changed` / `category_changed`. Status tab (in `inventory_panel.gd`): `TemperatureStatusView` shows temperature, category ladder, effects on the player, heat-producing activities, the environment data that really exists (unavailable data is labelled, never invented), and the cause of the current trend. `BodyTemperature` gained two read-only accessors (`get_heat_production()`, `get_environment_sample()`). Shared helpers: `temperature_ui.gd`.

## TP-05A-03D
Integration check of TP-05A-03 (static; no Godot available). No logic defects found; only stale header comments in `body_temperature.gd` and `player_survival.gd` were corrected. Pending the environment stage: a real `EnvironmentProvider` (air temperature, sun, wind, humidity, water, shelter). Water tuning note: with the 25x water conductance, swimming in 10 °C water reaches Hipotermia in about 2 game minutes (~9 real seconds at 1x) - tune when water exists.

## TP-05A-04A
`WorldEnvironmentData` (stage 1): air temperature in °C by position and in-game hour; simple model, optional regions, altitude from world Y. Not weather, not yet an EnvironmentProvider. See docs/WORLD_ENVIRONMENT_DATA.md.

## TP-05A-04A stage 2
`WorldAirTemperatureProvider` (EnvironmentProvider) fills EnvironmentSample.air_temperature from WorldEnvironmentData at the player position; other environment data stay unavailable. BodyTemperature unchanged.

## TP-05A-04B
Region lookup separated from the air-temperature formula: `RegionLocator` (interface), `PlanarRegionLocator`/`PlanarRegionArea` (flat prototype adapter), `TemperatureRegion` = character only. See docs/WORLD_ENVIRONMENT_DATA.md.

## TP-05A-04C
Altitude measurement separated from the air-temperature formula: `AltitudeProvider` (interface) + `FlatAltitudeProvider` (Y - sea_level_y). `sea_level_y` moved to the provider; behavior unchanged. See docs/WORLD_ENVIRONMENT_DATA.md.

## TP-05A-04D stage 1
`SunExposureProvider` reads the live SunLight managed by DayNightCycle (elevation, above-horizon, 0..1 intensity). Publishing to EnvironmentSample is off by default. BodyTemperature now calls all environment providers. See docs/SUN_EXPOSURE.md.

## TP-05A-04E
Sun exposure now feeds BodyTemperature: SunExposureProvider.publish_to_environment_sample = true; BodyTemperature adds solar heat only when has_sun and sun_above_horizon (intensity-proportional, max = solar_gain_full_sun, initial 300 W, not final). See docs/SUN_EXPOSURE.md.

## TP-05A-04F
Calibration of air vs body temperature. Cause: no thermoregulation, so a resting body settles at air + 12 °C (conductance 6.67 W/°C from neutral 25) and follows the 20..30 °C night with a 10.4 h time constant (34.7 °C at dawn). Temporary fix: `BodyTemperature.neutral_air_temperature` 25 -> 22 (night minimum 36.4 °C, cold air still causes hypothermia). Sun gain, air defaults, heat capacity unchanged. Simulation: `tools/body_temperature_sim.py`; report: `docs/TP05A_04F_CALIBRATION.md`.

## TP-05A-05A — Water temperature data foundation
Data only, not connected to BodyTemperature. See `WATER_TEMPERATURE_DATA.md`.

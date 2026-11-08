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

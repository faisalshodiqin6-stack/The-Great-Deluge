# The Great Deluge — TP-01: Core World Foundation

## Project baseline

- Engine family: Godot 4
- Script language: GDScript
- Renderer: Compatibility (`gl_compatibility`)
- Initial target: Web
- Future targets: Windows/Linux and Android
- Feature baseline: Godot 4.3
- Current stage: Core world foundation

Open this folder (the folder containing `project.godot`) in Godot 4. The main scene is configured as `res://scenes/world/world.tscn`.

## World scene structure

- `scenes/world/world.tscn`: main scene that brings the world components together.
- `scenes/world/island.tscn`: temporary island scene.
- `scenes/environment/ocean.tscn`: large, flat ocean surface.
- `scenes/environment/environment.tscn`: procedural sky, ambient environment light, and directional sunlight.
- `scripts/world/island.gd`: generates the island's low-poly grass and sandy shoreline mesh.
- `scripts/world/orbit_camera.gd`: observation camera orbit and zoom controls.

## Controls

- Hold the **right mouse button** and drag to rotate the observation camera.
- Scroll the mouse wheel to zoom in or out.

## Implementation notes

The island is generated from a small grid mesh at runtime; it does not use downloaded assets. The ocean is a single PlaneMesh, and the sky uses Godot's ProceduralSkyMaterial. The directional light has shadows disabled to keep this first prototype lightweight.

This stage intentionally does not include a player, movement, survival systems, inventory, crafting, building, vehicles, wildlife, weather simulation, time/astronomy, or multiplayer.

## Renderer and portability

The project explicitly selects Godot's Compatibility renderer for desktop and mobile. This is a conservative renderer choice for broad hardware coverage and Web deployment, but it does not guarantee that every browser/device will perform equally. Test exported builds on the intended browsers and hardware.

For Web exports, install the matching Godot 4 export templates and configure the Web export preset when ready. Avoid enabling threaded Web export unless the hosting environment supplies the required cross-origin isolation headers. Keep future rendering features within the Compatibility renderer's supported feature set.

For Android, test on actual low- and mid-range devices. For Windows/Linux, Compatibility remains usable; a later renderer change should be a deliberate project-wide decision, not an initialization tweak.

## Version note

`config/features` records Godot 4.3 as the project feature baseline. This is not proof of the exact Godot editor version installed on a developer's computer. Open and validate with the intended Godot 4 Stable installation before production work. Do not upgrade the feature baseline without a reason.

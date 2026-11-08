# The Great Deluge — Project Initialization

## Project baseline

- Engine family: Godot 4
- Script language: GDScript
- Renderer: Compatibility (`gl_compatibility`)
- Initial target: Web
- Future targets: Windows/Linux and Android
- Stage: Initialization only

Open this folder (the folder containing `project.godot`) in Godot 4.

## Structure

- `scenes/`: future scene files, grouped by responsibility.
- `scripts/`: future GDScript code, grouped by responsibility.
- `assets/`: imported source assets.
- `data/`: future authored game data (items, crafting, resources).
- `docs/`: project documentation.

No gameplay scenes, scripts, plugins, external dependencies, or placeholder systems are included.

## Renderer and portability

The project explicitly selects Godot's Compatibility renderer for desktop and mobile. This is the conservative renderer choice for broad hardware coverage and Web deployment. It does not guarantee that every Web browser/device will perform equally; test exported builds on the intended browsers and hardware.

For Web exports, install the matching Godot 4 export templates and configure the Web export preset when ready. Avoid enabling threaded Web export unless the hosting environment supplies the required cross-origin isolation headers. Keep future rendering features within the Compatibility renderer's supported feature set.

For Android, use the Compatibility renderer and test on actual low- and mid-range devices. For Windows/Linux, Compatibility remains usable; a later renderer change should be a deliberate project-wide decision, not an initialization tweak.

## Version note

`config/features` records Godot 4.3 as the project feature baseline and GL Compatibility. Open and validate with the intended Godot 4 Stable installation before production work. Do not upgrade the feature baseline without a reason.

## Not included yet

No player, world, island, ocean, environment, UI, gameplay logic, input mappings, or export presets have been created.

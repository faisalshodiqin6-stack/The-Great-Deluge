# TP-02 Fix 3 — Terrain Collision and Interaction Layers

## What changed
- Replaced the island's convex-hull collision with `mesh.create_trimesh_shape()`. The island is an open terrain surface; a convex hull fills empty space and does not follow its shoreline and slopes accurately.
- Kept terrain collision on physics layer 1, which is the layer the player collides with.
- Reserved physics layer 3 (bit mask `4`) for interactable objects. Driftwood now uses that layer.
- Updated the interaction ray to query only layer 3 and explicitly exclude the player's RID. This prevents the ray from detecting the player's own capsule before reaching the wood.
- Added a player node path to the interaction controller.

## Validation
Static files and scene paths were inspected. A Godot executable is not installed in this build environment, so scene import, physics behavior, and runtime interaction still need to be tested in the Godot editor.

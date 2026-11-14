# TP-02 Fix 9 — Item Placement and Interaction

## Changes
- Moved the driftwood test object to `(3, 8.98, -2)`, within the island's flat central plateau. The plateau top is `Y=9`; the wood mesh/collider are horizontally oriented, so this places their lower edge approximately on the surface.
- Increased the interaction range from 3.5 m to 5.0 m.
- Kept the precise center-screen raycast on physics layer 3.
- Added a fallback search for nearby interactables in front of the camera, limited by proximity and a line-of-sight ray against terrain and item collision layers. This makes the item easier to target while preventing selection through the island.
- Preserved the existing player controller, jump, camera, terrain, and TP-01 scenes.

## Validation
- ZIP integrity and project structure checked.
- Scene paths and interaction collision-layer values inspected statically.
- A Godot runtime is not available in the packaging environment; actual in-editor physics and interaction still require user testing.

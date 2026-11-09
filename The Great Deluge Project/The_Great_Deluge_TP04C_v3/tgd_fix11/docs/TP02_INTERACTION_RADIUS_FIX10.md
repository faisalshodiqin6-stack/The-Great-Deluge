# TP-02 Fix 10 — Interaction radius

Changes based on Fix 9 feedback:
- Increased interaction distance and proximity radius to 5.5 m.
- Centered the proximity query around the player's upper body.
- Widened the forward targeting cone so the object need not be exactly centered.
- Raised the line-of-sight target point to the upper half of the driftwood to reduce terrain occlusion.
- Refreshes the target immediately when E is pressed to avoid stale one-frame targeting.

The terrain, player movement, camera, jump, and driftwood placement are otherwise unchanged.

Validation: source-level inspection and ZIP integrity only. Godot runtime testing was not available in this environment.

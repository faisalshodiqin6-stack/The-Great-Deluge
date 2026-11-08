# TP-02 Fix 13 — Interaction distance

- Increased the proximity detection sphere radius from 0.85 m to 1.5 m.
- Increased the final interaction distance from 0.85 m to 1.5 m.
- Preserved Fix 11 target selection, proximity-query behavior, and input handling.
- Distance is measured from the player interaction center (player position + 1.0 m) to the interactable target point (item position + 0.35 m), not from the visible mesh edge.

Please test in Godot: approach the driftwood and confirm the prompt appears and the item can be collected at a comfortable distance around 1.5 m.

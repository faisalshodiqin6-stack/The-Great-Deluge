# TP-02 Fix 12 — Interaction distance

- Reduced the proximity sphere radius from 3.5 m to 0.85 m.
- Reduced the final interaction distance from 5.5 m to 0.85 m.
- Kept Fix 11 target selection and input handling unchanged.
- Distance is measured from the player interaction center (player position + 1.0 m) to the interactable target point (item position + 0.35 m), not from the visible mesh edge.

Please test in Godot: approach the driftwood slowly and confirm the prompt appears within roughly 85 cm. If the item is unusually large, the visible edge may appear closer than this center-to-center measurement.

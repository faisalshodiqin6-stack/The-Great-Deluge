# TP-02 Spawn and Jump Fix

Changes based on the user's TP-02 Fix 4 project:
- Lowered the initial Player root position from Y=12 to Y=10. The island's center plateau is at Y=9; the capsule's bottom is at the Player root, so this leaves a clear fall/settling gap rather than spawning intersecting the terrain.
- Added Space as the jump input (created at runtime if not already mapped).
- Added an exported `jump_velocity` setting (default 8.5).
- Jump is only triggered while `is_on_floor()` is true; gravity continues while airborne.

Controls:
- WASD: move
- Mouse: camera
- Space: jump
- Esc: release/capture mouse

Validation:
- ZIP integrity checked.
- Godot runtime execution was not available here; please verify spawn and jump in Godot 4.

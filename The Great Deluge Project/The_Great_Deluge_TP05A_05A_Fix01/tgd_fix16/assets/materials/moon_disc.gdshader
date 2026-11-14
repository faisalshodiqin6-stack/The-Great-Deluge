shader_type spatial;
// Moon disc (single fixed phase) with a faint soft glow, on a camera-facing quad.
// Clipped at the true horizon plane through the camera.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_color : source_color = vec3(0.95, 0.96, 1.0);
uniform float disc_radius = 0.2;          // Disc radius in quad space (-1..1).
uniform float glow_strength : hint_range(0.0, 1.0) = 0.1;
uniform float glow_ratio = 2.5;           // Glow radius / disc radius (set by SkyRig).

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float edge = max(fwidth(r), 0.002);
	float disc = 1.0 - smoothstep(disc_radius - edge, disc_radius + edge, r);
	vec2 q = p / disc_radius;
	float maria = 0.92 + 0.08 * sin(q.x * 3.1 + 1.3) * sin(q.y * 2.7 - 0.4);   // Subtle surface detail.
	float glow = exp(-pow(r / (disc_radius * glow_ratio), 2.0)) * glow_strength * (1.0 - disc) * (1.0 - smoothstep(0.7, 1.0, r));
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
	float sin_elevation = (world_pos.y - camera_pos.y) / length(world_pos - camera_pos);
	float above_horizon = smoothstep(-0.0015, 0.0015, sin_elevation);
	ALBEDO = moon_color * (disc * maria + glow);
	ALPHA = clamp(disc + glow, 0.0, 1.0) * alpha * above_horizon;
}

shader_type spatial;
// Sun disc on a camera-facing quad. Its color/brightness are set directly (not
// derived from the light's energy), so it never darkens near the horizon.
// Clipped at the true horizon plane through the camera, so it sinks into it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float disc_radius = 0.2;          // Disc radius in quad space (-1..1).
uniform float glow_strength : hint_range(0.0, 1.0) = 0.3;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float edge = max(fwidth(r), 0.002);
	float disc = 1.0 - smoothstep(disc_radius - edge, disc_radius + edge, r);
	float glow = exp(-pow(r / (disc_radius * 3.0), 2.0)) * glow_strength * (1.0 - disc);
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
	float sin_elevation = (world_pos.y - camera_pos.y) / length(world_pos - camera_pos);
	float above_horizon = smoothstep(-0.0015, 0.0015, sin_elevation);
	ALBEDO = mix(sun_color, vec3(1.0), disc * 0.4);   // Slightly hotter core, never darker.
	ALPHA = clamp(disc + glow, 0.0, 1.0) * alpha * above_horizon;
}

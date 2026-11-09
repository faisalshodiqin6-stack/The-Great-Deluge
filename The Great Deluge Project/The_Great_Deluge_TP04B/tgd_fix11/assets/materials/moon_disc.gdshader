shader_type spatial;
// Small soft moon disc on a camera-facing quad (single fixed phase) with a faint glow.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_color : source_color = vec3(0.92, 0.94, 1.0);

void vertex() {
	// Billboard: always face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float disc = smoothstep(0.5, 0.46, r);
	// Cheap darker "seas" so it does not look like a flat lamp.
	float maria = 0.86 + 0.14 * sin(p.x * 9.0 + 1.3) * sin(p.y * 7.0 - 0.4);
	float glow = exp(-pow(r / 0.85, 2.0) * 4.0) * 0.22;
	ALBEDO = moon_color * (disc * maria + glow);
	ALPHA = clamp(disc + glow, 0.0, 1.0) * alpha;
}

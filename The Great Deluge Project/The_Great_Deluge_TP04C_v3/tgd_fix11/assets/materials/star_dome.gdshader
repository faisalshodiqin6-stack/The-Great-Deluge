shader_type spatial;
// Procedural star field for a sky dome (inside of a sphere). Compatibility-safe:
// no textures, no loops. Stars are sparse, of varied size/brightness, steady (no twinkle).
render_mode unshaded, blend_mix, depth_draw_never, cull_front, fog_disabled;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float cell_scale = 60.0;
uniform float density : hint_range(0.0, 0.1) = 0.02;

varying vec3 dir;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	dir = VERTEX;
}

void fragment() {
	vec3 d = normalize(dir);
	vec3 p = d * cell_scale;
	vec3 cell = floor(p);
	vec3 f = fract(p) - 0.5;
	float present = step(1.0 - density, hash(cell));
	vec3 jitter = vec3(hash(cell + 1.7), hash(cell + 3.1), hash(cell + 5.3)) - 0.5;
	float dist = length(f - jitter * 0.5);
	float size = mix(0.10, 0.26, hash(cell + 9.1));
	float magnitude = mix(0.3, 1.0, hash(cell + 2.2) * hash(cell + 4.4));
	// (edge0 < edge1: reversed smoothstep edges are undefined in GLSL on some mobile GPUs.)
	float star = (1.0 - smoothstep(0.0, size, dist)) * magnitude;
	float horizon = smoothstep(0.03, 0.25, d.y);
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.92, 0.8), hash(cell + 7.7));
	ALBEDO = tint;
	ALPHA = star * present * horizon * intensity;
}

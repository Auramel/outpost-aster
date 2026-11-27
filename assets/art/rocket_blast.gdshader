shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float progress : hint_range(0.0, 1.0) = 0.0;
instance uniform float variation = 0.0;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_at(vec2 point) {
	vec2 cell = floor(point);
	vec2 f = fract(point);
	vec2 weight = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), weight.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + 1.0), weight.x), weight.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float seed = variation * 19.0;
	vec2 drift = vec2(seed, progress * 2.4);
	float broad = noise_at(p * 3.4 + drift);
	float folds = noise_at(p * 8.5 - drift * 0.59);
	float grit = noise_at(p * 23.0 + drift * 1.63);
	float cloud_edge = length(p * vec2(0.90, 0.98)) + (broad - 0.5) * 0.41 + (folds - 0.5) * 0.15;
	float cloud = (1.0 - smoothstep(0.59, 0.91, cloud_edge)) * smoothstep(0.13, 0.73, broad * 0.44 + folds * 0.56);
	cloud *= (1.0 - smoothstep(0.46, 1.0, progress)) * 0.90;

	float fire_edge = length((p - vec2(0.0, 0.16)) * vec2(0.95, 1.17)) + (broad - 0.5) * 0.34 + (grit - 0.5) * 0.10;
	float fire = (1.0 - smoothstep(0.14, 0.70, fire_edge)) * (1.0 - smoothstep(0.06, 0.33, progress));
	float hot = smoothstep(0.42, 0.95, fire + folds * 0.26);
	vec3 flame = mix(vec3(0.98, 0.21, 0.028), vec3(4.3, 2.74, 0.98), hot);
	vec3 smoke = mix(vec3(0.057, 0.051, 0.045), vec3(0.24, 0.18, 0.12), broad * 0.59 + folds * 0.41);
	ALBEDO = mix(smoke, flame, smoothstep(0.07, 0.64, fire));
	ALPHA = max(cloud, fire);
}

shader_type spatial;
render_mode cull_disabled, depth_draw_never, blend_mix;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform bool scorched = false;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float variation = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_at(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 w = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1., 0.)), w.x),
		mix(hash(cell + vec2(0., 1.)), hash(cell + vec2(1., 1.)), w.x), w.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float broad = noise_at(UV * 9.0);
	float flecks = noise_at(UV * 32.0);
	float edge = length(p * vec2(1.0, 1.03)) + (broad - 0.5) * 0.34;
	float pool = 1.0 - smoothstep(0.55, 0.69, edge);
	float angle = atan(p.y, p.x + 0.001);
	float streak = noise_at(vec2(angle * 12.0, 0.37)) * (1.0 - smoothstep(0.74, 0.99, edge));
	float drops = smoothstep(0.58, 0.82, streak * 0.87 + flecks * 0.36);
	ALBEDO = mix(vec3(0.24, 0.102, 0.021), vec3(0.58, 0.30, 0.061), broad);
	ROUGHNESS = mix(0.28, 0.55, flecks);
	SPECULAR = 0.56;
	ALPHA = max(pool * (0.60 + flecks * 0.29), drops * 0.75) * fade;
	if (scorched) {
		float ash = noise_at(UV * 18.0 + variation * 12.0);
		float grit = noise_at(UV * 63.0 + variation * 32.0);
		float contour = length(p * vec2(1.06, 0.93)) + (ash - 0.5) * 0.26 + (broad - 0.5) * 0.24;
		float blackened = 1.0 - smoothstep(0.48, 0.97, contour);
		float chalk = smoothstep(0.42, 0.80, ash * 0.64 + grit * 0.36);
		ALBEDO = mix(vec3(0.023, 0.017, 0.013), vec3(0.19, 0.13, 0.085), chalk);
		ROUGHNESS = 0.96;
		SPECULAR = 0.14;
		float embers = smoothstep(0.80, 0.92, grit * 0.74 + ash * 0.26) * blackened;
		EMISSION = vec3(2.8, 0.40, 0.038) * embers * heat;
		ALPHA = blackened * (0.93 - chalk * 0.42) * fade;
	}
}

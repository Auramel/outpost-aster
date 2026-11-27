shader_type sky;

uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform vec3 sunward = vec3(1.0, 0.0, 0.0);
uniform float daylight = 1.0;
uniform float sunset = 0.0;

float stars(vec3 direction) {
	vec3 cell = floor(direction * 390.0);
	float seed = fract(sin(dot(cell, vec3(127.1, 311.7, 74.7))) * 43758.5453);
	float center = length(fract(direction * 390.0) - 0.5);
	return step(0.997, seed) * (1.0 - smoothstep(0.08, 0.42, center));
}

void sky() {
	vec3 sample_color = texture(panorama, SKY_COORDS).rgb;
	float altitude = max(EYEDIR.y, 0.0);
	float horizon = exp(-9.0 * altitude);
	float sun_angle = max(dot(EYEDIR, sunward), 0.0);
	vec3 night = sample_color * vec3(0.018, 0.032, 0.081) + vec3(0.004, 0.008, 0.021);
	night += vec3(0.034, 0.043, 0.061) * horizon;
	if (!AT_CUBEMAP_PASS) {
		night += vec3(0.65, 0.76, 1.0) * stars(EYEDIR) * smoothstep(0.05, 0.35, altitude) * (1.0 - sunset);
	}
	float moon_angle = max(dot(EYEDIR, -sunward), 0.0);
	night += vec3(0.45, 0.57, 0.83) * (pow(moon_angle, 8600.0) * 1.3 + pow(moon_angle, 240.0) * 0.09);
	vec3 sky_color = mix(night, sample_color, daylight);
	sky_color += sunset * horizon * vec3(0.43, 0.18, 0.056) * (0.41 + 1.10 * pow(sun_angle, 5.0));
	sky_color += vec3(1.0, 0.67, 0.32) * (pow(sun_angle, 24500.0) * 20.0 + pow(sun_angle, 620.0) * 0.52) * smoothstep(-0.035, 0.01, sunward.y);
	COLOR = sky_color;
}

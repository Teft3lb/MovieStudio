shader_type spatial;
render_mode cull_back;

varying vec2 ground_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ground_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float broad = ground_noise(ground_position * 0.17);
	float field = ground_noise(ground_position * 0.82);
	float turf = 1.0 - smoothstep(0.12, 0.78, length(fwidth(ground_position)));
	float fine = ground_noise(ground_position * 12.0) * turf;
	vec3 grass = mix(vec3(0.105, 0.147, 0.082), vec3(0.146, 0.190, 0.103), broad);
	ALBEDO = grass * (0.88 + 0.19 * field + 0.10 * fine);
	ROUGHNESS = 0.89 + 0.10 * field;
	SPECULAR = 0.19;
}

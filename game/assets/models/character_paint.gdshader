shader_type spatial;
render_mode specular_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D grain : source_color, hint_default_white, filter_linear_mipmap;

void fragment() {
	vec3 paint = COLOR.rgb;
	if (OUTPUT_IS_SRGB) {
		paint = mix(12.92 * paint, 1.055 * pow(paint, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), paint));
	}
	ALBEDO = paint * base_color.rgb * texture(grain, UV).rgb;
	ROUGHNESS = 0.9;
}

void light() {
	float angle = dot(normalize(NORMAL), normalize(LIGHT));
	float first = smoothstep(-0.10, -0.035, angle);
	float second = smoothstep(0.48, 0.56, angle);
	float band = 0.12 + 0.52 * first + 0.35 * second;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / PI;
}

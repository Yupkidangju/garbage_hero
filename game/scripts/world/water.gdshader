shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

uniform float flow_speed = 1.0;
varying vec2 water_pos;

void vertex() {
	water_pos = VERTEX.xz;
}

void fragment() {
	float flow = TIME * flow_speed;
	float bend = sin(water_pos.x * .73 + water_pos.y * .24) * .42;
	float ripples = sin(water_pos.y * 5.2 + bend - flow * 1.1);
	float broken = smoothstep(.25, .78, sin(water_pos.x * 2.1 + water_pos.y * .63 + flow * .32));
	float ink = smoothstep(.88, .995, ripples) * broken;
	vec3 paint = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) { paint = pow(paint, vec3(2.2)); }
	ALBEDO = paint * (1.0 + sin(water_pos.x * .34 + water_pos.y * .77 - flow * .23) * .045) + ink * .045;
	ROUGHNESS = 1.0;
}

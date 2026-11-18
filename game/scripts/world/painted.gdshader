shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform vec3 hero = vec3(10000.0);
uniform bool occluding = false;
varying vec3 world_pos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float wash(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash2(i),hash2(i+vec2(1.0,0.0)),f.x),
		mix(hash2(i+vec2(0.0,1.0)),hash2(i+vec2(1.0)),f.x),f.y);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	if (occluding) {
		vec3 p = world_pos - (hero + vec3(0.0,0.8,0.0));
		vec3 ray = normalize(INV_VIEW_MATRIX[2].xyz);
		float depth = dot(p,ray);
		float radius = length(p - ray*depth);
		float fade = (1.0-smoothstep(0.5,1.3,radius))*smoothstep(0.0,1.3,depth);
		if (hash2(mod(floor(FRAGCOORD.xy),5.0)) < fade * 0.8) { discard; }
	}
	vec2 grain = world_pos.xz + world_pos.y*vec2(0.28,0.92);
	float pigment = wash(grain*1.7)*0.050 + wash(grain*vec2(11.0,3.5))*0.038;
	vec3 paint = COLOR.rgb;
	// Compatibility renders vertex colors in display space. Forward+ works in linear light.
	if (!OUTPUT_IS_SRGB) { paint = pow(paint,vec3(2.2)); }
	ALBEDO = paint * (0.956 + pigment);
	ROUGHNESS = 1.0;
}

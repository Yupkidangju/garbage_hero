shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.055, 0.043, 0.036);
	ALPHA = 0.34 * (1.0 - smoothstep(0.23, 1.0, radius));
}

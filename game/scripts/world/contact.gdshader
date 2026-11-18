shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	ALBEDO = OUTPUT_IS_SRGB ? vec3(.23,.25,.22) : vec3(.044,.051,.039);
	ALPHA = COLOR.a;
}

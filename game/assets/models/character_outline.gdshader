shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

void vertex() {
	// 투영 크기에 맞춰 폭을 제한해 가까이에서 얼굴의 선이 두꺼워지지 않게 한다.
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * view_pos;
	vec3 n_view = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 pixel_step = 2.0 / VIEWPORT_SIZE;
	vec2 screen_normal = n_view.xy / max(0.2, length(n_view.xy));
	vec4 physical_limit = PROJECTION_MATRIX * vec4(n_view.xy * 0.012, 0.0, 0.0);
	vec2 desired = screen_normal * pixel_step * 0.82 * clip.w;
	clip.xy += sign(desired) * min(abs(desired), abs(physical_limit.xy));
	POSITION = clip;
}

void fragment() {
	ALBEDO = OUTPUT_IS_SRGB ? vec3(0.13, 0.16, 0.17) : vec3(0.015, 0.022, 0.025);
}

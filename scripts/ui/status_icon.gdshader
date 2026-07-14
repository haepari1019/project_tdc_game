shader_type spatial;
// 디버프 코인 아이콘 — 색 원판 + 12시부터 시계방향 회색 부채꼴(경과분)로 잔여시간 표시.
// progress: 0(갓 걸림) → 1(만료 임박). enemy_unit이 status_list.ratio를 넣는다. ref: overhead_status_icons.gd.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);
	if (d > 0.5) { discard; }          // 원판 밖 = 투명(코인 형태)
	vec3 col = color.rgb;
	if (d > 0.42) { col *= 0.4; }      // 테두리 링(어둡게)
	float ang = atan(uv.x, -uv.y);     // 12시에서 0, 시계방향 증가
	if (ang < 0.0) { ang += 6.28318530718; }
	if (ang / 6.28318530718 <= progress) {
		col = mix(col, vec3(0.05, 0.05, 0.06), 0.72);   // 경과 부채꼴 = 회색 오버레이
	}
	ALBEDO = col;
	ALPHA = 1.0;
}

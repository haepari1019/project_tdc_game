shader_type spatial;
// Enemy vision UNION overlay — one ground quad samples the pre-merged top-down threat mask by
// WORLD XZ (from MODEL_MATRIX, no depth reconstruction) and tints the floor. The mask already
// merged all enemies' cones, so there is no overlapping translucent geometry on screen → no
// z-fighting, no alpha-stacking. mask.rgb = zone colour (red combat / yellow alert), mask.a =
// coverage. ref: vision cone union.
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform sampler2D threat_tex : filter_linear;
uniform vec2 bounds_min;                 // world (x,z) of the mask's min corner
uniform vec2 bounds_size;                // world (x,z) span
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.16;  // ground tint strength

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (v_world.xz - bounds_min) / bounds_size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;
	}
	vec4 t = texture(threat_tex, uv);
	if (t.a < 0.02) {
		discard;  // outside every cone
	}
	ALBEDO = t.rgb;
	ALPHA = t.a * overlay_alpha;
}

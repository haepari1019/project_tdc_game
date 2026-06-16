shader_type spatial;
// Enemy vision UNION overlay — one ground quad samples the GPU-lit threat mask (sector lights +
// wall occluders, computed in a SubViewport) by WORLD XZ (from MODEL_MATRIX, no depth) and tints
// the floor. The mask is lit per-pixel and shadow-clipped at walls on the GPU, so cone edges are
// precise + move smoothly (no discrete-raycast trembling). The tint is GATED by the party's
// CURRENT line-of-sight (vis_tex) so cones only appear where the party can see NOW — never in the
// explored/grey memory. mask.rgb = zone colour × soft intensity. ref: vision cone union (GPU).
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform sampler2D threat_tex : filter_linear;
uniform vec2 bounds_min;                 // cone mask world (x,z) min
uniform vec2 bounds_size;                // cone mask world (x,z) span
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.03;

// Party CURRENT-visibility gate (the fog's live LOS texture). vis_gate 0 = no gating (fallback).
uniform sampler2D vis_tex : filter_linear;
uniform vec2 vis_bounds_min;
uniform vec2 vis_bounds_size;
uniform float vis_gate = 0.0;
uniform float vis_lo = 0.30;
uniform float vis_hi = 0.60;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (v_world.xz - bounds_min) / bounds_size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;
	}
	vec3 c = texture(threat_tex, uv).rgb;
	float b = max(c.r, max(c.g, c.b));   // lit brightness = cone coverage (soft at edges)
	if (b < 0.02) {
		discard;
	}
	// Gate by the party's CURRENT line of sight — cones never show in explored/unseen areas.
	float seen = 1.0;
	if (vis_gate > 0.5) {
		vec2 vuv = (v_world.xz - vis_bounds_min) / vis_bounds_size;
		seen = 0.0;
		if (vuv.x >= 0.0 && vuv.x <= 1.0 && vuv.y >= 0.0 && vuv.y <= 1.0) {
			seen = smoothstep(vis_lo, vis_hi, texture(vis_tex, vuv).r);
		}
	}
	if (seen < 0.01) {
		discard;
	}
	ALBEDO = c / b;                       // recover the pure zone colour (red/yellow)
	ALPHA = b * overlay_alpha * seen;     // faint, and only where currently visible
}

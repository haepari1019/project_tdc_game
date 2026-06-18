shader_type spatial;
// F-011 vision fog — attached as a next_pass on world geometry (floors/walls/obstacles).
// THREE states, sampled by WORLD XZ from MODEL_MATRIX (NO depth reconstruction):
//   • currently visible (cur_tex high)            → no fog (discard, base shows lit)
//   • seen before but not now (exp_tex high)      → achromatic, near-normal brightness (mem_dim)
//   • never reached (exp_tex low)                 → dark (dark_dim)
// Occluded colour is the desaturated (grayscale) screen colour, so it reads as low-saturation
// rather than tinted. Both masks are blurred 3x3 in-shader so edges are smooth regardless of
// the fog texture resolution. exp_tex is the monotonic "ever seen" accumulator. ref: F-011.
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D cur_tex : filter_linear;   // current party line-of-sight
uniform sampler2D exp_tex : filter_linear;   // explored (ever seen) — accumulated
uniform vec2 bounds_min;                     // world (x,z) of the fog field's min corner
uniform vec2 bounds_size;                     // world (x,z) span
uniform float vis_lo = 0.25;                 // mask threshold lo
uniform float vis_hi = 0.70;                 // mask threshold hi (wide band = soft edge)
uniform float edge_blur : hint_range(0.0, 4.0) = 1.5;   // mask blur radius in texels (anti-stairstep)
uniform float mem_dim : hint_range(0.0, 1.5) = 0.9;     // explored brightness — near-normal, achromatic
uniform float dark_dim : hint_range(0.0, 1.0) = 0.0;    // never-reached FLOOR — flat (NOT luminance-scaled),
                               // so bright/emissive props (lanterns) are fully hidden in unseen rooms. 0 = black.
uniform float occluded_lum_cap : hint_range(0.0, 1.0) = 0.3;  // clamp source luminance in EXPLORED-memory areas
                               // so remembered bright props read as a dim grey, not a glowing beacon. (Never-reached
                               // is flat dark_dim; currently-visible is discarded — both unaffected by this cap.)

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 3x3 gaussian-ish blur of a mask → smooth edge independent of fog resolution.
// (Godot shaders can't take a sampler as a function arg, so one blur fn per mask.)
float blur_cur(vec2 uv) {
	vec2 ts = edge_blur / vec2(textureSize(cur_tex, 0));
	float s = texture(cur_tex, uv).r * 4.0;
	s += texture(cur_tex, uv + vec2( ts.x, 0.0)).r * 2.0;
	s += texture(cur_tex, uv + vec2(-ts.x, 0.0)).r * 2.0;
	s += texture(cur_tex, uv + vec2(0.0,  ts.y)).r * 2.0;
	s += texture(cur_tex, uv + vec2(0.0, -ts.y)).r * 2.0;
	s += texture(cur_tex, uv + ts).r;
	s += texture(cur_tex, uv - ts).r;
	s += texture(cur_tex, uv + vec2(ts.x, -ts.y)).r;
	s += texture(cur_tex, uv + vec2(-ts.x, ts.y)).r;
	return s / 16.0;
}

float blur_exp(vec2 uv) {
	vec2 ts = edge_blur / vec2(textureSize(exp_tex, 0));
	float s = texture(exp_tex, uv).r * 4.0;
	s += texture(exp_tex, uv + vec2( ts.x, 0.0)).r * 2.0;
	s += texture(exp_tex, uv + vec2(-ts.x, 0.0)).r * 2.0;
	s += texture(exp_tex, uv + vec2(0.0,  ts.y)).r * 2.0;
	s += texture(exp_tex, uv + vec2(0.0, -ts.y)).r * 2.0;
	s += texture(exp_tex, uv + ts).r;
	s += texture(exp_tex, uv - ts).r;
	s += texture(exp_tex, uv + vec2(ts.x, -ts.y)).r;
	s += texture(exp_tex, uv + vec2(-ts.x, ts.y)).r;
	return s / 16.0;
}

void fragment() {
	vec2 uv = (v_world.xz - bounds_min) / bounds_size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;  // outside the fog field = visible
	}
	float vis = smoothstep(vis_lo, vis_hi, blur_cur(uv));  // 1 = currently visible
	if (vis > 0.98) {
		discard;  // currently visible → base material shows through, fully lit
	}
	float mem = smoothstep(vis_lo, vis_hi, blur_exp(uv));  // 1 = explored (ever seen)
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(base, vec3(0.299, 0.587, 0.114));        // luminance (desaturate)
	g = min(g, occluded_lum_cap);                          // tame bright sources in REMEMBERED areas (lanterns)
	// seen-before → achromatic at near-normal brightness (almost like the live view, just grey);
	// never-reached → FLAT floor (not luminance-scaled) so nothing — incl. bright props — peeks through.
	vec3 mem_col = vec3(g) * mem_dim;
	vec3 dark_col = vec3(dark_dim);
	vec3 fog_col = mix(dark_col, mem_col, mem);
	ALBEDO = fog_col;
	ALPHA = 1.0 - vis;                                     // soft fade toward the visible edge
}

shader_type spatial;
// F-011 vision fog — attached as a next_pass on world geometry (floors/walls/obstacles).
// Occluded fragments are DESATURATED toward grayscale (low-saturation, lightly dimmed) rather
// than painted dark — it reads the already-lit colour from the screen texture and greys it.
// The visibility mask (fog_tex) is the 2D party-LOS texture, sampled by WORLD XZ from
// MODEL_MATRIX (NO depth reconstruction). The mask is BLURRED in-shader (3x3) so the line-of-
// sight edge is smooth regardless of the fog texture's resolution — kills the stairstepping.
// Fully-visible fragments discard. ref: F-011.
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D fog_tex : filter_linear;
uniform vec2 bounds_min;                 // world (x,z) of the fog field's min corner
uniform vec2 bounds_size;                // world (x,z) span
uniform float vis_lo = 0.25;             // below = fully occluded
uniform float vis_hi = 0.70;             // above = fully visible (wide band = soft edge)
uniform float edge_blur : hint_range(0.0, 4.0) = 1.5;   // mask blur radius in texels (anti-stairstep)
uniform float desaturate : hint_range(0.0, 1.0) = 1.0;  // 1 = full grayscale in occluded areas
uniform float dim : hint_range(0.0, 1.0) = 0.65;        // occluded brightness (1 = no darkening)

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 3x3 gaussian-ish blur of the visibility mask → smooth edge independent of fog resolution.
float sample_vis(vec2 uv) {
	vec2 ts = edge_blur / vec2(textureSize(fog_tex, 0));
	float s = texture(fog_tex, uv).r * 4.0;
	s += texture(fog_tex, uv + vec2( ts.x, 0.0)).r * 2.0;
	s += texture(fog_tex, uv + vec2(-ts.x, 0.0)).r * 2.0;
	s += texture(fog_tex, uv + vec2(0.0,  ts.y)).r * 2.0;
	s += texture(fog_tex, uv + vec2(0.0, -ts.y)).r * 2.0;
	s += texture(fog_tex, uv + ts).r;
	s += texture(fog_tex, uv - ts).r;
	s += texture(fog_tex, uv + vec2(ts.x, -ts.y)).r;
	s += texture(fog_tex, uv + vec2(-ts.x, ts.y)).r;
	return s / 16.0;
}

void fragment() {
	vec2 uv = (v_world.xz - bounds_min) / bounds_size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;  // outside the fog field = visible (no border darkening)
	}
	float vis = sample_vis(uv);
	float occ = 1.0 - smoothstep(vis_lo, vis_hi, vis);  // 0 visible .. 1 occluded (soft)
	if (occ < 0.02) {
		discard;  // fully visible → base material shows through, no fill / screen-read cost
	}
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;     // the lit colour already drawn here
	float g = dot(base, vec3(0.299, 0.587, 0.114));     // luminance
	vec3 fogged = mix(base, vec3(g), desaturate) * dim; // desaturate + slight dim
	ALBEDO = fogged;
	ALPHA = occ;                                         // soft blend base -> grayscale over the edge
}

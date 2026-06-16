shader_type canvas_item;
// F-011 explored accumulator — drawn every frame into the never-cleared "explored" viewport
// with ADD blend. Only pixels CLEARLY in line of sight (current visibility > thresh) count as
// "seen", so the soft far edge of the sight light doesn't slowly creep huge unseen areas into
// the explored map. Output is binary (0/1); ADD accumulates it into a monotonic union. F-011.
render_mode blend_add;

uniform float thresh : hint_range(0.0, 1.0) = 0.7;   // only STRONGLY-lit (clear, central LOS) counts
uniform float rate : hint_range(0.0, 1.0) = 0.06;    // per-frame increment → needs SUSTAINED view to
                                                      // mark explored (a 1-2 frame glimpse/streak won't)

void fragment() {
	float v = texture(TEXTURE, UV).r;
	float seen = step(thresh, v);
	COLOR = vec4(vec3(seen * rate), 1.0);
}

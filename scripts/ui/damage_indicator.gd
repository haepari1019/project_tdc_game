extends Control
## Directional damage indicator — a soft red glow hugging the screen edge in the
## direction an incoming hit came FROM (toward the attacker), for the controlled
## character. Severity-scaled, quick fade, same-direction debounce. Procedural draw
## (no assets, matches the PH aesthetic), mouse-transparent overlay.
## Fed by dungeon_run (CombatController.party_hit → screen-space dir). ref: F-011 HUD.

const COL := Color(0.92, 0.06, 0.06)
const FADE_S := 0.7          # one flash lifetime
const SPREAD_DEG := 38.0     # arc half-width along the edge
const DEPTH_FRAC := 0.16     # how far inward the glow reaches (frac of min screen dim)
const MERGE_DOT := 0.85      # refresh an existing flash from a similar direction

var _hits: Array = []  # [{dir: Vector2 (screen, normalized), strength: float, t: float}]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## screen_dir = on-screen direction toward the attacker (already camera-yaw adjusted).
func flash(screen_dir: Vector2, severity: float) -> void:
	if screen_dir.length() < 0.001:
		return
	var d := screen_dir.normalized()
	var s := clampf(severity, 0.0, 1.0)
	for h in _hits:
		if (h.dir as Vector2).dot(d) > MERGE_DOT:  # same direction → refresh, don't stack
			h.dir = d
			h.strength = maxf(h.strength, s)
			h.t = 0.0
			queue_redraw()
			return
	_hits.append({"dir": d, "strength": s, "t": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	if _hits.is_empty():
		return
	for h in _hits:
		h.t += delta
	_hits = _hits.filter(func(h): return h.t < FADE_S)
	queue_redraw()


func _draw() -> void:
	if _hits.is_empty():
		return
	# Use the viewport rect, not self.size — a code-created Control under a CanvasLayer
	# may report size 0 (no layout pass), which would draw everything at (0,0).
	var sz := get_viewport_rect().size
	var center := sz * 0.5
	var hw := sz.x * 0.5
	var hh := sz.y * 0.5
	var depth := minf(sz.x, sz.y) * DEPTH_FRAC
	var spread := deg_to_rad(SPREAD_DEG)
	var steps := 12
	for h in _hits:
		var a: float = float(h.strength) * (1.0 - float(h.t) / FADE_S)
		if a <= 0.003:
			continue
		var base_ang: float = (h.dir as Vector2).angle()
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var ocol := PackedColorArray()
		for i in steps + 1:
			var f := float(i) / float(steps)
			var off := lerpf(-1.0, 1.0, f)         # -1..1 across the arc
			var ang := base_ang + off * spread
			var d := Vector2(cos(ang), sin(ang))
			# distance from center to the screen border along this ray
			var t := minf(hw / maxf(absf(d.x), 0.0001), hh / maxf(absf(d.y), 0.0001))
			var edge := center + d * t
			outer.append(edge)
			inner.append(edge - d * depth)
			ocol.append(Color(COL.r, COL.g, COL.b, a * (1.0 - absf(off))))  # fade at arc ends
		# band polygon: outer arc (strong) left→right, then inner arc (transparent) right→left
		var poly := PackedVector2Array()
		var cols := PackedColorArray()
		for i in outer.size():
			poly.append(outer[i])
			cols.append(ocol[i])
		for i in range(inner.size() - 1, -1, -1):
			poly.append(inner[i])
			cols.append(Color(COL.r, COL.g, COL.b, 0.0))
		draw_polygon(poly, cols)

extends Control
## Minimap — top-right HUD (above the quest tracker). Fixed world-aligned orientation
## (+X right, +Z up): room footprints + extraction marker + interactable markers (chest/
## door/drops) + the player dot with a facing line. Reads the map's decoupled room-rect
## interface (get_room_rects), so a Blender map works unchanged. ref: UI minimap.

const PANEL_W := 286.0
const PANEL_H := 160.0
const MARGIN := 12.0
const PAD := 12.0   # inner padding inside the panel

const C_BG := Color(0.05, 0.06, 0.08, 0.74)
const C_BORDER := Color(0.40, 0.43, 0.52, 0.55)
const C_ROOM := Color(0.22, 0.24, 0.30, 0.95)
const C_ROOM_EDGE := Color(0.46, 0.49, 0.57)
const C_EXTRACT := Color(0.34, 0.90, 0.45)
const C_INTERACT := Color(0.95, 0.82, 0.30)
const C_PLAYER := Color(0.32, 0.78, 1.0)

var _map: Node = null
var _party: Node = null
var _rects: Array = []          # [{center: Vector3, size: Vector3}]
var _wmin := Vector2.ZERO       # world XZ bounds
var _wmax := Vector2.ZERO


func setup(map: Node, party: Node) -> void:
	_map = map
	_party = party
	if _map and _map.has_method("get_room_rects"):
		_rects = _map.get_room_rects()
	_compute_bounds()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(PANEL_W + MARGIN)
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_bottom = MARGIN + PANEL_H
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()  # player + interactables move


func _compute_bounds() -> void:
	if _rects.is_empty():
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for r: Dictionary in _rects:
		var c: Vector3 = r["center"]
		var s: Vector3 = r["size"]
		mn.x = minf(mn.x, c.x - s.x * 0.5)
		mn.y = minf(mn.y, c.z - s.z * 0.5)
		mx.x = maxf(mx.x, c.x + s.x * 0.5)
		mx.y = maxf(mx.y, c.z + s.z * 0.5)
	_wmin = mn
	_wmax = mx


## World XZ → minimap-local px, fit-to-panel + centered. X is flipped and +Z maps to
## up so the minimap matches the default top-down view (was left-right mirrored).
func _w2m(wx: float, wz: float) -> Vector2:
	var span := _wmax - _wmin
	if span.x < 0.01 or span.y < 0.01:
		return size * 0.5
	var inner := size - Vector2(PAD, PAD) * 2.0
	var sc := minf(inner.x / span.x, inner.y / span.y)
	var wc := (_wmin + _wmax) * 0.5
	return Vector2(size.x * 0.5 - (wx - wc.x) * sc, size.y * 0.5 - (wz - wc.y) * sc)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), C_BORDER, false, 1.0)
	if _rects.is_empty():
		return
	# Room footprints.
	for r: Dictionary in _rects:
		var c: Vector3 = r["center"]
		var s: Vector3 = r["size"]
		var a := _w2m(c.x - s.x * 0.5, c.z + s.z * 0.5)
		var b := _w2m(c.x + s.x * 0.5, c.z - s.z * 0.5)
		var rect := Rect2(a, b - a).abs()  # corner order flips with the X mirror
		draw_rect(rect, C_ROOM, true)
		draw_rect(rect, C_ROOM_EDGE, false, 1.0)
	# Extraction point.
	if _map and _map.has_method("get_extraction_position"):
		var ep: Vector3 = _map.get_extraction_position()
		draw_circle(_w2m(ep.x, ep.z), 4.0, C_EXTRACT)
	# Interactables (chest / door / drops).
	for n in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(n) and n is Node3D:
			var ip: Vector3 = (n as Node3D).global_position
			draw_circle(_w2m(ip.x, ip.z), 2.6, C_INTERACT)
	# Player (controlled) + facing line.
	if _party and _party.has_method("get_controlled"):
		var ctrl: Node3D = _party.get_controlled()
		if ctrl and is_instance_valid(ctrl):
			var pm := _w2m(ctrl.global_position.x, ctrl.global_position.z)
			draw_circle(pm, 4.6, Color(1, 1, 1, 0.9))  # white ring
			draw_circle(pm, 3.2, C_PLAYER)
			var v: Vector3 = ctrl.velocity
			v.y = 0.0
			if v.length() > 0.5:
				var nv := v.normalized() * 2.5
				var tip := _w2m(ctrl.global_position.x + nv.x, ctrl.global_position.z + nv.z)
				draw_line(pm, tip, Color(1, 1, 1, 0.9), 1.5)

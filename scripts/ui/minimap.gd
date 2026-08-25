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
const C_KEY := Color(0.98, 0.86, 0.25)     # 열쇠가 나오는 상자 — 「어디서 나오나」의 답
const C_LOCK := Color(0.85, 0.35, 0.30)    # 잠긴 문 — 어디가 막혔나
const C_PLAYER := Color(0.32, 0.78, 1.0)
const C_BATTLE := Color(0.95, 0.35, 0.25)   # 제3세력 교전 흔적(F-028 §3.3 — 멀리서 정보·기회)
const C_STAIRS := Color(0.72, 0.62, 0.98)   # 계단(레이어 전이) — 층을 옮기는 유일한 지점
const C_LAYER_TXT := Color(0.86, 0.88, 0.94, 0.92)
const THIRD_FACTION_TAG := "Third"          # combat_controller.THIRD_FACTION_NAME과 동일

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


## **활성 층의 방만** 그린다. 층이 XZ를 공유하므로 전부 그리면 겹쳐서 「지금 어느 층인지」를
## 잃는다 — 스펠렁키식 백레이어가 읽히는 이유의 절반은 back layer가 **작고 명확**했기 때문이다.
## 층 정보가 없는 맵(레거시)은 전부 layer 0으로 읽혀 동작이 그대로다.
func visible_rects() -> Array:
	var active: int = int(_map.get_active_layer()) if _map != null and _map.has_method("get_active_layer") else 0
	var out: Array = []
	for r: Dictionary in _rects:
		if int(r.get("layer", 0)) == active:
			out.append(r)
	return out


## 활성 층의 계단 앵커 위치들 — 「어디로 층을 옮길 수 있나」가 미니맵에 보여야 한다.
func stairs_positions() -> Array:
	var out: Array = []
	if _map == null or not _map.has_method("get_all_anchors"):
		return out
	var active: int = int(_map.get_active_layer()) if _map.has_method("get_active_layer") else 0
	for a in _map.get_all_anchors("transitions"):
		var d := a as Dictionary
		if String(d.get("role", "")) != "stairs":
			continue
		if int(_map.get_room_layer(String(d.get("room_ref", "")))) != active:
			continue
		out.append(d["pos"])
	return out


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
	# Room footprints — **활성 층만**.
	for r: Dictionary in visible_rects():
		var c: Vector3 = r["center"]
		var s: Vector3 = r["size"]
		var a := _w2m(c.x - s.x * 0.5, c.z + s.z * 0.5)
		var b := _w2m(c.x + s.x * 0.5, c.z - s.z * 0.5)
		var rect := Rect2(a, b - a).abs()  # corner order flips with the X mirror
		draw_rect(rect, C_ROOM, true)
		draw_rect(rect, C_ROOM_EDGE, false, 1.0)
	# Extraction point.
	if _map and _map.has_method("get_extraction_points"):
		# 탈출 지점은 여럿일 수 있다 — 하나만 그리면 나머지가 **없는 것처럼** 보인다.
		for e in _map.get_extraction_points(true):
			_draw_extraction((e as Dictionary)["pos"])
	elif _map and _map.has_method("get_extraction_position"):
		_draw_extraction(_map.get_extraction_position())
	# **뜻 있는 것만 그린다.** 예전엔 그룹 `interactable` 전체를 같은 노란 점으로 찍었는데,
	# 횃불·배럴·루트 상자·문·계단·탈출대가 전부 섞여 **무엇을 뜻하는지 알 수 없는 점 무리**가 됐다
	# (사용자: 「뭔지 모르겠고 필요도 없는 것 같음」). 미니맵에 남을 자격은 **길을 정하는 것**뿐이다:
	#   ① 열쇠가 나오는 상자 — 「열쇠가 어디서 나오는지 특정되지 않아 불편하다」의 답이다
	#   ② 잠긴 문 — 어디가 막혔는지
	# 탈출대·계단은 위에서 이미 자기 마커로 그린다.
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (is_instance_valid(n) and n is Node3D):
			continue
		var ip: Vector3 = (n as Node3D).global_position
		if ("yields" in n) and not String(n.get("yields")).is_empty():
			_draw_key(_w2m(ip.x, ip.z))
		elif ("rule" in n) and ("key_id" in n) and not bool(n.get("_opened") if "_opened" in n else false):
			draw_circle(_w2m(ip.x, ip.z), 2.4, C_LOCK)
	# S5b P3b — 제3세력 교전 단서: engaged 제3세력(faction "Third") 위치에 적색 마커(멀리서 "저기서 싸운다"
	# 정보). 몬스터 위치는 표시 안 함(포그 유지) — 3세력만 흔적으로 노출(F-028 §3.3).
	for n in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(n) and n is Node3D and bool(n.engaged) and String(n.faction) == THIRD_FACTION_TAG:
			var bp := _w2m((n as Node3D).global_position.x, (n as Node3D).global_position.z)
			draw_circle(bp, 4.6, Color(C_BATTLE.r, C_BATTLE.g, C_BATTLE.b, 0.32))
			draw_circle(bp, 2.4, C_BATTLE)
	# 계단(레이어 전이) 마커 — 활성 층에서 층을 옮길 수 있는 지점.
	for sp in stairs_positions():
		var s2 := _w2m((sp as Vector3).x, (sp as Vector3).z)
		draw_rect(Rect2(s2 - Vector2(3, 3), Vector2(6, 6)), C_STAIRS, true)
		draw_rect(Rect2(s2 - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, 0.6), false, 1.0)
	# 층 표시 — **여러 층이 있는 맵에서만** 띄운다(단층 맵에 노이즈를 얹지 않는다).
	if _map != null and _map.has_method("layers_present") and (_map.layers_present() as Array).size() > 1:
		var active2: int = int(_map.get_active_layer())
		var label := "지상" if active2 == 0 else "지하 %d" % active2
		var font := get_theme_default_font()
		if font != null:
			draw_string(font, Vector2(PAD, PAD + 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_LAYER_TXT)
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


func _draw_extraction(ep: Vector3) -> void:
	draw_circle(_w2m(ep.x, ep.z), 4.0, C_EXTRACT)


## 열쇠 표시 — 점이 아니라 **마름모**로 그려 다른 마커와 구별된다.
func _draw_key(p: Vector2) -> void:
	var r := 3.4
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), C_KEY)

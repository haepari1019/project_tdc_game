extends MeshInstance3D
## MovePathOverlay — RMB 이동 오더의 예상 경로를 지면 위 **점선**으로 그린다.
## 오더를 들고 있는 모든 파티원을 한 번에 그리되, 조작 중인 캐릭터만 진하게(나머지는 흐리게)
## — 여러 명을 각기 다른 위치로 보내는 기능이라 전체 배치가 한눈에 보여야 한다.
##
## 경로는 새로 계산하지 않는다. party_member 가 이미 NavigationServer3D 로 뽑아 캐시해 둔
## `_nav_path`(nav_path_remaining)를 `_nav_path_idx`부터 재사용하므로 오버레이 비용은 렌더뿐이다.
## 색은 F-003 §3.5.3의 "연두색 점선 이동선" 규정을 따른다. ref: DRIFT-090.
##
## dungeon_run / combat_sandbox 양쪽에서 setup(party) 로 붙인다(sandbox-input-parity).

const DASH_LEN := 0.45      # 대시 한 칸 길이(m)
const GAP_LEN := 0.30       # 대시 사이 간격(m)
const GROUND_Y := 0.06      # 지면 z-fighting 회피용 띄움
const COLOR_ACTIVE := Color(0.55, 1.0, 0.45, 0.95)   # 조작캐 — 연두, 진하게
const COLOR_IDLE := Color(0.55, 1.0, 0.45, 0.32)     # 그 외 오더 보유 멤버 — 같은 색, 흐리게
const END_MARK_R := 0.35    # 목적지 표시 원 반지름
const END_MARK_SEGS := 12

var _party: Node3D = null
var _im: ImmediateMesh = null


func setup(party: Node3D) -> void:
	_party = party


func _ready() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	top_level = true           # 부모 변환 무시 — 월드 좌표를 그대로 쓴다
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true   # 벽/지형에 묻히지 않게(탑다운에서 경로는 항상 읽혀야 한다)
	mat.disable_receive_shadows = true
	material_override = mat


func _process(_delta: float) -> void:
	if _im == null:
		return
	_im.clear_surfaces()
	if _party == null or not is_instance_valid(_party):
		return
	var any := false
	for m in _party.get_members():
		if not is_instance_valid(m) or not m.has_method("has_move_order"):
			continue
		if not m.has_move_order():
			continue          # HOLD/NONE = 진행 중인 경로 없음 → 표시 안 함
		if m.has_method("is_alive") and not m.is_alive():
			continue
		if not any:
			_im.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		var col: Color = COLOR_ACTIVE if m.is_controlled() else COLOR_IDLE
		_draw_member_path(m, col)
	if any:
		_im.surface_end()


## 멤버의 현재 위치 → 남은 웨이포인트들 → 최종 목적지를 하나의 폴리라인으로 잇고,
## 그 위에 일정 간격 대시를 얹는다. 목적지에는 작은 원 마커.
func _draw_member_path(m: Node3D, col: Color) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	pts.append(m.global_position)
	if m.has_method("nav_path_remaining"):
		for wp in m.nav_path_remaining():
			pts.append(wp)
	var goal: Vector3 = m.order_target()
	if pts.size() == 0 or pts[pts.size() - 1].distance_to(goal) > 0.05:
		pts.append(goal)
	# 폴리라인 전체를 하나의 연속 길이로 보고 대시를 얹어야 세그먼트 경계에서 리듬이 끊기지 않는다.
	var carry := 0.0   # 이번 세그먼트 시작 시점의 대시 주기 내 위상
	for i in pts.size() - 1:
		carry = _dash_segment(pts[i], pts[i + 1], col, carry)
	_draw_ring(goal, col)


## a→b 구간에 대시를 얹는다. `phase` = 구간 시작 시 대시 주기(DASH_LEN+GAP_LEN) 내 위치.
## 반환 = 다음 구간이 이어받을 위상.
func _dash_segment(a: Vector3, b: Vector3, col: Color, phase: float) -> float:
	var period := DASH_LEN + GAP_LEN
	var flat_a := Vector3(a.x, GROUND_Y, a.z)
	var flat_b := Vector3(b.x, GROUND_Y, b.z)
	var seg := flat_b - flat_a
	var len_seg := seg.length()
	if len_seg < 0.001:
		return phase
	var dir := seg / len_seg
	var t := -phase          # 현재 주기의 대시 시작 위치(음수면 이전 구간에서 이어짐)
	while t < len_seg:
		var s: float = maxf(t, 0.0)
		var e: float = minf(t + DASH_LEN, len_seg)
		if e > s:
			_im.surface_set_color(col)
			_im.surface_add_vertex(flat_a + dir * s)
			_im.surface_set_color(col)
			_im.surface_add_vertex(flat_a + dir * e)
		t += period
	return fposmod(phase + len_seg, period)


## 목적지 링 — "여기까지 간다"를 점 하나로 못 박아 준다(대시만으로는 끝점이 모호).
func _draw_ring(center: Vector3, col: Color) -> void:
	var c := Vector3(center.x, GROUND_Y, center.z)
	for i in END_MARK_SEGS:
		var a0 := TAU * float(i) / float(END_MARK_SEGS)
		var a1 := TAU * float(i + 1) / float(END_MARK_SEGS)
		_im.surface_set_color(col)
		_im.surface_add_vertex(c + Vector3(cos(a0), 0.0, sin(a0)) * END_MARK_R)
		_im.surface_set_color(col)
		_im.surface_add_vertex(c + Vector3(cos(a1), 0.0, sin(a1)) * END_MARK_R)

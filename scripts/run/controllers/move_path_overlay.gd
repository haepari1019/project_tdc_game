extends MeshInstance3D
## MovePathOverlay — RMB 이동 오더의 예상 경로를 지면 위 **점선**으로 그린다.
## 오더를 들고 있는 모든 파티원을 한 번에 그리되, 조작 중인 캐릭터만 진하게(나머지는 흐리게)
## — 여러 명을 각기 다른 위치로 보내는 기능이라 전체 배치가 한눈에 보여야 한다.
##
## 경로는 새로 계산하지 않는다. party_member 가 이미 NavigationServer3D 로 뽑아 캐시해 둔
## `_nav_path`(nav_path_remaining)를 `_nav_path_idx`부터 재사용하므로 오버레이 비용은 렌더뿐이다.
## 색은 F-003 §3.5.3의 "연두색 점선 이동선" 규정을 따른다. ref: DRIFT-090.
##
## **두 종류의 오더를 색으로 가른다**(DRIFT-196): 좌표로 가는 순수 이동은 연두, **단일 대상 스킬을
## 쓰러 가는 접근**은 캐스트바와 같은 파랑이다. 파란 점선의 끝에는 대상 발밑 **조준 표식**이 붙고,
## 대상이 움직이면 점선도 표식도 따라간다 — "저 적에게, 이 스킬을 쓰는 중"이 한 그림으로 읽힌다.
## 이동선과 시전선이 같은 연두였을 땐 걸어가는 것인지 쓰러 가는 것인지 구분할 근거가 없었다.
##
## dungeon_run / combat_sandbox 양쪽에서 setup(party) 로 붙인다(sandbox-input-parity).

const DASH_LEN := 0.45      # 대시 한 칸 길이(m)
const GAP_LEN := 0.30       # 대시 사이 간격(m)
## 지면 z-fighting 회피용 띄움 — **각 점의 자기 Y 기준 오프셋**이다. 예전엔 절대 Y 상수(0.06)라
## 층이 있는 맵(`layer_floor_y`가 `[0.0, -8.0]`)에서 1층 멤버의 점선이 **8m 위 허공**에 그려졌다.
const GROUND_LIFT := 0.06
const COLOR_ACTIVE := Color(0.55, 1.0, 0.45, 0.95)   # 조작캐 — 연두, 진하게
const COLOR_IDLE := Color(0.55, 1.0, 0.45, 0.32)     # 그 외 오더 보유 멤버 — 같은 색, 흐리게
## 시전 접근 — `ability_dispatch._cast_bar_color`의 캐스트바 파랑과 같은 톤. 점선 → 도착 → 캐스트바로
## 색이 이어져 하나의 사슬로 읽힌다.
const COLOR_CAST_ACTIVE := Color(0.50, 0.72, 1.0, 0.95)
const COLOR_CAST_IDLE := Color(0.50, 0.72, 1.0, 0.34)
const END_MARK_R := 0.35    # 목적지 표시 원 반지름
const END_MARK_SEGS := 12
const LOCK_R := 0.75        # 대상 조준 표식 — 발밑 링 반지름
const LOCK_SEGS := 20
const LOCK_TICK := 0.30     # 링 밖으로 뻗는 브래킷 길이(4방향) — 링만으론 목적지 원과 안 갈린다
const LOCK_SPIN_DPS := 55.0 # 브래킷 회전 속도(°/s) — 정지 표식과 달리 "지금 걸려 있다"가 읽힌다

var _party: Node3D = null
var _im: ImmediateMesh = null
var _spin: float = 0.0      # 조준 표식 브래킷 회전 위상(rad)


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


func _process(delta: float) -> void:
	if _im == null:
		return
	_spin = fposmod(_spin + deg_to_rad(LOCK_SPIN_DPS) * delta, TAU)
	_im.clear_surfaces()
	if _party == null or not is_instance_valid(_party):
		return
	var any := false
	for m in _party.get_members():
		if not is_instance_valid(m):
			continue
		if m.has_method("is_alive") and not m.is_alive():
			continue
		var moving: bool = m.has_method("has_move_order") and m.has_move_order()
		# **시전 중인 대상**(DRIFT-197) — 접근이 끝난 뒤에도, 그리고 사거리 안이라 접근 오더가
		# 아예 없던 경우에도 표식을 잇는다. 표식이 사라지는 시점 = 스킬이 나가는 시점.
		var casting: Node3D = m.cast_target() if m.has_method("cast_target") else null
		if not moving and casting == null:
			continue          # 오더도 시전도 없음 → 그릴 것 없음
		if not any:
			_im.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		var on: bool = m.is_controlled()
		var cast_col: Color = COLOR_CAST_ACTIVE if on else COLOR_CAST_IDLE
		var follow: Node3D = null
		if moving:
			# 추종 대상이 있으면 = 단일 대상 스킬을 쓰러 가는 접근 → 파랑 + 조준 표식.
			follow = m.order_follow_target() if m.has_method("order_follow_target") else null
			var col: Color = cast_col if follow != null else (COLOR_ACTIVE if on else COLOR_IDLE)
			_draw_member_path(m, col, follow)
		# 시전 중 — 캐스터는 멈춰 있으므로 점선 없이 대상 표식만. 접근 중 같은 대상을 이미
		# 그렸다면(follow == casting) 겹쳐 그리지 않는다.
		if casting != null and casting != follow:
			_draw_lock(casting.global_position, cast_col)
	if any:
		_im.surface_end()


## 멤버의 현재 위치 → 남은 웨이포인트들 → 최종 목적지를 하나의 폴리라인으로 잇고,
## 그 위에 일정 간격 대시를 얹는다. 목적지에는 작은 원 마커.
func _draw_member_path(m: Node3D, col: Color, follow: Node3D = null) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	pts.append(m.global_position)
	if m.has_method("nav_path_remaining"):
		for wp in m.nav_path_remaining():
			pts.append(wp)
	# 추종 오더는 목적지가 좌표가 아니라 **대상의 현위치**다 — 오더 갱신(order_desired_velocity)과
	# 같은 프레임 기준을 쓰도록 여기서도 대상에서 직접 읽는다(한 틱 밀린 좌표로 그리지 않게).
	var goal: Vector3 = follow.global_position if follow != null else m.order_target()
	if pts.size() == 0 or pts[pts.size() - 1].distance_to(goal) > 0.05:
		pts.append(goal)
	# 폴리라인 전체를 하나의 연속 길이로 보고 대시를 얹어야 세그먼트 경계에서 리듬이 끊기지 않는다.
	var carry := 0.0   # 이번 세그먼트 시작 시점의 대시 주기 내 위상
	for i in pts.size() - 1:
		carry = _dash_segment(pts[i], pts[i + 1], col, carry)
	if follow != null:
		_draw_lock(goal, col)   # 대상 발밑 조준 표식(링 + 회전 브래킷)
	else:
		_draw_ring(goal, col)


## a→b 구간에 대시를 얹는다. `phase` = 구간 시작 시 대시 주기(DASH_LEN+GAP_LEN) 내 위치.
## 반환 = 다음 구간이 이어받을 위상.
func _dash_segment(a: Vector3, b: Vector3, col: Color, phase: float) -> float:
	var period := DASH_LEN + GAP_LEN
	var flat_a := Vector3(a.x, a.y + GROUND_LIFT, a.z)
	var flat_b := Vector3(b.x, b.y + GROUND_LIFT, b.z)
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
	var c := Vector3(center.x, center.y + GROUND_LIFT, center.z)
	for i in END_MARK_SEGS:
		var a0 := TAU * float(i) / float(END_MARK_SEGS)
		var a1 := TAU * float(i + 1) / float(END_MARK_SEGS)
		_im.surface_set_color(col)
		_im.surface_add_vertex(c + Vector3(cos(a0), 0.0, sin(a0)) * END_MARK_R)
		_im.surface_set_color(col)
		_im.surface_add_vertex(c + Vector3(cos(a1), 0.0, sin(a1)) * END_MARK_R)


## 대상 조준 표식 — 발밑 링 + **회전하는 4방향 브래킷**(DRIFT-196). 목적지 원(`_draw_ring`)과
## 같은 그림이면 "여기까지 간다"와 "이 적에게 쓴다"가 안 갈리므로, 더 크게 + 브래킷 + 회전으로
## 벌린다. 링은 지형에 따라 기울지 않고 항상 수평이다(탑다운에서 읽는 표식이라 그게 맞다).
func _draw_lock(center: Vector3, col: Color) -> void:
	var c := Vector3(center.x, center.y + GROUND_LIFT, center.z)
	for i in LOCK_SEGS:
		var a0 := TAU * float(i) / float(LOCK_SEGS)
		var a1 := TAU * float(i + 1) / float(LOCK_SEGS)
		_im.surface_set_color(col)
		_im.surface_add_vertex(c + Vector3(cos(a0), 0.0, sin(a0)) * LOCK_R)
		_im.surface_set_color(col)
		_im.surface_add_vertex(c + Vector3(cos(a1), 0.0, sin(a1)) * LOCK_R)
	for k in 4:                      # 대각 4방향 브래킷 — 링 밖으로 뻗는다
		var ang: float = _spin + TAU * float(k) / 4.0 + PI * 0.25
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		_im.surface_set_color(col)
		_im.surface_add_vertex(c + dir * LOCK_R)
		_im.surface_set_color(col)
		_im.surface_add_vertex(c + dir * (LOCK_R + LOCK_TICK))

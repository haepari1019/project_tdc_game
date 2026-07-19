extends Node3D
## 좌클릭 선택 컨트롤러 (dungeon_run + combat_sandbox 공유):
##  - 클릭(드래그 없음): 아군 클릭 → 스왑 / 적 클릭 → 12시 인스펙트 / 빈 곳 → 해제
##  - 드래그(박스): 릴리즈 시 박스 안 아군 중 **화면 좌측(작은 x)** 캐릭터로 스왑
## setup 후 좌클릭 라우터가 handle_input(event) 호출(모달=조준/부활/횃불 뒤). 클릭/박스는 릴리즈에서 확정.
## ref: 전투 템포 C, sandbox-input-parity 메모리, DRIFT-083.

const LAYER_PARTY := 2   # party_member.collision_layer (project.godot layer_2)
const LAYER_ENEMY := 4   # enemy_unit.collision_layer  (project.godot layer_3)
## 임계는 우클릭(카메라 orbit) 판별과 **같은 값**을 쓴다 — 좌/우 버튼의 클릭 허용 오차가
## 다르면 손에 익지 않는다. 해상도 비례라 InputTuning 이 SSOT.
## 마퀴는 DRAG_START 에서 뜨지만 릴리즈 판정은 CLICK_MAX 라 **겹치는 구간**이 있다: 박스가
## 잠깐 보였어도 그 안에서 손을 떼면 박스가 아니라 **클릭(점 선택)** 으로 처리된다.
## 기존 고정 8px는 너무 빡빡해서, 아군을 클릭해 스왑하려다 손이 조금 밀리면 초소형 마퀴로
## 판정되고 → 그 박스 안에 아군 **원점**이 안 들어가 스왑이 통째로 씹혔다.
const InputTuning := preload("res://scripts/core/input_tuning.gd")

## 드래그 박스가 아군의 화면상 사각형을 이 비율 이상 덮어야 선택 후보가 된다.
## 발끝만 걸친 이웃이 좌측 우선 규칙을 타고 가로채는 걸 막는 게 목적(사용자 체감 2026-07-19).
const SELECT_COVER_MIN := 0.70

var _party: Node3D     # PartyController — get_members / index_of / try_swap_to
var _enemy_info: Node  # EnemyInfo 패널 — set_enemy / clear
var _marquee: Panel    # 드래그 박스 시각(HUD 오버레이)

var _pressing: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _max_dist: float = 0.0   # 누른 지점으로부터 도달한 최대 직선거리(릴리즈 순간 거리로 재면 왕복 드래그가 클릭이 된다)


func setup(party: Node3D, enemy_info: Node, hud: Node) -> void:  # hud = HUD Control 또는 CanvasLayer
	_party = party
	_enemy_info = enemy_info
	_marquee = Panel.new()
	_marquee.visible = false
	_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 클릭 안 먹게(오버레이만)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.75, 1.0, 0.14)
	sb.border_color = Color(0.55, 0.85, 1.0, 0.9)
	sb.set_border_width_all(1)
	_marquee.add_theme_stylebox_override("panel", sb)
	hud.add_child(_marquee)


## 좌클릭 라이프사이클. 소비하면 true(드래그 모션·릴리즈). 프레스는 소비 안 함(클릭/드래그는 릴리즈 확정).
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			_pressing = true
			_dragging = false
			_max_dist = 0.0
			_press_pos = _mouse()
			return false
		if not _pressing:
			return false
		_pressing = false
		var was_dragging := _dragging
		_dragging = false
		_marquee.visible = false
		# 마퀴가 떴더라도 CLICK_MAX 안이면 클릭으로 인정(겹치는 구간) — 살짝 밀린 스왑 구제.
		if was_dragging and _max_dist > InputTuning.click_max_px(get_viewport()):
			_swap_to_leftmost_in_box()
			return true
		# 클릭 → 아군 스왑 우선, 아니면 적 인스펙트
		if not _swap_to_party_under_mouse():
			_inspect_enemy_under_mouse()
		return true
	if event is InputEventMouseMotion:
		if not _pressing:
			return false
		_max_dist = maxf(_max_dist, _press_pos.distance_to(_mouse()))
		if not _dragging and _max_dist > InputTuning.drag_start_px(get_viewport()):
			_dragging = true
		if _dragging:
			_update_marquee()
			return true
	return false


func _mouse() -> Vector2:
	return get_viewport().get_mouse_position()


## 프레스~현재 마우스로 이루는 화면 사각형.
func _box_rect() -> Rect2:
	var a := _press_pos
	var b := _mouse()
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


func _update_marquee() -> void:
	var r := _box_rect()
	_marquee.position = r.position
	_marquee.size = r.size
	_marquee.visible = true


## 박스가 **충분히 덮은** 아군 중 화면 x가 가장 작은(좌측) 캐릭터로 스왑. 없으면 무동작.
##
## 예전엔 아군의 **원점(발밑) 한 점**이 박스에 드는지만 봤다. 그래서 몸통이 거의 다 박스
## 밖이어도 발끝만 걸치면 후보가 되고, 거기에 좌측 우선 규칙이 겹쳐 **의도한 가운데 아군 대신
## 왼쪽에 살짝 걸린 아군이 선택**됐다. 이제 캐릭터의 화면상 사각형 중 박스와 겹친 **면적
## 비율**을 재서 SELECT_COVER_MIN 이상만 후보로 삼는다.
func _swap_to_leftmost_in_box() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var rect := _box_rect()
	var best_idx := -1
	var best_x := INF
	for m in _party.get_members():
		if not is_instance_valid(m) or (m.has_method("is_alive") and not m.is_alive()):
			continue
		var body := _screen_rect_of(cam, m)
		if body.size.x <= 0.0 or body.size.y <= 0.0:
			continue                     # 카메라 뒤 등 투영 불가
		var covered := rect.intersection(body)
		var ratio := (covered.size.x * covered.size.y) / (body.size.x * body.size.y)
		if ratio >= SELECT_COVER_MIN and body.position.x < best_x:
			best_x = body.position.x
			best_idx = _party.index_of(m)
	if best_idx >= 0:
		_party.try_swap_to(best_idx)
	# 아무도 기준을 못 넘으면 **무동작**. 살짝 끌린 클릭은 이미 릴리즈 판정(CLICK_MAX)에서
	# 점 선택으로 처리되므로, 여기까지 온 건 "제대로 끈 박스"다 — 그때 엉뚱한 대상을
	# 레이픽으로 주워오면 오히려 이 수정의 취지에 반한다.


## 캐릭터의 화면상 경계 사각형 — 콜리전 캡슐 AABB 8꼭짓점을 투영해 감싸는 2D 사각형.
## 꼭짓점 하나라도 카메라 뒤면 투영이 무의미해지므로 빈 Rect2 를 돌려 후보에서 제외한다.
func _screen_rect_of(cam: Camera3D, m: Node) -> Rect2:
	if not m.has_method("selection_aabb"):
		return Rect2()
	var ab: AABB = m.selection_aabb()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in 8:
		var corner: Vector3 = ab.get_endpoint(i)
		if cam.is_position_behind(corner):
			return Rect2()
		var sp := cam.unproject_position(corner)
		mn = mn.min(sp)
		mx = mx.max(sp)
	return Rect2(mn, mx - mn)


## 아군(mask 2) 레이픽 → 그 슬롯으로 스왑. 히트 시 true. down/MIA는 try_swap_to의 _can_swap이 거른다.
func _swap_to_party_under_mouse() -> bool:
	var n := _pick(LAYER_PARTY)
	if n == null:
		return false
	var idx: int = _party.index_of(n)
	if idx < 0:
		return false
	_party.try_swap_to(idx)
	return true


## 적(mask 4) 레이픽 → 12시 인스펙트 패널에 표시. 빈 공간/비적은 해제.
func _inspect_enemy_under_mouse() -> void:
	var n := _pick(LAYER_ENEMY)
	if n != null and n.has_method("get_body_color"):
		_enemy_info.set_enemy(n)
	else:
		_enemy_info.clear()


## 마우스 아래를 지정 레이어로 레이캐스트한 콜라이더(없으면 null).
func _pick(mask: int) -> Node:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse := _mouse()
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 1000.0
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.get("collider") if not hit.is_empty() else null

extends Node3D
## 좌클릭 선택 컨트롤러 (dungeon_run + combat_sandbox 공유):
##  - 클릭(드래그 없음): 아군 클릭 → 스왑 / 적 클릭 → 12시 인스펙트 / 빈 곳 → 해제
##  - 드래그(박스): 릴리즈 시 박스 안 아군 중 **화면 좌측(작은 x)** 캐릭터로 스왑
## setup 후 좌클릭 라우터가 handle_input(event) 호출(모달=조준/부활/횃불 뒤). 클릭/박스는 릴리즈에서 확정.
## ref: 전투 템포 C, sandbox-input-parity 메모리, DRIFT-083.

const LAYER_PARTY := 2   # party_member.collision_layer (project.godot layer_2)
const LAYER_ENEMY := 4   # enemy_unit.collision_layer  (project.godot layer_3)
const DRAG_THRESHOLD_PX := 8.0   # 이 미만 이동=클릭, 이상=박스 드래그

var _party: Node3D     # PartyController — get_members / index_of / try_swap_to
var _enemy_info: Node  # EnemyInfo 패널 — set_enemy / clear
var _marquee: Panel    # 드래그 박스 시각(HUD 오버레이)

var _pressing: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO


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
			_press_pos = _mouse()
			return false
		if not _pressing:
			return false
		_pressing = false
		if _dragging:
			_dragging = false
			_marquee.visible = false
			_swap_to_leftmost_in_box()
			return true
		# 드래그 아님 → 단일 클릭(아군 스왑 우선, 아니면 적 인스펙트)
		if not _swap_to_party_under_mouse():
			_inspect_enemy_under_mouse()
		return true
	if event is InputEventMouseMotion:
		if not _pressing:
			return false
		if not _dragging and _press_pos.distance_to(_mouse()) > DRAG_THRESHOLD_PX:
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


## 박스 안 살아있는 아군 중 화면 x가 가장 작은(좌측) 캐릭터로 스왑. 없으면 무동작.
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
		var wp: Vector3 = (m as Node3D).global_position
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		if rect.has_point(sp) and sp.x < best_x:
			best_x = sp.x
			best_idx = _party.index_of(m)
	if best_idx >= 0:
		_party.try_swap_to(best_idx)


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

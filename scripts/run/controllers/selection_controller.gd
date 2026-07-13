extends Node3D
## 좌클릭 선택 컨트롤러 — 아군(mask 2) 클릭 시 그 캐릭터로 스왑, 아니면 적(mask 4) 클릭 시 12시 인스펙트
## 패널 표시(빈 공간/비적 = 해제). **dungeon_run과 combat_sandbox가 공유**해 입력 드리프트를 막는다
## (조준/부활/횃불 같은 모달 컨트롤러 패턴과 동일: setup 후 좌클릭 라우터가 handle_click 호출).
## 모달 아님 — 좌클릭이면 항상 처리. ref: 전투 템포 C, sandbox-input-parity 메모리, DRIFT-083.

const LAYER_PARTY := 2   # party_member.collision_layer (project.godot layer_2)
const LAYER_ENEMY := 4   # enemy_unit.collision_layer  (project.godot layer_3)

var _party: Node3D     # PartyController — index_of / try_swap_to
var _enemy_info: Node  # EnemyInfo 패널 — set_enemy / clear


func setup(party: Node3D, enemy_info: Node) -> void:
	_party = party
	_enemy_info = enemy_info


## 좌클릭(pressed)이면 아군 스왑(우선) 또는 적 인스펙트를 처리하고 true(소비). 그 외 이벤트는 false.
func handle_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return false
	if not _swap_to_party_under_mouse():
		_inspect_enemy_under_mouse()
	return true


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
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 1000.0
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.get("collider") if not hit.is_empty() else null

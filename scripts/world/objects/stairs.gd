extends Node3D
## **계단 — 같은 런 안에서 층을 옮기는 입력 경로.**
##
## 포털(= Extraction Point)은 **런 경계**이고 계단은 그 안의 전이다(`LDG-001` §9.2).
## 전이 자체는 `LayerTransition`이 **한 트랜잭션**으로 한다 — 이 오브젝트는 그걸 **부르는 손가락**만
## 소유한다. 그래서 여기엔 안개·nav·카메라 이야기가 없다.
##
## 상호작용 계약(덕타이핑): `interact_prompt()` · `interact_anchor()` · `interact()` +
## 그룹 `"interactable"` + 콜리전 바디가 INTERACT 비트. 상자·문과 같은 모양이다.
##
## **월드 비트를 안 켠다**(INTERACT만). 계단은 통행을 막지도, 시야를 끊지도 않는다 —
## world 비트를 켜면 오클루더 유도(`derive_occluders`)가 이걸 벽으로 세어 안개에 구멍이 뚫린다.
##
## ref: docs/design/map_upgrade_plan.html §Phase 1 D-4 · `DEC-20260824-001` §⑤

const SIZE := Vector3(4.0, 0.5, 4.0)
const INTERACT_BIT := 1 << 4

## 목적지 방 / 그 방의 레이어.
var to_room: String = ""
var to_layer: int = 0
## **이 계단이 놓인 층.** 활성 층이 여기가 아니면 숨고 콜리전을 끈다 — 안 그러면 바닥 너머의
## 계단이 마우스에 잡힌다(`visible = false`만으로는 레이캐스트가 계속 맞는다).
var on_layer: int = 0

var _trans: Node = null
var _body: StaticBody3D = null
## `_build()`가 정한 콜리전 비트. 층 토글은 이걸 **켰다 껐다 할 뿐**이다 —
## 토글이 비트를 스스로 정하면 빌더가 무엇을 켜든 조용히 덮어써서, 「world 비트를 안 켠다」가
## 빌더의 성질이 아니라 토글의 부작용으로 성립한다(게이트가 그걸 못 잡았다).
var _mask := 0
var _mesh: MeshInstance3D = null


func setup(trans: Node, dest_room: String, dest_layer: int, own_layer: int) -> void:
	_trans = trans
	to_room = dest_room
	to_layer = dest_layer
	on_layer = own_layer
	if _trans != null and _trans.has_signal("transitioned"):
		_trans.transitioned.connect(_on_transitioned)


func _ready() -> void:
	add_to_group("interactable")
	_build()


## 활성 층이 바뀌면 자기 존재를 갱신한다.
func _on_transitioned(layer: int, _room: String) -> void:
	set_active_layer(layer)


func set_active_layer(layer: int) -> void:
	var here := layer == on_layer
	visible = here
	if _body != null:
		_body.collision_layer = _mask if here else 0


## **결집 상태를 누르기 전에 보여준다.** 눌렀는데 아무 일도 안 일어나면 고장으로 읽힌다 —
## 파티를 찢지 않는다는 규칙은 거절 화면이 있어야 규칙으로 읽힌다.
func interact_prompt() -> String:
	var verb := "내려가기" if to_layer > on_layer else "올라가기"
	if _trans == null:
		return "계단\n[우클릭] %s" % verb
	var gate: Dictionary = _trans.can_transition(global_position)
	if bool(gate["ok"]):
		return "계단 → %s\n[우클릭] %s" % [to_room, verb]
	return "계단 → %s\n⛔ 파티 결집 필요: %s" % [to_room, ", ".join(gate["missing"])]


func interact_anchor() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)


func interact() -> void:
	if _trans == null or to_room.is_empty():
		return
	_trans.transition(to_room, to_layer, global_position)


func _build() -> void:
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	_mesh.mesh = bm
	_mesh.position.y = SIZE.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.26, 0.34)
	mat.emission_enabled = true
	mat.emission = Color(0.30, 0.42, 0.62)
	mat.emission_energy_multiplier = 0.6
	_mesh.material_override = mat
	add_child(_mesh)

	_body = StaticBody3D.new()
	_body.collision_layer = INTERACT_BIT   # world 비트 없음 — 통행/시야를 막지 않는다
	_mask = _body.collision_layer
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	cs.shape = box
	cs.position.y = SIZE.y * 0.5
	_body.add_child(cs)
	add_child(_body)

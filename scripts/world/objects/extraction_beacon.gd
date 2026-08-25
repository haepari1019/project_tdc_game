extends Node3D
## **탈출 지점 — 눌러서 시작한다.**
##
## 스펙 이름이 `ExtractionActivate`(`F-007` §3.1.2a)인 대로 **활성화**가 먼저다. 예전에는 존 반경
## 안에 들어가면 홀드가 **저절로** 시작됐는데, 그러면 탈출이 「지나가다 걸리는 것」이 되어
## **커밋할 것인가**라는 선택이 사라진다. 이제 이 오브젝트를 눌러야 홀드가 돈다.
##
## 활성 조건은 **지점이 갖는다**(`F-006` §3.10): `always` = 언제나 · `onObjectiveComplete` = 목표 완료 후.
## 조건이 안 찼으면 프롬프트가 **이유를 말하고** 눌러도 시작되지 않는다 — 문과 같은 규약이다.
##
## 상호작용 계약(덕타이핑): `interact_prompt()` · `interact_anchor()` · `interact()` + 그룹 `"interactable"`.
## **world 비트를 안 켠다**(INTERACT만) — 탈출대가 통행이나 시야를 막으면 안 된다.

const SIZE := Vector3(3.2, 0.4, 3.2)
const INTERACT_BIT := 1 << 4

var room: String = ""
var activation: String = "always"

var _run: Node = null
var _end: Node = null       # RunEndController
var _body: StaticBody3D = null
var _mesh: MeshInstance3D = null
var _mask := 0


func setup(run: Node, run_end: Node) -> void:
	_run = run
	_end = run_end


func _ready() -> void:
	add_to_group("interactable")
	_build()


## 지금 쓸 수 있는가 — 활성 조건(`F-006` §3.10).
func is_active() -> bool:
	if activation == "onObjectiveComplete":
		return _run != null and bool(_run.objective_complete)
	return true


func interact_prompt() -> String:
	if not is_active():
		return "봉쇄된 탈출 지점\n🔒 목표 완료 필요"
	if _end != null and _end.has_method("is_extracting") and _end.is_extracting():
		return "탈출 진행 중\n[우클릭] 중단"
	return "탈출 지점\n[우클릭] 탈출 시작"


func interact_anchor() -> Vector3:
	return global_position + Vector3(0, 1.4, 0)


func interact() -> void:
	if _end == null or not is_active():
		return
	if _end.has_method("is_extracting") and _end.is_extracting():
		_end.cancel_extraction()      # 되돌릴 수 있어야 커밋이 선택이 된다
		return
	_end.request_extraction(self)


func _build() -> void:
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	_mesh.mesh = bm
	_mesh.position.y = SIZE.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.42, 0.28)
	mat.emission_enabled = true
	mat.emission = Color(0.28, 0.85, 0.45)
	mat.emission_energy_multiplier = 0.9
	_mesh.material_override = mat
	add_child(_mesh)

	_body = StaticBody3D.new()
	_body.collision_layer = INTERACT_BIT   # world 비트 없음 — 통행/시야를 막지 않는다
	_mask = _body.collision_layer
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE.x, 1.6, SIZE.z)   # 클릭 판정은 넉넉히(바닥판은 얇다)
	cs.shape = box
	cs.position.y = 0.8
	_body.add_child(cs)
	add_child(_body)

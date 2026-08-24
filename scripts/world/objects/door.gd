extends Node3D
## **진입 조건의 실물** — 잠긴 방으로 가는 길을 막는 문. 조건은 맵 문서가 소유한다:
## `transitions` 앵커의 `gates`가 막을 방을 지목하고, 그 방의 `entry_requirement`가
## **무엇이 필요한가**를 정한다(`LDG-001` §9.1). 열리면 콜리전·메시·오클루더를 치운다.
##
## 예전엔 **열쇠만 아는 문**이었다. 그러면 열쇠가 아닌 조건(`onObjectiveComplete` 등)은
## 데이터에 적어도 **실물이 될 수 없어** 조용히 죽은 선언이 된다. 규칙별로 갈린다:
##   - `requiresItem` / `onBossKey` — 백팩의 **정확한 열쇠 id**. 열면 소모된다.
##   - `onObjectiveComplete` — 목표 완료. **스스로 열린다**(누르는 조건이 아니라 진행 조건이다).
##   - `onFacilityTier` / `onAccess` — 어휘는 스펙에 있으나 **런타임 미구현**. 잠그지 않는다
##     (조용히 막으면 진행 불가가 되므로, 미구현은 **열어 두는 쪽**으로 실패한다).
##
## ref: `LDG-001` §9.1 · `F-006` §3.10 · world loop / F-007.

const SIZE := Vector3(6.4, 3.2, 0.9)  # spans the ~6-wide route→extraction opening

var _inv: Node = null     # InventoryUI (key check)
## **이 문이 요구하는 열쇠 id.** 맵 문서가 소유한다 — 문이 막는 방의 `entry_requirement.ref`다
## (`transitions` 앵커 `gates`가 그 방을 지목한다). 비면 구 부분 문자열 매칭으로 떨어진다.
var key_id: String = ""
## 진입 조건 규칙(`entry_requirement.rule`). 기본값은 구 동작(열쇠 문).
var rule: String = "requiresItem"
## 열면 열쇠가 사라지는가(`entry_requirement.consume_on_use`, `LDG-001` §9.1).
## **false면 같은 열쇠로 여러 문을 연다** — 열쇠 하나가 「어디에 쓸까」의 선택이 아니라
## **「어디까지 둘러볼까」의 허가증**이 된다. 소모/비소모는 맵이 문마다 정한다.
var consume_on_use: bool = true
## **이 문을 열면 런 목표가 완료되는가.** 데모 맵의 봉인문이 곧 목표(GIMMICK-DEMO-01)라
## 예전엔 **무조건** 완료시켰다 — 문이 둘 이상인 맵에서는 아무 관문이나 목표를 끝내 버린다.
## 이제 앵커가 `completes_objective`로 명시한 문만 완료시킨다.
var completes_objective: bool = false
var _run: Node = null     # RunController (objective)
var _opened := false
var _body: StaticBody3D = null
var _mesh: MeshInstance3D = null
var _occluders: Array = []   # F2: fog/cone occluders (closed door) — freed on open


func setup(inv: Node, run: Node) -> void:
	_inv = inv
	_run = run
	# 진행 조건 문은 **스스로 열린다** — 목표를 끝내고 돌아와 문을 누르게 만들 이유가 없다.
	if rule == "onObjectiveComplete" and _run != null and _run.has_signal("objective_completed"):
		_run.objective_completed.connect(_open_now)


## F2: dynamic fog/cone occluders for the closed door (registered by dungeon_run). The closed door
## now casts a vision shadow; opening frees them so light/cones pass through (fog updates next frame).
func set_occluders(occ: Array) -> void:
	_occluders = occ


func _ready() -> void:
	add_to_group("interactable")
	_build()


func interact_prompt() -> String:
	if _unlocked():
		return "문\n[우클릭] 열기"
	if rule == "onObjectiveComplete":
		return "봉쇄된 문\n🔒 목표 완료 필요"
	return "잠긴 문\n🔒 열쇠 필요"


## 이 문의 조건이 충족됐는가. **미구현 규칙은 잠그지 않는다** — 조용히 막으면 진행 불가가 된다.
func _unlocked() -> bool:
	match rule:
		"requiresItem", "onBossKey":
			return _inv != null and _inv.backpack_has_key(key_id)
		"onObjectiveComplete":
			return _run != null and bool(_run.objective_complete)
		_:
			return true


func interact_anchor() -> Vector3:
	return global_position + Vector3(0, SIZE.y + 0.4, 0)  # above the door


func interact() -> void:
	if _opened or not _unlocked():
		return  # locked — prompt already says what is needed
	if consume_on_use and (rule == "requiresItem" or rule == "onBossKey") 			and _inv != null and _inv.has_method("consume_key"):
		_inv.consume_key(key_id)                    # 소모성 문 — 열면 열쇠가 사라진다
	_open_now()


## 실제로 치우는 부분. 진행 조건 문은 시그널로 여기 직행한다(누르지 않는다).
func _open_now() -> void:
	if _opened:
		return
	_opened = true
	remove_from_group("interactable")        # no more prompt / interaction
	if _body:
		_body.queue_free()                    # clear the barrier — path open
	if _mesh:
		_mesh.visible = false
	for o in _occluders:                      # F2: door open → vision (fog + cones) passes through
		if is_instance_valid(o):
			o.queue_free()
	# **이 문이 목표인 맵에서만** 목표를 완료시킨다(데모 맵의 봉인문 = GIMMICK-DEMO-01).
	# 예전엔 무조건이라, 문이 둘 이상인 맵에서 아무 관문이나 목표를 끝내 버렸다.
	if completes_objective and _run and _run.has_method("complete_objective"):
		_run.complete_objective()             # objective = door opened
	print("[TDC] 문 열림 (%s%s%s) — 길이 열렸다" % [rule,
		"" if consume_on_use else " · 열쇠 유지", " · 목표 완료" if completes_objective else ""])


func _build() -> void:
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	_mesh.mesh = bm
	_mesh.position.y = SIZE.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.30, 0.20)
	mat.emission_enabled = true
	mat.emission = Color(0.32, 0.13, 0.05)
	mat.emission_energy_multiplier = 0.5
	_mesh.material_override = mat
	add_child(_mesh)

	_body = StaticBody3D.new()
	_body.collision_layer = 1 | (1 << 4)      # world (blocks movement/LOS) + interactable (hover)
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	cs.shape = box
	cs.position.y = SIZE.y * 0.5
	_body.add_child(cs)
	add_child(_body)

extends Node
## **계단 전이 — 같은 맵 안에서 레이어를 옮긴다.**
##
## 포털은 런 경계(= Extraction Point)이고, 계단은 **런을 끊지 않는** 레이어 전이다.
## 레이어는 같은 `mapId` 안에서 **XZ를 공유하는 병렬 공간**이라(`LDG-001` §9.2), 전이는
## 「다른 맵을 로드」가 아니라 **파티를 옮기고 활성 층을 바꾸는 것**이다.
##
## 조건: **행동 가능한 파티 전원 결집** (`F-007` §3.6.2 `extractionCohesionRule` ·
## `F-003` `unbound_anchor_max_m`과 같은 모양). 파티는 찢지 않는다.
##   - `down` / `MIA` 멤버는 **따라오지 않고 기존 상태 그대로 남는다.** 강제 전환도 없다.
##     `MIA`(살아서 이탈)는 남은 층에서 **적에게 노출**되고, `down`은 회수 대상이다.
##   - 남겨진 멤버로 **스왑이 안 되는 것**이 이 설계의 전제다 — `F-001` §3.6을
##     `PartyController.try_swap_to()`가 이미 강제한다([[DRIFT-170]]).
##
## 전이는 **한 트랜잭션**이다. 넷이 함께 가지 않으면 층이 어긋난다:
##   ① 활성 레이어 + 안개(오클루더·탐색 기억·가시성)  ② 파티 위치  ③ 파티 nav 바인딩  ④ 카메라
##
## ref: docs/design/map_upgrade_plan.html §Phase 1 · `DEC-20260824-001` §⑤

signal transitioned(layer: int, room_ref: String)
signal transition_refused(missing: Array)

## 결집 반경 — 계단 앞에 4인이 설 자리(맵 계약 문서의 저작 규약과 같은 값).
const COHESION_RADIUS_M := 6.0
const FADE_S := 0.22

var _party: Node = null
var _map: Node = null
var _fog: Node = null
var _camera: Node = null
var _fade: ColorRect = null


func setup(party: Node, map: Node, fog: Node, camera_rig: Node = null, fade: ColorRect = null) -> void:
	_party = party
	_map = map
	_fog = fog
	_camera = camera_rig
	_fade = fade


## 이 지점에서 전이할 수 있는가. `{ok: bool, missing: [이름]}` —
## **행동 가능한**(살아 있고 MIA 아닌) 멤버만 본다. 쓰러진 동료는 조건이 아니라 **두고 가는 것**이다.
func can_transition(at: Vector3) -> Dictionary:
	var missing: Array = []
	if _party == null:
		return {"ok": false, "missing": missing}
	for m in _party.get_members():
		if not is_instance_valid(m) or not m.is_alive():
			continue                      # down = 두고 간다(조건 아님)
		if m.has_method("is_mia") and m.is_mia():
			continue                      # MIA도 두고 간다
		if (m as Node3D).global_position.distance_to(at) > COHESION_RADIUS_M:
			missing.append(String(m.name))
	return {"ok": missing.is_empty(), "missing": missing}


## 전이 실행. 거절되면 false. 성공하면 **행동 가능한 멤버만** 목적지로 간다.
func transition(to_room: String, to_layer: int, at: Vector3) -> bool:
	var gate: Dictionary = can_transition(at)
	if not bool(gate["ok"]):
		transition_refused.emit(gate["missing"])
		print("[LAYER] 전이 거절 — 결집 안 됨: %s" % str(gate["missing"]))
		return false
	if _map == null:
		return false

	await _fade_to(1.0)

	# ① 활성 레이어 + 안개(오클루더·탐색 기억·비활성 층 숨김)
	if _fog != null and _fog.has_method("switch_layer"):
		_fog.call("switch_layer", to_layer)
	elif _map.has_method("set_active_layer"):
		_map.set_active_layer(to_layer)

	# ② 파티 위치 — **행동 가능한 멤버만**. 쓰러진/이탈한 멤버는 그 자리에 그대로 남는다.
	var dest: Vector3 = _map.get_spawn_position(to_room)
	var i := 0
	for m in _party.get_members():
		if not is_instance_valid(m) or not m.is_alive():
			continue
		if m.has_method("is_mia") and m.is_mia():
			continue
		var ang := float(i) * TAU / 4.0
		(m as Node3D).global_position = dest + Vector3(cos(ang), 0.0, sin(ang)) * 2.0
		if m.has_method("nav_clear"):
			m.nav_clear()             # 옛 층의 경로를 들고 가지 않는다
		i += 1

	# ③ 파티 nav 바인딩 — 새 층의 맵으로
	if _party.has_method("bind_nav_layer"):
		_party.bind_nav_layer(to_layer, _map)

	# ④ 카메라는 **글라이드가 아니라 스냅** — 맵을 가로질러 날아가면 전이가 아니라 사고로 보인다.
	if _camera != null and _camera.has_method("glide_to_current"):
		_camera.call("glide_to_current")

	await _fade_to(0.0)
	transitioned.emit(to_layer, to_room)
	print("[LAYER] 전이 완료 → layer %d · %s" % [to_layer, to_room])
	return true


## 페이드. 오버레이가 없으면(헤드리스·테스트) 즉시 반환한다 — 로직이 연출에 묶이지 않게.
func _fade_to(a: float) -> void:
	if _fade == null:
		return
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", a, FADE_S)
	await tw.finished
	_fade.visible = a > 0.01

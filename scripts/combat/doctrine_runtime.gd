extends Node
## `F-030` 파티 운용 doctrine — **Trait 런타임 발동**. CombatController 자식.
##
## 성장이 "캐릭터를 강하게"가 아니라 **"4명을 어떤 순서·템포로 조작하는가"** 라서, 이 파일이 읽는 것은
## 스탯이 아니라 **조작 맥락**이다 — 누가 지금 조작 중인가 / 방금 누구에게 넘겼나 / 돌아왔나.
##
## **`controlContext` 4값** (`F-030` §3.4 · `D-021` §3):
##   · `OnControl`  — 직접 조작 **중**(지속)          · `WhileAI`  — AI가 굴리는 **중**(지속)
##   · `OnHandoff`  — 조작을 **넘기는 순간**(엣지)     · `OnReswap` — 조작이 **돌아오는 순간**(엣지)
##
## **하드 제약** (`D-021` §6 · `ROLE-001` §E-1 — 위반은 대전제를 깬다):
##   · Status/Zone/Event를 **새로 생성하지 않는다** — 이미 걸린 것을 **읽고 늘릴 뿐**.
##   · 파티 **공용 자원·게이지 신설 금지** — `ResourceGrant`는 **기존 자원**(방벽 등)만.
##   · `NcModulation`은 **여기서 처리하지 않는다** — `F-005` §3.3a 8단계 경유 필수(CS-3).
##     여기서 NC를 건드리면 lookup 1~7이 doctrine 유무로 갈려 `QA-032` §2.1이 무너진다.

const Spatial := preload("res://scripts/core/spatial.gd")

var _combat: Node = null
var _party: Node = null
## per-member 상태 — {member: {ever_controlled: bool, icd: {trait_id: 남은초}}}
var _state: Dictionary = {}


func setup(combat: Node, party: Node) -> void:
	_combat = combat
	_party = party
	if _party == null or not _party.has_method("get_members"):
		return
	for m in _party.get_members():
		if m == null or not is_instance_valid(m):
			continue
		_state[m] = {"ever_controlled": m.is_controlled(), "icd": {}}
		# 조작 전환 **엣지**는 멤버가 이미 시그널로 알린다 — 폴링하지 않는다.
		m.became_non_controlled.connect(_on_handoff.bind(m))
		m.became_controlled.connect(_on_control_gained.bind(m))


func _physics_process(delta: float) -> void:
	if _party == null:
		return
	for m in _party.get_members():
		if m == null or not is_instance_valid(m) or not m.is_alive():
			continue
		var st: Dictionary = _state.get(m, {})
		for tid in (st.get("icd", {}) as Dictionary).keys():
			st["icd"][tid] = maxf(0.0, float(st["icd"][tid]) - delta)
		# 지속형 컨텍스트 — 매 틱 조건을 재평가하되 icd가 발동 빈도를 잡는다(R3 방어).
		_fire(m, "OnControl" if m.is_controlled() else "WhileAI")


func _on_handoff(m: Node) -> void:
	_fire(m, "OnHandoff")


## 조작 획득 — **처음 잡는 것과 돌아오는 것은 다르다.** `OnReswap`은 "잠깐 빠졌다 복귀"라는
## 운용을 보상하는 컨텍스트이므로, 한 번도 조작한 적 없는 최초 진입은 여기 해당하지 않는다.
func _on_control_gained(m: Node) -> void:
	var st: Dictionary = _state.get(m, {})
	if bool(st.get("ever_controlled", false)):
		_fire(m, "OnReswap")
	st["ever_controlled"] = true
	_state[m] = st


## 이 멤버의 활성 doctrine에서 `ctx` 컨텍스트 Trait을 조건 판정 후 발동.
func _fire(m: Node, ctx: String) -> void:
	var dp := get_node_or_null("/root/DoctrineProfile")
	if dp == null:
		return
	var doc: Dictionary = dp.active_for(String(m.get("class_id")))
	if doc.is_empty():
		return                                   # 중립 성장 — 아무것도 하지 않는다(QA-032 §2.1)
	var st: Dictionary = _state.get(m, {"ever_controlled": false, "icd": {}})
	for t in doc.get("traits", []):
		if String(t.get("control_context", "")) != ctx:
			continue
		var tid := String(t.get("trait_id", ""))
		if float((st.get("icd", {}) as Dictionary).get(tid, 0.0)) > 0.0:
			continue                             # 내부 쿨다운 중 — R3(고빈도 반복 보상) 방어
		if not _condition_met(m, t):
			continue
		if not _apply_payoff(m, t):
			continue                             # 적용 대상이 없었다 → icd를 태우지 않는다
		st["icd"][tid] = float(t.get("icd_s", 0.0))
		_state[m] = st


## 조건 — `conditionRefs`(기존 상태 ID 참조) + `conditionCount`(수량 하한).
## 신규 문법을 만들지 않는다(`F-010` §3.11.1 / `D-021` §3와 같은 규약).
func _condition_met(m: Node, t: Dictionary) -> bool:
	var need := int(t.get("condition_count", 1))
	for ref in t.get("condition_refs", []):
		match String(ref):
			"Taunted":
				if _taunted_count(m) < need:
					return false
			"bulwark_charge":
				if int(m.get("bulwark_stacks")) < need:
					return false
			_:
				return false      # 모르는 조건은 **거짓** — 조용히 항상 발동하는 것보다 낫다
	return true


## 이 멤버가 지금 도발 중인 적 수. `Taunted`는 어그로가 아니라 **마커**를 읽는다(enemy_unit).
func _taunted_count(m: Node) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("is_taunted_by") and e.is_taunted_by(m):
			n += 1
	return n


## payoff — 성공 시 true. **NcModulation은 여기서 처리하지 않는다**(CS-3 · F-005 §3.3a).
func _apply_payoff(m: Node, t: Dictionary) -> bool:
	var target := String(t.get("payoff_target_ref", ""))
	var val := float(t.get("payoff_value", 0.0))
	match String(t.get("payoff_kind", "")):
		"DurationExtend":
			if target != "Taunted":
				return false
			var n := 0
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) and e.has_method("extend_taunt") and e.extend_taunt(m, val):
					n += 1
			if n > 0:
				m.popup_status("도발 연장 +%.0fs (%d)" % [val, n], Color(1.0, 0.82, 0.45))
			return n > 0
		"ResourceGrant":
			if target != "bulwark_charge" or not m.has_method("binding_bulwark_add"):
				return false
			# **기존 자원**만 지급(F-030 §8). 캡스톤 구조는 그대로 두고 도달 속도만 바꾼다 —
			# 적립이 3겹을 채우면 평소와 똑같이 터진다.
			var b: Dictionary = BindingOverlays.BULWARK
			for _i in int(maxf(1.0, val)):
				if m.binding_bulwark_add(int(b["stacks_needed"]), float(b["icd_s"])):
					var e2 = _combat._nearest_enemy_in_range(m.global_position, float(b["radius_m"]))
					if e2 != null and e2.has_method("apply_stun"):
						e2.apply_stun(float(b["stun_s"]) * float(m.get("bulwark_payoff_mult")))
			m.popup_status("방벽 적립 +%d" % int(val), Color(0.6, 0.85, 1.0))
			return true
		"MagnitudeScale":
			if target != "bulwark_charge":
				return false
			m.bulwark_payoff_mult = val      # 다음 캡스톤 1회에만 — 소모는 ability_dispatch가
			m.popup_status("복귀 정산 준비 ×%.1f" % val, Color(0.75, 0.9, 1.0))
			return true
		"NcModulation":
			return false                     # CS-3 — F-005 §3.3a 8단계 경유. 여기서 처리하면 대전제가 깨진다
	return false

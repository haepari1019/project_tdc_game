extends SceneTree
## **참(charm) 스모크** (`F-010` §3.11) — 「칸은 먹는데 효과는 없다」를 잡는 게이트.
##
## 왜 별도 스위트인가: 이 결함은 **소스 단언으로 안 잡힌다.** 계산(`charm_mods`)도 적재
## (`apply_charms`)도 멀쩡했고, 연결(`charms_changed` → `refresh_charms`)도 코드에 있었다.
## 빠진 건 **호출 시점** 하나였다 — 시그널을 쏘는 곳이 `InventoryUI._close()`뿐이라 런 시작
## 시점엔 아무도 밀어 넣지 않았다. 그 결과 「인벤을 한 번 열었다 닫아야 참이 켜지는」 상태가
## 됐는데, 화면 어디에도 그 사실이 드러나지 않는다.
##
## 그래서 여기서는 **실제로 런 씬을 띄우고 멤버의 값을 읽는다.** 배선이 아니라 **결과**를 묻는다.
## 저장은 건드리지 않는다 — `Backpack.loose`를 메모리에서만 갈아끼우고 복원한다.

var _ok := true


func _init() -> void:
	for _i in 3:
		await process_frame
	var sd = root.get_node_or_null("/root/Slice01Data")
	if sd == null or not sd.is_loaded():
		print("CHARM SMOKE FAILED — Slice01Data not loaded")
		quit(1)
		return

	# ① 카탈로그 무결 — `effect` 이름이 집계 사전의 키와 어긋나면 `charm_mods`가 **조용히 건너뛴다**
	#    (`if not out.has(eff): continue`). 참 하나가 통째로 무효가 되는데 아무 소리도 안 난다.
	const EFFECT_KEYS := ["damage_taken_mult", "outgoing_mult", "move_mult",
		"attack_speed_mult", "reflect_flat", "threat_mult"]
	# **조건부 참은 집계 사전을 타지 않는다** — 조건은 멤버 상태라 시점이 다르고(`F-010` §3.11.1),
	# 효과도 멤버가 직접 구현한다(`charm_ward_guard`의 이동방해 1회 무효화처럼). 그래서 둘로 나눠
	# 묻는다: 상시 참은 **집계 키**가 있어야 하고, 조건부 참은 **멤버에 구현**이 있어야 한다.
	# 어느 쪽도 아니면 그 참은 데이터에만 존재하고 게임엔 없다.
	var pm_src0 := FileAccess.get_file_as_string("res://scripts/party/party_member.gd")
	var orphan: Array = []
	var conds: Array = []
	for cid in sd.get_charm_ids():
		var row: Dictionary = sd.get_charm(String(cid))
		if String(row.get("display_name", "")) == "":
			orphan.append("%s(이름없음)" % cid)
		if row.has("condition"):
			conds.append(String(cid))
			if not pm_src0.contains('"%s"' % cid):
				orphan.append("%s(조건부인데 멤버 구현 없음)" % cid)
		elif not EFFECT_KEYS.has(String(row.get("effect", ""))):
			orphan.append("%s(effect '%s' 미집계)" % [cid, row.get("effect", "")])
	_expect(orphan.is_empty(), "참 카탈로그 — 전종 실효(집계 또는 멤버 구현) (%s)" % ("없음" if orphan.is_empty() else ", ".join(orphan)))

	# ② 조건부 참의 `condition`을 멤버가 실제로 판정할 줄 아는가 — 모르는 조건은 `false` 고정이라
	#    그 참은 영원히 안 걸린다. `party_member.charm_condition_met`의 match 문을 소스로 대조한다.
	var pm_src := FileAccess.get_file_as_string("res://scripts/party/party_member.gd")
	var unknown_cond: Array = []
	for ccid in conds:
		var cn := String(sd.get_charm(ccid).get("condition", ""))
		if cn != "" and not pm_src.contains('"%s"' % cn):
			unknown_cond.append("%s:%s" % [ccid, cn])
	_expect(unknown_cond.is_empty(), "조건부 참 — 조건 전건 판정 구현 (%s)" % ("없음" if unknown_cond.is_empty() else ", ".join(unknown_cond)))

	# ③ **본론** — 런을 띄우면 참이 실제로 걸려 있는가.
	#    비늘(받는 피해 −5%) + 허장허세(Tank 전용 위협 ×2)를 심는다: 전역 효과와 역할 한정 효과가
	#    **둘 다** 제대로 갈리는지 한 번에 본다.
	var bp = root.get_node_or_null("/root/Backpack")
	var saved: Array = bp.loose.duplicate(true)          # 실 저장 미오염 — 끝나면 되돌린다
	bp.loose = [
		{"id": "비늘 부적", "kind": "charm", "charm_id": "charm_ward_scale", "w": 1, "h": 1, "at_risk": true},
		{"id": "허장허세 부적", "kind": "charm", "charm_id": "charm_bluster", "w": 1, "h": 1, "at_risk": true},
	]
	var scn = load("res://scenes/run/dungeon_run.tscn").instantiate()
	root.add_child(scn)
	for _i in 40:
		await process_frame

	var party: Node = null
	for c in scn.get_children():
		if c.has_method("get_members"):
			party = c
			break
	if party == null:
		_expect(false, "런 씬 — 파티 노드 발견")
		_finish(bp, saved, scn)
		return

	var members: Array = party.get_members()
	_expect(members.size() >= 4, "런 씬 — 파티 4명 스폰")
	var tank_threat := 1.0
	var non_tank_threat := 0.0
	var all_dr := true
	for m in members:
		if float(m.charm_damage_taken_mult) > 0.951:      # 0.95여야 한다
			all_dr = false
		if String(m.get("class_id")) == "Tank":
			tank_threat = float(m.charm_threat_mult)
		else:
			non_tank_threat = maxf(non_tank_threat, float(m.charm_threat_mult))
	# **이 한 줄이 이 스위트의 존재 이유다.** 인벤을 열지 않은 상태에서 값이 붙어 있어야 한다.
	_expect(all_dr, "런 시작 직후 — 참 오오라가 전원에 적재됨(인벤 개폐 불요)")
	_expect(abs(tank_threat - 2.0) < 0.001, "applies_to — Tank 한정 참이 Tank에 걸림 (×%.2f)" % tank_threat)
	_expect(abs(non_tank_threat - 1.0) < 0.001, "applies_to — 비Tank에는 안 걸림 (×%.2f)" % non_tank_threat)

	# ④ 버리고 다시 줍는 왕복에서 **정체가 살아 있는가.** `_drop_def` 화이트리스트와
	#    `ItemDrop.interact()` 분기는 짝이다 — 한쪽만 있으면 반쪽만 살아 돌아온다.
	var inv: Node = null
	for c2 in scn.get_node("HUD").get_children():
		if c2.has_method("charm_mods"):
			inv = c2
			break
	if inv != null:
		var def: Dictionary = inv._drop_def({"id": "비늘 부적", "kind": "charm",
			"charm_id": "charm_ward_scale", "w": 1, "h": 1, "col": 0, "row": 0})
		_expect(String(def.get("charm_id", "")) == "charm_ward_scale",
			"버리기 def — charm_id 보존(정체 없는 익명 블록 방지)")
		var mdef: Dictionary = inv._drop_def({"id": "약한 마석", "kind": "manastone",
			"manastone_id": "ms_weak", "count": 5, "w": 1, "h": 1})
		_expect(String(mdef.get("manastone_id", "")) == "ms_weak", "버리기 def — manastone_id 보존")
	var drop_src := FileAccess.get_file_as_string("res://scripts/world/objects/item_drop.gd")
	for k in ["charm", "manastone", "consumable"]:
		_expect(drop_src.contains('"%s":' % k), "바닥 재획득 분기 존재 — %s" % k)

	# ⑤ 화면이 참을 설명하는가. 효과가 꺼져 있던 기간과 「원래 이런 물건」이 구분되지 않았다.
	var grid_src := FileAccess.get_file_as_string("res://scripts/ui/inventory/inventory_grid.gd")
	_expect(grid_src.contains("func _charm_tip("), "가방 툴팁 — 참 상세 존재")
	var gate_src := FileAccess.get_file_as_string("res://scripts/ui/hub_gate_panel.gd")
	_expect(not gate_src.contains('get_charm(String(it.get("charm_id", ""))).get("display", '),
		"성문 반입 확인 — display_name 사용(전건 '?' 표기 방지)")

	_finish(bp, saved, scn)


func _finish(bp, saved: Array, scn: Node) -> void:
	bp.loose = saved            # 메모리 복원(디스크는 애초에 안 건드렸다)
	scn.queue_free()
	if _ok:
		print("CHARM SMOKE PASSED")
		quit(0)
	else:
		print("CHARM SMOKE FAILED")
		quit(1)


func _expect(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false

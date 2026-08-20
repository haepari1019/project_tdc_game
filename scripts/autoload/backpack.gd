extends Node
## Backpack — the single persistent CARRIED inventory (At-Risk), the SoT for what the party brings
## into a run and keeps between runs (B-model unification). Distinct from Stash (safe storage).
##  · loose[]   = serializable item DESCRIPTORS in the pack (gear/skillbook/haul/consumable/generic).
##  · equipped{} = per-member assignment {member_key: {gear: base_gear_id, subs: [{base_ability_id,charges}×3]}}.
## Persisted as SaveProfile "backpack" section (single user://save.json). Loaded by BOTH the hub
## editor and the run inventory (autoload survives the scene change → it IS the hub→run bridge).
## SETTLE: extract keeps everything; death clears At-Risk = loose + equipped SUBS, but equipped GEAR
## is Safe (F-009 §3.7). ref: 사용자 B안 / F-007 / F-009 / DEC(meta-save).

var loose: Array = []          # [{id, kind, base_gear_id|base_ability_id|haul_material_id|consumable_id, w, h, count?, charges?, charges_max?, at_risk}]
var equipped: Dictionary = {}  # member_key(String) -> {"gear": base_gear_id|"", "subs": [ {base_ability_id, charges} | null ×3 ]}
var _seeded: bool = false
## 스타터 기어 id 스펙 정렬(GEAR-COR-000 §2) — 구 세이브의 _set id를 spec 슬러그로 1회 마이그레이션.
const GEAR_ID_ALIAS := {
	"gear_ward_tank_anchor_set": "gear_ward_tank_anchor_bulwark",
	"gear_ward_dps_press_set": "gear_ward_dps_press_rod",
	"gear_ward_nuker_ruin_set": "gear_ward_nuker_ruin_sight",
	"gear_ward_healer_mend_set": "gear_ward_healer_mend_lantern",
}


func _ready() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	var s: Dictionary = sp.section("backpack") if sp != null else {}
	if s.is_empty():
		_seed()
		save()
	else:
		loose = s.get("loose", [])
		equipped = s.get("equipped", {})
		_seeded = true
		_migrate_gear_ids()   # 구 세이브 _set id → spec 슬러그 (1회)
		migrate_subs_to_gear()  # M4 — 멤버 서브 → gear 인스턴스 슬롯 (1회)


## Rewrite legacy starter gear ids (equipped + loose) to the spec slugs. ref: GEAR-COR-000 §2.
func _migrate_gear_ids() -> void:
	var dirty := false
	for k in equipped.keys():
		var e: Dictionary = equipped[k]
		var g := String(e.get("gear", ""))
		if GEAR_ID_ALIAS.has(g):
			e["gear"] = GEAR_ID_ALIAS[g]
			equipped[k] = e
			dirty = true
	for it in loose:
		if typeof(it) == TYPE_DICTIONARY and GEAR_ID_ALIAS.has(String(it.get("base_gear_id", ""))):
			it["base_gear_id"] = GEAR_ID_ALIAS[String(it["base_gear_id"])]
			dirty = true
	if dirty:
		save()


func save() -> void:
	# 스모크/테스트는 이 스크립트를 **트리 밖 인스턴스**로 쓴다 — 그땐 절대경로 조회 자체가 에러를 뱉고
	# 저장할 곳도 없다. 조용히 넘긴다(실 오토로드는 항상 트리 안이라 영향 없음).
	if not is_inside_tree():
		return
	var sp := get_node_or_null("/root/SaveProfile")
	if sp != null:
		sp.put("backpack", {"loose": loose, "equipped": equipped})


## First-run starting kit (demo seed — the old inventory_ui hardcoded backpack). Plain descriptors;
## the grid rebuilds full visuals via ItemFactory when it loads these.
func _seed() -> void:
	if _seeded:
		return
	_seeded = true
	# F-009 §3.1.1 Hub Starter Skillbooks (StarterGrant) — 역할별 1권(Healer 2권), 분석 불요·
	# 즉시 장착 가능. + 부활 소비. Gear는 equipped, haul은 런 중 드롭. (구 데모 Ember 스타터 → 스펙 정렬)
	# DPS 자리 = **AB-053 작열 폭발** (DRIFT-137). spec F-008 §3.10.2가 지정한 `AB-028`이 DRIFT-115
	# (D4 → 채널링 클러스터 재정의)에서 폐기돼 유령 참조가 됐다. 대체 기준 = 스타터 gear(press_rod)의
	# 저작된 Q 슬롯 — `docs/design/dps_binding_kit.md` §공유3서브 + `BIND-019`(press_rod × IDA-024 ×
	# AB-053 @ slot 0)가 이미 등재돼 있어 **첫 런부터 「초월」 결속이 실제로 걸린다**. Basic tier·DPS 주력
	# 밴드(sub_bands = Nuker만 B2). 구 시드 AB-008은 slot-0 결속이 없어 GENERIC 폴백만 됐다.
	# 스킬북 탄환수는 PIN하지 않음 — 로드 시 add_skillbook_to_backpack가 master(skillbooks.json charges_max,
	# 현재 50~80)로 채움. (구 하드코딩 6/8/5가 새 값을 덮어쓰던 버그 수정. Slice01Data는 autoload 순서상
	# _seed 시점엔 미준비 → 여기서 조회 불가, 그래서 charges 생략으로 master 위임.)
	loose = [
		{"id": "전방위 방벽", "kind": "skillbook", "base_ability_id": "AB-033", "w": 1, "h": 1, "at_risk": true},
		{"id": "작열 폭발", "kind": "skillbook", "base_ability_id": "AB-053", "w": 1, "h": 1, "at_risk": true},
		{"id": "전격 제압", "kind": "skillbook", "base_ability_id": "AB-030", "w": 1, "h": 1, "at_risk": true},
		{"id": "침묵 결계", "kind": "skillbook", "base_ability_id": "AB-044", "w": 1, "h": 1, "at_risk": true},
		{"id": "구명 견인", "kind": "skillbook", "base_ability_id": "AB-045", "w": 1, "h": 1, "at_risk": true},
		{"id": "con_revive_scroll", "kind": "consumable", "consumable_id": "con_revive_scroll", "count": 3, "w": 1, "h": 1},
		# F-009 §3.8 / F-020 §3.2.0 — 스타터 마석. **빈 마석으로 첫 ENC에 들어가면 슬롯 스킬이 통째로
		# 잠긴다.** 수량 SSOT는 `manastones.json` `starter_grant`지만, 시드는 오토로드 순서상
		# Slice01Data 조회 전이라 여기에 값을 복제해 둔다 — 둘이 어긋나지 않게 `hub_smoke`가 대조한다.
		{"id": "약한 마석", "kind": "manastone", "manastone_id": "ms_weak", "count": 40, "w": 1, "h": 1, "at_risk": true},
		# F-010 §3.11 참 — 첫 런 소량(I-007 §14.3). 마석과 **직교하는 압력**이다: 마석은 쓰면 줄고,
		# 참은 줄지 않는 대신 **칸을 계속 먹는다**. id 목록 SSOT = charms.json starter_grant(hub_smoke 대조).
		{"id": "비늘 부적", "kind": "charm", "charm_id": "charm_ward_scale", "w": 1, "h": 1, "at_risk": true},
		{"id": "바람 부적", "kind": "charm", "charm_id": "charm_swift_step", "w": 1, "h": 1, "at_risk": true},
	]
	# Worn starter Identity Gear per role (F-008 §3.7). Gear lives in equipped (Safe on death),
	# NOT in the Stash library — equipping a spare from the stash consumes it; the worn gear here.
	# `slot_abilities` = gear 인스턴스 귀속 Q/E/R (`D-019` §3). 스타터 gear는 슬롯 1칸이라
	# 나머지 2칸은 트리 `Slot` 노드를 사기 전엔 잠겨 있다(`gear_skill_slot_count_max`).
	equipped = {
		"Tank": {"gear": "gear_ward_tank_anchor_bulwark", "subs": [null, null, null], "slot_abilities": [null, null, null]},
		"DPS": {"gear": "gear_ward_dps_press_rod", "subs": [null, null, null], "slot_abilities": [null, null, null]},
		"Nuker": {"gear": "gear_ward_nuker_ruin_sight", "subs": [null, null, null], "slot_abilities": [null, null, null]},
		"Healer": {"gear": "gear_ward_healer_mend_lantern", "subs": [null, null, null], "slot_abilities": [null, null, null]},
	}


## 테스트/디버그 — 캐리(낱개 + 장착)를 데모 시드로 초기화.
func reset_to_seed() -> void:
	loose = []
	equipped = {}
	_seeded = false
	_seed()
	save()


# --- loose carry API ---------------------------------------------------------

## Replace the loose contents (the run/hub commit their grid here). Strips runtime-only fields.
func set_loose(items: Array) -> void:
	loose = []
	for it in items:
		loose.append(_strip(it))
	save()


## A copy of the loose descriptors (the grid rebuilds full items from these).
func get_loose() -> Array:
	return loose.duplicate(true)


## Death (F-007 §3.7) — the whole loose carry is At-Risk → lost. Stash (safe) untouched.
func clear_loose() -> void:
	loose = []
	save()


# --- equipped assignment API (I3/I4 wire member slots to these) --------------

## **D2 — gear를 갈면 슬롯 AB는 소멸한다**(`F-008` §3.10, 사용자 판정 "spec 정본 · 교체 시 소멸").
## 소멸한 AB id 목록을 돌려주니 호출부는 **미리 확인 모달**을 띄우고(모딩 패널), 사후에 로그를 남긴다.
## 같은 gear로 재장착(id 동일)이면 아무것도 잃지 않는다 — 인스턴스가 그대로이므로.
## `inst`는 스태시 gear **인스턴스**({base_gear_id, rolled_identity_skill_id?, rolls?}) — 넘기면 굴림이
## 따라온다. 안 넘기면 굴림을 **지운다**: 새 건에 옛 건의 굴림이 남으면 정체성이 어긋난다(F-008 §3.7).
func set_member_gear(member_key: String, base_gear_id: String, inst: Dictionary = {}) -> Array:
	var e: Dictionary = equipped.get(member_key, {})
	var lost: Array = []
	# **맨몸 → 착용**은 교체가 아니다(잃을 게 없다). 소멸은 **이미 신고 있던 건을 벗을 때**만.
	# `_bind_gear`의 런타임 판정과 같은 조건이어야 둘이 갈리지 않는다.
	var prev := String(e.get("gear", ""))
	var changed: bool = prev != "" and prev != base_gear_id
	if changed:
		lost = clear_gear_slots(member_key)
		e = equipped.get(member_key, {})           # clear_gear_slots가 다시 쓴 걸 읽는다
		e.erase("rolled_identity")
		e.erase("rolls")
		e["subs"] = [null, null, null]             # 구 모델 폴백도 같이 소멸(안 그러면 옛 서브가 부활한다)
	if String(inst.get("rolled_identity_skill_id", "")) != "":
		e["rolled_identity"] = String(inst["rolled_identity_skill_id"])
	if typeof(inst.get("rolls", null)) == TYPE_DICTIONARY and not (inst["rolls"] as Dictionary).is_empty():
		e["rolls"] = inst["rolls"]
	e["gear"] = base_gear_id
	equipped[member_key] = e
	save()
	return lost


## 이 역할이 **지금 실제로 쓸 수 있는** gear 스킬 슬롯 수 = `D-019` §3 `gearSkillSlotCount`.
##   `clamp(1 + 트리 Slot 노드 합, 1, gear.gear_skill_slot_count_max)`
## 기본 1칸은 공짜다(gear를 끼면 Q는 열린다). 나머지는 트리 `Slot` 노드로 산다.
##
## **`smithy` tier를 여기서 더하지 않는다.** `F-008` §3.10 사다리(starter 1 → `smithy` T2 = 2 → T3 = 3)와
## `F-020` §3.10 `Slot` 노드(「예: smithy 연동」)는 **같은 +1**이다 — 노드가 구매 표면이고 대장간은
## `facility_req` 게이트다(`hub_profile.tree_check`). 두 축을 더하면 대장간 없이 트리만으로 3칸이 열려
## 스펙 사다리가 무너진다.
##
## 어느 쪽이든 **gear의 천장을 넘지 못한다**: 스타터 gear(max 1)를 낀 채로는 뭘 사도 1칸이고,
## 슬롯을 늘리는 첫 걸음은 **gear 교체**다(`D-019` §2).
func gear_slot_count(member_key: String) -> int:
	var gm: Dictionary = Slice01Data.get_gear_master(String(member_entry(member_key).get("gear", "")))
	if gm.is_empty():
		return 0                                   # gear 없음 = 슬롯 없음
	var cap := int(gm.get("gear_skill_slot_count_max", 3))
	var hp := get_node_or_null("/root/HubProfile") if is_inside_tree() else null
	var bonus: int = int(hp.tree_slot_bonus(member_key)) if hp != null else 0
	return clampi(1 + bonus, 1, maxi(cap, 1))


func set_member_subs(member_key: String, subs: Array) -> void:
	var e: Dictionary = equipped.get(member_key, {})
	e["subs"] = subs
	equipped[member_key] = e
	save()


func member_entry(member_key: String) -> Dictionary:
	var e = equipped.get(member_key, {})
	return e if typeof(e) == TYPE_DICTIONARY else {}


## Death — equipped SUBS are At-Risk (lost), equipped GEAR is Safe (kept). F-009 §3.7.
## `slot_abilities`는 **건드리지 않는다** — gear 인스턴스에 귀속돼 있고 gear는 Safe다(`F-009` §3.7).
## 죽어서 사라지는 건 낱개 스킬북(`loose`)과 잔탄(`subs`)뿐이다. 슬롯 AB가 사라지는 유일한 길은
## **gear 교체**(D2 소멸, `clear_gear_slots`).
func clear_at_risk_equipped() -> void:
	for k in equipped.keys():
		var e: Dictionary = equipped[k]
		e["subs"] = [null, null, null]
		equipped[k] = e
	save()


## Apply persisted equipped GEAR + SUBS to a LIVE party (run start / hub load). Keyed by class_id
## (4 distinct roles). Gear overrides the starter spawn (F-008); equipping a sub resets it to max
## 탄수, so we then RESTORE the persisted remaining charges (I5) — a partially-spent skillbook carries
## its 탄수 across runs (F-009).
func apply_to_party(party) -> void:
	if party == null or not party.has_method("get_members"):
		return
	for m in party.get_members():
		if m == null or not is_instance_valid(m):
			continue
		var e: Dictionary = member_entry(String(m.get("class_id")))
		# Equipped Identity Gear — restore the persisted worn gear (overrides party_controller starter).
		var gid: String = String(e.get("gear", ""))
		if gid != "" and m.has_method("equip_gear"):
			var gm: Dictionary = Slice01Data.get_gear_master(gid)
			if not gm.is_empty():
				# F-008 §3.7 — 인스턴스 rolled identity/rolls 주입(있을 때만 → 없으면 bundled 폴백, G2).
				var rid := String(e.get("rolled_identity", ""))
				if rid != "":
					gm["rolled_identity_skill_id"] = rid
				if e.has("rolls") and typeof(e["rolls"]) == TYPE_DICTIONARY and not (e["rolls"] as Dictionary).is_empty():
					gm["rolls"] = e["rolls"]
				m.equip_gear(gm)
		# Q/E/R 슬롯 — **정본은 gear 인스턴스**(`D-019` §3). `subs`는 구 모델 폴백 + 탄수 보관용.
		# gear 슬롯에 뭐가 끼워져 있으면 그게 이긴다. 같은 AB면 `subs`의 잔탄을 이어받는다.
		if m.has_method("equip_skillbook_by_id"):
			var subs: Array = e.get("subs", [])
			var slots: Array = gear_slot_abilities(String(m.get("class_id")))
			# `D-019` §3 `effectiveSlotAbilities` — **해금된 칸만** 살아난다. 잠긴 칸은 정본이 `null`이라
			# 구 세이브가 3칸을 채워 뒀어도 여기서 잘린다(스타터 gear는 1칸). 조용히 자르지 않고 알린다.
			var open_slots: int = gear_slot_count(String(m.get("class_id")))
			for j in 3:
				m.set_skillbook(j, null)   # 저장분이 정본 — 이전 상태를 먼저 비운다(모딩에서 뺀 슬롯이 남지 않게)
				if j >= open_slots:
					var blocked = slots[j] if slots[j] != null else (subs[j] if j < subs.size() else null)
					if typeof(blocked) == TYPE_DICTIONARY:
						push_warning("[TDC] %s 슬롯 %d 잠김(열린 칸 %d) — '%s' 미장착. gear 교체 또는 트리 Slot 노드 필요." % [String(m.get("class_id")), j, open_slots, String(blocked.get("base_ability_id", "?"))])
					continue
				var s = subs[j] if j < subs.size() else null
				var g = slots[j]
				if typeof(g) == TYPE_DICTIONARY and String(g.get("base_ability_id", "")) != "":
					# gear 슬롯이 정본 — subs가 다른 AB를 들고 있으면 탄수는 버린다(다른 스킬이니까).
					if typeof(s) != TYPE_DICTIONARY or String(s.get("base_ability_id", "")) != String(g["base_ability_id"]):
						s = {"base_ability_id": String(g["base_ability_id"])}
				if typeof(s) == TYPE_DICTIONARY and String(s.get("base_ability_id", "")) != "":
					m.equip_skillbook_by_id(j, String(s["base_ability_id"]), s.get("affix", {}))   # D-018 affix 복원
					# Restore persisted remaining 탄수 (equip set it to max). I5 charge persistence.
					if s.has("charges"):
						var inst = m.get_skillbook(j)
						if inst != null:
							inst.charges = clampi(int(s["charges"]), 0, int(inst.charges_max))


## **M4 마이그레이션** — 구 모델은 서브가 **멤버**에 붙어 있었다(`equipped[cls].subs`). P4b 정본은
## **gear 인스턴스 귀속**(`D-019` §3 `equippedSlotAbilities[3]`)이라, 착용 중인 gear 쪽으로 1회 옮긴다.
## 옮긴 뒤에도 `subs`를 **지우지 않는다** — M5(F-009 폐기) 전까지 구 경로 폴백이 남아 있고, 지우면
## 롤백이 불가능해진다. 읽기 우선순위는 gear > subs.
func migrate_subs_to_gear() -> void:
	var moved := 0
	for k in equipped.keys():
		var e: Dictionary = equipped[k]
		if e.has("slot_abilities"):
			continue                                   # 이미 이관됨
		var subs: Array = e.get("subs", [])
		var slots: Array = [null, null, null]
		for j in mini(3, subs.size()):
			var sdd = subs[j]
			if typeof(sdd) == TYPE_DICTIONARY and String(sdd.get("base_ability_id", "")) != "":
				slots[j] = {"base_ability_id": String(sdd["base_ability_id"])}
				moved += 1
		e["slot_abilities"] = slots
		equipped[k] = e
	if moved > 0:
		print("[TDC] M4 마이그레이션 — 멤버 서브 %d개를 gear 슬롯으로 이관" % moved)
	save()


## 이 역할이 착용한 gear의 슬롯 AB(길이 3, null 포함). `D-019` §3 `equippedSlotAbilities`.
func gear_slot_abilities(member_key: String) -> Array:
	var e: Dictionary = member_entry(member_key)
	var a = e.get("slot_abilities", null)
	return a if typeof(a) == TYPE_ARRAY and (a as Array).size() == 3 else [null, null, null]


func set_gear_slot_ability(member_key: String, slot: int, base_ability_id: String) -> void:
	if slot < 0 or slot > 2:
		return
	var e: Dictionary = equipped.get(member_key, {})
	var a: Array = gear_slot_abilities(member_key)
	a[slot] = null if base_ability_id == "" else {"base_ability_id": base_ability_id}
	e["slot_abilities"] = a
	equipped[member_key] = e
	save()


## 이 슬롯에 이 AB를 끼울 수 있는가. 거부 사유를 **말로** 돌려준다 — 모딩 패널이 그대로 띄운다.
##   `slot`      : gear의 열린 칸 수(`gear_slot_count`) 밖 → "slot"
##   `no_gear`   : gear 미착용 → 끼울 데가 없다
##   `family`    : `allowed_slot_families` 불일치 또는 Role Gate 불통과 (`F-008` §3.10 / `F-009` §3.2.1)
##   `locked`    : 트리 `Unlock` 노드 미구매 (`F-020` §3.10)
##   `dup`       : 같은 AB가 다른 칸에 이미 있음 — 한 gear에 같은 스킬 두 번은 막는다
func slot_equip_check(member_key: String, slot: int, base_ability_id: String) -> Dictionary:
	if base_ability_id == "":
		return {"ok": false, "reason": "invalid"}
	var gid := String(member_entry(member_key).get("gear", ""))
	if gid == "":
		return {"ok": false, "reason": "no_gear"}
	if slot < 0 or slot >= gear_slot_count(member_key):
		return {"ok": false, "reason": "slot"}
	if not Slice01Data.gear_allows_slot_ability(gid, base_ability_id, member_key):
		return {"ok": false, "reason": "family"}
	var hp := get_node_or_null("/root/HubProfile") if is_inside_tree() else null
	if hp != null and not bool(hp.is_shop_unlocked(base_ability_id)):
		return {"ok": false, "reason": "locked"}
	var cur: Array = gear_slot_abilities(member_key)
	for j in cur.size():
		if j != slot and typeof(cur[j]) == TYPE_DICTIONARY and String(cur[j].get("base_ability_id", "")) == base_ability_id:
			return {"ok": false, "reason": "dup"}
	return {"ok": true}


## 검사 후 장착. 통과하면 `set_gear_slot_ability`로 내려간다(그쪽은 검사 없는 저수준 쓰기 — 마이그레이션·
## 테스트가 쓴다). UI 경로는 **반드시 이쪽**을 쓸 것.
func equip_slot_ability(member_key: String, slot: int, base_ability_id: String) -> Dictionary:
	var chk := slot_equip_check(member_key, slot, base_ability_id)
	if bool(chk.get("ok", false)):
		set_gear_slot_ability(member_key, slot, base_ability_id)
	return chk


## **D2 소멸** — gear를 갈아끼우면 이전 인스턴스에 끼운 슬롯 AB가 **전부 사라진다**(`F-008` §3.10).
## 재획득은 트리 해금 + 상점 재구매(`F-009` §3.9.3). 되돌릴 수 없으므로 호출부가 확인을 받아야 한다.
func clear_gear_slots(member_key: String) -> Array:
	var lost: Array = []
	for s in gear_slot_abilities(member_key):
		if typeof(s) == TYPE_DICTIONARY:
			lost.append(String(s.get("base_ability_id", "")))
	var e: Dictionary = equipped.get(member_key, {})
	e["slot_abilities"] = [null, null, null]
	equipped[member_key] = e
	save()
	return lost


## Capture a live party's equipped GEAR + SUBS into the persistent store (extract / hub deploy). One save.
## 슬롯 AB(`slot_abilities`)는 **캡처하지 않는다** — 그건 gear 인스턴스 소유라 허브 모딩에서만 바뀐다.
## 런 중에 바뀌는 건 `charges`뿐이고 그건 `subs`가 계속 들고 있다.
func capture_from_party(party) -> void:
	if party == null or not party.has_method("get_members"):
		return
	for m in party.get_members():
		if m == null or not is_instance_valid(m):
			continue
		var e: Dictionary = equipped.get(String(m.get("class_id")), {})
		e["gear"] = String(m.get("base_gear_id"))   # worn Identity Gear archetype (Safe on death — F-009 §3.7)
		e["rolled_identity"] = String(m.get("identity_skill_id"))   # F-008 §3.7 effective rolled identity (Node.get = 1-arg)
		var gr = m.get("gear_rolls")
		if typeof(gr) == TYPE_DICTIONARY and not (gr as Dictionary).is_empty():
			e["rolls"] = gr
		else:
			e.erase("rolls")
		if m.has_method("get_skillbook"):
			var subs: Array = []
			for j in 3:
				var sb = m.get_skillbook(j)
				if sb != null:
					subs.append({"base_ability_id": String(sb.get("base_ability_id", "")), "charges": int(sb.get("charges", 0)), "affix": sb.get("affix", {})})
				else:
					subs.append(null)
			e["subs"] = subs
		equipped[String(m.get("class_id"))] = e
	save()


## Strip runtime/non-serializable fields (live grid Panel node, transient grid col/row) from an
## item dict so only the persistent descriptor is stored. Color is rebuilt from kind/id on load.
func _strip(it: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in ["id", "kind", "base_gear_id", "base_ability_id", "haul_material_id", "manastone_id", "charm_id",
			"consumable_id", "w", "h", "count", "charges", "charges_max", "at_risk", "equipped",
			"rolled_identity_skill_id", "rolls",    # F-008 §3.7 gear 인스턴스 굴림 보존(G2)
			"affix"]:                               # D-018 §7.3/§7.6 스킬북 affix 인스턴스 보존
		if it.has(key):
			out[key] = it[key]
	return out

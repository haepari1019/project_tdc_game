extends Node
## Player stash (F-010 / F-008 / F-009 demo) — the persistent pool of OWNED items the
## deployment hub draws from: Identity Gear, skillbooks, consumables. The hub moves items
## stash ↔ run inventory ↔ character slots; what's brought is At-Risk (F-007). Seeded with
## demo content on first load. ref: F-010 §3.2.

var gear: Array = []               # owned gear 인스턴스 {base_gear_id, rolled_identity_skill_id?, rolls?} — F-008 §3.7. 레거시=문자열(로드 시 정규화).
var skillbooks: Array = []         # owned 스킬북 인스턴스 {base_ability_id, affix?, charges?} — D-018 §7.3. 레거시=문자열(로드 시 정규화).
var consumables: Dictionary = {}   # consumable_id -> count owned
# 재료(haul)는 일반 스태시가 아니라 HubProfile 금고(vault)에 일원화 — 별도 store 두지 않음(혼란 방지).

# 영속 = SaveProfile 단일 파일(user://save.json)의 "stash" 섹션 (구 user://stash.json은 1회 마이그레이션).
var _seeded: bool = false


func _ready() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	var s: Dictionary = sp.section("stash") if sp != null else {}
	if s.is_empty():     # 섹션 없음(최초) → 시드 + 저장. 빈 배열로 저장된 상태는 키가 있어 apply.
		_seed()
		save_stash()
	else:
		apply_dict(s)


## Persist owned items — 변경마다 호출. SaveProfile "stash" 섹션(단일 파일).
func save_stash() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	if sp != null:
		sp.put("stash", to_dict())


func to_dict() -> Dictionary:
	return {"gear": gear, "skillbooks": skillbooks, "consumables": consumables}


func apply_dict(d: Dictionary) -> void:
	gear = d.get("gear", [])
	_normalize_gear()   # 레거시 세이브(문자열 gear) → 인스턴스 dict 마이그레이션
	skillbooks = d.get("skillbooks", [])
	_normalize_skillbooks()   # 레거시 세이브(문자열 skillbook) → 인스턴스 dict 마이그레이션
	consumables = d.get("consumables", {})
	_seeded = true


## gear 엔트리를 인스턴스 dict로 정규화 — 시드/레거시 세이브의 문자열 base_gear_id → {base_gear_id}.
## 인스턴스 = {base_gear_id, rolled_identity_skill_id?, rolls?} (F-008 §3.7 스페어도 굴린 정체성·옵션 보존).
func _normalize_gear() -> void:
	for i in gear.size():
		if typeof(gear[i]) == TYPE_STRING:
			gear[i] = {"base_gear_id": String(gear[i])}


## skillbook 엔트리 정규화 — 시드/레거시 세이브의 문자열 base_ability_id → {base_ability_id}.
## 인스턴스 = {base_ability_id, affix?, charges?} (D-018 §7.3 — 스태시도 affix·잔여탄 보존).
func _normalize_skillbooks() -> void:
	for i in skillbooks.size():
		if typeof(skillbooks[i]) == TYPE_STRING:
			skillbooks[i] = {"base_ability_id": String(skillbooks[i])}


func _seed() -> void:
	if _seeded:
		return
	_seeded = true
	# Demo stash — SPARE Identity Gear: the full GEAR catalog (17 alternatives to swap to; worn
	# starters live in Backpack.equipped, not here — F-008 ownership). Looted-AB skillbooks, revives.
	gear = [
		"gear_ward_tank_kite_shield", "gear_ward_tank_beacon_hook", "gear_ward_tank_march_plate", "gear_ward_tank_rampart_wall", "gear_ward_tank_sentinel_aegis",
		"gear_ward_dps_weave_staff", "gear_ward_dps_rift_needle", "gear_ward_dps_ember_wand", "gear_ward_dps_brand_foci", "gear_ward_dps_tide_censer",
		"gear_ward_nuker_scout_frame", "gear_ward_nuker_flank_knife", "gear_ward_nuker_hex_scope", "gear_mag_nuker_coil_rifle", "gear_mag_nuker_volt_lance",
		"gear_ward_healer_ward_sigil", "gear_ward_healer_beacon_lantern",
	]
	skillbooks = ["AB-002", "AB-010", "AB-011", "AB-037"]
	consumables = {"con_revive_scroll": 8}
	_normalize_gear()         # 시드는 문자열로 적고 인스턴스로 정규화(roll/affix 없음=base)
	_normalize_skillbooks()


## 테스트/디버그 — 스태시를 데모 시드로 초기화.
func reset_to_seed() -> void:
	gear = []
	skillbooks = []
	consumables = {}
	_seeded = false
	_seed()
	save_stash()


## Remove one consumable from the stash (taken into the run). Returns true if available.
func take_consumable(cid: String, amount: int = 1) -> bool:
	var have := int(consumables.get(cid, 0))
	if have < amount:
		return false
	consumables[cid] = have - amount
	if int(consumables[cid]) <= 0:
		consumables.erase(cid)
	save_stash()
	return true


## Return a consumable to the stash (un-brought).
func return_consumable(cid: String, amount: int = 1) -> void:
	consumables[cid] = int(consumables.get(cid, 0)) + amount
	save_stash()


## Permanently remove one owned gear from the stash (hub 버리기). True if it was present.
func remove_gear(base_gear_id: String) -> bool:
	for i in gear.size():
		var g = gear[i]
		var bid := String(g.get("base_gear_id", "")) if typeof(g) == TYPE_DICTIONARY else String(g)
		if bid == base_gear_id:
			gear.remove_at(i)
			save_stash()
			return true
	return false


## Add one owned gear to the stash (무기고 구매 / 회수). 상점 기어 = bundled identity(굴림 없음, 확정 세트).
func add_gear(base_gear_id: String, rolled_identity_skill_id: String = "", rolls: Dictionary = {}) -> void:
	if base_gear_id.is_empty():
		return
	var inst := {"base_gear_id": base_gear_id}
	if not rolled_identity_skill_id.is_empty():
		inst["rolled_identity_skill_id"] = rolled_identity_skill_id
	if not rolls.is_empty():
		inst["rolls"] = rolls
	gear.append(inst)
	save_stash()


## Add one owned skillbook to the stash (shop 구매 / 회수). 상점 생본=affix 없음; 회수 본은 affix/잔여탄 보존.
func add_skillbook(base_ability_id: String, affix: Dictionary = {}, charges: int = -1) -> void:
	if base_ability_id.is_empty():
		return
	var inst := {"base_ability_id": base_ability_id}
	if not affix.is_empty():
		inst["affix"] = affix          # D-018 §7.3 affix 보존
	if charges >= 0:
		inst["charges"] = charges      # 잔여 탄 보존
	skillbooks.append(inst)
	save_stash()


## Permanently remove one owned skillbook (analysis/sink/버리기) by base id. affix본 보존을 위해 plain(무affix)
## 사본을 우선 제거하고, 모두 affix면 첫 매칭을 제거. True if one was present.
func remove_skillbook(base_ability_id: String) -> bool:
	var first := -1
	for i in skillbooks.size():
		var s = skillbooks[i]
		var bid := String(s.get("base_ability_id", "")) if typeof(s) == TYPE_DICTIONARY else String(s)
		if bid != base_ability_id:
			continue
		if first < 0:
			first = i
		var has_affix := typeof(s) == TYPE_DICTIONARY and not (s.get("affix", {}) as Dictionary).is_empty()
		if not has_affix:
			skillbooks.remove_at(i)   # plain 사본 우선 소멸 → affix본 보존
			save_stash()
			return true
	if first < 0:
		return false
	skillbooks.remove_at(first)
	save_stash()
	return true

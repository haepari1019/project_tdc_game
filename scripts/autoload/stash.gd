extends Node
## Player stash (F-010 / F-008 / F-009 demo) — the persistent pool of OWNED items the
## deployment hub draws from: Identity Gear, skillbooks, consumables. The hub moves items
## stash ↔ run inventory ↔ character slots; what's brought is At-Risk (F-007). Seeded with
## demo content on first load. ref: F-010 §3.2.

var gear: Array = []               # owned base_gear_id strings (Identity Gear)
var skillbooks: Array = []         # owned base_ability_id strings (skillbooks)
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
	skillbooks = d.get("skillbooks", [])
	consumables = d.get("consumables", {})
	_seeded = true


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
	var i := gear.find(base_gear_id)
	if i < 0:
		return false
	gear.remove_at(i)
	save_stash()
	return true


## Add one owned skillbook to the stash (shop 구매 / 회수). F-009 상점 생본은 affix 없음(base만 보관).
func add_skillbook(base_ability_id: String) -> void:
	if base_ability_id.is_empty():
		return
	skillbooks.append(base_ability_id)
	save_stash()


## Permanently remove one owned skillbook from the stash (hub 버리기). True if it was present.
func remove_skillbook(base_ability_id: String) -> bool:
	var i := skillbooks.find(base_ability_id)
	if i < 0:
		return false
	skillbooks.remove_at(i)
	save_stash()
	return true

extends Node
## Player stash (F-010 / F-008 / F-009 demo) — the persistent pool of OWNED items the
## deployment hub draws from: Identity Gear, skillbooks, consumables. The hub moves items
## stash ↔ run inventory ↔ character slots; what's brought is At-Risk (F-007). Seeded with
## demo content on first load. ref: F-010 §3.2.

var gear: Array = []               # owned base_gear_id strings (Identity Gear)
var skillbooks: Array = []         # owned base_ability_id strings (skillbooks)
var consumables: Dictionary = {}   # consumable_id -> count owned

const SAVE_PATH := "user://stash.json"   # 소유 아이템 영속 (B6)
var _seeded: bool = false


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		load_stash()
	else:
		_seed()
		save_stash()


## Persist owned items (B6) — 변경마다 호출. user:// JSON.
func save_stash() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"gear": gear, "skillbooks": skillbooks, "consumables": consumables}))
	f.close()


func load_stash() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return
	gear = d.get("gear", [])
	skillbooks = d.get("skillbooks", [])
	consumables = d.get("consumables", {})
	_seeded = true


func _seed() -> void:
	if _seeded:
		return
	_seeded = true
	# Demo stash — the 4 role Identity Gears + a spare set, looted-AB skillbooks, revive scrolls.
	gear = [
		"gear_ward_tank_anchor_set", "gear_ward_dps_press_set",
		"gear_ward_nuker_ruin_set", "gear_ward_healer_mend_set",
	]
	skillbooks = ["AB-002", "AB-010", "AB-011", "AB-037"]
	consumables = {"con_revive_scroll": 8}


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


## Permanently remove one owned skillbook from the stash (hub 버리기). True if it was present.
func remove_skillbook(base_ability_id: String) -> bool:
	var i := skillbooks.find(base_ability_id)
	if i < 0:
		return false
	skillbooks.remove_at(i)
	save_stash()
	return true

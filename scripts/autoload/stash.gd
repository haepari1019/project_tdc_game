extends Node
## Player stash (F-010 / F-008 / F-009 demo) — the persistent pool of OWNED items the
## deployment hub draws from: Identity Gear, skillbooks, consumables. The hub moves items
## stash ↔ run inventory ↔ character slots; what's brought is At-Risk (F-007). Seeded with
## demo content on first load. ref: F-010 §3.2.

var gear: Array = []               # owned base_gear_id strings (Identity Gear)
var skillbooks: Array = []         # owned base_ability_id strings (skillbooks)
var consumables: Dictionary = {}   # consumable_id -> count owned

var _seeded: bool = false


func _ready() -> void:
	_seed()


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
	return true


## Return a consumable to the stash (un-brought).
func return_consumable(cid: String, amount: int = 1) -> void:
	consumables[cid] = int(consumables.get(cid, 0)) + amount


## Permanently remove one owned gear from the stash (hub 버리기). True if it was present.
func remove_gear(base_gear_id: String) -> bool:
	var i := gear.find(base_gear_id)
	if i < 0:
		return false
	gear.remove_at(i)
	return true


## Permanently remove one owned skillbook from the stash (hub 버리기). True if it was present.
func remove_skillbook(base_ability_id: String) -> bool:
	var i := skillbooks.find(base_ability_id)
	if i < 0:
		return false
	skillbooks.remove_at(i)
	return true

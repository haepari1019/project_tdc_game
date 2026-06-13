extends Node3D
## Per-kill loot drops (F-009 / F-010) — on CombatController.enemy_defeated, rolls one drop
## (skillbook from the enemy's lootable AB > gear > generic item) and spawns an ItemDrop world
## pickup at the death position. setup(inventory_ui); connect combat.enemy_defeated → on_enemy_defeated.

const ItemDrop := preload("res://scripts/world/objects/item_drop.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")

## PH loot table — a defeated enemy drops one of these as a world pickup. ref: F-010.
const LOOT_TABLE: Array = [
	{"id": "Ammo", "w": 1, "h": 1, "color": Color(0.80, 0.55, 0.30)},
	{"id": "Medkit", "w": 1, "h": 1, "color": Color(0.85, 0.30, 0.30)},
	{"id": "Scrap", "w": 1, "h": 1, "color": Color(0.55, 0.58, 0.62)},
	{"id": "Cell", "w": 1, "h": 2, "color": Color(0.62, 0.45, 0.82)},
]
## PH gear-loot pool — dungeon-dropped Identity Gear (F-008 §3.3 / DEC-20260611-001; looted =
## At Risk). Same-role (Tank) equippable + cross-role (Healer) to show the equipClasses reject.
const GEAR_LOOT: Array = ["gear_ward_tank_anchor_set", "gear_ward_healer_mend_set"]
const GEAR_DROP_CHANCE := 0.08          # gear is RARE (per-kill, after the skillbook roll). (tuning)
const SKILLBOOK_DROP_CHANCE := 0.85     # high so lootable-AB enemies almost always drop. (tuning)

var _inv: Node


func setup(inventory_ui: Node) -> void:
	_inv = inventory_ui


## CombatController.enemy_defeated → spawn a PH loot drop at the death position.
func on_enemy_defeated(world_pos: Vector3, ability_refs: Array) -> void:
	var def := _roll_loot_def(ability_refs)
	if def.is_empty():
		return
	var drop := ItemDrop.new()
	drop.setup(_inv, def)
	drop.position = Vector3(world_pos.x, 0.0, world_pos.z)
	add_child(drop)


## Per-kill roll: (1) skillbook — if this enemy USES a lootable AB, roll for that AB
## (F-009/DEC-20260611-002); (2) else gear; (3) else generic item.
func _roll_loot_def(ability_refs: Array) -> Dictionary:
	var lootable: Array = []
	for r in ability_refs:
		if not Slice01Data.get_skillbook_master(String(r)).is_empty():
			lootable.append(String(r))
	if not lootable.is_empty() and randf() < SKILLBOOK_DROP_CHANCE:
		return _make_skillbook_drop_def(String(lootable[randi() % lootable.size()]))
	if randf() < GEAR_DROP_CHANCE and not GEAR_LOOT.is_empty():
		return _make_gear_drop_def(String(GEAR_LOOT[randi() % GEAR_LOOT.size()]))
	return (LOOT_TABLE[randi() % LOOT_TABLE.size()] as Dictionary).duplicate()


func _make_skillbook_drop_def(base_ability_id: String) -> Dictionary:
	var m: Dictionary = Slice01Data.get_skillbook_master(base_ability_id)
	var classes: Array = m.get("equip_classes", [])
	var cid := String(classes[0]) if not classes.is_empty() else "DPS"
	return {
		"id": String(m.get("display_name", base_ability_id)),
		"w": 1, "h": 1,
		"color": UnitVisuals.role_color(cid).lightened(0.15),
		"kind": "skillbook",
		"base_ability_id": base_ability_id,
	}


func _make_gear_drop_def(base_gear_id: String) -> Dictionary:
	var m: Dictionary = Slice01Data.get_gear_master(base_gear_id)
	var classes: Array = m.get("equip_classes", [])
	var cid := String(classes[0]) if not classes.is_empty() else "Tank"
	return {
		"id": String(m.get("display_name", base_gear_id)),
		"w": 2, "h": 2,
		"color": UnitVisuals.role_color(cid),
		"kind": "gear",
		"base_gear_id": base_gear_id,
	}

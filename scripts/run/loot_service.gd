extends Node3D
## Per-kill loot drops (F-009 / F-010) — on CombatController.enemy_defeated, rolls one drop
## (skillbook from the enemy's lootable AB > gear; else NO drop) and spawns an ItemDrop world
## pickup at the death position. setup(inventory_ui); connect combat.enemy_defeated → on_enemy_defeated.
## (generic filler loot removed per 사용자 요청 — only lootable skill / 장비 / haul(ENC clear) drop.)

const ItemDrop := preload("res://scripts/world/objects/item_drop.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")

## PH gear-loot pool — dungeon-dropped Identity Gear (F-008 §3.3 / DEC-20260611-001; looted =
## At Risk). Same-role (Tank) equippable + cross-role (Healer) to show the equipClasses reject.
const GEAR_LOOT: Array = ["gear_ward_tank_anchor_set", "gear_ward_healer_mend_set"]
const GEAR_DROP_CHANCE := 0.08          # gear is RARE (per-kill, after the skillbook roll). (tuning)
const SKILLBOOK_DROP_CHANCE := 0.85     # high so lootable-AB enemies almost always drop. (tuning)
# haulMaterial(F-029/D-029)은 per-kill가 아니라 ENC(분대) 클리어 시 HUB-COR-000 §3 표로 드롭
# (on_squad_cleared). combat.squad_cleared → 여기 연결.

var _inv: Node


func setup(inventory_ui: Node) -> void:
	_inv = inventory_ui


## Drop a backpack item back into the world (player Shift+우클릭 버리기) — a re-pickable ItemDrop
## beside the player. Reuses the item's def so pickup routing (gear/skillbook/haul/generic) restores it.
func drop_item(def: Dictionary, world_pos: Vector3) -> void:
	if def.is_empty():
		return
	var drop := ItemDrop.new()
	drop.setup(_inv, def)
	drop.position = Vector3(world_pos.x + 1.0, 0.0, world_pos.z)
	add_child(drop)


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
## (F-009/DEC-20260611-002); (2) else gear; (3) else NO drop ({} = nothing spawns).
func _roll_loot_def(ability_refs: Array) -> Dictionary:
	var lootable: Array = []
	for r in ability_refs:
		if not Slice01Data.get_skillbook_master(String(r)).is_empty():
			lootable.append(String(r))
	if not lootable.is_empty() and randf() < SKILLBOOK_DROP_CHANCE:
		return _make_skillbook_drop_def(String(lootable[randi() % lootable.size()]))
	if randf() < GEAR_DROP_CHANCE and not GEAR_LOOT.is_empty():
		return _make_gear_drop_def(String(GEAR_LOOT[randi() % GEAR_LOOT.size()]))
	return {}   # no generic filler — nothing drops


## ENC(분대) 클리어 → HUB-COR-000 §3 ENC별 haul 드롭표를 각 행 1회 롤 → 클리어 지점에 재획득
## 가능한 At-Risk ItemDrop 생성. CombatController.squad_cleared 연결.
func on_squad_cleared(encounter_id: String, world_pos: Vector3) -> void:
	var i := 0
	for row in Slice01Data.get_haul_drops(encounter_id):
		var r: Dictionary = row
		if randf() >= float(r.get("chance", 0.0)):
			continue
		for _q in int(r.get("qty", 1)):
			var drop := ItemDrop.new()
			drop.setup(_inv, _make_haul_drop_def(String(r.get("haul", ""))))
			@warning_ignore("integer_division")  # i/3 = 그리드 행 인덱스 — 정수 의도
			drop.position = world_pos + Vector3(0.8 * float(i % 3) - 0.8, 0.0, 0.8 * float(i / 3))
			add_child(drop)
			i += 1


## Haul drop def (F-029/D-029) — kind "haul" + haul_material_id; picked up → run inventory At-Risk.
func _make_haul_drop_def(haul_material_id: String) -> Dictionary:
	var m: Dictionary = Slice01Data.get_haul_material(haul_material_id)
	return {
		"id": String(m.get("display", haul_material_id)),
		"w": 1, "h": 1,
		"color": Color(0.62, 0.5, 0.32),
		"kind": "haul",
		"haul_material_id": haul_material_id,
	}


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

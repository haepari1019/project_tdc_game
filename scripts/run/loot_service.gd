extends Node3D
## Per-kill loot drops (F-009 / F-010) — on CombatController.enemy_defeated, rolls one drop
## (skillbook from the enemy's lootable AB > gear; else NO drop) and spawns an ItemDrop world
## pickup at the death position. setup(inventory_ui); connect combat.enemy_defeated → on_enemy_defeated.
## (generic filler loot removed per 사용자 요청 — only lootable skill / 장비 / haul(ENC clear) drop.)

const ItemDrop := preload("res://scripts/world/objects/item_drop.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const AffixRoller := preload("res://scripts/run/affix_roller.gd")   # D-018 §7.6 스킬북 affix roll

## PH gear-loot pool — dungeon-dropped Identity Gear (F-008 §3.3 / DEC-20260611-001; looted =
## At Risk). Same-role (Tank) equippable + cross-role (Healer) to show the equipClasses reject.
const GEAR_LOOT: Array = ["gear_ward_tank_anchor_bulwark", "gear_ward_healer_mend_lantern"]
const GEAR_DROP_CHANCE := 0.08          # gear is RARE (per-kill, after the skillbook roll). (tuning)
const SKILLBOOK_DROP_CHANCE := 0.85     # high so lootable-AB enemies almost always drop. (tuning)
# haulMaterial(F-029/D-029)은 per-kill가 아니라 ENC(분대) 클리어 시 HUB-COR-000 §3 표로 드롭
# (on_squad_cleared). combat.squad_cleared → 여기 연결.

var _inv: Node

# 클래스 밸런스 소프트-피티 (사용자 요청) — per-run 클래스별 스킬북 드롭 수. 과대표 클래스 스킬은 드롭
# 확률을 점감해 EN-001(가장 흔한 lootable 적)의 단일 Tank 스킬 쏠림을 자가 교정. equip_classes 기준.
var _class_drops: Dictionary = {}
const CLASS_BALANCE_TAPER := 0.25   # 평균 초과 1건당 드롭확률 배수 감소
const CLASS_BALANCE_FLOOR := 0.15   # 과대표 클래스 최소 드롭확률 배수
const PARTY_ROLE_COUNT := 4         # Tank/DPS/Nuker/Healer — 평균 기준


func setup(inventory_ui: Node) -> void:
	_inv = inventory_ui
	_class_drops = {}   # per-run 리셋


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
	if not lootable.is_empty():
		var base := String(lootable[randi() % lootable.size()])
		var eq: Array = Slice01Data.get_skillbook_master(base).get("equip_classes", [])
		# 클래스 밸런스 소프트-피티: 과대표 클래스 스킬은 확률 점감 → 클래스 쏠림 자가 교정.
		if randf() < SKILLBOOK_DROP_CHANCE * _class_balance_factor(eq):
			_record_class_drop(eq)
			return _make_skillbook_drop_def(base)
	if randf() < GEAR_DROP_CHANCE and not GEAR_LOOT.is_empty():
		return _make_gear_drop_def(String(GEAR_LOOT[randi() % GEAR_LOOT.size()]))
	return {}   # no generic filler — nothing drops


## 이 스킬북이 '봉사할' 가장 덜 나온 eligible 클래스 기준 드롭확률 배수. 그 클래스가 평균 이하면 1.0(통과),
## 초과면 (초과분 × TAPER)만큼 점감(FLOOR까지). 초반(총 < 역할수)엔 throttle 안 함.
func _class_balance_factor(equip_classes: Array) -> float:
	if equip_classes.is_empty():
		return 1.0
	var total := 0
	for v in _class_drops.values():
		total += int(v)
	if total < PARTY_ROLE_COUNT:
		return 1.0   # warmup
	var avg := float(total) / float(PARTY_ROLE_COUNT)
	var best := 1 << 30   # 이 스킬이 봉사 가능한 클래스 중 최소 보유수(가장 부족한 쪽)
	for c in equip_classes:
		best = mini(best, int(_class_drops.get(String(c), 0)))
	if float(best) <= avg:
		return 1.0
	return clampf(1.0 - CLASS_BALANCE_TAPER * (float(best) - avg), CLASS_BALANCE_FLOOR, 1.0)


## 드롭 기록 — 이 스킬이 봉사하는(가장 부족한) eligible 클래스 1건 증가.
func _record_class_drop(equip_classes: Array) -> void:
	if equip_classes.is_empty():
		return
	var pick := ""
	var lo := 1 << 30
	for c in equip_classes:
		var n := int(_class_drops.get(String(c), 0))
		if n < lo:
			lo = n
			pick = String(c)
	_class_drops[pick] = int(_class_drops.get(pick, 0)) + 1


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
		"affix": AffixRoller.roll(),   # D-018 §7.6 — 루팅만 18% affix(상점 Raw=0%). {} = 무affix.
	}


func _make_gear_drop_def(base_gear_id: String) -> Dictionary:
	var m: Dictionary = Slice01Data.get_gear_master(base_gear_id)
	var classes: Array = m.get("equip_classes", [])
	var cid := String(classes[0]) if not classes.is_empty() else "Tank"
	# F-008 §3.7 인스턴스 굴림 (DungeonDrop): identity = 가중 롤테이블, 서브옵션 mult = 넓은 band(D-019 §8).
	var def := {
		"id": String(m.get("display_name", base_gear_id)),
		"w": 2, "h": 2,
		"color": UnitVisuals.role_color(cid),
		"kind": "gear",
		"base_gear_id": base_gear_id,
		"rolls": {"dmg_mult": snappedf(randf_range(0.90, 1.10), 0.01), "cd_mult": snappedf(randf_range(0.94, 1.06), 0.01)},
	}
	var rid := _roll_identity(base_gear_id)
	if rid != "":
		def["rolled_identity_skill_id"] = rid
	return def


## Weighted pick from a gear's identity roll table (F-008 §3.7). "" if no table.
func _roll_identity(base_gear_id: String) -> String:
	var table: Array = Slice01Data.get_gear_identity_roll_table(base_gear_id)
	if table.is_empty():
		return ""
	var total := 0.0
	for e in table:
		total += float(e.get("weight", 0))
	if total <= 0.0:
		return String(table[0].get("skill_id", ""))
	var r := randf() * total
	for e in table:
		r -= float(e.get("weight", 0))
		if r <= 0.0:
			return String(e.get("skill_id", ""))
	return String(table[-1].get("skill_id", ""))

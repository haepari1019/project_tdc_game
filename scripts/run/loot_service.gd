extends Node3D
## Per-kill loot drops (F-009 / F-010) — on CombatController.enemy_defeated, rolls one drop
## (skillbook from the enemy's lootable AB > gear; else NO drop) and spawns an ItemDrop world
## pickup at the death position. setup(inventory_ui); connect combat.enemy_defeated → on_enemy_defeated.
## (generic filler loot removed per 사용자 요청 — only lootable skill / 장비 / haul(ENC clear) drop.)

const ItemDrop := preload("res://scripts/world/objects/item_drop.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const AffixRoller := preload("res://scripts/run/affix_roller.gd")   # D-018 §7.6 스킬북 affix roll
const ItemFactory := preload("res://scripts/ui/inventory/item_factory.gd")   # 상자 소모품 item dict

# 스펙 §7.4 대역 — 난이도별 스킬북 드롭률(탄약수↑(50~80)에 맞춰 빈도↓, 피로 완화). RunLoadout.get_difficulty() 기준. (tuning)
const SKILLBOOK_DROP_BY_DIFF := {"Normal": 0.08, "Hard": 0.15}
const SKILLBOOK_DROP_DEFAULT := 0.15    # 미지정 난이도 폴백
# 몬스터 킬 = 자기 스킬 OR 소량 재화(사용자 요청). 스킬 미드롭 시 ward_scrap 소량 → At-Risk 런 누적(추출 성공 시
# 지급, 실패 시 소실). 기어·재료는 킬에서 안 나옴(→ 상자). gear는 상자(build_chest_items)에서만 드롭.
const KILL_SCRAP := 1                    # 스킬 미드롭 킬당 재화(소량, At-Risk). (tuning)
# 상자(chest) 루트 — 상자가 재료·스킬·기어의 주 공급원(사용자 요청). 티어로 품질 차등.
const CHEST_HAUL_COMMON := Vector2i(1, 3)   # 일반(안좋은) 상자: 재료 1~3 (재료 주 공급원)
const CHEST_HAUL_RARE := Vector2i(1, 1)     # 희귀(좋은) 상자: 재료 1 + 스킬/기어 집중
const CHEST_SKILL_COMMON := 0.40
const CHEST_SKILL_RARE := 0.90              # 희귀 상자 = 스킬 거의 + affix 강제
const CHEST_GEAR_COMMON := 0.15
const CHEST_GEAR_RARE := 0.50
const CHEST_CONSUM_COMMON := 0.25           # 소모품(부활 두루마리 등) — 상자에서 획득
const CHEST_CONSUM_RARE := 0.40
const CHEST_GRID_COLS := 5                  # chest open_loot 그리드 기준
const SQUAD_HAUL_MULT := 0.2                # 몬스터(분대 클리어) 재료 드롭 = 상자로 이전, 잘 안 나오게(×0.2)
# haulMaterial(F-029/D-029)은 per-kill가 아니라 ENC(분대) 클리어 시 HUB-COR-000 §3 표로 드롭
# (on_squad_cleared). combat.squad_cleared → 여기 연결.

var _inv: Node

# 클래스 밸런스 소프트-피티 (사용자 요청) — per-run 클래스별 스킬북 드롭 수. 과대표 클래스 스킬은 드롭
# 확률을 점감해 EN-001(가장 흔한 lootable 적)의 단일 Tank 스킬 쏠림을 자가 교정. equip_classes 기준.
var _class_drops: Dictionary = {}
const CLASS_BALANCE_TAPER := 0.25   # 평균 초과 1건당 드롭확률 배수 감소
const CLASS_BALANCE_FLOOR := 0.15   # 과대표 클래스 최소 드롭확률 배수
const PARTY_ROLE_COUNT := 4         # Tank/DPS/Nuker/Healer — 평균 기준

## 몬스터 킬 누적 재화(At-Risk) — 추출 성공 시 run_end가 HubProfile.add_scrap, 실패 시 소실.
var run_scrap: int = 0


func setup(inventory_ui: Node) -> void:
	_inv = inventory_ui
	_class_drops = {}   # per-run 리셋
	run_scrap = 0


## Drop a backpack item back into the world (player Shift+우클릭 버리기) — a re-pickable ItemDrop
## beside the player. Reuses the item's def so pickup routing (gear/skillbook/haul/generic) restores it.
func drop_item(def: Dictionary, world_pos: Vector3) -> void:
	if def.is_empty():
		return
	var drop := ItemDrop.new()
	drop.setup(_inv, def)
	drop.position = Vector3(world_pos.x + 1.0, 0.0, world_pos.z)
	add_child(drop)


## CombatController.enemy_defeated → 몬스터 킬 = 자기 스킬 드롭 OR 소량 재화(둘 중 하나).
## 기어·재료는 킬에서 안 나옴(상자 전용). 스킬 = 그 적의 own lootable AB(F-009/DEC-20260611-002)
## + 클래스 밸런스 소프트-피티. 미드롭 시 ward_scrap 소량(At-Risk 런 누적).
func on_enemy_defeated(world_pos: Vector3, ability_refs: Array, by_party: bool = true) -> void:
	if not by_party:
		return   # 3세력·몬스터 간 오프스크린 킬 — 플레이어 전리품/재화 없음(S5b P3b: run_scrap 인플레·난장판 방지)
	var lootable: Array = []
	for r in ability_refs:
		if not Slice01Data.get_skillbook_master(String(r)).is_empty():
			lootable.append(String(r))
	if not lootable.is_empty():
		var base := String(lootable[randi() % lootable.size()])
		var eq: Array = Slice01Data.get_skillbook_master(base).get("equip_classes", [])
		if randf() < _skillbook_drop_chance() * _class_balance_factor(eq):
			_record_class_drop(eq)
			var drop := ItemDrop.new()
			drop.setup(_inv, _make_skillbook_drop_def(base))
			drop.position = Vector3(world_pos.x, 0.0, world_pos.z)
			add_child(drop)
			return
	run_scrap += KILL_SCRAP   # 스킬 미드롭 → 소량 재화(추출 시 지급)


## 난이도별 스킬북 드롭률(스펙 §7.4: Normal 8% / Hard 15%). RunLoadout(허브 선택 or manifest 폴백) 기준.
func _skillbook_drop_chance() -> float:
	return float(SKILLBOOK_DROP_BY_DIFF.get(String(RunLoadout.get_difficulty()), SKILLBOOK_DROP_DEFAULT))


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


## 상자 내용물 빌드 — 티어별(common/rare) 재료·스킬·기어 인스턴스 item dict 배열(그리드 col/row 포함).
## 일반(안좋은)=재료 多 + 스킬/기어 적음(자연 affix). 희귀(좋은)=재료 1 + 스킬/기어 多 + **affix 보장**.
## 콘텐츠는 global randf(다양성), 배치 시드는 호출측(dungeon_run)이 담당. ref: F-009/F-010.
func build_chest_items(tier: String) -> Array:
	var rare := tier == "rare"
	var out: Array = []
	# 1) 재료(haul) — 상자가 주 공급원. 일반 상자가 더 많이.
	var haul_ids: Array = Slice01Data.get_haul_material_ids()
	if not haul_ids.is_empty():
		var span: Vector2i = CHEST_HAUL_RARE if rare else CHEST_HAUL_COMMON
		for _h in randi_range(span.x, span.y):
			out.append(_make_haul_drop_def(String(haul_ids[randi() % haul_ids.size()])))
	# 2) 스킬북 — 희귀 상자는 거의 항상 + affix 강제. 일반은 자연 18% affix.
	if randf() < (CHEST_SKILL_RARE if rare else CHEST_SKILL_COMMON):
		var rows: Array = Slice01Data.get_skillbook_rows()
		if not rows.is_empty():
			var base := String((rows[randi() % rows.size()] as Dictionary).get("base_ability_id", ""))
			var def := _make_skillbook_drop_def(base)   # 자연 18% affix 내장
			if rare and (def.get("affix", {}) as Dictionary).is_empty():
				def["affix"] = AffixRoller.roll_forced()   # 좋은 상자 = affix 보장
			out.append(def)
	# 3) 기어 — 희귀 상자가 더 잘(기어는 항상 rolled 보유).
	if randf() < (CHEST_GEAR_RARE if rare else CHEST_GEAR_COMMON):
		var grows: Array = Slice01Data.get_gear_rows()
		if not grows.is_empty():
			out.append(_make_gear_drop_def(String((grows[randi() % grows.size()] as Dictionary).get("base_gear_id", ""))))
	# 4) 소모품 — 부활 두루마리 등(상자에서도 획득). 픽업/드래그 시 스택.
	if randf() < (CHEST_CONSUM_RARE if rare else CHEST_CONSUM_COMMON):
		var crows: Array = Slice01Data.get_consumable_rows()
		if not crows.is_empty():
			out.append(ItemFactory.consumable_item(crows[randi() % crows.size()], randi_range(1, 2)))
	# 그리드 배치(가로 우선)
	for idx in out.size():
		out[idx]["col"] = idx % CHEST_GRID_COLS
		@warning_ignore("integer_division")
		out[idx]["row"] = idx / CHEST_GRID_COLS
	return out


## ENC(분대) 클리어 → HUB-COR-000 §3 ENC별 haul 드롭표를 각 행 1회 롤 → 클리어 지점에 재획득
## 가능한 At-Risk ItemDrop 생성. CombatController.squad_cleared 연결.
func on_squad_cleared(encounter_id: String, world_pos: Vector3) -> void:
	var i := 0
	for row in Slice01Data.get_haul_drops(encounter_id):
		var r: Dictionary = row
		if randf() >= float(r.get("chance", 0.0)) * SQUAD_HAUL_MULT:   # 재료=상자 위주 → 분대 클리어 드롭 희귀화
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
		"rolls": {"dmg_mult": snappedf(randf_range(0.90, 1.10), 0.01), "cd_mult": snappedf(randf_range(0.94, 1.06), 0.01), "potency_mult": snappedf(randf_range(0.92, 1.10), 0.01)},
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

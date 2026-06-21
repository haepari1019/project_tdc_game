extends Node
## HubProfile (D-029) — per-player 허브 상태: 시설 Tier · Safe haul vault · 퀘스트 플래그.
## 시설 승급 = QuestGate AND HaulGate (F-029 §3.5; 표/퀘스트/haul = Slice01Data). haul은 런 At Risk →
## 탈출 성공 시 vault Safe(F-029 §3.2) → 승급 소모. 세션 영속(autoload); 디스크 저장은 후속(P2-S4 B6).
## ref: F-029, D-029.

const FACILITY_IDS := ["barracks", "stash", "scriptorium", "scribe_shop", "armory", "quartermaster", "smithy", "chapel"]

signal facilities_changed()
signal vault_changed()

var facilities: Dictionary = {}        # facilityId -> facilityTier (int, ≥0)
var hub_haul_vault: Dictionary = {}    # haulMaterialId -> qty (Safe only)
var quest_completed: Dictionary = {}   # questId -> bool


func _ready() -> void:
	for f in FACILITY_IDS:
		if not facilities.has(f):
			facilities[f] = 0


func facility_tier(id: String) -> int:
	return int(facilities.get(id, 0))


## Transfer a haul stack into the Safe vault — called on ExtractionSuccess (F-029 §3.2). Merges by id.
func add_haul(id: String, qty: int) -> void:
	if id.is_empty() or qty <= 0:
		return
	hub_haul_vault[id] = int(hub_haul_vault.get(id, 0)) + qty
	vault_changed.emit()


func vault_count(id: String) -> int:
	return int(hub_haul_vault.get(id, 0))


## Remove haul from the Safe vault (테스트 편집 / 향후 분해 등). 0 이하면 제거.
func remove_haul(id: String, qty: int = 1) -> void:
	if id.is_empty() or qty <= 0:
		return
	var left := vault_count(id) - qty
	if left > 0:
		hub_haul_vault[id] = left
	else:
		hub_haul_vault.erase(id)
	vault_changed.emit()


func set_quest_completed(quest_id: String, done: bool = true) -> void:
	quest_completed[quest_id] = done


func is_quest_done(quest_id: String) -> bool:
	return bool(quest_completed.get(quest_id, false))


## B4-lite: 충족 가능한 Slice-01 퀘스트 stub(vault 수량·시설 Tier 기반)을 자동 완료 처리한다
## (F-029 §3.3.1). 런 이벤트형(ENC clear·map success·GIMMICK·party wipe·NPC)은 B4 full에서
## 런 훅으로 완료. 비가역(완료는 유지) — 허브 진입/vault·시설 변동 시 호출.
func evaluate_quests() -> void:
	_q_if("Q-HUB-002", vault_count("haul_ward_splinter") >= 2)   # 창고 T1 — 파편 반입
	_q_if("Q-HUB-011", vault_count("haul_arc_ink") >= 2)         # 필기소 T2 — 아크 잉크
	_q_if("Q-HUB-012", facility_tier("scriptorium") >= 1)        # 상점 개장 — 필기소 선행
	_q_if("Q-HUB-013", facility_tier("scribe_shop") >= 1)        # 상점 T2
	_q_if("Q-HUB-021", facility_tier("armory") >= 1)             # 무기고 T2
	_q_if("Q-HUB-030", vault_count("haul_forge_coal") >= 3)      # 대장간 건립 — 연료
	_q_if("Q-HUB-031", facility_tier("smithy") >= 1)             # 대장간 T2
	_q_if("Q-HUB-051", vault_count("haul_pack_frame") >= 2)      # 군수 T2


func _q_if(quest_id: String, cond: bool) -> void:
	if cond and not is_quest_done(quest_id):
		quest_completed[quest_id] = true


## D-029 §5 — 시설 `id`를 다음 Tier로 승급 가능한지. 반환:
## {ok, reason("ok"|"max"|"prereq"|"quest"|"haul"), next_tier, quest, missing:{haulId:부족수량}, prereq?}
func upgrade_check(id: String) -> Dictionary:
	var next_tier := facility_tier(id) + 1
	var row: Dictionary = Slice01Data.get_facility_tier(id, next_tier)
	if row.is_empty():
		return {"ok": false, "reason": "max", "next_tier": next_tier, "quest": "", "missing": {}}
	# 선행 시설 (예: scribe_shop T1 requires scriptorium ≥ 1)
	var prereq: Dictionary = row.get("prereq", {})
	for pid in prereq:
		if facility_tier(String(pid)) < int(prereq[pid]):
			return {"ok": false, "reason": "prereq", "next_tier": next_tier, "quest": "", "missing": {}, "prereq": pid}
	var quest := String(row.get("quest", ""))
	var quest_ok: bool = quest.is_empty() or is_quest_done(quest)
	var missing: Dictionary = {}
	var haul: Dictionary = row.get("haul", {})
	for hid in haul:
		var deficit := int(haul[hid]) - vault_count(String(hid))
		if deficit > 0:
			missing[hid] = deficit
	var ok: bool = quest_ok and missing.is_empty()
	var reason := "ok"
	if not quest_ok:
		reason = "quest"
	elif not missing.is_empty():
		reason = "haul"
	return {"ok": ok, "reason": reason, "next_tier": next_tier, "quest": quest, "missing": missing}


## D-029 §5 — 승급 가능하면 수행: haul 소모(Safe vault만), Tier+1. 성공 여부 반환.
func attempt_upgrade(id: String) -> bool:
	var chk := upgrade_check(id)
	if not bool(chk["ok"]):
		return false
	var next_tier := int(chk["next_tier"])
	var row: Dictionary = Slice01Data.get_facility_tier(id, next_tier)
	var haul: Dictionary = row.get("haul", {})
	for hid in haul:
		var left := vault_count(String(hid)) - int(haul[hid])
		if left > 0:
			hub_haul_vault[hid] = left
		else:
			hub_haul_vault.erase(hid)
	facilities[id] = next_tier
	facilities_changed.emit()
	vault_changed.emit()
	return true


# --- Derived reads (D-029 §6) — 다른 Feature가 시설 Tier를 조회 ---
func stash_capacity() -> int:
	return int(Slice01Data.get_facility_value("stash", facility_tier("stash"), 20))

func run_inventory_capacity() -> int:
	return int(Slice01Data.get_facility_value("quartermaster", facility_tier("quartermaster"), 12))

func armory_catalog_tier() -> int:
	return facility_tier("armory")   # 0=none, 1=B, 2=B+C

func can_analyze() -> bool:
	return facility_tier("scriptorium") >= 1

func shop_tier_ceiling() -> int:
	return facility_tier("scribe_shop")   # 0=locked, 1=Basic, 2=Advanced

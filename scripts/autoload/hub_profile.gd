extends Node
## HubProfile (D-029) — per-player 허브 상태: 시설 Tier · Safe haul vault · 퀘스트 플래그.
## 시설 승급 = QuestGate AND HaulGate (F-029 §3.5; 표/퀘스트/haul = Slice01Data). haul은 런 At Risk →
## 탈출 성공 시 vault Safe(F-029 §3.2) → 승급 소모. 세션 영속(autoload); 디스크 저장은 후속(P2-S4 B6).
## ref: F-029, D-029.

const FACILITY_IDS := ["barracks", "stash", "scriptorium", "scribe_shop", "armory", "quartermaster", "smithy", "chapel"]
# 영속 = SaveProfile 단일 파일(user://save.json)의 "hub" 섹션 (구 user://hub_profile.json은 1회 마이그레이션).
# Skillbook economy (F-009 §3.5 / D-018 §7.1) — 분석 의뢰 N=3 → 상점 해금; 생본 가격 ward_scrap/tier.
const ANALYSIS_REQUIRED := 3
const SHOP_PRICE := {"Basic": 12, "Advanced": 30, "Master": 60}   # ward_scrap, D-018 §7.1
const TIER_RANK := {"Basic": 1, "Advanced": 2, "Master": 3}       # vs shop_tier_ceiling (scribe_shop Tier)
const SINK_DISASSEMBLE := 8   # D-018 §7.5 — 해금 후 중복 스킬북 분해
const SINK_SELL := 4          # D-018 §7.5 — 미해금 중복 스킬북 허브 매각(분석 재료 대안)
const GEAR_PRICE := {1: 40, 2: 90}   # F-029 armory 카탈로그 tier별 기어 가격(ward_scrap, B/C)

signal facilities_changed()
signal vault_changed()
signal economy_changed()   # analysis progress / shop unlock / ward_scrap changed (UI-029 후속)

var facilities: Dictionary = {}        # facilityId -> facilityTier (int, ≥0)
var hub_haul_vault: Dictionary = {}    # haulMaterialId -> qty (Safe only)
var quest_completed: Dictionary = {}   # questId -> bool
var enc_cleared: Dictionary = {}       # encounterId -> true (런 이벤트 퀘스트 판정용, B4)
var extraction_success: int = 0        # 누적 추출 성공 횟수 (데모 이벤트 퀘스트: 군수 1·창고T2 2 대용)
var party_wiped: int = 0               # 누적 전멸 횟수 (데모 이벤트 퀘스트: 성소 복구 대용)
var analysis_progress: Dictionary = {} # baseAbilityId -> 분석 의뢰 누적 횟수 (Safe meta, F-009 §3.5)
var shop_listing_unlocked: Dictionary = {}  # baseAbilityId -> bool (progress >= ANALYSIS_REQUIRED)
var ward_scrap: int = 0                # 상점 통화 (D-018 §7.1 placeholder); 추출 성공 시 획득
var persist: bool = true               # false면 디스크 저장/로드 skip (테스트 인스턴스용 — 실 save 미오염)
var _q_dirty: bool = false


func _ready() -> void:
	load_profile()
	for f in FACILITY_IDS:
		if not facilities.has(f):
			facilities[f] = 0


## Persist meta progress (B6) — 변경마다 호출(승급·vault·퀘스트 완료). user:// JSON.
func save_profile() -> void:
	if not persist:
		return
	var sp := get_node_or_null("/root/SaveProfile")
	if sp != null:
		sp.put("hub", to_dict())


func to_dict() -> Dictionary:
	return {
		"facilities": facilities,
		"hub_haul_vault": hub_haul_vault,
		"quest_completed": quest_completed,
		"enc_cleared": enc_cleared,
		"analysis_progress": analysis_progress,
		"shop_listing_unlocked": shop_listing_unlocked,
		"ward_scrap": ward_scrap,
		"extraction_success": extraction_success,
		"party_wiped": party_wiped,
	}


func load_profile() -> void:
	if not persist:
		return
	var sp := get_node_or_null("/root/SaveProfile")
	if sp != null:
		apply_dict(sp.section("hub"))


func apply_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	facilities = d.get("facilities", {})
	hub_haul_vault = d.get("hub_haul_vault", {})
	quest_completed = d.get("quest_completed", {})
	enc_cleared = d.get("enc_cleared", {})
	analysis_progress = d.get("analysis_progress", {})
	shop_listing_unlocked = d.get("shop_listing_unlocked", {})
	ward_scrap = int(d.get("ward_scrap", 0))
	extraction_success = int(d.get("extraction_success", 0))
	party_wiped = int(d.get("party_wiped", 0))


## 테스트/디버그 — 허브 메타(시설 Tier/vault/퀘스트/ENC clear)를 초기 상태로 초기화.
func reset_to_seed() -> void:
	facilities = {}
	hub_haul_vault = {}
	quest_completed = {}
	enc_cleared = {}
	analysis_progress = {}
	shop_listing_unlocked = {}
	ward_scrap = 0
	extraction_success = 0
	party_wiped = 0
	for f in FACILITY_IDS:
		facilities[f] = 0
	vault_changed.emit()
	facilities_changed.emit()
	economy_changed.emit()
	save_profile()


## 런에서 ENC(분대) 클리어 기록 (B4 런 이벤트 퀘스트 판정용). squad_cleared → dungeon_run → 여기.
func record_enc_cleared(encounter_id: String) -> void:
	if encounter_id.is_empty() or bool(enc_cleared.get(encounter_id, false)):
		return
	enc_cleared[encounter_id] = true
	save_profile()


## 런 결과 기록 (데모 이벤트 퀘스트용) — run_end_controller에서 호출. 추출 성공 / 전멸.
func record_extraction_success() -> void:
	extraction_success += 1
	evaluate_quests()
	save_profile()

func record_party_wipe() -> void:
	party_wiped += 1
	evaluate_quests()
	save_profile()


func facility_tier(id: String) -> int:
	return int(facilities.get(id, 0))


## Transfer a haul stack into the Safe vault — called on ExtractionSuccess (F-029 §3.2). Merges by id.
func add_haul(id: String, qty: int) -> void:
	if id.is_empty() or qty <= 0:
		return
	hub_haul_vault[id] = int(hub_haul_vault.get(id, 0)) + qty
	vault_changed.emit()
	save_profile()


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
	save_profile()


func set_quest_completed(quest_id: String, done: bool = true) -> void:
	quest_completed[quest_id] = done


func is_quest_done(quest_id: String) -> bool:
	return bool(quest_completed.get(quest_id, false))


## B4-lite: 충족 가능한 Slice-01 퀘스트 stub(vault 수량·시설 Tier 기반)을 자동 완료 처리한다
## (F-029 §3.3.1). 런 이벤트형(ENC clear·map success·GIMMICK·party wipe·NPC)은 B4 full에서
## 런 훅으로 완료. 비가역(완료는 유지) — 허브 진입/vault·시설 변동 시 호출.
func evaluate_quests() -> void:
	_q_dirty = false
	_q_if("Q-HUB-002", vault_count("haul_ward_splinter") >= 2)   # 창고 T1 — 파편 반입
	# 데모 이벤트 퀘스트(미구현 기능 대용, DRIFT-065): 2번째 맵·전멸 복구·NPC → 추출/전멸 횟수로 근사.
	_q_if("Q-HUB-003", extraction_success >= 2)                  # 창고 T2 — 추출 2회(맵 2종 대용)
	_q_if("Q-HUB-040", party_wiped >= 1)                         # 성소 T1 — 전멸 1회(복구 대용)
	_q_if("Q-HUB-050", extraction_success >= 1)                  # 군수 T1 — 추출 1회(NPC 고용 대용)
	_q_if("Q-HUB-011", vault_count("haul_arc_ink") >= 2)         # 필기소 T2 — 아크 잉크
	_q_if("Q-HUB-012", facility_tier("scriptorium") >= 1)        # 상점 개장 — 필기소 선행
	_q_if("Q-HUB-013", facility_tier("scribe_shop") >= 1)        # 상점 T2
	_q_if("Q-HUB-020", bool(enc_cleared.get("ENC-HARD-001", false)))  # 무기고 T1 — ENC-HARD-001 클리어(B4)
	_q_if("Q-HUB-021", facility_tier("armory") >= 1)             # 무기고 T2
	_q_if("Q-HUB-030", vault_count("haul_forge_coal") >= 3)      # 대장간 건립 — 연료
	_q_if("Q-HUB-031", facility_tier("smithy") >= 1)             # 대장간 T2
	_q_if("Q-HUB-051", vault_count("haul_pack_frame") >= 2)      # 군수 T2
	if _q_dirty:
		save_profile()


func _q_if(quest_id: String, cond: bool) -> void:
	if cond and not is_quest_done(quest_id):
		quest_completed[quest_id] = true
		_q_dirty = true


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
	save_profile()
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


# --- Skillbook economy (F-009 §3.5 / D-018 §7.1) ----------------------------------------------

## Submit a skillbook for analysis (caller consumes the instance): +1 progress, unlock at N=3.
## Returns {ok, progress, unlocked, reason}. Rejects if scriptorium locked / already unlocked
## (no duplicate burn, F-009 §3.5). Safe meta — survives death.
func submit_analysis(base_id: String) -> Dictionary:
	if base_id.is_empty():
		return {"ok": false, "reason": "invalid"}
	if not can_analyze():
		return {"ok": false, "reason": "facility"}        # scriptorium Tier 1 needed
	if is_shop_unlocked(base_id):
		return {"ok": false, "reason": "already_unlocked"} # 해금 후 의뢰 거부
	var p := int(analysis_progress.get(base_id, 0)) + 1
	analysis_progress[base_id] = p
	var unlocked: bool = p >= ANALYSIS_REQUIRED
	if unlocked:
		shop_listing_unlocked[base_id] = true
	economy_changed.emit()
	save_profile()
	return {"ok": true, "progress": p, "unlocked": unlocked, "reason": "ok"}


func analysis_count(base_id: String) -> int:
	return int(analysis_progress.get(base_id, 0))


func is_shop_unlocked(base_id: String) -> bool:
	return bool(shop_listing_unlocked.get(base_id, false))


func scrap() -> int:
	return ward_scrap


## Grant ward_scrap (extraction reward / sale). No-op for ≤0.
func add_scrap(n: int) -> void:
	if n <= 0:
		return
	ward_scrap += n
	economy_changed.emit()
	save_profile()


func shop_price(tier: String) -> int:
	return int(SHOP_PRICE.get(tier, 999))


## D-018 §7.5 중복 스킬북 sink 값 — 해금된 base = 분해(8), 미해금 = 매각(4). 둘 다 인스턴스 1 소멸.
## CALLER가 스태시에서 책을 제거하고 add_scrap(이 값)을 호출(buy_raw와 대칭: hub=통화, caller=인스턴스).
func skillbook_sink_value(base_id: String) -> int:
	return SINK_DISASSEMBLE if is_shop_unlocked(base_id) else SINK_SELL


func gear_price(catalog_tier: int) -> int:
	return int(GEAR_PRICE.get(catalog_tier, 999))


## 소모품 구매(상점 — 기본 보급, 시설 게이트 없음). 가격 = consumables.json `price`(없으면 25). ward_scrap 차감.
## 성공 시 CALLER가 스태시에 추가. {ok, reason("ok"|"scrap"), cost}.
func buy_consumable(consumable_id: String) -> Dictionary:
	var m: Dictionary = Slice01Data.get_consumable_master(consumable_id)
	var cost := int(m.get("price", 25))
	if ward_scrap < cost:
		return {"ok": false, "reason": "scrap", "cost": cost}
	ward_scrap -= cost
	economy_changed.emit()
	save_profile()
	return {"ok": true, "reason": "ok", "cost": cost}


## F-029 무기고 기어 구매 — armory Tier ≥ catalog_tier + ward_scrap. 성공 시 scrap 차감(CALLER가 스태시 추가,
## buy_raw와 대칭). {ok, reason("ok"|"tier"|"scrap"), cost}.
func buy_gear(base_gear_id: String, catalog_tier: int) -> Dictionary:
	if facility_tier("armory") < catalog_tier:
		return {"ok": false, "reason": "tier", "cost": 0}
	var cost := gear_price(catalog_tier)
	if ward_scrap < cost:
		return {"ok": false, "reason": "scrap", "cost": cost}
	ward_scrap -= cost
	economy_changed.emit()
	save_profile()
	return {"ok": true, "reason": "ok", "cost": cost}


## Buy a Raw (affix-less) skillbook of `base_id` (default Basic). Gated by unlock + scribe_shop Tier
## ceiling + ward_scrap. Spends scrap on success; the CALLER grants the instance. {ok, reason, cost}.
func buy_raw(base_id: String, tier: String = "Basic") -> Dictionary:
	if not is_shop_unlocked(base_id):
		return {"ok": false, "reason": "locked", "cost": 0}
	if int(TIER_RANK.get(tier, 9)) > shop_tier_ceiling():
		return {"ok": false, "reason": "tier_ceiling", "cost": shop_price(tier)}
	var cost := shop_price(tier)
	if ward_scrap < cost:
		return {"ok": false, "reason": "scrap", "cost": cost}
	ward_scrap -= cost
	economy_changed.emit()
	save_profile()
	return {"ok": true, "reason": "ok", "cost": cost}

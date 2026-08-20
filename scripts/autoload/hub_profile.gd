extends Node
## HubProfile (D-029) — per-player 허브 상태: 시설 Tier · Safe haul vault · 퀘스트 플래그.
## 시설 승급 = QuestGate AND HaulGate (F-029 §3.5; 표/퀘스트/haul = Slice01Data). haul은 런 At Risk →
## 탈출 성공 시 vault Safe(F-029 §3.2) → 승급 소모. 세션 영속(autoload); 디스크 저장은 후속(P2-S4 B6).
## ref: F-029, D-029.

## **7시설**(M6) — `scriptorium`(필기소)은 분석 폐기 후 기능이 0이 돼 `scribe_shop`이 흡수했다.
## 마을 화면의 건물 목록이자 승급 대상. 순서 = 승급 패널 나열 순서.
const FACILITY_IDS := ["barracks", "stash", "scribe_shop", "armory", "quartermaster", "smithy", "chapel"]
# 영속 = SaveProfile 단일 파일(user://save.json)의 "hub" 섹션 (구 user://hub_profile.json은 1회 마이그레이션).
# Skillbook economy (F-009 §3.5 / D-018 §7.1) — 분석 의뢰 N=3 → 상점 해금; 생본 가격 ward_scrap/tier.
## ~~분석 N=3 · 중복 sink~~ — M5 폐기. 상수는 **마이그레이션 판독용**으로만 남는다.
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
## **수락한 의뢰**(M6). 의뢰는 이제 **그 의뢰가 여는 건물에서 받는다** — 폐허 앞에 서서 「이걸
## 세워 주게」를 듣고 수락하는 것이, 장부를 열어 목록을 보는 것보다 「이 마을을 일으킨다」에 가깝다.
## **수락하지 않은 의뢰는 완료되지 않는다** — 조건을 우연히 충족해도 마찬가지다. 그래야 수락이
## 의미를 갖는다.
var quest_accepted: Dictionary = {}    # questId -> bool
var enc_cleared: Dictionary = {}       # encounterId -> true (런 이벤트 퀘스트 판정용, B4)
## ~~`hard_cleared`~~ — M6에서 게이트가 **고정 보스 처치**로 옮겨가 판정에 안 쓰인다. 필드는 남긴다:
## 지역·입장조건이 난이도 축을 되찾을 때(사용자 로드맵) 다시 쓰일 자리이고, 기록 자체는 무해하다.
var hard_cleared: bool = false
var extraction_success: int = 0        # 누적 추출 성공 횟수 (데모 이벤트 퀘스트: 군수 1·창고T2 2 대용)
var party_wiped: int = 0               # 누적 전멸 횟수 (데모 이벤트 퀘스트: 성소 복구 대용)
## 출정 횟수 — `F-020` §3.2.0 **첫 런 게이트**의 판정축. 추출/전멸 카운터로 대신할 수 없다:
## 시작해 놓고 중도 이탈한 런도 「첫 런」은 아니기 때문이다. **출정 확정 시점**에 오른다.
var runs_started: int = 0
## ~~분석 경제~~ — **M5 폐기**(`D-018` §9). 필드는 **읽기 전용 유물**로 남는다: 구 세이브를
## 트리 해금으로 옮기는 `migrate_analysis_to_tree`가 이걸 읽고 비운다. 새로 쓰는 곳은 없다.
var analysis_progress: Dictionary = {} # (deprecated) baseAbilityId -> 분석 누적
var shop_listing_unlocked: Dictionary = {}  # (deprecated) baseAbilityId -> bool
## F-020 §3.10 스킬 트리 — 해금한 노드 id. **구 분석(N=3)의 후임**이라 같은 자리에 둔다:
## sink(금고 재료)·게이트(chapel Tier)·해금 상태가 전부 여기 모여 있어야 한 곳만 보면 된다.
## 분석 경로는 M5(F-009 폐기)에서 걷어낸다 — 그때까지 **두 경로가 공존**하되 트리가 우선한다.
var tree_unlocked: Dictionary = {}   # node_id -> true
## 플테 — 트리 전 노드 해금(D4 「전 카탈로그 개방」의 트리판). 교정한 스킬에 손이 닿아야 한다.
## 끄면 chapel 승급 → 재료 소비 → 노드 구매의 실제 곡선이 살아난다. ref: DRIFT-150.
## **const가 아니라 var다** — 켜 두면 `is_node_unlocked`가 항상 true라 게이트가 **트리 로직을 안 타고
## 통과해 버린다**(헛된 확신). 스모크가 false로 내려 실제 해금 파생을 검증한다.
var PLAYTEST_TREE_ALL_UNLOCKED: bool = true
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
		"quest_accepted": quest_accepted,
		"enc_cleared": enc_cleared,
		"hard_cleared": hard_cleared,
		"runs_started": runs_started,
		"analysis_progress": analysis_progress,
		"shop_listing_unlocked": shop_listing_unlocked,
		"tree_unlocked": tree_unlocked,
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
	quest_accepted = d.get("quest_accepted", {})
	enc_cleared = d.get("enc_cleared", {})
	hard_cleared = bool(d.get("hard_cleared", false))
	runs_started = int(d.get("runs_started", 0))
	analysis_progress = d.get("analysis_progress", {})
	shop_listing_unlocked = d.get("shop_listing_unlocked", {})
	tree_unlocked = d.get("tree_unlocked", {})
	ward_scrap = int(d.get("ward_scrap", 0))
	extraction_success = int(d.get("extraction_success", 0))
	party_wiped = int(d.get("party_wiped", 0))


## 테스트/디버그 — 허브 메타(시설 Tier/vault/퀘스트/ENC clear)를 초기 상태로 초기화.
func reset_to_seed() -> void:
	facilities = {}
	hub_haul_vault = {}
	quest_completed = {}
	quest_accepted = {}
	enc_cleared = {}
	hard_cleared = false
	runs_started = 0
	analysis_progress = {}
	shop_listing_unlocked = {}
	tree_unlocked = {}
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
## difficulty="Hard"면 hard_cleared 플래그 — Q-HUB-020(무기고)을 특정 ENC가 아니라 "Hard 클리어"로 판정
## (절차생성 ENC와 정합: 어느 Hard ENC를 잡든 게이트 충족). enc_cleared도 계속 기록(다른 판정용).
func record_enc_cleared(encounter_id: String, difficulty: String = "") -> void:
	var changed := false
	if difficulty == "Hard" and not hard_cleared:
		hard_cleared = true
		changed = true
	if not encounter_id.is_empty() and not bool(enc_cleared.get(encounter_id, false)):
		enc_cleared[encounter_id] = true
		changed = true
	if changed:
		evaluate_quests()   # Hard 클리어 즉시 Q-HUB-020 반영(record_extraction_success와 동형)
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


## 런 이벤트형 완료(목표 클리어 등). **수락한 의뢰만** 완료된다 — 수락 전에 우연히 조건을 채워도
## 크레딧이 없다. 대신 조용히 흘리지 않고 알린다(「깼는데 왜 안 되지」를 남기지 않는다).
func set_quest_completed(quest_id: String, done: bool = true) -> void:
	if done and not is_quest_accepted(quest_id):
		print("[TDC] 의뢰 '%s' 미수락 — 조건은 충족했으나 완료로 치지 않는다(해당 건물에서 수락)" % quest_id)
		return
	quest_completed[quest_id] = done
	save_profile()


func is_quest_done(quest_id: String) -> bool:
	return bool(quest_completed.get(quest_id, false))


func is_quest_accepted(quest_id: String) -> bool:
	return bool(quest_accepted.get(quest_id, false))


## 의뢰 수락 — **그 의뢰가 여는 건물에서** 부른다. 수락 직후 곧바로 재평가한다: 이미 조건을
## 채워 둔 상태로 수락하면 그 자리에서 완료돼야 「받자마자 됐다」가 성립한다.
func accept_quest(quest_id: String) -> bool:
	if quest_id == "" or is_quest_accepted(quest_id) or is_quest_done(quest_id):
		return false
	quest_accepted[quest_id] = true
	evaluate_quests()
	save_profile()
	return true


## 이 시설의 다음 단계가 요구하는 의뢰 id("" = 없음). 건물 패널이 「여기서 받는 의뢰」를 찾는 경로다.
func quest_for_next_tier(facility_id: String) -> String:
	var chk := upgrade_check(facility_id)
	if String(chk.get("reason", "")) == "max":
		return ""
	var nt := int(chk.get("next_tier", facility_tier(facility_id) + 1))
	return String(Slice01Data.get_facility_tier(facility_id, nt).get("quest", ""))


## 이 건물에서 **지금 할 일이 있는가** — 마을 카드의 뱃지가 이걸 읽는다.
## `"accept"`(받을 의뢰가 있다) · `"upgrade"`(지을/올릴 수 있다) · `""`(없음).
func building_action(facility_id: String) -> String:
	if bool(upgrade_check(facility_id).get("ok", false)):
		return "upgrade"
	var q := quest_for_next_tier(facility_id)
	if q != "" and not is_quest_accepted(q) and not is_quest_done(q):
		return "accept"
	return ""


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
	_q_if("Q-HUB-013", facility_tier("scribe_shop") >= 1)        # 상점 T2
	# 무기고 T1 — **고정 보스 처치**(M6). 구 조건은 「Hard 인카운터 클리어」였는데 허브에서 난이도를
	# 고르는 UI가 사라져 `hard_cleared`가 영영 서지 않는다. 「어려운 관문」을 토글이 아니라 **맵의 방**이
	# 소유하게 옮겼다 — `spawn_table` `force_overrides`가 `P-BOSS-01`에 보스를 난이도 무관 고정한다.
	_q_if("Q-HUB-020", bool(enc_cleared.get("ENC-BOSS-001", false)))
	_q_if("Q-HUB-021", facility_tier("armory") >= 1)             # 무기고 T2
	# 대장간 사다리 — **초반 재료로 연다**(DRIFT-154). 연료(`haul_forge_coal`)는 Deep 분기 전용
	# (0.4/런)이라 T1부터 요구하면 건 모딩이 ~20런 뒤에 열린다. T1은 파편, T2부터 연료.
	_q_if("Q-HUB-030", vault_count("haul_ward_splinter") >= 3)   # 대장간 건립 — 파편
	_q_if("Q-HUB-031", facility_tier("smithy") >= 1 and vault_count("haul_forge_coal") >= 1)
	# T3 = **심층 노두**. `gear_skill_slot_count_max = 3` gear의 세 번째 칸이 여기서 열린다 —
	# 구 스펙은 T3+를 Expansion으로 미뤄 그 칸이 Slice-01에서 영영 도달 불가였다.
	_q_if("Q-HUB-032", bool(enc_cleared.get("ENC-DEEP-001", false)))
	_q_if("Q-HUB-051", vault_count("haul_pack_frame") >= 2)      # 군수 T2
	if _q_dirty:
		save_profile()


## 자동 판정 — **수락한 의뢰만** 완료된다(M6). 수락 전에는 조건을 충족해도 아무 일이 없다.
func _q_if(quest_id: String, cond: bool) -> void:
	if cond and is_quest_accepted(quest_id) and not is_quest_done(quest_id):
		quest_completed[quest_id] = true
		_q_dirty = true


## D-029 §5 — 시설 `id`를 다음 Tier로 승급 가능한지. 반환:
## {ok, reason("ok"|"max"|"prereq"|"quest"|"haul"), next_tier, quest, missing:{haulId:부족수량}, prereq?}
func upgrade_check(id: String) -> Dictionary:
	var next_tier := facility_tier(id) + 1
	var row: Dictionary = Slice01Data.get_facility_tier(id, next_tier)
	if row.is_empty():
		return {"ok": false, "reason": "max", "next_tier": next_tier, "quest": "", "missing": {}}
	# 선행 시설 — 데이터의 `prereq: {facility: tier}`. M6 재편 후 남은 선행은 없지만 스키마는 유지한다.
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

## 플레이테스트 한정 창고 무제한(사용자 결정 D4 — 전 카탈로그 개방, P4b_WORK_ORDER §M0-6).
## `stash` T0 capacity는 20인데 전 카탈로그 시드는 19 gear + 49 서브 = 68이라, 이 게이트를 켠 채로는
## 스태시 입금이 즉시 막혀 스킬 교정 검증이 불가능하다. **끄면 F-029 창고 승급 압력이 그대로 돌아온다** —
## 이건 밸런스 결정이 아니라 플테 도구다. 서브가 gear 슬롯으로 이관되면(M4) 스태시에서 서브 타일이
## 사라지므로 자연히 불필요해진다. ref: DRIFT-139.
const PLAYTEST_UNCAPPED_STASH := true
const PLAYTEST_STASH_CAP := 9999

func stash_capacity() -> int:
	if PLAYTEST_UNCAPPED_STASH:
		return PLAYTEST_STASH_CAP
	return int(Slice01Data.get_facility_value("stash", facility_tier("stash"), 20))


## 승급 UI가 보여줄 **실제 tier 용량**(플테 우회와 무관) — "capacity 20 → 28"이 우회 때문에
## 9999로 보이면 시설 승급이 의미 없어 보인다. 표시는 진실을, 게이트만 우회한다.
func stash_capacity_tier() -> int:
	return int(Slice01Data.get_facility_value("stash", facility_tier("stash"), 20))

func run_inventory_capacity() -> int:
	return int(Slice01Data.get_facility_value("quartermaster", facility_tier("quartermaster"), 12))

func armory_catalog_tier() -> int:
	return facility_tier("armory")   # 0=none, 1=B, 2=B+C

func shop_tier_ceiling() -> int:
	return facility_tier("scribe_shop")   # 0=locked, 1=Basic, 2=Advanced


# --- Skillbook economy (F-009 §3.5 / D-018 §7.1) ----------------------------------------------

## ~~`submit_analysis` · `analysis_count` · `is_shop_unlocked`~~ — **M5에서 폐기**(`D-018` §9 ·
## `F-009` §3.9.4). 「같은 책 3권 제출 → 해금」은 **트리 노드 클릭**으로 대체됐다. 해금 판정은
## 이제 `is_ability_unlocked` **하나**다 — 폴백을 남기면 두 벌의 진실이 생긴다.
##
## **모딩 시술비**(`F-008` §3.10 「동일 AB **재구매** 후 새 gear에 모딩」) — 트리 해금은 *허가*이고,
## 실제로 슬롯에 새기는 데는 매번 `ward_scrap`이 든다. 이게 없으면 D2 소멸이 이빨이 없다: gear를
## 갈아도 해금은 남아 있으니 공짜로 되끼우면 그만이기 때문이다. 가격 = 구 생본 가격(tier 차등) 승계.
func mod_install_price(base_id: String) -> int:
	return shop_price(String(Slice01Data.get_skillbook_master(base_id).get("tier", "Basic")))


## 슬롯 모딩 시술 — 해금 + `scribe_shop` tier 상한 + `ward_scrap`. 성공 시 차감(호출부가 슬롯을 쓴다).
## {ok, reason("ok"|"locked"|"tier_ceiling"|"scrap"), cost}.
func mod_install(base_id: String) -> Dictionary:
	if not is_ability_unlocked(base_id):
		return {"ok": false, "reason": "locked", "cost": 0}
	var tier := String(Slice01Data.get_skillbook_master(base_id).get("tier", "Basic"))
	if int(TIER_RANK.get(tier, 9)) > shop_tier_ceiling():
		return {"ok": false, "reason": "tier_ceiling", "cost": shop_price(tier)}
	var cost := shop_price(tier)
	if ward_scrap < cost:
		return {"ok": false, "reason": "scrap", "cost": cost}
	ward_scrap -= cost
	economy_changed.emit()
	save_profile()
	return {"ok": true, "reason": "ok", "cost": cost}


## **1회 마이그레이션** — 구 분석 경제(`shop_listing_unlocked`)로 열어 둔 AB를 **트리 해금으로 이전**.
## 스킬북 인스턴스는 소멸시키지만(사용자 판정), **이미 열어 둔 해금은 뺏지 않는다** — 그건 잃는 게
## 아니라 형식이 바뀌는 것이다. 대응 노드가 여러 역할에 걸리면 전부 연다.
func migrate_analysis_to_tree() -> void:
	if shop_listing_unlocked.is_empty():
		return
	var moved := 0
	for row in Slice01Data.get_tree_nodes():
		if String(row.get("type", "")) != "Unlock":
			continue
		if bool(shop_listing_unlocked.get(String(row.get("base_ability_id", "")), false)) 				and not bool(tree_unlocked.get(String(row.get("node_id", "")), false)):
			tree_unlocked[String(row["node_id"])] = true
			moved += 1
	shop_listing_unlocked = {}
	analysis_progress = {}
	if moved > 0:
		print("[TDC] M5 마이그레이션 — 구 분석 해금 %d건을 트리 노드로 이전" % moved)
	save_profile()


# --- F-020 §3.10 스킬 트리 -----------------------------------------------------

## `starter_unlocked` = `F-008` §3.10.2 프리모딩 4종 — **사지 않아도 열려 있다.** 이게 없으면 첫 런에
## 끼울 AB가 하나도 없어 `F-020` §3.2.0(첫 런 ≥1 슬롯)이 무너진다. 데이터가 소유하므로 코드에
## AB id를 하드코딩하지 않는다.
func is_node_unlocked(node_id: String) -> bool:
	if PLAYTEST_TREE_ALL_UNLOCKED or bool(tree_unlocked.get(node_id, false)):
		return true
	return bool(Slice01Data.get_tree_node(node_id).get("starter_unlocked", false))


## 트리로 이 AB가 열렸는가 — `Unlock` 노드가 가리키는 `base_ability_id`.
func is_ability_unlocked(base_id: String) -> bool:
	if base_id == "":
		return false
	for row in Slice01Data.get_tree_nodes():
		if String(row.get("type", "")) == "Unlock" and String(row.get("base_ability_id", "")) == base_id:
			if is_node_unlocked(String(row.get("node_id", ""))):
				return true
	return false


## 트리로 확보한 추가 gear 슬롯 수(`Slot` 노드 합). M4의 `gear_skill_slot_count`가 소비한다.
func tree_slot_bonus(class_id: String) -> int:
	var n := 0
	for row in Slice01Data.get_tree_nodes():
		if String(row.get("type", "")) == "Slot" and String(row.get("class_id", "")) == class_id 				and is_node_unlocked(String(row.get("node_id", ""))):
			n += int(row.get("grants_slot", 0))
	return n


## 이 AB에 걸린 `Upgrade` 파라미터 배율 합성({} = 없음). 행동 발전은 AB 소비처가 해석한다.
func ability_upgrades(base_id: String) -> Dictionary:
	var out: Dictionary = {}
	for row in Slice01Data.get_tree_nodes():
		if String(row.get("type", "")) != "Upgrade" or String(row.get("base_ability_id", "")) != base_id:
			continue
		if not is_node_unlocked(String(row.get("node_id", ""))):
			continue
		for k in (row.get("param_override", {}) as Dictionary):
			out[k] = float(out.get(k, 1.0)) * float(row["param_override"][k])
	return out


## 노드 구매 가능 판정 — chapel 게이트 · 선행 노드 · 금고 재료. {ok} 또는 {ok:false, reason}.
func tree_check(node_id: String) -> Dictionary:
	var row: Dictionary = Slice01Data.get_tree_node(node_id)
	if row.is_empty():
		return {"ok": false, "reason": "unknown"}
	if bool(tree_unlocked.get(node_id, false)):
		return {"ok": false, "reason": "already"}
	if facility_tier("chapel") < 1:
		return {"ok": false, "reason": "facility"}   # F-029 — chapel T0 = 트리 Locked
	var pre := String(row.get("prerequisite", ""))
	if pre != "" and not bool(tree_unlocked.get(pre, false)):
		return {"ok": false, "reason": "prereq"}
	# 시설 게이트 — `Slot` 사다리가 `smithy` T2/T3에 묶인다(`F-008` §3.10). 슬롯 수를 트리와 시설
	# **양쪽에서 더하면** 대장간 없이 트리만으로 3칸이 열려 스펙 사다리가 무너진다. 그래서 더하지 않고
	# **여기서 막는다** — 노드가 구매 표면이고 시설은 게이트다.
	for fac in (row.get("facility_req", {}) as Dictionary):
		if facility_tier(String(fac)) < int(row["facility_req"][fac]):
			return {"ok": false, "reason": "facility_req"}
	# **`Unlock`/`Upgrade`는 필기상점(`scribe_shop`) tier가 AB tier를 받아야 산다**(M6 건물 재편).
	# 해금과 시술이 같은 건물로 모였으므로 게이트도 같아야 한다 — 열 수는 있는데 못 새기는(또는 반대)
	# 상태가 생기면 유저는 어느 건물을 올려야 하는지 알 수 없다.
	var ab := String(row.get("base_ability_id", ""))
	if ab != "" and String(row.get("type", "")) in ["Unlock", "Upgrade"]:
		var tr := String(Slice01Data.get_skillbook_master(ab).get("tier", "Basic"))
		if int(TIER_RANK.get(tr, 9)) > shop_tier_ceiling():
			return {"ok": false, "reason": "tier_ceiling"}
	for mat in (row.get("cost", {}) as Dictionary):
		if vault_count(String(mat)) < int(row["cost"][mat]):
			return {"ok": false, "reason": "haul"}
	return {"ok": true}


## 노드 구매 — 재료를 **금고에서** 뺀다(sink 경쟁, I-007 §14.6). `Doctrine` 노드는 구매 이력을
## `DoctrineProfile`이 소유하므로 그쪽에도 남긴다. **환불 없음**(F-030 §3.2).
func tree_buy(node_id: String) -> Dictionary:
	var chk := tree_check(node_id)
	if not bool(chk.get("ok", false)):
		return chk
	var row: Dictionary = Slice01Data.get_tree_node(node_id)
	for mat in (row.get("cost", {}) as Dictionary):
		remove_haul(String(mat), int(row["cost"][mat]))
	tree_unlocked[node_id] = true
	if String(row.get("type", "")) == "Doctrine":
		var dp := get_node_or_null("/root/DoctrineProfile")
		if dp != null:
			dp.mark_purchased(String(row.get("doctrine_id", "")))
	save_profile()
	economy_changed.emit()
	return {"ok": true}


## `F-020` §3.2.0 — 첫 런 동안은 **역할당 슬롯 스킬 ≥1**이 필수다(미충족 시 출정 차단).
## 이후 런은 빈 슬롯이어도 들어갈 수 있고 경고만 뜬다.
func is_first_run() -> bool:
	return runs_started <= 0


func mark_run_started() -> void:
	runs_started += 1
	save_profile()


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




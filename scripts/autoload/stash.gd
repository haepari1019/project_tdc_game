extends Node
## Player stash (F-010 / F-008 / F-009 demo) — the persistent pool of OWNED items the
## deployment hub draws from: Identity Gear, skillbooks, consumables. The hub moves items
## stash ↔ run inventory ↔ character slots; what's brought is At-Risk (F-007). Seeded with
## demo content on first load. ref: F-010 §3.2.

var gear: Array = []               # owned gear 인스턴스 {base_gear_id, rolled_identity_skill_id?, rolls?} — F-008 §3.7. 레거시=문자열(로드 시 정규화).
## ~~스킬북 인스턴스~~ — **M5 폐기**(`D-018` §9 Frozen). 필드는 **마이그레이션 1회 판독용**으로만
## 남는다: 구 세이브가 들고 있던 목록을 읽어 소멸시키고 비운다(`migrate_drop_skillbooks`).
var skillbooks: Array = []         # (deprecated) 구 세이브 판독 전용
var consumables: Dictionary = {}   # consumable_id -> count owned
var manastones: Dictionary = {}     # manastone_id -> count owned (F-009 §3.8 — 허브 보관분)
var charms: Array = []              # charm_id 목록 (F-010 §3.11 — **비스택**: 같은 참 2개 = 항목 2개)
# 재료(haul)는 일반 스태시가 아니라 HubProfile 금고(vault)에 일원화 — 별도 store 두지 않음(혼란 방지).

# 영속 = SaveProfile 단일 파일(user://save.json)의 "stash" 섹션 (구 user://stash.json은 1회 마이그레이션).
var _seeded: bool = false


func _ready() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	var s: Dictionary = sp.section("stash") if sp != null else {}
	if s.is_empty():     # 섹션 없음(최초) → 시드 + 저장. 빈 배열로 저장된 상태는 키가 있어 apply.
		_seed()
		if _seeded:
			save_stash()   # ⚠️ 시드 실패(Slice01Data 미준비) 시엔 저장하지 않는다 — 빈 스태시를
			               # 저장해 버리면 다음 부팅에 섹션이 "존재"해서 apply_dict가 _seeded를
			               # 세우고 **영구히 빈 스태시**가 된다. 미저장으로 두면 ensure_seeded가 채운다.
	else:
		apply_dict(s)


## Persist owned items — 변경마다 호출. SaveProfile "stash" 섹션(단일 파일).
func save_stash() -> void:
	# 스모크/테스트는 이 스크립트를 **트리 밖 인스턴스**로 쓴다 — 그땐 절대경로 조회가 에러를 뱉고
	# 저장할 곳도 없다. 조용히 넘긴다(실 오토로드는 항상 트리 안이라 영향 없음).
	if not is_inside_tree():
		return
	var sp := get_node_or_null("/root/SaveProfile")
	if sp != null:
		sp.put("stash", to_dict())


## `skillbooks`를 **쓰지 않는다** — M5 이후 항상 비어 있으므로 저장할 것이 없다(다음 로드에서 키가
## 없으면 `[]`가 된다 = 소멸 완료). 구 세이브의 키는 `apply_dict`가 읽고 마이그레이션이 비운다.
func to_dict() -> Dictionary:
	return {"gear": gear, "consumables": consumables, "manastones": manastones, "charms": charms}


func apply_dict(d: Dictionary) -> void:
	gear = d.get("gear", [])
	_normalize_gear()   # 레거시 세이브(문자열 gear) → 인스턴스 dict 마이그레이션
	skillbooks = d.get("skillbooks", [])
	migrate_drop_skillbooks()   # M5 — 구 세이브 스킬북 소멸(1회, 로그 남김)
	consumables = d.get("consumables", {})
	manastones = d.get("manastones", {})
	charms = d.get("charms", [])
	_seeded = true


## gear 엔트리를 인스턴스 dict로 정규화 — 시드/레거시 세이브의 문자열 base_gear_id → {base_gear_id}.
## 인스턴스 = {base_gear_id, rolled_identity_skill_id?, rolls?} (F-008 §3.7 스페어도 굴린 정체성·옵션 보존).
func _normalize_gear() -> void:
	for i in gear.size():
		if typeof(gear[i]) == TYPE_STRING:
			gear[i] = {"base_gear_id": String(gear[i])}


## **M5 마이그레이션(1회)** — 스태시에 남은 스킬북 인스턴스를 **소멸**시킨다(사용자 판정: 보상 없음).
## 해금은 잃지 않는다 — `HubProfile.migrate_analysis_to_tree`가 구 분석 해금을 트리로 이미 옮겼고,
## 플테 프로필은 전 노드 해금이라 모딩에서 그대로 꺼내 쓸 수 있다. 조용히 지우지 않고 몇 권인지 알린다.
func migrate_drop_skillbooks() -> void:
	if skillbooks.is_empty():
		return
	print("[TDC] M5 마이그레이션 — 스태시 스킬북 %d권 소멸(인스턴스 Frozen, 해금은 트리 보존)" % skillbooks.size())
	skillbooks = []
	save_stash()


## 플레이테스트 시드 = **전 카탈로그 개방**(사용자 결정 D4, 2026-08-12 · P4b_WORK_ORDER §0).
## 스킬 교정(DRIFT-101~136)을 실제로 체감하려면 서브 49종·gear 19종에 전부 손이 닿아야 한다.
## P4b 이후엔 "gear 전량 소유 + 스킬 트리 전 노드 해금"으로 재해석된다(M3/M4).
const PLAYTEST_FULL_CATALOG := true


## 시드를 **카탈로그에서 파생**한다 — 하드코딩 목록은 AB/gear가 폐기될 때마다 유령 참조가 됐다
## (`AB-037`이 DRIFT-111 폐기 후에도 남아 조용히 3권만 들어오던 버그, DRIFT-139). 파생이면
## 카탈로그가 곧 시드라 어긋날 수가 없다. Slice01Data가 아직 안 떴으면(오토로드 순서 방어)
## 빈 시드로 두고 `ensure_seeded()`가 나중에 채운다 — 잘못된 하드코딩 폴백보다 낫다.
func _seed() -> void:
	if _seeded:
		return
	if not _seed_from_catalog():
		return          # Slice01Data 미준비 — _seeded를 세우지 않아 다음 접근에서 재시도
	_seeded = true


## 카탈로그 파생 시드. 성공 시 true. 소유 규칙(F-008): **스타터 4종은 Backpack.equipped(착용 중)**
## 이라 스태시엔 없고, armory 세트(Purchasable)는 상점 물건이라 제외 → 남는 "스페어" 아키타입만.
func _seed_from_catalog() -> bool:
	var sd := get_node_or_null("/root/Slice01Data")
	if sd == null or not sd.has_method("is_loaded") or not sd.is_loaded():
		return false
	gear = []
	for row in sd.get_gear_rows():
		if bool(row.get("starter", false)):
			continue                                            # 착용 중 = Backpack.equipped 소관
		if String(row.get("unlock_state", "")) == "Purchasable":
			continue                                            # armory 세트 = 상점 물건
		gear.append(String(row.get("base_gear_id", "")))
	# ~~스킬북 전 카탈로그 시드~~ — **M5 제거**. D4「전 카탈로그 개방」은 이제 **트리 전 노드 해금**
	# (`HubProfile.PLAYTEST_TREE_ALL_UNLOCKED`)으로 표현된다. 물건이 아니라 권한이 열려 있는 것이다.
	skillbooks = []
	consumables = {"con_revive_scroll": 8}
	# 허브 보관 마석 — 백팩 스타터(반입분)와 **별개**다. 스태시 = 다음 런에 꺼내 쓸 여유분.
	# `sd`는 get_node_or_null 반환이라 untyped → `:=` 추론이 안 된다(파스 에러). 명시 타입 필수.
	var msid: String = String(sd.default_manastone_id())
	manastones = {msid: int(sd.manastone_starter_grant())} if msid != "" else {}
	# 허브 보관 참 — 플테용으로 카탈로그 전량(칸 압력을 직접 느껴 보려면 손이 닿아야 한다).
	charms = []
	for crow in sd.get_charm_rows():
		charms.append(String(crow.get("charm_id", "")))
	_normalize_gear()         # 시드는 문자열로 적고 인스턴스로 정규화(roll 없음=base)
	return true


## `_ready` 시점에 Slice01Data가 없었으면 첫 접근에서 시드를 채운다(허브가 스태시를 읽기 전).
func ensure_seeded() -> void:
	if _seeded:
		return
	if _seed_from_catalog():
		_seeded = true
		save_stash()


## 테스트/디버그 — 스태시를 데모 시드로 초기화.
func reset_to_seed() -> void:
	gear = []
	skillbooks = []
	consumables = {}
	manastones = {}
	charms = []
	_seeded = false
	_seed()
	if _seeded:
		save_stash()


## 허브 보관 마석 — 입금/인출. 반입은 백팩(런 인벤)이 들고 가고, 스태시는 Safe 보관분이다.
func add_manastone(count: int, manastone_id: String = "") -> void:
	if count <= 0:
		return
	var mid := manastone_id if manastone_id != "" else String(Slice01Data.default_manastone_id())
	if mid == "":
		return
	manastones[mid] = int(manastones.get(mid, 0)) + count
	save_stash()


func take_manastone(count: int, manastone_id: String = "") -> bool:
	var mid := manastone_id if manastone_id != "" else String(Slice01Data.default_manastone_id())
	var have := int(manastones.get(mid, 0))
	if mid == "" or have < count:
		return false
	manastones[mid] = have - count
	if int(manastones[mid]) <= 0:
		manastones.erase(mid)
	save_stash()
	return true


func manastone_count(manastone_id: String = "") -> int:
	var mid := manastone_id if manastone_id != "" else String(Slice01Data.default_manastone_id())
	return int(manastones.get(mid, 0))


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
	for i in gear.size():
		var g = gear[i]
		var bid := String(g.get("base_gear_id", "")) if typeof(g) == TYPE_DICTIONARY else String(g)
		if bid == base_gear_id:
			gear.remove_at(i)
			save_stash()
			return true
	return false


## 창고 capacity 판정용 아이템 수 — 기어 + 스킬북 타일(소비는 스택·소량이라 제외). F-029 stash_capacity 비교용.
func item_count() -> int:
	return gear.size() + skillbooks.size()


## Add one owned gear to the stash (무기고 구매 / 회수). 상점 기어 = bundled identity(굴림 없음, 확정 세트).
func add_gear(base_gear_id: String, rolled_identity_skill_id: String = "", rolls: Dictionary = {}) -> void:
	if base_gear_id.is_empty():
		return
	var inst := {"base_gear_id": base_gear_id}
	if not rolled_identity_skill_id.is_empty():
		inst["rolled_identity_skill_id"] = rolled_identity_skill_id
	if not rolls.is_empty():
		inst["rolls"] = rolls
	gear.append(inst)
	save_stash()


## ~~`add_skillbook` / `remove_skillbook`~~ — **M5 제거**. 스킬북이 물건이 아니게 됐으므로
## 스태시가 소유할 것이 없다. 슬롯 AB의 획득 = 트리 해금(권한) + 모딩 시술(`F-008` §3.10).

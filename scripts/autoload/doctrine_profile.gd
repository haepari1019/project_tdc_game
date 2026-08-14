extends Node
## `profileDoctrineState` (D-021 §4) — 파티 운용 doctrine의 **프로필 영구** 상태.
##
## **런 단위가 아니다.** 스태시·백팩과 달리 doctrine은 `F-007` Recovery Loss Bundle에 **미포함**
## (`F-030` §3.5 Hub Safe) — 전멸해도 잃지 않는다. 성장이 "이번 런의 소지품"이 아니라 "내가 이 파티를
## 어떻게 운용하는가"라서, 런 결과로 흔들리면 정체성이 무너진다.
##
## 키 = `class_id`(D-011과 동일 규약; 게임은 역할당 1명이라 partySlotIndex와 1:1).
## `activeDoctrineIds` = **Identity당 최대 1개** 활성 · `purchasedNodeIds` = 구매 이력(**환불 없음**,
## `F-030` §3.2 — 재배치는 자유롭되 되사지 않는다).
##
## ⚠️ **중립 성장이 기본값이다.** 활성 0 = `QA-032` §2.1 회귀 게이트의 전제 — 이 상태에서
## `F-005` §3.3a 8단계가 스킵되고 결과가 개정 전과 동일해야 한다.

var active: Dictionary = {}      # class_id -> doctrine_id (활성 1개)
var purchased: Array = []        # 구매한 doctrine_id 이력(환불 없음)
var _loaded: bool = false


func _ready() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	var s: Dictionary = sp.section("doctrine") if sp != null else {}
	active = s.get("active", {})
	purchased = s.get("purchased", [])
	_loaded = true


func save_profile() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	if sp != null:
		sp.put("doctrine", {"active": active, "purchased": purchased})


## 활성 doctrine id 전량(중립이면 빈 배열) — `QA-032` §2.1이 이걸로 중립을 판정한다.
func active_ids() -> Array:
	var out: Array = []
	for k in active:
		var v := String(active[k])
		if v != "":
			out.append(v)
	return out


func is_neutral() -> bool:
	return active_ids().is_empty()


## 이 역할이 지금 굴리는 doctrine row({}이면 중립).
func active_for(class_id: String) -> Dictionary:
	return Slice01Data.get_doctrine(String(active.get(class_id, "")))


func is_purchased(doctrine_id: String) -> bool:
	return purchased.has(doctrine_id)


## 트리 구매 — `chapel` 게이트·비용 판정은 호출부(HubProfile)가 하고 여기선 이력만 남긴다.
## **환불 없음**(`F-030` §3.2)이라 되돌리는 API를 두지 않는다 — 있으면 결국 쓰인다.
func mark_purchased(doctrine_id: String) -> void:
	if doctrine_id == "" or purchased.has(doctrine_id):
		return
	purchased.append(doctrine_id)
	save_profile()


## 활성 교체 — **재배치는 자유**다(`F-030` §3.2). 구매한 것 중에서만 고를 수 있고,
## Identity당 1개라 같은 역할의 이전 활성은 그냥 밀려난다.
func set_active(class_id: String, doctrine_id: String) -> bool:
	if doctrine_id != "":
		if not is_purchased(doctrine_id):
			return false
		var row: Dictionary = Slice01Data.get_doctrine(doctrine_id)
		if String(row.get("class_id", "")) != class_id:
			return false
	active[class_id] = doctrine_id
	save_profile()
	return true


## 테스트/디버그 — 중립 성장으로. `QA-032` §2.1 기준선을 뜰 때 쓴다.
func clear_all() -> void:
	active = {}
	purchased = []
	save_profile()


func reset_to_seed() -> void:
	clear_all()

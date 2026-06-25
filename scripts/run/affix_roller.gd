extends RefCounted
## Skillbook affix roll (D-018 §7.3 caps / §7.6 roll policy). Looted skillbooks have an 18% chance
## to gain an affix; an affixed instance has a 30% chance of a 2nd (distinct) affix merged in —
## coeff/charges/cd_trade summed into the one `affix` dict (ids 리스트), §7.3 합산캡(0.15) 클램프.
## Shop Raw = 0% (callers just don't roll). The rolled instance carries `affix` = {} | a dict below;
## `coeff` feeds the cast potency multiplier (alongside the cross-class band, independent — §7.3 note),
## `charges` adds to chargesMax, `cd_trade` lengthens cooldown. ref: docs/design/affix_design.md.

const CHANCE := 0.18                                   # §7.6 affix 부여 (루팅만)
const SINGLE_COEFF_CAP := 0.12                         # §7.3 단일 coeffMult affix ≤ 12%
const MULTI_CHANCE := 0.30                             # affix 부여 인스턴스 중 2nd affix 추가 확률(다종 병합)
const SUM_COEFF_CAP := 0.15                            # §7.3 동일 인스턴스 coeffMult 합산 ≤ 15%

## affixTier 희귀도 (§7.6) — 누적 임계 [T1, T2]. 나머지 = T3.
const TIER_CUM := [0.85, 0.97]                          # T1 85% · T2 12% · T3 3%
## 희귀 tier일수록 band 내 coeff를 소폭 상향(게임측 파생, 튜닝). cap으로 클램프.
const TIER_SCALE := {"T1": 1.0, "T2": 1.06, "T3": 1.12}

## 종류 (§7.6 design examples) — weight로 가중 추첨. coeff band = [lo, hi], charges band = [lo, hi].
const TYPES := [
	{"id": "affix_eff_plus", "w": 50, "coeff": [0.08, 0.10], "charges": [0, 0], "cd_trade": 0.0},
	{"id": "affix_eff_minus_trade", "w": 25, "coeff": [0.10, 0.12], "charges": [0, 0], "cd_trade": 0.05},
	{"id": "affix_charges_small", "w": 30, "coeff": [0.0, 0.0], "charges": [4, 6], "cd_trade": 0.0},
]


## Roll a looted skillbook's affix. Returns {} (no affix, 82%) or the affix instance dict.
## Uses the global RNG (randf) — loot already runs under the run seed.
static func roll() -> Dictionary:
	if randf() >= CHANCE:
		return {}
	return _make_affix()


## Always returns an affix (18% 게이트 생략) — 희귀(좋은) 상자 전용. ref: chest loot 보장.
static func roll_forced() -> Dictionary:
	return _make_affix()


## 1~2개 affix를 굴려 **단일 인스턴스 dict로 병합**(ids 리스트 누적·coeff/charges/cd_trade 합산).
## 파이프라인은 그대로 dict 1개를 쓰레딩하고, apply는 합산 스칼라(coeff/charges/cd_trade)를 읽음 → 다종 affix
## 무리스크. 2nd는 다른 종류(다양성), coeff 합산은 §7.3 캡(0.15)으로 클램프.
static func _make_affix() -> Dictionary:
	var a := _make_part(_weighted_type())
	if randf() < MULTI_CHANCE:
		var second := _weighted_type_excluding(String((a["ids"] as Array)[0]))
		if not second.is_empty():
			_merge_part(a, _make_part(second))
	return a


static func _make_part(t: Dictionary) -> Dictionary:
	var tier := _roll_tier()
	var scale := float(TIER_SCALE.get(tier, 1.0))
	var coeff := minf(randf_range(float(t["coeff"][0]), float(t["coeff"][1])) * scale, SINGLE_COEFF_CAP)
	var charges := 0
	if int(t["charges"][1]) > 0:
		charges = randi_range(int(t["charges"][0]), int(t["charges"][1]))
	return {
		"ids": [String(t["id"])],
		"tier": tier,
		"coeff": snappedf(coeff, 0.001),     # 0.0 for charges-only affix
		"charges": charges,
		"cd_trade": float(t["cd_trade"]),
	}


## b를 a에 병합(제자리) — ids 누적, coeff 합산(§7.3 캡), charges·cd_trade 가산, tier=더 희귀한 쪽.
static func _merge_part(a: Dictionary, b: Dictionary) -> void:
	a["ids"] = (a["ids"] as Array) + (b["ids"] as Array)
	a["coeff"] = snappedf(minf(float(a["coeff"]) + float(b["coeff"]), SUM_COEFF_CAP), 0.001)
	a["charges"] = int(a["charges"]) + int(b["charges"])
	a["cd_trade"] = float(a["cd_trade"]) + float(b["cd_trade"])
	if _tier_rank(String(b["tier"])) > _tier_rank(String(a["tier"])):
		a["tier"] = b["tier"]


static func _tier_rank(tier: String) -> int:
	return {"T1": 1, "T2": 2, "T3": 3}.get(tier, 1)


static func _weighted_type_excluding(exclude_id: String) -> Dictionary:
	var pool: Array = []
	for t in TYPES:
		if String(t["id"]) != exclude_id:
			pool.append(t)
	if pool.is_empty():
		return {}
	var total := 0
	for t in pool:
		total += int(t["w"])
	var pick := randi_range(0, total - 1)
	for t in pool:
		pick -= int(t["w"])
		if pick < 0:
			return t
	return pool[0]


## Sum of coeffMult on an instance's affix (sanity-capped to §7.3 동일 인스턴스 합산 ≤15%).
static func coeff_of(affix) -> float:
	if typeof(affix) != TYPE_DICTIONARY:
		return 0.0
	return clampf(float((affix as Dictionary).get("coeff", 0.0)), -0.15, 0.15)


static func charges_of(affix) -> int:
	if typeof(affix) != TYPE_DICTIONARY:
		return 0
	return int((affix as Dictionary).get("charges", 0))


static func cd_trade_of(affix) -> float:
	if typeof(affix) != TYPE_DICTIONARY:
		return 0.0
	return float((affix as Dictionary).get("cd_trade", 0.0))


static func _roll_tier() -> String:
	var r := randf()
	if r < float(TIER_CUM[0]):
		return "T1"
	if r < float(TIER_CUM[1]):
		return "T2"
	return "T3"


static func _weighted_type() -> Dictionary:
	var total := 0
	for t in TYPES:
		total += int(t["w"])
	var pick := randi_range(0, total - 1)
	for t in TYPES:
		pick -= int(t["w"])
		if pick < 0:
			return t
	return TYPES[0]

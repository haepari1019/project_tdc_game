extends RefCounted
## Skillbook affix roll (D-018 §7.3 caps / §7.6 roll policy). Looted skillbooks have an 18% chance
## to gain ONE affix (Slice-01: single-affix per instance — trivially within the §7.3 sum cap).
## Shop Raw = 0% (callers just don't roll). The rolled instance carries `affix` = {} | a dict below;
## `coeff` feeds the cast potency multiplier (alongside the cross-class band, independent — §7.3 note),
## `charges` adds to chargesMax, `cd_trade` lengthens cooldown. ref: docs/design/affix_design.md.

const CHANCE := 0.18                                   # §7.6 affix 부여 (루팅만)
const SINGLE_COEFF_CAP := 0.12                         # §7.3 단일 coeffMult affix ≤ 12%

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
	var tier := _roll_tier()
	var t: Dictionary = _weighted_type()
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

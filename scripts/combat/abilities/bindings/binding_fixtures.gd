extends RefCounted
class_name BindingFixtures
## P4a Tank Kit Binding (결속) pilot overlays — BIND-PILOT-001~006. **NON-CANONICAL dev fixtures.**
## `docs/combat/bindings/` is CombatContentMap-UNREGISTERED in the spec (README) → these are deliberately
## NOT in `id_registry` / `require_id`. effectiveAbility = baseAbilityId + bindingOverlayId(if active);
## the AB effect files are NOT cloned — an overlay is a runtime DELTA applied AFTER the base sub cast.
## ref: F-020 §3.7 resolveEffectiveAbility · F-008 §3.9 · D-019 §10 · ROLE-010 §4.5 · QA-005 §2.12 · spec 77d9532.
##
## **공통 규약 (identity covenant):** identity가 시그니처 규약을 **선언·생성**하고, 링크된 서브(base 스킬)는
## 착용된 identity 규약에 의해 **상태-조건부로 버프**된다. 균일 구조 = [identity가 상태 생성] → [서브는 그
## 상태일 때 추가효과] → [상태 소모 시 캡스톤 보상]. 스펙 테마(ROLE-010 §4.5): Anchor Guard = 방벽 충전
## (누적 → 기절), Iron Beacon = 표식(낙인 → 응징). NC 미적용(F-020 §3.3, 조작 전용).
##
## Triple-match (F-020 §3.7): bindingProfileId(=`base_gear_id` slug) + identity `baseAbilityId` + slot
## `baseAbilityId` @ `slotIndex` 모두 일치해야 오버레이 활성. 불일치 → base only. gear ID = 게임 슬러그.

static var enabled: bool = true

## 정체성 규약 — identity 툴팁에 자기완결적으로 표시(상태 생성·의미·활용을 한 문단). {name, covenant}.
const SIGNATURE := {
	"AB-020": {
		"name": "방벽 충전",
		"covenant": "전선을 지키는 스킬을 쓸 때마다 방벽이 한 겹 쌓인다. 세 겹이 되면 방벽을 터뜨려 눈앞의 적을 기절시킨다.",
	},
	"AB-021": {
		"name": "표식",
		"covenant": "위협을 건 대상은 표식을 얻는다. 표식이 있는 적에게는 링크된 스킬이 추가 위협을 부여하며, 표식을 유지한 채 처치하면 링크된 모든 스킬의 재사용을 일부 돌려받는다.",
	},
}
## 시그니처 공통 payoff 파라미터 (해당 정체성의 모든 슬롯 스킬이 공유).
const BULWARK := {"stacks_needed": 3, "stun_s": 1.5, "icd_s": 8.0, "radius_m": 8.0}   # Anchor 방벽 → 기절(가장 가까운 적). stun_s=튜닝(스펙 예시 0.8, 체감↑ 위해 1.5)
const MARK := {"window_s": 8.0, "cd_reduce": 0.40, "radius_m": 8.0, "threat": 45.0}    # Beacon 표식 → 위협/환급

# `theme` = 시그니처(bulwark/mark). `delta` = 서브가 규약에 기여하는 방식(공통). `desc_ko` = 서브 툴팁 줄글.
# Anchor 서브: 전부 방벽 +1(공통 버프). Beacon 서브: 전부 표식 대상 조건부 위협(공통), R은 표식 갱신 추가.
const OVERLAYS := [
	{
		"id": "BIND-PILOT-001", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "AB-020", "slot_ab": "AB-033", "slot_index": 0, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Intercept → BulwarkCharge +1", "desc_ko": "방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-PILOT-002", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "AB-020", "slot_ab": "AB-034", "slot_index": 1, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Barrier → BulwarkCharge +1", "desc_ko": "방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-PILOT-003", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "AB-020", "slot_ab": "AB-035", "slot_index": 2, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Mark → BulwarkCharge +1", "desc_ko": "방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-PILOT-004", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "AB-021", "slot_ab": "AB-033", "slot_index": 0, "theme": "mark", "delta": "beacon_mark",
		"payoff": "Intercept → +threat vs marked", "desc_ko": "표식 대상에게 추가 위협 효과를 부여한다.",
	},
	{
		"id": "BIND-PILOT-005", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "AB-021", "slot_ab": "AB-034", "slot_index": 1, "theme": "mark", "delta": "beacon_mark",
		"payoff": "Barrier → +threat vs marked", "desc_ko": "표식 대상에게 추가 위협 효과를 부여한다.",
	},
	{
		"id": "BIND-PILOT-006", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "AB-021", "slot_ab": "AB-035", "slot_index": 2, "theme": "mark", "delta": "beacon_mark_refresh",
		"payoff": "Challenge → +threat vs marked + 표식 갱신", "desc_ko": "표식 대상에게 추가 위협을 주고, 표식의 유지 시간을 갱신한다.",
	},
]

## resolveEffectiveAbility (F-020 §3.7) — active overlay for a member's slot, or {} (base only). enabled=false → {}.
static func resolve(base_gear_id: String, identity_ab: String, slot_ab: String, slot_index: int) -> Dictionary:
	if not enabled:
		return {}
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov["slot_ab"]) == slot_ab and int(ov["slot_index"]) == slot_index:
			return ov
	return {}


## 이 gear+identity가 「표식」 킷(Beacon)인가 — identity가 시전 시 대상에 표식을 남기는지. enabled 게이트 포함.
static func identity_marks(base_gear_id: String, identity_ab: String) -> bool:
	if not enabled:
		return false
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov.get("theme", "")) == "mark":
			return true
	return false


## 이 gear+identity가 결속 킷이면 그 정체성 규약({name, covenant})을, 아니면 {}. identity 툴팁용.
static func signature_for(base_gear_id: String, identity_ab: String) -> Dictionary:
	if not enabled:
		return {}
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab:
			return SIGNATURE.get(identity_ab, {})
	return {}

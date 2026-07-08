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
## (누적 → 기절), Iron Beacon = 표식(낙인 → 응징), Mark & Ruin = 집중(누적 증폭 → 처형 폭발). NC 미적용(F-020 §3.3, 조작 전용).
##
## Triple-match (F-020 §3.7): bindingProfileId(=`base_gear_id` slug) + identity `baseAbilityId` + slot
## `baseAbilityId` @ `slotIndex` 모두 일치해야 오버레이 활성. 불일치 → base only. gear ID = 게임 슬러그.

## 결속은 기어+정체성+서브를 착용한 순간 내재적으로 적용된다(on/off 토글 없음 — triple-match면 항상 활성).

## 정체성 규약 — identity 툴팁에 자기완결적으로 표시(상태 생성·의미·활용을 한 문단). {name, covenant}.
const SIGNATURE := {
	"IDA-020": {
		"name": "방벽 충전",
		"covenant": "전선을 지키는 스킬을 쓸 때마다 방벽이 한 겹 쌓인다. 세 겹이 되면 방벽을 터뜨려 눈앞의 적을 기절시킨다.",
	},
	"IDA-021": {
		"name": "표식",
		"covenant": "위협을 건 대상은 표식을 얻는다. 표식이 있는 적에게는 링크된 스킬이 추가 위협을 부여하며, 표식을 유지한 채 처치하면 링크된 모든 스킬의 재사용을 일부 돌려받는다.",
	},
	"IDA-025": {
		"name": "집중",
		"covenant": "정체성이 단일 표적을 집중 대상으로 새긴다. 링크된 스킬을 그 대상에게 명중시킬수록 집중이 쌓여 피해가 증폭되고, 다른 적을 조준하면 집중이 초기화된다. 집중을 소모하는 계열의 스킬을 사용하면, 쌓아 둔 집중을 모두 터뜨려 집중 수에 비례한 추가 피해를 준다.",
	},
	"IDA-029": {
		"name": "잠행",
		"covenant": "정체성이 근접 교전을 강제한다. 링크된 스킬은 근접 거리에서만 시전되지만, 원래 사거리가 멀수록 더 큰 피해(1차)와 재사용 감소(2차)를 얻는다. 적을 처치하면 짧은 시간 은신하여 적의 표적에서 벗어난다.",
	},
	"IDA-031": {
		"name": "지속 치유",
		"covenant": "이 정체성이 있는 동안 모든 치유가 지속 치유로 전환된다. 즉시 회복하는 대신 더 오랜 시간에 걸쳐 여러 번 나눠 들어오지만, 총 회복량이 늘어난다.",
	},
	"IDA-026": {
		"name": "성역",
		"covenant": "정체성이 발밑에 좁은 성역을 세운다. 성역 안에 머문 채 치유 스킬을 시전하면 회복량이 크게 늘지만, 성역을 벗어나면 평범해진다. 움직이며 쫓을지, 성역을 지키며 강하게 치유할지 선택하게 된다.",
	},
}
## 시그니처 공통 payoff 파라미터 (해당 정체성의 모든 슬롯 스킬이 공유).
const BULWARK := {"stacks_needed": 3, "stun_s": 1.5, "icd_s": 8.0, "radius_m": 8.0}   # Anchor 방벽 → 기절(가장 가까운 적). stun_s=튜닝(스펙 예시 0.8, 체감↑ 위해 1.5)
const MARK := {"window_s": 8.0, "cd_reduce": 0.40, "radius_m": 8.0, "threat": 45.0}    # Beacon 표식 → 위협/환급
const FOCUS := {"stack_cap": 5, "stack_dmg_pct": 0.15, "window_s": 8.0, "radius_m": 12.0, "spend_mult": 0.7}  # Mark&Ruin 집중 → 누적 추가타 / 소모 시 누적 비례 폭발
# 「집중」 소모 아키타입 — 이 계열의 kind을 가진 스킬이면 슬롯·링크 여부와 무관하게 누적 집중을 소모한다.
# 특정 처형 스킬(AB) 하드코딩을 피하려는 의도(그 스킬이 반드시 장착된다는 보장이 없음). 소모형 kind 추가 시 여기에.
const FOCUS_SPEND_KINDS := ["skillbook_execute"]
# Flank Collapse 잠행 — 링크 스킬을 근접 사거리로 강제하고, 원래 range_band이 멀수록 큰 이득(1차 피해/2차 쿨감).
# 처치 시 veil_s초 은신(apply_veil = 적 표적 드롭 = 어그로 감소). band_dmg=basic_damage 배수, band_cd=쿨 감소율.
const FLANK := {
	"melee_range_m": 2.8, "veil_s": 2.0,
	"band_dmg": {"Melee": 0.0, "Mid": 0.25, "Long": 0.5},
	"band_cd": {"Melee": 0.0, "Mid": 0.10, "Long": 0.20},
}
# Ward Pulse 자리 재해석 → 지속 치유(가호=보호막 폐지, DRIFT-073). 치유 choke(deal_heal/deal_regen)가 정체성
# 게이트로 즉시 치유를 HoT로 전환: 총량 = 원래 치유 × total_mult 를 dur초에 걸쳐. 기존 apply_regen 재사용(신규 상태 없음).
const DOT := {"total_mult": 1.4, "dur": 4.0}
# Mend Circle 성역 — 정체성이 발밑에 좁은 zone(radius_m)을 세우고, 그 안에서 시전한 치유를 amp배 증폭(무빙 대신
# 제자리 시전 유도). 치유 choke(deal_heal/deal_regen)가 in_sanctuary 게이트로 증폭. dur초 후 만료·재설치.
const SANCT := {"radius_m": 3.0, "dur": 8.0, "amp": 1.4}

# `theme` = 시그니처(bulwark/mark). `delta` = 서브가 규약에 기여하는 방식(공통). `desc_ko` = 서브 툴팁 줄글.
# Anchor 서브: 전부 방벽 +1(공통 버프). Beacon 서브: 전부 표식 대상 조건부 위협(공통), R은 표식 갱신 추가.
const OVERLAYS := [
	{
		"id": "BIND-PILOT-001", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "IDA-020", "slot_ab": "AB-033", "slot_index": 0, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Intercept → BulwarkCharge +1", "desc_ko": "방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-PILOT-002", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "IDA-020", "slot_ab": "AB-034", "slot_index": 1, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Barrier → BulwarkCharge +1", "desc_ko": "방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-PILOT-003", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "IDA-020", "slot_ab": "AB-035", "slot_index": 2, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Mark → BulwarkCharge +1", "desc_ko": "방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-PILOT-004", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "IDA-021", "slot_ab": "AB-033", "slot_index": 0, "theme": "mark", "delta": "beacon_mark",
		"payoff": "Intercept → +threat vs marked", "desc_ko": "표식 대상에게 추가 위협 효과를 부여한다.",
	},
	{
		"id": "BIND-PILOT-005", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "IDA-021", "slot_ab": "AB-034", "slot_index": 1, "theme": "mark", "delta": "beacon_mark",
		"payoff": "Barrier → +threat vs marked", "desc_ko": "표식 대상에게 추가 위협 효과를 부여한다.",
	},
	{
		"id": "BIND-PILOT-006", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "IDA-021", "slot_ab": "AB-035", "slot_index": 2, "theme": "mark", "delta": "beacon_mark_refresh",
		"payoff": "Challenge → +threat vs marked + 표식 갱신", "desc_ko": "표식 대상에게 추가 위협을 주고, 표식의 유지 시간을 갱신한다.",
	},
	# Nuker Mark&Ruin 「집중」 링크 서브(빌더): 집중 대상 명중 시 누적 +1 & 누적 비례 추가타(공통).
	# 소모는 슬롯 오버레이가 아니라 아키타입 규칙(FOCUS_SPEND_KINDS / is_focus_spender)이 담당 — 특정 처형 스킬에 묶지 않음.
	{
		"id": "BIND-PILOT-007", "gear": "gear_ward_nuker_ruin_sight",
		"identity_ab": "IDA-025", "slot_ab": "AB-055", "slot_index": 0, "theme": "focus", "delta": "focus_stack",
		"payoff": "ScatterShot → Focus +1 & 누적 비례 추가타", "desc_ko": "집중 대상에게 명중하면 집중을 한 겹 쌓고, 쌓인 만큼 추가 피해를 준다. 다른 적을 조준하면 집중이 초기화된다.",
	},
	{
		"id": "BIND-PILOT-008", "gear": "gear_ward_nuker_ruin_sight",
		"identity_ab": "IDA-025", "slot_ab": "AB-072", "slot_index": 1, "theme": "focus", "delta": "focus_stack",
		"payoff": "Hailstorm → Focus +1 & 누적 비례 추가타", "desc_ko": "집중 대상에게 명중하면 집중을 한 겹 쌓고, 쌓인 만큼 추가 피해를 준다. 다른 적을 조준하면 집중이 초기화된다.",
	},
	# Nuker Flank Collapse 「잠행」 링크 서브: 근접 사거리로만 시전 + 원래 range_band 비례 이득(1차 뎀/2차 쿨감).
	# 처치 시 은신은 슬롯 오버레이가 아니라 kill 훅(identity_flanks 게이트)이 담당 — 어떤 처치든 vanish.
	{
		"id": "BIND-PILOT-010", "gear": "gear_ward_nuker_flank_knife",
		"identity_ab": "IDA-029", "slot_ab": "AB-055", "slot_index": 0, "theme": "flank", "delta": "flank_strike",
		"payoff": "ScatterShot(Mid) → 근접화 + 사거리 비례 이득", "desc_ko": "근접에서만 시전된다. 원래 사거리가 멀수록 추가 피해가 크고 재사용이 짧아진다.",
	},
	{
		"id": "BIND-PILOT-011", "gear": "gear_ward_nuker_flank_knife",
		"identity_ab": "IDA-029", "slot_ab": "AB-072", "slot_index": 1, "theme": "flank", "delta": "flank_strike",
		"payoff": "Hailstorm(Long) → 근접화 + 사거리 비례 이득(큼)", "desc_ko": "근접에서만 시전된다. 원래 사거리가 멀수록 추가 피해가 크고 재사용이 짧아진다.",
	},
	{
		"id": "BIND-PILOT-012", "gear": "gear_ward_nuker_flank_knife",
		"identity_ab": "IDA-029", "slot_ab": "AB-060", "slot_index": 2, "theme": "flank", "delta": "flank_strike",
		"payoff": "Rupture(Mid) → 근접화 + 사거리 비례 이득", "desc_ko": "근접에서만 시전된다. 원래 사거리가 멀수록 추가 피해가 크고 재사용이 짧아진다.",
	},
	# Healer 지속치유(가호 폐지) 링크 힐 서브: 실제 전환은 deal_heal/deal_regen choke(정체성 게이트)가 담당 —
	# 오버레이는 킷 등록 + 툴팁용(delta "dot_heal"은 _apply_binding에서 no-op, 전환은 choke에서).
	{
		"id": "BIND-PILOT-013", "gear": "gear_ward_healer_ward_sigil",
		"identity_ab": "IDA-031", "slot_ab": "AB-064", "slot_index": 0, "theme": "dot_heal", "delta": "dot_heal",
		"payoff": "QuickMend → 지속 치유 전환", "desc_ko": "즉시 치유가 지속 치유로 바뀌어 더 오래 나눠 들어오고, 총 회복량이 늘어난다.",
	},
	{
		"id": "BIND-PILOT-014", "gear": "gear_ward_healer_ward_sigil",
		"identity_ab": "IDA-031", "slot_ab": "AB-065", "slot_index": 1, "theme": "dot_heal", "delta": "dot_heal",
		"payoff": "RenewingTide → 지속 치유 강화", "desc_ko": "지속 치유의 총 회복량이 늘어난다.",
	},
	{
		"id": "BIND-PILOT-015", "gear": "gear_ward_healer_ward_sigil",
		"identity_ab": "IDA-031", "slot_ab": "AB-066", "slot_index": 2, "theme": "dot_heal", "delta": "dot_heal",
		"payoff": "SanctuaryFont → 지속 치유 강화", "desc_ko": "지속 치유의 총 회복량이 늘어난다.",
	},
	# Healer 성역 링크 힐 서브: 실제 증폭은 deal_heal/deal_regen choke(in_sanctuary 게이트) — 오버레이는 등록+툴팁용.
	{
		"id": "BIND-PILOT-016", "gear": "gear_ward_healer_mend_lantern",
		"identity_ab": "IDA-026", "slot_ab": "AB-064", "slot_index": 0, "theme": "sanctuary", "delta": "sanct",
		"payoff": "QuickMend → 성역 안 증폭", "desc_ko": "성역 안에 머문 채 시전하면 회복량이 늘어난다. 성역을 벗어나면 평범해진다.",
	},
	{
		"id": "BIND-PILOT-017", "gear": "gear_ward_healer_mend_lantern",
		"identity_ab": "IDA-026", "slot_ab": "AB-065", "slot_index": 1, "theme": "sanctuary", "delta": "sanct",
		"payoff": "RenewingTide → 성역 안 증폭", "desc_ko": "성역 안에 머문 채 시전하면 회복량이 늘어난다. 성역을 벗어나면 평범해진다.",
	},
	{
		"id": "BIND-PILOT-018", "gear": "gear_ward_healer_mend_lantern",
		"identity_ab": "IDA-026", "slot_ab": "AB-066", "slot_index": 2, "theme": "sanctuary", "delta": "sanct",
		"payoff": "SanctuaryFont → 성역 안 증폭", "desc_ko": "성역 안에 머문 채 시전하면 회복량이 늘어난다. 성역을 벗어나면 평범해진다.",
	},
]

## resolveEffectiveAbility (F-020 §3.7) — active overlay for a member's slot, or {} (base only). 착용 즉시 활성.
static func resolve(base_gear_id: String, identity_ab: String, slot_ab: String, slot_index: int) -> Dictionary:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov["slot_ab"]) == slot_ab and int(ov["slot_index"]) == slot_index:
			return ov
	return {}


## 이 gear+identity가 「표식」 킷(Beacon)인가 — identity가 시전 시 대상에 표식을 남기는지.
static func identity_marks(base_gear_id: String, identity_ab: String) -> bool:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov.get("theme", "")) == "mark":
			return true
	return false


## kind이 「집중」 소모 아키타입인가 — 이 계열 스킬을 쓰면 슬롯/링크 여부와 무관하게 누적 집중을 소모한다.
## 특정 처형 AB에 묶지 않는 카테고리 규칙.
static func is_focus_spender(kind: String) -> bool:
	return FOCUS_SPEND_KINDS.has(kind)


## 이 gear+identity가 「집중」 킷(Mark&Ruin)인가 — identity가 시전 시 단일 표적을 집중 대상으로 새기는지.
static func identity_focuses(base_gear_id: String, identity_ab: String) -> bool:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov.get("theme", "")) == "focus":
			return true
	return false


## 이 gear+identity가 「잠행」 킷(Flank Collapse)인가 — 처치 시 은신(veil) 게이트 + 툴팁용.
static func identity_flanks(base_gear_id: String, identity_ab: String) -> bool:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov.get("theme", "")) == "flank":
			return true
	return false


## 이 gear+identity가 「지속 치유」 킷(DoT heal)인가 — 치유 choke가 즉시 치유→HoT 전환할지 게이트.
static func identity_dot_heals(base_gear_id: String, identity_ab: String) -> bool:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov.get("theme", "")) == "dot_heal":
			return true
	return false


## 이 gear+identity가 「성역」 킷(Mend Circle)인가 — 정체성이 성역을 세우고 치유 choke가 in-zone 증폭할지 게이트.
static func identity_sanctuaries(base_gear_id: String, identity_ab: String) -> bool:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov.get("theme", "")) == "sanctuary":
			return true
	return false


## 이 gear+identity가 결속 킷이면 그 정체성 규약({name, covenant})을, 아니면 {}. identity 툴팁용.
static func signature_for(base_gear_id: String, identity_ab: String) -> Dictionary:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab:
			return SIGNATURE.get(identity_ab, {})
	return {}

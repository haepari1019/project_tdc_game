extends RefCounted
class_name BindingOverlays
## Kit Binding (결속) — 정본 결속 오버레이 레지스트리. **게임이 SSOT** (IMPL-DEC-20260709-001: spec 로드맵 스텁 역전).
## 결속 = effectiveAbility = baseAbilityId + bindingOverlayId(활성 시). AB effect 파일은 복제하지 않음 —
## 오버레이는 base 서브 캐스트 **후** 적용되는 런타임 DELTA. resolve = triple-match(gear + identity_ab + slot_ab + slot).
## id_registry 미등재 = 오버레이는 **독립 능력이 아니라** effectiveAbility 합성 요소(별 네임스페이스 BIND-###) —
## spec CombatContentMap도 bindings 미등재. 정식 spec 등재는 P4b 정본화 배치(OPS_30).
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
		"covenant": "공격이 적에게 명중하면 그 대상이 집중 대상이 된다(평타·정체성·서브 공통). 같은 대상에게 계속 명중시킬수록 집중이 쌓여 피해가 증폭되고, 다른 적을 명중시키면 집중이 그 적으로 옮겨가며 초기화된다. 집중을 소모하는 계열의 스킬을 사용하면, 쌓아 둔 집중을 모두 터뜨려 집중 수에 비례한 추가 피해를 준다.",
	},
	"IDA-029": {
		"name": "잠행",
		"covenant": "정체성이 근접 교전을 강제한다. 링크된 스킬은 근접 거리에서만 시전되지만, 원래 사거리가 멀수록 더 큰 피해(1차)와 재사용 감소(2차)를 얻는다. 이미 근접인 스킬은 피해 배율 +15%를 얻는다(합연산). 적을 처치하면 짧은 시간 은신하여 적의 표적에서 벗어난다.",
	},
	"IDA-031": {
		"name": "지속 치유",
		"covenant": "이 정체성이 있는 동안 모든 치유가 지속 치유로 전환된다. 즉시 회복하는 대신 더 오랜 시간에 걸쳐 여러 번 나눠 들어오지만, 총 회복량이 늘어난다.",
	},
	"IDA-026": {
		"name": "성역",
		"covenant": "정체성이 발밑에 좁은 성역을 세운다. 성역 안에 머문 채 치유 스킬을 시전하면 회복량이 크게 늘지만, 성역을 벗어나면 평범해진다. 움직이며 쫓을지, 성역을 지키며 강하게 치유할지 선택하게 된다.",
	},
	"IDA-024": {
		"name": "초월",
		"covenant": "스킬과 평타로 적을 명중할 때마다 초월 게이지가 쌓인다. 게이지가 가득 차면 짧은 시간 초월 상태가 되어 링크된 스킬이 강화된 형태로 발동한다 — 화염은 화상 지속딜을 남기고, 광선은 적을 끌어당기며, 냉기는 얼려버린다. 게이지는 힐·탱을 운영하는 동안에도 쌓이니, 초월이 켜지는 순간 딜러로 전환해 몰아쳐라.",
	},
	"IDA-027": {
		"name": "혈풍",
		"covenant": "링크된 스킬은 모두 자신의 체력을 대가로 시전되지만, 광역으로 명중한 적의 수에 비례해 체력을 돌려받는다. 세 명 이상 휩쓸면 오히려 이득이다. 적이 많을수록 강하게 유지되고 적이 적으면 손해이니, 광역이 필요한 순간에 꺼내 쓰는 정체성이다.",
	},
}
## 시그니처 공통 payoff 파라미터 (해당 정체성의 모든 슬롯 스킬이 공유).
const BULWARK := {"stacks_needed": 3, "stun_s": 1.5, "icd_s": 8.0, "radius_m": 8.0}   # Anchor 방벽 → 기절(가장 가까운 적). stun_s=튜닝(스펙 예시 0.8, 체감↑ 위해 1.5)
const MARK := {"window_s": 8.0, "cd_reduce": 0.40, "radius_m": 8.0, "threat": 45.0}    # Beacon 표식 → 위협/환급
const FOCUS := {"stack_cap": 5, "stack_dmg_pct": 0.15, "window_s": 8.0, "radius_m": 12.0, "seed_radius_m": 3.0, "spend_mult": 0.7, "spread_m": 8.0}  # Mark&Ruin 집중 → 링크 서브가 명중한 적(seed_radius_m 내 = 조준 대상)을 집중 대상으로 새김 / 누적 추가타 / 소모 폭발 / E는 spread_m 내 근처 적으로 전이
# 「집중」 소모 아키타입 — 이 계열의 kind을 가진 스킬이면 슬롯·링크 여부와 무관하게 누적 집중을 소모한다.
# 특정 처형 스킬(AB) 하드코딩을 피하려는 의도(그 스킬이 반드시 장착된다는 보장이 없음). 소모형 kind 추가 시 여기에.
const FOCUS_SPEND_KINDS := ["skillbook_execute"]
# Flank Collapse 잠행 — 링크 스킬을 근접 사거리로 강제하고, 원래 range_band이 멀수록 큰 이득(1차 피해/2차 쿨감).
# 처치 시 veil_s초 은신(apply_veil = 적 표적 드롭 = 어그로 감소). band_dmg=basic_damage 배수, band_cd=쿨 감소율.
const FLANK := {
	"melee_range_m": 2.8, "veil_s": 2.0, "dash_m": 4.0,   # E 이탈 = 짧은 고정 거리(원래 서브 사거리 15m를 그대로 쓰면 너무 멀리 튕김, DRIFT-076)
	"band_dmg": {"Melee": 0.15, "Mid": 0.25, "Long": 0.5},   # Melee = 이미 근접 → generic +15%(합연산). Mid/Long = 근접화 보상(멀수록 큼)
	"band_cd": {"Melee": 0.0, "Mid": 0.10, "Long": 0.20},
	"disengage_veil_s": 4.0, "disengage_bonus": 0.3,   # AB-007 이탈 잠행 결속 — 은신 유지 초 + 은신 첫 스킬 증폭
}
# Ward Pulse 자리 재해석 → 지속 치유(가호=보호막 폐지, DRIFT-073). 치유 choke(deal_heal/deal_regen)가 정체성
# 게이트로 즉시 치유를 HoT로 전환: 총량 = 원래 치유 × total_mult 를 dur초에 걸쳐. 기존 apply_regen 재사용(신규 상태 없음).
const DOT := {"total_mult": 1.4, "dur": 4.0}
# Mend Circle 성역 — 정체성이 발밑에 좁은 zone(radius_m)을 세우고, 그 안에서 시전한 치유를 amp배 증폭(무빙 대신
# 제자리 시전 유도). 치유 choke(deal_heal/deal_regen)가 in_sanctuary 게이트로 증폭. dur초 후 만료·재설치.
const SANCT := {"radius_m": 3.0, "dur": 8.0, "amp": 1.4}
# DPS press_line 「초월(Overdrive)」 — 명중으로 게이지 충전(평타/서브·조작AI공통), 가득 차면 dur초간 링크 서브가
# **강화 변형**으로 발동(단순 배수 아님·효과 변화, ref=LoL 카르마 Mantra). fire→화상 DoT(Ignited·적한정),
# beam→끌어당김(pull), cold→빙결(Rooted), bolt→감전 폭주(Silenced·적한정). DPS=광역이라 전부 대상한정=아군 무피해. DRIFT-077.
const OVERDRIVE := {
	"gauge_max": 100.0, "basic_gain": 8.0, "sub_gain": 12.0, "hits_cap": 5, "dur": 6.0,
	"burn_dur": 4.0, "burn_dps_pct": 0.4, "beam_pull_m": 3.0, "beam_half_deg": 12.0,
	"cold_root_s": 1.5, "radius_bonus_m": 1.0, "bolt_silence_s": 2.0, "poison_overdrive_stacks": 3.0,
}
# DPS arc_weave 「혈풍(Blood Gale)」 — 서브 시전당 max_hp 소모, 명중 적 수 비례 회복(3기+ 순이득). 서브가
# 애초에 광역이라 억지 스플래시 없이 자연 성립. 자살 불가(hp_floor 클램프). DRIFT-077.
const BLOODGALE := {
	"hp_cost_pct": 0.12, "refund_pct": 0.05, "hp_floor": 1.0,
	"beam_refund_mult": 2.0,   # 흡혈 광선(절단광선) — 채널 사이펀이라 회복 증폭(더 빨아옴)
	"shield_dur": 5.0,          # 혈빙(빙결) — 과회복(max_hp 초과)분을 임시 보호막으로, 이 시간동안
}

# ── 정체성 기본 델타 (GENERIC) — DRIFT-087 ────────────────────────────────────────────────────
# 결속은 이제 **정체성 착용만으로 장착한 모든 서브에 기본 델타가 적용된다**(등록 불요). OVERLAYS 항목은
# **변주/특수만** 담는다(초월·혈풍 variant · 슬롯 변주 · 이탈 결속). 이유: generic 델타의 등록 항목은
# 정보를 담지 않아(BIND-001/002/003은 세 줄이 완전히 동일) 순수 비용이었고, **누락 = 조용한 기능 상실**
# 이었다(AB-008이 미등록이라 결속 델타 0이던 사례). 「정체성별 동일 3서브」 평가 패리티 제약은 검증
# 완료로 해제(사용자, 2026-07-19).
#   · Healer(IDA-031/026)는 애초에 identity 단위 — `identity_dot_heals`/`identity_sanctuaries`가 치유
#     choke를 게이트하므로 여기 등재 불요(delta 경로를 안 탄다).
#   · IDA-024 초월 = 기본은 **게이지 충전만**(variant ""), 강화 변형은 AB 단 등록분만. 미등록 서브도
#     게이지는 쌓이되 폭주 시 변형이 없다 — 저작 전 상태이지 버그가 아니다.
#   · IDA-027 혈풍 = 기본 `burst`(흡수 폭발). beam/cold만 OVERLAYS가 특수 변형으로 덮어쓴다.
const GENERIC := {
	"IDA-020": {"delta": "bulwark_charge", "theme": "bulwark",
		"desc_ko": "방벽을 한 겹 쌓는다."},
	"IDA-021": {"delta": "beacon_mark", "theme": "mark",
		"desc_ko": "표식 대상에게 추가 위협 효과를 부여한다."},
	"IDA-025": {"delta": "focus_stack", "theme": "focus",
		"desc_ko": "명중한 적을 집중 대상으로 새기고 집중을 한 겹 쌓아, 쌓인 만큼 추가 피해를 준다. 다른 적을 명중하면 집중이 그 적으로 옮겨가며 초기화된다."},
	"IDA-029": {"delta": "flank_strike", "theme": "flank",
		"desc_ko": "근접에서만 시전된다. 원래 사거리가 멀수록 추가 피해가 크고 재사용이 짧아진다."},
	"IDA-024": {"delta": "overdrive_charge", "variant": "", "theme": "overdrive",
		"desc_ko": "명중 시 초월 게이지를 채운다."},
	"IDA-027": {"delta": "blood_soak", "variant": "burst", "theme": "bloodgale",
		"desc_ko": "체력을 대가로 시전하고, 광역으로 맞춘 적 수에 비례해 회복한다(3기 이상이면 이득)."},
}

# `theme` = 시그니처(bulwark/mark). `delta` = 서브가 규약에 기여하는 방식(공통). `desc_ko` = 서브 툴팁 줄글.
# Anchor 서브: 전부 방벽 +1(공통 버프). Beacon 서브: 전부 표식 대상 조건부 위협(공통), R은 표식 갱신 추가.
const OVERLAYS := [
	{
		"id": "BIND-001", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "IDA-020", "slot_ab": "AB-033", "slot_index": 0, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Intercept → BulwarkCharge +1", "desc_ko": "방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-002", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "IDA-020", "slot_ab": "AB-034", "slot_index": 1, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Barrier → BulwarkCharge +1", "desc_ko": "방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-003", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "IDA-020", "slot_ab": "AB-035", "slot_index": 2, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Mark → BulwarkCharge +1", "desc_ko": "방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-004", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "IDA-021", "slot_ab": "AB-033", "slot_index": 0, "theme": "mark", "delta": "beacon_mark",
		"payoff": "Intercept → +threat vs marked", "desc_ko": "표식 대상에게 추가 위협 효과를 부여한다.",
	},
	{
		"id": "BIND-005", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "IDA-021", "slot_ab": "AB-034", "slot_index": 1, "theme": "mark", "delta": "beacon_mark",
		"payoff": "Barrier → +threat vs marked", "desc_ko": "표식 대상에게 추가 위협 효과를 부여한다.",
	},
	{
		"id": "BIND-006", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "IDA-021", "slot_ab": "AB-035", "slot_index": 2, "theme": "mark", "delta": "beacon_mark_refresh",
		"payoff": "Challenge → +threat vs marked + 표식 갱신", "desc_ko": "표식 대상에게 추가 위협을 주고, 표식의 유지 시간을 갱신한다.",
	},
	# Nuker Mark&Ruin 「집중」 링크 서브(빌더): 집중 대상 명중 시 누적 +1 & 누적 비례 추가타(공통).
	# 소모는 슬롯 오버레이가 아니라 아키타입 규칙(FOCUS_SPEND_KINDS / is_focus_spender)이 담당 — 특정 처형 스킬에 묶지 않음.
	{
		"id": "BIND-007", "gear": "gear_ward_nuker_ruin_sight",
		"identity_ab": "IDA-025", "slot_ab": "AB-004", "slot_index": 0, "theme": "focus", "delta": "focus_stack",
		"payoff": "전격사격 → Focus +1 & 누적 비례 추가타", "desc_ko": "명중한 적을 집중 대상으로 새기고 집중을 한 겹 쌓아, 쌓인 만큼 추가 피해를 준다. 다른 적을 명중하면 집중이 그 적으로 옮겨가며 초기화된다.",
	},
	{
		"id": "BIND-008", "gear": "gear_ward_nuker_ruin_sight",
		"identity_ab": "IDA-025", "slot_ab": "AB-059", "slot_index": 1, "theme": "focus", "delta": "focus_spread",
		"payoff": "공허창 → 누적 추가타 + 집중을 근처 적으로 전이", "desc_ko": "집중 대상을 명중하면 누적+추가 피해를 준 뒤, 집중을 근처의 다른 적으로 전이시킨다(누적 유지).",
	},
	{
		"id": "BIND-027", "gear": "gear_ward_nuker_ruin_sight",
		"identity_ab": "IDA-025", "slot_ab": "AB-005", "slot_index": 0, "theme": "focus", "delta": "focus_dump",
		"payoff": "Melee Flurry — 단일: 집중 소모 처형 / 광역: 집중 유지·빌드", "desc_ko": "레인에 적이 하나뿐이면 쌓아둔 집중을 모두 소모해 처형 폭발을 일으킨다. 여럿이면 집중을 유지·누적하며 쓸어버린다.",
	},
	# Nuker Flank Collapse 「잠행」 링크 서브: 근접 사거리로만 시전 + 원래 range_band 비례 이득(1차 뎀/2차 쿨감).
	# 처치 시 은신은 슬롯 오버레이가 아니라 kill 훅(identity_flanks 게이트)이 담당 — 어떤 처치든 vanish.
	{
		"id": "BIND-010", "gear": "gear_ward_nuker_flank_knife",
		"identity_ab": "IDA-029", "slot_ab": "AB-004", "slot_index": 0, "theme": "flank", "delta": "flank_strike",
		"payoff": "전격사격(Long) → 근접화 + 사거리 비례 이득(큼)", "desc_ko": "근접에서만 시전된다. 원래 사거리가 멀수록 추가 피해가 크고 재사용이 짧아진다.",
	},
	{
		"id": "BIND-011", "gear": "gear_ward_nuker_flank_knife",
		"identity_ab": "IDA-029", "slot_ab": "AB-059", "slot_index": 1, "theme": "flank", "delta": "flank_dash",
		"payoff": "공허창(Long) → 근접화 + 사거리 비례 이득 + 타격 후 반대편 이탈", "desc_ko": "근접에서만 시전된다. 원래 사거리 비례 이득에 더해, 발현 후 적의 반대편으로 원래 사거리만큼 순간 이탈한다.",
	},
	{
		"id": "BIND-012", "gear": "gear_ward_nuker_flank_knife",
		"identity_ab": "IDA-029", "slot_ab": "AB-060", "slot_index": 2, "theme": "flank", "delta": "flank_strike",
		"payoff": "Rupture(Mid) → 근접화 + 사거리 비례 이득", "desc_ko": "근접에서만 시전된다. 원래 사거리가 멀수록 추가 피해가 크고 재사용이 짧아진다.",
	},
	{
		"id": "BIND-028", "gear": "gear_ward_nuker_flank_knife",
		"identity_ab": "IDA-029", "slot_ab": "AB-005", "slot_index": 0, "theme": "flank", "delta": "flank_strike",
		"payoff": "Melee Flurry(근접) → generic +15% 추가타(합연산)", "desc_ko": "이미 근접 스킬이라 근접화 보상으로 +15% 추가 피해를 얻는다(합연산).",
	},
	# Tank Toll Stun(AB-011) — 타겟 단일 기절. 방벽/표식 둘 다 generic delta로 링크(코드 무변경).
	{
		"id": "BIND-029", "gear": "gear_ward_tank_anchor_bulwark",
		"identity_ab": "IDA-020", "slot_ab": "AB-011", "slot_index": 0, "theme": "bulwark", "delta": "bulwark_charge",
		"payoff": "Toll Stun → 방벽 충전", "desc_ko": "적을 기절시키며 방벽을 한 겹 쌓는다.",
	},
	{
		"id": "BIND-030", "gear": "gear_ward_tank_kite_shield",
		"identity_ab": "IDA-021", "slot_ab": "AB-011", "slot_index": 0, "theme": "mark", "delta": "beacon_mark",
		"payoff": "Toll Stun → 표식", "desc_ko": "기절시킨 적을 표식해 추가 위협을 부여한다.",
	},
	# Healer 지속치유(가호 폐지) 링크 힐 서브: 실제 전환은 deal_heal/deal_regen choke(정체성 게이트)가 담당 —
	# 오버레이는 킷 등록 + 툴팁용(delta "dot_heal"은 _apply_binding에서 no-op, 전환은 choke에서).
	{
		"id": "BIND-013", "gear": "gear_ward_healer_ward_sigil",
		"identity_ab": "IDA-031", "slot_ab": "AB-064", "slot_index": 0, "theme": "dot_heal", "delta": "dot_heal",
		"payoff": "QuickMend → 지속 치유 전환", "desc_ko": "즉시 치유가 지속 치유로 바뀌어 더 오래 나눠 들어오고, 총 회복량이 늘어난다.",
	},
	{
		"id": "BIND-014", "gear": "gear_ward_healer_ward_sigil",
		"identity_ab": "IDA-031", "slot_ab": "AB-065", "slot_index": 1, "theme": "dot_heal", "delta": "dot_heal",
		"payoff": "RenewingTide → 지속 치유 강화", "desc_ko": "지속 치유의 총 회복량이 늘어난다.",
	},
	{
		"id": "BIND-015", "gear": "gear_ward_healer_ward_sigil",
		"identity_ab": "IDA-031", "slot_ab": "AB-066", "slot_index": 2, "theme": "dot_heal", "delta": "dot_heal",
		"payoff": "SanctuaryFont → 지속 치유 강화", "desc_ko": "지속 치유의 총 회복량이 늘어난다.",
	},
	# Healer 성역 링크 힐 서브: 실제 증폭은 deal_heal/deal_regen choke(in_sanctuary 게이트) — 오버레이는 등록+툴팁용.
	{
		"id": "BIND-016", "gear": "gear_ward_healer_mend_lantern",
		"identity_ab": "IDA-026", "slot_ab": "AB-064", "slot_index": 0, "theme": "sanctuary", "delta": "sanct",
		"payoff": "QuickMend → 성역 안 증폭", "desc_ko": "성역 안에 머문 채 시전하면 회복량이 늘어난다. 성역을 벗어나면 평범해진다.",
	},
	{
		"id": "BIND-017", "gear": "gear_ward_healer_mend_lantern",
		"identity_ab": "IDA-026", "slot_ab": "AB-065", "slot_index": 1, "theme": "sanctuary", "delta": "sanct",
		"payoff": "RenewingTide → 성역 안 증폭", "desc_ko": "성역 안에 머문 채 시전하면 회복량이 늘어난다. 성역을 벗어나면 평범해진다.",
	},
	{
		"id": "BIND-018", "gear": "gear_ward_healer_mend_lantern",
		"identity_ab": "IDA-026", "slot_ab": "AB-066", "slot_index": 2, "theme": "sanctuary", "delta": "sanct",
		"payoff": "SanctuaryFont → 성역 안 증폭", "desc_ko": "성역 안에 머문 채 시전하면 회복량이 늘어난다. 성역을 벗어나면 평범해진다.",
	},
	# DPS press_line 「초월」 링크 서브(광역 3종 + bolt 대체 슬롯): 명중 시 초월 게이지 충전, 초월 중이면 서브가 강화 변형으로 발동.
	# 강화는 kind로 분기(fire→화상 / beam→끌어당김 / cold→빙결 / bolt→감전 폭주) — _dps_overdrive. delta 공통 overdrive_charge.
	{
		"id": "BIND-019", "gear": "gear_ward_dps_press_rod",
		"identity_ab": "IDA-024", "slot_ab": "AB-053", "slot_index": 0, "theme": "overdrive", "delta": "overdrive_charge", "variant": "burn",
		"payoff": "작열 폭발 → 초월 충전 / (초월)겁화: 화상 DoT", "desc_ko": "명중 시 초월 게이지를 채운다. 초월 중에는 「겁화」로 발동 — 명중한 적에게 화상 지속딜을 남긴다.",
	},
	{
		"id": "BIND-026", "gear": "gear_ward_dps_press_rod",
		"identity_ab": "IDA-024", "slot_ab": "AB-003", "slot_index": 0, "theme": "overdrive", "delta": "overdrive_charge", "variant": "silence",
		"payoff": "Arc Bolt Volley → 초월 충전 / (초월)감전 폭주: 침묵", "desc_ko": "명중 시 초월 게이지를 채운다. 초월 중에는 「감전 폭주」로 발동 — 명중한 적을 침묵시켜 액티브 스킬을 봉쇄한다.",
	},
	{
		"id": "BIND-020", "gear": "gear_ward_dps_press_rod",
		"identity_ab": "IDA-024", "slot_ab": "AB-054", "slot_index": 1, "theme": "overdrive", "delta": "overdrive_charge", "variant": "gravity",
		"payoff": "절단 광선 → 초월 충전 / (초월)중력광선: 끌어당김", "desc_ko": "명중 시 초월 게이지를 채운다. 초월 중에는 「중력 광선」으로 발동 — 빔에 맞은 적을 중심선으로 끌어당긴다.",
	},
	{
		"id": "BIND-021", "gear": "gear_ward_dps_press_rod",
		"identity_ab": "IDA-024", "slot_ab": "AB-041", "slot_index": 2, "theme": "overdrive", "delta": "overdrive_charge", "variant": "freeze",
		"payoff": "빙결 파동 → 초월 충전 / (초월)절대영도: 빙결", "desc_ko": "명중 시 초월 게이지를 채운다. 초월 중에는 「절대영도」로 발동 — 감속이 빙결(속박)로 격상된다.",
	},
	{
		# AB-009 Oil은 명중이 없어 게이지 충전 기여는 없다(충전은 볼트/광역 딜 슬롯 몫) — 이 슬롯은 초월 소모 발현 전용.
		"id": "BIND-027", "gear": "gear_ward_dps_press_rod",
		"identity_ab": "IDA-024", "slot_ab": "AB-009", "slot_index": 0, "theme": "overdrive", "delta": "overdrive_charge", "variant": "safeslick",
		"payoff": "Spawn Oil Patch → (초월)아군 안심 기름: 아군 무해 + 청록 구분", "desc_ko": "초월 중에 깐 기름은 아군을 해치지 않는다 — 미끄럼도 점화 피해도 면제되고 청록빛으로 구분된다(직후 반응까지). 기름은 명중이 없어 게이지 충전은 다른 슬롯이 맡는다.",
	},
	# DPS arc_weave 「혈풍」 링크 서브(광역 3종): 시전당 HP 소모 + 명중 적 수 비례 회복(3기+ 이득). delta 공통 blood_soak.
	{
		"id": "BIND-022", "gear": "gear_ward_dps_weave_staff",
		"identity_ab": "IDA-027", "slot_ab": "AB-053", "slot_index": 0, "theme": "bloodgale", "delta": "blood_soak", "variant": "burst",
		"payoff": "작열 폭발 → 흡수 폭발(기본 회복)", "desc_ko": "체력을 대가로 시전하고, 광역으로 맞춘 적 수에 비례해 회복한다(3기 이상이면 이득).",
	},
	{
		"id": "BIND-023", "gear": "gear_ward_dps_weave_staff",
		"identity_ab": "IDA-027", "slot_ab": "AB-054", "slot_index": 1, "theme": "bloodgale", "delta": "blood_soak", "variant": "siphon",
		"payoff": "절단 광선 → 흡혈 광선(채널 사이펀·회복 증폭)", "desc_ko": "체력을 대가로 시전하는 흡혈 광선. 채널로 빨아들여 맞춘 적 수 대비 더 많이 회복한다(사이펀).",
	},
	{
		"id": "BIND-024", "gear": "gear_ward_dps_weave_staff",
		"identity_ab": "IDA-027", "slot_ab": "AB-041", "slot_index": 2, "theme": "bloodgale", "delta": "blood_soak", "variant": "iceblood",
		"payoff": "빙결 파동 → 혈빙(과회복 → 임시 보호막)", "desc_ko": "체력을 대가로 시전하고, 광역으로 맞춘 적 수에 비례해 회복한다. 최대 체력을 넘긴 과회복분은 임시 보호막이 된다.",
	},
	# DPS Venom Spit(AB-010, 스택 독 DoT) — 초월(맹독 폭주: 스택 즉시 폭증) / 혈풍(중독 적 비례 회복).
	{
		"id": "BIND-031", "gear": "gear_ward_dps_press_rod",
		"identity_ab": "IDA-024", "slot_ab": "AB-010", "slot_index": 0, "theme": "overdrive", "delta": "overdrive_charge", "variant": "venom",
		"payoff": "독 살포 → 초월 충전 / (초월)맹독 폭주: 독 스택 폭증", "desc_ko": "명중 시 초월 게이지를 채운다. 초월 중에는 「맹독 폭주」로 발동 — 명중한 적에게 독 스택을 한 번에 여러 겹 쌓아 지속딜을 폭증시킨다.",
	},
	{
		"id": "BIND-032", "gear": "gear_ward_dps_weave_staff",
		"identity_ab": "IDA-027", "slot_ab": "AB-010", "slot_index": 0, "theme": "bloodgale", "delta": "blood_soak", "variant": "burst",
		"payoff": "독 살포 → 흡수 폭발(기본 회복)", "desc_ko": "체력을 대가로 시전하고, 중독시킨 적 수에 비례해 회복한다(3기 이상이면 이득).",
	},
	# --- AB-007 이탈 결속(Nuker; 007a/007b 공통, slot 무관 = -1) ---
	{
		"id": "BIND-033", "gear": "gear_ward_nuker_ruin_sight",
		"identity_ab": "IDA-025", "slot_ab": "AB-007a", "slot_index": -1, "theme": "focus", "delta": "disengage_focus",
		"payoff": "이탈 마무리 → 대상 집중 +1", "desc_ko": "이탈의 마무리 한 방을 맞은 대상에게 집중을 1스택 누적한다(처형 준비).",
	},
	{
		"id": "BIND-034", "gear": "gear_ward_nuker_ruin_sight",
		"identity_ab": "IDA-025", "slot_ab": "AB-007b", "slot_index": -1, "theme": "focus", "delta": "disengage_focus",
		"payoff": "이탈 마무리 → 대상 집중 +1", "desc_ko": "이탈의 마무리 한 방을 맞은 대상에게 집중을 1스택 누적한다(처형 준비).",
	},
	{
		"id": "BIND-035", "gear": "gear_ward_nuker_flank_knife",
		"identity_ab": "IDA-029", "slot_ab": "AB-007a", "slot_index": -1, "theme": "flank", "delta": "disengage_veil",
		"payoff": "이탈 → 은신 유지 · 은신 첫 스킬 강타", "desc_ko": "이탈 후 은신을 유지한다(은신 중 평타 정지). 은신에서 쓰는 첫 스킬이 추가 피해 — 시전/은신해제 시 종료.",
	},
	{
		"id": "BIND-036", "gear": "gear_ward_nuker_flank_knife",
		"identity_ab": "IDA-029", "slot_ab": "AB-007b", "slot_index": -1, "theme": "flank", "delta": "disengage_veil",
		"payoff": "이탈 → 은신 유지 · 은신 첫 스킬 강타", "desc_ko": "이탈 후 은신을 유지한다(은신 중 평타 정지). 은신에서 쓰는 첫 스킬이 추가 피해 — 시전/은신해제 시 종료.",
	},
]

## resolveEffectiveAbility (F-020 §3.7) — active overlay for a member's slot, or {} (base only). 착용 즉시 활성.
static func resolve(base_gear_id: String, identity_ab: String, slot_ab: String, slot_index: int) -> Dictionary:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov["slot_ab"]) == slot_ab \
				and (int(ov["slot_index"]) == slot_index or int(ov["slot_index"]) == -1):   # -1 = 슬롯 무관(이탈 결속)
			return ov
	return {}


## **결속 해소 SSOT** — OVERLAYS 변주가 있으면 그것을, 없으면 정체성 **기본 델타**(GENERIC)를 돌려준다.
## 호출부는 전부 이쪽을 쓴다(`_apply_binding`·조준 사거리·툴팁). 기본 델타 결과에는 `generic: true`가
## 붙어, "저작 전(변주 미등록)"과 "등록 버그"를 호출부가 구분할 수 있다. ref: DRIFT-087.
static func resolve_effective(base_gear_id: String, identity_ab: String, slot_ab: String, slot_index: int) -> Dictionary:
	var ov: Dictionary = resolve(base_gear_id, identity_ab, slot_ab, slot_index)
	if not ov.is_empty():
		return ov
	var g: Dictionary = GENERIC.get(identity_ab, {})
	if g.is_empty():
		return {}
	var out: Dictionary = g.duplicate()
	out["id"] = "GEN-%s" % identity_ab
	out["generic"] = true
	return out


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


## 이 gear+identity가 「초월」 킷(DPS press_line)인가 — 명중으로 게이지 충전 + 초월 중 서브 강화 변형 게이트.
static func identity_overdrive(base_gear_id: String, identity_ab: String) -> bool:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov.get("theme", "")) == "overdrive":
			return true
	return false


## 이 gear+identity가 「혈풍」 킷(DPS arc_weave)인가 — 서브 시전당 HP 대가 + 명중 적 비례 회복 게이트.
static func identity_bloodgale(base_gear_id: String, identity_ab: String) -> bool:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab \
				and String(ov.get("theme", "")) == "bloodgale":
			return true
	return false


## 이 gear+identity가 결속 킷이면 그 정체성 규약({name, covenant})을, 아니면 {}. identity 툴팁용.
static func signature_for(base_gear_id: String, identity_ab: String) -> Dictionary:
	for ov in OVERLAYS:
		if String(ov["gear"]) == base_gear_id and String(ov["identity_ab"]) == identity_ab:
			return SIGNATURE.get(identity_ab, {})
	return {}

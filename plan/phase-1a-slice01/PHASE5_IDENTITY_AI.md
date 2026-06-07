# Phase 1a · 5단계 — Identity NC AI 진행 문서

> **상위:** [WORK_ORDER.md](./WORK_ORDER.md) 5단계 · spec pin `cd6009e` @ `staging`
> **목적:** 4역할 Identity(메인) 스킬을 NC 자동 사용으로 구현. 진행 로그 + 체크리스트.
> **갱신 규칙:** CP 완료마다 ① 체크박스 ② 진행 로그 1줄 ③ 현재상태/다음.

---

## 0. 목표 / 게이트
전투 중 비조작(NC)이 **Identity 스킬만으로** 행동 (서브/패시브 auto 없음 — 4.5 이미 적용). `T-ENC-NORM-001`(6단계) 진입 준비.

## 1. 스펙 근거 (pin cd6009e)
- ENC-NORM-001 `nonControlledAssumptions` + RP Role Intent
- AB-020/024/025/026 (어빌리티 수치), PT-010/020/021/022 (NC 자동 조건)
- F-005(NC AI 폴백), F-022(위협), QA-005 §2.10(`T-ENC-NORM-001`)
- **Evaluate(F-005):** Valid Use → PT when → cast. 실패 → §3.8 폴백(기본공격). 서브/대체 Identity 없음.

## 2. 4역할 사양 (데모 PH 수치 = spec Draft)

| 역할/ability | 쿨 | 조건(when) | 효과 | 이동/밴드 |
|---|---|---|---|---|
| **Tank** `tank_anchor_guard`/AB-020 | 6s | 5m내 교전적 1+ | 자기 Shield `80+20·n`(cap 160, 4s) + 적별 위협펄스 `+90`. **데미지0, 이동안함** | Frontline·Hold·Melee |
| **DPS** `dps_press_line`/AB-024 | 4s | 전방 콘(5m,60°) 내 적 1+ | 3타 sweep(0.25s 간격), 타당 `0.35×base`를 콘 내 **모든 적**에 | Skirmisher·Mid·Hold |
| **Nuker** `nuker_mark_ruin`/AB-025 | 5s | 8m LOS 내 적 1+ | 0.5s 표식 → `7.0×base` 단일타. 백라인 우선, fodder시 **최저HP**. 표식 중 대상 사망/이탈→실패(쿨 50%환급) | Flanker·Mid-Long |
| **Healer** `healer_mend_circle`/AB-026 | 7s | 4m내 아군 <85%max (또는 Tank<90%) | 반경4m 아군 각 **12%max** 힐(자힐 포함, overheal 없음) | Support·Rear·추격금지 |

`base` = party_member `basic_damage`. NC가 Identity 미사용 조건이면 기본공격 폴백.

## 3. 현재 코드와의 차이
- 지금: 전원 동일한 "최근접 적 기본공격" + 팔로워는 최근접 적으로 engage.
- 5단계: 역할별 Identity 자동 + (선택) 역할 밴드 이동(탱 전열/힐러 후열/누커 중장거리).
- **컨트롤 캐릭터:** 스펙상 Identity는 플레이어 입력(Q). Q 입력 미구현 → **데모에선 컨트롤 포함 전원 auto-identity**로 근사(역할 가시화). 나중에 컨트롤분만 Q 수동으로 분리.

## 4. 빌드 체크포인트

- [x] **CP1 — 데이터**: identities.json에 `identity` 블록(쿨·반경·수치) 추가. party_member가 `row.identity` 파싱. JSON 검증 통과. ✅
- [x] **CP2 — party_member 배관**: `shield`(흡수, take_damage에서 HP보다 먼저 소모, AB-020 정책) + `heal(amount)`(overheal 없음, 초록 플래시) + `identity_cooldown_s` + 실드 만료 틱(`_physics_process`). ✅ (실드 시각=CP4 보류)
- [x] **CP3 — Identity 디스패치**(combat_controller): 멤버별 identity 쿨 tick → `_try_identity` (class별 cast), else 기본공격 폴백. `[ID]` 로그. ✅
  - [x] CP3a Healer Mend Circle (4m 아군<85%/Tank<90% → 12%max 힐, 자힐 포함)
  - [x] CP3b Tank Anchor Guard (5m내 적 → 자기 shield, 위협=step7 로그만)
  - [x] CP3c DPS Press the Line (전방 콘 60°·5m, 3타 합산 AoE / v1)
  - [x] CP3d Nuker Mark & Ruin (8m내 최저HP 적에 7×base 단일타 / v1 텔레그래프 없음)
- [~] **CP4 — 폴리시**(진행 중):
  - [x] **스킬 VFX**(사용자 요청): 역할별 색+형태 구분. Tank=파란 돔+바닥펄스, DPS=청록 전방콘, Nuker=보라 빔+폭발(대상), Healer=초록 바닥펄스. 자동 페이드·정리 · `skill_vfx.gd` + combat_controller 연결.
  - [ ] 누커 0.5s 표식 텔레그래프·DPS 3타 순차·실드 지속 시각 + 역할 밴드 이동(탱 melee·DPS mid·누커 mid-long·힐러 후열 비추격).
- [ ] **CP5 — 스모크**: ENC-NORM-001에서 4역할이 각자 Identity 사용 로그/시각 확인(사용자 F5).

**4.5 (서브 차단) 유지:** Identity(메인)만 자동. sub/passive 호출 경로 없음.

---

## 5. 진행 로그 (append-only)

- 2026-06-07 · CP0 · 스펙 정독(ENC-NORM-001·AB·PT) 후 플랜 문서 작성 · `PHASE5_IDENTITY_AI.md`
- 2026-06-07 · CP1 · identities.json `identity` 블록 4역할 추가, party_member 파싱 · `identities.json`, `party_member.gd`
- 2026-06-07 · CP2 · party_member shield(흡수·만료틱)·heal·identity_cooldown 배관 · `party_member.gd`
- 2026-06-07 · CP3 · Identity 디스패치 + 4역할 cast(`_cast_anchor_guard/press_line/mark_ruin/mend_circle`) + 헬퍼(radius/cone/lowestHP/allies). 전원 auto-identity, 폴백 기본공격 · `combat_controller.gd`
- 2026-06-07 · CP3-fix · `_allies_in_radius`에서 `Node` 그룹멤버 `global_position` 타입추론 에러 → `a as Node3D` 캐스팅 · `combat_controller.gd`
- 2026-06-07 · CP4(VFX) · 스킬별 절차적 PH VFX(역할 색+형태 구분, 자동 페이드) · `skill_vfx.gd`, `combat_controller.gd`
- 2026-06-07 · 밸런스 · 적 HP 대폭↑(전투 관찰용), 힐러 30%/4s/5m로 보강 · `enemies.json`, `identities.json`
- 2026-06-07 · **적 어빌리티 + 데이터모델 리팩토링**(사용자 지시: 스킬 개별 정의·ID 링크·확장성): **통합 `abilities.json` 카탈로그**(AB-### → 효과/kind) 신설. 파티 identity는 `ability_id`로, 적은 `abilities[].ref`로 **링크**. identity 인라인 블록·enemies 인라인 카탈로그 제거. 디스패치를 class_id→**ability kind**로 변경. 적 행동 구현: EN-001 KB-LIGHT+3타 방패치기(넉백·`shield_bash` VFX), EN-011 원거리 투척(7.5m·`projectile` VFX); EN-010/012=단순 근접. `apply_knockback` 추가 · `abilities.json`(신규), `slice01_data.gd`(`get_ability`), `identities.json`, `enemies.json`, `enemy_unit.gd`, `party_member.gd`, `combat_controller.gd`, `skill_vfx.gd`
- 2026-06-07 · 조준형 서브: DPS Lunge·Nuker Nova를 **2단계 지면 조준**(서브키→마우스 클릭 위치 발동)으로. `targeted` 플래그, 바닥 조준 마커(AoE 반경), 좌클릭 발동/우클릭·Esc 취소 · `abilities.json`, `combat_controller.gd`(cast_sub target_pos), `dungeon_run.gd`
- 2026-06-07 · **서브 스킬**(사용자 지시 — 플레이어 능동 개입거리): 4역할 1개씩, **플레이어 전용·키 1**(조작 캐릭). NC 자동 없음(스펙 유지). Tank 도발슬램(넉백+어그로강제+실드)/DPS 돌진강타/Nuker 노바(광역+둔화)/Healer 성역(대힐+실드). `sub_ability_id` 링크, 적 슬로우(`apply_slow`), HUD 쿨표시. 밸런스 위해 적 HP/dmg 버프. ⚠️ **QA-030 Non-goal**("조작 서브")를 데모 재미 위해 의도적 확장 — slice 계약 밖. · `abilities.json`(AB-S01~S04), `identities.json`, `enemies.json`, `party_member.gd`, `enemy_unit.gd`, `combat_controller.gd`(`cast_sub`+4), `skill_vfx.gd`, `dungeon_run.*`, `project.godot`(key 1)

## 6. 현재 상태 / 다음 할 일
- **현재:** CP1~CP3 완료 — 4역할 Identity 자동 사용 동작(콘솔 `[ID]` 로그). 탱 실드, 힐러 힐(초록 플래시), DPS 콘 AoE, 누커 폭딜. **F5 검증 대기**.
- **검증(F5):** RM-ADV-01 전투 → 콘솔에 `[ID] tank_anchor_guard Anchor Guard`, `[ID] healer_mend_circle Mend Circle`, `[ID] dps_press_line Press the Line`, `[ID] nuker_mark_ruin Mark & Ruin` 4종이 쿨마다 뜨고, 적이 콘/폭딜로 빠르게 정리·아군 HP가 회복되는지.
- **다음:** CP4 폴리시(누커 표식 텔레그래프·실드 시각·역할 밴드 이동) 또는 밸런스 튜닝. 그 후 6단계(`T-ENC-NORM-001` PASS).
- **주의:** Identity로 파티가 세짐(밸런스 재조정 가능). 컨트롤 포함 auto는 데모 근사(나중 Q 수동 분리). 위협(F-022)·누커 텔레그래프는 미구현.

## 7. Spec 참조 (pin cd6009e)
| Artifact | Path (spec repo) |
|---|---|
| Encounter | `docs/combat/encounters/ENC-NORM-001.md` |
| Abilities | `docs/combat/abilities/AB-020·024·025·026` |
| Patterns | `docs/combat/patterns/PT-010·020·021·022` |
| NC AI | `docs/features/F-005...`; Threat `F-022` |
| Acceptance | `docs/qa/QA-005` §2.10 `T-ENC-NORM-001` |

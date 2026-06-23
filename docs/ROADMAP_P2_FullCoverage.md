# ROADMAP — Phase 2 Full Spec Coverage (게임 측 정본)

> **무엇:** 스펙 `ImplementationPhase_FullSpecCoverage.md`(목표 = 스펙에 정의된 ID 전부 구현)의 **게임 측 실행 로드맵**. 스펙은 P2-S3~S7을 "Planned/TBD"로만 둠 → 본 문서가 게임측 작업 정본. SSOT 아님(규칙은 각 F-###/콘텐츠).
> **핀:** spec `bc22c38` (main, 2026-06-22; 제3세력 Stalker Pack 전파 DEC-20260621-001). **갱신:** 스프린트 종료마다. 상세 근거: 4-에이전트 스코핑(2026-06-19).
>
> **진행(2026-06-23):** P2-S2-fin ✅ · P2-S3 Interaction ✅ · P2-S2-place ✅ · **P2-S4 Hub ✅** · **P2-S5a ✅ 진영전(F-028 core) + 제3세력 Stalker Pack**(EN-3RD-01~03·AB-100~106·ENC-3RD-001) · **P2-S6a Phase1 ✅ 제3세력 lootable 아군 효과 6종**(loot 루프). **추가(스프린트 외):** 기어 카탈로그 고도화(17기어·6정체성·6 ability effect·기어귀속 평타·평타 VFX 8종, DRIFT-056) · 메타세이브 B리팩터 I1–I4(SaveProfile·Backpack 오토로드·영속) · 인벤/금고 정리(재료 금고 일원화·스태시/금고 편집창·잡템 제거·버그 수정). **현재 위치 → 다음 = P2-S6a 잔여(파티 능력 풀 — 신규 AB-### 스펙 ID 필요) + 메타세이브 I5.**

---

## 1. 커버리지 스냅샷 (2026-06-19)

| 축 | 현재 | 비고 |
|----|------|------|
| **적 전투행동 (EN-001~014)** | ✅ 완료 | 기본타 rom_* 12/12 · 포지셔닝 7프로필 · 마퀴 시그니처 · Provoked · 채널 interrupt |
| **AB-### (전체)** | **15/84** | 적 kit 10/13(비-zone) · 적 zone 0/7 · 파티 풀 5/64 |
| **PT-### (적 패턴)** | ✅ 14/14 | 갭 없음 (PT-010/011/020~022는 플레이어/미사용) |
| **ENC-### (인카운터)** | **23/24** | NORM 3/3 · HARD 11/12(007=Extreme deferred) · MID/DEEP 1/1 · BOSS 1/1 · PAT 3/3 · AMB 2/2 · **3RD 1/1 ✅(S5a)** |
| **배치/resolve (F-006/LDG-SPAWN)** | ✅ 확률화 | placement Patrol/AmbushHold·dual-anchor 순차·torch lead · **가중 다중후보+runSeed resolve · 스폰 위치 산포**(DEC-20260620-002). 조합 제너레이터·창발 모디파이어 = S5 |
| **ZONE/반응 (F-021/F-027)** | ✅ keystone | 9매체 zone·event bus·resolver·Hit-RX 4축(Fire/Cold/Lightning/Physical)·연쇄 per-RX VFX · zone AB 7종 enemy+lootable. S3e spread만 보류 |
| **Hub (F-029)** | ✅ 시설 progression | 8시설 Tier·Quest/Haul 게이트·vault 파이프·UI-029 승급·디스크 영속·ENC haul 드롭표(HUB-COR-000)·QA-029 스모크. **효과 실연동 이연**: armory B/C(GEAR-COR-000)·분석/상점(F-009)·passive(F-020)·capacity 강제 — 해당 피처 구현 시 |
| **3세력 (F-028)** | ✅ S5a 코어 | 진영전(교차진영 타겟·N진영/혼합분대) + 제3세력 Stalker Pack(EN-3RD-01~03·AB-100~106·ENC-3RD-001·outcome Rooted/Pinned/Scented/Tethered/Bloodlust). **잔여=Encounter Variety 엔진(조합 제너레이터·창발 모디파이어)=S5b** |
| **기어/정체성 (F-008/D-019)** | ✅ 카탈로그 | 17 신규 기어·6 정체성·6 ability effect·기어귀속 평타·평타 VFX 8종 (DRIFT-056). 잔여=gear roll-table 이행(S6b)·ba 특수거동 |
| **메타세이브 (B리팩터)** | ◐ I1–I4 | SaveProfile 단일파일·Backpack 오토로드·낱개/장착서브/소비/장착기어 영속·재료 금고 일원화·스태시/금고 편집창. **잔여=I5(허브 완전 Backpack화·RunLoadout 잔여 제거)·충전수 영속** |

---

## 2. Critical Path (의존성)

```
[P2-S3 Interaction = F-021/F-027 zone·event·reaction]  ← KEYSTONE (최장 리드)
   ├─ zone ABs(AB-009/036/039/040/041/042/043) → EN-004/007 전투 완성
   ├─ 다수 party AB(zone-spawn·finisher)
   └─ F-028 3세력 causality(환경연쇄로 굴러감)
[P2-S4 Hub F-029] → economy(shop/analysis = hub 시설 의존) → 파티능력 풀 메타
[Haul] = Level + Run(F-007) + Hub 수직 슬라이스
독립 레인(keystone과 병렬): 조합 ENC · patrol/ambush placement · party effect-kind 기반
```

**키워드:** Interaction이 keystone(zone·다수 AB·3세력을 막음) · Hub가 economy 게이트 · effect-kind 기반은 일찍 병렬 착수 가능.

---

## 3. 스프린트 시퀀스 (스펙 P2-S3~S7 채택 + P2-S2 마감 + placement 레인)

| 스프린트 | 범위 | 의존 | 규모 | 병렬화 |
|---|---|---|:---:|---|
| **P2-S2-fin** ✅ | combat-pool 잔여 ENC (조합·증원·assassin·boss) | 없음 | S–M | ★ ENC별 독립 |
| **P2-S3** ✅ | 원소 ZONE/반응 (keystone) | — | L | 내부 부분 |
| **P2-S2-place** ✅ | patrol/ambush placement + 확률 resolve | placement plumbing | M | S3와 독립 병렬 |
| **P2-S4** ✅ | Hub/Meta (F-029) — 효과 일부 이연 | — (economy 게이트) | M–L | 시설별 부분 |
| **P2-S5a** ✅ | 진영전(F-028 core) + 제3세력 Stalker Pack(EN-3RD·AB-100~106·ENC-3RD-001) | S3 event | M | 완료 |
| **P2-S6a Phase1** ✅ | 제3세력 lootable 아군 효과 6종(loot 루프) | S5a | S | 완료 |
| **▶ P2-S6a 잔여** | 파티 능력 effect-kind ~11 + 데미지 sub ~24 — **다음(신규 AB-### 스펙 ID 필요)** | B1 기반·spec | L | effect-kind∥, sub 대량∥ |
| **P2-S5b** | Encounter Variety 엔진(조합 제너레이터·창발 모디파이어·런 내 비복원) + EN-* 정식 태그 | S5a · EN-* 태그 | M–L | 단독 |
| **P2-S6b** | economy/UI + gear roll-table | hub | M–L | UI∥데이터 |
| **P2-S7** | 통합 회귀/QA | 전부 | M | 케이스별∥ |

---

## 4. 스프린트별 배치 (스코핑 근거)

### P2-S2-fin — combat-pool 잔여 (신규 시스템 0~소)
- **A1 조합 ENC** (순수 JSON, 구현 enemy kit 사용): HARD-002/003/004/007. 단, 데모맵 reachability(pool/room) = 소규모 level 확장 동반.
- **A2 phase 증원**: HARD-005(신) + HARD-010 수정(EN-008 → phase-2 flank). `_tick_reinforcement` 시스템 기존(HARD-001 활용 중) — rear/flank 방향+텔레그래프 구분 추가.
- **A3 Assassin transform**: NORM-003 · HARD-011 — disguise→reveal+텔레그래프(0.6/0.4s)→backline execute. 신규 enemy state(소).
- **A4 Boss phase**: BOSS-001 — EN-002 MiniBoss 오버레이(ccTenacity 1.2·leash 28·attentionTier High) + HP 50% phase(AB-004 텔레 −0.15s). 신규 boss-overlay+phase hook(소-중).

### P2-S3 — Interaction (keystone, L) — 의존순 배치
- **S3a** 유닛 OUTCOME status셋 확장(party+enemy): Slippery·Sodden·Chilled·Shock(실)·Ignited·WindBuffeted. (적은 현재 slow/stun/kb만.)
- **S3b** zone 모델 업그레이드: `hazard_zone`에 `activeMedia[]`+`primaryMedium` + zone 프리셋 카탈로그(9매체) + RX-OIL-FIRE 이관(**Smoke vs ToxicGas 드리프트 수정 → OPS_30**).
- **S3c** event bus + EnterZone/ExitZone 엣지 감지(현 direct `fire_hit()` 호출 대체).
- **S3d** primaryMedium resolver(전역 우선순위 Oil>ToxicGas>Water>Fire>Steam>Smoke>Ice>Veg>Wind) + 데이터주도 RX 매트릭스 ~19(병렬 작성 가능).
- **S3e** spread 엔진 + room 캡(2/gust·6/room·2.0s).
- **S3f** zone AB 7종(enemy+lootable) → **EN-004(Oil+Slippery 최소)·EN-007(가장 무거움: Water/Ice/Veg/Hex+RX) 완성**.

### P2-S2-place — patrol/ambush + 확률 resolve ✅ (완료 2026-06-21)
- ✅ placement_behavior(Fixed/Patrol/AmbushHold) — Patrol=spawn home 자동 루프, AmbushHold=근접 reveal+hold(facing 무시)+스프링 먼지 VFX. AMB-002 듀얼 앵커 순차 기상(14m·anchor 게이트). PAT-003 EN-010 torch(데이터 구동). ENC-PAT/AMB 5종.
- ✅ **확률적 ENC resolve**(가중 다중후보+runSeed) + **스폰 위치 시드 산포**(navmesh 스냅). 스펙 `LDG-SPAWN-DEMO-001` §2/§3/§5 전파(DEC-20260620-002)→재핀 `ef9c0c7`. forceEncounter QA핀 유지.
- **확장 운영(지금~)**: ① 기존 ENC에 placement 변형 후보 추가 ② **기존 EN-* 재조합으로 새 ENC**(mechanicAxes≤2) ③ 풀 후보 폭 절제 확대 — 모두 데이터만. EN-* 다듬을 때 **태그 동반**(S5 제너레이터 연료). 상세 = [design/encounter_variety_architecture.md](design/encounter_variety_architecture.md).
- **이연→S5**: 런 내 비복원 · 조합 제너레이터 · 창발 모디파이어.

### P2-S4 — Hub/Meta (F-029) ✅ (완료 2026-06-21, IMPL-DEC-20260621-001~006)
- ✅ **B0** 데이터(facilities_tiers·quests·haul_materials)+HubProfile(승급 게이트 D-029 §5). **B1** haul vault 파이프(At-Risk→탈출→vault, run_end). **B2/B3** UI-029 시설 패널(승급·재료 ± 인라인). **B6** 디스크 영속(HubProfile·Stash, user://). **B7** ENC haul 드롭표(HUB-COR-000, 분대 클리어 롤). **B8** QA-029 스모크(ci_smoke 편입).
- ✅ **B4-lite/부분**: 충족가능 퀘스트 자동완료(vault·시설Tier) + Q-HUB-020(ENC-HARD-001 클리어, squad_cleared 훅).
- **이연(의존성)**: B5 효과 실연동 — armory B/C(GEAR-COR-000 미존재)·분석/상점(F-009)·passive(F-020)·capacity 강제(friction+백팩40 vs 12~16 불일치). B4 잔여 — Q-HUB-003(데모 맵 1개)·010(GIMMICK)·040(recovery D6)·050(NPC) 시스템 미존재. 승급 *메커니즘*은 동작, *효과/잔여 퀘스트*는 해당 피처 스프린트 소관.
- **스펙**: F-029/D-029/HUB-COR-000 구현 + draft 데모 데이터 확장(haul_drops). 규칙 변경 없음 → **전파 불필요**.

### P2-S6a — 파티 능력 풀 (L)
- **B1** 신규 effect kind ~11: buff/DR-aura · ally-shield · HoT · silence · vulnerable/mark-debuff · self-dash/blink · ally-relocate · enemy knockback/pull · channel-beam · cleanse/strip · **+status-read finisher 게이트**(Stunned/Asleep/Vulnerable 소비 보너스).
- **B2** 데미지 sub ~24(기존 strike/fire/stun 재사용 = 데이터행 대량 병렬).
- **6 Identity 후보**(AB-021/022/052·027·029·031) — gear-roll-table(S6b)와 함께.

### P2-S5 — 3세력 (F-028) + Encounter Variety 엔진 (M–L) — S3 event 후
- **3세력:** faction-tagged 적대(player+monster 양쪽) · offscreen `active_and_adjacent` 시뮬 · ENC-3RD-001. (스펙 stub — EN/OBJ-3RD 확정 후.)
- **Encounter Variety 엔진**(3세력과 동시 — 둘이 같이 값을 함): 조합 제너레이터(그룹 레시피 + mechanicAxes 예산 + seed → EN-* 조합 생성, ENC-000 가드레일) · **3세력 = 창발 런타임 모디파이어**(교전중/정리/약화/증원) · 런 내 비복원 · 하이브리드(보스·QA핀 authored). 빌드 직전 ENC-000/F-006/F-028 **스펙 전파→재핀**. 설계 = [design/encounter_variety_architecture.md](design/encounter_variety_architecture.md) · `IMPL-DEC-20260620-014`.
- **선결:** EN-* 정식 킷 + 태그(role·tier·mechanic_axis_kind·faction·placement_affinity).

### P2-S6b — economy/UI + gear roll-table
- 분석진척·shop·affix(hub 의존) + **gear `identityRollTable` 이행**(현 1:1 `bundled_identity_skill_id` = 레거시 핀; F-008 §3.7) + 21 gear 아키타입 + UI 폴리시(shop/analysis·HUD 확장·핑).

### P2-S7 — 통합/QA
- QA-005 13+케이스 · QA-021 19 interaction · QA-029 hub · 헤드리스→F5 자동화 · QA-031 마감 · 역전파 배치.

---

## 5. 병렬화 & 서브에이전트 전략
- **데이터 대량(조합 ENC·데미지 sub·RX 정의)** → 스펙 doc→JSON/데이터 **드래프트를 서브에이전트 병렬**, 통합(파일쓰기·id_registry·spawn)은 **중앙(충돌 방지)**.
- **공유 코드(enemy_ai·party_member·dispatch)** → 직렬(병렬 worktree는 충돌). effect-kind 스크립트는 파일 독립이라 병렬 가능.
- **읽기 스코핑** → 서브에이전트 병렬(본 로드맵이 그 산물).

## 6. 게이트 결정 (별도 승인)
- **gear roll-table 이행**(F-008 §3.7): loot/extraction 메타 리팩터 → [[refactor-risk-preference]] clean-first·고위험 이연 원칙. S6b에서 단독 결정.
- **드리프트 전파**: RX-OIL-FIRE Smoke 수정 등 규칙 편차는 S3 착수 시 OPS_30 묶음.

## 7. 제외 (스펙 명시 deferred만)
- `I-###` 아이디어 · `Deprecated` 헤더 · 명시 폐기 ID(예 `RX-POISONED-STEAM-ENTER-001`).
- 이연: Recovery 재방문(DRIFT-031) · ENC Extreme 프로필 · Tank-sub 수동입력 · Locked 승격.
- 튜닝수치(SPEC_DRIFT 로깅) · Forward+/web-export(impl-only).

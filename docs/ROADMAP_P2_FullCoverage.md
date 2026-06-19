# ROADMAP — Phase 2 Full Spec Coverage (게임 측 정본)

> **무엇:** 스펙 `ImplementationPhase_FullSpecCoverage.md`(목표 = 스펙에 정의된 ID 전부 구현)의 **게임 측 실행 로드맵**. 스펙은 P2-S3~S7을 "Planned/TBD"로만 둠 → 본 문서가 게임측 작업 정본. SSOT 아님(규칙은 각 F-###/콘텐츠).
> **핀:** spec `4422e50` (staging). **갱신:** 스프린트 종료마다. 상세 근거: 4-에이전트 스코핑(2026-06-19).

---

## 1. 커버리지 스냅샷 (2026-06-19)

| 축 | 현재 | 비고 |
|----|------|------|
| **적 전투행동 (EN-001~014)** | ✅ 완료 | 기본타 rom_* 12/12 · 포지셔닝 7프로필 · 마퀴 시그니처 · Provoked · 채널 interrupt |
| **AB-### (전체)** | **15/84** | 적 kit 10/13(비-zone) · 적 zone 0/7 · 파티 풀 5/64 |
| **PT-### (적 패턴)** | ✅ 14/14 | 갭 없음 (PT-010/011/020~022는 플레이어/미사용) |
| **ENC-### (인카운터)** | **17/24** | NORM 3/3(003 assassin) · HARD 11/12(002/003/004/005·010 phase·011 assassin; 007=Extreme deferred) · MID/DEEP/BOSS 1/1(BOSS 스텁) · PAT 0/3 · AMB 0/2 · 3RD 0/1 |
| **ZONE/반응 (F-021/F-027)** | RX 1/~19 | RX-OIL-FIRE만 (Smoke 드리프트) · zone 1/9 · element status 0 |
| **Hub (F-029)** | 배치화면만 | 8시설·퀘스트/haul 게이트·vault·UI-029 미구현 |
| **3세력 (F-028)** | 0 | event 시스템 의존 |

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
| **P2-S2-fin** | combat-pool 잔여 ENC (조합·증원·assassin·boss) | 없음 | S–M | ★ ENC별 독립 |
| **P2-S3** | 원소 ZONE/반응 (keystone) | — | L | 내부 부분 |
| **P2-S2-place** | patrol/ambush placement | placement plumbing | M | S3와 독립 병렬 |
| **P2-S4** | Hub/Meta (F-029) | — (economy 게이트) | M–L | 시설별 부분 |
| **P2-S6a** | 파티 능력 effect-kind + sub 풀 | B1 기반 | L | effect-kind∥, 데미지 sub 대량∥ |
| **P2-S5** | 3세력 (F-028) | S3 event | M | 단독 |
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

### P2-S2-place — patrol/ambush (M, S3와 병렬)
- placement 컬럼 소비(resolver+prespawn) + patrol 웨이포인트 AI(`_tick_roam` 확장). PAT-003은 **torch carry/throw 기존 재사용**(EN-010 lead 플래그 + 경로 ENT-TORCH).
- AMB: dormant-reveal 트리거 + AMB-002 순차 wake(`ambushAnchorCount:2`).

### P2-S4 — Hub/Meta (F-029, M–L)
- 8시설 티어(barracks/stash/scriptorium/scribe_shop/armory/quartermaster/smithy/chapel) + Quest/Haul 게이트 + `hubHaulVault`(Safe) + haul drop→extract→vault 파이프 + D-029 schema + UI-029 맵.

### P2-S6a — 파티 능력 풀 (L)
- **B1** 신규 effect kind ~11: buff/DR-aura · ally-shield · HoT · silence · vulnerable/mark-debuff · self-dash/blink · ally-relocate · enemy knockback/pull · channel-beam · cleanse/strip · **+status-read finisher 게이트**(Stunned/Asleep/Vulnerable 소비 보너스).
- **B2** 데미지 sub ~24(기존 strike/fire/stun 재사용 = 데이터행 대량 병렬).
- **6 Identity 후보**(AB-021/022/052·027·029·031) — gear-roll-table(S6b)와 함께.

### P2-S5 — 3세력 (F-028, M) — S3 event 후
- faction-tagged 적대(player+monster 양쪽 적대) · offscreen `active_and_adjacent` 시뮬 · ENC-3RD-001. (스펙 자체 stub — EN/OBJ-3RD 확정 후.)

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

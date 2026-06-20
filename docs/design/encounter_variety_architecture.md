# Encounter Variety Architecture — 목표 설계 (target)

> **STATUS: 설계 target (미구현).** 현재 동작 = 가중+시드 resolve(`DEC-20260620-002`) + placement 변주 + 큐레이션 24 ENC. **빌드는 P2-S5(제3세력)와 함께** — 아래 §빌드 시퀀싱. 이 문서는 그때 채울 골격 + 스펙 전파 예약.

## 1. 원칙 (사례조사 결론)
반복 탐험의 지루함은 **콘텐츠를 늘려서가 아니라 고정 자산 위의 "레이어"로** 해결한다 (Tarkov·Arc Raiders·Dark and Darker·RoR2·D3·PoE·Hades·L4D 공통). 작은 로스터에서 변주/제작비 비율이 가장 높은 기법 = ① affix/modifier(공유 base에 행동 모듈) ② 크레딧 예산형 스포너 ③ set-piece 확률.

**우리 핵심 통찰:** 원자 콘텐츠는 ENC가 아니라 **EN-* + 구성 규칙(ENC-000)**. ENC는 그 조합 공간의 *큐레이션된 점*일 뿐 → **EN-* 하나 추가 = ENC 공간 곱연산 확장.** 스펙이 이미 ENC를 레시피로 모델링: `ENC-000 §2 mechanicAxes = eliteCount + specialistArchetypeKinds`(cap ≤2), `fodderTrashCount`/`fodderVariantMix`/역할 패밀리/`compositionDownshift`.

## 2. Resolution 파이프라인 (분리·조합 가능한 축)
```
Room(Site) → Group(레시피) → Scale(예산) → [generate | set-piece] → Modifiers(authored + 창발) → Pick(seed, 비복원)
```

## 3. 스키마 (필드 · 현재 · 목표 · 스펙 소유)
| 축 / 필드 | 의미 | 지금 | 목표 | 스펙 소유 |
|---|---|---|---|---|
| **EN-\* 태그** | role·tier·mechanic_axis_kind·faction·placement_affinity | role/pattern/abilities 있음; EN-002/003/004/007/008/009 stub | 제너레이터가 소비할 정식 태그 셋 | `EN-COR-000`/`EN-AI-000`, tier=`D-013` |
| **Group(레시피)** | "어떤 종류 전투" = 역할/티어 믹스 + fodderVariantMix + placement/지각 affinity + mechanicAxes 목표 | 암묵(PAT/AMB/NORM 흩뿌림) | named recipe(ENC-000 역할 패밀리 = proto-그룹) | `ENC-000` (신규 group 개념 = 확장) |
| **Scale(예산)** | (difficulty, depth)별 mechanicAxes cap·group_size·tier 상한 = 생성기가 쓰는 크레딧 | difficulty×layer→ENC 1:1 | 예산형 스포너(RoR2 디렉터 패턴) | `ENC-000 §2`, `F-006 §3.1.2`, `F-024`(인지부하) |
| **Resolve** | 그룹+예산+seed로 EN-* 조합 *생성*, 또는 authored set-piece(보스·QA핀) 사용 | authored ENC만 | 하이브리드(set-piece authored + 슬롯 생성) | `LDG-SPAWN`(resolve)·`ENC-000`(validity) |
| **Modifiers** | 같은 전투에 비틀기 — ①authored affix[](reinforced·elite-led·hazard·야간) ②**창발 런타임 주입** | placementBehavior 3종(첫 modifier) | affix는 stub, 창발이 메인 | `F-028`(제3세력)·`F-006`(hazard/event)·`ENC-000`(affix↔mechanicAxes 정합) |
| **Pick** | 구체 1개, 중복 없이 | run_seed 가중 | + 런 단위 **비복원** | `LDG-SPAWN §2` |

## 4. 제3세력 = 창발 모디파이어 (authored affix 대체 아님, 보완)
`F-028 ThirdFaction_OffscreenDungeonEvents`/`ENC-3RD-001` — 3세력이 자기 전투를 수행하면 입장 시 *교전 중/정리됨/약화/증원* 상태로 **같은 ENC가 변조**됨 (Tarkov "다른 플레이어=변주 엔진"과 동형). → authored affix 테이블에 과투자 불필요; Modifiers 축에 **런타임 주입 슬롯**만 열어두면 F-028이 유기적으로 채움.

## 5. 제약 (그래서 지금 빌드 아님)
1. 생성기는 **ENC-000 가드레일 필수**(mechanicAxes≤2·역할 캡·F-024) — 안 지키면 손맛이 authored보다 *나빠짐*. → **하이브리드**(보스·QA핀 authored, 랜덤 슬롯만 생성)가 안전, full-gen 아님.
2. **EN-* 성숙 선행** — stub(EN-002/003/004/007/008/009)을 정식 킷+태그로.
3. **스펙 표면 큼**(ENC-000/F-006/F-028) — 가중 resolve보다 큰 변경.

## 6. 빌드 시퀀싱
- **지금:** 이 스키마 확정(본 문서) + EN-* 정식 킷 다듬을 때 §3 태그 채움. 인터림(가중 resolve+placement+큐레이션) 유지.
- **P2-S5(제3세력)와 함께:** 조합 제너레이터 + 창발 모디파이어 동시 빌드(둘이 같이 있어야 서로 값을 함). 빌드 시점에 ENC-000/F-006/F-028 **스펙 전파(OPS_30)→재핀**.
- **스펙 전파 예약:** group=recipe·mechanicAxes-budget 생성·modifier 주입 훅 — S5 빌드 직전 SSOT 편집 + OPS_30.

## 7. 근거
사례조사 digest(2026-06-20) · 가중 resolve 결정 `DEC-20260620-002` · 본 설계 `IMPL-DEC-20260620-014`.

# 전파 패킷 — 맵 고도화 Phase 1 (위상·공간 문법·앵커)

> **용도:** spec repo(`project_tdc` @`staging`)에서 `OPS_30`(impact_scan → 매퍼×4 → DecisionLog `DEC-` → TODO → SpecScopeTracker) → `OPS_20`(lint) → PR로 집행할 **역전파 목록**.
> **이 레포는 spec md를 직접 편집하지 않는다**(AGENTS.md §Spec drift). 집행 후 [`spec_ref.json`](../spec_ref.json) 핀 bump가 이 레포의 유일한 spec-관련 쓰기.
> 🕒 **초안 — 미집행.** **판정 2건 접수(2026-08-24): §B = 옵션 2 · §F = 실제 지역명 선반영.** 반영해 아래를 갱신했다.
>
> **패킷 작성:** 2026-08-24 · **근거:** [map_upgrade_plan.html](design/map_upgrade_plan.html) Phase 1 · [map_demo_001_status.html](design/map_demo_001_status.html) 실측 · DRIFT-162~166(Phase 0 완료)
> **선행 상태:** Phase 0 종료 — 맵 계약·계측기·앵커 데이터화 완료. **Phase 1은 첫 단계에서 스펙이 먼저 움직여야 한다.**

---

## 0. 한눈에

| # | 항목 | 분류 | 대상 문서 | 근거(실측) |
|---|---|---|---|---|
| **A** | `routeClass` — 방이 어느 탈출로에 속하는가 | schema | `LDG-001` §8 · `DBP-DEFAULT-001` §3 · `F-006` §3.10.1 | 경로 개념이 없어 전투 예산이 **전역 4~5** |
| **B** | **난이도 축을 방·경로가 소유한다**(옵션 2 채택) | **rule** ⚠ DecisionLog 필수 | `F-006` §3.1.2 · §3.10.1 · `D-015` · `DBP-DEFAULT-001` · `LDG-SPAWN-DEMO-001` | 도달 가능 ENC **12/24** — Hard 20행 + 12파일 사문화 |
| **C** | `spatialGrammar` — 방의 전투 공간 문법 | schema | `LDG-001` §8 · `F-026` §3 | 장애물 보유 **2/16방** · 동일 규격 방 8개 |
| **D** | `encounterAnchor.category` — 공간 역할이 **스폰 여부**를 정한다 | rule/schema | `F-006` §3.2 · `LDG-001` §8 · `DBP-DEFAULT-001` §4 | 진행 게이트가 **32 % / 40 %** 확률 |
| **E** | `lootAnchor.tier` — 위험과 보상의 결합 | schema | `LDG-001` §8 (`HUB-COR-000` 참조) | 상자 **18.4** vs 전투 **4.5** (4:1) |
| **F** | 신규 ID + **Upper 지역 어휘 신설** | scope/ID | `LevelDesignMap.md` · 신규 `DBP-###` · `LAY-UPPER` | 방 9 · 탈출 2 · **ID 충돌**(아래) |

> **튜닝 수치는 이 패킷에 없다** — 상자 EV 밴드(16~20)·장애물 좌표·전투 예산 수치는 전파 금지(로깅만, AGENTS.md §Spec drift).
> **게임 소유라 전파하지 않는 것:** 맵 계약(MapSource) · Blender 노드 규약 · 오클루더 콜라이더 유도 · Concave 제외 · 안개 크기 예산 · 도면 방향. 전부 DRIFT-162~166에 로깅됨.

---

## 1. 필드·enum 신설 — `LDG-001` §8 표 확장

`LDG-001` §8은 이미 Room/Pool 최소 필드표(`lightingProfile`·`placementBehavior`·`patrolGraphRef`·`ambushAnchorRefs[]`·`farmingOnly`)를 갖고 있다. **같은 표에 4행을 추가**하는 형태를 제안한다.

| field | owner | 값 | 비고 |
|-------|-------|-----|------|
| `routeClass[]` | RM | `route_early` \| `route_mid` \| `route_deep` | §A |
| `spatialGrammar[]` | RM | `open` \| `choke` \| `los_broken` \| `split` \| `flank` \| `backline_pocket` | §C |
| `encounterAnchor.category` | RM / Pool slot | `mandatory_threat` \| `gated_elite` \| `optional_threat` \| `patrol_route` \| `ambush_candidate` \| `third_faction_candidate` \| `safe` | §D |
| `lootAnchor.tier` | RM | `safe` \| `contested` \| `gated` | §E |

---

### A. `routeClass` — 방이 어느 탈출로에 속하는가 (schema)

**스펙에 이미 있는 것:** `F-006` §3.10.1이 탈출로 아키타입 3종(`route_early` / `route_mid` / `route_deep`)과 **경로별 교전 수**(1~2 / 3~4 / 4~5)를 정의한다. `DBP-DEFAULT-001`은 `extractionRouteRef`를 갖는다.

**없는 것:** **방이 어느 경로에 속하는지 표기하는 필드.** 그래서 「이 런의 경로가 무엇인가」를 런타임이 알 수 없고, 게임은 전투 예산을 **전역 4~5**로 눌러 놓았다(경로 개념 없음).

**제안:** Room 레벨 `routeClass[]`(복수 — 한 방이 여러 경로에 속할 수 있다). `DBP` 인스턴스는 `extractionRoutes[]`와 방 태그가 정합해야 한다.

**실측:** 현 맵은 탈출 지점 1개·경로 1개. 임계 경로 기대 전투 **1.02회**(런 4.5 중), 남쪽 사슬이 전투 가중치의 **35 %**를 갖는데 임계 경로가 지나지도 않는다.

---

### B. **난이도 축을 방·경로가 소유한다** — 옵션 2 채택 ⚠ `rule`

**결정(2026-08-24):** 옵션 2. `difficultyProfile`을 방·경로가 오버라이드한다.
초안 판단은 옵션 1이었으나 기획 판정으로 옵션 2로 간다 — **M6 판정(「어려운 관문은 맵의 방이 소유한다」)을
가장 직접 표현하는 형태**이고, 티어라는 중간 어휘를 하나 더 만들지 않는다.

**문제(실측):** 도달 가능 ENC **12/24**. 난이도 선택 UI가 M6에서 폐기돼 `RunLoadout.difficulty`가 항상 빈 문자열
→ manifest 기본값 `Normal` 고정 → spawn_table의 **Hard 20행 + `ENC-HARD-*` 12파일이 영영 안 나온다.**

**충돌하는 조문 — `F-006` §3.1.2:**

> `Normal`, `Hard`, `Extreme` 등은 **던전 시작 전** 플레이어가 고르는 **난이도 프로필**이다.
> - **한 런 안에서** `Normal` 구역을 지나 `Hard` 구역으로 "진행"하지 **않는다**.

이 조문의 전제(**런 전 플레이어 선택**)가 M6에서 사라졌다. 선택 UI가 없는데 「선택한 프로필은 런 내내 불변」만
남아 있어, **존재하지 않는 메커니즘을 지키느라 콘텐츠 절반이 잠긴** 상태다.

#### ⚠ 영향 범위 실측 — `difficultyProfile` 참조 **41개 파일**

무제한으로 손대면 패킷이 터진다. **가장 좁은 형태**로 집행할 것을 제안한다.

| 대상 | 처리 | 사유 |
|---|---|---|
| `F-006` §3.1.2 | **본문 교체**(아래) | 여기가 규칙의 정본 |
| `F-006` §3.10.1 | 한 줄 추가 — 경로 아키타입이 프로필을 공급 | §A와 짝 |
| `LDG-001` §8 | `difficultyProfile` 행 추가(RM/Pool 오버라이드) | 필드 등록 |
| `DBP-DEFAULT-001` §3 | 템플릿 주석 — 런 기본값 + 방/경로 override | 양식 |
| `LDG-SPAWN-DEMO-001` | resolve 키 표기 정정 | 실사용 |
| `D-015` ExtractionRunState | **`difficultyProfile` 필드의 의미를 「런 기본값」으로 명시** | 아래 |
| **`ENC-*` 21개 파일** | **건드리지 않는다** | 아래 |

**① `D-015`가 이유 있는 부작용이다.** 런 상태가 `difficultyProfile`을 **하나** 들고 있는데, 방마다 다를 수 있게
되면 그 값이 무엇을 뜻하는지 모호해진다. → 필드를 **「런 기본값(방/경로 override의 폴백)」**으로 재정의만 하고
스키마는 그대로 둔다. 삭제하면 조기 탈출·정산·QA 계약이 같이 흔들린다.

**② ENC 21개 파일은 손대지 않는다.** 헤더의 `difficultyProfile: Hard`는 **「이 ENC는 Hard 규모다」**로 이미
기능하고 있다 — 누가 그 값을 정하느냐만 바뀌지, ENC 자신의 의미는 그대로다. 21파일을 여는 순간 패킷이
검수 불가능해지고, 얻는 것이 없다.

#### 제안 본문 — `F-006` §3.1.2 교체안 (초안)

> #### 3.1.2 Difficulty profile (공간이 소유 — NOT run phases)
> `Normal`, `Hard`, `Extreme` 등은 **공간이 소유하는 난이도 프로필**이다.
> - **런 기본값**은 `Run Contract`가 정한다(`D-015` `difficultyProfile` = 폴백).
> - **`Room`/`extractionRoute`가 이를 오버라이드한다.** 한 런 안에서 `Normal` 구역을 지나 `Hard` 구역으로
>   **진행할 수 있다** — 어려운 관문은 **토글이 아니라 맵의 방**이 소유한다.
> - 오버라이드는 **경로 선택으로 노출**되어야 한다(`F-006` §3.10 — 보스 격파는 탈출 전제가 아니다).
>   플레이어가 모르고 밟는 난이도 상승은 금지한다: 진입 전 **전조**(조명·`zoneAmbientTier`·문/관문 연출)를 둔다.
> - 인지 부하 상한(`F-024`)은 **오버라이드 후 값**으로 검증한다.
>
> **폐기:** 「한 런 안에서 Normal 구역 → Hard 구역으로 진행하지 않는다」(M6에서 난이도 선택 UI가 사라져
> 전제가 소멸). 이력은 §3.1.6 Legacy note에 남긴다.
>
> **resolve 순서(개정)**
> 1) `Run Contract`의 런 기본 `difficultyProfile` 확정
> 2) 인스턴스 생성 시 **방·경로 오버라이드** 적용 → 그 방의 유효 프로필 확정
> 3) Pool의 규모/티어 참조 + 유효 프로필로 `docs/combat/` 테이블에서 `ENC-###` resolve
> 4) `F-024` 인지 부하·Hazard 밀도 가이드 만족 검증

**동반 요구(추가 제안):** 위 「전조」 조항이 없으면 이 변경은 **「모르고 밟는 난장판」**이 된다.
`F-006` §3.2.3(의도치 않은 전투 개시 완화)과 같은 성격의 방어선이므로 같이 넣는 것을 권한다.

#### DecisionLog 초안 (`rule` 변경이므로 필수)

```
- id: DEC-YYYYMMDD-###
- title: 난이도 프로필을 공간이 소유한다 (런 전 토글 폐기의 완결)
- context: M6에서 난이도 선택 UI 폐기 → RunLoadout.difficulty 공백 → Normal 고정.
  Hard 20행 + ENC-HARD-* 12파일이 도달 불가(12/24). LDG-SPAWN-DEMO-001 _note_boss가
  이미 「어려운 관문은 맵의 방이 소유한다」고 적었으나 표현할 필드가 없었다.
- decision: difficultyProfile을 Room/extractionRoute가 오버라이드한다. 런 기본값은
  Run Contract가 갖고 D-015가 폴백으로 보유. F-006 §3.1.2의 「한 런 안에서 진행 금지」 폐기.
- rejected: (옵션 1) encounterScaleRef 티어 축 신설 — 규칙 변경은 피하지만 난이도와
  거의 같은 뜻의 어휘를 하나 더 만든다. M6 판정의 직접 표현이 아니다.
- guardrail: 오버라이드는 경로 선택으로 노출 + 진입 전 전조 필수. F-024 인지 상한은
  오버라이드 후 값으로 검증.
- impact_scope: [F-006, F-024, D-015, LDG-001, DBP-DEFAULT-001, LDG-SPAWN-DEMO-001, F-010]
```

**미판정:** `F-010` 배치 단계의 난이도 선택 UI 언급(§3.1.2가 참조) 처리 — ⓐ 문구 삭제 / ⓑ 「지역·입장 조건이 대체」로 갱신.

---

### C. `spatialGrammar` — 방의 전투 공간 문법 (schema)

**스펙 현황:** 공간 문법 어휘가 **없다**(`docs` 전수 grep 0건). 방을 구별하는 축이 `RM-###` ID뿐이라 「어떤 전투가 벌어지는 공간인가」가 문서에 안 남는다.

**실측:** 장애물 정의가 있는 방이 **16개 중 2개**. 나머지 14방은 시야 차단·엄폐·내비 우회가 **전무**. Upper 13방 중 8방이 치수·조명·형태가 완전히 동일(27 × 22.5 m).

**제안:** Room `spatialGrammar[]` — `open` / `choke` / `los_broken` / `split` / `flank` / `backline_pocket`. 방 하나에 **1~2개만** 쓴다(겹칠수록 읽기가 어려워진다).

**동반 규약 제안:** `F-026` §3(Feature vs LevelContent 역할 분리)에 한 줄 — *「공간 문법은 게임플레이 어휘이고, 지역 테마(병영·수문·기록원·제련소)는 그 문법의 표현이다. 역순으로 설계하지 않는다.」*

**게임 측 부수 요구(전파 아님, 구현 백로그):** 원거리 적(`standoff`)이 LOS를 잃었을 때 **회복 위치로 재배치**하는 거동. 지금은 사거리까지만 좁히고 LOS를 되찾으려 하지 않아서, 기둥을 넣으면 **플레이어만 이득을 본다**. 그리고 `aggro_wake_buffer_m`(`F-006` §3.2.3, 4.0 m)가 **코드에 없다** — 초크 뒤 즉시 어그로는 스펙이 이미 금지한 배치인데 문법을 넣는 순간 그 배치가 쉬워진다.

---

### D. `encounterAnchor.category` — 공간 역할이 **스폰 여부**를 정한다 (rule/schema)

**스펙 현황:** `F-006` §3.2.4가 `placementBehavior` 3종(`Fixed`/`Patrol`/`AmbushHold`)을 정의한다. 그런데 이건 **배치 거동**이고, **「이 방에 전투가 존재하는가」를 정하는 축은 없다.**

**실측(충돌):** 허브 진행 게이트 2개가 확률에 걸려 있다 — 무기고 T1(`ENC-BOSS-001` 처치)은 **32 %**, 대장간 T3(`ENC-DEEP-001` 처치)는 **40 %**로만 생성된다. 게다가 그 방에 도달하려면 임계 경로를 벗어나 왕복해야 한다. 「어려운 관문은 맵의 방이 소유한다」는 설계 의도와 가중 추첨이 서로를 갉아먹는다.

**제안:** Room/Pool `encounterAnchor.category` 7종. **카테고리가 스폰 여부를**, 그 안에서 **spawn table이 구체 편성을** 정한다.

| category | 스폰 | 의미 |
|---|---|---|
| `mandatory_threat` | 100 % | 임계 경로의 필수 교전 |
| `gated_elite` | 100 % | **진행 게이트** — 추첨에서 제외 |
| `optional_threat` | 가중 | 보상 루트 |
| `patrol_route` | 경로 | `patrolGraphRef` 순회 |
| `ambush_candidate` | 가중 | `AmbushHold` 후보 |
| `third_faction_candidate` | 확률 | `F-028` exit 수렴 |
| `safe` | 0 % | 진입·조기 탈출 |

**핵심 구분(문서에 명시 제안):** **「반드시 존재」이지 「반드시 싸움」이 아니다.** 관문은 경로 선택으로 남고, 랜덤성은 그 전투의 **구체적 형태**에 둔다. `F-006` §3.10(보스 격파는 탈출 전제가 아니다)과 정합.

**연동:** `F-028` `thirdFaction.exitConvergenceRouteRef → route_deep`이 이미 스펙에 있는데 게임은 **랜덤 전투방에 코드 상수로 주입**하고 `P-3RD-01`은 고아다. `routeClass`(§A)가 생기면 이 스펙 조항이 그대로 실구현된다.

---

### E. `lootAnchor.tier` — 위험과 보상의 결합 (schema)

**실측:** 런당 기대 상자 **18.4개** vs 전투 **4.5회**(4:1). 상자 밀도는 **면적**에, 전투는 **가중치 추첨**에 걸려 있어 **둘이 서로를 전혀 모른다.** 전투가 배치되지 않은 9~10개 방이 사실상 무저항 상자 창고가 된다.

**제안:** Room `lootAnchor.tier` — `safe` / `contested` / `gated`.

**⚠ 경제 제약(문서에 명시 제안):** 상자는 **재료의 주 공급원**이다(분대 클리어 드롭에 ×0.2 배율이 걸려 있다 — `HUB-COR-000`). 재료 11종이 시설 9 + 스킬트리 2를 먹인다. 따라서 **티어 재분배는 총 기대치를 보존한 채** 해야 하고, 총량 변경은 별도 경제 판정이다. 수치 자체(밴드 16~20)는 튜닝이므로 전파하지 않는다.

---

## 2. 신규 ID + Upper 지역 어휘 (§F)

**결정(2026-08-24):** **실제 지역명 선반영.** `PROTO` 같은 임시 접두사를 쓰지 않는다.

### ⚠ 먼저 — 지역명이 스펙에 아예 없다

병영·수문·기록원·제련소는 **기획 코멘트에만 있고 스펙에 없다**(`docs` 전수 grep **0건**).
`LAY-UPPER`는 톤·비주얼·전조만 정의하고 **구체 장소를 하나도 명명하지 않는다**.
→ 이 패킷은 ID 발급뿐 아니라 **Upper 지역 어휘 자체를 신설**한다. 대상: `LAY-UPPER` §7 또는 신규 Zone 문서 + `LevelDesignMap.md`.

### ⚠ 그리고 — ID 충돌이 이미 강제 조건이다

`MAP-DEMO-001`은 **유지**한다(회귀 게이트·허브 사다리 T1/T3). 두 맵이 공존하는데
`id_registry.room_refs`는 **평면 전역 목록**이라, 새 맵은 `RM-ENTRY-01`·`RM-OBJ-01`·`RM-EXT-01`·
`RM-ADV-01..09`·`RM-MID-01`·`RM-BOSS-01`·`RM-DEEP-01`·`RM-ROUTE-01`을 **재사용할 수 없다**.

역할 기반 이름(`RM-ENTRY-##`)을 이어 쓰면 번호만 늘려 가며 충돌을 피해야 하는데, 그러면
「01은 데모, 02는 신맵」이라는 **문서 어디에도 안 적힌 규칙**이 생긴다. **지역명 채택이 이 문제를 자연히 없앤다.**

### 제안 명명 체계 (기존 패턴 준수)

| 종류 | 현행 예 | 제안 |
|---|---|---|
| 맵 | `MAP-DEMO-001` | `MAP-UPPER-001` |
| 청사진 | `DBP-DEMO-001` | `DBP-UPPER-001` (`basedOn: DBP-DEFAULT-001`) |
| 계약 | `CONTRACT-DEMO-001` | `CONTRACT-UPPER-001` |
| 컨셉존 | `ZONE-DEMO-UPPER` | `ZONE-UPPER-<REGION>` (지역별) |
| 방 | `RM-ADV-01` | **`RM-<REGION>-##`** |
| 풀 | `P-ADV-01` | `P-<REGION>-##` |
| 추출점 | `POINT-DEMO-01` | `POINT-UPPER-01` / `-02` (**탈출 2점**) |

> `ZONE-` 접두사는 스펙에서 **해저드 존**(`ZONE-OIL-001`·`ZONE-FIRE-001`)에도 쓰인다.
> 컨셉존과 해저드존이 같은 접두사를 공유하는 기존 부채다 — **이번에 분리할지 판정 필요**(예: 컨셉존 = `CZ-`).

### 지역 슬러그 — **이름은 기획 소유, 아래는 초안**

| 한국어(기획 코멘트) | 슬러그 초안 | 공간 문법 | Phase 1 초안 방 |
|---|---|---|---|
| 성문 어귀 | `THRESHOLD` | `safe` | ENTRY |
| 병영 | `BARRACKS` | `choke` + 증원 | HALL(중앙 분기) |
| 기록원 | `ARCHIVE` | `los_broken` | REC |
| 수문 | `SLUICE` | `split` + 우회 | OBJ(관통 목표방) |
| 제련소 | `FOUNDRY` | `open` + hazard | FOR(보상 루트) |
| **(미명명)** 위험 관문 | `?` | `choke` | GATE(확정 정예) |
| **(미명명)** 심부 | `?` | `split` | DEEP(확정 교전) |
| **(미명명)** 탈출 | `?` | `safe` | EXT-A / EXT-B |

**판정 필요 3건:** GATE·DEEP·EXT 지역명. 나머지 5개도 슬러그 철자는 확정 필요(예: 성문 어귀를
`THRESHOLD`로 할지 `WARDGATE`로 할지 — 데모 ENTRY 방 라벨이 이미 "Ward Threshold"다).

### 발급 규모

방 9 · 풀 6~7 · 추출점 2 · 맵/청사진/계약 각 1 · 컨셉존 4~8.
**미등록 ID는 로드 시점 abort**이므로 spec 등록이 게임 구현보다 **먼저**다
(`LevelDesignMap.md` 행 추가 = `F-026` §4 의무 → 게임 `data/slice01/id_registry.json`).

## 3. 집행 순서

1. ~~§B 택일~~ ✅ 옵션 2 · ~~§F 방향~~ ✅ 실제 지역명 — **남은 판정: 지역 슬러그 8종(§2) · 컨셉존 접두사 분리 여부 · `F-010` UI 문구**
2. spec repo에서 SSOT 편집 — **`F-006` §3.1.2 본문 교체**(§B) · §3.10.1 · `LDG-001` §8(필드 5행) · `D-015` 의미 명시 · `F-026` §3 · `DBP-DEFAULT-001` · `LAY-UPPER`(지역 어휘) · 신규 `DBP-UPPER-001`
3. `OPS_30` — impact_scan → 매퍼×4(`mapper_sync_check.py --fix`) → `RelationGraph` 재생성 → **DecisionLog `DEC-` 발급(§B 초안 사용)** → `TODO.md` → `SpecScopeTracker.md` → `LevelDesignMap.md`
4. `OPS_20` lint — `spec_xref_check.py` BLOCKER 0
5. PR → merge
6. **게임:** [`spec_ref.json`](../spec_ref.json) 핀 bump + `id_registry.json` 등록 + `rooms.json` 필드 반영 + `map_smoke` 설계 리포트를 **하드 게이트로 승격**(사이클 ≥ 2 · 경로별 교전 밴드 · 상자 EV 밴드)

---

## 4. 전파하지 않는 것 (분류 근거 기록)

| 항목 | 분류 | 처리 |
|---|---|---|
| 맵 계약(MapSource) · getter 8종 · 씬 요구 3종 | 게임 소유 | DRIFT-163 |
| Blender 노드 규약(`MK_*`·`TRIG_room`·`GEO_`/`OCC_`) | 게임 소유 | DRIFT-166 · [map_contract.md](design/map_contract.md) |
| 오클루더 콜라이더 유도 · Concave 제외 | 게임 소유 | DRIFT-163/164 |
| 안개 크기 예산(12 px/m · 바운딩 상한) | 튜닝/구현 | DRIFT-162 |
| 상자 EV 밴드 · 장애물 좌표 · 전투 예산 수치 | **튜닝(전파 금지)** | 로깅만 |
| `patrolGraphRef` · `aggro_wake_buffer_m` 실구현 | **커버리지**(스펙에 이미 있음) | 게임 구현 백로그 |
| 도면 방향(동 좌/우) | 게임 로컬 | DRIFT-162 |

---

## 5. 미판정 이월

**해소됨:** ~~§B 옵션 택일~~ → 옵션 2 · ~~§F 명명 방향~~ → 실제 지역명 선반영 (2026-08-24)

**남은 것:**
- **지역 슬러그 8종**(§2) — 특히 GATE·DEEP·EXT **3건은 이름 자체가 없다**. 이후 모든 ID가 따라간다
- **컨셉존 접두사** — `ZONE-`을 해저드 존과 계속 공유할지, `CZ-` 등으로 분리할지(기존 부채)
- `F-010` 배치 단계의 난이도 선택 UI 문구 처리(§B)
- `spatialGrammar` enum 개수 — 5종 시작 vs 6종(+`backline_pocket`)
- Phase 1 그레이박스의 실제 방 배치 — 플랜 문서 §Phase 1 도면은 **초안**이며 채택 전
- `ENC-HARD-*` 12종의 프로필 태그 유지 여부(§B ②는 「손대지 않는다」로 제안)

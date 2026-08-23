# 전파 패킷 — 맵 고도화 Phase 1 (위상·공간 문법·앵커)

> **용도:** spec repo(`project_tdc` @`staging`)에서 `OPS_30`(impact_scan → 매퍼×4 → DecisionLog `DEC-` → TODO → SpecScopeTracker) → `OPS_20`(lint) → PR로 집행할 **역전파 목록**.
> **이 레포는 spec md를 직접 편집하지 않는다**(AGENTS.md §Spec drift). 집행 후 [`spec_ref.json`](../spec_ref.json) 핀 bump가 이 레포의 유일한 spec-관련 쓰기.
> 🕒 **초안 — 미집행.** §A~E는 판정이 필요하고, 특히 **§B는 두 안 중 택일**이다.
>
> **패킷 작성:** 2026-08-24 · **근거:** [map_upgrade_plan.html](design/map_upgrade_plan.html) Phase 1 · [map_demo_001_status.html](design/map_demo_001_status.html) 실측 · DRIFT-162~166(Phase 0 완료)
> **선행 상태:** Phase 0 종료 — 맵 계약·계측기·앵커 데이터화 완료. **Phase 1은 첫 단계에서 스펙이 먼저 움직여야 한다.**

---

## 0. 한눈에

| # | 항목 | 분류 | 대상 문서 | 근거(실측) |
|---|---|---|---|---|
| **A** | `routeClass` — 방이 어느 탈출로에 속하는가 | schema | `LDG-001` §8 · `DBP-DEFAULT-001` §3 · `F-006` §3.10.1 | 경로 개념이 없어 전투 예산이 **전역 4~5** |
| **B** | **경로·레이어가 교전 티어를 공급한다** ⚠ **택일** | doc/schema 또는 rule | `F-006` §3.1.2 · §3.10.1 · `LDG-SPAWN-DEMO-001` | 도달 가능 ENC **12/24** — Hard 20행 + 12파일 사문화 |
| **C** | `spatialGrammar` — 방의 전투 공간 문법 | schema | `LDG-001` §8 · `F-026` §3 | 장애물 보유 **2/16방** · 동일 규격 방 8개 |
| **D** | `encounterAnchor.category` — 공간 역할이 **스폰 여부**를 정한다 | rule/schema | `F-006` §3.2 · `LDG-001` §8 · `DBP-DEFAULT-001` §4 | 진행 게이트가 **32 % / 40 %** 확률 |
| **E** | `lootAnchor.tier` — 위험과 보상의 결합 | schema | `LDG-001` §8 (`HUB-COR-000` 참조) | 상자 **18.4** vs 전투 **4.5** (4:1) |
| **F** | 신규 그레이박스 ID 발급 | scope/ID | `LevelDesignMap.md` · 신규 `DBP-###` | 방 9 · 탈출 2 · 사이클 3 |

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

### B. ⚠ **경로·레이어가 교전 티어를 공급한다** — **두 안 중 택일**

**문제(실측):** 도달 가능 ENC가 **12/24**다. 난이도 선택 UI가 M6에서 폐기돼 `RunLoadout.difficulty`가 항상 빈 문자열 → manifest 기본값 `Normal` 고정 → **spawn_table의 Hard 20행 + `ENC-HARD-*` 12파일이 영영 안 나온다.** 유일한 예외가 `P-BOSS-01`의 문자열 override다.

스펙도 이미 이 자리를 알고 있다 — `LDG-SPAWN-DEMO-001` `_note_boss`: *「어려운 관문」은 이제 토글이 아니라 **맵의 방**이 소유한다.* 그런데 **그걸 표현할 필드가 없다.**

#### 옵션 1 — `encounterScaleRef` 실구현 (**권장 · 규칙 변경 없음**)

`F-006` §3.1.2 resolve 순서 **2번이 이미 이렇게 적혀 있다**:

> Blueprint/Contract의 Pool 슬롯은 기본적으로 **"교전 규모/티어 참조"**(예: `encounterScaleRef` 또는 동등 키)를 사용한다.

게임은 이 단계를 건너뛰고 `(poolSlot, difficulty, world_layer)`로 바로 갔다. **원래 스펙대로 티어 참조를 실구현하고, 그 티어를 `routeClass × world_layer`가 공급**하면:

- `F-006` §3.1.2의 *「한 런 안에서 Normal 구역 → Hard 구역으로 진행하지 않는다」* 규칙 **그대로 유지**된다. `difficultyProfile`은 여전히 런 전 확정·전역이다.
- 티어는 난이도가 아니라 **공간의 성격**이다(`route_deep`의 Deep 방 = 높은 티어). 이미 `world_layer`가 resolve 키에 들어 있으니 축 하나(`routeClass`)를 더하는 것이다.
- 사문화된 Hard 12종은 **티어 태그를 다시 붙이면** 되살아난다.

**필요한 스펙 편집(작다):**
- `F-006` §3.10.1에 한 줄 — *「경로 아키타입은 Pool의 교전 티어 참조를 공급한다(`routeClass` × `world_layer`)」*
- `LDG-001` §8에 `routeClass[]` 행(§A와 동일)
- `LDG-SPAWN-DEMO-001` resolve 키 표기를 `(poolSlot, tier, world_layer)`로 정정 + 기존 `difficulty` 컬럼의 해석 정리

**미판정(사용자 판단 필요):** 기존 `ENC-HARD-*` 12종을 ⓐ 티어 태그로 재분류할지, ⓑ 파일명은 두고 spawn_table 컬럼만 티어로 읽을지.

#### 옵션 2 — `difficultyProfile`을 방/경로가 오버라이드

`F-006` §3.1.2의 *「한 런 안에서 진행하지 않는다」*와 **정면 충돌**한다. 분류가 `rule`이 되고 DecisionLog 필수.

**초안 판단(참고):** 옵션 1이 스펙의 원래 설계를 되살리는 쪽이고 충돌도 없다. 다만 **채택은 기획 판정 사항**이다 — 옵션 2가 「난이도 = 지역 입장 조건」이라는 M6 판정을 더 직접 표현한다는 견해도 성립한다.

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

## 2. 신규 ID 발급 (§F)

Phase 1 그레이박스(방 9 · 연결 11 · **사이클 3** · 탈출 2점)에 필요한 ID. **미등록 ID는 로드 시점 abort**이므로 spec 등록이 게임 구현보다 **먼저**다.

| 종류 | 개수 | 비고 |
|---|---|---|
| `MAP-###` | 1 | 신규 맵 — `MAP-DEMO-001`은 **유지**(회귀 게이트·허브 사다리) |
| `DBP-###` | 1 | `basedOn: DBP-DEFAULT-001` |
| `CONTRACT-###` | 1 | |
| `RM-###` | 9 | ENTRY · HALL · OBJ · REC · FOR · GATE · DEEP · EXT-A · EXT-B |
| `P-###` | 6~7 | 앵커 카테고리별 pool slot |
| `POINT-###` | 2 | **탈출 2점**(조기/심층) |

**미판정(사용자 판단):** 명명 체계. `MAP-PROTO-002`(두 번째 프로토타입임을 드러냄) vs `MAP-UPPER-001`(실제 지역명 선반영) vs 다른 안. 이후 전부가 이 접두사를 따라가므로 **여기서 정하고 시작하는 게 싸다.**

**동반:** `LevelDesignMap.md` 행 추가(신규 `DBP`/`RM` 등록 의무 — `F-026` §4) · 게임 측 `data/slice01/id_registry.json` 등록.

---

## 3. 집행 순서

1. **§B 택일** + **§F 명명 확정** ← 여기서 막혀 있다(판정 필요)
2. spec repo에서 SSOT 편집 — `LDG-001` §8 · `F-006` §3.10.1(+§3.1.2 옵션 2일 때) · `F-026` §3 · `DBP-DEFAULT-001` · 신규 `DBP-###`
3. `OPS_30` — impact_scan → 매퍼×4(`mapper_sync_check.py --fix`) → `RelationGraph` 재생성 → DecisionLog `DEC-YYYYMMDD-###` → `TODO.md` → `SpecScopeTracker.md` → `LevelDesignMap.md`
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

- **§B 옵션 택일** — 초안 판단은 옵션 1(규칙 변경 없음)이나 **기획 판정 사항**
- **§F 명명 체계** — 이후 전부가 따라간다
- `ENC-HARD-*` 12종의 티어 재분류 방식(ⓐ 파일 재태그 / ⓑ 컬럼 해석 변경)
- `spatialGrammar` enum 개수 — 5종으로 시작할지 6종(+`backline_pocket`)으로 시작할지
- Phase 1 그레이박스의 실제 방 배치 — 플랜 문서 §Phase 1 도면은 **초안**이며 채택 전

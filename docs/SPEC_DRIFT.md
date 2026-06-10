# SPEC_DRIFT — 구현 ↔ 스펙 이격 대장

> **무엇:** 구현이 spec(SSOT)과 달라진 지점의 **단일 추적 대장**. 발견 즉시 `DRIFT-###`로 기록하고, 분류·결정·상태를 유지한다.
> **규칙:** [AGENTS.md](../AGENTS.md) §Spec drift & propagation. 튜닝수치=로깅만 / 아이디어=`OPS_08·I-002` / 규칙변경=spec repo `OPS_30` 전파 후 `spec_ref.json` 재핀.
> **최종 갱신:** 2026-06-10 · **스펙 핀:** `spec_ref.json` @ `staging` `f7739a1` (DRIFT-021 전파 — F-003 §3.0.4 지휘권 보유자↔랠리 앵커 분리, DEC-20260610-002. 이전 018/019=F-013, 6f0e534).
> **출처:** 2026-06-08 read-only 드리프트 서베이(스펙 SSOT 대조 검증).

## 범례
- **분류**: `tuning`(전파금지·로깅만) · `idea`(OPS_08) · `rule`(OPS_30 전파) · `code-bug`(가드/검증 결함) · `scope`(스코프/마일스톤)
- **상태**: `LOGGED`(기록만) · `OPEN`(사용자 결정 필요) · `SCHEDULED`(이번 작업 처리예정) · `RESOLVED` · `PENDING-PROP`(스펙 전파 대기, 승인 필요) · `BACKLOG`(1b)

---

## 🔶 DRIFT-000 — Phase 1a(Slice-01) 종료 → Phase 1b 확장 (최상위 스코프 결정)

| | |
|---|---|
| **현실** | 사용자 선언: "Slice-01은 사실상 끝났고 이후 필요한 기능부터 확장 중." 즉 프로젝트는 **1b 확장 단계**. |
| **스펙/문서 상태** | `spec_ref.json`·`manifest.json`·`WORK_ORDER.md`·spec `SpecScopeTracker`는 여전히 **Phase 1a / QA-030 진행중**으로 기술. |
| **알려진 갭** | Slice-01 졸업 게이트 **`T-ENC-NORM-001`은 공식 검증된 적 없음** (필수방이 ENC-NORM-001을 스폰 안 함 → DRIFT-004). "선언적 완료 — 미검증 갭 수용". |
| **분류** | `scope` |
| **결정** | (1) Slice-01을 *선언적 완료*로 닫음(미검증 갭 수용). (2) 1b 기능 확장을 공식화 → spec `SpecScopeTracker`/`TODO` 갱신 + **1b 계약 `QA-031` 신설** 필요. |
| **상태** | ✅ `MERGED` — spec staging 머지 완료(`d70ed48`: QA-031·QA-030 §7·DEC-20260608-001·SpecScopeTracker·TODO). 게임 `spec_ref.json`/`manifest` 재핀(QA-031·1b), 헤드리스 검증 통과. |
| **참고** | 나중에 Slice-01을 진짜 마일스톤으로 써야 하면 DRIFT-004를 `adopt`로 전환해 게이트 검증부터. |

---

## 요약 표

| ID | 영역 | 분류 | 결정 | 상태 |
|----|------|------|------|------|
| 000 | Phase 1a→1b 전환 | scope | 선언적 완료 + 1b 공식화(QA-031) | ✅ MERGED (staging d70ed48) |
| 001 | 플레이어 서브 스킬 AB-S01~04 | rule | **유지** = 1b 스킬북 기능, spec 승격(QA-031); AB-S0x→spec 서브 정합은 1b 콘텐츠 과제 | ✅ MERGED · 정합 BACKLOG |
| 002 | Identity 전원 자동(조작캐 포함) | rule | spec HEAD와 정합 → **재핀** | RESOLVED (P2) |
| 003 | 인런 키: 스왑 1-4 / 서브 Q | rule | 스왑=HEAD 정합(재핀); 서브키는 001에 종속 | RESOLVED/부분 |
| 004 | P-ADV-01 → ENC-HARD-001 (NORM-001 도달불가) | scope | **둘 다 살림**: P-ADV-01→NORM-001, P-ADV-02→HARD-001 | RESOLVED (P3) |
| 005 | 1b 메커닉이 전투에(EN-005/006·증원·상태이상) | rule | 유지=1b, spec 승격(QA-031) | ✅ MERGED (staging d70ed48) |
| 006 | abilities.json id 검증 누락 + 미등록 ID | code-bug | 등록(14 AB) + `require_id` + sub_ability_id 검증 | RESOLVED (P3) |
| 007 | AB-020 Anchor Guard 수치 | tuning | 로깅만, 재산출 | LOGGED |
| 008 | AB-024 Press the Line 수치 + 3타 붕괴 | tuning/polish | 로깅; 3타 순차는 1b 폴리시 | LOGGED/BACKLOG |
| 009 | AB-025 Mark & Ruin 수치 + 텔레그래프/환급 없음 | tuning/polish | 로깅; 텔레그래프는 1b | LOGGED/BACKLOG |
| 010 | AB-026 Mend Circle 수치 | tuning | 로깅, 임계 재정렬 | LOGGED |
| 011 | 적 HP/접촉뎀/**이속** 튜닝 | tuning | 로깅, ENC-NORM-001 기준 재산출 | LOGGED |
| 012 | DIFFICULTY_OPTIONS EN-013 문서 오타 | code-bug(doc) | 재현 안 됨(파일에 EN-013 없음) | DROPPED |
| 013 | 아군간 물리충돌 제거(MASK_PARTY) | (비위반) | 로깅만 | LOGGED |
| 014 | 파티전멸=Run Failure 없음(F-007) | scope | 1b 갭(저비용 추가 권장) | BACKLOG |
| 015 | 맵 장애물 + 파티합집합 LOS 가림 구현 (F-011 선행) | scope/impl | occlusion-only 토대, 풀 F-011은 보류 | IMPLEMENTED |
| 016 | RMB 카메라회전 + WASD 카메라상대 + 방향별속도(W>A/D>S) + 진형정면=카메라추종 | rule/impl | F-002(RMB=페이싱)와 충돌 → 카메라 우선. 진형 이동반전 플립머신 제거(~134줄). 페이싱 구현 시 재바인딩 | IMPLEMENTED |
| 017 | enemy_unit LAYER_ENEMY 3→4 콜리전레이어 근본수정 | code-bug | 적이 world비트 공유하던 버그 수정(LOS·스티어링 정상화) | FIXED |
| 018 | 적 시야 인지(F-011 perception **부분구현**, deferred→1b): 전방콘(FOV~160°)+LOS+근접버블·2존(경계존?·전투존!)·last_seen 수색·도망 시 grace(6s)+감속(0.55) 추격 후 포기 | scope/rule | **유지=1b 확장.** F-011 perception 데모 부분집합 노트 + 신규 **F-013** enemy-AI + QA-031 승격 | ✅ MERGED (staging 6f0e534 · DEC-20260610-001) |
| 019 | 적 **분대(squad)** 단위 engage(분대 독립·분대원 근접전파 9m·stray 예외) + **미리 스폰(휴면)**·시작방 인카운터→메인전투방 이전·방 먼쪽 배치 + navmesh 추격 + **threat/시야기반 타겟**(미인지 대상 비타겟) | rule/scope | 신규 **F-013** enemy-AI 행동 루프로 SSOT화(분대=F-022 Encounter Group 구체화). 포스트복귀/리쉬는 F-013 §9 후속 | ✅ MERGED (staging 6f0e534 · DEC-20260610-001) |
| 020 | 전투AI/인지 **튜닝수치**(FOV 160°·sight 12m·proximity 2.5m·alert_zone 0.2·scan ±35°/4s·investigate 0.35·chase_blind 0.55·squad_prop 9m·exit_grace 6s·lane 12m·cone alpha 0.05~0.06) | tuning | 로깅만(전파 금지). grace 6s는 D-010 §4.2와 정합 | LOGGED |
| 021 | 비결속 지휘권 **분리 모델**: 지휘권 보유자(리더 고정·핑/MIA 대상) ↔ 포메이션 랠리 앵커(보유자 조작/복귀 중 stand-in 자동·복귀 시 환원) | rule | F-003 §3.0.4 신설로 SSOT화(보유자=리더 고정, 랠리 앵커만 자동). UI-008=리더 외 명시 지정 | ✅ MERGED (staging f7739a1 · DEC-20260610-002) |

> **비-드리프트(기존 spec 구현=정합, ImplDecisionLog 기록):** partyInCombat 진입/종료(D-010 §4.1 피해·공격·인지 / §4.2 grace), 비조작 안전우선 슬롯-이탈 트리거=피격/사거리(F-004 §3.1/§3.3), 힐러 포지셔닝(F-005), **지휘권 진입 핸드오프=서브리더 앵커(F-003 §3.4 #2)** — 진입 동작은 기존 spec 정합. 단 **스왑 중 지휘권/랠리 거동은 §3.0.4 분리 모델로 정제 → DRIFT-021(✅ MERGED f7739a1)**. 서브리더 지정(UI-005)·지휘권 전환 UX(UI-008)·Leader Move Ping(F-003 §3.5)은 **미구현(기본값/보류)**.
> **아이디어(OPS_08):** "시야콘을 보이게 하는 소모품"(현재는 개발용 상시 표시) → 소모품/UI 아이디어로 등록 권장.
> **비-드리프트(검증결과 정합):** EN-013@ENC-NORM-002, EN-001 방패치기(AB-002), EN-011 원거리(AB-016)는 **스펙 역할과 정합** — 드리프트 아님.

---

## 상세

### DRIFT-001 — 플레이어 서브 스킬 (AB-S01~S04)
- **현재:** `abilities.json`에 자작 서브 4종(AB-S01 도발슬램/S02 돌진/S03 노바/S04 성역), `identities.sub_ability_id`, `combat_controller.cast_sub()`(조작캐 전용, Q+지면조준). NC는 서브 자동사용 안 함.
- **스펙:** QA-030 §1 Non-goal "조작 서브"; 스펙 자체 플레이어 서브는 `AB-033~035`(PT-011), 그조차 Slice-01 deferred. F-009 SkillbookEconomy가 습득 경로.
- **재분류(사용자):** Slice-01 위반이 아니라 **풀게임 정식 기능**(스킬북 루팅 습득)을 1b에서 먼저 구현한 것.
- **결정:** **유지.** F-009/플레이어 툴킷에 승격.
- **상태:** ✅ **MERGED** (staging d70ed48 — `QA-031`이 "스킬북 경제 + 플레이어 서브"를 1b In-scope로 승격, §2에 AB-S0x 정합 과제 명시, DEC-20260608-001). **잔여:** 자작 `AB-S01~04` → spec 서브(Tank `AB-033~035` / DPS·Nuker·Healer `ROLE-020/030/040` lootable 풀) **ID 정합**은 `QA-031` §2 명시 **1b 콘텐츠 과제(BACKLOG)** — 정합 전까지 id_registry 비-spec 표기 유지.

### DRIFT-002 / 003 — Identity 자동 + 키 스킴 (재핀으로 해소)
- 핀 `cd6009e`는 Identity=Q(수동), 스왑=F1~F4. 스펙 **HEAD `262d8bb`**는 Identity=자동(조작캐 포함), 스왑=1~4. 게임은 **이미 HEAD 상태 구현**.
- `cd6009e..262d8bb` diff는 인런 키바인딩+Identity 자동 **한 건뿐**(전투/어빌리티/ENC/QA-030 수치 동일).
- **결정/상태:** `spec_ref.json` 재핀(P2)으로 002·003(스왑) `RESOLVED`. 서브 키(Q)는 DRIFT-001 결정에 종속.

### DRIFT-004 — 필수 전투방이 ENC-NORM-001 미스폰 🔴 OPEN
- **현재:** `manifest.json` `P-ADV-01 → ENC-HARD-001`. `ENC-NORM-001`은 `required_encounter_smoke`로만 존재, 어떤 룸/풀도 스폰 안 함.
- **스펙:** DBP-DEMO-001 §5.1 `P-ADV-01: forceEncounter ENC-NORM-001`; QA-030 §5 FAIL "필수 ENC 미스폰/임의 ENC 하드코딩".
- **결정(2026-06-08, 사용자): "둘 다 살림".** `manifest` `P-ADV-01 → ENC-NORM-001`(복원, 필수·게이트), `rooms.json` `RM-ADV-02`에 `pool_slot: P-ADV-02` 추가 + `manifest` `P-ADV-02 → ENC-HARD-001`(ADV-02 분기의 선택 전투). NORM-001은 다시 도달 가능, HARD-001도 보존.
- **상태:** `RESOLVED` (P3). 헤드리스 로드 검증 통과. **잔여:** ENC-NORM-001 전투 실제 스폰/플레이는 F5 기준선 검증 + HARD-001의 1b spec 승격(DRIFT-005와 함께 QA-031).

### DRIFT-005 — 1b 난이도 메커닉이 전투에 유입
- EN-005(독)·EN-006(스턴 CC)·증원 웨이브·상태이상(F-021)으로 effective mechanicAxes 3 > 데모 상한 2. 단, EN-005/006·AB-010/011은 **유효 spec ID**.
- **결정:** 1b 기능으로 유지, spec 승격(QA-031). 단 *Slice-01 검증 전투*(DRIFT-004 A 선택 시)에는 등장 금지.
- **상태:** ✅ **MERGED** (staging d70ed48 — `QA-031`이 EN-005/006/013·`ENC-HARD-001`·증원 wave·`F-021` 상태이상 depth 1을 1b In-scope로 승격, DEC-20260608-001).

### DRIFT-006 — abilities.json 검증 누락 (코드 가드 버그) ✅ RESOLVED (P3)
- `slice01_data._parse_abilities()`가 `require_id` 미수행. `id_registry.ability_ids`엔 AB-020/024/025/026만 → AB-001/002/010/011/015/016·AB-S0x가 "미등록 ID→abort" 우회. `sub_ability_id`도 미검증이었음.
- **처리(P3):** ① `id_registry.ability_ids`에 사용중 14개 AB-### 등록(`_note`로 AB-S0x 비-spec 표기) ② `_parse_abilities`에 `require_id` 루프 ③ `_parse_identities`에 `sub_ability_id` 검증 추가. 헤드리스 로드 검증 통과(등록 누락 시 abort했을 것).

### DRIFT-007~011 — 수치 드리프트 (tuning, 로깅만)
- AB-020(cd6→8·base80→120·cap160→280·dur4→5·pulse90→60), AB-024(cd4→7·perhit0.35→1.0·3타 단발붕괴), AB-025(cd5→9·mult7→12·텔레그래프/환급 없음), AB-026(cd7→6·r4→5·heal12%→10%·임계 85/90→90/95), 적HP 인플레(EN-001 760 등).
- **적 이속(2026-06-08):** 2.0~5.0 → **7.5~9.5** (조작 9.0 대비 near-equal). 이유: 적이 느려 무시·도망 전략이 통함 → 카이팅 차단. 아키타입 유지. spec 무관(F-025 §11 tuning).
- **템포 ×2/3 + 감속(2026-06-08):** 전 이동체 이속 ×2/3 — 파티 조작 9→6·추종 13→8.7·근접 9.5→6.3, 적 7.5~9.5→**5.0~6.3** (비율유지 → 카이팅방지 유지). 조작캐 감속 45→**200**(빙판느낌 제거; 가속 25 유지). `formation.json`·`enemies.json`, spec 무관 tuning.
- **팔로워 catch-up 재조정(2026-06-09):** 반응성을 최고속도 대신 가속도로 — 추종 far 8.7→**6.6**(조작 6.0 근처 마진만), `follower_accel` 50→**70**. 조작캐 이동 방향별 속도(W 1.0/A·D 0.75/S 0.65) 추가.
- 스펙 어빌리티/적 수치는 모두 **"design example, runtime SSOT 아님"** → 위반 아님. ChangeProtocol §5-d: 튜닝은 마일스톤에서만 선택적 반영.
- **로깅 사유:** 수치 인플레가 *과강한 자작 서브/Identity 보정*에서 비롯됨(PHASE5 §60/63). DRIFT-001/004 정리 후 ENC-NORM-001 기준으로 **재산출**할 것.

### DRIFT-008/009 폴리시 갭 (BACKLOG)
- AB-024 3타 순차 sweep·"적 전멸 시 잔여타 취소", AB-025 0.5s 표식 텔레그래프·실패시 쿨 50% 환급 — 게임 자체 CP4 미완 항목. 1b 폴리시로 구현.

### DRIFT-012 — 문서 오타 (SCHEDULED P4)
- `DIFFICULTY_OPTIONS.md`가 ENC-NORM-001 구성에 EN-013 포함이라 기술(실제는 EN-012). 문구만 수정.

### DRIFT-015 — 맵 장애물 + LOS 가림 (F-011 선행 구현)
- **구현(2026-06-08):** 맵에 엄폐 장애물 3종(기둥/상자/바리어, `map_demo_layout` OBSTACLE_SPECS, navmesh 자동 우회) + **파티 합집합 LOS 가림**(`enemy_visibility.gd`: 살아있는 파티원 중 한 명이라도 LOS 있으면 적 표시; 없으면 `enemy_unit.set_seen` 알파 페이드아웃 + `last_seen_pos` 저장).
- **F-011 관계:** Vision & Information War(파티 광원 합집합·perceptionProfile·Patrol·Threat Memory)는 QA-031 Non-goal/Expansion(보류). 본 구현은 그 **occlusion-only 토대** — perception/patrol/광원합집합/마커는 미구현.
- **결정:** 풀 F-011 착수 시 본 구현을 그 위에 확장(관측자=합집합 그대로, last_seen_pos→마커, 장애물→그림자 캐스터). spec 전파는 F-011 정식화 때 OPS_30. 현재는 impl 토대 + 맵 LevelContent(Local edit).

### DRIFT-013/014 — 비위반 / 1b 갭 (LOGGED)
- 013: 아군간 물리충돌 제거 — spec 조항 없음(스티어링 스태킹 방지용). F-003 정밀검증(QA-003) 시 재검토.
- 014: 파티전멸=Run Failure(F-007 §3.7.1)는 실제 규칙이나 QA-030 Non-goal로 1a 보류. 1b에서 "4 down→Run Failure" 저비용 추가 권장.

### DRIFT-018 — 적 시야 인지(F-011 perception 부분구현, deferred→1b) ✅ MERGED (staging 6f0e534)
- **구현(2026-06-09):** 적 휴면/경계/전투 3상태 + **하이브리드 시야콘** 인지:
  - 전방 FOV 콘(~160°) + **LOS 레이캐스트**(벽 가림) + **360° 근접버블**(2.5m, 각도무관) — `combat_controller._tick_dormant`/`_has_los`, `enemy_unit`(facing·scan·콘 VFX).
  - 콘 거리 **2존**: 외곽 20%=경계존(`?` + last_seen 조사 이동), 내부 80%=전투존(`!` + 교전 진입). 근접버블=전투존.
  - 교전 중 **LOS 끊기면** 마지막 목격(last_seen)으로 감속 추적, `combat_exit_grace_s`(6s) 무LOS 시 휴식 복귀. 공격도 LOS 게이트(벽 관통 사격 차단).
- **F-011 관계:** F-011(Vision & Information War)은 QA-031 Non-goal/Expansion(보류, DRIFT-015 occlusion-토대만). 본 작업은 그 위에 **적→파티 perception(시야콘·인지·시야기반 전투 진입)** 을 1b에서 선구현 = **deferred 스코프를 앞당김**. 미구현 잔여: perceptionProfile별 수치·Patrol 경로·Threat Memory·광원합집합 인지.
- **분류/전파:** scope(F-011 일부 1b 편입) + rule(신규 적AI). **PENDING-PROP** → spec repo OPS_30: QA-031(1b 스코프에 perception/enemy-AI 추가)·F-011(구현된 perception 모델 일부 확정 or "demo subset" 명시)·SpecScopeTracker. DecisionLog `DEC-`.

### DRIFT-019 — 적 분대(squad) 전투AI + 미리스폰 + 시야기반 타겟 ✅ MERGED (staging 6f0e534)
- **구현(2026-06-09):**
  - **분대(squad)** = 인카운터 그룹. engage는 적 단위지만 **같은 분대 근접(9m) 전파**만 → 조사로 분대와 멀어진 적을 잡아도 먼 분대는 안 깨움(stray 예외). partyInCombat = 임의 적 engaged(파생).
  - **미리 스폰**: 런 시작 시 인카운터를 휴면 분대로 사전 배치(방 진입 트리거 제거). **시작 방 인카운터는 메인 전투방으로 이전**, 분대는 방 **먼쪽**(파티 시작 반대편)에 배치 + 입구 반대 응시.
  - **타겟**: highest-threat → 없으면 **시야(LOS) 내 최근접**. 인지·위협 없는 먼 멤버(숨은 본대)는 타겟 안 됨. 인지 시 그 멤버에 위협 부여(분대 공유).
  - 적 **navmesh 추격**(벽 우회), 비결속 Tank-앵커도 전투 합류.
- **분류/전파:** rule/scope — 신규 적 전투AI 동작(분대 어그로·미리스폰·도망 대응). **PENDING-PROP** → QA-031 + enemy-AI 규칙 절(신규 또는 `F-024 RiskPatterns`/`F-022` 확장). 인카운터 미리스폰은 `DBP`/encounter 스폰 모델과 정합 필요.
- **잔여(미구현):** 포기 후 **스폰 원위치 복귀** + 스폰 리쉬(Phase D 잔여).

### DRIFT-021 — 비결속 지휘권: 보유자↔랠리 앵커 분리 (rule) ✅ MERGED (staging f7739a1)
- **증상(사용자):** 비결속에서 Tank(컨트롤)로 정찰 나간 뒤 DPS로 스왑하면, 기대는 "Tank 복귀·DPS만 이탈"인데 **Tank·DPS 둘 다 대열 이탈**. 원인: §3.4가 "컨트롤=비리더 → 앵커=리더(Tank)"인데, 그 Tank는 방금 멀리 정찰 간 캐릭이라 **파티가 Tank를 따라 이동**.
- **구현(2026-06-10, 2차 정제):** `_update_command_holder()`를 **per-frame** 갱신으로 — **리더가 정본 앵커**(이동핑 명령 대상). 리더가 "나가 있는" 동안만 임시 위임: ① 리더 컨트롤(정찰) → stand-in 보유(파티 위치 유지) ② 리더 해제됐으나 복귀 중 → stand-in 유지(파티가 리더의 먼 위치로 안 끌려감) ③ **리더가 대열 복귀(stand-in 앵커 5m 내, `_leader_returned`) → 앵커를 리더로 환원**. stand-in 선정 시 **방금 떨어진 정찰자 제외**(`avoid_scout`)로 거울 케이스(서브 정찰→리더 스왑)도 처리. 결과: 떨어진 1명만 이탈, 나머지 대열 유지, 복귀자 슬롯 복귀, **앵커는 임의 멤버로 흘러가지 않고 리더로 돌아옴**.
- **§3.4 관계:** 진입 핸드오프(리더 컨트롤→서브, §3.4 #2/#3)는 **그대로**. 추가: (a)리더=정본 앵커·복귀 시 환원 (b)정찰/복귀 중 임시 stand-in (c)stand-in 후보=leader/sub→전 멤버(2명으론 불충족)·정찰자 제외. 1차 시도(앵커가 stand-in으로 영구 drift)는 사용자 지적으로 폐기 — 앵커는 이동핑 대상이라 의미있는 역할이어야 함.
- **전파 결과(✅ MERGED, staging f7739a1 · DEC-20260610-002):** 전파 단계에서 F-003 §3.0/§3.10이 "**앵커 고정 + UI-008 수동 전환**" 모델임을 발견 — 단순 확장이 아니라 **모델 충돌**. 사용자 결정으로 **분리 모델** 채택: **지휘권 보유자**(리더 고정·이동핑/MIA/합류 기준, UI-008로만 변경) ↔ **포메이션 랠리 앵커**(보유자 조작/복귀 중 stand-in 자동·복귀 시 환원, 정찰자 제외)를 **F-003 §3.0.4** 신설로 SSOT화. 게임 코드는 랠리 앵커만 구현(핑/MIA 미구현이라 보유자=리더는 개념상 동치). `leader_return_radius_m` 5m은 tuning. UI-008은 "리더 외 명시 지정"으로 재정의(후속). 게임 `spec_ref.json` 재핀 f7739a1.

### DRIFT-020 — 전투AI/인지 튜닝수치 (LOGGED, 전파금지)
- FOV 160° · sight_range 12m · proximity 2.5m · alert_zone_frac 0.2 · scan ±35°/4s · investigate_speed 0.35 · chase_blind 0.55 · squad_prop_radius 9m · combat_exit_grace 6s · squad_lane 12m · cone alpha 0.05~0.06.
- **탈출 채널(2026-06-10):** POINT-DEMO-01 홀드→Extraction Success. **비전투 5s / 전투중(partyInCombat) 30s** (매 프레임 현재 전투상태로 임계 판정) + 큰 카운트다운 UI(높은 수→1). **F-007 §3.1.2 정합**(ExtractionActivate=채널·홀드, 완료=성공; 채널 시간은 "후속 UI/전투 SSOT"라 tuning). 존 이탈=취소(실패 정산 없음, F-007). `EXTRACT_RADIUS_M` 3m.
- ChangeProtocol §5-d 튜닝 — 전파 금지, 로깅만. `combat_exit_grace_s` 6s는 **D-010 §4.2 초기값과 정합**. F-011 정식화 시 perceptionProfile 기준으로 재산출.

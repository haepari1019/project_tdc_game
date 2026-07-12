# SPEC_DRIFT — 구현 ↔ 스펙 이격 대장

> **무엇:** 구현이 spec(SSOT)과 달라진 지점의 **단일 추적 대장**. 발견 즉시 `DRIFT-###`로 기록하고, 분류·결정·상태를 유지한다.
> **규칙:** [AGENTS.md](../AGENTS.md) §Spec drift & propagation. 튜닝수치=로깅만 / 아이디어=`OPS_08·I-002` / 규칙변경=spec repo `OPS_30` 전파 후 `spec_ref.json` 재핀.
> **최종 갱신:** 2026-07-09 — **컴팩션:** 스펙 전파 완료(✅ MERGED / ✅ 전파 / 🔷 전파) 드리프트 **19건 제거** — DRIFT-000·005·018·019·021·022·023·024·025·027·035·036·037·038·050·054·070·071·072(스펙 SSOT 반영 완료; 이력=spec DecisionLog/커밋). 잔존 = 튜닝 로깅(전파금지)·impl 결정·전파 후보(미전파)·파일럿 로깅(🕒 전파 보류). **현재 스펙 핀:** `staging@2bf37b2`(QA-031·Phase 2, 결속 정본 계열).
> **미전파(승인/게이트 대기):** DRIFT-069 F3 환경 RX 3종·B7 zone spread = `PENDING-PROP`(OPS_30) · DRIFT-073~077 파일럿 결속/캐스터 설계 = 🕒 로깅(게이트 후 전파) · 058·064·065·066·067·068 = 전파 후보.
> **2026-07-12 추가(미커밋 작업 로깅):** DRIFT-078 I-006 캐스팅 확장 패스(엄브렐러·impl/tuning·진행 중) · **DRIFT-079 AB-054 채널 규칙변경**·**DRIFT-080 DPS 초월 개편** = 🔶 rule **전파 후보**(OPS_30 미전파) · DRIFT-081 적 상태칩(impl) · **DRIFT-082 Shared 스킬 적↔아군 통합**(AB-003 파일럿·CastContext·프레젠테이션 파리티) = 🔶 rule/design **전파 후보**(packet 준비). 세부 원장 = `docs/_WIP_casting_expansion_pass.md` §4.
> **출처:** 2026-06-08 read-only 드리프트 서베이(스펙 SSOT 대조) 이래 누적.

## 범례
- **분류**: `tuning`(전파금지·로깅만) · `idea`(OPS_08) · `rule`(OPS_30 전파) · `code-bug`(가드/검증 결함) · `scope`(스코프/마일스톤)
- **상태**: `LOGGED`(기록만) · `OPEN`(사용자 결정 필요) · `SCHEDULED`(이번 작업 처리예정) · `RESOLVED` · `PENDING-PROP`(스펙 전파 대기, 승인 필요) · `BACKLOG`(1b)

---

## 요약 표

| ID | 영역 | 분류 | 결정 | 상태 |
|----|------|------|------|------|
| 001 | 플레이어 서브 스킬 AB-S01~04 | rule | **유지** = 1b 스킬북 기능, spec 승격(QA-031); AB-S0x→spec 서브 정합은 1b 콘텐츠 과제 | ✅ MERGED · 정합 BACKLOG |
| 002 | Identity 전원 자동(조작캐 포함) | rule | spec HEAD와 정합 → **재핀** | RESOLVED (P2) |
| 003 | 인런 키: 스왑 1-4 / 서브 Q | rule | 스왑=HEAD 정합(재핀); 서브키는 001에 종속 | RESOLVED/부분 |
| 004 | P-ADV-01 → ENC-HARD-001 (NORM-001 도달불가) | scope | **둘 다 살림**: P-ADV-01→NORM-001, P-ADV-02→HARD-001 | RESOLVED (P3) |
| 006 | abilities.json id 검증 누락 + 미등록 ID | code-bug | 등록(14 AB) + `require_id` + sub_ability_id 검증 | RESOLVED (P3) |
| 007 | IDA-020 Anchor Guard 수치 | tuning | 로깅만, 재산출 | LOGGED |
| 008 | IDA-024 Press the Line 수치 + 3타 붕괴 | tuning/polish | 로깅; 3타 순차는 1b 폴리시 | LOGGED/BACKLOG |
| 009 | IDA-025 Mark & Ruin 수치 + 텔레그래프/환급 없음 | tuning/polish | 로깅; 텔레그래프는 1b | LOGGED/BACKLOG |
| 010 | IDA-026 Mend Circle 수치 | tuning | 로깅, 임계 재정렬 | LOGGED |
| 011 | 적 HP/접촉뎀/**이속** 튜닝 | tuning | 로깅, ENC-NORM-001 기준 재산출 | LOGGED |
| 012 | DIFFICULTY_OPTIONS EN-013 문서 오타 | code-bug(doc) | 재현 안 됨(파일에 EN-013 없음) | DROPPED |
| 013 | 아군간 물리충돌 제거(MASK_PARTY) | (비위반) | 로깅만 | LOGGED |
| 014 | 파티전멸=Run Failure 없음(F-007) | scope | 1b 갭(저비용 추가 권장) → **DRIFT-031로 구현**(PartyWipe→Run Failure) | ✅ IMPLEMENTED (DRIFT-031) |
| 015 | 맵 장애물 + 파티합집합 LOS 가림 구현 (F-011 선행) | scope/impl | occlusion-only 토대, 풀 F-011은 보류 | IMPLEMENTED |
| 016 | RMB 카메라회전 + WASD 카메라상대 + 방향별속도(W>A/D>S) + 진형정면=카메라추종 | rule/impl | F-002(RMB=페이싱)와 충돌 → 카메라 우선. 진형 이동반전 플립머신 제거(~134줄). 페이싱 구현 시 재바인딩 | IMPLEMENTED |
| 017 | enemy_unit LAYER_ENEMY 3→4 콜리전레이어 근본수정 | code-bug | 적이 world비트 공유하던 버그 수정(LOS·스티어링 정상화) | FIXED |
| 020 | 전투AI/인지 **튜닝수치**(FOV 160°·sight 12m·proximity 2.5m·alert_zone 0.2·scan ±35°/4s·investigate 0.35·chase_blind 0.55·squad_prop 9m·exit_grace 6s·lane 12m·cone alpha 0.05~0.06) | tuning | 로깅만(전파 금지). grace 6s는 D-010 §4.2와 정합 | LOGGED |
| 026 | **스킬북 시스템 B**: 적 lootable AB(AB-002/010/011) per-kill 드랍 → 백팩 At-Risk 1×1 / Q·E·R 3슬롯 장착(클래스 게이트·드래그·우클릭·녹적 프리뷰)·탄수 소모·전투 외 교체 / Identity 고정서브(AB-S01~04) 제거 | rule(전파됨)+tuning | per-kill·서브3슬롯=spec(DEC-20260611-002, c795fee). charges 8/10/6·드랍률 0.5·독/스턴 프록시=tuning/impl | IMPLEMENTED |
| 028 | **Fatal 장판 트랩 + MIA + navmesh carve + 레버**: 초크포인트 트랩→치명 장판(텔레그래프→치사·피아무구분) 스폰→파티 분리 / 후미 fatal 회피·stand-off hold / 장판=**navmesh carve**(벽처럼 우회/단절) / **MIA 양경로**(비결속 leash 20m·즉시 경계링·1s 경고·5s MIA·조작캐면 앵커 강제이전 / 복귀실패=nav 경로 도달불가) / 레버=함정 회복 | rule(기존 spec 구현)+scope+tuning | F-006 트랩·F-004 §3.1.1/§3.3·F-003 §3.3.1/§3.6.2·F-001 §3.6 구현. 트랩/레버 gimmick=신규 데모(전파 후보). 장판 수치·leash 20m·타이밍=tuning | IMPLEMENTED (일부 전파 후보) |
| 029 | **기름 배럴 + 화염 연쇄(RX-OIL-FIRE) + 디버프 핍 + 서브 페널티**: 파괴 배럴(ENT-BARREL)→기름 장판(슬로우 필드)·화염 스킬북(Ember Lance AB-037)→기름 점화→**폭발+화염/독안개 장판+연쇄**(depth≤2) / zone 일반화(status·impassable·ttl·slow) / 슬로우·DoT 디버프 핍 / **서브 클래스 페널티**(비주력 −10% + UI 경고) | rule(기존 spec 구현)+tuning | F-027 RX-OIL-FIRE-001·ENT-BARREL-001·D-016 AB-037·F-021 ZONE/연쇄·F-009 §3.2.1 구현. 수치·main=first-equip-class 휴리스틱=tuning/impl | IMPLEMENTED |
| 030 | **MIA 대응 UI(UI-006) 정식화 + 다중 MIA 모집지점 픽스**: 중앙 분리경고 배너 + PIP 카메라(world 공유·강조 3s→저강조→8s 자동최소화·최소/확장·다중 MIA 사이클 ▶·수동닫기 5s 쿨다운) / MIA 멤버=랠리 앵커·지휘권 stand-in **선정 제외** / 비조작 전원 MIA여도 BOUND 폴백 안 함(UNBOUND 유지=leash로 고립 유지, 마지막 조작캐만 이동) | rule(기존 spec 구현)+impl+tuning | UI-006 §6/§7 구현, F-003 §3.6.2 MIA 거동 정제. anchor 제외·all-MIA-unbound=**전파 후보**(F-003 §3.0.4 stand-in 선정). 타이밍 3/8/5s·PIP 크기=tuning | IMPLEMENTED (일부 전파 후보) |
| 031 | **F-007 탈출 정산 + 결속 게이트 + 전멸 실패**: ExtractionActivate 완료→정산 파이프라인(생존/ExtractCasualty + 런인벤 At-Risk→Safe), Partial 동일·추가 메타벌 없음 / extractionCohesionRule(§3.6.2): 생존자 MIA/이탈 시 채널 0에서 "집합 필요" 정지(런 지속) / PartyWipe→Run Failure(§3.7.1): At-Risk=Loss Bundle, 장착 Identity Gear=Safe / 정산 화면(§3.8): 카테고리 요약 + 스크롤 상세 | rule(기존 spec 구현)+impl+tuning | F-007 §3.6/§3.6.1/§3.7.1/§3.6.2/§3.8 구현. Recovery Target 영속·월드마커·RecoverActivate/Loot UI 보류. COHESION_RULE 데모 on(Contract 기본 false)·채널 5/30s=tuning | IMPLEMENTED (Recovery 보류) |
| 032 | **횃불(ENT-TORCH) 들기/던지기 + 광원화 + 화염 어그로 + 시야밖 피격 수색**: 횃불=carriable 점화체(F-interact→소모품 슬롯, 빈슬롯 자동·풀이면 선택, 발동=지면조준 투척→착지 점화+소모), 들고 기름 접촉 즉시 점화 / 횃불이 방 광원(천장 omni 그리드 대체, 동적조명) / 던지거나 들고 점화한 화염·폭발이 적 때리면 **던진 주체에게 threat** / **시야 밖 피격(어떤 수단이든)→공격자 방향 investigate 수색** | rule(기존 spec 구현)+impl+tuning | F-021 §3.1.2(carry/투척/torch+oil)·F-027 ENT-TORCH·F-011/F-013(수색) 구현. 아군 능동 carry/투척·화염 source 어그로·시야밖 수색=전파 후보. 적 carry/몬스터 세트(증분2) 후속. 광원·수치=tuning | IMPLEMENTED (아군측; 적 carry 후속) |
| 033 | **적 횃불꾼(EN-014) + 제네릭 적-오브젝트 프로토콜 + 랜턴/토치 분리 (증분2)**: `interacts_with_objects` 적이 group interactable 중 `enemy_usable()` 오브젝트 탐색→`enemy_use`(들기); 든 오브젝트가 `enemy_combat_tick()`으로 행동(토치=접근→텔레그래프→투척). 행동이 오브젝트 내부라 신규 오브젝트는 적 코드 무수정·체스트=enemy_usable 미구현→자동 제외 / 방 조명=고정 랜턴(줍기 불가), 토치=기름 코트 4개만 | rule(기존 spec 구현)+impl+content | F-021 §3.1.2 적 carry/투척·EN-COR-000 구현. EN-014=신규 데모 적(spec 정합=1b). 제네릭 프로토콜=확장 아키텍처. 랜턴·수치=impl/tuning | IMPLEMENTED |
| 034 | **배치 허브(F-010 §3.2 / UI-005 / F-003) — 스태시 로드아웃 편집 + 반입 At-Risk + 포메이션 편집**: 메뉴에 InventoryUI(combat=null→장착 허용) + 정적 허브 파티 임베드 → 스태시(소유 gear/스킬북/소모품)를 컨테이너로 띄워 캐릭터 Q/E/R·장착·백팩 드래그. **탑다운 드래그 포메이션 에디터**(4 역할 토큰→슬롯 오프셋). Deploy 시 멤버 서브+백팩+포메이션 직렬화→RunLoadout→dungeon_run 적용(At-Risk 시작→정산 연동, 슬롯 오프셋 오버라이드). 소모품 스택10·Ctrl클릭 분해팝업·드래그 합치기. 오토로드 런타임 경로 접근 | rule(기존 spec 구현)+impl | F-010 §3.2·UI-005·F-007 At-Risk·F-003 슬롯 오프셋 구현. 스태시 시드·스택수치·CLAMP/SCALE=content/tuning | IMPLEMENTED |
| 039 | **P2-S1 던전 스케일 — spawn resolver(LDG-SPAWN-DEMO-001) + 다층맵(≥12룸 Upper/Mid/Deep) + ENC 9·EN 6 스텁** | scope/impl + content(stub) | (pool×difficulty×world_layer) resolver·force override 구현; ROOM_SPECS 절차확장(placeholder 기하 유지=DEBT-DM3); EN/ENC 스텁 kit·전투폴리시=P2-S2. Recovery 이연(DRIFT-031) | 🔸 IMPLEMENTED (헤드리스 검증; 인터랙티브 Hard 플레이 스모크 user-pending) |

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

### DRIFT-006 — abilities.json 검증 누락 (코드 가드 버그) ✅ RESOLVED (P3)
- `slice01_data._parse_abilities()`가 `require_id` 미수행. `id_registry.ability_ids`엔 IDA-020/024/025/026만 → AB-001/002/010/011/015/016·AB-S0x가 "미등록 ID→abort" 우회. `sub_ability_id`도 미검증이었음.
- **처리(P3):** ① `id_registry.ability_ids`에 사용중 14개 AB-### 등록(`_note`로 AB-S0x 비-spec 표기) ② `_parse_abilities`에 `require_id` 루프 ③ `_parse_identities`에 `sub_ability_id` 검증 추가. 헤드리스 로드 검증 통과(등록 누락 시 abort했을 것).

### DRIFT-007~011 — 수치 드리프트 (tuning, 로깅만)
- IDA-020(cd6→8·base80→120·cap160→280·dur4→5·pulse90→60), IDA-024(cd4→7·perhit0.35→1.0·3타 단발붕괴), IDA-025(cd5→9·mult7→12·텔레그래프/환급 없음), IDA-026(cd7→6·r4→5·heal12%→10%·임계 85/90→90/95), 적HP 인플레(EN-001 760 등).
- **적 이속(2026-06-08):** 2.0~5.0 → **7.5~9.5** (조작 9.0 대비 near-equal). 이유: 적이 느려 무시·도망 전략이 통함 → 카이팅 차단. 아키타입 유지. spec 무관(F-025 §11 tuning).
- **템포 ×2/3 + 감속(2026-06-08):** 전 이동체 이속 ×2/3 — 파티 조작 9→6·추종 13→8.7·근접 9.5→6.3, 적 7.5~9.5→**5.0~6.3** (비율유지 → 카이팅방지 유지). 조작캐 감속 45→**200**(빙판느낌 제거; 가속 25 유지). `formation.json`·`enemies.json`, spec 무관 tuning.
- **팔로워 catch-up 재조정(2026-06-09):** 반응성을 최고속도 대신 가속도로 — 추종 far 8.7→**6.6**(조작 6.0 근처 마진만), `follower_accel` 50→**70**. 조작캐 이동 방향별 속도(W 1.0/A·D 0.75/S 0.65) 추가.
- 스펙 어빌리티/적 수치는 모두 **"design example, runtime SSOT 아님"** → 위반 아님. ChangeProtocol §5-d: 튜닝은 마일스톤에서만 선택적 반영.
- **로깅 사유:** 수치 인플레가 *과강한 자작 서브/Identity 보정*에서 비롯됨(PHASE5 §60/63). DRIFT-001/004 정리 후 ENC-NORM-001 기준으로 **재산출**할 것.

### DRIFT-008/009 폴리시 갭 (BACKLOG)
- IDA-024 3타 순차 sweep·"적 전멸 시 잔여타 취소", IDA-025 0.5s 표식 텔레그래프·실패시 쿨 50% 환급 — 게임 자체 CP4 미완 항목. 1b 폴리시로 구현.

### DRIFT-012 — 문서 오타 (SCHEDULED P4)
- `DIFFICULTY_OPTIONS.md`가 ENC-NORM-001 구성에 EN-013 포함이라 기술(실제는 EN-012). 문구만 수정.

### DRIFT-015 — 맵 장애물 + LOS 가림 (F-011 선행 구현)
- **구현(2026-06-08):** 맵에 엄폐 장애물 3종(기둥/상자/바리어, `map_demo_layout` OBSTACLE_SPECS, navmesh 자동 우회) + **파티 합집합 LOS 가림**(`enemy_visibility.gd`: 살아있는 파티원 중 한 명이라도 LOS 있으면 적 표시; 없으면 `enemy_unit.set_seen` 알파 페이드아웃 + `last_seen_pos` 저장).
- **F-011 관계:** Vision & Information War(파티 광원 합집합·perceptionProfile·Patrol·Threat Memory)는 QA-031 Non-goal/Expansion(보류). 본 구현은 그 **occlusion-only 토대** — perception/patrol/광원합집합/마커는 미구현.
- **결정:** 풀 F-011 착수 시 본 구현을 그 위에 확장(관측자=합집합 그대로, last_seen_pos→마커, 장애물→그림자 캐스터). spec 전파는 F-011 정식화 때 OPS_30. 현재는 impl 토대 + 맵 LevelContent(Local edit).

### DRIFT-013/014 — 비위반 / 1b 갭 (LOGGED)
- 013: 아군간 물리충돌 제거 — spec 조항 없음(스티어링 스태킹 방지용). F-003 정밀검증(QA-003) 시 재검토.
- 014: 파티전멸=Run Failure(F-007 §3.7.1)는 실제 규칙이나 QA-030 Non-goal로 1a 보류. 1b에서 "4 down→Run Failure" 저비용 추가 권장.

### DRIFT-026 — 스킬북 시스템 (Track B 구현; per-kill 전파 MERGED) 🔸 IMPLEMENTED
- **구현(2026-06-11):** F-009 스킬북 경제 게임 구현. `skillbooks.json` 3종(`AB-002` Shield Bash/Tank · `AB-010` Venom Spit/Nuker·Healer · `AB-011` Toll Stun/Tank·DPS = 적 lootable AB **Shared**). 적 처치 시 그 적의 lootable AB 확률 드랍(`enemy_defeated` AB refs 전파 → `dungeon_run._roll_loot_def`) → 백팩 **At-Risk** 1×1. `party_member.skillbook_slots[3]`(Q/E/R), `ability_dispatch.cast_skillbook`(탄수−1·쿨다운, 자기중심 AoE), Q/E/R 입력. 인벤 SUB 슬롯 UI(조작캐 3슬롯·클래스 게이트·드래그/우클릭·녹적 프리뷰·탄수 표시), `controlled_sheet` 탄수/쿨 표시. **Identity 고정서브 제거**(`_bind_gear` sub 바인딩 삭제) → 서브 전부 스킬북(F-009 §3.1).
- **전파/분류:** 드랍 트리거 **per-kill** + 서브 3슬롯은 **rule = 전파됨**(`DEC-20260611-002`, staging `c795fee`; D-018 §7.4 per-kill·F-009 §3.6·QA-009 §2.5). equip이어도 At-Risk(§3.7)·클래스 게이트(§3.2.1)·탄수(D-018)는 기존 spec 정합.
- **tuning/impl(전파금지):** `charges_max` 8/10/6 (spec 권장 50~80 — "제약적" 데모 체감 위해 하향, ChangeProtocol §5-d). `SKILLBOOK_DROP_CHANCE` 0.85 · `GEAR_DROP_CHANCE` 0.08(던전런 ~2회) (spec 예 8~15% — 데모 밸런스). cast 효과 **프록시**: 적 poison/stun 미모델 → poison=업프론트 버스트+slow, stun=near-freeze slow(`apply_slow(0.05, stun_s)`). 캐스트는 지면조준 없이 자기중심 AoE(데모 단순화).
- **DRIFT-001 관계:** 자작 서브 `AB-S01~04`는 이제 **미사용**(서브=스킬북 구동, spec 모델 정합). DRIFT-001 "AB-S0x→spec 서브 정합" 과제는 본 구현으로 **실질 대체**(Shared 적 AB 3종 사용); AB-S01~04 정의는 abilities.json에 잔존(orphan, 후속 정리 가능).
- **잔여:** 추출 정산이 At-Risk 스킬북을 실제 Safe/Loss로 처리하는 F-007 배선 미구현(장비와 동일). 분석·상점·affix·tier(F-009 §3.3/§3.5)는 허브 메타 후속. 풀 D-018 인스턴스(instanceId·affix)·Range/Family 게이트 미구현.

### DRIFT-028 — Fatal 장판 트랩 + MIA(비결속 leash/복귀실패) + navmesh carve + 레버 🔸 IMPLEMENTED
- **구현(2026-06-11):** B-시퀀스(함정→분리→MIA→레버). 대부분 **기존 spec 구현**.
  - **치명 장판**(`run/hazard_zone.gd`): 지속 틱데미지 지면 영역, **텔레그래프(주황 경고)→치사(빨강)**, 안의 **모든 유닛 피해**(피아무구분 `F-021`). y=0.4·`render_priority` 2(시야콘 깊이 위). `clear_zone`/`contains_point`/`blocks_segment`.
  - **초크포인트 트랩**(`run/trap.gd`): 조작 멤버가 압력판 통과→뒤(남)에 장판 스폰→후미 차단(분리). `reset()`=장판 소거+재무장. `RM-ROUTE-01`(6m 통로) 배치.
  - **레버**(`run/lever.gd`): 상호작용→`trap.reset()`=**함정 회복**(장판 해제·통로 재개).
  - **fatal 회피**(`party_controller._clamp_fatal`): 후미·비조작 앵커는 치사 반경 밖 stand-off(1.6m)에 hold(인입속도 0+부드러운 밀어내기, 조작캐 예외). `F-004` §3.1.1 정합.
  - **navmesh carve**(`map_demo_layout`): 장판 스폰/소거 시 navmesh **재bake** + 장판 원을 **carve**(벽처럼, `add_projected_obstruction`)→pathfinding 우회/단절. `F-004` §3.3(거리=nav 경로; 단절→hold/MIA) 정합.
  - **MIA 양경로**(`party_controller._update_mia`; `party_member` `_mia`/`_warn`+마커; `party_sheet` 틴트):
    - **(B) 비결속 leash**(`F-003` §3.3.1): 파티비결속·비전투에서 앵커(지휘권 보유자) **직선거리 > leash**→**즉시 경계 링** + **1s 경고**(노란 틴트) + **5s MIA**. **조작캐도 대상**→MIA 시 **컨트롤 앵커로 강제 이전**(`_force_control_off`).
    - **(A) 복귀실패**(`F-003` §3.6.2/`F-004` §3.3): 비조작 멤버의 앵커 **nav 경로 도달거리** 초과/단절(carve)→MIA.
    - MIA=**스왑락**(`F-001` §3.6, `try_swap_to`)·**hold**(`F-004` §3.4). 전투 중 거리-MIA 동결(§3.3.1). 범위 내 복귀/도달 가능 시 즉시 해제.
- **분류/전파:** 대부분 **기존 spec 구현**(F-006/F-004/F-003/F-001 — 전파 불필요, `ImplDecisionLog`). **트랩-분리 + 레버 회복 gimmick**은 신규 데모 콘텐츠(키-게이트 `GIMMICK-DEMO-01`와 동급) → **전파 후보**(향후 `DBP-DEMO-001`/`F-006` 트랩 타입). navmesh carve는 impl.
- **tuning(전파금지):** 장판 dps 90·반경 4·텔레그래프 0.8s, leash **20m**(spec 예 12m), 경고 1s·MIA 5s(spec t_mia 3s), stand-off 1.6m·flee 4.5, MIA recheck 0.2s.
- **잔여:** `UI-006` 분리경고/PIP·`UI-008` 지휘권 전환 미구현(틴트+링+콘솔로 대체). 트랩 타입 카탈로그·일반 gimmick 후속. 열린공간 우회는 carve로 정확(통로는 단절→MIA).

### DRIFT-029 — 기름 배럴 + 화염 연쇄(RX-OIL-FIRE) + 디버프 핍 + 서브 클래스 페널티 🔸 IMPLEMENTED
- **구현(2026-06-12):** 환경 상호작용 A체인 (F-027/F-021 기존 spec 구현).
  - **zone 일반화**(`run/hazard_zone.gd`): `status`(Fatal/Oil/Fire/ToxicGas)·`impassable`(Fatal만 carve/회피)·`ttl`·`slow_factor`. 그룹 `ground_zone`(전체)/`fatal_zone`(impassable). DoT(Fire/ToxicGas)는 **파티=`apply_poison`(핍)·적=raw**.
  - **배럴**(`run/barrel.gd`, `ENT-BARREL-001`): HP 40 파괴(AoE `ability_dispatch._damage_destructibles`)→**기름 장판**(`ZONE-OIL`, 통과 가능·**슬로우 0.5**·지속).
  - **기름=슬로우 필드**(피아무구분): `party_member.apply_slow`+`move_speed_mult`→player/party_controller 이동 반영(적 기존 `apply_slow`).
  - **화염 스킬북**(`AB-037 Ember Lance`; `equipClasses [DPS,Nuker]` Shared lootable, id_registry 추가): 조준 화염 AoE→`_sb_fire`→`_fire_hit`.
  - **RX-OIL-FIRE-001**(`ability_dispatch._ignite_oil`): 기름+`FireDamageHit`→기름 소모+**폭발(피아무구분)**+**화염 장판(DoT)**+**독안개(DoT)**+인접 기름 **연쇄**(depth ≤ 2, F-021 §3.2.1).
  - **디버프 핍**(`party_member.get_status_list`+`party_sheet`): 슬로우(하늘색)·DoT(초록). **파티시트 서브슬롯** 픽스(옛 `sub_params`→`skillbook_slots` Q/E/R).
  - **서브 클래스 페널티**(F-009 §3.2.1 Family Mismatch): main=`equipClasses[0]`, 비주력 시전 데미지 **×0.9(−10%)** + `controlled_sheet` 슬롯 **주황·▼·툴팁** 경고.
- **분류/전파:** **기존 spec 구현**(F-027 RX-OIL-FIRE-001/ENT-BARREL-001/ZONE-OIL, F-021 ZONE·연쇄, D-016 AB-037, F-009 §3.2.1) — 전파 불필요(`ImplDecisionLog`). 신규 콘텐츠 ID 없음(AB-037=spec 등재, id_registry 추가만).
- **tuning/impl(전파금지):** 배럴 HP 40·기름 슬로우 0.5·화염 dps 14·독안개 8·폭발 60·연쇄 depth 2·페널티 −10%·Ember cd 5(spec 6). **main=first-equip-class**는 휴리스틱(spec 정식=skillFamily∈preferredFamilies). DoT는 poison 상태 재사용(화염·독안개 핍 미구분·실드 우회·비스택).
- **잔여:** 화염/독안개 별도 status(색 구분)·스택·실드 흡수·배럴 navmesh 미반영. F-009 Range Gate·affix·tier 미구현. Water/Vegetation 등 기타 환경 RX 미구현.

### DRIFT-030 — MIA 대응 UI(UI-006) 정식화 + 다중 MIA 모집지점 픽스 🔸 IMPLEMENTED
- **구현(2026-06-12):** C-시퀀스(MIA 대응 UI). 대부분 **기존 spec(UI-006) 구현**.
  - **중앙 분리경고 배너**(`dungeon_run._alert_banner`/`_on_party_alert`/`_hide_alert`): MIA·이탈경고 시 화면 상단 중앙 경고(레벨별 색·`_alert_token` 디바운스·자동 숨김). 멘트 "파티 범위로 복귀하세요"(경고)/"집합 필요"·"조작 전환 → X"(MIA). `party_controller.party_alert(text, level)` 시그널 구동.
  - **PIP 카메라**(`ui/pip_camera.gd`, UI-006 §7): SubViewport+Camera3D가 `root.world_3d` 공유(같은 씬/광원), 좌하단. `party_controller.pip_targets(members)` 구동 — **MIA 대상(강제 조작전환 후)** 표시(§7.4-1).
    - **자동 라이프사이클**(§7.6): 자동오픈→**0~3s 강조**(테두리 굵게·밝은 주황)→**3~8s 저강조 확장**→**8s 자동 최소화**. 원인(MIA) 지속 중 **최소화 유지**(완전 닫힘 안 함), 해소(빈 리스트)→**자동 닫힘+리셋**.
    - **수동 오버라이드**(§7.7): 수동 확장→`_manual_hold`로 **자동최소화 타이머 일시중단**. 수동 닫기(`×`)→숨김+**5s 재오픈 쿨다운**(해당 대상만 억제, 다른 MIA는 표시; 쿨다운 후 여전히 MIA면 재오픈).
    - **다중 MIA**(§7.8): 확장 PIP는 1개 유지, `▶`로 대상 순환·라벨 "(i/n)". 최소화 시 `+`만 노출.
  - **MIA 모집지점 픽스(2건)**(`party_controller`):
    - `_member_valid`에 **MIA 제외** 추가 → MIA 멤버가 **랠리 앵커·지휘권 보유자·stand-in으로 선정 안 됨**(재집결지점이 고립된 MIA로 끌려가 꼬이던 문제 해소).
    - `_has_living_noncontrolled`: 비조작이 **전부 MIA여도 "살아있음"** → `_update_command_holder`가 **BOUND 폴백 안 함**(UNBOUND 유지). 앵커=조작캐 폴백으로 leash가 MIA들을 계속 잡아 **전원 MIA 고립 유지·마지막 조작캐만 이동**. BOUND 폴백은 비조작 **전원 사망** 시에만(§3.4 #4).
- **분류/전파:** 대부분 **기존 spec 구현**(UI-006 §6/§7, F-003 §3.6.2 — 전파 불필요, `ImplDecisionLog`). **MIA=앵커/stand-in 제외**·**all-MIA→UNBOUND 유지**는 F-003 §3.0.4(분리 모델)의 stand-in 선정 규칙을 구체화 → **전파 후보**(stand-in은 도달가능·비-MIA 멤버에서만 선정; 후보 전무 시 BOUND는 전원 사망에 한정).
- **tuning(전파금지):** PIP 강조 3s·자동최소화 8s·재오픈 쿨다운 5s, PIP 크기(확장 248×160·최소 96×62), 배너 디바운스·레벨별 색.
- **잔여:** PIP §7.2 정보범위(현재 위치추종 단순 카메라·벽너머 가림 미구현)·§7.8 우선순위 정렬(현재 MIA 진입순)·§7.5 파티시트 PIP 아이콘/단축키 수동오픈 미구현. DRIFT-028 잔여(UI-006 분리경고/PIP)는 본 항목으로 해소.

### DRIFT-031 — F-007 탈출 정산 + 결속 게이트 + 전멸 실패 🔸 IMPLEMENTED
- **구현(2026-06-13):** C-시퀀스(탈출 정산). 탈출 스텁(`run_ended("Success")`)을 **F-007 정산 파이프라인**으로 교체.
  - **정산 finalizer**(`run_controller`): `try_extract` 스텁 → `can_extract()`(목표 게이트) + `settle_extraction(summary)`/`settle_failure(cause, summary)` + `run_settled(summary)` 시그널. run_over·결과 SSOT.
  - **Extraction Success**(`dungeon_run._settle_extraction`, §3.6/§3.6.1): 채널 완료 시 파티 생존/ExtractCasualty 분류 + **런 인벤 At-Risk → Safe**(`inventory_ui.mark_run_inventory_safe`). 사망자 있으면 **Partial Extraction Success**(루트 전량 Safe 동일·추가 메타 벌 없음).
  - **At-Risk 집합**: 백팩 전체(gear/skillbook/consumable) + **장착 스킬북**(F-009 §3.7). **장착 Identity Gear 모듈=Safe**(허브 메타, 제외).
  - **결속 게이트**(§3.6.2 `extractionCohesionRule`): 채널 완료 시점 **생존 파티원이 MIA/이탈(경고)** 중이면 카운트가 **0에서 "집합 필요"로 정지**(완료 불가·런 지속·실패 아님). 합류 시 완료. 데모 `COHESION_RULE=true`(spec Contract 기본 false).
  - **PartyWipe → Run Failure**(§3.7.1): 비조작 포함 전원 ExtractCasualty(`_is_party_wiped`)→`settle_failure("PartyWipe")`. 런 인벤 At-Risk=**Loss Bundle**(회수 후보), 장착 Gear=Safe 유지.
  - **정산 화면**(§3.8, `_show_settlement`/`_build_settlement_panel`): 전용 중앙 패널(고정 520×440). 결과별 색(녹색/주황빨강) + 생존/ExtractCasualty 요약 + **카테고리 요약**(장비·스킬북·소모품·총) + **스크롤 상세 박스**(항목 초과분 흡수) + 장착 Gear=Safe. 옛 ResultBanner(font 56)는 미사용.
- **분류/전파:** **기존 spec 구현**(F-007 §3.6/§3.6.1/§3.7.1/§3.6.2/§3.8 — 전파 불필요, `ImplDecisionLog`). 정산 단위(공용 런 인벤)·At-Risk/Safe 전이·Partial·PartyWipe 분기 모두 SSOT 정합.
- **tuning/impl(전파금지):** `COHESION_RULE` 데모 on(Contract 기본 false), 채널 5/30s(DRIFT-020), 패널 크기·폰트·카테고리 라벨. At-Risk→Safe는 **인메모리**(허브/계정 영속 없음) — 정산은 화면 표시 + 백팩 flag flip(런 종료라 사실상 표시용).
- **보류(다음 증분):** Recovery Target 프로필 슬롯·Anchor 스냅샷·월드 Marker·RecoverActivate/Recovery Loot UI·mapId 재방문·MainBossRaid·배치단계 리스크 프리뷰(UI-005)·extractionEndsRecoveryOpportunity·haulMaterial — 즉 **실패 후 회수 루프 전체**가 보류(정산 분기만 구현). DRIFT-014(파티전멸=Run Failure 없음) 본 항목으로 해소.

### DRIFT-032 — 횃불(ENT-TORCH) carry/투척 + 광원화 + 화염 어그로 + 시야밖 피격 수색 🔸 IMPLEMENTED
- **구현(2026-06-13):** 환경 상호작용 — 횃불(증분1 아군측). F-021 §3.1.2 / F-027 / F-011·F-013 기존 spec 구현.
  - **횃불 오브젝트**(`run/torch.gd`, ENT-TORCH-001): group interactable+carriable+torch. PLACED↔CARRIED↔THROWN. 항상 점화체 — 활성 중 Oil 존 접촉 시 즉시 `ignite_at`(들고 기름 밟으면 폭발, 리스크). **던지면 착지 점화 후 소모(파괴)**; 운반 캐 사망 시 발밑에 떨어뜨림(재획득).
  - **점화 일원화**(`ability_dispatch.ignite_at` + `combat_controller` 포워더): Fire 존 스폰 + `_fire_hit`(Oil→RX-OIL-FIRE). = F-027 ENT-TORCH→FireDamageHit.
  - **아군 carry/투척**(`dungeon_run`): F-interact→`pickup_requested`→**빈 소모품 슬롯 자동 배정**(꽉 차면 Z/X/C 선택)→그 슬롯 키=**지면 조준 투척**(스킬북 조준 재사용)→`throw_to`→아크→착지 점화. ConsumableBar carry 오버레이(refresh가 carry 슬롯 스킵).
  - **광원화**(`torch.gd` OmniLight + `map_demo_layout`): 방 조명을 **천장 omni 그리드 → 횃불 브레이저 그리드로 대체**(간격 20m·따뜻한 톤·energy×0.6). 들고/던지면 광원도 이동 = 동적 조명. unlit 방 0개.
  - **화염 어그로**(source 전파: `ignite_at`/`_fire_hit`/`_ignite_oil`/`_explosion` + `hazard_zone.set_source`): 던지거나 들고 점화한 **Fire·독안개 DoT + 폭발이 적을 때리면 던진 주체에게 threat**. Ember Lance 화염도 시전자 어그로(정합).
  - **시야 밖 피격 수색**(`enemy_unit.perceive_attacker` + `enemy_ai`): **어떤 수단이든** 적이 피해를 받으면(직접/장판 DoT/폭발) **교전 + 공격자 방향(search_pos) 기록**, 교전 중 타겟에 LOS 없으면 그 방향으로 investigate 이동·수색 → 못 찾으면 grace(6s) 만료 포기. 공격자 보이면 기존 추격(수색 무시).
- **분류/전파:** **기존 spec 구현**(F-021 §3.1.2 carry/투척/torch+oil·§3.3.1 피아무구분, F-027 ENT-TORCH, F-011/F-013 인지·수색 — 전파 불필요, `ImplDecisionLog`). **전파 후보 3종**: ① 아군 **능동 carry/투척 툴**(F-021은 파티 연쇄를 "부수적"으로 규정, 능동 툴 명시 없음) ② 환경 화염의 **source 어그로 귀속** ③ **시야 밖 피격→공격자 방향 수색** 규칙(F-013 상태머신 명시). ENT-TORCH는 코드 const(배럴처럼 id_registry 비대상).
- **tuning/impl(전파금지):** 횃불 light energy 1.6·range 13·grid 20m·energy×0.6, IGNITE_RADIUS 2.4·THROW_DUR 0.55·ARC 2.5, SEARCH_GRACE 6s, 화염 어그로=DoT/폭발 dmg 그대로 threat.
- **잔여(증분2):** **적 carry/투척 + `prefers_objects` 오브젝트-우선 몬스터 세트**(F-021 §3.1.2 적측·EN-COR-000) 미구현. 스왑 중 횃불 거동(원 운반자 추종)·횃불 navmesh 미반영.

### DRIFT-033 — 적 횃불꾼(EN-014) + 제네릭 적-오브젝트 프로토콜 + 랜턴/토치 분리 (증분2) 🔸 IMPLEMENTED
- **구현(2026-06-13):** DRIFT-032 잔여(증분2 적측). F-021 §3.1.2 기존 spec.
  - **EN-014 "Torch Bearer"**(enemies.json·id_registry·ENC-NORM-001): `interacts_with_objects:true` fodder(HP280·평타 AB-015 — RX 없이도 처치 가능). RM-ADV-01 코트.
  - **제네릭 적-오브젝트 프로토콜**(덕타이핑, 플레이어 interactable 계약과 유사):
    - `enemy_ai._try_object_interaction`(교전 tick): 든 오브젝트(`held_object`)면 `held.enemy_combat_tick(enemy, target, has_los, delta)` 위임 / 없으면 group `interactable` 중 **`enemy_usable()`=true** 최근접 탐색(16m)→접근→`obj.enemy_use(enemy)`. **토치 특정 코드 0줄.**
    - **오브젝트가 행동 소유**(torch.gd): `enemy_usable()`(=is_available)·`enemy_use(enemy)`(=pick_up + `enemy.held_object=self`)·`enemy_combat_tick`(=투척 사거리 11m 접근→텔레그래프 0.7s→`throw_to(타겟)`). 신규 상호작용 오브젝트는 이 3메서드만 구현하면 **적 AI 무수정**으로 사용됨.
    - **체스트 자동 제외**: `enemy_usable()` 미구현 → 탐색서 빠짐(예외처리 불요).
    - `enemy_unit.nav_move_toward(dest, speed)` 헬퍼 노출(오브젝트가 운반자 접근이동 구동), `_nav_move`가 위임.
  - **랜턴/토치 분리**(`run/lantern.gd` 신규): 방 조명 그리드=**고정 랜턴**(carry/interactable/enemy_usable 미구현→줍기 불가·점화 안 함, 방 안 어두워짐). 줍기 가능 **토치는 기름 배럴 코트 4개만** 손배치(carry/투척+RX 게임플레이 지점). 적이 토치만 집어 던지므로 방 조명 유지.
  - **시각 차별화**: 랜턴=받침+긴 기둥+갇힌 박스 함체+지붕캡·옅은 금빛 정상광. 토치=콘 불꽃·뜨거운 주황·깜빡임(live fire).
- **분류/전파:** **기존 spec 구현**(F-021 §3.1.2 적 carry/투척·torch+oil — 전파 불필요, `ImplDecisionLog`). **EN-014=신규 데모 적 id**(id_registry; spec **EN-COR-000** 정합=1b 콘텐츠 과제). **제네릭 enemy-object 프로토콜**=확장 아키텍처(impl).
- **tuning/content(전파금지):** seek 16m·reach 1.6m·throw 11m·windup 0.7s, EN-014 stats·ENC-NORM-001 편성(5→6), 랜턴/토치 비주얼·색·깜빡. 투척=타겟 위치(기름 콤보=포지셔닝 창발).
- **잔여:** 적 투척 텔레그래프=착지마킹만(전용 애니 없음). 다중 토치 저글링·경합=최근접 단순. 적 화염 타 적 타격 시 perceive 엣지(무해).

### DRIFT-034 — 배치 허브(F-010 §3.2 / UI-005 / F-003) — 스태시 로드아웃 편집 + 반입 At-Risk + 포메이션 🔸 IMPLEMENTED
- **구현(2026-06-13):** 추출 루프 앞단(배치). F-010 §3.2 / UI-005 / F-007 기존 spec.
  - **스태시**(`autoload/stash.gd`): 소유 gear 4종·스킬북 4종·부활스크롤 8 시드. take/return.
  - **허브**(`main.gd`): 메뉴에 `PartyController`(processing off, `$Members` 주입) + `InventoryUI`(`setup_party(party, null)`→combat=null이라 장착 허용) 임베드. **스태시를 InventoryUI 컨테이너로**(`stash_source.gd`, chest 덕타이핑) 오픈 → 캐릭터 Q/E/R·Identity Gear·백팩 **드래그(기존 재사용)**. 편집 버튼은 Identity 확정 위.
  - **Deploy 직렬화/적용**: 멤버별 장착 서브 + 백팩 반입품 → `RunLoadout`(autoload) → `dungeon_run`이 시작 시 적용(`party_member.equip_skillbook_by_id`·`add_*_to_backpack`). 반입품=**At-Risk 시작 → 탈출 Safe / 실패 Loss Bundle**(F-007 정산 연동).
  - **인벤 스택 메커닉**: 부활스크롤 max_stack 3→**10**. **Ctrl+클릭→분해 수량 팝업**(SpinBox)→N개 새 스택. **드래그 합치기**(같은 id 스택 위 → ≤max_stack, 잔량 원위치). `InventoryGrid.item_at` 추가.
  - **포메이션 편집(③·F-003)**: 탑다운 드래그 에디터(`formation_editor.gd`, Panel)에 4 역할 토큰(중앙=리더/앵커, +z=전방). 드래그→슬롯 오프셋(±3.6m clamp). `party_controller.get/set_slot_offset`로 SSOT(`_slot_offsets`) 읽기/오버라이드. Deploy 직렬화 `RunLoadout.formation`=[{class_id, offset:[x,z]}] → `dungeon_run`이 스폰 후 `set_slot_offset` 적용(formation.json 기본 위에 덮어씀).
  - **오토로드 런타임 접근**: `Stash`/`RunLoadout`을 파스타임 전역 대신 `get_node("/root/...")`로 — 에디터가 새 오토로드 미등록이어도 컴파일·실행(런타임 로드). 에디터 리로드 불필요.
- **분류/전파:** **기존 spec 구현**(F-010 §3.2 Consumable Selection/Risk Budget·Deployment Loadout, UI-005 pre-dungeon, F-007 At-Risk — 전파 불필요, `ImplDecisionLog`). 허브 재사용(party+InventoryUI)·스택 분해/합치기=impl 아키텍처/UX. 신규 content id 없음.
- **tuning/content:** 스태시 시드 구성, max_stack 10, 분해 팝업 기본=절반, 포메이션 CLAMP_M 3.6·SCALE 28px/m. v1 소모품 -/+ 셀렉터는 스태시 드래그로 통일(제거).
- **잔여:** 포메이션은 슬롯 **오프셋**만(class별 위치) — leader/subleader **명시 지정**(UI-008)·역할↔슬롯 재배정은 미구현. 스태시 비-소모 영속(데모는 비고갈). 인벤은 오버레이(컨펌은 메뉴 버튼 순서로만 위/아래). gear 스왑은 역할당 1종이라 제한적.

### DRIFT-020 — 전투AI/인지 튜닝수치 (LOGGED, 전파금지)
- FOV 160° · sight_range 12m · proximity 2.5m · alert_zone_frac 0.2 · scan ±35°/4s · investigate_speed 0.35 · chase_blind 0.55 · squad_prop_radius 9m · combat_exit_grace 6s · squad_lane 12m · cone alpha 0.05~0.06.
- **탈출 채널(2026-06-10):** POINT-DEMO-01 홀드→Extraction Success. **비전투 5s / 전투중(partyInCombat) 30s** (매 프레임 현재 전투상태로 임계 판정) + 큰 카운트다운 UI(높은 수→1). **F-007 §3.1.2 정합**(ExtractionActivate=채널·홀드, 완료=성공; 채널 시간은 "후속 UI/전투 SSOT"라 tuning). 존 이탈=취소(실패 정산 없음, F-007). `EXTRACT_RADIUS_M` 3m.
- ChangeProtocol §5-d 튜닝 — 전파 금지, 로깅만. `combat_exit_grace_s` 6s는 **D-010 §4.2 초기값과 정합**. F-011 정식화 시 perceptionProfile 기준으로 재산출.

### DRIFT-039 — P2-S1 Dungeon Scale (spawn resolver + 다층맵 + ENC/EN 스텁) 🔸 IMPLEMENTED
- **구현(2026-06-18):** Phase 2 첫 스프린트. slice01 6룸+manifest 3-pool을 spec `LDG-SPAWN-DEMO-001` resolver + 다층 room graph로 확장(기존 자산 리팩터, 신규 빌드 아님).
  - **Spawn resolver**(`spawn_table.json` + `Slice01Data.get_encounter_for_pool(pool, difficulty, world_layer)`): force override(`P-ADV-01→ENC-NORM-001`, DBP §5.1) > 정확 (pool×difficulty×world_layer) > (pool×difficulty) any-layer > "". `_load_encounters`가 spawn 참조 ENC까지 로드. 호출부 2곳(`combat_controller.prespawn_encounters`·`run_controller.on_player_entered_room`) 신 API로 교체.
  - **맵·zone**(`rooms.json`·`map_demo_layout`): room **6→12**, `world_layer` Upper/Mid/Deep. 신규 RM-ADV-03/04/05(Upper)·RM-MID-01·RM-BOSS-01(Mid)·RM-DEEP-01(Deep) — 비겹침·인접엣지 공유(navmesh 244폴리 연결). 임계경로(ENTRY→ADV-01→OBJ 키-게이트→ROUTE→EXT) **불변**. ROOM_SPECS는 **placeholder 절차 기하 유지**(JSON-geometry 이전=DEBT-DM3 여전히 deferred).
  - **ENC 9 + EN 6 스텁**: `ENC-HARD-006/008/009/010/011/012`·`ENC-MID-001`·`ENC-DEEP-001`·`ENC-BOSS-001` JSON(기존 schema). `EN-002/003/004/007/008/009` = placeholder 스탯 + 재사용 basic AB(AB-015/016)로 등록(전투 kit 미구현). id_registry 신규 ID 전부 등록.
  - **Run flow 데이터화**(`run_controller`): `RM-OBJ-01/ROUTE-01/EXT-01` 문자열 분기 제거 → `rooms.json run_phase_on_enter` + `RunPhase.SEQUENCE` 단조전진. RM-ADV-01에 Advance 추가 → **5단계 전환 완결**(D1).
- **헤드리스 검증(Godot 4.5.1):** 데이터 로드 clean · Normal 런 prespawn = NORM-002/NORM-001/MID-001/DEEP-001 스폰 · Hard 런 = NORM-001(force)/HARD-006/008/009/010/011/012/**BOSS-001** 8분대 스폰 · 임계경로 5단계 전환 OK · navmesh 244폴리.
- **분류/전파:** **scope/impl + content(stub).** resolver·world_layer·신규 pool/room은 spec `LDG-SPAWN-DEMO-001`/`DBP-DEMO-001 §5.3·§6`이 이미 정의한 구조의 **구현**(전파 불필요). EN/ENC 스텁은 P2-S2에서 실제 kit으로 대체될 placeholder(로깅).
- **거동 변화(의도):** P-ADV-02는 Normal에서 미스폰(과거 manifest `ENC-HARD-001`)·Hard에서 ENC-HARD-006. ENC-HARD-001은 P-ADV-01 force override에 가려 로드되나 미스폰. `manifest.encounters`는 이제 legacy fallback(resolver가 정본). D4: Normal=MID-001+DEEP-001 / Hard=BOSS-001(+HARD-008 Mid) — 단일 런이 셋 다는 아님(LDG 충실).
- **tuning/impl(전파금지):** EN 스텁 스탯·룸 좌표/치수(placeholder)·lighting(Mid/Deep=dim).
- **잔여:** EN-002/003/004/007/008/009 실제 kit + MID/DEEP/BOSS 전투 폴리시(P2-S2). **인터랙티브 키-게이트→Extract 회귀 + Hard 플레이 스모크(§9.1)는 F5 수동 검증 필요**(구조는 미변경). Recovery 재방문=DRIFT-031 이연.

### DRIFT-040 — P2-S2b Per-enemy 교전 포지셔닝 (PT-### engage 파생 + 이동 PH) 🔸 IMPLEMENTED
- **구현(2026-06-18, IMPL-DEC-20260618-004):** `patterns.json`(D-017/`PT-###` 카탈로그 미러) + `enemy_ai._engage_move` 7-프로필 디스패치(`advance`/`standoff`/`kite`/`zone`/`orbit`/`probe`/`surround`). 적 교전 이동이 아키타입별로 분기(백라인 카이팅·플랭크 arc·zone 고정·서스테인 후퇴·probe 인아웃·swarm 포위).
- **분류/전파:** **impl(구조는 spec) + tuning(파생/수치).** `PT-###`·카탈로그 필드(`formation_role`/`band`/`anchor`/`spacing`/`retreat`)는 spec `patterns/PT-*.md`@`4422e50` verbatim — 구현일 뿐 전파 불필요. **`engage` enum**은 spec "Engaged 우선"(EN-AI-000 §1) 컬럼의 게임측 디스패치 인코딩(spec에 enum 명문 없음) — 정식화 시 D-017/EN-AI-000에 anchorPreference→behavior 매핑을 명문화할지 **사용자 판단** 후보(현재 impl-only 종결).
- **tuning/impl(전파금지):** `MELEE_THREAT_M` 4m(=EN-014 §1 명시)·`ENGAGE_LEASH_M` 18m(=§3 leash default)·`RETREAT_STEP_M` 3·`ZONE_RADIUS_DEFAULT` 8·`ORBIT_ARC_M` 4·`PROBE_BACKSTEP_S` 0.6·`SURROUND_RING_M` 0.9·`chase_speed_mult` 1.1(EN-013). orbit side=instance_id%2·surround angle=instance_id%8(연출 분산).
- **EN-AI-000 §1표 vs EN 유닛문서 불일치:** §1표 "EN-010~013 → PT-010~013"은 loose 참조 — 정본은 각 EN 유닛문서 `patternRef`(**PT-012~015**; PT-010/011은 플레이어 Tank 패턴). 게임은 유닛문서 기준 채택. (스펙 §1표 표기 정합은 spec 측 정리 후보 — 경미, 전파 보류.)
- **잔여:** 시그니처 AB 캐스트·interrupt/channel(EN-AI-000 §2)·AB-007 HP≤50% 후퇴·**거리 leash 이탈**(현 grace-timer)·EN-014 "anchor dead" 조건 = **S2c**. **교전 체감은 F5 수동 검증 잔여**(헤드리스는 부트/스폰/dormant까지).

### DRIFT-041 — P2-S2c(1) 시그니처 캐스트 (AB-004/008/012/098 + channel-freeze) 🔸 IMPLEMENTED
- **구현(2026-06-19, IMPL-DEC-20260619-001):** EN-002 차지(AB-004)·EN-004 스플래시(AB-008)·EN-007 헥스(AB-012)는 기존 every_n+윈드업 경로로, EN-014 힐(AB-098)은 신규 cooldown+condition 패스로 추가. winding+channel 시 제자리(EN-AI-000 §2).
- **분류/전파:** **impl(구조는 spec) + tuning(수치/파생).** AB-### · telegraph_s · cooldown_s · heal 8%/r3 = spec `abilities/AB-*.md` Draft "design examples" 구현. `enemy_charge/splash/hex/heal` kind 네이밍·channel-freeze·splash_frac 0.6 = 게임 인코딩(전파 불필요).
- **tuning/impl(전파금지):** Shock=slow 0.5/2s · HEX-WEAK=slow 0.6/4s · AB-004 dmg×2.0 · AB-008 ×0.8 splash r1.5 · AB-012 ×0.4 · every_n n(EN-002:4·EN-004:3·EN-007:3) · 텔레그래프 색.
- **부분/미구현(정직):** ① **HEX-WEAK "피해 감소" 절반 미구현** — 이동감소(slow)만; 파티 outgoing-damage 훅 필요 → 후속. Shock·Hex 둘 다 slow로 표현(색/지속/소스로 구분). ② AB-008 `chains_to_status: Slippery`·AB-009 Oil SEED·zone 시스템 = 미구현(스플래시 직격만). ③ ~~interrupt-on-channel~~ → **DRIFT-044에서 구현**.
- **잔여:** AB-006/013 대시(mobility) · AB-099 Provoked(party-side 상태) = S2c(2/3). **교전 체감 F5 수동 검증 잔여**.

### DRIFT-042 — P2-S2c(2) 대시 mobility (AB-006/013) 🔸 IMPLEMENTED
- **구현(2026-06-19, IMPL-DEC-20260619-002):** EN-003 Gap-Close(AB-006)·EN-008 Backstab(AB-013) 대시. 텔레그래프(channel-freeze 크라우치)→knockback류 velocity-takeover 런지(`DASH_TIME` 0.2s)→AB-013 도착 1.5x 백스탭. cooldown+condition 트리거(`_try_cast_dash`).
- **분류/전파:** **impl(구조는 spec) + tuning.** AB-006/013·telegraph_s·cooldown_s·×1.5 = spec Draft 구현. `enemy_dash` kind·DASH_TIME/MAX_M(9)/FLANK_OFFSET(1.3)·dash_range_m(10) = 게임 PH/인코딩.
- **부분/미구현(정직):** ① 대시 **벽 라우팅 없음** — straight lunge + `move_and_slide` 충돌정지(navmesh 우회 X, 0.2s라 허용). ② **AB-005 후속 flurry**(PT-003 priority 3, gap-close 후 보조연타)·**AB-007 HP≤50% 후퇴 hop**(PT-003) 미구현. ③ "탱커가 경로 막을 때" 조건은 단순 갭(dist>range)으로 근사 — 탱커 차폐 판정 X.
- **잔여:** AB-099 Provoked = S2c(3). **돌진 체감 F5 잔여**.

### DRIFT-043 — P2-S2c(3) AB-099 Iron Mockery / Provoked 🔸 IMPLEMENTED
- **구현(2026-06-19, IMPL-DEC-20260619-003):** EN-001 전방 60°/4m 부채꼴 도발(`enemy_provoke`, channel 0.85s, 쿨 14s) → 신규 party-side `Provoked` 상태(이동·스킬 잠금 + 시전자 강제 평타, 2s, 멤버 귀속·스왑 허용, Stunned 우선). 게이트 4곳(combat_controller·player_controller·party_controller·dungeon_run sub-key).
- **분류/전파:** **impl(구조는 spec) + tuning.** AB-099 수치(telegraph/cd/zone/dur)·스왑허용·Stunned우선 = spec `AB-099` Draft 그대로. `enemy_provoke` kind·강제 접근 이동·존 facing(resolve 시점, 채널-freeze라 cast-start≈동일) = 게임 인코딩.
- **미구현(정직):** ① ~~interrupt-on-channel~~ → **DRIFT-044에서 구현**(Toll Stun으로 Mockery 채널 끊기 성립). ② **IDA-031 Ward Pulse 클렌즈** 데모 무. ③ 존 anchor = cast-start facing 고정(spec) 대신 resolve facing(채널 freeze로 근사). ④ aim 모달 활성 중 provoke 진입 시 confirm 캐스트가 게이트 우회(희소).
- **잔여:** ~~interrupt/channel 정책(§2)~~ → **DRIFT-044에서 종결**. **존 도발 체감 F5 잔여**.

### DRIFT-044 — P2-S2c(4) 채널 interrupt + 적 stun primitive (EN-AI-000 §2) 🔸 IMPLEMENTED
- **구현(2026-06-19, IMPL-DEC-20260619-004):** 적 `apply_stun`/`is_stunned`/`tick_stun` 신설 + `enemy_ai.tick`이 stun 시 winding/dashing 취소(cast 실패, 쿨 소모 유지) + Toll Stun(`sb_stun`)이 slow 프록시 → 실제 stun. DRIFT-041/042/043의 "interrupt 미구현" 공통 잔여 종결.
- **분류/전파:** **impl(스펙 전제) + tuning.** §2 interrupt 정책·"쿨 전액 소모"는 spec `EN-AI-000` §2 그대로. 적 stun primitive·"모든 winding/dashing 취소"·Toll Stun=실제 stun은 게임 인코딩(스펙이 stun 효과를 전제하나 적 stun 데이터모델은 게임 측).
- **미구현(정직):** AB-004 "쿨 50% 환급"(every_n 구현이라 쿨 자체 없음 → N/A)·적 stun 시각 피드백(freeze만, VFX 무)·dormant 중 stun 미틱(교전 전까지, 희소).
- **잔여:** 적 stun VFX(피격 readability)는 폴리시 후보. **채널-끊기 체감 F5 잔여**.

### DRIFT-045 — P2-S2-fin 조합 ENC 맵확장 + EN-001 mockery per-ENC 토글 미모델 🔸 IMPLEMENTED
- **구현(2026-06-19, IMPL-DEC-20260619-005):** HARD-002/003/004 + Upper 룸 3개(RM-ADV-06/07/08, ADV-03 남쪽 선형 체인). navmesh 244→274.
- **분류/전파:** **impl(스펙 구조 구현) + scope.** ENC 조합·RP는 spec `ENC-HARD-00X` 그대로. 룸 좌표/체인 배치는 데모 placeholder 기하(LDG-SPAWN-DEMO 확장 허용, FullSpecCoverage §4). 전파 불필요.
- **드리프트(경미, rule):** **EN-001 AB-099 Mockery가 유닛 상시 시그니처** — 스펙은 `en001_mockery`를 **per-ENC 토글**(HARD-004/002 default off·HARD-006/009 on, ENC-HARD-### §Template). 게임은 encounter-level ability 게이팅 미모델 → EN-001이 들어간 모든 ENC에서 Mockery 상시. 정식화 시 ① ENC JSON에 `ability_overrides`/`en001_mockery` 필드 + 적 시그니처 조건부 게이트, 또는 ② 스펙이 상시로 단순화. **전파 보류**(per-ENC ability override 시스템 = 후속 결정).
- **스코프:** ENC-HARD-007(Extreme)·HARD-005(phase 증원)·NORM-003(assassin)은 본 증분 제외(각각 deferred/A2/A2). **교전 체감 F5 잔여**.

### DRIFT-046 — P2-S2-fin A2 phase 증원 rear/flank (게임이 스펙 런타임 스코프보다 앞섬) 🔸 IMPLEMENTED
- **구현(2026-06-19, IMPL-DEC-20260619-006):** reinforcement에 direction(rear/flank) 추가 + HARD-010(flank)·HARD-005(rear) phase-2 정합. RM-ADV-09 추가(navmesh 284).
- **분류/전파:** **impl ahead-of-spec.** 스펙 `ENC-HARD-005` non-goal: "Phase-2 spawn 런타임 SSOT = F-006 Population 후속; 본 ENC는 문서 훅만"·HARD-010 "phase spawn = P2-S2". 게임은 이미 reinforcement 런타임(delay·engage-gated·telegraph·rear/flank)을 구현 → **게임이 F-006 phase-spawn 모델을 앞서 구현**. 정식화 시 reinforcement 런타임 모델(delay_s/direction/engage-trigger)을 F-006/ENC-000에 역전파 후보. rear/flank 좌표 오프셋(z−8/x+9)은 데모 PH 튜닝.
- **잔여:** 증원 wave 실제 발동 체감 F5(교전 필요). HARD-005 spawn telegraph 연출(소리/그림자)은 폴리시.

### DRIFT-047 — P2-S2-fin A3 AssassinTransform 변장 모델 🔸 IMPLEMENTED
- **구현(2026-06-19, IMPL-DEC-20260619-007):** NORM-003(신)·HARD-011(정합)의 EN-011 1기에 per-ENC `assassin` 태그 → backline 재지정 + reveal 텔레그래프(0.6/0.4s) + execute(×3) + reveal 후 정상복귀.
- **분류/전파:** **impl(스펙 tag 구현) + tuning.** AssassinTransform tag·전조 0.6/0.4s = spec `ENC-NORM-003`/`ENC-HARD-011`/D-013. 변장 런타임 모델(backline 타겟 재지정·execute ×3·reveal 후 정상)·crimson 조준선 = 게임 인코딩.
- **드리프트(경미):** ① HARD-011 기존 JSON이 스펙과 불일치(EN-008/EN-010×3 오기)였던 걸 정합 — 단순 수정. ② **시각 변장**(fodder로 위장한 실루엣)은 박스 데모라 미구현 — reveal 텔레그래프(조준선)로 tell만. ③ EN-011=ranged standoff라 execute가 7.5m 원거리(스펙 "후열 처형" 의도와 정합, sneak-melee 아님).
- **잔여:** 변장 실루엣 에셋·sneak 근접화는 폴리시. 체감 F5.

### DRIFT-048 — P2-S2-fin A4 MiniBoss 오버레이 (leash_m 미배선) 🔸 IMPLEMENTED
- **구현(2026-06-19, IMPL-DEC-20260619-008):** BOSS-001 EN-002 per-ENC MiniBoss(ccTenacity 1.2·attentionTier High·50%HP 텔레그래프 −0.15s 페이즈).
- **분류/전파:** **impl(스펙 오버레이 구현) + tuning.** ccTenacity 1.2·phase 50%·−0.15s = spec `ENC-BOSS-001` Catalog overlay/Phase 그대로. per-ENC boss 태그·텔레그래프 delta 적용은 게임 인코딩.
- **미배선(rule):** **leash_m 28**(EN-AI-000 §3 거리-leash, arena 밖 kite 금지) — 게임 disengage가 grace-timer라 거리-leash 전반 미구현(DRIFT-040에서도 기재). 정식화 시 거리-leash를 grace와 병행 도입 후보. 보스 한정 아닌 S2 전반 공통 잔여.
- **잔여:** 페이즈·ccTenacity 체감 F5. MainBoss/약화스택(F-006) 스코프 밖.

### DRIFT-049 — EN-004 zone-holder 보상 튜닝 (사거리·데미지 상향) 🔶 tuning
- **현실(2026-06-19, 사용자 지시):** EN-004(PT-004 zone)는 자리를 고수하므로 **보상**으로 사거리·데미지 상향. `enemies.json` EN-004 `attack_range_m` 5.0→**9.0**, `enemy_basics.json rom_elite_slag_toss` `damage_mult` 0.35→**0.55**·`range_band` Mid→Long.
- **분류\전파:** **tuning(로깅만, 전파금지).** spec `F-025 §11` design-example 수치 조정. PT-004 `zone_radius_m` 8.0 유지 → 9m 사거리로 존 가장자리까지 타격, 존(8m) 내에서만 추격. 밸런스 PH.
- **잔여:** zone 고수 vs 보상 밸런스 F6 체감. range_band Long은 서술 메타(기계적으론 unit attack_range_m 9가 게이트).

### DRIFT-053 — P2-S3b zone 매체 모델 + RX-OIL-FIRE Smoke 정정 (game→spec) ✅ code-bug 수정
- **현실(2026-06-20, P2-S3b):** `reaction_system`의 RX-OIL-FIRE가 폭발 후 **데미지 ToxicGas 존**(`GAS_DPS`)을 깔았음 — 그러나 스펙 `RX-OIL-FIRE-001`은 **Smoke(연소 연기·무해·시야), 독·ToxicGas 아님** + 유닛 **Ignited** + Fire 잔류로 명시(`STATUS-ENV-CORE`도 Smoke/ToxicGas 분리). **게임이 스펙을 어긴 code-bug.**
- **수정:** `hazard_zone`를 매체→OUTCOME 디스패치 모델로(`_apply_medium`; Fire→Ignited·ToxicGas→Poisoned·Water/Ice/Oil/Steam/Wind→이동결과·Smoke/Veg→무해). RX-OIL-FIRE = 폭발+**Ignited**(APPLY-IGNITED-…-5S)+Fire 잔류+**Smoke(무해)**. ToxicGas는 별도 매체(`AB-039`, S3f) 전용.
- **분류\전파:** **code-bug(game→spec 정합) + impl(매체 모델).** 스펙이 이미 Smoke로 규정 → **OPS_30 전파 불필요**. DRIFT-029의 "RX-OIL-FIRE 기존 spec 구현" 주장이 ToxicGas로 부정확했던 것 교정. 9매체 프리셋·디스패치=게임 인코딩. 수치(FIRE_DPS 8·SMOKE_TTL 5) PH.
- **잔여(S3d):** activeMedia[] 다중 스택 + primaryMedium resolver + event bus(EnterZone/ExitZone) + RX 매트릭스 데이터화. 체감 F6(배럴 점화 → 무해 연기 vs 데미지 화염/Ignited).

### DRIFT-052 — P2-S3a OUTCOME 상태 수치 PH + AB-004 Shock 이관 🔶 tuning/impl
- **현실(2026-06-20, P2-S3a):** STATUS-OUTCOME-CORE 결과상태(Sodden/Chilled/SteamHaze/Slippery/Shock/Ignited/WindBuffeted)를 공용 컨테이너로 도입(IMPL-DEC-20260620-002). 이동 슬로우 배수(0.6~0.85)·Ignited 8dps·Slippery 가속(player 10·enemy lerp3) = **DEMO PH**. AB-004 `shock_slow`(ad-hoc apply_slow) → 정식 **Shock** 상태 이관(데이터 shock_slow 0.5 미사용, 컨테이너 0.55).
- **분류\전파:** **tuning(로깅만) + impl.** 상태 ID·태그는 spec STATUS-OUTCOME-CORE 그대로. 수치는 design example PH — 실제 RX→status 매핑/수치는 P2-S3d에서 RX 매트릭스로 데이터주도화 예정. HEX-WEAK(AB-012)는 S3a 범위 밖(기존 apply_slow 유지).
- **잔여:** S3d에서 RX 매트릭스가 어떤 매체→어떤 상태·수치인지 확정 → PH 대체. 체감 F6(샌드박스에서 Shock/추후 zone).

### DRIFT-051 — EN-014 'healer' 거동 (아군 힐러식 포지셔닝) + kite jitter 픽스 🔶 impl
- **현실(2026-06-19, 사용자: "EN-014 체력없는 자기팀에 붙도록 + 4m 혼자일 때 부들부들 떨림"):** PT-016(Support)이 `kite` 거동이었는데, EN-014는 attack_range 1.7m < MELEE_THREAT 4m라 "4m 안이면 후퇴 / attack_range 밖이면 접근"이 4m 경계에서 상충 → **제자리 진동(jitter)**. 또 힐러인데 평타 접근만 해서 팀 케어 동작 없음.
- **변경:** 새 engage `healer`(게임측 dispatch key) 신설 + PT-016에 배정. `_move_healer` = ① 플레이어 근접 시 kite 후퇴(공용 `_kite_flee`), ② **무리를 따라 이동**(`_heal_follow_target` = 체력 최저<90% 우선, 없으면 최근접 아군; HEAL_SEEK 30m)해 AB-098 힐 사거리(HEAL_HUG 2.5) 유지 → 무리가 플레이어를 쫓아 이동해도 **낙오 안 함**, ③ 혼자/이미 무리와 함께면 hold(평타-접근 안 함 → jitter 제거). 검증기 `_ENGAGE_PROFILES`에 healer 추가.
- **분류\전파:** **impl(거동 인코딩) + code-bug(jitter).** spec PT-016 = Support/Hold/Mid/flee_if_melee — healer는 그 'Engaged 우선'을 게임측에서 힐러 포지셔닝으로 구현. 수치(HUG 2.5·SEEK 14·<90%) DEMO PH.
- **잔여:** 아군이 플레이어와 근접교전 중일 때 hug↔flee 미세 진동 가능(엣지) — 체감 F6.

### DRIFT-055 — P2-S5a-3 제3세력 Stalker Pack: 능력 수치 PH + 일부 effect 근사 🔶 tuning/impl
- **현실(2026-06-22, DEC-20260621-001 / spec `bc22c38` 재핀):** EN-3RD-01/02/03 + AB-100~106 + PT-023/024/025 + status/effect 전파·구현. stat(hp/speed/dmg/range/interval)·AB 수치(cooldown/telegraph/dash_range/scent_s/root_s/execute_under/atk_speed_mult 등) = **DEMO PH**(F-025 §11 design examples).
- **의도적 근사(impl):** ① **Tether(AB-103)** = `Tethered` 상태만 적용 — 스펙 effect `APPLY-TETHER-4S`의 `leash_distance_m`/`dot_on_break_dps`(거리 이탈 DoT)는 미구현(상태 태그만; 거리 추적 DoT 후속). ② ✅ **Bloodlust(AB-105) HP-스케일 해결(2026-06-23)** — `attack_interval_now`/`contact_damage_mult`가 **missing HP 비례**로 rage 산출(저장 mult=0HP 최대치, `_missing_hp_frac`로 램프). 스펙 `scaleByMissingHp` 충족. ③ Rooted/Pinned = `MOVE_MULT 0.0` 이동봉쇄(행동가능) — `ccTenacity` 스케일 미적용(spec base만).
- **분류\전파:** **tuning(로깅만) + impl(근사).** 상태 ID·effect 토큰·AB kind·equipClasses는 spec(bc22c38) 그대로 — 규칙 드리프트 없음. 수치/근사는 design example PH, 밸런스 패스에서 조정.
- **이연(S6a):** lootable 6종의 **아군 skillbook 효과(sb_mark/root/tether/execute/bloodlust/lunge 신규)** 미구현 — 스펙에 lootable/equipClasses만 정의(IMPL-DEC-20260622-010). 적 측만 S5.
- **잔여:** Tether leash-DoT(거리추적 트래커 필요)·ccTenacity 적용 = 후속. (**Bloodlust HP-스케일 해결**.) 체감 F6(샌드박스 "ENC 추가"로 Third vs Dungeon 진영전 — Scent→Snare(Root)→Devour 킬체인 관찰).

### DRIFT-056 — Identity Gear 카탈로그 고도화: 17 신규 기어 + 6 정체성 + 6 ability 구현 🔶 tuning/impl
- **현실(2026-06-22, 사용자: "기어를 스펙에 맞게 고도화 + 장착가능한 기어 + 스왑테스트"):** 게임이 역할당 스타터 1개(4기어)만 구현했음 — 스펙(`bc22c38`)은 GEAR-011~016/021~026/031~036/041~043 풀 카탈로그를 정의. 비스타터 기어·정체성(7)·ability(IDA-021/022/027/029/030/031/032/052)·확장 ba 전부 게임 미구현(id_registry note "armory 카탈로그 GEAR-COR-000 후속" 명시).
- **구현(impl):** ① **I4 기어 소유·영속** — 장착 Identity Gear를 `Backpack.equipped[class].gear`로(런 적용·런간 유지·사망 시 Safe, F-009). 스타터=착용(equipped), 스태시=스페어. deploy 스태시 동기화에 gear 포함. ② **17 신규 기어**(gear.json) — GEAR-012~016/022~026/032~036/042~043. 다수는 기존 스타터 정체성 재사용(rampart/ember/brand/scout/hex/coil); volt_lance/beacon_lantern은 스펙상 "Identity 부적합" 정체성 핀 → suitable 폴백(mark_ruin/mend_circle). ③ **6 신규 정체성**(iron_beacon·bulwark_march·sentinel_form·arc_weave·flank_collapse·ward_pulse). ④ **6 ability effect 드롭인**(beacon_threat·march_advance·sentinel_form·arc_line·flank_dash·ward_shield) + member DR(`damage_taken_mult`)·`cleanse_one` + outcome `remove`/`cleanse_one`.
- **튜닝(로깅만):** 새 정체성 combat 스탯(hp/dmg/range/interval/threat — 예: sentinel hp205, arc_weave r14, flank r2.2 dmg20) + 6 ability params(cooldown/radius/dr/dash/cleanse 등) + **17 기어 평타 수치**(basic_damage/interval/range) = **DEMO PH**(의도 반영). 스펙 IDA-021/022/027/029/031/052 문서는 **PT-pending stub**(런타임 수치 미정) → 효과는 **설계 의도대로 구현**(스펙 규칙 위반 아님; 수치=드리프트 로깅).
- **의도적 근사:** ① ✅ **Sentinel Form 40% 반사 해결(2026-06-23)** — `take_damage(amount, attacker)` 시그니처 확장 + `_apply_enemy_hit` attacker 전달 → 스탠스 중 reflect_frac(0.4 draft) 반사. DR(damage_taken_mult)+move-lock(Rooted) 유지. ② **march/flank dash** = `global_position` 직접 이동(nav 경합 없는 짧은 리포지션) — i-frame 미구현. ③ 새 정체성 pattern_id = **역할 스타터 패턴 재사용**(PT-010/020/021/022). ④ **기어귀속 평타(D-019 §4.4)** = 17 신규 기어에 `basic_damage/interval/range` 주입 — 평타는 **기어 ba 아키타입이 SSOT**(`_bind_gear` gear-first, 정체성 combat는 스타터 폴백). 같은 정체성 재사용 기어가 평타로 구분(kite_bash 6/0.8/2.2 vs hook_tug 7/1.0/3.5; ember_wand vs brand_foci). ba 프로필 id(`ba_*`)는 등록만 — 수치는 그 아키타입의 데모 근사. 특수거동(pierce/cone/knockback/threat)은 평타 후속(현재 단일타겟).
- **분류\전파:** **tuning(로깅만) + impl.** 기어/정체성/ability/ba ID는 전부 spec(bc22c38)에 이미 존재 → **구현일 뿐, 규칙 드리프트 없음**(스펙 무편집). nuker_voltaic_interrupt/healer_beacon_sight는 "Identity 부적합"(D-012)이라 정체성 미추가(lootable 서브 전용 유지) — 해당 기어는 suitable 폴백.
- **검증:** 부팅 id 1:1·swap chain(기어→정체성→스탯 변경: anchor hp180↔sentinel hp205, press r10↔weave r14, ruin r2.4↔flank r2.2 등)·ci_smoke. 커밋 38d7df7(I4)·357decf(데이터)·(effect).
- **잔여:** Sentinel 반사·dash i-frame·정체성별 전용 pattern·ba 프로필 전투 반영 = 후속/밸런스. 스펙 AB stub들이 PT 확정되면 params reconcile. 체감 F6(허브에서 스페어 기어 장착 → 런에서 정체성·스킬 변화 관찰).

### DRIFT-057 — P2-S6a 파티 능력 풀(D-016 lootable sub) 단계 구현 🔶 impl/tuning
- **현실(2026-06-23):** 파티 능력 풀 AB 5/64만 구현. 스펙(`bc22c38`) D-016 §3.2 lootable sub 풀(AB-044~075 등)을 단계적으로 게임에 추가. AB-### ID는 전부 스펙 기존재 → **게임 등록·구현만**(스펙 무편집·전파 불필요).
- **구현(B2 — 기존 effect kind 재사용, 데이터만):** AB-053 Searing Volley(Fire)→`skillbook_fire` · AB-049 Ground Pound(Control)→`skillbook_stun` · AB-072 Hailstorm(Cold)→`skillbook_cold` · AB-071 Bulwark Bash·AB-028 Guard Break Rhythm→`skillbook_strike`. id_registry + skillbooks.json만, 신규 코드 0. equip = `mainClasses ∪ subClasses`(D-016 §3.2).
- **의도적 근사:** ① **shape 근사** — cone/zone/multi-hit/fork(DMG-CONE-4HIT·ZONE-8TICK·CONE-2HIT 등)를 기존 kind의 **단일 AoE/타겟 버스트**로 표현(effective dmg = hits×per-hit로 합산: 0.3×4≈1.2, 0.2×8≈1.6, 0.5×2≈1.0). VFX/형태는 후속 전용 kind에서. ② **조건 미모델** — AB-028 "threat 초록 한정"·comboRole(OPENER/LINKER) 등 조건/콤보는 미구현(플레이어 캐스트 시 무조건 발동). ③ **단일↔AoE** — AB-071 단일(targetType Enemy)을 소반경 strike로 근사. ④ params=draft(스펙 "design examples; runtime TBD") 데모값.
- **밴드 패널티 미구현:** D-016 mainClasses(B0)/subClasses(밴드 B1/B2/B3) 중 게임은 `equip_classes`(합집합 게이트)만 — sub 밴드 coeff 패널티(D-012 §2.4)는 미적용(SUB_CLASS_COEFF 0.9 데모 유지). 후속.
- **구현(B1 — 신규 effect kind):** ① `skillbook_heal`(AB-064 Quick Mend, 반경 ally instant heal heal_pct×maxHP + healer threat) ② `skillbook_dr`(AB-046 Shield Wall·AB-047 Aegis Pulse·AB-068 Warding Sigil, 반경 ally DR — `member.apply_damage_reduction`, Sentinel 감쇠 재사용·move-lock 없음) ③ `skillbook_shield`(AB-067 Aegis Blessing, 반경 ally 보호막 add_shield) ④ `skillbook_hot`(AB-065 Renewing Tide, 반경 ally HoT — `member.apply_regen` maxHP%/s) ⑤ `skillbook_blink`(AB-061 Shadowstep, 조준점/최근접 향해 self-teleport) ⑥ `skillbook_vulnerable`(AB-057 Focus Fire, 적에 Vulnerable outcome+mag → enemy take_damage가 받는 피해 증폭, outcome 감쇠 재사용) ⑦ `skillbook_haste`(AB-069 Swift Grace, 아군 이동+공속 ×(1+pct) — `member.apply_haste`·`attack_interval()`를 combat_controller가 읽음). 단일타겟·self는 소반경 pulse로 근사.
- **구현(B1 잔여 — 2026-06-23 패스, 신규 effect kind 5종 + 데이터 1종):** ① `skillbook_stealth`(AB-062 Smoke Veil — self Veiled: `party_member.apply_veil`, 적 타겟 제외는 `enemy_ai._is_hostile`가 veiled 멤버 false 반환 → 타겟/헌트/스플래시 전부 드롭) ② `skillbook_beam`(AB-054 Rending Beam — 조준 방향 고정 라인 채널: `beam_channel.gd` 노드가 `tick_interval_s`마다 cone 데미지+`LightningHit`(→Water/Steam Shock RX), 캐스터 Rooted move-lock, downed/stunned 시 채널 중단) ③ `skillbook_barrier`(AB-034 Rampart Slam — `rampart_barrier.gd`=ENT-RAMPART-001: world-layer 솔리드 벽, 전방 offset, barrier_hp+duration_s Break, 스폰 시 접촉 소형/일반 적 stagger, 캐스터당 1개) ④ `skillbook_purge`(AB-070 Purge Light — 조준점 근방 적 1버프 제거 `enemy_unit.purge_one_buff`) ⑤ `skillbook_silence`(AB-044 Hush Ward — 적 Silenced: `enemy_unit.apply_silence`, `enemy_ai`의 6개 `_try_cast_*`가 `is_silenced()`면 return → 액티브 캐스트만 차단, 이동·평타 유지) ⑥ AB-075 Blessed Barrier = **데이터만**(기존 `skillbook_shield` 재사용, 반경 4m·8%maxHP·5s).
- **밴드 패널티 구현(D-016 §3.2 / D-012 §2.4):** `SUB_CLASS_COEFF 0.9 단일` → **밴드 차등**. skillbooks.json에 `sub_bands {classId: band}` 추가(미기재 클래스=main B0). `ability_dispatch.BAND_COEFF {B0:1.0,B1:0.9,B2:0.75,B3:0.55}` + `_band_coeff`. **equip_classes는 그대로 Role Equip Gate(=main∪sub)** → 기존 ~10 readers 무변경(저위험 가산). coeff 수치 = **tuning**(스펙: 수치 TBD·band 라벨만 SSOT — 로깅만). 규칙(−10단일→밴드)은 spec(`bc22c38`)에 이미 결정(DEC-20260617-002) → 전파 불필요.
- **ally 획득 경로(S6b-lite):** ally-only lootable(usable_by_enemy=false: 034/044/054/062/070/075 등)은 `on_enemy_defeated`(적 kit 롤)로 안 떨어짐 → `dungeon_run`에 **ally-cache 상자**(RM-ADV-01, `ALLY_CACHE_POOL`에서 2종 랜덤, At-Risk) 배치(`ItemFactory.skillbook_item`). shop/드롭표는 S6b 본격 시.
- **의도적 근사/이연(B1 잔여):** ① **Rampart 투사체 1회 흡수 → DRIFT-059 Phase 1에서 부분 해소**(projectile-delivery 어빌리티가 Rampart에 맞으면 흡수; 현재 AB-056만 projectile). threat-on-hit은 후속. navmesh 미리베이크라 NC 추격은 벽 우회 안 함(물리 차단만, 4s 한시). ② Beam = cone 근사(라인 판정 대신 좁은 cone half_deg). ③ Smoke Veil = 적 타겟만 드롭(인플라이트 locked hit는 명중). ④ Purge 제거 대상 = Bloodlust 외 [Fortified/Hasted/Shielded/Warded/Regenerating]는 현재 적이 안 가짐(전방호환 no-op) → DRIFT-058.
- **✅ 능력 디테일 해결(2026-06-23 패스, IMPL-DEC-20260623-017):** ④ **Shadowstep(AB-061) "next hit +20%"** — `party_member._next_hit_bonus`(grant/consume) + `combat_controller._deal_damage` 훅(basic·sub 공통, 1회 소모). ⑤ **Beam Channeling** — `begin_channel`/`is_channeling` busy 플래그가 채널 동안 다른 서브 캐스트 차단(dungeon_run·sandbox 게이트), Rooted move-lock 병행. ⑥ **Sentinel Form(IDA-052) 40% 반사** — `take_damage(amount, attacker)`로 시그니처 확장, `_apply_enemy_hit`가 attacker 전달 → 스탠스 중 피격분의 reflect_frac을 공격자에 반사(DRIFT-056 반사 해결).
- **분류\전파:** **impl + tuning(로깅만).** AB-### ID·status(Veiled/Silenced)·effect 토큰·밴드 라벨은 spec(`bc22c38`) 그대로 → 규칙 드리프트 없음(스펙 무편집). 수치/근사는 design example PH.
- **구현(B2 데미지 sub — 2026-06-23 패스, 19/24, 신규 kind 1 + 재사용):** 남은 lootable 24종 중 **19종**을 추가 — 신규 **`skillbook_bolt`**(targeted 원거리 데미지, 옵션 `lightning`→`LightningHit` RX + Shock outcome) = AB-003 Arc Bolt·AB-004 Charged Voltaic·AB-008 Slag(physical)·AB-055 Scatter·AB-056 Longshot·AB-058 Arc Detonation·AB-059 Void Lance·AB-073 Overcharge. 재사용: AB-005→strike·AB-013→charge·AB-006→blink·**AB-007→blink(`away` 플래그 신설=후퇴 hop)**·AB-030→stun(채널 interrupt 근사)·AB-012→vulnerable(HEX-WEAK 근사)·AB-048/074→dr(reflect/redirect 근사)·AB-033→shield(intercept-soak 근사)·AB-060→execute·AB-066→hot(heal-zone 근사). 멀티히트/포크/차지 shape는 단일 damage_mult로 합산 근사. params=design example PH. **이연(bespoke 5종)**: AB-032 reveal(시야)·AB-035 taunt(threat API 필요)·AB-045 ally-relocate(아군 타겟팅)·AB-050 slow-cone·AB-051 pull — 신규 시스템/타겟팅 필요라 데미지 sub 범위 밖, 후속.
- **구현(B2 잔여 bespoke 5종 — 2026-06-23 패스, 파티 lootable 풀 완료):** ① `skillbook_taunt`(AB-035 Challenge Mark — `enemy.add_threat`+`set_threat_floor`로 Tank 어그로 강제, 무피해; +threat 스파이크 감쇠=시간제한 근사) ② `skillbook_pull`(AB-051 Shield Throw — `enemy.apply_knockback(caster−enemy)` 당김 + threat) ③ `skillbook_slow`(AB-050 Warding Shout — 전방 cone `enemy.apply_slow` + threat) ④ `skillbook_relocate_ally`(AB-045 Lifeline — 반경 내 **최저 HP 아군 자동선택** → 시전자 쪽 이동, 아군 타겟팅 시스템 불요) ⑤ `skillbook_reveal`(AB-032 Beacon Sight — `EnemyVisibility._reveal_timer`가 reveal_s 동안 전 적 `set_seen(true)` 강제, 미니맵 텔레그래프=3D 포그 리빌 근사). 신규 ctx `reveal_enemies` 1개. 누적 lootable sub **44종**·신규 effect kind **18종** — **파티 풀 lootable 사실상 완료**.
- **검증:** JSON 유효(skillbooks/id_registry) + `ci_smoke`(id 1:1·전 스킬북 kind→effect 매핑·effect 컴파일·dungeon_run 부팅=ally-cache 포함) + **`tools/party_pool_smoke.gd`**(전 skillbook kind 커버·밴드 coeff·Veiled/Silenced/Purge 거동 — ci_smoke 편입). 커밋 …·13cb343(B1 잔여+밴드+ally-cache)·5103b68(B2 데미지 19)·(bespoke 5 미커밋).

### DRIFT-058 — Purge Light(AB-070)가 Bloodlust도 제거(스펙 removes_status 초과) 🔶 전파 후보
- **현실(2026-06-23):** AB-070 spec `removes_status: [Fortified, Hasted, Shielded, Warded, Regenerating]` — 현재 게임에서 적이 가지는 유일한 버프는 **Bloodlust(AB-105 제3세력 자가 rage)**뿐(스펙 목록에 없음). 목록대로만 구현하면 Purge가 **항상 no-op**(검증·체감 불가).
- **결정(impl):** `enemy_unit.PURGEABLE_BUFFS = [Bloodlust, Fortified, Hasted, Shielded, Warded, Regenerating]` — Bloodlust를 실효 대상에 포함(제거 시 `is_bloodlust()` false → 공속/뎀 배율 즉시 정상화). 나머지 5종은 전방호환.
- **분류\전파:** **전파 후보(규칙 확장).** "Purge가 적 자가버프(Bloodlust)도 해제"는 AB-070 `removes_status`에 Bloodlust 추가 = 진짜 spec 변경 → 승인 시 OPS_30. 그 전까지 게임측 PH(로깅).
- **잔여:** 적 버프 5종이 실제 적 kit에 생기면 Purge 자동 검증. 체감 F6(샌드박스 Third Reaver Bloodlust → Healer Purge 해제).

### DRIFT-059 — 어빌리티 전달(delivery) 축: 투사체 시스템 (Phase 1 증명) 🔶 impl
- **현실(2026-06-23, 사용자 설계):** 어빌리티를 "모양(범위/단일)"이 아니라 **"전달 방식(투사체 과정을 거치나)"**으로 분류하는 게 옳음 — 두 축 직교(`delivery` × payload). `instant`=조준점/대상에 즉시 발생, `projectile`=날아가 충돌·도달 시 발생(범위폭발/단일 무관). 투사체만 벽/Rampart에 막히고 흡수됨. 통제자(플레이어/AI)는 조준만 다름, 전달 물리는 동일.
- **스펙 근거:** `targetType`(Enemy/Area)은 있으나 투사체 이동/충돌 규칙 미정의 → **impl 결정**. `ENT-RAMPART-001`(LineProjectile 1회 흡수)·`RX-PHYSICAL-BARRIER-001`이 투사체-차단을 전제 → 구현은 스펙 의도 충족(전파 불요).
- **Phase 1(증명):** 범용 `projectile.gd`(segment-raycast 이동→첫 충돌: Rampart→흡수·벽→불발·적유닛/도달→payload) + `ability_dispatch.spawn_projectile`/`_projectile_mask`(시전자 진영 제외=무방수/자가타격 방지, Rampart=world layer 1) + effect `cast()`/`resolve_at()` 분리(즉발·투사체 공유 판정) + `rampart_barrier.absorb_projectile`(DMG-BARRIER-HIT-10). 아군 볼트 **AB-056 Longshot만** `delivery:projectile`(speed 22)로 라우팅해 증명. 나머지 bolt(003/004/008/055/058/059/073)·전 어빌리티는 **instant 유지(무변경)**.
- **진영 필터(사용자 지적 "내 벽이 내 공격 막으면 안 됨"):** 벽은 **적대 투사체만** 흡수, **소유자 같은 편은 통과**(RP-02 = 탱커 벽이 *적* 샷을 막음). `rampart_barrier.blocks_projectile_from(shooter)`(party↔party·동faction=통과 / party↔enemy·교차faction=차단) + 투사체가 아군 벽 RID를 `exclude`해 통과. 이동 차단은 물리(layer 1)라 전원 공통(벽 우회), 투사체만 진영 필터.
- **분류\전파:** **impl(아키텍처).** 규칙 드리프트 없음. **Rampart 투사체흡수(DRIFT-057 BLOCKED) → 해소**: 파티 투사체(10종, Phase 2a)·적 ranged 샷(Phase 2b) 모두 적대 Rampart/벽에 막힘. threat-on-hit만 후속.
- **검증:** ci_smoke + party_pool_smoke(AB-056 flag·resolve_at·spawn_projectile 배선 + **진영필터: 아군벽 통과·적벽 차단**) + 샌드박스 헤드리스 부팅. **충돌/비행 실거동 → 플레이테스트(F5)**: `combat_sandbox` **"Rampart 테스트" 버튼**(앞 6m=**적 소유 벽** + 북쪽 적 + Q=내 벽(AB-034)·E=AB-056) → E를 적 벽 너머 조준=흡수, Q로 내 벽 소환 후 E=통과, 벽 옆=명중.
- **Phase 2a(완료) — 파티 데미지 어빌리티 분류 + VFX 승격:** sb_fire/sb_cold도 `cast()`/`resolve_at()` 분리. `delivery:projectile` 부여 = bolt(003/004/008/055/056/058/059/073)·fire(037/053)·cold(041 Glacial Bolt). **instant 유지**: Hailstorm(072 비)·zone 설치·self/aura·melee·CC/utility(지면/대상 즉발). 투사체 비주얼 element 틴트(`proj_color`: 화염 주황·냉기 cyan·void 보라·lightning 자동 blue). 호밍 VFX→실엔티티 승격(투사체가 곧 비주얼).
- **Phase 2b(완료) — 적 샷 interception (RP-02 정방향):** 적 RANGED 히트(`_apply_enemy_hit`, dist>3m)가 시전자→표적 사이 벽/**파티 Rampart**에 막히면 무효(`_shot_blocked` raycast, world layer; 파티 Rampart=`absorb_projectile`). **homing-locked 유지**(공정성 — 파티 AI 회피 불가라 적중 보장은 그대로, 기하만 차단). 적 샷을 실엔티티(회피가능)로 만들지 **않음**(의도적 — locked 설계 보존). → **내 Rampart/엄폐물이 적 누커 샷을 막는다.**
- **이연(후속):** range 클램프·pierce·AoE-projectile의 벽 폭발(현 fizzle)·적 샷 VFX가 차단 시 벽까지만 날아가게(현재 호밍 VFX는 차단돼도 끝까지 날아가는 비주얼만 — 데미지는 정확히 차단). 적 진짜 탄도(회피가능)는 비채택(locked 설계).

### DRIFT-060 — P2-S6b 스킬북 economy 1a: 분석/상점/ward_scrap (통화 source·tier만 데모) 🔶 impl/tuning
- **구현(F-009 §3.5 / D-018 §7.1):** HubProfile에 `analysis_progress`·`shop_listing_unlocked`·`ward_scrap` + 메서드 — `submit_analysis`(N=3→해금, 해금 후 거부, scriptorium T1 게이트)·`buy_raw`(해금+scribe_shop Tier ceiling+scrap 차감)·`add_scrap`. 가격 ward_scrap Basic 12/Adv 30/Master 60(스펙 정확). Safe meta(SaveProfile 영속).
- **starter 스킬북 정렬(F-009 §3.1.1):** Backpack 시드 = 구 데모 Ember(AB-037) → 스펙 스타터(Tank AB-033·DPS AB-028·Nuker AB-030·Healer AB-044+045). 신규 프로필/리셋 시 적용.
- **데모 근사(tuning, 로깅만):** ① **ward_scrap source** = 추출 성공 시 `15 + 생존자×5`(D-018 §7은 통화·가격만 정의, 획득 source 미지정 → 데모 보상값). ② 상점 생본 tier = 데모상 **Basic 기본**(per-AB abilityTier 데이터 미보유 → Advanced/Master는 loot 경로; tier 데이터 후속). ③ affix·gear roll-table = **미구현(고위험 게이트 이연)**.
- **분류\전파:** impl + tuning. 통화·해금 N·가격·게이트는 spec(F-009/D-018) 그대로 → 규칙 드리프트 없음; source 수치만 데모.
- **1b UI 완료:** `hub_economy_panel.gd`(풀스크린) — 분석 의뢰(스태시 책→소멸·progress/해금)·상점(해금 base ward_scrap 구매→스태시)·scrap 표시 + `main.gd` "필기소·상점" 버튼. 부팅 스모크 PASS, 거동=F5.
- **검증:** hub_smoke(분석 1/3·3/3 해금·해금 후 거부·scribe_shop 잠김 차단·scrap 부족·Basic 구매 −12·미해금 차단) + ci_smoke(허브 패널 부팅) PASS.

### DRIFT-061 — 기어 롤테이블 이행 G1+G2: id 정렬·파생 롤테이블·획득 롤·인스턴스 영속 🔶 impl
- **현실(2026-06-23, 사용자 결정):** gear 1:1 `bundled_identity_skill_id`(레거시 핀) → 아키타입(롤테이블)+인스턴스(굴린 identity) 이행(F-008 §3.7/DEC-20260618-002). G1 = 저위험 토대(가산·거동 불변).
- **id 스펙 엄격 정렬(GEAR-COR-000):** 17 비스타터는 이미 spec 슬러그 일치 → **스타터 4종만 개명**: `_set` → anchor_bulwark/press_rod/ruin_sight/mend_lantern(GEAR-011/021/031/041). gear.json·id_registry·Backpack 시드·loot_service 동기 + **세이브 마이그레이션**(Backpack `_migrate_gear_ids` old→new alias, equipped+loose 1회).
- **파생 롤테이블(권고안):** `Slice01Data.get_gear_identity_roll_table` = main(bundled w50) + 동클래스 나머지(잔여 균등). 명시 per-archetype 테이블 override = 향후(사용자: 필요 시 수정).
- **bind fwd-prep:** `party_member._bind_gear` = `rolled_identity_skill_id`(있으면) > bundled. master 행엔 rolled 없음 → bundled(**G1 거동 불변**). 인스턴스 저장(G2)부터 rolled 적용.
- **G2 완료(획득 롤 + 인스턴스 영속) — 바운드 범위:** loot_service 기어 드롭 = identity 가중 롤 + 서브옵션 mult(던전 band) → 인스턴스 디스크립터. 인스턴스 필드(`rolled_identity_skill_id`/`rolls`)가 **loot→백팩 loose(디스크립터+재구축)→장착→equipped(capture/apply)** 경로로 보존(item_factory·inventory_ui 재구축·Backpack `_strip`/apply/capture·equip_panel `_commit_equip` 병합·party_member `gear_rolls`). rolled 없으면 bundled 폴백(거동 호환). **바운드/이연:** Stash 스페어 = 문자열 유지(roll 미보존, 스태시 왕복 시 bundled로) · revert(드래그 취소) edge = bundled · affix·대장간(Expansion).
- **G3 완료(rolls 스탯 적용 + UI):** `_bind_gear`가 **dmg_mult→평타 위력**(매 bind fresh 재계산, 비누적), **cd_mult→`cooldown_mult`→identity 쿨**(ability_dispatch.try_identity가 곱). 상세 툴팁(인벤/장착, 표시명 레이어 display_names.json)으로 굴린 identity·옵션 표시.
- **Stash 인스턴스화 완료:** `Stash.gear`가 문자열 → **인스턴스 dict `{base_gear_id, rolled_identity_skill_id?, rolls?}`**. `_normalize_gear`(시드/레거시 세이브 문자열→dict 마이그레이션)·`remove_gear`(base 매칭)·make_gear_stash_item/_sync_stash_from_source(rolled/rolls 왕복). 스페어도 굴린 정체성·옵션 보존(왕복 시 bundled 리셋 해소). **부수 수정:** `backpack.capture_from_party`의 `m.get(key, default)`(Node.get은 1-arg → 매 hub deploy/추출마다 런타임 에러)를 1-arg로. **G3 잔여:** potencyMult·affix(다음).
- **분류\전파:** impl. 메커니즘은 spec(F-008/GEAR-COR-000/D-019) 그대로 → 규칙 드리프트 없음. mult band 수치=데모. 설계 = `docs/design/gear_roll_table.md`.
- **검증:** ci_smoke(개명 id validate·부팅·인벤 패널) + party_pool_smoke(id 정렬·롤테이블·**G2 rolled identity apply/capture 영속·rolls 저장**) PASS. 인벤 드래그 거동 = F5.

### DRIFT-062 — 스킬북 affix(D-018 §7.3/§7.6) 구현: 루팅 18% 굴림 + coeff/탄/쿨 적용·영속 🔶 impl/tuning
- **현실(2026-06-23, 사용자 "affix 하자"):** 루팅 스킬북 인스턴스에 affix 굴림 추가(기어 롤의 스킬북 판본). `affix_roller.gd` — 루팅만 **18%**(상점 Raw=0%), affixTier T1 85/T2 12/T3 3, 종류 eff_plus/eff_minus_trade/charges_small(§7.6 examples).
- **적용:** coeffMult = `cast_skillbook`에서 cross-class 밴드와 **독립으로 곱**(§7.3 note, `_coeff × (1+affix.coeff)`, 합산 ±15% 클램프) · cd_trade → 쿨 가산 · charges → instance `charges_max` 가산.
- **인스턴스 스키마:** 스킬북 instance/item에 `affix: Dictionary` 필드(`{}` = 무affix). loot→`_strip`(키 유지)→장착(equip_panel `_skillbook_inst`·`equip_skillbook_by_id(…, affix)`)→member→capture/apply subs로 영속(gear 롤과 동형). 인벤 툴팁 affix 라인(표시명 `display_names.json` `affixes`).
- **바운드/파생:** **Slice-01 = 인스턴스당 단일 affix**(§7.3 합산 ≤15% 자명 만족; multi=후속). `TIER_SCALE`(희귀 tier coeff 소폭↑)=게임측 파생(스펙 외, cap 클램프, 튜닝). 절대 수치=데모(런타임 SSOT F-025 §11). **이연:** §7.5 중복 sink·affixTier 5단·대장간 리롤.
- **분류\전파:** impl. 메커니즘 spec(D-018/F-009) 그대로 → 규칙 드리프트 없음. 설계 = `docs/design/affix_design.md`.
- **검증:** party_pool_smoke §16(roll cap·charges 가산·capture/apply 영속) + ci_smoke PASS. 전투 적용·툴팁 = F5.

### DRIFT-063 — 스킬북 탄약수↑ + 드롭률↓ (스펙 §7.2/§7.4 대역으로 수렴) 🔶 tuning
- **현실(2026-06-25, 사용자 "스킬북 너무 많이 떨어져 피로 → 탄약↑·드롭↓"):** 기존 게임값(charges_max 4~12, skillbook 드롭 flat 0.85)이 스펙과 크게 괴리 → 스펙 대역으로 수렴.
- **변경:** `skillbooks.json` charges_max **×10 클램프[50,80]**(§7.2 50~80 대역; 결과 50/60/80 중심, n=61) · `loot_service.SKILLBOOK_DROP_CHANCE 0.85→0.15`(§7.4 Normal 8%/Hard 15% 대역) · `GEAR_DROP_CHANCE 0.08→0.04`(스킬북 롤↓로 gear 롤 도달↑ 상쇄 + 전반 클러터↓).
- **효과:** 스킬북 드롭/런 ~27→~5(피로 완화), 탄약 ~10x → 적게 줍고 오래 쓰는 형태. 순 전력예산 유사~약간↑.
- **분류\전파:** **tuning만**(로깅, 전파 없음). 메커니즘·규칙 무변경. 절대 수치=데모(런타임 SSOT F-025 §11). per-AB abilityTier 차등 charges(§7.2 Basic56/Adv60/Master72)·난이도별 드롭(8%/15%)=후속(데이터 미보유). 클래스 소프트-피티(IMPL-DEC-030)와 곱연산으로 동작.
- **검증:** ci_smoke PASS(JSON 검증·부팅). 체감=F5.

### DRIFT-064 — 루트 출처 재구성: 재료/스킬/기어=절차적 티어 상자, 몬스터 킬=스킬 OR 소량 재화 🔶 impl/design (전파 후보)
- **현실(2026-06-25, 사용자 설계 지시):** 루트 출처를 재편 — **상자**(절차적 산포·티어)가 재료·스킬·기어 주공급, **몬스터 킬**은 자기 스킬 OR At-Risk 소량 ward_scrap. 기어·재료는 킬에서 미드롭.
- **스펙과의 차이:** HUB-COR-000 §3은 haul을 **ENC(분대) 클리어** 드롭표로 정의 → 게임은 이를 ×0.2로 줄이고 **상자**로 이전(재료 출처 변경). D-018 §7.4 per-kill 스킬 드롭은 유지하되 킬의 gear/haul 제거 + **킬 보상 재화(ward_scrap)** 신설(스펙 source 미정 — 기존 추출 보상 drift와 동류). 상자 티어/affix 보장은 게임측 설계(스펙 미정).
- **수치(tuning):** 상자 면적당 ~1/520m²·희귀 18%·일반 재료 1~3/스킬 40%/기어 15%·희귀 재료 1/스킬 90%(affix 강제)/기어 50% · squad-clear haul ×0.2 · 킬 재화 1(At-Risk).
- **분류\전파:** impl/design — **전파 후보**(재료=상자 + 킬=재화 모델은 HUB-COR-000/D-018 설계 의도와 다름). 현재 미전파(사용자 "아껴" 기조 유지) → 확정 시 OPS_08(아이디어)/OPS_30(규칙) 경로. 절대 수치=데모.
- **검증:** 부팅 절차적 상자 배치 로그 + party_pool_smoke + ci_smoke PASS. IMPL-DEC-031.

### DRIFT-065 — 허브 이벤트 퀘스트 데모 완료 경로 (미구현 기능 대용) 🔶 impl (전파 후보)
- **현실(2026-06-25, 사용자 "A로 진행"):** 막혀 있던 이벤트형 승급 퀘스트 3종을 달성 가능하게 배선. 스펙(F-029 §3.3) 완료 조건이 미구현 기능(2번째 맵·전멸 복구·NPC 고용)에 의존 → 추출/전멸 횟수로 **데모 근사**.
  - **Q-HUB-003**(창고 T2): "맵 2종 탈출" → **추출 성공 ≥2회**. **Q-HUB-040**(성소 T1): "전멸 복구" → **전멸 ≥1회**. **Q-HUB-050**(군수 T1): "NPC 고용" → **추출 성공 ≥1회**.
  - **부수 버그:** Q-HUB-010(필기소)이 어디서도 완료 안 되던 것 수정(complete_objective→set, DRIFT 외 커밋 ce7b344).
- **구현:** HubProfile `extraction_success`/`party_wiped` 카운터(+영속) + `record_extraction_success`/`record_party_wipe`(run_end_controller 성공/PartyWipe 시 호출) + evaluate_quests 3줄. quests.json `completion` 텍스트도 데모 조건으로 갱신(퀘스트 로그 표시). 퀘스트 로그 패널(hub_quest_panel)에서 조건 노출.
- **분류\전파:** impl — **전파 후보**(실 완료 조건은 2맵/복구/NPC; B4-full에서 교체). 게임은 데모 proxy. 미전파.
- **검증:** hub_smoke(추출 1→군수·2→창고T2·전멸→성소) + ci_smoke PASS.

### DRIFT-066 — S5b Encounter Variety: EN-* 태그 + 조합 제너레이터(라이브) + 절차적 스폰 위치 🔶 impl/design (전파 후보)
- **현실(2026-06-25, 사용자 "S5b 진행"):** 인카운터를 authored ENC 1:1 → **조합 생성 하이브리드**로. 설계=`docs/design/encounter_variety_architecture.md`.
  - **P1 태그:** enemies.json 17종 `tags{tier·archetype·bucket·axis·faction·placement_affinity·fodder_variant}`(taxonomy=D-013/ENC-000). `Slice01Data.get_enemy_tags`.
  - **P2 제너레이터:** `encounter_generator.gd` `generate(difficulty, seed)` — ENC-000 §2 가드레일(mechanicAxes=elite+고유 specialist 축 ≤2·fodder min/max·variant_min) 준수. 제3세력 base 제외. 결정적.
  - **P2b 라이브:** `combat_controller.prespawn`이 보스/3RD 외 ENC의 units를 생성 조합으로 대체(frame=placement/faction/reinforcement는 authored 유지=하이브리드). 스폰 위치=방 크기 비례 산포(고정 4.5m→0.28×최소변, 상한 13m)+벽 클램프.
- **스펙과의 차이:** ENC가 authored 1:1이 아니라 (difficulty,seed)→생성. ENC-000(group/budget 생성)·LDG-SPAWN(resolve)·F-006(placement)에 표면 변경. tier/mechanicAxes taxonomy는 스펙 준수(가드레일).
- **분류\전파:** impl/design — **전파 후보**(S5b 빌드 직전 ENC-000/F-006/LDG-SPAWN OPS_30 예약, 설계 §6). 현재 게임측 검증 우선·미전파. 절대 수치(SCALE·SCATTER_FRAC)=데모.
- **검증:** party_pool_smoke(태그 + 제너레이터 3난이도×149시드 가드레일) + dungeon_run 부팅 prespawn 생성 + ci_smoke PASS. **잔여=P3 제3세력 창발 모디파이어·P4 런 내 비복원.** 체감=F5.

### DRIFT-067 — Q-HUB-020(무기고) 절차생성 정합: 특정 ENC 의존 제거 + force_overrides 난이도별 스키마 🔶 impl (전파 후보)
- **현실(2026-06-26):** spawn_table `force_overrides`가 P-ADV-01을 **모든 난이도에서** ENC-NORM-001로 강제 → Hard에서도 ENC-HARD-001 미등장 → Q-HUB-020(armory) 달성 불가였음. (사용자 "하드 들어갔더니 적이없어".)
- **결정 진화:** ① 1차 — force_override를 `{difficulty: enc}`로 확장해 Hard=ENC-HARD-001 핀(도달). → ② **사용자 재지정("ENC도 절차적으로 뽑기로 한 거 아니냐")**으로 **퀘스트를 특정 ENC에서 분리**: Q-HUB-020 = "임의 **Hard 인카운터 1회 클리어**"(절차생성과 정합). Hard 핀 제거 — Hard P-ADV-01은 일반 weighted resolve(현 풀 단일후보=HARD-001이나 핀 아님).
- **구현(최종):**
  - `force_overrides[pool]` 값이 **문자열(전 난이도 강제, back-compat)** 또는 **{difficulty: enc}** 모두 허용(`get_encounter_for_pool`·`_parse_spawn_table`·enc 커버리지). 데이터=`{"P-ADV-01": {"Normal":"ENC-NORM-001"}}` — **Normal QA핀만 유지**(QA-031 그대로), Hard 미핀.
  - `HubProfile.hard_cleared`(영속) + `record_enc_cleared(enc, difficulty)`가 difficulty=="Hard"면 set + evaluate. `evaluate_quests`의 Q-HUB-020 = `hard_cleared`. quests.json completion="Hard encounter clear once (any)". `dungeon_run`이 `RunLoadout.get_difficulty()` 전달.
- **스펙과의 차이:** ① LDG-SPAWN forceEncounter 스키마 단일 enc → 난이도별 map 확장(하위호환). ② Q-HUB-020 완료조건 "ENC-HARD-001 clear once" → "임의 Hard 클리어"(F-029 §3.3.1 — 절차생성 ENC와 정합).
- **분류\전파:** impl — **전파 후보**(LDG-SPAWN 스키마 + Q-HUB-020 조건 OPS_30). 하위호환·게이트 완화라 비파괴. 미전파.
- **검증:** hub_smoke(Normal 클리어 미해금·임의 Hard 클리어 해금) + 난이도별 resolve + ci_smoke PASS. 체감=Hard F5 → 아무 Hard 전투 클리어 → 무기고 개방.
- **참고:** P-ENTRY-01·P-DEEP-01은 Hard 행 없음(∅, 콘텐츠 갭·비차단). EncounterGenerator Hard SCALE(2~5 fodder) 정상 → "적 0" 체감은 generator 아닌 force핀(가림) + 4~5전투 budget(방 대부분 비전투).

### DRIFT-068 — per-AB tier: 스펙 abilityTier 미정의 12 sub = Basic 기본 🔶 impl (재싱크 후보)
- **현실(2026-06-26, S6b per-AB tier):** skillbooks 61종 `tier`를 스펙 AB-###.md `abilityTier`에서 소싱(67 정의). 12종은 스펙에 abilityTier 항목 없음(AB-028/030/032/033/034/035/044/045/051/062/070/074 — 대부분 identity 유래/bespoke 유틸·제어 sub) → 게임이 **Basic 기본** 부여.
- **스펙과의 차이:** 해당 sub 정식 tier 미정(스펙 갭). 게임은 가장 보수적(저가·scribe_shop T1 접근) Basic으로 채움. 분포=Basic31·Adv28·Master2.
- **분류\전파:** impl — **재싱크 후보**(스펙이 12종 abilityTier 정의 시 동기화). 비파괴(상점 가격/천장만 영향).
- **검증:** ci_smoke + hub_smoke(AB-002 Basic·AB-004 Advanced·Adv 생본 T1차단/T2구매) PASS.

### DRIFT-069 — T1 백로그 배치: 잔여 종결 6 + 신규 콘텐츠 2 (2026-07-04) 🔶 impl/tuning + 일부 PENDING-PROP
- **현실(2026-07-04, 사용자 "T1 진행"):** `BACKLOG_open_items.md` §T1(지금 바로 가능) 배치 구현. 전 헤드리스 ci_smoke 6/6 PASS.
- **잔여 종결(기존 spec 구현 — 전파 불필요):**
  - **HEX-WEAK 피해감소 절반(DRIFT-041):** `party_member.apply_hex_weak/hex_weak_mult` + `_deal_damage` 소비 훅 + AB-012 `hex_weak 0.5`. 이동 slow에 더해 나가는 피해 −50%.
  - **거리-leash + 스폰복귀(DRIFT-048/040/019):** `combat_controller.DISENGAGE_LEASH_M 28`(EN-AI-000 §3) 이탈 → `enemy.returning` → `enemy_ai._tick_dormant` 스폰 앵커 복귀(Phase D). 수치=tuning.
  - **난이도 드롭률(DRIFT-063 일부):** `loot_service.SKILLBOOK_DROP_BY_DIFF` Normal 8%/Hard 15%(§7.4). tier별 충전수=밸런스 결정 보류(61 저작값 일괄 변경 회피).
  - **fog 문 occluder(DRIFT-037 잔여):** `vision_fog`/`enemy_vision_overlay.add_box_occluder` — 닫힌 문=시야 그림자(기존: 그림자 전무 버그)·열림=제거(UPDATE_ALWAYS로 다음 프레임 반영).
  - **적 stun VFX + 오프스크린 아군 지표(DRIFT-044/022):** `enemy_unit._stun_label`(✦, 지속) + `party_hit` 시그널에 member 추가 → 오프스크린 피격 아군은 앰버 엣지 글로우(자기피격 red와 구분).
  - **PIP §7.8 우선순위 정렬(DRIFT-030 잔여):** `mia_controller` PIP 리스트 최저 HP순 정렬(가장 위험한 아군 먼저).
- **신규 콘텐츠 — `PENDING-PROP`(OPS_30 승인 대기, 이 레포 spec md 미편집):**
  - **F3 환경 RX 3종:** `RX-FIRE-ICE-001`(Ice→Water melt)·`RX-COLD-FIRE-001`(Fire→quench Steam)·`RX-COLD-STEAM-001`(Steam→Water). `reaction_system` RX_FIRE/COLD_MATRIX 확장. **새 RX 룰 → 전파 후보.**
  - **B7 zone spread(S3e):** `reaction_system` Wind 구동 유계 spread(`_physics_process` 2s·per-gust 2·global cap 6·children 비재확산). room-cap=전역 프록시. **spread 룰 → 전파 후보 + F5 튜닝.**
- **분류\전파:** impl + tuning(로깅만). 종결 6은 기존 spec 구현. **F3/B7 = 새 규칙 → PENDING-PROP**(승인 후 OPS_30). IDA-052 reflect 키 불일치(`reflect_frac`→`reflect` 폴백)·party_member:510·combat_sandbox:74 stale 주석 수정 포함(비-드리프트).
- **이연:** C2 §7.5/§7.2(PIP 아이콘/관통가림)·저위험 부채(DEBT-DUP-*)·E3 tier-충전수(밸런스). ref: `ImplDecisionLog` IMPL-DEC-20260704-001.

### DRIFT-073 — 가호(Ward Pulse, IDA-031) 폐지 → 「지속 치유」(DoT) 재해석 🕒 파일럿 설계변경 (전파 보류)
- **발견/결정(감독 2026-07-08, P2-S8a Stage3 Healer):** IDA-031 가호(=아군 보호막 제공, `ward_shield`)를 **폐지**하고 **지속 치유** 정체성으로 재해석 — 착용 시 **모든 치유가 도트힐로 강제 전환**(즉시 회복 대신 N틱 분할, 총 회복량↑). 이유: 도트 서브를 따로 두는 것보다 정체성이 힐 전체를 변형하는 편이 평가/판타지 모두 선명.
- **게임 반영:** `abilities.json` IDA-031 `kind` `ward_shield`→`radius_heal`(자동시전도 힐). 전환 로직 = 치유 choke(`ability_dispatch.deal_heal`/`deal_regen`)가 `identity_dot_heals` 게이트로 즉시→HoT 변환(기존 `apply_regen` 재사용). `ward_shield.gd` 미사용(무해).
- **분류\전파:** rule/데이터(정체성 능력 재정의) — **파일럿 검증 중이라 로깅만**, 게이트 PASS 후 OPS_30로 `ROLE-010`/IDA-031 ability doc 재정의 전파 예정(가호→지속치유). 이 레포에서 spec md 편집 금지.
- **상태:** 🕒 로깅(게임 반영·smoke PASS, 스펙 전파 보류). 관련: IMPL-DEC-20260708-001.

### DRIFT-074 — Healer 서브 킷 재설계: 도트 서브 제거 → 채널힐/수호-흡수 🕒 파일럿 설계변경 (전파 보류)
- **발견/결정(감독 2026-07-08):** 「지속 치유」가 모든 힐을 도트로 강제 전환하므로 **전용 도트 서브가 중복** + 성역에서도 컨셉이 흐림 → 힐러 서브 3종을 **동일 상태에서 두 정체성이 어떻게 변형하는지 평가**하기 좋게 재설계(힐러 사례가 곧 「정체성별 스킬셋 통일」 원칙의 출발점). AB-064 Quick Mend→**짧은 집중(채널 2초)**, AB-065 Renewing Tide→**수호-흡수 힐**(보호막 종료 시 흡수량만큼 치유), AB-066 Sanctuary Font→**긴 집중(채널 5초)**.
- **게임 반영:** `skillbooks.json` AB-064/065/066 `kind` 재해석(`skillbook_channel_heal`/`skillbook_ward_heal`) + 신규 이펙트(sb_channel_heal·channel_heal·sb_ward_heal·ward_heal) + 재사용 컴포넌트 `cast_bar`(연속 진행바)·`range_disc`(자기중심 힐 범위). 채널=점유+이동취소(쿨/차지 환급). 최종 힐은 deal_heal 경유 → 정체성 자동 연동.
- **분류\전파:** rule/데이터(서브 kind 재정의) — 로깅만, 게이트 후 전파 예정.
- **상태:** 🕒 로깅. **P4a 재사용:** `cast_bar`/`range_disc`는 「캐스팅 시간 전체 스킬 확장」에서 재활용 예정.

### DRIFT-075 — 캐스터(Nuker·DPS·Healer) 스킬 = 캐스트/채널 중심, 즉발 최소·강패널티 🕒 설계 원칙 (전파 대기)
- **감독 방향(2026-07-08):** 백라인/캐스터 클래스(**Nuker·DPS·Healer**)는 **즉발기(instant-cast)를 최대한 배제**한다. 즉발기를 넣는다면 **강한 패널티**(예: 고쿨). → 이 클래스 스킬의 기본은 **캐스트 시간/채널**(commit·텔레그래프·이동취소 리스크).
- **함의:** 단일타겟 너커 등 스킬 **차별화는 숫자(딜/쿨)가 아니라 캐스트 방식(즉발↔짧은캐스트↔긴차지↔채널)이 주도**. 현재 즉발 볼트(AB-004 전격사격·AB-059 공허창 등)는 잠정 — P4a에서 캐스트 시간이 붙으며 자연히 갈림.
- **연결:** 스펙 **`castTier`(D-016 §3.6.2 wind-up/rootDuringCast)** = 이 원칙의 SSOT 후보. 게임측 `cast_bar`(연속 진행바)·채널(begin/end_channel·이동취소→쿨/차지 환급) 시스템이 「P4a 캐스팅 시간 전체 스킬 확장」의 토대(IMPL-DEC-20260708-001). castTier B/C는 IMPL-DEC-20260704-002에서 이연됨 — 이 원칙으로 재개.
- **분류\전파:** rule(설계 원칙) — P4a 캐스팅 확장 스프린트에서 **OPS_30로 spec `D-016`/castTier·`ROLE-010` 캐스터 절 전파** 예정. 이 레포에서 spec md 편집 금지.
- **상태:** 🕒 원칙 로깅(게임 미구현, 스펙 전파 대기).

### DRIFT-076 — 「집중」(Mark&Ruin, IDA-025) 빌드를 조작-전용→**모든 명중·AI 공통**으로 확장 🕒 파일럿 스코프변경 (전파 보류)
- **증상(2026-07-08):** ENC에서 AI 누커 집중 대상(🎯)이 안 뜸. (거리 아님 — 누커가 근접까지 가도 안 뜸.)
- **진단(2정):** ① **is_controlled 게이트** — 파일럿 결속은 `F-020 §3.3`(NC 미적용, 조작-전용)대로 `is_controlled()` 안에서만 집중을 씨앗했고, 기본 조작 캐릭터는 탱커(index 0, `party_controller` `_set_controlled_index(0)`)라 AI 누커는 집중을 **아예 안 새김**. ② **씨앗 원천이 8m 정체성뿐** — 조작 중이어도 원거리 서브 캐스터(전격 14m·공허창 15m)는 8m mark_burst가 안 닿아 집중이 안 떴음(2차 문제). 서브 `focus_stack`도 `get_focus_enemy()==null`이라 무력. 허수아비 근접 테스트에서만 우연히 동작.
- **감독 결정(2026-07-08):** **AI 누커도 집중 빌드**(스펙 `F-020 §3.3` NC-미적용 이탈). 소모(execute)는 서브 아키타입이라 **조작 시에만**(AI는 서브 미사용) — 빌드/시각화는 AI, 페이오프는 조작.
- **수정:** 집중 seed/stack을 공용 `nuker_focus_accumulate(member, enemy)`로 통일(**ungated**) — **평타(`_resolve_basic`)·정체성(`mark_ruin`)·서브(`_nuker_focus_stack`) 명중이 모두 호출**, is_controlled 무관. 반환=누적 비례 증폭 배수(1+누적×pct)를 각 명중 딜에 곱(평타/정체성 fold-in, 서브는 진홍 추가타 팝업). `FOCUS.seed_radius_m=3.0`. covenant를 "공격이 명중하면 집중 대상(평타·정체성·서브 공통)"으로 갱신.
- **스코프 주:** 이 ungate는 **「집중」(focus)만**. 탱커 방벽·표식 / 힐러 성역·지속치유는 **여전히 조작-전용** — 동일 확장은 감독 결정 시 별도.
- **분류\전파:** 파일럿 로컬(binding_fixtures = CombatContentMap-UNREGISTERED 비정본). rule·scope 변경 — P4a 정본화 시 「집중」 빌드 규칙 + **결속 NC 스코프(`F-020 §3.3`) 재검토**와 함께 OPS_30 전파. 이 레포에서 spec md 편집 금지.
- **상태:** 🕒 파일럿 수정. 게임 내 플레이테스트 확인 대기.

### DRIFT-077 — DPS 결속 「초월(Overdrive)」 / 「혈풍(Blood Gale)」 파일럿 (press_line/arc_weave) 🕒 파일럿 신규 (전파 보류)
- **감독 설계(2026-07-08):** DPS 두 정체성의 운영 루프를 감독이 직접 지정. **역할 원칙 = 단일표적은 누커, DPS는 애초에 광역** → DPS 공유 3서브를 기본부터 AoE로(작열 폭발 fire 원형 / 절단 광선 beam 라인 / 빙결 파동 cold 원형). 누커 볼트 재탕 금지.
- **「초월」(press_line/IDA-024):** 스킬·평타 명중마다 게이지↑, 가득 차면 dur초 **강화 변형**. 강화 = **단순 배수 아님, 효과 변화**(ref=LoL 카르마 Mantra): fire→화상(Ignited·**적한정 DoT**, 장판 대신 상태라 아군 무피해) / beam→끌어당김 / cold→빙결(Rooted). 게이지·강화 모두 **조작/AI 공통**([[DRIFT-076]] 스코프) — AI가 게이지를 쌓고, 켜지는 순간 조작 전환해 몰아치는 루프.
- **「혈풍」(arc_weave/IDA-027):** 서브 시전당 max_hp 12% 소모, **명중 적 1기당 5% 회복**(3기+ 순이득). 서브가 애초에 광역이라 억지 스플래시 없이 성립. 자살 불가(hp_floor 클램프). 적 多=유지 / 적 少=손해 → 누커로 전환 유도.
- **구현:** `BindingFixtures.OVERDRIVE/BLOODGALE` + BIND-PILOT-019~024(6). party_member 게이지 상태·틱·`blood_soak`, health_bar 초월 게이지 바, overhead_badges 「초월」. dispatch `overdrive_charge`/`blood_soak` 델타 + kind 분기 강화(`_dps_overdrive_empower`) + 명중 집계(radius/cone). 서브 데이터: AB-053/041 cast_s(DRIFT-075), AB-053/054/041 한글명.
- **분류\전파:** 파일럿 로컬(비정본). rule·scope(캐스터 광역·초월 리소스·NC 공통) — P4a 정본화 시 [[DRIFT-075]]/[[DRIFT-076]]와 함께 spec `ROLE-010`/`D-016` 전파. 이 레포에서 spec md 편집 금지.
- **상태:** 🕒 파일럿 구현(binding_smoke 23 + ci_smoke 대상). 플레이테스트 확인 대기. 설계 정본 = `docs/design/dps_binding_kit.md`.

### DRIFT-078 — I-006 캐스팅 확장 패스: 캐스터 서브 즉발→캐스트/채널 정합 (엄브렐러) 🔶 impl/tuning (진행 중)
- **배경(2026-07-09~):** [[DRIFT-075]] 원칙(캐스터=캐스트/채널 중심) 적용 — 캐스터 서브 ~29종 즉발을 스킬 하나씩 샌드박스 핑퐁으로 캐스트/방향/효과 정합. **수치 밸런싱은 스킵**(명백한 파손·방향만). 세부 대칭 원장 = `docs/_WIP_casting_expansion_pass.md` §4(패스 종료 시 삭제, 정본=이 항목). 티어 밴드 A(0~0.4s)/B(3~5s)/C(8~15s).
- **완료분(cast_s 부여):** AB-041(cold) 0.8→3.5(B) · AB-053(fire 작열) 0.6→3.0(B) · AB-064(channel_heal) 2.0→3.0 · AB-004(bolt) 0.5→4.0(B) · AB-059(bolt) 1.5→5.0(B) · AB-066(channel_heal 궁극) 5.0→10.0(C) · **AB-003(bolt)** +cast_s 3.0·cd 2→6·radius 1.6→4.0(A→B).
- **효과·결속 변경:** **AB-002 Shield Bash** — 반경 4→8·dmg ×2.5→×1.0·cd 4→2(Anchor 방벽충전 스팸형 궁합) + 발동 프레임 반경 telegraph 링 + **헛스윙도 차지/쿨 소모**(반응형 CC는 명중이 아니라 휘두름이 비용, `sb_strike`). **AB-003 초월 링크** — press_line 초월 중 감전 폭주(`skillbook_bolt`→`apply_silence` 2.0s, AB-044 API 재사용) + `OVERLAYS` `BIND-PILOT-026`(press_rod·IDA-024·AB-003@slot0, AB-053과 슬롯 공유). [[DRIFT-077]] 초월 kind 분기 확장.
- **분류\전파:** impl/tuning(cast_s·수치=로깅만). 단 [[DRIFT-075]] castTier 원칙 자체는 P4a에서 OPS_30 전파 대기 — 개별 cast_s 값은 그 하위 튜닝. 이 레포 spec md 편집 금지.
- **상태:** 🔶 진행 중(위 8 AB 완료, 잔여 ~21 AB는 ENC 순회). **미커밋**. ci_smoke 대상.

### DRIFT-079 — AB-054 절단 광선: 채널 rootDuringCast/점유 폐지 → 인터럽트형 채널 🔶 rule (전파 후보)
- **변경(2026-07-12, 사용자 지시):** AB-054 빔 채널이 시전자에 걸던 **셀프 Rooted(이동잠금) + begin_channel 점유(타 시전 차단)를 제거**. 대신 **인터럽트형** — 이동(시전지점 0.3m 이탈)·다른 스킬 시전·기절/다운 시 채널이 **중단**된다(강제 차단 아님).
- **UI:** 채널 진행을 **감소형 바**(캐스팅바가 좌→우 차오르는 것과 반대로 우→좌 소진·청록색)로 표시 — "속박" 상태 텍스트/오브 제거. 조준은 원형 원판→**직선 레인**(시전자→마우스, 길이=사거리·너비=빔폭).
- **구현:** `beam_channel`(감소바+이동/중단 감시+`cancel_channel`), `sb_beam`(Rooted/begin_channel 제거→`set_active_channel`), `party_member`(`_active_channel`+`interrupt_active_channel`), `ability_dispatch.cast_skillbook`(새 시전 시 채널 중단), `aim_marker.show_beam`/`aim_controller`(직선 조준+방향 즉시 시전). `begin_channel`/`is_channeling`은 wind-up 캐스트(skill_cast)용으로 유지.
- **분류\전파:** **rule** — 스펙 `D-016` `rootDuringCast`/`castTier`(채널 성격)와 직접 충돌. [[DRIFT-075]] 캐스터 원칙 전파 시 함께 OPS_30(채널=인터럽트형·비점유 모델) 전파 후보. `ImplDecisionLog.md`의 "Beam=cone+Rooted move-lock" 노트 outdated → 갱신 필요. 이 레포 spec md 편집 금지.
- **상태:** 🔶 구현(브랜치 `wip/casting-ab054-overdrive-20260712` 커밋 · **미검증** — godot 헤드리스 부재). 플레이테스트 대기. **전파 packet:** [_PROP_PACKET_DRIFT-079-080.md](_PROP_PACKET_DRIFT-079-080.md) (적용 = P4b 배치 시점).

### DRIFT-080 — DPS 「초월」 운영 개편: 지속형 → 강화 1회 소모 + 비전투 초기화 🔶 rule (전파 후보, [[DRIFT-077]] 개정)
- **변경(2026-07-12, 사용자 지시):** [[DRIFT-077]]의 초월을 **지속시간형(dur 6s 창) → 무지속**으로. 게이지 만석=발동 유지, **강화 서브 1회 시전 시 소모**(`overdrive_reset`), **비전투 5초 지속 시 게이지 초기화**. `OVERDRIVE.dur`·party_member `_od_timer_s/_od_dur_s`·physics 드레인 제거.
- **UI:** 초월 게이지를 오버헤드 HP바 → **캐릭터 시트(controlled_sheet) 체력 바 바로 아래** 금색 게이지 + "초월/초월 준비!" 라벨로 이동(가독성). 초월 DPS 정체성일 때만 표시.
- **구현:** `party_member`(무지속 유지·`overdrive_reset`·드레인 제거), `ability_dispatch._dps_overdrive`(empower 후 소모·2-arg overdrive_add), `party_controller`(engagement_changed→비전투 5초 one-shot 타이머→전 멤버 `overdrive_reset`), `controlled_sheet`(시트 게이지 바).
- **분류\전파:** **rule** — 초월 리소스 모델(지속→1회소모·OOC초기화) 변경. P4a 정본화 시 [[DRIFT-077]]/[[DRIFT-075]]와 함께 `ROLE-010`/`dps_binding_kit.md` 전파. `binding_fixtures.OVERDRIVE.dur`=구 지속형 잔재. 이 레포 spec md 편집 금지.
- **상태:** 🔶 구현(브랜치 커밋 · **미검증**). 플레이테스트 대기. **전파 packet:** [_PROP_PACKET_DRIFT-079-080.md](_PROP_PACKET_DRIFT-079-080.md) (적용 = P4b 배치 시점).

### DRIFT-081 — 적 상태(버프/디버프) 12시 인스펙트 시트 칩 노출 🔶 impl (전파 불필요)
- **변경(2026-07-12):** 적 좌클릭 인스펙트 패널(enemy_info, 12시)에 **버프/디버프 칩**(아이콘+한글명 상자)을 체력 아래에 나열. 적이 스스로 상태를 노출하도록 `enemy_unit.get_status_list()` 신설(stun/slow/silence + 원소 아웃컴, party_member와 동일 `{name,color,ratio,buff}` 스키마), `outcome_status`에 한글명(`KO`) 맵 추가. 샌드박스도 동일 패널 재사용(적 클릭 시 표시).
- **분류\전파:** impl(기존 상태를 표시만; 규칙·필드·enum 변경 없음). 전파 불필요, 로깅만.
- **상태:** 🔶 구현(**미커밋**). 인게임 확인 필요. (샌드박스 좌패널 접기/스크롤/휠줌차단 = dev 툴링, 비-드리프트.)

### DRIFT-082 — Shared 스킬 적↔아군 **통합**: AB-003 단일정의 파일럿(CastContext) + 캐스트 프레젠테이션 파리티 🔶 rule/design (전파 후보)
- **결정(2026-07-12, 사용자 지시·확정):** Shared 스킬은 **"같은 ID = 같은 거동"** 원칙 — 적/아군이 **단일 정의**에서 동일 발현. 두 정의(skillbooks.json 아군 / abilities.json 적)로 쪼개져 사용패턴이 갈리던 이중유지를 폐지. **fodder(EN-011)가 3초 캐스트하는 것도 확정 OK**(재배정 불필요). 아키텍처 = **"능력 해소 1개 + 캐스팅 프론트엔드 2개"**: 해소(효과·VFX·캐스트시간·damage_mult·delivery·상태)는 통합, 선택/조준(플레이어 수동 vs 적 AI 타겟팅/이동)은 진영별 유지(본질적으로 다름). base는 시전자 속성(`basic_damage` vs `contact_damage`).
- **구현(AB-003 파일럿):** 신규 [cast_context.gd](../scripts/combat/abilities/cast_context.gd) 진영-flip 파사드 — 진영별 분기 3개(`enemies_in_radius`→적이면 party, `deal_damage`→적이면 `take_damage`, `spawn_projectile`→caster 마스크+self ctx); shake/lightning/destructibles는 party dispatch 위임. `enemy_unit` `basic_damage`/`class_id` 읽기 별칭(=contact_damage/enemy_id)+`windup_unified`. `combat_controller.resolve_unified_cast`+`_enemy_cast_ctx` 마운트. `ability_dispatch.skill_for(kind)`. `enemy_ai._unified_cast`(skillbook `unified:true` 감지)→윈드업=cast_s(아군 동일)→resolve를 **공유 `sb_bolt`** 로 라우팅(투사체가 벽/차폐 처리→LOS 게이트 없음=아군 동일). **데이터 단일화:** skillbooks.json AB-003 `unified:true` / abilities.json AB-003=selection 스텁(kind+channel+cooldown만; drift나던 telegraph 0.7·mult 1.3·vfx **제거**).
- **프레젠테이션 파리티(부속 변경):** (a) 적 통합 캐스트도 **HP바 위 CastBar**(아군 CastBar 재사용·진행률)+charge_up 구체+sb_bolt 투사체 = 아군과 동일 시각. (b) 아군 캐스트에 **charge_up "전격 모으기" VFX** 확장(`skill_cast` `charge_color`, `lightning:true`만). (c) **캐스트 중 평타 정지**(`combat_controller` `is_channeling()` 게이트, 적 `winding` 직렬화와 **대칭**; 아군 cast_s wind-up만·identity/AB-054 채널 제외).
- **분류\전파:** **rule/design** — spec `D-016` §3.6.1(적 telegraph 밴드=역할별 배정)과 충돌: 통합 스킬의 telegraph는 **능력 내재**(cast_s), 밴드 배정 아님. + 스킬북 스키마 **`unified` 신규 필드**. OPS_30 전파 4건: (i) unified-skill 개념 + "해소1·프론트엔드2" 모델, (ii) §3.6.1을 **비통합 적 능력** 스코프로 한정, (iii) AB-003 SSOT(`docs/combat/abilities/AB-003`) 통합 표기, (iv) skillbook 스키마 `unified`. **파일럿=AB-003만**; 잔여 대칭 subset(strike/stun/poison/cold) 마이그레이션=follow-on. 이 레포 spec md 편집 금지. 전파 packet: [_PROP_PACKET_DRIFT-082.md](_PROP_PACKET_DRIFT-082.md).
- **상태:** 🔶 구현·**sandbox 확인(사용자, 2026-07-12)**·커밋(브랜치 `wip/casting-ab054-overdrive-20260712`). ci_smoke **7/7 PASS**. 전파=배치 시점([[DRIFT-079]]/[[DRIFT-080]] 배치와 동반 후보).

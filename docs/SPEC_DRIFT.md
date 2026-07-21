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
- **분류\전파:** 파일럿 로컬(binding_overlays = CombatContentMap-UNREGISTERED 비정본). rule·scope 변경 — P4a 정본화 시 「집중」 빌드 규칙 + **결속 NC 스코프(`F-020 §3.3`) 재검토**와 함께 OPS_30 전파. 이 레포에서 spec md 편집 금지.
- **상태:** 🕒 파일럿 수정. 게임 내 플레이테스트 확인 대기.

### DRIFT-077 — DPS 결속 「초월(Overdrive)」 / 「혈풍(Blood Gale)」 파일럿 (press_line/arc_weave) 🕒 파일럿 신규 (전파 보류)
- **감독 설계(2026-07-08):** DPS 두 정체성의 운영 루프를 감독이 직접 지정. **역할 원칙 = 단일표적은 누커, DPS는 애초에 광역** → DPS 공유 3서브를 기본부터 AoE로(작열 폭발 fire 원형 / 절단 광선 beam 라인 / 빙결 파동 cold 원형). 누커 볼트 재탕 금지.
- **「초월」(press_line/IDA-024):** 스킬·평타 명중마다 게이지↑, 가득 차면 dur초 **강화 변형**. 강화 = **단순 배수 아님, 효과 변화**(ref=LoL 카르마 Mantra): fire→화상(Ignited·**적한정 DoT**, 장판 대신 상태라 아군 무피해) / beam→끌어당김 / cold→빙결(Rooted). 게이지·강화 모두 **조작/AI 공통**([[DRIFT-076]] 스코프) — AI가 게이지를 쌓고, 켜지는 순간 조작 전환해 몰아치는 루프.
- **「혈풍」(arc_weave/IDA-027):** 서브 시전당 max_hp 12% 소모, **명중 적 1기당 5% 회복**(3기+ 순이득). 서브가 애초에 광역이라 억지 스플래시 없이 성립. 자살 불가(hp_floor 클램프). 적 多=유지 / 적 少=손해 → 누커로 전환 유도.
- **구현:** `BindingOverlays.OVERDRIVE/BLOODGALE` + BIND-019~024(6). party_member 게이지 상태·틱·`blood_soak`, health_bar 초월 게이지 바, overhead_badges 「초월」. dispatch `overdrive_charge`/`blood_soak` 델타 + kind 분기 강화(`_dps_overdrive_empower`) + 명중 집계(radius/cone). 서브 데이터: AB-053/041 cast_s(DRIFT-075), AB-053/054/041 한글명.
- **분류\전파:** 파일럿 로컬(비정본). rule·scope(캐스터 광역·초월 리소스·NC 공통) — P4a 정본화 시 [[DRIFT-075]]/[[DRIFT-076]]와 함께 spec `ROLE-010`/`D-016` 전파. 이 레포에서 spec md 편집 금지.
- **상태:** 🕒 파일럿 구현(binding_smoke 23 + ci_smoke 대상). 플레이테스트 확인 대기. 설계 정본 = `docs/design/dps_binding_kit.md`.

### DRIFT-078 — I-006 캐스팅 확장 패스: 캐스터 서브 즉발→캐스트/채널 정합 (엄브렐러) 🔶 impl/tuning (진행 중)
- **배경(2026-07-09~):** [[DRIFT-075]] 원칙(캐스터=캐스트/채널 중심) 적용 — 캐스터 서브 ~29종 즉발을 스킬 하나씩 샌드박스 핑퐁으로 캐스트/방향/효과 정합. **수치 밸런싱은 스킵**(명백한 파손·방향만). 세부 대칭 원장 = `docs/_WIP_casting_expansion_pass.md` §4(패스 종료 시 삭제, 정본=이 항목). 티어 밴드 A(0~0.4s)/B(3~5s)/C(8~15s).
- **완료분(cast_s 부여):** AB-041(cold) 0.8→3.5(B) · AB-053(fire 작열) 0.6→3.0(B) · AB-064(channel_heal) 2.0→3.0 · AB-004(bolt) 0.5→4.0(B) · AB-059(bolt) 1.5→5.0(B) · AB-066(channel_heal 궁극) 5.0→10.0(C) · **AB-003(bolt)** +cast_s 3.0·cd 2→6·radius 1.6→4.0(A→B).
- **효과·결속 변경:** **AB-002 Shield Bash** — 반경 4→8·dmg ×2.5→×1.0·cd 4→2(Anchor 방벽충전 스팸형 궁합) + 발동 프레임 반경 telegraph 링 + **헛스윙도 차지/쿨 소모**(반응형 CC는 명중이 아니라 휘두름이 비용, `sb_strike`). **AB-003 초월 링크** — press_line 초월 중 감전 폭주(`skillbook_bolt`→`apply_silence` 2.0s, AB-044 API 재사용) + `OVERLAYS` `BIND-026`(press_rod·IDA-024·AB-003@slot0, AB-053과 슬롯 공유). [[DRIFT-077]] 초월 kind 분기 확장.
- **⚡ 어텐션 이코노미 보강(2026-07-12, 사용자 결정 — rule):** 딜 최소주의 — **딜 서브(Nuker/DPS)=긴 캐스트+긴 쿨+큰 한방**("가끔·중요"), Tank=반응형 즉발 OK, Healer 큰 힐=긴 캐스트+쿨, Movement 상시. + **규칙5(통합 refine):** Shared 기본 통합, 진영분기는 **새 적 전용 스킬(신규 ID)** 로만(같은 ID 분기 금지). **rule-level → OPS_30 전파 후보**([[DRIFT-082]]/[[DRIFT-075]] 배치 동반). 세부=WIP §0.
- **AB-005 Melee Flurry(2026-07-12):** 즉발 스팸필러(cd1)→**커밋 근접 버스트**(cast_s 3.0·cd 10·dmg ×1→×3·range_band Mid→Melee) + Nuker 집중 바인딩(BIND-027). 규칙5 적용: EN-010=빠른 rush라 AB-005 제거→기본평타(abilities.json AB-005 orphan).
- **분류\전파:** impl/tuning(cast_s·수치=로깅만). 단 [[DRIFT-075]] castTier 원칙 자체는 P4a에서 OPS_30 전파 대기 — 개별 cast_s 값은 그 하위 튜닝. 이 레포 spec md 편집 금지.
- **상태:** 🔶 진행 중(위 8 AB + **AB-005** 완료, 잔여 ~20 AB는 ENC 순회). **미커밋**. ci_smoke 7/7. ⚠️ 어텐션 이코노미 rule은 기판정 딜 서브 **쿨 소급 검토** 후보(예: AB-003 cd6이 "가끔"에 아직 잦음).

### DRIFT-079 — AB-054 절단 광선: 채널 rootDuringCast/점유 폐지 → 인터럽트형 채널 🔶 rule (전파 후보)
- **변경(2026-07-12, 사용자 지시):** AB-054 빔 채널이 시전자에 걸던 **셀프 Rooted(이동잠금) + begin_channel 점유(타 시전 차단)를 제거**. 대신 **인터럽트형** — 이동(시전지점 0.3m 이탈)·다른 스킬 시전·기절/다운 시 채널이 **중단**된다(강제 차단 아님).
- **UI:** 채널 진행을 **감소형 바**(캐스팅바가 좌→우 차오르는 것과 반대로 우→좌 소진·청록색)로 표시 — "속박" 상태 텍스트/오브 제거. 조준은 원형 원판→**직선 레인**(시전자→마우스, 길이=사거리·너비=빔폭).
- **구현:** `beam_channel`(감소바+이동/중단 감시+`cancel_channel`), `sb_beam`(Rooted/begin_channel 제거→`set_active_channel`), `party_member`(`_active_channel`+`interrupt_active_channel`), `ability_dispatch.cast_skillbook`(새 시전 시 채널 중단), `aim_marker.show_beam`/`aim_controller`(직선 조준+방향 즉시 시전). `begin_channel`/`is_channeling`은 wind-up 캐스트(skill_cast)용으로 유지.
- **분류\전파:** **rule** — 스펙 `D-016` `rootDuringCast`/`castTier`(채널 성격)와 직접 충돌. [[DRIFT-075]] 캐스터 원칙 전파 시 함께 OPS_30(채널=인터럽트형·비점유 모델) 전파 후보. `ImplDecisionLog.md`의 "Beam=cone+Rooted move-lock" 노트 outdated → 갱신 필요. 이 레포 spec md 편집 금지.
- **상태:** ✅ **전파 완료·푸시**(spec `751097a` origin/staging, `DEC-20260720-002` — 채널=비잠금 인터럽트형 → `D-016` §3.6 + `STATUS-ACTOR-CORE` `Channeling` 정정). **080도 클러스터2 `DEC-20260720-005`로 전파 완료** → `_PROP_PACKET_DRIFT-079-080.md` 소진(삭제).

### DRIFT-080 — DPS 「초월」 운영 개편: 지속형 → 강화 1회 소모 + 비전투 초기화 🔶 rule (전파 후보, [[DRIFT-077]] 개정)
- **변경(2026-07-12, 사용자 지시):** [[DRIFT-077]]의 초월을 **지속시간형(dur 6s 창) → 무지속**으로. 게이지 만석=발동 유지, **강화 서브 1회 시전 시 소모**(`overdrive_reset`), **비전투 5초 지속 시 게이지 초기화**. `OVERDRIVE.dur`·party_member `_od_timer_s/_od_dur_s`·physics 드레인 제거.
- **UI:** 초월 게이지를 오버헤드 HP바 → **캐릭터 시트(controlled_sheet) 체력 바 바로 아래** 금색 게이지 + "초월/초월 준비!" 라벨로 이동(가독성). 초월 DPS 정체성일 때만 표시.
- **구현:** `party_member`(무지속 유지·`overdrive_reset`·드레인 제거), `ability_dispatch._dps_overdrive`(empower 후 소모·2-arg overdrive_add), `party_controller`(engagement_changed→비전투 5초 one-shot 타이머→전 멤버 `overdrive_reset`), `controlled_sheet`(시트 게이지 바).
- **분류\전파:** **rule** — 초월 리소스 모델(지속→1회소모·OOC초기화) 변경. P4a 정본화 시 [[DRIFT-077]]/[[DRIFT-075]]와 함께 `ROLE-010`/`dps_binding_kit.md` 전파. `binding_overlays.OVERDRIVE.dur`=구 지속형 잔재. 이 레포 spec md 편집 금지.
- **상태:** ✅ **전파 완료·푸시**(spec `fb4f16c` origin/staging, `DEC-20260720-005` — `IDA-024` §Keystone "6초 지속창→강화 1회 준비·시전 시 소모·비전투 5초 초기화" + `ROLE-000` §C-4). 샌드박스 체감 확인분(DRIFT-087 세션). packet `_PROP_PACKET_DRIFT-079-080.md` 소진(삭제).

### DRIFT-081 — 적 상태(버프/디버프) 12시 인스펙트 시트 칩 노출 🔶 impl (전파 불필요)
- **변경(2026-07-12):** 적 좌클릭 인스펙트 패널(enemy_info, 12시)에 **버프/디버프 칩**(아이콘+한글명 상자)을 체력 아래에 나열. 적이 스스로 상태를 노출하도록 `enemy_unit.get_status_list()` 신설(stun/slow/silence + 원소 아웃컴, party_member와 동일 `{name,color,ratio,buff}` 스키마), `outcome_status`에 한글명(`KO`) 맵 추가. 샌드박스도 동일 패널 재사용(적 클릭 시 표시).
- **분류\전파:** impl(기존 상태를 표시만; 규칙·필드·enum 변경 없음). 전파 불필요, 로깅만.
- **상태:** 🔶 구현(**미커밋**). 인게임 확인 필요. (샌드박스 좌패널 접기/스크롤/휠줌차단 = dev 툴링, 비-드리프트.)

### DRIFT-082 — Shared 스킬 적↔아군 **통합**: AB-003 단일정의 파일럿(CastContext) + 캐스트 프레젠테이션 파리티 🔶 rule/design (전파 후보)
- **결정(2026-07-12, 사용자 지시·확정):** Shared 스킬은 **"같은 ID = 같은 거동"** 원칙 — 적/아군이 **단일 정의**에서 동일 발현. 두 정의(skillbooks.json 아군 / abilities.json 적)로 쪼개져 사용패턴이 갈리던 이중유지를 폐지. **fodder(EN-011)가 3초 캐스트하는 것도 확정 OK**(재배정 불필요). 아키텍처 = **"능력 해소 1개 + 캐스팅 프론트엔드 2개"**: 해소(효과·VFX·캐스트시간·damage_mult·delivery·상태)는 통합, 선택/조준(플레이어 수동 vs 적 AI 타겟팅/이동)은 진영별 유지(본질적으로 다름). base는 시전자 속성(`basic_damage` vs `contact_damage`).
- **구현(AB-003 파일럿):** 신규 [cast_context.gd](../scripts/combat/abilities/cast_context.gd) 진영-flip 파사드 — 진영별 분기 3개(`enemies_in_radius`→적이면 party, `deal_damage`→적이면 `take_damage`, `spawn_projectile`→caster 마스크+self ctx); shake/lightning/destructibles는 party dispatch 위임. `enemy_unit` `basic_damage`/`class_id` 읽기 별칭(=contact_damage/enemy_id)+`windup_unified`. `combat_controller.resolve_unified_cast`+`_enemy_cast_ctx` 마운트. `ability_dispatch.skill_for(kind)`. `enemy_ai._unified_cast`(skillbook `unified:true` 감지)→윈드업=cast_s(아군 동일)→resolve를 **공유 `sb_bolt`** 로 라우팅(투사체가 벽/차폐 처리→LOS 게이트 없음=아군 동일). **데이터 단일화:** skillbooks.json AB-003 `unified:true` / abilities.json AB-003=selection 스텁(kind+channel+cooldown만; drift나던 telegraph 0.7·mult 1.3·vfx **제거**).
- **프레젠테이션 파리티(부속 변경):** (a) 적 통합 캐스트도 **HP바 위 CastBar**(아군 CastBar 재사용·진행률)+charge_up 구체+sb_bolt 투사체 = 아군과 동일 시각. (b) 아군 캐스트에 **charge_up "전격 모으기" VFX** 확장(`skill_cast` `charge_color`, `lightning:true`만). (c) **캐스트 중 평타 정지**(`combat_controller` `is_channeling()` 게이트, 적 `winding` 직렬화와 **대칭**; 아군 cast_s wind-up만·identity/AB-054 채널 제외).
- **분류\전파:** **rule/design** — spec `D-016` §3.6.1(적 telegraph 밴드=역할별 배정)과 충돌: 통합 스킬의 telegraph는 **능력 내재**(cast_s), 밴드 배정 아님. + 스킬북 스키마 **`unified` 신규 필드**. OPS_30 전파 4건: (i) unified-skill 개념 + "해소1·프론트엔드2" 모델, (ii) §3.6.1을 **비통합 적 능력** 스코프로 한정, (iii) AB-003 SSOT(`docs/combat/abilities/AB-003`) 통합 표기, (iv) skillbook 스키마 `unified`. **파일럿=AB-003만**; 잔여 대칭 subset(strike/stun/poison/cold) 마이그레이션=follow-on. 이 레포 spec md 편집 금지. 전파 packet: [_PROP_PACKET_DRIFT-082.md](_PROP_PACKET_DRIFT-082.md).
- **상태:** ✅ **전파 완료**(spec `751097a`, `DEC-20260720-001` — `D-016` §2 `unified` 필드 + §3.6.1 밴드 예외). ci_smoke 검증분. packet `_PROP_PACKET_DRIFT-082.md` 소진(삭제).

### DRIFT-083 — 전투 템포 개편: 능력 role/exec 레지스트리 + 캐스트 페이싱(알파 스트라이크) + 전투 감속 🔶 rule/impl (전파 후보)
- **배경(2026-07-13, 사용자 결정):** 체감 "급한 AOE → 정제된 MMORPG". (설계 계획 문서는 IN-scope 완료 후 제거 — 기록 = 본 DRIFT-083 + 커밋 `ee0207b`~`c141e10`.) 시퀀싱 **(b) 분리**(role+캡 먼저 / 적→shared 이사=[[DRIFT-082]] 병행), 점2 힐러·데미지 defer.
- **role/exec 레지스트리(impl):** 신규 [ability_roles.gd](../scripts/combat/abilities/ability_roles.gd) — 27 AB를 `{kind, role, exec}` 로 **중앙 등재**(shared·적고유·예외 전부). role(threat/control/**debuff**/support/buff/reposition/utility)=목적 축(**캡 판정=threat·control**), exec(shared/ai_internal/hybrid)=실행 라우팅, kind=delivery(유지). enemy_ai 흩어진 문자열 분기의 SOT화 준비. **경계 핑퐁 1차:** AB-100→control, AB-012→**debuff**(신설·캡X), AB-099=control(캡O), AB-040=utility, AB-002=threat/즉발; hybrid=AB-013/100/104.
- **캐스트 페이싱(rule, 구현):** 알파 스트라이크 방지 — (B-1) 교전 첫 틱에 per-enemy 스태거 창 `cast_stagger_s` **1.5~3.5s** 시딩, 창 동안 cap 캐스트 게이트(증원 자동 커버·비교전 시 재시딩), (B-2) 스쿼드 **K=1** 소프트 동시성 캡. 캡 판정 = `AbilityRoles.is_cap_eligible`(role∈{threat,control}), `kind` 아님. [[DRIFT-078]] 어텐션 이코노미 rule의 **런타임 실현**. 구현: `enemy_ai._cast_gated`(+cast 패스 5곳 게이트·seed/decay) · `enemy_unit.cast_stagger_s/stagger_armed` · `combat_controller.squad_cast_busy`.
- **전투 감속(수치, 구현):** 교전 시 이동 ×2/3(`COMBAT_MOVE_MULT`) — 적 `enemy_unit.current_move_speed`(engaged 게이트), 아군 `party_member.move_speed_mult`(`combat_slowed`; `party_controller._on_engagement_changed`가 `is_engaged`로 토글 → controlled+follower 공통). 비전투 현행(스프린트). **적** 텔레그래프 중 이동 정지 = `enemy_ai._engage_move` winding 게이트(채널 무관으로 확장; 아군은 기존). **팔로워/앵커 감속은 가속 前 target에 적용**(post-accel `velocity*=2/3`는 move_toward와 상호작용해 평형이 ~2.3m/s로 붕괴하던 버그 → 조작캐 패턴으로 정정, `party_controller` Pass2/3).
- **아군 선택(impl, 구현):** 좌클릭 선택 = **`SelectionController`**(dungeon_run+sandbox 공유, 씬 입력 드리프트 방지 — [[sandbox-input-parity]]) — 클릭: 아군(mask2)→스왑 / 적(mask4)→인스펙트, **드래그 박스: 안에 든 아군 중 화면 좌측(작은 x) 캐릭터로 스왑**(marquee 오버레이). + `party_controller.index_of` + 1~4 키 병존 + 머리 위 상시 번호 배지(`_add_slot_badge`).
- **분류\전파:** role/exec 레지스트리·클릭스왑·전투상태토글 = impl(게임 인코딩, spec 미핀 → 로컬 `ImplDecisionLog`). 캐스트 페이싱(스태거+캡) = **rule → OPS_30 전파 후보**([[DRIFT-078]] 어텐션 이코노미와 동반). 이동 ×2/3·텔레그래프 정지 = 튜닝 수치(로깅만). 이 레포 spec md 편집 금지.
- **상태:** ✅ **캐스트 페이싱(B) 전파 완료·푸시**(spec `ace95e0`, `DEC-20260720-008` — `F-013` §3.4.1 진입 스태거 + 분대 동시성 캡 K=1 + `D-016` §3.6.1 상호참조). B 샌드박스 확인분. **role 레지스트리·클릭스왑(C)·감속(A) = impl/튜닝**(전파 안 함, 로컬 `ImplDecisionLog`). A·C 샌드박스 확인은 잔여(비-전파).

### DRIFT-084 — 적 fire 통합(AB-053) + 신규 불 캐스터 EN-015 + `enemy_fire` kind · 사물 상호작용 프로토콜 확장 · ctx 계약 게이트 🔶 rule/impl (일부 전파 후보)
- **배경(2026-07-18, 사용자 지시):** oil 배럴 콤보용 "불 적" 요구. 실사 결과 (a) [sb_fire.gd](../scripts/combat/abilities/effects/sb_fire.gd)가 이미 배럴 파괴(`damage_destructibles`)+Oil 점화(`fire_hit`) 내장, (b) unified 적 시전 파이프라인(`resolve_unified_cast`+`CastContext`) 재활용 가능. **EN-004 zone 판정([[DRIFT-078]] §8) 보존** 위해 기존 적 교체 대신 별도 신규 적 신설.
- **fire 통합(전파 후보):** AB-053 `unified:true` — [[DRIFT-082]] fire subset(bolt/poison에 이은 3번째). abilities.json AB-053 = `enemy_fire` selection 스텁(kind+channel+cooldown). **`enemy_fire` = 신규 kind enum**(`enemy_ai.gd` gate_kinds 추가). `ability_roles.gd` 등재(threat/shared). resolve는 공유 `sb_fire`(신규 enemy_ai 경로 불요 — 파이프라인 재활용). → **enum 변경 = OPS_30 전파 후보.**
- **EN-015 신규 적(전파 후보):** Cinder Adept — nuker/PT-002 standoff/AB-053. **spec 원장에 없는 신규 엔티티(스코프)** → id_registry 게임 등록(1:1 위반 감수, **프로토타입**). `axis=fire`(신규). stats/basic=EN-005 참조·재활용. sb_fire를 배럴 근처 시전 시 RX-OIL-FIRE 콤보 자동(배럴 opportunistic 상호작용 불요). → **스코프 = OPS_30 전파 후보.** ⚠️ AB-053 적 거동 밸런스·telegraph 감각 = [[DRIFT-078]] §4 캐스팅 패스 **스킬단위 판정 대상**(급조 아님).
- **사물 상호작용 프로토콜 확장(impl, F-021 §3.1.2):** enemy-usable 오브젝트 계약 명시화 — `ENEMY_USABLE_REQUIRED`(enemy_usable·enemy_use 필수) + optional `enemy_combat_tick`(held형) + `ENEMY_USABLE_OBJECTS` 코드 배열 레지스트리 + `object_smoke` 게이트(부분구현 크래시 차단, ctx 게이트와 동형). barrel `enemy_usable`(즉발형). **`interaction_policy` = priority(torch·항상 최우선)/opportunistic(배럴·'어쩌다': 우선순위↓ + 근처 usable + 확률 롤 + `object_committed` 완주).**
- **ctx 계약 게이트(impl, 별도 커밋 `1972618`):** ctx 이중 facade(AbilityDispatch/CastContext) 파리티 — `CTX_CONTRACT` SSOT + `party_pool_smoke` 파리티 게이트, CastContext 갭 **15개**(fire_hit/cold_hit 포함) 메움, kind/role 조용한실패 `push_error` 승격 + role 전수검증. combat_controller 공간쿼리 순수필터 추출. [[DRIFT-082]] 통합의 안전 확장(strike/stun/cold subset unified 시 throw 제거).
- **분류\전파:** `enemy_fire` enum·EN-015 스코프 = **rule → OPS_30 전파 후보**([[DRIFT-082]] 배치와 동반). 사물 상호작용·ctx 게이트·`interaction_policy` = impl(로컬 [ImplDecisionLog](impl_decisions/ImplDecisionLog.md)). 이 레포 spec md 편집 금지.
- **상태:** 🔶 구현·ci_smoke **8/8 PASS**(`object_smoke` 신설 포함, ctx 파리티 46·role 25). ✅ **부분 전파**(spec `751097a`, `DEC-20260720-004` — `EN-015` Cinder Adept 신규 + `AB-053` `usable_by_enemy=true`). ⚠️ **`enemy_fire` kind enum·적 `axis` 필드 = impl 잔류**(전파 안 함 — 주로 라우팅, 감독 결정). EN-015 fire telegraph·배럴 콤보 샌드박스 체감 대기.

### DRIFT-085 — 이동(blink/dash) 계열 정리: AB-061→AB-006 통합 · AB-013=AB-006 발전형 · 이동스킬 무캐스팅 🔶 rule/scope (전파 후보)
- **배경(2026-07-19, 사용자 결정):** [[DRIFT-078]] Phase A 스킬 전수 핑퐁의 AB-006 차례. 실사 결과 아군 blink 3종(AB-006·AB-061·AB-007a/b)이 같은 `skillbook_blink` kind에 벡터·페이로드만 다른 변주였고, **AB-006 = AB-061 − next_hit_bonus**(완전 하위집합)로 확인됨. 사용자 판정: *"퇴각이 아닌 이동기는 탱커 돌진 빼면 불필요, 특히 DPS는 이동기가 하자"*.
- **① AB-061 → AB-006 통합(scope):** `skillbooks.json`에서 **AB-061 Shadowstep 스킬북 삭제**, 페이로드 `next_hit_bonus: 0.2`는 **AB-006이 흡수**(사거리·쿨은 AB-006 값 10m·cd4 유지). AB-006의 "페이로드 0 = 죽은 슬롯"(AB-007 재설계와 동일 진단) 해소. `dungeon_run.ALLY_CACHE_POOL`에서 AB-061 제거. **AB-061은 유일한 DPS 이동 서브였으므로 → DPS 이동 서브 0**(설계-의도, 딜 전담 클래스의 하자). AB-006은 Nuker equip이라 Nuker 접근 blink만 잔존. **ID는 `id_registry`에 등록만 잔존·미사용**(AB-039 선례 — 정식 제거는 스펙 배치).
- **② AB-013 = AB-006의 발전형(design, 관계만 기록):** 계열 = *기초(접근 + 다음타 +20%) → 발전(접근 + 즉시 딜 ×1.5 + kb)*. AB-013의 **shared 유지 OK**(적 EN-008 킷 존치). **스킬트리 미구현이므로 지금은 별개 스킬로 병존** — 승급 관계는 스킬트리 배치 시 실현. 코드 변경 0.
- **③ 이동스킬 = 무캐스팅 확정(rule):** 이동 계열 시전밴드 **A(즉발) 고정** — [[DRIFT-078]] §0 어텐션 이코노미 *"Movement = 항상 가용"* 의 스킬단위 확정. AB-006 밴드 `?`→`A`. cast_s 부여 없음(데이터 변경 0).
- **④ AB-007a/b 이탈 = 「특정 적」 기준으로 전환(rule — AB-006과의 차별화, 사용자 지시):** 기존엔 양쪽 다 `nearest_enemy_in_range(20m)`이라 "막연히 최근접에서 멀어짐"이었다. → **007a(액티브)**: `targeted:true`(range 10 · 픽업 radius 2.5, `sb_stun` 어시스트 패턴) — **적을 조준했을 때만 발동**하고 그 적의 반대로 블링크. 대상 없으면 `return false` = **no-op(차지·쿨 미소모)**. **007b(패시브)**: `party_member.engaged_attacker()`(최근 `ENGAGED_ATTACKER_S`=3.0s 내 나를 때린 적)의 반대. **트랩/장판 피해는 `hazard_zone`이 `take_damage(dmg)`를 attacker 없이 호출** → 교전 상대 null → **`last_move_dir()` 역방향**(왔던 길)으로 후퇴. **마무리딜 대상 = 벗어나는 그 적**(옛 최근접 폴백 제거; 트랩 이탈은 마무리딜 없음). 신규 상태 2개(`_last_attacker`+타이머 / `_last_move_dir`, 컨트롤러가 세팅한 `velocity`를 `_physics_process`가 관측). **적측 EN-005는 이미 `target`(현재 교전 대상) 기준이라 이 변경은 [[DRIFT-082]] K1 대칭에 수렴**(분기 아님).
- **⑤ AB-008 = 「광역 투사체」 원형 + 스타터 승격(design/scope, 사용자 결정 2026-07-19):** 볼트 7종이 같은 `skill_desc` 한 줄을 공유하던 걸 **원형-변형 체계**로 재정의. **AB-008 Slag Spit = 원형**(에너지를 집중 → 원거리 투사체 → 광역 피해), 나머지는 여기서 갈라지는 변형(예: **AB-003 = 원형 + 전격**). 실사 근거: 볼트 **8종 전부 `radius_m` 보유**(1.2~4.0) → 광역은 kind 속성이라 원형 주장이 데이터로 성립. **툴팁 = params 조립**([skill_text.gd](../scripts/ui/skill_text.gd) `describe`, 기존 `single_target_mult` 선례와 동형) — `cast_s>0`→"에너지를 집중한 뒤" 접두 · `lightning`→"전격 …감전" 후미. 스키마 변경 0이고 **스킬마다 참**(즉발/비-전격 변형에서 거짓말 안 함). `skill_desc.skillbook_bolt`에 **광역** 명시(기존 문장은 광역을 안 말했음).
  - **AB-008 A→B 밴드:** `cast_s 3.0` 신설 + `cd 2.5→5`(§0 "캐스트가 쿨을 넘으면 쿨도 동반 상향" 규칙, AB-003 선례 cd6보다 짧게 = 기초). `damage_mult 0.8` **유지** — 원형이 변형보다 약한 게 의도. ⚠️ 3초 캐스트에 ×0.8은 §0 "큰 한방"에 미달 → **Phase B 딜 튜닝 대상**(로깅만).
  - **스타터 시드 교체:** [backpack.gd `_seed()`](../scripts/autoload/backpack.gd) DPS 자리 **AB-028 Guard Break Rhythm → AB-008**. 스타터에 **첫 딜 서브**가 생긴다(기존 5권은 전부 유틸). AB-028은 `ALLY_CACHE_POOL` 잔존이라 획득 경로는 유지.
  - ✅ **이월 2건 해소 → [[DRIFT-086]]:** (i) 결속 축 어긋남(성립=AB 단 / 발현=kind 단) (ii) AB-008 unified. 아래 참조.
  - ❌ **정정(2026-07-19):** 본 항목 초안과 [[DRIFT-078]] §8.5에 *"BIND-026이 kind 분기라 AB-008에도 자동 적용 → 볼트 2종 차별성 0"* 이라 적었으나 **틀렸다.** `BindingOverlays.resolve`는 `slot_ab` **정확 일치**를 요구하고 AB-008은 OVERLAYS에 없다 → 결속이 **아예 안 붙는다**(게이지도 안 참). 중복이 아니라 **부재**였다. §8.5 원문도 같은 오류 — 함께 정정 대상.
- **AB-006 적측 무변경:** EN-003 `exec: ai_internal`(`enemy_dash`, `hit_on_arrival:false`) 존치 — 게임 내 **유일한 무피해 리포지션 대시**이자 `_is_hit_run_flanker` stick/hit-run 분기와 teal/crimson 시각 언어의 한 축. AB-013으로의 교체안은 **기각**(EN-003이 EN-008의 상위 사본이 되고 근접 flurry 평타와 킷이 충돌).
- **⚠️ 선행 미로깅 발견:** [[DRIFT-078]] HARD-001에서 신설된 **AB-007a/AB-007b ID 2종**이 `id_registry.json:124-125`에 등재됐으나 **본 문서에 드리프트 항목이 없다.** 신규 ID + "스킬트리 택1" 구조 = rule/scope 전파 대상 → **소급 로깅·전파 처리 필요**(사용자 판단 대기).
- **분류\전파:** AB-061 폐기(아군 풀 스코프)·AB-013 승급 계열 = **rule/scope → OPS_30 전파 후보**([[DRIFT-078]] 패스 확정분과 동반 배치). 이동 무캐스팅 = [[DRIFT-078]] §0 rule의 스킬단위 확정(동반). `next_hit_bonus` 이전 = 필드 이동(스키마 변경 없음). 이 레포 spec md 편집 금지.
- **상태:** ✅ **전파 완료**(spec `751097a`, `DEC-20260720-001/002/004` — 이동밴드=A(`D-016` §3.6) · `AB-061` 폐기→`AB-006` 흡수 · `AB-007`→`007a`/`007b` 분할). 샌드박스 체감 확인 완료(2026-07-20).

### DRIFT-086 — 결속 발현 축을 kind→**AB 단(`variant`)**으로 + 속성 `element` 필드 신설 · AB-008 unified 🔶 rule/schema (전파 후보)
- **배경(2026-07-19, 사용자 결정):** [[DRIFT-085]] ⑤에서 AB-008을 「광역 투사체」 원형으로 승격하며 드러난 구조 문제. 사용자 판정: *"속성은 AB단에서 저장 · bind로 강화/변형되는 것도 AB단에서 지정 · kind는 bind와 묶일 이유가 없음."*
- **① 진단 — 결속의 두 축이 어긋나 있었다.** **성립**(`BindingOverlays.resolve`)은 gear+identity+`slot_ab`+slot의 **AB 단 정확 일치**인데, **발현**(`_dps_overdrive_empower`·`_dps_blood_soak`)만 `match kind`였다. 지금까지 충돌이 없던 건 IDA-024 등록 5종이 **5 AB : 5 kind로 우연히 1:1**이었기 때문(fire/bolt/beam/cold/poison). **같은 kind의 두 번째 AB를 등록하는 순간 구분 불가** → 볼트 8종·존 5종·실드 3종·피해감소 6종 계열 전부가 같은 천장에 걸린다. 근본 원인 = **`kind`(delivery)를 속성(서사)의 대용으로 쓴 것** — 볼트 안에 슬래그(물리)와 전격이 섞이면서 대용이 깨짐.
- **② `variant` 키 신설(OVERLAYS, 게임 SSOT):** BIND 항목이 자기 강화 변형을 **직접 지정**. IDA-024 초월 5종 = `burn`(AB-053)·`silence`(AB-003)·`gravity`(AB-054)·`freeze`(AB-041)·`venom`(AB-010) / IDA-027 혈풍 4종 = `burst`(AB-053·AB-010)·`siphon`(AB-054)·`iceblood`(AB-041). `_apply_binding`이 `ov`를 empower까지 관통시키고 `match variant`로 분기. **미지정 = `push_error`**(조용한 실패 승격, DRIFT-084 규약). ⚠️ 기존 `payoff` 키는 **사람이 읽는 설명 문자열**이라 재사용 불가 — 그래서 신규 키.
  - **효과:** 같은 kind의 AB를 여럿 등록해도 각자 다른 변형을 가진다. AB-008을 초월 킷에 넣어도 AB-003의 감전폭주와 섞이지 않음(원형/변형 체계의 전제 조건).
- **③ `element` 필드 신설(skillbook 스키마 — ⚠️ 신규 필드):** 속성을 **AB 단 데이터**로 분리(`cast.element`). `kind`(전달 방식)와 **독립**. 부여 11종 = lightning(AB-003/004/056/058/073) · slag(**AB-008**) · fire(AB-037/053) · cold(AB-041/072) · poison(AB-010). **명확히 도출되는 것만** 부여, 나머지(AB-055/059/054 등)는 Phase A 각 스킬 판정 때 채움(임의 작명 회피). 툴팁 전격 분기를 `lightning` 플래그 → `element == "lightning"`로 이관. ⚠️ **`lightning: true` 플래그는 존치** — `sb_bolt`의 Shock RX 트리거라 제거하면 반응계가 끊긴다. **element = 속성 정체성 SSOT / lightning = RX 트리거**로 당분간 병존, 통합은 후속.
- **④ AB-008 unified(rule — [[DRIFT-082]] subset 4번째):** `skillbooks.json` `unified: true` + `abilities.json`을 스텁으로 축소(`{enemy_splash, channel, cooldown_s 5.0, unified}`). 적 EN-004가 아군과 **같은 정의**로 시전 — `_unified_cast`가 스킬북 `cast`를 읽어 윈드업을 굴리고 공유 `sb_bolt`로 해소. `enemy_splash`는 이미 `gate_kinds` 등재라 enum 추가 불요. **거동 변화: 적 시전 0.4s → 3.0s, splash 1.5m+60%감쇠 → radius 2.0m 균일.** ⚠️ **밸런스 영향이 크다** — [[DRIFT-078]] §8.3 "적 3s가 tele 0.4 대비 굼뜬가" 체감 항목이 이걸 직접 묻는다(fodder EN-011 3초 OK 선례 있음).
- **분류\전파:** `element` **신규 스키마 필드** + AB-008 unified = **rule/schema → OPS_30 전파 후보**(`D-016` 스킬북 스키마 · [[DRIFT-082]] unified subset과 동반). `variant` = OVERLAYS 키인데 **binding_overlays.gd는 게임이 SSOT**(IMPL-DEC-20260709-001)라 전파 압력 낮음 — P4b 결속 정본화 배치에 동반. 이 레포 spec md 편집 금지.
  - ⚠️ **배치 트리거 발동:** "스키마 필드가 또 하나 늘어나면 그 시점에 배치"(전파 보류 결정 시 합의한 체크포인트)에 `element`가 해당한다 — **전파 시점 재판단 대상**.
- **상태:** ✅ **전파 완료·푸시**(element = spec `751097a` `DEC-20260720-001` / **variant = spec `fb4f16c` `DEC-20260720-006`** — 결속 변형 발현축 kind→AB단, `IDA-024`/`027` §Keystone + `ROLE-020` §4.5). 샌드박스 체감 확인 완료(2026-07-20). ⚠️ 스타터 시드 교체는 샌드박스 경로 밖(허브 `reset_to_seed` 필요) → **미확인 잔여**.

### DRIFT-087 — 결속을 whitelist→**정체성 기본 델타(GENERIC)**로 전환: 등록 없이 장착 서브 전부 적용 🔶 rule/design (전파 후보, [[DRIFT-077]] 파일럿 스코프 개정)
- **배경(2026-07-19, 사용자 결정):** [[DRIFT-086]] ①의 후속. 사용자 제안 — *"identity에 직접 연결되는 generic형 변형은 AB마다 추가하기보다 identity가 어떤 스킬에든 generic하게 적용되도록"*. **「정체성별 동일 3서브」 평가 패리티 제약은 검증 완료로 해제**(사용자: "이제 필요없어").
- **진단 — generic 델타의 등록 항목은 정보를 담지 않았다.** 각 핸들러가 AB별 정보를 쓰는지 실사: `bulwark_charge`·`beacon_mark`·`focus_stack` = **전혀 안 씀**, `flank_strike` = 스킬북 `range_band`만(데이터 기반, 하드코딩 없음). 결정적 증거로 **Anchor의 BIND-001/002/003은 세 줄이 완전히 동일**(같은 gear·identity·delta, slot만 다름) — whitelist가 차별화를 하나도 안 하고 **순수 게이팅만** 하고 있었다. 반면 초월/혈풍은 항목이 실제 정보(변형)를 담아 [[DRIFT-086]] `variant`가 필수. **Healer(IDA-031/026)는 애초에 identity 단위**(`identity_dot_heals`/`identity_sanctuaries`가 gear+identity만 보고 치유 choke를 게이트) — 이미 generic이었다.
  - **비용이 아니라 위험이었다:** 미등록 = **조용한 기능 상실**. 실제 사례 = AB-008이 OVERLAYS에 없어 결속 델타 0이었는데 [[DRIFT-078]] §8.5는 이를 "중복(차별성 0)"으로 **정반대 오진**했다([[DRIFT-086]] 정정분). 61서브×8정체성 = 최대 488항목인데 현재 36 → Phase A 진행 시 누락이 계속 발생.
- **구현:** `binding_overlays.gd`에 **`GENERIC`**(identity → {delta, variant?, theme, desc_ko}) 신설 + **`resolve_effective()`** = OVERLAYS 변주 우선, 없으면 GENERIC 기본 델타(결과에 `generic: true` 표시). 호출부 **3곳 전부 전환**(`_apply_binding` · `aim_controller`(잠행 근접 사거리) · `controlled_sheet`(툴팁)) — `resolve()` 직접 호출 잔여 0. OVERLAYS는 이제 **변주/특수만** 담는다(초월·혈풍 variant · 슬롯 변주 `mark_refresh`/`focus_spread`/`flank_dash`/`focus_dump` · 이탈 결속 slot -1).
  - **IDA-024 초월 기본 = 게이지 충전만**(`variant: ""`), 강화 변형은 AB 단 등록분만. empower의 `""` 케이스를 **정상 통과(pass)** 로 두고, OVERLAYS 항목인데 variant가 미구현인 경우만 `push_error` — "저작 전"과 "저작 버그"를 구분. **IDA-027 혈풍 기본 = `burst`**(흡수 폭발), beam/cold만 OVERLAYS가 덮어씀.
- **거동 변화(의도):** 정체성을 착용하면 **장착한 모든 서브가 기본 델타를 받는다.** 조합 폭은 `equip_classes` 게이트가 이미 제한(정체성 클래스에 장착 가능한 서브만) — 전수 검토 불요(사용자 확인). ⚠️ **잠행(IDA-029)은 파급이 크다**: 이제 **모든 장착 서브가 근접 강제**가 된다(covenant *"정체성이 근접 교전을 강제한다"*와는 정합하나 로드아웃 체감이 크게 바뀜). ⚠️ **훅 없는 서브는 여전히 무효과**(존·블링크는 명중/치유 훅이 없어 `focus_stack`·`dot_heal`이 걸리지 않음, [[DRIFT-078]] §8.5) — generic이 이 문제를 해결하진 않으나 악화시키지도 않음.
- **초월 소모 = 강화가 실제로 발현됐을 때만(rule, 사용자 결정 2026-07-20):** *"초월에 바인딩되지 않는 서브클래스의 스킬군은 초월을 소비하지 않도록."* 기존 `_dps_overdrive`는 초월 활성 중이면 **무조건 `overdrive_reset()`** 이라, 아래 두 경우에 **아무 이득 없이 초월만 날아갔다** — ① 비주력 게이트로 강화가 막힌 서브 ② `variant` 미저작(GENERIC 기본 델타) 서브. → `_dps_overdrive_empower`가 **`bool`(강화 발현 여부)을 반환**하고, 호출부는 `true`일 때만 소모. 게이지 **충전은 그대로**(명중 기여는 유효) — 막힌 건 소모뿐이라 초월을 아꼈다가 주력 서브에 쓰게 된다.
- **비주력(서브 클래스) = 초월 강화 변형 없음(rule, 사용자 결정 2026-07-19):** `_dps_overdrive_empower` 진입부에 `_is_main_class_sub()` 게이트 — `sub_bands`에 멤버 클래스가 있으면(B1~B3) **게이지는 차되 폭주 시 변형이 없다**(base 그대로). 판정 소스 = 기존 밴드 계수와 동일(`sub_bands.get(class_id, "B0")`). 의미: 밴드 피해 패널티(−%)에 더해 **"정체성 payoff 자체가 없다"는 2차 벽** — 비주력 서브로 정체성 킷을 채우는 걸 막는다. 툴팁도 연동(비주력+초월이면 등록 변형 설명 대신 **기본 델타 설명 + `┗ 비주력 적성 — 강화 변형 없음`**; 안 그러면 툴팁이 거짓말).
- **⚠️ 파생 — AB-041 「빙결 파동」 밴드 수정:** 위 규칙 적용 시 AB-041이 `sub_bands {DPS: "B2"}`라 **BIND-021 「절대영도」가 영구 미발동**이 된다(초월 킷 R 슬롯 payoff 상실). 사용자 판정(안 ㄴ) = **AB-041을 DPS·Nuker 양쪽 주력으로 변경** → `sub_bands` 제거. ⚠️ **선례 없음** — 다중 클래스인데 `sub_bands`가 없는(= 전 클래스 주력) **최초 스킬**이다. 스키마상 합법(`_note`: "미기재 클래스 = main(B0 full)")이나, 이 스킬만 밴드 특화 압력에서 벗어난다 → **후속 스킬 판정의 선례가 됨**(같은 냉기인 AB-072는 `{Nuker: B2}` 유지).
- **분류\전파:** **파일럿 스코프 변경**([[DRIFT-077]]/[[DRIFT-073]]/[[DRIFT-074]]/[[DRIFT-076]] 계열) — 결속 성립 규칙이 triple-match **필수**에서 **선택적 변주**로 바뀌므로 `F-020 §3.7 resolveEffectiveAbility` 서술과 SIGNATURE covenant 문구("링크된 스킬")가 개정 대상. **rule/design → OPS_30 전파 후보**(P4b 결속 정본화 배치와 동반). `binding_overlays.gd`는 게임이 SSOT(IMPL-DEC-20260709-001)라 구현 자체는 로컬 권한. 이 레포 spec md 편집 금지.
- **상태:** ✅ **전파 완료·푸시**(spec `fb4f16c`, `DEC-20260720-007` — 결속 whitelist→generic 기본 델타 + 비주력 초월 제외·미소모 → `F-020` §3.7 + `D-016` §3.6.3 + bindings README + `ROLE-010` §4.5). 샌드박스 체감 확인 완료(2026-07-20). ⚠️ **잔여 딥오소링(2-D): 개별 `BIND-###` 정본·`D-###` 결속 스키마 = spec TODO**(generic 위에서, 미착수).

### DRIFT-088 — 속성 통합: `lightning` 플래그 폐기 → `element` 단일화 + **속성 타격 seam**(`element_hit`) 🔶 rule/impl (전파 후보)
- **배경(2026-07-19, 사용자 결정):** [[DRIFT-086]] ③이 `element`를 신설하며 `lightning: true`와 **병존**하는 중복을 남겼다. 사용자 설계 — *"AB에서는 element로 속성을 판단하고, 타격 시점에 element가 맞는 대상에게 속성을 전달한 후 RX로 이어질 수 있으면 이어지는 식"*. + **부여 규칙 통일**: *"즉시 효과는 element가 직접, 조건부 효과는 RX가 처리."*
- **규약(신설):** **① 즉시 효과 = element가 직접 부여**(무조건, 대상 상태 무관) **② 조건부 효과 = RX**(element는 이벤트만 쏘고 발현 여부는 반응계가 판단). **표준 사례 = fire** — 불은 Ignited를 **직접 걸지 않는다**. `FireDamageHit`만 쏘고 가연 대상(Oil 장판 · 향후 `burnable` 적)에서 반응이 성립할 때만 점화로 발현. (현재 fire 거동이 이미 그러했고, 이제 그게 **규약으로 승격**됐다.)
- **통합 전 — 속성이 흩어져 있던 6곳:** `lightning:true` 플래그 3곳(`sb_bolt` 효과/VFX · `_cast_charge_color` 차징색 · `projectile.gd` 투사체색) + **kind로 암묵 결정** 2곳(`sb_fire`=무조건 fire_hit · `sb_cold`=무조건 Chilled+cold_hit) + **하드코딩** 1곳(`beam_channel:95` 무조건 `lightning_hit` — AB-054는 element도 플래그도 없었다).
- **구현:** 신규 [elements.gd](../scripts/combat/abilities/elements.gd) `Elements.TABLE` = 속성 SSOT(`rx` 이벤트 · `scope`(area/per_target) · `outcome`+`dur_key` · 대표색). 신규 ctx 메서드 **`element_hit(element, center, radius, source, p, targets)`** = ①즉시효과 + ②RX를 한자리에서 처리. `CTX_CONTRACT` 등재 + `CastContext` 위임(적 unified 측 자동 동일) → `party_pool_smoke` 파리티 게이트가 검증.
  - **`scope` 축이 필요했던 이유:** 전격은 **대상마다 반경 1.2로** RX를 쏴야 전도 판정이 개별 대상 발치에서 성립하고, 냉기/화염은 **착탄 반경에 1회**다. 기계적으로 합쳤으면 감전 전도 범위가 조용히 바뀌었을 자리 — `area`/`per_target`으로 기존 거동 보존.
  - **`FireDamageHit`은 `fire_hit()`로 위임** — 기름 연쇄 `depth` 인자를 다루는 전용 진입점이라 일반 `emit_event`로 못 합친다.
  - 이관: `sb_bolt`·`sb_cold`·`sb_fire`·`beam_channel` 전부 `ctx.element_hit(...)` 한 줄로. **`lightning` 플래그는 데이터·코드에서 완전 제거**(AB-003/004/056/058/073 5종). 소비처 grep 0건 확인.
- **⚠️ AB-054에 `element: lightning` 부여 = 현상 보존:** `beam_channel`이 이미 무조건 `lightning_hit`을 쏘고 있었으므로 **신규 설계 결정이 아니라 코드 실태의 데이터 승격**이다. 부여하지 않으면 이관과 동시에 Shock RX가 **조용히 죽는다**. ⚠️ 단 "절단 광선의 속성이 정말 전격인가"는 AB-054 스킬 판정 때 **재확인 대상**(초월 변형은 `gravity`라 서사가 어긋날 여지).
- **⑤ `delivery`는 `element`·`kind`와 독립 축임을 재확인 + AB-004 투사체 제거(사용자 지적):** *"AB-004는 원래 번개만 나가는 이펙트였는데 투사체가 추가됐다. element나 kind로 투사체 발현이 같을 필요는 없다."* → **코드는 이미 독립**(각 `sb_*`가 `delivery`를 따로 읽고, `projectile.gd`는 색만 element에서 가져온다). 문제는 **데이터**로, AB-004에 [[DRIFT-059]] 투사체 패스 때 붙은 `delivery: projectile`이 남아 있었다(이번 세션 변경분 아님 — `git diff` 확인). → AB-004에서 `delivery`·`speed_mps`·`arc_vfx` 제거 → **`instant`**(시전자→대상 번개 줄기 즉발). `arc_vfx`는 projectile 분기 전용이라 같이 사문화되고, instant 경로가 `element == "lightning"`으로 동일한 번개 VFX를 이미 그린다. 적 EN-002는 `abilities.json` 별도 정의(AB-004 미-unified)라 무영향.
  - **현황 표(Phase A 판정 재료)** — bolt/fire/cold 12종 중 `instant`는 **AB-004·AB-072 둘뿐**, 나머지 10종이 `projectile`. 계열 일괄 부여의 잔재로 보이므로 **각 스킬 판정 때 delivery도 축으로 볼 것**(원거리 탄 = projectile / 즉시 내리꽂힘·범위 개시 = instant).
- **잔여(사용자 방침 — Phase A 진행하며 채움):** 타격계 중 element 미부여 = **AB-055 산탄 · AB-059 공허창** 2종. 미부여 = 무속성(즉시효과·RX 모두 없음)이라 **동작은 안전**하고, 각 스킬 판정 때 부여한다. `poison`은 스택 누적이 즉시효과라 `sb_poison`이 자체 처리(TABLE 비등재·RX 없음).
- **분류\전파:** 스킬북 스키마에서 **`lightning` 필드 제거 + `element`로 대체** = [[DRIFT-086]] ③의 완결 → **rule → OPS_30 전파 후보**(`D-016` 스킬북 스키마, 086과 한 packet). `element_hit`·`Elements` 테이블 = impl(로컬 ImplDecisionLog). RX 규약("즉시=element / 조건부=RX")은 **설계 규칙 → 전파 후보**(`F-021` 반응계 서술과 정합 확인 필요). 이 레포 spec md 편집 금지.
- **상태:** ✅ **전파 완료**(spec `751097a`, `DEC-20260720-001/003` — `element` 필드(`D-016` §3) + 속성 부여 규약(`F-021` §3.4 즉시=element/조건부=RX) + `EVENT-CORE` §5). `lightning` 플래그 폐지는 게임 전용(spec엔 애초 없음). 샌드박스 체감 확인 완료(2026-07-20).

### DRIFT-089 — DoT 표기 규격 통일(점화 팝업 누락) + 상태 오브 만료 미갱신 버그 🔶 impl (전파 불필요)
- **배경(2026-07-19, 샌드박스 A2 체감 — 사용자 보고):** 기름 점화 RX 자체는 정상인데 **① 점화 피해가 화면에 안 뜨고 ② 머리 위 빨간 오브가 DoT 종료 후에도 남았다.** 사용자 지시: *"모든 딜링은 독 DoT처럼 카메라 기준 캐릭터 오른쪽에 비스듬히 나와야 하고, 점화에도 걸려야 한다. 빨간 표식이 해소되지 않는 건 오류."*
- **① DoT 표기 규격 통일:** 원인 = **점화와 중독이 서로 다른 기제**였다. 중독은 `POISON_TICK_S`(0.5s) 주기로 틱하며 보라 팝업을 띄웠지만, 점화는 *"누적이 1HP를 넘을 때마다 `take_damage`"* 라 **팝업 경로가 아예 없었다**(피해가 조용히 들어감). → `outcome_status.gd`에 **DoT 공통 규격** 신설: `DOT_TICK_S`(0.5s 공통 리듬) · `DOT_IDS`(Poison·Ignited) · `DOT_COLOR`(중독=보라 / 점화=주황) + `take_dot_ticks()`가 `[{id, dmg}]`를 반환. 유닛(`enemy_unit`·`party_member`)은 이를 순회해 **동일 좌표 규격**(`FloatText.popup(..., x_off=0.9)` = 카메라 기준 우측 빗겨 — 체력바/아이콘 비가림)으로 팝업. **총 DPS 불변**(틱 배칭만 바뀜). 새 DoT는 `DOT_IDS`+`DOT_COLOR` 두 줄로 편입.
- **② 상태 오브 만료 미갱신(버그):** `party_member._update_status_orb()`가 `apply_stun`/`apply_poison` 등 **이벤트에서만** 호출되고, `_outcome.tick(delta)`가 상태를 **만료**시키는 물리 틱 경로엔 없었다 → 점화가 끝나도 오브가 마지막 색(빨강)으로 **영구 잔존**. `_physics_process`의 tick 직후 호출 추가(비활성이면 숨김). ⚠️ **적(enemy_unit)은 무관** — `_update_status_badges()`가 이미 `tick_outcome` 안에서 매 틱 갱신되고 있었다(오브는 party 전용 위젯).
- **③ 아군 상태 표시 = 적과 동일 규격으로 교체(사용자 요청 "시계방향 잔여시간"):** 단색 구슬 하나(`SphereMesh`)라 **남은 시간을 알 수 없고 우선순위 1개만** 보였다 → 적이 쓰던 [`OverheadStatusIcons`](../scripts/ui/overhead_status_icons.gd)(색 코인 + 한글 심볼 + **시계방향 회색 부채꼴 잔여시간**, `status_icon.gdshader`)로 **재사용 교체**. 신규 위젯 작성 0. 아군 `get_status_list()` 7개 항목에 **`name` 부여**(심볼 조회용 — 보호막·은신·기절·중독·둔화·취약·도발; 적 vocabulary와 통일). 디버프만 표시(버프 제외 = 적 규칙 동일). 함수명 `_update_status_orb`→**`_update_status_icons`** 정리(12곳).
  - 참고: 이 버그가 아군에서 보인 건 **존이 피아무구분**이라(F-021 §3.3.1) 내가 깐 기름에 파티가 점화됐기 때문 — 의도된 설계.
- **부수:** `outcome_status.gd`에 `class_name OutcomeStatus` 부여(`dot_color()` 정적 조회용; 기존엔 preload 인스턴스만 참조).
- **④ 「존 체류」와 「점화 DoT」를 별개 상태로 분리(사용자 설계):** 사용자 지적 — *"zone에 대한 디버프와 점화 때문에 DoT가 들어가는 디버프는 별개로 표기되고, zone은 나오면 바로(0.5초) 없어지고 DoT가 없어질 때까지 점화 표식이 남는 게 맞다."* 실사 결과 `hazard_zone._apply_medium`의 Fire 분기가 **둘을 `Ignited` 하나로 뭉쳐** `OUTCOME_DUR`(≈0.5s)을 물리고 있었다 → 존을 나오는 즉시 꺼져 **아이콘의 잔여시간 아크가 지각 불가**. (셰이더·`sync`·`ratio` 계산은 전부 정상이었다 — 렌더 문제가 아니라 데이터 모델 문제.)
  - **조치:** Fire 존이 **두 가지를 따로** 건다. ① **`Scorched`(화염) = 존 체류 표식** — 다른 매체와 동일하게 `OUTCOME_DUR`로 갱신, 나오면 ~0.5s 내 소멸. ② **`Ignited`(점화) = DoT** — `IGNITE_DUR`(5.0s, spec `APPLY-IGNITED-…-5S` / `reaction_system.IGNITE_DUR`와 동일)로 걸려 **존을 나와도 끝날 때까지 남고 아크가 돈다**. `OUTCOME_DUR`은 손대지 않음(Water·Ice·Oil·Steam·Wind가 공유).
  - ⚠️ **신규 outcome enum `Scorched`** — `outcome_status.COLOR`/`KO` + `overhead_status_icons.SYM`("화염"→"염") 등재. STATUS-OUTCOME-CORE에 없던 값이므로 **enum 변경 = OPS_30 전파 후보**([[DRIFT-084]] `enemy_fire` 선례와 동형).
  - ⚠️ **피해량 증가:** 존을 스치기만 해도 점화가 5초 지속된다(FIRE_DPS 8 × 5s ≈ 40, 기존 0.5s ≈ 4). 의미상 맞지만("불이 옮겨붙는다") **체감 후 튜닝 대상**.
  - ~~(이전 시도) `IGNITE_RESIDUAL_S = 2.5`~~ — 잔류만 늘리는 방식은 **두 상태를 계속 뭉친 채**라 사용자 의도와 달랐다. 폐기.
- **⑤ 상태 아이콘 = 글자 제거 + 호버 팝업(사용자 결정):** 문제 — `Label3D`가 `fixed_size`(화면상 고정 크기)라 **카메라가 멀어지면 코인은 작아지는데 글자는 그대로**여서 원·부채꼴이 가려지고 글자만 남았다. 사용자 판정: *"체력바 위에 뜨는 건 직관성이 우선 → 글자를 아예 없애고, 반대급부로 마우스를 올리면 이름과 효과가 팝업으로."* → 타일에서 `Label3D` **제거**(코인 색 + 시계 부채꼴만), **마우스 호버 시 이름 + 효과 한 줄 팝업**. 스택은 심볼 뒤 숫자 대신 팝업의 "N중첩"으로.
  - **구현:** 호버 판정·팝업을 `overhead_status_icons.gd`가 **자체 처리** → 씬별 배선 0(던전·샌드박스 자동 동일, [[sandbox-input-parity]] 회피). 판정 = 코인 중심과 가장자리를 각각 `unproject_position`으로 화면에 투영해 **화면상 반지름** 비교(줌/거리 무관) + `is_position_behind` 제외. 팝업은 기존 [`RichTooltip.make()`](../scripts/ui/rich_tooltip.gd) 재사용, **전 유닛 공유 CanvasLayer 1개**(static, 지연 생성)라 유닛마다 레이어가 늘지 않는다. 커서 기준 배치 + 화면 밖이면 반대편 접힘. `_exit_tree`/타일 소멸 시 팝업 해제.
  - 효과 문구는 `DESC`(표시명 키) 신설 — 상태 원본 id가 없는 레거시 타이머 항목(기절·둔화·도발 등)도 같은 경로로 읽히게 하려는 의도.
- **분류\전파:** 표기 규격·버그 수정·아이콘 UX = **impl(전파 불필요)**. DoT 틱 주기 0.5s·`IGNITE_DUR` 5s는 튜닝 수치(로깅만). ⚠️ 예외 = **`Scorched` 신규 outcome enum**(위 ④) = OPS_30 전파 후보. 이 레포 spec md 편집 금지.
- **상태:** ✅ **부분 전파**(spec `751097a`, `DEC-20260720-003` — 신규 outcome `Scorched`(화염존 체류 표식) + `RX-FIRE-ENTER-001`/`ZONE-FIRE-001`/`EFFECT-CORE` 배선, 존↔DoT 분리). 나머지(DoT 팝업 규격·코인·호버 팝업)=impl(전파 불필요). 샌드박스 확인 완료(2026-07-20).

### DRIFT-090 — 클릭이동을 **멤버별 이동 오더**로: F-003 §3.5 Leader Move Ping 스코프 확장 + 집합(rally)키 🔶 rule/design (전파 후보, 5축 이격)
- **배경(2026-07-19, 사용자 결정):** 요청 — *"클릭이동(RMB)시 목표지점까지 점선으로 예상 path를 이어주고, 전투시나 비결속시에는 캐릭을 스왑하더라도 클릭이동의 path는 그대로 유지해서 각각을 원하는 위치로 따로 보낼 수 있도록"* + *"기본적으로는 항상 같이 결속처럼 움직이다가 ... 다시 뭉쳐야하면 집합키"*. 참조 = 스타크래프트 등 RTS.
- **⚠️ 스펙에 이미 있던 기능이다 — 스코프가 다를 뿐.** `F-003 §3.5 Leader Move Ping`이 **연두색 점선 이동선**(§3.5.3)까지 포함해 정의돼 있다. 요청 동작은 그 SSOT와 **5축에서 어긋난다**:
  | 축 | F-003 스펙 | 구현(본 드리프트) |
  |----|-----------|------------------|
  | 명령 대상 | 지휘권 보유자 **1명 고정**(§3.5, 1b·§3.0.4) | **멤버 각각**(스왑으로 순회 지시) |
  | 적용 모드 | **파티비결속 전용**(§3.5) | 결속 포함 **항상** |
  | 전투 중 | 이동목표 **일시정지, 전투 우선**(§3.5.2) | **이동 우선, 자동전투 정지**(정반대) |
  | 결속 전환 | 라디오 UI로 **상호 전환**(§3.3) | 암묵적 파생 + **집합키(T)** |
  | 입력 | 커뮤니케이션 휠(`UI-007` SSOT) | RMB 클릭이동 + 취소=집합키 |
  - §3.4("결속/비결속은 파티 이동 기준만 바꾼다 · 입력 라우팅 불변")는 **위반하지 않는다** — WASD는 여전히 Controlled 전용이고, 오더는 입력 라우팅이 아니라 멤버 상태다.
- **오더 상태 모델(신설, `party_member`):** `MoveOrder { NONE, MOVING, HOLD }`.
  - `MOVING` = 오더 이행 중 — **자동전투 정지**(순수 move) · 진형 추종/교전 제외.
  - `HOLD` = 목적지 도착 후 그 자리 유지 — **자동전투 재개** · **진형 복귀 안 함**. 넉백 등으로 밀려나도 원위치로 되돌아가지 않는다(사용자 결정).
  - **cb 있는 오더는 도착 시 `NONE`**: `order_move_to`는 상자 상호작용(`interaction_controller`)·사거리 밖 캐스트 접근(`aim_controller`)에도 쓰인다. 전부 `HOLD`로 두면 상자 한 번 열 때마다 그 캐릭이 진형에서 영구 이탈한다 → **"배치 의도"(cb 없음)와 "심부름"(cb 있음)을 분리**.
- **구현 — 소유권 이전이 핵심.** 오더는 원래 `player_controller`(각 멤버의 `Control` 자식 노드)에 있었는데, 스왑 시 비조작 멤버의 Control은 `set_physics_process(false)`로 꺼진다 → **오더가 살아남되 실행만 멈추는** 상태였다(기존 잠재버그). 오더를 **멤버 상태로 승격**하고 구동 규칙(`order_desired_velocity`)을 멤버가 소유 → 조작캐는 `player_controller`, 비조작은 `party_controller._sv1_update_follow`(Pass 1 + 앵커 Pass 3)가 **같은 헬퍼**를 소비. 멤버당 `move_and_slide()` 1회 불변.
- **동반 해소 — 스왑 시 상태 미리셋 3건(기존 잠재버그):**
  - `player_controller.cancel_move()`가 **정의만 되고 호출처 0건**이었다 → `cancel_order()`로 통합하고 실호출 경로 확보(WASD·도착·다운·MIA·도발·집합).
  - `nav_set_target`의 0.5m early-return이 **stale path를 재사용**했다 → `nav_invalidate()` 신설, 오더↔진형 전환 시 캐시 폐기.
  - `_sv1_prev_dir`/`_sv1_nav_mode` 등 6개 스티어링 dict가 미청소였다 → `_sv1_forget()` + 오더 해제 프레임 감지(Pass -1)로 폐기. 취소 경로가 여럿이라 **상태 전이를 한 곳에서 관찰**하는 방식을 택했다.
  - `_move_active`가 스왑을 넘어 살아남던 건 **이제 의도된 동작**이라 수정 대상에서 제외.
- **집합(rally) = `T`키 신설(`rally_party`).** 전원 오더/HOLD 해제 + 결속 복귀. **U(결속/비결속 토글)는 유지** — `cohesion_mode`는 Command Holder와 §3.3.1(비결속 앵커 이탈 → MIA)까지 물고 있어, 걷어내면 이번 기능과 무관한 스펙 기계장치가 고아가 된다. 키 선정: 전투 중 연타 대상이라 `U`는 너무 멀고, `Space`는 향후 회피/대시 관례를 위해 비워둠 → 검지 사거리 + `G`(진형우선)와 같은 "파티 명령" 계열인 `T`.
- **점선 경로:** 신규 `move_path_overlay.gd`(`ImmediateMesh`, PRIMITIVE_LINES). 경로는 이미 `party_member._nav_path`에 `NavigationServer3D`가 계산해둔 것을 `_nav_path_idx`부터 재사용 — **추가 pathfinding 없음**. 색은 스펙 §3.5.3의 **연두색** 준수. 조작캐 진하게 / 오더 있는 나머지 흐리게(사용자 결정 — 여러 명을 따로 보내는 기능이라 전체 배치가 한눈에 보여야 함).
- **⚠️ 파생 — 비조작 멤버 기절 미적용(기존 버그) 수정, 사용자 지시 2026-07-19:** 작업 중 발견 — `party_controller`에 **기절 검사가 아예 없어** 비조작 멤버는 기절 중에도 계속 이동했다(`move_speed_mult`도 기절에 0을 곱하지 않음). 조작캐는 `player_controller`가 정상 정지 → **같은 기절인데 조작 여부로 거동이 갈렸다**(F-021 위반). 사용자 지시 = *"기절시 잠시 멈췄다가, 기절끝나면 목표지점까지 다시이동"* → Pass 1·Pass 3에 기절 분기 추가(velocity 0). **오더는 취소하지 않고 유지**만 하므로 풀리면 목표로 재출발하고, 정지 중엔 `order_desired_velocity`가 호출되지 않아 **끼임 타이머도 누적되지 않는다**. 도발/오더보다 앞에 둬서 기절이 강제이동까지 덮는다. ⚠️ **전투 밸런스 변화** — 이제 모든 팔로워가 기절에 멈춘다(기존엔 기절해도 진형 추종·교전 이동을 계속했다). 스펙 정합 방향의 수정이나 체감 난이도는 오를 수 있다.
- **분류\전파:** **rule/design → OPS_30 전파 후보.** 개정 대상 = `F-003` §3.3(상호 전환 UI) · §3.5(명령 대상·비결속 전용) · §3.5.2(전투 중 일시정지 ↔ 이동 우선) · §3.5.3(이동선 표시 주체 복수화) · §3.5.4 신설 후보(집합 명령) + `UI-007`(입력 경로가 휠이 아닌 RMB). 사용자 방침 = **먼저 구현·체감 후 일괄 역전파**(과거 15건 백로그 소진 선례와 동형). 이 레포 spec md 편집 금지.
- **⚠️ 후속 — 클릭↔드래그 판별 결함(체감 수정, 사용자 보고 2026-07-19):** *"클릭이동이 카메라 드래그와 겹쳐 씹힌다, 스왑하면서 동시에 이동하면 더 심하다"*. 원인은 데드존 크기가 아니라 **판별 모델**이었다 — RMB 판별이 `Σ|dx|+|dy|`(누적 경로 길이, 맨해튼)라 **줄어들지 않는 값**이었다. 고DPI·고폴링 마우스에서는 제자리 클릭도 미세 이벤트가 수십 개 쌓여 8px를 넘겨 카메라 드래그로 오판 → 이동 명령이 통째로 소실. → **누른 지점으로부터의 직선 거리**로 교체(제자리로 돌아오면 0에 수렴) + 데드존 `14px` + **래치**(한 번 드래그 확정되면 놓을 때까지 유지, 경계 깜빡임 방지) + **데드존 안에서는 카메라를 아예 돌리지 않음**(클릭마다 카메라가 미세하게 틀어져 다음 클릭 지점이 어긋나던 문제).
  - **"스왑하면서 더 심하다"의 정체는 좌클릭 쪽이었다.** `selection_controller`의 마퀴 임계도 8px인데, 아군 클릭 스왑 중 손이 조금 밀리면 초소형 박스로 판정되고 → 박스 판정이 아군의 **원점(unproject 한 점)** 포함 여부라 캐릭터를 덮고도 원점을 놓쳐 **스왑이 씹혔다**. 임계를 `14px`로 통일(좌/우 허용 오차가 다르면 손에 안 익는다) + **빈 박스면 릴리즈 지점 레이픽 폴백**(빈 공간 드래그는 레이픽도 비므로 무동작 유지 = 오작동 없음).
  - **임계를 해상도 비례로(사용자 지시):** 고정 픽셀은 해상도가 올라가면 무력화된다 — 같은 손떨림이 1080p에서 10px이면 4K에서는 20px이라 고해상도일수록 오판이 잦아진다. 신규 [`scripts/core/input_tuning.gd`](../scripts/core/input_tuning.gd)가 SSOT. 가로가 아니라 **짧은 변** 기준 — 울트라와이드에서 가로를 쓰면 임계가 과도해진다(3440×1440은 172px이 아니라 72px 계열).
  - **⚠️ 단일 임계로는 둘 중 하나가 반드시 나쁘다 → 두 임계 + 겹침(사용자 체감 2026-07-19).** 값이 크면 클릭은 잘 먹지만 카메라 orbit 시작이 둔하고("조금 둔하게 느껴진다"), 작으면 orbit은 즉각적이지만 클릭이 씹힌다. → **orbit/마퀴는 일찍 시작**(`DRAG_START` 3.0%) **릴리즈 판정은 늦게**(`CLICK_MAX` 6.0%). 그 사이 구간에서는 **카메라가 돌면서도 손을 떼면 클릭이 먹는다** — "살짝 밀렸지만 클릭할 의도였다"가 정확히 이 구간. 좌클릭도 동일(마퀴가 잠깐 떴어도 CLICK_MAX 안이면 박스가 아니라 점 선택으로 처리).
  - 역산 확인(orbit 시작 | 클릭 인정 | 겹침): 720p `21.6 | 43.2 | 21.6` · **1080p `32.4 | 64.8 | 32.4`** · 1440p `43.2 | 86.4 | 43.2` · 4K `64.8 | 129.6 | 64.8`.
  - **거리 측정은 "누른 지점으로부터의 최대 직선거리"**(릴리즈 순간 거리로 재면 멀리 끌었다 제자리로 돌아와 놓는 동작이 클릭으로 오인된다). 누적 이동량(Σ|dx|+|dy|)은 줄지 않아 손떨림만으로 부풀므로 폐기 — **이게 원래 버그의 정체**.
  - 튜닝 이력 = 고정 8px → 비율 2.5% → 5.0% → **DRAG_START 3.0% / CLICK_MAX 6.0%**. ⚠️ `stretch/mode=canvas_items`라 마우스 좌표가 이미 정규화돼 들어올 수 있는데, `get_visible_rect()`에서 역산하므로 **정규화 여부와 무관하게** 마우스 이벤트와 같은 좌표계를 쓴다(스트레치 설정이 바뀌어도 안전).
  - 던전·샌드박스 **양쪽 동일 적용**([[sandbox-input-parity]]) · 좌/우 버튼 **같은 임계**(허용 오차가 다르면 손에 안 익는다).
- **⚠️ 후속 — 시전 중 오더 일시정지(사용자 지시 2026-07-19):** *"이동중 스킬 캐스팅하면 캐스팅 걸리고 그거 끝난 후에 마저 움직이도록"*. 실사 결과 **비조작 멤버는 이미 정상**이었다(`party_controller` Pass 1/3 의 `is_channeling` 분기가 오더 분기보다 앞이라 정지 + 오더 유지). 갭은 **조작 중인 멤버뿐** — `player_controller` 에 채널 검사가 없어 시전하면서 계속 걸어갔다. → 오더 분기 안에 채널 정지를 추가(velocity 0, **오더는 유지**). 기절과 동일하게 정지 중엔 `order_desired_velocity` 를 부르지 않아 끼임 타이머도 안 쌓인다.
  - **WASD 는 손대지 않았다** — 직접 이동하면 시전이 취소되는 기존 규칙 유지. 오더는 "예약된 의도"라 시전에 양보(일시정지)하고, WASD 는 "지금 이 순간의 입력"이라 시전을 덮는다는 구분이다.
  - ⚠️ **남은 상호작용:** 사거리 밖 지상 타겟 스킬은 `aim_controller` 가 `order_move_to`(cb=시전)로 접근하는데, 이는 **기존 이동 오더를 덮어쓴다**(§3.5.1 "큐잉 없음"과 동형). 시전 후 원래 목적지로 이어가지 않고 그 자리에서 풀린다(cb 있는 오더 = NONE). 현재는 의도된 동작으로 두되 체감 확인 대상.
- **⚠️ 후속 — 드래그 박스 선택 = 면적 커버리지 게이트(사용자 체감 2026-07-19):** *"중간 아군을 클릭하려고 드래그했는데 좌측 아군의 일부가 걸려서 의도와 다른 아군이 선택된다"*. 원인 = 박스 판정이 아군의 **원점 한 점** 포함 여부였는데, **40° 피치 카메라에서 원점(발밑)은 캐릭터 화면 사각형의 세로 ~86% 지점**(거의 바닥)에 찍힌다 → 박스가 발치 14%만 스쳐도 후보가 되고, 거기에 "화면 좌측 우선" 규칙이 겹쳐 **왼쪽에 살짝 걸린 아군이 가운데 의도 대상을 가로챘다**. → 콜리전 캡슐 AABB 8꼭짓점을 투영한 **화면 사각형의 겹친 면적 비율**로 판정, `SELECT_COVER_MIN = 0.70` 이상만 후보(사용자 제안 수치). `party_member.selection_aabb()` 신설(역할별 radius/height 반영).
  - **폴백 제거:** 직전에 넣었던 "빈 박스면 릴리즈 지점 레이픽" 폴백을 **삭제**했다. 살짝 끌린 클릭은 이미 릴리즈 판정(`CLICK_MAX`)에서 점 선택으로 처리되므로, `_swap_to_leftmost_in_box`까지 온 건 "제대로 끈 박스"다 — 거기서 기준 미달인데 레이픽으로 엉뚱한 대상을 주워오면 이 수정의 취지에 정면으로 반한다. 기준 미달 = **무동작**.
  - ⚠️ 판정 기준이 **콜리전 캡슐**이라 시각 메시가 캡슐보다 크면 체감과 어긋날 수 있다(현재 placeholder 실린더는 대체로 일치). 메시 교체(A2) 시 재확인 대상.
- **회귀 게이트:** 신규 [`tools/selection_smoke.gd`](../tools/selection_smoke.gd) — 원점이 사각형 하단부라는 **전제 자체**를 먼저 검증하고(카메라 피치를 바꾸면 이 게이트가 먼저 깨진다 = 의도), 발치 박스 탈락 · 85% 통과 · 임계 경계 방향성. `ci_smoke.sh` 편입. 신규 [`tools/move_order_smoke.gd`](../tools/move_order_smoke.gd) — 상태 전이(NONE/MOVING/HOLD) · **cb 유무로 갈리는 도착 거동** · MIA·도발 취소 · **기절은 유지** · `nav_invalidate`. 실거동(점선·`T`키·전투 우선 체감·마우스 손맛)은 커버 못 함 = F5 플레이테스트 몫.
- **상태:** ✅ **전파 완료·푸시**(spec `2da700d` origin/staging, `DEC-20260721-001` — `F-003` §3.5 계열 전면 재작성: 멤버별 오더·`MoveOrder{NONE,MOVING,HOLD}`·항상·이동우선·집합 `T`키·멤버별 점선 + §3.4/§3.6/§3.11 정합 + `UI-007` Deprecated + F-006/D-010 참조 정정). impl/튜닝(소유권 이전·스왑 미리셋·기절 정지·시전중 일시정지·입력 판별·드래그박스) = 비-전파. ⚠️ `F-002` §3.2.1(Left Ctrl+RMB 휠 예외)=Locked 후속. ci_smoke 10/10. **샌드박스 체감 대기**(①전투 중 오더 우선 ②HOLD 방치 ③점선 가독성 ④기절 정지 난이도).

### DRIFT-091 — AB-009 Spawn Oil Patch 존 클래스 재배정: `[Nuker,Healer]→[DPS,Healer]` (메인=DPS·서브=Healer) 🔶 rule/scope (전파 후보)
- **배경(2026-07-21, 사용자 결정 — I-006 캐스팅 패스 §8 AB-009 판정 축2):** 존 서브를 **DPS 메인**으로 승격. §8.5에서 짚은 *"존 equip=Nuker/Healer vs 초월=DPS 클래스 축 불일치"* 를 해소해 존을 **DPS 정체성(초월/혈풍)에 결속** 가능하게 하는 방향(§8.2-2안). 사용자 지시 = *"nuker 빼고 healer 서브로"*.
- **⚠️ spec 대비 불일치 — 이 변경 전부터 게임이 이미 drift 상태였다:**
  | 소스 | mainClasses(메인) | subClasses(서브) |
  |------|-------------------|------------------|
  | **spec 정본**([AB-009_SpawnOilPatch.md](../../project_tdc_spec/docs/combat/abilities/AB-009_SpawnOilPatch.md)) | `[]` | `[DPS, Nuker]` |
  | 게임(변경 전) | Healer(`sub_bands` 미기재=메인) | Nuker(B3) |
  | **게임(변경 후·본 드리프트)** | **DPS** | **Healer(B3)** |
  - spec은 AB-009에 **Healer가 없고 Nuker가 subClass**. 게임은 이전부터 `[Nuker,Healer]`로 어긋나 있었으나 **개별 로깅이 없던 선재 drift**(DRIFT-029의 "서브 페널티" 일반 항목에만 묻혀 있었음). 본 변경으로 게임은 spec에서 **더 멀어진다**(Nuker 제거·Healer 유지·DPS 메인 승격).
- **변경(`data/slice01/skillbooks.json` AB-009):** `equip_classes ["Nuker","Healer"]→["DPS","Healer"]` · `sub_bands {"Nuker":"B3"}→{"Healer":"B3"}`. 시스템 규약상 `sub_bands` **미기재=메인(B0 ×1.0)** ([ability_dispatch.gd:72](../scripts/combat/abilities/ability_dispatch.gd#L72))이라 DPS=메인, Healer=서브. 밴드 B3는 **기존 Nuker 서브밴드 승계**(밸런싱 §0 스킵 — 값 재산정은 Phase B).
- **⚠️ 존 5쌍둥이 대칭 미정합(후속 판정 대상):** AB-036/040/042/043은 아직 게임 `[Nuker,Healer]`. spec은 제각각(036=main[Healer]/sub[DPS,Nuker] · 040=main[Healer]/sub[Nuker] · 042·043=main[]/sub[DPS,Nuker]). AB-009만 선행 재배정 → **존 계열 클래스 정책이 아직 통일 안 됨**. §8 존 정책 확정 시 나머지 4종 일괄 판정 예정(§5.3 "존 정책 상속").
- **분류/전파:** **rule/scope → OPS_30 전파 후보.** 개정 대상 = spec `AB-009_SpawnOilPatch.md` `mainClasses`/`subClasses`. AB-041 `sub_bands` 변경([[DRIFT-087]])과 **동형 경로**. 사용자 방침 = 먼저 게임 편집·체감 후 존 정책 클러스터로 일괄 역전파. 이 레포 spec md 편집 금지.
- **⚠️ 축3 시전모드(2026-07-21 확정): A(즉발) 유지 — 데이터 변경 0.** 무피해 `role:utility`라 §0/§1 캐스트 상향 비대상(딜·힐 공격형만 대상). Oil=RX 점화 콤보 씨앗이라 빠른 셋업이 정체성. 선례 AB-011·AB-002 A유지 정합.
- **⚠️ 축1 효과 튜닝(병기·`tuning`·로깅만·전파금지): Oil 미끄럼 관성 강화.** 사용자 지시 "관성 이동 효과를 더 키워라". Slippery(=Oil 전용 상태)의 velocity 수렴 가속률을 절반으로: `player_controller.SLIP_ACCEL_MPS2 10.0→5.0` · `enemy_ai.SLIP_ACCEL 3.0→1.5`(피아 대칭). 감속 배율(MOVE_MULT ×0.85)은 불변 — "관성"만. **피아무구분이라 파티도 더 미끄러짐 → 즉발(축3 A유지)의 비용↑**(축1 방향과 합치). 값은 체감 후 재조정 가능. 효과 자체는 파손 없음(Wind와 대조 — Slippery·RX 정상 가동).
- **게이트:** ci_smoke 11/11 PASS (클래스 편집·관성 편집 후 각각 재확인 모두 통과).
- **상태:** 🔶 LOGGED (전파 후보·미전파 = 클래스 rule/scope / 관성 = tuning 로깅만). AB-009 판정 **진행 중** — 축2 클래스·축3 시전모드·축1 효과 확정. 남음: 축4 바인딩(DPS 초월/혈풍 bespoke — Oil 무피해라 신규코드 필요·§9 Stop-line) + 축1 샌드박스 체감.

### DRIFT-092 — 이동상태 모델 확장(STATUS-OUTCOME-CORE): `move_mult` 곱연산+양방향 · 관성 일반화 · Oil/Ice 상태 분리 · AB-069 `Hastened` 통합 🔶 rule/schema (전파 후보)
- **배경(2026-07-21, 사용자 결정 — AB-009 축4 전 Oil↔Ice 구분):** 장판 매질을 성향으로 구분 — **기름=끈적(느림)+관성 · 얼음=질주(빠름)+관성**. 기존엔 Oil=Slippery(×0.85+관성)·Ice=Chilled(×0.6, **관성 없음**)로 오히려 반대였다. "kind로 안 묶고 개별 성향으로"([[DRIFT-091]] §8 zone 통합정책 폐기)의 첫 적용.
- **변경 5축(`outcome_status.gd` 중심):**
  1. **`move_mult()` `minf`→곱연산 + 1.0 초과 허용.** 여러 이동상태 겹치면 전부 곱해진다(감속×부스트 양방향). ⚠️ **파급:** 감속 중첩이 더 세짐 — 예 `Sodden(0.7)×Shock(0.55)=0.385`(기존 `min`=0.55). 전 이동상태 조합에 영향(사용자 승인).
  2. **`Slippery`→개념명 승격.** 특정 상태 `Slippery` 폐기 → **관성 개념**(`is_slippery()`/`INERTIA` 집합)으로. Oil 장판 = **`OilSlick`**(×0.85 + 관성 scale 1.0) · Ice 장판 = 신설 **`IceGlide`**(×1.5 부스트 + 관성 scale 0.7=더 미끄럼). `Chilled`(×0.6)는 **냉기공격 전용으로 유지**(AB-041/072 · RX-Veg-Cold · 절대영도) — Ice 장판과 분리해 빙결 둔화가 안 뒤집힘.
  3. **관성 일반화 + 상태별 강도.** `INERTIA={OilSlick:1.0, IceGlide:0.7}` → `inertia_scale()`. 컨트롤러(`player_controller`·`enemy_ai`)가 base `SLIP_ACCEL`(5.0/1.5)에 곱 → 빙판이 더 미끄럽다. `is_slippery()`는 집합 판정으로 확장.
  4. **AB-069 Swift Grace → `Hastened` outcome 통합.** 별도 `_haste_mult`/`_haste_timer` **제거** → 이동=`move_mult`(×(1+mag))·공격속도=`attack_interval`(basic/(1+mag))·만료=`_outcome.tick`. mag=pct, strongest wins(max 갱신). move_mult 단일창구화(사용자 지시 "AB069도 move_mult 사용").
  5. **medium→상태 매핑**(`hazard_zone` MEDIUM_OUTCOME): Oil→OilSlick · Ice→IceGlide. RX-OIL-PHYSICAL(넉백)도 OilSlick.
- **KO 표기 정리:** `OilSlick`="기름" · `IceGlide`="빙판"(기존 Slippery가 "빙판"으로 오표기되던 것 해소) · `Hastened`="가속".
- **파일(9):** outcome_status · hazard_zone · reaction_system · party_member · enemy_unit · player_controller · enemy_ai · float_text · combat_sandbox.
- **분류/전파:** **rule/schema → OPS_30 전파 후보.** 개정 대상 = spec `STATUS-OUTCOME-CORE`(겹침규칙 곱연산 · 신규 outcome enum `OilSlick`/`IceGlide`/`Hastened` · 관성 일반화). 게임 편집·체감 후 역전파. 이 레포 spec md 편집 금지.
- **게이트:** ci_smoke 11/11 PASS.
- **상태:** 🔶 LOGGED (전파 후보·미전파). ⚠️ **샌드박스 체감 대기** — ①빙판 질주+관성 손맛 ②곱연산 감속중첩 체감 ③AB-069 haste 통합 회귀(이동·공격속도 정상). 값(IceGlide 1.5 · inertia 0.7)은 체감 후 재조정.

### DRIFT-093 — 원소 RX(fire·cold·lightning): primaryMedium 1개 → **겹친 모든 medium 각 반응**(EVENT-CORE §3 개정) 🔶 rule (전파 후보)
- **배경(2026-07-21, 사용자 발견·결정):** Oil+Ice 중첩 장판에 Ember(FireDamageHit) 시전 시 **Oil만 폭발하고 Ice는 안 녹던** 현상. 원인 = `_on_fire_damage_hit`이 `_primary_medium_of`로 **우선순위 1개 매체만** 골라 RX 하나만 발동(RX_PRIORITY: Oil>…>Ice). spec `EVENT-CORE §3` "ONE combo RX per tile" 설계였으나, 겹친 매질이 **각각 반응**하는 게 자연스럽다는 판단 → 전부 반응(옵션 a). **3개 원소 RX 전부 통일**(사용자 후속 결정 1).
- **변경(`reaction_system`):** `_on_fire_damage_hit`·`_on_cold_damage_hit`·`_on_lightning_hit` 3핸들러 모두 primaryMedium 단일선택 → 겹친 zone의 **고유 medium마다 각 RX** 호출. (fire 예: Oil 폭발 + Ice→Water + Water→Steam + Veg→Fire + ToxicGas→flash 동시.)
  - **연쇄 폭주 방지 2장치:** ① fire의 Oil은 `_ignite_oil`이 `fire_hit` 재귀(인접 연쇄)라 **비-Oil 먼저 처리 후 Oil 마지막** → 다른 medium은 먼저 소비돼 재귀 중복 회피(cold/lightning은 재귀 없어 순서 무관). ② Ice→Water·Fire→Steam 등 **변환물은 새 zone**(현재 스냅샷 `zones`에 없음)이라 같은 틱에 재반응 안 함(연쇄 폭주 차단).
  - **`_primary_medium_of`·RX_PRIORITY 유지:** 프로덕션 코드에선 이제 미사용(orphan)이나 `reaction_smoke`(EVENT-CORE §3 resolver 단위테스트)가 직접 호출 → 삭제 안 함.
- **분류/전파:** **rule → OPS_30 전파 후보.** 개정 대상 = spec `EVENT-CORE §3`("ONE combo RX per tile" → "겹친 매질 각각 반응") / `INT-002 §6.1`. fire·cold·lightning 3축 일관. 게임 편집·체감 후 역전파. 이 레포 spec md 편집 금지.
- **게이트:** ci_smoke 11/11 PASS (reaction_smoke 포함 — primaryMedium resolver 함수 유지로 단위테스트 무영향).
- **상태:** 🔶 LOGGED (전파 후보·미전파). ⚠️ 체감 대기 — ①Oil+Ice 동시반응(fire) ②Water+Veg 동시반응(cold)·Water+Steam(lightning) ③연쇄 폭주 없는지(Oil 인접연쇄 + 변환물 재반응 차단).

### DRIFT-094 — AB-009 축4 결속 「아군 안심 기름」(safeslick): 초월 Oil이 아군 무해 — **F-021 §3.3.1 피아무구분 예외**(결속이 환경 근본규칙을 뒤집는 첫 사례) 🔶 rule (전파 후보)
- **배경(2026-07-21, 사용자 결정 — AB-009 축4 바인딩):** DPS 초월(IDA-024)에 AB-009 결속. **자동 폭발(컨셉 A)은 "화염존을 앞당긴 것"이라 Oil 컨셉을 지운다**는 판단으로 기각 → **Oil의 유일한 비용(피아무구분)을 제거하는 payoff**로 선회. 딜을 더하지 않고 "안심하고 깔 수 있는 기름"으로 컨셉 유지. 결속 후보 4개 중 **초월만** 결속(혈풍=무피해라 흡수 0 / Healer 지속치유·성역=서브+무치유 → 결속 없음).
- **변경(5파일):**
  - `hazard_zone`: `friendly_safe`/`safe_faction` 속성 + `set_friendly_safe(faction)` + tick 효과 면제(`safe_faction` 유닛은 미끄럼·피해 **전부** 스킵) + 시각 청록 이미시브 구분.
  - `reaction_system`: `_explosion`에 면제 파라미터 + `_ignite_oil`이 oil의 flag를 **직후 파생(폭발·Fire존)에만** 상속(인접 연쇄는 상속 안 함).
  - `ability_dispatch`: `_dps_overdrive_empower` variant `safeslick` — 초월 중 aim에 깐 Oil zone을 `set_friendly_safe(시전자 진영)`.
  - `binding_overlays`: BIND-027(`gear_ward_dps_press_rod` + IDA-024 + AB-009 @ slot0, variant safeslick).
  - `binding_smoke`: 카운트 34→35 + BIND-027 resolve 검증.
- **사용자 결정 3축:** ① 면제 범위 = **전부**(미끄럼+피해) ② 시각 = **청록빛 구분** ③ 상속 = **직후 RX만**.
- **⚠️ 무게 — 결속이 환경 근본규칙을 뒤집는 첫 사례:** `F-021 §3.3.1` "존은 피아무구분"은 정본 규칙. 이 결속은 거기에 조건부 예외(초월 + source 진영)를 뚫는다. 단순 kit 확장(kind/variant payoff)이 아니라 **환경 RX 시스템에 진영 개념을 부분 도입**. 전파 시 spec F-021에 "결속 예외" 항 신설 필요.
- **함의:** AB-009는 무명중(무피해 존)이라 **초월 게이지 충전 기여 0** — 충전은 볼트/광역 딜 슬롯 몫, 이 슬롯은 발현(초월 소모) 전용. desc_ko에 명시.
- **분류/전파:** **rule → OPS_30 전파 후보.** 개정 대상 = spec `F-021 §3.3.1`(피아무구분 + 결속 예외 신설) · `D-016` DPS 초월 kit(AB-009 safeslick variant). 게임 편집·체감 후 역전파. 이 레포 spec md 편집 금지.
- **⚠️ 체감 수정(2026-07-21, F5): 청록 미표시 2원인.** ① 샌드박스 초월 픽스처가 `subs`에 AB-009 미포함(AB-010@Q) → safeslick 발현 불가. 픽스처 Q를 AB-009로 교체(비정본). ② Oil zone은 `SHADING_MODE_UNSHADED`라 **emission만으론 색이 안 바뀜**(albedo가 표시색) → 청록 albedo 병행. 층서(DRIFT-095)는 F5 정상 확인. **③ 색 구분이 "기름 같지 않다"는 피드백** → 색 override **폐기**, 매질색 통일 + **청록 파티클 오버레이**(`CPUParticles3D`, 위로 떠오름, Oil·직후 Fire 공통)로 표기 전환. ⚠️ 파티클은 헤드리스 미실행(런타임 `set_friendly_safe`) → **F5에서 첫 실제 검증**.
- **게이트:** ci_smoke 11/11 PASS (binding_smoke 카운트/resolve 갱신 포함).
- **상태:** 🔶 LOGGED (전파 후보·미전파). **AB-009 4축 확정·닫음(2026-07-21)**. ✅ F5 체감 확인 — safeslick 아군무해 · 청록 파티클 표기(매질색 통일) · 겹친 존 층서. 잔여 체감은 별개 DRIFT 몫(092 관성/곱연산 · 093 RX 전부반응). 인접 연쇄는 여전히 피아무구분(상속 직후만).

### DRIFT-095 — 겹친 반투명 존 render 층서(깜빡임 수정) 🔷 impl (전파 불필요)
- **배경(2026-07-21, 사용자 발견):** zone 여러 개 겹치면 상단 노출 순서가 원칙 없이 **매 프레임 뒤집혀 반짝임**. 예: 기름 폭발 시 같은 자리에 Fire+Smoke가 깔리는데 붉은 빛이 연기에 가려졌다 안 가려졌다 함.
- **원인:** `hazard_zone._build`에서 Oil(opaque) 외 반투명 존이 **전부 `render_priority=2`·`y=0.4` 동일** → 겹치면(특히 `_ignite_oil`의 Fire/Smoke 동일 pos) draw order tie-break가 없어 카메라 거리로 매 프레임 재정렬 → 깜빡.
- **수정:** 매체별 `RENDER_ORDER`(현실 물리 층서 — 상승 기체 Smoke/Steam/Wind/ToxicGas 위 > 지면 화염 Fire/Fatal > 지면 액체·고체 Water/Ice/Vegetation). `render_priority = 2 + order`(시야콘 위 유지 + 매체 고정순) + `y = 0.4 + order*0.01`(연기가 실제로 더 높이 + z-fighting 방지). Oil은 opaque(y 0.07)라 별개.
- **분류:** **impl(렌더링) — 전파 불필요, 로깅만.** spec 무관(시각 표현). §0 "명백한 파손" 스코프.
- **게이트:** ci_smoke 11/11 PASS. ⚠️ 체감 = 겹친 존 깜빡 사라졌나 + 층서 자연스러운가(연기가 불 위).

### DRIFT-096 — passive 존 쌍 반응(Oil+Fire→폭발 · Fire+Water→Steam): Hit 없이 겹침만으로 RX 🔶 rule (전파 후보)
- **배경(2026-07-21, 사용자):** 불존과 물존이 나란히 겹쳐 있어도 아무 반응 없이 공존 = 비물리적(몰입↓). 겹친 존은 물리적으로 반응해야(예: oil존에 fire존 겹치면 터짐). 기존 RX는 **Hit 이벤트(FireDamageHit 등) 기반**이라 passive 중첩엔 트리거가 없었다.
- **변경(`reaction_system` + `hazard_zone`):** `_zone_reaction_tick`(0.4s 주기, 활성 존 쌍 O(n²) 순회, spread 자식 제외) 신설 → `_resolve_zone_pair`:
  - **Oil+Fire** 겹침 → `_ignite_oil`(기존 재사용: 폭발+Ignited+Fire존+인접 연쇄, Oil 소비).
  - **Fire+Water** 겹침 → 교집합 중점에 Steam + 양쪽 `hazard_zone.shrink`(반경 감소, 0.4 미만이면 소멸) → 겹침 해소될 때까지 서서히 소진.
- **⚠️ 아키텍처 한계(교집합·확산 = 원 단위 근사):** 사용자 이상 = "교집합만 반응 + 서서히 확산"(DOS2/BG3 surface = **셀 그리드**). 우리 존은 `center+radius` **원 하나**라 부분 반응이 구조적으로 없음 → 교집합="중점 Steam", 확산="반경 축소"로 **근사**. 완전한 셀 그리드 surface는 전투 시스템 **대공사** = 별도 spec 과제로 **defer**(사용자와 [[refactor-risk-preference]] 논의).
- **분류/전파:** **rule → OPS_30 전파 후보.** spec `EVENT-CORE`/`F-021 §3.2`(RX)에 **passive 존 중첩 반응** 개념 신설. 게임 편집·체감 후 역전파.
- **게이트:** ci_smoke 11/11 PASS.
- **상태:** 🔶 LOGGED (전파 후보·미전파). ⚠️ 체감 — Oil+Fire 자동폭발 · Fire+Water 증기+소진 · 폭주/성능(O(n²)·Steam 생성 빈도) · 확산 근사(축소) 자연스러운가.
- **➡️ 후속(2026-07-21, 사용자 승인): 셀 그리드화 착수 — 이 "원 단위 근사"의 정식 해소.** 설계 확정 = **Target A**(셀=substrate,
  원=저작; `spawn_zone`/`radius_m` 저작 불변, 내부 래스터화). 예정 기능(퍼짐·바람 밀림)의 토대. 설계·단계·마이그레이션
  정본 = [docs/design/surface_grid.md](design/surface_grid.md) · 결정 = [[IMPL-DEC-20260721-001]]. 단계: **S0**(shadow 렌더·무침습)
  착수 → S1(셀 권위화) → **S2에서 본 DRIFT-096 정식 종결**(중점/shrink 근사 제거, 셀 내 공존매질 해소) → S3(확산 CA).
  전파는 Target A라 최소(`INT-002 §6.1`/`EVENT-CORE §3` "타일=셀" 명료화; `ZONE-CORE`/`EFFECT-CORE` 지오메트리 불변,
  **수렴**) — S1/S2 체감 후 OPS_30.
- **➡️ S3 확산 CA(2026-07-22, 사용자 결정 — 규칙/전파 후보):** 확산이 **circle 자식-존(WindGust `_spread_tick`)** →
  **셀 CA**로 이동(Fire creep=연료 위 번짐 · Wind push=기체·불 downwind 밀림). flag ON 시 `reaction_system._spread_tick`
  비활성. spec `SPREAD-ZONE-*-{n}TILES`·`max_tiles_per_gust`·`max_spreads_per_room`의 **"타일"이 우리 셀(0.1m)과 스케일이
  달라 재조정 필요**(spec 1타일 ≈ 우리 10셀). 이 tile↔cell 재정합 + 확산 모델(연료 한정·바람 대상)이 OPS_30 전파
  대상(S2/S3 체감 후 `INT-002 §6.1`/`EVENT-CORE §3`/`SPREAD-ZONE-*` 묶어서). 게임 상수(rings/cadence)는 튜닝수치=로깅만.
- **➡️ S2 셀 연료 점화(2026-07-22):** RX-OIL-FIRE·RX-FIRE-VEGETATION을 셀판(footprint 점화+creep)으로 구현. **신규 규칙:
  Fire+Vegetation passive 점화**(존 겹침만으로 — 기존 spec은 Hit RX만) = OPS_30 전파 후보. `RX-FIRE-VEGETATION`에 passive
  트리거 추가 + 연료 creep 모델. 위 S3 전파 묶음에 포함.

# SPEC_DRIFT — 구현 ↔ 스펙 이격 대장

> **무엇:** 구현이 spec(SSOT)과 달라진 지점의 **단일 추적 대장**. 발견 즉시 `DRIFT-###`로 기록하고, 분류·결정·상태를 유지한다.
> **규칙:** [AGENTS.md](../AGENTS.md) §Spec drift & propagation. 튜닝수치=로깅만 / 아이디어=`OPS_08·I-002` / 규칙변경=spec repo `OPS_30` 전파 후 `spec_ref.json` 재핀.
> **최종 갱신:** 2026-07-09 — **컴팩션:** 스펙 전파 완료(✅ MERGED / ✅ 전파 / 🔷 전파) 드리프트 **19건 제거** — DRIFT-000·005·018·019·021·022·023·024·025·027·035·036·037·038·050·054·070·071·072(스펙 SSOT 반영 완료; 이력=spec DecisionLog/커밋). 잔존 = 튜닝 로깅(전파금지)·impl 결정·전파 후보(미전파)·파일럿 로깅(🕒 전파 보류). **현재 스펙 핀:** `staging@2bf37b2`(QA-031·Phase 2, 결속 정본 계열).
> **미전파(승인/게이트 대기):** DRIFT-069 F3 환경 RX 3종·B7 zone spread = `PENDING-PROP`(OPS_30) · DRIFT-073~077 파일럿 결속/캐스터 설계 = 🕒 로깅(게이트 후 전파) · 058·064·065·066·067·068 = 전파 후보.
> **2026-07-12 추가(미커밋 작업 로깅):** DRIFT-078 I-006 캐스팅 확장 패스(엄브렐러·impl/tuning·진행 중) · **DRIFT-079 AB-054 채널 규칙변경**·**DRIFT-080 DPS 초월 개편** = 🔶 rule **전파 후보**(OPS_30 미전파) · DRIFT-081 적 상태칩(impl) · **DRIFT-082 Shared 스킬 적↔아군 통합**(AB-003 파일럿·CastContext·프레젠테이션 파리티) = 🔶 rule/design **전파 후보**(packet 준비). 세부 원장 = `docs/_WIP_casting_expansion_pass.md` §4.
> **2026-07-22 전파 완료:** DRIFT-096(셀 substrate 반응/확산 모델)·097(환경 zone 유계 ∞→10s)·093(Hit RX 겹친 매질 각 반응) → spec 역전파(staging `d9e9f52`, `DEC-20260722-001/002/003`; `INT-002`·`EVENT-CORE`·`RX-OIL-FIRE-001`·`RX-FIRE-WATER-001`·`RX-FIRE-VEGETATION-001`·`EFFECT-CORE`·`ZONE-CORE`). 스펙 핀 `2da700d`→`d9e9f52` 재핀. mapper 0·xref 0. **DRIFT-069**(per-medium RX 3종: `RX-FIRE-ICE`·`RX-COLD-FIRE`·`RX-COLD-STEAM`)은 093 위에서 채울 후속 = 여전히 미전파.
> **2026-07-24 전파 완료:** DRIFT-098(zone 형상 축 `Rect` 방향성 복도 + 능력 `shape`/`length_m`/`width_m` + `WindBuffeted` 진입임펄스→체류 드리프트) → spec 역전파(staging `a5e5ae3`, `DEC-20260724-001`; `ZONE-CORE`·`D-016`·`EFFECT-CORE`·`STATUS-OUTCOME-CORE`·`RX-WIND-ENTER-001`·`AB-042`). 스펙 핀 `d9e9f52`→`a5e5ae3` 재핀. mapper 0·xref broken-ref 0. **후속:** AB-042 적 telegraph ↔ 아군 cast_s 타이밍 대칭 = Phase B(spec TODO 등재).
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
- **상태:** ✅ **전파** (staging `d9e9f52`, `DEC-20260722-003`; `EVENT-CORE §3`·`INT-002 §6/§6.1` — Hit medium RX 각 매질, `PhysicalImpact`는 primaryMedium 예외). F5 체감 확정(사용자, 2026-07-22): Oil+Ice에 Fire → Oil 점화 + Ice 융해 둘 다(각 매질 반응 OK). ⚠️ 얼음→물이 기름불을 켄치(Steam)해 첫 캐스트가 불발처럼 보이는 건 **096-S2 셀 경계반응과의 합작**(의도대로 수용). per-medium RX 신설(`RX-FIRE-ICE` 등)은 별개 = **DRIFT-069 후속**.

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
- **상태:** ✅ **전파** (staging `d9e9f52`, `DEC-20260722-001`; `INT-002 §6/§6.1`·`EVENT-CORE §1/§3`·`RX-OIL-FIRE-001`·`RX-FIRE-WATER-001`·`RX-FIRE-VEGETATION-001`·`EFFECT-CORE`). 셀=substrate·per-cell CA·`radius_m`=초기 seed·Overlap combo RX passive 확장(Oil+Fire·Fire+Veg·Fire+Water 경계 Steam)·확산 모델(연료 creep+Wind push) 반영. `activeMedia[]` 단일-매질/셀 = S4 갭 → **✅ S4 다매질 스택 구현으로 수렴(2026-07-22, primaryMedium+extra; 비드리프트 — 게임이 spec `INT-002 §6.1`에 따라잡음, [surface_grid.md §6 S4](design/surface_grid.md)).** 게임 상수(CELL_M/rings/cadence/prob)=튜닝(로깅만).
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
- **✅ 근사 정식 해소(2026-07-22, S2 완료):** 본 DRIFT의 핵심 한계였던 "교집합=중점 Steam·확산=반경 shrink" 원 근사를
  **셀 경계 반응**으로 대체 — `SurfaceGrid._react_cells`: **Fire 셀과 Water 셀이 인접한 경계 셀만** Steam으로(양쪽 소진,
  매틱 1셀 잠식=서서히). `_resolve_zone_pair` 중점/shrink는 flag ON에서 폐기. **사용자 이상("교집합만 반응+서서히 확산")이
  셀 단위로 실현됨.** ✅ **전파 완료(2026-07-22, staging `d9e9f52`, `DEC-20260722-001`)**: 셀 모델·연료 creep·passive
  Fire+Veg·Fire↔Water 셀반응을 `INT-002 §6/§6.1`/`EVENT-CORE §1/§3`/`EFFECT-CORE`/`RX-*`에 반영. 설계 정본 [design/surface_grid.md](design/surface_grid.md).

### DRIFT-097 — 모든 환경 zone 유계(영속 ∞ 제거 → ~10s 지속): 리소스 상한 원칙 🔶 rule (전파 후보)
- **배경(2026-07-22, 사용자):** 셀 그리드에서 **영속(ttl ∞) zone은 셀이 무한 누적** → 매 틱 순회/렌더 비용이 시간에
  비례해 증가(랙). 원칙 채택: **모든 zone은 지속시간을 두고(영속 제거) ~10초** → 총 활성 표면이 시간으로 상한 =
  "10초간 최대한 깔아도 연산이 버티는" 리소스 유계. (셀 관점: 지속 셀이 없어 `_expire`가 전부 만료 → 누적 차단.)
- **변경:** `barrel.gd` Oil 장판 `ttl -1→10`, `combat_sandbox` lay-zone `-1→10`. (스킬 zone 데이터는 이미 6~9s 유계 —
  변경 불요.)
- **⚠️ spec 규칙 변경:** `ZONE-CORE`가 **Oil ∞·Vegetation ∞**(`default_ttl` ∞)로 정의 — 이걸 **유계 지속**으로 바꾸는
  규칙 변경. `ZONE-OIL-001`/`ZONE-VEGETATION-001` TTL + "영속 zone" 개념(있다면) 개정 → **OPS_30 전파 후보.** 셀
  substrate 전파 묶음(DRIFT-096)과 함께.
- **분류:** rule → OPS_30 전파 완료. 게임 값(10s)은 튜닝수치지만, **∞→유계 전환 자체가 규칙**.
- **게이트:** ci_smoke(부팅·존 정상 만료). ⚠️ 체감 — 기름 10s 뒤 사라짐이 게임플레이상 OK인가(점화 전 소멸 등).
- **상태:** ✅ **전파** (staging `d9e9f52`, `DEC-20260722-002`; `ZONE-CORE` `ZONE-OIL-001`·`ZONE-VEGETATION-001` ttl `∞`→`10.0` + 유계 원칙 명문화).

### DRIFT-098 — AB-042 Spawn Gust Patch: 무효과 파손 해소 + 원형→**방향성 직사각 바람 복도** 🔶 rule (전파 후보)
- **배경(2026-07-23~24, I-006 캐스팅 패스 Phase A):** ① **파손** — `WindBuffeted`는 색·KO라벨·플로팅텍스트·오브까지
  배선돼 있으나 `outcome_status.MOVE_MULT`에 항목이 없고 넉백 소스도 없어 **런타임 무효과**였다(주석은 *"the source
  applies a knockback"* 이라 약속하지만 그 source가 부재). `ability_roles.gd` "Wind 밀림(무피해)"의 밀림이 실제로
  없음 = §0 "명백히 깨진 효과" 스코프. ② **surface_grid 리팩터로 전제 갱신** — 존 outcome 틱이 `hazard_zone`→
  `SurfaceGrid`로 이관됐고, Wind 확산도 `reaction_system._spread_tick`(자식-원 해킹) → `SurfaceGrid._wind_push`(셀 CA)로
  교체됨. 즉 Wind는 **기체·불 매질 산포기로만** 살아 있고 유닛 대상 효과는 0이었다(`WIND_PUSHABLE`=Smoke/Steam/
  ToxicGas/Fire — 기름·물·얼음은 고착이라 "돌풍에 기름이 흘러간다"는 옛 서술도 무효).
- **결정(사용자):** 원형 중심-방사 밀림이 아니라 **직사각 방향성 복도** — 조준점 P가 **복도 중앙**, 축 = 캐스터→P,
  **근단(캐스터쪽)이 최강이고 원단으로 gradient 감소**, 세기 소폭 상향. 즉발 체감이 나빠 **짧은 캐스트 1.0s** 부여("마법적").
- **변경:**
  - **유닛 밀림 신설** — `apply_drift(dir,dist)`(party_member·enemy_unit 동일 규격) = collision-stopped 위치 넛지.
    넉백(`apply_knockback`)은 일회 임펄스라 유닛별 스무딩이 달라(적=velocity·스티어링 차단 / 아군=instant) 지속 밀림엔
    부적합 → 드리프트 전용 API로 분리. `SurfaceGrid._wind_push_units`가 grid tick마다 적용(피아무구분·F-021, telegraph 중 제외).
  - **rect 지오메트리** — `HazardZone.shape/wind_dir/length/width` + `setup_rect()` + rect-aware `contains_point`,
    `SurfaceGrid.stamp_rect()`(직사각 셀 래스터화) + `_stamp_zone` 분기. `spawn_zone(...,opts)`로 전달(sb_zone·enemy_ai).
    **RX 스폰은 opts 없음 = 원형 유지**(Steam/Fire 등 무영향).
  - **축방향+gradient 통일** — `_wind_field()` 공용 헬퍼로 매질(`_wind_push`)·유닛(`_wind_push_units`) 모두 축 방향 +
    근단 gradient(1.0→`WIND_FALLOFF_MIN`). 원형 Wind는 방사·uniform 폴백.
  - **적 대칭(규칙5 통합)** — EN-004도 동일 rect 복도(축 = 적→시전지점).
  - **aim 회귀 수정** — `shape:"rect"` 추가가 AB-042를 **AB-005용 빔 조준 분기**(캐스터에서 뻗는 lane)로 밀어넣어
    ⓐ 프리뷰↔실제 스폰 좌표 불일치 ⓑ 최대사거리 링 미표시가 발생. `skillbook_zone`+rect는 **지면배치 조준**으로 분리
    (`AimMarker.show_zone_rect` = 커서 P 중앙 rect 프리뷰 + 사거리 링). `skillbook_strike`+rect(AB-005)는 빔 유지.
- **⚠️ spec 필드 추가 → ✅ 전파 완료:** zone cast 스키마에 **`shape`(circle|rect)·`length_m`·`width_m`** 신설 —
  튜닝수치가 아니라 **필드/enum 추가**라 SSOT 편집 대상이었고 OPS_30으로 역전파했다. (impact_scan 결과 `F-021`은
  형상을 언급하지 않아 **대상 아님** — 형상 SSOT는 `ZONE-CORE`.) 실제 전파 범위는 예상보다 넓었다: spec이
  `WindBuffeted`를 *"진입 0.3s 짧은 밀림 + 속도 ×1.05"*(`APPLY-WIND-PUSH-0P3S`/`RX-WIND-ENTER-001`)로 정의하고
  있어 **밀림 모델 전환**까지 함께 반영.
- **튜닝수치(로깅만):** `length_m` 6.0 · `width_m` 2.5(구 `radius_m` 2.0 원 대체) · `WIND_UNIT_PUSH_MPS` 2.5(근단 피크) ·
  `WIND_FALLOFF_MIN` 0.2 · `cast_s` 1.0. 전부 Phase B 재튜닝 대상.
- **분류:** rule(형상 축·기준점 규약·밀림 모델 전환) → **OPS_30 전파 완료** + impl/tuning(aim 분리·수치)은 DRIFT-078
  우산 하위 로깅.
- **게이트:** ci_smoke **PASS**(11/11). F5 체감 2회 반영(조준 불일치 → aim 분리 / 즉발 체감 → cast_s 1.0).
- **상태:** ✅ **전파** (spec `a5e5ae3` staging push, `DEC-20260724-001`; `ZONE-CORE` 형상 축 규약 + `ZONE-WIND-001`
  `Circle`→`Rect` · `D-016` §3 `shape`/`length_m`/`width_m` + 기준점 규약 · `EFFECT-CORE` `DRIFT-WIND-CORRIDOR`+
  `APPLY-WIND-BUFFETED-DWELL` 신설·`APPLY-WIND-PUSH-0P3S` Deprecated · `STATUS-OUTCOME-CORE` `WindBuffeted`=체류 표식 ·
  `RX-WIND-ENTER-001` 재작성 · `AB-042` 값 부여). 게임 재핀 `d9e9f52`→`a5e5ae3`. mapper 0 · xref broken-ref 0.
  **후속(spec TODO 등재):** 적 `telegraph_s` 0.4 ↔ 아군 `cast_s` 1.0 **타이밍 대칭 미확정** = Phase B 판정.

### DRIFT-099 — AB-012 Hex Bolt: 취약 표식(HEX-WEAK/Vulnerable) → **개구리 폴리모프 CC** 🔶 rule (전파 후보)
- **배경(2026-07-24, I-006 캐스팅 패스 Phase A · 사용자 결정):** AB-012는 **3중 드리프트**였다 — 아군(skillbooks
  `skillbook_vulnerable` = 순수 `Vulnerable` +15%) ≠ 적(abilities `enemy_hex` = `hex_slow`+`hex_weak`+dmg) ≠ spec
  (`HEX-WEAK` 이동·피해 soft CC). 게다가 아군 AB-012 == AB-057(둘 다 `Vulnerable` +15%, §5 "취약 2 통폐합 후보").
- **결정:** AB-012를 **개구리 변이 폴리모프 하드 CC로 전면 재정의**(취약 표식 폐기). 시나리오 = "까다로운 엘리트를
  잠시 얼려두고 잡몹 먼저 처리." → **적↔아군 통일**(단일 거동). 이로써 AB-057(순수 증폭)과 완전히 갈려 **통폐합 문제도 해소**.
- **동작(신규 CC):** 대상 30s 개구리 변이 → ① 공격/시전 전면 불가 ② AI/플레이어 컨트롤 무력(랜덤 hop 자동이동)
  ③ **어떤 피해든 받으면 즉시 해제**(sheep式) ④ **양측 모두 개구리를 타겟 후보에서 제외**(파티 평타·적 어그로 전부
  무시 → 자동 브레이크 방지, "얼려둔 놈 방치") ⑤ **힐러 정화(AB-070)로 아군 개구리 해제**(AB-070에 아군 dispel 경로 신설).
- **변경(~18파일):** 신규 `skillbook_polymorph`(`sb_polymorph.gd`) · 양 유닛 `apply_polymorph`/`is_polymorphed`/
  `remove_polymorph`/`polymorph_hop_velocity` + 미니멀 개구리 큐(메시 축소 0.45·초록·hop 바운스) + `take_damage`
  break 훅 · `enemy_ai` takeover 슬롯(stun 다음)·`enemy_hex` resolve→`apply_polymorph`(통일) · 행동차단 게이트
  (`combat_controller`·`skill_cast`·`beam_channel`·`dungeon_run`·`combat_sandbox`) · party 컨트롤 hop(`player_controller`·
  `party_controller`) · 타겟 제외(파티 `_nearest_enemy_in_range` skip_poly / 적 `_alive_members`·`_nearest_visible`·
  `_huntable`) · `sb_purge`(AB-070) 아군 dispel · `ability_dispatch` 레지스트리 · `aim_controller` UNIT_AIM.
  **회귀 동반수정:** AB-042 적-rect가 `combat_controller.spawn_zone`/`cast_context.spawn_zone` 래퍼의 `opts` 인자
  누락으로 **적 zone 시전 시 크래시**(ci_smoke 사각=적-zone 런타임 경로 미검증) → 4개 `spawn_zone` 정의 arity 통일.
- **⚠️ spec 재정의(전파 후보):** `HEX-WEAK`(soft CC) 폐기 + 신규 **폴리모프 상태**(공격/시전/컨트롤 봉쇄 + break-on-damage)
  + AB-012 `abilityKind`/`applies_status`/effects 재정의. 대상 후보: `AB-012` 정의 · `STATUS-OUTCOME-CORE`(`HEX-WEAK`→
  폴리모프 상태) · `EFFECT-CORE`(`APPLY-HEX-WEAK-4S` Deprecated + 폴리모프 effect) · `D-016`(castTier B/cast_s) ·
  AB-070 dispel 규약. **이 레포에서 spec md 미편집**(CLAUDE.md 절대규칙). ⚠️ 규모 큰 전파.
- **튜닝수치(로깅만):** `poly_dur_s` 30 · `cast_s` 3.0 · `cooldown_s` 4→12 · 적 `telegraph_s` 0.45→3.0 · hop(간격 0.65·
  속도 2.2) · 개구리 축소 0.45. 전부 Phase B 재튜닝.
- **분류:** rule/design(폴리모프 재정의·통일·dispel 규약) → **OPS_30 전파 완료** + impl/tuning은 DRIFT-078 우산 하위.
- **게이트:** ci_smoke **PASS**(11/11, 4회 — 구현·spawn_zone회귀·적무시 각 확인). F5 체감 반영 2건(적이 개구리
  아군 즉시 브레이크 → 적 타겟 제외 / 적 zone 크래시 → spawn_zone arity).
- **상태:** ✅ **전파** (spec `fb87816` staging push, `DEC-20260724-002`; 신규 `Polymorphed`(`STATUS-ACTOR-CORE`) ·
  `AB-012` Debuff→Control·`applies_status`→`[Polymorphed]`·`cast_s 3.0` · `EFFECT-CORE` `APPLY-POLYMORPH-30S`·
  `APPLY-HEX-WEAK-4S` Deprecated · `STATUS-OUTCOME-CORE` `HEX-WEAK` Deprecated · `AB-070` 아군 dispel(`targetType` Any) ·
  프로즈 `EN-007`/`ROLE-040`/`ROLE-001`/`ENC-HARD-004`/`AB-080`/`IDA-031` 정합). 게임 재핀 `a5e5ae3`→`fb87816`. mapper 0 ·
  xref broken-ref 0 · 정의 ID +1. 개구리 dispel = **AB-070 단일 확정**(게임에 다른 정화 없음 — IDA-031은 지속치유로 재해석됨, Ward Pulse 정화 폐지 DRIFT-073). **후속:** 3s 캐스트 중 표적 이탈=대상 엔티티 락(impl).

### DRIFT-100 — AB-013 Backstab Dash 확정: 아군 `skillbook_charge`→`skillbook_dash`(단일 접근+피해) + 결속 2종 · 적 telegraph/cd 튜닝 🔶 impl + tuning
- **배경(2026-07-27, 사용자 확정):** [[DRIFT-085]] ②(AB-013=AB-006 발전형: 접근+즉시딜×1.5)의 아군측 구현 완결. DRIFT-085 당시 "코드 변경 0(스킬트리 배치 시)"였으나, 아군 AB-013 스킬북이 `skillbook_charge`(전방 콘·다수 넉백=탱커형)로 남아 "단일표적 접근+피해" 설계와 어긋나 있었다.
- **① 아군 스킬(impl):** `skillbooks.json` AB-013 cast `skillbook_charge`→**`skillbook_dash`**(신규 `sb_dash.gd`): 조준 적에게 캐스터 돌진(gap_m 1.4 남김)+단일 데미지(×1.5)+`report_hit_target`(집중 결속 훅). Tank `skillbook_charge`(콘·넉백)와 분리 = 이동계열 접근+피해 슬롯(AB-006 무피해 gap-close ↔ AB-013 접근+피해). 적 `enemy_dash`(EN-008 백스탭) 거동 통일. `cast_s 1.0`·targeted·range 8·radius 2.5.
- **② 결속 2종(impl, BIND-037/038, 슬롯 무관):** 「집중」(IDA-025 `focus_backstab`)=명중 시 집중 +2스택, max 도달/이미 max면 준 피해만큼 캐스터 보호막(1s). 「잠행」(IDA-029 `flank_backstab`)=근접 사거리 패널티 없음(이미 돌진) + 주변 처치 시 이 스킬 쿨 초기화(암살 연쇄, `notify_kill`). overlay 35→37.
- **③ 적(tuning):** `abilities.json` AB-013 `telegraph_s` 0.3→**1.0** · `cooldown_s` 5→**10** · `knockback_m` 1.0→**0.0**. EN-008 하드모델(치고-빠지기) 페이싱 — 로깅만, Phase B 재튜닝.
- **분류\전파:** 신규 `skillbook_dash` kind + BIND-037/038 = **rule 전파 후보**(OPS_30, [[DRIFT-085]] 발전형 계열 후속 배치 — 085는 ✅전파완료). 적 telegraph/cd/kb = **tuning 로깅만**. 이 레포 spec md 편집 금지.
- **영향 파일:** `data/slice01/{abilities,skillbooks}.json` · `scripts/combat/abilities/effects/sb_dash.gd`(신규) · `ability_dispatch.gd`(등재+`_nuker_focus_backstab`) · `bindings/binding_overlays.gd`(BIND-037/038) · `party_member.gd`(notify_kill 쿨초기화) · `aim_controller.gd`(UNIT_AIM) · `tools/binding_smoke.gd`(37).
- **상태:** LOGGED (게임측 확정). skillbook_dash kind + BIND-037/038 전파 = 사용자 판단 대기.

### DRIFT-101 — T1(Tank 지역 강타) 통폐합: AB-071·049·104 폐기 → AB-002/011 2종 · 강타/기절 툴팁 재정의 🔶 rule/scope (전파 후보)
- **배경(2026-07-28, 사용자 판정):** [[DRIFT-078]] Phase A를 **「효과 유사도 × 주력 클래스」 클러스터**로 재편(§5)한 뒤 첫 판정. Tank 지역 강타 클러스터(T1) 실사에서 **AB-002↔071이 툴팁·`damage_mult`(1.0) 100% 동일**(차이 = 반경 8.0↔2.2 · kb 3.0↔2.0 · cd 2↔6)이고 **AB-011↔049는 단조 사다리**(stun 1.4↔0.6 · dmg 0.6↔0.3 · cd 8↔10, 049는 반경만 우위)로 확인. AB-104는 AB-011과 역할 중복. 사용자 판정: *"각 스킬이 주는 추가적인 메리트가 없으니 AB-002와 011만 남긴다"*.
- **① 아군 서브 3종 폐기(scope):** `skillbooks.json`에서 **AB-071 Bulwark Bash · AB-049 Ground Pound · AB-104 Rampage 삭제**(60→**57종**). 폐기분은 전부 미완료였으므로 완료 19 불변 / 미완료 41→**38**. Tank 주력 15→**12종**. **ID는 `id_registry`에 등록만 잔존·미사용**([[DRIFT-085]] AB-061·AB-039 선례 — 정식 제거는 스펙 배치).
- **② Shared 폐기 시 적측 처리 규칙(rule — 사용자 확정):** *"아군 스킬을 제거할 때 그게 Shared였다면 적측도 통폐합 대상 스킬로 교체한다."* [[DRIFT-082]] K1 대칭·§0 규칙5(진영별 분기 금지)의 폐기 방향 대칭 규칙. 적용: **EN-3RD-03 Reaver 킷 `AB-104`→`AB-011`**(`enemies.json`), 고아가 된 `abilities.json` **AB-104 항목 삭제**. AB-071·049는 Ally-only라 해당 없음.
  - ⚠️ **파생 결과(로깅):** Reaver(elite, hp640)의 오프너가 **돌진 line-cleave(dmg 1.1 + splash 0.6 + kb) → 단일 기절(dmg 0.6 · stun 1.4 · cd 5)**로 바뀐다. 아키타입이 "돌진 학살자"에서 "기절 학살자"로 이동하고 위협도가 내려간다 — **Phase B 밸런싱/아키타입 재확인 대상**(§0 밸런싱 스킵 원칙에 따라 지금은 로깅만). 되돌릴 경우의 대안 = 돌진을 `rom_*` 기본 공격 아키타입으로 내리기.
- **③ 남은 2종의 차이축을 툴팁으로 못박음(impl — 사용자 지시):** 실사 결과 **AB-011은 이미 코드상 단일 대상**이었다(`sb_stun`이 `nearest_enemy_in_range`로 1체 선택, `radius_m`은 조준 어시스트 반경). 즉 기계는 맞고 **문구만 광역처럼 거짓말**하고 있었다. `display_names.json` `skill_desc`:
  - `skillbook_strike`: "대상 지역의 적을 강타해…" → **"자신의 발밑을 강타해 주변 적 전체에게 피해를 주고 밀어낸다."** (AB-002·028 = `targeted` 없는 **자기중심**인데 "대상 지역"이라 조준형으로 읽혔다.)
  - `skillbook_strike_rect`(신규 키): **"전방 직선 범위를 휩쓸어 그 안의 적에게 피해를 주고 밀어낸다."** — `shape:"rect"`(AB-005) 분기. [skill_text.gd](../scripts/ui/skill_text.gd) `describe`가 params로 고른다([[DRIFT-085]] ⑤ 볼트 조립 선례와 동형, 스키마 변경 0).
  - `skillbook_stun`: "대상 지역의 적을 강타하고…" → **"조준한 적 1기를 강타하여 피해를 주고 잠시 기절시킨다. 시전 중이었다면 시전을 중단시킨다."** 채널 인터럽트는 `apply_stun`이 실제로 하는 일(EN-AI-000 §2)이라 **AB-011의 실질 메리트**로 표면화. AB-030(Voltaic Interrupt)도 같은 kind라 동시에 참이 된다 — 이름과 데이터의 괴리 해소.
  - ⚠️ **AB-028은 `knockback_m: 0.0`이라 "밀어낸다"가 여전히 거짓** — 변경 전에도 거짓이었고 D4(DPS 지역 강타) 판정 항목으로 이월(로깅만).
- **④ 고아 정리:** `sb_charge.gd` **삭제**(`skillbook_charge` 유일 사용자였음) + `ability_dispatch` preload·`ability_roles` AB-104 행·`aim_controller` UNIT_AIM_KINDS·`display_names`(skill_desc/effect_kinds) 항목 제거. **`enemy_ai`의 `line` 분기·`_rampage_splash`는 존치** — AB 고정이 아니라 데이터(`line: true`) 구동이라 재사용 가능한 일반 경로다(현재 사용처 0, 주석 표기).
- **분류\전파:** 서브 3종 폐기(아군 풀 스코프) + **Shared 폐기 대칭 규칙(②)** = **rule/scope → OPS_30 전파 후보**([[DRIFT-078]] 패스 확정분과 동반 배치). 툴팁 워딩·`skillbook_strike_rect` 키 = impl(스키마 변경 없음). Reaver 위협도 = tuning 로깅만. **이 레포 spec md 편집 금지.**
- **영향 파일:** `data/slice01/{skillbooks,enemies,abilities,display_names}.json` · `scripts/ui/skill_text.gd` · `scripts/combat/abilities/{ability_dispatch,ability_roles,cast_context}.gd` · `effects/sb_charge.gd`(삭제)·`effects/sb_dash.gd`(주석) · `scripts/run/controllers/aim_controller.gd` · `tools/third_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — third_smoke에 `EN-3RD-03 kit has AB-011` · `AB-104 removed from catalog` 검증 2건 신설.
- **상태:** ✅ **전파 완료**(spec `0944e6f`, `DEC-20260728-001`) — AB-071/049/104 Deprecated · Shared 폐기 대칭 규칙 신설 · AB-002/011 차이축 SSOT 명시 · EN-3RD-03 킷 교체.

### DRIFT-102 — T2(Tank 피해 감소) 통폐합: AB-074 폐기 · AB-048 → **반격(반사)** 재정의 · AB-046/047 자기↔파티 분화 🔶 rule/scope/schema (전파 후보)
- **배경(2026-07-28, 사용자 판정):** [[DRIFT-101]] T1에 이은 T2 판정. Tank 주력 DR 4종(AB-046·047·048·074)이 **툴팁 한 문장을 공유**하고 실차이가 수치뿐이었다(046 0.5/2.0s·048 0.4/1.5s = **같은 자기중심·같은 cd9**, 047 0.2/3.0s·074 0.3/6.0s = 둘 다 광역 r4.0). Tank 서브 슬롯은 3개인데 같은 문장 4종이 경합 = 전수 중 최악의 동일-클래스 중복.
- **① AB-046 ↔ AB-047 = 「자기만 ↔ 팀원도」로 분화(impl):** 기계는 이미 갈려 있었다(`sb_dr`가 `allies_in_radius(radius_m)` — 046/068 r0.5 = 자기 · 047 r4.0 = 주변 아군). **문구만 뭉뚱그려져** 있었으므로 워딩으로 못박음:
  - `skillbook_dr`: "잠시 동안 받는 피해를 감소시킨다." → **"잠시 동안 자신이 받는 피해를 감소시킨다."**
  - `skillbook_dr_party`(신규 키): **"잠시 동안 주변 아군 전체가 받는 피해를 감소시킨다."** — [skill_text.gd](../scripts/ui/skill_text.gd) `describe`가 `radius_m > 1.0`으로 분기([[DRIFT-101]] `skillbook_strike_rect` 선례와 동형, 스키마 변경 0). AB-068(Healer 자기)도 자동으로 자기 문구.
- **② AB-048 Counter Stance → `skillbook_reflect` 재정의(scope/schema — 신규 effect kind):** *"이름에 맞게 피해를 일정 부분 반사하는 효과로"*(사용자). DR 계열에서 **빼내** 이름값을 실현 → T2의 4종 중복이 구조적으로 해소된다(DR 2 + 반격 1).
  - `skillbooks.json` AB-048 cast: `skillbook_dr`/`damage_reduction 0.4`/`radius_m 0.5` **삭제** → **`skillbook_reflect`** · `reflect_frac 0.4`(기존 DR 0.4 자리 승계) · **`reflect_cap 40.0`** · `duration_s 1.5`·`cooldown_s 9` 유지.
  - **`reflect_cap` = 시전 1회당 반사 총량 상한**(사용자 지시: *"최대 상한치를 만들어서 추후 밸런싱이 편하게"*). 다수에게 둘러싸일수록 반사가 무한 증폭되는 걸 막는 레버 — **frac·cap 두 숫자만 만지면 튜닝 완결.** 상한 소진 시 태세가 남아 있어도 반사 정지, 재시전마다 예산 재충전. 밴드/affix `_coeff`는 **상한 쪽에 태운다**(비주력이 들면 총량이 줄어듦).
  - **IDA-052 Sentinel Form과 분리:** Sentinel = DR + 이동잠금 + 반사(무제한). AB-048 = **순수 반사**(DR 없음·이동잠금 없음·상한 있음). 훅은 `party_member.take_damage`에서 Sentinel 반사 바로 다음, **경감 전 amount 기준**(Sentinel과 동일 규약).
  - ⚠️ **`reflect_cap 40.0`은 PH 시작값** — 적 contact 10~22 기준 "1.5초에 100 피해를 받아야 상한이 무는" 수준. Phase B 튜닝 대상(로깅만).
- **③ AB-074 Guardian Oath 폐기(scope):** 사용자 판정 *"74는 제거"*. AB-047과 같은 광역 r4.0 DR로 축이 완전히 겹쳤다(0.3/6.0s/cd16 ↔ 0.2/3.0s/cd12). **Ally-only라 [[DRIFT-101]] ② Shared 폐기 대칭 규칙은 해당 없음.** `skillbooks.json` 삭제(57→**56종**) + `dungeon_run.ALLY_CACHE_POOL` 제거. ID는 `id_registry` 등록만 잔존·미사용.
- **결과 — T2 클러스터:** 4종(⬜4) → **3종(⬜3)**, 그러나 **DR은 046(자기)·047(파티) 2종으로 축이 직교**하고 048은 별 계열로 이탈 → **클러스터 내부 실중복 0.** 완료 19 불변 / 미완료 38→**37**. Tank 주력 12→**11종**.
- **분류\전파:** **신규 `skillbook_reflect` kind + `reflect_frac`/`reflect_cap` 필드** = schema/rule → **OPS_30 전파 후보**([[DRIFT-100]] `skillbook_dash` 선례와 동일 처리). AB-074 폐기 = scope 전파 후보. 툴팁 분화·`skillbook_dr_party` 키 = impl. `reflect_cap` 값 = tuning 로깅만. **이 레포 spec md 편집 금지.**
- **영향 파일:** `data/slice01/{skillbooks,display_names}.json` · `scripts/combat/abilities/effects/sb_reflect.gd`(신규)·`sb_dr.gd`(주석) · `ability_dispatch.gd`(등재) · `party/party_member.gd`(`apply_reflect`/`is_countering`/take_damage 훅/만료) · `ui/skill_text.gd` · `run/dungeon_run.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 반격 재정의·074 폐기·046/047 반경 분화 검증 **7건** 신설.
- **상태:** ✅ **전파 완료**(spec `0944e6f`, `DEC-20260728-001`) — AB-074 Deprecated · AB-048 반사 재정의(spec은 원래 `REFLECT-*`였고 게임이 DR로 드리프트했던 것 → **수렴**). ⏳ F5 체감 대기.

### DRIFT-103 — 피해 감소 체감 개편: 상태 승격 + 막은 양 표시 + **횟수 기반** 전환 · DR 곱연산 · 타이머 공유 버그 수정 🔶 rule/impl + 🐞 bugfix
- **배경(2026-07-28, 사용자 지시 "ABE 적용"):** [[DRIFT-102]] T2 직후 *"피해 감소가 너무 체감되지 않는다"*. 실사 결과 원인이 셋으로 갈렸다.
  - **① 화면에 존재하지 않았다(가장 큼):** `damage_taken_mult`가 생 float라 [party_member.gd](../scripts/party/party_member.gd) `get_status_list()`에 **없었다** — 보호막·은신·기절은 칩+지속 arc가 뜨는데 DR만 아무 표시가 없었고, 시전 시 팝업 1회가 전부. 게다가 **아군은 피격 데미지 숫자 팝업 자체가 없어**(`take_damage`→`_flash()`만) "원래 얼마 맞았는지" 기준선이 없었다. 즉 줄어든 걸 지각할 채널이 0.
  - **② 지속 < 적 공격 주기:** 적 `attack_interval_s` 1.3~1.8s인데 AB-046은 2.0s → 적 1기 상대 **1~2타**만 덮음.
  - **③ 절대량:** Tank HP 170~205 · 적 contact 10~22 기준 AB-046 실경감 **7~15(HP의 4~8%)**, AB-047 **약 6**.
- **① A — 상태 승격(impl):** DR을 `_dr_stacks` 배열로 승격하고 `get_status_list()`에 **스택마다 별개 버프 칩**으로 내보낸다(`name` = "라벨 −N%", `ratio` = 남은 타수 비율, `stacks` = 남은 타수). `party_sheet`의 status pip(4슬롯, 버프 미필터)이 자동으로 둘을 나란히 그린다. **버프 아이콘 2개 별개 = 사용자 명시 지시.**
- **② B — 막은 양 표시(impl):** 피격 시 경감량을 계산해 **"막음 N"** 팝업(≥1일 때만), 스택 소진 시 **"라벨 종료 (총 N 막음)"**. 곱연산이라 스택별 기여 분리가 불가능해 표시용 누적은 **균등 배분**(정확한 귀속이 아니라 체감 지표라는 걸 코드 주석에 명시). AB-065 `ward_heal`의 흡수량 정산과 같은 계열.
- **③ E — 횟수 기반 전환(rule/schema) — ⛔ [[DRIFT-104]]에서 롤백됨(2026-07-28 당일):** `duration_s`(초) → **`dr_hits`(타수)**. *"다음 N회의 공격에 대해 피해가 X% 줄어든다"* — **셀 수 있는 게 체감의 핵심**이라 툴팁 문장에도 params로 박았다. 타수는 **가해자가 있는 피격만 소모**(존/장판/DoT는 경감은 받되 예산을 안 태운다 — 0.5s마다 도는 DoT가 예산을 즉시 태워 버리는 걸 막는다). `dr_ttl_s`(기본 8s) = 전투 이탈 시 스택이 영원히 남지 않게 하는 **안전장치일 뿐** 주 수명이 아니다.
  - 데이터: **AB-046 철벽 50%×2타** · **AB-047 수호진 20%×3타** · **AB-068 수호인 15%×3타**(+`dr_label` = 칩 분리 키, `dr_ttl_s` 8.0). `duration_s` 제거.
  - ⚠️ 타수 값은 **PH**(기존 지속에서 환산) — Phase B 튜닝 대상.
- **④ 곱연산(rule — 사용자 지시):** 여러 DR이 겹치면 **Π(1−frac)**. 50%+20% = **×0.4(60% 감소)**. 종전 "최강 하나만 적용(minf)"에서 전환 — 연속으로 쓰면 실제로 더 단단해진다. 최종 배율 = `_sentinel_dr_mult × Π(1−frac_i)`, `_recalc_damage_taken_mult()`가 단일 소유.
- **⑤ 🐞 버그 수정 — Sentinel/DR 타이머·배율 공유:** 종전 `apply_damage_reduction`이 `damage_taken_mult`(minf)와 **`_sentinel_timer_s`(maxf)를 IDA-052와 공유**해서, **약하고 긴 DR을 덧걸면 강한 DR의 지속만 연장**됐다(AB-046 50%/2s → AB-047 20%/3s = **50%가 3초 유지**). Sentinel 배율을 `_sentinel_dr_mult`로 분리하고 DR은 자체 스택이 소유 → 둘은 이제 **곱해질 뿐 서로의 수명에 관여하지 않는다.**
- **분류\전파:** **DR 시간→타수 전환 + `dr_hits`/`dr_label`/`dr_ttl_s` 필드 + 곱연산 규칙** = rule/schema → **OPS_30 전파 후보**([[DRIFT-102]] `skillbook_reflect`와 동반 배치). 상태 승격·막은 양 표시 = impl. 타수 값 = tuning 로깅만. 타이머 공유 = **버그 수정**(전파 불요). **이 레포 spec md 편집 금지.**
- **영향 파일:** `data/slice01/{skillbooks,display_names}.json` · `scripts/party/party_member.gd`(`_dr_stacks`/`_sentinel_dr_mult`/`apply_damage_reduction`/`_recalc_damage_taken_mult`/`_consume_dr`/take_damage 훅/만료/`get_status_list`) · `scripts/combat/abilities/effects/sb_dr.gd` · `scripts/ui/skill_text.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 곱연산(0.5×0.8=0.4)·칩 2개 분리·같은 label 갱신·**Sentinel×DR 분리(0.4×0.4=0.16)** 검증 신설.
- **상태:** ✅ **전파 완료**(spec `0944e6f`, `DEC-20260728-001`) — **DR 중첩 = 곱연산** 규칙이 `EFFECT-CORE` 전역 노트로 승격(별개 버프 아이콘·독립 수명 포함). ③ 타수형은 [[DRIFT-104]]에서 롤백돼 전파 대상 아님. ⏳ F5 체감 대기.

### DRIFT-104 — DR 타수형 **롤백**(시간 기반 복귀) · 반격 2변주 분기(AB-048 → **048a 시간형 / 048b 캐스팅 한정**) 🔶 rule/scope/schema (전파 후보)
- **배경(2026-07-28, 사용자 판정):** [[DRIFT-103]] ③으로 DR을 타수형(`dr_hits`)으로 바꿨는데 F5 없이 즉시 반려 — *"타수로 했더니 체감하기가 더 어렵다"*. **원인 분석:** 타수는 **소진 시점을 플레이어가 예측할 수 없다**(적 공격 타이밍에 종속). 지속(초)은 칩 arc가 줄어드는 걸 보며 남은 창을 읽을 수 있는데, 타수는 "언제 닳는지"가 외부 변수라 오히려 인지 부하가 늘었다. 반면 **[[DRIFT-103]] ①(상태 승격)·②(막은 양 표시)·④(곱연산)·⑤(버그 수정)는 유지**한다 — 반려된 건 시간→타수 축 하나뿐.
- **① DR 시간 기반 복귀(rule 롤백):** `dr_hits`/`dr_ttl_s` 제거 → **`duration_s` 복귀**(AB-046 2.0s · AB-047 3.0s · AB-068 4.0s = 종전값). 칩 `ratio`는 남은 시간, `stacks` 표기 제거. `_consume_dr`는 **막은 양 적산 전용**이 되고 만료는 시간이 처리 → 존/DoT도 동일하게 경감된다(예산 개념 소멸 = 타수형의 "DoT가 예산을 태운다" 예외도 함께 소멸).
  - ⚠️ **[[DRIFT-103]] ②(지속 < 적 공격 주기)는 미해결로 남는다** — AB-046의 2.0s는 적 `attack_interval_s` 1.3~1.8s 기준 여전히 1~2타만 덮는다. 지속 상향이 남은 레버지만 수치라 Phase B(사용자 지시 없이 건드리지 않음).
- **② 반격 2변주 분기(scope — 신규 ID):** *"특정 타수에 대해서, 평타급은 제외하고 적이 캐스팅 집중을 하고 쓰는 스킬에 한정해서 막는 스킬"* + *"일정 시간 동안 반사가 적용되는 스킬"* 두 개로 갈라라(사용자). **AB-007 → AB-007a/AB-007b 선례와 동형**으로 `AB-048` → **`AB-048a`/`AB-048b`** 분할, `id_registry.ability_ids`에서 `AB-048`을 두 항목으로 치환.
  | | AB-048a **Counter Stance**(반격 태세) | AB-048b **Riposte**(응수) |
  |---|---|---|
  | 발동 조건 | 지속 동안 **모든 피격** | **적 캐스팅 스킬 피격만**(평타 무시) |
  | 수명 | `duration_s 3.0` | `reflect_hits 2`타(+`duration_s 6.0` = 창 안전장치) |
  | 반사율 / 상한 | 40% / 40 | **80% / 60** — 발동 기회가 드문 만큼 한 방이 크다 |
  | cd | 9 | 12 |
  - **캐스팅 판별:** `enemy_ai._apply_enemy_hit`가 `chosen.trigger == "signature"`(= AB-### 능력)를 `take_damage(amount, attacker, from_ability)` 3번째 인자로 넘긴다. `rom_*` 평타·존·트랩은 false. **신규 시그니처 인자**(기본값 false라 기존 호출부 무영향).
  - 타수형은 **반사가 성립한 피격만** 타수를 깎는다(평타를 맞아도 응수 창이 닳지 않음).
- **③ ⚠️ 반사는 경감이 아니다(rule — 사용자 확정):** **두 변주 모두 내 캐릭터가 받는 피해는 그대로 들어간다.** 반사는 `amount`를 건드리지 않고 공격자에게 추가로 되돌리기만 한다. *"패링되어 딜이 안 들어오고 반사만 되는 건 나중에 고도화 시 특성으로 넣을 예정"* — **딜 무효화는 후속 특성으로 이연**(지금 구현 금지). 툴팁에도 "받는 피해 자체는 줄어들지 않는다"를 명시.
- **④ 피드백:** 반사 성립 시 **"반사 N"** 팝업, 종료 시 **"라벨 종료 (총 N 반사)"**. 반격도 DR과 같이 **버프 칩**(arc = 남은 타수 or 시간, stacks = 남은 타수)으로 승격.
- **분류\전파:** **신규 ID `AB-048a`/`AB-048b`** + `reflect_hits`/`reflect_cast_only`/`reflect_label` 필드 + `take_damage(from_ability)` 시그니처 = rule/scope/schema → **OPS_30 전파 후보**([[DRIFT-102]]/[[DRIFT-103]]과 동반 배치). ⚠️ **[[DRIFT-085]]가 지적한 "AB-007a/b 신규 ID 미로깅" 선례 반복을 피하려 이번엔 분할 즉시 로깅한다.** DR 롤백 = [[DRIFT-103]] ③ supersede. 수치 = tuning 로깅만.
- **영향 파일:** `data/slice01/{skillbooks,display_names,id_registry}.json` · `scripts/party/party_member.gd`(take_damage 3인자·`apply_reflect` 6인자·`_end_reflect`·DR 시간 롤백·반격 칩) · `effects/{sb_reflect,sb_dr}.gd` · `scripts/combat/enemy_ai.gd`(from_ability 전달 4곳) · `scripts/ui/skill_text.gd` · `scripts/run/dungeon_run.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 **기능 검증** 신설: 응수가 ① 평타를 반사하지 않고 ② 평타 피해는 그대로 들어오며 ③ 캐스팅 스킬은 0.8×20=16 반사하고 ④ **반사해도 내 피해는 그대로**임을 실제 `take_damage` 호출로 확인.
- **상태:** ✅ **전파 완료**(spec `0944e6f`, `DEC-20260728-001`) — `AB-048a`/`AB-048b` 분할 등재 + preset 2종 신설 + **반사 ≠ 경감** 규칙이 `EFFECT-CORE` 전역 노트로 승격(패링 이연 명시). ⏳ F5 체감 대기(응수 발동 빈도).

### DRIFT-105 — 피해 감소 지속 상향(오오라형 전환): 2~4s → 6~10s · 쿨 동반 상향 🔶 tuning (로깅만)
- **배경(2026-07-28, 사용자 판정):** *"2초 너무 짧아. 이런 오오라 류는 길게 지속되면서 버프를 줘야 해."* [[DRIFT-104]]가 미해결로 남긴 "지속 < 적 공격 주기" 문제의 해소. 적 `attack_interval_s` 1.3~1.8s 기준 AB-046의 2.0s는 **1~2타**밖에 못 덮어, 버튼을 눌러도 "무슨 일이 일어났는지" 관측할 표본 자체가 안 생겼다.
- **⚠️ 지속만 늘리면 안 되는 이유(동반 상향 근거):** 장르 관례는 능동 방어 쿨기 **6~12초 지속 + 그보다 훨씬 긴 쿨**(수십 초~분)인데, **이 게임의 쿨 스케일은 2~16초로 압축**돼 있다. 지속만 관례에 맞추면 가동률이 100%를 넘어 **버프가 아니라 패시브 스탯**이 된다(선택이 사라짐). → 쿨을 같이 올려 가동률을 설계값으로 고정.
- **적용:**
  | AB | 감소 | 지속 | 쿨 | 가동률 | 덮는 타수 |
  |---|---|---|---|---|---|
  | **AB-046** 철벽(자기) | 50% | 2.0 → **6.0s** | 9 → **16** | **38%** | 1~2 → **4** |
  | **AB-047** 수호진(파티 r4.0) | 20% | 3.0 → **10.0s** | 12 → **16** | **62%** | 2 → **6~7** |
  | **AB-068** 수호인(Healer 자기) | 15% | 4.0 → **10.0s** | 10 → **14** | **71%** | 2~3 → **6~7** |
- **파생 성격 분화:** 강한 자기 방어(046) = **저가동률 반응기**(38%) / 약한 광역(047·068) = **고가동률 오오라**(62·71%). [[DRIFT-102]]의 "자기 ↔ 파티" 축에 **가동률 축**이 하나 더 얹혀 두 스킬이 문구·범위·리듬 세 겹으로 갈린다.
- ⚠️ **남는 과제:** 가동률이 크게 올랐으므로 **감소율 자체의 재검토**가 필요하다(62%·71% 시간 동안 20%·15%가 상시로 붙는 게 맞는지). Phase B 밸런싱 대상 — 이번엔 지속·쿨만 만졌다.
- **분류\전파:** 전부 **수치 → tuning 로깅만**(전파 불요). 규칙·필드·enum 변경 없음. [[DRIFT-078]] §0 "밸런싱 스킵"의 예외 근거 = **"적 공격 주기보다 짧다"는 구조적 결함 해소**([[DRIFT-104]]에서 이미 구조 문제로 식별).
- **영향 파일:** `data/slice01/skillbooks.json`(AB-046/047/068 `duration_s`·`cooldown_s`).
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28).
- **상태:** ✅ **전파 완료**(spec `0944e6f`, `DEC-20260728-001`) — preset 3종 교체(구 ID Deprecated) + AB 문서 지속·쿨 갱신. **감소율 재검토는 spec TODO로 이월**. ⏳ F5 체감 대기.

### DRIFT-106 — 피해 감소 **지속형 오오라 VFX** 신설(`aura_field`/`clear_aura`) 🔶 impl (로깅만)
- **배경(2026-07-28, 사용자 지시):** *"수호를 키면 오오라가 지속시간 동안 나오도록 vfx를 추가해줘."* [[DRIFT-105]]로 지속이 6~10초가 됐는데 VFX는 시전 순간 1회 펄스(`sub_sanctuary`)뿐이라, **버프가 켜져 있는 대부분의 시간이 화면에서 비어 있었다** — [[DRIFT-103]] ①(지각 채널 부재)의 잔여분.
- **① `SkillVfx.aura_field(unit, radius, color, dur, key)` 신설:** 기존 VFX가 전부 **월드 좌표 1회성**인 것과 달리, **유닛의 자식으로 붙어 따라다니는 지속형**이다. 바닥 회전 링(TorusMesh, 6초 1회전) + 옅은 돔 + 0.9초 주기 맥동, 마지막 `AURA_FADE_S`(0.6s)에 페이드아웃 후 자기 소멸.
  - **`key` = 교체 식별자** — 재시전 시 같은 key의 기존 오오라를 먼저 제거해 링이 겹쳐 쌓이는 걸 막는다. `clear_aura(unit, key)`는 조기 해제용.
  - **부모 스케일 상쇄** — 파티원은 `_role_scale × CONTROLLED_SCALE`로 스케일이 붙어 있어 자식이 그대로 상속하면 반경이 어긋난다. `root.scale = 1/unit.scale`로 월드 반경을 params 값에 고정.
  - ⚠️ **트윈 함정 2건(구현 중 발견·수정):** ① `set_parallel(true)`는 "다음 tweener를 **직전 것과** 병렬"이라 `tween_interval` 뒤에 쓰면 페이드가 대기 없이 즉시 시작된다 → `parallel()`(다음 하나만) + `chain()`(앞의 전부 이후)로 명시. ② 무한 루프 맥동이 같은 `albedo_color:a`를 계속 덮어써 페이드를 무효화 → 페이드 직전 `pulse.kill()`.
- **② `sb_dr` 연결 — 오오라는 「캐스터의 반경」이 아니라 「버프받은 각 유닛」에 붙인다(설계 판단):** AB-047은 시전 **순간** 반경 안에 있던 대상에게 DR을 1회 부여할 뿐, "안에 서 있어야 유지되는 필드"가 아니다. 캐스터에 r4.0 링을 깔면 **규칙을 오독**하게 되므로(들어오면 걸리는 줄 앎), 각 대상 발밑에 개인 링(r 0.9)을 붙였다. 시전 순간 펄스(`sub_sanctuary`)는 그대로 두어 "시전 큐 → 지속 오오라" 2단으로 읽힌다. 색은 펄스와 같은 금색(0.97,0.86,0.35)이라 같은 효과로 묶여 보인다.
- **③ 반격(AB-048a/b)도 적용(사용자 지시, 동일 세션):** 자기 대상 스탠스라 캐스터 발밑 개인 링(r1.0). **주황**(1.0,0.50,0.20) = DR 금색과 구분되는 색 언어. **반격 상태는 `_reflect_*` 단일 슬롯**이라(동시에 두 반격이 켜질 수 없다) 오오라 key도 `"reflect"` 하나로 맞췄다 — 메커니즘과 표현의 슬롯 수가 일치.
  - **🦔 고슴도치 가시(사용자 제안):** `aura_field(..., spikes)` 옵션 신설 — 링 둘레 등간격으로 원뿔 8개를 **바깥+위(0.92:0.38)로 곤두세운다**. 링(root)의 자식이라 같이 돌고, 0.75초 주기로 미세하게 곤두섰다 눕는다(`bristle`). 원뿔 축이 +Y라 `look_at`(−Z 기준)이 아니라 **basis 직접 조립**(side/up/fwd)으로 방향을 잡았다. 페이드아웃 때 가시 머티리얼도 같이 사그라든다. → **"건드리면 아프다"를 형태로 말한다** — 반사는 경감이 아니라 되받아치기라는 규칙이 아이콘·숫자 없이 읽힌다. DR(부드러운 금색 링)과 실루엣부터 갈린다.
  - **조기 종료 동기화:** 타수형(048b)은 **창 시간이 남아도 타수가 먼저 소진**될 수 있다. `party_member._end_reflect()`가 `clear_aura(self, "reflect")`를 불러 **상태와 화면을 즉시 일치**시킨다(안 그러면 꺼진 버프의 오오라가 최대 6초까지 남는다). `party_member`에 `_SkillVfx` preload 추가.
- **적용 범위:** `skillbook_dr` 3종(AB-046 철벽 · AB-047 수호진 · AB-068 수호인) + `skillbook_reflect` 2종(AB-048a 반격 태세 · AB-048b 응수).
- **분류\전파:** 순수 표현 → **impl 로깅만**(전파 불요). 규칙·필드·enum 변경 없음.
- **영향 파일:** `scripts/combat/abilities/skill_vfx.gd`(`aura_field`/`clear_aura`/`AURA_FADE_S`) · `effects/sb_dr.gd`(대상별 호출) · `effects/sb_reflect.gd`(캐스터 호출) · `scripts/party/party_member.gd`(`_end_reflect` → `clear_aura`) · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 **수명 검증 7건** 신설: 생성 · 같은 key 재시전 시 교체(중복 없음) · **지속 종료 후 자기 소멸** · `clear_aura` 즉시 제거 · **반격 오오라 부착** · **가시 8개 생성** · **타수 소진 시 즉시 제거(창 시간 남아도)**. (VFX는 게이트가 컴파일까지만 보증하므로 노드 수명을 별도로 잠갔다. 카운트는 `meta("aura_key")` 기준 — `party_member`는 `_ready`에서 체력바 등 자식을 만들어 `child_count`로는 못 센다.)
- **상태:** LOGGED (순수 표현 — 전파 불요). ⏳ F5 체감 대기.

### DRIFT-107 — T3 재정의: AB-033 실드 → **전방위 돔 방벽** · 엄폐 레이어 신설 · 방벽 VFX 차단 버그 수정 🔶 rule/scope/schema (전파 후보) + 🐞 bugfix
- **배경(2026-07-28, 사용자 판정):** *"T3는 동일 클러스터라고 보기 어렵다 — 34는 물리 오브젝트를 소환하고 33은 보호막인데, **보호막은 Healer 쪽(AB-075)이 소화하니 33은 구현이 잘못된 것**"*. [[DRIFT-102]] T2에서 T3를 "보호막·방벽"으로 묶어 뒀지만 실제로는 **이질적인 두 계통을 억지로 붙여 둔 것**이었다. 재정의 후 T3는 처음으로 **동질 클러스터(물리 방벽 2종)** 가 됐다.
- **① AB-033 재정의(scope/schema):** `skillbook_shield`(광역 흡수 버프 0.10/2.0s) → **`skillbook_barrier` + `shape: "dome"`**. 시전자 중심 **반구 r3.0 · HP 90 · 5.0s · cd 14**. AB-034(벽)과 **3겹으로 분화**: 형상(벽↔돔) · 커버(단일 방향↔전방위) · 차단축(이동+투사체↔**투사체만**). Healer 실드(AB-075 흡수 버프)와는 계통 자체가 다르다.
- **② 엄폐 레이어 `LAYER_COVER`(8) 신설(schema):** 돔을 world(1)에 올리면 유닛 `collision_mask`가 1을 포함해 **시전자가 자기 돔에 갇힌다.** 전용 레이어로 분리하고 **투사체 레이캐스트 2곳**(`ability_dispatch._projectile_mask` · `enemy_ai._shot_blocked`)에만 비트를 더했다. 유닛 이동 마스크는 불변 → 돔은 이동을 통과시킨다. 실증(임시 스크립트): 마스크 `1|8` 레이는 돔 표면 (2.891, 0.8, 0)에 적중, 마스크 `1`은 통과.
- **③ 완전 포함 판정(rule — 사용자 확정):** *"아군이 보호막에 걸쳐 있는 경우는 데미지 판정. 완전히 감싸인 경우만 무데미지."* 반구는 반지름 `r`·높이 `r`이라 수평거리 `d`의 천장 = `√(r²−d²)` → **`covers_point`: `(d + unit_r)² + unit_h² ≤ r²`**. 히트박스 분할 대신 **수식 1회 계산**을 택했다(피격당 거리 계산 1회, 추가 물리 쿼리 0). 이 규칙이면 *"보호 범위 내에서는 아군 키를 넘는다"* 요구가 **정의상 자동 만족**된다. 실측 r3.0·유닛(0.40/1.60) → **완전 보호 반경 2.14m**(2.14~3.00m = 걸침 구간, 피해 그대로). 외곽과 안전 반경이 달라 **바닥 안전 반경 링**을 그린다. 판정은 `_shot_blocked`·`projectile` 두 경로 모두에 적용. 벽은 방향성 엄폐라 `covers_point`가 항상 true(기하가 판정).
- **④ 🐞 반구 형상 버그:** `SphereMesh.is_hemisphere`에서 `height`는 **보이는 높이**다. `r*2`를 줘 반경 3m에 높이 6m로 **수직으로만 두 배 솟아** 있었다 → `height = radius`로 교정.
- **⑤ 🐞 방벽 VFX가 그대로 통과하던 문제(사용자 제보):** `_deliver_enemy_hit`가 **VFX를 무조건 먼저 발사**하고 차단 검사는 도착 후 `_apply_enemy_hit`에서 했다 → **피해는 막히는데 오브만 벽/돔을 뚫고 대상까지 날아갔다**("막히는지 모르겠다"의 원인 — 막히긴 했는데 화면이 아무 말도 안 했다). **차단 판정을 배달 시점으로 이동**: `_shot_blocked`(bool) → **`_shot_block_point`**(막힌 좌표 or null), `SkillVfx.enemy_vfx(..., stop_at)` 신설(호밍 해제 + 지점 비행), 막히면 피해 예약 자체를 취소. **`_apply_enemy_hit`의 중복 검사 제거** — 두 곳에서 검사하면 `absorb_projectile`이 2회 호출돼 **방벽이 발당 20씩** 닳는다(돔 90 HP가 9발이 아니라 4.5발). 소각 섬광도 오브젝트 중심 → **피격 지점**으로(돔은 반경이 커서 중심 섬광이 안 읽혔다).
- **⑥ 적 반응 확인(사용자 질의 — 미변경, 기록):** `LOS_MASK`는 **world(1)뿐**이다. → **벽(레이어 1) = LOS 차단** → 사격 게이트(`has_los and dist <= attack_range_m`)가 안 열려 **발사 자체를 안 하고 네비메시로 우회**(`CHASE_BLIND_SPEED_FRAC` 감속); 캐스트 중 벽이 서면 착탄 직전 재검사에서 불발. **돔(레이어 8) = LOS 비차단** → 적이 **계속 사격**하고 표면에서 흡수된다. **이 분리는 의도** — 돔도 LOS를 끊으면 적이 우회해 버려 HP 90이 죽은 숫자가 된다. 역할이 갈린다: **벽 = 시간 벌기 / 돔 = 피해 대신 받기.**
- **⑦ 근접 적의 방벽 공격 = 미구현 확정(사용자 판정):** 전투 모델이 target-locked라 근접 피해가 월드 지오메트리로 라우팅되지 않는다(`rampart_barrier` 헤더가 "DEFERRED"로 명시). 방벽 HP를 깎는 건 **투사체 흡수뿐**. 사용자: *"경로가 막히지 않는 한 굳이 공격할 필요는 없다"* → 구현하지 않는다.
- **분류\전파:** **`shape: dome` + `LAYER_COVER` + `covers_point` 완전 포함 규칙 + AB-033 kind 전환** = rule/scope/schema → **OPS_30 전파 후보**([[DRIFT-104]] 등과 다음 패킷). ④⑤ = **버그 수정**(전파 불요). ⑥⑦ = 현황 기록. 수치(r3.0·HP90·5.0s·cd14) = tuning 로깅만.
- **영향 파일:** `data/slice01/{skillbooks,display_names}.json` · `scripts/world/objects/rampart_barrier.gd`(dome/`covers_point`/`safe_radius`/안전링/피격지점 섬광) · `scripts/combat/abilities/{ability_dispatch,projectile,skill_vfx}.gd` · `scripts/combat/abilities/effects/sb_barrier.gd` · `scripts/combat/enemy_ai.gd`(`_shot_block_point`·배달 시점 차단·중복 제거) · `scripts/ui/skill_text.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 **T3 검증 14건**: kind/shape/실드 잔재/벽=wall/돔HP<<벽HP · 레이어 분리 2건 · 커버리지 6건(중심·안전반경 경계 안팎·돔 밖·벽 always-true) · 9발 파괴. ⚠️ 물리 space query 검증은 `--script` 런에서 콜리전 등록 타이밍이 불안정해(process_frame 미등록 / physics_frame 무한대기) **넣지 않았다** — 별도 임시 스크립트로 수동 실증 후 결과를 주석에 남겼다.
- **상태:** LOGGED (게임측 확정 · F5 체감 확인 완료). 전파 = 사용자 판단 대기. 돔 반경 3.0(안전 2.14m)이 좁으면 **반경 상향이 가장 직접적인 레버**(3.5 → 2.7m) — Phase B.

### DRIFT-108 — T4 도발 재정의: AB-051 견인→도발(Tank 전용) · AB-035 광역+2.5s 캐스트 · 밴드=레퍼런스 격하 🔶 rule/scope/schema (전파 후보) + 🐞 bugfix
- **배경(2026-07-28, 사용자 판정):** *"51도 35처럼 도발로 하고, 긴 범위를 갖는 대신 단일 도발로 하자. 탱커만 쓸 수 있게."* → 구현 중 **`sb_taunt`이 원래부터 단일 대상**(첫 적을 잡고 `break`, 주석도 "single-target mark")임이 드러나 그대로 두면 AB-035와 **숫자 두 개만 다른 중복**이 됐다. 보고 후 사용자 확정: *"ab35는 범위 내 전체 도발로 하고 대신 캐스팅을 조금 넣자 2.5초 정도"*.
- **① AB-051 재정의(scope/schema):** `skillbook_pull`(견인 5.0m + threat 60) → **`skillbook_taunt`**. **Tank 전용**(`equip_classes` [Tank,DPS]→[Tank], `sub_bands` 제거). **단일** 대상 · `range_m` **10.5**(최장) · `mark_threat 90`/`floor 35` · 즉발. 고아가 된 **`sb_pull.gd` 삭제** + dispatch preload·`aim_controller` UNIT_AIM·`display_names`(skill_desc/effect_kinds) 정리 → **`skillbook_pull` kind 소멸**.
- **② AB-035 광역화(rule/schema):** `taunt_all: true` 신설 — 반경 안 **전체** 도발. **광역의 대가로 `cast_s 2.5`**(커밋). `radius_m` 2.0→**4.0**(2m 광역은 사실상 단일이라 이름값이 안 섰다), `range_m` 10→**5.0**.
  - **차이축 4겹 확정:** 대상(광역↔단일) · 시전(2.5s 커밋↔즉발) · 사거리(5.0↔10.5) · 위협(120/50↔90/35). *"붙어서 무리째"* ↔ *"떨어져서 하나만"*.
  - **조준 표시:** 같은 kind라 035도 단일 커서로만 떴다 → `aim_controller`가 `taunt_all`이면 **반경 원판**을 그리게 수정(4m 광역인데 범위를 못 읽는 문제).
- **③ 🐞 도발이 비전투(dormant) 적을 끌어오지 못하던 버그(사용자 제보):** `enemy_unit.add_threat`는 **위협 수치만 쓰고 `engaged`를 안 건드린다.** 교전 진입 경로는 `perceive_attacker`(피격)·`_engage_enemy`(지각) 둘뿐인데 **도발은 피해가 0이라 어느 쪽도 안 탄다** → dormant 적이 위협 90을 받고도 계속 잤다. 최대 사거리에서 특히 드러났다(가까우면 시야로 스스로 깨서 가려졌다). → `sb_taunt._force_engage`가 **직접 끌어낸다**(`perceive_attacker` + `returning=false`). `search_pos`가 시전자로 잡혀 **LOS 없어도 걸어온다.** 광역은 반경 내 **전원**에 적용.
  - **분대 전파는 의도적으로 미사용:** `combat_controller._engage_enemy`엔 반경 내 같은 분대를 함께 깨우는 경로가 있으나 쓰지 않는다 → 도발이 **"자는 무리에서 원하는 놈만 떼어오는" 풀링 도구**가 된다. 광역(035)도 **반경 4.0m 안만** 깨운다(밖까지 연쇄하면 "광역 4m"라는 약속이 깨진다).
- **④ 밴드 = 레퍼런스로 격하(rule — 사용자 확정):** *"밴드는 레퍼런스로 하고, 각 스킬 하나하나를 거기에 꼭 맞출 필요는 없는 선택사항으로 둬."* → [[DRIFT-078]] §1 시전 티어 밴드표(A 0~0.4 / B 3~5 / C 8~15)는 **"이 길이면 대충 이런 역할"을 잡아 주는 참조 척도**이지 스킬을 끼워 맞춰야 하는 규격이 아니다. **밴드 사이 값이면 그 값 그대로 둔다** — 맞추려고 스킬을 비트는 순간 척도가 목적이 된다. 선례: `AB-013` **1.0s**(커밋 다이브) · `AB-035` **2.5s**. §5 표의 `밴드` 칸도 밴드 밖이면 **실제 `cast_s`를 그대로** 적는다.
- **분류\전파:** **`skillbook_pull` kind 소멸 + AB-051 kind/클래스 전환 + `taunt_all` 필드 + 도발의 교전 강제 규칙 + 밴드=레퍼런스 규칙** = rule/scope/schema → **OPS_30 전파 후보**([[DRIFT-107]]과 다음 패킷). ③ = **버그 수정**(전파 불요). 사거리·위협·캐스트 수치 = tuning 로깅만(사용자 지시로 사거리 1/2·2/3 축소).
- **영향 파일:** `data/slice01/{skillbooks,display_names}.json` · `scripts/combat/abilities/effects/sb_taunt.gd`(광역 분기·`_force_engage`) · `effects/sb_pull.gd`(삭제) · `ability_dispatch.gd` · `scripts/run/controllers/aim_controller.gd` · `scripts/ui/skill_text.gd` · `tools/party_pool_smoke.gd` · `docs/_WIP_casting_expansion_pass.md`(§1 밴드 격하 · §2.1 축3 · §5 범례 · T4/T4b).
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 **T4 검증 13건**: kind 전환·pull 잔재 0·Tank 전용·sub_bands 소멸·사거리/위협 대소·`taunt_all`·`cast_s 2.5`·051 단일/즉발·반경 대소 + **교전 강제 5건**(`add_threat`만으론 교전 안 됨(원인) → 도발 후 engaged·귀환취소·수색·최고위협 타겟).
- **상태:** LOGGED (게임측 확정). 전파 = 사용자 판단 대기. ⏳ F5 체감 대기(광역 도발 2.5s 커밋이 실전에서 버틸 만한지).

### DRIFT-109 — T4b 이동 CC 정리: AB-050 폐기 · AB-102 → **DPS 「뭉치기+속박」 콤보 셋업** 이관 · Rooted ccTenacity 수정 🔶 rule/scope/schema (전파 후보) + 🐞 bugfix
- **배경(2026-07-28, 사용자 제기):** *"이 게임이 액션성을 강조하진 않아서 이동 관련 CC가 플레이테스트상 큰 의미가 있어 보이지 않는다."* → **런 전수 실측**으로 검증: 인카운터 26개 × 적 스폰 97기를 `engage` 프로필별로 집계.
  | 프로필 | 스폰 | 비율 |
  |---|---|---|
  | **advance**(도달 후 정지) | 70 | **72%** |
  | standoff(사거리 유지) | 11 | 11% |
  | **orbit + kite**(계속 이동) | **9** | **9%** |
  | probe·healer·zone | 7 | 8% |
  - 이동형이 1기라도 나오는 ENC = **8/26**, 그마저 대부분 1기. **결정적 사실:** `Rooted`/`Pinned`는 **이동만 잠그고 행동은 허용**한다([outcome_status.gd](../scripts/combat/outcome_status.gd) 주석) → **이미 붙은 적에게 걸면 효과가 정확히 0.** 진단은 *"액션성 부재"* 가 아니라 **"표적이 9%로 좁은데 그 유효 조건이 스킬 어디에도 안 적혀 있다"**([[DRIFT-103]] DR과 같은 구조 — 기능이 아니라 가시성).
- **① AB-050 Warding Shout 폐기(scope):** 근접(72%)은 붙으면 정지하니 둔화의 실효가 *"도착 1~2초 지연"* 뿐이고, 정작 카이터·다이버는 60° 부채꼴에 잘 안 들어온다. `threat 30`은 [[DRIFT-108]] 도발 2종이 이미 위협 축을 가져가 중복. **Ally-only라 적측 대칭 처리 불요.** 고아 `sb_slow.gd` 삭제 → **`skillbook_slow` kind 소멸**.
- **② AB-102 = 폐기 대신 재정의 + DPS 이관(scope/schema — 사용자안):** *"차라리 마법사인 딜러에게 주고, 원거리에서 광역으로 속박 + 한곳으로 뭉치기 효과를 넣어서 다음 DPS 광역스킬을 쉽게 맞출 수 있는 콤보 기술로."* → **Tank → DPS 주력 전용**(Nuker 미부여, 사용자 확정). `gather_m` 신설(중심으로 끌어모으기 — 폐기된 `sb_pull`의 `apply_knockback(중심−대상)` 기법을 `sb_root`로 되살림). `range_m` 11→**14** · `radius_m` 2.5→**3.5** · `cast_s` **1.0** 신설 · `cd` 9→**16**. **표적 빈도가 아니라 자기 광역기와의 연결이 존재 이유**가 되므로 9% 문제가 소멸한다.
  - **⚠️ 콤보 성립 조건(실사로 확정한 수치):** DPS 주력 광역기 최장 캐스트 = **AB-041 3.5s**(053/008/003 = 3.0s) + 투사체 비행 0.4s → **`root_s` 2.0→4.0.** 종전 값으론 광역기 캐스트가 끝나기 전에 속박이 풀려 **콤보가 물리적으로 성립하지 않았다.** 스모크가 이 부등식(`root_s ≥ max(DPS 주력 광역기 cast_s) + 0.4`)을 **런타임 계산으로 잠근다** — 나중에 광역기 캐스트를 늘리면 게이트가 먼저 깨진다.
  - **순서 규약:** 뭉치기 → 속박. 반대면 `Rooted`(MOVE_MULT 0)가 이동을 잠가 **끌려오지 않는다**. 아군·적 양쪽 구현 모두 이 순서.
- **③ 적측 대칭(사용자 승인):** `EN-3RD-02` Snarer도 동형 — **파티를 한곳으로 끌어모은 뒤 전원 속박**(`enemy_root` 분기에 `radius_m`/`gather_m` 반영). 적 입장에서도 자기 광역기 셋업이라 *"뭉치기 = 콤보 셋업"* 이라는 언어가 양 진영에서 같은 의미를 갖는다. `telegraph_s` 0.5→**1.0**(강해진 만큼 읽을 시간).
- **④ 🐞 `Rooted`가 `ccTenacity`를 무시하던 드리프트:** `apply_stun`/`apply_silence`는 `duration / cc_tenacity`로 저항을 받는데 **`apply_outcome` 경로만 빠져** 있었다. spec `EFFECT-CORE`는 *"CC `duration_s`는 base이며 대상 `ccTenacity`로 최종 지속이 스케일된다"* 로 못박고 있으므로 **spec 위반**. 2초일 땐 가려졌지만 **4초 광역 하드 CC**가 되면 미니보스를 통째로 묶는다 → `enemy_unit.apply_outcome`에 `CC_TENACITY_OUTCOMES`(`Rooted`/`Pinned`) 스케일 적용. **soft 아웃컴**(Chilled/Sodden 등)은 지속 그대로.
- **⑤ 조준 표시:** `skillbook_root`를 `UNIT_AIM_KINDS`에서 제외 — 반경 3.5m 광역인데 단일 커서로 뜨면 범위를 못 읽는다([[DRIFT-108]] `taunt_all`과 같은 성격의 수정).
- **결과 — Tank 블록 완결:** 12→**10종**(050 폐기·102 이관), **✅10 / ⬜0**. 전수 57→**56종**, 완료 27→**28** / 미완료 30→**28**. AB-102는 D 블록 신규 클러스터 **D6 군집 제어**로 이동.
- **분류\전파:** **`skillbook_slow` kind 소멸 · AB-102 클래스/kind 파라미터 전환 · `gather_m` 필드 · 뭉치기→속박 순서 규약** = rule/scope/schema → **OPS_30 전파 후보**([[DRIFT-107]]·[[DRIFT-108]]과 다음 패킷). ④ = **spec 위반 수정**(전파 시 `EFFECT-CORE` 규약 재확인). 수치 = tuning 로깅만.
- **영향 파일:** `data/slice01/{skillbooks,abilities,display_names}.json` · `scripts/combat/abilities/effects/sb_root.gd`(뭉치기) · `effects/sb_slow.gd`(삭제) · `ability_dispatch.gd` · `scripts/combat/enemy_ai.gd`(enemy_root 뭉치기) · `scripts/combat/enemy_unit.gd`(ccTenacity) · `scripts/run/controllers/aim_controller.gd` · `scripts/ui/skill_text.gd` · `tools/party_pool_smoke.gd` · WIP(T4b·D6).
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 **T4b 검증 8건**: AB-050 폐기 · AB-102 DPS 전용/sub_bands 0 · `gather_m>0` · **콤보 부등식 자동 검증** · `Rooted` ccTenacity(4.0→2.0) · soft 아웃컴 불변.
- **상태:** LOGGED (게임측 확정). 전파 = 사용자 판단 대기. ⏳ F5 체감 대기(뭉치기가 실제로 광역기를 맞히게 해주는지 · 적 Snarer의 파티 뭉치기 압박이 적정한지).

### DRIFT-110 — D1: AB-055 「산탄」 재구현(부채꼴 파편 + 데드존) · 전격 볼트 착탄 전기장 VFX 🔶 scope/schema (전파 후보) + impl
- **배경(2026-07-28, 사용자 판정):** D 블록(DPS) 진입. ① *"AB-003은 착탄 후 범위 내에 전기가 흐르는 효과를 VFX로 추가"* ② *"AB-055는 지금 효과가 잘못됐다 — 이름처럼 산탄으로, 착탄 지역에서 투사체 6개를 방사형으로 재생성하고 각 투사체도 충돌하면 좁은 범위 딜"*.
- **① AB-055 재구현(scope/schema):** 종전 AB-055는 **AB-008(볼트 원형)의 즉발·무속성 판**(반경만 +0.6)이라 이름값과 동작이 따로 놀았다 — D1 중복 실사에서 지적했던 그 항목. → **초탄 + 부채꼴 파편**으로 재정의.
  - 신규 params: **`scatter_pellets`**(6) · **`scatter_cone_deg`**(70) · **`scatter_range_m`**(8.0) · **`scatter_radius_m`**(0.6) · **`scatter_damage_mult`**(0.35) · **`scatter_speed_mps`**(24) · **`scatter_deadzone_m`**(1.2) · **`scatter_hit_radius_m`**(0.55).
  - **반경 서열이 설계 축:** 원형 `AB-008`(2.0) > **초탄**(1.5) > **파편**(0.6). 사용자 지시 *"초탄도 08보다는 작게, 산탄은 그보다 훨씬 적게"*.
  - **확산은 부채꼴** — 처음 360° 방사로 만들었다가 *"조금 더 산탄총처럼"*(사용자)으로 **탄이 날아가던 방향(캐스터→착탄점) 기준 70° 원뿔**로 교체. 파편은 그 안에 균등 배치 + 미세 지터.
  - **`cast_s 3.5`**(원형 3.0보다 길게) · `cd` 4→6 → 총 주기 9.5s(원형 8.0s). **§0 딜 원칙(긴 캐스트 + 긴 쿨 + 큰 한방)에 합류** — D1 미완료 4종이 전부 즉발이던 상태에서 하나가 빠져나왔다. 초탄 dmg 1.2→**0.8**(파편이 더해지므로).
  - **파편은 같은 이펙트를 재귀 사용**(`sb_bolt.resolve_at`)하고 **`_pellet` 플래그로 재귀 차단** — 없으면 파편이 또 산탄을 낳아 무한 증식한다.
- **② 데드존(설계의 핵심):** 파편이 착탄점에서 태어나므로 거기 적이 서 있으면 **6발이 그 자리에서 동시 폭발**해 피해가 몰린다(사용자 제보). 파편에 **무장 거리**(초탄 반경 + `scatter_deadzone_m` = 2.7m)를 줘 퍼진 뒤에야 터진다. 조준 마커도 **원판 → 빈 공간 → 부채꼴 띠** 3단으로 그려 화면과 실제가 일치한다. 구현 상세·함정은 [[IMPL-DEC-20260728-002]].
- **③ 전격 볼트 착탄 전기장(impl · VFX):** `SkillVfx.arc_field` 신설 — 착탄 후 `radius_m` 안에서 지그재그 아크가 3묶음 시차로 튀고 0.8s에 잦아든다. **`element == lightning`으로 갈리고 크기는 `radius_m` 그대로**라 per-AB 분기 없이 **볼트마다 자기 반경이 그려진다**(003 r4.0 최대 · 004/073 r1.2~1.4 최소). 원형-변형 조립 방식([[DRIFT-085]] ⑤)과 동형. **AB-003 전용 게이트는 두지 않는다**(사용자 확인) — 덤으로 AB-003의 r4.0이 볼트 중 최대라는 사실이 화면에서 처음 보인다(D1/N2 판정 재료).
- **분류\전파:** **`scatter_*` 8필드 + AB-055 재정의** = scope/schema → **OPS_30 전파 후보**([[DRIFT-107]]·[[DRIFT-108]]·[[DRIFT-109]]와 다음 패킷). 투사체 능력(origin·`arm_after_m`·`hit_radius_m`)·조준 마커·`arc_field` = **impl**([[IMPL-DEC-20260728-002]], 전파 불요). 수치 = tuning 로깅만.
- **영향 파일:** `data/slice01/skillbooks.json` · `scripts/combat/abilities/{skill_vfx,projectile,ability_dispatch,cast_context}.gd` · `effects/sb_bolt.gd` · `scripts/ui/{aim_marker,skill_text}.gd` · `scripts/run/controllers/aim_controller.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 **D1 검증 10건**: 산탄 구조·반경 서열(원형>초탄>파편)·도달>착탄·데드존(초탄보다 큼·도달보다 작아 띠 성립)·부채꼴(<360)·재귀 가드 존재·캐스트 서열(≥원형·총주기>원형).
- **상태:** LOGGED (게임측 확정 · F5 체감 확인 완료). 전파 = 사용자 판단 대기. **D1 = ✅3 / ⬜1**(AB-058† 무주력 처리만 남음).

### DRIFT-111 — D1+D2 병합: 볼트 단일 클러스터화 · `skillbook_fire`/`cold` kind 소멸 · 중복 4종 폐기 · AB-008 무속성 원형 복귀 🔶 rule/scope/schema (전파 후보)
- **배경(2026-07-28, 사용자 판정):** [[DRIFT-110]] 직후 *"D1, D2 자체를 하나의 클러스터로 묶고 중복을 제거하자."* → 두 클러스터를 합치자 **§5.2.1이 지적하던 "D1에 fire·cold 없음"이 클러스터 경계 때문에 생긴 착시**였음이 드러났다(D2에 이미 둘 다 있었다). 경계를 지우니 공백이 사라지고 **진짜 중복이 드러났다.**
- **⚠️ 실패 기록(방법론 교훈):** 병합 직전 *"D1에 다른 element 추가가 필요"* 판단으로 **AB-107 화염탄·AB-108 서리탄을 신설**(ID 발급·`id_registry` 등재까지 완료)했다가, **병합 즉시 AB-053·AB-041과 완전 중복이 되어 폐기**했다. 만들어 보고 나서야 문제가 **스킬 부족이 아니라 클러스터 경계**임이 드러난 사례. → **부족해 보이면 먼저 옆 클러스터를 의심할 것.** 이 패스가 「유사도 × 주력」으로 클러스터를 재정의([[DRIFT-101]])한 이유와 같은 교훈이 한 층 더 적용된다.
- **① 중복 4종 폐기(scope):** ~~`AB-037` Ember Lance~~(`AB-053`의 **즉발 쌍둥이** — §0 딜 원칙 "긴 캐스트+긴 쿨" 위반) · ~~`AB-072` 우박 세례~~(`AB-041`의 즉발 쌍둥이) · ~~`AB-107`~~·~~`AB-108`~~(신설 즉시 철회). **넷 다 Ally-only**라 [[DRIFT-101]] ② Shared 폐기 대칭 규칙은 해당 없음. ID는 `id_registry` 등록만 잔존.
- **② `skillbook_fire`·`skillbook_cold` kind 소멸(schema):** 세 이펙트(`sb_bolt`/`sb_fire`/`sb_cold`)의 `resolve_at`을 나란히 놓으니 **구조가 동일**했다 — 피해(radius) → `ctx.element_hit(element)` → VFX. **[[DRIFT-088]]로 `element`가 SSOT가 된 순간 속성별 kind는 존재 이유를 잃었는데** 그대로 남아 있었다. `AB-053`·`AB-041`을 **`skillbook_bolt`로 이관**하고 `sb_fire.gd`·`sb_cold.gd` 삭제.
  - **동작 흡수:** `sb_fire`에만 있던 **배럴 파괴**(`ctx.damage_destructibles`)를 `sb_bolt`가 흡수 → **모든 볼트가 배럴을 깬다**(전엔 화염만 — 그 자체가 비대칭이었다). 놓쳤으면 조용히 사라졌을 동작.
  - **툴팁:** 볼트 문장 하나 + **`element`별 후미 조립**(전격=감전 / 화염=가연물 점화 / 냉기=둔화·결빙 / 맹독=독 누적). [[DRIFT-085]] ⑤ 조립 방식의 확장.
- **③ AB-008 무속성 원형 복귀(scope — 사용자 지시):** `element: "slag"` 제거(아군·적 unified 양쪽). 이제 **원형은 무속성이고 속성은 전부 변형이 진다** — 전엔 원형이 `slag`(elements.gd "의도된 무반응")를 들고 있어 *"원형을 배우면 반응계도 같이 배운다"* 가 성립하지 않았다([[DRIFT-085]] ⑤의 미해결분). 부수: **`slag` 속성 사용처 0.**
- **④ AB-058 무주력 해소(scope — 사용자 지시):** `sub_bands`에서 Nuker 제거 → **주력 = Nuker**(sub = DPS B1). [[DRIFT-102]]에서 "전수 유일 무주력 서브"로 표기했던 항목 해소 → **무주력 서브 0.** 클러스터도 D1 → **N2**로 이관.
- **결과:** 전수 **58→54종**(폐기 4). D1 = **6종 전부 ✅**(008 원형·003 lightning·053 fire·041† cold·010 poison·055 산탄) — **클러스터 내부 실중복 0.** RX 속성 커버 = fire·cold·lightning·poison **전부**(공백 해소). **DPS 블록 ✅8/⬜2**(D4 지역강타·D5 빔만 남음).
- **분류\전파:** **kind 2종 소멸 + AB-053/041 kind 이관 + AB-008 element 제거 + AB-058 주력 확정 + 4종 폐기** = rule/scope/schema → **OPS_30 전파 후보**([[DRIFT-107]]·[[DRIFT-108]]·[[DRIFT-109]]·[[DRIFT-110]]과 한 패킷). 배럴 파괴 확대·툴팁 조립 = impl.
- **영향 파일:** `data/slice01/{skillbooks,abilities,display_names,id_registry,enemies}.json` · `scripts/combat/abilities/effects/{sb_bolt,sb_fire(삭제),sb_cold(삭제)}.gd` · `ability_dispatch.gd` · `scripts/ui/skill_text.gd` · `scripts/run/dungeon_run.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 병합 검증: 폐기 4종 · 053/041 kind 이관 · **`skillbook_fire`/`cold` kind 소멸** · 볼트 계열 속성 전수 스캔(fire·cold·lightning 커버 · slag 소멸) · AB-008 무속성 · AB-058 주력.
- **상태:** LOGGED (게임측 확정). 전파 = 사용자 판단 대기.

### DRIFT-112 — 매질 생성 스킬 5종 폐기 → **소모품(매질 플라스크) 이관** · 적측 `enemy_only` 존치 · 가시덩굴 이동피해 신설 🔶 rule/scope/schema (전파 후보)
- **배경(2026-07-28, 사용자 판정):** *"D3에서 매질을 까는 건 그냥 스킬로는 다 빼고 차라리 소모품으로 관리하는 건 어떨까"* → 실사 후 *"스킬 하나가 그냥 **셋업으로만** 쓰이는 건 별로"* 로 사유가 확정됐다. **셋업 전용 슬롯을 없애는 것**이 목적이고, 매질 공급은 다른 축으로 옮긴다.
- **⚠️ 선행 실사 — 그냥 빼면 RX가 죽는다:** 매질 **1차 공급처가 사실상 스킬뿐**이었다. 맵은 매질을 깔지 않고(`map_demo_layout._carve_zone`는 **navmesh 파내기**이지 매질 배치가 아니다), **RX 산출물(Fire·Steam·Water)은 전부 2차**라 1차 매질이 없으면 나오지 않는다. 스킬만 빼면 1차 공급이 **배럴 Oil 하나**로 붕괴 → `surface_grid`·`reaction_system` 투자가 논다. **대체 공급(소모품)을 같이 세우는 것이 전제**였다.
- **① 아군 스킬 5종 폐기(scope):** ~~`AB-009` Oil~~ · ~~`AB-036` Water~~ · ~~`AB-040` Ice~~ · ~~`AB-042` Wind~~ · ~~`AB-043` Vegetation~~. **`skillbook_zone` kind 소멸**(`sb_zone.gd` 삭제). 전수 54→**49종**. §5.2.1이 지적하던 **"장판은 사실상 Healer 킷인데 힐러 정체성과 무관"** + **"medium 문자열만 다른 중복 4종"** 이 한 번에 해소(Healer 18→14종).
  - ⚠️ 폐기분엔 완료 판정 2건이 포함된다 — `AB-009`(DPS 초월 결속 safeslick) · `AB-042`(rect 복도 + `apply_drift`, [[DRIFT-098]] 전체). 결속·`apply_drift` 코드는 **남는다**(다른 쓰임 있음).
- **② 매질 플라스크 5종 신설(schema):** `consumables.json`에 **`effect: "spawn_medium"`** + `medium`/`radius_m`/`ttl_s`/`range_m`. `con_oil_flask`·`con_water_flask`·`con_frost_flask`·`con_gust_flask`·`con_briar_flask`. 전투 중 사용 가능(RX 셋업이 전투 행위). `id_registry.consumable_ids` 등재.
  - **`MediumConsumableController` 신설** — `ReviveController`와 같은 모달 계약(`is_active`/`cancel`/`handle_click`). Z/X/C 핫키·인벤 우클릭 양쪽 진입, 지면 조준 → 좌클릭 확정 / 우클릭 취소.
  - **사거리 규약 = 스킬과 동일**(사용자 판정: *"일관된 경험이 더 중요"*): 사거리 밖이면 **navmesh로 걸어가 사거리를 맞춘 뒤 던진다**(`AimController._confirm_cast` 규약). 초안은 "던지는 것이니 거부"였으나 **같은 조작에 다른 결과가 나오면 학습이 깨진다**는 이유로 뒤집혔다.
  - **소모 시점 = 투척 시점**(조준/오더 시점 아님) — 걸어가다 취소·소진돼도 차감되지 않는다.
- **③ 적측은 `enemy_only`로 존치(rule 예외 — 사용자 판정):** 5종 전부 Shared였다(EN-004: 009·042 / EN-007: 036·040·043). **적 능력만 남기고 `abilities.json`에 `enemy_only: true`** 표기. [[DRIFT-101]] ② *"Shared 폐기 시 적측도 교체"* 의 **명시적 예외** — 진영별 분기가 아니라 **아군이 다른 시스템(소모품)으로 같은 일을 하게 된 것**이고, 무엇보다 **적이 깐 매질이 플레이어의 RX 재료**가 되므로 존치가 이득이다(적이 깐 기름에 내가 불을 붙이는 그림).
- **④ 가시덩굴(Vegetation) 이동 피해 신설(rule — 사용자 지시):** 종전 Vegetation은 `"Smoke", "Vegetation": pass  # harmless — flammable only`로 **자체 효과가 0**이었다. 이름값대로 **이동 거리 비례 피해** 부여: `THORN_DMG_PER_M 3.0` · `THORN_MIN_MOVE_M 0.05`(부동 시 무피해). **틱 상한 없음 — 선형**(사용자 확정): 초안엔 폭주 차단용 상한(6.0)을 뒀으나 *"가시덩굴을 깔아 **돌진을 방지**하거나 **넉백으로 추가 딜**을 넣는 식이 오히려 더 좋은 창의성을 준다"* 로 제거. 상한을 두면 **"많이 움직이면 손해"라는 규칙 자체가 무뎌진다.** 폭주 우려는 구조가 이미 막는다 — 틱은 "지금 존 안에 있는 유닛"만 돌고 나가는 순간 exit 엣지가 위치 추적을 지우므로, **밖으로 블링크한 거리는 계산되지 않는다**(안에서 움직인 만큼만 아프다).
  - **"서 있으면 안 아프고 움직이면 아프다"** — 다른 매질(체류 dps · 상태 부여)과 **축이 겹치지 않는** 유일한 규칙이 된다. 존을 나가면 위치 추적 리셋(재진입 첫 틱 무피해).
  - **표현(사용자 지시):** 이름값대로 **하얀 작은 가시가 촘촘히 돋은 바닥** — `MultiMesh` 1개로 1m²당 26개(상한 420)를 한 드로콜에 그린다. 원 분포는 `sqrt` 보정(안 하면 중심에 몰린다), 각 가시는 회전·기울기·크기를 무작위(똑바로만 서 있으면 인공적). 매질 필드(셀 CA coverage plane)는 **색만** 칠하므로 형태는 이 장식 레이어가 준다. ⚠️ 존 노드 기준이라 **바람으로 번진 셀까지는 따라가지 않는다**(Vegetation은 자체 확산이 없어 실사용 대부분 일치 — 표현 한계로 기록).
  - **피해 표기(사용자 지시):** *"다른 DoT 장판처럼 옆에 데미지 표기"* → 매질 틱(0.2s)마다 띄우면 시끄러우므로 **`OutcomeStatus.DOT_TICK_S`와 같은 0.5s 리듬**으로 모아서 한 번에 올린다(`thorn_popup`). 누적·플러시 규칙도 `HazardZone` 한 곳이 SSOT.
  - 식은 **`HazardZone.thorn_damage()` 한 곳이 SSOT** — 원 모델(`hazard_zone`)·셀 CA(`surface_grid`, `USE_SURFACE_GRID=true`로 현재 권위) **두 경로가 같은 static을 호출**한다. 복제했으면 두 모델이 조용히 갈라졌을 것.
- **⑤ 후속(사용자 확정):** 매질을 **스킬 결과물로** 얻는 경로(`AB-010`의 ToxicGas 장판이 선례)는 **채용하되 필요할 때마다 점진 적용**. 이번 범위 밖.
- **부수 발견:** `ALLY_CACHE_POOL`에 **`AB-050` 유령 ID** 잔존([[DRIFT-109]]에서 스킬만 지우고 풀 정리를 빠뜨림) → 카탈로그 대조로 제거. 신규 소모품 미등재는 **`Slice01Data` ID 계약이 로드 거부로 잡아냈다**(계약이 작동한 사례).
- **분류\전파:** **`skillbook_zone` kind 소멸 + 아군 5종 폐기 + `enemy_only` 예외 + `spawn_medium` 소모품 effect + Vegetation 이동피해 규칙** = rule/scope/schema → **OPS_30 전파 후보**([[DRIFT-107]]~[[DRIFT-111]]과 한 패킷). 컨트롤러·소모 시점 = impl.
- **영향 파일:** `data/slice01/{skillbooks,consumables,abilities,display_names,id_registry}.json` · `scripts/run/controllers/medium_consumable_controller.gd`(신규) · `scripts/run/dungeon_run.gd` · `scripts/combat/abilities/effects/sb_zone.gd`(삭제) · `ability_dispatch.gd` · `scripts/world/hazards/{hazard_zone,surface_grid}.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS**(2026-07-28) — party_pool_smoke에 **20건**: 아군 5종 폐기 · 적 5종 `enemy_only` 존치 · `skillbook_zone` 소멸 · 플라스크 5종 해소/`spawn_medium`/medium·ttl · **가시 4건**(첫 틱 무피해 · 정지 무피해 · 1m=DMG_PER_M · 틱 상한).
- **상태:** LOGGED (게임측 확정). 전파 = 사용자 판단 대기. ⏳ F5 체감 대기(플라스크 조작감 · 가시밭 이동 압박).

### DRIFT-113 — `take_damage` 시그니처 파리티 붕괴(진영전 전용 크래시) · 반사 처치 크레딧 🔷 impl (전파 불필요)
- **발단:** CI run `31058027571`(커밋 `b4e3b04`) **실패** — `dungeon_run.tscn` 부팅 스모크에서 `SCRIPT ERROR: Invalid call to function 'take_damage' in base 'CharacterBody3D (enemy_unit.gd)'. Expected 2 argument(s).` **다음 커밋(`349b117`)은 통과**했으나 이는 **버그가 고쳐진 게 아니라 조우가 안 뜬 것**이다.
- **원인:** [[DRIFT-104]](반격 캐스팅 판별)에서 `party_member.take_damage`에 3번째 인자 `from_ability`를 추가하면서 **`enemy_unit` 쪽은 2인자로 남겨뒀다.** `enemy_ai`는 피격 적용 시 **대상 진영을 가리지 않고** 3인자로 부른다(`enemy_ai.gd:1082/1137/1476/1761`). 아군 대상 경로는 항상 열려 있어 매번 정상, **적↔적 피격은 진영전(3세력) 조우가 떴을 때만** 열린다 → **같은 코드가 판에 따라 되고 안 되는** 형태로 잠복했다.
- **왜 로컬 게이트를 통과했나:** `dungeon_run` 스모크는 16프레임만 돌린다. 그 사이 3세력 교전이 실제로 성립하는지는 **스폰/시드/타이밍 의존**이라 재현이 확률적이다. 로컬 11/11 PASS는 **버그 부재의 증거가 아니었다.**
- **① 파리티 복원:** `enemy_unit.take_damage(amount, attacker, _from_ability := false)` — 적 쪽엔 반격(AB-048b) 같은 게이트가 없어 **받고 무시**한다. 존재 이유는 동작이 아니라 **호출 계약의 파리티**다(`ctx` 파리티를 `CTX_CONTRACT`로 강제하는 것과 같은 이유).
- **② 부수 수정 — 반사 처치 크레딧:** `party_member`의 Sentinel/반격 반사가 `attacker.take_damage(back)`으로 **attacker 없이** 때리고 있었다 → `enemy_unit`이 `killed_by_party`를 세우지 못해 **반사딜로 마무리한 적은 파티 킬로 집계되지 않았다**(전리품·잠행 관여 크레딧 누락). `self`를 넘겨 귀속을 복원.
- **③ 게이트 보강(재발 방지):** 타이밍 의존 스모크에 기대지 않도록 `party_pool_smoke`에 **선언 자체를 비교하는 검사** 추가 — `_argc(pm,"take_damage") == _argc(enemy,"take_damage") == 3` + **3인자 실호출**. 인자 수가 갈리는 변경은 조우 운과 무관하게 여기서 먼저 막힌다.
- **교훈:** 한쪽 유닛 타입의 시그니처만 늘리면 **호출자가 진영을 안 가리는 경로**에서 조용히 갈라진다. `party_member` ↔ `enemy_unit`은 `take_damage`/`apply_outcome` 등 **공유 호출면**을 가지므로 한쪽만 바꾸지 않는다.
- **분류\전파:** 순수 구현 결함(스펙에 시그니처 규정 없음) → **전파 불필요.**
- **영향 파일:** `scripts/combat/enemy_unit.gd` · `scripts/party/party_member.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS** · party_pool_smoke 파리티 2건 신규.
- **상태:** FIXED.

### DRIFT-114 — D4 폐기: `AB-028` Guard Break Rhythm 삭제(클래스 불일치) 🔶 scope (전파 후보)
- **판정(사용자):** *"AB-028은 그냥 삭제해도 되지 않을까"* → **폐기 확정.** 48종(49 → 48), DPS 주력 9 → **8**.
- **근거 — 클러스터 중복이 아니라 「클래스와의 불일치」:** DPS 정체성 2종의 평타 사거리가 **10.0m / 14.0m**(`dps_press_line` HP110 · `dps_arc_weave` HP100 · 둘 다 `threat_mult` 0.6)인데 AB-028만 **자기중심 r3.0**이다. 원거리 클래스에게 어그로 안 끄는 몸으로 3m까지 들어가라 요구하면서 **`knockback_m: 0.0`이라 붙은 뒤 공간을 만들 수단이 없다.** 성능도 지배당한다 — 같은 DPS 풀의 **AB-004(원거리 dmg2.0/cd5)** · **AB-059(dmg4.0/cd9)** vs **AB-028(근접 dmg1.0/cd6)**. **리스크를 더 지는 쪽의 보상이 더 낮다.**
- **재정의 안을 왜 안 골랐나:** D4 노트의 대안(kb·속성 복구 → "DPS 근접 이탈기")은 **AB-002(Tank 자기중심 강타 + kb3.0)와 축이 그대로 겹치고**, 위 정체성 사거리와는 여전히 어긋난다. **재정의해도 살 자리가 없다**는 게 폐기로 기운 이유.
- **폐기 비용:** `skillbook_strike` kind는 **AB-002(Tank 자기중심) · AB-005(Nuker rect)** 가 계속 써 **kind 소멸 없음**. **Ally-only**(`abilities.json`에 AB-028 없음)라 [[DRIFT-101]] ②(Shared 폐기 시 적측 교체) **미적용**. 죽은 `castTier=B`/`rootDuringCast`/`telegraph_s` 잔존 스키마도 함께 소멸.
- **RX:** 속성 없음 + kb 0.0이라 `PhysicalImpact` 축에도 못 끼던 **전수 유일 "RX 접점 0" 피해 스킬**이 사라졌다 → §5.2.1 공백 항목에서 제거.
- **정리 규약(선례 따름):** `id_registry.json`의 `AB-028`은 **존치**한다 — AB-050/009/071/074/036 등 기폐기 ID 전부 registry에 남아 있다(폐기 = 카탈로그에서 빼는 것이지 ID 반납이 아님). **`ALLY_CACHE_POOL`(dungeon_run.gd)에서는 제거** — [[DRIFT-112]]에서 걸린 `AB-050` 유령 ID의 재발 방지.
- **분류\전파:** 스킬 1종 폐기 = scope → **OPS_30 전파 후보**([[DRIFT-107]]~[[DRIFT-112]]와 한 패킷).
- **영향 파일:** `data/slice01/skillbooks.json` · `scripts/run/dungeon_run.gd` · `docs/_WIP_casting_expansion_pass.md`.
- **상태:** LOGGED (게임측 확정). 전파 = 사용자 판단 대기.

### DRIFT-115 — D5 재정의: 「빔」 → **채널링** 클러스터(4형상 × 4속성) · `Frozen` 신설 · 냉각에 공속 축 추가 🔶 rule/scope/schema (전파 후보)
- **판정(사용자):** *"D5는 '빔'에 초점을 맞추기보다 **채널링**에 초점을 맞춰 클러스터를 유지하고, 이에 맞춰 다른 element 스킬도 생성한다."* → 단일 스킬 클러스터(AB-054)가 **4종 클러스터**가 됐다. 51종(48 → 51), DPS 주력 8 → **11**.
- **왜 이 방향이 성립하나:** `beam_channel`은 이름만 빔이지 실제로는 **범용 틱커**였다 — 판정이 `enemies_in_cone`이라 빔은 이미 `half_deg 7°`짜리 부채꼴이었고, `element_hit` seam도 틱마다 이미 호출되고 있었다. 즉 **형상·속성 축이 이미 열려 있었는데 스킬이 하나뿐이었던 것**이다. §5.2.1의 "D5는 채널 형태가 lightning에 고정" 진단은 **kind 이름에 갇힌 착시**였다([[DRIFT-111]] D1+D2 병합과 같은 교훈).
- **① kind 개명 `skillbook_beam` → `skillbook_channeling`**(사용자 선택): 4형상 중 1개만 참인 이름을 버렸다. `sb_beam.gd`→`sb_channeling.gd` · `beam_channel.gd`→`channel_field.gd`.
- **② 4형상 (`channel_shape`):**
  - `line`(AB-054 절단 광선 · lightning) — 원형. 좁은 원뿔 = 직선 관통. 변경 없음.
  - `cone`(**AB-109 화염 분사** · fire) — **틱마다 사거리가 자란다**(reach = range × (i+1)/ticks). 사용자 판정: *"한번에 전범위 아니고 나로부터 뻗어나가는"*. 1틱은 발밑, 마지막 틱에 최대 사거리 → **가까운 적부터 순서대로** 맞고 뒷줄은 완주해야 닿는다.
  - `cloud`(**AB-110 독무 살포** · poison) — **조준점**에 서는 구름(사거리 8m, *"너무 멀지 않게"*), 틱마다 `apply_poison_stack`. 피해가 아니라 **스택이 payoff**.
  - `nova`(**AB-111 냉기 폭풍** · cold) — 자기중심 r5.0. 틱마다 냉각 심화, **마지막 틱까지 전부 맞은 대상만 빙결**. 반경을 한 번이라도 벗어나면 연속 카운트가 끊겨 무산된다 = **적에게 빠져나갈 여지가 있는 CC**.
- **③ `Frozen` 상태 신설(사용자 선택):** 종전엔 빙결 상태가 **없었다** — DPS 초월 `freeze` variant가 `Chilled`를 `Rooted`(이동만 잠금·행동은 가능)로 격상하는 게 유일한 선례였다. 사용자 판정은 *"모든 행동 금지"* → `MOVE_MULT 0.0` + `ATK_MULT 0.0` + **`enemy_ai`가 `is_stunned()`와 같은 게이트에서 검사**(캐스트·돌진 중단 + 정지). 스턴과 원천만 다르다(스턴=타이머 필드 / 빙결=outcome 컨테이너라 지속·표시·해제가 다른 냉기 상태와 한 규격). `CC_TENACITY_OUTCOMES` 등재 — 미니보스 저항이 먹는다.
- **④ 냉각(`Chilled`)에 공속 축 추가(사용자 지시):** **이동만 늦추는 감속은 원거리 적에게 거의 의미가 없었다**(제자리에서 같은 속도로 쏜다 — [[DRIFT-109]]에서 이동 CC를 폐기한 것과 같은 진단). `ATK_MULT` 표 + `attack_interval_now()`가 접는다. 이 seam이 생기기 전엔 공속을 건드리는 수단이 **Bloodlust 가속 하나뿐**이었다(단방향).
  - **심화도 = `Chilled.mag`(0~1)** — 상태를 새로 만들지 않고 **기존 Chilled에 깊이 축을 추가**했다. mag 0 = 종전 값 그대로라 **RX·볼트 등 기존 냉기는 하나도 안 변한다**(하위호환). mag 1 = `CHILL_DEEP_MOVE 0.25` / `CHILL_DEEP_ATK 0.30`.
- **⑤ 화염 = 순수 피해(사용자 결정):** `Elements` 규약(2026-07-19: 점화는 RX 조건부)을 **건드리지 않는다.** 화염 분사는 맨땅에서 틱 피해만 주고, 기름 위에서만 점화가 붙는다. *"향후 데미지 배율에 속성 추가 피해를 추가할 예정"* — 그때 얹는다.
- **⑥ 조준 분화:** 한 kind가 **네 조준**을 갖는 첫 사례라 `channel_shape`로 갈랐다 — line=레인 / **cone=부채꼴 프리뷰 신설**(`AimMarker.show_fan`) / cloud=지면 원판 / nova=조준 없음(자기중심 즉시). cone을 직선 레인으로 그리면 산탄 때와 같은 "마커와 실제가 다르다" 문제가 난다(IMPL-DEC-20260728-002에서 세운 규칙).
- **⚠️ 클래스 정합 리스크(명시 기록):** [[DRIFT-114]]에서 AB-028을 *"DPS는 평타 10/14m 원거리라 자기중심 근접은 집이 없다"* 로 폐기했는데, `cone`(전방 7m)·`nova`(자기중심 r5)는 **같은 구조를 다시 만든다.** 게다가 채널은 `MOVE_CANCEL_M 0.3`이라 **제자리에 못 박힌다.** 성립 조건은 하나 — **payoff**다. AB-028은 payoff가 `dmg 1.0`뿐이었고, 여기는 빙결(전 틱 완주)·전방 광역 지속피해가 대가다. **냉기 폭풍이 피해 위주로 튜닝되면 AB-028의 재판이 된다** — 밸런싱 시 이 문장을 먼저 볼 것.
- **부수 수정:** 샌드박스 로드아웃(`SANDBOX_SUBS`)에 **폐기된 `AB-037`**([[DRIFT-111]])이 남아 DPS·Nuker 슬롯이 **조용히 비어 있었다**(`equip_skillbook_by_id`가 없는 마스터를 무시). 유저의 실제 체감 무대라 목록이 낡으면 "그 스킬 안 나온다"로 돌아온다 → 신규 채널 4형상으로 교체 + **스모크에 전수검증 추가**.
- **분류\전파:** **kind 개명 + `channel_shape` enum + 신규 AB 3종(AB-109/110/111) + `Frozen` 상태 신설 + `Chilled` 공속 규칙** = rule/scope/schema → **OPS_30 전파 후보**([[DRIFT-107]]~[[DRIFT-114]]와 한 패킷).
- **영향 파일:** `data/slice01/{skillbooks,display_names,id_registry}.json` · `scripts/combat/abilities/effects/{sb_channeling,channel_field}.gd`(신규, `sb_beam`·`beam_channel` 삭제) · `scripts/combat/{outcome_status,enemy_unit,enemy_ai}.gd` · `scripts/ui/{aim_marker,float_text,skill_text}.gd` · `scripts/run/controllers/aim_controller.gd` · `scripts/combat/abilities/ability_dispatch.gd` · `scripts/run/dungeon_run.gd` · `scripts/dev/combat_sandbox.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS** — party_pool_smoke에 **30여 건** 신규: kind 소멸/등록 · 4형상 전수 · 4속성 커버 · 형상별 필수 params · 냉각 하위호환(mag 0) · 심화(mag 1) 이동·공속 · 빙결 이동/공격 0 · `is_frozen()` 게이트 · 적 공격 간격 증가 · 샌드박스 슬롯 실재.
- **⑦ 체감 수정 2건(2026-08-06 F5 피드백):**
  - **화염 VFX 전면 교체** — `fan_telegraph`(지면 반투명 삼각팬)를 재사용했더니 *"불 느낌이 안 난다"*(사용자). 그건 **전조 마커**용이라 정지·평면·단색이었다 — 구조적으로 불이 될 수 없다. `SkillVfx.flame_cone` 신설: **바깥으로 뻗는 이동 + 식는 색(흰노랑→주황→검붉음, `emission_energy`도 동반 감쇠) + 자라는 크기**를 한 puff에 태우고, 노즐 코어 번쩍 + 끝단 검댕을 얹었다. 퍼프 수명(`interval × 1.6`)이 틱 간격보다 길어 **틱끼리 겹치며 연속 분사**로 보인다. 지면 팬은 **그을음 색으로 낮춰** 존치(부채꼴 각도 단서는 남기되 마커로 안 읽히게).
  - **채널 지속 2.1~3.2배 연장** — *"너무 짧아서 집중 중인 느낌이 안 난다"*(사용자). 054 1.08→**3.5s** · 109 1.6→**4.0s** · 110 2.0→**4.2s** · 111 1.8→**4.2s**. **총 피해(ticks × tick_mult)는 유지**했다 — 요청은 길이지 세기가 아니다. 스모크에 **3초 하한**을 못박았다(짧으면 즉발과 구분이 안 돼 클러스터의 존재 이유가 사라진다).
  - ⚠️ **파생 — 냉기 폭풍 빙결이 크게 어려워졌다:** 요건이 "전 틱 연속 적중"이라 **1.8s → 4.2s 동안 반경 안에 붙잡아둬야** 한다. 결과적으로 빙결은 **접근형(advance) 적 전용 CC**가 된다 — 카이팅·standoff 적은 사실상 못 얼린다. 자기방어(붙은 적을 떼어낸다) 프레이밍과는 일관되지만, **F5에서 한 번도 안 걸리면 요건을 "전 틱" → "N틱 이상"으로 완화**할 것.
- **상태:** LOGGED (게임측 확정). ⏳ F5 체감 대기: 뻗어나가는 화염의 도달 순서 · 독무 배치 사거리 · **냉기 폭풍 완주 난이도(4.2s 연장으로 더 어려워짐 — 위 ⑦ 참조)** · 냉각 공속 감소 체감 · 새 화염 VFX 밀도/속도.

### DRIFT-116 — H 블록 교정: 힐러 방어 4종 대상 분화 · `AB-070` 정화 재정의 · `AB-101` 폐기 · tier 역전 교정 🔶 rule/scope (전파 후보)
- **판정 기준(신규):** 힐러 정체성은 **평타 사거리 2.0m · dmg 6**(`healer_mend_circle` HP100 / `healer_ward_pulse` HP105)로 **전 클래스 최저**다. 즉 **평타로 기여할 방법이 없다** — 딜러는 애매한 슬롯을 평타로 메우지만 힐러는 못 메운다. 그래서 H 블록 판정 축을 중복이 아니라 **"표적이 실제로 존재하는가"**로 잡았다([[DRIFT-109]] T4b 이동 CC 9% 폐기와 같은 잣대).
- **전수 실측(23 ENC / 97 스폰):** 침묵 표적(AB 보유 적) **39/97 = 40%** · purge 적 표적(`Bloodlust`) **1/97 = 1%** · 개구리 시전자 EN-007 **2/97**.
- **① H3+H4 방어 4종 → 「대상」 4갈래로 분화:**
  - **AB-067 Aegis Blessing: 자기중심(r0.5) → 조준점 최근접 아군 1인**(`targeted` + `range_m 10` + 집는 반경 2.0). 종전엔 **힐러가 자기만 지키는 칸이 AB-068과 둘**이었다 — 남을 지키는 게 힐러의 존재 이유인데 두 칸이 자기에게 갔다. "축복(Blessing)"이라는 이름값도 남에게 거는 쪽이다. 단일 선택은 **조준점 최근접**(레포에 아군 클릭 타겟팅이 없어 `sb_stun`/`sb_taunt`의 적 단일기 방식을 그대로 따름 — `sb_relocate_ally` 주석이 그 제약을 이미 기록).
  - **AB-075 Blessed Barrier: tier `Master` → `Advanced`** · **AB-065 수호막: `Basic` → `Master`**. **tier 서열이 실성능과 반대**였다 — Master(075)가 흡수율 최저(8%/5s)이고 쿨 최장인데, Basic(065)이 16%/4s + 종료 시 막은 만큼 치유 전환으로 명백히 강했다. **수치가 아니라 표기를 고쳤다** — 광역 흡수는 총량이 커서 성능을 올리면 밸런스가 흔들린다.
  - **AB-068 Warding Sigil 유지** — 힐러 유일 자기 생존기(물몸이라 1칸은 정당) + 유일 **감소(DR)** 방식.
  - 결과 축: **자기 DR(068) / 지정 1인 흡수(067) / 파티 광역 흡수(075) / 자동 최저HP 흡수→치유(065)**. 중복 0.
- **② H5 AB-044 Hush Ward — 광역으로 밀기:** `radius_m 2.0 → 3.5` · `silence_s 3.0 → 4.0`. 표적 40%는 충분하므로 판정 축은 존재 이유가 아니라 **AB-011 Toll Stun(Tank)과의 구분**이었다. "여러 캐스터를 한 번에 잠근다" ↔ "하나를 짧게 끊는다"로 역할이 갈린다.
- **③ H6 AB-101 Scent of Blood(아군판) 폐기 — 플레이어 쪽 효과가 측정 가능하게 0:** `Scented`를 소비하는 코드는 [`enemy_ai._pick_scented_target`](../scripts/combat/enemy_ai.gd) **하나뿐**이고, 그건 **적 팩이 자기 적대 대상 중 공유 표적을 고르는** 용도다. 파티가 적에게 걸면 그 적의 동료는 그를 노리지 않는다(소스 주석도 *"solo-party utility is modest … fuller payoff TBD"* 로 인정). 살리는 길은 "Scented 대상 피해 증폭"뿐인데 그건 **AB-057 Focus Fire와 정면 중복**이다. → 폐기. **`skillbook_scent` kind 소멸**(적측은 `enemy_ai`의 `enemy_mark` 내부 경로라 무관). 적측은 [[DRIFT-112]] ③의 **`enemy_only` 예외**로 존치 — 팩 공유 표적은 실제로 작동하는 기능이다.
- **④ H7 AB-070 Purge Light — 「적 강화 제거」 → 「아군 디버프 정화」로 축 이동:** 종전 표적은 **적 강화 1% + 개구리 2%**로 슬롯 하나를 쓰면서 표적이 사실상 없었다. 파티가 매 판 겪는 건 **디버프**(Chilled·Ignited·Poison·Rooted·Frozen…)이고, 특히 **매질을 소모품으로 옮기며([[DRIFT-112]]) 아군도 장판을 밟게 됐다** — 정화 수요는 그때 구조적으로 생겼다. 우선순위 = **개구리 → 아군 debuff 1건(각자) → (없으면) 적 강화 1건 폴백**. 적 강화 제거를 버리지 않아 Bloodlust Reaver의 답은 계속 이 스킬이다. `radius_m 2.0 → 3.0`(아군을 감쌀 크기), 커서 초록(`ALLY_TARGET_KINDS`).
  - ⚠️ **기절(stun)은 일부러 안 푼다** — 하드 CC 해제는 별개 축이고, 얹으면 13초 쿨짜리 스턴 브레이크가 조용히 생긴다.
  - `OutcomeStatus.cleanse_one()`이 이미 있어(BUFF 제외) 아군측은 `party_member.cleanse_debuff()` 한 겹만 추가했다. **강화(Hastened 등)는 지우지 않는다.**
- **⑤ H7 AB-069 Swift Grace `duration_s 4.0 → 9.0`:** [[DRIFT-105]] *"오오라 류는 길게"* 판정으로 DR을 6~10s로 늘렸는데 **haste만 4s로 남아** 있었다. 같은 잣대 적용.
- **⑥ H7 AB-045 Lifeline 죽은 스키마 제거**(`castTier`/`rootDuringCast`/`telegraph_s`) — [[DRIFT-114]]에서 AB-028이 폐기되며 남아 있던 **마지막 1건**. 스모크에 **전수 0 검증**을 걸어 재유입을 막는다.
- **부수 정정:** ① `ALLY_TARGET_KINDS`의 **`skillbook_ally_shield`는 존재하지 않는 kind**였다 — 효과 **파일명**만 그렇고 선언 kind는 `skillbook_shield`다(제거). ② WIP 문서의 AB-032 서술 *"은신 감지"* 는 부정확 — 실제로는 **모든 적을 안개 너머로 드러내는 F-011 정찰**이라 은신 적 수와 무관하게 항상 값이 있다(H6에서 가장 멀쩡한 슬롯).
- **분류\전파:** 스킬 1종 폐기 + kind 소멸 + AB-070 효과 재정의 + `enemy_only` 지정 = rule/scope → **OPS_30 전파 후보**([[DRIFT-107]]~[[DRIFT-115]]와 한 패킷). tier·수치 교정 = 로깅만.
- **영향 파일:** `data/slice01/{skillbooks,abilities,display_names}.json` · `scripts/combat/abilities/effects/{sb_ally_shield,sb_purge}.gd`(`sb_scent.gd` 삭제) · `scripts/combat/abilities/ability_dispatch.gd` · `scripts/party/party_member.gd` · `scripts/run/controllers/aim_controller.gd` · `scripts/ui/skill_text.gd` · `tools/{party_pool_smoke,third_smoke}.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS** — party_pool_smoke에 **20여 건** 신규: 067 지정형/075 광역 · **힐러 자기 방어 슬롯 = 1개** · tier 서열 · 침묵 광역 우위 · AB-101 폐기 + kind 소멸 + `enemy_only` 존치 · haste 8s 하한 · **죽은 스키마 전수 0** · 정화 4건(빈손 무소모 · 디버프 제거 · **강화 미제거**).
- **상태:** LOGGED (게임측 확정). 각 항목은 사용자 개별 확인 대기. ⏳ F5 체감: 아군 지정 보호막 조작감 · 정화가 실제로 걸 게 있는지 · 광역 침묵 체감.

### DRIFT-117 — 적 진영 지원 킷 신설: 보호막·정화 + 3세력 위생병(EN-3RD-04) 🔶 rule/scope (전파 후보)
- **판정(사용자):** *"게임의 의도상 **분대 대 분대** 전투가 되어야 하고, 특히 **3세력은 다른 익스트랙션에서 타 유저에 대응하는 구성**이다. 따라서 적도 힐러가 있어야 하고 **그걸 먼저 저격하는 게 누커의 역할**이 될 것. 힐링·보호막·클렌즈 같은 주요 보조 능력은 적들도 들고 있어야 한다."*
- **실사(23 ENC / 97 스폰):** 적 진영 지원은 **`enemy_heal`(AB-098) 하나뿐**이었고, 그걸 가진 **EN-014가 23 ENC 중 2곳**에만 등장했다(그마저 `slot: "fodder"` 오표기). **3세력(ENC-3RD-001)은 stalker/snarer/reaver 3종으로 서포터 0** — "상대 추출조"라는 설정과 정면으로 어긋났다. 보호막·정화는 적 진영에 **개념 자체가 없었다**.
- **① 신규 적 능력 kind 2종:**
  - **`enemy_shield`(AB-067)** — 같은 진영에서 **가장 다친 1명**에게 흡수 보호막(12% / 6s). 아군판이 "지정 1인"이라 적도 단일이어야 대칭이 맞는다(광역으로 주면 같은 AB가 진영에 따라 다른 스킬이 된다). 자기 자신도 후보 — 서포터가 저격당할 때 스스로를 감싸는 게 자연스럽다.
  - **`enemy_cleanse`(AB-070)** — 같은 진영 아군의 디버프를 **각자 1건씩** 제거. 즉 **플레이어가 건 CC(빙결·속박·중독·취약)가 되돌려질 수 있다** — 이게 "서포터를 먼저 끊어라"에 값을 만드는 핵심이다.
  - 둘 다 힐과 같은 **target-less 아군 대상**이라 `_try_cast_signature`의 초기 패스를 공유한다. 캐스트 조건은 `_support_needed`로 일반화 — **쓸 데가 없으면 쿨을 아낀다**(AB-098이 세운 규약을 3종으로 확장). 보호막은 **이미 보호막이 있는 대상엔 안 쓴다**(덮어써 낭비되는 걸 방지).
- **② `enemy_unit`에 보호막 체계 신설:** 적에겐 흡수 보호막이 **아예 없었다**. `shield`/`shield_timer_s` + `add_shield()` + `tick_shield()` + `take_damage`의 **HP보다 먼저 닳는** 흡수 분기. IDA-020 규약(더 센 것만 덮어쓰기)·HP바 `set_shield_ratio` 표시 전부 파티와 동일 — `HealthBar`가 이미 보호막 오버레이를 지원해 표시는 공짜였다.
- **③ `cleanse_debuff()` 양측 파리티:** [[DRIFT-116]]에서 `party_member`에 넣은 것과 **같은 규약**으로 `enemy_unit`에도 추가(개구리 우선 → debuff 1건, **기절은 안 푼다**, 강화는 안 지운다). `OutcomeStatus.has_any_debuff()` 신설(캐스트 조건용).
- **④ 신규 유닛 `EN-3RD-04` Mender(제3세력 위생병):** HP 220 · 평타 8m · `PT-016`(Support/Hold/flee_if_melee) 재사용 · 킷 = **힐(AB-098) + 보호막(AB-067)**. 3세력에 처음 생긴 지원 슬롯이다. 패턴·평타 아키타입은 기존 것을 재사용해 신규 등록은 `enemy_ids`의 **EN-3RD-04 하나**뿐.
- **⑤ EN-014 Gutter Chanter 킷 확장:** AB-098(힐) → **AB-098 + AB-070(정화)**. 던전 진영의 유일 서포터에 정화를 얹어 두 진영 모두 "지원을 끊어야 하는 대상"을 갖게 했다.
- **⑥ ENC 배치:** `ENC-3RD-001`에 EN-3RD-04 추가(3 → 4). EN-014를 **엘리트 보유 분대** 3곳(`ENC-HARD-002` · `ENC-HARD-008` · `ENC-MID-001`)에 추가 → 2/23 → **5/23**. `slot: "fodder"` → **`"support"`** 오표기 정정(HARD-006·009). 서포터는 **유지할 가치가 있는 분대에만** 붙였다 — 잡몹만 있는 팩에 붙이면 저격 우선순위라는 학습이 생기지 않는다.
- **⑦ 획득 경로 이동(F-009 정합):** AB-067·AB-070이 **Shared가 되면서 처치 드롭 경로**가 생겼다(`loot_service`는 죽은 적의 AB에 skillbook master가 있으면 드롭). → **`ALLY_CACHE_POOL`에서 제거** + `skillbooks._note`의 ally-only 목록 갱신. 캐시에 남겨두면 같은 책을 **두 경로로** 주게 된다.
- **설계 파급(기록):** 이 변경으로 **누커의 존재 이유가 하나 생겼다** — 후열 서포터 저격. 종전엔 "딜이 센 원거리"였을 뿐 표적 우선순위를 만드는 구조가 없었다. 힐/보호막/정화를 끊지 않으면 분대가 안 죽는다는 압력이 생기고, 이는 [[DRIFT-116]]에서 힐러 킷을 지원 중심으로 정리한 것과 **대칭**을 이룬다.
- **분류\전파:** 신규 enemy AB kind 2종 + 신규 enemy 유닛 1종 + ENC 편성 변경 + 획득 경로 이동 = rule/scope → **OPS_30 전파 후보**([[DRIFT-107]]~[[DRIFT-116]]과 한 패킷). 배치 수량 = 튜닝(로깅만).
- **영향 파일:** `data/slice01/{abilities,enemies,skillbooks,id_registry}.json` · `data/slice01/encounters/{ENC-3RD-001,ENC-HARD-002,ENC-HARD-006,ENC-HARD-008,ENC-HARD-009,ENC-MID-001}.json` · `scripts/combat/{enemy_unit,enemy_ai,outcome_status}.gd` · `scripts/combat/abilities/ability_roles.gd` · `scripts/run/dungeon_run.gd` · `tools/third_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS** — third_smoke에 신규: EN-3RD-04 row 해소 · ENC-3RD-001 서포터 편성 · **적 진영 지원 킷 3종(heal/shield/cleanse) 보유 전수 확인**.
- **상태:** LOGGED (게임측 확정). ⏳ F5 체감: 서포터가 실제로 분대를 살려내는지(저격 압력이 생기는지) · 정화가 플레이어 CC를 되돌리는 빈도가 과한지 · EN-3RD-04의 후열 유지(flee_if_melee)가 성립하는지.

### DRIFT-118 — 적 외형 구분: 「특성 → 실루엣·표식」 파생 체계 🔷 impl (전파 불필요)
- **판정(사용자):** *"적들의 능력이 다양해지고 있으니 적을 구분짓는 것이 필요하다. 지금은 색 정도 빼면 구분할 방법이 쉽지 않아서, **각 특성을 이용해 적의 생김새를 고도화**했으면 좋겠다."*
- **실사:** `UnitVisuals.ENEMY_VISUALS`는 **19종 중 7종만 손으로 색·크기를 박아뒀고 나머지 12종이 `ENEMY_DEFAULT` 하나(갈색 박스 1.0배)를 공유**했다. 형태 구분은 진영 축(3세력=콘) 하나뿐. **색은 부감 시점·안개(F-011)·색각에서 가장 먼저 무너지는 축**이라, 손키를 19개로 늘리는 건 같은 문제를 미루는 것에 불과했다.
- **접근 — 손으로 칠하지 않고 규칙이 낳게 한다:** 유닛 row에 **이미 있는 특성**(`role` · `tags.tier` · `stats.attack_range_m`)에서 외형을 파생한다. 새 유닛을 추가해도 자동으로 구분되고, 데이터와 외형이 어긋날 수 없다.
  | 축 | 출처 | 표현 |
  |---|---|---|
  | **실루엣** | `attack_range_m` (≤2.5m ↔ 초과) | 근접 = **박스**(넓고 낮음) / 원거리 = **8각 기둥**(좁고 높음, ×0.72 폭·×1.28 높이) |
  | **체급** | `tags.tier` | Trash 1.0 / Elite 1.30 / Boss 1.45 (손키 scale이 있으면 그쪽 우선) |
  | **표식** | `role` | support=**후광 링**(초록) · nuker=**떠 있는 오브** · cc=**뿔 2개** · elite/boss=**왕관 3뿔** · fodder=**없음** |
  | 색(보조) | `role` 팔레트 + id 해시 ±9% | 같은 role끼리도 완전히 겹치지 않음 |
- **① 실루엣이 교전 거리를 말한다:** 원거리 유닛은 기둥이라 **"뒤에 서서 쏘는 놈"**으로 읽힌다. **충돌 박스도 같이 바뀐다** — 외형만 바꾸면 실루엣과 판정이 어긋난다.
- **② 표식이 가장 강한 구분자:** 부감 시점에선 실루엣 **위쪽**이 가장 잘 보인다. 특히 **support 후광 링**은 [[DRIFT-117]]의 *"서포터를 먼저 끊어라"* 가 **글이 아니라 화면으로** 전달되게 하는 장치다. `fodder`는 표식이 없고 **그 없음 자체가 "잡몹"이라는 정보**다 — 위협 우선순위가 실루엣만으로 읽힌다.
- **③ 진영 × 역할 = 직교:** 표식은 몸(`Mesh`)의 **형제 노드**라 `apply_faction_shape()`가 몸을 콘+보라로 갈아도 살아남는다(콘 끝에 파묻히지 않게 y만 재조정). 덕분에 **EN-3RD-04는 3세력(콘·보라)이면서 동시에 서포터(후광)**로 읽힌다 — 축이 겹쳤다면 둘 중 하나를 포기해야 했다.
- **부수 발견(미수정):** `EN-014`는 패턴이 `PT-016`(band=**Mid**, Support/Hold/flee_if_melee)인데 `attack_range_m`이 **1.7m(근접)** 이다 — 뒤에 서야 할 서포터의 평타가 근접 사거리다. 파생 규칙상 박스 실루엣이 되는데, 이건 **외형 문제가 아니라 데이터 불일치**라 여기서 조용히 고치지 않고 기록만 남긴다(신규 EN-3RD-04는 8.0m로 잡아 기둥).
- **영향 파일:** `scripts/core/unit_visuals.gd` · `scripts/combat/enemy_unit.gd` · `scripts/combat/combat_controller.gd` · `tools/party_pool_smoke.gd`.
- **게이트:** `ci_smoke.sh` **11/11 PASS** — party_pool_smoke 신규: 전 유닛 shape/scale 유효 · **실루엣 = 교전거리 일치 전수(19종)** · **색상 고유값 ≥ 유닛 수의 80%**(12종 동일 문제 재발 방지) · 역할별 표식 유무.
- **🐞 스모크 함정(기록):** `String(Color)` 생성자는 Godot 4에 **없다**. `_initialize`에서 던지면 `quit()`에 도달하지 못해 **헤드리스 프로세스가 그대로 멈춘다**(FAIL이 아니라 hang). `str()`로 교체. 이 스모크는 실패보다 **정지**로 나타날 수 있음을 기억할 것.
- **상태:** LOGGED. ⏳ F5 체감: 표식 크기가 부감에서 충분한지 · 기둥↔박스가 실제로 갈리는지 · 후광이 서포터 저격을 유도하는지.

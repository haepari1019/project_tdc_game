# SPEC_DRIFT — 구현 ↔ 스펙 이격 대장

> **무엇:** 구현이 spec(SSOT)과 달라진 지점의 **단일 추적 대장**. 발견 즉시 `DRIFT-###`로 기록하고, 분류·결정·상태를 유지한다.
> **규칙:** [AGENTS.md](../AGENTS.md) §Spec drift & propagation. 튜닝수치=로깅만 / 아이디어=`OPS_08·I-002` / 규칙변경=spec repo `OPS_30` 전파 후 `spec_ref.json` 재핀.
> **최종 갱신:** 2026-06-18 · **스펙 핀:** `spec_ref.json` @ `staging` `4422e50` (**Phase 2 Full Spec Coverage 채택** — 데모 스코프 상한 해제, `ImplementationPhase_FullSpecCoverage.md` · DRIFT-037 F-011 fog·DRIFT-038 F-012 see-through 전파 `daa1114`/DEC-20260618-001 머지+재핀). **PENDING-PROP 없음.** 이전 핀: 0edf55c=DRIFT-035/036(F-004 §3.5·F-012 §3.1.2), b84e975=DEC-20260611-003~006, c795fee=DEC-001/002, f7739a1=DRIFT-021.
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
| 014 | 파티전멸=Run Failure 없음(F-007) | scope | 1b 갭(저비용 추가 권장) → **DRIFT-031로 구현**(PartyWipe→Run Failure) | ✅ IMPLEMENTED (DRIFT-031) |
| 015 | 맵 장애물 + 파티합집합 LOS 가림 구현 (F-011 선행) | scope/impl | occlusion-only 토대, 풀 F-011은 보류 | IMPLEMENTED |
| 016 | RMB 카메라회전 + WASD 카메라상대 + 방향별속도(W>A/D>S) + 진형정면=카메라추종 | rule/impl | F-002(RMB=페이싱)와 충돌 → 카메라 우선. 진형 이동반전 플립머신 제거(~134줄). 페이싱 구현 시 재바인딩 | IMPLEMENTED |
| 017 | enemy_unit LAYER_ENEMY 3→4 콜리전레이어 근본수정 | code-bug | 적이 world비트 공유하던 버그 수정(LOS·스티어링 정상화) | FIXED |
| 018 | 적 시야 인지(F-011 perception **부분구현**, deferred→1b): 전방콘(FOV~160°)+LOS+근접버블·2존(경계존?·전투존!)·last_seen 수색·도망 시 grace(6s)+감속(0.55) 추격 후 포기 | scope/rule | **유지=1b 확장.** F-011 perception 데모 부분집합 노트 + 신규 **F-013** enemy-AI + QA-031 승격 | ✅ MERGED (staging 6f0e534 · DEC-20260610-001) |
| 019 | 적 **분대(squad)** 단위 engage(분대 독립·분대원 근접전파 9m·stray 예외) + **미리 스폰(휴면)**·시작방 인카운터→메인전투방 이전·방 먼쪽 배치 + navmesh 추격 + **threat/시야기반 타겟**(미인지 대상 비타겟) | rule/scope | 신규 **F-013** enemy-AI 행동 루프로 SSOT화(분대=F-022 Encounter Group 구체화). 포스트복귀/리쉬는 F-013 §9 후속 | ✅ MERGED (staging 6f0e534 · DEC-20260610-001) |
| 020 | 전투AI/인지 **튜닝수치**(FOV 160°·sight 12m·proximity 2.5m·alert_zone 0.2·scan ±35°/4s·investigate 0.35·chase_blind 0.55·squad_prop 9m·exit_grace 6s·lane 12m·cone alpha 0.05~0.06) | tuning | 로깅만(전파 금지). grace 6s는 D-010 §4.2와 정합 | LOGGED |
| 021 | 비결속 지휘권 **분리 모델**: 지휘권 보유자(리더 고정·핑/MIA 대상) ↔ 포메이션 랠리 앵커(보유자 조작/복귀 중 stand-in 자동·복귀 시 환원) | rule | F-003 §3.0.4 신설로 SSOT화(보유자=리더 고정, 랠리 앵커만 자동). UI-008=리더 외 명시 지정 | ✅ MERGED (staging f7739a1 · DEC-20260610-002) |
| 022 | **방향 피격 인디케이터** — 조작캐 피격 시 공격자 방향으로 화면 가장자리 빨간 글로우(인포워 HUD) | rule(전파됨) | **F-011 §3.7** 방향 피격 인디케이터(정보전 HUD) 신설. DEC-20260611-006(b84e975); 수치=tuning | ✅ MERGED (b84e975) |
| 023 | **인벤토리 시스템**(5×8 백팩 + 컨테이너, `i` 토글·중앙·창드래그) + **백팩 아이템**(가변 W×H·occupancy·드래그&드롭·경계/겹침/스냅·**회전 R**·**컨테이너 간 이동**) | rule(전파됨) | **F-010 §3.8.1** Run Inventory 그리드 표현. DEC-20260611-004(b84e975); 용량모델·무게·스택 정합 OQ | ✅ MERGED (b84e975) |
| 024 | **월드 루프**: 상자(키 보유, 우클릭 루팅) → 키 → **키 게이트 문**(탈출경로 차단) → 문 개방 시 objective → 탈출. RM-OBJ-01 진입 자동완료 **제거**. 상호작용=우클릭(E=서브스킬2 예약) | rule(전파됨) | **DBP-DEMO-001 §4.1** 키-게이트 objective(상자→키→문) + QA-030 §3.5. DEC-20260611-005(b84e975); gimmick 타입 카탈로그=F-026 후속 | ✅ MERGED (b84e975) |
| 025 | **Identity Gear**(F-008): 던전 루팅 gear → 장비 슬롯 장착·교체(equipClasses)·장착 Safe/미장착 At-Risk | rule(전파됨) | 던전 루팅 정식 채택, DEC-20260611-001 전파(4281981) | ✅ MERGED (c795fee) |
| 026 | **스킬북 시스템 B**: 적 lootable AB(AB-002/010/011) per-kill 드랍 → 백팩 At-Risk 1×1 / Q·E·R 3슬롯 장착(클래스 게이트·드래그·우클릭·녹적 프리뷰)·탄수 소모·전투 외 교체 / Identity 고정서브(AB-S01~04) 제거 | rule(전파됨)+tuning | per-kill·서브3슬롯=spec(DEC-20260611-002, c795fee). charges 8/10/6·드랍률 0.5·독/스턴 프록시=tuning/impl | IMPLEMENTED |
| 027 | **소모품 시스템 + 부활 스크롤**: consumables.json·스택(max 3)·Z/X/C 핫키(호버+키/드래그 등록, 6시 시트 위 바)·**인-런 부활**(휴식중만, 소모1→다운 아군 부활 HP50%) | rule(전파됨) | **F-010 §3.4·D-020·F-007 §3.6.1 경계** 전파. DEC-20260611-003(b84e975); 부활 HP%·채널·스택=tuning | ✅ MERGED (b84e975) |
| 028 | **Fatal 장판 트랩 + MIA + navmesh carve + 레버**: 초크포인트 트랩→치명 장판(텔레그래프→치사·피아무구분) 스폰→파티 분리 / 후미 fatal 회피·stand-off hold / 장판=**navmesh carve**(벽처럼 우회/단절) / **MIA 양경로**(비결속 leash 20m·즉시 경계링·1s 경고·5s MIA·조작캐면 앵커 강제이전 / 복귀실패=nav 경로 도달불가) / 레버=함정 회복 | rule(기존 spec 구현)+scope+tuning | F-006 트랩·F-004 §3.1.1/§3.3·F-003 §3.3.1/§3.6.2·F-001 §3.6 구현. 트랩/레버 gimmick=신규 데모(전파 후보). 장판 수치·leash 20m·타이밍=tuning | IMPLEMENTED (일부 전파 후보) |
| 029 | **기름 배럴 + 화염 연쇄(RX-OIL-FIRE) + 디버프 핍 + 서브 페널티**: 파괴 배럴(ENT-BARREL)→기름 장판(슬로우 필드)·화염 스킬북(Ember Lance AB-037)→기름 점화→**폭발+화염/독안개 장판+연쇄**(depth≤2) / zone 일반화(status·impassable·ttl·slow) / 슬로우·DoT 디버프 핍 / **서브 클래스 페널티**(비주력 −10% + UI 경고) | rule(기존 spec 구현)+tuning | F-027 RX-OIL-FIRE-001·ENT-BARREL-001·D-016 AB-037·F-021 ZONE/연쇄·F-009 §3.2.1 구현. 수치·main=first-equip-class 휴리스틱=tuning/impl | IMPLEMENTED |
| 030 | **MIA 대응 UI(UI-006) 정식화 + 다중 MIA 모집지점 픽스**: 중앙 분리경고 배너 + PIP 카메라(world 공유·강조 3s→저강조→8s 자동최소화·최소/확장·다중 MIA 사이클 ▶·수동닫기 5s 쿨다운) / MIA 멤버=랠리 앵커·지휘권 stand-in **선정 제외** / 비조작 전원 MIA여도 BOUND 폴백 안 함(UNBOUND 유지=leash로 고립 유지, 마지막 조작캐만 이동) | rule(기존 spec 구현)+impl+tuning | UI-006 §6/§7 구현, F-003 §3.6.2 MIA 거동 정제. anchor 제외·all-MIA-unbound=**전파 후보**(F-003 §3.0.4 stand-in 선정). 타이밍 3/8/5s·PIP 크기=tuning | IMPLEMENTED (일부 전파 후보) |
| 031 | **F-007 탈출 정산 + 결속 게이트 + 전멸 실패**: ExtractionActivate 완료→정산 파이프라인(생존/ExtractCasualty + 런인벤 At-Risk→Safe), Partial 동일·추가 메타벌 없음 / extractionCohesionRule(§3.6.2): 생존자 MIA/이탈 시 채널 0에서 "집합 필요" 정지(런 지속) / PartyWipe→Run Failure(§3.7.1): At-Risk=Loss Bundle, 장착 Identity Gear=Safe / 정산 화면(§3.8): 카테고리 요약 + 스크롤 상세 | rule(기존 spec 구현)+impl+tuning | F-007 §3.6/§3.6.1/§3.7.1/§3.6.2/§3.8 구현. Recovery Target 영속·월드마커·RecoverActivate/Loot UI 보류. COHESION_RULE 데모 on(Contract 기본 false)·채널 5/30s=tuning | IMPLEMENTED (Recovery 보류) |
| 032 | **횃불(ENT-TORCH) 들기/던지기 + 광원화 + 화염 어그로 + 시야밖 피격 수색**: 횃불=carriable 점화체(F-interact→소모품 슬롯, 빈슬롯 자동·풀이면 선택, 발동=지면조준 투척→착지 점화+소모), 들고 기름 접촉 즉시 점화 / 횃불이 방 광원(천장 omni 그리드 대체, 동적조명) / 던지거나 들고 점화한 화염·폭발이 적 때리면 **던진 주체에게 threat** / **시야 밖 피격(어떤 수단이든)→공격자 방향 investigate 수색** | rule(기존 spec 구현)+impl+tuning | F-021 §3.1.2(carry/투척/torch+oil)·F-027 ENT-TORCH·F-011/F-013(수색) 구현. 아군 능동 carry/투척·화염 source 어그로·시야밖 수색=전파 후보. 적 carry/몬스터 세트(증분2) 후속. 광원·수치=tuning | IMPLEMENTED (아군측; 적 carry 후속) |
| 033 | **적 횃불꾼(EN-014) + 제네릭 적-오브젝트 프로토콜 + 랜턴/토치 분리 (증분2)**: `interacts_with_objects` 적이 group interactable 중 `enemy_usable()` 오브젝트 탐색→`enemy_use`(들기); 든 오브젝트가 `enemy_combat_tick()`으로 행동(토치=접근→텔레그래프→투척). 행동이 오브젝트 내부라 신규 오브젝트는 적 코드 무수정·체스트=enemy_usable 미구현→자동 제외 / 방 조명=고정 랜턴(줍기 불가), 토치=기름 코트 4개만 | rule(기존 spec 구현)+impl+content | F-021 §3.1.2 적 carry/투척·EN-COR-000 구현. EN-014=신규 데모 적(spec 정합=1b). 제네릭 프로토콜=확장 아키텍처. 랜턴·수치=impl/tuning | IMPLEMENTED |
| 034 | **배치 허브(F-010 §3.2 / UI-005 / F-003) — 스태시 로드아웃 편집 + 반입 At-Risk + 포메이션 편집**: 메뉴에 InventoryUI(combat=null→장착 허용) + 정적 허브 파티 임베드 → 스태시(소유 gear/스킬북/소모품)를 컨테이너로 띄워 캐릭터 Q/E/R·장착·백팩 드래그. **탑다운 드래그 포메이션 에디터**(4 역할 토큰→슬롯 오프셋). Deploy 시 멤버 서브+백팩+포메이션 직렬화→RunLoadout→dungeon_run 적용(At-Risk 시작→정산 연동, 슬롯 오프셋 오버라이드). 소모품 스택10·Ctrl클릭 분해팝업·드래그 합치기. 오토로드 런타임 경로 접근 | rule(기존 spec 구현)+impl | F-010 §3.2·UI-005·F-007 At-Risk·F-003 슬롯 오프셋 구현. 스태시 시드·스택수치·CLAMP/SCALE=content/tuning | IMPLEMENTED |
| 035 | **전투 진형 — 탱커 선공 게이트 + 2선 딜러(원거리 백라인/근접 측면 플랭크) + DPS 원거리화** | rule(전파됨)+tuning | AI DPS/Nuker는 탱커 첫타 전까지 교전·접근 보류; 원거리=백라인 딜, 근접=탱커축 측면 플랭크. DPS basic_range 2.0→10.0=tuning | ✅ 전파 (F-004 §3.5, DEC-20260616-001, spec 0edf55c) + 재핀; range=tuning |
| 036 | **카메라 RMB 세로 드래그 = pitch 틸트(인버트) + 피치 범위 15~85°** | rule(전파됨)+tuning | RMB Δy→pitch(yaw와 동시 자유오빗). 범위·감도·줌=tuning | ✅ 전파 (F-012 §3.1.2, DEC-20260616-002, spec 0edf55c) + 재핀 |
| 037 | **F-011 풀 GPU vision fog**(2D SubViewport 파티-LOS→3D next_pass·explored 기억) + 적 시야콘 GPU union 재구성 + **렌더러 Forward+ 강제→web export 차단** | scope/impl + rule(제약) | DRIFT-015 deferred 풀 F-011 구현됨. fog 가시모델(차폐형 마스크·Explored Memory·시야콘 오버레이) **F-011 §3.0/§3.3/§5 정식화**. Forward+/web-export 제약=**impl-only 결정**(spec 비대상, ARCHITECTURE DEBT-PLAT-FWD) | ✅ MERGED (F-011 §3.0/§3.3/§5, daa1114·DEC-20260618-001, spec 4422e50) + 재핀 |
| 038 | **F-012 wall x-ray** — 카메라↔조작캐 사이 벽 알파 페이드(see-through), 저각 시네마틱 카메라 보완 | rule/impl | DRIFT-036 pitch 저각화의 짝. **F-011 §3.3.1 Camera Occlusion See-Through**로 정식화(F-012 §3.1.2가 F-011에 위임) | ✅ MERGED (F-011 §3.3.1, daa1114·DEC-20260618-001, spec 4422e50) + 재핀 |
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

### DRIFT-022 — 방향 피격 인디케이터 (인포워 HUD) ✅ MERGED (b84e975 · DEC-20260611-006)
- **구현(2026-06-10):** 조작 캐릭 피격 시 **공격자 방향으로 화면 가장자리 빨간 글로우** — `CombatController.party_hit` 신호(모든 피격, 칩뎀컷, severity=dmg/maxHP) → dungeon_run이 조작캐만 필터 + 카메라 `unproject_position`으로 스크린 방향 산출 → `damage_indicator.gd`(Control, 절차 draw, 동방향 debounce·페이드). 기존 카메라 방향킥(AB 전용)을 보강.
- **분류/전파:** scope/idea — 신규 인포워 HUD 피드백 UX. spec 미정의. **F-011**(Vision & Information War, 정보 제시) 또는 신규 **UI 문서**가 적합한 홈. F5 확인·튜닝(방향 부호·강도·페이드) 후 OPS_30 정합. 튜닝수치(MIN_FRAC 0.012·GAIN 4.0·SPREAD 38°·DEPTH 0.16·FADE 0.7s)는 전파 금지.
- **확장(2단계):** 팔로워(비조작) 오프스크린 피격 표시 — F-003 §3.9 분리경고/PIP와 정합 여지. ImplDecisionLog IMPL-DEC-20260610-011.
- **전파 결과(✅ MERGED, b84e975 · DEC-20260611-006):** `F-011` §3.7(방향 피격 인디케이터, 정보전 HUD) 신설로 SSOT화. 수치(MIN_FRAC·GAIN·SPREAD·DEPTH·FADE)는 tuning 유지. 팔로워 오프스크린 확장은 F-011 §3.7 후속 노트.

### DRIFT-025 — Identity Gear 던전 루팅·교체 (rule, 전파됨) ✅ MERGED (staging 4281981→c795fee)
- **결정/전파:** 장비 identity-bound + **던전 루팅 정식 채택**(per F-008). 장착 gear=Safe / 미장착 looted=At-Risk(결정 B) / `equipClasses` 동일역할 교체. `DEC-20260611-001` 전파(F-008/D-019/F-007/D-011/D-015/F-010/QA-008/HUB-COR-000/Terms + DataMap), staging `4281981`, 게임 재핀.
- **구현:** `gear.json` 4 스타터 master, `party_member._bind_gear`(gear→identity), 인벤 PARTY GEAR 슬롯(드래그/우클릭·녹적 프리뷰·게이트), 던전 gear 루팅(~40%). 게임 커밋 da46e13.
- **잔여:** 추출 정산(At-Risk→Owned/Loss) F-007 배선 미구현(표시/플래그까지). 풀 D-019 인스턴스(unlockState·blacksmith·Magitech) 보류. 미장착 Owned Protected 승격=귀속(bind) 모델 후속(F-008 OQ-7).

### DRIFT-026 — 스킬북 시스템 (Track B 구현; per-kill 전파 MERGED) 🔸 IMPLEMENTED
- **구현(2026-06-11):** F-009 스킬북 경제 게임 구현. `skillbooks.json` 3종(`AB-002` Shield Bash/Tank · `AB-010` Venom Spit/Nuker·Healer · `AB-011` Toll Stun/Tank·DPS = 적 lootable AB **Shared**). 적 처치 시 그 적의 lootable AB 확률 드랍(`enemy_defeated` AB refs 전파 → `dungeon_run._roll_loot_def`) → 백팩 **At-Risk** 1×1. `party_member.skillbook_slots[3]`(Q/E/R), `ability_dispatch.cast_skillbook`(탄수−1·쿨다운, 자기중심 AoE), Q/E/R 입력. 인벤 SUB 슬롯 UI(조작캐 3슬롯·클래스 게이트·드래그/우클릭·녹적 프리뷰·탄수 표시), `controlled_sheet` 탄수/쿨 표시. **Identity 고정서브 제거**(`_bind_gear` sub 바인딩 삭제) → 서브 전부 스킬북(F-009 §3.1).
- **전파/분류:** 드랍 트리거 **per-kill** + 서브 3슬롯은 **rule = 전파됨**(`DEC-20260611-002`, staging `c795fee`; D-018 §7.4 per-kill·F-009 §3.6·QA-009 §2.5). equip이어도 At-Risk(§3.7)·클래스 게이트(§3.2.1)·탄수(D-018)는 기존 spec 정합.
- **tuning/impl(전파금지):** `charges_max` 8/10/6 (spec 권장 50~80 — "제약적" 데모 체감 위해 하향, ChangeProtocol §5-d). `SKILLBOOK_DROP_CHANCE` 0.85 · `GEAR_DROP_CHANCE` 0.08(던전런 ~2회) (spec 예 8~15% — 데모 밸런스). cast 효과 **프록시**: 적 poison/stun 미모델 → poison=업프론트 버스트+slow, stun=near-freeze slow(`apply_slow(0.05, stun_s)`). 캐스트는 지면조준 없이 자기중심 AoE(데모 단순화).
- **DRIFT-001 관계:** 자작 서브 `AB-S01~04`는 이제 **미사용**(서브=스킬북 구동, spec 모델 정합). DRIFT-001 "AB-S0x→spec 서브 정합" 과제는 본 구현으로 **실질 대체**(Shared 적 AB 3종 사용); AB-S01~04 정의는 abilities.json에 잔존(orphan, 후속 정리 가능).
- **잔여:** 추출 정산이 At-Risk 스킬북을 실제 Safe/Loss로 처리하는 F-007 배선 미구현(장비와 동일). 분석·상점·affix·tier(F-009 §3.3/§3.5)는 허브 메타 후속. 풀 D-018 인스턴스(instanceId·affix)·Range/Family 게이트 미구현.

### DRIFT-027 — 소모품 시스템 + 부활 스크롤 (인-런 부활) ✅ MERGED (b84e975 · DEC-20260611-003)
- **구현(2026-06-11):** F-010 소모품 데모. `consumables.json` 1종(`con_revive_scroll` 부활 스크롤, `max_stack` 3, `usable_in_combat` false, `effect` revive_ally). 인벤 1×1 **스택 아이템**(시드 3장=1스택), **Z/X/C 핫키**(party-shared) — 등록: 인벤에서 **소모품 호버 + Z/X/C** 또는 **바에 드래그**. **6시 캐릭터 시트 위 `ConsumableBar`**(3슬롯, 할당 소모품+보유수 표시). **부활(타겟+채널)**: Z/X/C → **타겟팅**(죽은 아군 **월드 시체 ray** 또는 **파티시트 초상화** 클릭, 우클릭/Esc 취소·재입력 토글) → **1.5s 빛기둥 채널**(`SkillVfx.revive_pillar`) → `party_member.revive(0.5)`(HP 50%)+소모1. **휴식중(`not is_engaged()`)만**. 핫키 **유니크**(1슬롯)·호버+동일키 토글해제·바슬롯 드래그(다른슬롯 이동/밖 해제). 인벤 열림 중 Z/X/C=핫키 등록(use와 분리).
- **분류/전파:** scope/idea — **인-런 부활은 spec과 결이 다름**: `F-007` §3.6.1은 "`AwaitingRevive`/`ReviveOffer` 부활 경제를 소유하지 않으며 도입하지 않는다"(추출 정산 `ExtractCasualty` 한정). 본 구현은 hub/추출 경제가 아니라 **런 중 다운→소모품 부활**이라 직접 위반은 아니나 정합 필요. `con_revive_scroll`은 `D-020` 카탈로그 미등재. **PENDING-PROP 후보** → F-010(소모품 use 입력·효과)/D-020(부활 소모품)/F-007(인-런 부활 경계) 정합 시 OPS_30. 인벤/월드루프(DRIFT-023/024)와 동급의 "신규 시스템 데모 → 전파 후보".
- **tuning/impl:** 부활 HP 50%·스택 3·핫키 Z/X/C·바 위치(시트 위 ~110px)는 데모값. 드래그-프리뷰 미구현(호버+키/드롭 등록만). 게임 사용 피드백은 콘솔 print(전투중/대상없음).
- **전파 결과(✅ MERGED, b84e975 · DEC-20260611-003):** `D-020` `con_revive_scroll` + `F-010` §3.4 인-런 부활 범주 + `F-007` §3.6.1 경계(허브 `AwaitingRevive`/`ReviveOffer` 경제와 별개·탈출 전 부활자≠ExtractCasualty)로 SSOT화. 부활 HP%·채널·스택·핫키=tuning 유지. 사용자 결정: F-007 경계 명시만(본문 1급 규칙 신설 안 함).
- **잔여:** 다른 소모품(회복/해독 등 `D-020`)·전투 중 사용 입력(F-010 §3.7.1 2단 루트)·소모품 At-Risk/추출 정산 미구현.

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

### DRIFT-035 — 전투 진형: 탱커 선공 게이트 + 2선 딜러 + DPS 원거리화 ✅ 전파+재핀
- **현실/의도(2026-06-16):** 자동전투에서 비조작 딜러(DPS/Nuker)가 탱커보다 먼저 적에게 돌진·교전 → 분대 컨셉(탱커 전선·딜러 후열) 위배. 사용자 결정: **탱커 첫타를 게이트**로, 2선=측면.
- **구현(게임 레포):**
  - **탱커 선공 게이트:** `CombatController._deal_damage`에서 탱커 첫 피해 → `_tank_engaged`=true + `tank_engaged` 시그널. 디스인게이지(`_refresh_party_in_combat` any=false) 시 리셋. AI DPS/Nuker는 게이트 전까지 `_tick_party_attacks`에서 평타·Identity 보류 + `PartyController` engage 루프에서 대형 이탈(접근) 보류(시그널-래치 `_tank_engaged`). **조작캐 예외**(is_controlled), **탱커 사망 시 게이트 개방**(딜러 자유).
  - **2선 포지셔닝(`CombatPositioning.engage_target`):** 원거리(basic_range>3.5m)=대형 슬롯 유지(백라인, 사거리 내 자동공격) / 근접=탱커→적 축의 **수직(측면)** melee reach 지점(전면·추월 금지). 힐러=기존 부상자 지원 유지.
- **분류/전파:** **✅ 행동 규칙(탱커 선공·2선 딜러) 전파 완료 → F-004 §3.5 신설(DEC-20260616-001, spec `0edf55c`) + spec_ref 재핀.** 스킬=F-005·위협=F-022 참조. **DPS basic_range 2.0→10.0=tuning(로깅만, 전파 안 함)** — DPS=원거리 광역 설계와 정합(데이터가 근접으로 박혀 있던 불일치 교정).
- **잔여:** 탱커 자동 전진(앵커일 때 전선 진입)은 명시 로직 없음 — 전열 슬롯+파티 전진에 의존. 근접 측면 side-flip 미세 지터 가능. 원거리 사거리 10m=잠정 튜닝값.

### DRIFT-036 — 카메라 RMB 세로 드래그 = pitch 틸트(인버트) ✅ 전파+재핀
- **현실/의도(2026-06-16):** 기존 RMB 드래그=yaw(수평)만. 사용자 요청으로 **RMB 세로 드래그(Δy)→카메라 pitch** 추가(인버트), 피치 범위 15~85°(저각 시네마틱↔거의 탑다운).
- **구현(게임):** `camera_rig.pitch_by_drag(dy)` — `_pitch ± dy*PITCH_DRAG_SENS(0.15)` clampf(PITCH_MIN 15·PITCH_MAX 85) + `_apply_placement`. dungeon_run RMB 모션에서 yaw(Δx)+pitch(Δy) 동시(자유 오빗). 저각 가림=wall_xray see-through.
- **분류/전파:** **✅ 규칙(RMB Δy=pitch 틸트) 전파 → F-012 §3.1.2 신설(DEC-20260616-002, spec `0edf55c`) + §9 open Q 해소, spec_ref 재핀.** 민감도·pitch 범위·줌 수치=tuning(로깅만).
- **잔여:** 줌(거리, scroll)·전방 가중 카메라는 F-012 후속. pitch 범위/감도=잠정 튜닝값.

### DRIFT-037 — F-011 풀 GPU vision fog(Step 1-3) + 적 시야콘 GPU 재구성 + Forward+ 강제 ✅ MERGED (daa1114 · DEC-20260618-001)
- **구현(2026-06-14~16):** DRIFT-015(occlusion-only 토대)·DRIFT-018(적 perception)에서 **보류했던 풀 F-011 시야 fog**를 GPU 2D 라이팅으로 구현.
  - **파티-LOS fog**(`run/controllers/vision_fog.gd`, 332): top-down SubViewport에 멤버별 그림자캐스트 PointLight2D + 벽 LightOccluder2D → 점등영역 = 파티 union 가시폴리곤(차폐형, 거리감쇠 아님). 별도 **explored 누적 뷰포트**(CLEAR_ONCE+ADD, `fog_accumulate.gdshader`)=기억(한 번 본 곳은 무채색 저채도 잔존). 공유 `vision_fog.gdshader`를 월드 메쉬 `next_pass`로 붙여 **3D 적용**(각 메쉬 월드XZ→fog UV, **depth 텍스처 재구성 없음** — 두 번 실패했던 부분 회피). V=디버그 오버레이, B=3D fog A/B.
  - **적 시야콘 GPU 재구성**(`run/controllers/enemy_vision_overlay.gd`, 206): 기존 레이팬 콘(벽 엣지 떨림)을 fog와 동일 기법으로 교체 — 적별 섹터 PointLight2D + 벽 occluder → 벽서 정확 클립되는 union 마스크, 지면 quad가 샘플(빨강 전투/노랑 경계). fog cur-LOS로 게이트(가시영역만 표시).
  - **렌더러 Forward+ 강제**(`project.godot` `rendering_method="forward_plus"`): 2D 라이팅 그림자 + 셰이더 next_pass가 Compatibility 백엔드 미동작 → Forward+ 전환. **결과: web(HTML5) export 차단**(Compatibility 전용). ARCHITECTURE §6 `DEBT-PLAT-FWD`.
- **분류/전파:** **scope/impl + rule(제약).** DRIFT-015는 "풀 F-011 전파는 정식화 때 OPS_30"으로 명시 보류 → 본 구현으로 그 조건 충족. ① fog 가시모델(union LOS·explored 기억)을 **F-011에 확정**하거나 "demo subset" 명시 ② **Forward+/web-export-차단**은 플랫폼/타겟 **제약 변경**(ChangeProtocol §1 constraints) → QA-031/contract 또는 플랫폼 스코프에 반영. **PENDING-PROP** → spec repo OPS_30(F-011 + SpecScopeTracker + QA) + **사용자 플랫폼 결정**(web 타겟 포기 수용 여부).
- **전파 결과(✅ MERGED, daa1114 · DEC-20260618-001, spec 4422e50):** ① fog 가시모델 — **F-011 §3.0 Explored Memory · §3.3 차폐형 가시 마스크 · §5 적 시야콘 바닥 오버레이**로 정식화(거리감쇠 아님, "미탐색 FoW 없음" §1 정합). ② **Forward+/web-export 차단은 사용자 결정으로 spec 비대상(impl-only)** — 게임 `ARCHITECTURE.md` DEBT-PLAT-FWD에만 잔존, 스펙 미반영(DEC alternatives B 기각). 게임 `spec_ref.json` 재핀 `4422e50`(Phase 2). 잔여 미구현(광원 합집합·perceptionProfile 차등·Patrol·미니맵 레이어)은 1b 현황 노트로 F-011에 명시.
- **tuning/impl(전파금지):** fog PX_PER_M 12·SIGHT_RADIUS 64m·MAX_LIGHTS 4·OCCLUDER_INSET 0.15, 시야콘 PX_PER_M 8·CULL 32m·MAX_LIGHTS 16·overlay alpha 0.03·색(빨강/노랑). 셰이더 3종(vision_fog/fog_accumulate/enemy_vision_overlay).
- **관련 아이디어:** "시야콘 상시표시 → 가시화 소모품/UI"(OPS_08 미등록). 적 시야콘 오버레이는 현재 개발용 상시 on.
- **잔여:** fog 동적 occluder(움직이는 벽/문 개방 미반영)·멀티층·성능(UPDATE_ALWAYS 2 뷰포트). 시야콘 16개 캡.

### DRIFT-038 — F-012 wall x-ray(카메라↔캐릭 벽 투과) ✅ MERGED (daa1114 · DEC-20260618-001)
- **구현(2026-06-16):** 카메라 저각 pitch(DRIFT-036, `camera_rig` PITCH_MIN 30→15)에서 벽/장애물이 파티를 가리는 문제 → **see-through 벽 투과**(`run/controllers/wall_xray.gd`, 92): 매프레임 카메라→**생존 멤버 전원** 레이캐스트(벽 레이어 1, 최대 5겹)→히트 벽 머티리얼 알파 0.16 페이드 + F-011 fog `next_pass` 임시 제거(이중 어둡힘 방지), 비차폐 시 복원. `camera_rig` 주석에 "PITCH_MIN lowered from 30; wall_xray handles wall occlusion".
- **분류/전파:** **rule/impl.** DRIFT-036(RMB pitch 틸트, ✅ F-012 §3.1.2 전파)의 **직접 후속** — 저각 카메라가 만든 가림을 해소하는 카메라 가시규칙. F-012에 "카메라 가림 처리(see-through/페이드)" 절 신설 후보. 단독으론 표현 휴리스틱(impl)에 가까워 **전파 여부 사용자 판단** 필요. **PENDING-PROP** → spec repo OPS_30(F-012 §3.x) 또는 impl-only(`ImplDecisionLog`)로 종결.
- **전파 결과(✅ MERGED, daa1114 · DEC-20260618-001, spec 4422e50):** F-012 §3.x 신설 대신 **F-011 §3.3.1 Camera Occlusion See-Through**로 정식화 — F-012 §3.1.2(저각 카메라)가 가림 처리를 시야/엄폐 소유자 **F-011에 위임**(역참조 정밀화, related 양방향). see-through=**표현(렌더) 처리**로 명시(충돌·LOS·적 perception 판정 불변). 수치(XRAY_ALPHA·MAX_OCCLUDERS)=tuning 유지. 게임 `spec_ref.json` 재핀 `4422e50`.
- **tuning/impl(전파금지):** XRAY_ALPHA 0.16·MAX_OCCLUDERS 5·WALL_LAYER 1. 투과 대상=StandardMaterial3D 가진 벽만.
- **잔여:** 아웃라인/블러 폴리시·카메라-룸 fog(파일 헤더 "follow-up polish") 미구현.

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
- **부분/미구현(정직):** ① **HEX-WEAK "피해 감소" 절반 미구현** — 이동감소(slow)만; 파티 outgoing-damage 훅 필요 → 후속. Shock·Hex 둘 다 slow로 표현(색/지속/소스로 구분). ② AB-008 `chains_to_status: Slippery`·AB-009 Oil SEED·zone 시스템 = 미구현(스플래시 직격만). ③ **interrupt-on-channel**(채널 중 stun→쿨 전액 소모, EN-AI-000 §2) 미구현 — 현재 stun이 적 채널을 끊지 않음.
- **잔여:** AB-006/013 대시(mobility) · AB-099 Provoked(party-side 상태) = S2c(2/3). **교전 체감 F5 수동 검증 잔여**.

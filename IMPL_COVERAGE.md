# Implementation Coverage

> Non-SSOT. Phase 2 스프린트 종료마다 갱신. 정본 스코프는 spec `docs/context/ImplementationPhase_FullSpecCoverage.md`. 실행 로드맵: [docs/ROADMAP_P2_FullCoverage.md](docs/ROADMAP_P2_FullCoverage.md).

- spec_ref_pin: `4422e50` (`staging`, 2026-06-18)
- last_sprint: P2-S2-fin **Track A 완료** (A1 조합 ENC·A2 phase 증원·A3 assassin·A4 MiniBoss — ENC 12→17/24, navmesh 284). 다음: P2-S2-place(PAT/AMB) 또는 P2-S3(Interaction)
- last_updated: 2026-06-19

## Full Spec Coverage — AB-### 스냅샷 (2026-06-19)

전체 스펙 어빌리티 **AB-### 15/84**. 적 전투행동(EN-001~014)은 완료지만 AB 전체·ENC·zone은 진행 중 (상세·로드맵: [ROADMAP](docs/ROADMAP_P2_FullCoverage.md)).

| 군 | 구현/전체 | 미구현 핵심 |
|----|:---:|------|
| 적 kit (비-zone) | 10/13 | AB-003·005·007 (대체평타·연타후속·후퇴hop) |
| 적 zone/원소 | 0/7 | AB-009/036/039/040/041/042/043 — **F-027 ZONE 서브시스템(P2-S3)** |
| 파티 능력 풀 | 5/64 | ~48 lootable sub(데이터행+~11 신규 effect kind) + 6 identity 후보 (P2-S6) |
| 적 기본타 rom_* (별도) | 12/12 | — |
| PT-### 적 패턴 (별도) | 14/14 | — |

## Sprint log

| Sprint | Done | Notes |
|--------|------|-------|
| P2-S1 | ◐ | S1a~e 완료 + 헤드리스 검증 통과. S1f 문서 완료 · **인터랙티브 Hard 플레이 스모크(§9.1)는 F5 수동** 잔여 |
| P2-S2 | ◐ | S2a~c(1~4): 적 **전투행동 축** 완료+헤드리스 PASS (ID 1:1·포지셔닝·시그니처 캐스트·대시·Provoked·§2 interrupt). EN-001~014 행동 kit 반영. |
| P2-S2-fin | ☑ | **Track A 완료** — A1 조합 ENC(HARD-002/003/004)+Upper 룸·A2 phase 증원 rear/flank(HARD-005·010)·A3 AssassinTransform(NORM-003·011)·A4 MiniBoss(BOSS-001 ccTenacity+50%HP 페이즈). ENC 12→17/24, navmesh 244→284, 헤드리스 PASS. **잔여(P2-S2 스펙):** PAT/AMB=placement 레인 · 3RD=faction · 적 zone AB(F-027/P2-S3) · 교전 체감 F5 |

## P2-S2 checklist (combat redesign)

| ID | Item | Status |
|----|------|--------|
| S2a | Combat ID 1:1 — rom_* basics·비-spec AB 제거·EN-014 Gutter Chanter·ENC-NORM-001 | ☑ 커밋 186a024 (헤드리스) |
| S2b | Per-enemy 포지셔닝 — patterns.json(PT-### 미러)·`engage` 7프로필·enemy_ai 분기 | ☑ 헤드리스 PASS · **체감 F5 잔여** (2210d30) |
| S2c-1 | 시그니처 캐스트 — AB-004 차지·AB-008 스플래시·AB-012 헥스·**AB-098 EN-014 힐**(+channel-freeze) | ☑ 헤드리스 PASS · **체감 F5 잔여** |
| S2c-2 | AB-006/013 대시 (EN-003 갭클로즈 · EN-008 백스탭 mobility) | ☑ 헤드리스 PASS · **체감 F5 잔여** |
| S2c-3 | AB-099 Iron Mockery / **Provoked** (EN-001 존 도발 + party-side 상태 + 입력 게이트) | ☑ 헤드리스 PASS · **체감 F5 잔여** |
| S2c-4 | 채널 interrupt + 적 stun primitive (EN-AI-000 §2 — Toll Stun으로 채널 끊기) | ☑ 헤드리스 PASS · **체감 F5 잔여** |

> S2b engage 맵: advance(EN-001/010/012/013)·standoff(EN-002/007/011)·kite(EN-005/014)·zone(EN-004)·orbit(EN-003/008)·probe(EN-006)·surround(EN-009). PT-### 정본=EN 유닛문서 patternRef(EN-010~013→PT-012~015). 상세 DRIFT-040.

## P2-S1 checklist (game)

| ID | Item | Status |
|----|------|--------|
| S1a | AGENTS v2 · IMPL_COVERAGE · spec_ref bump | ☑ (2026-06-18) |
| S1b | spawn_table + Slice01Data resolver (override>exact>pool+diff) | ☑ 헤드리스 검증 |
| S1c | rooms.json ≥12 · world_layer · map layout (겹침0·연결 navmesh 244폴리) | ☑ 헤드리스 검증 |
| S1d | encounter JSON 9 + EN 스텁 6 + id_registry | ☑ |
| S1e | run_controller data-driven phase (monotonic SEQUENCE) | ☑ 5단계 전환 검증 |
| S1f | 헤드리스 검증 · IMPL_COVERAGE · SPEC_DRIFT | ◐ docs 완료, 수동 스모크 잔여 |
| — | Recovery revisit (D6) | **deferred** DRIFT-031 |

## Spawn table (LDG-SPAWN-DEMO-001) — 헤드리스 prespawn resolve 검증

| poolSlot | world_layer | Normal | Hard | spawned (in-engine) |
|----------|-------------|--------|------|---------------------|
| P-ENTRY-01 | Upper | ENC-NORM-002 | — | ☑ Normal |
| P-ADV-01 | Upper | ENC-NORM-001 (force) | ENC-NORM-001 (force) | ☑ 양쪽 |
| P-ADV-02 | Upper | — | ENC-HARD-006 | ☑ Hard |
| P-ADV-03 | Upper | — | ENC-HARD-010 | ☑ Hard |
| P-ADV-04 | Upper | — | ENC-HARD-011 | ☑ Hard |
| P-ADV-05 | Upper | — | ENC-HARD-012 | ☑ Hard |
| P-EXT-ROUTE-01 | Upper | — | ENC-HARD-009 | ☑ Hard |
| P-MID-01 | Mid | ENC-MID-001 | ENC-HARD-008 | ☑ 양쪽 |
| P-DEEP-01 | Deep | ENC-DEEP-001 | — | ☑ Normal |
| P-BOSS-01 | Mid | — | ENC-BOSS-001 | ☑ Hard |

> D4 (MID/DEEP/BOSS 각 1회 스폰): **Normal=MID-001+DEEP-001 / Hard=BOSS-001** — LDG 테이블 충실(단일 런이 셋 다는 아님). force override(P-ADV-01→NORM-001)가 Hard 행(HARD-001)을 가려 ENC-HARD-001은 로드되나 미스폰. manifest.encounters는 legacy fallback(resolver가 정본).

## Regression (1b — must stay green)

| Feature | Status |
|---------|--------|
| Hub deploy + RunLoadout | ☑ 헤드리스 hub load clean |
| Key-gate objective + extract | ◐ 구조 불변(door→complete_objective·can_extract 미변경) · F5 스모크 잔여 |
| PartyWipe → Run Failure | ◐ 미변경 · 스모크 잔여 |
| Inventory / gear / skillbook | ◐ 미변경 |
| Vision fog + enemy AI | ◐ 미변경 · navmesh 재베이크 정상 |

## Known drift

| DRIFT | Summary |
|-------|---------|
| 031 | Recovery persistence/revisit deferred (P2-S1 밖) |
| 037/038 | F-011 fog · See-Through ✅ MERGED (daa1114 · 재핀 4422e50) |
| 039 | P2-S1 dungeon scale — EN-002/003/004/007/008/009 스텁·ENC 9 스텁·맵 placeholder 기하 (kit·폴리시=P2-S2) |
| 040 | P2-S2b per-enemy 포지셔닝 — PT-### `engage` 파생·이동 PH 튜닝. 교전 체감 F5 잔여 |
| 041 | P2-S2c-1 시그니처 캐스트 — AB-004/008/012/098 + channel-freeze. HEX 피해감소·interrupt·zone = 후속. F5 잔여 |
| 042 | P2-S2c-2 대시 mobility — AB-006/013. 벽 라우팅·AB-005 flurry·AB-007 hop = 후속. F5 잔여 |
| 043 | P2-S2c-3 AB-099 Provoked — EN-001 존 도발 + party 상태. AB-031 클렌즈 = 후속. F5 잔여 |
| 044 | P2-S2c-4 채널 interrupt + 적 stun — Toll Stun으로 채널 끊기. 적 stun VFX = 후속. F5 잔여 |

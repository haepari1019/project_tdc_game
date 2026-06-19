# Implementation Coverage

> Non-SSOT. Phase 2 스프린트 종료마다 갱신. 정본 스코프는 spec `docs/context/ImplementationPhase_FullSpecCoverage.md`.

- spec_ref_pin: `4422e50` (`staging`, 2026-06-18)
- last_sprint: P2-S2 (S2a/S2b/S2c-1 커밋 · S2c-2 대시 구현 · 교전 체감 F5 user-pending · S2c-3 Provoked 잔여)
- last_updated: 2026-06-19

## Sprint log

| Sprint | Done | Notes |
|--------|------|-------|
| P2-S1 | ◐ | S1a~e 완료 + 헤드리스 검증 통과. S1f 문서 완료 · **인터랙티브 Hard 플레이 스모크(§9.1)는 F5 수동** 잔여 |
| P2-S2 | ◐ | S2a 커밋(186a024) · S2b 구현+헤드리스 PASS. **교전 포지셔닝/적 기본타 체감 F5 수동** 잔여 · S2c(시그니처 AB+Provoked) 미착수 |

## P2-S2 checklist (combat redesign)

| ID | Item | Status |
|----|------|--------|
| S2a | Combat ID 1:1 — rom_* basics·비-spec AB 제거·EN-014 Gutter Chanter·ENC-NORM-001 | ☑ 커밋 186a024 (헤드리스) |
| S2b | Per-enemy 포지셔닝 — patterns.json(PT-### 미러)·`engage` 7프로필·enemy_ai 분기 | ☑ 헤드리스 PASS · **체감 F5 잔여** (2210d30) |
| S2c-1 | 시그니처 캐스트 — AB-004 차지·AB-008 스플래시·AB-012 헥스·**AB-098 EN-014 힐**(+channel-freeze) | ☑ 헤드리스 PASS · **체감 F5 잔여** |
| S2c-2 | AB-006/013 대시 (EN-003 갭클로즈 · EN-008 백스탭 mobility) | ☑ 헤드리스 PASS · **체감 F5 잔여** |
| S2c-3 | AB-099 Iron Mockery / **Provoked** (EN-001 party-side 상태 + 입력 게이트) | ☐ 미착수 |

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

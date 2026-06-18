# Implementation Coverage

> Non-SSOT. Phase 2 스프린트 종료마다 갱신. 정본 스코프는 spec `docs/context/ImplementationPhase_FullSpecCoverage.md`.

- spec_ref_pin: `4422e50` (`staging`, 2026-06-18)
- last_sprint: P2-S1 (구현 완료 · Hard 플레이 스모크 user-pending)
- last_updated: 2026-06-18

## Sprint log

| Sprint | Done | Notes |
|--------|------|-------|
| P2-S1 | ◐ | S1a~e 완료 + 헤드리스 검증 통과. S1f 문서 완료 · **인터랙티브 Hard 플레이 스모크(§9.1)는 F5 수동** 잔여 |

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

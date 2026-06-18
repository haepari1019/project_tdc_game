# Implementation Coverage

> Non-SSOT. Phase 2 스프린트 종료마다 갱신. 정본 스코프는 spec `docs/context/ImplementationPhase_FullSpecCoverage.md`.

- spec_ref_pin: `4422e50` (`staging`, 2026-06-18)
- last_sprint: P2-S1 (착수)
- last_updated: 2026-06-18

## Sprint log

| Sprint | Done | Notes |
|--------|------|-------|
| P2-S1 | ☐ | S1a 완료 · S1b~f 진행 예정 — spec `Sprint_P2-S1_DungeonScale.md` |

## P2-S1 checklist (game)

| ID | Item | Status |
|----|------|--------|
| S1a | AGENTS v2 · IMPL_COVERAGE · spec_ref bump | ☑ (2026-06-18) |
| S1b | spawn_table + Slice01Data resolver | ☐ |
| S1c | rooms.json ≥12 · world_layer · layout | ☐ |
| S1d | encounter JSON (LDG §3 rows) | ☐ |
| S1e | run_controller data-driven (룸 ref 하드코딩 제거) | ☐ |
| S1f | Hard smoke · D5 regression | ☐ |
| — | Recovery revisit (D6) | **deferred** DRIFT-031 |

## Spawn table (LDG-SPAWN-DEMO-001)

> 목표 resolver: `difficultyProfile` × `world_layer` × `poolSlot` → `encounterRef`.
> 현재 `manifest.json`은 difficulty/layer 없는 flat 바인딩 3행(아래 ☑) — S1b에서 spec LDG-SPAWN-DEMO-001 §3 전 행으로 확장.

| poolSlot | difficulty | world_layer | ENC expected | spawned |
|----------|------------|-------------|--------------|---------|
| P-ENTRY-01 | Normal | Upper | ENC-NORM-002 | ☑ (현 manifest) |
| P-ADV-01 | Normal | Upper | ENC-NORM-001 | ☑ (현 manifest) |
| P-ADV-02 | Hard | Upper | ENC-HARD-001 | ☑ (현 manifest) |
| _(… spec LDG-SPAWN-DEMO-001 §3 나머지 행 — MID/DEEP/BOSS 포함)_ | | | | ☐ |

## Regression (1b — must stay green)

| Feature | Status |
|---------|--------|
| Hub deploy + RunLoadout | ☐ |
| Key-gate objective + extract | ☐ |
| PartyWipe → Run Failure | ☐ |
| Inventory / gear / skillbook | ☐ |
| Vision fog + enemy AI | ☐ |

## Known drift

| DRIFT | Summary |
|-------|---------|
| 031 | Recovery persistence/revisit deferred (P2-S1 밖) |
| 037/038 | F-011 fog · See-Through ✅ MERGED (daa1114 · 재핀 4422e50) |

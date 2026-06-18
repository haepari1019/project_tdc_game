# AGENTS.md — Game repository

## Overview

Godot **4.5.1** implementation for **Project TDC** (`project.godot` features: 4.5). Design SSOT lives in **`project_tdc`** (GitHub: `haepari1019/project_tdc`, branch `staging`). Do not duplicate `F-###` / `D-###` rule text here.

## Spec contract (project_tdc_spec)

- **SSOT 레포:** `E:/Game_design/project_tdc_spec` (`staging`). Pin: [`spec_ref.json`](spec_ref.json).
- **Phase:** `implementation_phase` in spec_ref — **1b playable done**; active sprint **P2-S1** (dungeon scale).
- **Phase 2 policy:** spec `docs/context/ImplementationPhase_FullSpecCoverage.md` — implement the full spec catalog over time; **do not** cap work to Slice-01 / 6-room demo / `QA-030` non-goals alone.
- **Current sprint:** spec `docs/context/Sprint_P2-S1_DungeonScale.md` + `docs/context/GameRepo_Baseline_P2-S1.md`.
- **Game architecture map:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — read before run/map/spawn changes.
- **Coverage:** maintain [`IMPL_COVERAGE.md`](IMPL_COVERAGE.md) at end of each sprint.
- **Drift:** [`docs/SPEC_DRIFT.md`](docs/SPEC_DRIFT.md) + [`docs/impl_decisions/ImplDecisionLog.md`](docs/impl_decisions/ImplDecisionLog.md). No silent spec divergence.

### ID contract (hard rule)

- Code/data string IDs match spec **1:1** — `tank_anchor_guard`, `ENC-NORM-001`, `DBP-DEMO-001`, etc. No aliases.
- Unregistered IDs → **abort at load** (`require_id`). New spec IDs introduced by a sprint must be registered in `data/slice01/id_registry.json` before use.

### Do NOT (scope)

- Reject tasks because "not in Slice-01" or "only DBP-DEMO-001 6 rooms".
- Re-implement 1b systems already in game (hub, key-gate, extract settlement, inventory, vision fog, enemy AI) — **extend** `data/slice01` + resolver instead.
- Implement Recovery Marker / revisit (`F-007` §3.3) in P2-S1 — **deferred** (DRIFT-031).

### Context load order

1. `GameRepo_Baseline_P2-S1.md` (spec repo)
2. `Sprint_P2-S1_DungeonScale.md` (spec repo)
3. This repo `ARCHITECTURE.md` + `data/slice01/manifest.json`
4. Target `F-###` / `LDG-SPAWN-DEMO-001` / encounter JSON in spec repo

### P2-S1 Definition of Done (summary)

- Spawn resolver: `difficultyProfile` × `world_layer` × `poolSlot` → `encounterRef` (`LDG-SPAWN-DEMO-001`)
- Map ≥12 rooms, Upper/Mid/Deep layers
- All non-empty LDG spawn rows resolve; MID/DEEP/BOSS **spawn** once (combat polish → P2-S2)
- Key-gate extract **regression pass**
- `IMPL_COVERAGE.md` updated; `spec_ref` bumped after spec merge

## This repo owns

- `project.godot`, scenes, scripts
- `data/` runtime manifests (derived from spec)
- `assets/` art/audio

## Do not

- Edit spec markdown in this repo (use spec repo + OPS workflow).
- Copy full feature specs into comments or duplicate SSOT.

## Spec drift & propagation (구현 → 스펙 역전파) — **MANDATORY**

구현 중 동작/데이터/스코프가 **스펙(SSOT)과 달라지면 침묵하지 말고 반드시 분류·트래킹**한다. 누적 드리프트는 spec을 거짓으로 만든다.

**1. 분류** (spec repo `docs/context/ChangeProtocol.md` 기준):
- **튜닝 수치** (스킬/적 수치 등 spec이 "design example, runtime SSOT 아님"이라고 명시한 값) → 게임 데이터에서 자유 조정. **전파 금지**, [docs/SPEC_DRIFT.md](docs/SPEC_DRIFT.md)에 **로깅만**.
- **아이디어/판단 보류** ("이거 바꿀까?", 플레이 피드백) → spec repo `OPS_08` → `docs/ideas/I-002_DemoValidationFeedback`. SSOT 아님, 전파 안 함.
- **규칙·필드·enum·AC·의존·스코프 변경** (F-###/UI-###/D-###/QA-### 경계) → **진짜 spec 변경**. 아래 절차.

**2. 절차 (규칙 변경 시):**
1. **이 레포에서 spec md 직접 편집 금지.** spec repo(`staging`)에서 대상 SSOT 문서 편집.
2. spec repo에서 `OPS_30`(impact_scan → 매퍼×4 → DecisionLog `DEC-` → TODO → SpecScopeTracker) 실행 → `OPS_20`(lint) → `staging` PR.
3. spec 변경이 `staging`에 반영되면 이 레포 [`spec_ref.json`](spec_ref.json) 핀을 bump하고, 런타임 ID/enum을 1:1로 맞춘다. **이 핀 갱신이 이 레포가 하는 유일한 spec-관련 쓰기.**

**3. 항상:**
- 드리프트는 발견 즉시 [docs/SPEC_DRIFT.md](docs/SPEC_DRIFT.md)에 기록(`DRIFT-###`).
- 코드/구현 측 결정은 [docs/impl_decisions/ImplDecisionLog.md](docs/impl_decisions/ImplDecisionLog.md)(`IMPL-DEC-`)에 기록.
- **Stop Line:** 파일 편집·커밋·전파·PR은 사용자 명시 승인("반영해/패치해/진행해/커밋해") 후에만. 모호하면 분석만 하고 먼저 묻는다.

## Git

- Default branch: `main`
- Commit messages: `feat:`, `fix:`, `data:`, `scene:` prefixes encouraged.

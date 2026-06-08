# CLAUDE.md — project_tdc_game

이 레포의 에이전트 가이드는 [AGENTS.md](AGENTS.md)가 정본이다. 먼저 읽을 것.

## 시작 전
1. [`spec_ref.json`](spec_ref.json) — 핀된 spec 커밋 확인.
2. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — 코드 구조·책임·기술부채 지도.
3. ID 1:1, 미등록 ID → abort (AGENTS.md §Before coding).

## ⚠️ 절대 규칙 — Spec drift propagation
구현이 spec과 달라지면 **반드시** 분류·트래킹한다 (상세: [AGENTS.md](AGENTS.md) §Spec drift & propagation):
- **튜닝 수치** → [docs/SPEC_DRIFT.md](docs/SPEC_DRIFT.md) 로깅만.
- **아이디어/피드백** → spec repo `OPS_08` / `I-002`.
- **규칙·필드·enum·스코프 변경** → spec repo에서 SSOT 편집 + `OPS_30` 전파 → `spec_ref.json` 재핀. **이 레포에서 spec md 편집 금지.**
- 드리프트는 [docs/SPEC_DRIFT.md](docs/SPEC_DRIFT.md), 코드 결정은 [docs/impl_decisions/ImplDecisionLog.md](docs/impl_decisions/ImplDecisionLog.md)에 기록.
- **Stop Line:** 편집·커밋·전파·PR은 명시 승인 후에만.

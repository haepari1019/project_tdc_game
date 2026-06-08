# ImplDecisionLog — 코드/구현 측 결정 기록

> **무엇:** 게임 레포의 **구현 측** 결정(아키텍처·리팩토링·핀·근사치)을 남긴다. 스펙 규칙 변경은 여기가 아니라 spec repo `DecisionLog.md`(`DEC-`)에 기록한다.
> **기록 대상:** 비자명한 구조/접근 결정, 의도적 근사, 핀 변경, 되돌리기 어려운 선택. **비대상:** 단순 버그픽스·오타·자명한 구현.
> **형식:** `IMPL-DEC-YYYYMMDD-### · 결정 · 이유 · 대안 · 영향 파일`

---

### IMPL-DEC-20260608-001 — 코드 구조 지도 + 드리프트 거버넌스 도입
- **결정:** [docs/ARCHITECTURE.md](../ARCHITECTURE.md)(모듈 책임 + 기술부채 레지스터)와 [docs/SPEC_DRIFT.md](../SPEC_DRIFT.md)(드리프트 대장) 신설, [AGENTS.md](../../AGENTS.md)/[CLAUDE.md](../../CLAUDE.md)에 spec 역전파 규칙 고정.
- **이유:** 코드가 덧붙이기로 누적되며 스파게티/스펙 이격 위험. 단일 지도 + 강제 트래킹으로 방지.
- **대안:** 폴더별 README만 유지(분산·드리프트 탐지 불가) — 기각.
- **영향:** `docs/ARCHITECTURE.md`, `docs/SPEC_DRIFT.md`, `AGENTS.md`, `CLAUDE.md`.

### IMPL-DEC-20260608-002 — 스펙 핀 재정렬 cd6009e → 262d8bb
- **결정:** `spec_ref.json`·`id_registry.json` 핀을 staging HEAD `262d8bb`로 bump.
- **이유:** 게임은 이미 HEAD 상태(Identity 전원 자동, 스왑 1~4)를 구현. diff는 인런 키바인딩+Identity 자동 1건뿐(전투/어빌리티/ENC/QA-030 수치 동일). 재핀으로 "팬텀 드리프트"(DRIFT-002/003)를 정합으로 전환.
- **대안:** cd6009e 유지(코드를 Q수동/F1~F4로 되돌리기) — 스펙 진행방향과 역행, 기각.
- **영향:** `spec_ref.json`, `data/slice01/id_registry.json`.

### IMPL-DEC-20260608-003 — 리팩토링 순서: 기준선 확보 후 전체 리팩토링
- **결정:** 전체 리팩토링(party_controller 갓오브젝트 분해·v0 삭제·전투상태 단일소유)을 수행하되, **게이트차단 수정 → 반복가능 검증 기준선 확보 → 리팩토링 → 검증 재확인** 순서로.
- **이유:** 라이브 전투/스티어링 흐름은 한 번도 공식 검증되지 않음. 기준선 없이 1623줄을 분해하면 회귀와 기존버그 구분 불가.
- **대안:** 리팩토링 선행 — 회귀 판별 불가로 기각. 게이트 후로 무기한 연기 — 1b 확장이 부채 위에 쌓이므로 기각.
- **영향:** (예정) `scripts/party/*`, `scripts/combat/*`, `scripts/core/unit_visuals.gd`(신규).

### IMPL-DEC-20260608-004 — 인카운터 재바인딩 + 어빌리티 id 검증 (P3)
- **결정:** ① `manifest` `P-ADV-01 → ENC-NORM-001`(스펙 필수·게이트 복원), `RM-ADV-02`에 `pool_slot: P-ADV-02` + `P-ADV-02 → ENC-HARD-001`(선택 전투로 보존) — DRIFT-004 "둘 다 살림". ② `id_registry.ability_ids`에 사용중 14개 AB 등록 + `slice01_data._parse_abilities`에 `require_id` + identities `sub_ability_id` 검증 — DRIFT-006.
- **이유:** ENC-NORM-001(스펙 필수)이 빌드에서 도달 불가였고, "미등록 ID→abort" 가드가 어빌리티에만 비활성이었음.
- **검증:** Godot 4.5.1 헤드리스 로드 통과(`[TDC] Hub ready — staging@262d8bb`), 검증 abort/parse 에러 없음. ENC-NORM-001 실제 전투 스폰은 F5 기준선 검증 대기.
- **영향:** `data/slice01/manifest.json`, `rooms.json`, `id_registry.json`, `scripts/core/slice01_data.gd`.

### IMPL-DEC-20260608-006 — Phase 1b 스펙 공식화 전파 + 재핀 d70ed48
- **결정:** spec 레포에 `QA-031`(Phase 1b Playable Contract) 신설 + QA-030 §7 전환 절 + DecisionLog `DEC-20260608-001` + SpecScopeTracker/TODO 갱신을 `staging`에 머지(`d70ed48`). 게임 `spec_ref.json`/`id_registry`/`manifest`를 `262d8bb`→`d70ed48`로 재핀하고 `implementation_phase: 1b` · `contract/playable_contract_id: QA-031`로 전환.
- **이유:** 사용자(2026-06-08) 결정으로 Slice-01 선언적 완료 + 1b 확장을 spec SSOT에 공식 반영(DRIFT-000/001/005). 매퍼는 QA 계약 문서 선례로 미변경.
- **검증:** Godot 헤드리스 로드 `[TDC] Hub ready — staging@d70ed48 (QA-031)` 통과.
- **영향:** (spec) QA-031/QA-030/DecisionLog/SpecScopeTracker/TODO · (game) spec_ref.json/id_registry.json/manifest.json/docs/SPEC_DRIFT.md.

### IMPL-DEC-20260608-005 — HP색 단일화 (P4, DEBT-DUP-HP)
- **결정:** `scripts/core/ui_colors.gd` 신설(static `hp_color`), party_sheet·controlled_sheet·health_bar가 공유 호출.
- **이유:** 동일 HP비율 색 램프가 3파일에 복붙되며 빌보드바와 HUD바의 노랑/빨강이 실제로 달라진 시각 버그.
- **영향:** `scripts/core/ui_colors.gd`(신규), `scripts/ui/party_sheet.gd`, `scripts/ui/controlled_sheet.gd`, `scripts/combat/health_bar.gd`.

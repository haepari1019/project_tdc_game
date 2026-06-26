# F5 Playable Contract — QA-031 / QA-005 (S7 통합 마감)

> **무엇:** Phase 1b Playable Contract(QA-031) + Combat AI 역할 거동(QA-005)의 **수용 체크리스트**.
> 이 케이스들은 **실전투 씬·전체 런이 필요**해 헤드리스 단위검증이 부적합 → F5 수동 회귀로 검증한다.
> 구조적으로 보장되는 계약(아래 §0)은 코드 참조로 대체. 세션 신규 기능 거동은 `F5_checklist_p2.md`.
> ref: spec `QA-031_Phase1b_PlayableContract.md` · `QA-005_CombatAI_MainSkillRoleGuidelines.md`.

## §0 구조적 보장 (코드 검증 — F5 불필요, FAIL-tier 계약)
- [x] **NC 서브 자동 사용 안 함** (QA-005 §2.6 · QA-031 FAIL-tier) — 파티 AI 틱(`combat_controller._process`)은 `try_identity` + `_resolve_basic`(평타)만. `cast_skillbook`(line 291)은 **플레이어 입력 전용** 메서드라 NC가 호출하지 않음. *by construction.*
- [x] **PartyWipe = Run Failure** (QA-031 §3.2 · FAIL-tier) — `run_end_controller.gd:46-48` 전원 ExtractCasualty → `_settle_failure("PartyWipe")` → `result "Run Failure"`(line 155). Success 스텁 아님. *by construction.*
- [x] **Identity 불가 → 폴백(서브 대체 없이)** (QA-005 §2.4/§2.6) — `_process`: `if try_identity(): continue` 실패 시 `_resolve_basic`(평타)로 수렴. 서브 우회 없음.

## §1 QA-005 — 비조작(NC) 역할 거동 (F5)
사전: 4역할 Identity 로드아웃으로 출격, partyInCombat=true 상태에서 관찰.
- [ ] **2.1 Identity 시전** — 비조작 파티원이 쿨/대상 충족 시 자기 Identity를 자동 시전.
- [ ] **2.4 폴백** — Identity 불가(쿨/대상부재)면 평타로 수렴(서브 자동 안 씀 = §0).
- [ ] **2.5 안전 제약** — `combat_leash_m` 초과 추격 없음, Fatal 영역 미진입(너무 멀리 안 쫓아감).
- [ ] **2.9 Healer 전진 추격 없음** — 비조작 Healer가 사거리 밖 대상에 **전진 추격하지 않고 hold**.
- [ ] **(2.2/2.3 basicTargetRule)** — 해당 identity가 LowestHpAlly/Controlled 등 타겟룰을 쓰면 그 방향으로 시전. *현 식별자 풀에 해당 룰 적용 시에만.*

## §2 QA-031 — 통합 루프 (F5)
- [ ] **3.1 스킬북 루프 (T-1B-SKILLBOOK)** — 던전 루팅 → 비전투 중 서브 슬롯 장착 → **조작 캐릭터가 Q/E/R로 발동** → 효과+쿨. (NC 자동발동 안 함 = §0)
- [ ] **3.2 전멸 = 실패 (T-1B-WIPE)** — 4인 전원 다운 → Run **Failure** 종료(=§0, 체감 확인).
- [ ] **3.3 Hard 인카운터 (T-1B-HARD)** — Hard 입장 → 상태이상(stun/poison/slow)+텔레그래프 → **전조→대응창→결과** 루프 동작.
- [ ] **3.4 출격 로드아웃 (T-1B-LOADOUT)** — 출격 전 소모품/반입품 선택(0개 출정 포함) → 런에 반영. (capacity 한도 = `F5_checklist_p2.md` B)
- [ ] **3.5 ENC-NORM-001 게이트 (T-ENC-NORM-001)** — Normal `P-ADV-01` 진입 → Tank NC가 `EN-001` 상대 hold, DPS NC가 fodder 클러스터 타겟. **자동 AB-033/Challenge Mark 없음**. `EN-011` poke 1~2회는 허용(런 전멸 아님).

## §3 헤드리스로 이미 덮은 것 (회귀 게이트)
- ci_smoke: 컴파일·부팅 · hub(QA-029) · third · party-pool(S6a, 모든 skillbook kind 이펙트 존재) · **reaction(QA-021 결정코어: primaryMedium 우선순위 + RX 매트릭스 4축)**.
- capacity 게터(군수 12/14/16·창고 20/28/36) · stash 시드 ≤ T0.

## Pass / Fail (QA-031 §5)
- **PASS:** §1·§2 핵심 F5 통과 + §0 구조 보장 + §3 회귀 없음.
- **FAIL:** NC 서브 자동 사용 / PartyWipe가 Success 종료 / 1a carry-over 회귀 / 비-spec ID 미정합. (§0가 앞 둘을 구조적으로 차단.)

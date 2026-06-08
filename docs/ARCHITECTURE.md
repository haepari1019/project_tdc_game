# ARCHITECTURE — project_tdc_game

> **목적:** 코드가 "필요할 때마다 덧붙이기"로 쌓이는 것을 막기 위한 **단일 구조 지도**.
> 각 스크립트의 책임·의존·핵심 심볼과, 알려진 **기술 부채**(중복/비효율/결합)를 한 곳에 적재한다.
> **갱신 규칙:** 스크립트를 추가/이동/삭제하거나 책임이 바뀌면 이 문서를 같은 PR에서 갱신한다. 부채를 해소하면 §6 레지스터에서 항목을 지운다.
> **최종 갱신:** 2026-06-08 · **기준 커밋:** `3b098d8` 이후 작업 트리 · 라인수는 작성 시점 기준.

---

## 1. 레포 토폴로지 (3-레포)

| 레포 | 역할 | 위치 |
|------|------|------|
| **project_tdc_game** (이 레포) | 구현: 씬·스크립트·런타임 데이터·에셋 | `E:/Game_design/project_tdc_game` (`main`) |
| **project_tdc** (spec) | 설계 SSOT (docs-only). 규칙·F-###/D-### 본문 | `E:/Game_design/project_tdc_spec` (`staging`) |
| **project_tdc_arts** | 아트·오디오 원본 | `E:/Game_design/project_tdc_arts` |

- 스펙 핀: [`spec_ref.json`](../spec_ref.json) → spec 커밋 고정. **이 레포는 spec 마크다운을 편집하지 않는다** ([AGENTS.md](../AGENTS.md) §Spec drift & propagation).
- 데이터는 spec에서 파생되어 [`data/slice01/`](../data/slice01/)에 런타임 자원으로 적재된다.

---

## 2. 부트 & 런타임 흐름

```text
[Autoload]  GameBootstrap ──reads──> spec_ref.json (핀 요약)
            Slice01Data   ──loads/validates──> data/slice01/*.json  (실패 시 abort)
                │
[Scene] main.tscn (main.gd) ── Slice01Data 로드 게이트 + LoadoutStub 확정 ──> 씬 전환
                │
                ▼
       dungeon_run.tscn (dungeon_run.gd = 씬 오케스트레이터)
        ├─ RunController     : 런 상태머신(phase/room) · 시그널
        ├─ MapDemoLayout     : 6룸 절차생성 + navmesh + spawn/extraction 질의
        ├─ PartyController    : 4인 스폰·스왑·결속 + 추종 스티어링(전 프레임)
        ├─ CombatController   : 인카운터 스폰 + 전투 루프 + Identity/Sub 디스패치 + Threat(F-022)
        ├─ PartyLight         : F-011 시야 결합 조명 리그
        └─ HUD (CanvasLayer)  : PartySheet · ControlledSheet · 정보패널 · ResultBanner
```

**프레임당(`_physics_process`) 핫패스:** ① CombatController가 적 AI + 파티 자동공격/스킬을 틱, ② PartyController가 추종자 스티어링을 틱. 두 시스템이 각자 `get_nodes_in_group()` 스캔과 최근접-적 계산을 **중복 수행**한다(§6 비효율 참고).

---

## 3. 모듈 맵 (도메인별 책임)

### autoload — `scripts/autoload/`, `scripts/core/`
| 파일 | L | 책임 | 핵심 심볼 | 의존 |
|------|--:|------|-----------|------|
| [game_bootstrap.gd](../scripts/autoload/game_bootstrap.gd) | 48 | `spec_ref.json` 로드, 스펙 핀 요약 노출 | `get_spec_ref` `get_spec_pin_summary` | Slice01Data |
| [core/slice01_data.gd](../scripts/core/slice01_data.gd) | 318 | `data/slice01/*` 전부 로드·검증·캐시, 타입드 게터 | `get_encounter` `get_enemy_row` `get_ability` `get_blueprint` `get_room_row` | IdValidate, JSON 파일 |
| [core/validate_ids.gd](../scripts/core/validate_ids.gd) | 16 | id 레지스트리 멤버십 검증 + 표준 에러 문자열 | `contains_id` `require_id` `unknown_id_error` | (순수함수) |

### run — `scripts/run/`
| 파일 | L | 책임 | 핵심 심볼 | 의존 |
|------|--:|------|-----------|------|
| [run_phase.gd](../scripts/run/run_phase.gd) | 16 | 5개 runPhase 문자열 상수 + 순서 | `ENTRY..EXTRACTION` `SEQUENCE` | — |
| [run_controller.gd](../scripts/run/run_controller.gd) | 124 | 런 상태(phase/room/flags), 룸진입→인카운터 트리거, objective/extraction | `start_run` `on_player_entered_room` `try_extract` | RunPhase, Slice01Data |
| [dungeon_run.gd](../scripts/run/dungeon_run.gd) | 261 | 씬 와이어링·카메라·조준UI·조작표시·HUD 라벨 갱신·입력 | `_ready` `_process` `_unhandled_input` `_on_*_changed` | 전 노드 트리, HUD 라벨경로 |
| [map_demo_layout.gd](../scripts/run/map_demo_layout.gd) | 417 | 6룸 절차생성(바닥/벽/조명/트리거)·navmesh 베이크·spawn/extraction 질의 | `ROOM_SPECS` `get_spawn_position` `get_room_profile` | NavigationServer3D, group 'player' |
| [player_controller.gd](../scripts/run/player_controller.gd) | 34 | 조작 캐릭터 WASD→velocity (가속모델 옵션) | `_physics_process` | 부모 CharacterBody3D, InputMap |
| [party_light.gd](../scripts/run/party_light.gd) | 115 | F-011 시야결합 조명(멤버별 omni+spot)·플리커·룸감쇠 | `_build_rigs` `_on_room_changed` | PartyController/Map/Run (노드경로) |
| [main.gd](../scripts/main.gd) | 34 | 허브/메뉴: 로드 게이트 + 로드아웃 + 던전 진입 | `_ready` `_on_start_pressed` | Slice01Data, GameBootstrap |

### party — `scripts/party/`
| 파일 | L | 책임 | 핵심 심볼 | 의존 |
|------|--:|------|-----------|------|
| [party_controller.gd](../scripts/party/party_controller.gd) | **1623** | ⚠️ **갓오브젝트**: 스폰·스왑·결속 + 포메이션 상태머신 + 슬롯기하 + **스티어링 v1** + **폐기 v0** + 전투교전 + 설정로더 | `try_swap_to` `_sv1_update_follow` `_v0_update_follow` `_combat_engage_target` `CLASS_COLORS` | party_cohesion, party_member.tscn, player_controller, Slice01Data, formation.json, group 'enemy' |
| [party_member.gd](../scripts/party/party_member.gd) | 401 | 단일 슬롯: 스탯·스킬파라미터·HP/실드/상태(F-021)·넉백·navmesh 캐시·조작비주얼 | `take_damage` `heal` `add_shield` `apply_stun/poison` `get_status_list` `nav_*` | health_bar, Slice01Data, groups 'party_member'/'player' |
| [party_cohesion.gd](../scripts/party/party_cohesion.gd) | 8 | F-003 결속 모드 enum(BOUND/UNBOUND) | `Mode` `MODE_*` | — |

### combat — `scripts/combat/`
| 파일 | L | 책임 | 핵심 심볼 | 의존 |
|------|--:|------|-----------|------|
| [combat_controller.gd](../scripts/combat/combat_controller.gd) | 638 | 인카운터 스폰·증원, 전 프레임 적AI+파티 자동공격, Identity 4 + Sub 4 디스패치, F-022 threat, 공간쿼리 | `on_encounter_triggered` `cast_sub` `_try_identity` `_cast_*` `_sub_*` `_deal_damage` `_heal_threat` `ENEMY_VISUALS` | Slice01Data, enemy_unit.tscn, skill_vfx, group 'party_member' |
| [enemy_unit.gd](../scripts/combat/enemy_unit.gd) | 263 | 단일 적: 데이터 스탯·F-022 threat 테이블(히스테리시스)·slow/knockback·박스메쉬·HP바 | `setup` `add_threat` `pick_target` `apply_slow/knockback` | health_bar, group 'enemy' |
| [health_bar.gd](../scripts/combat/health_bar.gd) | 129 | 아군/적 공용 빌보드 HP바(프레임/배경/필/타겟·임박 마커) | `set_ratio` `set_target` `set_imminent` | 카메라(프레임당 조회) |
| [skill_vfx.gd](../scripts/combat/skill_vfx.gd) | 224 | 무상태 절차 PH VFX 라이브러리(역할별 자동소멸) | `anchor_guard` `press_line` `mark_ruin` `mend_circle` `sub_*` `enemy_vfx` | Godot 메쉬/트윈 only |

### ui — `scripts/ui/`
| 파일 | L | 책임 | 핵심 심볼 | 의존 |
|------|--:|------|-----------|------|
| [party_sheet.gd](../scripts/ui/party_sheet.gd) | 152 | UI-002 좌상단 4인 로스터(초상/HP/서브쿨/상태핍) | `setup` `_build_slot` `_process` | radial_cooldown, 멤버 덕타이핑 |
| [controlled_sheet.gd](../scripts/ui/controlled_sheet.gd) | 110 | UI-003 하단 조작캐 액션바(초상/HP/Identity+Q/E/R 쿨) | `setup` `_process` | radial_cooldown, PartyController |
| [radial_cooldown.gd](../scripts/ui/radial_cooldown.gd) | 45 | 쿨다운 라디얼 웨지 Control(쿨/상태핍 겸용) | `set_cd` `set_icon_color` `_draw` | — |
| [loadout_stub.gd](../scripts/ui/loadout_stub.gd) | 37 | 메뉴 로드아웃 스텁(4 Identity 표시·확정) | `populate_from_data` `loadout_confirmed` | Slice01Data |

### scenes — `scenes/`
`main.tscn` · `run/dungeon_run.tscn` · `party/party_member.tscn`(원기둥 PH) · `combat/enemy_unit.tscn`(박스 PH). 메쉬·색·크기는 런타임에 덮어쓴다.

---

## 4. 데이터 파이프라인

`data/slice01/*.json` → [slice01_data.gd](../scripts/core/slice01_data.gd)가 로드·검증·링크:

- `manifest.json` (phase/contract/pool→encounter 바인딩) · `id_registry.json` (허용 ID) · `blueprint.json` · `rooms.json` · `formation.json`
- `identities.json` (역할→`ability_id`/`sub_ability_id`) · `enemies.json` (적→`abilities[].ref`) · `abilities.json` (**통합 카탈로그**, AB-### → kind/효과) · `encounters/ENC-*.json`
- 캐릭터/유닛은 **ID로 어빌리티를 링크**한다(인라인 정의 금지). "한 번 정의 → 어디서나 할당".

> ⚠️ `abilities.json`은 현재 `id_registry`와 대조 **검증되지 않는다**(§6 DEBT-DM1). 다른 도메인(enemies 등)은 `require_id`로 검증됨.

---

## 5. 핵심 규약 (dev_templates 기준 + 현 레포 편차)

- ID 1:1: 코드/데이터의 문자열 ID는 spec과 **그대로** (`tank_anchor_guard`, `ENC-NORM-001`, `P-ADV-01` …). 별칭 금지.
- 미등록 ID → abort: 로드 시 `require_id`로 차단 (현재 abilities 도메인은 누락).
- 규칙 SSOT 복사 금지: F/QA 전문을 주석에 붙이지 말고 `## ref:` 한 줄 + spec 경로만.
- 단일 책임: 1 파일 = 1 책임. **현 편차:** `party_controller.gd`가 6+ 책임을 가짐(§6 DEBT-GOD).
- 도메인 폴더: `core/run/party/combat/ui` (dev_templates의 `features/F###_*` per-feature 컨벤션과는 다름 — 의도적 단순화).

---

## 6. 기술 부채 레지스터 (효율화 체크 결과)

> `risk_to_fix` = **게이트/라이브 흐름 회귀 위험**. `now` = 안전(P4에서 정리), `defer` = 라이브 전투/스티어링 흐름을 건드림(P6 전체 리팩토링 + 검증 동반).
> 출처: 2026-06-08 read-only 아키텍처 서베이(9-agent).

### 갓오브젝트 / 죽은 코드
| ID | 항목 | 위치 | sev | 처리 |
|----|------|------|-----|------|
| DEBT-GOD | `party_controller.gd` 1623줄 = 스폰·스왑·결속·포메이션 상태머신·슬롯기하·스티어링×2·전투교전·설정로더. 추출 단위: `FormationConfig`(Resource) / `SteeringV1`(strategy) / `FormationForward`(상태머신) / `PartyRoster` | party_controller.gd:1-1623 | high | **defer (P6)** |
| DEBT-V0 | ✅ **해소(P6.1)** — 죽은 v0 추종엔진 349줄 삭제(party_controller 1623→1273), 데이터경로 확인(formation.json 항상 steering_v1)+에디터 임포트 검증. **잔여(P6.2):** 데드 `_sv1_enabled`·v0 전용 config vars·`_tank_steer_axes`·formation.json `follow_steering_deprecated` 정리 | scripts/party/party_controller.gd | med | **부분 DONE** |
| DEBT-DEAD1 | `_sync_tank_follow_collision`이 이름과 달리 무조건 `set_party_member_collision(true)` — 사실상 no-op | party_controller.gd:1598-1600 | low | **now (P4)** |
| DEBT-DEAD2 | `run_controller.can_swap()` 항상 true 스텁 + `party_in_combat` 이중관리(소비자 없음) | run_controller.gd:66, party_controller.gd:226 | low | now/defer |

### 중복
| ID | 항목 | 위치 | sev | 처리 |
|----|------|------|-----|------|
| DEBT-DUP-COLOR | 역할→색/크기 테이블 분산: `CLASS_COLORS`/`CLASS_SCALES`(party) vs `ENEMY_VISUALS`(combat) vs 멤버 `_base_color`. 단일 팔레트 SSOT 없음 | party_controller.gd:12-25, combat_controller.gd:23-32, party_member.gd:237 | med | **now (P4)** → `scripts/core/unit_visuals.gd` |
| DEBT-DUP-HP | ✅ **해소(P4)** — 공유 `ui_colors.gd:hp_color(r)`로 단일화, 3파일 호출. (구: 노랑/빨강 값 갈라진 시각버그) | scripts/core/ui_colors.gd | med | **DONE** |
| DEBT-DUP-SPATIAL | 반경/콘/최근접/y평탄화 쿼리가 5~6회 재구현 | combat_controller.gd:307-382, party_controller.gd:683-703, enemy_unit.gd:191 | low | **now (P4)** → 공간헬퍼 |
| DEBT-DUP-MAT | StandardMaterial3D/메쉬 PH 빌더 중복(언셰이드+알파 디스크는 dungeon_run 안에서도 2회) | dungeon_run.gd:149-200, map_demo_layout.gd:235-298, party_member.gd:168, enemy_unit.gd:233 | low | **now (P4)** → 머티리얼 팩토리 |
| DEBT-DUP-HPBAR | 2D HP바 위젯이 2곳에서 손수 재구현 | party_sheet.gd:83, controlled_sheet.gd:51 | low | now (P4, 선택) |
| DEBT-DUP-CD | 쿨다운 비율식 `cd/params.cooldown_s` 인라인 복붙(div-by-zero 가드 포함) | party_sheet.gd:132, controlled_sheet.gd:97 | low | now (P4) → 멤버 `*_cd_ratio()` 접근자 |

### 비효율 (프레임당 핫패스)
| ID | 항목 | 위치 | sev | 처리 |
|----|------|------|-----|------|
| DEBT-EFF-GRP | `get_nodes_in_group('party_member')` 프레임당 3회 재스캔(combat); `'enemy'` 그룹을 party가 O(추종자)회 재스캔 + 최근접식 중복 | combat_controller.gd:61,92,357; party_controller.gd:670-703 | med | **defer (P6)** — 전투 틱 순서 변경 |
| DEBT-EFF-RAY | 스티어링 v1이 추종자당 프레임당 레이캐스트 6~15회(벽/경로). 스로틀·캐시 없음 | party_controller.gd:914-1012 | med | **defer (P6)** |
| DEBT-EFF-ALLOC | 프레임당 Dictionary/RNG 신규할당(`peer_slot_targets`, reposition RNG) | party_controller.gd:574,590,643,731 | low | defer (P6) |
| DEBT-EFF-HPBAR | HP바마다 프레임당 카메라 조회 + 트랜스폼 재구성 | health_bar.gd:51-60 | low | now/선택 (빌보드 플래그) |

### 결합 / 데이터모델
| ID | 항목 | 위치 | sev | 처리 |
|----|------|------|-----|------|
| DEBT-CPL-COMBAT | `party_in_combat`가 RunController·PartyController에 이중 + dungeon_run(글루)이 set. "전투 중?"의 단일 소유자 없음 → 전투 시작/종료 의미 변경 시 3파일 동시수정 | dungeon_run.gd:209-217, party_controller.gd:29, run_controller.gd:19 | med | **defer (P6)** — CombatController 단일소유 |
| DEBT-CPL-DUCK | CombatController가 party_member 필드 ~20개를 가드 없이 덕타이핑; 스킬 'kind' 4종 하드코딩 | combat_controller.gd:91-123 | med | defer (P6) — 타입드 계약 + 테이블 디스패치 |
| DEBT-CPL-HUD | dungeon_run이 HUD 라벨 11개 노드경로를 하드코딩·직접 set; 한글 상태문자열 .tscn과 중복 | dungeon_run.gd:10-20,230-261 | med | defer (P6) — `RunInfoPanel` 노드로 분리 |
| DEBT-CPL-GROUP | controlled/alive/room-trigger 상태가 문자열 그룹으로 멀티플렉싱(member에서 mutate, 여러 시스템이 read) | party_member.gd:96-111,397 | med | defer (P6) |
| DEBT-OTHER-AWAIT | 적 텔레그래프가 물리틱 중 `await create_timer` → 공격이 프레임 가로질러 해소(**비결정적**, ENC 테스트에 불리) | combat_controller.gd:435-472 | med | defer (P6) — 윈드업 상태머신 |
| DEBT-DM1 | `abilities.json` 로드 시 `require_id` 미수행 → "미등록 ID→abort" 규칙이 어빌리티만 무력화 | slice01_data.gd:211-213 | med | **now (P3)** — 코드 가드 버그 |
| DEBT-DM2 | `ENEMY_VISUALS` 색/크기가 enemies.json과 분리(컨트롤러 리터럴) | combat_controller.gd:23-32 | low | now/선택 (PH 아트) |
| DEBT-DM3 | 룸 기하가 `map_demo_layout` 상수 vs `rooms.json` 이중소유 → 드리프트 가능 | map_demo_layout.gd:10-75, rooms.json | med | defer |

**가장 깨끗한 파일:** `skill_vfx.gd`(무상태·정적), `health_bar.gd`(단일책임·무결합), `party_cohesion.gd`. 신규 코드의 참고 모델.

---

## 7. 참고
- 거버넌스·스펙 전파 규칙: [AGENTS.md](../AGENTS.md) · [CLAUDE.md](../CLAUDE.md)
- 스펙 드리프트 대장: [docs/SPEC_DRIFT.md](SPEC_DRIFT.md)
- 코드측 결정 기록: [docs/impl_decisions/ImplDecisionLog.md](impl_decisions/ImplDecisionLog.md)
- Phase 1a 작업순서(역사): [plan/phase-1a-slice01/WORK_ORDER.md](../plan/phase-1a-slice01/WORK_ORDER.md)

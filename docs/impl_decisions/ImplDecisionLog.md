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

### IMPL-DEC-20260609-001 — 전투 진입/슬롯-이탈 분리 + 안전우선 폴로워 (F-004·D-010 구현)
- **결정:** ① partyInCombat(전투중/휴식중)을 D-010 §4.1(파티 피해·공격·인지) 진입 / §4.2(grace 6s) 종료로 구현, HUD 표시. ② **폴로워 슬롯-이탈(진형 깨기)을 partyInCombat과 분리**: 피격 또는 적이 아군 기본사거리 진입 시에만(인지/스폰만으론 안 깸) → 선전진 돌진 방지(F-004 §3.1 안전우선/§3.3 leash 취지). ③ 힐러는 적이 아닌 **부상 아군을 힐 사거리에 두도록 이동**(F-005 롤).
- **이유:** "비조작 파티원 안전우선"(F-004) + "전투 판정"(D-010)의 구현. 사용자 요구(배치 우선, 돌진 금지)와 spec 정합.
- **대안:** 인카운터 스폰=즉시 돌격(기존) — F-004 위반, 기각.
- **영향:** `scripts/combat/combat_controller.gd`, `scripts/party/party_controller.gd`, `scripts/run/dungeon_run.gd`, `scenes/run/dungeon_run.tscn`.

### IMPL-DEC-20260609-002 — 적 전투AI 재설계: 분대 + 미리스폰 + 시야콘 인지 (F-011 부분/신규 enemy-AI)
- **결정:** 전역 engaged 제거 → **적 분대(squad) 단위 engage**(분대원 근접 9m 전파, stray 예외). 인카운터 **미리 스폰(휴면)**, 시작방 인카운터→메인전투방 이전, 방 먼쪽 배치. **하이브리드 시야콘 인지**(FOV+LOS+근접버블, 2존 경계/전투, ?/! 텔, last_seen 조사, 도망 시 grace+감속 추격→포기). 적 **navmesh 추격**, 공격 LOS 게이트, **threat/시야기반 타겟**(미인지 먼 멤버 비타겟).
- **이유:** 인지 기반 전투 개시 + 분대 독립 + 도주/은신 성립(스텔스성). DRIFT-018/019에 트래킹, F-011 deferred 스코프를 1b로 선구현.
- **대안:** 풀 F-011(perceptionProfile/Patrol/Threat Memory)까지 — 범위 과대, 데모엔 과함. 부분 구현 + PENDING-PROP.
- **영향:** `scripts/combat/combat_controller.gd`, `scripts/combat/enemy_unit.gd`, `scripts/run/map_demo_layout.gd`(deep spawn), `scripts/party/party_controller.gd`(앵커 전투 합류).

### IMPL-DEC-20260610-008 — 비결속 지휘권: 리더 정본 앵커 + 임시 위임/복귀 환원 (F-003 §3.4 확장)
- **결정:** `_update_command_holder(avoid_scout)`를 **per-frame**(+스왑/진입) 갱신으로. **리더=정본 앵커**(이동핑 명령 대상). 리더가 정찰(컨트롤)/복귀 중에만 stand-in 임시 위임, **리더가 대열 복귀(`_leader_returned`: stand-in 5m 내)하면 앵커를 리더로 환원**. stand-in 선정(`_pick_command_holder`, 후보 leader/sub→전 멤버)에서 **방금 떨어진 정찰자(avoid_scout) 제외**.
- **이유(2단계):** ① 1차(IMPL-DEC 초안): §3.4 "비리더 컨트롤→앵커=리더"가 정찰 나간 리더를 앵커로 만들어 파티가 끌려감 → persistence+정찰자제외로 "떨어진 1명만 이탈"화. ② **사용자 재지적:** 앵커가 stand-in(Healer 등)으로 **영구 drift**하면 이동핑(F-003 §3.5)의 명령 대상으로서 의미가 깨짐 → "탱커 복귀 시 앵커를 탱커로 환원"이 옳다. → per-frame 리더-환원으로 재설계.
- **대안:** (a)가상 포메이션 앵커(좌표 기반) — 더 큰 구조변경, 보류. (b)stand-in 영구화 — 이동핑 역할 훼손이라 사용자 기각.
- **트레이드오프:** 리더 환원 순간 포메이션 중심이 stand-in→리더로 ~slot offset만큼 1회 부드럽게 이동(스티어링 흡수). RETURN_RADIUS 5m=tuning.
- **전파(✅ 완료):** spec staging **f7739a1** · **DEC-20260610-002** — F-003 **§3.0.4** 신설로 **지휘권 보유자(리더 고정·핑/MIA 대상)↔포메이션 랠리 앵커(자동 stand-in/환원) 분리** SSOT화. 전파 중 §3.0/§3.10 "앵커 고정+UI-008 수동" 모델과의 충돌을 발견→사용자 결정으로 분리 모델 채택. 게임 코드는 랠리 앵커만(핑/MIA 미구현). `spec_ref.json` 재핀 6f0e534→f7739a1. DRIFT-021 MERGED.
- **영향:** `scripts/party/party_controller.gd`(`_update_command_holder`/`_leader_returned`/`_pick_command_holder`/`_set_controlled_index`/`_get_anchor`/`_physics_process`), `spec_ref.json`, `docs/SPEC_DRIFT.md`. spec: `F-003`/`DecisionLog`/`SpecScopeTracker`/`TODO`.

### IMPL-DEC-20260610-010 — CombatPositioning 분리 + 데드 v0 config 정리 (갓코드 정리 4단계, party_controller)
- **결정:** ① party_controller의 전투우선 goal-point 로직(`_has_live_enemies`/`_enemy_in_party_basic_range`/`_combat_engage_target`/`_healer_support_target`/`_lowest_hp_ally_below_threshold`, ~104줄)을 **`scripts/party/combat_positioning.gd`(111줄)** 자식 노드로 추출(`_members`만 `_party` 백레퍼). ② **데드 v0 config 17종 제거**(DEBT-V0 잔재): tank_follow 보정/리버설 6 + v0 separation 7 + preferred_anchor/lateral_approach/slot_arrive/path_clearance 4 — 선언 + `_load_formation_config`의 tank_follow 로더 블록.
- **이유:** 사용자 선택(party 갓코드 "깨끗한 것부터"). SteeringV1(~530줄)은 config 소유권·per-member 상태·라이브무빙에 **깊게 결합**돼 통째 추출 시 백레퍼 대량 + 최고위험이라, 저결합·저위험 단위부터. party_controller **1623→1014줄**(이번 -128: CombatPositioning -104, 데드config -24).
- **결합 처리:** CombatPositioning은 goal-point만 계산(enemy/ally 그룹 + 멤버 메서드), `_members`만 `_party` 콜백. `_update_formation_follow`/`_sv1_update_follow`(Pass3)가 `_combat_pos.*` 위임. Node 자식이라 `get_tree()` 보유.
- **동작 보존:** 순수 리팩토링 — 슬롯이탈 트리거(F-004)·근접 attack-range 포지션·힐러 wounded 추종(F-005) 로직 그대로. 데드 config는 sv1 미사용(grep 0 검증) 확인 후 제거.
- **잔여:** **SteeringV1**(~530줄)은 전용 세션(config 소유권 재설계 동반). DEBT-GOD 잔여 최대 덩어리.
- **영향:** `scripts/party/combat_positioning.gd`(신규), `scripts/party/party_controller.gd`, `docs/ARCHITECTURE.md`(DEBT-GOD/DEBT-V0).
- **F5 검증:** 전투우선 follower 교전(근접 attack-range)·힐러 wounded 추종·진형우선 hold·슬롯이탈 트리거가 이전과 동일한지.

### IMPL-DEC-20260610-009 — AbilityDispatch 분리 (갓코드 정리 3단계, combat_controller 분해)
- **결정:** combat_controller의 파티 스킬 디스패치(`_build_ability_handlers` + `try_identity` + Identity 4 `_cast_*` + `cast_sub` + Sub 4 `_sub_*` + `_sub_hit_shake`, ~185줄)를 **`scripts/combat/ability_dispatch.gd`(197줄)** 자식 노드로 추출. 전용 상수(TANK_PULSE_FLOOR·SUB_SHAKE_MULT_REF·HIT_SHAKE_CAP) 동반 이동. `_tick_party_attacks`는 `_ability_dispatch.try_identity(m)` 위임, `cast_sub`는 얇은 래퍼로 유지(dungeon_run 무수정).
- **이유:** DEBT-GOD2 분해 계속(EnemyAI 다음, 사용자 추천 승인). combat_controller **581→408줄**(854에서 -446 누적). "스킬이 무엇을 하는가"를 전투 루프/스폰/threat에서 분리.
- **결합 처리:** 공유 시스템(공간쿼리 `_enemies_in_*`/`_nearest_*`, `_deal_damage`/`_heal_threat`, `camera_shake` 시그널)은 컨트롤러 단일소유 유지 → AbilityDispatch가 `_combat.*` 콜백. AbilityDispatch는 Node3D 자식이라 VFX 부모(`self`) 자체 보유. EnemyAI와 동일 패턴(순환 preload 회피 위해 `_combat`=Node3D).
- **동작 보존:** 순수 리팩토링 — Identity 자동(AB-020/024/025/026)·Sub 4(taunt/lunge/nova/sanctuary)·SUB 캐스트당 1회 셰이크 로직/상수 그대로.
- **영향:** `scripts/combat/ability_dispatch.gd`(신규), `scripts/combat/combat_controller.gd`, `docs/ARCHITECTURE.md`(DEBT-GOD2).
- **F5 검증:** Identity 자동 발동(역할별)·Sub 4종(Q+지면조준)·SUB 타격감 셰이크가 이전과 동일한지.

### IMPL-DEC-20260610-007 — EnemyAI 분리 (갓코드 정리 2단계, combat_controller 분해)
- **결정:** combat_controller의 적 AI(perception `_tick_dormant` + 전투행동 `_tick_enemy`→`tick` + 공격 `_begin/_resolve/_apply_enemy_hit` + `_telegraph_color`/`_select_enemy_ability`/`_nearest_visible`/`_alive_members` + 인프라 `_has_los`/`_nav_move`, ~273줄)를 **`scripts/combat/enemy_ai.gd`(301줄)** 자식 노드로 추출. AI-only 상수(LOS/시야콘/투사/DMG셰이크/SWITCH_RATIO)도 동반 이동. `_physics_process`는 `_enemy_ai.tick(enemy, targets, delta)`로 위임, 비전콘은 `_enemy_ai.attach_vision_cone(unit)`.
- **이유:** DEBT-GOD2(combat_controller 854줄, 5 하위시스템). 사용자 승인 추출순서 EnemyAI 우선. combat_controller **854→581줄**, 적 의사결정이 스폰/threat/어빌리티에서 분리.
- **결합 처리:** 전투 상태(engaged/grace)·시그널(camera_shake/party_damaged)은 **컨트롤러 단일소유** 유지 → AI가 `_combat._engage_enemy()`/`_combat.refresh_engage_grace()`(신규)/`_combat.party_damaged.emit()`/`_combat.camera_shake.emit()`로 콜백. AI는 Node3D 자식이라 `get_world_3d()`(LOS 레이캐스트)·VFX 부모(`self`) 자체 보유. 양방향 ref는 Godot 컴포넌트 패턴(허용).
- **동작 보존:** 순수 리팩토링 — perception 2존·investigate·engage/disengage grace·텔레그래프 윈드업·LOS 게이트 공격·시야상실 추격·피격 방향셰이크 로직/상수 그대로.
- **영향:** `scripts/combat/enemy_ai.gd`(신규), `scripts/combat/combat_controller.gd`, `docs/ARCHITECTURE.md`(DEBT-GOD2).
- **F5 검증:** 적 perception(?/!·investigate)·전투 교전/추격·텔레그래프·증원·피격 셰이크·탈출이 이전과 동일한지.

### IMPL-DEC-20260610-006 — CameraRig 분리 (갓코드 정리 1단계, 동작 보존 리팩토링)
- **결정:** dungeon_run의 카메라 로직(추종/스왑글라이드/RMB 오르빗/trauma 셰이크, ~70줄 + consts/vars)을 **`scripts/run/camera_rig.gd`(87줄)** 로 추출, `CameraPivot` 노드에 부착. dungeon_run은 `set_follow_target`/`glide_to_current`/`orbit_yaw`/`add_shake` API로 위임. 카메라셰이크 시그널은 `_combat.camera_shake → _camera_rig.add_shake`로 직결.
- **이유:** 갓코드 점검(사용자 요청)에서 dungeon_run이 씬오케스트레이션 + 카메라 + UI를 혼재. 카메라는 CameraPivot에 응집돼 **가장 고립·저위험** 추출 단위 → 첫 정리 대상으로 선정(사용자 승인). dungeon_run 326→256줄, 책임 분리.
- **동작 보존:** 순수 리팩토링 — follow/glide/shake/orbit 로직·상수(SWAP 60/320/6, SHAKE 1.8/3.5°/7.0) 그대로 이동. 부트 글라이드(원점→스폰)·스왑 글라이드·피격 방향킥·회전셰이크 동일. no-op `_sync_tank_follow_collision` 제거(DEBT-DEAD1)도 동반.
- **영향:** `scripts/run/camera_rig.gd`(신규), `scripts/run/dungeon_run.gd`, `scenes/run/dungeon_run.tscn`(CameraPivot에 스크립트), `docs/ARCHITECTURE.md`.
- **F5 검증:** 부트 카메라·1~4 스왑 글라이드·RMB 드래그 회전·전투 피격/타격 셰이크가 이전과 동일한지.

### IMPL-DEC-20260610-005 — 맵 인터페이스 데이터 주도화 (Blender 실맵 교체 대비)
- **결정:** `map_demo_layout`의 인터페이스 getter(`get_spawn_position`/`get_deep_spawn_position`/`get_extraction_position`)를 ROOM_SPECS 직접참조 → **런타임 테이블 `_room_points`**(room_ref→{spawn,size}) + `_extraction_point` 기반으로 분리(`_resolve_room_points`로 채움, placeholder는 ROOM_SPECS에서 파생). `lighting_profile`은 **`rooms.json`(SSOT)** 우선(`_room_profile`), ROOM_SPECS.profile은 빌드 폴백. 맵 계약 주석 블록 추가.
- **이유:** 나중에 spec 기반 **Blender 실맵**으로 교체 시, 절차 생성 placeholder를 버리고 새 맵 노드가 **같은 계약**(getter 5종 + `room_entered` + 벽 콜리전 layer1 + navmesh)만 제공하면 perception/LOS·스폰·탈출·룸 트리거가 **콜러 무수정**으로 동작하게. 옵션 C(placeholder를 씬으로 굽기)는 버려질 작업이라 불채택. DEBT-DM3 부분 해소(profile 이중소유 제거).
- **잔여:** 룸 **기하**(center/size)는 ROOM_SPECS 상수 유지(placeholder geometry; Blender 메시가 대체). Blender 맵은 `_resolve_room_points` 오버라이드 또는 Marker3D 권장.
- **영향:** `scripts/run/map_demo_layout.gd`, `docs/ARCHITECTURE.md`(DEBT-DM3).

### IMPL-DEC-20260610-004 — 카메라 셰이크 (타격감 + 피격 방향킥, trauma 모델)
- **결정:** 카메라 흔들림을 **trauma 모델**(trauma 누적·clamp 1.0·trauma² 진폭·초당 감쇠, 비누적)로 도입. **2케이스만**: ① 타격감 = 파티의 **플레이어 발동 SUB 스킬**만 — **평타 + Identity 자동딜 제외**. **캐스트당 1회**(`_sub_hit_shake`, 타깃 수 무관 — AOE 누적 방지) `damage_mult` 비례(lunge 5.0>nova 3.0). ② 피격 = **AB로 정의된 스킬**(`chosen.ref` 있음 + `trigger!="basic"`) 피해만(평타 ability·접촉뎀·잔뎀 제외), **맞은 방향 킥**(위협 방향 정보) + 셰이크. **파티 전체** 적용하되 **비조작 멤버 이벤트는 감쇄**(`SHAKE_NONCTRL_MULT` 0.4). 진폭은 가독성 위해 낮게(`SHAKE_MAX_POS` 0.45·`DMG_KICK_M` 0.6·caps 0.4/0.6).
- **이유:** 정보전/택티컬 게임이라 흔들림=가독성 해치지 않는 "신호". trauma²가 작은 건 미세·큰 건 펀치로 자동 차등 + clamp로 연타 블러 방지. 방향 킥은 "어느 쪽에서 맞았나" 정보 제공. (사용자 설계 결정)
- **적용:** 피벗(추종/글라이드)은 불간섭, Camera3D 로컬에만 적용. **흔들림=회전(rotational)** — 탑다운 원거리라 위치 흔들림은 거의 안 보여 회전 jitter로 체감 확보(진폭 `trauma^1.5` × `SHAKE_MAX_ROT_DEG` 3.5°, roll 0.5배). **방향 킥만 위치 오프셋**(화면기준 -pivot.yaw 회전). 서브 타격감이 안 느껴지던 문제 → `HIT_SHAKE_REF` 90→50·`CAP` 0.4→0.6로 상향.
- **분류:** F-012(Camera) 범위의 UX 피드백; 수치(REF/GAIN/CAP/KICK/DECAY/MAX_POS·NONCTRL 0.4)는 **tuning**. 전파 불요(안정화되면 F-012 카메라-피드백 규칙으로 승격 후보).
- **영향:** `scripts/combat/combat_controller.gd`(camera_shake 시그널·trauma 산출·평타 게이트), `scripts/run/dungeon_run.gd`(`_on_camera_shake`/`_apply_camera_shake`).

### IMPL-DEC-20260610-003 — 스왑 카메라 글라이드 (텔레포트 → 가속/감속)
- **결정:** 1~4 스왑 시 카메라 피벗이 순간이동하던 것을 **가속+arrive 감속 글라이드**(`_glide_camera`: desired=min(dist·gain, max), 속도 move_toward로 ramp)로 전환. 평소 추종은 **타이트 유지**(글라이드는 스왑 전환 중에만). 모든 스왑(수동/자동) 커버(`_on_controlled_changed`).
- **이유:** 스왑 카메라 텔레포트가 방향감 상실 → 빠르되 부드러운 전환으로 가독/유저 친화성↑. F-012(Camera) 범위의 **UX 폴리시**; 속도/가속/arrive_gain은 **tuning**(전파 불요).
- **영향:** `scripts/run/dungeon_run.gd`(_glide_camera·_focus_camera 재정의·per-frame 분기).
- **결정:** 익스트랙션을 **즉시 성공 스텁**에서 **POINT-DEMO-01 홀드 채널**로 전환. 조작 캐릭이 존(3m) 안에 머무는 동안 누적, 완료 시 `try_extract()`(Extraction Success). **비전투 5s / 전투중(`_combat.is_engaged()`) 30s** — 매 프레임 현재 상태로 임계 판정(전투가 붙으면 탈출이 길어짐). 존 이탈 시 **취소·리셋**(실패 정산 없음). 큰 카운트다운 라벨이 높은 수→1로 표시.
- **이유:** F-007 §3.1.2 `ExtractionActivate`는 "채널·홀드 등 상호작용 **완료** 시 성공"으로 이미 정의됨 — 즉시 스텁을 정합 구현으로 교체(사용자 요청). 채널 시간(5/30s)은 F-007이 "후속 UI/전투 SSOT"로 둔 **tuning**(SPEC_DRIFT DRIFT-020) → 전파 불요.
- **영향:** `scripts/run/dungeon_run.gd`(채널 타이머 `_update_extraction` + 카운트다운), `scenes/run/dungeon_run.tscn`(`HUD/ExtractCount` 라벨). `run_controller.try_extract()`는 완료 핸들러로 유지.

### IMPL-DEC-20260610-001 — 스펙 핀 재정렬 19f2af0 → 6f0e534 (F-013 전파)
- **결정:** DRIFT-018/019(적 시야 인지·분대 전투AI)를 spec staging에 전파 후 `spec_ref.json` 핀을 `19f2af0`→`6f0e534`로 bump.
- **전파 내용(spec repo, DEC-20260610-001):** `F-013`(Enemy Combat AI) 신설 — 휴면→경계→교전→이탈 상태머신·인지 게이트 진입·분대 교전 전파·타겟 공정성·lastSeenPos 수색→grace 이탈. `F-011`에 적 인지 데모 부분집합 노트, `QA-031` 1b In-scope 승격, 매퍼(FeatureMap/DependencyMap/DataMap)·SpecScopeTracker·TODO·I-000.
- **비전파:** 수치(DRIFT-020 tuning), 기존 spec 구현분(D-010/F-004/F-005/F-003 §3.4 — IMPL-DEC-20260609-001/003).
- **잔여(spec 후속):** F-013 포스트복귀/리쉬·perceptionProfile 차등·전용 QA-013·OPS_20 양방향 related/RelationGraph 동기화.
- **영향:** (game) `spec_ref.json`, `docs/SPEC_DRIFT.md` · (spec) F-013/F-011/F-022/F-024/QA-031/DataMap/FeatureMap/DependencyMap/DecisionLog/SpecScopeTracker/TODO/I-000.

### IMPL-DEC-20260609-003 — 비결속 지휘권 보유자(Active Anchor) 구현 (F-003 §3.4)
- **결정:** 파티비결속 앵커를 항상-리더에서 **지휘권 보유자**로 변경 — 진입 시 §3.4 규칙으로 결정(리더 조작 중+서브리더 유효 → 서브리더가 앵커 → 리더 독립 이동), 스왑으로 불변, 보유자 무효 시 자동 전환. 서브리더 기본값 = 첫 비-리더 멤버.
- **이유:** "리더(앵커)를 따로 이동시키고 서브앵커가 대체" 요구 = F-003 §3.4 그대로.
- **보류(spec 존재, 미구현):** 서브리더 지정 UI(UI-005)·지휘권 전환 UX(UI-008)·Leader Move Ping(F-003 §3.5) → 기본값/미구현. 전파 불필요(기존 spec 구현).
- **영향:** `scripts/party/party_controller.gd`.

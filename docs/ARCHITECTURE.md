# ARCHITECTURE — project_tdc_game

> **목적:** 코드가 "필요할 때마다 덧붙이기"로 쌓이는 것을 막기 위한 **단일 구조 지도**.
> 각 스크립트의 책임·의존·핵심 심볼과, 알려진 **기술 부채**(중복/비효율/결합)를 한 곳에 적재한다.
> **갱신 규칙:** 스크립트를 추가/이동/삭제하거나 책임이 바뀌면 이 문서를 같은 PR에서 갱신한다. 부채를 해소하면 §6 레지스터에서 항목을 지운다.
> **최종 갱신:** 2026-06-13 · **기준 커밋:** `5e9dab8` 이후 작업 트리(1b 횃불/배럴·기름/MIA/배치허브/포메이션 + DEBT-GOD/GOD2 추출 라운드) · 라인수는 갱신 시점 기준.

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
        ├─ PartyController    : 4인 스폰·스왑·결속 + 추종 스티어링(전 프레임) ⚠️갓오브젝트
        ├─ CombatController   : 분대 스폰 + 전투 루프 + Threat(F-022) │ └ EnemyAI(적 perception/전투) · AbilityDispatch(Identity/Sub 스킬) 자식
        ├─ CameraPivot        : CameraRig(추종/스왑글라이드/오르빗/셰이크) + Camera3D
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
| [core/slice01_data.gd](../scripts/core/slice01_data.gd) | 326 | `data/slice01/*`(gear 포함) 전부 로드·검증·캐시, 타입드 게터 | `get_encounter` `get_enemy_row` `get_ability` `get_gear_master` `get_starter_gear_for_identity` `get_identity_row` | IdValidate, JSON 파일 |
| [core/validate_ids.gd](../scripts/core/validate_ids.gd) | 16 | id 레지스트리 멤버십 검증 + 표준 에러 문자열 | `contains_id` `require_id` `unknown_id_error` | (순수함수) |
| [autoload/stash.gd](../scripts/autoload/stash.gd) | 39 | 🟢 플레이어 스태시(소유 gear/스킬북/소모품 시드). 배치 허브가 컨테이너로 띄움 | `take_consumable` `return_consumable` `_seed` | — |
| [autoload/run_loadout.gd](../scripts/autoload/run_loadout.gd) | 14 | 🟢 씬간 런 로드아웃(F-010): 반입 소모품·백팩(At-Risk)·멤버 서브·포메이션 오프셋. 허브 set→던전 read | `set_consumables` (vars) | — |

### run — `scripts/run/`
| 파일 | L | 책임 | 핵심 심볼 | 의존 |
|------|--:|------|-----------|------|
| [run_phase.gd](../scripts/run/run_phase.gd) | 16 | 5개 runPhase 문자열 상수 + 순서 | `ENTRY..EXTRACTION` `SEQUENCE` | — |
| [run_controller.gd](../scripts/run/run_controller.gd) | 124 | 런 상태(phase/room/flags), 룸진입→인카운터 트리거, objective/extraction | `start_run` `on_player_entered_room` `try_extract` | RunPhase, Slice01Data |
| [dungeon_run.gd](../scripts/run/dungeon_run.gd) | 487 | 🟢 씬 부트·시그널 라우팅 + **입력 라우터**(Esc/클릭/키 → 모달 컨트롤러 위임) + 월드오브젝트 스폰(횃불/랜턴/배럴) + **RunLoadout 적용**(반입품·서브·포메이션) + HUD 콜백. (모달/추출/루트/정산 전부 컨트롤러로 분리) | `_ready` `_unhandled_input` `_on_*` | 전 노드 트리, 컨트롤러들, RunLoadout |
| [aim_controller.gd](../scripts/run/aim_controller.gd) | 52 | 🟢 스킬북 지면조준 모달(start_aim→클릭 시전). 균일 인터페이스 is_active/cancel/handle_click | `start_aim` `handle_click` `cancel` | AimMarker/combat(ref) |
| [loot_service.gd](../scripts/run/loot_service.gd) | 77 | 🟢 처치 루트 드랍(F-009/F-010): 스킬북>gear>일반 롤 → ItemDrop 스폰. enemy_defeated 구동 | `on_enemy_defeated` `_roll_loot_def` | Slice01Data, ItemDrop |
| [run_end_controller.gd](../scripts/run/run_end_controller.gd) | 173 | 🟢 런 종료 흐름(F-007): 탈출 홀드채널 + 결속게이트(§3.6.2) + 전멸감지(§3.7.1) + 정산조합. 자기 _process, settle_* 호출 | `_update_extraction` `_settle_extraction` `_is_party_wiped` | run/party/combat/inv/map(ref) |
| [camera_rig.gd](../scripts/run/camera_rig.gd) | 87 | 🟢 게임플레이 카메라 리그(추종/스왑글라이드 accel·decel/RMB 오르빗/trauma 셰이크). `CameraPivot` 노드에 부착 | `set_follow_target` `glide_to_current` `orbit_yaw` `add_shake` | Camera3D(자식) only |
| [revive_controller.gd](../scripts/run/revive_controller.gd) | 131 | 🟢 타게팅 부활(F-010/D-020): 시동→시체/초상화 클릭→1.5s 빛기둥→HP50%. 자체 프롬프트 | `try_start` `handle_click` `is_active` `cancel` | party/combat/inv/sheet(ref) |
| [torch_carry_controller.gd](../scripts/run/torch_carry_controller.gd) | 145 | 🟢 횃불 carry/투척(F-021 §3.1.2): 빈슬롯 자동/선택→슬롯키 지면조준 투척. AimMarker+소모품바 사용 | `on_torch_pickup` `handle_consumable_key` `handle_click` | party/aim/bar/inv(ref) |
| [map_demo_layout.gd](../scripts/run/map_demo_layout.gd) | 580 | 6룸 절차생성(바닥/벽/조명/트리거)·navmesh 베이크 + **fatal 장판 carve 재bake**·**데이터주도 인터페이스**(`_room_points`/profile=rooms.json) | `get_spawn_position` `rebake_navigation` `_carve_zone` `_resolve_room_points` | NavigationServer3D, Slice01Data, group 'player'/'navmap' |
| [player_controller.gd](../scripts/run/player_controller.gd) | 34 | 조작 캐릭터 WASD→velocity (가속모델 옵션) | `_physics_process` | 부모 CharacterBody3D, InputMap |
| [party_light.gd](../scripts/run/party_light.gd) | 115 | F-011 시야결합 조명(멤버별 omni+spot)·플리커·룸감쇠 | `_build_rigs` `_on_room_changed` | PartyController/Map/Run (노드경로) |
| [hazard_zone.gd](../scripts/run/hazard_zone.gd) | 193 | 🟢 일반 지면 zone: `status`(Fatal/Oil/Fire/ToxicGas)·dps/slow/ttl·`impassable`(Fatal=carve+회피). **Oil=불투명 지면 슬릭(opaque, 적 안 가림)·기타=투명 텔레그래프(부유)**. DoT=apply_poison(파티)/raw(적). 피아무구분 F-021 | `setup` `clear_zone` `contains_point` `blocks_segment` | groups, call_group('navmap') |
| [trap.gd](../scripts/run/trap.gd) | 86 | 🟢 초크포인트 압력판: 조작멤버 통과→뒤에 HazardZone 스폰(분리)·`reset()`=소거+재무장 (F-006 트랩) | `reset` `has_active_zone` | HazardZone, group 'party_member' |
| [lever.gd](../scripts/run/lever.gd) | 75 | 🟢 상호작용 레버: `trap.reset()`=함정 회복(장판 해제·통로 재개) | `interact` `setup` | Trap |
| [barrel.gd](../scripts/run/barrel.gd) | 64 | 🟢 ENT-BARREL: HP 파괴 가능(AoE)→기름 HazardZone(슬로우 필드) 스폰; 화염 hit로 점화(RX-OIL-FIRE) | `take_damage` `_break` | HazardZone, group 'destructible' |
| [torch.gd](../scripts/run/torch.gd) | 252 | 🟢 ENT-TORCH: 휴대/투척 광원(F-021 §3.1.2). 점화시 콘플레임 플리커, 착지/오일접촉→`combat.ignite_at`. 제네릭 적-오브젝트 프로토콜(`enemy_usable`/`enemy_combat_tick`=어그로시 투척) | `pickup` `throw_to` `enemy_use` | combat(ignite_at), group 'destructible'/usable |
| [lantern.gd](../scripts/run/lantern.gd) | 85 | 🟢 거치형 고정 광원(주요 진입점/방 중앙): 금속기둥+박스하우징+steady OmniLight. 줍기 불가(횃불과 시각 차별화) | `_build` | OmniLight3D |
| [main.gd](../scripts/main.gd) | 166 | 🟢 **배치 허브**(F-010 §3.2/UI-005): 로드 게이트 + Identity 확정 + **스태시→캐릭터/백팩 장착**(InventoryUI 임베드, combat=null) + **포메이션 에디터** + Deploy 직렬화→RunLoadout→던전 | `_setup_hub` `_build_formation_editor` `_serialize_loadout` `_build_stash_items` | Slice01Data, PartyController, InventoryUI, FormationEditor, Stash/RunLoadout(런타임경로) |

### party — `scripts/party/`
| 파일 | L | 책임 | 핵심 심볼 | 의존 |
|------|--:|------|-----------|------|
| [party_controller.gd](../scripts/party/party_controller.gd) | **1280** | ⚠️ **갓오브젝트**: 스폰·스왑·결속(command-holder) + 포메이션 상태머신 + 슬롯기하/오프셋(get/set) + **스티어링 v1(~21 `_sv1_*`, ~530줄 지배덩어리)** + 설정로더 + fatal 회피 (MIA→MiaController, 전투교전·힐러무빙→CombatPositioning 분리) | `try_swap_to` `_update_command_holder` `_clamp_fatal` `get/set_slot_offset` `force_control_off` | party_cohesion, CombatPositioning, MiaController, party_member.tscn, player_controller, Slice01Data, NavigationServer3D, group 'fatal_zone' |
| [mia_controller.gd](../scripts/party/mia_controller.gd) | 151 | 🟢 MIA/이탈-leash 서브시스템(F-003 §3.3.1/§3.6.2): 비결속 거리 leash + 복귀실패 nav-path + warn→MIA 타이머 + 경계링. PartyController 자식; 컨텍스트는 접근자로 pull, 컨트롤 전환은 `party.force_control_off` 콜백 | `tick` `_reachable_dist` `_update_leash_ring` | party_controller(접근자/콜백), NavigationServer3D |
| [combat_positioning.gd](../scripts/party/combat_positioning.gd) | 111 | 🟢 전투우선 follower goal-point: 슬롯이탈 트리거(`enemy_in_party_basic_range`)·근접 attack-range 점·힐러 wounded 추종. PartyController 자식; `_members`만 백레퍼 | `has_live_enemies` `enemy_in_party_basic_range` `engage_target` | party_controller(`_members`), group 'enemy' |
| [party_member.gd](../scripts/party/party_member.gd) | 405 | 단일 슬롯: **Identity Gear 바인딩(gear→identity, F-008)** · **서브 스킬북 슬롯 Q/E/R(F-009)** · 스탯·스킬파라미터·HP/실드/상태(F-021)·넉백·navmesh·조작비주얼 | `setup` `_bind_gear` `equip_gear` `get_skillbook` `set_skillbook` `can_equip_skillbook` `take_damage` | health_bar, Slice01Data, groups 'party_member'/'player' |
| [party_cohesion.gd](../scripts/party/party_cohesion.gd) | 8 | F-003 결속 모드 enum(BOUND/UNBOUND) | `Mode` `MODE_*` | — |

### combat — `scripts/combat/`
| 파일 | L | 책임 | 핵심 심볼 | 의존 |
|------|--:|------|-----------|------|
| [combat_controller.gd](../scripts/combat/combat_controller.gd) | **494** | 🔸 코디네이터(적AI=EnemyAI·스킬=AbilityDispatch·반응=ReactionSystem 분리): ①인카운터/분대 스폰·증원 ②파티 자동공격 루프(basic) ③F-022 threat + 공간쿼리 ④engage/grace 소유 + camera_shake 시그널 ⑤`ignite_at` 퍼사드→ReactionSystem | `prespawn_encounters` `_spawn_squad` `_engage_enemy` `refresh_engage_grace` `_tick_party_attacks` `_deal_damage` `_enemies_in_*` `ignite_at` | EnemyAI, AbilityDispatch, ReactionSystem, Slice01Data, enemy_unit.tscn, skill_vfx, unit_visuals, spatial |
| [enemy_ai.gd](../scripts/combat/enemy_ai.gd) | 394 | 🟢 적 perception(시야콘+LOS+근접존)·전투행동(위협추적/LOS공격/시야상실추격/텔레그래프/피격시 발신원 수색). CombatController 자식; engage/grace/시그널은 컨트롤러 콜백 | `tick` `_tick_dormant` `_begin_enemy_attack` `_apply_enemy_hit` `attach_vision_cone` | combat_controller(콜백), skill_vfx, Slice01Data |
| [ability_dispatch.gd](../scripts/combat/ability_dispatch.gd) | **348** | 🟢 파티 Identity(자동) + **Sub=스킬북**(조작 전용) 스킬 효과 — kind 기반 디스패치(Identity 4 + **skillbook 4: strike/poison/stun/fire = 적 Shared AB** F-009). CombatController 자식; 공간쿼리/damage/셰이크는 컨트롤러 콜백, destructible·오일/파이어는 ReactionSystem 위임 | `try_identity` `cast_skillbook` `_cast_*` `_sb_*` | combat_controller(콜백), ReactionSystem, skill_vfx |
| [reaction_system.gd](../scripts/combat/reaction_system.gd) | 100 | 🟢 월드오브젝트 AoE + 위험요소 화학(F-021/F-027): destructible 파괴(ENT-BARREL) + **RX-OIL-FIRE-001** 오일점화 체인(폭발+Fire/ToxicGas zone, depth-limited) + `ignite_at`(횃불 FireDamageHit). AbilityDispatch가 분리(DEBT-GOD2) | `damage_destructibles` `fire_hit` `ignite_at` `_ignite_oil` `_explosion` | combat_controller(셰이크), HazardZone, skill_vfx, groups 'destructible'/'ground_zone' |
| [enemy_unit.gd](../scripts/combat/enemy_unit.gd) | 527 | 단일 적: 데이터 스탯·F-022 threat·slow/knockback·**perception(facing/scan/cone VFX/alert)·navmesh 캐시·investigate·피격발신원 수색**·박스메쉬·HP바·제네릭 오브젝트 상호작용(`enemy_usable`) | `setup` `add_threat` `pick_target` `scan` `face_toward` `nav_*` `build_vision_cone` `perceive_attacker` | health_bar, NavigationServer3D, group 'enemy' |
| [health_bar.gd](../scripts/combat/health_bar.gd) | 129 | 아군/적 공용 빌보드 HP바(프레임/배경/필/타겟·임박 마커) | `set_ratio` `set_target` `set_imminent` | 카메라(프레임당 조회) |
| [skill_vfx.gd](../scripts/combat/skill_vfx.gd) | 224 | 무상태 절차 PH VFX 라이브러리(역할별 자동소멸) | `anchor_guard` `press_line` `mark_ruin` `mend_circle` `sub_*` `enemy_vfx` | Godot 메쉬/트윈 only |

### ui — `scripts/ui/`
| 파일 | L | 책임 | 핵심 심볼 | 의존 |
|------|--:|------|-----------|------|
| [party_sheet.gd](../scripts/ui/party_sheet.gd) | 152 | UI-002 좌상단 4인 로스터(초상/HP/서브쿨/상태핍) | `setup` `_build_slot` `_process` | radial_cooldown, 멤버 덕타이핑 |
| [controlled_sheet.gd](../scripts/ui/controlled_sheet.gd) | 110 | UI-003 하단 조작캐 액션바(초상/HP/Identity+Q/E/R 쿨) | `setup` `_process` | radial_cooldown, PartyController |
| [radial_cooldown.gd](../scripts/ui/radial_cooldown.gd) | 45 | 쿨다운 라디얼 웨지 Control(쿨/상태핍 겸용) | `set_cd` `set_icon_color` `_draw` | — |
| [settlement_panel.gd](../scripts/ui/settlement_panel.gd) | 163 | 🟢 F-007 §3.8 런 정산 화면(중앙 박스: 결과·생존/전사·카테고리요약·스크롤 상세). 순수 표현 — `run_settled(summary)` 구동 | `show_settlement` `_build` `_category_summary` | summary dict only |
| [aim_marker.gd](../scripts/ui/aim_marker.gd) | 51 | 🟢 지면조준 마커(가시일 때 마우스 자동추종). 스킬북조준·횃불투척 공유 | `show_at` `hide_marker` `ground_pos` | 카메라/뷰포트 |
| [controlled_indicator.gd](../scripts/ui/controlled_indicator.gd) | 60 | 🟢 UI-001 조작캐 표시(발판디스크+bob 화살표). setup(party) 후 자기 추종 | `setup` `_process` | PartyController(ref) |
| [loadout_stub.gd](../scripts/ui/loadout_stub.gd) | 37 | 메뉴 로드아웃 스텁(4 Identity 표시·확정) | `populate_from_data` `loadout_confirmed` | Slice01Data |
| [inventory_ui.gd](../scripts/ui/inventory_ui.gd) | **663** | 🔸 인벤 코디네이터(§6 DEBT-INV 대부분 해소): 백팩(영속)+루트/컨테이너 그리드 + **공유 드래그 라우터**(`_drop`/`_update_drag`/`_revert_drag`/회전/합치기) + 윈도우 + EquipPanel/ConsumableController에 위임. 빌더는 ItemFactory | `setup_party` `open_loot` `start_drag_from_slot` `backpack_grid` `_drop` `_do_split` | InventoryGrid, ItemFactory, EquipPanel, ConsumableController, Slice01Data |
| [equip_panel.gd](../scripts/ui/equip_panel.gd) | 501 | 🟢 캐릭터 장비 슬롯(F-008)+서브 Q/E/R(F-009) UI·규칙·슬롯드래그아웃·드롭프리뷰. InventoryUI 자식; 중앙 드래그는 `_inv` 콜백 | `build` `refresh` `try_equip_gear` `try_equip_sub` `update_previews` `revert_*` | inventory_ui(backref), ItemFactory, Slice01Data |
| [consumable_controller.gd](../scripts/ui/consumable_controller.gd) | 204 | 🟢 소모품 스택·Z/X/C 핫키·게임플레이 사용(F-010). 바 위젯 구동, 백팩은 `_inv.backpack_grid()` | `add_to_backpack` `use` `assign_hotkey` `count` `consume` | inventory_ui(backref), ItemFactory, Slice01Data |
| [item_factory.gd](../scripts/ui/item_factory.gd) | 56 | 🟢 순수 아이템 dict 빌더(gear/skillbook/consumable). 무상태 static | `gear_item` `skillbook_item` `consumable_item` `consumable_color` | UnitVisuals |
| [consumable_bar.gd](../scripts/ui/consumable_bar.gd) | 131 | 🟢 화면 Z/X/C 바 위젯(슬롯 표시·`slot_grabbed`·`slot_under`·횃불 carry 오버레이). ConsumableController가 구동 | `refresh` `slot_under` `set_interactive` `set_carry` | (표시 only) |
| [inventory_grid.gd](../scripts/ui/inventory_grid.gd) | 260 | 🟢 격자 배치/충돌/footprint 위젯(아이템 dict 셀 점유) | `add_item_dict` `can_place` `item_at` `place` | — |
| [pip_camera.gd](../scripts/ui/pip_camera.gd) | 244 | 🟢 UI-006 §7 PIP 카메라(MIA 멤버 표시·3s 강조→8s 자동최소화·수동토글·재오픈 쿨다운) | `set_targets` `_minimize` `toggle` | PartyController(pip_targets), SubViewport |
| [formation_editor.gd](../scripts/ui/formation_editor.gd) | 92 | 🟢 탑다운 드래그 포메이션 에디터(4 역할 토큰→슬롯 오프셋, 중앙=리더). 허브 전용 | `setup` `get_offsets` | — |
| [stash_source.gd](../scripts/ui/stash_source.gd) | 7 | 🟢 chest 덕타이핑 컨테이너 소스(스태시를 InventoryUI에 띄우기 위함) | `title` `items` | — |
| [enemy_info.gd](../scripts/ui/enemy_info.gd) | 166 | 적 정보 패널(호버/타겟 적 스탯·상태) | `show_for` `_process` | enemy_unit(덕타이핑) |

### scenes — `scenes/`
`main.tscn` · `run/dungeon_run.tscn` · `party/party_member.tscn`(원기둥 PH) · `combat/enemy_unit.tscn`(박스 PH). 메쉬·색·크기는 런타임에 덮어쓴다.

---

## 4. 데이터 파이프라인

`data/slice01/*.json` → [slice01_data.gd](../scripts/core/slice01_data.gd)가 로드·검증·링크:

- `manifest.json` (phase/contract/pool→encounter 바인딩) · `id_registry.json` (허용 ID) · `blueprint.json` · `rooms.json` · `formation.json`
- `identities.json` (역할→`ability_id`/`sub_ability_id`) · `enemies.json` (적→`abilities[].ref`) · `abilities.json` (**통합 카탈로그**, AB-### → kind/효과) · `encounters/ENC-*.json`
- `gear.json` (**Identity Gear 마스터**: `base_gear_id` → `bundled_identity_skill_id` → identities; F-008 §3.7 · `DEC-20260611-001`) — 캐릭터 **identity는 장착 gear에서 파생**(`party_member._bind_gear`). 미장착 looted gear = run-inventory At Risk(인벤 `kind:"gear"`).
- `skillbooks.json` (**Skillbook 마스터**: `base_ability_id`(적 lootable AB Shared) → 탄수·`equip_classes`·player-cast; F-009 · `DEC-20260611-002`) — **서브 Q/E/R = 루팅 스킬북**(`party_member.skillbook_slots`); 적 처치 **per-kill** 드랍 → run-inventory At-Risk(인벤 `kind:"skillbook"`).
- `consumables.json` (**소모품 마스터**: `consumable_id` → `effect`·`max_stack`·`usable_in_combat`; F-010 / D-020) — 인벤 스택 아이템(`kind:"consumable"`) + **Z/X/C 핫키**(`ui/consumable_bar.gd`, 6시 시트 위); 부활 스크롤=다운 아군 부활(휴식중, `party_member.revive`). 인-런 부활=SPEC_DRIFT-027(전파 후보).
- 캐릭터/유닛은 **ID로 어빌리티를 링크**한다(인라인 정의 금지). "한 번 정의 → 어디서나 할당".

> ⚠️ `abilities.json`은 현재 `id_registry`와 대조 **검증되지 않는다**(§6 DEBT-DM1). 다른 도메인(enemies 등)은 `require_id`로 검증됨.

---

## 5. 핵심 규약 (dev_templates 기준 + 현 레포 편차)

- ID 1:1: 코드/데이터의 문자열 ID는 spec과 **그대로** (`tank_anchor_guard`, `ENC-NORM-001`, `P-ADV-01` …). 별칭 금지.
- 미등록 ID → abort: 로드 시 `require_id`로 차단 (현재 abilities 도메인은 누락).
- 규칙 SSOT 복사 금지: F/QA 전문을 주석에 붙이지 말고 `## ref:` 한 줄 + spec 경로만.
- 단일 책임: 1 파일 = 1 책임. **현 편차:** `party_controller.gd`(§6 DEBT-GOD — `CombatPositioning`+`MiaController` 분리로 **1280**, 잔여 SteeringV1). 🔸 `combat_controller.gd`은 `EnemyAI`+`AbilityDispatch`+`ReactionSystem` 분리로 **494줄**(§6 DEBT-GOD2, 잔여: EncounterSpawner/Squad). 🟢 `dungeon_run.gd`은 1115줄 재증식 후 **SettlementPanel + 모달 패밀리 + Loot/RunEnd 분리로 1115→487**(§6 DEBT-GOD3; 씬부트+입력라우터+월드스폰+HUD로 수렴). 🔸 `inventory_ui.gd`는 ItemFactory+EquipPanel+ConsumableController 분리로 **1273→663**(§6 DEBT-INV).
- 도메인 폴더: `core/run/party/combat/ui` (dev_templates의 `features/F###_*` per-feature 컨벤션과는 다름 — 의도적 단순화).

---

## 6. 기술 부채 레지스터 (효율화 체크 결과)

> `risk_to_fix` = **게이트/라이브 흐름 회귀 위험**. `now` = 안전(P4에서 정리), `defer` = 라이브 전투/스티어링 흐름을 건드림(P6 전체 리팩토링 + 검증 동반).
> 출처: 2026-06-08 read-only 아키텍처 서베이(9-agent).

### 갓오브젝트 / 죽은 코드
| ID | 항목 | 위치 | sev | 처리 |
|----|------|------|-----|------|
| DEBT-GOD | 🔸 **부분(P6.1·6.2 + 2026-06-10)** — v0 엔진·데드로직·팔레트 제거 + **CombatPositioning 분리**(전투교전·힐러, `combat_positioning.gd` 111) + **데드 v0 config 17종 정리**(DEBT-V0)로 1623→1014줄. 이후 1b 기능(MIA/fatal/슬롯오프셋) 재증식 1396 → **MiaController(`mia_controller.gd` 151) 분리로 1280**(2026-06-13). 잔여 추출 단위(우선순위): **①`SteeringV1`(~21 `_sv1_*`, ~530줄 — 최대 덩어리, 고위험·config 소유권 재설계 동반)** / `FormationConfig`(설정로더) / `FormationForward`(상태머신) | party_controller.gd | high | **부분 DONE** |
| DEBT-GOD2 | 🔸 **대부분 해소(2026-06-10)** — **EnemyAI**(`enemy_ai.gd` 301) + **AbilityDispatch**(`ability_dispatch.gd` 197) 분리로 854→408줄. 이후 skillbook 핸들러+RX-OIL-FIRE 재증식(ability_dispatch 431) → **ReactionSystem(`reaction_system.gd` 100, destructible+오일/파이어 체인) 분리로 ability_dispatch 348**(2026-06-13). 셋 다 자식 노드, 공유 시스템(engage/grace/threat/공간쿼리/셰이크)은 컨트롤러 단일소유 + 콜백. 잔여 추출 단위: `EncounterSpawner/SquadManager`(스폰·증원·분대 — `_squads` 상태 소유, combat_controller 494) | combat_controller.gd, enemy_ai.gd, ability_dispatch.gd, reaction_system.gd | high | **부분 DONE** |
| DEBT-GOD3 | 🟢 **대부분 해소(2026-06-13, 3라운드)** — CameraRig 분리 후 정산·횃불·부활·루트 누적 1115줄 재증식. ① `SettlementPanel`(163) ② 모달 패밀리 `AimMarker`·`ControlledIndicator`·`ReviveController`·`TorchCarryController`·`AimController` ③ `LootService`(77)·`RunEndController`(173, 탈출채널+정산조합+전멸). dungeon_run은 **씬부트+입력라우터+월드스폰+HUD콜백**으로 수렴 **1115→455줄(-660)**. 잔여(저위험): 라우터 ModalStack 정식화·_ready 월드스폰 빌더 분리 | dungeon_run.gd + 컨트롤러 8종 | high | **대부분 DONE** |
| DEBT-INV | 🔸 **대부분 해소(2026-06-13, 3라운드)** — `inventory_ui.gd` 1273줄 갓-UI를 **ItemFactory(56, 순수 빌더) + EquipPanel(501, 장착/서브 슬롯, backref) + ConsumableController(204, 핫키/사용, backref) 분리로 1273→663(−48%)**. 코디네이터는 **공유 드래그 라우터 + 백팩/루트 그리드 + 윈도우**로 수렴(정상 크기). 분리한 패널은 `_inv` 콜백(start_drag_from_slot/is_dragging/backpack_grid/_msg)으로 중앙 드래그 상태 사용; 외부 소모품 API는 델리게이트 래퍼로 보존. **잔여(선택·defer):** 드래그 라우터를 분기→패널 자가등록 **레지스트리 재설계**(한계효용 작음). ⚠️ 드래그/장착/핫키는 헤드리스 검증 불가 — 플레이테스트로 확인 | inventory_ui.gd, equip_panel.gd, consumable_controller.gd, item_factory.gd | med | **대부분 DONE** |
| DEBT-V0 | ✅ **완전 해소(2026-06-10)** — 죽은 v0 추종엔진 삭제 + **잔여 데드 config 17종 제거**(tank_follow 보정/리버설 6 + v0 separation 7 + preferred_anchor/lateral/slot_arrive/path_clearance 4, 선언+로더). sv1은 `_sv1_*` config만 사용 | scripts/party/party_controller.gd | med | **DONE** |
| DEBT-DEAD1 | ✅ **해소(2026-06-10)** — no-op `_sync_tank_follow_collision`(+호출 2곳) 제거. `set_party_member_collision(false)`가 어디서도 안 불려 스폰 기본값 재확인일 뿐이었음. (setter 자체는 1b 상태시스템용 API로 보존) | party_controller.gd | low | **DONE** |
| DEBT-DEAD2 | 🔸 `party_in_combat` 이중관리 **해소(②)**. `run_controller.can_swap()` 항상 true 스텁은 Control Lock/MIA 미구현이라 **의도적 잔존** | run_controller.gd:66 | low | 부분 DONE |

### 중복
| ID | 항목 | 위치 | sev | 처리 |
|----|------|------|-----|------|
| DEBT-DUP-COLOR | ✅ **해소(P6.2b)** — `scripts/core/unit_visuals.gd` 단일 팔레트(role_color/role_scale/enemy_visual)로 통합, party+combat 호출 | scripts/core/unit_visuals.gd | med | **DONE** |
| DEBT-DUP-HP | ✅ **해소(P4)** — 공유 `ui_colors.gd:hp_color(r)`로 단일화, 3파일 호출. (구: 노랑/빨강 값 갈라진 시각버그) | scripts/core/ui_colors.gd | med | **DONE** |
| DEBT-DUP-SPATIAL | 🔸 **해소(④)** — `scripts/core/spatial.gd` `h_dist2`로 combat 4개 쿼리(radius/lowest-hp/allies/nearest) 통합. 잔여: party_controller `_combat_engage_target`(3D 메트릭, 의도적 보존)·enemy_unit pick_target | scripts/core/spatial.gd | low | 부분 DONE |
| DEBT-DUP-MAT | StandardMaterial3D/메쉬 PH 빌더 중복(언셰이드+알파 디스크는 dungeon_run 안에서도 2회) | dungeon_run.gd:149-200, map_demo_layout.gd:235-298, party_member.gd:168, enemy_unit.gd:233 | low | **now (P4)** → 머티리얼 팩토리 |
| DEBT-DUP-HPBAR | 2D HP바 위젯이 2곳에서 손수 재구현 | party_sheet.gd:83, controlled_sheet.gd:51 | low | now (P4, 선택) |
| DEBT-DUP-CD | 쿨다운 비율식 `cd/params.cooldown_s` 인라인 복붙(div-by-zero 가드 포함) | party_sheet.gd:132, controlled_sheet.gd:97 | low | now (P4) → 멤버 `*_cd_ratio()` 접근자 |

### 비효율 (프레임당 핫패스)
| ID | 항목 | 위치 | sev | 처리 |
|----|------|------|-----|------|
| DEBT-EFF-GRP | 🔸 **부분(⑤)** — combat의 party_member 중복 재스캔 제거(틱당 1회 fetch→스레딩). 잔여: party_controller의 `'enemy'` 그룹 O(추종자) 재스캔 + 추종자별 레이캐스트 (P6.3 분해와 함께) | party_controller.gd | med | 부분 DONE |
| DEBT-EFF-RAY | 스티어링 v1이 추종자당 프레임당 레이캐스트 6~15회(벽/경로). 스로틀·캐시 없음 | party_controller.gd:914-1012 | med | **defer (P6)** |
| DEBT-EFF-ALLOC | 프레임당 Dictionary/RNG 신규할당(`peer_slot_targets`, reposition RNG) | party_controller.gd:574,590,643,731 | low | defer (P6) |
| DEBT-EFF-HPBAR | HP바마다 프레임당 카메라 조회 + 트랜스폼 재구성 | health_bar.gd:51-60 | low | now/선택 (빌보드 플래그) |

### 결합 / 데이터모델
| ID | 항목 | 위치 | sev | 처리 |
|----|------|------|-----|------|
| DEBT-CPL-COMBAT | ✅ **해소(②)** — CombatController가 단일 소유(`is_in_combat()` + combat_started/ended). PartyController는 `bind_combat()`로 **구독**해 `_in_combat` 캐시. run_controller 중복 제거, dungeon_run의 bool 포킹 제거. 1b 전투반응 시스템은 구독만 하면 됨 | combat_controller.gd, party_controller.gd | med | **DONE** |
| DEBT-CPL-DUCK | CombatController가 party_member 필드 ~20개를 가드 없이 덕타이핑; 스킬 'kind' 4종 하드코딩 | combat_controller.gd:91-123 | med | defer (P6) — 타입드 계약 + 테이블 디스패치 |
| DEBT-CPL-HUD | dungeon_run이 HUD 라벨 11개 노드경로를 하드코딩·직접 set; 한글 상태문자열 .tscn과 중복 | dungeon_run.gd:10-20,230-261 | med | defer (P6) — `RunInfoPanel` 노드로 분리 |
| DEBT-CPL-GROUP | controlled/alive/room-trigger 상태가 문자열 그룹으로 멀티플렉싱(member에서 mutate, 여러 시스템이 read) | party_member.gd:96-111,397 | med | defer (P6) |
| DEBT-OTHER-AWAIT | ✅ **해소(③)** — `await` 제거. 프레임 구동 윈드업 상태머신(`enemy.winding`/`windup_timer_s`, `_tick_enemy`에서 tick)로 전환. `_begin_enemy_attack`→`_resolve_enemy_attack`→`_apply_enemy_hit` 분리. 전투 결정론적 | combat_controller.gd, enemy_unit.gd | med | **DONE** |
| DEBT-DM1 | `abilities.json` 로드 시 `require_id` 미수행 → "미등록 ID→abort" 규칙이 어빌리티만 무력화 | slice01_data.gd:211-213 | med | **now (P3)** — 코드 가드 버그 |
| DEBT-DM2 | `ENEMY_VISUALS` 색/크기가 enemies.json과 분리(컨트롤러 리터럴) | combat_controller.gd:23-32 | low | now/선택 (PH 아트) |
| DEBT-DM3 | 🔸 **부분 해소** — `lighting_profile`은 `rooms.json`(SSOT)로 통일(`_room_profile`), 맵 인터페이스(spawn/extraction/size)는 `_room_points` 런타임 테이블로 분리 → **Blender 실맵 교체 시 콜러 무수정**(getter가 ROOM_SPECS 직접참조 안 함). 잔여: 룸 **기하**(center/size)는 ROOM_SPECS 상수(placeholder, Blender가 대체 예정) | map_demo_layout.gd, rooms.json | med | **부분 DONE** |

**가장 깨끗한 파일:** `skill_vfx.gd`(무상태·정적), `health_bar.gd`(단일책임·무결합), `party_cohesion.gd`. 신규 코드의 참고 모델.

---

## 7. 참고
- 거버넌스·스펙 전파 규칙: [AGENTS.md](../AGENTS.md) · [CLAUDE.md](../CLAUDE.md)
- 스펙 드리프트 대장: [docs/SPEC_DRIFT.md](SPEC_DRIFT.md)
- 코드측 결정 기록: [docs/impl_decisions/ImplDecisionLog.md](impl_decisions/ImplDecisionLog.md)
- Phase 1a 작업순서(역사): [plan/phase-1a-slice01/WORK_ORDER.md](../plan/phase-1a-slice01/WORK_ORDER.md)

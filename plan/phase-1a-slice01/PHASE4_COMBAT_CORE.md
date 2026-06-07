# Phase 1a · 4단계 — 전투 코어 (Combat Core) 진행 문서

> **상위 문서:** [WORK_ORDER.md](./WORK_ORDER.md) 4단계 · spec pin `cd6009e` @ `staging`
> **목적:** 4단계 구현 플랜 + 체크리스트 + 진행 로그를 한 곳에. **중단돼도 이 문서만 읽으면 맥락 복구**.
> **갱신 규칙:** 체크포인트 완료마다 ① 체크박스 체크 ② "진행 로그"에 1줄 추가 ③ "현재 상태/다음 할 일" 갱신.

---

## 0. 목표 / 게이트

임의 테스트 ENC 없이 **"스폰 → 전투 → 종료" 루프 동작**.
- 종료 = 적 **전멸(승리)** 또는 **120s 타임아웃**.
- 비주얼 = 박스+난색 PH (아군 원기둥과 도형으로 구분).
- **서브 skillbook 자동발동 없음** (QA-030/QA-005 §2.6 — FAIL 조건).

## 1. 확정 결정 (locked)

| 항목 | 결정 |
|---|---|
| 파티 공격 범위 | **공용 기본공격** — 전 파티원 자동, 사거리 내 최근접 적. identity main skill은 **5단계**로 분리 |
| 스탯 데이터 위치 | **기존 json 확장** — `enemies.json`·`identities.json`에 stats/combat 블록 (데모 PH, lenient 파싱) |
| 진영 구분 | 적 = group `"enemy"` + collision layer **3(신규)**. 타겟팅은 **거리 기반** |
| 스폰 오케스트레이션 | `RunController`(로직)는 시그널만 emit, 스폰은 씬 노드 `CombatController`가 담당 |

## 2. 데이터/코드 구조 참조 (재독 방지용 메모)

- 적 데이터: [enemies.json](../../data/slice01/enemies.json) — 현재 `enemy_id/role/display_name`만. **stats 없음 → 추가 대상**.
- 인카운터: [ENC-NORM-001.json](../../data/slice01/encounters/ENC-NORM-001.json) — `units: [{enemy_id,count,slot}]`, group_size 5 (EN-001×1, EN-010×2, EN-011×1, EN-012×1).
- 로더: [slice01_data.gd](../../scripts/core/slice01_data.gd) — `get_encounter(id)`, `get_pool_encounter(pool)`, `_enemies` 보유. `_parse_enemies` L165, `get_encounter` L58.
- 런 상태: [run_controller.gd](../../scripts/run/run_controller.gd) — `party_in_combat`(L17, 미사용), `can_swap`(L58), 스폰 훅 자리 **L71** ("spawn deferred step 4+"), 룸 진입 `on_player_entered_room` L62.
- 씬 루트: [dungeon_run.gd](../../scripts/run/dungeon_run.gd) — `_party.party_in_combat = _run.party_in_combat` 1회 대입 **L24 → 반응형 교체 필요**.
- 파티 엔티티 패턴: [party_member.gd](../../scripts/party/party_member.gd) `setup()`/메쉬빌드/group, [party_member.tscn](../../scenes/party/party_member.tscn) CharacterBody3D+Capsule+Mesh.
- 맵: [map_demo_layout.gd](../../scripts/run/map_demo_layout.gd) — RM-ADV-01 center `(0,0,32.25)` size `(42,0,42)`. `get_spawn_position(room_ref)` L85.
- 레이어: [project.godot](../../project.godot#L84) layer_1=world, layer_2=party. **layer_3=enemy 추가 필요**.

### PH 비주얼 사양 (WORK_ORDER §코드 PH)
적: BoxMesh + 난색 — EN-001 진홍 `#C03030`(대), EN-010 주황 `#D08020`, EN-011 황 `#C0B030`(소), EN-012 갈적 `#8B4020`(대).

## 3. 데이터 추가 스펙 (데모 PH 수치 — spec 밸런스 아님)

`enemies.json` 각 적에 `stats` 블록, `identities.json` 각 파티원에 `combat` 블록. 없으면 기본값 머지(lenient).

```jsonc
// enemies.json 적 항목 예
"stats": { "hp": 60, "move_speed": 3.5, "contact_damage": 6, "attack_range_m": 1.6, "attack_interval_s": 1.2 }
// EN-001 elite: hp↑ 속도↓ / EN-012 slow bulk: hp↑ 속도↓↓ / fodder: hp↓

// identities.json 파티 항목 예
"combat": { "hp": 120, "basic_damage": 10, "basic_range_m": 2.0, "basic_interval_s": 0.8 }
// Tank: hp↑ dmg↓ / DPS: dmg↑ / Healer: hp중 dmg↓
```

---

## 4. 빌드 체크포인트 (순차 · 각 체크포인트 F5 검증)

- [x] **CP1 — 데이터+게터**: enemies/identities json에 stats/combat 추가, `slice01_data`에 `get_enemy_row(id)` + lenient 스탯 파싱. → **로드 회귀 없음** 확인. ✅ JSON 파싱 검증 통과, 추가 필드는 검증기 무시.
- [x] **CP2 — enemy PH 엔티티**: `scenes/combat/enemy_unit.tscn` + `scripts/combat/enemy_unit.gd` (setup/HP/`take_damage`/박스메쉬/group "enemy"/layer 3). project.godot `layer_3="enemy"` 추가. ✅ 코드 완료 (런타임 F5 검증 대기).
- [x] **CP3 — 스폰 파이프라인 (4.2)**: `RunController.encounter_triggered` 시그널(+emit) + `scripts/combat/combat_controller.gd` (DungeonRun 자식, ENEMY_VISUALS 난색 매핑) + dungeon_run 와이어링. RM-ADV-01 진입 시 units 펼쳐 스폰. ✅ 코드 완료 (런타임 F5 검증 대기).
- [x] **CP4 — 적 추격 + HP 배관 (4.1·4.3)**: 적이 최근접 파티원 추적 이동(attack_range에서 정지). **접촉 데미지 제외(사용자 지시 2026-06-07)** — 데미지는 명시적 공격으로. party_member에 HP/`take_damage`/`is_alive`/`downed` 배관 추가(범용). ✅ 코드 완료 (F5 검증 대기).
- [x] **CP5 — 파티 기본공격 + 종료 (4.4)**: 전 파티원 자동 기본공격(명시적 in-range, 최근접 적 `basic_damage`/`basic_interval_s`), 전멸=승리 / 120s=타임아웃 → `combat_started`/`combat_ended` 시그널 + 콘솔 로그. ✅ 코드 완료 (F5 검증 대기).
- [x] **CP6 — partyInCombat 토글 (4.1 완성·E)**: combat_started/ended → dungeon_run에서 run+party `party_in_combat` **상태** 토글(백페달 commit 억제 등에 사용). ⚠️ **스왑은 막지 않음** — F-001 §3.3 전투 중 스왑 허용. (초기 구현이 스왑을 막아 2026-06-07 정정, 아래 CP6-fix 참조) ✅
- [x] **CP7 — 게이트 스모크**: 스폰→전투→종료(victory 29.8s) 1회 완주 로그 확인(2026-06-07 사용자 F5). 서브 auto 경로 없음(basic만). ✅ **4단계 게이트 충족**.

**4.5 (서브 차단):** 파티 공격에 basic만 존재. sub/passive skillbook 호출 경로를 만들지 않음. `## ref: QA-005 §2.6` 주석.

---

## 5. 진행 로그 (append-only)

> 형식: `YYYY-MM-DD · CPn · 요약 · 산출 파일`

- 2026-06-07 · CP0 · 플랜 문서 작성, 결정 2건 locked, 빌드 순서 확정 · `PHASE4_COMBAT_CORE.md`
- 2026-06-07 · CP1 · enemies.json(+stats)·identities.json(+combat) 확장, `get_enemy_row()`+기본값 머지 추가, JSON 파싱 검증 통과 · `enemies.json`, `identities.json`, `slice01_data.gd`
- 2026-06-07 · CP2 · enemy PH 엔티티(box+난색, HP/take_damage/died, group enemy/layer3) · `scenes/combat/enemy_unit.tscn`, `scripts/combat/enemy_unit.gd`, `project.godot`(layer_3)
- 2026-06-07 · CP3 · 스폰 파이프라인: RunController.encounter_triggered emit + CombatController 스폰 + dungeon_run 와이어링 · `run_controller.gd`, `scripts/combat/combat_controller.gd`, `scenes/run/dungeon_run.tscn`, `dungeon_run.gd`
- 2026-06-07 · CP3-fix · 플레이어가 적 통과 문제 수정: 파티 `MASK_PARTY` 3→7(enemy 레이어 차단), 적 충돌 캡슐→**BoxShape3D**(비주얼 박스와 일치, 모서리 겹침 제거), box_scale 반영 · `party_member.gd`, `enemy_unit.gd`, `enemy_unit.tscn`, `combat_controller.gd`
- 2026-06-07 · CP4 · 적 추격 이동(`_physics_process` seek, attack_range 정지), party_member HP/take_damage/downed 배관. **접촉 데미지 제외(사용자 지시)**. 충돌박스 메쉬 정렬(바닥 튐 방지) · `combat_controller.gd`, `party_member.gd`, `enemy_unit.gd`
- 2026-06-07 · CP5 · 파티 기본공격(in-range, `_tick_party_attacks`)+종료조건(전멸/120s)+combat_started/ended 시그널 · `combat_controller.gd`
- 2026-06-07 · CP6 · partyInCombat 토글 배선(combat 시그널→run/party 플래그) · `dungeon_run.gd`
- 2026-06-07 · CP6.5 · 시각 피드백(사용자 요청): 유닛별 떠있는 HP **바**(`health_bar.gd`, 수동 빌보드·좌측앵커·색 단계) + 피격 흰색 플래시. 초기 숫자 라벨에서 바 형태로 교체 · `health_bar.gd`, `enemy_unit.gd`, `party_member.gd`
- 2026-06-07 · CP6-fix · **스왑이 전투 중 막히던 버그 정정**. 스펙 확인 결과 F-001 §3.3 "전투/비전투 무관 스왑" → 스펙은 옳고 게임 코드가 위반. `can_swap()`/`_can_swap()`에서 partyInCombat 게이트 제거(항상 허용; Control Lock·MIA만 차단은 미구현). WORK_ORDER 3.4 문구 정정 · `run_controller.gd`, `party_controller.gd`, `dungeon_run.gd`, `WORK_ORDER.md`
- 2026-06-07 · CP6.7 · HP 바 → 진짜 바 그래픽(`health_bar.gd`)으로 교체 완료(위 CP6.5 갱신)
- 2026-06-07 · **전투 교전 동작**(사용자 요청, 5단계 선취): 전투 중 팔로워가 슬롯을 버리고 최근접 적에게 접근→교전(`_combat_engaging`, `_combat_engage_target`). 전투 종료/적 전멸/후퇴 시 자동으로 포메이션 복귀. **후퇴핑 훅** `set_retreat(active)` 추가(입력 미연결 — 나중에 핑으로) · `party_controller.gd`
- 2026-06-07 · 공격 사거리 판정 수평(x,z)化 + **Y축 지면 정렬**: 파티가 1.7m 떠 있어 일부 역할이 공격 누락 → `_nearest_enemy_in_range` 수평거리, 파티 캡슐 발-원점 정렬(`$CollisionShape3D.position.y=h/2`), 스폰 +1.2 제거, `get_spawn_position` +0.5→+0.02. 파티·적 모두 바닥에 닿음 · `combat_controller.gd`, `party_member.gd`, `party_controller.gd`, `map_demo_layout.gd`
- 2026-06-07 · 교전 재타겟 개선(팔로워가 적 죽인 뒤 멈추던 문제): 교전 중 분리력 F_sep ×0.35(뭉친 무리 뚫고 다음 적으로 이동) + 교전 정지거리 0.85×사거리→`사거리-0.6`(사거리 안쪽 확보, 지터로 밀려도 공격 유지) · `party_controller.gd`. ※ 컨트롤 캐릭터는 플레이어 조종이라 안 움직이면 사거리 내 적만 공격(정상).
- 2026-06-07 · 아군 스택(탱 위에 DPS) 수정: Y 그라운딩 후 뭉칠 때 캡슐이 위로 타고 올라가는 문제 → 파티끼리 **물리 충돌 제거**(`MASK_PARTY` 7→5, world+enemy만). 아군 간격은 스티어링 분리력으로만(ARPG 표준). 벽·적 충돌은 유지 · `party_member.gd`
- 2026-06-07 · **적 공격 추가**(사용자 선택): 적이 사거리 내에서 `attack_interval_s`마다 `contact_damage`로 파티 타격(명시적 in-range, 접촉 아님). 파티원 피격 시 HP바↓+플래시. 다운 시 그룹 제외·steering 정지(시신처럼 잔류). **컨트롤 캐릭터 다운→살아있는 멤버로 자동 스왑**(스턱 방지). 전멸 시 경고 로그 · `combat_controller.gd`, `party_controller.gd`
- 2026-06-07 · HP바 깜빡임(가끔 0으로 보임) 수정: 배경/채움 투명 정렬이 뒤집히던 문제 → 채움 머티리얼 `render_priority=1`로 항상 앞에 그리도록 고정 · `health_bar.gd`
- 2026-06-07 · **진형우선 토글**(후퇴핑 대체, 사용자 지시): `_formation_priority` + 단축키 **F**. OFF=전투우선(교전), ON=슬롯유지 우선(전투 중에도 진형 유지, 사거리 들어온 적만 공격). HUD에 전투우선/진형우선 표시 + 시그널 · `party_controller.gd`(`toggle_formation_priority`/`is_formation_priority`), `dungeon_run.gd`, `dungeon_run.tscn`(HUD 라벨), `project.godot`(F 입력)
- 2026-06-07 · **키맵 정리**(F 충돌 해소): 스왑 1-4→**F1~F4**(F-001 §3.5 데모 기본값에 맞춤), 1/2/3은 서브 스킬용으로 비움. **스펙 직접 수정**: 소모품 E/R/F→**E/R/T**(F 비움) · `project.godot`, `dungeon_run.gd`(힌트). 스펙 변경: `project_tdc_spec` F-020 §3.2.1·OQ-1, UI-005 §3 → spec 레포 커밋 **cd6009e**(staging, "인런 키 바인딩 정리"). 게임 레포 **재핀 완료**(`spec_ref.json`·`id_registry.json` → cd6009e)

## 6. 현재 상태 / 다음 할 일

- **현재:** CP1~CP6 코드 완료 → **전투 루프 닫힘**. RM-ADV-01 진입 시: 5체 스폰 → 적 추격 접근 + 파티 자동 기본공격으로 적 처치 → 전멸 시 `victory`(또는 120s `timeout`)로 종료. 전투 중 스왑 차단. (적→파티 데미지는 보류, 파티 일방 공격으로 종료 루프 성립)
- **검증 방법(F5) = CP7 게이트:**
  1. RM-ADV-01 진입 → `[TDC] Encounter ENC-NORM-001 spawned ... (5 units)` + `[TDC] partyInCombat=true`
  2. 적이 몰려오고, 콘솔에 `[CBT] <member> -> <EN> -N (hp..)` 데미지 로그, 박스가 하나씩 사라짐
  3. 전멸 시 `[TDC] Encounter ... ended: victory` + `[TDC] partyInCombat=false`
  4. **전투 중에도 1~4 스왑 정상 동작**(F-001 §3.3 — 전투가 스왑을 막지 않음)
- **다음:** **CP7** — 위 스모크 1회 완주 확인(사용자 F5). 통과하면 **4단계 게이트 충족** → WORK_ORDER 체크리스트 4 체크. 이후 5단계(Identity NC AI).
- **주의:** 데미지 로그가 다소 spammy — 확인 후 throttle/제거 가능. 적→파티 데미지·다운 연출은 5단계+에서 설계.

---

## 7. Spec 참조 (pin `cd6009e`)

| Artifact | Path (spec repo) |
|---|---|
| Primary ENC | `docs/combat/encounters/ENC-NORM-001.md` (units·RP-02) |
| Combat AI QA | `docs/qa/QA-005` §2.6(서브 차단)·§2.10(PASS) |
| Playable contract | `docs/qa/QA-030` §3.3 (combat 테스트) |
| Demo blueprint | `docs/level-design/blueprints/DBP-DEMO-001.md` §5.1 (P-ADV-01 forceEncounter) |

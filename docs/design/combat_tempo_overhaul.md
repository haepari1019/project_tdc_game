# 전투 템포 개편 — 설계·계획 (게임측)

> **무엇:** 전투 체감을 "급한 AOE 난전"에서 "정제된 MMORPG 템포"로 옮기기 위한 4개 개선점 + 이를 받치는 능력 `role` 레지스트리 인프라의 실행 계획.
> **의도:** 플레이어가 너무 바쁘고 정신없는 감각을 줄인다 — 이동 가독성↑, 힐/탱 동시가동 강요↓, 캐릭터 선택 오조작↓.
> **SSOT/드리프트:** 수치=`SPEC_DRIFT.md` 로깅 / 로컬 코드결정=`ImplDecisionLog.md` / 적→shared 이사=`DRIFT-082`(전파 추적, `_PROP_PACKET_DRIFT-082.md`). 본 문서는 게임측 실행 계획(규칙 아님).
> **상태:** 계획 (2026-07-13). 시퀀싱 결정 **(b) 분리** 확정. `role` 표 산출 후 ①/③ 경계 재-핑퐁 예정. **Stop Line: 편집·커밋·전파·PR은 명시 승인 후.**

---

## 0. 배경 — 관측된 4개 통증

체감 플레이에서 도출. 근본 방향 = "덜 바쁘게, 더 의도적으로."

1. **지면 캐스트가 안 맞는다** — 적이 빠르고 계속 움직여 배치를 신경 쓰기 벅참.
2. **힐러를 쉼없이 돌려야 한다** — 딜 고저가 없어 상시 힐 부담. (→ 이번 배치 **제외**, §1 참조)
3. **첫 접촉 알파 스트라이크** — 마주친 순간 모든 적이 동시에 스킬을 쏟아 탱+힐 동시가동 강요 → 피로.
4. **1~4 스왑 오조작** — 아군 위치와 눌러야 할 번호가 헷갈림.

## 1. 스코프

| 구분 | 항목 |
|---|---|
| **IN (이번 배치)** | A 이동 템포 · B 적 캐스트 페이싱(알파 스트라이크) · C 아군 선택 · 인프라(능력 `role` 레지스트리 + 캡) |
| **DEFER** | **점 2 힐러/데미지 모델 리워크** (스킬 데미지 비중↑·쿨↑·HoT 저점 커버·예고 피크창). B의 페이싱 인프라가 깔린 뒤 별도 배치. 이유: 읽히는 데미지 peak은 캡/스케줄러 위에서 튜닝해야 안전. |
| **PARALLEL (진행 중 아크)** | **T1 적→shared 이사** = `DRIFT-082` 캐스팅 통합. 전파 추적(P4b). 본 배치의 `role` 인프라와 **디커플**(결정 b). |

**시퀀싱 결정 (b) 분리:** `role` 부여 + 캡은 이사 완료를 기다리지 않는다. 현재 로스터 전체에 코드측 `role`을 달아 캡을 지금 출하하고, 이사는 DRIFT-082 진도대로 병행하며 스킬이 하나씩 shared로 흡수된다.

---

## 2. 워크스트림 A — 이동 템포

### A-1. 전투 감속 ×2/3 (아군·적 일괄, 유닛별 변별 유지)
- **게이트:** 기존 파티 전역 전투상태 재사용 — `combat_controller.is_engaged()` / `engagement_changed`. **새 상태 안 만듦.** (선례: `party_controller.OVERDRIVE_OOC_RESET_S` one-shot가 동일 신호 구독.)
- **아군:** 조작캐 6.0 → **4.0**, 팔로워 6.3~6.6 → **4.2~4.4**. `party_member.move_speed_mult()`에 combat 항 추가.
- **적:** 교전(engaged) 경로에 ×2/3. 유닛별 4.8~6.5 변별·안티카이팅 관계 **유지**(균일 배율). `enemy_unit.current_move_speed()`에 combat 항. 비전투(roam/patrol fraction)는 현행.
- **비전투 = 현행(스프린트).** 답답함 해소는 여기서 확보.
- ⚠️ **리스크:** SteeringV1 팔로워 catch-up/slot damping이 6.x대에 튜닝됨 → 4.x대 재튜닝 필요(고위험 미뤄둔 시스템). `formation.json`·`party_controller._sv1_*`.

### A-2. 적 텔레그래프 중 이동 정지 (적만)
- **핵심:** 지면 AOE가 안 맞는 진짜 원인은 이동속도가 아니라 `aim_controller`의 **박제 타겟팅**(클릭 순간 좌표 고정, 적 추적 안 함). 감속은 비례적으로만 도움.
- 적이 자기 캐스트 윈드업(`enemy.winding`/`windup_timer_s`) 동안 **제자리 정지** → 정지한 적 = AOE 적중 가능. `enemy_ai._engage_move()`를 `!winding`으로 게이트.
- **아군은 이미 텔레그래프 중 정지** → 적만 대칭 적용.

**드리프트:** 속도·감속 수치 → `SPEC_DRIFT.md` 로깅.

---

## 3. 워크스트림 B — 적 캐스트 페이싱 (알파 스트라이크 방지)

현황: 조율자 전무. 분대가 함께 교전 진입 → 사거리 동시 도달 + 쿨 초기화 → 첫 시그니처 일제사격(`combat_controller.gd:213` 개별 tick, 전역 캡 없음).

### B-1. [핵심] 교전 시 첫 캐스트 난수 지연
- 각 적이 **교전하는 순간**, `role ∈ {threat, control}` 능력의 `ability_cd`를 **1.5~3.5s 난수 시딩** → 첫 캐스트가 흩어짐.
- 이후엔 능력별 쿨 차이(2~14s)로 자연 분산 — 초기 오프셋만 깨면 됨(OQ5 결정).
- **per-enemy·on-engage** 라 **증원 웨이브도 자동 커버**(새로 교전하는 적이 각자 지연).
- 평타 chip은 무제한 → valley 베이스라인 유지.

### B-2. [안전망] 소프트 동시성 캡 K=1
- `role ∈ {threat, control}`에 한해 **동시 캐스트 최대 1**(스쿼드 단위). 정상상태 재겹침 방지.
- **캡 기준은 `kind`가 아니라 `role`**(§5). `enemy_dash` 같은 과부하 kind 우회.
- 신규: 스쿼드/ENC 레벨 캐스트 조율 지점(`combat_controller`). 캡 K는 플레이테스트로 확정(1 유력).

**드리프트:** 캡·스태거 = 로컬 `ImplDecisionLog`. (`role`은 게임 인코딩, spec 미핀 → 전파 없음.)

---

## 4. 워크스트림 C — 아군 선택

- **좌클릭 아군 스왑:** party 레이어(mask `2`) 레이픽 → `party_controller.try_swap_to()`. 삽입 위치: 모달 핸들러(revive/aim/torch) 통과 **후** → 적 인스펙트(`dungeon_run._select_enemy_under_mouse`) **앞**. 우클릭=이동이라 충돌 없음.
- **1~4 키 유지** (병존). 난전 클럼프에선 키가 더 정확할 수 있음.
- ~~**번호 배지**~~: 초기 구현했다가 **제거**(2026-07-13, 유저 결정 — 불필요). 조종캐 초록 발밑 링(`controlled_indicator`) + 클릭 스왑으로 "위치↔번호 혼동" 충분 해소.
- **다운/MIA:** 스왑 무동작 — `try_swap_to`의 `_can_swap` 가드가 이미 처리.
- 아군은 이미 `CapsuleShape3D`·layer 2 보유 → 신규 콜리전 노드 불필요.

**드리프트:** 클릭스왑·배지 = 로컬 `ImplDecisionLog`.

---

## 5. 인프라 — 능력 `role` 레지스트리 + 택소노미

### 5-1. 문제 진단
`kind`는 **delivery(해소·VFX) 축**인데, 여기에 role·selection·pacing까지 뒤섞여 있고(예: `enemy_dash`=이동+피해+CC 4성격), 적 쪽은 `enemy_ai.gd` **하드코딩 문자열 분기 ~20곳**에 흩어져 중앙 SOT·컴파일 안전망이 없다. 반면 파티 쪽은 `ability_dispatch._skills` **자가등록 레지스트리**로 깨끗. → 적 쪽을 파티 수준으로 끌어올린다.

### 5-2. 중앙 레지스트리 = 모든 능력의 `{kind, role, exec}` SOT
**shared든 적고유든 예외든 전부 등재.** enemy_ai에 숨는 분류 0.

- **`kind`** — delivery/effect (유지, 해소·VFX 구동). *delivery dispatch는 부채 아님, 없애지 않음.*
- **`role`** — 목적 (**신규 축, 캡이 읽음**): `threat` · `control` · `debuff`(소프트 감속/약화, 캡X) · `support` · `buff` · `reposition` · `utility`.
- **`exec`** — 실행 라우팅:
  - `shared` — CastContext 진영flip으로 파티 effect 재사용.
  - `ai_internal` — 거동을 enemy_ai에 위임 (AI 공격성/포지셔닝 결합, 진영대칭 불가).
  - `hybrid` — 피해 effect=shared, 딜리버리(대시)=ai.

```
AB-010 poison   → {kind: skillbook_poison, role: threat, exec: shared}       캡 O
AB-105 frenzy   → {kind: enemy_frenzy,     role: buff,   exec: ai_internal}   캡 X
AB-013 backstab → {kind: skillbook_strike, role: threat, exec: hybrid}        캡 O
```

> **등재 ≠ 실행:** 적고유 예외도 레지스트리 시민(관측·캡 커버)이되, `cast()`가 shared 파이프라인을 흉내내지 않고 AI에 위임된다. `exec` 축 덕에 "무엇이 이사됐고 무엇이 AI에 남았나"까지 한 표에서 관측된다.

### 5-3. 캡셋 = `role ∈ {threat, control}`
**행복한 정렬:** 캡 대상(위협/통제) ≈ shared 이사 대상, 적고유 예외 ≈ 캡 제외(buff/reposition/utility). 마이그레이션과 캡이 서로를 강화.

### 5-4. 분류 SOT = `ability_roles.gd` (관측용)

전 능력 `{kind, role, exec}`는 [ability_roles.gd](../../scripts/combat/abilities/ability_roles.gd)에 등재(근거 주석 = 관측 표). 요약:
- **캡 O** — role ∈ {`threat`, `control`}: 파티 겨냥 예고 피해 / 하드 CC(기절·루트·테더·핀·도발).
- **캡 X** — `debuff`(소프트 감속/약화) · `support`(힐) · `buff`(자버프) · `reposition`(이동) · `utility`(표식/지형존).
- **exec** — `shared`(이사 완료/대상) · `ai_internal`(격노·재배치) · `hybrid`(대시=ai·피해=shared: AB-013/100/104).
- **핑퐁 1차:** AB-100→control, AB-012→**debuff**(신설·캡X), AB-099=control(캡O), AB-040=utility, AB-002=threat/즉발.

**드리프트:** 레지스트리(kind+role+exec 메타) = 로컬 `ImplDecisionLog`. `role`은 **코드측 레지스트리**에 둔다(abilities.json 스키마 필드 X) → 전파 없음. 이사(exec `ai_internal`→`shared` 전환)만 `DRIFT-082` 아크.

---

## 6. 시퀀싱 (결정 b)

- **Phase 0 — A + C** (독립·저리스크) → **체감 즉시 확보.**
- **Phase 1 — `role` 레지스트리** (전 능력 코드측 분류; `exec` 포함). → **관측 산출물(role 표) 확보 → §7 재-핑퐁.**
- **Phase 2 — B** (스태거 B-1 + 캡 B-2, `role` 기반).
- **병행 — T1 이사** (DRIFT-082, 파리티 검증하며 스킬별 흡수).
- **이후(별도) — 점 2** 힐러/데미지 모델.

## 7. 열린 질문 / 다음 핑퐁 (role 표 산출 후)

1. **①/③ 경계** — hybrid 3종(AB-013/100/104) 모델링(피해↔대시 분리 지점), AB-099 도발을 캡셋에 넣을지.
2. **role 분류 적정성** — role/kind가 적절한 규모로 나뉘었는지 유저 관측 후 조정(이번 핑퐁의 목적).
3. **캡 K** — 1 확정 여부(플레이테스트).
4. **A 리스크** — SteeringV1 4.x 재튜닝 범위, 전투 종료 후 스프린트 복귀 디바운스 필요 여부(`is_engaged` 자체엔 파티 디바운스 없음).

## 8. 드리프트·프로세스 원장

| 변경 | 등급 | 기록처 |
|---|---|---|
| 전투속도 ×2/3, 텔레그래프 정지, 스태거·캡 수치 | 튜닝 수치 | `SPEC_DRIFT.md` |
| combat-speed 토글, 클릭스왑, 번호배지, `role` 레지스트리, 캡 로직 | 로컬 코드결정 | `ImplDecisionLog.md` |
| 적→shared 이사(exec 전환), `unified` 스키마 | 규칙/스키마 | `DRIFT-082` → OPS_30/P4b 전파 → 재핀 |

**Stop Line:** 편집·커밋·전파·PR은 명시 승인 후에만.

## 9. 코드 레퍼런스 인덱스 (조사 확인)

- **이동:** `enemy_unit.gd:26,603`(move_speed/current_move_speed) · `data/slice01/formation.json`(6.0/6.3/6.6) · `party_member.gd:1325`(move_speed_mult) · `enemy_ai.gd:476`(engaged move), `:346-353`(winding) · `aim_controller.gd:105-139`(박제 타겟팅).
- **전투상태:** `combat_controller.gd:81,120,140`(_party_in_combat/is_engaged/engagement_changed) · `party_controller.gd:22,203`(OVERDRIVE_OOC_RESET_S 선례) · `run_end_controller.gd:11-12,70`(EXTRACT_HOLD 5/30, is_engaged 구독).
- **적 캐스트:** `combat_controller.gd:213`(개별 tick 루프), `:317`(resolve_unified_cast) · `enemy_ai.gd:311`(tick), `:369-448`(_try_cast_* 패스), `:809`(_begin_enemy_attack), `:1442`(gate_kinds) · `ability_dispatch.gd:90`(파티 자가등록 레지스트리).
- **아군 선택:** `dungeon_run.gd:404-408`(swap 키), `:543-561`(적 인스펙트 mask 4) · `party_controller.gd:238`(try_swap_to), `:292`(_set_controlled_index) · `party_member.tscn`(CapsuleShape3D, layer 2).
- **택소노미:** `abilities.json`(AB-###) · `enemy_ai.gd` ~20 분기(`:982` match, `:1051` telegraph_color 17종, `:1442` gate_kinds) · `skillbooks.json`(skillbook_* 33종, 이사 대응) · `_WIP_casting_expansion_pass.md`(어텐션 이코노미 규칙) · `_PROP_PACKET_DRIFT-082.md`(통합 전파 패킷).

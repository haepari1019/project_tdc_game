# Party Follow Steering v1 — 구현 설계 (Slice-01)

> **상태:** 합의 완료 · 구현 중 (Phase 1)
> **범위:** `party_controller.gd` 팔로워 이동 로직 전면 교체  
> **스펙:** F-003 formation, F-001 swap · 계약 QA-030  
> **데이터 SSOT:** `data/slice01/formation.json` (`steering_v1` 블록 추가 예정)

기존 `follow_steering` 스택(`v=inherit+slot+spacing`, flank waypoint, 탱 orbit/comfort/cruise, compose cap)은 **삭제**하고, 아래 1원칙만으로 재구현한다.

---

## 1. 배경

증상별 패치(comfort, separation, rear_anchor, corridor_yield, detour, 탱 예외 등)가 누적되며 서로 깨졌다. Slice-01 파티 이동은 **단일 steering 모델**로 통일한다.

**목표 체감**

- 이동 중 아군끼리 붙지 않고 **옆으로 우회**
- 배치 전환·힐러 조작·180° 전환에서 **길막·관통** 완화
- 대형 슬롯에 **도착 가능** (영원히 못 붙는 평형 없음)
- 조작 캐 주변 **위성처럼 기계적으로 동기화**되는 느낌 완화 (가속·출발 시차·catch-up, §11)

---

## 2. 1원칙

### 2.1 팔로워 속도

매 물리 프레임, 팔로워 `i` (앵커·조작 캐 제외):

```
d_goal     = unit(slotTarget[i] − pos[i])          // 슬롯 최단 방향
F_sep      = Σ repel(pos[i], ally_j)              // 모든 아군 j≠i, 대칭
F_bypass   = collinear_bypass(...)                // 일직선 상쇄 시에만
dir        = unit(d_goal × w_goal + F_sep + F_bypass)   // Phase 2: dir 스무딩
v_target   = dir × speed_seek(dist_to_slot) + catchup_bonus(dist_to_slot)  // Phase 3, §11
v_plan     = clip_walls(v_target)
v          = accel_toward(v, v_plan, follower_accel)   // Phase 3, §11.3
move_and_slide()
```

**우회**는 별도 waypoint 규칙이 아니라, `F_sep`·`F_bypass`·벽 클립이 합쳐진 **결과**여야 한다.

**방향(`dir`) SSOT = steering 합성.** 속도 **크기·출발 시점**은 §11 motion_feel 레이어가 담당 (가속, delay, catch-up).

### 2.2 조작 캐 (앵커)

- 입력으로 **목표 속도**만 정함 (`player_controller.gd`). 실제 `velocity`는 **가속/감속 램프** (§11.1). 척력으로 velocity를 덮지 않음.
- 다른 멤버의 `repel` 대상으로 앵커 **위치는 포함** (앵커도 아군 장애물).
- `member == anchor` → steering 루프 **스킵** (자기 슬롯 추격 금지).

### 2.3 유지하는 기존 시스템

| 항목 | 파일/데이터 | 비고 |
|------|-------------|------|
| `formationForward` (후진 hold/commit) | `party_controller.gd` | F-003 §3.0.2 |
| `layoutOrigin` / `_slot_world_target` | 동일 | wedge SSOT = `formation.json` slots |
| reposition / swap **출발 delay** | `follow_variation` | 속도 배율 아님, 출발 시차만 |
| cohesion / swap / controlled | 동일 | steering와 독립 |

### 2.4 삭제하는 기존 시스템

- `_spacing_velocity` + `_compose_follow_velocity` (spacing wins cap)
- `_steer_goal` / `_path_requires_flank` (flank waypoint 목표 치환)
- `_slot_pull_velocity` / `_inherit_velocity` (앵커 속도 **복사** 방식 폐기 → Phase 3 **catch-up + 가속**으로 대체, §11)
- `_tank_orbit_extra` / `_needs_tank_reversal_steering` / comfort·cruise·need_close
- 앵커 전용 clearance (`preferred_min_anchor_distance` 등 `follow_steering` 전부)

---

## 3. 거리 스케일 (3층 분리)

**척력 반경**과 **대형 슬롯 간격**은 의도적으로 다른 스케일이다.

| 개념 | 역할 | Slice-01 값 |
|------|------|-------------|
| **`R_zero`** (`sep_zero_radius_m`) | 이 거리 밖이면 척력 0. 지나갈 때만 옆으로 밀기 | **~1.0 m** |
| **`R_touch`** (`sep_touch_radius_m`) | urgency 최대 구간. 캡슐 접촉 직전 | **~0.52 m** (쌍별 scale 반영) |
| **슬롯 배치** (`formation.json` slots) | 도착 후 아군 간 설계 거리 | **2~6 m** (쌍마다) |
| **`arrive_r`** | 슬롯 도착 허용 오차 (`formation_arrive_distance_m` + extra) | **~0.9~1.1 m** |

### 3.1 슬롯 쌍별 거리 (layoutOrigin 기준)

| 쌍 | 거리 (대략) |
|----|-------------|
| Tank ↔ DPS | ~4.9 m |
| Tank ↔ Nuker | ~6.3 m |
| Tank ↔ Healer | ~6.3 m |
| DPS ↔ Nuker | ~4.8 m |
| DPS ↔ Healer | **~2.0 m** (가장 촘촘) |

### 3.2 슬롯 배치 제약 (자동 보정)

플레이어 커스텀 배치 지원을 위해 로드 시 자동 보정(`_sv1_enforce_slot_constraints`):

| 제약 | 파라미터 | 기본값 | 산출 근거 |
|------|---------|--------|----------|
| 슬롯 간 최소 거리 | `slot_min_distance_pair_m` | **2.5m** | R_dead(0.85) + arrive_r(0.95) + 캡슐(0.52) + 마진 |
| 앵커까지 최소 거리 | `slot_min_distance_anchor_m` | **2.0m** | R_dead_anchor(1.02) + arrive_r(0.95) |

**보정 순서:**
1. 앵커 거리 위반 → 원점에서 방사 방향으로 밀어냄
2. 쌍 거리 위반 → 양쪽을 반씩 벌림 (최대 10회 반복)
3. `push_warning` 출력으로 개발자/디자이너에게 보정 사실 알림

---

## 4. 코어 함수 정의

### 4.1 `repel(pos, ally_pos, r_self, r_ally)`

```
offset = pos − ally_pos  (y=0)
d = |offset|
R_touch_pair = r_self + r_ally             // 캡슐 접촉 거리 = 반경 합
R_zero       = sep_zero_radius_m (+ sep_zero_anchor_extra_m 앵커만, 선택)
R_dead       = R_zero × sep_deadzone_ratio // 실질 반응 경계

if d >= R_dead or d < 0.05:               // 데드존 밖 = 척력 0
    return ZERO

if d <= R_touch_pair:
    urgency = 1.0
else:
    urgency = ((R_dead − d) / (R_dead − R_touch_pair)) ^ sep_urgency_power

return unit(offset) × sep_strength × urgency
```

- 합산 후 `limit_length(sep_max_mps)`.
- **모든 아군 동일 규칙.** 앵커만 `sep_zero_anchor_extra_m` (0~0.3 m, 기본 0.2) 선택 적용.
- `R_dead(0.85m)` ~ `R_zero(1.0m)` 구간은 **무응답 데드존** — 경계 on/off 진동 방지.
- `R_touch_pair` = `r_self + r_ally` (기존 `max×2` 수정 — 반경이 다를 때 과대추정 방지).

### 4.2 `collinear_bypass` (리스크 3) — repel 루프 통합

`repel` 순회와 **단일 루프**에서 bypass 조건을 함께 판정한다 (중복 순회 제거).

**발동** (둘 중 하나, 첫 hit에서 확정):

1. `pos → slot` 선분이 아군(앵커 포함)과 거리 `< R_zero` (또는 앵커 `R_zero + extra`)
2. 루프 후: `dot(unit(F_sep_anchor), d_goal) < collinear_opposing_dot` (예: −0.65)

**출력:**

```
side = sign(cross(d_goal, to_ally).y)
F_bypass = perpendicular(d_goal) × side × bypass_strength
```

기존 `_path_requires_flank` + 옆 waypoint **대체**. 목표점 치환 금지.

**구현 노트:** `_compute_sep_and_bypass()` 단일 함수가 `{F_sep, F_bypass}` 딕셔너리를 반환. 조건 1은 루프 내에서, 조건 2는 루프 후 앵커 척력 방향으로 판정.

### 4.3 `clip_walls(vec, member)` (리스크 4) — 2중 방어

**1원칙:** 벽 때문에 그 방향으로 진행 불가 시, **벽 안쪽(inward) 성분만 제거**.

```
// 1차: 전 프레임 캐시 법선으로 성분 제거
for each cached wall normal n (horizontal, outward):
    if dot(vec, n) < 0:
        vec -= n × dot(vec, n)

// 2차: test_move — 캐시 없거나 부족할 때 보정
if |vec| > 0.001:
    collision = member.test_move(vec × Δt)
    if collision:
        n2 = collision.normal (horizontal)
        if dot(vec, n2) < 0:
            vec -= n2 × dot(vec, n2)
return vec
```

적용 위치 (**동일 함수, 두 번**):

1. `F_sep` 합산 **후** (`clip_walls(F_sep, member)`)
2. 최종 `v_target` / `accel_toward` 결과 `v`

법선 획득: 이전 프레임 `move_and_slide()` 후 `get_slide_collision` 저장 (fast path) + `test_move` 사전 검사 (fallback). `wall_clip_enabled`로 on/off.

### 4.4 `speed_seek(dist)` + `catchup_bonus(dist)` (Phase 3)

**기본 속도:**

```
if dist <= arrive_r:
    return 0
base = min(follower_move_speed_mps, dist × seek_gain)
```

**거리 catch-up (§11.4):** `dist_slot` 기준, 점진 보너스. MIA 구간 밖에서는 **0** (무한 추격 금지).

```
if dist_slot <= catchup_start_m or dist_slot >= catchup_disable_beyond_m:
    bonus_mps = 0
else:
    t = smoothstep(catchup_start_m, catchup_full_m, dist_slot)
    bonus_mps = t × catchup_max_bonus_mps

return base + bonus_mps    // 상한: follower_move_speed_mps + catchup_max_bonus_mps
```

`dist <= arrive_r` 이면 **`w_goal = 0`**, `d_goal` 합성 중단 (리스크 1-A).

### 4.4b `accel_toward(v, v_target, accel)` (Phase 3, §11.3)

```
return move_toward(v, v_target, accel × Δt)   // 감속 시 decel_mps2 사용 가능
```

즉시 `v = v_target` 금지. 팔로워 `accel` > 조작 캐 `accel`.

### 4.5 방향 스무딩 (리스크 2-B, Phase 2)

```
if |dir| < 0.001: return dir          // 방향 없으면 스무딩 불필요
if |prev_dir| < 0.001:               // 첫 유효 방향 — 즉시 초기화
    prev_dir = dir; return dir
dir_smoothed = slerp(prev_dir, dir, 1 − exp(−dir_smooth_rate × Δt))
prev_dir = dir_smoothed              // 정지 시 리셋하지 않음 — 재출발 시 자연 전환
```

멤버별 `prev_dir` 상태 저장. **위치가 아닌 방향만** 스무딩.

---

## 5. 리스크별 대응 (최종)

| # | 이름 | 원인 | 대응 | Phase |
|---|------|------|------|-------|
| **1** | 슬롯 못 붙음 (평형) | `R_zero`≈슬롯 간격, 슬롯 근처 척력 잔존 | **`R_zero≈1m` + 슬롯 2~6m 분리**; `arrive_r`에서 `d_goal`/speed 중단 (1-A); 필요 시 슬롯 근처 `F_sep` 감쇠 (1-B) | 1~2 |
| **2** | 진동 (`dir` 튐) | 대칭 척력, normalize 불연속, on/off 경계 | **α≥2 + sep_max cap** (2-A); **dir 스무딩** (2-B); **데드존** `d > R_zero×0.85` → `F_sep=0` (2-C) | 1~2 |
| **3** | 앵커 척력 원 | 슬롯이 앵커 반대편, `d_goal`↔`F_anchor` 충돌 | **앵커=동일 repel** (3-A); **collinear bypass** (3-C); 앵커 `R` +0.2m 선택 (3-B); 거리 catch-up (§11.4, inherit 대체) | 1, 3 |
| **4** | 벽 비비기 | `F_sep`·`d_goal`이 벽 inward 성분 | **`clip_walls` on `F_sep` + `v`** (4-A/B, 동일 원칙); mask 월드 유지 (4-D) | 1 |
| **5** | delay 해제 돌진 | delay 끝에 `d_goal` 계단 0→1 | delay 중 **`F_sep`만** (5-A); 해제 **`w_goal` 램프** `goal_ramp_after_delay_s` (5-B); **탱 delay 예외 제거** (5-C) | 3 |
| **6** | 논리 vs 물리 이중 | 척력·캡슐이 각각 밀음 | steering=방향 SSOT (6-A); **`R_touch`≈캡슐** scale 반영 (6-B); Phase 1 **MASK_PARTY 유지** (6-C) | 1 |

### 5.1 리스크 1 보조 (Phase 1 기본 적용)

슬롯 근처 `dist(slot) < arrive_r × 1.5` 일 때 `F_sep` 감쇠 (**기본 활성**, 선택 아님):

```
threshold = arrive_r × 1.5
if dist_to_slot >= threshold: damping = 1.0
else: damping = lerp(0.2, 1.0, dist_to_slot / threshold)
F_sep_total *= damping
```

- 하한 `0.2` — 관통 방지 최소 척력 보존
- DPS–Healer 쌍(2.0m)이 이동 중 R_zero 내 빈번 진입 → 이 감쇠 없이는 Phase 1 F5 검증 4번("정지 후 슬롯 도착·유지")에서 떨림 발생 예상

### 5.2 리스크 2 보조 (보류)

쌍별 히스테리시스 `R_on`/`R_off` (2-D) — 튜닝 부담 시 생략.  
속도 댐핑 (2-E) — §11 가속 램프와 중복 가능, 보류.

### 5.3 리스크 4 보조 (보류)

벽 근접 `R_zero` 축소 (4-C) — MAP-DEMO 좁은 구간에서만.

### 5.4 비대칭 척력 가중 (Phase 1 적용)

**증상:** 탱커가 직진할 때 DPS 위치를 관통하면서 DPS가 밀림 → 탱커(이동 중)가 우회하는 게 자연스러움. 원형 이동 시 바깥쪽 멤버가 전원 척력을 동시 수신하여 대형이 벌어짐.

**원인:** 대칭 척력 — 쌍(A, B) 간 크기 동일, 누가 자기 자리에 가까운지 무관.

**해법:** 슬롯 목표까지 거리(`dist_to_slot`) 기반 **비대칭 가중치**.

```
dist_self  = |slot_target_self − pos_self|
dist_other = |slot_target_other − pos_other|
ratio      = dist_self / (dist_self + dist_other + ε)
w          = lerp(sep_asymmetry_min, 2.0 − sep_asymmetry_min, ratio)
F_repel_on_self *= w
```

| 상황 | `dist_self` | `dist_other` | `ratio` | `w` (min=0.15) | 의미 |
|------|------------|-------------|---------|----------------|------|
| 자기 자리에 있음 | ≈0 | 큰 값 | ≈0 | ≈0.15 | 거의 안 밀림 |
| 이동 중 (상대가 자리에) | 큰 값 | ≈0 | ≈1 | ≈1.85 | 많이 밀림 → 우회 |
| 둘 다 이동 중 | 비슷 | 비슷 | ≈0.5 | ≈1.0 | 기존과 동일 |

- 쌍 합 `w_A + w_B = 2.0` → 총 에너지 보존.
- **앵커 쌍:** 앵커 `dist_to_slot = 0` (항상 자기 위치) → 팔로워가 항상 우회. 기존 `sep_zero_anchor_extra_m`과 병행.
- **`sep_asymmetry_min`** (기본 0.15): 관통 방지 최소 척력 유지. 0이면 슬롯 위 멤버가 완전 무적(위험).
- `_sv1_slot_proximity_damping`과 별도 메커니즘: damping은 총 F_sep 감쇠(슬롯 도착 떨림 방지), asymmetry는 쌍별 분배(우회 대상 결정).

---

## 6. Reposition delay (F-003 출발 시차 + §11.2)

`follow_variation` **유지**. steering_v1·`motion_feel`과 연동. **멤버별 독립 RNG** (`identity_skill_id` 시드).

| 구간 | 동작 |
|------|------|
| `delay_s > 0` | `w_goal = 0` → **`F_sep` + 벽 클립만** |
| delay 종료 | `goal_ramp_after_delay_s` 동안 `w_goal`: 0→1 (리스크 5-B) |
| 대상 | **탱 포함** 전 팔로워 (앵커·조작 캐 제외) |

### 6.1 delay 트리거 (통합)

| 트리거 | 조건 | 지연 범위 (기본) |
|--------|------|------------------|
| **A. 레이아웃 변화** | `formationForward` 25°+ / 100°+ / 정지 스왑 | `follow_variation` reposition·swap delay |
| **B. 앵커 출발** | 앵커 정지→이동 (`speed ≥ formation_min_speed`) **상태 전이** | `motion_feel.anchor_start_delay_min_s` ~ `max_s` (예: 0~0.08s) |

- 멤버별 delay = `max(기존 A, 새 B RNG)`. **매 프레임이 아님** — 상태 전이에만 큐.
- 3명이 **동시 출발하지 않게** 하는 §11.2 목적. B는 **짧게** 유지 (0.08s 초과 비권장).

Phase 1에서는 delay **비활성** (코어 검증 우선). Phase 3에서 재활성.

---

## 7. `formation.json` — `steering_v1` 블록 (초안)

구현 시 `follow_steering` 제거 또는 deprecated. 아래 블록 추가:

```json
"steering_v1": {
  "sep_zero_radius_m": 1.0,
  "sep_zero_anchor_extra_m": 0.2,
  "sep_touch_radius_m": 0.52,
  "sep_touch_use_scaled_radius": true,
  "sep_urgency_power": 2.2,
  "sep_strength": 7.0,
  "sep_max_mps": 9.0,
  "sep_deadzone_ratio": 0.85,
  "sep_asymmetry_min": 0.15,

  "collinear_perp_dist_m": 0.35,
  "collinear_opposing_dot": -0.65,
  "bypass_strength": 5.5,

  "arrive_radius_extra_m": 0.45,
  "seek_gain": 4.0,

  "goal_weight_near_slot": 1.0,
  "sep_weight_near_slot": 1.0,

  "dir_smooth_rate": 14.0,
  "sep_deadzone_enabled": true,

  "wall_clip_enabled": true,

  "goal_ramp_after_delay_s": 0.08,

  "slot_min_distance_pair_m": 2.5,
  "slot_min_distance_anchor_m": 2.0
}
```

**`motion_feel` 블록 (Phase 3, §11):**

```json
"motion_feel": {
  "controlled_accel_mps2": 90,
  "controlled_decel_mps2": 120,
  "follower_accel_mps2": 220,
  "follower_decel_mps2": 260,

  "anchor_start_delay_min_s": 0.0,
  "anchor_start_delay_max_s": 0.08,

  "catchup_start_dist_m": 4.5,
  "catchup_full_dist_m": 9.0,
  "catchup_max_bonus_mps": 3.0,
  "catchup_disable_beyond_m": 14.0
}
```

| 키 | 의미 |
|----|------|
| `controlled_accel_mps2` | 조작 캐 가속 (~9 m/s / 0.1s ≈ 90) |
| `follower_accel_mps2` | 팔로워 가속 (**더 큼** → 짧은 delay 후 빠르게 만속) |
| `anchor_start_delay_*` | 트리거 B (§6.1) |
| `catchup_*` | 슬롯 거리 기반 속도 보너스; `disable_beyond` 이상 = MIA 포기 구간 (F-003 MIA 수치 확정 시 동기화) |

기존 키 매핑:

- `arrive_r` = `formation_arrive_distance_m` + `arrive_radius_extra_m`
- `follower_move_speed_mps`, `follow_variation`, `collision`, `slots`, `formation_forward`, `tank_min_lead_m` — **그대로**

---

## 8. 물리 / 캡슐 (리스크 6)

| 항목 | 값 |
|------|-----|
| `capsule_radius_m` | 0.26 |
| 조작 캐 scale | 1.15 → 유효 반경 ~0.30 m |
| `collision_layer` | 2 (PARTY) |
| `collision_mask` | 3 (WORLD + PARTY) — **Phase 1 유지** |

조작 캐 노드 `scale`이 캡슐에 반영되므로 `repel`의 `R_touch_pair`는 **양쪽 반경 합**으로 계산.

---

## 9. 구현 단계

### Phase 1 — 코어 (delay/inherit 없음)

**구현**

- `steering_v1` 파서
- `repel`, `collinear_bypass`, `clip_walls`, `speed_seek`
- `_follower_velocity` 교체
- 슬롯 최소 거리 검증
- 기존 follow 블록 삭제

**끔**

- inherit, reposition delay, 탱 orbit, flank waypoint, compose

**F5 검증**

1. DPS 조작 직진 — 탱이 앵커 옆 슬롯으로 **관통 없이** 추종  
2. 4인 좁은 복도 — **벽 비비기** 없이 통과  
3. 이동 중 교차 — 1m 이내에서 **옆 우회**, 1m 밖에서 척력 0  
4. 정지 후 슬롯 — **도착·유지** (평형 없음)

### Phase 2 — 안정화

- arrive `d_goal` 중단 (1-A), 슬롯 근처 `F_sep` 감쇠 (1-B, 필요 시)
- dir 스무딩 (2-B), 데드존 (2-C)

**F5 검증**

1. 힐러 조작 180° — 뒤 슬롯 복귀, 앵커 **우회**  
2. 정지 스왑 — 진동·못 붙음 없음

### Phase 3 — 체감 패키지 (delay + motion_feel)

- reposition delay 통합 (5-A/B/C + §6.1 트리거 B)
- **가속/감속** (§11.1): 조작 캐 `player_controller`, 팔로워 `accel_toward`
- **앵커 출발 랜덤 delay** (§11.2): `anchor_start_delay_*`
- **거리 catch-up** (§11.4): `catchup_*` (inherit **대체**, 무한 추격 없음)
- ~~`v_inherit` 앵커 속도 복사~~ **사용 안 함**

**F5 검증**

1. 직선 전진 — 팔로워가 **동시에 안 출발**, 위성처럼 거리 고정되지 않음  
2. 멀어짐 — **점진적** catch-up; MIA 거리 밖에서는 따라오지 않음  
3. delay 해제 **돌진 없음** (`w_goal` 램프 + 가속)  
4. 조작 캐 — 출발·정지 **짧게** 부드럽고 답답하지 않음

### Phase 4 — 탱 리드

- `tank_min_lead_m` 슬롯 오프셋만 활용 (orbit **금지**)

---

## 10. `party_controller.gd` 변경 가이드

### 10.1 `_update_formation_follow` (2-pass 모델로 교체)

비대칭 척력 방지를 위해 **계산 pass → 적용 pass** 분리:

```
// Pass 1: 전 멤버 velocity 계산 (위치 변경 없음)
planned = {}
for member in _members:
    if member == anchor: planned[member] = ZERO; continue
    if member.is_controlled(): continue
    planned[member] = _steering_v1_velocity(...)

// Pass 2: 일괄 적용
for member in _members:
    if member.is_controlled(): continue
    member.velocity = planned[member]
    member.move_and_slide()
    _store_wall_normals(member)
```

### 10.1b `player_controller.gd` (Phase 1~2: 즉시 속도 / Phase 3: 가속 모델)

`motion_feel` 블록 유무로 분기. `use_accel_model` 플래그를 `party_controller`가 주입:

```
v_target = input_dir × move_speed

if use_accel_model:                                     // Phase 3
    a = accel if input else decel
    v = move_toward(v, v_target, a × Δt)
else:                                                   // Phase 1~2 (기존 동작)
    v = v_target

body.velocity = v
```

### 10.2 새 상태 (멤버별 또는 controller 내 Dictionary)

- `prev_dir: Dictionary` — `{member: Vector3}`, 방향 스무딩용. 초기 `ZERO`, 첫 유효 방향에서 즉시 채움
- `w_goal: Dictionary` — `{member: float}`, 슬롯 추적 가중치 `0.0~1.0`. delay 중 `0`, 램프 후 `1`
- `wall_normals: Dictionary` — `{member: Array[Vector3]}`, 직전 프레임 slide 법선
- `anchor_was_moving: bool` (트리거 B 상태 전이)

### 10.3 삭제 대상 함수 (교체 완료 후)

`_spacing_velocity`, `_repel_from_point` (v1로 대체), `_path_requires_flank`, `_pick_flank_sign`, `_pick_less_crowded_side`, `_steer_goal`, `_slot_pull_velocity`, `_inherit_velocity`, `_compose_follow_velocity`, `_tank_orbit_extra`, `_needs_tank_reversal_steering`, `_tank_reversal_orbit`, `_follower_velocity` (구버전)

### 10.4 `_load_formation_config`

- `steering_v1` · `motion_feel` 블록 로드
- `follow_steering` / `tank_follow` steering 관련 필드 로드 **제거** (`tank_min_lead_m`, `formation_forward` 등은 유지)

---

## 11. Motion feel — 위성感 완화 (Phase 3)

조작 캐를 중심으로 거리가 **기계적으로 고정**되는 느낌을 줄이기 위한 레이어. **§2.1 방향 합성은 변경하지 않음.**

### 11.1 가속/감속 (즉시 최고속 금지)

| 대상 | accel (예) | 만속 시간 목표 (~max_speed/accel) |
|------|------------|-----------------------------------|
| 조작 캐 | `controlled_accel_mps2` ≈ 90 | **~0.08~0.12 s** @ 9 m/s |
| 팔로워 | `follower_accel_mps2` ≈ 220 | **~0.04~0.07 s** @ 12 m/s |

- 팔로워 accel **> 조작 캐** → §11.2 delay 후에도 슬롯 방향으로 **빠르게** 속도 도달.
- 정지 시 `decel_mps2` (조작 캐 ≥ accel 권장) — 미끄러짐 방지.
- **dir 스무딩(Phase 2)** 과 함께 켤 것. 방향만 즉시·속도만 램프면 어색할 수 있음.

### 11.2 캐릭별 랜덤 반응 지연

- **별도 시스템 아님** — §6 delay에 **트리거 B (앵커 출발)** 추가.
- 멤버마다 `anchor_start_delay` RNG → 3명 **동기 출발** 방지.
- delay 중: `F_sep`만 (슬롯 추격 없음). 종료 후 §11.1 가속 + 리스크 5 `w_goal` 램프.

### 11.3 파이프라인 (Phase 3 전체)

```
[트리거 A/B] → 멤버별 delay_s
delay_s > 0     → F_sep만, w_goal=0
delay 종료      → w_goal 램프 0→1

dir = 합성 (+ dir 스무딩)
speed = speed_seek(dist) + catchup_bonus(dist)
v_target = clip_walls(dir × speed)
v = accel_toward(v, v_target, follower_accel)
move_and_slide()
```

### 11.4 거리 catch-up (MIA 허용)

- 기준: **슬롯까지 거리** `dist_slot` (앵커 거리 아님).
- `catchup_start_m` ~ `catchup_full_m`: `smoothstep`으로 `bonus_mps` 0 → `catchup_max_bonus_mps`.
- `dist_slot ≥ catchup_disable_beyond_m`: bonus = **0** — **무한 추격 없음**, MIA는 게임 요소로 유지.
- 보너스도 §11.1 **가속 램프**를 거침 → 갑자기 확 빨라지는 느낌 완화.
- 좁은 통로: `speed` 상한은 `follower_move_speed_mps + catchup_max_bonus_mps` 이내; `sep_max_mps`와 별도 튜닝.

### 11.5 튜닝 시 주의

| 조합 | 결과 |
|------|------|
| delay 길음 + accel 느림 + catch-up 없음 | MIA 빈번 → §11.4 필수 |
| catch-up 과다 | 다시 위성/자석 느낌 → `catchup_max_bonus_mps` 상한 엄수 |
| 트리거 B 매 프레임 | 답답함 → **상태 전이만** |

---

## 12. 한 줄 요약

| 리스크 | 핵심 |
|--------|------|
| 못 붙음 | `R_zero` 1m ≠ 슬롯 2~6m + arrive 중단 |
| 진동 | α+cap + dir 스무딩 + 데드존 |
| 앵커 | 동일 repel + collinear bypass |
| 벽 | `F_sep`·`v` 벽 inward 성분 제거 |
| delay 돌진 | `F_sep`만 → `w_goal` 램프 |
| 물리 이중 | `R_touch`≈캡슐, mask 유지 |

**이동 방향 SSOT = steering v1 합성.** 속도 크기·출발 시점 = **§11 motion_feel.** 물리 캡슐은 관통 방지 안전망.

| motion feel | 핵심 |
|-------------|------|
| 가속 | 조작 캐 느리게·팔로워 빠르게 만속 |
| 랜덤 delay | §6 트리거 B, 3명 비동기 출발 |
| catch-up | 멀면 점진 보너스, MIA 밖 포기 |

---

## 13. 참고

- 스펙 원문: `project_tdc` repo, F-003 / QA-030 (이 문서에 F-### 규칙 전문 복사하지 않음)
- 구현 파일: `scripts/party/party_controller.gd`, `scripts/run/player_controller.gd`, `scripts/party/party_member.gd`
- 데이터: `data/slice01/formation.json`

# Surface Grid — 환경 존 셀 그리드화 설계 (게임측 정본)

> **무엇:** 환경 surface(존)를 `center+radius` **원 단위** → DOS2/BG3식 **셀 그리드 substrate**로 전환하는
> 게임측 설계·단계·마이그레이션 계획. DRIFT-096의 "원 단위 근사"(교집합=중점 Steam·확산=반경 축소) 한계를
> 정식 해소하고, 예정된 **퍼짐(spread)·바람 밀림(wind)** 기능의 토대를 만든다.
> **SSOT:** spec `F-021 §3.2`(RX)·`EVENT-CORE §3`·`INT-002 §6.1`(Tile medium model)·`ZONE-CORE`·`EFFECT-CORE`.
> 본 문서는 **게임측 실행 계획(규칙 아님).** 규칙 변경은 spec repo + OPS_30.
> **상태:** 설계 확정(2026-07-21, 사용자 승인) — **Target A**(셀=substrate, 원=저작). S0(shadow) 착수.
> 관련: [[IMPL-DEC-20260721-001]] · DRIFT-096 · `reaction_system.gd` · `hazard_zone.gd`.

## 0. 배경 — spec은 이미 하이브리드

spec 실사 결과(핀 `2da700d`), 환경 존은 내부가 두 모델로 갈라져 있다:

| 층 | spec 모델 | 근거 |
|----|-----------|------|
| **존 지오메트리(저작 단위)** | **원 + `radius_m`** | `ZONE-CORE` 전 행 `shape: Circle`+`default_radius_m`; `EFFECT-CORE` 모든 SpawnZone/AoE `radius_m`; `F-006` "원·박스·폴리곤" |
| **RX 해상도(반응 단위)** | **"타일(tile)"** | `INT-002 §6.1` 제목 literally "Tile medium model"; `EVENT-CORE §3` "타일당 combo RX 1종만"; `SPREAD-ZONE-*-{n}TILES` |
| **이음새** | 타일 = 원 위 추상 | `INT-002 §6.1`: `activeMedia[]`는 "존 TTL·**반경**으로 유지" |

즉 spec도 진짜 셀 그리드가 아니라, "타일"을 매질 겹침 지점의 느슨한 단위로 쓰고 실제 저작은 원이다. 게임은 이
하이브리드를 충실히 구현했고(원 저작 + 근사 타일 해상), DRIFT-096의 한계는 **게임과 spec 양쪽에** 있다.

## 1. Target A — 셀=substrate, 원=저작 (확정)

두 갈래 중 **A**를 채택한다:

- **A(채택):** `spawn_zone(medium,pos,radius,…)`·`radius_m`·`shape:Circle` **저작 그대로**, 내부에서 원을 셀로
  **래스터화**. 셀이 상태·반응·확산을 소유. → spec의 "타일" 어휘가 **literally 참이 됨(수렴)**. 지오메트리 SSOT 불변.
- **B(기각):** `radius_m`/`shape:Circle`를 셀 footprint로 교체 = 지오메트리 SSOT 대규모 변경(`ZONE-CORE`·`EFFECT-CORE`·
  `F-006`·모든 `RX-*`, DEC-20260617-007 impact set). A 대비 이득 적음(DOS2도 shape 저작→래스터화).

**핵심 논거:** 런타임 비원형화(퍼짐·바람)는 **substrate(셀 CA) 층의 성질**이라 A/B가 동일하게 제공한다. A/B 차이는
**최초 seed 저작 단위**뿐. seed는 실제로 모양(스킬 조준점 원·배럴 원형 슬릭)이라 `radius_m` 저작이 자연스럽고,
`radius_m`은 **초기 스폰 범위**를 뜻할 뿐 살아있는 불변식이 아니다. 비원형 seed가 필요하면 `stamp_box`/`stamp_polygon`
래스터 프리미티브로 커버(F-006 `shape:` 컬럼 이미 존재) — SSOT 재작성 불필요.

**유기적 seed(물감 스플래터):** seed는 스탬프 함수가 셀에 칠하는 결과이므로, 판정식을 노이즈로 흔들면 스플래터가
된다 — `dist ≤ radius + noise(cell)*amp`(울퉁불퉁 경계) / `noise(cell) > threshold`(방울 분리) / 메타볼 / 브러시
마스크. 스탬프 함수는 **엔진 안**(`SurfaceGrid.stamp_*`)에 살아 SSOT 불변. **두 레버 분리:** seed 셀-set 노이즈
(게임플레이 footprint) vs 렌더 엣지 노이즈(순수 시각, sub-cell). 한계: seed 결의 미세도는 셀 크기에 묶임(렌더
엣지는 sub-cell로 무제한).

## 2. 설계

### 2.1 셀 크기 — 1.0m (단일 튜너블 상수)
nav `cell_size`=0.25m의 4배 → carve 정렬 깔끔. 3m 원 ≈ 28셀, 5m ≈ 78셀. 동시 존 몇 개 → 활성 셀 수백 이내.
블록감은 spec 타일 근사에 오히려 부합. 각짐이 문제면 상수를 0.5m로(셀 4배). PH 단계엔 1.0m.

### 2.2 자료구조 — sparse
`Dictionary<int, CellState>`, `key = (ix & 0xFFFF)<<16 | (iz & 0xFFFF)` (음수 오프셋 처리). 활성 셀만 순회.
표면이 작고 일시적이라 sparse 압승(dense-bbox는 매틱 빈 셀 수천 순회 낭비). 대면적 상시화 시 chunk 승격.

### 2.3 셀 상태 모델
```
CellState (S4 다매질 스택):
  medium       : String            # primaryMedium(최우선). activeMedia = [medium] + extra.keys()
  extra        : {medium→MediumState}  # S4: 겹친 하위 매질(각자 dps/slow/source/ttl/age/origin). 비면 단일
  dps, slow, source, ttl, age, origin_id  # primary 매질의 상태(MediumState와 동형)
  friendly_safe, safe_faction      # DRIFT-094
  lethal       : bool              # telegraph phase(false면 효과 없음)
```
**S4 done** — `medium`(primaryMedium) + `extra`(하위 activeMedia) 스택으로 승격, `primaryMedium`=`RX_PRIORITY` 최우선.
outcome/render는 primary+extra 전부 반영(S1a 복원), stamp는 drop→stack, primary 소멸 시 하위 승격. → INT-002 §6.1 정확 수렴.
impassable(Fatal carve)은 원(circle) 유지(S1c/S1d 디스코프 — 매질과 분리).

### 2.4 반응 = 셀 오토마타
- **Hit-RX(이벤트 버스):** `_zones_overlapping(center,r)` → `cells_in_radius(center,r)`. resolver가 **셀당**
  primaryMedium 선택 → 셀당 1 combo RX(= "타일당 1 RX" literally 참). (현 게임의 "겹친 매질 전부 반응" DRIFT-093은
  셀 단위로 정확히 표현/재조정 가능.)
- **Passive-RX(DRIFT-096 = 실제 목표):** `_zone_reaction_tick` O(n²)+중점Steam+shrink → **셀 내 공존 매질 해소**.
  확산/겹침이 두 매질을 같은 셀로 데려오면 그 셀에서 반응(Oil셀 점화 / Fire↔Water셀 Steam+소비) → "경계 셀만
  반응 + 셀 확산"이 공짜.

### 2.5 확산 = 셀 오토마타 (S3)
활성 셀마다 spreadable 매질이 저-intensity 이웃으로 밀기(Moore/von Neumann, 레이트 제한). Fire=Oil/Vegetation 셀
따라 기어감·기체 감쇠+소멸·Wind zone=방향 바이어스. spec `max_tiles_per_gust:2`·`max_spreads_per_room:6`·
`SPREAD-ZONE-*-{n}TILES`가 literally 구현 가능(수렴). `_spread_tick` WindGust 자식-원 해킹 제거.

### 2.6 렌더 — MultiMesh
매질별 `MultiMeshInstance3D` 1개, 활성 셀당 flat quad 인스턴스 1개. per-instance transform(셀 중심)+custom-data
(intensity→alpha). **매질당 draw call 1회.** 버퍼는 매 그리드 틱 갱신 O(활성 셀). **DRIFT-095 깜빡임 대부분 소멸**
(셀은 평면상 안 겹침; 매질 STACK만 `RENDER_ORDER`로 순서). 유기 엣지=셰이더 노이즈(S5). 대안(셰이더 필드,
vision_fog 월드XZ→UV 재사용)=S5 최적화 후보.

### 2.7 navmesh carve
impassable 셀 → carve. 인접 impassable 셀 greedy 사각 병합 → obstruction 소수. **rebake 디바운스**(≤0.5s·set 변화
시만). impassable은 **빠른 CA 확산 금지**(정적 trap footprint) → carve 빈도 오늘 수준 유지. 정직한 위험: impassable
매질이 빠르게 확산하면 스래시 → 확산 레이트 제한+디바운스로 억제.

### 2.8 파티 회피
`_clamp_fatal`의 `fatal_zone` 원 스캔 → 그리드 쿼리(`fatal_repulsion(pos)` = 근접 impassable 셀/거리필드). MVP는
멤버 주변 소창 impassable 셀 스캔으로 충분. `blocks_segment` → 세그먼트 위 셀 샘플.

### 2.9 마이그레이션/호환 = 위험 통제
**어댑터.** 신규 `SurfaceGrid`가 셀+렌더+틱 소유(CombatController 자식 → dungeon_run·combat_sandbox 공짜 획득,
[[sandbox-input-parity]]). `spawn_zone`/`ignite_at`/`fire_hit` **시그니처 유지** — 내부 `stamp_circle`. **저작 8곳·모든
스킬 effect(`radius_m`) 무수정.** **소비 4곳만** 그리드 쿼리로 이주(불가피 실작업). `USE_SURFACE_GRID` 플래그로 원
경로 폴백(S1 회귀 시 즉시 되돌림).

### 2.10 틱 예산
| | 현재 | 셀 모델 |
|--|------|---------|
| 멤버십/outcome | 존N × 유닛M 스캔 | 유닛M → 셀 룩업(한 번) |
| passive RX | O(N²) 존쌍/0.4s | O(활성셀×이웃)/0.2–0.4s |
| 렌더 | 존당 메쉬 | 매질당 draw 1 + 버퍼 O(셀) |
| nav | spawn/clear마다 rebake | 디바운스 |

→ 동일 충실도에서 오늘보다 싸고, 존 개수 아닌 표면 면적에 스케일. 새 비용=nav rebake(디바운스)·MultiMesh 업로드(수백=trivial).

### 2.11 정직한 트레이드오프
- **정밀도:** 엣지 블록화(sub-cell 상실) ↔ 교집합 반응은 오히려 더 정확(중점/shrink 근사 제거). 셀 크기로 조절.
- **메모리:** sparse=표면 비례, 무시가능.
- **성능:** 대부분 개선. 유일 위험=nav rebake(억제책 있음).
- **체감:** CA 확산은 튜닝 없으면 체커보드/게임틱 → F5 반복(DOS2도 여기 공들임). **최대 미지수.**
- **복잡도:** 새 서브시스템 1개 ↔ 존별 노드 fan-out + DRIFT-095 렌더 해킹 + DRIFT-096 근사 3개 은퇴. 순증가 아님.

## 3. 단계 (비용·위험)

| 단계 | 내용 | 비용 | 위험 |
|------|------|------|------|
| **S0** | SurfaceGrid 골격 + shadow 렌더(`ground_zone` 옵저버 래스터화, 원이 권위, A/B 토글). 무침습 | 중 | **낮음(가산)** |
| **S1** | 셀 권위화(단일 매질) — 소비 4곳 이주(RX쿼리·`_clamp_fatal`·`_carve_zone`·outcome틱), HazardZone tick/mesh 은퇴, `USE_SURFACE_GRID` 폴백 | 높음 | **높음(nav+회피=실전투/스티어링)** |
| **S2** | 셀 경계 반응 — `_resolve_zone_pair` 중점/shrink → 셀 내 공존매질 해소. **← DRIFT-096 정식 종결** | 중 | 중 |
| **S3** | 셀 확산 CA — 퍼짐·바람(spec `max_tiles` 캡 literal), WindGust 해킹 제거 | 중 | 중(체감튜닝) |
| **S4 ✅** | 다매질 스택(`activeMedia[]`/`primaryMedium`) → INT-002 §6.1 정확 수렴 **(done — S4a 구조·S4b 스택+S1a복원·S4c 셀-내 RX)** | 중 | 낮음~중 |
| **S5** | 셰이더 엣지 노이즈·intensity custom-data·chunk 승격·nav 디바운스 튜닝 | 중 | 낮음 |

- **DRIFT-096 목표 달성 MVP = S0+S1+S2.** 퍼짐·바람 payoff = +S3. S4/S5 = 수렴·확장.
- **게이트(각 단계):** ci_smoke + 체감. 통과 전 다음 단계 착수 금지. 편집/커밋/PR은 매번 명시 승인.

## 4. 파일 touch-map
```
신설:  scripts/world/hazards/surface_grid.gd
S0:    combat_controller.gd(자식 생성·facade)  ·  combat_sandbox.gd/dungeon_run.gd(디버그키)
S1:    hazard_zone.gd(tick/mesh 은퇴·스탬프 핸들화 or 제거)
       reaction_system.gd(_zones_overlapping·_zone_reaction_tick → 셀쿼리)
       party_controller.gd(_clamp_fatal → 그리드)
       map_demo_layout.gd(_carve_zone → 셀-set·디바운스)
S2:    reaction_system.gd(_resolve_zone_pair → 셀 경계반응)
S3:    reaction_system.gd(_spread_tick → 셀 CA) or surface_grid.gd 이관
문서:  이 파일 · docs/SPEC_DRIFT.md(DRIFT-096) · docs/impl_decisions/ImplDecisionLog.md · docs/ARCHITECTURE.md
```

## 5. spec 전파 (Target A) — ✅ 완료 (2026-07-22)
`OPS_30` 역전파 완료(staging `d9e9f52`, `DEC-20260722-001/002/003`, `spec_ref` `2da700d`→`d9e9f52` 재핀):
- **DRIFT-096**(셀 substrate 반응/확산): `INT-002 §6/§6.1`(타일=`CELL_M` 셀·per-cell CA·`radius_m`=초기 seed)·
  `EVENT-CORE §1/§3`(Ambient 중첩 반응·Hit medium RX)·`RX-OIL-FIRE-001`·`RX-FIRE-WATER-001`·`RX-FIRE-VEGETATION-001`
  (passive/overlap 트리거·연료 creep·셀 경계 반응)·`EFFECT-CORE`(`SPREAD-ZONE-FIRE` 연료=[Veg,Oil]·확산 모델).
- **DRIFT-097**(zone 유계): `ZONE-CORE` `ZONE-OIL-001`·`ZONE-VEGETATION-001` ttl `∞`→`10.0` + 유계 원칙 명문화.
- **DRIFT-093**(Hit RX 각 매질, 동봉): `EVENT-CORE §3`·`INT-002 §6/§6.1` — 겹친 각 매질 반응(`PhysicalImpact`는 예외).
- **불변(수렴):** `ZONE-CORE shape:Circle`·`EFFECT-CORE radius_m` 지오메트리 그대로. `activeMedia[]` 단일-매질/셀 = S4
  갭(규칙 비전파). per-medium RX(`RX-FIRE-ICE` 등)=DRIFT-069 후속. 게임 상수(CELL_M/rings/cadence/prob)=튜닝(로깅만).

## 6. 진행 상태

- **S0 done** — shadow substrate(`surface_grid.gd` 관측 렌더·MultiMesh·A/B `N`키·`surface_smoke`). 무침습.
- **S1a done** — **outcome+render 권위를 셀로**(`USE_SURFACE_GRID=true`, `hazard_zone.gd`). HazardZone은 mesh·자기
  outcome틱을 은퇴(`_build`/`_physics_process` 게이트, `clear_zone` null-safe, `get_source`/`is_lethal` 게터)하고
  **lifetime(ttl/telegraph/clear)·geometry(radius/contains_point)·group만 유지.** `SurfaceGrid._tick_outcomes`가
  유닛→커버 존 primaryMedium(`RX_PRIORITY`)→효과(`hazard_zone._apply_medium` 이식). **소비 4곳(RX·회피·carve)은
  아직 원**(HazardZone circle 그대로 질의) — S1b/c/d에서 이주. 게이트: `surface_smoke`(Fire/Fatal/ToxicGas) + ci_smoke 11/11.
  - **⚠️ 알려진 한계(S1):** 겹친 존에서 **연속 outcome은 단일 primaryMedium만** 적용(오늘은 겹친 존 전부 적용).
    예: Fire+ToxicGas 동시 체류 → 우선순위 상위(ToxicGas) 효과만. **✅ S4 다매질 스택에서 복원됨(2026-07-22).**
    실전 impact 작음(지속 다매질 겹침 드묾; 대부분 RX가 즉시 변환). 폴백=`USE_SURFACE_GRID=false`(원 자기완결 복귀).
  - **⚠️ 렌더 차이:** Oil 불투명 슬릭 → 셀 반투명 오버레이(MEDIUM_COLOR). 미관 폴리시는 S5.
- **S1b done** — **owned cells 전환.** 존이 셀을 **stamp-once**(원→셀, origin_id·ttl 복사)하면 셀은 그때부터
  **독립 지속**(`_cells: {key: Cell}`). `_grid_tick`(0.1s) = `_stamp_zones`(신규/변화 존만·radius/lethal 변화 시
  재스탬프·소멸 존 origin 셀 제거) → `_expire`(ttl) → outcome. render+outcome가 owned `_cells`를 읽는다(존이 아닌
  셀 룩업 O(유닛)). **flag OFF = S0 shadow 폴백 유지.** 이게 **반응(S2)·확산(S3)의 필수 토대**(셀이 원과 분리돼야
  소비/생성 가능). 게이트: `surface_smoke`(stamp→존재·ttl 만료·origin 소멸·outcome) + ci_smoke 11/11. 동작 중립.
- **로드맵 실사 갱신:**
  - **S1c(회피)·S1d(carve) 디스코프** — Fatal/impassable은 **확산 안 함**(정적 trap)이라 원(circle)이 계속
    유효. 회피/carve는 원 유지 → **고위험 nav/스티어링 이주 회피.** 필요 시에만.
  - **다음 = S3(확산 CA·frontier)** = 사용자 비전(퍼짐·바람) 핵심 payoff → 그 뒤 **S2(셀 경계 반응·DRIFT-096 종결).**
    둘 다 owned cells(S1b) 위에 얹는다.
- **S3 v1 done** — **확산 CA(owned cells 위 frontier).** 사용자 결정(2026-07-22): 권장 기본 + 확산 속도 조금 빠르게.
  - **Fire creep** — Fire 셀이 인접 **연료(Oil/Vegetation)** 셀로 번져 Fire 전환(`FIRE_CREEP_RINGS=3`/틱). 연료
    없으면 안 번짐(무한확산·성능 방지). 확산 산물 = detached(origin 0, 자체 ttl).
  - **Wind push** — Wind 존 인근 **기체(Smoke/Steam/ToxicGas) + 불** 셀을 downwind(존 밖)로 `WIND_PUSH_RINGS=3`
    이동(빈 셀로만, 틱당 `WIND_MAX_PER_TICK` 상한). **reaction_system `_spread_tick`(WindGust 자식-원 해킹)을
    flag ON일 때 비활성화** — 그리드가 대체.
  - **미포함(→후속):** gas 확산+intensity 알파 페이드는 S5. 액체·기름 바람 밀림 제외(지면 고착).
  - 게이트: `surface_smoke`(fire creep Oil→Fire·wind push 이동) + ci_smoke 11/11. **튜닝 상수**(cadence·rings·wind)는
    F5 체감 후 조정.
  - **튜닝(2026-07-22 체감):** `FIRE_CREEP_RINGS 3→2`·`SPREAD_CADENCE 0.12→0.13`(너무 빨라 잘 안 보임).
- **S2 착수 — 국소 점화(첫 조각).** 체감 피드백: Fire를 Oil **가장자리**에 맞혀도 옛 `_ignite_oil`이 **존 전체를 중심
  기준 즉시 점화**해 "가운데부터 확산"처럼 보이고 creep이 안 보였다. → flag ON 시 `_ignite_oil`이 **명중 지점 국소
  점화**로 분기: 그 존의 oil 셀을 detach(존과 분리)하고 `IGNITE_SEED_R` 인근만 Fire 씨드 → 나머지 oil 셀은 creep이
  **맞힌 자리부터** 태운다. 존 제거해도 detach된 셀 생존. 재귀 fire_hit 연쇄 제거(creep이 대체). `surface_grid.ignite_oil_local`
  + `combat_controller` facade + `reaction_system._ignite_oil` 분기.
- **S2 oil-fire 재작업(2026-07-22 체감 2차).** 피드백: ① 가장자리 점화가 oil에 안 닿고 불스킬 중앙만 탐(고정 1m 씨드가
  명중 *중앙* 기준이라 실제 oil 겹침부에 안 닿음), ② 그 뒤 detach된 oil이 원-기반 hit 감지에 안 잡혀 재점화 불가,
  ③ 확산이 끊겨 부자연스러움. 수정:
  - **`fire_hits_oil(center, radius)`** — 불의 **실제 footprint**의 oil 셀(zone-owned·detach **무관**, medium="Oil")을
    Fire로 전환. `_on_fire_damage_hit`이 이걸 직접 호출 → **detach된 oil도 재점화**(존 스냅샷 무관). 실제로 닿았을 때만
    폭발+겹친 oil존 정리(`detach_zone_cells`+`clear_zone`, passive 재트리거 방지). `ignite_oil_local` 제거.
  - **확산 부드럽게**: `GRID_TICK_S 0.1→0.06`·`RENDER_CADENCE 0.1→0.06`·`FIRE_CREEP_RINGS 2→1` = 매 0.06s 1셀 전진(점프↓).
  - 게이트: surface_smoke(footprint 점화·detach·통합경로·재점화) + ci_smoke 11/11.
- **연료 일반화 + 속도 튜닝(2026-07-22 체감 3차, 3개 다 OK 후):** ① **Vegetation도 Oil처럼** 셀 footprint 점화
  (`fire_hits_fuel(center,radius,fuel)`로 일반화 — Oil/Vegetation 공통, veg는 폭발 없이 붙음)+creep. `_rx_fire_vegetation`
  원판은 flag OFF 폴백. ② **연료별 creep 속도** `FIRE_CREEP={"Oil":2,"Vegetation":1}` — **Oil 2배**(사용자). `_fire_creep`→
  `_creep_fuel(fuel, rings)`. 게이트: surface_smoke(oil/veg footprint·veg creep) + ci_smoke 11/11.
- **veg passive 점화 + oil 속도(2026-07-22 체감 4차):** ① **Fire+Vegetation passive 점화 추가**(`_resolve_zone_pair`) —
  기존엔 Oil+Fire만 passive라 fire 존을 veg에 깔면 veg가 안 붙었다("oil·veg 떨어뜨려 동시 발화 시 veg만 안 붙음"). 셀판
  footprint 점화+detach+clear. **⚠️ spec엔 RX-FIRE-VEGETATION이 Hit RX만 — passive 신설 = 전파 후보(DRIFT-096).**
  ② **Oil creep 6배**(`FIRE_CREEP.Oil 2→6`, 사용자 "3배 더").
- **연기 위치·팽창·트레일(2026-07-22 체감 5~7차):** ① 연기를 조준중심이 아닌 **실제 점화된 셀 중심**
  (`get_last_ignite_center/radius`)에 배치(+폭발도). ② 연기 반경 = 탄 영역보다 팽창(`ir*1.4+1.0`, 기체 팽창).
  ③ **연소 완료 셀 → Smoke 전환**(`_expire`: Fire ttl 끝나면 제거 대신 Smoke `SMOKE_AFTER_TTL`) — **불이 번진 만큼
  연기가 따라 퍼진다**(일회성 착탄 원 → 확산 트레일).
- **연기 트레일화·팽창(2026-07-22 체감 8차):** ① **초기 착탄 연기 원 제거**(hit·passive) — 점화 안 된 부분까지
  덮던 문제. 연기 = **연소 트레일만**(탄 셀만). ② **`_smoke_expand`**(`SMOKE_EXPAND_CADENCE` 주기) — 연기가 외곽 빈
  셀로 번지며 옅어짐(`ttl*0.75`, `SMOKE_EXPAND_MIN_TTL` 미만이면 정지) = 탄 영역보다 크게. ③ **렌더(연기가 oil 밑):
  render_priority Smoke 8 > Oil 0라 셀 렌더상 연기가 위**(가려짐 아님). 어두운 oil(α0.80) 위에서 옅은 연기가 저대비로
  보이는 것 — **S5 render 패스(셰이더/대비) 영역.** 착탄 원 제거로 연기가 탄(빈) 자리에 주로 떠 완화됨.
- **S2 done — Fire↔Water 셀 경계 반응(DRIFT-096 종결).** `_react_cells`(grid tick): Fire 셀과 Water 셀이 **인접**하면
  그 경계 셀들만 Steam으로(양쪽 소진, 매틱 1셀 잠식 = 서서히). `_resolve_zone_pair`의 **중점 Steam+원 shrink 근사
  폐기**(flag ON) — "교집합만 반응 + 서서히 확산"이 셀 단위로 실현. 게이트: surface_smoke(인접 반응·비인접 무반응) +
  ci_smoke 11/11. **DRIFT-096 근사 정식 해소.** (Oil+Fire·Fire+Veg는 이미 creep/footprint로 셀화됨.)
- **perf 실사·해소(2026-07-22 체감 9차, 10존 랙 제보):** 원인 = 구현이 frontier 아닌 **naive**(매 틱 전체 셀 다중
  순회 + oil 6링=6패스). 1차: **매질 인덱스 + creep frontier BFS**(50→30ms/틱). 그래도 남은 병목 = **0.1m×다존
  = 지속 oil 셀 28k 전체를 매 틱 순회/렌더**(index/expire/render는 셀 수 비례 — 초기 경고한 "0.1m=100× 셀" 본질).
  2차(사용자 A안): **`CELL_M 0.1→0.25`**(셀 ~6배↓) → per-tick CA **30.6→5.95ms**(surface_bench D, 10존 4480셀).
  cell-count 속도(creep/wind)는 m/s 보존하려 `Oil 6→2`·`WIND 3→1` 재스케일. 엣지 미세함은 S5 셰이더.
  ⚠️ 근본 교훈: **cell-count 튜닝은 셀 크기 의존** — 향후 m/s 기반으로 바꾸면 셀 크기 무관해짐(S5 후보).
- **확산 유기화(2026-07-22 체감 10차):** creep이 4방향 인접 연료를 매 틱 **전부** 전환 → 완벽한 다이아몬드 전선
  (도미노·직선). → **노이즈 변조 확률 전파**: 각 frontier→연료 전환 확률을 `FastNoiseLite` 공간 노이즈로 변조
  (`_creep_noise_at`, `BASE_PROB 0.72 · MIN 0.30`). 안 붙은 셀은 다음 틱 재시도 → 불규칙 fingers, 결국 다 탐.
  impl/튜닝(DRIFT-096 확산 우산). smoke는 확률이라 creep 테스트를 반복 호출로 near-certain화.
- **S4 done — 다매질 스택(activeMedia = primaryMedium + extra), INT-002 §6.1 정확 수렴.** 리스크 통제로 **primary(평면 필드)=primaryMedium
  + `extra:{medium→MediumState}`=하위 activeMedia** 모델 채택(spec primaryMedium/activeMedia 구분과 정합). 3단계:
  - **S4a**(behavior-neutral): `MediumState` 클래스 + `Cell.extra` + 리더 extra-aware(`_tick_outcomes`/`_apply_medium_outcome`·
    `_render_cells`·`_expire` 하위 만료+`_promote_extra`). extra 항상 비어 동작 불변. 게이트 ci_smoke 11/11.
  - **S4b**(S1a 복원): `_stamp_zone` drop→**stack**(`_merge_medium_into`·`_demote_primary_to_extra`), origin·`_remove_origin`·
    `detach_zone_cells` 매질별. 겹친 존 outcome/render **전부** 적용. primary 소멸 시 하위 승격. surface_smoke test17.
  - **S4c**(셀-내 RX): `_react_same_cell`(같은 셀 Fire+Water→Steam, 겹침 내부=S2 인접의 보완) + 변환자(`fire_hits_fuel`·
    `_creep_fuel`·`_react_cells`) **extra-clear**(stale/dupe 봉합). Oil+Fire·Fire+Veg는 `reaction_system._resolve_zone_pair`→
    `fire_hits_fuel`(폭발/detach 포함)가 이미 처리 → 안 건드림(preempt 방지). surface_smoke test18.
  - **비드리프트(수렴):** S4는 게임이 방금 전파한 `INT-002 §6.1`(activeMedia[]/primaryMedium)에 따라잡는 것 → 새 spec 드리프트 없음.
    창발 트레이드오프(겹침 내부 Fire+Water 즉시 Steam·반응 변환 시 하위 매질 소진)는 튜닝/체감(F5).
- **S4d done — passive 반응 트리거 일원화(반응 아키텍처 정리, 사용자 지적 "예외처리식" 해소).** S4c가 남긴 감지 이원화
  (circle `_resolve_zone_pair` vs 셀)를 규칙으로 대체:
  - **passive 매질 반응 감지 = 그리드 CA 단일 소유.** `_react_same_cell`이 Fire+{Water→Steam · Oil→Fire · Vegetation→Fire}를
    **균일 처리**(특수처리 skip 제거) + adjacency는 `_creep_fuel`. `reaction_system._physics_process`가 flag ON에서 **early-return**
    → `_zone_reaction_tick`/`_resolve_zone_pair` 미호출; `_resolve_zone_pair`는 flag OFF 원모델 폴백 전용으로 축소.
  - **effect layering(감지=grid / 전투효과=reaction_system):** RX-OIL-FIRE **폭발**은 reaction_system 소유 — 그리드가 Fire+Oil 감지
    → `_combat.rx_explode_at` → `reaction_system.passive_explode`(국소 1회, oil+fire 셀 centroid, fsafe/source 승계). Fire+Veg는
    폭발 없음(RX-FIRE-VEGETATION 정합). `grid._combat` 주입(combat_controller).
  - **규칙:** *passive medium 반응 = 그리드 CA · Hit 이벤트/전투효과 = reaction_system.* **spec 정합 유지(비드리프트)** — passive
    Oil+Fire는 여전히 RX-OIL-FIRE 폭발(방금 전파한 `INT-002 §6.1` Overlap combo RX와 일치). surface_smoke test19(폭발 콜백)·ci_smoke 11/11.
  - **데이터 주도(if-분기 제거, 사용자 요청):** passive 반응을 `SAME_CELL_RX` 테이블 + `RX_RESULT_PRESET`(결과 매질 프리셋)로.
    `_react_same_cell`은 제네릭 루프(`_match_same_cell_rx` — 테이블 순서=우선순위), 전투효과는 `_dispatch_burst`(burst kind →
    reaction_system 콜백). **새 반응 = 테이블 한 줄**(코드 무수정). 반응이 늘 부분이라 선접기(Ice·Lightning passive 등 대비).
- **남은:** S5(gas/연기 알파 페이드·셰이더 엣지·m/s 기반 속도·render dirty-track). ⚠️ S4/S4d **F5 체감 대기**(겹친 존 동시효과·렌더 층서·passive Oil+Fire 국소폭발 유지).

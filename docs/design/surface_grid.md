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
CellState (MVP·S1):
  medium       : String       # MVP 단일; S4 → activeMedia{medium→sub} + primaryMedium
  intensity    : float 0..1    # 확산·부분소진. MVP는 1.0 바이너리 허용
  age / ttl
  dps, slow
  source       : WeakRef       # threat crediting
  friendly_safe, safe_faction  # DRIFT-094
  impassable   : bool          # Fatal → carve (매질과 분리 — spec엔 Fatal 매질 없음, F-006 Severity)
```
S4에서 `medium`→`activeMedia` 스택+`primaryMedium`(기존 `RX_PRIORITY` 재사용) 승격 → INT-002 §6.1 정확 수렴.

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
| **S4** | 다매질 스택(`activeMedia[]`/`primaryMedium`) → INT-002 §6.1 정확 수렴 | 중 | 낮음~중 |
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

## 5. spec 전파 (Target A · S1/S2 체감 후 별도 승인)
`OPS_30`: `INT-002 §6.1`+`EVENT-CORE §3`에 "타일=크기 X 셀 · 반응/확산 per-cell CA · `radius_m`=초기 seed" 명료화 →
staging PR → `spec_ref` 재핀. **`ZONE-CORE`/`EFFECT-CORE` 지오메트리 불변**(수렴, 이탈 아님). DRIFT-096: 🔶전파후보
→ "realized + INT-002 소폭 명료화".

## 6. 진행 상태

- **S0 done** — shadow substrate(`surface_grid.gd` 관측 렌더·MultiMesh·A/B `N`키·`surface_smoke`). 무침습.
- **S1a done** — **outcome+render 권위를 셀로**(`USE_SURFACE_GRID=true`, `hazard_zone.gd`). HazardZone은 mesh·자기
  outcome틱을 은퇴(`_build`/`_physics_process` 게이트, `clear_zone` null-safe, `get_source`/`is_lethal` 게터)하고
  **lifetime(ttl/telegraph/clear)·geometry(radius/contains_point)·group만 유지.** `SurfaceGrid._tick_outcomes`가
  유닛→커버 존 primaryMedium(`RX_PRIORITY`)→효과(`hazard_zone._apply_medium` 이식). **소비 4곳(RX·회피·carve)은
  아직 원**(HazardZone circle 그대로 질의) — S1b/c/d에서 이주. 게이트: `surface_smoke`(Fire/Fatal/ToxicGas) + ci_smoke 11/11.
  - **⚠️ 알려진 한계(S1):** 겹친 존에서 **연속 outcome은 단일 primaryMedium만** 적용(오늘은 겹친 존 전부 적용).
    예: Fire+ToxicGas 동시 체류 → 우선순위 상위(ToxicGas) 효과만. **S4 다매질 스택(activeMedia[])에서 복원.**
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
  연기가 따라 퍼진다**(일회성 착탄 원 → 확산 트레일). 초기 착탄 연기(팽창)는 유지.
- **남은 S2:** Fire↔Water 등 나머지 경계 반응(`_zone_reaction_tick` 중점/shrink 완전 대체) → DRIFT-096 종결.

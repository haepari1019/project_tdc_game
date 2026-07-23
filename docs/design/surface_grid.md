# Surface Grid — 환경 존 셀 그리드화 설계 (게임측 정본)

> **무엇:** 환경 surface(존)를 `center+radius` **원 단위** → DOS2/BG3식 **셀 그리드 substrate**로 전환하는
> 게임측 설계·단계·마이그레이션 계획. DRIFT-096의 "원 단위 근사"(교집합=중점 Steam·확산=반경 축소) 한계를
> 정식 해소하고, 예정된 **퍼짐(spread)·바람 밀림(wind)** 기능의 토대를 만든다.
> **SSOT:** spec `F-021 §3.2`(RX)·`EVENT-CORE §3`·`INT-002 §6.1`(Tile medium model)·`ZONE-CORE`·`EFFECT-CORE`.
> 본 문서는 **게임측 실행 계획(규칙 아님).** 규칙 변경은 spec repo + OPS_30.
> **상태:** **S0~S4d done + F5 검증 완료(샌드박스, 2026-07-23).** Target A(셀=substrate, 원=저작). DRIFT-096/097/093 전파 완료. 다음 = S5(렌더/perf).
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

### 2.6 렌더 — 필드(coverage, flag ON) / MultiMesh(flag OFF 폴백)
**flag ON(현재) = 필드 방식(S5b done).** 셀 → 매질별 coverage 이미지(R=intensity) → 지면 plane 1장이 `bilinear`+월드 노이즈로
샘플 → 매끈한 유기 표면(겹침 알파누적 격자·타일 seam 없음, plane 1장=픽셀당 1샘플). 아래 MultiMesh 서술은 **flag OFF 폴백**.
매질별 `MultiMeshInstance3D` 1개, 활성 셀당 flat quad 인스턴스 1개. per-instance transform(셀 중심)+custom-data
(intensity→alpha). **매질당 draw call 1회.** 버퍼는 매 그리드 틱 갱신 O(활성 셀). **DRIFT-095 깜빡임 대부분 소멸**
(셀은 평면상 안 겹침; 매질 STACK만 `RENDER_ORDER`로 순서). 유기 엣지=셰이더 노이즈(S5). 대안(셰이더 필드,
vision_fog 월드XZ→UV 재사용)=S5 최적화 후보.

**렌더 = 셀의 읽기 전용 소비자 (미래 아트 대비, 2026-07-23).** 렌더는 셀 상태를 *읽기만* 하고 바꾸지 않는다 → 진짜
그래픽(블렌더 텍스처·GPU 파티클·메시)은 **렌더 층만 교체**, 시뮬(반응·데미지·확산)은 무변. **인계 seam** =
`_render_cells`의 `buckets{매질→{셀:intensity}}`. 매질별로 다른 렌더러 가능(`_update_medium_mesh`가 매질당 1):
기름/물/얼음/초목=텍스처 지면(S5 셰이더가 토대), 불/연기/증기/독안개=`GPUParticles3D`(활성 셀 영역=emitter), 특수=영역
hero 메시. **`CELL_M`=시뮬 해상도지 아트 해상도 아님**(아트 디테일=텍스처/파티클로 sub-cell 무제한 — 셀 안 잘게 해도 됨).
매질별 렌더러 인터페이스(quad/particle/decal 전략)는 **아트 방향 확정 후 이 seam 위에 접는다**(지금은 YAGNI — 위 분리 규율만 유지).

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

## 6. 진행 상태 — S0~S5 완료 (요약)

> 최종 상태 + 핵심 결정/교훈만. F5 튜닝 라운드 블로우바이블로우는 **git 이력**(압축, 2026-07-23).

**완료 스테이지:** S0(shadow) · S1a(outcome/render 권위를 셀로, `USE_SURFACE_GRID=true`) · S1b(owned cells) ·
S3(확산 CA) · S2(셀 경계반응·DRIFT-096 종결) · S4~S4d(다매질 스택·반응 아키텍처) · S5a/b(렌더) · S5 perf.
`surface_smoke`(test1~20) + `ci_smoke 11/11` + F5 체감(시각 스테이지) 게이트 전부 통과. **폴백:** `USE_SURFACE_GRID=false` → S0 shadow(원 자기완결).

- **S1c/S1d(회피·carve) 디스코프** — Fatal/impassable은 확산 안 함(정적 trap) → 원(circle) 유지 = 고위험 nav/스티어링 이주 회피.

### 핵심 결정·교훈 (스테이지별)
- **S1b owned cells = 반응/확산의 필수 토대.** 존이 셀을 **stamp-once**(원→셀, origin_id·ttl 복사)하면 셀은 원과 분리돼 독립
  지속(`_cells:{key:Cell}`) → 소비/생성 가능. `_grid_tick` = stamp(신규/변화 존만) → expire → 반응 → 확산 → outcome.
- **S3 확산 모델.** Fire **creep** = 인접 **연료 셀(Oil/Vegetation)로만** 번짐(무연료=무확산, 산물=detached origin 0); **Wind push**
  = 기체+불을 downwind 빈 셀로(WindGust 자식-원 해킹 대체). **유기화**: creep이 4방향 전부 전환하면 다이아몬드 직선전선 →
  **노이즈 변조 확률 전파**(`_creep_noise_at`)로 불규칙 fingers(안 붙은 셀 다음 틱 재시도, 결국 다 탐).
- **S2 국소 점화 + 경계반응.** 옛 `_ignite_oil`(존 전체 즉시점화)이 creep을 가림 → **`fire_hits_fuel(center,radius,fuel)`**로 불
  **footprint의 연료 셀만** 점화(Oil/Vegetation 공통, zone-owned·detach 무관 → 재점화 가능)+creep. **Fire↔Water 셀 경계반응**
  (`_react_cells`: 인접 경계 셀만 Steam, 매틱 1셀 = 서서히) = **DRIFT-096 근사(중점 Steam·원 shrink) 정식 해소.** 연소 완료 Fire
  셀 → Smoke 전환(`_expire`)+외곽 팽창(`_smoke_expand`) = 트레일.
- **perf 교훈.** index/expire/render는 **셀 수 비례** → `CELL_M 0.1→0.25`(셀 ~6배↓, per-tick CA 30→6ms). 확산은 매질 인덱스+
  frontier BFS. **근본 교훈: cell-count 튜닝은 셀 크기 의존** → S5에서 m/s로 해소.
- **S4 다매질 스택 (INT-002 §6.1 정확 수렴, 비드리프트).** `Cell.medium`(primaryMedium) + `extra:{medium→MediumState}`(하위
  activeMedia). 겹친 존 outcome/render **전부** 적용 = S1a 한계(겹침 시 단일 primaryMedium만) 복원. 단계 S4a(구조·무동작)→
  S4b(stack)→S4c(셀-내 RX + 변환자 extra-clear). 리스크 통제로 위험한 CA는 S4c까지 무손.
- **S4d 반응 아키텍처 규칙 ("예외처리식" 해소).** **passive medium 반응 = 그리드 CA**(`_react_same_cell` + `SAME_CELL_RX`
  데이터 테이블·`_creep_fuel`) · **Hit 이벤트/전투효과 = reaction_system.** 감지 일원화(circle `_resolve_zone_pair`는 flag OFF
  폴백 전용). **effect layering**: RX-OIL-FIRE 폭발은 reaction_system 소유 — 그리드 감지 → `_combat.rx_explode_at` 콜백.
  새 반응 = 테이블 한 줄(Ice·Lightning passive 등 대비 선접기).
- **S5b 렌더 교훈 (중요).** 반투명 **per-quad** 타일은 **겹치면 알파누적(내부 격자)·안 겹치면 seam** → 매끈한 표면 구조적
  불가(원형/정사각 rim 다 실패). **필드 방식이 정답**: 셀 → 매질별 coverage 이미지(R=intensity) → 지면 plane 1장이 `bilinear`+
  월드 노이즈로 샘플(픽셀당 1샘플, 누적 없음). S5a 알파 페이드(휘발성 매질만) 유지. noise 시드는 surface 등장마다 재롤.
  **coverage 텍스처 = 미래 아트 셰이더 토대**(§2.6).
- **S5 perf.** m/s 속도(`_mps_to_rings`, 셀 크기 무관) · render dirty-track(정적 비휘발성 표면은 재빌드 스킵 — `_has_fade_media`
  + `_cells.size()` gate 한 곳, sprinkle 없음).

**남은:** chunk 승격(대면적 상시 표면) = 데모엔 **YAGNI**. **surface 셀 그리드 대공사 = 사실상 완료**(S0~S5 + DRIFT-096/097/093 전파).

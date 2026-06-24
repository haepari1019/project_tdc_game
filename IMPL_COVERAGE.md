# Implementation Coverage

> Non-SSOT. Phase 2 스프린트 종료마다 갱신. 정본 스코프는 spec `docs/context/ImplementationPhase_FullSpecCoverage.md`. 실행 로드맵: [docs/ROADMAP_P2_FullCoverage.md](docs/ROADMAP_P2_FullCoverage.md).

- spec_ref_pin: `bc22c38` (`main`, 2026-06-22; 제3세력 Stalker Pack 전파 DEC-20260621-001)
- last_sprint: **P2-S6a 파티 능력 풀 lootable 완료** — lootable sub 44종 + 신규 effect kind 18종. B1 잔여 + 밴드 패널티(sub_bands) + ally-cache + B2 데미지 sub 19 + **bespoke 5종(taunt/pull/slow/relocate/reveal)** 완료. 이전: P2-S5a 진영전+제3세력 · P2-S6a Phase1 · 기어 카탈로그(DRIFT-056). **메타세이브 I1–I5 완료** + **이연 능력 디테일**(Shadowstep+20%·Sentinel 40%반사·Beam Channeling·Bloodlust HP-scale) 완료. 투사체 delivery Phase 1+2(범용 projectile·진영필터 + 파티 10종 + 적 샷 interception RP-02). **P2-S6b-1a 시작**: 스킬북 economy 로직(분석 N=3→해금→상점 buy_raw·ward_scrap, F-009/D-018) + 스타터 시드 정렬(§3.1.1), hub_smoke 검증. **다음: S6b-1b(분석/상점 허브 UI) → gear roll-table(고위험 게이트)·affix 또는 S5b**
- last_updated: 2026-06-23

## Full Spec Coverage — AB-### 스냅샷 (2026-06-23 갱신)

전체 스펙 어빌리티 **AB-### ~72/84** (S3 zone 7·제3세력 7·정체성 6 + 파티 풀 lootable sub 44). 적 전투행동(EN-001~014) 완료, ENC·zone·진영전 완료. **파티 능력 풀 lootable 완료** — B2 19 + bespoke 5·밴드 패널티(sub_bands)·획득(ally-cache) 적용. 잔여=적 kit 3(AB-003/005/007 적측)·S6b economy (상세·로드맵: [ROADMAP](docs/ROADMAP_P2_FullCoverage.md)).

| 군 | 구현/전체 | 미구현 핵심 |
|----|:---:|------|
| 적 kit (비-zone) | 10/13 | AB-003·005·007 (대체평타·연타후속·후퇴hop) |
| 적 zone/원소 | ✅ 7/7 | AB-009/036/039/040/041/042/043 — F-027 ZONE (P2-S3) |
| 제3세력 (AB-100~106) | ✅ 7/7 | 적측+lootable 아군 6종 (S5a·S6a Phase1) |
| 정체성 ability effect | ✅ 6/6 | AB-021/022/052·027·029/031 (기어 카탈로그, DRIFT-056) |
| 파티 능력 풀 (기타 lootable) | ✅ ~49/~49 | 완료 — B1 신규 kind 12 + B2 19(skillbook_bolt 8 + 재사용) + **bespoke 5**(taunt/pull/slow/relocate_ally/reveal). 밴드 패널티(sub_bands)·ally-cache 적용. **능력 디테일 해결**: Shadowstep+20%·Sentinel 40%반사·Beam Channeling·Bloodlust HP-scale. 잔여 BLOCKED: Rampart 투사체흡수·Tether leash-DoT |
| 적 기본타 rom_* (별도) | 15/15 | rom_stalker/snarer/reaver 포함 |
| PT-### 적 패턴 (별도) | ✅ 17/17 | PT-023~025(제3세력) 포함 |

## Sprint log

| Sprint | Done | Notes |
|--------|------|-------|
| P2-S1 | ◐ | S1a~e 완료 + 헤드리스 검증 통과. S1f 문서 완료 · **인터랙티브 Hard 플레이 스모크(§9.1)는 F5 수동** 잔여 |
| P2-S2 | ◐ | S2a~c(1~4): 적 **전투행동 축** 완료+헤드리스 PASS (ID 1:1·포지셔닝·시그니처 캐스트·대시·Provoked·§2 interrupt). EN-001~014 행동 kit 반영. |
| P2-S2-fin | ☑ | **Track A 완료** — A1 조합 ENC(HARD-002/003/004)+Upper 룸·A2 phase 증원 rear/flank(HARD-005·010)·A3 AssassinTransform(NORM-003·011)·A4 MiniBoss(BOSS-001 ccTenacity+50%HP 페이즈). ENC 12→17/24, navmesh 244→284, 헤드리스 PASS. **잔여(P2-S2 스펙):** PAT/AMB=placement 레인 · 3RD=faction · 적 zone AB(F-027/P2-S3) · 교전 체감 F5 |
| P2-S2-place | ☑ | placement_behavior(Fixed/Patrol/AmbushHold)·dual-anchor 순차·PAT-003 torch · 확률 ENC resolve(가중 다중후보+runSeed)+스폰 산포 (DEC-20260620-002). ENC-PAT/AMB 5종. |
| P2-S3 | ☑ | Interaction keystone — 9매체 zone·event bus·primaryMedium resolver·Hit-RX 4축(Fire/Cold/Lightning/Physical)·zone AB 7종 enemy+lootable. **S3e spread만 보류.** |
| P2-S4 | ☑ | Hub(F-029) — 8시설 Tier·Quest/Haul 게이트·vault 파이프·UI-029 승급·디스크 영속·ENC haul 드롭표·QA-029 스모크. **효과 실연동 이연**: armory B/C(GEAR-COR-000)·분석/상점(F-009)·passive(F-020)·capacity 강제. |
| P2-S5a | ☑ | 진영전(F-028 core: 교차진영 타겟·N진영/혼합분대) + **제3세력 Stalker Pack**(EN-3RD-01~03 추적/포획/학살·AB-100~106·PT-023~025·ENC-3RD-001·outcome Rooted/Pinned/Scented/Tethered/Bloodlust). 진영전 크래시 전수정리. ci_smoke+third_smoke PASS. |
| P2-S6a Phase1 | ☑ | 제3세력 lootable 아군 효과 6종(loot 루프 완성, 2ddf580). |
| P2-S6a 파티풀 | ✅ lootable 완료 | lootable sub **44종** + 신규 effect kind **18종**. B1(12) + **B2 데미지 19**(skillbook_bolt 8 + 재사용 11) + **bespoke 5**(taunt AB-035·pull AB-051·slow AB-050·relocate_ally AB-045·reveal AB-032). **밴드 패널티**(`sub_bands`+BAND_COEFF) · **ally-cache 상자**(RM-ADV-01). `party_pool_smoke.gd`(전 kind 커버 + 디테일 거동) + ci_smoke PASS. **능력 디테일 해결**(Shadowstep+20%·Sentinel 40%반사·Beam Channeling·Bloodlust HP-scale, IMPL-DEC-017). **잔여 BLOCKED**: Rampart 투사체흡수(투사체 엔티티 부재)·Tether leash-DoT. 13cb343·5103b68·3859579·644c29e(I5)·(디테일 미커밋). DRIFT-055/056/057/058·IMPL-DEC-013~017. |
| 기어 카탈로그 | ☑ | 17 신규 기어·6 정체성·6 ability effect(beacon_threat/march_advance/sentinel_form/arc_line/flank_dash/ward_shield)·기어귀속 평타(D-019)·평타 VFX 8종·샌드박스 검증툴 (DRIFT-056). |
| 메타세이브 B | ✅ I1–I5 | SaveProfile 단일파일·Backpack 오토로드·낱개/장착서브/소비/장착기어 영속·재료 금고 일원화·스태시/금고 편집창. **I5**: RunLoadout config 전용(죽은 인벤 필드 제거)·서브 **충전수 영속**(부분소모 런간 유지). 완전 Backpack화는 기존 가드/동기화로 이미 도달. IMPL-DEC-016. |
| P2-S6b 1a+1b | ◐ | **1a 로직**(F-009 §3.5/D-018 §7.1): HubProfile 분석(N=3·scriptorium 게이트·해금 후 거부)→해금→`buy_raw`(scribe_shop ceiling+ward_scrap Basic12/Adv30/Master60). ward_scrap=추출 보상(15+생존자×5, 데모). 스타터 시드 §3.1.1 정렬. hub_smoke 7 assertion. **1b UI**: `hub_economy_panel`(분석 의뢰·상점 구매·scrap 표시) + main.gd 버튼. **잔여**: per-AB tier 데이터·affix·gear roll-table(게이트). DRIFT-060·IMPL-DEC-020. |

## P2-S2 checklist (combat redesign)

| ID | Item | Status |
|----|------|--------|
| S2a | Combat ID 1:1 — rom_* basics·비-spec AB 제거·EN-014 Gutter Chanter·ENC-NORM-001 | ☑ 커밋 186a024 (헤드리스) |
| S2b | Per-enemy 포지셔닝 — patterns.json(PT-### 미러)·`engage` 7프로필·enemy_ai 분기 | ☑ 헤드리스 PASS · **체감 F5 잔여** (2210d30) |
| S2c-1 | 시그니처 캐스트 — AB-004 차지·AB-008 스플래시·AB-012 헥스·**AB-098 EN-014 힐**(+channel-freeze) | ☑ 헤드리스 PASS · **체감 F5 잔여** |
| S2c-2 | AB-006/013 대시 (EN-003 갭클로즈 · EN-008 백스탭 mobility) | ☑ 헤드리스 PASS · **체감 F5 잔여** |
| S2c-3 | AB-099 Iron Mockery / **Provoked** (EN-001 존 도발 + party-side 상태 + 입력 게이트) | ☑ 헤드리스 PASS · **체감 F5 잔여** |
| S2c-4 | 채널 interrupt + 적 stun primitive (EN-AI-000 §2 — Toll Stun으로 채널 끊기) | ☑ 헤드리스 PASS · **체감 F5 잔여** |

> S2b engage 맵: advance(EN-001/010/012/013)·standoff(EN-002/007/011)·kite(EN-005/014)·zone(EN-004)·orbit(EN-003/008)·probe(EN-006)·surround(EN-009). PT-### 정본=EN 유닛문서 patternRef(EN-010~013→PT-012~015). 상세 DRIFT-040.

## P2-S1 checklist (game)

| ID | Item | Status |
|----|------|--------|
| S1a | AGENTS v2 · IMPL_COVERAGE · spec_ref bump | ☑ (2026-06-18) |
| S1b | spawn_table + Slice01Data resolver (override>exact>pool+diff) | ☑ 헤드리스 검증 |
| S1c | rooms.json ≥12 · world_layer · map layout (겹침0·연결 navmesh 244폴리) | ☑ 헤드리스 검증 |
| S1d | encounter JSON 9 + EN 스텁 6 + id_registry | ☑ |
| S1e | run_controller data-driven phase (monotonic SEQUENCE) | ☑ 5단계 전환 검증 |
| S1f | 헤드리스 검증 · IMPL_COVERAGE · SPEC_DRIFT | ◐ docs 완료, 수동 스모크 잔여 |
| — | Recovery revisit (D6) | **deferred** DRIFT-031 |

## Spawn table (LDG-SPAWN-DEMO-001) — 헤드리스 prespawn resolve 검증

| poolSlot | world_layer | Normal | Hard | spawned (in-engine) |
|----------|-------------|--------|------|---------------------|
| P-ENTRY-01 | Upper | ENC-NORM-002 | — | ☑ Normal |
| P-ADV-01 | Upper | ENC-NORM-001 (force) | ENC-NORM-001 (force) | ☑ 양쪽 |
| P-ADV-02 | Upper | — | ENC-HARD-006 | ☑ Hard |
| P-ADV-03 | Upper | — | ENC-HARD-010 | ☑ Hard |
| P-ADV-04 | Upper | — | ENC-HARD-011 | ☑ Hard |
| P-ADV-05 | Upper | — | ENC-HARD-012 | ☑ Hard |
| P-EXT-ROUTE-01 | Upper | — | ENC-HARD-009 | ☑ Hard |
| P-MID-01 | Mid | ENC-MID-001 | ENC-HARD-008 | ☑ 양쪽 |
| P-DEEP-01 | Deep | ENC-DEEP-001 | — | ☑ Normal |
| P-BOSS-01 | Mid | — | ENC-BOSS-001 | ☑ Hard |

> D4 (MID/DEEP/BOSS 각 1회 스폰): **Normal=MID-001+DEEP-001 / Hard=BOSS-001** — LDG 테이블 충실(단일 런이 셋 다는 아님). force override(P-ADV-01→NORM-001)가 Hard 행(HARD-001)을 가려 ENC-HARD-001은 로드되나 미스폰. manifest.encounters는 legacy fallback(resolver가 정본).

## Regression (1b — must stay green)

| Feature | Status |
|---------|--------|
| Hub deploy + RunLoadout | ☑ 헤드리스 hub load clean |
| Key-gate objective + extract | ◐ 구조 불변(door→complete_objective·can_extract 미변경) · F5 스모크 잔여 |
| PartyWipe → Run Failure | ◐ 미변경 · 스모크 잔여 |
| Inventory / gear / skillbook | ◐ 미변경 |
| Vision fog + enemy AI | ◐ 미변경 · navmesh 재베이크 정상 |

## Known drift

| DRIFT | Summary |
|-------|---------|
| 031 | Recovery persistence/revisit deferred (P2-S1 밖) |
| 037/038 | F-011 fog · See-Through ✅ MERGED (daa1114 · 재핀 4422e50) |
| 039 | P2-S1 dungeon scale — EN-002/003/004/007/008/009 스텁·ENC 9 스텁·맵 placeholder 기하 (kit·폴리시=P2-S2) |
| 040 | P2-S2b per-enemy 포지셔닝 — PT-### `engage` 파생·이동 PH 튜닝. 교전 체감 F5 잔여 |
| 041 | P2-S2c-1 시그니처 캐스트 — AB-004/008/012/098 + channel-freeze. HEX 피해감소·interrupt·zone = 후속. F5 잔여 |
| 042 | P2-S2c-2 대시 mobility — AB-006/013. 벽 라우팅·AB-005 flurry·AB-007 hop = 후속. F5 잔여 |
| 043 | P2-S2c-3 AB-099 Provoked — EN-001 존 도발 + party 상태. AB-031 클렌즈 = 후속. F5 잔여 |
| 044 | P2-S2c-4 채널 interrupt + 적 stun — Toll Stun으로 채널 끊기. 적 stun VFX = 후속. F5 잔여 |

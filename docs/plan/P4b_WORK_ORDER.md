# P4b 이관 작업 지시서 — 허브 · 스킬 장착 · 건 모딩

> **무엇:** 스킬 교정(DRIFT-101~136) 완료 후 **플레이테스트를 막고 있는 4겹 갭**의 교정 순서.
> **상위 플랜:** [I007_economy_migration_plan.md](I007_economy_migration_plan.md) (M1~M6 마일스톤 레벨). 본 문서 = 그 위의 **파일 단위 작업 지시 + 게이트 + 선행 결정**.
> **스펙 근거:** `F-009` §3.9 · `F-008` §3.10 · `F-020` §3.2.3/§3.7/§3.10 · `D-019` §3.3 · `F-029` chapel · `UI-005` §3.2 · `I-007` §15 P4b.
> **스펙 핀:** `spec_ref.json` = **`fd317b3`** (`DEC-20260813-002` 반영 후 재핀, 2026-08-13). **PENDING-PROP 없음.**
> **작성:** 2026-08-12.

---

## 0. 확정된 결정 (사용자, 2026-08-12)

| # | 결정 | 선택 | 함의 |
|---|------|------|------|
| D1 | 스코프 | **I-007 전면 이관 먼저** (M1~M5) | 마석·참·트리·금고까지 통짜 교체 후 허브/UX |
| D2 | 슬롯 AB 귀속 | **spec 정본 — gear 교체 시 소멸** | 재구매 경로(트리+상점)가 **선행 필수** → M3/M4가 M5보다 앞 |
| D3 | 결속 해소 키 | **identity 단독 키 + gear 변주 오버라이드** | 스태시 gear 19종 전부 시그니처 활성. §2b 참조 — **spec 역전파 필요** |
| D4 | 스태시 시드 | **전 카탈로그 개방** | 플테 전용. P4b 후엔 "gear 전량 소유 + 트리 전 노드 해금"으로 재해석 |

**D2 ↔ D4 정합성:** 소멸 모델은 "잃으면 다시 얻을 수 있어야" 성립한다. D4가 트리를 전부 해금해 두므로 재구매 경로가 항상 열려 있어 소멸이 소프트락으로 번지지 않는다. 둘은 충돌하지 않는다.

---

## 1. 현황 갭 (진단)

### 1a. 스킬 장착 모델이 spec P4b와 어긋남

spec `e328aaa`(2026-07-04)에서 서브 경제가 **스킬북 → gear 슬롯 스킬 + 마석**으로 교체됐다. 게임은 교체 전 모델로 돌아간다.

| 축 | spec 정본 | 현재 게임 | 위치 |
|----|-----------|-----------|------|
| 서브 귀속 | gear 인스턴스 `equippedSlotAbilities[3]` | 멤버 `skillbook_slots` | [party_member.gd:96](../../scripts/party/party_member.gd) |
| 슬롯 수 | 스타터 1 → `smithy` T2=2 → T3=3 | 항상 3 | 동일 |
| 장착 제약 | `allowedSlotFamilies` + Role Gate | Role Gate만 | [party_member.gd:323](../../scripts/party/party_member.gd) |
| gear 교체 | 슬롯 AB **소멸** → 재구매 | 서브는 멤버에 잔존 | [backpack.gd:129](../../scripts/autoload/backpack.gd) |
| 시전 소모 | 마석 | `charges` (**spec Deprecated**) | [skillbooks.json](../../data/slice01/skillbooks.json) |
| 해금 | 스킬 트리 | 분석 N=3 → 상점 (**spec Deprecated**) | [hub_economy_panel.gd](../../scripts/ui/hub_economy_panel.gd) |

코드 전역에 `slot_abilities` / `manastone` / `skill_tree` 심볼 **0건**.

### 1b. 결속이 gear ID 하드바인딩 → 스페어 gear 13종의 시그니처가 죽어 있었음 ✅ **M0b 해소**

[binding_overlays.gd:352-425](../../scripts/combat/abilities/bindings/binding_overlays.gd)의 게이트 8종(`identity_marks` / `identity_focuses` / `identity_flanks` / `identity_dot_heals` / `identity_sanctuaries` / `identity_overdrive` / `identity_bloodgale` / `signature_for`)이 전부 **`(base_gear_id, identity_ab)` 쌍이 `OVERLAYS`에 등재돼야** true를 돌려준다. 등재된 gear는 **8종뿐**.

스페어 gear는 **17종**(카탈로그 27 − 스타터 4 − armory 세트 6). 그중 **13종이 규약 미작동**이었다
(11종 = SIGNATURE는 있으나 gear 미등재 · 2종 = SIGNATURE 자체가 없음). armory 세트 6종도 동일:

| gear | identity | 죽은 규약 |
|------|----------|-----------|
| `gear_ward_tank_rampart_wall` | IDA-020 | 방벽 충전 |
| `gear_ward_tank_beacon_hook` | IDA-021 | 표식 |
| `gear_ward_nuker_scout_frame` · `hex_scope` · `coil_rifle` · `volt_lance` | IDA-025 | 집중 |
| `gear_ward_healer_beacon_lantern` | IDA-026 | 성역 |
| `gear_ward_dps_ember_wand` · `brand_foci` | IDA-024 | 초월 |
| `gear_ward_dps_rift_needle` · `tide_censer` | IDA-027 | 혈풍 |

| `gear_ward_tank_march_plate` · `march_set` | IDA-022 | **규약 미정의**(U2) |
| `gear_ward_tank_sentinel_aegis` | IDA-052 | **규약 미정의**(U2) |

> **해소:** M0b가 결속 키를 프로필(기본 = effective identity)로 바꿔 **작동 8종 → 24종**. 잔여 3종은
> U2(IDA-022·IDA-052 규약 미확정)이며 `binding_smoke` 전수 스윕이 「규약미확정」으로 분류해 추적한다.

`resolve_effective`는 `GENERIC`(identity 단독 키)으로 폴백하므로 **슬롯 델타는 살아 있고 시그니처만 죽는 반쪽 상태**다. 구조적 원인: gear 인스턴스는 정체성을 **굴리므로**(`rolled_identity_skill_id`) gear 아키타입 ID를 키로 쓰면 굴림 결과와 영구히 어긋난다.

### 1c. 스태시/백팩 시드가 현행 카탈로그와 불일치 ✅ **M0 해소**

[stash.gd:69-76](../../scripts/autoload/stash.gd):
- `skillbooks = ["AB-002","AB-010","AB-011","AB-037"]` — **AB-037은 DRIFT-111에서 폐기**되어 카탈로그에 없다. `equip_skillbook_by_id`가 마스터 미발견 시 **조용히 무시**하므로 실제로 3권만 들어온다.
- gear 15종 하드코딩 — `gear_ward_dps_tide_censer` · `gear_ward_nuker_hex_scope` 누락 (카탈로그 27종 = 스타터 4 + 스페어 17 + armory set 6).
- **서브 카탈로그 49종 중 스태시 3종** → 교정한 스킬을 플테로 확인할 경로가 사실상 없다. 49종 접근은 샌드박스 `SANDBOX_SUBS` / `_BIND_FIXTURES`에만 존재.

> **재발 이력:** 동일한 "폐기 AB → 조용한 빈 슬롯" 사고가 DRIFT-130(샌드박스 `AB-009`) · DRIFT-137(스타터 `AB-028`) · DRIFT-139(스태시 `AB-037`) = **3회**. 130에서 코멘트 경고만 달고 게이트를 안 세운 대가.
>
> **해소:** 시드를 카탈로그 파생으로 바꾸고, `hub_smoke`에 **유령 참조 전수 감사**를 신설했다(현재 0건).

### 1d. 허브가 구식

[scenes/main.tscn](../../scenes/main.tscn) = 560×400 센터 패널 + 버튼 세로 스택. 제목이 아직 `"UI-005 Loadout (stub) · QA-030"`.
- **"Confirm Loadout" 스텁**([loadout_stub.gd](../../scripts/ui/inventory/loadout_stub.gd), 정체성 4개 나열만)을 눌러야 Deploy가 열린다 — 정체성이 gear에서 파생되는 현행 모델에서 무의미한 유물.
- `UI-005` §3.2가 요구하는 **건 모딩 패널**(시그니처 읽기전용 · Q/E/R · 결속 프리뷰 1줄 · archetype 필터 회색 · gear 교체 경고 모달) 부재. 장착은 스태시 팝업 안 `EquipPanel` 컬럼 2개.
- `hub_economy_panel`은 spec이 Deprecated로 못박은 분석 N=3 경제를 현역으로 구현 중.

---

## 2. 착수 전 해소해야 할 스펙 이슈 (3건)

### 2a. DPS 스타터 프리모딩 = `AB-028`(폐기) ✅ **해소 — `AB-053`으로 확정 (2026-08-12)**

`F-008` §3.10.2 「스타터 프리모딩」 4행 중 DPS만 실재하지 않는 AB를 가리켰다.

| class | spec §3.10.2 Q | 게임 |
|-------|----------------|------|
| Tank | `AB-033` | ✅ |
| **DPS** | **`AB-028`** | ❌ DRIFT-115에서 폐기(D4 → 채널링 클러스터 재정의) |
| Nuker | `AB-030` | ✅ |
| Healer | `AB-044` | ✅ |

**결정(사용자: "있는 것 중 적절한 걸로 맞춰") → `AB-053` 작열 폭발.** 발명이 아니라 이미 저작된 자리:

- [dps_binding_kit.md](../design/dps_binding_kit.md) §공유3서브 — 스타터 gear `gear_ward_dps_press_rod`의 **Q 슬롯**이 원래 `AB-053`.
- **`BIND-019`**(`press_rod` × `IDA-024` × `AB-053` @ slot 0)가 이미 등재 → **첫 런부터 「초월」 결속이 실제로 발동**. 스타터의 목적은 빈 서브 방지(`F-020` §3.2.0)만이 아니라 **결속 축을 처음부터 보여주는 것**이다.
- Basic tier · `sub_bands` = `{Nuker: B2}` → DPS 주력(패널티 0).

탈락: `AB-008`(구 게임 시드) = slot-0 결속 없음 → GENERIC 폴백만. `AB-010` = `BIND-031`은 있으나 DPS 전용 poison이라 「DPS = 애초에 광역」 원칙과 어긋남.

**반영:** [backpack.gd](../../scripts/autoload/backpack.gd) 스타터 시드 `AB-008` → `AB-053`. **DRIFT-137** 로깅 · **`OPS_30` 전파 완료**(spec `baf0806` · `DEC-20260812-004`) · 재핀 완료.

> impact_scan이 `AB-028`의 「허브 스타터」 주장 **7곳**을 추가로 잡았다 — 폐기(`DEC-20260807-001`) 당시 AB 문서에만 Deprecated를 찍고 스타터 참조는 남겨 뒀던 것. 같은 커밋에서 정리했다.

### 2b. 결속 해소 키 (D3) — 두 갈래, 하나는 spec 무변경

`F-020` §3.7 step 2~3 + Edge case가 현재 **"gear+identity 이중 매치"** 를 명시한다("Identity만 맞고 gear 불일치 시 델타 없음"). D3를 그대로 구현하면 이 조항과 어긋난다.

단, `D-019` §3에 **`bindingProfileId`** 필드가 이미 있다 — "master 기본값 오버라이드; 비어 있으면 master", `effectiveBindingProfileId = bindingProfileId ?? master.bindingProfileId ?? baseGearId`. 즉 spec은 **결속 키를 gear ID에 고정하지 않고 프로필로 간접화**해 두었다.

| 구현안 | 내용 | spec 이격 |
|--------|------|-----------|
| **(a)** identity_ab 직접 키 | 게이트 8종을 identity만 보도록 | `F-020` §3.7 step 2/3 + Edge 수정 필요 |
| **(b) 권장** | `effectiveBindingProfileId` **기본값을 `baseGearId` → `effectiveIdentitySkillId`** 로 바꾸고, `OVERLAYS` 매치를 `(profile, identity_ab, slot_ab, slot_index)` 로 | `D-019` §2/§3 기본값 1줄 + `F-020` §3.7 Edge 1줄 |

**(b) 권장 이유:** 런타임 거동은 D3와 동일하면서, ① 굴림 정체성과 자동 정합(프로필이 굴림 결과를 따라감) ② gear 아키타입 고유 변주가 필요하면 master가 `binding_profile_id`를 명시 오버라이드해 그대로 살릴 수 있음 ③ spec 이격이 "기본값 정의 1줄"로 축소됨. → **DRIFT-138 (rule, 전파 후보 — 번호 예약됨, M0b 구현 시 로깅)**.

### 2c. 스킬 트리 SSOT 포인터 오참조 ✅ **해소 (2026-08-12, spec 레포 수정 완료)**

spec 9곳이 스킬 트리 SSOT로 **`F-029` §3.6**을 가리켰으나, 그 절은 레거시 진행 스파인("2. `scriptorium` T1 → 분석. 3. `scribe_shop` T1 → Basic 상점")이다. 실제 트리 내용(`chapel` Tier 표 · `scribe_shop` Tier · 시설 역할 변경 · "분석 의뢰 UI 제거")은 **`F-029` §3.2a**(Phase 4b — 통합 금고 · 시설 개편)에 있다.

**수정:** `D-011`(1) · `F-008`(1) · `F-009`(5) · `F-020`(2) = **9건** `§3.6` → `§3.2a`. 규칙 변경이 아닌 포인터 정정이므로 `OPS_20` 급으로 처리. `spec_xref_check` 신규 지적 0. **`DecisionLog`의 2건은 이력이라 보존.**

> spec 레포(`E:/Game_design/project_tdc_spec` `staging`)에서 직접 수정했다 — 게임 레포는 spec md를 편집하지 않는다([AGENTS.md](../../AGENTS.md)). `DEC-20260812-004` 커밋에 포함(`baf0806`).

---

## 3. 마일스톤 순서

```
M0  데이터 위생 + 게이트 ─┐ ✅ 완료 (2026-08-12)
M0b 결속 키 교정        ─┴─→ ★ **플레이테스트 1차 게이트 도달** (구 장착 모델)
                              │
M1 마석 ✅ ┬ M2 참 ✅ ┐          │
         └─────────┴─→ M3 트리 ─→ M4 금고 + gear 슬롯 귀속·소멸 + 건 모딩 UI
                                        │
                                        └─→ M5 F-009·affix 폐기 + 세이브 마이그레이션
                                                  │
                                                  └─→ M6 허브 화면 재구성 ─→ M7 잭팟(선택)
```

- **M0/M0b는 나머지와 독립**이며 저위험이다. 여기까지만 끝내도 **서브 49종 · gear 19종을 전부 체감하는 플레이테스트**가 성립한다(장착 모델은 구형이지만 스킬 교정 검증에는 충분).
- **M3(트리)가 M4(소멸 모델)보다 먼저**여야 한다 — D2 소멸이 재구매 경로 없이 들어가면 스킬을 잃기만 한다.
- **M5(폐기)는 M1~M4가 대체재를 전부 세운 뒤에만**. 순서를 뒤집으면 "그라인드만 남는" 공백(I-007 §15가 경고한 순서).

---

## 4. 마일스톤 상세

### M0 — 데이터 위생 + 조용한 실패 게이트 ✅ **완료 (2026-08-12 · DRIFT-139)**

| # | 작업 | 파일 |
|---|------|------|
| M0-1 | `_seed()` gear 하드코딩 15종 → `Slice01Data`에서 파생(스타터·armory set 제외 전량 = 17종) | [stash.gd](../../scripts/autoload/stash.gd) |
| M0-2 | 시드 skillbooks에서 폐기 `AB-037` 제거 → **전 카탈로그 49종 시드**(D4) | 동일 |
| M0-3 | `equip_skillbook_by_id` 마스터 미발견 시 `push_warning` — 조용한 무시 금지 | [party_member.gd:356](../../scripts/party/party_member.gd) |
| M0-4 | **시드/픽스처 전수 검증 게이트**: `Stash._seed` · `Backpack._seed` · `SANDBOX_SUBS` · `_BIND_FIXTURES` 의 모든 AB/gear ID가 카탈로그에 실재하는지 부팅 시 검증 | [tools/hub_smoke.gd](../../tools/hub_smoke.gd) |
| M0-5 | `_BIND_FIXTURES` ↔ `OVERLAYS` 정합 게이트: 픽스처의 `(gear, identity, sub, slot)`이 실제로 결속을 활성화하는지 | [tools/binding_smoke.gd](../../tools/binding_smoke.gd) |
| M0-6 | stash T0 capacity 20 게이트 — 전 카탈로그 시드와 충돌. 플테 동안 우회 플래그 + 별도 추적 | [stash.gd](../../scripts/autoload/stash.gd) · [facilities_tiers.json](../../data/slice01/facilities_tiers.json) |

**DoD:** 시드/픽스처에 유령 ID 0건이 스모크로 보증되고, 스태시에서 gear 17종 · 서브 49종을 꺼내 장착할 수 있다. `ci_smoke.sh` green.

**로깅:** M0-6 capacity 우회 = `DRIFT-###` (impl/tuning, 로깅만) · M0-3/4/5 = `IMPL-DEC-20260812-###`.

---

### M0b — 결속 해소 키 교정 ✅ **완료 (2026-08-12 · DRIFT-138)**

| # | 작업 | 파일 |
|---|------|------|
| M0b-1 | §2b **(b)안** 적용 — `effective_binding_profile_id` 헬퍼 신설(기본값 = effective identity, master `binding_profile_id`가 있으면 오버라이드) | [binding_overlays.gd](../../scripts/combat/abilities/bindings/binding_overlays.gd) |
| M0b-2 | `OVERLAYS` 엔트리의 `gear` 필드 → `profile`로 이행 + 게이트 8종 · `signature_for` · `resolve` / `resolve_effective` 전부 profile 기준으로 | 동일 |
| M0b-3 | ✅ **완료(2026-08-13, DRIFT-140)** — `IDA-022` 「진격」(변위 → 밀림 재차 밀면 Rooted) · `IDA-052` 「응보」(피격 누적 → 링크 서브가 방출)를 `SIGNATURE`+`GENERIC`에 등재. Tank 4정체성 축 완성. 부수로 `signature_for`/테마 게이트 7종을 `_has_covenant`/`_has_theme` 공용 술어로 통합(변주 미저작 정체성이 규약을 잃던 구 gear-키 잔재 제거) | 동일 |
| M0b-4 | 호출부 시그니처 갱신 — `ability_dispatch` · 툴팁(`skill_text`/`equip_panel`) · 조준 사거리 게이트 | [ability_dispatch.gd](../../scripts/combat/abilities/ability_dispatch.gd) 외 |
| M0b-5 | 스모크: 19종 gear × 자기 정체성 → 시그니처 활성 전수 확인 | [tools/binding_smoke.gd](../../tools/binding_smoke.gd) |

**DoD:** 스태시 gear 19종 전부가 자기 정체성 규약대로 작동. 굴림 정체성(rolled)이 bundled와 달라도 시그니처가 따라간다. 기존 8쌍의 gear 고유 변주는 회귀 없음.

**로깅:** **DRIFT-138** (rule, `PENDING-PROP` — 번호 예약됨) — `D-019` §2/§3 `bindingProfileId` 기본값 + `F-020` §3.7 Edge case. M0b 완료 후 `OPS_30` 전파 → 재핀.

> ★ **여기서 플레이테스트 1차 게이트.** 스킬 교정 결과 검증은 이 시점에 가능하다. M1 이후는 경제 교체이므로 플테 피드백을 받고 진행하는 편이 낫다.

---

### M1 — 마석 (manastone) ✅ **완료 (2026-08-13 · DRIFT-144)**

> 비용 = **스킬 tier 차등**(Basic 1 / Advanced 2 / Master 3 · 사용자 결정 (나)). `charges`는 **유지**(폐기는 M5) — 마석은 그 위에 얹은 게이트라 틀리면 꺼서 되돌린다. 샌드박스는 무제한(∞).

- 슬롯 스킬 시전 = **마석 1 소모**. Identity = 무소모/극저(`I-007` §6, NC 3인 고갈 방지).
- 드롭: 일반 적 → 약한 마석 / 3세력 → 강한 마석. 정산: 런 At Risk → 탈출 → stash(`F-007` §3.7.3a, 기존 골격 재사용).
- 고갈 = **의도된 고역**(소프트락 아님) — 시전 거부 + UI 경고.
- **과도기:** `charges`를 마석 카운터로 재해석 가능(`F-009` §3.8 "charges 병행"). 완전 분리는 M5.
- 신규 데이터: `manastones.json`(tier → 드롭/가격) + `id_registry` 등록.

**DoD:** 슬롯 스킬이 마석을 소모하고, 마석이 드롭·정산·stash되며, 0에서 시전이 거부된다.

### M2 — 참 (charm) ✅ **완료 (2026-08-13 · DRIFT-146)**

> 5종 · 비스택(칸 = 대가) · 인벤 소유 → 파티 전원 push. spec `CHARM-PROTO-001`(Voltaic 저항)은 게임에 원소 저항 축이 없어 **평타 속도로 대체**.

- 런 인벤 그리드 점유 오오라 5종(`F-010` §3.11 `CHARM-PROTO-001~005`). 액티브 아님 — stat-only.
- 들고 있을 때만 적용(칸 vs 파워 긴장). At Risk → 탈출 → stash.
- **교차:** 현재 gear roll(dmg/cd/potency band)이 담당하던 stat 축을 참으로 이전 — M5의 affix 폐기가 공백 없이 되려면 M2가 선행이어야 한다.

**DoD:** 참 5종이 인벤을 점유하고 오오라를 적용·정산하며, stat 축이 참으로 표현된다.

### M3 — 스킬 트리 ✅ **완료 (2026-08-14 · DRIFT-150)**

> 노드 4종(Slot/Unlock/Upgrade/Doctrine) · 해금 상태 = `HubProfile`(전임 `shop_listing_unlocked` 옆) · `hub_tree_panel` 신설로 **CS-2 잔여 doctrine 구매 경로 해소**. `Slot`→`gear_skill_slot_count` 배선은 **M4**.

- 노드 4종: **Unlock**(모딩/구매 허용) · **Upgrade**(행동 발전) · **Passive** · **Slot**(`gear_skill_slot_count` +1).
- 소비: `hubVault` Shared 재료 · `haul_*` · (선택) `ward_scrap` — sink 경쟁.
- UI: `chapel` T1+ 패널. **분석 의뢰 UI 제거**(`F-029` L100 — 트리 노드 클릭 = 해금).
- **선행:** §2c 스펙 포인터 교정.
- **D4 적용:** 플테 프로필은 전 노드 해금 상태로 시드.

**DoD:** 허브 트리에서 스킬을 해금·업그레이드하고 슬롯 수를 늘릴 수 있으며, 던전 진입 전 빌드 계획이 성립한다.

### M4 — 금고 통합 + gear 슬롯 귀속·소멸 + **건 모딩 UI** ✅ **완료 (2026-08-20 · DRIFT-151)**  ← 요청하신 핵심 UX

**데이터**

| # | 작업 | 파일 |
|---|------|------|
| M4-1 | `skillbooks.json` 49종에 **`skill_family`** 파생 — spec AB md frontmatter `skillFamily`(Control/Ranged/Melee/Mobility/Debuff/Utility/…)가 SSOT | [skillbooks.json](../../data/slice01/skillbooks.json) |
| M4-2 | `gear.json` 마스터에 **`allowed_slot_families[]`** · **`gear_skill_slot_count_max`**(스타터 1, 기본 3) 추가 (`D-019` §2) | [gear.json](../../data/slice01/gear.json) |
| M4-3 | gear **인스턴스**에 `equipped_slot_abilities[3]` · `gear_skill_slot_count` 추가 (`D-019` §3) | [stash.gd](../../scripts/autoload/stash.gd) · [backpack.gd](../../scripts/autoload/backpack.gd) |
| M4-4 | 세이브 마이그레이션: `Backpack.equipped[member].subs` → 그 멤버가 착용 중인 gear 인스턴스의 슬롯으로 이관 | [backpack.gd](../../scripts/autoload/backpack.gd) |

**코드**

| # | 작업 | 파일 |
|---|------|------|
| M4-5 | `_bind_gear`가 gear 인스턴스에서 슬롯 AB를 적재 — `skillbook_slots`는 gear 파생 뷰로 축소 | [party_member.gd](../../scripts/party/party_member.gd) |
| M4-6 | **D2 소멸:** `equip_gear`로 gear가 교체되면 이전 인스턴스의 슬롯 AB 소멸. 확인 모달 통과 후에만 | [party_member.gd](../../scripts/party/party_member.gd) · 모딩 패널 |
| M4-7 | 장착 게이트에 `allowed_slot_families` + `gear_skill_slot_count` 추가(기존 Role Gate 위에) | [party_member.gd:323](../../scripts/party/party_member.gd) |
| M4-8 | Shared 적 AB 처치 → 재구현 재료 드롭 → 금고(D-029 haul과 탭 통합). per-kill 스킬북 드롭 폐지 | [loot_service.gd](../../scripts/run/loot_service.gd) · [hub_profile.gd](../../scripts/autoload/hub_profile.gd) |

**UI — `UI-005` §3.2 6개 영역**

신규 `scripts/ui/hub_modding_panel.gd`:

| 영역 | 내용 |
|------|------|
| 시그니처 | Identity `IDA-###` + 평타 `ba_*` — **읽기 전용**(gear 핀) |
| Q/E/R 슬롯 | 해금된 `base_ability_id` 드래그 장착 · 미해금은 잠금 + 트리 링크 |
| 결속 프리뷰 | 활성 `BIND-###` **1줄 요약** — `BindingOverlays.resolve_effective` (M0b 선행이라 대부분 채워짐) |
| archetype 필터 | `allowed_slot_families` 위반 AB 회색 · Role 불일치 회색 |
| gear 교체 확인 | **슬롯 AB 소멸 경고 모달**(D2) |
| 마석·참 | 반입 요약 — gear Risk 뱃지 없음 |

`equip_panel`의 SUB 컬럼은 제거하고 모딩 패널 진입점으로 축소한다. **스태시 팝업의 중앙 드래그 라우터([inventory_ui.gd](../../scripts/ui/inventory/inventory_ui.gd) `_drop`/`_update_drag`/`_revert_drag`)는 건드리지 않는다** — 회귀 위험 대비 이득이 없다.

**DoD:** 허브에서 gear를 골라 Q/E/R에 스킬을 끼우고, 결속 1줄이 그 자리에서 보이며, gear를 갈아끼우면 경고 후 슬롯이 소멸하고 트리/상점에서 재획득할 수 있다. 처치 → 재료 → 금고 → 해금 루프가 돈다. ✅ 전부 충족(`ci_smoke` 12/12).

> **M4 결과 요약** — 슬롯 소유자가 멤버 → **gear 인스턴스**로 이관(`slot_abilities[3]`), 열린 칸 = `clamp(1 + smithy + 트리 Slot, 1, gear max)`, D2 소멸을 영속·런타임 **양층**에 배선, per-kill 스킬북 → **공유 재료**(`haul_shared_shard`/`haul_shared_core`) 대체, `hub_modding_panel` 신설(6영역).
> **판정 4건 → ✅ 전파 완료** (spec `890bf73` · `DEC-20260820-001` · 재핀 완료). ⓐ는 판정이 아니라 **구현의 이중 계산**이었고(`F-008` §3.10 사다리 오독) 착수 중 자체 해소. ⓑ 공유 재료 id · ⓒ `gearSkillSlotCount` → `derived` · ⓓ 루트 노드 금지 + 노드 카탈로그 구현 소유 = SSOT 반영. 상세 = [SPEC_DRIFT DRIFT-151](../SPEC_DRIFT.md).
> **드래그 → 클릭 배치로 변경** — 스태시 드래그 라우터 불가침 제약과 상충. 기능 동치 + 거부 사유 표기 가능.

### M5 — F-009 폐기 + affix 폐기 ✅ **완료 (2026-08-20 · DRIFT-152)**  *(파괴적)*

- `hub_economy_panel`의 분석·상점·스킬북 인스턴스·`charges`·per-kill 드롭 **제거**.
- gear 롤테이블 affix(dmg/cd/potency) 폐기 또는 극소화(`F-008` §3.10.1 — Shop ±2% / Dungeon ±5% 상한 검토). 빌드 변주는 `rolled_identity_skill_id` + 결속으로.
- **세이브 마이그레이션:** 기존 스킬북/affix 인스턴스 → 마석·참·재료로 변환 또는 만료.
- `D-018` Frozen 처리(§9 마이그레이션 가이드).

**DoD:** 구 경제 코드·데이터 제거, 기존 세이브가 손실 없이 마이그레이션, `ci_smoke` · `hub_smoke` green. ✅ 충족.

> **M5 결과 요약** — 탄(charges)·스킬북 affix·분석 N=3·생본 구매·중복 sink·per-kill 스킬북·`affix_roller` 전부 제거. 스킬북은 **물건이 아니게 됐다**(생산자·저장소·소비자 일괄 철거). gear 굴림 ±10% → **±5%**(`F-008` §3.10.1 극소화). 신설 = **모딩 시술비**(`HubProfile.mod_install`) — 트리 해금은 허가이고 새기는 데는 매번 값을 치른다(이게 없으면 D2 소멸이 무의미).
> **착수 전 대조에서 하드 블로커 2건**: ① 트리 `Unlock` 5종 → **63종(역할×AB 전수)** 확장 안 하면 44 AB 영구 잠김. ② `F-008` §3.10.2 **스타터 프리모딩** 미구현 → 첫 런 슬롯 전멸. 둘 다 `D-018` §9 마이그레이션 지침 **밖**이었다.
> **🐞 탄이 아직 실제 게이트였다** — DRIFT-145는 표시만 내렸고 소비·고갈 게이트 4곳이 살아 **보이지 않는 두 번째 자원**으로 남아 있었다.
> **`PENDING-PROP` → ✅ 전파 완료** (spec `16031d3` · `DEC-20260820-002`). 시술비는 스펙 의도(`I-007` §14.2 「스킬 세트 재조립 비용」) 그대로였고, 전파된 것은 **「재구매」의 실체**(살 물건이 없으므로 값은 시공에 붙는다) + 부수 4건.

### M6 — 허브 화면 재구성 ✅ **완료 (2026-08-20 · DRIFT-153)** (`UI-005` §3 / `UI-029`)

- [main.tscn](../../scenes/main.tscn) 스텁 → 풀스크린 허브: **좌** 파티 4인 카드(기어·시그니처·Q/E/R 요약) / **중** 모딩·스태시 / **우** 포메이션·난이도·출정 / **상단** 시설·트리·상점·퀘스트·재화.
- **"Confirm Loadout" 게이트 제거** — 기어=정체성 동기화라 무의미. 대신 **첫 런 ≥1 슬롯 게이트**(`F-020` §3.2.0, `UI-005` §3), 이후 런은 빈 슬롯 경고(비차단).
- 포메이션 에디터는 `UI-005` §3.1(히트박스 스케일 토큰 · `party_range_m` 8.0m 원형 클램프 · 비중첩)로 승격 검토 — **별건 가능**.

**DoD:** 허브 한 화면에서 기어·모딩·트리·포메이션·출정이 모두 처리되고, 스텁 유물이 사라진다. ✅ 충족(난이도는 폐기 — 아래).

> **M6 결과 요약** — 테이블 → **마을 화면**(다키스트던전 햄릿식). 건물 = `F-029` 시설 그대로, 좌표는 `map_pos`가 소유(아트 교체 시 코드 불변), 미건립은 **폐허**. 파티 스트립은 **건 이름만** + 마우스 오버 툴팁(정체성 규약·Q/E/R·결속).
> **기능 기준 건물 재편** — 대장간(모딩+**슬롯 확장**) · 필기상점(**해금·강화**, 필기소 흡수) · 성소(**doctrine 전담**) · 무기고(gear) · 군수(보급) · 창고 · **성문**(포메이션·출정). `Slot` 사다리가 대장간으로 돌아가 「사는 곳 = 조건인 건물」이 됐다.
> **건물 안 UX** — 대장간 Q/E/R **3칸 타일** + 계열 필터 + **「고르기 → 결속 미리보기 → 확정」**(시술비는 되돌릴 수 없다). 필기상점 63노드를 **계열로 접고** `Upgrade`를 `Unlock` 아래 들여쓰기.
> **난이도 폐기** — UI만 제거(데이터·폴백 보존). 파급으로 `Q-HUB-020`을 **고정 보스**(`force_overrides` `P-BOSS-01`)로 재게이트.
> **판정 6건 → ✅ 전파 완료** (spec `660706e` · `DEC-20260821-001` · 재핀 완료). 트리 3건물 분산 · `scriptorium` 폐기(8→7) · 폐허 표시 · 난이도/고정보스 · **의뢰 수락 게이트** · **창고 시드 스타터만 + `armory` 4역할 불변식**(`F-029` OQ-4 해소). 상세 = [SPEC_DRIFT DRIFT-153](../SPEC_DRIFT.md).

### M7 — 잭팟 레이어  *(선택)*

마석 티어(`ms_weak`~`ms_prime`, Prime=던전 전용·상점 미판매) · 3세력 강한 마석 + 저확률 Identity gear · 결속 **공명 충전**(금고 재료 sink, BiS 고착 방어). `F-009` §3.9.5 · `F-008` §3.10.3.

---

## 5. 스펙 역전파 대상 (`OPS_30`)

| # | 내용 | 대상 SSOT | 상태 |
|---|------|-----------|------|
| 1 | **DRIFT-137** DPS 스타터 프리모딩 `AB-028`(폐기) → **`AB-053`** | `F-008` · `F-009` · `F-020` · `D-012` · `ROLE-020` · `CombatContentMap` · `AB-028`/`AB-053` | ✅ **전파 완료** — spec `baf0806` · `DEC-20260812-004` · 재핀 완료 |
| 2 | **DRIFT-138** 결속 프로필 기본값 `baseGearId` → `effectiveIdentitySkillId` | `D-019` §2/§3/§3.1/§10 · `F-020` §3.7 · `F-008` §3.9 · `ROLE-010` §4.5 | ✅ **전파 완료** — spec `66a3dda` · `DEC-20260813-001` · 재핀 완료 |
| 3 | 스킬 트리 포인터 `F-029` §3.6 → **§3.2a** (9건) | `D-011` · `F-008` · `F-009`×5 · `F-020`×2 | ✅ **전파 완료** (같은 커밋, `OPS_20` 급 부수 정정) |
| 4 | **DRIFT-140** IDA-022 「진격」 · IDA-052 「응보」 규약 신설 | `ROLE-010` §4.5 · `IDA-022`/`IDA-052` §Identity Keystone | ✅ **전파 완료** — 같은 커밋 |
| 5 | **DRIFT-151** 슬롯 사다리 단일 축 · 공유 재료 id · `gearSkillSlotCount` 파생 · 루트 노드 금지 | `F-008` §3.10 · `F-009` §3.9.2 · `F-020` §3.10 · `F-029` `smithy` · `D-019` §3 · `D-029` §3 | ✅ **전파 완료** — spec `890bf73` · `DEC-20260820-001` · 재핀 완료 |
| 7 | **DRIFT-153** 마을 화면 · 건물 재편(`scriptorium` 폐기) · 트리 3건물 분산 · 의뢰 수락 게이트 · 난이도 폐기/고정 보스 · 창고 시드 스타터만 | `F-008` §3.7 · `F-009` · `F-020` §3.10 · `F-029` §3.3/§3.5 · `D-029` · `UI-029` | ✅ **전파 완료** — spec `660706e` · `DEC-20260821-001` · 재핀 완료 |
| 6 | **DRIFT-152** `modInstallFee` 정본화 + 스킬북 무출처 · 굴림 극소화 확정 · `D-018` §9 두 구멍 · `Unlock` 전수 커버 불변식 | `F-008` §3.10/§3.10.1 · `F-009` §3.9.2/§3.9.3 · `F-020` §3.10 · `D-018` §9 | ✅ **전파 완료** — spec `16031d3` · `DEC-20260820-002` · 재핀 완료 |

**게임 레포는 spec md를 편집하지 않는다** — spec 레포(`staging`)에서 `OPS_30` 실행 후 `spec_ref.json` 재핀. ([AGENTS.md](../../AGENTS.md) §Spec drift & propagation)

---

## 6. 미결 (착수 시 확정 — 사용자 결정)

| # | 항목 | 걸린 마일스톤 |
|---|------|---------------|
| ~~U1~~ | ~~DPS 스타터 슬롯 AB~~ → ✅ **`AB-053` 확정** (§2a, 2026-08-12) | — |
| ~~U2~~ | ~~IDA-022 · IDA-052 규약~~ → ✅ **「진격」(변위) · 「응보」(피격 누적) 신설** (DRIFT-140, 2026-08-13). `BIND-###` 변주는 미저작 = 플테 후 | — |
| U3 | `skill_family` 분류 — spec frontmatter 그대로 vs 게임 재분류 | M4-1 |
| U4 | `allowed_slot_families` — gear archetype별 허용 family 표 | M4-2 |
| U5 | 참 5종 수치 · 스택 상한 · stash 용량 관계 (`I-007` §14.7 OQ) | M2 |
| U6 | 스킬 트리 단위 — 클래스 / gear archetype / Identity 분기 (`I-007` §14.7 OQ) | M3 |
| U7 | 상점 스킬 재구매 가격·티어·트리 선행 조건 | M4 |

---

## 6.5 성장 개편 이관 (spec `d1bc78b` · `DEC-20260813-003/004/005`)

> 목차 = spec `docs/context/DoctrineGrowth_WorkPlan.md`. **CS-1 → CS-2 → CS-3 순서 고정**(CS-1이 참·Passive 경계를 정리해야 CS-2가 doctrine 조건을 이중 기술하지 않는다).

| CS | 범위 | 상태 |
|----|------|------|
| **CS-1** | Passive 폐기 · 참 일원화 · 조건부 참 | ✅ **완료** (DRIFT-147). 게임에 Passive가 애초에 없어 9항 중 1-1~1-4 무작업. 판정 3건 반영 |
| **CS-2** | `F-030` doctrine 골격 + Trait 런타임 | ✅ **완료** (DRIFT-148). 스키마·검증·프로필·chapel·**Trait 발동**(3 payoff) + QA-032 §2.1 게이트 CI 편입 |
| **CS-3** | `F-005` §3.3a NC 변조 + Tank 파일럿 | ⏸ **미착수** — `NcModulation` 8단계 훅 · fixture 이원화 |

**CS-2 잔여(CS-3 전 무관):** chapel 트리 **구매 UI**(`hub_facilities_panel`) · `mandatorySwaps` doctrine 태그(`F-024` §3.2.1a).

**🚨 CS-3 착수 조건:** `tools/nc_baseline_smoke.gd`가 이미 CI에 있다. CS-3이 `doctrine_modulate` 훅을 넣는 **순간부터** 그 게이트의 카운터가 실물이 되고 doctrine 0에서 **호출 0 + 항등 통과**를 강제한다. 깨지면 doctrine 전체 롤백(`F-030` §3.7 R2).

---

## 7. 다음 액션

1. ✅ **M0 + M0b 완료** (2026-08-12) — ★ 플레이테스트 1차 게이트 도달. 스태시에서 gear 17종 · 서브 49종을 꺼내 쓸 수 있고, 어느 gear를 껴도 그 정체성 규약이 작동한다.
2. **플레이테스트** → 피드백 수령 후 M1(마석) 착수 여부 재판단.
3. ✅ **DRIFT-138 · 140 전파 완료**(`DEC-20260813-001`, spec `66a3dda`) — 재핀 완료. **PENDING-PROP 없음.**
4. **플테 관찰 대상(신규):** 「진격」 밀어내기가 라인 정리로 읽히는지(캡스톤 = 밀린 뒤 그 자리 속박) · 「응보」 누적이 태세 안에서 터뜨릴 만큼 모이는지 · `IDA-052` 둔화 0.45가 「굼떠지되 움직인다」로 체감되는지. `BIND-###` 변주와 수치(`MARCH`/`RETRIB`/`move_slow`)는 그 결과로 결정.
5. **표시명** — 기어 27종 한글 재명명 완료(DRIFT-142). 정체성 10종은 기존 한글명 유지.

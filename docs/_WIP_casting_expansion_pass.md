# _WIP — I-006 캐스팅 확장 패스 (스킬별 핑퐁 검증)

> **임시 작업 문서.** 패스 완료 후 **삭제**한다. SSOT 아님 — 결정은 `SPEC_DRIFT.md`(DRIFT-078)로 남는다.
> **모델 분업:** 방법·표 = Opus 작성(이 파일). **실제 스킬별 핑퐁 = Sonnet 세션이 이 파일을 열어 §2 루프를 구동.**
> **작성:** 2026-07-09 · spec pin `2bf37b2` · 게임 `main`.

---

## 0. 목적

`I-006` 캐스터 원칙(`D-016` §3.6 line 207 / 게임 DRIFT-075): **Nuker·DPS·Healer 슬롯 스킬 = 캐스트/채널 중심**, 즉발(A)은 최소·강패널티. 현재 캐스터 서브 51종 중 ~29종이 아직 즉발. 이를 **스킬 하나씩 샌드박스에서 체감·수정**하며 캐스트/방향/효과/바인딩을 정합시킨다. **일괄 편집 금지**(완성도 저하) — AB당 의식적 판정.

**핵심 제약(사용자 결정):**
- **수치 밸런싱(스킬 간 딜/쿨 상대값)은 이번 패스 스킵.** 명백히 깨진 효과·방향만 손봄.
- **대부분 서브가 Shared** → AB당 **적-시전 + 아군-시전 동시 판정**(K1 대칭).
- **판정-1회:** 같은 AB가 여러 ENC에 겹치면 **첫 등장 ENC에서만** 판정.

---

## 1. 참조

- 원칙: spec `D-016` §3.6 / §3.6.1(적 telegraph 밴드) / §3.6.2(아군 B 파일럿) · `I-006` §2.2 티어 · `I-007` §15 P3.
- 게임 라우팅: [ability_dispatch.gd](combat/../../scripts/combat/abilities/ability_dispatch.gd) `cast_skillbook` — `cast_s>0`만 캐스트바 경로([skill_cast.gd](../scripts/combat/abilities/effects/skill_cast.gd)). 결속 델타는 **캐스트 완료 시점** 발현(`_resolve_sub`→`_apply_binding`).
- effect 구현: `scripts/combat/abilities/effects/sb_*.gd`.
- ⚠️ `castTier`/`rootDuringCast`/`telegraph_s`는 **아군 측 죽은 스키마**([slice01_data.gd](../scripts/autoload/slice01_data.gd) L551 "DEFERRED"). 아군 캐스트는 **오직 `cast_s`**가 구동.

### 시전 티어 밴드 (가이드 — 초는 튜닝, 2026-07-09 상향 재조정)
| 티어 | 길이 | 역할 |
|------|------|------|
| **A** | 0~0.4s(즉발) | 연사 필러·이동·인터럽트·침묵·시야·Identity |
| **B** | 3~5s | 딜러·누커 캐스트, 힐러 캐스트힐(중형) |
| **C** | 8~15s | 궁극기급 — 반드시 회피/보호해야 하는 대형 스킬 |

⚠️ B/C는 **딜러·누커 공격형 + 힐러 캐스트힐**로 확인된 밴드. Tank·그 외 유틸 서브(버프·실드·CC 등)는 아직 이 상향의 대상이 아님 — 등장 시 별도 판단.
캐스트가 자체 쿨다운을 넘어서면(캐스트 중엔 쿨이 의미 없어짐) **쿨다운도 같이 상향**(AB-003 사례).

### 이미 완료(cast_s 有) — **표에서 생략**
`AB-003`(3.0, cd6) · `AB-004`(4.0) · `AB-041`(3.5) · `AB-053`(3.0) · `AB-059`(5.0) · `AB-064`(3.0) · `AB-066`(10.0, C 궁극기) · `AB-054`(빔 채널, 미변경).
⚠️ `AB-028`·`AB-045`는 **미완료**(castTier/root만 있고 cast_s 없음 → 실제 즉발). 등장 시 판정 대상.

---

## 2. 스킬별 핑퐁 루프 (Sonnet 구동)

각 스킬 1개당 다음을 반복. **컨펌 전 편집은 사용자 승인 후에만.**

### 2.1 판정 축 (무엇을 수정하나)
1. **효과** — `sb_*.gd` 거동이 의도대로인가.
2. **방향성** — 역할 부합(`I-006` §2.3: Identity≠주딜, 서브=적재적소 수단).
3. **시전 모드** — `A 유지` / `cast_s=X`(짧은캐스트·긴차지) / `채널`. → `skillbooks.json` `cast.cast_s`.
4. **바인딩** — 정체성 결속 델타와 상호작용 정상(캐스트 완료 시 발현).
5. ~~수치 밸런싱~~ — **스킵**(명백한 파손만).

### 2.2 체감 스테이지
**Shared 스킬(적도 사용):**
- **A. 허수아비** — 아군으로 시전 → 사용감·방향성·효과 1차 수정. (`허수아비 소환` 버튼, 누적딜/어그로 표기)
- **B. 적 1종 소환** — 그 AB를 쓰는 적을 소환해 **맞아봄** → 적-시전 telegraph 감각 → **대칭 판단**(적 telegraph_s ↔ 아군 cast_s).
- **C. 관련 ENC 소환** — 실전 교전에서 최종 확인.

**Ally-only 스킬(적 안 씀):**
- **A. 허수아비** → **C. 들고 갈 ENC**에 반입해 확인. (B 없음)

### 2.3 컨펌 → 기록
4축 OK (+Shared면 대칭 기록) → **§4 원장에 행 추가 + DRIFT-078 갱신** → 다음 스킬.
- 편집 = 데이터/이펙트 → 게이트 `GODOT=... bash tools/ci_smoke.sh` **7/7 PASS** 확인.
- **규칙·필드·enum 변경이 필요해지면 STOP** → OPS_30 전파 제안(사용자 승인). 그 외는 DRIFT 로깅만.

### 2.4 ENC 완료 → 이터레이션
ENC 내 모든 스킬 컨펌 → §5 진행표 체크 → **다음 ENC**.

### 2.5 결속 링크 제안 (축4 보강 — Shared/Ally-only 전용)

Shared 서브(적도 드롭) 또는 Ally-only 서브는, 장착 가능한 **각 클래스**마다 이미 확립된 **2개 정체성**(`binding_fixtures.gd` SIGNATURE)이 있다. 스킬별 판정 시 축4(바인딩)에서 다음을 함께 제안·기록한다:

1. `equip_classes`로 장착 가능 클래스를 확인.
2. 그 클래스(들)의 두 정체성 각각에 대해 "이 서브가 그 규약(delta)에 자연스럽게 들어맞는가"를 판단.
3. delta가 **generic**(코드 변경 없이 `OVERLAYS`에 항목만 추가하면 동작)인지, **kind별 분기가 필요한 special-case**(`overdrive_charge`의 화상/견인/빙결처럼 `ability_dispatch.gd`에 새 코드가 있어야 함)인지 구분.
4. 이 절은 **제안 기록만** — 실제 `OVERLAYS` 등록이나 신규 kind 분기 코드는 스킬별 컨펌 후 별도 승인(§8 Stop-line).

**클래스별 정체성 참조표:**
| 클래스 | 정체성 A (delta) | 정체성 B (delta) |
|--------|-------------------|-------------------|
| Tank | IDA-020 방벽충전(`bulwark_charge`, generic) | IDA-021 표식(`beacon_mark`/`beacon_mark_refresh`, generic) |
| Nuker | IDA-025 집중(`focus_stack`/`focus_spread`, generic) | IDA-029 잠행(`flank_strike`/`flank_dash`, generic — melee 강제 + range_band 비례 보상) |
| Healer | IDA-031 지속치유(`dot_heal`, generic — 치유 choke단 처리) | IDA-026 성역(`sanct`, generic — 치유 choke단 처리) |
| DPS | IDA-024 초월(`overdrive_charge`, **kind별 분기 필요** — 현재 fire/cold/beam만 구현. 미구현 kind는 게이지는 쌓여도 발동 시 무효과) | IDA-027 혈풍(`blood_soak`, generic 기본 흡수 + beam/cold만 특수 변형) |

#### AB-002 Shield Bash (Tank 전용) 결속 제안
`equip_classes`: Tank만 → Tank의 두 정체성 모두 대상. 둘 다 generic delta라 코드 추가 없이 `OVERLAYS` 등록만으로 동작.
- **Anchor 방벽충전(IDA-020):** "전선을 지키는 스킬"에 정확히 부합 — 캐스트마다 방벽 +1. 지금 이 킷은 AB-033/034/035(Q/E/R) 3종이 이미 채우고 있어, AB-002를 넣으려면 셋 중 하나를 교체하거나 로드아웃을 재구성해야 함. 넓은 반경(8m)·저딜(×1.0)이라 "맞히는 것보다 휘두르는 것 자체"가 방벽 소스가 되는 스팸형 슬롯과 궁합이 좋음.
- **Beacon 표식(IDA-021):** 표식 대상에 추가 위협 — AB-002가 광역이라 표식 대상이 얻어맞을 확률이 높아 "표식 유지용 광역 어그로 핑거" 역할에 적합. R(`beacon_mark_refresh`, 갱신형)보다는 Q/E급 단순 `beacon_mark`가 자연스러움.

#### AB-003 Arc Bolt Volley (DPS·Nuker 겸용) 결속 제안
`equip_classes`: DPS(main) + Nuker(sub, B1) → 4개 정체성 전부 후보.
- **Nuker 집중(IDA-025, `focus_stack`):** 같은 kind(`skillbook_bolt`)인 AB-004가 이미 이 델타로 등록돼 있어 동일 패턴으로 자연스럽게 낌(명중 시 집중 대상 지정+누적 추가타). Generic, 코드 변경 없음.
- **Nuker 잠행(IDA-029, `flank_strike`):** `range_band`="Mid"라 근접화 보상은 중간 수준(`band_dmg.Mid`=0.25, `band_cd.Mid`=0.10) — AB-060(Mid)과 동급 취급 가능. Generic, 코드 변경 없음.
- **DPS 초월(IDA-024, `overdrive_charge`):** ✅ **결정 + 구현 완료 — 감전 폭주(Silence).** `_dps_overdrive_empower`(`ability_dispatch.gd`)에 `skillbook_bolt` 분기 추가: 초월 중 명중한 적을 `apply_silence(bolt_silence_s=2.0)`로 침묵(AB-044 Hush Ward와 동일 API 재사용, 신규 상태 없음). `OVERLAYS`에 `BIND-PILOT-026`(`gear_ward_dps_press_rod` + IDA-024 + AB-003 @ slot0, AB-053과 슬롯 공유 — 둘 중 하나로 장착 가능) 등록. (기각안: Vulnerable 부여 / 연쇄 감전 / 관통형 — 침묵이 "몰아치는 버스트 창 + 상대 액션 봉쇄"로 더 강한 차별점이라 선택.)
- **DPS 혈풍(IDA-027, `blood_soak`):** kind가 `_`(default) 분기(흡수 폭발)로 이미 커버됨 — AB-053과 동일 취급. Generic, 코드 변경 없음.

---

## 3. 샌드박스 퀵레퍼런스

`scenes/dev/combat_sandbox.tscn` 실행.
- **스킬 장착:** `LOADOUT (controlled — 1-4)` Q/E/R 드롭다운(전체 스킬북) → 슬롯 지정.
- **적/ENC:** `SINGLE UNIT (add)` = 적 1종 소환 · `ENCOUNTER (replace)` = ENC 스폰 · `Third 진영` 체크 = 3세력.
- **허수아비:** `허수아비 소환`(불사·정지 표적 + 누적딜/어그로) · 초기화 버튼.
- **바인딩:** `결속 파일럿` 버튼(ANCHOR/BEACON·NUKER 집중/잠행·HEALER 지속치유/성역·DPS 초월/혈풍) = gear+정체성+Q/E/R 3종 원클릭 착용.
- **시전:** 스왑 1-4 → Q/E/R. targeted 서브 = 좌클릭 지면 조준. `cast_s>0` = 캐스트바(이동 이탈 시 취소·환급).
- **우측 패널:** 라이브 params + 의도 효과.
- ⚠️ **JSON 핫리로드 없음** — `skillbooks.json`/`effects` 편집 후 **씬 재실행**.

---

## 4. 대칭 원장 (컨펌 시 채움)

> AB당 1행. 이게 bulk 없이 29개 일관성을 잡는 장치.

| AB · 이름 | 모드 결정 | 효과·방향 변경 | 바인딩 영향 | 적 telegraph ↔ 아군 cast_s (대칭/비대칭+이유) | 편집 파일 | 상태 |
|-----------|-----------|----------------|-------------|-----------------------------------------------|-----------|------|
| **AB-002** Shield Bash | A 유지(반응형 CC) | 반경 4→8·dmg ×2.5→×1.0·cd 4→2(스팸형 광역 저딜) · 발동 telegraph 링 · **헛스윙도 차지/쿨 소모** | Tank 방벽충전(IDA-020) 스팸 소스 궁합 · 표식(IDA-021) 광역 어그로 | 적 EN-001도 근접 CC(A) — 대칭 | `skillbooks.json` · `sb_strike.gd` | ✅ 완료 |
| **AB-003** Arc Bolt Volley | A→**B**(cast_s 3.0·cd 2→6·radius 1.6→4.0) | 볼트 연사→광역 캐스트 볼트 | **DPS 초월 감전폭주**(BIND-PILOT-026, bolt→`apply_silence` 2.0s) · Nuker 집중/잠행 generic 후보 | 적 EN-011=필러(§3.6.1 A/0.30) ↔ 아군 B — **비대칭**(아군 볼트를 캐스터화, 적은 필러 유지) | `skillbooks.json` · `binding_fixtures.gd` · `ability_dispatch.gd` | ✅ 완료 |
| **AB-004** 전격사격(bolt) | A→**B**(cast_s 0.5→4.0) | — | — | (대칭 판정 보류) | `skillbooks.json` | ✅ 완료 |
| **AB-041** Glacial Bolt(cold) | A→**B**(cast_s 0.8→3.5) | — | 초월 cold→빙결(Rooted) 강화 | 적 EN-007 존/볼트 ↔ 아군 B | `skillbooks.json` | ✅ 완료 |
| **AB-053** 작열(fire) | A→**B**(cast_s 0.6→3.0) | — | 초월 fire→화상(Ignited) 강화(BIND-019) | (DPS 전용) | `skillbooks.json` | ✅ 완료 |
| **AB-059** 공허창(bolt) | A→**B**(cast_s 1.5→5.0) | — | — | (Ally-only) | `skillbooks.json` | ✅ 완료 |
| **AB-064** 치유 캐스트(channel_heal) | 캐스트힐(cast_s 2.0→3.0) | — | Healer 지속치유(dot_heal) | (Ally-only) | `skillbooks.json` | ✅ 완료 |
| **AB-066** 대치유(channel_heal) | **C 궁극**(cast_s 5.0→10.0) | — | Healer 성역/지속치유 | (Ally-only 궁극) | `skillbooks.json` | ✅ 완료 |

> ⚠️ **원장 재구성 주(2026-07-12):** 위 8행은 **세션 전 Sonnet 캐스팅 패스 산출물을 미커밋 diff에서 역-복원**한 기록(핑퐁 당시 실시간 기록이 아님). "적↔아군 대칭" 칸은 diff에서 확정 가능한 것만 채움 — 미확정은 잔여 판정 대상.
> **범위 초과 2건(이 패스 밖, 별도 rule DRIFT):** AB-054 절단 광선 채널 개편 = **DRIFT-079**(rootDuringCast 폐지·인터럽트형) · DPS 초월 운영 개편 = **DRIFT-080**(지속→1회소모+OOC초기화). 둘 다 impl/tuning 엄브렐러가 아니라 **rule → OPS_30 전파 후보**.

**DRIFT-078(엄브렐러):** "I-006 캐스팅 확장 패스 — 캐스터 서브 즉발→캐스트/채널 정합." 분류 `impl/tuning`. 위 원장이 세부, 패스 완료 시 확정 요약을 DRIFT-078 본문에 집약. (생성 직전 `SPEC_DRIFT.md` 실제 최신 번호 재확인.)

---

## 5. ENC 이터레이션 순서 + 진행표

### 5.1 적 → AB 백본 (판정-1회 기준표)
> 각 ENC = 그 유닛들의 AB. 아래에서 **첫 등장 ENC**에서만 판정.

| 적(EN) | AB(캐스터 서브) | 완료? |
|--------|------------------|-------|
| EN-001 Aegis Bearer | AB-002(탱 강타) · AB-099(적전용 도발바) | |
| EN-002 Voltaic Acolyte | AB-004 | ✅ |
| EN-003 Skirting Raptor | AB-006(누커 이동) | |
| EN-004 Slag Siphon | AB-008(볼트) · AB-009(존) · AB-042(존) | |
| EN-005 Gutter Spitter | AB-010(독) · AB-039(포자존) · AB-007(이동) | |
| EN-006 Bell Ringer | AB-011(스턴) | |
| EN-007 Mire Hexer | AB-012(취약) · AB-036·040·043(존) · AB-041 | AB-041 ✅ |
| EN-008 Corner Knife | AB-013(돌진) | |
| EN-010 Front Rush | AB-005(연타 필러) | |
| EN-011 Back Pester | AB-003(볼트 필러) | |
| EN-3RD-01 Stalker | AB-100(핀) · AB-101(추적) | |
| EN-3RD-02 Snarer | AB-102(루트) · AB-103(테더) | |
| EN-3RD-03 Reaver | AB-104(돌진) · AB-106(처형) | |

### 5.2 Ally-only 백로그 (적 안 씀 — "들고 갈 ENC"에서 처리, 사각 방지)
- **딜 누킹:** AB-037 · AB-055 · AB-056 · AB-058 · AB-060 · AB-072 · AB-073
- **CC·인터럽트·유틸:** AB-030 · AB-028 · AB-044 · AB-062 · AB-032 · AB-061
- **힐·버프·실드·DR:** AB-065 · AB-067 · AB-068 · AB-069 · AB-057 · AB-075 · AB-045 · AB-047 · AB-070 (+ 탱 반응형 AB-046·048·033·034·035·050·051·074·049·071 = 대개 A 유지)
> 각 ENC 세션에서 "그 적의 Shared" + "거기 대응해 들고 갈 ally-only"를 **함께** 올려 소진.

### 5.3 진행표
| ENC | 판정 스킬(신규) | 상태 |
|-----|------------------|------|
| ENC-NORM-001 | AB-002 · AB-003 · AB-005 · (AB-099 적전용) | ⬜ 진행 전 |
| ENC-HARD-001 | AB-011 · AB-010 · AB-039 · AB-007 | ⬜ |
| ENC-NORM-002 | _(구성 확인 후 채움)_ | ⬜ |
| … | | |

---

## 6. ENC-NORM-001 — 확인 스킬표

> 유닛: EN-001 ×1 · EN-010 ×2 · EN-011 ×1 · EN-013 ×1. (EN-013 능력 없음)
> 성격: 대부분 **A(즉발) 유지 확인용** 워밍업 + 적 텔레그래프 1종.

| AB | 이름 | 효과(kind) | 아군 equip | 쓰는 적(1종) | 현재 | 판정 가설 |
|----|------|-----------|-----------|--------------|------|-----------|
| **AB-002** | Shield Bash | 강타+넉백(strike) | Tank | EN-001 Aegis Bearer | 즉발 cd4 | 탱 반응형 근접 CC → **A 유지 후보**. 넉백 감각만 |
| **AB-003** | Arc Bolt Volley | 볼트 연사(bolt·투사체) | DPS·Nuker | EN-011 Back Pester | 즉발 cd2 | 필러(§3.6.1 적=A/0.30) → **A 유지 후보** |
| **AB-005** | Melee Flurry | 근접 연타(strike) | Nuker | EN-010 Front Rush | 즉발 cd1 | 필러 → **A 유지 후보** |
| AB-099 | Iron Mockery | 존 도발(적 telegraph) | (없음·적전용) | EN-001 Aegis Bearer | 적 telegraph | 아군 서브 없음 → **적 캐스트바만 확인**(이미 B/1.0) |

**들고 갈 ally-only 후보(선택):** 없음/자유(라이트 ENC).

---

## 7. ENC-HARD-001 — 확인 스킬표

> 유닛: EN-001 ×1 · EN-010 ×2 · EN-006 ×1 · EN-005 ×1 / 증원(13s): EN-005 · EN-013 ×2.
> **AB-002·005·099 = NORM-001에서 판정 완료 → 생략.** 여기서 **첫 진짜 캐스트 결정**.

| AB | 이름 | 효과(kind) | 아군 equip | 쓰는 적(1종) | 현재 | 판정 가설 |
|----|------|-----------|-----------|--------------|------|-----------|
| **AB-011** | Toll Stun | 스턴(stun) | Tank·DPS | EN-006 Bell Ringer | 즉발 cd8 | 하드 CC → **캐스트/차지(B~C)?** ⚠️ 아군 AB-011은 **적 채널 인터럽트 도구**로도 쓰임(샌드박스) → 인터럽트 응답성(A) vs 딜-스턴(cast) **역할 충돌 판단 필요**. 적 측은 채널 스턴(DRIFT-050) |
| **AB-010** | Venom Spit | 독 도트(poison) | Nuker·Healer | EN-005 Gutter Spitter | 즉발 cd6 | 지속 도트 → **짧은 캐스트 후보**. 적 poke telegraph(§3.6.1 A/0.30)와 대칭 여부 |
| **AB-039** | Vent Spore | 독안개 존(zone) | Nuker·Healer | EN-005 Gutter Spitter | 즉발 | **캐스트 결정**. 적 = **B/1.2**(§3.6.1) → **대칭 강력 후보**(현 아군 비대칭이 플래그됨) |
| **AB-007** | Retreat Hop | 이탈(blink) | Nuker | EN-005 Gutter Spitter | 즉발 cd6 | 이동 → **A 유지 후보** |

**들고 갈 ally-only 후보(사각 처리):**
- **AB-070 Purge Light** — EN-005 독/디버프 클렌즈 대응 (Healer).
- **AB-030 Voltaic Interrupt** — EN-006 채널 스턴 인터럽트 대응 (AB-011 역할 충돌 판단과 연동).
- **AB-037 등 딜 누킹** — 실전 딜 체감 겸.

---

## 8. Stop-line

- 스킬 편집·게이트·원장/DRIFT 기록 = **사용자 스킬별 컨펌 후.**
- spec md 편집·OPS_30 전파·커밋·푸시 = **명시 승인 후에만.** 모호하면 분석·질문 우선.
- 이 파일은 **작업 산출물 임시 보관** — 패스 종료 시 삭제, 정본은 DRIFT-078.

# _WIP — I-006 캐스팅 확장 패스 (스킬별 핑퐁 검증) · **활성(TODO)**

> **임시 작업 문서.** 패스 완료 후 **삭제**한다. SSOT 아님 — 결정은 `SPEC_DRIFT.md`(DRIFT-078)로 남는다.
> **📂 2-파일 체계(2026-07-15):** 이 파일 = **활성/해야할것**(방법론 §0~§3 · 진행 지도 §5 · 현재 ENC §8 · 규칙 §9). 완료분은 [_WIP_casting_expansion_pass_DONE.md](_WIP_casting_expansion_pass_DONE.md) = **완료 아카이브**(원장 §4 · 완료 ENC §6~§7 상세). **ENC 컨펌 시 활성→DONE 이동**(§2.4). 활성 파일을 짧게 유지해 매 세션 읽는 비용을 줄이는 게 목적.
> **모델 분업:** 방법·표 = Opus 작성(이 파일). **실제 스킬별 핑퐁 = Sonnet 세션이 이 파일을 열어 §2 루프를 구동.**
> **작성:** 2026-07-09 · **최신화:** 2026-07-15 (2-파일 분리 / ENC-NORM-001·ENC-HARD-001 완료→DONE 이관 / 다음 = **ENC-MID-001** §8) · spec pin `2bf37b2` · 게임 `wip/casting-ab054-overdrive-20260712` @ `fb29fbd`.

---

## 0. 목적

`I-006` 캐스터 원칙(`D-016` §3.6 line 207 / 게임 DRIFT-075): **Nuker·DPS·Healer 슬롯 스킬 = 캐스트/채널 중심**, 즉발(A)은 최소·강패널티. 현재 캐스터 서브 51종 중 ~29종이 아직 즉발. 이를 **스킬 하나씩 샌드박스에서 체감·수정**하며 캐스트/방향/효과/바인딩을 정합시킨다. **일괄 편집 금지**(완성도 저하) — AB당 의식적 판정.

**핵심 제약(사용자 결정):**
- **수치 밸런싱(스킬 간 딜/쿨 상대값)은 이번 패스 스킵.** 명백히 깨진 효과·방향만 손봄.
- **대부분 서브가 Shared** → AB당 **적-시전 + 아군-시전 동시 판정**(K1 대칭).
- **판정-1회:** 같은 AB가 여러 ENC에 겹치면 **첫 등장 ENC에서만** 판정.

**⚡ 어텐션 이코노미 (2026-07-12 보강 — 딜 최소주의):** 플레이어 인지예산은 **Tank(어그로)·Healer(힐싸이클)·Movement·적 대응**이 지배(3서브×4클래스=12버튼 포화). 딜은 **잔여 주의로 최소 조작**하되 "딜 기분"은 남긴다.
- **딜 서브(Nuker/DPS) = 긴 캐스트 + 긴 쿨 + 큰 한방** → "가끔, 중요하게"(저쿨 난사·짧은 캐스트 **금지**). 캐스트·쿨 **둘 다** 레버. 드문 만큼 한 방 임팩트 — 이 경우 **딜 집중은 위 "밸런싱 스킵"의 예외**(설계-의도).
- **Tank 서브 = 손이 가는 존**(어그로 관리) → 반응형·즉발/짧음 OK. **Healer = 큰 힐은 긴 캐스트 + 긴 쿨**(드물게). **Movement = 항상 가용.**
- **쿨 시작 = 캐스트 "완료" 시점** (2026-07-15 · ENC-HARD-001 파생 **전역 변경**): 시작 시점에 걸면 캐스트 도중 쿨이 소모돼 `cd≈cast_s`인 스킬이 **무한쿨처럼 난사**됨 → 위 "긴 캐스트+긴 쿨" 레버가 무력화. 이제 **총 주기 = cast_s + cd**(취소 시 쿨 미발동·차지 환급 / 캐스트 중엔 `is_channeling`이 재시전 차단). `ability_dispatch.cast_skillbook`.
- **규칙5(통합 refine):** Shared = 기본 통합(적도 같은 스킬). **진영별 같은 ID 분기 금지**(드리프트). 예외(적 빠른 싸이클/적-전용 밸런싱)만 **새 적 전용 스킬(신규 ID)** 신설·배치. 예: AB-005 = 아군 커밋 버스트로 정의, EN-010은 빠른 rush라 AB-005 제거→기본 평타.

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

### 2.4 ENC 완료 → 이터레이션 + **DONE 이동 규칙**
ENC 내 모든 스킬 컨펌 → 아래 이동 절차 → **다음 ENC**.

**완료 이동 절차(활성 파일을 짧게 유지):** ENC 하나가 컨펌·완료되면,
1. 그 ENC의 **확인 스킬표 섹션(§8류) 전체** + 그 ENC에서 새로 채운 **원장 행**을 → [DONE 파일](_WIP_casting_expansion_pass_DONE.md)로 **잘라 이동**(§6/§7 형식: 표 + "가설 대비 실제 결정" 요약).
2. 활성 **§5.3 진행표**에서 그 ENC 행을 `✅ 완료 → DONE §N` 한 줄로 **축약**(상세 삭제).
3. 활성 **§5.1 백본표** 완료? 칸 체크.
4. 활성 파일엔 그 ENC 상세를 **남기지 않는다**(진행표 한 줄 + DONE 링크만). 번호 구멍은 스텁 한 줄로 메워 참조를 살린다.

### 2.5 결속 링크 제안 (축4 보강 — Shared/Ally-only 전용)

Shared 서브(적도 드롭) 또는 Ally-only 서브는, 장착 가능한 **각 클래스**마다 이미 확립된 **2개 정체성**(`binding_overlays.gd` SIGNATURE)이 있다. 스킬별 판정 시 축4(바인딩)에서 다음을 함께 제안·기록한다:

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
| DPS | IDA-024 초월(`overdrive_charge`, **kind별 분기 필요** — 현재 fire·cold·beam·**bolt**(감전폭주=침묵)·**poison**(맹독폭주=+3스택 **+ 독장판**) 구현. 미구현 kind는 게이지는 쌓여도 발동 시 무효과) | IDA-027 혈풍(`blood_soak`, generic 기본 흡수 + beam/cold만 특수 변형) |

#### AB-002 Shield Bash (Tank 전용) 결속 제안
`equip_classes`: Tank만 → Tank의 두 정체성 모두 대상. 둘 다 generic delta라 코드 추가 없이 `OVERLAYS` 등록만으로 동작.
- **Anchor 방벽충전(IDA-020):** "전선을 지키는 스킬"에 정확히 부합 — 캐스트마다 방벽 +1. 지금 이 킷은 AB-033/034/035(Q/E/R) 3종이 이미 채우고 있어, AB-002를 넣으려면 셋 중 하나를 교체하거나 로드아웃을 재구성해야 함. 넓은 반경(8m)·저딜(×1.0)이라 "맞히는 것보다 휘두르는 것 자체"가 방벽 소스가 되는 스팸형 슬롯과 궁합이 좋음.
- **Beacon 표식(IDA-021):** 표식 대상에 추가 위협 — AB-002가 광역이라 표식 대상이 얻어맞을 확률이 높아 "표식 유지용 광역 어그로 핑거" 역할에 적합. R(`beacon_mark_refresh`, 갱신형)보다는 Q/E급 단순 `beacon_mark`가 자연스러움.

#### AB-003 Arc Bolt Volley (DPS·Nuker 겸용) 결속 제안
`equip_classes`: DPS(main) + Nuker(sub, B1) → 4개 정체성 전부 후보.
- **Nuker 집중(IDA-025, `focus_stack`):** 같은 kind(`skillbook_bolt`)인 AB-004가 이미 이 델타로 등록돼 있어 동일 패턴으로 자연스럽게 낌(명중 시 집중 대상 지정+누적 추가타). Generic, 코드 변경 없음.
- **Nuker 잠행(IDA-029, `flank_strike`):** `range_band`="Mid"라 근접화 보상은 중간 수준(`band_dmg.Mid`=0.25, `band_cd.Mid`=0.10) — AB-060(Mid)과 동급 취급 가능. Generic, 코드 변경 없음.
- **DPS 초월(IDA-024, `overdrive_charge`):** ✅ **결정 + 구현 완료 — 감전 폭주(Silence).** `_dps_overdrive_empower`(`ability_dispatch.gd`)에 `skillbook_bolt` 분기 추가: 초월 중 명중한 적을 `apply_silence(bolt_silence_s=2.0)`로 침묵(AB-044 Hush Ward와 동일 API 재사용, 신규 상태 없음). `OVERLAYS`에 `BIND-026`(`gear_ward_dps_press_rod` + IDA-024 + AB-003 @ slot0, AB-053과 슬롯 공유 — 둘 중 하나로 장착 가능) 등록. (기각안: Vulnerable 부여 / 연쇄 감전 / 관통형 — 침묵이 "몰아치는 버스트 창 + 상대 액션 봉쇄"로 더 강한 차별점이라 선택.)
- **DPS 혈풍(IDA-027, `blood_soak`):** kind가 `_`(default) 분기(흡수 폭발)로 이미 커버됨 — AB-053과 동일 취급. Generic, 코드 변경 없음.

---

## 3. 샌드박스 퀵레퍼런스

`scenes/dev/combat_sandbox.tscn` 실행.
- **스킬 장착:** `LOADOUT (controlled — 1-4)` Q/E/R 드롭다운(전체 스킬북) → 슬롯 지정.
- **적/ENC:** `SINGLE UNIT (add)` = 적 1종 소환 · `ENCOUNTER (replace)` = ENC 스폰 · `Third 진영` 체크 = 3세력.
- **허수아비:** `허수아비 소환`(불사·정지 표적 + 누적딜/어그로) · 초기화 버튼.
- **바인딩:** `결속` 버튼(ANCHOR/BEACON·NUKER 집중/잠행·HEALER 지속치유/성역·DPS 초월/혈풍) = gear+정체성+Q/E/R 3종 원클릭 착용. **파일럿 → 정본 승격 완료**(`binding_overlays.gd` / BIND-###, 게임이 SSOT). DPS `초월` 픽스처는 **Q = AB-010**(맹독폭주·독장판 체감용).
- **시전:** 스왑 1-4 → Q/E/R. targeted 서브 = 좌클릭 지면 조준. `cast_s>0` = 캐스트바(이동 이탈 시 취소·환급).
- **우측 패널:** 라이브 params + 의도 효과.
- ⚠️ **JSON 핫리로드 없음** — `skillbooks.json`/`effects` 편집 후 **씬 재실행**.

---

## 4. 대칭 원장 → **[DONE 파일 §4](_WIP_casting_expansion_pass_DONE.md)로 이관**

> 완료 행(AB당 1행, 현재 13행)은 **DONE 파일**에 있다. 새 스킬 컨펌 시 → DONE §4 표에 행 추가(§2.4 이동 규칙). 여기서 참조가 필요할 때만 DONE을 연다.
> 아래 DRIFT 엄브렐러 노트는 **패스 전체를 지배하는 메타**라 활성에 유지한다.

**DRIFT-078(엄브렐러):** "I-006 캐스팅 확장 패스 — 캐스터 서브 즉발→캐스트/채널 정합." 분류 `impl/tuning`. 위 원장이 세부, 패스 완료 시 확정 요약을 DRIFT-078 본문에 집약. (생성 직전 `SPEC_DRIFT.md` 실제 최신 번호 재확인.)

**DRIFT-082(패스 파생 — 통합, 2026-07-12 확정):** AB-003 §2.2-B **대칭 판정**이 "적↔아군 **완전 동일**(단일정의)" 결정으로 귀결 → 위 원장 AB-003 행의 "비대칭(적은 필러 유지)" 칸은 **폐기(superseded)**. Shared 스킬 통합 아키텍처 = **CastContext**("해소 1개 + 프론트엔드 2개"), AB-003 파일럿 구현 완료. **fodder(EN-011) 3초 캐스트 확정 OK**(재배정 불요). AB-002는 A(즉발) 유지 확정(cd2). rule/design·OPS_30 전파 후보 — packet=[_PROP_PACKET_DRIFT-082.md](_PROP_PACKET_DRIFT-082.md). 잔여 대칭 subset(strike/stun/poison/cold) 통합 = follow-on.

---

## 5. ENC 이터레이션 순서 + 진행표

### 5.1 적 → AB 백본 (판정-1회 기준표)
> 각 ENC = 그 유닛들의 AB. 아래에서 **첫 등장 ENC**에서만 판정.

| 적(EN) | AB(캐스터 서브) | 완료? |
|--------|------------------|-------|
| EN-001 Aegis Bearer | AB-002(탱 강타) · AB-099(적전용 도발바) | ✅ (AB-002 A유지 · AB-099 무변경) |
| EN-002 Voltaic Acolyte | AB-004 | ✅ |
| EN-003 Skirting Raptor | AB-006(누커 이동) | |
| EN-004 Slag Siphon | AB-008(볼트) · AB-009(존) · AB-042(존) | |
| EN-005 Gutter Spitter | AB-010(독) · ~~AB-039(포자존)~~ · AB-007(이동) | ✅ (AB-010 통합·B·스택독 / AB-039 **병합→폐기** / AB-007 auto-trigger 이탈·007a·007b 분기) |
| EN-006 Bell Ringer | AB-011(스턴) | ✅ (A유지·타겟팅 단일·Tank 전용 / 통합 defer) |
| EN-007 Mire Hexer | AB-012(취약) · AB-036·040·043(존) · AB-041 | AB-041 ✅ |
| EN-008 Corner Knife | AB-013(돌진) | |
| EN-010 Front Rush | AB-005(커밋 근접 버스트) | ✅ |
| EN-011 Back Pester | AB-003(통합 캐스트 볼트) | ✅ |
| EN-014 Gutter Chanter | AB-098(적 힐) | ⬜ (**적 전용** — 아군 서브 없음 → AB-099처럼 텔레그래프만 확인) |
| EN-3RD-01 Stalker | AB-100(핀) · AB-101(추적) | |
| EN-3RD-02 Snarer | AB-102(루트) · AB-103(테더) | |
| EN-3RD-03 Reaver | AB-104(돌진) · AB-106(처형) | |

### 5.2 Ally-only 백로그 (적 안 씀 — "들고 갈 ENC"에서 처리, 사각 방지)
- **딜 누킹:** AB-037 · AB-055 · AB-056 · AB-058 · AB-060 · AB-072 · AB-073
- **CC·인터럽트·유틸:** AB-030 · AB-028 · AB-044 · AB-062 · AB-032 · AB-061
- **힐·버프·실드·DR:** AB-065 · AB-067 · AB-068 · AB-069 · AB-057 · AB-075 · AB-045 · AB-047 · AB-070 (+ 탱 반응형 AB-046·048·033·034·035·050·051·074·049·071 = 대개 A 유지)
> 각 ENC 세션에서 "그 적의 Shared" + "거기 대응해 들고 갈 ally-only"를 **함께** 올려 소진.

### 5.3 진행표

> **2026-07-15 전면 재구성:** 전 ENC 구성을 실제 데이터(`data/slice01/encounters/*.json` × `enemies.json` 킷)로 매핑해 **신규 캐스터 AB가 있는 ENC만** 남겼다. fodder 전용 구성(EN-010·012·013 = 능력 **없음**, EN-011=AB-003 기판정)은 판정 대상이 아니다 — 기존 "ENC-NORM-002가 다음" 계획은 **폐기**(신규 AB 0).

| ENC | 판정 스킬(신규) | 상태 |
|-----|------------------|------|
| ENC-NORM-001 | AB-002 · AB-003 · AB-005 · (AB-099 적전용) | ✅ 완료 → [DONE §6](_WIP_casting_expansion_pass_DONE.md) (AB-002 A유지 · AB-003 통합캐스트 · AB-005 커밋버스트 / AB-099 무변경) |
| ENC-HARD-001 | AB-011 · AB-010 · AB-039 · AB-007 | ✅ 완료 → [DONE §7](_WIP_casting_expansion_pass_DONE.md) (AB-011 A유지 · AB-010 통합B+스택독 · AB-039 병합→폐기 · AB-007 auto-trigger+007a/007b) |
| **ENC-MID-001** | **AB-008 · AB-009 · AB-042** | ⬜ **← 다음** (§8) — **존(zone) 패밀리 정책 결정** |
| ENC-HARD-002 | AB-013(돌진) | ⬜ |
| ENC-HARD-003 · DEEP-001 | AB-006(누커 이동) | ⬜ |
| ENC-HARD-004 · HARD-012 | AB-012(취약) · AB-036 · AB-040 · AB-043(존 3종) | ⬜ — **존 정책 상속**(MID-001 결정을 일괄 적용) |
| ENC-HARD-006 · HARD-009 | AB-098(적 힐) | ⬜ — **적 전용**(아군 서브 없음 → 텔레그래프만, AB-099 선례) |
| ENC-3RD-001 | AB-100 · 101 · 102 · 103 · 104 · 105 · 106 | ⬜ — 3세력(최대 블록) |
| ENC-HARD-008 | (EN-004 = MID-001과 동일) | ⏭️ 판정-1회 소진 |
| NORM-002 · NORM-003 · AMB-001/002 · PAT-001~003 · BOSS-001 · HARD-005/010/011 | — | ⏭️ **판정 대상 아님**(신규 캐스터 AB 0 — fodder/기판정 구성) |

---

## 6. ENC-NORM-001 → **[DONE 파일 §6](_WIP_casting_expansion_pass_DONE.md)로 이관** ✅
## 7. ENC-HARD-001 → **[DONE 파일 §7](_WIP_casting_expansion_pass_DONE.md)로 이관** ✅

> 완료 ENC 상세(확인 스킬표 + "가설 대비 실제 결정" 요약)는 DONE 파일에 있다. 요약은 §5.3 진행표 참조.
> §8이 참조하는 선례: **AB-039 병합·독장판 초월화**(§7·AB-010 행) · **AB-007 "A유지" 가설 뒤집힘**(§7) · **전역 파생 3건**(쿨=캐스트 완료 시점 §0 / 결속 slot_index:-1 / 패시브 UI 규약).

---

## 8. ENC-MID-001 — 확인 스킬표 (다음)

> 유닛: **EN-004 Slag Siphon ×1** · EN-010 ×2 · EN-013 ×1. (EN-010/013 = 능력 없음)
> **왜 여기가 다음인가:** NORM-002/003·AMB·PAT·BOSS 등은 **신규 캐스터 AB가 0**(§5.3 재구성). EN-004가 **존(zone) 계열 첫 등장**이라, 방금 AB-039 병합·독장판 초월화로 생긴 **존 선례**를 여기서 **정책**으로 확정한다. (EN-004는 ENC-HARD-008과 공유 → 판정-1회로 소진)

### 8.1 코드 실사 (2026-07-15 · Opus — 조사만, 편집 0)

> 아래 3건이 **아래 정책 옵션표의 전제를 바꾼다.** 핑퐁 전에 읽을 것.

1. **RX 엔진은 이미 완전 가동 중**(설계 의도 아님). [reaction_system.gd](../scripts/combat/abilities/reaction_system.gd) — Oil→Fire 점화(`:336` `_ignite_oil` = 폭발 60dmg + **인접 기름 연쇄**(depth≤2) + 잔류 Fire존 8dps/4s + Ignited 5s + Smoke), Water→감전 전도(`:276` Shock), Wind→풍하 산포(`:68` `_spread_tick`, 2s마다 1.6m·≤2/gust·≤6 live), Ice↔Fire 용해/응결 등 10여 쌍. 우선순위 중재(`:169` `_primary_medium_of`)까지 있음. **점화 진입점 = `sb_fire.gd:30`(AB-037) · `torch.gd:185` 둘뿐.**
   - ⚠️ **정정(2026-07-15, 사용자 지적):** 초안은 여기서 "옵션 2·3 = RX 파괴"라 썼으나 **틀렸다.** 기존 방식(AB-039)은 **삭제가 아니라 흡수**였다 — ToxicGas 존 분기(`hazard_zone.gd:194-204`)도 fire+ToxicGas→toxic flash(`reaction_system.gd:218`)도 **그대로 살아 있고** 트리거만 BIND-031로 이동했다. 즉 병합은 RX를 **손상시키지 않았다.** Oil도 흡수처만 있으면 `_ignite_oil` 도달성은 유지된다. 남는 사실은 "**매질의 판 등장 빈도**가 줄어든다"(EN-005가 더는 가스를 안 깖)뿐 — 파괴가 아니라 노출 감소.
2. **잔존 존 5종 전부 이미 `role: utility` · 무피해**([ability_roles.gd:59-63](../scripts/combat/abilities/ability_roles.gd#L59-L63)). 유일한 `role: threat` 피해 존이던 **AB-039**(`:38` 주석 = *"독가스 존 (dps 8 — 유일한 피해 존)"*)가 바로 HARD-001에서 병합·소멸한 그것. → §8 원안이 옵션 1을 기각한 근거("적이 장판 계속 까는 그림 = HARD-001 기각")는 **피해 존에 대한 기각**이라 **무피해 존에 전이되지 않음**. 아래 「기계적 일반화 경고」에 정확히 해당하는 사례.
3. **존은 피아무구분**([hazard_zone.gd:14](../scripts/world/hazards/hazard_zone.gd#L14) `UNIT_GROUPS`, 진영 체크 0 — spec F-021 §3.3.1 명시). **내 기름에 우리 파티도 미끄러진다.** 위협만 진영 인지(`:218` `_credit` — 아군 오폭은 어그로 0, HP는 깎임).

### 8.2 존 정책 — 옵션표 (원안 4안 + 실사 파생 2안)

> **역할 주의(2026-07-15):** 이 표는 **초안·재료**다. 평가·추천 칸은 **의도적으로 없앴다** — 안의 채택은 사용자가 **스킬단위 감독**으로 정한다(§9). 아래 칸은 각 안에 걸리는 **사실**만 적는다.

| 안 | 내용 | 걸리는 사실(실사) |
|----|------|------------------|
| 1 | (원안) 존 = base — 모든 시전이 존을 깖 | 캐스트 모드는 미지정(1+가 그 축을 명시) |
| **1+** | base + **A(즉발) 유지** 명시 | 존 5종 = `role: utility`·무피해(`ability_roles.gd:59-63`). 적 캐스트 캡 대상 아님(`CAP_ROLES=["threat","control"]`). AB-011이 `role=control` 근거로 A유지한 선례 있음(§7). 적 tele 0.55는 `windup_pos`에 해소되므로([enemy_ai.gd:891-896](../scripts/combat/enemy_ai.gd#L891-L896)) 마커 밟고 비키면 회피 성립 |
| 2 | 존 = 결속 payoff | **AB-039 선례 = 흡수**(코드 유지·트리거 이동, §8.1 정정) → RX 손상 없음. 단 존 equip = **Nuker/Healer**, 초월 = **DPS**(클래스 축 상이) → 어느 정체성에 붙일지가 미정. 적용 시 EN-005 전례대로 EN-004도 base에선 안 깖(매질 노출 빈도↓) |
| 3 | 존 = 적 전용 | EN-004 = `axis: zone`·`archetype: EnvironmentElite`·PT-004 "plants + reaches"·공격사거리 9m(`enemies.json:2,89-119`). 아군 점화 경로(AB-037·횃불)는 잔존 → 반응형 플레이 성립. 아군 스킬북 5종 소멸 |
| 4 | base + 캐스트화 | 아군 캐스트는 **오직 `cast_s`**가 구동(§1 line 31 — `telegraph_s`는 아군 죽은 스키마). 적 tele와 아군 cast_s는 서로 다른 기제 |
| **5** | **존 = 다른 스킬에 흡수**(실사 파생) | AB-039→AB-010과 **같은 형태**(같은 유닛 킷·같은 flavor 내 병합). AB-009 후보 흡수처 = **AB-008**(EN-004 = "Slag **Siphon**", AB-008 = 그 스플래시 볼트 r2.0, 둘 다 EN-004 킷). 버튼 수↓(§0 어텐션 이코노미). **미검증 — 체감 필요** |

> **⚠️ 판단 포인트(기계적 일반화 경고 — 실사로 뒷받침됨):** AB-039(독 존)는 *"AB-010과 느낌 중복"* 이라 병합된 것이지 "존은 나쁘다"가 아니다. 게다가 AB-039는 **유일한 피해 존**이었고(실사 2), AB-009/042(기름·돌풍)는 **중복 대상이 없고 RX 콤보의 기판**이며 EN-004의 정체성 그 자체(`axis: zone` · `archetype: EnvironmentElite` · PT-004 "plants + reaches" · 공격사거리 9m = zone-holder reward, `enemies.json:2,89-119`). → 독 존 선례를 확장하지 말고 **존 자체의 존재 가치**를 먼저 판정할 것.

### 8.3 스킬별 초안 (전부 ⬜ 미확정 — **변경안은 사용자가 스킬단위 감독으로 작성**)

> 「초안 가설」칸 = **검증 대상이지 권고가 아니다.** 체감이 뒤집으면 뒤집힌다(HARD-001에서 AB-007 "A 유지" 가설이 통째로 뒤집힌 전례).

| AB | 현재(실측) | 초안 가설(미검증) | 관련 사실 | 샌드박스 체크 |
|----|-----------|------------------|----------|--------------|
| **AB-008** Slag Spit | `skillbook_bolt` 즉발 · cd 2.5 · dmg ×0.8 · splash r2.0 · range 10 · projectile 16m/s · DPS·Nuker(B1) · **role=threat**/exec=shared · 적 tele 0.4 | 존 정책과 **독립**(유일한 `role=threat` 딜 서브) → AB-003 선례를 그대로 상속하면 B(`cast_s`~3.0)+cd 상향+dmg 상향+`unified`. **단 §8.2-5안이면 흡수처가 되므로 판정이 얽힘** | 같은 kind(`skillbook_bolt`)인 AB-003이 이미 통합·B·cd6. DRIFT-082 "같은 ID = 같은 거동". §0 딜-캐스트 규칙 대상 | **A** 허수아비: 캐스트 후 한방 임팩트 있나 · **B** EN-004 소환: 적 3s 캐스트가 tele 0.4 대비 굼뜬가(fodder EN-011 3s OK 선례) · **C** ENC |
| **AB-009** Spawn Oil Patch | `skillbook_zone` Oil · 즉발 · cd 8 · r2.0 · ttl 8 · range 9 · targeted · Nuker·Healer(B3) · **role=utility** · 적 tele 0.55 | **정책 선택에 종속** — 1+면 무변경 / 5면 AB-008로 흡수 / 2·3이면 아군 킷 이탈 / 4면 cast_s 부여 | 무피해 유틸 · RX 기판(Oil→Fire 60dmg 연쇄) · EN-004 정체성(`axis: zone`) · §8.1 실사 1~3 | **A** 허수아비에 기름 → **AB-037로 점화** → 폭발·연쇄·잔류 화염존 체감 · **피아무구분** 확인(내 기름에 파티가 미끄러지나 — 이게 캐스트 대신인 "비용"으로 충분한가?) · **B** EN-004 기름 tele 0.55 회피 감각 |
| **AB-042** Spawn Gust Patch | `skillbook_zone` Wind · 즉발 · cd 10 · r2.0 · ttl 8 · range 9 · Nuker·Healer(B3) · **role=utility** · 적 tele 0.4 | AB-009 정책 상속. **정책과 무관하게** WindBuffeted 무효과 = 파손(§8.4-①) → "밀림 구현" vs "순수 기판 확정" 별도 판정 | spread(`_spread_tick`)는 정상 작동 → Wind는 **산포기**로는 살아 있음. 자체 효과만 공백 | 기름 옆에 돌풍 → **기름이 실제로 흘러가나** → 흘러간 기름에 점화 · 돌풍 **자체 피격감**(현재 = 색·팝업만 뜨고 무효과) |

### 8.4 실사로 드러난 파손 2건 (§0 "명백히 깨진 효과" = 이 패스 스코프)

① **AB-042 Wind = 무효과 상태.** `WindBuffeted`는 색([outcome_status.gd:25](../scripts/combat/outcome_status.gd#L25))·KO라벨(`:40`)·플로팅텍스트·오브 슬롯(`:149`)까지 배선돼 있으나 **`MOVE_MULT` 항목이 없고 넉백도 없다**. `outcome_status.gd:8`은 *"the source applies a knockback"* 이라 약속하지만 **그 source가 존재하지 않음**(`hazard_zone.gd`는 상태만 부여). → `ability_roles.gd:62` 주석 "Wind **밀림**(무피해)"의 밀림이 **런타임에 없음**. Vegetation(`:63` "무효과(가연성/RX 전용)")은 **의도된** 무효과라 대비됨.

② **잠복 크래시 → ✅ 해소(2026-07-18).** 실사해보니 [cast_context.gd](../scripts/combat/abilities/cast_context.gd)의 계약 누락은 fire_hit/cold_hit 2개가 아니라 **15개**였다(공간쿼리 flip 6·힐 3·RX 위임 3·파티전용 3). 전부 메움 + `CTX_CONTRACT` 계약 상수([ability_dispatch.gd](../scripts/combat/abilities/ability_dispatch.gd)) + `party_pool_smoke` **파리티 게이트**로 앞으로의 누락도 CI가 잡는다(암묵중복→명시계약). `combat_controller` 공간쿼리는 순수필터(`_in_cone`/`_rect`/`_nearest`) 추출로 진영-flip 재사용. **kind/role 조용한 실패**도 `push_error`·전수검증으로 승격. → **strike/stun/poison/cold subset을 unified로 확대해도 throw 없음**(§4 통합 착수 전 선결 완료). ci_smoke 7/7. ImplDecision 후보.

### 8.5 축4(바인딩) — 존 공통 공백 **[판정 필요]**

존 5종은 **Nuker·Healer** equip인데, 그 4개 정체성 델타는 전부 **명중 훅**(`focus_stack`·`flank_strike`) 또는 **치유 훅**(`dot_heal`·`sanct`)이다. **무피해·무치유인 존은 어느 훅에도 안 걸린다** → 존 서브 = **결속 델타 0**. §2.5 절차상 "각 정체성에 자연스럽게 들어맞나"의 답이 4개 모두 "아니오"다. 이게 "존 스킬의 존재 이유" 판정의 **실제 축** — 정책 1+를 택하더라도 별도 판단이 남는다.

⚠️ **AB-008 파생:** DPS 초월 감전폭주(BIND-026)는 **kind 분기**(`skillbook_bolt`)라 AB-008에도 **자동 적용**된다(침묵 2.0s). 볼트 2종이 같은 폭주 효과 → **차별성 0** 문제. 의도 확인 필요.

**들고 갈 ally-only 후보(사각 처리):**
- **AB-037 Ember Lance** (`skillbook_fire` · 즉발 cd5 · DPS·Nuker) — **Oil→Fire 점화의 유일한 스킬 진입점**(`sb_fire.gd:30`). 존 체감에 **필수**. ⚠️ 반입 시 AB-037 자신도 딜 서브 판정 대상(즉발 → §0 대상)이 됨.
- ~~AB-055 · AB-056 · AB-060~~ — **정정(2026-07-15 실사):** 셋 다 점화 **불가**. AB-055/056 = `skillbook_bolt`(→ Water 있으면 **감전 전도** RX), AB-060 = `skillbook_execute`. `fire_hit` 방출은 `sb_fire.gd`(AB-037)와 횃불(`torch.gd:185`)뿐. 딜 누킹 체감용으로만 유효.
- **AB-070 Purge Light** (`skillbook_purge` · Healer) — 기름/돌풍 디버프 대응.

---

## 9. Stop-line

- 스킬 편집·게이트·원장/DRIFT 기록 = **사용자 스킬별 컨펌 후.**
- spec md 편집·OPS_30 전파·커밋·푸시 = **명시 승인 후에만.** 모호하면 분석·질문 우선.
- 이 파일 + [DONE 파일](_WIP_casting_expansion_pass_DONE.md)은 **작업 산출물 임시 보관** — 패스 종료 시 **둘 다 삭제**, 정본은 DRIFT-078.
- **2-파일 동기화:** ENC 컨펌 시 §2.4 이동 절차를 반드시 따른다(활성→DONE). 완료 상세가 활성에 남으면 파일이 다시 비대해져 분리 취지가 무너진다.

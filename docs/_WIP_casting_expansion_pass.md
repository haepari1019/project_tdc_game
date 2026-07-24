# _WIP — I-006 캐스팅 확장 패스 (스킬별 핑퐁 검증) · **활성(TODO)**

> **임시 작업 문서.** 패스 완료 후 **삭제**한다. SSOT 아님 — 결정은 `SPEC_DRIFT.md`(DRIFT-078)로 남는다.
> **📂 2-파일 체계(2026-07-15):** 이 파일 = **활성/해야할것**(방법론 §0~§3 · 진행 지도 §5 · 현재 ENC §8 · 규칙 §9). 완료분은 [_WIP_casting_expansion_pass_DONE.md](_WIP_casting_expansion_pass_DONE.md) = **완료 아카이브**(원장 §4 · 완료 ENC §6~§7 상세). **ENC 컨펌 시 활성→DONE 이동**(§2.4). 활성 파일을 짧게 유지해 매 세션 읽는 비용을 줄이는 게 목적.
> **모델 분업:** 방법·표 = Opus 작성(이 파일). **실제 스킬별 핑퐁 = Sonnet 세션이 이 파일을 열어 §2 루프를 구동.**
> **작성:** 2026-07-09 · **최신화:** 2026-07-24 (**AB-042 완결 → ENC-MID-001 완료·DONE §8 이관**. 전수 표 **완료 17/미완료 43**. **Phase A = 스킬 전수 핑퐁(§5 표 순회) / Phase B = ENC 밸런싱(§5.3)**. 다음 = Phase A 표 순서로 미완료 43종 — 표 순서상 **AB-012 Hex Bolt**부터) · spec pin `2bf37b2` · 게임 `wip/casting-ab042-wind-20260723`.

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

### 2.0 검토 순서 (2-Phase — 2026-07-19 축 전환)
**검토 축을 ENC→스킬로 전환.** 기존 ENC 순회(§5.3) 대신 **스킬 전수(§5 표) 우선**.
- **Phase A — 스킬 전수 핑퐁(§5 표 순회):** 각 스킬을 표 순서로 §2.1의 4축(효과·방향·시전모드·바인딩)을 **1차 확정** + **통폐합 판단**(겹치는 효과 통합/차별화). 데이터 수정 → DRIFT 로깅 → 표 `[x]`. **밸런싱(딜/쿨 상대값)은 제외**(§0 스킵). Phase A가 확정하는 건 **밴드(시전모드)**까지.
- **Phase B — ENC 실전 밸런싱(§5.3 진행표):** ENC별 딜/쿨 상대값 밸런싱 + **맥락 재확인**. 판정-1회(첫 등장 ENC).
> **관계: Phase A = 잠정 / Phase B = 확정.** A의 시전밴드·통폐합이 B 실전에서 안 맞으면 **뒤집는다**(선례: HARD-001에서 AB-007 "A유지" 가설이 실전 체감으로 뒤집힘).

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

> **⚠️ 2026-07-19 개정(DRIFT-087):** 아래 절차는 **whitelist 전제로 쓰였으나 그 전제가 폐기됐다.** 이제 정체성을 착용하면 장착한 **모든 서브**가 기본 델타(GENERIC)를 받는다 — 스킬별 "어느 정체성에 등록할까" 제안은 **더 이상 필요 없다.** 남은 축4 판정은 두 가지뿐: ① 이 서브가 **훅을 가졌나**(명중/치유 — 없으면 generic이어도 무효과, 존·블링크 사례) ② **변주가 필요한가**(초월/혈풍 `variant`, 슬롯 변주). 아래 클래스별 정체성 참조표는 그 판정용으로 유지.

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

## 5. 전수 스킬 표 (Phase A — 스킬 순회)

> 캐스터/탱 서브 **61종 전수**(Nuker/DPS/Healer/Tank equip; Identity IDA-### 제외). Phase A는 이 표 순서로 각 스킬 §2.1 4축 확정 + 통폐합 판단.
> - **밴드** = 목표 시전밴드(A 0~0.4 / B 3~5 / C 8~15). 완료는 `DONE`(상세 = [DONE §4](_WIP_casting_expansion_pass_DONE.md)).
> - **효과** = 게임 툴팁(`skill_desc`) 원문. **특수 params** = 부수효과 필드(통폐합 판단 재료; 긴 건 `…` 절단, 상세는 `skillbooks.json`).
> - **관련 ENC** = encounters 전수 매핑(Phase B 밸런싱 맥락). `[uni]` = 적↔아군 통합. **Ally** = 적 미사용.
> - ⚠️ **cast·cd·dmg = 현황 참조**(§0 밸런싱 스킵) — Phase A는 **밴드(시전모드)**만 확정, 수치는 Phase B.
> - **적전용 AB-098(적힐)·AB-099(도발)는 아군 서브 없어 표 제외** — 텔레그래프만 확인(§5.3).

| AB · 이름 | 효과(툴팁요약) | 특수 params | equip | 시전 | cast·cd | 밴드 | dmg | 관련 ENC | 검토 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|
| **AB-002** Shield Bash | 대상 지역의 적을 강타해 피해를 주고 밀어낸다 | knockback_m=3.0 | Tank | Shared·EN-001 | A·2 | DONE | 1.0 | HARD-001·HARD-002·HARD-004·HARD-005·HARD-006·HARD-009·HARD-010·HARD-012·NORM-001·PAT-002·PAT-003 | [x] | |
| **AB-003** Arc Bolt Volley | 원거리 투사체를 발사해 대상에 피해를 준다 [uni] | lightning=True shock_s=2.0 | DPS/Nuker | Shared·EN-011 | 3.0s·6 | DONE | 1.0 | AMB-001·HARD-002·HARD-011·NORM-001·NORM-003·PAT-003 | [x] | |
| **AB-004** 전격 사격 | 에너지를 집중한 뒤 원거리 투사체를 발사해 착탄 지점에 광역 피해를 준다 (전격) | element=lightning shock_s=2.0 | Nuker/DPS | Shared·EN-002 | 4.0s·5 | DONE | 2.0 | BOSS-001 | [x] | **delivery=instant**(투사체 제거 — 번개만 내리꽂힘, DRIFT-088) |
| **AB-005** Melee Flurry | 대상 지역의 적을 강타해 피해를 주고 밀어낸다 | shape=rect length_m=5.0 width_m=3.0 si… | Nuker | Ally | 3.0s·10 | DONE | 3.0 | — | [x] | |
| **AB-006** Gap-Close Dash | 지정한 방향으로 순간이동한다 | blink_m=7.0 next_hit_bonus=0.2 | Nuker | Shared·EN-003 | A·4 | **A** | — | DEEP-001·HARD-003 | [x] | AB-061 흡수 · AB-013이 발전형 · DRIFT-085 |
| **AB-007a** Retreat Hop | 지정한 방향으로 순간이동한다 | away=True targeted=True blink_m=6.0 parting_shot_mul… | Nuker | Ally | A·8 | DONE | — | — | [x] | **적 조준 필수**(대상 없으면 시전 거부) · DRIFT-085 |
| **AB-007b** Retreat Reflex | 지정한 방향으로 순간이동한다 | away=True blink_m=6.0 auto_disengage=T… | Nuker | Ally | A·8 | DONE | — | — | [x] | **교전 상대** 반대 / 트랩이면 마지막 이동 반대 · DRIFT-085 |
| **AB-008** Slag Spit | 에너지를 집중한 뒤 원거리 투사체를 발사해 착탄 지점에 광역 피해를 준다 | radius_m=2.0 element=slag | DPS/Nuker | Shared·EN-004 **[uni]** | 3.0s·5 | **B** | 0.8 | HARD-008·MID-001 | [x] | **볼트 원형** · **스타터**(AB-028 대체) · unified · DRIFT-085/086 |
| **AB-009** Spawn Oil Patch | 지정 지점에 일정 시간 지속되는 장판을 생성한다 | medium=Oil ttl_s=8.0 | **DPS/Healer** | Shared·EN-004 | A·8 | **A** | — | HARD-008·MID-001 | [x] | 클래스 DPS/Healer(091) · Oil=OilSlick 관성강화·Ice=IceGlide 구분·곱연산·haste통합(092) · RX 전부반응(093) · A유지 · 초월 **safeslick** 아군안심기름(094). ⚠️F5 체감 대기 |
| **AB-010** Venom Spit | 대상에 맹독을 걸어 시간에 걸쳐 지속 피해를 준다 [uni] | poison_dps=1.35 poison_dur_s=8 poison_… | DPS | Shared·EN-005 | 2.0s·4 | DONE | 0.3 | HARD-001 | [x] | |
| **AB-011** Toll Stun | 대상 지역의 적을 강타하고 잠시 기절시킨다 | stun_s=1.4 | Tank | Shared·EN-006 | A·8 | DONE | 0.6 | DEEP-001·HARD-001·HARD-003 | [x] | |
| **AB-012** Hex Bolt | 대상에 취약 표식을 남겨 받는 피해를 증폭시킨다 | vulnerable_pct=0.15 duration_s=4.0 | Healer/Nuker | Shared·EN-007 | A·4 | ? | — | HARD-004·HARD-012 | [ ] | |
| **AB-013** Backstab Dash | 대상을 향해 돌진해 충돌 피해를 준다 | cone_deg=24 knockback_m=0.0 | Nuker | Shared·EN-008 | A·5 | ? | 1.5 | HARD-002 | [ ] | |
| **AB-028** Guard Break Rhythm | 대상 지역의 적을 강타해 피해를 주고 밀어낸다 | knockback_m=0.0 castTier=B rootDuringC… | DPS | Ally | A·6 | ? | 1.0 | — | [ ] | |
| **AB-030** Voltaic Interrupt | 대상 지역의 적을 강타하고 잠시 기절시킨다 | stun_s=0.5 | Nuker/DPS | Ally | A·8 | ? | 0.4 | — | [ ] | |
| **AB-032** Beacon Sight | 주변에 숨은 적을 드러낸다(정찰) | reveal_s=3.5 | Healer | Ally | A·10 | ? | — | — | [ ] | |
| **AB-033** 철벽 차단 | 대상에게 피해를 흡수하는 보호막을 부여한다 | shield_pct=0.1 duration_s=2.0 | Tank | Ally | A·8 | ? | — | — | [ ] | |
| **AB-034** 성벽 강타 | 지정 위치에 방벽을 소환해 적의 투사체와 진격을 막는다. 벽에 닿는 적은 중심을 잃고 잠시 스턴에 빠진다 (0.7초) | offset_m=2.0 width_m=3.5 height_m=2.0 … | Tank | Ally | A·10 | ? | — | — | [ ] | |
| **AB-035** 도전 선포 | 대상을 도발해 자신을 공격하도록 강제한다 | mark_threat=120.0 floor=50.0 | Tank | Ally | A·12 | ? | — | — | [ ] | |
| **AB-036** Spawn Water Patch | 지정 지점에 일정 시간 지속되는 장판을 생성한다 | medium=Water ttl_s=8.0 | Nuker/Healer | Shared·EN-007 | A·8 | ? | — | HARD-004·HARD-012 | [ ] | |
| **AB-037** Ember Lance | 지정 지점에 화염 피해를 주고 점화시킨다 | — | DPS/Nuker | Ally | A·5 | ? | 1.8 | — | [ ] | |
| **AB-040** Spawn Frost Patch | 지정 지점에 일정 시간 지속되는 장판을 생성한다 | medium=Ice ttl_s=9.0 | Nuker/Healer | Shared·EN-007 | A·9 | ? | — | HARD-004·HARD-012 | [ ] | |
| **AB-041** 빙결 파동 | 지정 지점에 냉기 피해를 주고 적을 둔화시킨다 | chill_dur_s=3.0 element=cold | DPS/Nuker **양쪽 주력** | Shared·EN-007 | 3.5s·5.5 | DONE | 1.2 | HARD-004·HARD-012 | [x] | sub_bands 제거(BIND-021 절대영도 복구) · **다중클래스 전-주력 최초 선례** · DRIFT-087 |
| **AB-042** Spawn Gust Patch | 지정 지점에 일정 시간 지속되는 장판을 생성한다 | medium=Wind **shape=rect** length_m=6.0 width_m=2.5 ttl_s=8.0 | Nuker/Healer | Shared·EN-004 | 1.0s·10 | DONE | — | HARD-008·MID-001 | [x] | **원형→방향성 rect 복도**(P=중앙·축 캐스터→P·근단최강 gradient) · **유닛 밀림 신설**(apply_drift) · aim 지면배치 분리 · 적 대칭 · DRIFT-098 |
| **AB-043** Spawn Briar Patch | 지정 지점에 일정 시간 지속되는 장판을 생성한다 | medium=Vegetation ttl_s=9.0 | Nuker/Healer | Shared·EN-007 | A·9 | ? | — | HARD-004·HARD-012 | [ ] | |
| **AB-044** Hush Ward | 대상 지역의 적을 침묵시켜 액티브 스킬 사용을 막는다 | silence_s=3.0 | Healer | Ally | A·12 | ? | — | — | [ ] | |
| **AB-045** Lifeline | 가장 위험한 아군을 안전한 위치로 견인한다 | relocate_m=5.0 castTier=B rootDuringCa… | Healer | Ally | A·14 | ? | — | — | [ ] | |
| **AB-046** Shield Wall | 잠시 동안 받는 피해를 감소시킨다 | damage_reduction=0.5 duration_s=2.0 | Tank | Ally | A·9 | ? | — | — | [ ] | |
| **AB-047** Aegis Pulse | 잠시 동안 받는 피해를 감소시킨다 | damage_reduction=0.2 duration_s=3.0 | Tank/Healer | Ally | A·12 | ? | — | — | [ ] | |
| **AB-048** Counter Stance | 잠시 동안 받는 피해를 감소시킨다 | damage_reduction=0.4 duration_s=1.5 | Tank | Ally | A·9 | ? | — | — | [ ] | |
| **AB-049** Ground Pound | 대상 지역의 적을 강타하고 잠시 기절시킨다 | stun_s=0.6 | Tank/Nuker | Ally | A·10 | ? | 0.3 | — | [ ] | |
| **AB-050** Warding Shout | 전방 부채꼴 범위의 적을 둔화시킨다 | cone_deg=60 slow_factor=0.7 slow_s=3.0… | Tank | Ally | A·7 | ? | — | — | [ ] | |
| **AB-051** Shield Throw | 대상을 자신 쪽으로 끌어당긴다 | pull_m=5.0 threat=60.0 | Tank/DPS | Ally | A·11 | ? | — | — | [ ] | |
| **AB-053** 작열 폭발 | 지정 지점에 화염 피해를 주고 점화시킨다 [uni] | — | DPS/Nuker | Shared·EN-015 | 3.0s·5 | DONE | 1.2 | — | [x] | |
| **AB-054** 절단 광선 | 전방으로 관통 빔을 채널링하며 지속 피해를 준다 | ticks=6 tick_interval_s=0.18 half_deg=… | DPS | Ally | A·6 | ? | — | — | [ ] | |
| **AB-055** 산탄 사격 | 원거리 투사체를 발사해 대상에 피해를 준다 | — | DPS/Nuker | Ally | A·4 | ? | 1.2 | — | [ ] | |
| **AB-056** Longshot Bolt | 원거리 투사체를 발사해 대상에 피해를 준다 | lightning=True | Nuker/DPS | Ally | A·4 | ? | 1.2 | — | [ ] | |
| **AB-057** Focus Fire | 대상에 취약 표식을 남겨 받는 피해를 증폭시킨다 | vulnerable_pct=0.15 duration_s=5.0 | Healer/Nuker | Ally | A·12 | ? | — | — | [ ] | |
| **AB-058** 방전 작렬 | 원거리 투사체를 발사해 대상에 피해를 준다 | lightning=True shock_s=2.0 | Nuker/DPS | Ally | A·8 | ? | 2.5 | — | [ ] | |
| **AB-059** 공허창 | 원거리 투사체를 발사해 대상에 피해를 준다 | — | Nuker/DPS | Ally | 5.0s·9 | DONE | 4.0 | — | [x] | |
| **AB-060** 파열 처형 | 체력이 낮은 대상을 처형해 큰 피해를 준다 | execute_under=0.3 execute_mult=2.0 on_… | Nuker | Ally | A·7 | ? | 1.0 | — | [ ] | |
| **AB-062** Smoke Veil | 잠시 은신해 적의 표적에서 벗어난다 | veil_s=1.5 | Nuker | Ally | A·14 | ? | — | — | [ ] | |
| **AB-064** 짧은 집중 | 집중해서 시전한다. 완료 시 주변 아군을 크게 치유한다 (집중 중에는 이동할 수 없고, 방해받으면 취소된다) | cast_range_disc_m=6.0 heal_pct=0.22 | Healer | Ally | 3.0s·6 | DONE | — | — | [x] | |
| **AB-065** 수호막 | 가장 다친 아군에게 보호막을 두른다. 보호막이 끝날 때, 그동안 막아 낸 피해량만큼 치유한다 | shield_pct=0.16 ward_s=4.0 | Healer | Ally | A·9 | ? | — | — | [ ] | |
| **AB-066** 긴 집중 | 집중해서 시전한다. 완료 시 주변 아군을 크게 치유한다 (집중 중에는 이동할 수 없고, 방해받으면 취소된다) | cast_range_disc_m=6.0 heal_pct=0.55 | Healer | Ally | 10.0s·14 | DONE | — | — | [x] | |
| **AB-067** Aegis Blessing | 대상에게 피해를 흡수하는 보호막을 부여한다 | shield_pct=0.12 duration_s=6.0 | Healer | Ally | A·9 | ? | — | — | [ ] | |
| **AB-068** Warding Sigil | 잠시 동안 받는 피해를 감소시킨다 | damage_reduction=0.15 duration_s=4.0 | Healer | Ally | A·10 | ? | — | — | [ ] | |
| **AB-069** Swift Grace | 잠시 동안 공격·이동 속도를 높인다 | haste_pct=0.2 duration_s=4.0 | Healer | Ally | A·11 | ? | — | — | [ ] | |
| **AB-070** Purge Light | 대상에 걸린 강화 효과를 정화(제거)한다 | — | Healer | Ally | A·13 | ? | — | — | [ ] | |
| **AB-071** Bulwark Bash | 대상 지역의 적을 강타해 피해를 주고 밀어낸다 | knockback_m=2.0 | Tank/Nuker | Ally | A·6 | ? | 1.0 | — | [ ] | |
| **AB-072** 우박 세례 | 지정 지점에 냉기 피해를 주고 적을 둔화시킨다 | chill_dur_s=3.0 | DPS/Nuker | Ally | A·7 | ? | 1.6 | — | [ ] | |
| **AB-073** Overcharge | 원거리 투사체를 발사해 대상에 피해를 준다 | lightning=True shock_s=2.0 | Nuker/DPS | Ally | A·10 | ? | 3.5 | — | [ ] | |
| **AB-074** Guardian Oath | 잠시 동안 받는 피해를 감소시킨다 | damage_reduction=0.3 duration_s=6.0 | Tank | Ally | A·16 | ? | — | — | [ ] | |
| **AB-075** Blessed Barrier | 대상에게 피해를 흡수하는 보호막을 부여한다 | shield_pct=0.08 duration_s=5.0 | Healer | Ally | A·14 | ? | — | — | [ ] | |
| **AB-100** Pounce | 대상을 제자리에 고정한다 | pin_s=0.6 | Nuker | Shared·EN-3RD-01 | A·6 | ? | 1.2 | 3RD-001 | [ ] | |
| **AB-101** Scent of Blood | 대상에 혈향을 묻혀 추적 표식을 남긴다 | scent_s=6.0 | Healer | Shared·EN-3RD-01 | A·10 | ? | — | 3RD-001 | [ ] | |
| **AB-102** Snare Net | 대상을 속박해 이동을 막는다 | root_s=2.0 | Tank | Shared·EN-3RD-02 | A·9 | ? | 0.2 | 3RD-001 | [ ] | |
| **AB-103** Tether | 대상과 사슬로 연결해 묶어 둔다 | tether_s=4.0 | Nuker | Shared·EN-3RD-02 | A·8 | ? | 0.4 | 3RD-001 | [ ] | |
| **AB-104** Rampage | 대상을 향해 돌진해 충돌 피해를 준다 | cone_deg=40 knockback_m=0.9 | Tank | Shared·EN-3RD-03 | A·7 | ? | 1.1 | 3RD-001 | [ ] | |
| **AB-106** Devour | 체력이 낮은 대상을 처형해 큰 피해를 준다 | execute_under=0.3 execute_mult=2.0 on_… | Nuker | Shared·EN-3RD-03 | A·8 | ? | 1.0 | 3RD-001 | [ ] | |

> **통폐합 후보(효과 겹침 — Phase A 판단):** ~~볼트 7~~ → **원형-변형 체계로 확정**(DRIFT-085): **원형 = AB-008**(집중→투사체→광역) · 변형 = AB-003/004/056/058/073(+전격) · AB-055/059(비전격). 툴팁은 params 조립이라 변형이 늘어도 자동 정렬. 잔여 = 각 변형의 **차별축**(밴드·딜·반경) 판정 · ~~존 5(AB-009/036/040/042/043)~~ → **통합 폐기**(2026-07-21, kind≠역할 · 각자 개별 판정) · 피해감소 6(AB-046/047/048/068/074/047) · 실드 3(AB-033/067/075) · 취약 2(AB-012/057) · 처형 2(AB-060/106) · ~~순간이동 4~~ → **이동 계열 = 벡터×페이로드 2×2로 확정**(접근·무피해 AB-006[적] / 접근·피해 AB-013 / 이탈·피해 AB-007a·b / 이탈·무피해 = 의도적 공백. AB-061 폐기 — DRIFT-085) · 냉기 2(AB-041/072) · 화염 2(AB-037/053). 같은 툴팁 다수 = **통합/차별화 판정 대상**.

### 5.3 진행표 (Phase B — ENC 실전 밸런싱)

> **2026-07-15 전면 재구성:** 전 ENC 구성을 실제 데이터(`data/slice01/encounters/*.json` × `enemies.json` 킷)로 매핑해 **신규 캐스터 AB가 있는 ENC만** 남겼다. fodder 전용 구성(EN-010·012·013 = 능력 **없음**, EN-011=AB-003 기판정)은 판정 대상이 아니다 — 기존 "ENC-NORM-002가 다음" 계획은 **폐기**(신규 AB 0).

| ENC | 판정 스킬(신규) | 상태 |
|-----|------------------|------|
| ENC-NORM-001 | AB-002 · AB-003 · AB-005 · (AB-099 적전용) | ✅ 완료 → [DONE §6](_WIP_casting_expansion_pass_DONE.md) (AB-002 A유지 · AB-003 통합캐스트 · AB-005 커밋버스트 / AB-099 무변경) |
| ENC-HARD-001 | AB-011 · AB-010 · AB-039 · AB-007 | ✅ 완료 → [DONE §7](_WIP_casting_expansion_pass_DONE.md) (AB-011 A유지 · AB-010 통합B+스택독 · AB-039 병합→폐기 · AB-007 auto-trigger+007a/007b) |
| ENC-MID-001 | AB-008 · AB-009 · AB-042 | ✅ 완료 → [DONE §8](_WIP_casting_expansion_pass_DONE.md) (AB-008 볼트원형 · AB-009 A유지+RX확장 · AB-042 rect 바람복도+1s캐스트) |
| ENC-HARD-002 | AB-013(돌진) | ⬜ |
| ENC-HARD-003 · DEEP-001 | AB-006(누커 이동) | ✅ Phase A 완료(DRIFT-085) — 적측 무변경 확정 → **Phase B 판정 대상 0** |
| ENC-HARD-004 · HARD-012 | AB-012(취약) · AB-036 · AB-040 · AB-043 | ⬜ — 각 존 **개별 판정**(상속 폐기 2026-07-21) |
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

## 8. ENC-MID-001 → **[DONE 파일 §8](_WIP_casting_expansion_pass_DONE.md)로 이관** ✅

> 확인 스킬표(AB-008·AB-009·AB-042) + 존 통합 정책 폐기 결정 + 코드 실사(surface_grid 3차 갱신 포함) + 파손 2건 +
> "가설 대비 실제 결정"은 DONE 파일에 있다. 요약은 §5.3 진행표 참조.
> **여기서 나온 전역 파생:** ① **존 통합 정책 폐기**(kind≠역할) ② zone cast 스키마 **형상 축 신설**
> (`shape`/`length_m`/`width_m` → DRIFT-098 **OPS_30 전파 후보**) ③ rect 존 **지면배치 조준 분리**
> (`AimMarker.show_zone_rect` — "rect = 캐스터에서 뻗는 빔" 가정을 깸) ④ **환경 드리프트 API**(`apply_drift`)를 일회 넉백과 분리.

---

## 9. Stop-line

- 스킬 편집·게이트·원장/DRIFT 기록 = **사용자 스킬별 컨펌 후.**
- spec md 편집·OPS_30 전파·커밋·푸시 = **명시 승인 후에만.** 모호하면 분석·질문 우선.
- 이 파일 + [DONE 파일](_WIP_casting_expansion_pass_DONE.md)은 **작업 산출물 임시 보관** — 패스 종료 시 **둘 다 삭제**, 정본은 DRIFT-078.
- **2-파일 동기화:** ENC 컨펌 시 §2.4 이동 절차를 반드시 따른다(활성→DONE). 완료 상세가 활성에 남으면 파일이 다시 비대해져 분리 취지가 무너진다.

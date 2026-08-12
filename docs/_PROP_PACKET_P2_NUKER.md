# 전파 패킷 — P2 누커 패스 + 전수 위생 (DRIFT-121~134)

> **용도:** spec repo(`project_tdc` @`staging`)에서 `OPS_30`(impact_scan → 매퍼×4 → DecisionLog `DEC-` → TODO → SpecScopeTracker) → `OPS_20`(lint) → PR로 집행할 **역전파 목록**.
> **이 레포는 spec md를 직접 편집하지 않는다**(AGENTS.md §Spec drift). 집행 후 [`spec_ref.json`](../spec_ref.json) 핀 bump가 이 레포의 유일한 spec-관련 쓰기.
> ✅ **집행 완료 (2026-08-12)** — spec `204c20c` · `DEC-20260812-001` · 25파일(신규 `ENC-NORM-004` 포함).
> 검증: `mapper_sync_check` 0건 · `RelationGraph` 재생성 · `spec_xref_check` **BLOCKER 0**(잔여 NOTE 1건 `F-025→F-023`은 기존 부채).
> **핀 bump 완료:** `3503004` → `204c20c`. 아래 본문은 **집행 기록**으로 보존한다(§5 미판정 이월은 여전히 유효).
>
> **패킷 작성:** 2026-08-12 · **근거:** [SPEC_DRIFT.md](SPEC_DRIFT.md) DRIFT-121~134

---

## 0. 한눈에

| # | 항목 | 분류 | 대상 문서 | 근거 |
|---|---|---|---|---|
| **A** | AB-062 은신 오프너 재정의 | rule | `AB-062` · `EFFECT-CORE` | DRIFT-121 |
| **B** | 단일 대상 = 유닛 잠금 조준(`single_target`) | rule/schema | `D-016` · 대상 12종 | DRIFT-122 |
| **C** | 배율·쿨 **진영 파리티** + 「적 역할 = 아군 클래스의 거울」 | rule | `D-016` · `EN-COR-000` · `ENC-000` | DRIFT-124 |
| **D** | 적 표적 선정 = 클래스 우선순위 × 인지 범위 | rule | `F-022` §3.6 · `EN-AI-000` | DRIFT-125 |
| **E** | `ENC-NORM-004` 신설 + **authored↔generated 이원 구조 명문화** | scope/doc | `ENC-000` · 신규 `ENC-NORM-004` | DRIFT-126 |
| **F** | AB-056 전격 → **냉기** · 속성=즉시효과 정합 규약 | rule | `AB-056` · `EFFECT-CORE` | DRIFT-128 |
| **G** | **누커 = 캐스터**(즉발은 무피해 반응·이동 4종만) | rule | `D-012` · `D-016` | DRIFT-129 |
| **H** | AB-060 아군판 폐기 | scope | `AB-060` · `D-016` | DRIFT-130 |
| **I** | `Tethered` 끌려오기 추가 | rule | `AB-103` · `APPLY-TETHER-4S` | DRIFT-132 |
| **J** | AB-030 인터럽트 → **침묵 「제압」** + `Silenced`가 진행 중 시전을 끊음 | rule/scope | `AB-030` · `STATUS-ACTOR-CORE` | DRIFT-133 |
| **K** | **카탈로그 위생 4종**(cooldown 예시화 · displayName 대조 제외 · rangeBand·클래스 정정 · AB 번호 4분류) | rule/doc | `D-016` | DRIFT-134 |

> **튜닝 수치는 이 패킷에 없다** — AGENTS.md §Spec drift 분류상 전파 금지(로깅만). DRIFT-123/127/131이 그쪽이다.

---

## 1. 개별 능력 문서 수정

### A. `AB-062` Smoke Veil — 순수 이탈기 → **은신 오프너** (DRIFT-121)
- `abilityKind`: `Mobility` → **피해 페이로드를 담을 수 있는 값으로 재판정 필요**(현 enum에 슬롯 없음)
- `effects`: `[APPLY-STEALTH-SHORT-1P5S]` → **효과 ID 자체가 부적합** — 이름이 `SHORT-1P5S`(1.5초)인데 게임은 **60초**다. 신규 효과 ID 발급 권장(예: `APPLY-STEALTH-VEIL`) + 첫 타격 증폭·자동공격 정지를 표현
- 거동: 은신 중 **평타·정체성 정지** · **첫 타격에 해제**(시전 시작 아님) · 재입력 = 무비용 취소(증폭 폐기) · **스왑해도 유지**(「안전 주차」 = 의도)
- **부수 발견(스펙 측 수정 필요):** `EFFECT-CORE`의 `APPLY-STEALTH-SHORT-1P5S`가 `evasionBonus: abilityDefined`를 정의하는데 **구현엔 회피 개념이 없다**(은신 = 적 표적 후보 제외뿐). 필드 삭제 또는 구현 요구로 판정

### F. `AB-056` Longshot Bolt — 전격 → **냉기** (DRIFT-128)
- `element`: `lightning` → **`cold`**, 상태 `Shock` → **`Chilled`**(2.0s)
- 사유: 073과 lightning·range15·즉발·단일이 전부 같고 **지속 화력도 0.244↔0.278로 동일** = 형태 없이 눈금만 다른 중복. 냉기 전환으로 *멀리서 얼려 묶는 견제* ↔ *멀리서 크게 지지는 저격* 으로 분화
- **동반 규약(신규):** *"`element`를 선언하면 그 속성의 **즉시 효과가 실제로 부여**되어야 한다."* — `lightning`만 `dur_default: 0.0`이라 `shock_s`를 빠뜨리면 **툴팁은 감전을 약속하고 코드는 아무것도 안 한다**. 실제로 `AB-056`·`AB-054` 2건이 그 상태였다

### H. `AB-060` Rupture Strike — **아군판 폐기** (DRIFT-130)
- `usable_by_ally`: `true` → **`false`** (또는 카탈로그에서 제거)
- 사유: `AB-106`과 `kind·cast·mult·radius·execute_under·execute_mult·tier·equip·잠금`이 전부 동일해지고 실차이가 흡혈 하나뿐이었다. **106은 Shared(EN-3RD-03)라 못 지우고 060은 Ally-only**라 제거
- 게임 ID는 `id_registry` 등록만 잔존(정식 제거는 스펙 배치 몫)

### I. `AB-103` Tether — **끌려오기 추가** (DRIFT-132)
- 스펙 Draft(leash 8m · break DoT 3dps)는 **그대로 구현**했다 — 종전엔 `Tethered`가 `MOVE_MULT`에도 없는 **순수 표시용 배지**여서 스킬의 페이로드 전체가 없었다
- **스펙 밖 추가:** leash 밖일 때 **시전자 쪽으로 끌림(2.5m/s)** → `APPLY-TETHER-4S` / `AB-103` effects에 반영 필요
- 참고: **`AB-106`의 `ON-KILL-FEED` 쿨 환급**도 미구현이었다(회복만 있었다). 스펙대로 구현(남은 쿨 50% 환급) — 스펙 수정 불요

### J. `AB-030` Voltaic Interrupt → **전격 제압** (DRIFT-133)
- `abilityKind` 유지(`Control`) · `effects`: `[INTERRUPT-CAST, DMG-SINGLE-0P4X-CHIP, APPLY-SHOCK-2S]` → **`[DMG-SINGLE-0P4X-CHIP, APPLY-SILENCE-3S]`**
- `applies_status`: `[Shock]` → **`[Silenced]`** · `emits_event`에서 `CastInterrupted`·`LightningHit` 재판정
- **사유(실측):** 적이 쓰는 **27종 중 `cast 1.0`으로 끊을 수 있는 건 `AB-012` 단 1종**이었다(텔레그래프가 0.2~1.0s에 몰림). 즉발인 **Tank `AB-011`이 오히려 더 잘 끊는** 역전 상태 → 누커는 저격 계열이므로 「끊는다」가 아니라 **「제압한다」**로 재정의
- **동반 규약:** `STATUS-ACTOR-CORE`의 `Silenced` 정의(*"액티브 스킬 시전 불가"*)를 **"진행 중인 시전도 중단"**까지 넓힌다. 단 *반응 인터럽트가 아니다* — 침묵 스킬 자신이 캐스트를 가져 노리고 쓸 수 없고, **얻어걸릴 때의 보너스**다

---

## 2. 규칙·스키마

### B. 단일 대상 = **유닛 잠금 조준** (DRIFT-122) — `D-016`
- `targeted`(현행)는 **지면 조준**이고, 클릭한 유닛을 잠그는 개념이 스펙·코드 어디에도 없었다 → **`single_target` 필드 신설**
- 규칙: 잠금 스킬은 **적 유닛을 찍어야만 시전**되고 **빈 지면 클릭 = 무비용 취소**. 투사체는 대상을 **유도 추적**
- **대상 12종:** `AB-004`·`012`·`013`·`030`·`056`·`057`·`059`·`073`·`100`·`103`·`106` (+`AB-060` 폐기 전 포함)
- **판정 기준을 `kind`로 두지 않는다** — 같은 `skillbook_bolt`에 광역(AB-003 r4.0)이 섞여 있고, **반경을 튜닝하다 조준 방식이 조용히 바뀌면 안 되기 때문**

### C. **진영 파리티 + 역할 대칭** (DRIFT-124) — `D-016` · `EN-COR-000` · `ENC-000`
- **규약:** *"같은 AB는 **배율·쿨이 진영 불변**이다. 진영별 세기 차이는 **유닛 기본치**(`contactDamage`/`basicDamage`)로 낸다."*
- 근거: `enemy_unit.basic_damage`는 `contact_damage`의 **읽기 별칭**이라 두 진영의 피해식이 `기본치 × 배율`로 **완전히 동일**하다. 배율에 세기를 얹으면 두 축이 섞여 스킬 하나를 튜닝할 때마다 진영 밸런스가 흔들린다
- **상위 원칙(신규 명문화):** **적 role = 아군 클래스의 거울**(`nuker`=저격 · `support`=힐 · `cc`=제어). 위 파리티는 이 사실의 **귀결**이다 → 적 role 분류와 파티 클래스의 대응을 스펙이 명시할 것
- ⚠️ **쿨 파리티 잔여 3건**(게임에도 남아 있음): `AB-002`(2/3) · `AB-011`(8/5) · `AB-067`(9/10) — 스펙·게임 합동 판정 필요

### D. 적 표적 선정 (DRIFT-125) — `F-022` §3.6 · `EN-AI-000`
- 위협 비교식에 **클래스 축** 신설: `threat × {Healer 3.0 · Nuker 2.2 · DPS 1.6 · Tank 1.0}`
- **하드 오버라이드가 아니라 배율**인 이유: 탱커 `threatMult`가 4.5~6.0 vs 딜러 0.6이라 **생성량이 이미 7~10배** — 배율 폭(3배)보다 커서 **탱커가 붙으면 반드시 되찾는다**. 이 표가 지배하는 구간은 교전 초반·탱커가 놓친 후열·원거리 몹
- 후보 집합을 **인지 범위**로 한정(교전 중이거나 16m+LOS) — 없으면 벽 너머 어그로가 새서 *저격*이 아니라 **텔레포트 어그로**가 된다

### G. **누커 = 캐스터** (DRIFT-129) — `D-012` · `D-016`
- **클래스 방향성 확정:** 누커 주력은 **즉발을 갖지 않는다.** 예외는 **무피해 반응·이동 4종**뿐 — `AB-062`(은신) · `AB-007a/b`(이탈) · `AB-006`(접근)
- 적용 전 상태: 주력 17종 중 **12종(71%)이 즉발**이었다
- **[[DRIFT-120]] ③의 범위 축소:** *"즉발은 도발·DR·반격·방벽·정화 같은 **반응·유지형**에 정당한 자리"* 는 **계열 한정**임을 명문화 — 누커 같은 캐스터 계열엔 적용되지 않는다(그 판정이 누커에서만 어긋나 있었다)

### E. `ENC-NORM-004` 신설 + **이원 구조 명문화** (DRIFT-126) — `ENC-000`
- **신규 ENC:** `ENC-NORM-004` Cinder Line — `EN-001`×1(elite) + **`EN-015`×1(specialist)** + `EN-010`×2 + `EN-013`×1 · `RP-02` · `mechanicAxes 2`
  - 사유: Normal authored 3종이 **전부 Specialist 0**이라 *"후열 캐스터를 먼저 끊는다"* 를 **Hard(`ENC-HARD-001`)에 가서야** 배웠다. 이건 그 Normal판
  - fodder를 근접만으로 짠 건 §3 안티패턴 회피 — `EN-011`은 `BackPester`(**7.5m 원거리**)라 9m 캐스터와 겹치면 *"원거리 poke 이중"* 에 걸린다
- **🐞 미문서화된 실장 사실:** `ENC`의 authored `units`는 **런에서 §2 조합 제너레이터가 대체**하고(BOSS·3RD 제외), **샌드박스 스폰에서만** 그대로 쓰인다 → *"authored units = 검증·체감용 · 런은 제너레이터"* 를 ENC 문서에 명시할 것
- ⏭ **맵 개편 시 함께:** `difficulty × pool_slot` 커버리지 구멍 — **Normal 런은 보스방이 뽑혀도 보스전이 안 열리고**(P-BOSS-01은 Hard 행뿐) Hard 런은 심층·입구가 빈다(가중 12%). `LDG-SPAWN-DEMO-001` §2 + AGENTS.md P2-S1 DoD *"All non-empty LDG spawn rows resolve"* 와 어긋남

---

## 3. K. 카탈로그 위생 4종 (DRIFT-134) — `D-016`

### K-1. `Catalog` 블록의 `cooldown_s` = **design example** 명문화
- 49종 중 **21종(43%)이 게임과 불일치** — 카탈로그의 쿨 열이 사실상 거짓이었다. `## Draft Parameters (design examples — not runtime SSOT)` 섹션과 달리 **Catalog 블록엔 예시 표기가 없어 SSOT처럼 읽힌다**
- **판정(사용자): 게임이 정본.** → Catalog 블록에 예시 표기 추가. 이후 쿨 불일치는 드리프트로 세지 않는다

### K-2. `displayName` — **대조 축에서 영구 제외**
- 게임은 표시명을 **전부 한글**로 통일(37종 변경), 스펙은 영문 카탈로그 유지 → 두 값은 영구히 갈라진다. **ID로 대응**하고 이름은 대조하지 않는다는 규약을 명시
- 게임 측 이름↔효과 교정 5건(`AB-033`·`034`·`051`·`064/066`·`065`)은 **한글명 재작명으로 해소** — 스펙 영문명은 그대로 두어도 무방하나, `AB-051`은 스펙 `notes`도 확인 권장(게임 `id_registry` 노트가 `skillbook_pull`이라고 **오기**하고 있었다)

### K-3. `rangeBand` · 장착 클래스 정정 (게임 정본)

| AB | 필드 | 스펙 | → 게임 | 문서 |
|---|---|---|---|---|
| AB-005 | rangeBand | Mid | **Melee** | `AB-005_MeleeFlurry.md` |
| AB-010 | rangeBand | Long | **Mid** | `AB-010_PoisonSting.md` |
| AB-011 | rangeBand | Melee | **Mid** | `AB-011_BellRing.md` |
| AB-102 | rangeBand | Mid | **Long** | `AB-102_SnareNet.md` |
| AB-106 | rangeBand | Melee | **Mid** | `AB-106_Devour.md` |
| AB-010 | 클래스 | DPS·Nuker | **DPS** | 동상 |
| AB-041 | 클래스 | DPS·Healer·Nuker | **DPS·Nuker** | `AB-041_GlacialBolt.md` |

> `rangeBand`는 표기가 아니라 **잠행 결속(IDA-029)의 보상 계수를 정하는 실효 필드**다(Melee 0.15 / Mid 0.25 / Long 0.5). AB-106은 **10m에서 쏘면서 "이미 근접이니 보상 최소"** 를 받고 있었다.
> ⏳ **미판정 1건:** `AB-035`(Melee / 5.0m) — Tank 전용이라 밴드가 아무 계수도 구동하지 않는다. **근접 상한을 몇 m로 볼지** 정해지면 함께 정리.

### K-4. `usable_by_ally` / `usable_by_enemy` 정정

| AB | 스펙 | 게임 실태 | 조치 |
|---|---|---|---|
| `AB-007` | ally=true | **`AB-007a`/`AB-007b`로 분할 사용** | 원 ID를 분할 안내로 전환(DRIFT-085/100) |
| `AB-007b` | enemy=true | 적 정의 없음 | `usable_by_enemy` → false |
| `AB-039` | ally=true | **폐기**(AB-010에 병합) | ally → false |
| `AB-105` | ally=true | 아군판 없음(`enemy_frenzy` 전용) | ally → false 또는 구현 백로그로 |

### K-5. **AB 번호 4분류 + 재사용 금지** (`D-016` §Validation)
- 사용자 제기: *"중간에 구멍나 있으니까 나중에 코드 까보면 왜 비지 라는 물음이 생길 것 같아서"*
- **재번호는 하지 않는다** — 참조 **5,194건**(스펙 2,373 + 게임 2,432 + **git 커밋 389 = 영구히 못 고침**) + 스펙 **파일명 97개가 ID 자체**. 이번 감사 55건은 전부 **내용** 문제라 번호를 바꿔도 하나도 안 풀린다. **ID는 정렬 키가 아니라 불변 식별자**
- **번호 상태 4분류**(1~111을 빈틈없이 덮음):

| 분류 | 종수 | 내용 |
|---|---|---|
| 구현 | 82 | 게임 `ability_ids` |
| **미구현 백로그** | **17** | AB-076~088·090·091·096·097 — 스펙 정의·게임 미등록 |
| **영구 결번** | **27** | 아래 사유표 |
| IDA 이관 | 10 | 정체성 프리픽스 |

- **결번 27개 사유(전부 규명됨 — 무작위가 아니었다):**
  - **IDA 이관 9** — AB-020·021·022·024·025·026·029·031·052 → `IDA-###`(DecisionLog *"번호 유지(AB-020→IDA-020)"*, IDA 문서 10종이 정확히 그 번호에 있다)
  - **적 기본타 스텁 폐지 4** — AB-001·014·015·016 → `rom_*` 아키타입(`EN-COR-000`)
  - **설계 기각 1** — AB-063 Cataclysm
  - **신설 즉시 철회 2** — AB-107·108(DRIFT-111, AB-053/041과 중복 판명)
  - **미사용 11** — AB-017·018·019·023·027·038·089·092·093·094·095(흔적 0)
- **규약:** 폐기·이관 ID는 **영구 결번**, 재사용 금지. 신규는 **끝번호에서만**(현재 최대 AB-111 → 다음 AB-112)

---

## 4. 집행 순서 제안

1. **K-1/K-2 먼저** — 이걸 확정해야 이후 대조에서 쿨·이름이 노이즈로 안 뜬다
2. **K-3/K-4** — 기계적 필드 정정(값이 이미 확정됨)
3. **A·F·H·I·J** — 개별 능력 문서(효과 ID·상태 변경 수반, `EFFECT-CORE`/`STATUS-ACTOR-CORE` 동반 수정)
4. **B·C·D·G** — 규칙/스키마(영향 범위 넓음, `impact_scan` 필수)
5. **E** — ENC 신설 + 이원 구조 문서화(맵 개편과 묶어도 됨)
6. **K-5** — 번호 정책(`D-016` §Validation Rules)
7. `OPS_20` lint → `staging` PR → 머지 후 이 레포 [`spec_ref.json`](../spec_ref.json) 핀 bump

## 5. 게임 측 미판정 이월

- `AB-035` rangeBand(Melee / 5.0m) — 근접 상한 정의 대기
- 쿨 파리티 잔여 3건 — `AB-002`·`AB-011`·`AB-067`
- `EN-009` `bucket` — 게임 `Fodder` ↔ 스펙 §1 `SwarmTrash`=Specialist. 고치면 **생성 조합이 바뀐다**(`encounter_generator._bucket_pools`)
- `EN-012` HP 500(fodder인데 Trash 중앙값의 2.3배) — "일반몹" 정의를 혼자 무너뜨림
- `safeslick` variant 코드 — `AB-009` 아군판 폐기로 고아가 됨(소모품 기름으로 재배선 or 폐기)
- 보스 전용 유닛 신설 + `ENC-BOSS-001` 재배선(현재 EN-002를 보스로 쓰는 건 임시)
- 맵 개편 시: `difficulty × pool_slot` 커버리지 구멍

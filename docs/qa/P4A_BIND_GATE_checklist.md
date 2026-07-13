# P4a Kit Binding — Playtest Gate Checklist (QA-005 §2.12 `T-P4A-BIND-GATE`)

> **감독(사람)이 채우는 폼.** 이 게이트가 P4b 전면 경제 이관의 분기점이다.
> **Pass 판정 → Stage 2(P4b) 진행 / Fail → 오버레이 단순화 후 재테스트, 타 클래스 확장 금지** (`EXPANSION_P4B` §금지).
> spec: `77d9532` · `QA-005 §2.12` · `ROLE-010 §4.5` · `docs/combat/bindings/` (비정본 파일럿).
> 구현: P2-S8a (Stage 0+1). 결속 = 런타임 오버레이(`binding_overlays.gd`), AB 파일 복제 없음.

## 실행 방법 (combat sandbox)
1. 샌드박스 씬 진입 → 좌측 패널 **"결속 파일럿 (Tank P4a)"** 섹션.
2. **ANCHOR** / **BEACON** / **BASE (결속 OFF)** 버튼 → Tank에 gear(GEAR-011/012) + Q/E/R=AB-033/034/035 세팅 + 결속 게이트 토글.
3. **숫자 1~4로 Tank에게 스왑** → Q/E/R로 서브 시전, 오버레이 체감.
4. 픽스처당 3런(ANCHOR ON / BEACON ON / BASE OFF), 각 ENC에서 관찰.

## 관찰할 오버레이 (ON일 때만)
| 픽스처 | 슬롯 | 오버레이 | PAYOFF (base 대비 추가분) |
|--------|------|----------|---------------------------|
| ANCHOR (GEAR-011·IDA-020) | Q AB-033 | BIND-001 | Intercept 3회 누적 → 0.8s **Stun** (8s ICD) |
| | E AB-034 | BIND-002 | Barrier → **threat pulse +50 + threat floor +25** 2s |
| | R AB-035 | BIND-003 | Mark → 시전자 **Shield 60 / 5s** |
| BEACON (GEAR-012·IDA-021) | Q AB-033 | BIND-004 | Intercept → **threat floor +15%** 2s |
| | E AB-034 | BIND-005 | wall stagger **knockback +25%** |
| | R AB-035 | BIND-006 | Mark 대상 8s 내 처치 → **AB-035 쿨 −40%** |
| BASE | — | (없음) | base AB만 — 회귀 기준선 |

> 수치는 `BIND-###` 설계 예시(튜닝). BIND-005 knockback은 파일럿 근사(시전 시 전방 콘 push). castTier는 전부 **A(즉발)** — wind-up 없음.

---

## 게이트 판정 (감독 기입)

### Gate 1 — 빌드 명명 *(Pass 필수)*
플레이어가 **Anchor vs Beacon 빌드 의도를 말로 구분** 가능한가? (Fail: 구분 불가)
- 판정: ☐ Pass ☐ Fail
- 메모:

### Gate 2 — BASE가 Normal 클리어 *(Pass 필수)*
`TANK-P4A-BASE`(결속 OFF)가 **ENC-NORM-001을 서브 1회↑ 사용해 클리어**하는가? (Fail: 결속 없이 Hard만 가능)
- 판정: ☐ Pass ☐ Fail
- 메모:

### Gate 3 — Hard payoff *(Pass 필수)*
ANCHOR **또는** BEACON이 `ENC-HARD-001`에서 BASE 대비 **문서화된 payoff ≥1**을 보이는가? (Fail: 체감 차 없음)
- 판정: ☐ Pass ☐ Fail
- 관찰된 payoff (어느 BIND-###):

### Gate 4 — 첫런 과부하 없음 *(회귀)*
첫런 스타터(AB-033 Q만) 프로필이 `ENC-HARD-001` 클리어 **강제가 아닌가**? 튜토리얼 블로킹 없음? (Fail: 블로킹)
- 판정: ☐ Pass ☐ Fail
- 메모:

### Gate 5 — base 인식성 *(회귀)*
루팅한 shared **AB-033 base 동작이 결속 설명 전에 인식**되는가? 결속이 "base 교체"로 느껴지지 않는가? (Fail: 교체 느낌)
- 판정: ☐ Pass ☐ Fail
- 메모:

---

## DoD & 분기
- **Gate 1·2·3 Pass + 4·5 회귀 통과 → PASS.** → Stage 2(P4b 전면 이관) 착수 승인. Nuker/DPS/Healer 로드맵(Stage 3) 개방.
- **어느 하나 Fail → FAIL.** → 해당 `BIND-###` 오버레이 **단순화** 후 재테스트. **타 클래스 본문화 금지** (게이트 재통과 전까지).
- 결과는 `ROLE-010 §4.5` + 본 파일 + ENC Notes 1줄로 기록. 최악(반복 Fail): 결속 컨셉 폐기 판정.

## 최종 판정
- 날짜: 2026-07-05
- 종합: ☑ **PASS** → Stage 2/3 개방 ☐ FAIL → 오버레이 단순화 재테스트
- 감독 노트: 결속 개념이 잘 반영됨(방벽 충전·표식 규약, identity 선언→서브 조건부→캡스톤). 개별 스킬 튜닝 여지는 남으나 파일럿 재미/명료성 통과. 다음 = **Stage 3(Nuker/DPS/Healer 결속 확장)**.

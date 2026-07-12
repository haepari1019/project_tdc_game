# _PROP PACKET — DRIFT-082 Shared 스킬 통합 전파 (배치용)

> **무엇:** 게임측 rule/design 변경 **DRIFT-082**(Shared 스킬 적↔아군 통합 — AB-003 파일럿 · CastContext)를 스펙 SSOT에 반영하기 위한 **적용-준비 packet**. 실제 편집 문안까지 확정.
> **⛔ 적용 시점(Stop-line):** **지금 적용 금지.** ① AB-003 통합 캐스트 인게임 플레이테스트(적 투사체가 파티 타격·캐스트바 파리티 체감) 확정 **AND** ② P4b 정본화 스펙 세션에서 **DRIFT-075(부모 원칙)·078(캐스팅 패스)·079/080과 함께 배치**. (godot 헤드리스 부재로 이번엔 로드 검증만.)
> **적용 위치:** 스펙 레포 `E:/Game_design/project_tdc_spec`(staging). 게임 레포는 반영 후 `spec_ref.json` 재핀만.
> **작성:** 2026-07-12 · 게임 pin `staging@2bf37b2` · 브랜치 `wip/casting-ab054-overdrive-20260712`.

## 핵심 결정 (전파할 원칙)
**Shared 스킬(적도 사용)은 "같은 ID = 같은 거동" — 단일 정의에서 적/아군 동일 발현.** 아키텍처 = **"능력 해소 1개 + 캐스팅 프론트엔드 2개"**:
- **해소(통합):** 효과·VFX·캐스트시간(cast_s)·damage_mult·delivery·상태 — 단일 정의. base는 시전자 속성(`basic_damage` vs `contact_damage`).
- **선택/조준(진영별):** 플레이어 수동 vs 적 AI 타겟팅·이동 — 본질적으로 다르므로 유지.
- 파일럿 = **AB-003만**. 잔여 대칭 subset(strike/stun/poison/cold) = follow-on.

## 왜 지금 piecemeal OPS_30을 안 하나
1. **미검증** — AB-003 통합 캐스트 인게임 미확인(로드 PASS만).
2. **§3.6.1 telegraph 모델 변경은 부모 원칙(DRIFT-075) 배치와 함께** 나가야 SSOT가 조각나지 않음 — 079/080과 동일 배치.

---

## 타깃 1 — `docs/combat/abilities/AB-003_ArcBoltVolley.md` (AB-003 SSOT)
**변경 성격:** 통합 표기(rule) — AB-003이 아군/적 **동일 정의**임을 명시.
**제안 편집** — 프론트매터/notes에:
> `unified: true` — 이 능력은 아군·적이 **단일 정의**로 발현(효과·cast_s·damage_mult·delivery·VFX 동일). 시전 telegraph = **cast_s 내재**(적 telegraph 밴드 §3.6.1 배정 대상 아님). 적 시전 시에도 아군과 동일한 캐스트바·charge_up·투사체. base 피해만 시전자별(party `basic_damage` / enemy `contact_damage`).

## 타깃 2 — `docs/combat/D-016_*` §3.6.1 (적 telegraph 밴드 모델)
**변경 성격:** **rule** — 밴드 모델 스코프 한정. 현재 "적 능력 telegraph = 역할별 밴드(filler A/0.30 등)"를 **"비통합(non-unified) 적 능력"** 으로 한정하고, unified 능력은 telegraph를 능력 내재(cast_s)로 규정.
**제안 편집** — §3.6.1 서두에 1줄 + §3.6(캐스터 원칙, DRIFT-075와 함께):
> **통합(unified) 스킬 예외:** `unified:true` Shared 스킬은 적 시전 시에도 telegraph = 능력의 `cast_s`(아군과 동일)이며, 아래 역할별 밴드 배정의 대상이 **아니다**. 밴드(A/B/C)는 비통합 적 고유 능력에만 적용. (모델 = "능력 해소 1개 + 프론트엔드 2개"; 게임 DRIFT-082.)

## 타깃 3 — skillbook/ability 스키마 (`docs/data/*` 또는 CombatContentMap)
**변경 성격:** **신규 필드** — skillbook 정의에 optional `unified: bool`. true면 해당 Shared AB가 적/아군 단일정의(위 원칙) 적용. 미지정=false(기존 이중정의 유지 = 마이그레이션 전 상태).

---

## DEC- 초안 (스펙 레포 `DecisionLog.md` — 적용 시 날짜/번호 확정)
### DEC-2026MMDD-### — Shared 스킬 통합: 적↔아군 단일정의("해소1·프론트엔드2"), AB-003 파일럿
- **배경:** 게임 P4a 캐스팅 확장에서 AB-003 §2.2-B 대칭 판정이 "적↔아군 완전 동일"로 귀결(게임 DRIFT-082). DRIFT-078 패스 파생.
- **결정:** Shared 스킬은 `unified:true` 시 적/아군 단일정의로 발현(효과·cast_s·mult·delivery·VFX 동일, base만 시전자별). telegraph는 밴드 배정(§3.6.1)이 아니라 cast_s 내재. 선택/조준 레이어는 진영별 유지.
- **근거(감독):** "같은 ID·다른 거동" = 이중유지 비용만·이득 없음. fodder(EN-011) 3초 캐스트도 수용(별도 약스킬 포크 불요).
- **영향 문서:** AB-003 · D-016 §3.6/§3.6.1 · skillbook 스키마 · CombatContentMap.
- **연결:** 게임 DRIFT-082. 075/078/079/080 배치와 동시 전파. 잔여 subset 통합=follow-on.

---

## 배치 적용 체크리스트 (P4b 세션)
- [x] AB-003 통합 캐스트 **인게임 플레이테스트 확정**(2026-07-12 sandbox, 사용자 — 적 투사체 파티 타격·캐스트바/charge_up 파리티)
- [ ] 스펙 OPS_30: impact_scan → 매퍼(ability/combat/data/CombatContentMap) → DEC- 생성 → TODO → SpecScopeTracker (075/078/079/080과 배치)
- [ ] 타깃 1·2·3 편집 → OPS_20 lint → `staging` PR
- [ ] 머지 후 게임 `spec_ref.json` 핀 bump + `SPEC_DRIFT.md` DRIFT-082 상태 → ✅ 전파
- [ ] 잔여 대칭 subset(strike/stun/poison/cold) 통합 마이그레이션 착수(follow-on)
- [ ] 이 packet 파일 삭제(정본 = 스펙 + SPEC_DRIFT)

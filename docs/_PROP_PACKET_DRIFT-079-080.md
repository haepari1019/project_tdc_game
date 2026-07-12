# _PROP PACKET — DRIFT-079/080 캐스터 전파 (P4b 정본화 배치용)

> **무엇:** 게임측 규칙변경 **DRIFT-079**(AB-054 채널)·**DRIFT-080**(DPS 초월)을 스펙 SSOT에 반영하기 위한 **적용-준비 packet**. impact_scan 완료, 실제 편집 문안까지 확정해 둠.
> **⛔ 적용 시점(Stop-line):** **지금 적용 금지.** ① 인게임 플레이테스트로 079/080 설계 확정 **AND** ② P4b 정본화 스펙 세션에서 **DRIFT-075(부모 원칙)·073~077(파일럿)·078(캐스팅 패스)와 함께 배치** 될 때 적용. (IMPL-DEC-20260709-001 = P4b 정본화 = 별도 스펙 세션.)
> **적용 위치:** 스펙 레포 `E:/Game_design/project_tdc_spec`(staging). 게임 레포는 반영 후 `spec_ref.json` 재핀만(= 게임의 유일한 spec-관련 쓰기).
> **작성:** 2026-07-12 · 게임 pin `staging@2bf37b2` · 브랜치 `wip/casting-ab054-overdrive-20260712`.

## 왜 지금 piecemeal OPS_30을 안 하나 (근거 요약)
1. **미검증** — 079/080 인게임 미확인. 073~077도 같은 이유로 "🕒 게이트 후 전파" 홀드 중. 플테 후 설계가 바뀌면 SSOT를 되돌려야 함.
2. **스펙이 runtime을 게임에 위임** — AB-054는 "채널 거동 runtime TBD", IDA-024는 "런타임 SSOT = 게임 `binding_fixtures.gd`". 게임 변경 + DRIFT 로깅으로 이미 정합, 키스톤 텍스트 갱신만 배치 대상.
3. **정본 절차 = 배치** — 073~077 + 075(부모) + 078이 P4b 별도 스펙 세션에서 함께 OPS_30로 나가기로 이미 정해짐. 079/080만 떼면 부모 원칙(075) 없이 SSOT가 조각남.

---

## 타깃 1 — `docs/combat/abilities/AB-054_RendingBeam.md` (DRIFT-079)

**현재 상태:** `applies_status: [Channeling]` · effects `[APPLY-CHANNELING, DMG-LINE-CHANNEL-6TICK-0P25X]` · Draft Parameters = "design examples — not runtime SSOT". **Rooted 언급 없음**(게임측 Rooted 근사 = DRIFT-057, 폐기 대상).

**변경 성격:** 대부분 **runtime 명세**(스펙이 비워둔 Channeling 거동을 정의). rule 충돌 아님 — note/EFFECT-CORE 명확화 수준.

**제안 편집** — `notes:` 또는 EFFECT-CORE의 `Channeling`/`APPLY-CHANNELING` 설명에 1줄:
> Channeling 런타임 거동 = **비잠금·비점유 인터럽트형**: 채널 중 시전자 이동 / 다른 스킬 시전 / 기절·다운 시 채널 취소. 시전자 이동잠금(Rooted) 없음(구 게임측 Rooted 근사 = 게임 DRIFT-057 폐기). 조준 = 직선 레인, 진행 표시 = 감소형 채널바.

**OPS_30 매퍼 영향:** ability(AB-054) · status(Channeling 정의, EFFECT-CORE) — D-016 `castTier`/`rootDuringCast` 스키마는 AB-054에 미부여 상태라 신규 필드 없음.

---

## 타깃 2 — `docs/combat/abilities/IDA-024_PressTheLine.md` §Identity Keystone (DRIFT-080)

**현재(표 3행 발췌):**
| 항목 | 내용 |
|------|------|
| **시그니처 상태** | `OverdriveGauge` 0~100 — 평타 +8 / 서브 명중 +12. 만충 → **초월 6s** |
| **캡스톤** | 초월 창(6s) 자체 — 게이지 소모 = 강화 로테이션 윈도우 |
| **vs 혈풍(`IDA-027`)** | 초월 = 게이지→버스트 윈도우 · 혈풍 = 상시 HP 경제 |

**변경 성격:** 키스톤 **모델 변경**(지속 윈도우 → 1회 소모). "6s" 수치 = design example(전파금지·튜닝)지만 **모델 서술은 §Keystone 텍스트 갱신 대상**.

**제안 편집(위 3행 교체):**
| 항목 | 내용 |
|------|------|
| **시그니처 상태** | `OverdriveGauge` 0~100 — 평타 +8 / 서브 명중 +12. 만충 → **발동(무지속 유지)** |
| **캡스톤** | 게이지 만충 = **1회 강화 준비** — 강화 서브 1회 시전 시 소모(지속 윈도우 없음) · **비전투 5초 시 게이지 초기화** |
| **vs 혈풍(`IDA-027`)** | 초월 = 게이지→**1회 강화 버스트** · 혈풍 = 상시 HP 경제 |

- 하단 런타임 SSOT note: `DRIFT-077` → `DRIFT-077·080` 로 갱신.
- 행동 규율 문장의 "만충 시 **짧은 시간** 링크 스킬이 강화 변형으로 발동" → "만충 시 **다음 강화 서브 1회**가 강화 변형으로 발동".

**OPS_30 매퍼 영향:** identity(IDA-024) · role(`ROLE-020_Dps.md` §4.5 DPS 초월 절 · `ROLE-000` §C-4 키스톤) · CombatContentMap(OVERDRIVE 키스톤 요약). §번호는 적용 시 재확인.

---

## DEC- 초안 (스펙 레포 `DecisionLog.md` — 적용 시 날짜/번호 확정)

### DEC-2026MMDD-### — 캐스터 후속: AB-054 채널=인터럽트형 · IDA-024 초월=1회소모+OOC초기화
- **배경:** 게임 P4a 캐스팅 확장/체감 조정에서 도출(게임 DRIFT-079/080). DEC-20260709-001(결속 정본화)의 후속.
- **결정:** ① `Channeling` 런타임 = 비잠금 인터럽트형(이동/시전/CC 시 취소), Rooted 근사 폐기. ② 초월 키스톤 = 지속 윈도우(6s) → 게이지 만충 후 **강화 1회 소모 + 비전투 5초 초기화**.
- **근거(감독):** 셀프-CC "속박"이 채널 맥락에 안 맞음 / 초월이 "지속창"보다 "충전→1회 강타"로 더 읽힘.
- **영향 문서:** AB-054 · IDA-024 · ROLE-020 §4.5 · ROLE-000 §C-4 · CombatContentMap.
- **연결:** 게임 DRIFT-079/080. 073~077 배치와 동시 전파.

---

## 배치 적용 체크리스트 (P4b 세션에서 순차)
- [ ] 079/080 **인게임 플레이테스트로 설계 확정**(godot 헤드리스 부재로 이번엔 미검증)
- [ ] 스펙 레포에서 OPS_30: impact_scan → 매퍼×4 → 위 DEC- 생성 → TODO → SpecScopeTracker (075 + 073~077 + 078과 배치)
- [ ] 위 타깃 1·2 편집 적용 → OPS_20 lint → `staging` PR
- [ ] 머지 후 게임 `spec_ref.json` 핀 bump + `SPEC_DRIFT.md` DRIFT-079/080 상태 → ✅ 전파
- [ ] `docs/design/dps_binding_kit.md` 초월 서술(구 지속형) 갱신
- [ ] `binding_fixtures.gd` `OVERDRIVE.dur`(=6.0) 잔재 제거
- [ ] 이 packet 파일 삭제(정본은 스펙 + SPEC_DRIFT)

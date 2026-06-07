# 난이도 상승 옵션 — 스펙 기반 정리 (2026-06-08)

> 현재: ENC-NORM-001 단일(Elite EN-001 + fodder EN-010/011/012/013). 전문 적 0·상태이상 0·장판 0·웨이브 0·매복 0 = 스펙상 **최저 난이도 구성**. 아래는 스펙에 정의된 난이도 메커니즘.

## A. 전문 적(Specialist) 추가 — **스펙의 핵심 난이도 모델** (ENC-000 §1, ENC-HARD-*)
스펙은 난이도를 "단순 수치"가 아니라 **전문 적 = 의사결정 축(decision axis)** 추가로 올린다. 데모 상한 `mechanicAxes ≤ 2`.
| 전문 적 | 능력 | 강요되는 플레이 |
|---|---|---|
| **Nuker** EN-005 (AB-010 Poison Sting) | 백라인 독 DoT 폭딜 | 누커로 스왑해 우선 제거 (ENC-HARD-001) |
| **CC** EN-006 (AB-011 Bell Ring) | 단발 스턴 STUN-SHORT(telegraph 0.5s) | 스턴 회피/끊김 대응 (ENC-HARD-003) |
| **Debuff** EN-007 (AB-012 Hex Bolt) | Hex-Weak 마크(이동·피해 감소) | 마크 대상 집중사격·정리 (ENC-HARD-004) |
| **Flank** EN-008 (AB-013 Backstab Dash) | 측면/백라인 기습 | 2축 커버·탱 재배치 (ENC-HARD-002) |
| **Mobile** EN-003 (AB-006 Gap-close, AB-007 Retreat) | 돌진+도주(hp≤50%) | 카이팅 붕괴·추격 (ENC-HARD-003) |

## B. 적 능력 강화 — 텔레그래프 + CC/투사체 (AB-### 카탈로그)
- **텔레그래프 캐스트**(telegraph_s 0.15~0.5) → 회피 윈도우 = "보고 대응". 현재 우리 적은 텔레그래프 없음.
- 종류: 넉백·돌진(gap-close)·원거리 연발(volley)·차지샷·스턴·독·약화.
- 현재: 기본 근접 + EN-001 방패치기(넉백) + EN-011 원거리 1종뿐.

## C. 상태이상 시스템 (F-021) — 파티에 디버프
- **Stun**(행동불가)·**Hex-Weak**(약화)·**Poison**(DoT)·**Slow**. 우리는 적 slow만 있음.
- 힐러/클렌즈·실드의 가치를 만든다. `ccTenacity`(지속=base/tenacity)로 적 CC 저항도 표현.
- friendly-fire: 반응/장판은 적·아군 모두 적용(§3.3.1).

## D. 환경 위험 + 연쇄 (F-027, F-021 §3) — 지역 장판 + 콤보
- AB-009/036~043: Oil·Fire·ToxicGas·Water·Ice·Wind·Briar 장판 생성.
- 연쇄 RX: **Oil+Fire 폭발**(RX-OIL-FIRE-001), Water+Lightning 등. depth≤1 기본(콤보는 보너스).
- 바닥 장판 회피 + 적이 까는 위험 지대 = 위치 관리 압박.

## E. 증원 웨이브 (ENC-HARD-005)
- Phase 1 전투 중 **Phase 2 후방 증원**(~12s 텔레그래프, 새 threat 풀) → 전투 중 어그로 재편·샌드위치 위험. `mandatorySwaps: 3`.

## F. 매복 / 인지전 (F-011)
- **DormantUntilLOS** 매복: 파티 LOS+`aggro_wake_buffer_m`(4m) 전까지 **비활성**, 무텔레그래프 기습.
- 시야 축소: dim 0.85×·unlit 0.65×. `squadLight`(횃불 텔레그래프)·`soundBiased`(소리 우선) 퍼셉션 프로파일.

## G. 죽음의 스테이크 (F-007)
- **파티 전멸(4인 다운) = Run Failure**(§3.7.1). 현재는 추출만 하면 성공 — 죽어도 페널티 없음.
- 부분 추출(1인+ 생존=성공)은 유지하되, 전멸 패배 조건으로 긴장 부여.

---
## 추천 구현 순서 (데모 난이도 ↑, 우리 데이터-드리븐 구조에 적합)
1. **파티 전멸=패배** (저비용·즉효 스테이크) + 다운 시스템 정리
2. **상태이상 시스템**(파티: Stun/Slow/Hex/Poison) — C. 그릇 먼저
3. **전문 적 2종**(축 ≤2): 예) **CC(EN-006 스턴) + Nuker/Debuff(EN-005 독 or EN-007 약화)** — A+B. 링크-by-ref로 데이터 추가 + kind 구현
4. **증원 웨이브**(ENC-HARD-005식) — E
5. (선택) 환경 장판 Oil+Fire 연쇄 — D / 매복 — F

---
## 구현됨 (2026-06-08) — 패키지 3(전문 적+스킬) + 5(증원 웨이브)
- **상태이상 시스템**(party_member): `apply_stun`(행동·이동·서브 차단)·`apply_poison`(실드 무시 DoT)·머리 위 상태 오브(스턴 노랑/독 초록). 통합: `player_controller`(조작 스턴 이동정지)·`combat_controller._tick_party_attacks`(스턴 공격정지)·`dungeon_run`(스턴 서브차단).
- **텔레그래프 적 능력**(combat_controller `_enemy_attack` await 와인드업 + 바닥 경고 VFX `SkillVfx.telegraph`): `enemy_stun`(근접, 0.5s, **사거리 이탈로 회피 가능**)·`enemy_poison`(원거리, 0.4s).
- **전문 적 2종**: **EN-006 Bell Ringer**(CC, AB-011 스턴 1.2s every 2)·**EN-005 Gutter Stinger**(Nuker, AB-010 독 7dps/4s 원거리). enemies.json/abilities.json/id_registry 등록.
- **증원 웨이브**(ENC-HARD-005식): `ENC-HARD-001`에 `reinforcement{delay_s:14, units}` → 후방(-Z) 스폰, 1웨이브 정리 시 즉시 발동. combat_controller `_tick_reinforcement`/`_spawn_reinforcement`, 증원 대기 중 victory 보류.
- **인카운터 교체**: RM-ADV-01 → `ENC-HARD-001`(Elite+fodder×2+CC+Nuker, +증원 Nuker+fodder×2). manifest P-ADV-01 repoint.
- ⚠️ mechanicAxes 3(Elite+CC+Nuker) — 데모 가독성 캡(≤2) 초과(난이도 목적 의도적). 전멸=패배(G)는 미구현(추후).

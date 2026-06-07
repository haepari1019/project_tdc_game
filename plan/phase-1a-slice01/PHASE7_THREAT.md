# Phase 1a · 7단계 — Threat (F-022) 진행 문서

> 상위: [WORK_ORDER.md](./WORK_ORDER.md) 7단계 · spec pin `cd6009e`. SSOT: `F-022`, 검증 `QA-022`/`QA-030` §3.4.

## 목표
적마다 Threat Table을 두고 **최고 threat 파티원을 타겟** → 탱커가 어그로를 잡아 전선 유지. (이전엔 최근접 타겟이라 딜러/누커가 맞음)

## 구현 (slice-01 핵심)
- **Threat Table** (`enemy_unit.gd`): `threat{member→value}`, `decay_threat(-8/s, floor 10)`, `pick_target(switchRatio 1.15 히스테리시스, 동률→last_gainer)`.
- **피해 threat** (`combat_controller._deal_damage`): 피해 × 공격자 `threat_mult`. 기본/콘/누킹 모두 경유.
- **탱커 펄스** (Anchor Guard): 반경 내 적에 `threat_pulse`(AB-020=90) 가산. 탱은 `threat_mult=3.0`(identities combat) → 피해경쟁 없이 어그로 우위.
- **타겟팅** (`_tick_enemy`): threat 최고 선택, threat 0이면 최근접 폴백(교전 초반).
- 밸런스 감각: 탱 ~35 threat/s vs 딜/누 ~30~31/s → 탱이 대부분 유지, **누킹 168 스파이크는 그 적만 잠깐 누커로 전환**(스펙 의도 §3.6).

## 기본어그로 UI (F-022 §5.2) — 구현됨
- 적 HP바 **왼쪽에 현재 타겟의 파티 슬롯 색** 사각 마커(Tank 파랑/DPS 청록/Nuker 남보라/Healer 초록). 타겟 바뀌면 색 변경.
- `health_bar.set_target(color)/clear_target()`, `party_member.get_class_color()`, `enemy_unit.set_target_marker()`, `_tick_enemy`에서 매 프레임 갱신.

## 미구현 / 후속
- ~~힐 threat(§3.9)~~ → **구현됨**(2026-06-08): heal()이 실효 회복량 반환, 그 아군을 위협하는 적에만 힐러 threat `effHeal×0.5`.
- ~~타겟 전환 임박 UI(§5.2)~~ → **구현됨**: 2위≥1위×0.85시 적 HP바에 다음타겟 슬롯색 **펄스 마커**. ~~주의어그로(§5.3)~~ → **구현됨**: Elite(EN-001) HP바 **금색 테두리**.
- ~~first-aggressor/group-pull(+120/+60)·threatFloor~~ → **구현됨**: 첫공격 +120, 그룹풀 +60, floor(기본10·첫공격자25·탱40).
- **남은 보류**: Combat Area 이탈(§3.8) — F-006 지오메트리 의존, 단일룸 슬라이스에선 한계. 임박 UI의 "적 시선 전조"는 미구현(마커만).

## 검증 (F5)
- 전투 시 적 다수가 **탱커를 향함**(딜러/누커 안전). 누커 큰 폭딜 직후 해당 적이 잠깐 누커로 갔다가 복귀.
- 튜닝: 탱이 어그로 못 잡으면 `identities.json` Tank `threat_mult`↑ 또는 `abilities.json` AB-020 `threat_pulse`↑.

## 감쇄 모델 (2026-06-08 변경)
- **누적→비례(지수) 감쇄**: `threat *= retain^Δt`. 과거 threat가 빠르게 흐려져 **최근 threat가 어그로 결정** → 누적격차 고착 없음. 버스트(누킹 +168 등)가 그 적을 수초간 뺏음.
- 현재 값(2026-06-08, 더 잘 튀게 2차 조정): `THREAT_RETAIN_PER_S=0.6`(half-life ~1.35s) · `SWITCH_RATIO=1.02` · Tank `threat_mult=2.2`·`AB-020.threat_pulse=60`. → 탱은 펄스(8s)+도발로 능동 유지, 평시엔 딜/누커가 잘 뺏음.
- 노브: retain↑(0.7)=잔잔 / retain↓(0.5)=더 튐 · SWITCH_RATIO · Tank mult·pulse · 도발 `AB-S01.threat_amount`(1500).

## 로그
- 2026-06-07 · Threat Table + 피해/펄스 threat + 타겟선택(히스테리시스) 구현 · `enemy_unit.gd`, `combat_controller.gd`, `party_member.gd`(threat_mult), `identities.json`(Tank 3.0)
- 2026-06-07 · 기본어그로 UI: HP바 옆 현재타겟 슬롯색 마커 · `health_bar.gd`(set_target/clear_target+marker), `party_member.gd`(get_class_color), `enemy_unit.gd`(set_target_marker), `combat_controller.gd`
- 2026-06-08 · **F-022 충실도 복원**(스펙 대비 축소분): ①힐 threat(§3.9, heal()→실효량 반환·`_heal_threat`) ②첫공격+120/그룹풀+60/threat floor(기본10·첫공25·탱40, per-member `floor_of`·`set_threat_floor`) ③타겟 전환 임박 UI(§5.2, `imminent_target`·HP바 펄스 마커 `_marker2`) ④주의어그로 Elite(§5.3, HP바 `_frame` 금테). 보류: Combat Area 이탈(§3.8, F-006 의존) · `enemy_unit.gd`, `combat_controller.gd`, `health_bar.gd`, `party_member.gd`(heal 반환)

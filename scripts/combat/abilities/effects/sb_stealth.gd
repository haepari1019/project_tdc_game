extends RefCounted
## AB-062 Smoke Veil (kind=skillbook_stealth) — self stealth: the caster gains Veiled for veil_s,
## dropping enemy targeting for the window (party_member.apply_veil → enemy_ai._is_hostile skips it).
## **오프너로 재정의(DRIFT-121):** 이탈 전용이던 것에 `hold_fire`(은신 중 **평타·정체성** 정지 —
## `holds_fire()` 게이트가 정체성 발동보다 앞) + `next_hit_bonus`(은신 후 첫 타격 증폭)를 얹었다.
## 둘은 한 쌍이다 — 자동 공격을 안 멈추면 은신 직후 평타가 증폭을 즉시 먹어치워 플레이어에게
## "무엇에 실을지" 고르는 창이 없다. 자동을 멈추면 `veil_s`가 그대로 **준비 창**이 된다.
## **해제는 시전이 아니라 첫 타격**(`combat_controller._deal_damage`) — 시전 시작에 풀면 긴 캐스트
## 내내 표적으로 노출돼 "숨어서 준비한다"가 성립하지 않는다. 그래서 `veil_s`는 최장 캐스트를 여유 있게
## 덮는 길이(60s)로 잡았고, 은신을 끝내는 건 시간이 아니라 **플레이어의 능동 타격**이다.
## **조작을 옮겨도 은신은 유지된다(의도 — 고치지 말 것):** 빈사 멤버를 표적에서 빼 놓고 힐러로 스왑해
## 캐스팅을 완주시키는 「안전 주차」가 이 스킬의 두 번째 용도다. AI는 서브를 안 쓰므로 그동안 그 멤버의
## 기여가 0이 되는데, 그 유휴가 **지불하는 대가**다 — 노는 것처럼 보인다고 조작 상실 시 해제를 넣으면
## 용도 자체가 사라진다. 피격도 은신을 깨지 않아 이 운용이 규칙으로 보장된다. ref: DRIFT-121 ⑧.
## ref: F-009 · STATUS Veiled · DRIFT-057 · DRIFT-121.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_stealth"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	if not m.has_method("apply_veil"):
		return false
	var dur := float(p.get("veil_s", 1.5))
	m.apply_veil(dur, bool(p.get("hold_fire", false)))
	var nhb := float(p.get("next_hit_bonus", 0.0))   # 은신 후 첫 타격 증폭(AB-006·잠행 이탈 결속과 같은 훅)
	if nhb > 0.0 and m.has_method("grant_next_hit_bonus"):
		m.grant_next_hit_bonus(nhb)
	SkillVfx.smoke_puff(ctx, m.global_position)
	print("[SB] %s Smoke Veil — Veiled %.1fs (hold_fire=%s, next-hit +%d%%)" % [
		m.class_id, dur, bool(p.get("hold_fire", false)), int(round(nhb * 100.0))])
	return true

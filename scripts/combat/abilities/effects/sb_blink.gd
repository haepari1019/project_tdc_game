extends RefCounted
## kind=skillbook_blink — short self-teleport up to blink_m. AB-061 Shadowstep / AB-006 Gap-Close
## (toward the aim point or nearest enemy); AB-007 Retreat Hop (`away`=true → hop AWAY from the
## nearest enemy, disengage). (Spec "next hit +20%" deferred.) ref: F-009 · STATUS-OUTCOME · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_blink"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var dist := float(p.get("blink_m", 6.0))
	var away := bool(p.get("away", false))
	var to: Vector3
	var foe = null
	if away:   # AB-007 이탈 — hop away from the nearest threat
		foe = ctx.nearest_enemy_in_range(m.global_position, 20.0)
		to = (m.global_position - foe.global_position) if foe != null else Vector3(0, 0, -1)
	elif target_pos != Vector3.ZERO and target_pos.distance_to(m.global_position) > 0.3:
		to = target_pos - m.global_position
	else:
		foe = ctx.nearest_enemy_in_range(m.global_position, 20.0)
		to = (foe.global_position - m.global_position) if foe != null else Vector3(0, 0, 1)
	# AB-007 이탈 — 후퇴 전 '마무리 한 방'(평타치던 대상 = 최근접 적)
	var ps := float(p.get("parting_shot_mult", 0.0))
	if ps > 0.0:
		var tgt = foe if foe != null else ctx.nearest_enemy_in_range(m.global_position, 20.0)
		if tgt != null:
			ctx.deal_damage(tgt, m, m.basic_damage * ps)
			if ctx.has_method("report_hit_target"):
				ctx.report_hit_target(tgt)   # 집중 결속이 마무리 대상에 집중 스택을 얹도록
	to.y = 0.0
	if to.length() < 0.1:
		to = Vector3(0, 0, 1)
	var start: Vector3 = m.global_position
	m.global_position += to.normalized() * (dist if away else minf(dist, to.length()))
	SkillVfx.dash_streak(ctx, start, m.global_position, Color(0.55, 0.38, 0.78))   # shadow blink trail
	# AB-007 이탈 — 어그로 감소(아군: 전 적 위협 −frac / 적 ctx: no-op)
	var ag := float(p.get("aggro_reduce", 0.0))
	if ag > 0.0 and ctx.has_method("reduce_threat"):
		ctx.reduce_threat(m, ag)
	var nhb := float(p.get("next_hit_bonus", 0.0))   # AB-061 Shadowstep — boost the next hit
	if nhb > 0.0 and m.has_method("grant_next_hit_bonus"):
		m.grant_next_hit_bonus(nhb)
	return true

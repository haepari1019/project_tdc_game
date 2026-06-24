extends RefCounted
## kind=skillbook_blink — short self-teleport up to blink_m. AB-061 Shadowstep / AB-006 Gap-Close
## (toward the aim point or nearest enemy); AB-007 Retreat Hop (`away`=true → hop AWAY from the
## nearest enemy, disengage). (Spec "next hit +20%" deferred.) ref: F-009 · STATUS-OUTCOME · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_blink"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var dist := float(p.get("blink_m", 6.0))
	var to: Vector3
	if bool(p.get("away", false)):   # AB-007 Retreat Hop — hop away from the nearest threat
		var foe = ctx.nearest_enemy_in_range(m.global_position, 20.0)
		to = (m.global_position - foe.global_position) if foe != null else Vector3(0, 0, -1)
	elif target_pos != Vector3.ZERO and target_pos.distance_to(m.global_position) > 0.3:
		to = target_pos - m.global_position
	else:
		var tgt = ctx.nearest_enemy_in_range(m.global_position, 20.0)
		to = (tgt.global_position - m.global_position) if tgt != null else Vector3(0, 0, 1)
	to.y = 0.0
	if to.length() < 0.1:
		to = Vector3(0, 0, 1)
	var start: Vector3 = m.global_position
	m.global_position += to.normalized() * minf(dist, to.length())
	SkillVfx.dash_streak(ctx, start, m.global_position, Color(0.55, 0.38, 0.78))   # shadow blink trail
	var nhb := float(p.get("next_hit_bonus", 0.0))   # AB-061 Shadowstep — boost the next hit
	if nhb > 0.0 and m.has_method("grant_next_hit_bonus"):
		m.grant_next_hit_bonus(nhb)
	print("[SB] %s Shadowstep — blink %.1fm%s" % [m.class_id, start.distance_to(m.global_position), (" (+%d%% next)" % int(nhb * 100)) if nhb > 0.0 else ""])
	return true

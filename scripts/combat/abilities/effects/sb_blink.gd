extends RefCounted
## AB-061 Shadowstep (kind=skillbook_blink) — short self-teleport toward the aim point (targeted) or
## the nearest enemy, up to blink_m. (Spec "next hit +20%" deferred.) Drop-in skillbook effect.
## ref: F-009 · STATUS-OUTCOME · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_blink"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var dist := float(p.get("blink_m", 6.0))
	var to: Vector3
	if target_pos != Vector3.ZERO:
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
	print("[SB] %s Shadowstep — blink %.1fm" % [m.class_id, start.distance_to(m.global_position)])
	return true

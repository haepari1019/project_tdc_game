extends RefCounted
## AB-022 Bulwark March (kind=march_advance) — a short forward advance toward the nearest foe with
## knockback + light damage to frontal enemies (corridor control). DEC-20260617-005.
## Drop-in identity effect. ref: GEAR-014 · DEC(gear catalog).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "march_advance"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var tgt = ctx.nearest_enemy_in_range(m.global_position, 8.0)
	if tgt == null:
		return false
	var axis: Vector3 = tgt.global_position - m.global_position
	axis.y = 0.0
	axis = axis.normalized() if axis.length() > 0.1 else Vector3(0, 0, 1)
	var foes: Array = ctx.enemies_in_cone(m.global_position, axis, float(p.get("radius_m", 2.6)), deg_to_rad(60.0))
	var start: Vector3 = m.global_position   # for the advance trail VFX
	m.global_position += axis * float(p.get("advance_m", 1.5))   # short advance — corridor block
	var dmg: float = float(p.get("damage_mult", 0.6)) * m.basic_damage
	var kb: float = float(p.get("knockback", 3.0))
	for e in foes:
		ctx.deal_damage(e, m, dmg)
		if e.has_method("apply_knockback"):
			e.apply_knockback(e.global_position - m.global_position, kb)
	SkillVfx.dash_streak(ctx, start, m.global_position, Color(0.6, 0.7, 0.9))   # forward ADVANCE trail
	SkillVfx.telegraph(ctx, m.global_position + axis * 1.5, Color(0.6, 0.7, 0.9))  # front knockback zone
	print("[ID] %s Bulwark March — advance, %d knocked" % [m.identity_skill_id, foes.size()])
	return true

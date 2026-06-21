extends RefCounted
## AB-104 Rampage (kind=skillbook_charge) — frontal line/cone toward the aim: damage + light
## knockback to everything in the path (anti-swarm displacement). Looted from EN-3RD-03. Tank.
## ref: DEC-20260621-001 / F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_charge"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var axis := target_pos - m.global_position
	axis.y = 0.0
	axis = axis.normalized() if axis.length() > 0.1 else Vector3(0, 0, 1)
	var range_m := float(p.get("range_m", 8.0))
	var half := deg_to_rad(float(p.get("cone_deg", 40.0)) * 0.5)
	var foes: Array = ctx.enemies_in_cone(m.global_position, axis, range_m, half)
	if foes.is_empty():
		return false
	var dmg: float = float(p.get("damage_mult", 1.1)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var kb := float(p.get("knockback_m", 0.9))
	for e in foes:
		ctx.deal_damage(e, m, dmg)
		if kb > 0.0 and e.has_method("apply_knockback"):
			e.apply_knockback(e.global_position - m.global_position, kb)
	ctx.sub_shake(p)
	SkillVfx.telegraph(ctx, m.global_position + axis * (range_m * 0.5), Color(0.85, 0.5, 0.2))
	print("[SB] %s Rampage — %d in path" % [m.class_id, foes.size()])
	return true

extends RefCounted
## AB-002 Shield Bash (kind=skillbook_strike) — AoE strike + knockback on nearby foes.
## Drop-in skillbook effect (ability_dispatch ctx facade). ref: F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_strike"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 4.0))
	var dmg: float = float(p.get("damage_mult", 2.0)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var foes: Array = ctx.enemies_in_radius(m.global_position, radius)
	var broke: bool = ctx.damage_destructibles(m.global_position, radius, dmg)
	if foes.is_empty() and not broke:
		return false
	var kb := float(p.get("knockback_m", 0.0))
	for e in foes:
		ctx.deal_damage(e, m, dmg)
		if kb > 0.0:
			e.apply_knockback(e.global_position - m.global_position, kb)
	ctx.sub_shake(p)
	SkillVfx.sub_taunt(ctx, m.global_position, float(p.get("radius_m", 4.0)))
	print("[SB] %s Shield Bash — %d foes" % [m.class_id, foes.size()])
	return true

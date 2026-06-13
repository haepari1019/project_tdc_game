extends RefCounted
## AB-010 Venom Spit (kind=skillbook_poison) — AoE poison burst (dps×dur upfront) + slow.
## Drop-in skillbook effect (ability_dispatch ctx facade). ref: F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_poison"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 5.0))
	var dmg: float = (float(p.get("damage_mult", 0.5)) * m.basic_damage \
			+ float(p.get("poison_dps", 0.0)) * float(p.get("poison_dur_s", 0.0))) * float(p.get("_coeff", 1.0))
	var foes: Array = ctx.enemies_in_radius(m.global_position, radius)
	var broke: bool = ctx.damage_destructibles(m.global_position, radius, dmg)
	if foes.is_empty() and not broke:
		return false
	for e in foes:
		ctx.deal_damage(e, m, dmg)
		e.apply_slow(0.6, float(p.get("poison_dur_s", 3.0)))
	ctx.sub_shake(p)
	SkillVfx.sub_nova(ctx, m.global_position, float(p.get("radius_m", 5.0)))
	print("[SB] %s Venom Spit — %d foes" % [m.class_id, foes.size()])
	return true

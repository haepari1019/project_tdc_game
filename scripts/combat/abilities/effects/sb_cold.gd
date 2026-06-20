extends RefCounted
## AB-041 Glacial Bolt skillbook (kind=skillbook_cold) — aimed cold burst: AoE dmg + Chilled +
## ColdDamageHit (Water→Ice, Vegetation→Slowed RX). Drop-in effect. ref: F-009 / F-027.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_cold"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var radius := float(p.get("radius_m", 2.0))
	var dmg: float = float(p.get("damage_mult", 1.2)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var foes: Array = ctx.enemies_in_radius(center, radius)
	for e in foes:
		ctx.deal_damage(e, m, dmg)
		if e.has_method("apply_outcome"):
			e.apply_outcome("Chilled", float(p.get("chill_dur_s", 3.0)))
	ctx.cold_hit(center, radius, m)  # ColdDamageHit → RX (Water→Ice, Veg→Slowed)
	ctx.sub_shake(p)
	SkillVfx.telegraph(ctx, center, Color(0.6, 0.9, 1.0, 0.45), radius)  # cyan frost impact
	print("[SB] %s Glacial Bolt — %d foes" % [m.class_id, foes.size()])
	return true

extends RefCounted
## AB-037 Ember Lance (kind=skillbook_fire) — aimed fire bolt: AoE fire dmg + breaks barrels +
## ignites Oil (RX-OIL-FIRE). Drop-in skillbook effect (ability_dispatch ctx facade). ref: F-009/F-027.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_fire"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var radius := float(p.get("radius_m", 3.0))
	var dmg: float = float(p.get("damage_mult", 1.8)) * m.basic_damage * float(p.get("_coeff", 1.0))
	for e in ctx.enemies_in_radius(center, radius):
		ctx.deal_damage(e, m, dmg)
	ctx.damage_destructibles(center, radius, dmg)
	ctx.fire_hit(center, radius, 0, m)  # FireDamageHit → ignite any Oil here (RX-OIL-FIRE)
	ctx.sub_shake(p)
	SkillVfx.telegraph(ctx, center, Color(1.0, 0.45, 0.1))  # orange fire impact
	print("[SB] %s Ember Lance @target" % m.class_id)
	return true

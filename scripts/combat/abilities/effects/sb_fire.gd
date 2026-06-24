extends RefCounted
## AB-037 Ember Lance / AB-053 Searing Volley (kind=skillbook_fire) — aimed fire bolt: AoE fire dmg +
## breaks barrels + ignites Oil (RX-OIL-FIRE). `delivery: projectile` → flies & explodes on impact
## (blocked by walls / hostile Rampart); else instant at the aim point. ref: F-009/F-027 · DRIFT-059.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_fire"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z) if target_pos != Vector3.ZERO else m.global_position
	if String(p.get("delivery", "instant")) == "projectile":
		ctx.spawn_projectile(self, m, center, p)
		ctx.sub_shake(p)
		return true
	resolve_at(m, center, p, ctx)
	ctx.sub_shake(p)
	return true


func resolve_at(m: CharacterBody3D, center: Vector3, p: Dictionary, ctx) -> void:
	var radius := float(p.get("radius_m", 3.0))
	var dmg: float = float(p.get("damage_mult", 1.8)) * m.basic_damage * float(p.get("_coeff", 1.0))
	for e in ctx.enemies_in_radius(center, radius):
		ctx.deal_damage(e, m, dmg)
	ctx.damage_destructibles(center, radius, dmg)
	ctx.fire_hit(center, radius, 0, m)  # FireDamageHit → ignite any Oil here (RX-OIL-FIRE)
	SkillVfx.telegraph(ctx, center, Color(1.0, 0.45, 0.1), radius)  # orange fire impact

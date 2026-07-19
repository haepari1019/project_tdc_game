extends RefCounted
## AB-041 Glacial Bolt / AB-072 Hailstorm (kind=skillbook_cold) — aimed cold burst: AoE dmg + Chilled +
## ColdDamageHit (Water→Ice, Vegetation→Slowed RX). `delivery: projectile` → flies & bursts on impact
## (blocked by walls / hostile Rampart); else instant at the aim point. ref: F-009 / F-027 · DRIFT-059.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_cold"


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
	var radius := float(p.get("radius_m", 2.0))
	var dmg: float = float(p.get("damage_mult", 1.2)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var hits: Array = []
	for e in ctx.enemies_in_radius(center, radius):
		ctx.deal_damage(e, m, dmg)
		hits.append(e)
	# 속성 seam — 즉시 Chilled + ColdDamageHit RX(Water→Ice, Veg→Slowed). AB의 `element`가 정한다.
	ctx.element_hit(String(p.get("element", "")), center, radius, m, p, hits)
	SkillVfx.telegraph(ctx, center, Color(0.6, 0.9, 1.0, 0.45), radius)  # cyan frost impact

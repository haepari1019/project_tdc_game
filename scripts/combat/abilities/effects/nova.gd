extends RefCounted
## Nuker SUB Nova (kind=sub_nova) — AoE burst + slow at the targeted ground point.
## Drop-in skill effect (ability_dispatch ctx facade).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "sub_nova"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var radius := float(p.get("radius_m", 6.5))
	var foes: Array = ctx.enemies_in_radius(center, radius)
	var dmg: float = float(p.get("damage_mult", 3.0)) * m.basic_damage
	var sf := float(p.get("slow_factor", 0.4))
	var sd := float(p.get("slow_duration_s", 4.0))
	for e in foes:
		ctx.deal_damage(e, m, dmg)
		e.apply_slow(sf, sd)
	ctx.damage_destructibles(center, radius, dmg)  # break barrels in the nova radius
	ctx.sub_shake(p)  # 서브 타격감: 캐스트당 1회(타깃 수와 무관)
	SkillVfx.sub_nova(ctx, center, radius)
	print("[SUB] %s Nova @target — %d foes" % [m.identity_skill_id, foes.size()])
	return true

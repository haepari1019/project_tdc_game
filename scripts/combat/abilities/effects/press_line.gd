extends RefCounted
## AB-024 Press the Line (kind=cone_sweep) — forward cone, 3-hit sweep AoE (v1: total at once).
## Drop-in skill effect (ability_dispatch ctx facade).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "cone_sweep"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var range_m := float(p.get("range_m", 5.0))
	var nearest: CharacterBody3D = ctx.nearest_enemy_in_range(m.global_position, range_m)
	if nearest == null:
		return false
	var axis := nearest.global_position - m.global_position
	axis.y = 0.0
	axis = axis.normalized()
	var half := deg_to_rad(float(p.get("cone_deg", 60.0)) * 0.5)
	var targets: Array = ctx.enemies_in_cone(m.global_position, axis, range_m, half)
	if targets.is_empty():
		return false
	var total: float = float(p.get("hit_damage_mult", 0.35)) * int(p.get("hits", 3)) * m.basic_damage
	for e in targets:
		ctx.deal_damage(e, m, total)
	SkillVfx.press_line(ctx, m.global_position, axis, range_m, float(p.get("cone_deg", 60.0)) * 0.5)
	print("[ID] %s Press the Line — %d in cone, %d ea" % [m.identity_skill_id, targets.size(), int(total)])
	return true

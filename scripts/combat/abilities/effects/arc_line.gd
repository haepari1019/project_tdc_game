extends RefCounted
## AB-027 Arc Weave (kind=arc_line) — a long, narrow piercing line toward the nearest foe; multi-hit
## with lower per-hit damage (range/spread over single-target). DEC-20260617-004.
## Drop-in identity effect. ref: GEAR-022/023/026 · DEC(gear catalog).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "arc_line"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var range_m: float = float(p.get("range_m", 14.0))
	var tgt = ctx.nearest_enemy_in_range(m.global_position, range_m)
	if tgt == null:
		return false
	var axis: Vector3 = tgt.global_position - m.global_position
	axis.y = 0.0
	axis = axis.normalized() if axis.length() > 0.1 else Vector3(0, 0, 1)
	var foes: Array = ctx.enemies_in_cone(m.global_position, axis, range_m, deg_to_rad(float(p.get("cone_deg", 12.0)) * 0.5))
	if foes.is_empty():
		return false
	var n: int = mini(foes.size(), int(p.get("max_hits", 4)))
	var dmg: float = float(p.get("damage_mult", 0.7)) * m.basic_damage
	for i in n:
		ctx.deal_damage(foes[i], m, dmg)
	SkillVfx.telegraph(ctx, m.global_position + axis * (range_m * 0.5), Color(0.5, 0.85, 1.0))
	print("[ID] %s Arc Weave — line pierce %d" % [m.identity_skill_id, n])
	return true

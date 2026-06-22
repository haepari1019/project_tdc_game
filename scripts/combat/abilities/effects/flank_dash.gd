extends RefCounted
## AB-029 Flank Collapse (kind=flank_dash) — dash to the nearest foe + a multi-hit burst finisher.
## DEC-20260617-005 (Burst); high per-hit to offset melee exposure.
## Drop-in identity effect. ref: GEAR-033 · DEC(gear catalog).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "flank_dash"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var tgt = ctx.nearest_enemy_in_range(m.global_position, float(p.get("dash_m", 6.0)))
	if tgt == null:
		return false
	var start: Vector3 = m.global_position   # for the dash trail VFX (movement is applied below)
	var to: Vector3 = tgt.global_position - m.global_position
	to.y = 0.0
	var dist: float = to.length()
	if dist > 1.2:
		m.global_position += to.normalized() * (dist - 1.0)   # dash adjacent
	var dmg: float = float(p.get("damage_mult", 1.6)) * m.basic_damage
	for _i in int(p.get("hits", 2)):
		ctx.deal_damage(tgt, m, dmg)
	ctx.sub_shake(p)
	SkillVfx.dash_streak(ctx, start, m.global_position, Color(0.95, 0.4, 0.5))   # crimson DASH trail
	SkillVfx.telegraph(ctx, tgt.global_position, Color(0.95, 0.4, 0.5))           # impact burst on target
	print("[ID] %s Flank Collapse — dash burst x%d" % [m.identity_skill_id, int(p.get("hits", 2))])
	return true

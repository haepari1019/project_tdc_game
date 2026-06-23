extends RefCounted
## AB-051 Shield Throw (kind=skillbook_pull) — yank the nearest enemy near the aim point toward the
## caster (apply_knockback along caster−enemy = a pull), + threat. Anti-backline / reposition tool,
## no damage. ref: F-009 · F-022 · AB-051 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_pull"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 1.8))
	var pull := float(p.get("pull_m", 5.0))
	var threat := float(p.get("threat", 60.0))
	var foe: CharacterBody3D = null
	for e in ctx.enemies_in_radius(center, radius):
		if e != null and is_instance_valid(e):
			foe = e
			break
	if foe == null:
		return false
	if foe.has_method("apply_knockback"):
		foe.apply_knockback(m.global_position - foe.global_position, pull)   # toward caster = pull
	if foe.has_method("add_threat"):
		foe.add_threat(m, threat)
	SkillVfx.dash_streak(ctx, foe.global_position, m.global_position, Color(0.40, 0.62, 1.0))
	print("[SB] %s Shield Throw — pulled 1 %.1fm" % [m.class_id, pull])
	return true

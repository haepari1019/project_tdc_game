extends RefCounted
## AB-050 Warding Shout (kind=skillbook_slow) — a forward cone toward the aim: slow enemies to
## slow_factor for slow_s, + a little Tank threat. No damage. ref: F-009 · F-022 · AB-050 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_slow"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var axis := target_pos - m.global_position
	axis.y = 0.0
	axis = axis.normalized() if axis.length() > 0.1 else Vector3(0, 0, 1)
	var range_m := float(p.get("range_m", 10.0))
	var cone_deg := float(p.get("cone_deg", 60.0))
	var factor := float(p.get("slow_factor", 0.7))
	var dur := float(p.get("slow_s", 3.0))
	var threat := float(p.get("threat", 30.0))
	var n := 0
	for e in ctx.enemies_in_cone(m.global_position, axis, range_m, deg_to_rad(cone_deg * 0.5)):
		if e == null or not is_instance_valid(e) or not e.has_method("apply_slow"):
			continue
		e.apply_slow(factor, dur)
		if e.has_method("add_threat"):
			e.add_threat(m, threat)
		n += 1
	if n == 0:
		return false   # nobody in the cone → don't spend a charge
	SkillVfx.fan_telegraph(ctx, m.global_position, axis, range_m, cone_deg, Color(0.40, 0.62, 1.0, 0.4), 0.6)
	print("[SB] %s Warding Shout — slowed %d" % [m.class_id, n])
	return true

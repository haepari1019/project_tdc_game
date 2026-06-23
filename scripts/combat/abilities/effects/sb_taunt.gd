extends RefCounted
## AB-035 Challenge Mark (kind=skillbook_taunt) — mark an enemy near the aim point: spike the caster's
## threat on it (+mark_threat) and raise its threat floor (flr) so it turns to the Tank. No damage.
## The +threat spike decays over a few seconds (≈ time-limited taunt); the floor keeps the Tank
## relevant after. ref: F-009 · F-022 · AB-035 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_taunt"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 2.0))
	var spike := float(p.get("mark_threat", 120.0))
	var flr := float(p.get("floor", 50.0))
	var hit: CharacterBody3D = null
	for e in ctx.enemies_in_radius(center, radius):
		if e != null and is_instance_valid(e) and e.has_method("add_threat"):
			e.add_threat(m, spike)
			if e.has_method("set_threat_floor"):
				e.set_threat_floor(m, flr)
			hit = e
			break   # single-target mark (AB-035)
	if hit == null:
		return false
	SkillVfx.sub_taunt(ctx, hit.global_position, 1.8)   # blue aggro pulse on the marked enemy
	print("[SB] %s Challenge Mark — +%d threat on 1" % [m.class_id, int(spike)])
	return true

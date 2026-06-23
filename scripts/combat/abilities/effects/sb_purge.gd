extends RefCounted
## AB-070 Purge Light (kind=skillbook_purge) — strip ONE buff from an enemy near the aim point.
## Today the live enemy buff is Bloodlust (Third-faction self-rage); Fortified/Hasted/Shielded/
## Warded/Regenerating are forward-compat (no enemy carries them yet). No direct damage. Spends no
## charge if there was nothing to purge. ref: F-009 · AB-070 · STATUS · DRIFT-058.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_purge"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 2.0))
	var removed := ""
	for e in ctx.enemies_in_radius(center, radius):
		if e != null and is_instance_valid(e) and e.has_method("purge_one_buff"):
			removed = e.purge_one_buff()
			if removed != "":
				SkillVfx.telegraph(ctx, e.global_position, Color(1.0, 0.95, 0.6), 1.6)
				break
	if removed == "":
		return false   # nothing to purge → don't spend a charge
	SkillVfx.telegraph(ctx, center, Color(1.0, 0.92, 0.55), maxf(radius, 1.5))
	print("[SB] %s Purge Light — removed %s" % [m.class_id, removed])
	return true

extends RefCounted
## AB-046 Shield Wall (self, radius~0.5) / AB-047 Aegis Pulse (ally aura, radius 4) — kind=skillbook_dr.
## Temporary damage reduction to allies in radius (caster included). Reuses member.damage_taken_mult
## (no move-lock, unlike Sentinel Form). Drop-in skillbook effect. ref: F-009 · STATUS Fortified/Warded.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_dr"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 0.5))
	var dr := clampf(float(p.get("damage_reduction", 0.3)), 0.0, 1.0)
	var dur := float(p.get("duration_s", 3.0))
	var n := 0
	for a in ctx.allies_in_radius(m.global_position, radius):
		if a != null and is_instance_valid(a) and a.has_method("apply_damage_reduction"):
			a.apply_damage_reduction(dr, dur)
			n += 1
	SkillVfx.sub_sanctuary(ctx, m.global_position, maxf(radius, 1.2))   # gold protective dome/pulse
	print("[SB] %s DR %d%% / %.1fs → %d ally" % [m.class_id, int(dr * 100), dur, n])
	return n > 0

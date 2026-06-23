extends RefCounted
## AB-065 Renewing Tide (kind=skillbook_hot) — apply heal-over-time to allies in radius (caster
## included): regen_pct_s × maxHP per second for duration_s. Single-target spec approximated as a
## radius pulse. Drop-in skillbook effect. ref: F-009 · STATUS Regenerating · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_hot"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 0.5))
	var pct_s := float(p.get("regen_pct_s", 0.0)) * float(p.get("_coeff", 1.0))
	var dur := float(p.get("duration_s", 5.0))
	var n := 0
	for a in ctx.allies_in_radius(m.global_position, radius):
		if a != null and is_instance_valid(a) and a.has_method("apply_regen"):
			a.apply_regen(pct_s, dur)
			n += 1
	SkillVfx.mend_circle(ctx, m.global_position, maxf(radius, 1.5))
	print("[SB] %s Renewing Tide — HoT %d ally" % [m.class_id, n])
	return n > 0

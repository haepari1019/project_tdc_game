extends RefCounted
## AB-069 Swift Grace (kind=skillbook_haste) — haste allies in radius (caster included): move +
## attack speed × (1+pct) for duration_s (member.apply_haste). Single-target spec approximated as a
## radius pulse. Drop-in skillbook effect. ref: F-009 · STATUS Hasted · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_haste"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 5.0))
	var pct := float(p.get("haste_pct", 0.2))
	var dur := float(p.get("duration_s", 4.0))
	var n := 0
	for a in ctx.allies_in_radius(m.global_position, radius):
		if a != null and is_instance_valid(a) and a.has_method("apply_haste"):
			a.apply_haste(pct, dur)
			n += 1
	SkillVfx.telegraph(ctx, m.global_position, Color(0.70, 1.0, 0.86), maxf(radius, 1.5))   # wind haste pulse
	print("[SB] %s Swift Grace — haste +%d%% → %d ally" % [m.class_id, int(pct * 100), n])
	return n > 0

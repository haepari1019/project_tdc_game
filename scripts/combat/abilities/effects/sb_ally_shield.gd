extends RefCounted
## AB-067 Aegis Blessing (kind=skillbook_shield) — grant a damage-absorbing shield to allies in
## radius (caster included). shield = shield_pct × target maxHP + flat, × coeff. Single-target spec
## approximated as a radius pulse. Drop-in skillbook effect. ref: F-009 · IDA-020 Shield Policy · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_shield"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 0.5))
	var pct := float(p.get("shield_pct", 0.0))
	var flat := float(p.get("shield", 0.0))
	var dur := float(p.get("duration_s", 6.0))
	var coeff := float(p.get("_coeff", 1.0))
	var n := 0
	for a in ctx.allies_in_radius(m.global_position, radius):
		if a != null and is_instance_valid(a) and a.has_method("add_shield"):
			a.add_shield((float(a.max_hp) * pct + flat) * coeff, dur)
			n += 1
	SkillVfx.sub_taunt(ctx, m.global_position, maxf(radius, 1.2))   # blue protective dome
	print("[SB] %s Aegis Blessing — shield %d ally" % [m.class_id, n])
	return n > 0

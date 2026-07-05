extends RefCounted
## IDA-026 Mend Circle (kind=radius_heal) — radius heal when any ally below threshold.
## Drop-in skill effect (ability_dispatch ctx facade).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "radius_heal"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 4.0))
	var allies: Array = ctx.allies_in_radius(m.global_position, radius)
	var ally_t := float(p.get("ally_threshold_pct", 0.85))
	var tank_t := float(p.get("tank_threshold_pct", 0.90))
	var should := false
	for a in allies:
		var t: float = tank_t if a.class_id == "Tank" else ally_t
		if a.hp / a.max_hp < t:
			should = true
			break
	if not should:
		return false
	var heal_pct := float(p.get("heal_pct", 0.12))
	for a in allies:
		var eff: float = a.heal(a.max_hp * heal_pct)
		ctx.heal_threat(m, a, eff)
	SkillVfx.mend_circle(ctx, m.global_position, radius)
	print("[ID] %s Mend Circle — %d allies healed" % [m.identity_skill_id, allies.size()])
	return true

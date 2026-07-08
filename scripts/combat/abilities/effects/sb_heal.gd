extends RefCounted
## AB-064 Quick Mend (kind=skillbook_heal) — instant heal allies in radius (caster included). Heal =
## heal_pct × target maxHP + flat, × off-class coeff. Single-target spec approximated as a radius
## pulse (demo). Drop-in skillbook effect. ref: F-009 · F-022 §3.9 healer threat · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_heal"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 5.0))
	var pct := float(p.get("heal_pct", 0.0))
	var flat := float(p.get("heal", 0.0))
	var coeff := float(p.get("_coeff", 1.0))
	var healed := 0
	for a in ctx.allies_in_radius(m.global_position, radius):
		if a == null or not is_instance_valid(a) or not a.has_method("heal"):
			continue
		var amt: float = (float(a.max_hp) * pct + flat) * coeff
		var eff: float = ctx.deal_heal(a, m, amt)   # 「지속 치유」 정체성이면 즉시→HoT 전환(choke)
		if eff > 0.0:
			healed += 1
			ctx.heal_threat(m, a, eff)   # F-022 §3.9 healer threat per effective HP
	if healed == 0:
		return false   # nobody needed healing → don't spend a charge
	SkillVfx.mend_circle(ctx, m.global_position, radius)
	print("[SB] %s Quick Mend — healed %d" % [m.class_id, healed])
	return true

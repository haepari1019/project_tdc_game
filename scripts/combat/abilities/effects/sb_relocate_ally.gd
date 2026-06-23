extends RefCounted
## AB-045 Lifeline (kind=skillbook_relocate_ally) — yank the most ENDANGERED ally (lowest HP ratio)
## in radius toward the caster by relocate_m. No manual target (the aim system has no ally-pick) →
## auto-select the lowest-HP living ally other than the caster. No damage. ref: F-009 · AB-045 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_relocate_ally"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 10.0))
	var dist := float(p.get("relocate_m", 5.0))
	var worst: CharacterBody3D = null
	var worst_ratio := 1.01
	for a in ctx.allies_in_radius(m.global_position, radius):
		if a == m or a == null or not is_instance_valid(a) or not a.is_alive():
			continue
		var ratio: float = float(a.hp) / maxf(float(a.max_hp), 1.0)
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst = a
	if worst == null:
		return false   # no other ally in range → don't spend a charge
	var to := m.global_position - worst.global_position
	to.y = 0.0
	if to.length() < 0.1:
		return false
	var start: Vector3 = worst.global_position
	worst.global_position += to.normalized() * minf(dist, to.length())
	SkillVfx.dash_streak(ctx, start, worst.global_position, Color(0.50, 1.0, 0.62))   # green tether yank
	print("[SB] %s Lifeline — yanked ally (%.0f%% HP) %.1fm" % [m.class_id, worst_ratio * 100.0, start.distance_to(worst.global_position)])
	return true

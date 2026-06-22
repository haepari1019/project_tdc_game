extends RefCounted
## AB-052 Sentinel Form (kind=sentinel_form) — turtle stance: heavy damage reduction + move-lock
## while foes are near. DEC-20260617-006. Reflect deferred (take_damage has no attacker source).
## Drop-in identity effect. ref: GEAR-016 · DEC(gear catalog).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "sentinel_form"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	if ctx.enemies_in_radius(m.global_position, 6.0).is_empty():
		return false   # no threat → don't lock down
	m.enter_sentinel(float(p.get("damage_reduction", 0.6)), float(p.get("duration_s", 4.0)))
	SkillVfx.anchor_guard(ctx, m.global_position, 2.0)
	print("[ID] %s Sentinel Form — DR %d%% / %.1fs" % [m.identity_skill_id, int(float(p.get("damage_reduction", 0.6)) * 100), float(p.get("duration_s", 4.0))])
	return true

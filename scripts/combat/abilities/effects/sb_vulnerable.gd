extends RefCounted
## AB-057 Focus Fire (kind=skillbook_vulnerable) — mark enemies near the aim point: they take +pct
## damage for duration_s (Vulnerable outcome; enemy take_damage reads its mag). No direct damage —
## pure team damage-amp. Single-target spec approximated as a small radius. ref: F-009 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_vulnerable"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 2.0))
	var extra := float(p.get("vulnerable_pct", 0.15))
	var dur := float(p.get("duration_s", 5.0))
	var foes: Array = ctx.enemies_in_radius(center, radius)
	if foes.is_empty():
		return false
	for e in foes:
		if e != null and is_instance_valid(e) and e.has_method("apply_outcome"):
			e.apply_outcome("Vulnerable", dur, extra)
	SkillVfx.telegraph(ctx, center, Color(1.0, 0.45, 0.55), maxf(radius, 1.5))   # focus mark
	print("[SB] %s Focus Fire — vulnerable +%d%% on %d" % [m.class_id, int(extra * 100), foes.size()])
	return true

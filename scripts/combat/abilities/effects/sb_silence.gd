extends RefCounted
## AB-044 Hush Ward (kind=skillbook_silence) — seal enemies near the aim point: Silenced for
## silence_s (ccTenacity applies). While Silenced an enemy cannot cast active skills (signature /
## zone / dash / provoke / frenzy); movement + basic attacks stay (enemy_ai gates the casts). Pre-
## emptive — does NOT interrupt an in-progress cast. No direct damage. ref: F-009 · AB-044 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_silence"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 2.0))
	var dur := float(p.get("silence_s", 3.0))
	var n := 0
	for e in ctx.enemies_in_radius(center, radius):
		if e != null and is_instance_valid(e) and e.has_method("apply_silence"):
			e.apply_silence(dur)
			SkillVfx.telegraph(ctx, e.global_position, Color(0.62, 0.42, 0.95), 1.4)   # seal rune
			n += 1
	if n == 0:
		return false   # no enemy in range → don't spend a charge
	SkillVfx.telegraph(ctx, center, Color(0.62, 0.42, 0.95), maxf(radius, 1.5))
	print("[SB] %s Hush Ward — Silenced %d (%.1fs)" % [m.class_id, n, dur])
	return true

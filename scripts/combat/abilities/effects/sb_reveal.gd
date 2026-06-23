extends RefCounted
## AB-032 Beacon Sight (kind=skillbook_reveal) — scout pulse: force every enemy visible through the
## fog for reveal_s (ctx.reveal_enemies → EnemyVisibility holds set_seen(true) for the window). Self,
## no damage. (Spec "minimap flank telegraph" approximated as a 3D fog reveal — the minimap draws
## interactables only.) ref: F-009 · F-011 · AB-032 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_reveal"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var dur := float(p.get("reveal_s", 3.5))
	ctx.reveal_enemies(dur)
	SkillVfx.telegraph(ctx, m.global_position, Color(0.97, 0.90, 0.50), 3.0)   # beacon flash
	print("[SB] %s Beacon Sight — reveal %.1fs" % [m.class_id, dur])
	return true

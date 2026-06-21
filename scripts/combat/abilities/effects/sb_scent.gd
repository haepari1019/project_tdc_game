extends RefCounted
## AB-101 Scent of Blood (kind=skillbook_scent) — mark the aimed enemy with Scented (a tracking
## mark, NOT a damage-amp): reveal/track utility. Looted from EN-3RD-01. Healer.
## NOTE: solo-party utility is modest (track/reveal) — fuller payoff (party focus) is TBD tuning.
## ref: DEC-20260621-001 / F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_scent"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var tgt: CharacterBody3D = ctx.nearest_enemy_in_range(center, float(p.get("radius_m", 3.0)))
	if tgt == null:
		return false
	if tgt.has_method("apply_outcome"):
		tgt.apply_outcome("Scented", float(p.get("scent_s", 6.0)))
	SkillVfx.telegraph(ctx, tgt.global_position, Color(0.92, 0.2, 0.22))
	print("[SB] %s Scent → enemy (marked)" % m.class_id)
	return true

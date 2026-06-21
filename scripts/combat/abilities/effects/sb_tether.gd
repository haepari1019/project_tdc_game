extends RefCounted
## AB-103 Tether (kind=skillbook_tether) — leash the aimed enemy (Tethered 4s): anti-flee positional
## control (DoT on distance-break is handled by the status carrier). Looted from EN-3RD-02. Nuker.
## ref: DEC-20260621-001 / F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_tether"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var tgt: CharacterBody3D = ctx.nearest_enemy_in_range(center, float(p.get("radius_m", 2.0)))
	if tgt == null:
		return false
	var dmg: float = float(p.get("damage_mult", 0.4)) * m.basic_damage * float(p.get("_coeff", 1.0))
	if dmg > 0.0:
		ctx.deal_damage(tgt, m, dmg)
	if tgt.has_method("apply_outcome"):
		tgt.apply_outcome("Tethered", float(p.get("tether_s", 4.0)))
	ctx.sub_shake(p)
	SkillVfx.telegraph(ctx, tgt.global_position, Color(0.72, 0.62, 0.25))  # chain amber
	print("[SB] %s Tether → enemy" % m.class_id)
	return true

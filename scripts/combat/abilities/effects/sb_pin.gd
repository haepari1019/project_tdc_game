extends RefCounted
## AB-100 Pounce (kind=skillbook_pin) — aimed burst strike that briefly PINS (move-lock 0.6s) the
## hit enemies, an opener that sets up Root/finisher. Looted from EN-3RD-01. Nuker. ref: DEC-20260621-001.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_pin"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var radius := float(p.get("radius_m", 1.8))
	var foes: Array = ctx.enemies_in_radius(center, radius)
	if foes.is_empty():
		return false
	var dmg: float = float(p.get("damage_mult", 1.2)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var pin_s := float(p.get("pin_s", 0.6))
	for e in foes:
		ctx.deal_damage(e, m, dmg)
		if e.has_method("apply_outcome"):
			e.apply_outcome("Pinned", pin_s)
	ctx.sub_shake(p)
	SkillVfx.telegraph(ctx, center, Color(0.9, 0.2, 0.2))
	print("[SB] %s Pounce — %d hit (Pinned)" % [m.class_id, foes.size()])
	return true

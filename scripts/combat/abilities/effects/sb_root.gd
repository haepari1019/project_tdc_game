extends RefCounted
## AB-102 Snare Net (kind=skillbook_root) — ranged AoE Root: enemies near the aimed point are
## MOVE-LOCKED (can still act) — a new CC distinct from stun(act-lock)/slow. Tank peel/lockdown,
## sets up the Nuker finisher. Looted from EN-3RD-02. ref: DEC-20260621-001 / F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_root"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var radius := float(p.get("radius_m", 2.5))
	var foes: Array = ctx.enemies_in_radius(center, radius)
	if foes.is_empty():
		return false
	var root_s := float(p.get("root_s", 2.0))
	var dmg: float = float(p.get("damage_mult", 0.2)) * m.basic_damage * float(p.get("_coeff", 1.0))
	for e in foes:
		if dmg > 0.0:
			ctx.deal_damage(e, m, dmg)
		if e.has_method("apply_outcome"):
			e.apply_outcome("Rooted", root_s)
	ctx.sub_shake(p)
	SkillVfx.telegraph(ctx, center, Color(0.6, 0.5, 0.3))  # net brown
	print("[SB] %s Snare Net — %d foes Rooted" % [m.class_id, foes.size()])
	return true

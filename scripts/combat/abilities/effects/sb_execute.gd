extends RefCounted
## AB-106 Devour (kind=skillbook_execute) — finisher on the aimed enemy: bonus damage vs low-HP
## prey (×execute_mult under execute_under), and ON KILL the caster is healed (chain into the next).
## Looted from EN-3RD-03. Nuker. ref: DEC-20260621-001 / F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_execute"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var tgt: CharacterBody3D = ctx.nearest_enemy_in_range(center, float(p.get("radius_m", 2.0)))
	if tgt == null:
		return false
	var dmg: float = float(p.get("damage_mult", 1.0)) * m.basic_damage * float(p.get("_coeff", 1.0))
	if tgt.hp <= tgt.max_hp * float(p.get("execute_under", 0.3)):
		dmg *= float(p.get("execute_mult", 2.0))
	ctx.deal_damage(tgt, m, dmg)
	# On-kill feed: restore the caster (chain into the next prey). Defensive — skip if no heal method.
	if (not tgt.has_method("is_alive") or not tgt.is_alive()) and m.has_method("heal"):
		m.heal(m.max_hp * float(p.get("on_kill_heal_pct", 0.2)))
	ctx.sub_shake(p)
	SkillVfx.telegraph(ctx, tgt.global_position, Color(0.85, 0.05, 0.15))
	print("[SB] %s Devour → enemy" % m.class_id)
	return true

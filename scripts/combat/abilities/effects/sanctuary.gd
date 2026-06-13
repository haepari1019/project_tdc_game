extends RefCounted
## Healer SUB Sanctuary (kind=sub_sanctuary) — big AoE heal + shield to nearby allies.
## Drop-in skill effect (ability_dispatch ctx facade).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "sub_sanctuary"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var pos := m.global_position
	var allies: Array = ctx.allies_in_radius(pos, float(p.get("radius_m", 6.5)))
	var hp_pct := float(p.get("heal_pct", 0.4))
	var sh := float(p.get("shield", 120.0))
	var sdur := float(p.get("shield_duration_s", 6.0))
	for a in allies:
		var eff: float = a.heal(a.max_hp * hp_pct)
		a.add_shield(sh, sdur)
		ctx.heal_threat(m, a, eff)
	SkillVfx.sub_sanctuary(ctx, pos, float(p.get("radius_m", 6.5)))
	print("[SUB] %s Sanctuary — %d allies" % [m.identity_skill_id, allies.size()])
	return true

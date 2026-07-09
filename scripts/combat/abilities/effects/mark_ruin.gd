extends RefCounted
## IDA-025 Mark & Ruin (kind=mark_burst) — single high-burst on lowest-HP enemy in range.
## Drop-in skill effect (ability_dispatch ctx facade).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "mark_burst"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var target: CharacterBody3D = ctx.lowest_hp_enemy_in_radius(m.global_position, float(p.get("range_m", 8.0)))
	if target == null:
		return false
	# 「집중」 빌드(조작/AI 공통) — 정체성 명중으로도 집중을 seed/stack하고, 누적 비례로 이 폭발을 증폭. DRIFT-076.
	var dmg: float = float(p.get("ruin_damage_mult", 7.0)) * m.basic_damage * ctx.nuker_focus_accumulate(m, target)
	var tpos: Vector3 = target.global_position
	ctx.deal_damage(target, m, dmg)
	SkillVfx.mark_ruin(ctx, tpos)
	print("[ID] %s Mark & Ruin -> %s (%d dmg)" % [m.identity_skill_id, target.enemy_id, int(dmg)])
	return true

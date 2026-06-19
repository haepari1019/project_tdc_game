extends RefCounted
## AB-011 Toll Stun (kind=skillbook_stun) — AoE strike + STUN: freezes enemies AND interrupts
## their channels (EN-AI-000 §2 counterplay — e.g. cancel EN-001's Mockery). ref: F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_stun"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 4.5))
	var dmg: float = float(p.get("damage_mult", 0.6)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var foes: Array = ctx.enemies_in_radius(m.global_position, radius)
	var broke: bool = ctx.damage_destructibles(m.global_position, radius, dmg)
	if foes.is_empty() and not broke:
		return false
	var stun_s := float(p.get("stun_s", 1.4))
	for e in foes:
		ctx.deal_damage(e, m, dmg)
		if e.has_method("apply_stun"):
			e.apply_stun(stun_s)          # real stun → freezes + interrupts channels (EN-AI-000 §2)
		else:
			e.apply_slow(0.05, stun_s)    # fallback for any foe without a stun state
	ctx.sub_shake(p)
	SkillVfx.sub_taunt(ctx, m.global_position, float(p.get("radius_m", 4.5)))
	print("[SB] %s Toll Stun — %d foes" % [m.class_id, foes.size()])
	return true

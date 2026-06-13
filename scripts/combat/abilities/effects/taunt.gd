extends RefCounted
## Tank SUB Taunt Slam (kind=sub_taunt) — knock back + force aggro on nearby foes + self shield.
## Drop-in skill effect (ability_dispatch ctx facade).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "sub_taunt"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var pos := m.global_position
	var foes: Array = ctx.enemies_in_radius(pos, float(p.get("radius_m", 6.5)))
	var kb := float(p.get("knockback_m", 3.0))
	var amt := float(p.get("threat_amount", 1500.0))
	for e in foes:
		e.add_threat(m, amt)
		if kb > 0.0:
			e.apply_knockback(e.global_position - pos, kb)
	m.add_shield(float(p.get("shield", 200.0)), float(p.get("shield_duration_s", 5.0)))
	ctx.damage_destructibles(pos, float(p.get("radius_m", 6.5)), m.basic_damage * 2.5)  # slam breaks barrels
	SkillVfx.sub_taunt(ctx, pos, float(p.get("radius_m", 6.5)))
	print("[SUB] %s Taunt Slam — %d foes pulled" % [m.identity_skill_id, foes.size()])
	return true

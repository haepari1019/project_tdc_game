extends RefCounted
## DPS SUB Lunge (kind=sub_lunge) — dash to the targeted ground point (clamped) + AoE strike.
## Drop-in skill effect (ability_dispatch ctx facade).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "sub_lunge"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var from := m.global_position
	var off := target_pos - from
	off.y = 0.0
	var dist := off.length()
	var range_m := float(p.get("range_m", 9.0))
	if dist > range_m:
		off = off / dist * range_m
	var dest := from + off
	dest.y = from.y
	m.global_position = dest
	var dmg: float = float(p.get("damage_mult", 5.0)) * m.basic_damage
	var aoe := float(p.get("aoe_radius_m", 2.8))
	for e in ctx.enemies_in_radius(dest, aoe):
		ctx.deal_damage(e, m, dmg)
	ctx.damage_destructibles(dest, aoe, dmg)  # break barrels at the dash target
	ctx.sub_shake(p)  # 서브 타격감: 캐스트당 1회(타깃 수와 무관)
	SkillVfx.sub_lunge(ctx, from, dest)
	print("[SUB] %s Lunge (dash strike)" % m.identity_skill_id)
	return true

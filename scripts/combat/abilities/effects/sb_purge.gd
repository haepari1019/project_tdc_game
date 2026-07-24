extends RefCounted
## AB-070 Purge Light (kind=skillbook_purge) — strip ONE buff from an enemy near the aim point.
## Today the live enemy buff is Bloodlust (Third-faction self-rage); Fortified/Hasted/Shielded/
## Warded/Regenerating are forward-compat (no enemy carries them yet). No direct damage. Spends no
## charge if there was nothing to purge. ref: F-009 · AB-070 · STATUS · DRIFT-058.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_purge"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 2.0))
	var removed := ""
	# 아군 개구리(AB-012 폴리모프) 해제 우선 — 적이 아군을 변이시켰을 때 힐러가 풀어준다.
	for a in ctx.allies_in_radius(center, radius):
		if a != null and is_instance_valid(a) and a.has_method("is_polymorphed") and a.is_polymorphed():
			a.remove_polymorph()
			removed = "개구리"
			SkillVfx.telegraph(ctx, a.global_position, Color(0.55, 0.9, 0.45), 1.6)
			break
	if removed != "":
		SkillVfx.telegraph(ctx, center, Color(1.0, 0.92, 0.55), maxf(radius, 1.5))
		print("[SB] %s Purge Light — removed %s" % [m.class_id, removed])
		return true
	for e in ctx.enemies_in_radius(center, radius):
		if e != null and is_instance_valid(e) and e.has_method("purge_one_buff"):
			removed = e.purge_one_buff()
			if removed != "":
				SkillVfx.telegraph(ctx, e.global_position, Color(1.0, 0.95, 0.6), 1.6)
				break
	if removed == "":
		return false   # nothing to purge → don't spend a charge
	SkillVfx.telegraph(ctx, center, Color(1.0, 0.92, 0.55), maxf(radius, 1.5))
	print("[SB] %s Purge Light — removed %s" % [m.class_id, removed])
	return true

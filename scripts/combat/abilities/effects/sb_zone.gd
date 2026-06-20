extends RefCounted
## Spawn-zone skillbook (kind=skillbook_zone) — AB-009/036/039/040/042/043. Lays a medium ground
## zone at the aimed spot (Oil/Water/ToxicGas/Ice/Wind/Vegetation). Combos via the RX matrix when a
## Hit event lands on it (Ember→Steam/burn/flash, Glacial→Ice…). Drop-in effect. ref: F-009/F-027.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_zone"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var pos := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var medium := String(p.get("medium", "Oil"))
	ctx.spawn_zone(medium, pos, float(p.get("radius_m", 2.0)), float(p.get("dps", 0.0)), float(p.get("ttl_s", 8.0)), m)
	SkillVfx.telegraph(ctx, pos, Color(0.6, 0.6, 0.85, 0.4), float(p.get("radius_m", 2.0)))
	print("[SB] %s spawn zone %s" % [m.class_id, medium])
	return true

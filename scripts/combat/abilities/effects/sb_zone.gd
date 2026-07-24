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
	var opts := {}
	if String(p.get("shape", "")) == "rect":
		# AB-042 Wind 복도 — 축 = 캐스터→조준점(P), P = 복도 중앙. 근단(캐스터쪽)이 최강(gradient).
		var dir := Vector3(pos.x - m.global_position.x, 0.0, pos.z - m.global_position.z)
		if dir.length() < 0.01:
			dir = -m.global_transform.basis.z   # 조준=발밑이면 시전자 정면
		opts = {"shape": "rect", "dir": dir, "length": float(p.get("length_m", 6.0)), "width": float(p.get("width_m", 2.5))}
	ctx.spawn_zone(medium, pos, float(p.get("radius_m", 2.0)), float(p.get("dps", 0.0)), float(p.get("ttl_s", 8.0)), m, opts)
	SkillVfx.telegraph(ctx, pos, Color(0.6, 0.6, 0.85, 0.4), float(p.get("radius_m", 2.0)))
	print("[SB] %s spawn zone %s" % [m.class_id, medium])
	return true

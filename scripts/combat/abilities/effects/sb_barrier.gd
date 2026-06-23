extends RefCounted
## AB-034 Rampart Slam (kind=skillbook_barrier) — spawn a Rampart Barrier (ENT-RAMPART-001) `offset_m`
## ahead of the Tank along its facing: a destructible wall that blocks forward movement for
## duration_s. Self-cast (targetType Self); facing = toward the nearest enemy (fallback forward).
## ref: F-009 · AB-034 · ENT-RAMPART-001 · DRIFT-057.


func kind() -> String:
	return "skillbook_barrier"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var facing: Vector3
	var tgt = ctx.nearest_enemy_in_range(m.global_position, 20.0)
	facing = (tgt.global_position - m.global_position) if tgt != null else Vector3(0, 0, 1)
	facing.y = 0.0
	if facing.length() < 0.1:
		facing = Vector3(0, 0, 1)
	facing = facing.normalized()
	var pos := m.global_position + facing * float(p.get("offset_m", 2.0))
	ctx.spawn_barrier(m, pos, facing, p)
	print("[SB] %s Rampart Slam — barrier (hp %d, %.1fs)" % [m.class_id, int(p.get("barrier_hp", 300)), float(p.get("duration_s", 4.0))])
	return true

extends RefCounted
## skillbook_barrier — 물리 방벽 오브젝트 소환. **두 형상**(DRIFT-107):
##  · **AB-034 Rampart Slam**(`shape: wall`) — 최근접 적 방향으로 `offset_m` 앞에 벽. 단일 방향을
##    두껍게 막고 **이동까지** 차단. 높은 HP.
##  · **AB-033 철벽 차단**(`shape: dome`) — **시전자 중심** 전방위 반구 엄폐. 이동은 통과시키고
##    투사체만 막는다. HP가 낮아 몇 발 받아내고 깨진다.
## 둘 다 자기 시전(targetType Self). ref: F-009 · AB-033/AB-034 · ENT-RAMPART-001 · DRIFT-057/107.


func kind() -> String:
	return "skillbook_barrier"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	# 돔 = 전방위라 facing이 의미 없고 위치도 시전자 중심(offset 0).
	if String(p.get("shape", "wall")) == "dome":
		ctx.spawn_barrier(m, m.global_position, Vector3(0, 0, 1), p)
		print("[SB] %s 철벽 차단 — dome r%.1f (hp %d, %.1fs)" % [m.class_id,
			float(p.get("radius_m", 3.0)), int(p.get("barrier_hp", 90)), float(p.get("duration_s", 5.0))])
		return true
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

extends SceneTree
## Surface-grid 셀 비용 벤치(dev, S1 튜닝용) — CELL_M=0.1에서 realistic 씬의 실측 비용:
## ① stamp(원→셀 래스터, S0 리빌드) ② naive CA area-tick(전 활성셀×8이웃 dict조회 = 최악) ③ frontier
## CA(경계셀만 = 올바른 설계) ④ MultiMesh transform build. GDScript·이 머신 기준 절대 ms를 찍는다.
## 실행: GODOT --headless --path . --script res://tools/surface_bench.gd  (ci_smoke 미포함)

const SurfaceGrid := preload("res://scripts/world/hazards/surface_grid.gd")

const NEI := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
	Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]


func _initialize() -> void:
	var sg = SurfaceGrid.new()
	print("=== SurfaceGrid bench @ CELL_M=%.2f (GDScript, this machine) ===" % SurfaceGrid.CELL_M)

	# 시나리오 A — "typical busy" 전투: 반경 3m 존 8개를 24×24m에 부분겹침 배치.
	var busy := []
	for i in 8:
		busy.append({"c": Vector3(float(i % 4) * 6.0, 0.0, float(i / 4) * 6.0), "r": 3.0})
	_bench("A. typical busy (8× r3, 24×24m)", sg, busy)

	# 시나리오 B — "대형 확산": 방 하나를 채운 반경 10m 단일 표면(불이 번져 방을 덮은 극단).
	_bench("B. large spread (1× r10, ~20×20m)", sg, [{"c": Vector3.ZERO, "r": 10.0}])

	# 시나리오 C — "조용": 존 2개(평시).
	_bench("C. quiet (2× r3)", sg, [{"c": Vector3.ZERO, "r": 3.0}, {"c": Vector3(5,0,0), "r": 3.0}])

	sg.free()

	# 시나리오 D — perf 리팩터 후 **실제 per-tick CA 비용**(오일 위 불 확산 busy). 10존 상당 oil + 중심 fire seed.
	var sgd: SurfaceGrid = SurfaceGrid.new()
	for i in 10:
		var oc := Vector3(float(i % 5) * 6.0, 0.0, float(i / 5) * 6.0)
		var tmp := {}
		sgd.stamp_circle(oc, 3.0, tmp)
		for k in tmp:
			var cell = SurfaceGrid.Cell.new(); cell.medium = "Oil"; cell.ttl = -1.0; cell.origin_id = 1000 + i
			sgd._cells[k] = cell
		var fk := sgd.cell_key(sgd.cell_ix(oc.x), sgd.cell_ix(oc.z))
		var fc = SurfaceGrid.Cell.new(); fc.medium = "Fire"; fc.ttl = 4.0
		sgd._cells[fk] = fc
	var nd := sgd._cells.size()
	var t := Time.get_ticks_usec()
	sgd._rebuild_index()
	sgd._expire(0.06)
	sgd._react_cells()
	sgd._fire_creep()      # oil 6링 BFS + veg 1링
	sgd._smoke_expand()
	var t_ca := (Time.get_ticks_usec() - t) / 1000.0
	print("D. busy burn (10× r3 oil+fire): cells=%d  per-tick CA(index+expire+react+creep6+smoke)=%.2fms" % [nd, t_ca])
	sgd.free()

	print("=== bench done ===")
	quit(0)


func _bench(title: String, sg, zones: Array) -> void:
	# ── stamp (원→셀) : S0 리빌드 1회 비용 ──
	var cells := {}   # key -> true (합집합)
	var t0 := Time.get_ticks_usec()
	for z in zones:
		sg.stamp_circle(z["c"], z["r"], cells)
	var t_stamp := (Time.get_ticks_usec() - t0) / 1000.0
	var n := cells.size()

	# 셀 키 배열(반복용).
	var keys := cells.keys()

	# ── naive CA area-tick : 전 활성셀마다 8이웃 dict.has (최악, 면적 스케일) ──
	var iters := 10
	var t1 := Time.get_ticks_usec()
	var _live := 0
	for _it in iters:
		for key in keys:
			var iz: int = (key & 0xFFFF) - 32768
			var ix: int = ((key >> 16) & 0xFFFF) - 32768
			for d in NEI:
				if cells.has(sg.cell_key(ix + d.x, iz + d.y)):
					_live += 1
	var t_ca := (Time.get_ticks_usec() - t1) / 1000.0 / float(iters)

	# ── frontier 집합 : 8이웃이 다 차지 않은 경계셀만(올바른 CA는 이것만 돈다) ──
	var frontier := 0
	for key in keys:
		var iz: int = (key & 0xFFFF) - 32768
		var ix: int = ((key >> 16) & 0xFFFF) - 32768
		var full := true
		for d in NEI:
			if not cells.has(sg.cell_key(ix + d.x, iz + d.y)):
				full = false
				break
		if not full:
			frontier += 1

	# ── MultiMesh transform build : 전 셀 인스턴스 트랜스폼 세팅 1회 ──
	sg._update_medium_mesh("Fire", cells, true)   # 워밍(생성)
	var t2 := Time.get_ticks_usec()
	sg._update_medium_mesh("Fire", cells, true)
	var t_render := (Time.get_ticks_usec() - t2) / 1000.0
	sg._update_medium_mesh("Fire", {}, true)      # 클리어

	print("%s" % title)
	print("   cells=%d  frontier=%d (%.0f%%)" % [n, frontier, 100.0 * float(frontier) / maxf(1.0, float(n))])
	print("   stamp=%.2fms  |  CA naive(area)=%.2fms  frontier=%.2fms(추정 = naive×frontier/cells)  |  render build=%.2fms"
		% [t_stamp, t_ca, t_ca * float(frontier) / maxf(1.0, float(n)), t_render])

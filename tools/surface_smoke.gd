extends SceneTree
## Surface-grid substrate smoke (S0/S1) — 헤드리스로 검증 가능한 셀 substrate 핵심:
## S0: world↔cell 수학 + stamp_circle 커버리지 + MultiMesh 렌더 경로. S1: outcome 권위(_tick_outcomes)가
## 존 위 유닛에 매질 효과를 정확히 적용(hazard_zone._apply_medium 이식). 실거동(A/B·성능·셀크기)은 F5 체감.
## 트리 의존 테스트가 있어 `process_frame` 첫 프레임에서 실행(_initialize 시점엔 tree 미가동). ref: docs/design/surface_grid.md.

const SurfaceGrid := preload("res://scripts/world/hazards/surface_grid.gd")

var _ok := true
var _done := false
var _case_i := 0


## 존 outcome 수신 기록용 목 유닛(S1 검증).
class MockUnit extends Node3D:
	var outcomes := {}
	var damage := 0.0
	var poisoned := false
	func apply_outcome(n: String, _dur: float, _dps: float = 0.0) -> void:
		outcomes[n] = true
	func take_damage(d: float) -> void:
		damage += d
	func apply_slow(_f: float, _d: float) -> void:
		pass
	func apply_poison_stack(_dur: float, _dps: float, _cap: float, _base: float) -> void:
		poisoned = true
	func add_threat(_s, _d: float) -> void:
		pass
	func perceive_attacker(_s) -> void:
		pass


func _initialize() -> void:
	process_frame.connect(_run)   # 첫 프레임 = tree 가동 후 → 노드 get_tree() 유효


func _run() -> void:
	if _done:
		return
	_done = true
	var sg = SurfaceGrid.new()

	# 1) cell 인덱스/중심 — 중심은 항상 원좌표에서 반 셀 이내.
	for x in [-7.3, -0.4, 0.0, 2.6, 51.9]:
		_chk(absf(sg.cell_center(sg.cell_ix(x)) - x) <= SurfaceGrid.CELL_M, "cell_center within 1 cell (x=%.1f)" % x)
	var k = sg.cell_key(-5, 12)
	var iz = (k & 0xFFFF) - 32768
	var ix = ((k >> 16) & 0xFFFF) - 32768
	_chk(ix == -5 and iz == 12, "cell_key round-trip (-5,12)")

	# 2) stamp_circle 커버리지 ≈ 원 면적/셀면적.
	var cells := {}
	sg.stamp_circle(Vector3(10.0, 0.0, -4.0), 3.0, cells)
	var exp := int(PI * 9.0 / (SurfaceGrid.CELL_M * SurfaceGrid.CELL_M))
	_chk(cells.size() >= int(exp * 0.7) and cells.size() <= int(exp * 1.3), "stamp_circle r=3 → ~%d셀 (got %d)" % [exp, cells.size()])
	var empty := {}
	sg.stamp_circle(Vector3.ZERO, 0.0, empty)
	_chk(empty.is_empty(), "radius 0 → 무스탬프")

	# 3) 렌더 경로: 매질 MultiMesh 생성 + 인스턴스 카운트 일치(무크래시).
	sg._update_medium_mesh("Fire", cells, true)
	var mmi = sg._mm.get("Fire")
	_chk(mmi != null and mmi.multimesh.instance_count == cells.size(), "Fire MultiMesh count == 셀 수")
	sg._update_medium_mesh("Fire", {}, true)
	_chk(sg._mm["Fire"].multimesh.instance_count == 0, "빈 셀 → 인스턴스 클리어")

	# 4) 디버그 순환 = 3-상태.
	var seen := {}
	for _i in 3:
		seen[sg.cycle_debug()] = true
	_chk(seen.size() == 3, "debug cycle = 3-상태")
	sg.free()

	# 5) S1 outcome 권위 — 존 위 유닛에 매질 효과 적용(존을 멀리 떨어뜨려 서로 간섭 없게).
	var grid = SurfaceGrid.new()
	get_root().add_child(grid)
	var HZ = load("res://scripts/world/hazards/hazard_zone.gd")
	_outcome_case(grid, HZ, "Fire", 8.0, false, 0.2, "Ignited")     # Fire → 점화
	_outcome_case(grid, HZ, "Fatal", 20.0, true, 0.2, "_damage")   # Fatal → raw 피해
	_outcome_case(grid, HZ, "ToxicGas", 6.0, false, HZ.POISON_STACK_S, "_poison")  # 가스(주기) → 스택

	# 6) owned cell 수명 — stamp→존재, ttl 만료→소멸, 존 소멸→origin 셀 제거.
	var zt = HZ.new()
	zt.setup(1.0, 5.0, 0.0, "Fire", false, 1.0)   # ttl 1.0s
	get_root().add_child(zt)
	zt.global_position = Vector3(500.0, 0.0, 0.0)
	grid._stamp_zones()
	_chk(_count_medium(grid, "Fire") > 0, "owned cell: stamp → 셀 존재")
	grid._expire(1.2)   # ttl 초과 → 만료
	_chk(_count_medium(grid, "Fire") == 0, "owned cell: ttl 만료 → 소멸")
	zt.free()
	var zc = HZ.new()
	zc.setup(1.0, 0.0, 0.0, "Water", false, -1.0)
	get_root().add_child(zc)
	zc.global_position = Vector3(600.0, 0.0, 0.0)
	grid._stamp_zones()
	_chk(_count_medium(grid, "Water") > 0, "owned cell: Water stamp 존재")
	zc.free()
	grid._stamp_zones()   # 존 소멸 감지 → origin 셀 제거
	_chk(_count_medium(grid, "Water") == 0, "owned cell: 존 소멸 → origin 셀 제거")

	grid.free()

	if _ok:
		print("SURFACE SMOKE PASSED")
		quit(0)
	else:
		print("SURFACE SMOKE FAILED")
		quit(1)


## 매질 존 1개 + 목 유닛 1개를 먼 곳에 놓고 _tick_outcomes → 기대 효과 검증.
func _outcome_case(grid, HZ, medium: String, dps: float, impassable: bool, dt: float, want: String) -> void:
	_case_i += 1
	var at := Vector3(float(_case_i) * 100.0, 0.0, 0.0)
	var z = HZ.new()
	z.setup(3.0, dps, 0.0, medium, impassable, -1.0)
	get_root().add_child(z)
	z.global_position = at
	var u := MockUnit.new()
	get_root().add_child(u)
	u.add_to_group("enemy")
	u.global_position = at
	grid._stamp_zones()      # owned 셀 채움(존→셀)
	grid._tick_outcomes(dt)
	match want:
		"_damage": _chk(u.damage > 0.0, "S1 outcome: %s 존 → raw damage" % medium)
		"_poison": _chk(u.poisoned, "S1 outcome: %s 존(주기) → poison stack" % medium)
		_: _chk(u.outcomes.has(want), "S1 outcome: %s 존 → %s" % [medium, want])
	z.free()
	u.free()


func _count_medium(grid, medium: String) -> int:
	var n := 0
	for key in grid._cells:
		if (grid._cells[key] as SurfaceGrid.Cell).medium == medium:
			n += 1
	return n


func _chk(cond: bool, label: String) -> void:
	if not cond:
		_ok = false
		push_error("[SURF] FAIL: %s" % label)
		print("  FAIL: %s" % label)

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


## reaction_system._ignite_oil 통합 테스트용 목 combat(camera_shake 신호 + surface_grid facade).
class MockCombat extends Node3D:
	signal camera_shake(trauma: float, kick: Vector3)
	var grid = null
	func surface_grid_fire_hits_fuel(center: Vector3, radius: float, fuel: String) -> bool:
		return grid.fire_hits_fuel(center, radius, fuel)
	func surface_grid_detach_zone_cells(oil) -> void:
		grid.detach_zone_cells(oil)


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

	# 7) 점화 순서 — Oil 소비 자리에 Fire가 남아야(우선순위로 막히면 빈 칸 = 화염바닥 사라짐 버그). 실버그 재현.
	var oil = HZ.new()
	oil.setup(2.0, 0.0, 0.0, "Oil", false, -1.0)
	get_root().add_child(oil)
	oil.global_position = Vector3(700.0, 0.0, 0.0)
	grid._stamp_zones()
	_chk(_count_medium(grid, "Oil") > 0, "ignite순서: Oil stamp")
	oil.clear_zone()   # 소비(ground_zone 이탈)
	var fire = HZ.new()
	fire.setup(2.0, 8.0, 0.0, "Fire", false, 4.0)
	get_root().add_child(fire)
	fire.global_position = Vector3(700.0, 0.0, 0.0)
	grid._stamp_zones()   # 사라진 Oil 먼저 제거 → Fire stamp 통과
	_chk(_count_medium(grid, "Fire") > 0, "ignite순서: Oil 소비 자리에 Fire 셀 남음")
	_chk(_count_medium(grid, "Oil") == 0, "ignite순서: Oil 셀 제거됨")

	# 8) render 경로 — _render_cells가 MultiMesh를 채운다(smoke가 이전엔 안 태우던 경로).
	grid._render_cells()
	var fmmi = grid._mm.get("Fire")
	_chk(fmmi != null and fmmi.multimesh.instance_count > 0, "render: _render_cells → Fire MultiMesh 채움")
	fire.free()
	grid.free()

	# 9) S3 Fire creep — Fire 인접 연료(Oil) 셀 → Fire 전환(연료 없으면 안 번짐).
	var g2 = SurfaceGrid.new()
	get_root().add_child(g2)
	var fca = SurfaceGrid.Cell.new(); fca.medium = "Fire"; fca.ttl = -1.0; fca.origin_id = 1
	g2._cells[g2.cell_key(0, 0)] = fca
	var oca = SurfaceGrid.Cell.new(); oca.medium = "Oil"; oca.ttl = -1.0; oca.origin_id = 2
	g2._cells[g2.cell_key(1, 0)] = oca
	g2._fire_creep()
	_chk(_count_medium(g2, "Fire") >= 2 and _count_medium(g2, "Oil") == 0, "S3 fire creep: Oil 인접 → Fire 전환")

	# 9b) Vegetation도 연료 — Fire 인접 Vegetation → Fire(veg creep).
	g2._cells.clear()
	var fcv = SurfaceGrid.Cell.new(); fcv.medium = "Fire"; fcv.ttl = -1.0; fcv.origin_id = 1
	g2._cells[g2.cell_key(0, 0)] = fcv
	var vcv = SurfaceGrid.Cell.new(); vcv.medium = "Vegetation"; vcv.ttl = -1.0; vcv.origin_id = 2
	g2._cells[g2.cell_key(1, 0)] = vcv
	g2._fire_creep()
	_chk(_count_medium(g2, "Fire") >= 2 and _count_medium(g2, "Vegetation") == 0, "S3 fire creep: Vegetation 인접 → Fire")

	# 10) S3 Wind push — Wind 존 인근 기체 셀이 downwind(존 밖)로 이동.
	g2._cells.clear()
	var wz = HZ.new(); wz.setup(2.0, 0.0, 0.0, "Wind", false, -1.0)
	get_root().add_child(wz); wz.global_position = Vector3(0.0, 0.0, 0.0)
	var gk := g2.cell_key(g2.cell_ix(1.0), g2.cell_ix(0.0))   # 월드 (1,0) 셀 = Wind r2 안
	var gca = SurfaceGrid.Cell.new(); gca.medium = "Steam"; gca.ttl = -1.0; gca.origin_id = 5
	g2._cells[gk] = gca
	g2._wind_push()
	_chk(_count_medium(g2, "Steam") == 1 and not g2._cells.has(gk), "S3 wind push: 기체 downwind 이동")
	wz.free()
	g2.free()

	# 11) 국소 점화 — Oil 존 가장자리 명중 → 명중 인근만 Fire, 나머지 Oil 생존+detach(존 제거돼도 살아 creep).
	var g3 = SurfaceGrid.new()
	get_root().add_child(g3)
	var oz = HZ.new(); oz.setup(3.0, 0.0, 0.0, "Oil", false, -1.0)
	get_root().add_child(oz); oz.global_position = Vector3.ZERO
	g3._stamp_zones()
	var oil_n0 := _count_medium(g3, "Oil")
	_chk(oil_n0 > 0, "국소점화: Oil stamp")
	_chk(g3.fire_hits_fuel(Vector3(2.8, 0.0, 0.0), 0.8, "Oil"), "셀점화: 가장자리 footprint가 oil에 닿음")   # +x 가장자리
	_chk(_count_medium(g3, "Fire") > 0, "셀점화: 닿은 oil 셀 → Fire")
	_chk(_count_medium(g3, "Oil") > 0 and _count_medium(g3, "Fire") < oil_n0, "셀점화: 전체 아닌 닿은 부분만, 나머지 Oil")
	g3.detach_zone_cells(oz)   # 나머지 oil 셀 detach(존 제거돼도 생존 → creep/재점화)
	var all_detached := true
	for k3 in g3._cells:
		if (g3._cells[k3] as SurfaceGrid.Cell).origin_id != 0:
			all_detached = false
	_chk(all_detached, "셀점화: detach_zone_cells 후 잔여 셀 detach(존 제거돼도 생존)")
	oz.free()
	g3.free()

	# 12) 통합 점화 — reaction_system._ignite_oil → facade → grid.ignite_oil_local(실게임 경로).
	var g4 = SurfaceGrid.new(); get_root().add_child(g4)
	var mc = MockCombat.new(); mc.grid = g4; get_root().add_child(mc)
	var RS = load("res://scripts/combat/abilities/reaction_system.gd")
	var rs = RS.new(); get_root().add_child(rs); rs.setup(mc)
	var oz2 = HZ.new(); oz2.setup(3.0, 0.0, 0.0, "Oil", false, -1.0)
	get_root().add_child(oz2); oz2.global_position = Vector3.ZERO
	g4._stamp_zones()
	_chk(_count_medium(g4, "Oil") > 0, "통합점화: oil stamp")
	rs._ignite_oil(oz2, 0, null, Vector3(2.8, 0.0, 0.0), 1.0)
	_chk(_count_medium(g4, "Fire") > 0, "통합점화: reaction._ignite_oil → facade → grid Fire 셀 + 재점화 가능")
	rs.free(); mc.free(); g4.free()

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

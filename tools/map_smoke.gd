extends SceneTree
## **맵 계약 스모크** — 맵 고도화 Phase 0의 계측기. 「구조가 데이터와 일치하는가」를 묻는다.
##
## 왜 별도 스위트인가: 맵은 **눈으로 보는 것**이라 소스 단언으로 안 잡히는 결함이 모인다 —
## `connects`에는 있는데 벽이 안 붙은 방, 개구부는 있는데 navmesh가 끊긴 방, pool은 박혔는데
## spawn_table 행이 없어 **아무 일도 안 일어나는 방**. 지금 남쪽 사슬이 그렇게 자랐다.
##
## 검사는 **맵 계약 getter를 통해서만** 한다(구현이 아니라 계약을 시험한다). 그래야 절차
## 그레이박스든 Blender authored 씬이든 **같은 스위트가 그대로 돈다** — 그게 계약이 진짜
## 계약이라는 증거다. ref: docs/design/map_upgrade_plan.html §Phase 0 / §게이트
##
## 두 종류를 나눠 출력한다:
##   [계약] 하드 실패 — 지금 지켜져야 하는 불변식. 깨지면 exit 1.
##   [설계] 리포트    — 목표치 추적(사이클 수·안개 예산·상자 EV). 현 맵은 기준선이라 실패 아님.
##
## Run: GODOT --headless --path . --script res://tools/map_smoke.gd

const LOS_EYE_Y := 1.0        # 적 시야 레이가 지나는 높이대 — 이 높이를 가리는 콜라이더만 오클루더다
const ADJ_EPS := 0.06         # 공유벽 판정 허용오차(WALL_DEDUP_EPS 0.04보다 크게)
const ADJ_MIN_OVERLAP := 0.5  # 모서리만 스치는 건 인접이 아니다
const CHEST_AREA_PER := 520.0 # dungeon_run.CHEST_AREA_PER 미러(설계 리포트용)
const CHEST_MAX_PER_ROOM := 3

var _ok := true
var _sd: Node = null          # /root/Slice01Data — --script 실행에선 전역 식별자가 안 잡힌다
var _rects: Dictionary = {}   # room_ref -> {c: Vector2, s: Vector2}


func _init() -> void:
	for _i in 3:
		await process_frame
	var sd = root.get_node_or_null("/root/Slice01Data")
	_sd = sd
	if sd == null or not sd.is_loaded():
		print("MAP SMOKE FAILED — Slice01Data not loaded")
		quit(1)
		return

	var scn = load("res://scenes/run/dungeon_run.tscn").instantiate()
	root.add_child(scn)
	for _i in 30:                      # navmesh 베이크 + nav map 동기화 + 안개 셋업까지 기다린다
		await process_frame

	var map: Node = _find_map(scn)
	if map == null:
		_expect(false, "런 씬 — 맵 노드 발견")
		_finish(scn)
		return

	_check_contract_getters(map)
	_collect_rects(map)
	var edges := _check_graph(sd, map)
	await _check_navigation(scn, map, edges)
	_check_occluders(map)
	_check_pools(sd)
	_check_ids(sd)
	_check_extraction(sd, map)
	_report_design(sd, map, edges)

	_finish(scn)


# ============================================================================
# [계약] 하드 불변식
# ============================================================================

## 계약 getter 8종. 하나라도 없으면 그 맵은 교체 후보가 아니다.
func _check_contract_getters(map: Node) -> void:
	const REQUIRED := [
		"get_spawn_position", "get_room_size", "get_deep_spawn_position",
		"get_obstacle_positions", "get_occluder_footprints", "get_room_rects",
		"get_room_profile", "get_extraction_position",
	]
	var missing: Array = []
	for m in REQUIRED:
		if not map.has_method(String(m)):
			missing.append(String(m))
	_expect(missing.is_empty(), "[계약] getter 8종 구현 (%s)" % ("전부" if missing.is_empty() else "누락: " + ", ".join(missing)))
	_expect(map.is_in_group("navmap"), "[계약] navmap 그룹 — 치명존 carve가 재bake를 부른다")


func _collect_rects(map: Node) -> void:
	for r in map.get_room_rects():
		var c: Vector3 = r["center"]
		var s: Vector3 = r["size"]
		# get_room_rects는 room_ref를 안 싣는다 — 계약을 넓히기 전까진 rooms.json 순회로 되짚는다.
		_rects[_ref_at(map, c)] = {"c": Vector2(c.x, c.z), "s": Vector2(s.x, s.z)}


## rect의 room_ref 되짚기 — get_spawn_position(ref)가 그 rect 중심과 일치하는 방을 찾는다.
func _ref_at(map: Node, center: Vector3) -> String:
	for row in _sd.get_rooms_document().get("rooms", []):
		var ref := String((row as Dictionary).get("room_ref", ""))
		var sp: Vector3 = map.get_spawn_position(ref)
		if absf(sp.x - center.x) < 0.01 and absf(sp.z - center.z) < 0.01:
			return ref
	return ""


## 그래프: 선언된 연결(rooms.json connects의 무향 합집합)이 **기하학적으로 붙어 있는가**,
## 그리고 ENTRY에서 전부 도달 가능한가. 「데이터엔 있는데 벽이 안 붙은 연결」이 여기서 죽는다.
func _check_graph(sd, map: Node) -> Array:
	var rooms: Array = sd.get_rooms_document().get("rooms", [])
	var refs: Array = []
	for row in rooms:
		refs.append(String((row as Dictionary).get("room_ref", "")))

	var resolved := 0
	for ref in refs:
		if _rects.has(ref) and float(_rects[ref]["s"].x) > 0.0:
			resolved += 1
	_expect(resolved == refs.size(), "[계약] rooms.json 방 %d개 전부 맵에서 해석됨 (%d)" % [refs.size(), resolved])

	# 무향 합집합 — 현재 데이터의 connects는 방향성이 섞여 있다(ADV-01은 ENTRY를 안 적는다).
	var edges: Array = []
	var seen: Dictionary = {}
	for row in rooms:
		var a := String((row as Dictionary).get("room_ref", ""))
		for b_v in (row as Dictionary).get("connects", []):
			var b := String(b_v)
			var key: String = ("%s|%s" % [a, b]) if a < b else ("%s|%s" % [b, a])
			if seen.has(key):
				continue
			seen[key] = true
			edges.append([a, b])

	var bad: Array = []
	for e in edges:
		if not _adjacent(String(e[0]), String(e[1])):
			bad.append("%s↔%s" % [e[0], e[1]])
	_expect(bad.is_empty(), "[계약] 선언된 연결 %d개가 전부 공유벽 (%s)" % [
		edges.size(), "일치" if bad.is_empty() else "불일치: " + ", ".join(bad)])

	# 도달성 — 시작 방에서 BFS.
	var adj: Dictionary = {}
	for e in edges:
		adj.get_or_add(String(e[0]), []).append(String(e[1]))
		adj.get_or_add(String(e[1]), []).append(String(e[0]))
	var start := "RM-ENTRY-01"
	var visited: Dictionary = {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for n in adj.get(cur, []):
			if not visited.has(n):
				visited[n] = true
				queue.append(n)
	var unreachable: Array = []
	for ref in refs:
		if not visited.has(ref):
			unreachable.append(ref)
	_expect(unreachable.is_empty(), "[계약] 전 방 도달 가능 (%s)" % (
		"%d/%d" % [visited.size(), refs.size()] if unreachable.is_empty() else "고립: " + ", ".join(unreachable)))
	return edges


## 두 방이 벽을 공유하는가(모서리 스침은 제외). 절차/authored 무관하게 rect로만 판정한다.
func _adjacent(a: String, b: String) -> bool:
	if not _rects.has(a) or not _rects.has(b):
		return false
	var ac: Vector2 = _rects[a]["c"]
	var as_: Vector2 = _rects[a]["s"]
	var bc: Vector2 = _rects[b]["c"]
	var bs: Vector2 = _rects[b]["s"]
	var ax0 := ac.x - as_.x * 0.5
	var ax1 := ac.x + as_.x * 0.5
	var az0 := ac.y - as_.y * 0.5
	var az1 := ac.y + as_.y * 0.5
	var bx0 := bc.x - bs.x * 0.5
	var bx1 := bc.x + bs.x * 0.5
	var bz0 := bc.y - bs.y * 0.5
	var bz1 := bc.y + bs.y * 0.5
	if absf(ax1 - bx0) < ADJ_EPS or absf(bx1 - ax0) < ADJ_EPS:
		return minf(az1, bz1) - maxf(az0, bz0) > ADJ_MIN_OVERLAP
	if absf(az1 - bz0) < ADJ_EPS or absf(bz1 - az0) < ADJ_EPS:
		return minf(ax1, bx1) - maxf(ax0, bx0) > ADJ_MIN_OVERLAP
	return false


## 개구부가 그림이 아닌가 — 선언된 연결마다 navmesh 경로가 실제로 뚫려 있어야 한다.
func _check_navigation(scn: Node, map: Node, edges: Array) -> void:
	var world := (scn as Node3D).get_world_3d() if scn is Node3D else null
	if world == null:
		_expect(false, "[계약] navigation map 접근")
		return
	var nav_map: RID = world.navigation_map
	for _i in 5:                                # nav 서버 동기화 여유
		await process_frame
	var blocked: Array = []
	for e in edges:
		var from: Vector3 = map.get_spawn_position(String(e[0]))
		var to: Vector3 = map.get_spawn_position(String(e[1]))
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, from, to, true)
		if path.size() < 2 or path[path.size() - 1].distance_to(to) > 3.0:
			blocked.append("%s→%s" % [e[0], e[1]])
	_expect(blocked.is_empty(), "[계약] 연결 %d개 navmesh 통행 (%s)" % [
		edges.size(), "전부" if blocked.is_empty() else "막힘: " + ", ".join(blocked)])


## **F-011의 「같은 출처」 불변식.** 안개가 쓰는 도형과 적 시야 레이캐스트가 쓰는 콜라이더는
## 같은 집합이어야 한다. 지금은 절차 생성 중에 손으로 기록하므로 우연히 맞을 뿐이고,
## Blender 맵에선 아무도 안 채운다 — Phase 0에서 **콜라이더 유도**로 바꾼다. 그때 이 줄이 증인이다.
func _check_occluders(map: Node) -> void:
	var declared: Array = map.get_occluder_footprints()
	var derived: Array = []
	_collect_los_footprints(map, derived)
	# 개수만 보면 양쪽이 같은 규칙을 쓰는 순간 무의미해진다 — **도형 하나하나를 대조**해
	# 투영 수학(회전 박스 AABB·실린더 반경)까지 시험한다.
	var unmatched := 0
	var pool: Array = derived.duplicate()
	for d in declared:
		var hit := -1
		for i in pool.size():
			if _same_footprint(d, pool[i]):
				hit = i
				break
		if hit < 0:
			unmatched += 1
		else:
			pool.remove_at(hit)
	_expect(declared.size() == derived.size() and unmatched == 0 and pool.is_empty(),
		"[계약] 오클루더 = LOS 높이대 레이어1 콜라이더 (선언 %d / 유도 %d · 미일치 %d)" % [
			declared.size(), derived.size(), unmatched + pool.size()])


## 레이어 1 콜라이더 중 **LOS 높이(y=1.0)를 가리는** 것의 수. 바닥(두께 0.3, y≤0)은 자동 제외된다 —
## 「시야를 막는가」로 판정하므로 authored 맵의 임의 지오메트리에도 같은 규칙이 선다.
## 맵 구현과 **독립적으로** 다시 계산한다(같은 규칙, 다른 코드) — 그래야 대조에 의미가 있다.
func _collect_los_footprints(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is StaticBody3D and (int((c as StaticBody3D).collision_layer) & 1) != 0:
			for cs in c.get_children():
				if cs is CollisionShape3D:
					var fp := _footprint_of(cs as CollisionShape3D)
					if not fp.is_empty():
						out.append(fp)
		_collect_los_footprints(c, out)


func _footprint_of(cs: CollisionShape3D) -> Dictionary:
	var shape: Shape3D = cs.shape
	if shape == null:
		return {}
	var xf := cs.global_transform
	if shape is BoxShape3D:
		var h: Vector3 = (shape as BoxShape3D).size * 0.5
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		var ymn := INF
		var ymx := -INF
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var w: Vector3 = xf * Vector3(h.x * sx, h.y * sy, h.z * sz)
					mn.x = minf(mn.x, w.x); mn.y = minf(mn.y, w.z)
					mx.x = maxf(mx.x, w.x); mx.y = maxf(mx.y, w.z)
					ymn = minf(ymn, w.y); ymx = maxf(ymx, w.y)
		if ymn > LOS_EYE_Y or ymx < LOS_EYE_Y:
			return {}
		return {"center": (mn + mx) * 0.5, "half": (mx - mn) * 0.5}
	if shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		var o: Vector3 = xf.origin
		if (o.y - cyl.height * 0.5) > LOS_EYE_Y or (o.y + cyl.height * 0.5) < LOS_EYE_Y:
			return {}
		return {"center": Vector2(o.x, o.z), "radius": cyl.radius}
	return {}


func _same_footprint(a: Dictionary, b: Dictionary) -> bool:
	const EPS := 0.01
	if (a["center"] as Vector2).distance_to(b["center"] as Vector2) > EPS:
		return false
	if a.has("radius") != b.has("radius"):
		return false
	if a.has("radius"):
		return absf(float(a["radius"]) - float(b["radius"])) < EPS
	return ((a["half"] as Vector2) - (b["half"] as Vector2)).length() < EPS


## pool_slot이 박혀 있는데 spawn_table 행이 없으면 「전투가 배정될 수 있는 방」인 척하는 빈 방이 된다.
func _check_pools(sd) -> void:
	var orphans: Array = []
	for row in sd.get_rooms_document().get("rooms", []):
		var d := row as Dictionary
		var pool := String(d.get("pool_slot", ""))
		if pool.is_empty():
			continue
		var layer := String(d.get("world_layer", "Upper"))
		if String(sd.get_encounter_for_pool(pool, "Normal", layer, 1)).is_empty():
			orphans.append(pool)
	_expect(orphans.is_empty(), "[계약] 모든 pool_slot이 ENC로 해석됨 (%s)" % (
		"전부" if orphans.is_empty() else "고아: " + ", ".join(orphans)))


## ID 계약 — 미등록 ID는 로드 abort 대상이다. 맵을 늘릴 때 가장 먼저 걸리는 곳이라 여기서 먼저 운다.
func _check_ids(sd) -> void:
	var raw := FileAccess.get_file_as_string("res://data/slice01/id_registry.json")
	var reg = JSON.parse_string(raw)
	if typeof(reg) != TYPE_DICTIONARY:
		_expect(false, "[계약] id_registry.json 파싱")
		return
	var rooms_reg: Array = reg.get("room_refs", [])
	var pools_reg: Array = reg.get("pool_slots", [])
	var missing: Array = []
	for row in sd.get_rooms_document().get("rooms", []):
		var d := row as Dictionary
		var ref := String(d.get("room_ref", ""))
		if not rooms_reg.has(ref):
			missing.append(ref)
		var pool := String(d.get("pool_slot", ""))
		if not pool.is_empty() and not pools_reg.has(pool):
			missing.append(pool)
	_expect(missing.is_empty(), "[계약] room_ref/pool_slot 전부 id_registry 등록 (%s)" % (
		"전부" if missing.is_empty() else "미등록: " + ", ".join(missing)))


func _check_extraction(sd, map: Node) -> void:
	var ext_ref := ""
	for row in sd.get_rooms_document().get("rooms", []):
		if not String((row as Dictionary).get("extraction_point_id", "")).is_empty():
			ext_ref = String((row as Dictionary).get("room_ref", ""))
	_expect(not ext_ref.is_empty(), "[계약] extraction_point_id를 가진 방 존재")
	if ext_ref.is_empty() or not _rects.has(ext_ref):
		return
	var p: Vector3 = map.get_extraction_position()
	var c: Vector2 = _rects[ext_ref]["c"]
	var s: Vector2 = _rects[ext_ref]["s"]
	var inside: bool = absf(p.x - c.x) <= s.x * 0.5 and absf(p.z - c.y) <= s.y * 0.5
	_expect(inside, "[계약] 추출 지점이 %s 안에 있음" % ext_ref)


# ============================================================================
# [설계] 리포트 — 목표치 추적. 현 맵은 기준선이므로 실패시키지 않는다.
# ============================================================================

func _report_design(sd, map: Node, edges: Array) -> void:
	var v: int = _rects.size()
	var e: int = edges.size()
	print("  [설계] 위상        방 %d · 연결 %d · 사이클 %d      (목표 ≥2)" % [v, e, e - v + 1])

	# 안개 예산 — 바운딩 박스 × 12 px/m × 2장. 빈 공간도 전액 지불한다.
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var floor_area := 0.0
	var chest_ev := 0.0
	var sizes: Dictionary = {}
	# 상자 EV는 **실제 배치 대상 방**만 센다 — 지금은 dungeon_run의 상수를 그대로 읽는다.
	# Phase 0에서 이 상수가 사라지고 rooms.json `loot_anchor`로 내려가면 이 줄이 먼저 운다(의도).
	var loot_rooms: Array = []
	var dr = load("res://scripts/run/dungeon_run.gd")
	if dr != null and "LOOT_CHEST_ROOMS" in dr:
		loot_rooms = dr.LOOT_CHEST_ROOMS
	for ref in _rects:
		var c: Vector2 = _rects[ref]["c"]
		var s: Vector2 = _rects[ref]["s"]
		mn.x = minf(mn.x, c.x - s.x * 0.5); mn.y = minf(mn.y, c.y - s.y * 0.5)
		mx.x = maxf(mx.x, c.x + s.x * 0.5); mx.y = maxf(mx.y, c.y + s.y * 0.5)
		var area := s.x * s.y
		floor_area += area
		if loot_rooms.is_empty() or loot_rooms.has(String(ref)):
			chest_ev += minf(area / CHEST_AREA_PER, float(CHEST_MAX_PER_ROOM))
		var key := "%.1fx%.1f" % [s.x, s.y]
		sizes[key] = int(sizes.get(key, 0)) + 1
	var span := mx - mn
	var bbox := span.x * span.y
	var pad := span + Vector2(16, 16)          # PADDING_M 8 × 2
	print("  [설계] 안개 예산    바운딩 %.0f×%.0f=%.0f m² · 바닥 %.0f m² (사용률 %.0f%%) · 텍스처 %d×%d ×2장" % [
		span.x, span.y, bbox, floor_area, floor_area / bbox * 100.0,
		int(ceil(pad.x * 12.0)), int(ceil(pad.y * 12.0))])

	# 상자 EV — 구조를 바꾸다 재화가 조용히 반토막 나는 걸 감시한다(상자가 주 공급원, ×0.2).
	print("  [설계] 상자 EV      %.1f개 / 런 (배치 대상 %d방)   (밴드 16~20)" % [chest_ev, loot_rooms.size()])

	# 전투 앵커 — 지금은 전역 가중 추첨이라 임계 경로와 무관하게 흩어진다.
	var wsum := 0.0
	var pool_rooms := 0
	for row in sd.get_rooms_document().get("rooms", []):
		var w := float((row as Dictionary).get("spawn_weight", 0.0))
		if w > 0.0:
			wsum += w
			pool_rooms += 1
	print("  [설계] 전투 앵커    pool 방 %d · 가중치 합 %.1f · 예산 4~5 (경로별 밴드 미적용)" % [pool_rooms, wsum])

	# 방 규격 다양성 — 같은 치수가 반복되면 공간으로 구분되지 않는다.
	var dup_max := 0
	var dup_key := ""
	for k in sizes:
		if int(sizes[k]) > dup_max:
			dup_max = int(sizes[k])
			dup_key = String(k)
	print("  [설계] 방 규격      최다 중복 %s ×%d / %d방" % [dup_key, dup_max, v])

	# 장애물 — grammar가 들어갈 자리. 0인 방은 전술 지형이 통째로 없다.
	var with_obs := 0
	var obs_total := 0
	for ref in _rects:
		var n: int = (map.get_obstacle_positions(String(ref)) as Array).size()
		obs_total += n
		if n > 0:
			with_obs += 1
	print("  [설계] 장애물 보유  %d / %d방 · 총 %d개" % [with_obs, v, obs_total])

	# Phase 0 진척 — 코드에 박힌 맵 좌표. 0이 되면 「맵 고칠 때 코드 수정」이 끝난다.
	var lits := _count_coord_literals("res://scripts/run/dungeon_run.gd")
	print("  [설계] 좌표 리터럴  dungeon_run.gd %d건        (Phase 0 목표 0)" % lits)


## 절대 좌표로 보이는 Vector3 리터럴 수(오프셋·방향 벡터는 제외하기 위해 큰 값만 센다).
func _count_coord_literals(path: String) -> int:
	var src := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("Vector3\\(\\s*-?\\d+\\.\\d+\\s*,\\s*-?\\d+\\.\\d+\\s*,\\s*-?\\d+\\.\\d+\\s*\\)")
	var n := 0
	for m in re.search_all(src):
		var nums := m.get_string().trim_prefix("Vector3(").trim_suffix(")").split(",")
		for s in nums:
			if absf(float(s.strip_edges())) >= 5.0:      # 5m 이상 = 월드 좌표로 본다
				n += 1
				break
	return n


# ============================================================================

func _find_map(scn: Node) -> Node:
	for c in scn.get_children():
		if c.has_method("get_room_rects"):
			return c
	return null


func _finish(scn: Node) -> void:
	scn.queue_free()
	if _ok:
		print("MAP SMOKE PASSED")
		quit(0)
	else:
		print("MAP SMOKE FAILED")
		quit(1)


func _expect(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false

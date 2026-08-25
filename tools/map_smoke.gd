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

const MeshMaterials := preload("res://scripts/core/mesh_materials.gd")
const MapConvention := preload("res://scripts/world/map_convention.gd")

const LOS_EYE_H := 1.0        # **방 바닥 기준 상대** 시야 높이(map_source.LOS_EYE_H 미러)
const ADJ_EPS := 0.06         # 공유벽 판정 허용오차(WALL_DEDUP_EPS 0.04보다 크게)
const ADJ_MIN_OVERLAP := 0.5  # 모서리만 스치는 건 인접이 아니다
const CHEST_AREA_PER := 520.0 # dungeon_run.CHEST_AREA_PER 미러(설계 리포트용)
const CHEST_MAX_PER_ROOM := 3

var _ok := true
var _sections: Dictionary = {}   # 섹션 완주 플래그 — 중간에 죽은 스모크를 초록으로 넘기지 않는다
var _sd: Node = null          # /root/Slice01Data — --script 실행에선 전역 식별자가 안 잡힌다
var _rects: Dictionary = {}   # room_ref -> {c: Vector2, s: Vector2}
## **계약만 검사하는 모드.** 기본 출정지가 아닌 blueprint로 돌 때 켜진다 — 「이 맵도 부팅되고
## 계약을 지키는가」를 묻는다. 깊은 거동 프로브(레이어 전환·계단 입력·3세력·진입 조건·순찰 주입)는
## 데모 맵의 **방 이름을 박아** 쓰므로 기본 출정지에서만 돈다.
var _contract_only := false


func _init() -> void:
	for _i in 3:
		await process_frame
	var sd = root.get_node_or_null("/root/Slice01Data")
	_sd = sd
	if sd == null or not sd.is_loaded():
		print("MAP SMOKE FAILED — Slice01Data not loaded")
		quit(1)
		return

	# **출정지를 바꿔 가며 돌 수 있다** — 「활성화」는 두 맵이 다 부팅되고 계약을 지켜야 성립한다.
	var want_bp := OS.get_environment("TDC_BLUEPRINT")
	if not want_bp.is_empty():
		if not sd.set_active_blueprint(want_bp):
			print("MAP SMOKE FAILED — 출정지 전환 실패: %s" % want_bp)
			quit(1)
			return
		_contract_only = want_bp != String(sd.get_manifest().get("blueprint_id", ""))
	print("[SMOKE] 출정지 = %s → %s%s" % [sd.active_blueprint_id(), sd.active_map_id(),
		"  (계약만)" if _contract_only else ""])

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
	_check_anchors(sd, map)
	_check_layers(map)
	_check_space_fields(sd, scn, map)
	_check_design_targets(sd, map, edges)
	_check_lock_solvable(sd, map, scn)
	_check_stair_links(map)
	_check_theme_axis(map, sd)
	_check_wake_buffer(scn, map, sd)
	_check_route_bands(scn, sd)
	await _check_playability(scn, map, sd)
	_check_readability(scn, map, sd)
	# 아래는 **데모 맵의 방 이름을 박아** 쓰는 거동 프로브다 — 기본 출정지에서만 돈다.
	# (계약 검사는 위에서 전 맵 공통으로 끝났다.)
	if not _contract_only:
		_check_layer_switch(scn, map)
		await _check_layer_transition(scn, map)
		_check_minimap_layer(scn, map)
		await _check_stairs_input(scn, map)
		_check_ground_plane()
		_check_third_layer(scn, map)
		await _check_entry_requirements(scn, map, sd)
		_check_patrol_graphs(scn, map, sd)
	_check_map_documents(sd)
	_check_extraction(sd, map)
	_report_design(sd, map, edges)
	if not _contract_only:
		await _check_import_parity(scn, map)
		await _check_authored_impl()

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
		# `get_room_rects()`가 `room_ref`·`layer`를 실어 온다 — 예전엔 좌표로 방을 역추적했다(취약·O(n²)).
		var ref := String((r as Dictionary).get("room_ref", ""))
		_rects[ref] = {"c": Vector2(c.x, c.z), "s": Vector2(s.x, s.z), "y": c.y,
			"layer": int((r as Dictionary).get("layer", 0))}


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
			var b := String((b_v as Dictionary).get("to", "")) if typeof(b_v) == TYPE_DICTIONARY else String(b_v)
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

	# 도달성 — 시작 방에서 BFS. **`connects` + 계단**을 합쳐 본다.
	# `connects`만 보면 계단으로만 닿는 **백레이어 방이 「고립」으로 잡힌다** — 실제로는 갈 수 있다.
	# (반대로 **공유벽 검사는 `connects`만** 본다. 계단은 워프라 벽을 공유하지 않는다.)
	var adj: Dictionary = {}
	for e in edges:
		adj.get_or_add(String(e[0]), []).append(String(e[1]))
		adj.get_or_add(String(e[1]), []).append(String(e[0]))
	var stairs: Array = map.stair_links() if map.has_method("stair_links") else []
	for e in stairs:
		adj.get_or_add(String(e[0]), []).append(String(e[1]))
		adj.get_or_add(String(e[1]), []).append(String(e[0]))
	var start := String(map.get_entry_room())
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
	_expect(unreachable.is_empty(), "[계약] 전 방 도달 가능 — connects %d + 계단 %d (%s)" % [
		edges.size(), stairs.size(),
		"%d/%d" % [visited.size(), refs.size()] if unreachable.is_empty() else "고립: " + ", ".join(unreachable)])
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
	for _i in 5:                                # nav 서버 동기화 여유
		await process_frame

	# ① **방 기준점이 navmesh 위에 있는가.** 기준점은 스폰·경로 질의의 출발점이다 — 그 위에 장애물이
	#    있으면 질의가 방을 못 벗어나고, 증상은 「연결 막힘」으로 나타나 **원인을 엉뚱한 곳으로** 가리킨다
	#    (실제로 그랬다: 원인은 방 중심에 놓인 기둥이었다).
	var buried: Array = []
	for ref in _rects:
		var room := String(ref)
		var nm: RID = map.get_nav_map(int((_rects[room] as Dictionary).get("layer", 0)))
		var sp: Vector3 = map.get_spawn_position(room)
		var cp: Vector3 = NavigationServer3D.map_get_closest_point(nm, sp)
		var probe: Vector3 = sp + Vector3(0, 0, 0)
		# 기준점에서 **같은 방 안 다른 지점**으로 경로가 나는가 — 기둥 속에 갇히면 안 난다.
		var sz: Vector2 = (_rects[room] as Dictionary)["s"]
		var away: Vector3 = sp + Vector3(sz.x * 0.3, 0, sz.y * 0.3)
		var pth: PackedVector3Array = NavigationServer3D.map_get_path(nm, sp, away, true)
		# **도착하는가**를 묻는다 — 「경로가 존재하는가」만 보면 기둥 속 작은 섬에서도 2점짜리
		# 경로가 나와 통과한다(반증 확인에서 실제로 그랬다).
		var arrived: bool = pth.size() >= 2 and Vector2(
			pth[pth.size() - 1].x - away.x, pth[pth.size() - 1].z - away.z).length() < 1.5
		if Vector2(cp.x - sp.x, cp.z - sp.z).length() > 1.0 or not arrived:
			buried.append(room)
	_expect(buried.is_empty(), "🔴 [계약] 방 기준점이 **navmesh 위**에 있다 — 장애물에 파묻히면 경로가 안 난다 (%s)" % (
		"전부" if buried.is_empty() else "파묻힘: " + ", ".join(buried)))

	# ② 연결 통행. **각 방의 층 맵**으로 묻는다 — 층이 XZ를 공유하므로 layer 0 맵으로 물으면
	#    layer 1 연결이 「위층을 걸어서」 판정돼 항상 막힌 것처럼 보인다.
	var blocked: Array = []
	for e in edges:
		var ra := String(e[0])
		var rb := String(e[1])
		var nm2: RID = map.get_nav_map(int((_rects.get(ra, {}) as Dictionary).get("layer", 0)))
		var from: Vector3 = map.get_spawn_position(ra)
		var to: Vector3 = map.get_spawn_position(rb)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nm2, from, to, true)
		if path.size() < 2 or path[path.size() - 1].distance_to(to) > 3.0:
			blocked.append("%s→%s" % [ra, rb])
	_expect(blocked.is_empty(), "[계약] 연결 %d개 navmesh 통행 (%s)" % [
		edges.size(), "전부" if blocked.is_empty() else "막힘: " + ", ".join(blocked)])


## **F-011의 「같은 출처」 불변식.** 안개가 쓰는 도형과 적 시야 레이캐스트가 쓰는 콜라이더는
## 같은 집합이어야 한다. 지금은 절차 생성 중에 손으로 기록하므로 우연히 맞을 뿐이고,
## Blender 맵에선 아무도 안 채운다 — Phase 0에서 **콜라이더 유도**로 바꾼다. 그때 이 줄이 증인이다.
func _check_occluders(map: Node) -> void:
	var declared: Array = map.get_all_occluder_footprints()   # 「같은 출처」는 레이어 무관 전체와 대조
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
## 미러도 **전 층**을 본다. 예전엔 `& 1`(layer 0 비트)만 봐서, 층이 둘인 맵에서
## 「같은 출처」 검사가 layer 0끼리만 비교하고 layer 1을 통째로 놓쳤다.
func _collect_los_footprints(n: Node, out: Array) -> void:
	for c in n.get_children():
		var bit: int = int((c as StaticBody3D).collision_layer) if c is StaticBody3D else 0
		if c is StaticBody3D and (bit & _world_mask_all()) != 0:
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
	var eye: float = _floor_y_at(Vector2(xf.origin.x, xf.origin.z), xf.origin.y) + LOS_EYE_H
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
		if ymn > eye or ymx < eye:
			return {}
		return {"center": (mn + mx) * 0.5, "half": (mx - mn) * 0.5}
	if shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		var o: Vector3 = xf.origin
		if (o.y - cyl.height * 0.5) > eye or (o.y + cyl.height * 0.5) < eye:
			return {}
		return {"center": Vector2(o.x, o.z), "radius": cyl.radius}
	if shape is ConvexPolygonShape3D:
		var pts: PackedVector3Array = (shape as ConvexPolygonShape3D).points
		if pts.is_empty():
			return {}
		var flat := PackedVector2Array()
		var ymn := INF
		var ymx := -INF
		var acc := Vector2.ZERO
		for v in pts:
			var w: Vector3 = xf * v
			flat.append(Vector2(w.x, w.z))
			acc += Vector2(w.x, w.z)
			ymn = minf(ymn, w.y)
			ymx = maxf(ymx, w.y)
		if ymn > eye or ymx < eye:
			return {}
		var hull := Geometry2D.convex_hull(flat)
		if hull.size() < 3:
			return {}
		return {"center": acc / float(pts.size()), "poly": hull}
	return {}


## 맵 구현과 독립적으로 계산한다 — `_rects`(계약 getter 결과)만 보고 바닥 높이를 되짚는다.
## 구현(`map_source.floor_y_at`)과 **같은 규칙**이어야 「같은 출처」 검사가 의미를 갖는다:
## 층 메타데이터가 아니라 **`near_y`에 가장 가까운 바닥**을 고른다.
func _floor_y_at(xz: Vector2, near_y: float = INF) -> float:
	var best := 0.0
	var best_d := INF
	for ref in _rects:
		var c: Vector2 = _rects[ref]["c"]
		var sz: Vector2 = _rects[ref]["s"]
		if absf(xz.x - c.x) > sz.x * 0.5 + 0.5 or absf(xz.y - c.y) > sz.y * 0.5 + 0.5:
			continue
		var fy := float((_rects[ref] as Dictionary).get("y", 0.0))
		if near_y == INF:
			return fy
		var d: float = absf(near_y - fy)
		if d < best_d:
			best_d = d
			best = fy
	return best if best_d < INF else 0.0


func _same_footprint(a: Dictionary, b: Dictionary) -> bool:
	const EPS := 0.01
	if (a["center"] as Vector2).distance_to(b["center"] as Vector2) > EPS:
		return false
	if a.has("radius") != b.has("radius") or a.has("poly") != b.has("poly"):
		return false
	if a.has("radius"):
		return absf(float(a["radius"]) - float(b["radius"])) < EPS
	if a.has("poly"):
		var pa := a["poly"] as PackedVector2Array
		var pb := b["poly"] as PackedVector2Array
		if pa.size() != pb.size():
			return false
		for i in pa.size():
			if pa[i].distance_to(pb[i]) > EPS:
				return false
		return true
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


## 앵커가 **방 안에** 있는가 + 코드가 찾는 role/ref가 실재하는가.
## 하드코딩을 데이터로 내리면 오타 하나가 조용히 「원점에 놓인 열쇠 상자」가 된다.
func _check_anchors(sd, map: Node) -> void:
	var kinds := ["obstacles", "interactions", "hazards", "transitions", "props"]
	var outside: Array = []
	var total := 0
	for ref in _rects:
		var c: Vector2 = _rects[ref]["c"]
		var s2: Vector2 = _rects[ref]["s"]
		for k in kinds:
			for a in map.get_anchors(String(ref), k):
				total += 1
				var p: Vector3 = (a as Dictionary)["pos"]
				if absf(p.x - c.x) > s2.x * 0.5 + 0.01 or absf(p.z - c.y) > s2.y * 0.5 + 0.01:
					outside.append("%s/%s" % [ref, k])
	_expect(total > 0 and outside.is_empty(), "[계약] 앵커 %d개가 전부 방 안 (%s)" % [
		total, "전부" if outside.is_empty() else "벗어남: " + ", ".join(outside)])

	# dungeon_run이 이름으로 찾는 앵커들 — 하나라도 없으면 그 오브젝트가 시작 방에 떨어진다.
	var need := [["interactions", "role", "key_chest"], ["interactions", "role", "ally_cache"],
		["transitions", "role", "key_gate"], ["hazards", "role", "plate"], ["hazards", "role", "lever"],
		["props", "ref", "ENT-BARREL-001"], ["props", "ref", "ENT-TORCH-001"]]
	var missing: Array = []
	for n in need:
		var found := false
		for a in map.get_all_anchors(String(n[0])):
			if String((a as Dictionary).get(String(n[1]), "")) == String(n[2]):
				found = true
		if not found:
			missing.append("%s=%s" % [n[1], n[2]])
	_expect(missing.is_empty(), "[계약] 런이 찾는 앵커 7종 존재 (%s)" % (
		"전부" if missing.is_empty() else "없음: " + ", ".join(missing)))


## **XZ 중첩 금지 + 방마다 오클루더 ≥ 1** — 다층(백레이어) 구조를 열기 전에 세워 두는 방어선.
## ① 안개는 XZ 텍스처 하나다. 같은 레이어에서 방이 겹치면 위층이 아래층을 지운다.
##    (레이어 축이 데이터에 들어오면 이 검사는 **레이어별**로 갈린다 — 다른 레이어끼리는 겹쳐도 된다.)
## ② 벽이 있는데 오클루더가 0개면 그 방은 **안개가 없는 방**이다. 절대 Y 버그가 정확히 그 증상이었고,
##    개수 대조만으로는 양쪽이 사이좋게 0을 반환해 통과한다 — 그래서 **방마다** 따로 센다.
func _check_layers(map: Node) -> void:
	var refs: Array = _rects.keys()
	var overlaps: Array = []
	for i in refs.size():
		for j in range(i + 1, refs.size()):
			var a: Dictionary = _rects[refs[i]]
			var b: Dictionary = _rects[refs[j]]
			if int(a.get("layer", 0)) != int(b.get("layer", 0)):
				continue   # **다른 레이어끼리는 겹쳐도 된다** — 그게 백레이어의 요점이다
			var ax: float = (a["s"] as Vector2).x * 0.5 + (b["s"] as Vector2).x * 0.5
			var az: float = (a["s"] as Vector2).y * 0.5 + (b["s"] as Vector2).y * 0.5
			var d: Vector2 = (a["c"] as Vector2) - (b["c"] as Vector2)
			if absf(d.x) < ax - 0.1 and absf(d.y) < az - 0.1:
				overlaps.append("%s↔%s" % [refs[i], refs[j]])
	_expect(overlaps.is_empty(), "[계약] **같은** 레이어 방 XZ 중첩 없음 (%s)" % (
		"전부" if overlaps.is_empty() else "겹침: " + ", ".join(overlaps)))

	var bare: Array = []
	for ref in _rects:
		var c: Vector2 = _rects[ref]["c"]
		var sz: Vector2 = _rects[ref]["s"]
		var n := 0
		for occ in map.get_all_occluder_footprints():
			if int((occ as Dictionary).get("layer", 0)) != int(_rects[ref].get("layer", 0)):
				continue
			var o: Vector2 = occ["center"]
			if absf(o.x - c.x) <= sz.x * 0.5 + 1.0 and absf(o.y - c.y) <= sz.y * 0.5 + 1.0:
				n += 1
		if n == 0:
			bare.append(String(ref))
	_expect(bare.is_empty(), "[계약] 방마다 오클루더 ≥ 1 — 안개 없는 방 없음 (%s)" % (
		"전부" if bare.is_empty() else "0개: " + ", ".join(bare)))


## **공간 필드 검증** (spec `LDG-001` §9 · `DEC-20260824-001`).
## ① enum 오타는 조용히 기본값으로 떨어진다 — `category` 오타 하나면 그 방이 `optional_threat`가 되어
##    진행 게이트가 다시 확률에 걸린다. 값 자체를 검사한다.
## ② **`gated_elite`는 실제로 스폰됐는가** — 데이터에 적어 두고 리졸버가 안 읽으면 아무 일도 안 난다.
##    허브 사다리(무기고 T1·대장간 T3)가 여기 걸려 있다.
func _check_space_fields(sd, scn: Node, _map_ref: Node) -> void:
	const CATEGORIES := ["mandatory_threat", "gated_elite", "optional_threat", "patrol_route",
		"ambush_candidate", "third_faction_candidate", "safe"]
	const GRAMMARS := ["open", "choke", "los_broken", "split", "flank", "backline_pocket"]
	var bad: Array = []
	var gated_rooms: Array = []
	var by_cat: Dictionary = {}
	for row in sd.get_rooms_document().get("rooms", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var ref := String((row as Dictionary).get("room_ref", ""))
		if not (row as Dictionary).has("layer"):
			bad.append("%s: layer 없음" % ref)
		var cat := String(((row as Dictionary).get("encounter_anchor", {}) as Dictionary).get("category", ""))
		if not CATEGORIES.has(cat):
			bad.append("%s: category `%s`" % [ref, cat])
		else:
			by_cat[cat] = int(by_cat.get(cat, 0)) + 1
			if cat == "gated_elite":
				gated_rooms.append(ref)
		for g in (row as Dictionary).get("spatial_grammar", []):
			if not GRAMMARS.has(String(g)):
				bad.append("%s: grammar `%s`" % [ref, g])
	_expect(bad.is_empty(), "[계약] 공간 필드 enum 유효 (%s)" % (
		"전부" if bad.is_empty() else ", ".join(bad)))

	# ② 리졸버가 실제로 읽는가 — 부팅된 런의 분대 배치를 본다.
	var combat: Node = null
	for c in scn.get_children():
		if c.has_method("prespawn_encounters"):
			combat = c
	if combat == null or not ("_squads" in combat):
		_expect(false, "[계약] CombatController 분대 목록 접근")
		return
	# `get_maps()[0]` 지뢰 제거의 증인 — 적이 **자기 방 층의 nav 맵**에 묶여 있는가.
	var bound := 0
	var wrong := 0
	for e in combat._enemies:
		if not is_instance_valid(e):
			continue
		var want: RID = _map_ref.get_nav_map(int(e.get("nav_layer")))
		if (e.get("nav_map_rid") as RID).is_valid():
			bound += 1
			if (e.get("nav_map_rid") as RID) != want:
				wrong += 1
	_expect(bound > 0 and wrong == 0,
		"🔴 [계약/레이어] 적 %d기가 **자기 층 nav 맵**에 묶임 (불일치 %d) — 전역 get_maps()[0] 제거" % [bound, wrong])

	var spawned: Array = []
	for sq in combat._squads:
		spawned.append(String((sq as Dictionary).get("room_ref", "")))
	var missing: Array = []
	for r in gated_rooms:
		if not spawned.has(r):
			missing.append(String(r))
	_expect(not gated_rooms.is_empty() and missing.is_empty(),
		"🔴 [계약] gated_elite %d방이 전부 스폰됨 — 진행 게이트가 확률에 안 걸린다 (%s)" % [
			gated_rooms.size(), "전부" if missing.is_empty() else "누락: " + ", ".join(missing)])
	print("  [설계] 공간 역할    " + JSON.stringify(by_cat))


## **맵이 선언한 목표치를 강제한다** (`rooms.json` `design_targets`).
## 목표치를 코드 상수로 두면 맵마다 다른 값을 가질 수 없어서, 데모 맵을 봐주려고 게이트를 통째로
## 느슨하게 만들게 된다. **맵이 자기 목표를 들고 오면** 신규 그레이박스가 엄격한 값을 선언하는 순간
## 코드 변경 없이 게이트가 세진다.
func _check_design_targets(sd, map: Node, edges: Array) -> void:
	var t: Dictionary = sd.get_rooms_document().get("design_targets", {})
	if t.is_empty():
		_expect(false, "[계약] rooms.json `design_targets` 선언")
		return

	# 사이클 = **E − V + C**. 예전엔 C를 1로 고정했는데, 층이 갈린 맵은 `connects` 그래프의
	# 성분이 2개 이상이라 그 식이 사이클을 **과소 계산**한다(백레이어가 붙으면 1 줄어든 것처럼 보인다).
	var adj: Dictionary = {}
	for ref in _rects:
		adj[String(ref)] = []
	for e in edges:
		if adj.has(String(e[0])) and adj.has(String(e[1])):
			(adj[String(e[0])] as Array).append(String(e[1]))
			(adj[String(e[1])] as Array).append(String(e[0]))
	var comps := _components(adj.keys(), adj)
	var cycles: int = edges.size() - _rects.size() + comps
	var min_c: int = int(t.get("min_cycles", 0))
	_expect(cycles >= min_c, "[계약] 사이클 %d ≥ 목표 %d (E%d − V%d + C%d)" % [
		cycles, min_c, edges.size(), _rects.size(), comps])

	var band: Array = t.get("chest_ev_band", [0, 999])
	var ev := _chest_ev(sd)
	_expect(ev >= float(band[0]) and ev <= float(band[1]),
		"[계약] 상자 EV %.1f ∈ [%s, %s] — 구조를 바꾸다 재화가 조용히 반토막 나지 않게" % [ev, band[0], band[1]])

	var bmax: Array = t.get("bbox_max_m", [9999, 9999])
	var span := _bbox_span()
	_expect(span.x <= float(bmax[0]) and span.y <= float(bmax[1]),
		"[계약] 안개 바운딩 %.0f×%.0f ≤ %s×%s m — 빈 공간도 텍스처를 전액 낸다" % [span.x, span.y, bmax[0], bmax[1]])


## **잠금 그래프 해결 가능성** — 메트로배니아 최다 사고가 「열쇠가 잠긴 방 안에」다.
## `entry_requirement`가 요구하는 것을 **그 방에 들어가지 않고** 얻을 수 있어야 한다.
func _check_lock_solvable(sd, map: Node, scn: Node) -> void:
	var locked: Array = []      # [{room, ref}]
	var yields_at: Dictionary = {}   # 산출물 -> room_ref
	for row in sd.get_rooms_document().get("rooms", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var ref := String((row as Dictionary).get("room_ref", ""))
		var req: Dictionary = (row as Dictionary).get("entry_requirement", {})
		if not req.is_empty() and not String(req.get("ref", "")).is_empty():
			locked.append({"room": ref, "need": String(req.get("ref", ""))})
		for kind in ["interactions", "props", "hazards"]:
			for a in map.get_anchors(ref, kind):
				var y := String((a as Dictionary).get("yields", ""))
				if not y.is_empty():
					yields_at[y] = ref
	if locked.is_empty():
		print("  [설계] 잠금        없음")
		return
	var bad: Array = []
	for l in locked:
		var need := String(l["need"])
		var src := String(yields_at.get(need, ""))
		if src.is_empty():
			bad.append("%s: `%s` 산출처 없음(어떤 앵커도 yields 안 함)" % [l["room"], need])
		elif src == String(l["room"]):
			bad.append("%s: 열쇠 `%s`가 **잠긴 방 안**에 있다" % [l["room"], need])
	_expect(bad.is_empty(), "🔴 [계약] 잠금 %d개 해결 가능 (%s)" % [
		locked.size(), "전부" if bad.is_empty() else ", ".join(bad)])

	# 데이터가 선언한 산출물 id가 **실제로 배치된 상자 안에 있는가.** 예전엔 dungeon_run.gd 소스를
	# grep해 문자열 존재만 봤다 — 코드가 id를 데이터에서 읽게 되면(하드코딩 제거) 그 검사는
	# **아무것도 검사하지 않는 상태**가 된다. 그래서 텍스트가 아니라 **부팅된 씬의 상자를 열어 본다**.
	var in_chests: Array = []
	for c in scn.get_children():
		if not ("items" in c):
			continue
		for it in (c.get("items") as Array):
			if typeof(it) == TYPE_DICTIONARY:
				in_chests.append(String((it as Dictionary).get("id", "")))
	var ghost: Array = []
	for y in yields_at:
		if not in_chests.has(String(y)):
			ghost.append(String(y))
	_expect(ghost.is_empty(), "🔴 [계약] 선언된 `yields`가 **실제 상자 안에** 있다 (%s)" % (
		"전부" if ghost.is_empty() else "없음: " + ", ".join(ghost)))

	# 문이 요구하는 열쇠 = 잠긴 방이 요구하는 열쇠. 열쇠가 둘 이상이면 부분 문자열 판정이
	# 「아무 열쇠나 아무 문을 여는」 상태가 되므로, **문에 id가 실렸는지**를 못 박는다.
	for c in scn.get_children():
		if not ("key_id" in c) or not ("rule" in c):
			continue
		# **열쇠를 요구하는 규칙일 때만** id를 묻는다. `onObjectiveComplete` 문은 열쇠가 없는 게 정상이고,
		# 그걸 요구하면 「열쇠가 아닌 진입 조건」이라는 축 자체를 부정하게 된다.
		var rule := String(c.get("rule"))
		if rule != "requiresItem" and rule != "onBossKey":
			continue
		var kid := String(c.get("key_id"))
		var want := ""
		for l in locked:
			if String(l["need"]) == kid:
				want = kid
		_expect(not kid.is_empty() and want == kid,
			"🔴 [계약] 잠긴 문이 **정확한 열쇠 id**를 안다 (`%s`)" % kid)


## **레이어 전환** — 계단이 부를 경로를 실제로 돌려 본다(오클루더·탐색 기억·가시성이 함께 가는가).
## 현 맵은 layer 0 하나뿐이라 layer 1로 가면 **아무것도 없는 층**이 되는데, 그 자체가 검사가 된다:
## 오클루더 0 · 방 전부 숨김 · 되돌아오면 원복. 「전환이 무언가를 빠뜨리는가」를 여기서 잡는다.
func _check_layer_switch(scn: Node, map: Node) -> void:
	var fog: Node = null
	for c in scn.get_children():
		if c.has_method("switch_layer") and c.has_method("toggle_world_fog"):
			fog = c
	if fog == null:
		_expect(false, "[계약/레이어] VisionFog.switch_layer 존재")
		return
	var room: Node = map.geometry_root().get_node_or_null("RM-ADV-01")
	var before: int = map.get_occluder_footprints().size()
	_expect(before > 0 and int(map.get_active_layer()) == 0 and room != null and (room as Node3D).visible,
		"[계약/레이어] 전환 전 — layer 0 · 오클루더 %d · 방 보임" % before)

	fog.call("switch_layer", 1)
	_expect(int(map.get_active_layer()) == 1 and map.get_occluder_footprints().is_empty(),
		"🔴 [계약/레이어] layer 1로 전환 — 활성 층이 바뀌고 **그 층 오클루더만** 남는다 (%d)" % map.get_occluder_footprints().size())
	_expect(room != null and not (room as Node3D).visible,
		"🔴 [계약/레이어] 비활성 층 지오메트리가 **숨는다** — 층이 XZ를 공유하므로 겹쳐 그려지면 안 된다")

	fog.call("switch_layer", 0)
	_expect(int(map.get_active_layer()) == 0 and map.get_occluder_footprints().size() == before
		and room != null and (room as Node3D).visible,
		"[계약/레이어] 되돌아오면 원복 (오클루더 %d)" % map.get_occluder_footprints().size())


## **계단 전이** — 지금까지 만든 조각이 처음으로 함께 도는 자리.
## 묻는 것 셋: ① 결집 안 되면 거절하는가 ② down/MIA는 **조건이 아니라 두고 가는 것**인가
## ③ 전이가 한 트랜잭션으로 도는가(활성 층·파티 위치·nav 바인딩).
func _check_layer_transition(scn: Node, map: Node) -> void:
	var tx: Node = null
	for c in scn.get_children():
		if c.has_method("transition") and c.has_method("can_transition"):
			tx = c
	var party: Node = _find_party(root)
	if tx == null or party == null:
		_expect(false, "[계약/전이] LayerTransition · PartyController 접근")
		return
	var members: Array = party.get_members()
	var at: Vector3 = (members[0] as Node3D).global_position
	# 게이트에서는 **페이드를 끈다** — 전이가 한 프레임 안에 끝나야 판정이 타이밍에 안 걸린다.
	# (프레임이 흐르면 `mia_controller`가 결속 모드에서 인위적 MIA를 **자동 해제**해 버린다.)
	tx.set("_fade", null)

	# ① 한 명을 멀리 보내면 거절된다.
	var stray: Node3D = members[3] as Node3D
	var keep := stray.global_position
	stray.global_position = at + Vector3(60, 0, 0)
	var g1: Dictionary = tx.can_transition(at)
	_expect(not bool(g1["ok"]) and (g1["missing"] as Array).size() == 1,
		"🔴 [계약/전이] 결집 안 되면 거절 — 파티를 찢지 않는다 (%s)" % str(g1["missing"]))

	# ② 그 멤버가 MIA면 **조건에서 빠진다** — 두고 가는 것이지 막는 것이 아니다.
	stray.set_mia(true)
	var g2: Dictionary = tx.can_transition(at)
	_expect(bool(g2["ok"]),
		"🔴 [계약/전이] MIA는 결집 조건이 아니다 — **두고 간다**(막지 않는다)")

	# ③ 전이 실행 — 행동 가능한 멤버만 옮겨지고 MIA는 그 자리에 남는다.
	var mia_pos := stray.global_position
	var dest_room := "RM-ADV-05"
	var ok: bool = await tx.transition(dest_room, 1, at)
	_expect(ok, "[계약/전이] 전이 성공")
	_expect(int(map.get_active_layer()) == 1, "[계약/전이] 활성 층이 바뀐다 (%d)" % map.get_active_layer())
	var dest: Vector3 = map.get_spawn_position(dest_room)
	var moved := 0
	for m in members:
		if m == stray:
			continue
		if (m as Node3D).global_position.distance_to(dest) < 6.0:
			moved += 1
	_expect(moved == 3, "[계약/전이] 행동 가능한 3명이 목적지로 (%d)" % moved)
	# MIA 멤버는 **살아서 계속 시뮬레이션**되므로 조금 움직인다(앵커 복귀 시도 등).
	# 물어야 할 것은 「안 움직였나」가 아니라 **「목적지로 순간이동되지 않았나」**다.
	_expect(stray.global_position.distance_to(dest) > 20.0
		and stray.global_position.distance_to(mia_pos) < 15.0,
		"🔴 [계약/전이] **MIA 멤버는 안 따라온다** — 남은 층에 회수 부채로 남는다 (목적지까지 %.0f m)"
			% stray.global_position.distance_to(dest))
	_expect((members[0] as Node3D).get("nav_layer") == 1,
		"[계약/전이] 파티 nav 바인딩이 새 층으로 (%s)" % str((members[0] as Node3D).get("nav_layer")))

	# 복원 — 뒤 검사들이 layer 0을 전제한다. MIA를 풀고 **파티 옆으로** 데려온다
	# (원래 자리로 되돌리면 결집이 안 돼 복귀 전이가 거절된다 — 픽션상으론 그게 맞는 동작이다).
	stray.set_mia(false)
	stray.global_position = (members[0] as Node3D).global_position + Vector3(1.5, 0, 0)
	var _keep_unused := keep
	await tx.transition(String(map.get_entry_room()), 0, (members[0] as Node3D).global_position)
	_expect(int(map.get_active_layer()) == 0, "[계약/전이] 되돌아오면 layer 0")


## **미니맵이 활성 층만 그리는가** — 인지 부하 방어선(`F-024`). 층이 XZ를 공유하므로 전부 그리면
## 겹쳐서 「지금 어느 층인지」를 잃는다. 그리기 자체는 검사할 수 없으니 **그릴 목록**을 본다.
func _check_minimap_layer(scn: Node, map: Node) -> void:
	var mini: Node = _find_by_method(scn, "visible_rects")
	if mini == null:
		_expect(false, "[계약/레이어] 미니맵 접근")
		return
	var n0: int = (mini.call("visible_rects") as Array).size()
	_expect(n0 == _rects.size(), "[계약/레이어] 미니맵이 layer 0 방 %d개를 그린다 (%d)" % [_rects.size(), n0])
	map.set_active_layer(1)
	var n1: int = (mini.call("visible_rects") as Array).size()
	map.set_active_layer(0)
	_expect(n1 == 0,
		"🔴 [계약/레이어] 활성 층을 바꾸면 미니맵이 **그 층 방만** 그린다 (layer 1 = %d개)" % n1)
	_expect((mini.call("stairs_positions") as Array).is_empty(),
		"[계약/레이어] 계단 마커 — 현 맵엔 계단 앵커가 없어 0개(신규 그레이박스에서 생긴다)")


func _find_by_method(n: Node, m: String) -> Node:
	if n.has_method(m):
		return n
	for c in n.get_children():
		var r := _find_by_method(c, m)
		if r != null:
			return r
	return null


## **계단 링크 파싱** — `transitions` 앵커는 문(`key_gate`)도 계단(`stairs`)도 담는다.
## 역할을 구분하지 않으면 **문을 계단으로 취급**해 도달성이 거짓으로 통과한다(문은 열쇠가 있어야 하고
## 계단은 층을 넘는다 — 성격이 다르다). 지금 맵엔 계단이 없고 문이 하나 있으므로 그 구분이 그대로 검사가 된다.
func _check_stair_links(map: Node) -> void:
	# `transitions`는 계단과 **잠긴 문**을 함께 담는다. 물어야 할 것은 「계단이 0개인가」가 아니라
	# **역할로 갈리는가**다 — 데모는 문만, UPPER는 둘 다 있다.
	var trans_n := 0
	var role_stairs := 0
	for a in map.get_all_anchors("transitions"):
		trans_n += 1
		if String((a as Dictionary).get("role", "")) == "stairs":
			role_stairs += 1
	_expect(trans_n > 0 and (map.stair_links() as Array).size() == role_stairs,
		"🔴 [계약] `transitions` %d개 중 계단 %d개만 `stair_links()` — **문(key_gate)을 계단으로 안 센다**" % [
			trans_n, role_stairs])

	# 계단을 하나 심어 파싱·복원을 확인한다(런타임 주입 — 데이터는 안 건드린다).
	var host := String(map.get_entry_room())
	var block: Dictionary = map._anchors.get(host, {})
	var had: bool = block.has("transitions")
	var saved: Array = block.get("transitions", [])
	var probe_to := ""            # 시작 방이 아닌 아무 방 — 맵마다 이름이 다르므로 데이터에서 고른다
	for r in map.data_room_refs():
		if String(r) != host:
			probe_to = String(r)
			break
	var before_n: int = (map.stair_links() as Array).size()
	block["transitions"] = saved.duplicate()
	(block["transitions"] as Array).append({"role": "stairs", "to": probe_to,
		"pos": map.get_spawn_position(host)})
	map._anchors[host] = block
	var links: Array = map.stair_links()
	var found := false
	for l in links:
		if String(l[0]) == host and String(l[1]) == probe_to:
			found = true
	_expect(found and links.size() == before_n + 1,
		"[계약] 계단 앵커가 `stair_links()`에 잡힌다 (%d → %d)" % [before_n, links.size()])
	if had:
		block["transitions"] = saved
	else:
		block.erase("transitions")
	map._anchors[host] = block
	_expect((map.stair_links() as Array).size() == before_n, "[계약] 주입 제거 후 복원 (%d)" % before_n)


func _check_extraction(sd, map: Node) -> void:
	# 탈출 지점은 **여럿일 수 있다**(Point마다 활성 조건이 다르다, `F-006` §3.10) —
	# 하나만 보면 탈출 방이 둘인 맵에서 나머지가 **죽은 방**인 채로 통과한다.
	var declared: Array = []
	for row in sd.get_rooms_document().get("rooms", []):
		if not String((row as Dictionary).get("extraction_point_id", "")).is_empty():
			declared.append(String((row as Dictionary).get("room_ref", "")))
	_expect(not declared.is_empty(), "[계약] extraction_point_id를 가진 방 존재 (%d)" % declared.size())
	var pts: Array = map.get_extraction_points(true)
	_expect(pts.size() == declared.size(),
		"🔴 [계약] 선언한 탈출 지점 %d개가 **전부 계약에 실린다** (%d)" % [declared.size(), pts.size()])
	var outside: Array = []
	for e in pts:
		var ref := String((e as Dictionary).get("room", ""))
		if not _rects.has(ref):
			outside.append(ref + "(방 없음)")
			continue
		var p: Vector3 = (e as Dictionary)["pos"]
		var c: Vector2 = _rects[ref]["c"]
		var s2: Vector2 = _rects[ref]["s"]
		if absf(p.x - c.x) > s2.x * 0.5 or absf(p.z - c.y) > s2.y * 0.5:
			outside.append(ref)
	_expect(outside.is_empty(), "[계약] 탈출 지점이 전부 자기 방 안 (%s)" % (
		"전부" if outside.is_empty() else "벗어남: " + ", ".join(outside)))


## **두 번째 MapSource 구현을 실제로 돌린다.** 플랜의 「절차 맵과 authored 씬 둘 다 같은 불변식」이
## 이 절이다 — 계약이 진짜 계약인지는 **구현이 둘일 때만** 증명된다.
## 실제 `.glb`가 없으므로 규약대로 지은 **합성 씬**을 만들어 `AuthoredMapSource`에 물린다.
## 여기서 통과하지 못하는 것은 실제 임포트에서도 통과하지 못한다(반대는 성립하지 않는다 —
## 임포트 고유의 차이는 `tools/import_post.gd` 머리의 미검증 목록 참조).
func _check_authored_impl() -> void:
	# ① 이름 규약 파서 — 임포트 후처리와 런타임이 **같은 파서**를 쓰므로 여기가 규약의 정본이다.
	var cases := [
		["MK_spawn", "spawn", "", ""],
		["MK_enc_2", "encounters", "", ""],
		["MK_int_CHEST-DEMO-01", "interactions", "CHEST-DEMO-01", ""],
		["MK_int__ally_cache", "interactions", "", "ally_cache"],
		["MK_haz_trap_split_lever__plate", "hazards", "trap_split_lever", "plate"],
		["MK_obs_pillar", "obstacles", "pillar", ""],
		["MK_prop_ENT-TORCH-001.001", "props", "ENT-TORCH-001", ""],   # Blender 사본 접미사
	]
	# 🔴 문자열 파서만 시험하면 **실제 노드에서만 깨지는** 결함을 놓친다 — Godot은 노드 이름에서
	#    `. : @ / " %` 를 조용히 지운다. 규약 구분자가 그 정화를 견디는지 여기서 못 박는다.
	var probe := Marker3D.new()
	probe.name = "MK_haz_trap_split_lever" + MapConvention.ROLE_SEP + "plate"
	_expect(String(probe.name) == "MK_haz_trap_split_lever" + MapConvention.ROLE_SEP + "plate",
		"[계약/authored] role 구분자가 Godot 노드 이름 정화를 견딘다 (`%s`)" % MapConvention.ROLE_SEP)
	probe.free()

	var bad: Array = []
	for c in cases:
		var m: Dictionary = MapConvention.parse_marker(String(c[0]))
		if String(m.get("kind", "")) != String(c[1]) or String(m.get("ref", "")) != String(c[2]) 				or String(m.get("role", "")) != String(c[3]):
			bad.append(String(c[0]))
	_expect(bad.is_empty() and MapConvention.parse_marker("Cube.003").is_empty(),
		"[계약/authored] 마커 이름 규약 파서 (%s)" % ("전부" if bad.is_empty() else "실패: " + ", ".join(bad)))

	# ② 규약대로 지은 합성 씬 → AuthoredMapSource. 좌표의 소유자가 **씬**이라는 점이 절차와 정반대다.
	const REF := "RM-ADV-05"                       # 실재하는 room_ref(오타 방어가 걸린다)
	var origin := Vector3(500.0, 0.0, 0.0)         # 실제 맵에서 멀리
	var src := Node3D.new()
	src.set_script(load("res://scripts/world/authored_map_source.gd"))
	var scene_root := Node3D.new()
	scene_root.name = "AuthoredRoot"
	src.add_child(scene_root)
	var room := Node3D.new()
	room.name = REF
	room.position = origin
	scene_root.add_child(room)

	var trig := Area3D.new()                        # TRIG_room — 방 중심 + 크기
	trig.name = MapConvention.TRIGGER_NAME
	var tshape := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(27.0, 4.0, 22.5)
	tshape.shape = tbox
	trig.add_child(tshape)
	room.add_child(trig)

	for spec in [["MK_spawn", Vector3(0, 0, 0)], ["MK_int__ally_cache", Vector3(2, 0, 2)],
			["MK_haz_trap_split_lever__plate", Vector3(0, 0, 5)], ["MK_obs_pillar", Vector3(-6, 0, 3)],
			["MK_loot_1", Vector3(4, 0, -4)]]:
		var mk := Marker3D.new()
		mk.name = String(spec[0])
		mk.position = spec[1]
		room.add_child(mk)

	var floor_mi := MeshInstance3D.new()            # GEO_floor — navmesh가 설 바닥
	floor_mi.name = "GEO_floor-col"
	var fm := BoxMesh.new()
	fm.size = Vector3(27.0, 0.3, 22.5)
	floor_mi.mesh = fm
	floor_mi.position = Vector3(0, -0.15, 0)
	var fbody := StaticBody3D.new()
	fbody.collision_layer = 1
	var fcs := CollisionShape3D.new()
	var fbs := BoxShape3D.new()
	fbs.size = fm.size
	fcs.shape = fbs
	fbody.add_child(fcs)
	floor_mi.add_child(fbody)
	room.add_child(floor_mi)

	var wall := MeshInstance3D.new()                # GEO_* — 임포트 계층(메시가 부모)
	wall.name = "GEO_wall-col"
	var wm := BoxMesh.new()
	wm.size = Vector3(27.0, 3.5, 0.4)
	wall.mesh = wm
	wall.position = Vector3(0, 1.75, 11.25)
	var wbody := StaticBody3D.new()
	wbody.collision_layer = 1
	var wcs := CollisionShape3D.new()
	var wbs := BoxShape3D.new()
	wbs.size = wm.size
	wcs.shape = wbs
	wbody.add_child(wcs)
	wall.add_child(wbody)
	room.add_child(wall)

	root.add_child(src)                             # 여기서 _ready → build_from_scene + 유도 + 베이크
	for _i in 6:
		await process_frame

	# ③ 계약 getter가 **같은 방식으로** 답하는가.
	_expect(src.get_room_rects().size() == 1, "[계약/authored] 방 해석 (%d)" % src.get_room_rects().size())
	var sz: Vector3 = src.get_room_size(REF)
	_expect(absf(sz.x - 27.0) < 0.01 and absf(sz.z - 22.5) < 0.01,
		"[계약/authored] TRIG_room → 방 크기 (%.1f × %.1f)" % [sz.x, sz.z])
	_expect(src.get_spawn_position(REF).distance_to(origin) < 0.01, "[계약/authored] MK_spawn → 방 기준점")

	var ints: Array = src.get_anchors(REF, "interactions")
	var hazs: Array = src.get_anchors(REF, "hazards")
	var obss: Array = src.get_anchors(REF, "obstacles")
	var loots: Array = src.get_anchors(REF, "loot")
	_expect(ints.size() == 1 and String((ints[0] as Dictionary).get("role", "")) == "ally_cache",
		"[계약/authored] MK_int__role → interactions 앵커")
	_expect(hazs.size() == 1 and String((hazs[0] as Dictionary).get("ref", "")) == "trap_split_lever"
		and String((hazs[0] as Dictionary).get("role", "")) == "plate",
		"[계약/authored] MK_haz_ref__role → hazards 앵커")
	_expect(obss.size() == 1 and String((obss[0] as Dictionary).get("type", "")) == "pillar",
		"[계약/authored] MK_obs_type → obstacles 앵커(킷 타입)")
	_expect(loots.size() == 1 and (loots[0] as Dictionary)["pos"].distance_to(origin + Vector3(4, 0, -4)) < 0.01,
		"[계약/authored] 앵커 좌표가 **씬**에서 온다(월드 변환)")

	# ④ 오클루더 유도 · navmesh — 절차와 같은 코드 경로다.
	_expect(src.get_occluder_footprints().size() == 1,
		"[계약/authored] 벽 1 + 바닥 1 → 오클루더 1개(바닥은 LOS 규칙에서 자동 제외) (%d)" % src.get_occluder_footprints().size())
	var nav: NavigationRegion3D = null
	for c in src.get_children():
		if c is NavigationRegion3D:
			nav = c as NavigationRegion3D
	_expect(nav != null and nav.navigation_mesh != null and nav.navigation_mesh.get_polygon_count() > 0,
		"[계약/authored] navmesh 베이크 (%d polys)" % (nav.navigation_mesh.get_polygon_count() if nav != null and nav.navigation_mesh != null else 0))

	# ⑤-b 🔴 **내려간 구획(백레이어) 회귀 테스트.** 여기가 이번 수정의 증인이다.
	#    LOS 기준 높이를 **절대 월드 Y**로 두면 바닥 y=−6인 방의 벽(y∈[−6,−2.5])이 y=1.0을 안 가려
	#    **오클루더에서 통째로 빠진다** — 안개 없는 방이 조용히 생긴다. 게이트도 못 잡는다(양쪽이
	#    같은 절대 규칙이라 사이좋게 0으로 일치한다). 상대 높이로 고쳤고, 그 증명이 이 블록이다.
	const SUNK_REF := "RM-ADV-04"
	var sunk_origin := Vector3(500.0, -6.0, -60.0)     # 지상 방과 XZ가 안 겹치게
	var sroom := Node3D.new()
	sroom.name = SUNK_REF
	sroom.position = sunk_origin
	scene_root.add_child(sroom)
	var strig := Area3D.new()
	strig.name = MapConvention.TRIGGER_NAME
	var stshape := CollisionShape3D.new()
	var stbox := BoxShape3D.new()
	stbox.size = Vector3(27.0, 4.0, 22.5)
	stshape.shape = stbox
	strig.add_child(stshape)
	sroom.add_child(strig)
	var smk := Marker3D.new()
	smk.name = "MK_spawn"
	sroom.add_child(smk)
	var swall := MeshInstance3D.new()                   # 바닥 기준 +1.75 → 월드 y = −4.25
	swall.name = "GEO_wall-col"
	var swm := BoxMesh.new()
	swm.size = Vector3(27.0, 3.5, 0.4)
	swall.mesh = swm
	swall.position = Vector3(0, 1.75, 11.25)
	var swbody := StaticBody3D.new()
	swbody.collision_layer = 1
	var swcs := CollisionShape3D.new()
	var swbs := BoxShape3D.new()
	swbs.size = swm.size
	swcs.shape = swbs
	swbody.add_child(swcs)
	swall.add_child(swbody)
	sroom.add_child(swall)
	await process_frame

	src.build_from_scene(scene_root)
	src.derive_occluders()
	_expect(absf(src.get_spawn_position(SUNK_REF).y - (-6.0)) < 0.01,
		"[계약/authored] 내려간 방의 바닥 높이가 계약에 실린다 (y=%.1f)" % src.get_spawn_position(SUNK_REF).y)
	var sunk_found := false
	for occ in src.get_occluder_footprints():
		if (occ["center"] as Vector2).distance_to(Vector2(sunk_origin.x, sunk_origin.z + 11.25)) < 0.5:
			sunk_found = true
	_expect(sunk_found,
		"🔴 [계약/authored] **바닥 y=−6 방의 벽이 오클루더로 잡힌다**(절대 Y였으면 0개 — 안개 없는 방)")
	_expect(src.get_occluder_footprints().size() == 2,
		"[계약/authored] 지상 1 + 지하 1 = 오클루더 2개 (%d)" % src.get_occluder_footprints().size())

	# ⑤ 규약 검증기 — 임포트 시점에 「트리거 없는 방」을 잡는다(런타임까지 끌고 가지 않는다).
	_expect(MapConvention.validate_room(room).is_empty(), "[계약/authored] 규약 검증 통과(정상 방)")
	trig.name = "TRIG_room_typo"
	var probs: Array = MapConvention.validate_room(room)
	_expect(probs.size() == 1 and String(probs[0]).contains("TRIG_room"),
		"[계약/authored] 규약 위반 검출(트리거 오타)")

	# ⑤-b2 🔴 **백레이어 증명 — 같은 XZ에 두 레이어를 겹쳐 놓는다.**
	#    이게 성립해야 「옆으로 치우지 않고 겹친다」(스펠렁키식)가 가능하고, 안개 바운딩이 안 커진다.
	#    지오메트리의 **콜리전 비트가 곧 레이어**이므로(layer 0 = 비트 1, layer 1 = 비트 16),
	#    유도가 비트를 읽어 층을 가르고 활성 레이어만 안개에 넘긴다.
	var over_xz := Vector2(sunk_origin.x, sunk_origin.z + 11.25)   # 지하 벽과 **정확히 같은 XZ**
	var l1 := StaticBody3D.new()
	l1.collision_layer = src.world_bit(1)          # ← layer 1 비트(16)
	l1.position = Vector3(0.0, 1.75, 11.25)        # **방 로컬** — 지하 벽과 같은 자리
	var l1cs := CollisionShape3D.new()
	var l1bs := BoxShape3D.new()
	l1bs.size = Vector3(27.0, 3.5, 0.4)
	l1cs.shape = l1bs
	l1.add_child(l1cs)
	sroom.add_child(l1)
	await process_frame
	src.derive_occluders()

	var all_n: int = src.get_all_occluder_footprints().size()
	src.set_active_layer(0)
	var a0: Array = src.get_occluder_footprints()
	src.set_active_layer(1)
	var a1: Array = src.get_occluder_footprints()
	src.set_active_layer(0)
	_expect(all_n == a0.size() + a1.size() and a0.size() > 0 and a1.size() == 1,
		"🔴 [계약/레이어] 같은 XZ에 두 레이어 공존 — 전체 %d = layer0 %d + layer1 %d" % [all_n, a0.size(), a1.size()])
	# 같은 XZ에 **두 층의 벽이 각각** 있고, 조회하면 **자기 층 것만** 나온다.
	var n0 := 0
	for occ in a0:
		if (occ["center"] as Vector2).distance_to(over_xz) < 0.5:
			n0 += 1
	var n1 := 0
	for occ in a1:
		if (occ["center"] as Vector2).distance_to(over_xz) < 0.5:
			n1 += 1
	_expect(n0 == 1 and n1 == 1,
		"🔴 [계약/레이어] 같은 XZ의 벽이 층별로 **각각 1개씩** 잡힌다 (layer0 %d · layer1 %d)" % [n0, n1])
	_expect(a1.size() == 1, "[계약/레이어] 활성 레이어를 1로 바꾸면 **그 층 것만** 보인다 (%d)" % a1.size())
	# layer 1에 **바닥**도 깔고 다시 구우면 그 층이 자기 리전·자기 nav 맵을 갖는다.
	var l1f := StaticBody3D.new()
	l1f.collision_layer = src.world_bit(1)
	l1f.position = Vector3(0.0, -0.15, 0.0)
	var l1fcs := CollisionShape3D.new()
	var l1fbs := BoxShape3D.new()
	l1fbs.size = Vector3(27.0, 0.3, 22.5)
	l1fcs.shape = l1fbs
	l1f.add_child(l1fcs)
	sroom.add_child(l1f)
	await process_frame
	src.bake_navigation()
	for _i in 4:
		await process_frame

	_expect(src.layers_present().has(1), "[계약/레이어] 지오메트리에서 layer 1을 발견 (%s)" % str(src.layers_present()))
	var r1: Node = src.get_node_or_null("NavRegion_L1")
	var r0: Node = src.get_node_or_null("NavRegion_L0")
	_expect(r0 != null and r1 != null, "[계약/레이어] 층마다 NavigationRegion3D")
	_expect(src.get_nav_map(1) != src.get_nav_map(0),
		"🔴 [계약/레이어] layer 1이 **자기 nav 맵**을 갖는다 — 층이 XZ를 공유해도 경로가 안 섞인다")
	var poly1: int = (r1 as NavigationRegion3D).navigation_mesh.get_polygon_count() if r1 != null and (r1 as NavigationRegion3D).navigation_mesh != null else 0
	_expect(poly1 > 0, "[계약/레이어] layer 1 navmesh 베이크 (%d polys)" % poly1)

	# 🔴 **층 격리 증명 — 같은 광선을 다른 층 마스크로 쏜다.**
	#    지상 방(layer 0)의 벽을 가로지르는 광선: layer 0 마스크로는 막히고, layer 1 마스크로는
	#    **통과해야 한다**. 안 그러면 남의 층 벽이 시야를 막아 「보이지 않는 벽」이 생긴다.
	var wall_world: Vector3 = wall.global_position           # 지상 방 벽(layer 0 전용)
	var ray_a := wall_world + Vector3(0, -1.0, -4.0)
	var ray_b := wall_world + Vector3(0, -1.0, 4.0)
	var space := src.get_world_3d().direct_space_state
	var q0 := PhysicsRayQueryParameters3D.create(ray_a, ray_b, src.world_bit(0))
	var q1 := PhysicsRayQueryParameters3D.create(ray_a, ray_b, src.world_bit(1))
	var hit0: Dictionary = space.intersect_ray(q0)
	var hit1: Dictionary = space.intersect_ray(q1)
	_expect(not hit0.is_empty(), "[계약/레이어] layer 0 벽이 layer 0 광선을 막는다")
	_expect(hit1.is_empty(),
		"🔴 [계약/레이어] layer 0 벽이 layer 1 광선을 **안 막는다** — 남의 층 벽은 보이지 않는 벽이 되면 안 된다")

	l1f.free()
	l1.free()
	src.derive_occluders()

	src.free()

	# ⑤-c **레이어 전제 — MIA·다운 멤버로는 스왑할 수 없다.**
	#    레이어 전이는 「행동 가능한 파티 전원」이 함께 가고 `down`/`MIA`는 남는다. 그런데 남겨진
	#    멤버로 **스왑이 되면** 조작 가능한 파티가 두 레이어에 나뉘어 전제가 깨진다(활성 레이어 1개 가정).
	#    `F-001` §3.6이 규정하고 `PartyController.try_swap_to()`가 이미 구현하는데 **시험이 없었다.**
	var party: Node = _find_party(root)
	if party == null:
		_expect(false, "[계약/레이어] PartyController 접근")
	else:
		var members: Array = party.get_members()
		_expect(members.size() >= 2, "[계약/레이어] 파티 %d명" % members.size())
		if members.size() >= 2:
			var target := 1
			var m: Node = members[target]
			m.set_mia(true)
			_expect(not party.try_swap_to(target),
				"🔴 [계약/레이어] MIA 멤버로 스왑 불가 — 파티가 두 레이어에 나뉘지 않는다")
			m.set_mia(false)
			_expect(party.try_swap_to(target), "[계약/레이어] MIA 해제 후엔 스왑된다(과잉 차단 아님)")

	# ⑥ **임포트 후처리의 변환 로직** — glTF에는 Area3D·Marker3D가 없다. Blender Empty는 Node3D로
	#    들어오고, 규약대로 런타임 노드로 바꾸는 것이 `import_post.convert_tree`다. 실제 `.glb`는
	#    아직 없지만 **변환 로직 자체는 여기서 매 커밋 돌린다**(고스트 코드로 두지 않는다).
	var ImportPost = load("res://tools/import_post.gd")
	var imported := Node3D.new()
	imported.name = "ImportedMap"
	var iroom := Node3D.new()
	iroom.name = "RM-ADV-05"
	imported.add_child(iroom)
	var raw_trig := Node3D.new()            # Blender Empty — 아직 Area3D가 아니다
	raw_trig.name = MapConvention.TRIGGER_NAME
	raw_trig.scale = Vector3(13.5, 1.0, 11.25)
	iroom.add_child(raw_trig)
	var raw_mk := Node3D.new()
	raw_mk.name = "MK_spawn"
	raw_mk.position = Vector3(1, 0, 2)
	iroom.add_child(raw_mk)
	var raw_int := Node3D.new()
	raw_int.name = "MK_int_CHEST-DEMO-01"
	iroom.add_child(raw_int)
	root.add_child(imported)
	var probs2: Array = ImportPost.convert_tree(imported)
	_expect(probs2.is_empty(), "[계약/authored] 임포트 변환 — 규약 통과 (%s)" % (
		"문제 없음" if probs2.is_empty() else ", ".join(probs2)))
	var conv_trig: Node = iroom.get_node_or_null(MapConvention.TRIGGER_NAME)
	var conv_mk: Node = iroom.get_node_or_null("MK_spawn")
	_expect(conv_trig is Area3D and conv_mk is Marker3D,
		"[계약/authored] Empty → Area3D / Marker3D 변환")
	_expect(conv_mk != null and (conv_mk as Node3D).position.is_equal_approx(Vector3(1, 0, 2)),
		"[계약/authored] 변환이 위치를 보존")
	var tsz := Vector3.ZERO
	if conv_trig is Area3D:
		for cc in conv_trig.get_children():
			if cc is CollisionShape3D and (cc as CollisionShape3D).shape is BoxShape3D:
				tsz = ((cc as CollisionShape3D).shape as BoxShape3D).size
	_expect(absf(tsz.x - 27.0) < 0.01 and absf(tsz.z - 22.5) < 0.01,
		"[계약/authored] Empty 스케일 → 트리거 크기 (%.1f × %.1f)" % [tsz.x, tsz.z])
	# 규약 위반은 임포트 시점에 선다(런타임까지 안 끌고 간다).
	iroom.get_node("MK_spawn").name = "MK_spwan"      # 오타
	var probs3: Array = ImportPost.convert_tree(imported)
	_expect(probs3.size() >= 1, "[계약/authored] 임포트 변환 — 규약 위반 검출 (%d건)" % probs3.size())
	imported.free()

	# ⑦ **`@tool` 프리뷰의 전제** — 생성 노드에 `owner`를 설정하지 않으면 `.tscn`에 저장되지 않는다.
	#    이게 「에디터 = 뷰어」가 성립하는 이유이고, 사람이 프리뷰를 손으로 옮겨도 데이터와 두 벌이
	#    되지 않는 근거다. Godot 동작에 기대는 규칙이므로 **여기서 못 박아 둔다**(버전이 바뀌면 운다).
	var host := Node3D.new()
	var kept := Node3D.new()
	kept.name = "Authored"
	host.add_child(kept)
	kept.owner = host                       # 저작된 노드 = 저장된다
	var gen := Node3D.new()
	gen.name = "GeneratedPreview"
	host.add_child(gen)                     # owner 미설정 = 저장되지 않는다
	var ps := PackedScene.new()
	ps.pack(host)
	var inst: Node = ps.instantiate()
	_expect(inst.get_node_or_null("Authored") != null and inst.get_node_or_null("GeneratedPreview") == null,
		"[계약/authored] owner 미설정 생성 노드는 .tscn에 직렬화되지 않는다(@tool 프리뷰 전제)")
	inst.free()
	host.free()

	_sections["authored_impl"] = true


## **authored(Blender 임포트) 계층 파리티** — 「절차 맵과 authored 씬이 같은 계약을 만족한다」를
## 실제로 시험한다. 임포트 씬이 없으므로 그 계층을 **흉내 낸 더미**를 맵에 잠깐 붙인다:
##   MeshInstance3D(부모) → StaticBody3D(자식, layer 1) · 머티리얼은 mesh surface에만.
## 절차 생성물과 계층도 머티리얼 자리도 정반대라, 셋 다 이 모양에서 조용히 깨졌던 것들이다.
func _check_import_parity(scn: Node, map: Node) -> void:
	var root: Node3D = map.geometry_root()
	var before: int = map.get_occluder_footprints().size()

	var bm := BoxMesh.new()
	bm.size = Vector3(4.0, 3.5, 0.4)
	bm.material = StandardMaterial3D.new()          # surface에만 — material_override는 비운다
	var mi := MeshInstance3D.new()
	mi.name = "GEO_import_parity_probe"
	mi.mesh = bm
	var body := StaticBody3D.new()                  # Godot `-col` 임포트가 만드는 계층(메시가 부모)
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	body.add_child(cs)
	mi.add_child(body)
	mi.position = Vector3(0.0, 1.75, -300.0)        # 실제 방에서 멀리 떨어뜨린다
	root.add_child(mi)
	await process_frame

	# ① 오클루더 유도가 **뒤집힌 계층**에서도 잡는가 (F-011 같은 출처).
	map.derive_occluders()
	var found := false
	for occ in map.get_occluder_footprints():
		if (occ["center"] as Vector2).distance_to(Vector2(0.0, -300.0)) < 0.01:
			found = true
	_expect(found and map.get_occluder_footprints().size() == before + 1,
		"[계약/authored] 임포트 계층 오클루더 유도 (%d → %d)" % [before, map.get_occluder_footprints().size()])

	# ② 콜라이더 → 메시 되짚기(X-ray). 절차는 body가 부모, 임포트는 mesh가 부모다.
	_expect(MeshMaterials.mesh_of_collider(body) == mi, "[계약/authored] 콜라이더→메시 계층 반전 대응")

	# ③ 안개가 surface 머티리얼 메시를 잡는가. 예전 조건(material_override)은 여기서 **조용히 스킵**했다.
	_expect(mi.material_override == null, "[계약/authored] 더미가 material_override 없이 구성됨")
	var fog: Node = null
	for c in scn.get_children():
		if c.has_method("fog_object") and c.has_method("toggle_world_fog"):
			fog = c
	if fog == null:
		_expect(false, "[계약/authored] VisionFog 노드 발견")
	else:
		fog.call("fog_object", mi)
		var sm: Material = mi.get_surface_override_material(0)
		_expect(sm is BaseMaterial3D and (sm as BaseMaterial3D).next_pass != null,
			"[계약/authored] 안개 next_pass가 surface 머티리얼에 적재됨")
		_expect(sm is BaseMaterial3D and sm != bm.material,
			"[계약/authored] 공유 surface 리소스가 아니라 인스턴스 복제본")

	# ④ **볼록 프록시(사선 벽)** — 축정렬 사각형에 갇히지 않는다는 것을 여기서 시험한다.
	#    box/cyl은 편의 표기이고, 안개가 원래 그리는 것은 폴리곤이다.
	var conv := ConvexPolygonShape3D.new()
	var cp := PackedVector3Array()
	for sy in [-1.75, 1.75]:
		cp.append(Vector3(-3.0, sy, -0.2)); cp.append(Vector3(3.0, sy, -0.2))
		cp.append(Vector3(2.0, sy, 0.2));   cp.append(Vector3(-3.0, sy, 0.2))
	conv.points = cp
	var cs2 := CollisionShape3D.new()
	cs2.shape = conv
	var body2 := StaticBody3D.new()
	body2.collision_layer = 1
	body2.rotation_degrees = Vector3(0, 30, 0)      # 사선으로 돌려 둔다
	body2.position = Vector3(0.0, 1.75, -340.0)
	body2.add_child(cs2)
	root.add_child(body2)
	await process_frame
	map.derive_occluders()
	var poly_ok := false
	for occ in map.get_occluder_footprints():
		if occ.has("poly") and (occ["poly"] as PackedVector2Array).size() >= 3:
			poly_ok = true
	_expect(poly_ok, "[계약/authored] 볼록(사선) 콜라이더 → poly 오클루더 유도")
	body2.free()

	_sections["import_parity"] = true
	mi.free()
	map.derive_occluders()                          # 기준선 복원
	_expect(map.get_occluder_footprints().size() == before, "[계약/authored] 프로브 제거 후 복원 (%d)" % before)


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
	# (상자 EV·바운딩은 게이트와 같은 헬퍼를 쓴다 — 두 벌 계산이 어긋나지 않게)
	# 상자 EV는 **실제 배치 대상 방**만 센다 — 대상은 rooms.json `loot_anchor`가 소유한다
	# (Phase 0에서 dungeon_run.LOOT_CHEST_ROOMS 상수를 대체했다).
	var loot_rooms: Array = []
	for row in sd.get_rooms_document().get("rooms", []):
		if typeof(row) == TYPE_DICTIONARY and (row as Dictionary).has("loot_anchor"):
			loot_rooms.append(String((row as Dictionary).get("room_ref", "")))
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

## 상자 기대치 — `loot_anchor`를 가진 방만, 면적 비례(방당 상한 3).
func _chest_ev(sd) -> float:
	var loot: Array = []
	for row in sd.get_rooms_document().get("rooms", []):
		if typeof(row) == TYPE_DICTIONARY and (row as Dictionary).has("loot_anchor"):
			loot.append(String((row as Dictionary).get("room_ref", "")))
	var ev := 0.0
	for ref in _rects:
		if loot.has(String(ref)):
			var sz: Vector2 = _rects[ref]["s"]
			ev += minf(sz.x * sz.y / CHEST_AREA_PER, float(CHEST_MAX_PER_ROOM))
	return ev


## 안개가 값을 치르는 바운딩 박스(XZ). 빈 공간도 전액 낸다.
func _bbox_span() -> Vector2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for ref in _rects:
		var c: Vector2 = _rects[ref]["c"]
		var sz: Vector2 = _rects[ref]["s"]
		mn.x = minf(mn.x, c.x - sz.x * 0.5); mn.y = minf(mn.y, c.y - sz.y * 0.5)
		mx.x = maxf(mx.x, c.x + sz.x * 0.5); mx.y = maxf(mx.y, c.y + sz.y * 0.5)
	return mx - mn


## 트리에서 PartyController 찾기(_check_authored_impl은 씬 참조를 안 받는다).
func _find_party(n: Node) -> Node:
	if n.has_method("try_swap_to") and n.has_method("get_members"):
		return n
	for c in n.get_children():
		var r := _find_party(c)
		if r != null:
			return r
	return null


func _find_map(scn: Node) -> Node:
	for c in scn.get_children():
		if c.has_method("get_room_rects"):
			return c
	return null


func _finish(scn: Node) -> void:
	scn.queue_free()
	# 런타임 에러로 섹션이 통째로 건너뛰어졌는데 초록으로 끝나는 일이 없게(방금 그런 일이 있었다).
	var need: Array = ["map_documents", "theme_axis", "wake_buffer", "route_bands", "playability", "readability"]
	if not _contract_only:
		need.append_array(["import_parity", "authored_impl", "stairs_input", "ground_plane",
			"third_layer", "entry_requirements", "patrol_graphs"])
	for sec in need:
		if not _sections.has(sec):
			print("  FAIL [게이트] 섹션 미완주: %s" % sec)
			_ok = false
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

# ============================================================================
# 맵 **문서** 정적 검사 — 부팅 없이 데이터만 본다.
#
# 위 검사들은 **부팅된 맵 하나**(활성 = `manifest.map_id`)를 본다. 그래서 맵을 추가하면
# 그 맵은 활성이 될 때까지 **아무 검사도 안 받는 데이터**가 된다 — 신규 맵이 활성이 되는
# 날에 처음 빨개지는 건 늦다. 그래서 축을 나눴다:
#   - **부팅 검사**(위) = navmesh 통행 · 오클루더 유도 · 스폰 · 전이 — 씬이 있어야 답이 나오는 것.
#   - **정적 검사**(여기) = 위상 · 인접 · 잠금 그래프 · enum · 문법 — **기하가 데이터에 있으니**
#     씬 없이도 답이 나오는 것. `data/slice01/maps/*.json` **전부**에 돈다.
# 겹치는 항목(인접·사이클)은 일부러 양쪽에 둔다 — 정적은 전 맵을, 부팅은 씬↔데이터 일치를 본다.
# ============================================================================

const MAPS_DIR := "res://data/slice01/maps"

## 문법이 요구하는 「시야를 끊는 것」의 최소 개수는 **맵이 선언한다**
## (`design_targets.grammar_min_obstacles`). 코드에 박으면 데모 맵(choke에 장애물 0개)이
## 즉시 빨개지고, 그러면 임계값을 낮춰 맞추게 된다 — 그건 게이트가 아니라 장식이다.
func _check_map_documents(sd) -> void:
	var reg = JSON.parse_string(FileAccess.get_file_as_string("res://data/slice01/id_registry.json"))
	var active := String(sd.get_manifest().get("map_id", ""))

	var files: Array = []
	var dir := DirAccess.open(MAPS_DIR)
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".json"):
				files.append(f)
	files.sort()
	_expect(files.size() >= 2, "[계약/문서] 맵 문서 %d개 발견 (활성=%s)" % [files.size(), active])

	for f in files:
		var doc = JSON.parse_string(FileAccess.get_file_as_string(MAPS_DIR + "/" + f))
		if typeof(doc) != TYPE_DICTIONARY:
			_expect(false, "[계약/문서] %s 파싱" % f)
			continue
		_check_one_document(sd, f, doc as Dictionary, reg as Dictionary, f == active + ".json")
	_sections["map_documents"] = true


func _check_one_document(sd, fname: String, doc: Dictionary, reg: Dictionary,
		is_active: bool) -> void:
	var mid := String(doc.get("map_id", ""))
	var tag := "%s%s" % [mid, "" if is_active else "/비활성"]
	# 파일명 = map_id. 안 그러면 매니페스트가 고를 수 없다.
	_expect(fname == mid + ".json", "[계약/문서] %s 파일명 = map_id" % tag)

	var rooms: Array = doc.get("rooms", [])
	var rects: Dictionary = {}       # ref -> {c: Vector2, s: Vector2, layer: int}
	var rows: Dictionary = {}
	var order: Array = []
	var bad: Array = []
	for row in rooms:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d := row as Dictionary
		var ref := String(d.get("room_ref", ""))
		rows[ref] = d
		order.append(ref)
		var geo: Dictionary = d.get("geometry", {})
		if geo.is_empty():
			bad.append("%s: geometry 없음" % ref)
			continue
		var c: Array = geo.get("center", [])
		var s: Array = geo.get("size", [])
		if c.size() != 2 or s.size() != 2:
			bad.append("%s: geometry 형식" % ref)
			continue
		rects[ref] = {"c": Vector2(float(c[0]), float(c[1])),
			"s": Vector2(float(s[0]), float(s[1])), "layer": int(d.get("layer", 0))}
	_expect(bad.is_empty() and rects.size() == rooms.size(),
		"[계약/문서] %s 방 %d개 전부 기하 보유 (%s)" % [tag, rooms.size(),
			"전부" if bad.is_empty() else ", ".join(bad)])

	# ── ID 등록 ────────────────────────────────────────────────────────────
	var allowed_rooms: Array = reg.get("room_refs", [])
	var allowed_pools: Array = reg.get("pool_slots", [])
	var unreg: Array = []
	for ref in order:
		if not allowed_rooms.has(ref):
			unreg.append(ref)
		var ps := String((rows[ref] as Dictionary).get("pool_slot", ""))
		if not ps.is_empty() and not allowed_pools.has(ps):
			unreg.append(ps)
	_expect(unreg.is_empty(), "[계약/문서] %s room_ref/pool_slot 전부 등록 (%s)" % [tag,
		"전부" if unreg.is_empty() else "미등록: " + ", ".join(unreg)])

	# ── enum ──────────────────────────────────────────────────────────────
	const CATEGORIES := ["mandatory_threat", "gated_elite", "optional_threat", "patrol_route",
		"ambush_candidate", "third_faction_candidate", "safe"]
	const GRAMMARS := ["open", "choke", "los_broken", "split", "flank", "backline_pocket"]
	const ROUTES := ["route_early", "route_mid", "route_deep"]
	const PROFILES := ["Normal", "Hard", "Extreme"]
	const RULES := ["requiresItem", "onBossKey", "onObjectiveComplete", "onFacilityTier", "onAccess"]
	var enum_bad: Array = []
	for ref in order:
		var d: Dictionary = rows[ref]
		if not d.has("layer"):
			enum_bad.append("%s: layer 없음" % ref)
		var cat := String((d.get("encounter_anchor", {}) as Dictionary).get("category", ""))
		if not CATEGORIES.has(cat):
			enum_bad.append("%s: category `%s`" % [ref, cat])
		for g in d.get("spatial_grammar", []):
			if not GRAMMARS.has(String(g)):
				enum_bad.append("%s: grammar `%s`" % [ref, g])
		# `spatialGrammar`는 **방 하나에 1~2개**다(LDG-001 §9) — 겹칠수록 읽기가 어려워진다.
		var gn: int = (d.get("spatial_grammar", []) as Array).size()
		if gn < 1 or gn > 2:
			enum_bad.append("%s: grammar %d개(1~2)" % [ref, gn])
		for rc in d.get("route_class", []):
			if not ROUTES.has(String(rc)):
				enum_bad.append("%s: route_class `%s`" % [ref, rc])
		if d.has("difficulty_profile") and not PROFILES.has(String(d["difficulty_profile"])):
			enum_bad.append("%s: difficulty_profile `%s`" % [ref, d["difficulty_profile"]])
		var req: Dictionary = d.get("entry_requirement", {})
		if not req.is_empty() and not RULES.has(String(req.get("rule", ""))):
			enum_bad.append("%s: entry rule `%s`" % [ref, req.get("rule", "")])
	_expect(enum_bad.is_empty(), "[계약/문서] %s 공간 필드 enum·개수 유효 (%s)" % [tag,
		"전부" if enum_bad.is_empty() else ", ".join(enum_bad)])

	# ── `gated_elite` ⇒ `entry_requirement` (LDG-001 §9 LD checklist) ──────
	# 「잠긴 방이라야 확정 정예가 정당하다」. 열쇠가 아니어도 된다 — `onObjectiveComplete`도 조건이다.
	var ungated: Array = []
	for ref in order:
		var d: Dictionary = rows[ref]
		if String((d.get("encounter_anchor", {}) as Dictionary).get("category", "")) != "gated_elite":
			continue
		if (d.get("entry_requirement", {}) as Dictionary).is_empty():
			ungated.append(ref)
	# 요구 여부는 **맵이 선언한다**. 데모 맵은 이 규약보다 먼저 만들어져 두 방이 위반 상태인데,
	# 거기에 잠금을 넣으면 QA-031 임계 경로가 바뀐다 — 그건 별도 판정이다. 그래서 선언으로 갈랐지만
	# **위반 목록은 선언과 무관하게 매 런 출력한다**(조용히 통과 = 「덮였다」로 읽힌다).
	if not ungated.is_empty():
		print("  [설계] %s `gated_elite` 진입 조건 없음: %s (LDG-001 §9 LD checklist)" % [
			tag, ", ".join(ungated)])
	if bool((doc.get("design_targets", {}) as Dictionary).get("require_entry_gate_on_elite", false)):
		_expect(ungated.is_empty(), "🔴 [계약/문서] %s `gated_elite`는 전부 진입 조건 동반 (%s)" % [tag,
			"전부" if ungated.is_empty() else "조건 없음: " + ", ".join(ungated)])

	# ── connects: 대상 존재 + 공유벽(겹침 ≥ width) ─────────────────────────
	var edges: Array = []
	var seen_edge: Dictionary = {}
	var conn_bad: Array = []
	for ref in order:
		for c in (rows[ref] as Dictionary).get("connects", []):
			var to := String((c as Dictionary).get("to", ""))
			var w := float((c as Dictionary).get("width", 0.0))
			if not rects.has(to):
				conn_bad.append("%s→%s: 없는 방" % [ref, to])
				continue
			var key: String = ref + "|" + to if ref < to else to + "|" + ref
			if seen_edge.has(key):
				continue
			seen_edge[key] = true
			edges.append([ref, to, w])
			var ov := _shared_wall_overlap(rects[ref], rects[to])
			if ov < 0.0:
				conn_bad.append("%s↔%s: 공유벽 없음" % [ref, to])
			elif ov < w - 0.01:
				conn_bad.append("%s↔%s: 겹침 %.1f < 폭 %.1f" % [ref, to, ov, w])
	_expect(conn_bad.is_empty(), "[계약/문서] %s 연결 %d개가 전부 공유벽 (%s)" % [tag, edges.size(),
		"일치" if conn_bad.is_empty() else ", ".join(conn_bad)])

	# ── 같은 층 XZ 중첩 금지 (다른 층은 겹쳐야 정상) ───────────────────────
	var ov_bad: Array = []
	var cross := 0
	for i in order.size():
		for j in range(i + 1, order.size()):
			var a: Dictionary = rects.get(order[i], {})
			var b: Dictionary = rects.get(order[j], {})
			if a.is_empty() or b.is_empty():
				continue
			if not _xz_overlaps(a, b):
				continue
			if int(a["layer"]) == int(b["layer"]):
				ov_bad.append("%s↔%s" % [order[i], order[j]])
			else:
				cross += 1
	_expect(ov_bad.is_empty(), "[계약/문서] %s **같은** 층 XZ 중첩 없음 (%s · 층 간 중첩 %d쌍)" % [tag,
		"전부" if ov_bad.is_empty() else "겹침: " + ", ".join(ov_bad), cross])

	# ── 층마다 바닥 높이가 선언돼 있고 서로 다른가 ─────────────────────────
	# 층은 XZ를 **겹치라고** 있는 것이므로 두 층이 같은 Y면 지오메트리가 서로 안에 박힌다.
	# 층 간격은 코드 상수가 아니라 맵 문서 `layer_floor_y`가 소유한다(맵마다 단차가 다르다).
	var layers_seen: Dictionary = {}
	for ref in order:
		layers_seen[int((rects[ref] as Dictionary)["layer"])] = true
	var fy: Array = doc.get("layer_floor_y", [])
	var fy_bad: Array = []
	var used_y: Dictionary = {}
	for l in layers_seen:
		if int(l) >= fy.size():
			fy_bad.append("layer %d: 바닥 높이 선언 없음" % int(l))
			continue
		var y := float(fy[int(l)])
		if used_y.has(y):
			fy_bad.append("layer %d: 바닥 y=%.1f 가 layer %d와 같다" % [int(l), y, int(used_y[y])])
		used_y[y] = int(l)
	_expect(fy_bad.is_empty(), "[계약/문서] %s 층 %d개가 각자 바닥 높이를 갖는다 (%s)" % [tag,
		layers_seen.size(), "전부" if fy_bad.is_empty() else ", ".join(fy_bad)])

	# ── 계단: 다른 층을 가리킨다 / 문: 잠긴 방을 가리킨다 ──────────────────
	var stairs: Array = []
	var tr_bad: Array = []
	for ref in order:
		for a in ((rows[ref] as Dictionary).get("anchors", {}) as Dictionary).get("transitions", []):
			var d := a as Dictionary
			var role := String(d.get("role", ""))
			if role == "stairs":
				var to := String(d.get("to", ""))
				if not rects.has(to):
					tr_bad.append("%s 계단→%s: 없는 방" % [ref, to])
				elif int((rects[to] as Dictionary)["layer"]) == int((rects[ref] as Dictionary)["layer"]):
					# 계단은 **층을 넘는 워프**다. 같은 층이면 그건 `connects`여야 한다.
					tr_bad.append("%s 계단→%s: 같은 층" % [ref, to])
				else:
					stairs.append([ref, to])
			elif role == "key_gate":
				var g := String(d.get("gates", ""))
				if not rows.has(g):
					tr_bad.append("%s 문→%s: 없는 방" % [ref, g])
				elif ((rows[g] as Dictionary).get("entry_requirement", {}) as Dictionary).is_empty():
					tr_bad.append("%s 문→%s: 그 방에 진입 조건 없음" % [ref, g])
	_expect(tr_bad.is_empty(), "🔴 [계약/문서] %s 계단은 층을 넘고 문은 잠긴 방을 막는다 (%s)" % [tag,
		"전부" if tr_bad.is_empty() else ", ".join(tr_bad)])

	# ── 잠긴 방은 **모든 도보 입구**가 막혀 있는가 ──────────────────────────
	# 한쪽만 막으면 조건이 무의미해진다 — 루프가 있는 위상에서는 뒤로 돌아 들어올 수 있다.
	# `connects` 이웃은 **하드**, 계단 입구는 **보고**한다(계단은 그 방을 통과해야 닿는 복귀로일 수 있다).
	var gates_on: Dictionary = {}          # gated_room -> {from_room: true}
	for ref in order:
		for a in ((rows[ref] as Dictionary).get("anchors", {}) as Dictionary).get("transitions", []):
			var g := String((a as Dictionary).get("gates", ""))
			if g.is_empty():
				continue
			if not gates_on.has(g):
				gates_on[g] = {}
			(gates_on[g] as Dictionary)[String(ref)] = true
	var open_side: Array = []
	var stair_side: Array = []
	for ref in order:
		if ((rows[ref] as Dictionary).get("entry_requirement", {}) as Dictionary).is_empty():
			continue
		var mine: Dictionary = gates_on.get(ref, {})
		for e in edges:
			var other := ""
			if String(e[0]) == ref:
				other = String(e[1])
			elif String(e[1]) == ref:
				other = String(e[0])
			if not other.is_empty() and not mine.has(other):
				open_side.append("%s←%s" % [ref, other])
		for s2 in stairs:
			if String(s2[1]) == ref and not mine.has(String(s2[0])):
				stair_side.append("%s←%s(계단)" % [ref, s2[0]])
	_expect(open_side.is_empty(), "🔴 [계약/문서] %s 잠긴 방은 **모든 도보 입구**가 막혀 있다 (%s)" % [tag,
		"전부" if open_side.is_empty() else "열린 쪽: " + ", ".join(open_side)])
	if not stair_side.is_empty():
		print("  [설계] %s 잠긴 방의 계단 입구 미차단: %s (그 방을 통과해야 닿는 복귀로면 정상)" % [
			tag, ", ".join(stair_side)])

	# ── 도달성: connects + 계단 ────────────────────────────────────────────
	var adj_conn: Dictionary = {}      # `connects`만 — 걸어서 갈 수 있는 그래프
	var adj: Dictionary = {}           # + 계단 — 실제로 갈 수 있는 그래프
	for ref in order:
		adj_conn[ref] = []
		adj[ref] = []
	for e in edges:
		(adj_conn[e[0]] as Array).append(e[1])
		(adj_conn[e[1]] as Array).append(e[0])
		(adj[e[0]] as Array).append(e[1])
		(adj[e[1]] as Array).append(e[0])
	for s in stairs:
		(adj[s[0]] as Array).append(s[1])
		(adj[s[1]] as Array).append(s[0])
	var entry := String(doc.get("entry_room", order[0] if order.size() > 0 else ""))
	var seen: Dictionary = {}
	var stack: Array = [entry] if rows.has(entry) else []
	while not stack.is_empty():
		var n: String = stack.pop_back()
		if seen.has(n):
			continue
		seen[n] = true
		for m in adj.get(n, []):
			if not seen.has(m):
				stack.append(m)
	_expect(seen.size() == order.size(),
		"[계약/문서] %s 전 방 도달 가능 — connects %d + 계단 %d (%d/%d)" % [tag, edges.size(),
			stairs.size(), seen.size(), order.size()])

	# ── 사이클 = E − V + C (연결 성분 수를 센다) ───────────────────────────
	# 예전엔 `E − V + 1`이었다. 층이 갈린 맵은 성분이 2개 이상이라 그 식은 사이클을 **과소 계산**한다
	# (백레이어 2방·1연결이 붙으면 사이클이 1 줄어든 것처럼 보인다).
	# 두 그래프의 성분 수는 다르다 — 계단이 층을 이으면 성분이 합쳐진다. 각자 자기 C를 써야 한다.
	var comps_conn := _components(order, adj_conn)
	var comps_all := _components(order, adj)
	var conn_only: int = edges.size() - order.size() + comps_conn
	var cycles: int = edges.size() + stairs.size() - order.size() + comps_all
	var t: Dictionary = doc.get("design_targets", {})
	var min_c := int(t.get("min_cycles", 0))
	_expect(conn_only >= min_c, "[계약/문서] %s 사이클 %d ≥ 목표 %d (E%d − V%d + C%d · 계단까지 세면 %d)" % [
		tag, conn_only, min_c, edges.size(), order.size(), comps_conn, cycles])

	# ── 상자 EV · bbox ────────────────────────────────────────────────────
	var ev := 0.0
	for ref in order:
		if not (rows[ref] as Dictionary).has("loot_anchor"):
			continue
		var s2: Vector2 = (rects[ref] as Dictionary)["s"]
		ev += minf(s2.x * s2.y / CHEST_AREA_PER, float(CHEST_MAX_PER_ROOM))
	var band: Array = t.get("chest_ev_band", [0, 999])
	_expect(ev >= float(band[0]) and ev <= float(band[1]),
		"[계약/문서] %s 상자 EV %.1f ∈ [%s, %s]" % [tag, ev, band[0], band[1]])

	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for ref in order:
		var r: Dictionary = rects[ref]
		var c: Vector2 = r["c"]
		var s3: Vector2 = r["s"]
		mn.x = minf(mn.x, c.x - s3.x * 0.5); mn.y = minf(mn.y, c.y - s3.y * 0.5)
		mx.x = maxf(mx.x, c.x + s3.x * 0.5); mx.y = maxf(mx.y, c.y + s3.y * 0.5)
	var span := mx - mn
	var bmax: Array = t.get("bbox_max_m", [9999, 9999])
	_expect(span.x <= float(bmax[0]) and span.y <= float(bmax[1]),
		"[계약/문서] %s 안개 바운딩 %.0f×%.0f ≤ %s×%s m" % [tag, span.x, span.y, bmax[0], bmax[1]])

	# ── 앵커가 방 안 · 문법이 장애물을 실제로 갖는가 ────────────────────────
	var out_bad: Array = []
	var total := 0
	var gmin: Dictionary = t.get("grammar_min_obstacles", {})
	var gram_bad: Array = []
	for ref in order:
		var anchors: Dictionary = (rows[ref] as Dictionary).get("anchors", {})
		var r2: Dictionary = rects[ref]
		var c2: Vector2 = r2["c"]
		var s4: Vector2 = r2["s"]
		for kind in anchors:
			for a in (anchors[kind] as Array):
				total += 1
				var p: Array = (a as Dictionary).get("pos", [])
				if p.size() != 2:
					out_bad.append("%s/%s: pos 형식" % [ref, kind])
				elif absf(float(p[0])) > s4.x * 0.5 + 0.01 or absf(float(p[1])) > s4.y * 0.5 + 0.01:
					out_bad.append("%s/%s" % [ref, kind])
		var n_obs: int = (anchors.get("obstacles", []) as Array).size()
		for g in (rows[ref] as Dictionary).get("spatial_grammar", []):
			var need := int(gmin.get(String(g), 0))
			if n_obs < need:
				gram_bad.append("%s(%s): 장애물 %d < %d" % [ref, g, n_obs, need])
	_expect(out_bad.is_empty(), "[계약/문서] %s 앵커 %d개가 전부 방 안 (%s)" % [tag, total,
		"전부" if out_bad.is_empty() else "벗어남: " + ", ".join(out_bad)])
	_expect(gram_bad.is_empty(), "🔴 [계약/문서] %s `spatial_grammar`가 장애물로 뒷받침됨 (%s)" % [tag,
		"전부" if gram_bad.is_empty() else ", ".join(gram_bad)])

	# ── 잠금 그래프 해결 가능성 ────────────────────────────────────────────
	var yields_at: Dictionary = {}
	for ref in order:
		var anchors2: Dictionary = (rows[ref] as Dictionary).get("anchors", {})
		for kind in ["interactions", "props", "hazards"]:
			for a in (anchors2.get(kind, []) as Array):
				var y := String((a as Dictionary).get("yields", ""))
				if not y.is_empty():
					yields_at[y] = ref
	var lock_bad: Array = []
	var locks := 0
	for ref in order:
		var req: Dictionary = (rows[ref] as Dictionary).get("entry_requirement", {})
		var need := String(req.get("ref", ""))
		if need.is_empty():
			continue                  # 아이템이 아닌 조건(onObjectiveComplete 등)은 열쇠 그래프 밖이다
		locks += 1
		var src := String(yields_at.get(need, ""))
		if src.is_empty():
			lock_bad.append("%s: `%s` 산출처 없음" % [ref, need])
		elif src == ref:
			lock_bad.append("%s: 열쇠 `%s`가 **잠긴 방 안**" % [ref, need])
	_expect(lock_bad.is_empty(), "🔴 [계약/문서] %s 잠금 %d개 해결 가능 (%s)" % [tag, locks,
		"전부" if lock_bad.is_empty() else ", ".join(lock_bad)])

	# ── 런이 이름으로 찾는 앵커 7종 ────────────────────────────────────────
	var need_kinds := [["interactions", "role", "key_chest"], ["interactions", "role", "ally_cache"],
		["transitions", "role", "key_gate"], ["hazards", "role", "plate"], ["hazards", "role", "lever"],
		["props", "ref", "ENT-BARREL-001"], ["props", "ref", "ENT-TORCH-001"]]
	var missing: Array = []
	for n in need_kinds:
		var found := false
		for ref in order:
			for a in (((rows[ref] as Dictionary).get("anchors", {}) as Dictionary).get(String(n[0]), []) as Array):
				if String((a as Dictionary).get(String(n[1]), "")) == String(n[2]):
					found = true
		if not found:
			missing.append("%s=%s" % [n[1], n[2]])
	_expect(missing.is_empty(), "[계약/문서] %s 런이 찾는 앵커 7종 (%s)" % [tag,
		"전부" if missing.is_empty() else "없음: " + ", ".join(missing)])

	# ── pool_slot이 스폰 표로 해석되는가 ───────────────────────────────────
	# 활성 맵은 **하드 게이트**(런이 즉시 깨진다). 비활성 맵은 아직 표가 없을 수 있어 리포트로 두되
	# **개수를 말한다** — 조용히 넘어가면 「덮였다」로 읽힌다.
	# 「표에 행이 있나」가 아니라 **실제 리졸버가 뽑히나**를 묻는다 — 그리고 **두 난이도 모두**에서.
	# 조회 키가 `(pool_slot, difficulty, world_layer)`이고 난이도는 **런이 정하거나 방이 덮으므로**
	# (`F-006` §3.1.2), 한쪽만 채우면 그 난이도의 런에서 방이 **조용히 빈다**(빈 문자열 = 스폰 없음).
	var unresolved: Array = []
	for ref in order:
		var row: Dictionary = rows[ref]
		var ps := String(row.get("pool_slot", ""))
		if ps.is_empty():
			continue
		var layer_name := String(row.get("world_layer", "Upper"))
		var over := String(row.get("difficulty_profile", ""))
		for run_diff in ["Normal", "Hard"]:
			var eff: String = over if not over.is_empty() else String(run_diff)
			if String(sd.get_encounter_for_pool(ps, eff, layer_name)).is_empty():
				unresolved.append("%s/%s(런 %s)" % [ps, eff, run_diff])
	if is_active:
		_expect(unresolved.is_empty(), "🔴 [계약/문서] %s 모든 pool이 **두 난이도 다** 해석됨 (%s)" % [tag,
			"전부" if unresolved.is_empty() else "없음: " + ", ".join(unresolved)])
	elif unresolved.is_empty():
		print("  [설계] %s pool 해석 — 두 난이도 전부 OK (활성화 가능)" % tag)
	else:
		print("  [설계] %s pool 미해석 %d — 활성화 전 spawn_table 필요 (%s)" % [tag,
			unresolved.size(), ", ".join(unresolved)])


## 두 방이 벽 하나를 공유하는가. 공유하면 그 벽에서의 **겹침 길이**(m), 아니면 −1.
func _shared_wall_overlap(a: Dictionary, b: Dictionary) -> float:
	var ac: Vector2 = a["c"]
	var as_: Vector2 = a["s"]
	var bc: Vector2 = b["c"]
	var bs: Vector2 = b["s"]
	var ax0 := ac.x - as_.x * 0.5
	var ax1 := ac.x + as_.x * 0.5
	var az0 := ac.y - as_.y * 0.5
	var az1 := ac.y + as_.y * 0.5
	var bx0 := bc.x - bs.x * 0.5
	var bx1 := bc.x + bs.x * 0.5
	var bz0 := bc.y - bs.y * 0.5
	var bz1 := bc.y + bs.y * 0.5
	if absf(ax1 - bx0) < 0.01 or absf(bx1 - ax0) < 0.01:
		return minf(az1, bz1) - maxf(az0, bz0)
	if absf(az1 - bz0) < 0.01 or absf(bz1 - az0) < 0.01:
		return minf(ax1, bx1) - maxf(ax0, bx0)
	return -1.0


func _xz_overlaps(a: Dictionary, b: Dictionary) -> bool:
	var ac: Vector2 = a["c"]
	var as_: Vector2 = a["s"]
	var bc: Vector2 = b["c"]
	var bs: Vector2 = b["s"]
	return absf(ac.x - bc.x) < (as_.x + bs.x) * 0.5 - 0.01 \
		and absf(ac.y - bc.y) < (as_.y + bs.y) * 0.5 - 0.01


## 연결 성분 수 — 사이클 식 `E − V + C`의 C.
func _components(nodes: Array, adj: Dictionary) -> int:
	var seen: Dictionary = {}
	var n := 0
	for r in nodes:
		if seen.has(r):
			continue
		n += 1
		var stack: Array = [r]
		while not stack.is_empty():
			var x: String = stack.pop_back()
			if seen.has(x):
				continue
			seen[x] = true
			for m in adj.get(x, []):
				if not seen.has(m):
					stack.append(m)
	return n


## **계단 입력 경로** — 앵커에서 실물 계단이 서고, 눌렀을 때 전이가 일어나는가.
## 전이 **역학**은 `_check_layer_transition`이 이미 본다. 여기는 **손가락**을 본다:
## 배치 · 역할 구분 · 결집 프롬프트 · 클릭 → 전이 · 남의 층 계단이 안 잡히는 것.
## 데모 맵엔 계단 앵커가 없으므로(그게 정상이다) **주입해서** 실제 배치 경로를 태운다 —
## 오브젝트만 따로 만들어 보면 `dungeon_run`의 배선은 검사되지 않는다.
func _check_stairs_input(scn: Node, map: Node) -> void:
	if not scn.has_method("_place_stairs"):
		_expect(false, "[계약/계단] dungeon_run._place_stairs 접근")
		return
	var party: Node = _find_party(root)
	if party == null:
		_expect(false, "[계약/계단] PartyController 접근")
		return
	# 활성 층을 0으로 되돌린다 — 앞선 전이 테스트가 1로 두고 갔다.
	map.set_active_layer(0)

	var home := "RM-ENTRY-01"
	var dest := "RM-ADV-05"
	var anchors: Dictionary = map.get("_anchors")
	var before: Array = (anchors.get(home, {}) as Dictionary).get("transitions", []).duplicate()
	var at: Vector3 = map.get_spawn_position(home)
	var injected: Array = before.duplicate()
	injected.append({"role": "stairs", "to": dest, "pos": at})
	# 문(key_gate)이 섞인 상태로 주입한다 — 역할을 안 보면 문까지 계단이 된다.
	injected.append({"role": "key_gate", "gates": dest, "pos": at})
	if not anchors.has(home):
		anchors[home] = {}
	(anchors[home] as Dictionary)["transitions"] = injected

	var n_before := _count_stairs(scn)
	scn._place_stairs()
	var built: Array = []
	for c in scn.get_children():
		if "on_layer" in c and "to_room" in c:
			built.append(c)
	_expect(built.size() == n_before + 1,
		"🔴 [계약/계단] 앵커 1+1개 중 **계단만** 실물이 된다 (+%d)" % (built.size() - n_before))
	if built.is_empty():
		(anchors[home] as Dictionary)["transitions"] = before
		return
	var st: Node = built[built.size() - 1]
	_expect(st.is_in_group("interactable") and String(st.get("to_room")) == dest,
		"[계약/계단] 상호작용 계약 + 목적지 (%s)" % st.get("to_room"))
	# 계단은 통행/시야를 막지 않는다 — world 비트를 켜면 오클루더 유도가 이걸 벽으로 센다.
	var body: Node = null
	for c in st.get_children():
		if c is StaticBody3D:
			body = c
	_expect(body != null and (int(body.get("collision_layer")) & 1) == 0,
		"🔴 [계약/계단] world 비트를 안 켠다 — 계단이 벽이 되면 안개에 구멍이 뚫린다")

	# ① 결집 안 된 상태의 프롬프트 — **누르기 전에** 거절 이유가 보여야 한다.
	var members: Array = party.get_members()
	var stray: Node3D = members[3] as Node3D
	var keep := stray.global_position
	for m in members:
		(m as Node3D).global_position = at
	(st as Node3D).global_position = at
	stray.global_position = at + Vector3(60, 0, 0)
	var p_bad := String(st.interact_prompt())
	_expect(p_bad.contains("결집") and p_bad.contains(String(stray.name)),
		"🔴 [계약/계단] 결집 안 되면 **프롬프트가 먼저 말한다** — 눌러도 아무 일 없으면 고장으로 읽힌다")

	# ② 결집하면 안내가 바뀐다.
	stray.global_position = at + Vector3(2, 0, 0)
	var p_ok := String(st.interact_prompt())
	_expect(p_ok.contains(dest) and not p_ok.contains("결집"),
		"[계약/계단] 결집되면 목적지를 안내한다")

	# ③ 클릭 → 실제로 전이가 일어난다(입력 경로가 LayerTransition에 닿는가).
	var tx: Node = null
	for c in scn.get_children():
		if c.has_method("transition") and c.has_method("can_transition"):
			tx = c
	if tx != null:
		tx.set("_fade", null)      # 한 프레임 안에 끝나게(페이드 await가 판정을 타이밍에 건다)
	st.interact()
	await root.get_tree().process_frame
	var dpos: Vector3 = map.get_spawn_position(dest)
	var moved := 0
	for m in members:
		if (m as Node3D).global_position.distance_to(dpos) < 6.0:
			moved += 1
	_expect(moved >= 3, "🔴 [계약/계단] 계단을 누르면 파티가 옮겨진다 (%d명)" % moved)

	# ④ 남의 층 계단은 **잡히지 않는다.** `visible = false`만으로는 레이캐스트가 계속 맞는다 —
	#    바닥 너머의 계단이 마우스에 걸리면 층 구분이 무너진다.
	st.set_active_layer(int(st.get("on_layer")) + 1)
	_expect(not bool(st.get("visible")) and int(body.get("collision_layer")) == 0,
		"🔴 [계약/계단] 남의 층 계단은 숨고 **콜리전도 꺼진다**")
	st.set_active_layer(int(st.get("on_layer")))
	_expect(bool(st.get("visible")) and int(body.get("collision_layer")) != 0,
		"[계약/계단] 자기 층으로 돌아오면 복원")

	# 정리 — 주입 제거 + 실물 제거 + 파티 복귀.
	(anchors[home] as Dictionary)["transitions"] = before
	st.queue_free()
	map.set_active_layer(0)
	stray.global_position = keep
	_sections["stairs_input"] = true


func _count_stairs(scn: Node) -> int:
	var n := 0
	for c in scn.get_children():
		if "on_layer" in c and "to_room" in c:
			n += 1
	return n


## **클릭-이동의 지면 평면이 활성 층을 따라가는가.** 예전엔 `y = 0` 고정이었다 —
## 지상만 있을 땐 맞지만 백레이어(바닥 −8 m)에서는 클릭한 곳이 **8 m 어긋난다**.
## 데모 맵은 층이 하나라 실맵으로는 이 차이를 못 만든다. 그래서 **단차가 있는 가짜 맵**을 세워
## 「어느 평면을 쓰는가」만 묻는다(상수로 돌아가면 즉시 빨개진다).
func _check_ground_plane() -> void:
	var stub := Node.new()
	var src := GDScript.new()
	src.source_code = "extends Node\nvar l := 0\nfunc get_active_layer() -> int:\n\treturn l\n" \
		+ "func layer_floor_y(layer: int) -> float:\n\treturn -8.0 if layer == 1 else 0.0\n"
	src.reload()
	stub.set_script(src)
	var ic = load("res://scripts/run/controllers/interaction_controller.gd").new()
	root.add_child(ic)
	ic.setup(null, null, null, stub)

	var from := Vector3(3, 20, 5)
	var dir := Vector3(0, -1, 0)
	var g0 = ic.ground_at(from, dir)
	_expect(g0 != null and absf((g0 as Vector3).y) < 0.001,
		"[계약/지면] layer 0 → 평면 y=0 (%.2f)" % (0.0 if g0 == null else (g0 as Vector3).y))
	stub.set("l", 1)
	var g1 = ic.ground_at(from, dir)
	_expect(g1 != null and absf((g1 as Vector3).y + 8.0) < 0.001,
		"🔴 [계약/지면] layer 1 → 평면 y=−8 — 클릭-이동이 **활성 층 바닥**을 쓴다 (%.2f)" % (
			0.0 if g1 == null else (g1 as Vector3).y))
	ic.queue_free()
	stub.queue_free()
	_sections["ground_plane"] = true


## **제3세력만 층을 넘는다**(`F-028` §3.2.2a) — 그리고 **다른 층은 서로 없는 것이다**(`F-006` §3.2.4).
## 데모 맵은 층이 하나라 실맵으로는 이 규칙을 못 만든다. 그래서 **가짜 층(2)** 위에 분대를 세워
## 「누가 넘을 수 있는가 · 언제 안 넘는가 · 넘을 때 무엇이 함께 바뀌는가」를 묻는다.
func _check_third_layer(scn: Node, map: Node) -> void:
	var combat: Node = null
	for c in scn.get_children():
		if c.has_method("prespawn_encounters") and c.has_method("_spawn_third_squad"):
			combat = c
	var party: Node = _find_party(root)
	if combat == null or party == null:
		_expect(false, "[계약/3세력] CombatController · PartyController 접근")
		return
	map.set_active_layer(0)

	# ① 층을 넘을 자격 — 진영 하나로 갈린다.
	var before: int = combat._enemies.size()
	combat._spawn_third_squad("RM-ENTRY-01")
	var crew: Array = []
	for i in range(before, combat._enemies.size()):
		crew.append(combat._enemies[i])
	var dungeon: Node = null
	for e in combat._enemies:
		if is_instance_valid(e) and String(e.faction) != "Third":
			dungeon = e
			break
	if crew.is_empty() or dungeon == null:
		_expect(false, "[계약/3세력] 제3세력 분대 · 몬스터 확보 (%d기)" % crew.size())
		return
	_expect(crew[0].can_cross_layers() and not dungeon.can_cross_layers(),
		"🔴 [계약/3세력] **제3세력만** 층을 넘을 수 있다 — 표준 몬스터는 레이어 고정 (%d기)" % crew.size())

	# ② 다른 층은 서로 없는 것이다 — 층을 안 보면 적이 바닥을 뚫고 파티를 인지한다.
	var members: Array = party.get_members()
	var m0: Node = members[0]
	var ai: Node = combat._enemy_ai
	var keep_layer := int(dungeon.nav_layer)
	_expect(ai._is_hostile(dungeon, m0), "[계약/3세력] 같은 층 파티는 적대다(과잉 차단 아님)")
	dungeon.nav_layer = 2
	_expect(not ai._is_hostile(dungeon, m0),
		"🔴 [계약/3세력] **남의 층 파티는 적대가 아니다** — 안 그러면 바닥을 뚫고 인지해 못 닿는 곳으로 몰려간다")
	dungeon.nav_layer = keep_layer

	# 계단 하나를 가짜 층 2 위에 세운다(플레이어가 쓰는 그 실물을 3세력도 쓴다).
	var home := "RM-ENTRY-01"
	var dest_room := "RM-ADV-05"
	var anchors: Dictionary = map.get("_anchors")
	var before_tr: Array = (anchors.get(home, {}) as Dictionary).get("transitions", []).duplicate()
	var at: Vector3 = map.get_spawn_position(home)
	var inj: Array = before_tr.duplicate()
	inj.append({"role": "stairs", "to": dest_room, "pos": at})
	(anchors[home] as Dictionary)["transitions"] = inj
	scn._place_stairs()
	var st: Node3D = null
	for c in scn.get_children():
		if "on_layer" in c and "to_room" in c:
			st = c as Node3D
	(anchors[home] as Dictionary)["transitions"] = before_tr
	if st == null:
		_expect(false, "[계약/3세력] 계단 확보")
		return
	st.set("on_layer", 2)
	st.set("to_layer", 0)
	for e in crew:
		e.nav_layer = 2
		e.engaged = false
		e.global_position = at
		e.layer_hop_cd = 0.0

	# ③ 파티가 이 층에 있으면 **안 넘는다** — 층 이동은 필수 추격이 아니다(§3.1.2).
	map.set_active_layer(2)
	combat._tick_third_layer_roam(0.016, members)
	_expect(int(crew[0].nav_layer) == 2,
		"🔴 [계약/3세력] 파티가 같은 층이면 **안 넘는다** — 못 따라오는 곳으로 도망치지 않는다")

	# ④ 사냥할 몬스터가 이 층에 남아 있으면 안 넘는다 — 여기 일이 안 끝났다.
	map.set_active_layer(0)
	dungeon.nav_layer = 2
	combat._tick_third_layer_roam(0.016, members)
	_expect(int(crew[0].nav_layer) == 2, "🔴 [계약/3세력] 자기 층에 사냥감이 남으면 안 넘는다")
	dungeon.nav_layer = keep_layer

	# ⑤ 계단에서 멀면 **걸어간다** — 계단을 「쓰는」 것이지 순간이동이 아니다.
	for e in crew:
		e.global_position = at + Vector3(30, 0, 0)
		e.velocity = Vector3.ZERO
	combat._tick_third_layer_roam(0.016, members)
	var toward := 0
	for e in crew:
		if (e.velocity as Vector3).length() > 0.01 and (e.velocity as Vector3).x < 0.0:
			toward += 1
	_expect(int(crew[0].nav_layer) == 2 and toward == crew.size(),
		"🔴 [계약/3세력] 계단이 멀면 **걸어간다**(안 넘는다) — %d/%d기가 계단 쪽으로" % [toward, crew.size()])

	# ⑥ 도착 — **분대 전체**가 함께 넘고, 위치만이 아니라 nav 바인딩·리시 기준까지 따라간다.
	# nav rid를 **무효로 비워 두고** 시작한다 — 안 그러면 분대가 스폰 때부터 layer 0에 묶여 있어서
	# 「새 층으로 바인딩됐는가」가 공허하게 통과한다(반증 확인에서 그렇게 드러났다).
	for e in crew:
		e.global_position = at
		e.nav_map_rid = RID()
	combat._tick_third_layer_roam(0.016, members)
	var want: RID = map.get_nav_map(0)
	_expect(want.is_valid(), "[계약/3세력] 목적지 층의 nav 맵이 실재한다")
	var moved := 0
	var bound := 0
	var homed := 0
	var dpos: Vector3 = map.get_spawn_position(dest_room)
	for e in crew:
		if int(e.nav_layer) == 0:
			moved += 1
		if (e.nav_map_rid as RID) == want:
			bound += 1
		if (e.home_pos as Vector3).distance_to(dpos) < 6.0:
			homed += 1
	_expect(moved == crew.size(), "🔴 [계약/3세력] **분대 전체**가 함께 넘는다 (%d/%d)" % [moved, crew.size()])
	_expect(bound == crew.size(),
		"🔴 [계약/3세력] 넘으면 **nav 맵도 새 층**으로 (%d/%d) — 위치만 옮기면 남의 층 navmesh를 걷는다" % [
			bound, crew.size()])
	_expect(homed == crew.size(),
		"[계약/3세력] 리시(leash) 기준도 새 층으로 (%d/%d) — 안 그러면 즉시 「끌려왔다」" % [homed, crew.size()])

	# ⑦ 쿨다운 — 사냥감이 없다고 매 프레임 오르내리지 않는다.
	st.set("on_layer", 0)
	st.set("to_room", home)
	for e in crew:
		e.global_position = map.get_spawn_position(home)
	combat._tick_third_layer_roam(0.016, members)
	_expect(int(crew[0].nav_layer) == 0, "[계약/3세력] 쿨다운 중엔 다시 안 넘는다 (%.0fs)" % crew[0].layer_hop_cd)

	# 정리 — 주입 계단 제거 + 분대 제거.
	st.queue_free()
	for e in crew:
		if is_instance_valid(e):
			combat._enemies.erase(e)
			e.queue_free()
	map.set_active_layer(0)
	_sections["third_layer"] = true


## **방이 런의 난이도를 덮는다**(`F-006` §3.1.2 · `DEC-20260824-001` §B) — 그리고 **열쇠가 아닌 진입
## 조건도 실물이 된다**(`LDG-001` §9.1). 둘 다 데이터에 저작해 두고 **읽는 사람이 없으면** 죽은 선언이다.
func _check_entry_requirements(scn: Node, _map: Node, sd) -> void:
	# ① 난이도 오버라이드 — 선언이 없으면 런 기본값, 있으면 그 방만 갈린다.
	var room := "RM-ADV-01"
	var rows: Array = sd._rooms.get("rooms", [])
	var row: Dictionary = {}
	for r in rows:
		if typeof(r) == TYPE_DICTIONARY and String((r as Dictionary).get("room_ref", "")) == room:
			row = r
	if row.is_empty():
		_expect(false, "[계약/진입] 대상 방 접근")
		return
	_expect(sd.get_room_difficulty(room, "Normal") == "Normal",
		"[계약/진입] 선언이 없으면 **런 기본값**이 내려온다")
	var pool := String(row.get("pool_slot", ""))
	var layer_name := String(row.get("world_layer", "Upper"))
	var enc_norm := String(sd.get_encounter_for_pool(pool, "Normal", layer_name))
	row["difficulty_profile"] = "Hard"
	_expect(sd.get_room_difficulty(room, "Normal") == "Hard",
		"🔴 [계약/진입] 방이 선언하면 **런이 Normal이어도 그 방은 Hard** — 난이도 축을 공간이 소유한다")
	var enc_hard := String(sd.get_encounter_for_pool(pool, sd.get_room_difficulty(room, "Normal"), layer_name))
	_expect(not enc_hard.is_empty() and enc_hard != enc_norm,
		"🔴 [계약/진입] 오버라이드가 **실제로 다른 ENC**를 뽑는다 (%s → %s)" % [enc_norm, enc_hard])
	row.erase("difficulty_profile")

	# ② 문이 규칙을 안다 — 열쇠 문은 열쇠를, 진행 조건 문은 목표를 본다.
	var doors: Array = []
	for c in scn.get_children():
		if "rule" in c and "completes_objective" in c:
			doors.append(c)
	_expect(doors.size() >= 1, "[계약/진입] 진입 조건 문 배치 (%d)" % doors.size())
	if doors.is_empty():
		return
	var keyed: Node = doors[0]
	_expect(String(keyed.get("rule")) == "requiresItem" and bool(keyed.get("completes_objective")),
		"[계약/진입] 데모 봉인문 = `requiresItem` + **이 문이 곧 목표** (%s)" % keyed.get("rule"))

	# ③ 진행 조건 문 — **누르는 조건이 아니라 진행 조건**이므로 스스로 열린다.
	var Door = load("res://scripts/world/objects/door.gd")
	var run: Node = null
	for c in scn.get_children():
		if c.has_method("complete_objective") and ("objective_complete" in c):
			run = c
	if run == null:
		_expect(false, "[계약/진입] RunController 접근")
		return
	var prog = Door.new()
	prog.rule = "onObjectiveComplete"
	scn.add_child(prog)
	prog.setup(null, run)
	_expect(String(prog.interact_prompt()).contains("목표 완료"),
		"🔴 [계약/진입] 목표 전엔 **막고, 이유를 말한다**")
	prog.interact()
	var body_alive := false
	for c in prog.get_children():
		if c is StaticBody3D:
			body_alive = true
	_expect(body_alive, "🔴 [계약/진입] 목표 전엔 눌러도 안 열린다 — 조건이 장식이 아니다")

	var was := bool(run.objective_complete)
	run.complete_objective()
	await root.get_tree().process_frame     # 자동 개방이 있었다면 여기서 돈다 — 안 기다리면 검사가 공허하다
	# **스스로 열리지 않는다** — 조건이 차도 문은 그대로 서 있고, 눌러야 열린다.
	# 자동 개방은 「세계가 조용히 바뀌는」 사건이라 플레이어가 못 본다(사용자 판정으로 되돌렸다).
	var still_there := false
	for c in prog.get_children():
		if c is StaticBody3D and is_instance_valid(c) and not c.is_queued_for_deletion():
			still_there = true
	_expect(still_there and String(prog.interact_prompt()).contains("열기"),
		"🔴 [계약/진입] 조건이 차도 **스스로 열리지 않는다** — 프롬프트만 바뀐다")
	prog.interact()
	var body_gone := true
	for c in prog.get_children():
		if c is StaticBody3D and is_instance_valid(c) and not c.is_queued_for_deletion():
			body_gone = false
	_expect(body_gone, "🔴 [계약/진입] 조건이 차면 **눌러서 열린다**")

	# ④ **비소모 문은 열쇠를 안 먹는다.** 데모 맵의 심부 관문(`RM-BOSS-01`/`RM-DEEP-01`)은
	#    탈출문과 **같은 열쇠**를 쓰되 `consume_on_use: false`다 — 먹어 버리면 심부에 들르는 순간
	#    탈출문이 안 열려 런이 막힌다. 열쇠 하나가 「어디에 쓸까」가 아니라 **「어디까지 둘러볼까」**가 된다.
	var inv: Node = null
	for c in scn.get_children():
		if c.has_method("backpack_has_key") and c.has_method("consume_key"):
			inv = c
	if inv == null:
		for c in scn.get_node_or_null("HUD").get_children() if scn.has_node("HUD") else []:
			if c.has_method("backpack_has_key") and c.has_method("consume_key"):
				inv = c
	if inv != null:
		var kid := "KEY-DEMO-01"
		inv._backpack.items.append({"id": kid, "w": 1, "h": 1, "col": 0, "row": 0})
		var keep = Door.new()
		keep.rule = "requiresItem"
		keep.key_id = kid
		keep.consume_on_use = false
		scn.add_child(keep)
		keep.setup(inv, run)
		keep.interact()
		_expect(inv.backpack_has_key(kid),
			"🔴 [계약/진입] **비소모 문은 열쇠를 안 먹는다** — 심부에 들러도 탈출문이 열린다")
		var eat = Door.new()
		eat.rule = "requiresItem"
		eat.key_id = kid
		eat.consume_on_use = true
		scn.add_child(eat)
		eat.setup(inv, run)
		eat.interact()
		_expect(not inv.backpack_has_key(kid), "[계약/진입] 소모 문은 먹는다(과잉 보존 아님)")
		keep.queue_free()
		eat.queue_free()
	else:
		_expect(false, "[계약/진입] InventoryUI 접근")

	# ⑤ `completes_objective`가 없는 문은 목표를 끝내지 않는다.
	run.objective_complete = false
	var plain = Door.new()
	plain.rule = "onAccess"           # 미구현 규칙 = 잠그지 않는다(조용히 막으면 진행 불가)
	scn.add_child(plain)
	plain.setup(null, run)
	plain.interact()
	_expect(not bool(run.objective_complete),
		"🔴 [계약/진입] 아무 문이나 목표를 끝내지 않는다 — `completes_objective`를 명시한 문만")
	run.objective_complete = was
	prog.queue_free()
	plain.queue_free()
	_sections["entry_requirements"] = true


## **지역 정체성은 표시명 축이 소유한다**(`DEC-20260824-001` §F · `F-026` §3) — ID는 안정 축이다.
## 그러려면 「이름은 나중에 공짜로 붙는다」가 **말이 아니라 성질**이어야 한다: 라벨을 바꿨을 때
## 계약이 한 글자도 안 움직여야 한다. 안 그러면 테마를 확정하는 날 맵이 조용히 달라진다.
## 임시 라벨은 **매 런 개수를 보고**한다 — 조용히 출시되지 않게.
func _check_theme_axis(map: Node, sd) -> void:
	var ref: String = map.get_entry_room()
	var before := {
		"spawn": map.get_spawn_position(ref),
		"size": map.get_room_size(ref),
		"rects": map.get_room_rects().duplicate(true),
		"conns": map.room_connections().duplicate(true),
		"layer": map.get_room_layer(ref),
		"profile": map.get_room_profile(ref),
	}
	var row: Dictionary = {}
	for r in sd._rooms.get("rooms", []):
		if typeof(r) == TYPE_DICTIONARY and String((r as Dictionary).get("room_ref", "")) == ref:
			row = r
	var keep: String = String(row.get("label", ""))
	var renamed := "지역명이 정해진 뒤의 이름"
	row["label"] = renamed
	var moved: Array = []
	# **바뀐 값과 비교한다.** 옛 값과만 비교하면 계약이 라벨을 아예 안 읽는 경우에도(= 검사가 무의미)
	# 통과해 버린다 — 반증 확인에서 실제로 그렇게 드러났다.
	if String(map.room_geometry(ref).get("label", "")) != renamed:
		moved.append("라벨이 계약에 안 실림(검사 무효)")
	if map.get_spawn_position(ref) != before["spawn"]:
		moved.append("spawn")
	if map.get_room_size(ref) != before["size"]:
		moved.append("size")
	if str(map.get_room_rects()) != str(before["rects"]):
		moved.append("rects")
	if str(map.room_connections()) != str(before["conns"]):
		moved.append("connects")
	if map.get_room_layer(ref) != before["layer"]:
		moved.append("layer")
	if map.get_room_profile(ref) != before["profile"]:
		moved.append("profile")
	row["label"] = keep
	_expect(moved.is_empty(), "🔴 [계약/테마] 라벨을 갈아도 계약이 안 움직인다 — 이름은 나중에 공짜다 (%s)" % (
		"전부 불변" if moved.is_empty() else "움직임: " + ", ".join(moved)))

	# zone_id 접두사 — `ZONE-`로 굳었다(두 맵 + 스펙 청사진 `zoneId`). 새 접두사를 만들지 않는다.
	var bad_zone: Array = []
	var temp := 0
	var total := 0
	var dir := DirAccess.open(MAPS_DIR)
	for f in (dir.get_files() if dir != null else []):
		if not f.ends_with(".json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string(MAPS_DIR + "/" + f))
		if typeof(doc) != TYPE_DICTIONARY:
			continue
		var z := String((doc as Dictionary).get("zone_id", ""))
		if not z.begins_with("ZONE-"):
			bad_zone.append("%s: `%s`" % [f, z])
		for r in (doc as Dictionary).get("rooms", []):
			if typeof(r) != TYPE_DICTIONARY:
				continue
			total += 1
			if String((r as Dictionary).get("label", "")).contains("(임시)"):
				temp += 1
	_expect(bad_zone.is_empty(), "[계약/테마] `zone_id` 접두사 = `ZONE-` (%s)" % (
		"전부" if bad_zone.is_empty() else ", ".join(bad_zone)))
	print("  [설계] 임시 라벨    %d / %d방 — 지역 테마 미확정(ID는 안정 축이라 라벨만 갈면 된다)" % [temp, total])
	_sections["theme_axis"] = true


## **문이 어디인가 + 진입 즉시 어그로 금지**(`F-006` §3.2.3).
## 계약이 `connects`+기하에서 문을 **유도**하는데, 그 유도가 틀리면 규칙 전체가 엉뚱한 좌표를 지킨다.
## 그래서 먼저 **유도한 문 = 실제로 벽에 뚫린 구멍**임을 확인하고, 그 위에서 규칙을 검사한다.
func _check_wake_buffer(scn: Node, map: Node, sd) -> void:
	# ① 유도 ↔ 실제 벽 구멍 대조. 그레이박스가 벽을 자를 때 쓴 `_room_openings`와 같아야 한다.
	var built: Dictionary = map.get("_room_openings")
	var mism: Array = []
	var doors_total := 0
	for ref in _rects:
		var room := String(ref)
		var derived: Array = map.get_room_openings(room)
		doors_total += derived.size()
		var n_built: int = (built.get(room, []) as Array).size()
		if derived.size() != n_built:
			mism.append("%s: 유도 %d ≠ 벽 %d" % [room, derived.size(), n_built])
			continue
		# 유도한 문이 실제 구멍 중심과 겹치는가 — side/pos_along을 월드로 되돌려 비교.
		var c: Vector2 = (_rects[room] as Dictionary)["c"]
		var s2: Vector2 = (_rects[room] as Dictionary)["s"]
		for o in (built.get(room, []) as Array):
			var d := o as Dictionary
			var side := String(d["side"])
			var along := float(d["pos_along"])
			var wp := Vector2.ZERO
			match side:
				"east":  wp = Vector2(c.x + s2.x * 0.5, c.y + along)
				"west":  wp = Vector2(c.x - s2.x * 0.5, c.y + along)
				"north": wp = Vector2(c.x + along, c.y + s2.y * 0.5)
				"south": wp = Vector2(c.x + along, c.y - s2.y * 0.5)
			var best := INF
			for dd in derived:
				var p: Vector3 = (dd as Dictionary)["pos"]
				best = minf(best, wp.distance_to(Vector2(p.x, p.z)))
			if best > 0.5:
				mism.append("%s/%s: %.1f m 어긋남" % [room, side, best])
	_expect(mism.is_empty(), "🔴 [계약/문] 유도한 문 %d개가 **실제 벽 구멍**과 일치 (%s)" % [doors_total,
		"전부" if mism.is_empty() else ", ".join(mism)])

	# ② 휴면 유닛이 §3.2.3을 지키는가.
	var combat: Node = null
	for c2 in scn.get_children():
		if c2.has_method("prespawn_encounters") and ("_enemies" in c2):
			combat = c2
	if combat == null:
		_expect(false, "[계약/어그로] CombatController 접근")
		return
	var EnemyAI = load("res://scripts/combat/enemy_ai.gd")
	# **임계값은 맵이 선언한다.** 구현과 같은 상수에서 읽으면 상수를 낮췄을 때 게이트도 같이
	# 내려가 「규칙을 몰래 끄는 것」을 못 잡는다(반증 확인에서 실제로 그랬다).
	var want_buf: float = float((_sd_targets(sd)).get("aggro_wake_buffer_m", 0.0))
	_expect(absf(float(combat.AGGRO_WAKE_BUFFER_M) - want_buf) < 0.001,
		"🔴 [계약/어그로] 코드 버퍼 %.1f m = 맵 선언 %.1f m (F-006 §3.2.3)" % [
			combat.AGGRO_WAKE_BUFFER_M, want_buf])
	var combat_r: float = EnemyAI.SIGHT_RANGE_M * (1.0 - EnemyAI.ALERT_ZONE_FRAC)
	var min_r: float = EnemyAI.PROXIMITY_M + want_buf
	var safe_r: float = combat_r + want_buf
	var too_near: Array = []
	var short: Array = []
	var narrow: Array = []
	var checked := 0
	var skipped := 0
	for e in combat._enemies:
		if not is_instance_valid(e) or e.engaged or e.training_dummy:
			continue
		# 대상은 **초기 배치**뿐이다. 증원·제3세력 창발은 「모르고 걸어 들어갔을 때」가 아니다.
		if not bool(e.wake_ruled):
			skipped += 1
			continue
		# 파티를 **이미 감지해** 조사·복귀 중인 유닛은 대상이 아니다 — 규칙은 「모르고 걸어
		# 들어갔을 때」를 지킨다. 감지 후의 이동까지 묶으면 그건 다른 규칙이다.
		if bool(e.has_investigate) or bool(e.returning):
			skipped += 1
			continue
		# **자기 방의 문**으로 잰다 — 서 있는 방이 아니라. 규칙은 「이 유닛이 자기 초소의 문에서
		# 떨어져 있는가」이고, 남의 방으로 새는 것은 위의 방 클램프가 따로 막는다.
		var room := _room_of(e.global_position)
		checked += 1
		var gap := INF
		for d in (e.wake_doors as Array):
			gap = minf(gap, Vector2(e.global_position.x - (d as Vector3).x,
				e.global_position.z - (d as Vector3).z).length())
		if gap == INF:
			continue
		if room.is_empty():
			room = "?"
		# 초소(`home_pos`)도 같은 규칙을 지켜야 한다 — 스폰 클램프의 증인이다.
		# 위치만 보면 틱 클램프가 한 프레임 만에 되밀어 주므로 스폰 쪽이 죽어도 안 드러난다.
		var hg := INF
		for d in (e.wake_doors as Array):
			hg = minf(hg, Vector2(e.home_pos.x - (d as Vector3).x,
				e.home_pos.z - (d as Vector3).z).length())
		if hg + 0.01 < min_r:
			too_near.append("%s 초소@%s %.1f<%.1f" % [e.name, room, hg, min_r])
		if gap + 0.01 < min_r:
			too_near.append("%s@%s %.1f<%.1f" % [e.name, room, gap, min_r])
		elif gap + 0.01 < safe_r:
			# 방이 좁아 못 채우는 경우와 **채울 수 있는데 안 지킨** 경우를 가른다.
			if _room_reach(map, room) + 0.01 >= safe_r:
				short.append("%s@%s %.1f<%.1f" % [e.name, room, gap, safe_r])
			else:
				narrow.append("%s(%.1f m)" % [room, gap])
	_expect(checked > 0, "[계약/어그로] 초기 배치 휴면 %d기 검사 (대상 외 %d기 = 증원·3세력)" % [checked, skipped])
	_expect(too_near.is_empty(),
		"🔴 [계약/어그로] 문에서 근접 바닥+버퍼(%.1f m) 확보 — **360°라 등져도 안 통한다** (%s)" % [
			min_r, "전부" if too_near.is_empty() else ", ".join(too_near)])
	_expect(short.is_empty(),
		"🔴 [계약/어그로] 방이 허락하면 **전투존+버퍼(%.1f m)** 확보 — 들어와서 1초는 걷는다 (%s)" % [
			safe_r, "전부" if short.is_empty() else ", ".join(short)])
	if not narrow.is_empty():
		print("  [설계] 좁은 방      %s — 기하상 %.1f m 불가. 「시야에 들어온 뒤 전투 판정」이 받는다(§3.2.3)" % [
			", ".join(narrow), safe_r])
	_sections["wake_buffer"] = true


## 이 방 안에서 **문에서 가장 멀리** 떨어질 수 있는 거리(격자 표본). 규칙이 기하상 가능한지 가른다.
## **클램프와 같은 공간**(벽 마진 안쪽)에서 재야 한다 — 방 전체로 재면 유닛이 갈 수 없는 구석까지
## 세어 「가능한데 안 지켰다」고 잘못 고발한다.
const WALL_MARGIN := 5.0   # combat_controller.SPAWN_WALL_MARGIN 미러

func _room_reach(map: Node, room: String) -> float:
	var doors: Array = map.get_room_openings(room)
	if doors.is_empty():
		return INF
	var c: Vector2 = (_rects[room] as Dictionary)["c"]
	var s0: Vector2 = (_rects[room] as Dictionary)["s"]
	var s2 := Vector2(maxf(s0.x - WALL_MARGIN * 2.0, 1.0), maxf(s0.y - WALL_MARGIN * 2.0, 1.0))
	var best := 0.0
	for i in 41:
		for j in 41:
			var p := Vector2(c.x - s2.x * 0.5 + s2.x * float(i) / 40.0,
				c.y - s2.y * 0.5 + s2.y * float(j) / 40.0)
			var m := INF
			for d in doors:
				var dp: Vector3 = (d as Dictionary)["pos"]
				m = minf(m, p.distance_to(Vector2(dp.x, dp.z)))
			best = maxf(best, m)
	return best


## 이 좌표가 속한 방(같은 층 기준). 없으면 "".
func _room_of(p: Vector3) -> String:
	for ref in _rects:
		var c: Vector2 = (_rects[ref] as Dictionary)["c"]
		var s2: Vector2 = (_rects[ref] as Dictionary)["s"]
		if absf(p.x - c.x) <= s2.x * 0.5 and absf(p.z - c.y) <= s2.y * 0.5:
			return String(ref)
	return ""


## 활성 맵의 `design_targets`.
func _sd_targets(sd) -> Dictionary:
	return sd.get_rooms_document().get("design_targets", {})


## **경로별 교전 밴드**(`F-006` §3.10.1 · `DBP-UPPER-001` §8) — 전역 예산 하나면 조기 탈출로와
## 심층로의 압력이 같아져 위험↔보상 축이 사라진다. 두 가지를 묻는다:
##   ① **선언이 만족 가능한가**(정적, 전 맵) — 하한을 채울 방이 실제로 있는가, 필수 방만으로 상한을 넘지 않는가.
##   ② **뽑기가 밴드를 지키는가**(주입) — 활성 맵엔 `route_class`가 없으므로(경로가 하나뿐이라 안 적었다)
##      데모 맵 데이터에 경로를 **주입해** 실제 picker를 여러 시드로 돌린다.
func _check_route_bands(scn: Node, sd) -> void:
	var combat: Node = null
	for c in scn.get_children():
		if c.has_method("pick_with_bands"):
			combat = c
	if combat == null:
		_expect(false, "[계약/경로] CombatController 접근")
		return

	# ① 전 맵 문서: 밴드 선언이 만족 가능한가.
	var dir := DirAccess.open(MAPS_DIR)
	var declared := 0
	for f in (dir.get_files() if dir != null else []):
		if not f.ends_with(".json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string(MAPS_DIR + "/" + f))
		if typeof(doc) != TYPE_DICTIONARY:
			continue
		var bands: Dictionary = ((doc as Dictionary).get("design_targets", {}) as Dictionary).get("route_bands", {})
		var mid := String((doc as Dictionary).get("map_id", "?"))
		if bands.is_empty():
			continue
		declared += 1
		var must: Dictionary = {}       # route -> 필수(mandatory) 방 수
		var avail: Dictionary = {}      # route -> 필수 + 뽑을 수 있는 optional 수
		var no_route: Array = []
		for r in bands:
			must[String(r)] = 0
			avail[String(r)] = 0
		for row in (doc as Dictionary).get("rooms", []):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var d := row as Dictionary
			if String(d.get("pool_slot", "")).is_empty():
				continue
			var cat := String((d.get("encounter_anchor", {}) as Dictionary).get("category", ""))
			if cat == "safe" or cat == "gated_elite":
				continue        # safe는 안 뽑고, gated는 경로 압력이 아니다
			var routes: Array = d.get("route_class", [])
			if routes.is_empty():
				no_route.append(String(d.get("room_ref", "")))
				continue
			for r in routes:
				var key := String(r)
				if not avail.has(key):
					continue
				avail[key] = int(avail[key]) + 1
				if cat == "mandatory_threat":
					must[key] = int(must[key]) + 1
		# 밴드를 선언한 맵은 **전투 방마다 경로를 적어야 한다** — 안 적힌 방은 영원히 안 뽑힌다.
		_expect(no_route.is_empty(), "🔴 [계약/경로] %s 전투 방이 전부 `route_class` 보유 (%s)" % [mid,
			"전부" if no_route.is_empty() else "없음: " + ", ".join(no_route)])
		var bad: Array = []
		for r in bands:
			var key := String(r)
			var lo := int((bands[r] as Array)[0])
			var hi := int((bands[r] as Array)[1])
			if int(must[key]) > hi:
				bad.append("%s: 필수 %d > 상한 %d" % [key, must[key], hi])
			if int(avail[key]) < lo:
				bad.append("%s: 가용 %d < 하한 %d" % [key, avail[key], lo])
		_expect(bad.is_empty(), "🔴 [계약/경로] %s 밴드가 **기하상 만족 가능** (%s)" % [mid,
			"전부" if bad.is_empty() else ", ".join(bad)])

	_expect(declared > 0, "[계약/경로] 밴드를 선언한 맵 %d개" % declared)

	# ② 실제 picker가 밴드를 지키는가 — 데모 맵 후보에 경로를 **주입해** 여러 시드로 돌린다.
	#    (활성 맵은 경로가 하나뿐이라 `route_class`가 없다. 그래서 데이터가 아니라 주입으로 검증한다.)
	const BANDS := {"route_early": [1, 2], "route_mid": [2, 3], "route_deep": [3, 4]}
	var mand: Array = [
		{"room": "M1", "weight": 1.0, "routes": ["route_early", "route_mid", "route_deep"]},
	]
	var opt: Array = []
	for i in 8:
		var routes: Array = ["route_deep"] if i % 3 == 0 else (
			["route_mid", "route_deep"] if i % 3 == 1 else ["route_early", "route_mid"])
		opt.append({"room": "O%d" % i, "weight": 1.0 + float(i % 3), "routes": routes})
	var violated: Array = []
	var seen_counts: Dictionary = {}
	for seed in range(1, 25):
		var picked: Array = combat.pick_with_bands(mand, opt, BANDS, seed)
		var cnt: Dictionary = {"route_early": 0, "route_mid": 0, "route_deep": 0}
		for row in (mand + picked):
			for r in (row["routes"] as Array):
				cnt[String(r)] = int(cnt[String(r)]) + 1
		for r in BANDS:
			var lo: int = BANDS[r][0]
			var hi: int = BANDS[r][1]
			if int(cnt[r]) < lo or int(cnt[r]) > hi:
				violated.append("seed %d %s=%d ∉ [%d,%d]" % [seed, r, cnt[r], lo, hi])
		seen_counts["%d/%d/%d" % [cnt["route_early"], cnt["route_mid"], cnt["route_deep"]]] = true
	_expect(violated.is_empty(), "🔴 [계약/경로] 24시드 전부 밴드 안 (%s)" % (
		"전부" if violated.is_empty() else ", ".join(violated.slice(0, 3))))
	# 전부 같은 조합만 나오면 밴드가 아니라 **한 해답만** 있는 것이다 — 검사가 공허해지는 자리.
	_expect(seen_counts.size() >= 2,
		"[계약/경로] 시드마다 다른 조합이 나온다 (%d종) — 밴드가 고정 해답이 아니다" % seen_counts.size())

	# ③ 상한을 0으로 만들면 **아무도 못 뽑는다** — 밴드가 실제로 제약으로 작동하는지의 반증.
	# **한 시드로는 부족하다** — 상한 검사를 꺼도 그 시드가 우연히 통과할 수 있다(실제로 그랬다).
	# 상한 0인 경로를 **건드리는 방이 단 한 번도** 안 뽑혀야 한다.
	const TIGHT := {"route_early": [0, 0], "route_mid": [0, 0], "route_deep": [1, 1]}
	var leaked: Array = []
	var tight_n := 0
	for seed2 in range(1, 25):
		var tight: Array = combat.pick_with_bands([], opt, TIGHT, seed2)
		tight_n = maxi(tight_n, tight.size())
		for row in tight:
			for r in (row["routes"] as Array):
				if String(r) != "route_deep":
					leaked.append("seed %d %s" % [seed2, row["room"]])
	_expect(leaked.is_empty() and tight_n == 1,
		"🔴 [계약/경로] 상한 0인 경로를 건드리는 방은 **24시드 내내 안 뽑힌다** (최대 %d방%s)" % [
			tight_n, "" if leaked.is_empty() else " · 샌 것: " + ", ".join(leaked.slice(0, 3))])
	_sections["route_bands"] = true


## **순찰 그래프**(`F-006` §3.2.4 `patrolGraphRef`).
## 그래프는 레벨 디자인 SSOT이므로 **데이터가 지오메트리와 어긋날 수 있다** — 붙어 있지 않은 두 방을
## 잇거나 층을 넘는 그래프. 정적으로 막고, 실제 순회는 주입으로 확인한다.
func _check_patrol_graphs(scn: Node, map: Node, sd) -> void:
	# ① 전 맵 문서: 정류장이 **연결돼 있고 같은 층**인가.
	var dir := DirAccess.open(MAPS_DIR)
	var graphs := 0
	for f in (dir.get_files() if dir != null else []):
		if not f.ends_with(".json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string(MAPS_DIR + "/" + f))
		if typeof(doc) != TYPE_DICTIONARY:
			continue
		var pg: Dictionary = (doc as Dictionary).get("patrol_graphs", {})
		if pg.is_empty():
			continue
		var mid := String((doc as Dictionary).get("map_id", "?"))
		var rooms: Dictionary = {}
		var edges: Dictionary = {}      # "a|b" (정렬) -> true
		for row in (doc as Dictionary).get("rooms", []):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var d := row as Dictionary
			var ref := String(d.get("room_ref", ""))
			rooms[ref] = int(d.get("layer", 0))
			for c in d.get("connects", []):
				var to := String((c as Dictionary).get("to", ""))
				edges[(ref + "|" + to) if ref < to else (to + "|" + ref)] = true
		var bad: Array = []
		var refd: Dictionary = {}
		for row in (doc as Dictionary).get("rooms", []):
			if typeof(row) == TYPE_DICTIONARY:
				var gr := String((row as Dictionary).get("patrol_graph_ref", ""))
				if not gr.is_empty():
					refd[gr] = true
					if not pg.has(gr):
						bad.append("%s: 없는 그래프 `%s`" % [row["room_ref"], gr])
		for g in pg:
			graphs += 1
			var stops: Array = (pg[g] as Dictionary).get("stops", [])
			if stops.size() < 2:
				bad.append("%s: 정류장 %d개(2 이상)" % [g, stops.size()])
				continue
			if not refd.has(String(g)):
				bad.append("%s: 아무 방도 참조 안 함(사문)" % g)
			var layer := -999
			for i in stops.size():
				var a := String((stops[i] as Dictionary).get("room", ""))
				if not rooms.has(a):
					bad.append("%s: 없는 방 `%s`" % [g, a])
					continue
				if layer == -999:
					layer = int(rooms[a])
				elif int(rooms[a]) != layer:
					# 표준 몬스터는 레이어 고정 — 층을 넘는 건 제3세력뿐이다(F-028 §3.2.2a).
					bad.append("%s: `%s`가 다른 층(%d≠%d)" % [g, a, rooms[a], layer])
				var b := String((stops[(i + 1) % stops.size()] as Dictionary).get("room", ""))
				if a == b or not rooms.has(b):
					continue
				var key: String = (a + "|" + b) if a < b else (b + "|" + a)
				if not edges.has(key):
					bad.append("%s: `%s`↔`%s` 연결 없음" % [g, a, b])
		_expect(bad.is_empty(), "🔴 [계약/순찰] %s 그래프가 **연결·동일 층** (%s)" % [mid,
			"전부" if bad.is_empty() else ", ".join(bad)])
	_expect(graphs > 0, "[계약/순찰] 순찰 그래프 %d개 선언" % graphs)

	# ② 실제 순회 — 활성 맵엔 그래프가 없으므로(경로가 하나뿐) **주입해서** 확인한다.
	var combat: Node = null
	for c in scn.get_children():
		if c.has_method("_apply_patrol_graph"):
			combat = c
	if combat == null:
		_expect(false, "[계약/순찰] CombatController 접근")
		return
	var rows: Array = sd._rooms.get("rooms", [])
	var host := "RM-ADV-05"
	var away := "RM-ADV-04"
	var row: Dictionary = {}
	for r in rows:
		if typeof(r) == TYPE_DICTIONARY and String((r as Dictionary).get("room_ref", "")) == host:
			row = r
	var doc2: Dictionary = sd._rooms
	doc2["patrol_graphs"] = {"PG-TEST": {"stops": [{"room": host}, {"room": away}]}}
	row["patrol_graph_ref"] = "PG-TEST"
	var stops: Array = map.get_patrol_stops("PG-TEST")
	_expect(stops.size() == 2, "[계약/순찰] 정류장 좌표 해석 (%d)" % stops.size())

	var before: int = combat._enemies.size()
	combat._active_patrols = 0
	combat._spawn_squad("ENC-PAT-001", host)
	var crew: Array = []
	for i in range(before, combat._enemies.size()):
		crew.append(combat._enemies[i])
	_expect(not crew.is_empty(), "[계약/순찰] 순찰 분대 스폰 (%d기)" % crew.size())
	if crew.is_empty():
		doc2.erase("patrol_graphs")
		row.erase("patrol_graph_ref")
		return
	var e = crew[0]
	_expect((e.patrol_stops as Array).size() == 2 and String(e.placement_mode) == "Patrol",
		"🔴 [계약/순찰] 분대가 **저작 정류장**을 받는다 (%d개 · %s)" % [
			(e.patrol_stops as Array).size(), e.placement_mode])
	# **방을 넘나드는 게 일이므로 문 버퍼에서 빠진다** — 대신 예고(분대 광원)가 실재해야 한다.
	_expect(not bool(e.wake_ruled) and e.has_squad_light(),
		"🔴 [계약/순찰] 문 버퍼 면제 + **분대 광원으로 예고**(§3.2.4 텔레그래프) — 면제만 하고 예고가 없으면 규칙을 근거 없이 끄는 것")
	# **AI가 실제로 그 정류장을 쓰는가.** 유닛이 데이터를 받았는지만 보면, 순회 로직이 그래프를
	# 무시하고 원형 루프를 돌아도 초록이다(반증 확인에서 실제로 그랬다).
	var ai: Node = combat._enemy_ai
	var wrong: Array = []
	for i in (e.patrol_stops as Array).size():
		var want: Vector3 = (e.patrol_stops as Array)[i]
		var got: Vector3 = ai._patrol_point(e, i)
		if got.distance_to(want) > 0.5:
			wrong.append("idx %d: %.1f m 어긋남" % [i, got.distance_to(want)])
	_expect(wrong.is_empty(), "🔴 [계약/순찰] 순회 로직이 **그 정류장으로 간다** (%s)" % (
		"전부" if wrong.is_empty() else ", ".join(wrong)))

	# 정류장이 **자기 방 밖**을 포함한다 = 실제로 방을 넘는다.
	var rooms_hit: Dictionary = {}
	for sp in (e.patrol_stops as Array):
		rooms_hit[_room_of(sp)] = true
	_expect(rooms_hit.size() >= 2, "🔴 [계약/순찰] 정류장이 **방을 넘는다** (%d방)" % rooms_hit.size())

	# ③ 상한 — 두 번째 분대는 그래프를 못 받는다(원형 루프로 남는다).
	combat._active_patrols = int(_sd_targets(sd).get("max_active_patrols", combat.MAX_ACTIVE_PATROLS))
	var before2: int = combat._enemies.size()
	combat._spawn_squad("ENC-PAT-001", host)
	var over_ok := true
	for i in range(before2, combat._enemies.size()):
		if not (combat._enemies[i].patrol_stops as Array).is_empty():
			over_ok = false
	_expect(over_ok, "🔴 [계약/순찰] 활성 순찰 **상한**을 넘으면 그래프를 안 받는다 (§3.2.4 ≤2)")

	# 정리
	for i in range(before, combat._enemies.size()):
		if is_instance_valid(combat._enemies[i]):
			combat._enemies[i].queue_free()
	combat._enemies = combat._enemies.slice(0, before)
	combat._active_patrols = 0
	doc2.erase("patrol_graphs")
	row.erase("patrol_graph_ref")
	_sections["patrol_graphs"] = true


## `MapSource.world_bit`/`layer_of_bit` 미러 — 게이트가 구현을 preload 하지 않으므로 규칙만 복제한다.
func _world_mask_all() -> int:
	var m := 1
	for l in range(1, 4):
		m |= 1 << (3 + l)
	return m


func _layer_of_bit(mask: int) -> int:
	if (mask & 1) != 0:
		return 0
	for l in range(1, 4):
		if (mask & (1 << (3 + l))) != 0:
			return l
	return -1


## **플레이로 드러난 세 결함을 이름 그대로 잡는다**(DRIFT-191). 셋 다 헤드리스 계약 검사를
## 통과하면서 실제 플레이에선 맵을 못 쓰게 만들었다 — 「부팅된다」와 「플레이된다」는 다르다.
func _check_playability(scn: Node, map: Node, sd) -> void:
	# ① **문이 개구부를 실제로 막는가.** 손으로 놓으면 1~2 m 어긋나고 폭도 안 맞아
	#    **옆으로 돌아 들어갈 수 있다**(실제로 그랬다). 위치·회전·폭은 개구부에서 유도해야 한다.
	var bad_doors: Array = []
	var doors := 0
	for c in scn.get_children():
		if not (("rule" in c) and ("completes_objective" in c)):
			continue
		doors += 1
		var p: Vector3 = (c as Node3D).global_position
		var near: Dictionary = {}
		var nd := INF
		for ref in map.data_room_refs():
			for o in map.get_room_openings(String(ref)):
				var op: Vector3 = (o as Dictionary)["pos"]
				var dist: float = Vector2(p.x - op.x, p.z - op.z).length()
				if dist < nd:
					nd = dist
					near = o
		if nd > 0.6:
			bad_doors.append("%s: 개구부에서 %.1f m" % [c.name, nd])
			continue
		# 폭: 문이 개구부보다 넓어야 옆이 안 뚫린다.
		if float(c.get("span")) < float(near.get("width", 0.0)) + 0.01:
			bad_doors.append("%s: 폭 %.1f < 개구부 %.1f" % [c.name, c.get("span"), near.get("width", 0.0)])
			continue
		# 방향: 개구부가 뻗은 축과 문이 선 축이 같아야 한다.
		var want_rot: float = PI * 0.5 if String(near.get("axis", "x")) == "z" else 0.0
		if absf(fmod(absf(float((c as Node3D).rotation.y) - want_rot), PI)) > 0.05:
			bad_doors.append("%s: 축 불일치(%s)" % [c.name, near.get("axis", "?")])
	_expect(bad_doors.is_empty(), "🔴 [계약/플레이] 문 %d개가 **개구부를 실제로 막는다** (%s)" % [doors,
		"전부" if bad_doors.is_empty() else ", ".join(bad_doors)])

	# ② **층을 옮기면 남의 층 물건이 사라지는가.** 방 지오메트리만 숨기면 런이 놓은 것들
	#    (횃불=광원·배럴·상자·문·함정)이 남아 **빛과 그림자가 층을 넘는다**(실제로 그랬다).
	var layers: Array = map.layers_present()
	if layers.size() >= 2:
		var other: int = int(layers[1])
		map.set_visible_layer(other)
		var leaked: Array = []
		for e in (map.get("_layer_objects") as Array):
			var n: Node = (e as Dictionary)["node"]
			if not is_instance_valid(n) or not (n is Node3D):
				continue
			if int((e as Dictionary)["layer"]) != other and bool((n as Node3D).visible):
				leaked.append(String(n.name))
		map.set_visible_layer(0)
		_expect(leaked.is_empty(), "🔴 [계약/플레이] 층을 옮기면 **남의 층 물건이 숨는다** — 광원이 층을 넘으면 안 된다 (%s)" % (
			"전부" if leaked.is_empty() else "남음: " + ", ".join(leaked.slice(0, 4))))
		# 등록 자체가 비어 있으면 위 검사가 공허하다.
		_expect((map.get("_layer_objects") as Array).size() > 0,
			"[계약/플레이] 런이 놓은 오브젝트가 층에 등록됨 (%d개)" % (map.get("_layer_objects") as Array).size())

	# ③ **탈출이 가능한가.** 목표가 완료될 길이 없으면 `onObjectiveComplete` 지점이 영원히 안 열리고,
	#    `always` 지점조차 전역 AND에 막힐 수 있다(실제로 UPPER가 그 상태였다).
	var doc: Dictionary = sd.get_rooms_document()
	var rule := String(doc.get("objective_rule", ""))
	var reachable := false
	var why := ""
	match rule:
		"onDoorOpen":
			for c in scn.get_children():
				if ("completes_objective" in c) and bool(c.get("completes_objective")):
					reachable = true
			why = "목표 문 없음"
		"onObjectiveRoomCleared":
			var target := String(doc.get("objective_room", ""))
			reachable = not target.is_empty() and _rects.has(target)
			why = "objective_room `%s` 없음" % target
		_:
			why = "objective_rule 미선언"
	_expect(reachable, "🔴 [계약/플레이] 목표를 **완료할 길이 있다** (%s)" % (rule if reachable else why))
	# **탈출로가 실제로 뚫려 있는가.** 지점이 하나도 없으면 당연히 막히고, 전부 목표 뒤라면
	# **목표가 완료 가능해야** 뚫린다(위 검사). 「항상 열린 지점이 하나는 있어야 한다」로 쓰면
	# 데모처럼 **단일 지점을 목표 뒤에 두는 정당한 설계**를 잘못 고발한다.
	var all_pts: int = (map.get_extraction_points(true) as Array).size()
	var always_n: int = (map.get_extraction_points(false) as Array).size()
	# **탈출은 눌러서 시작한다.** 지점마다 탈출대가 서 있고, 조건이 안 찼으면 눌러도 안 돈다 —
	# 근접으로 저절로 시작하면 「커밋할 것인가」라는 선택이 사라진다(`F-007` `ExtractionActivate`).
	var beacons: Array = []
	for c in scn.get_children():
		if ("activation" in c) and c.has_method("is_active") and c.has_method("interact_prompt"):
			beacons.append(c)
	var declared_pts: int = (map.get_extraction_points(true) as Array).size()
	_expect(beacons.size() == declared_pts,
		"🔴 [계약/플레이] 탈출 지점마다 **누를 것이 있다** (%d/%d)" % [beacons.size(), declared_pts])
	var end_ctl: Node = null
	var run_ref: Node = null
	for c in scn.get_children():
		if c.has_method("request_extraction") and c.has_method("is_extracting"):
			end_ctl = c
		if c.has_method("complete_objective") and ("objective_complete" in c):
			run_ref = c
	if end_ctl != null and run_ref != null and not beacons.is_empty():
		_expect(not end_ctl.is_extracting(), "[계약/플레이] 근접만으로는 탈출이 시작되지 않는다")
		var open_b: Node = null
		for b in beacons:
			if b.is_active():
				open_b = b
		# 잠긴 탈출대를 **만들어서** 시험한다 — 맵에 마침 하나 있기를 기대하면, 없는 맵에서
		# 검사가 통째로 건너뛰어진다(반증 확인에서 그렇게 드러났다).
		var Beacon = load("res://scripts/world/objects/extraction_beacon.gd")
		var lock_b = Beacon.new()
		lock_b.activation = "onObjectiveComplete"
		scn.add_child(lock_b)
		lock_b.setup(run_ref, end_ctl)
		var was_obj := bool(run_ref.objective_complete)
		run_ref.objective_complete = false
		_expect(not lock_b.is_active() and String(lock_b.interact_prompt()).contains("목표 완료 필요"),
			"🔴 [계약/플레이] 조건 미달 탈출대는 **이유를 말한다**")
		lock_b.interact()
		_expect(not end_ctl.is_extracting(), "🔴 [계약/플레이] 조건 미달 탈출대는 **눌러도 안 돈다**")
		run_ref.objective_complete = was_obj
		lock_b.queue_free()
		if open_b != null:
			open_b.interact()
			_expect(end_ctl.is_extracting(), "🔴 [계약/플레이] 탈출대를 누르면 **홀드가 시작된다**")
			open_b.interact()
			_expect(not end_ctl.is_extracting(), "[계약/플레이] 다시 누르면 중단 — 커밋이 되돌릴 수 있다")

	_expect(all_pts > 0 and (always_n > 0 or reachable),
		"🔴 [계약/플레이] 탈출로가 뚫려 있다 — 지점 %d개(목표 전 열림 %d개)%s" % [all_pts, always_n,
			"" if (always_n > 0 or reachable) else " · 전부 목표 뒤인데 목표를 완료할 길이 없다"])
	_sections["playability"] = true


## **플레이 2차 피드백**(DRIFT-193) — 「보이는가 · 알 수 있는가 · 갇히지 않는가」.
## 계약도 플레이도 통과한 맵이 **읽히지 않아서** 못 쓰는 경우가 있다.
func _check_readability(scn: Node, map: Node, sd) -> void:
	# ① **유닛이 층을 따른다.** 남의 층 적은 바닥 아래에 떠 있어 「안 보이는 적」이 된다 —
	#    층이 XZ를 공유하므로 미니맵·타겟팅상 같은 자리에 겹친다.
	var layers: Array = map.layers_present()
	if layers.size() >= 2:
		var other: int = int(layers[1])
		var combat: Node = null
		for c in scn.get_children():
			if c.has_method("prespawn_encounters") and ("_enemies" in c):
				combat = c
		if combat != null and not (combat._enemies as Array).is_empty():
			var probe = (combat._enemies as Array)[0]
			var keep_layer := int(probe.nav_layer)
			probe.nav_layer = other
			map.set_visible_layer(0)
			var hidden_ok: bool = not bool(probe.visible)
			map.set_visible_layer(other)
			var shown_ok: bool = bool(probe.visible)
			probe.nav_layer = keep_layer
			map.set_visible_layer(0)
			_expect(hidden_ok and shown_ok,
				"🔴 [계약/가독] **유닛도 층을 따른다** — 남의 층 적이 바닥 아래 「안 보이는 적」이 되면 안 된다")

	# ② **MIA 경로 질의가 자기 층 맵을 쓴다.** 전역 맵으로 물으면 layer 1에서 바로 옆 아군도
	#    「도달 불가」가 되어 5초 뒤 MIA가 뜨고 조작이 잠긴다(계단으로 내려간 직후가 그랬다).
	var party: Node = _find_party(root)
	var mia: Node = null
	if party != null:
		for c in party.get_children():
			if c.has_method("tick") and ("_mia_timer" in c):
				mia = c
	if mia != null and party != null:
		var members: Array = party.get_members()
		var a: Node3D = members[0] as Node3D
		var b: Node3D = members[1] as Node3D
		b.global_position = a.global_position + Vector3(2, 0, 0)
		var d_near: float = mia._reachable_dist(b, a.global_position)
		# 층을 옮긴 척 — 위치는 그대로 두고 nav 바인딩만 다른 층으로. 자기 층 맵을 쓰면
		# 이 조작으로 결과가 **달라져야** 한다(전역 맵을 쓰면 아무 일도 안 일어난다).
		var keep_rid: RID = b.nav_map_rid
		b.nav_map_rid = map.get_nav_map(1) if map.get_nav_map(1) != map.get_nav_map(0) else keep_rid
		var uses_own: bool = (b.nav_map_rid != keep_rid)
		var d_other: float = mia._reachable_dist(b, a.global_position)
		b.nav_map_rid = keep_rid
		_expect(d_near < 10.0, "[계약/가독] 바로 옆 아군은 **도달 가능**하다 (%.1f m)" % d_near)
		if uses_own:
			_expect(d_other != d_near,
				"🔴 [계약/가독] MIA 경로 질의가 **자기 층 맵**을 쓴다 — 전역 맵이면 층을 옮겨도 값이 같다")

	# ③ **잠긴 문이 무엇이·어디서를 말한다.** 「열쇠 필요」만으로는 맵을 헤매게 된다.
	var vague: Array = []
	for c in scn.get_children():
		if not (("rule" in c) and ("key_id" in c)):
			continue
		if String(c.get("rule")) != "requiresItem" or String(c.get("key_id")).is_empty():
			continue
		var txt := String(c.interact_prompt())
		if not txt.contains("—"):
			vague.append(txt.replace("
", " / "))
	_expect(vague.is_empty(), "🔴 [계약/가독] 잠긴 문이 **열쇠와 출처**를 말한다 (%s)" % (
		"전부" if vague.is_empty() else ", ".join(vague)))

	# ④ **미니맵이 뜻 있는 것만 그린다.** 그룹 전체를 같은 점으로 찍으면 무엇을 뜻하는지
	#    알 수 없는 점 무리가 된다. 열쇠 상자는 **반드시** 표시된다(그게 ③의 짝이다).
	var key_marked := 0
	var generic := 0
	for n in root.get_tree().get_nodes_in_group("interactable"):
		if not (is_instance_valid(n) and n is Node3D):
			continue
		if ("yields" in n) and not String(n.get("yields")).is_empty():
			key_marked += 1
		elif not (("rule" in n) or ("on_layer" in n) or ("activation" in n)):
			generic += 1
	_expect(key_marked > 0, "🔴 [계약/가독] 열쇠 상자가 미니맵에 표시될 근거를 갖는다 (%d)" % key_marked)
	print("  [설계] 미니맵      열쇠 %d · 일반 interactable %d개는 안 그린다" % [key_marked, generic])
	_sections["readability"] = true

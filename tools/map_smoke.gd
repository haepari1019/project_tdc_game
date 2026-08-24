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
	_check_anchors(sd, map)
	_check_layers(map)
	_check_space_fields(sd, scn)
	_check_extraction(sd, map)
	_report_design(sd, map, edges)
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
		_rects[_ref_at(map, c)] = {"c": Vector2(c.x, c.z), "s": Vector2(s.x, s.z), "y": c.y}


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
	var eye: float = _floor_y_at(Vector2(xf.origin.x, xf.origin.z)) + LOS_EYE_H
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
func _floor_y_at(xz: Vector2) -> float:
	for ref in _rects:
		var c: Vector2 = _rects[ref]["c"]
		var sz: Vector2 = _rects[ref]["s"]
		if absf(xz.x - c.x) <= sz.x * 0.5 + 0.5 and absf(xz.y - c.y) <= sz.y * 0.5 + 0.5:
			return float(_rects[ref].get("y", 0.0))
	return 0.0


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
			var ax: float = (a["s"] as Vector2).x * 0.5 + (b["s"] as Vector2).x * 0.5
			var az: float = (a["s"] as Vector2).y * 0.5 + (b["s"] as Vector2).y * 0.5
			var d: Vector2 = (a["c"] as Vector2) - (b["c"] as Vector2)
			if absf(d.x) < ax - 0.1 and absf(d.y) < az - 0.1:
				overlaps.append("%s↔%s" % [refs[i], refs[j]])
	_expect(overlaps.is_empty(), "[계약] 같은 레이어 방 XZ 중첩 없음 (%s)" % (
		"전부" if overlaps.is_empty() else "겹침: " + ", ".join(overlaps)))

	var bare: Array = []
	for ref in _rects:
		var c: Vector2 = _rects[ref]["c"]
		var sz: Vector2 = _rects[ref]["s"]
		var n := 0
		for occ in map.get_occluder_footprints():
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
func _check_space_fields(sd, scn: Node) -> void:
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

	src.free()

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

func _find_map(scn: Node) -> Node:
	for c in scn.get_children():
		if c.has_method("get_room_rects"):
			return c
	return null


func _finish(scn: Node) -> void:
	scn.queue_free()
	# 런타임 에러로 섹션이 통째로 건너뛰어졌는데 초록으로 끝나는 일이 없게(방금 그런 일이 있었다).
	for sec in ["import_parity", "authored_impl"]:
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

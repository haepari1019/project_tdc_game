extends Node3D
## **MapSource — 맵 계약**. 런·전투·파티가 맵에 요구하는 것의 전부를 여기 한 곳에 적는다.
## 지금까지 이 계약은 `map_demo_layout.gd`의 주석으로만 존재했고, 그래서 「인터페이스만 만족하면
## 갈아끼울 수 있다」가 **검증되지 않은 약속**이었다. 이 클래스가 그 약속을 코드로 바꾼다.
##
## 두 구현이 같은 계약을 만족한다:
##   - `map_demo_layout.gd`  절차 그레이박스 — 데이터에서 박스를 생성. 위상·문법 반복용.
##   - (후속) authored MapSource — Blender glTF + 마커 규약. 아트·구조 손편집용.
##
## 하위 구현이 해야 하는 것은 **셋뿐**이다:
##   1. `_room_points` 채우기 (room_ref -> {spawn: Vector3, size: Vector3}) + `_extraction_point`
##   2. 지오메트리를 `geometry_root()` 아래에 짓기 — 벽·장애물은 **콜리전 레이어 1**
##   3. 방마다 Area3D 트리거 → `_on_body_entered(body, room_ref)`
## 나머지(오클루더 유도·navmesh 베이크·계약 getter)는 이 클래스가 공짜로 준다.
##
## ref: docs/design/map_upgrade_plan.html §Phase 0 · docs/ARCHITECTURE.md
## 게이트: tools/map_smoke.gd — 이 계약을 **getter를 통해서만** 시험한다.

signal room_entered(room_ref: String)

## 지오메트리 루트가 속하는 그룹. 안개(F-011)가 「어디에 next_pass를 붙일지」를 노드 **이름**이
## 아니라 이 그룹으로 찾게 한다 — authored 씬의 루트 이름은 우리가 정하지 않는다.
const GEOMETRY_GROUP := "map_geometry"
## 치명존이 내비를 깎을 때 재베이크를 부르는 그룹.
const NAVMAP_GROUP := "navmap"

## 적 시야 레이가 지나는 높이. **이 높이를 가리는 레이어 1 콜라이더만 오클루더다.**
## 바닥(두께 0.3 m, y≤0)이 규칙에서 자동으로 빠지고, authored 맵의 임의 지오메트리에도 같은 선이 선다.
const LOS_EYE_Y := 1.0
## 방 경계에서 이만큼 안쪽에 있는 오클루더 = 벽이 아니라 **방 안 장애물**(상자 배치 앵커).
const INTERIOR_MARGIN_M := 1.0

# --- 계약 상태 (하위 구현이 채우거나, 이 클래스가 유도한다) --------------------
## room_ref -> {spawn: Vector3, size: Vector3}. **하위 구현이 채운다.**
var _room_points: Dictionary = {}
## 추출 지점(지면). **하위 구현이 채운다.**
var _extraction_point: Vector3 = Vector3.ZERO
## LOS 오클루더 footprint(월드 XZ). `derive_occluders()`가 콜라이더에서 유도한다 — 손으로 채우지 않는다.
## {center: Vector2, half: Vector2}(box) 또는 {center: Vector2, radius: float}(cyl).
var _occluders: Array = []
var _nav_region: NavigationRegion3D
var _warned_concave := false


# ============================================================================
# 하위 구현이 재정의하는 것
# ============================================================================

## 지오메트리가 매달린 루트 — navmesh 파싱과 오클루더 유도의 시작점.
## 절차 구현은 `$Rooms`, authored 구현은 임포트된 씬 루트를 돌려주면 된다.
func geometry_root() -> Node3D:
	return self


# ============================================================================
# 맵 계약 (interface) — 런/전투/파티가 읽는 것. 구현 무관.
# ============================================================================

## 방 조명 프로파일(lit/standard/dim/unlit). SSOT = `rooms.json`. F-011 §3.1.
func get_room_profile(room_ref: String) -> String:
	var row: Dictionary = Slice01Data.get_room_row(room_ref)
	if not row.is_empty() and row.has("lighting_profile"):
		return String(row.get("lighting_profile", "standard"))
	return "standard"


## 방 기준점(지면). 파티 스폰·분대 중심·고정 오브젝트 기준.
func get_spawn_position(room_ref: String = "RM-ENTRY-01") -> Vector3:
	var p: Dictionary = _room_points.get(room_ref, {})
	return p.get("spawn", Vector3(0, 0.02, 0))


## 방 footprint 크기(XZ; y=0). 상자 산포 개수·스폰 클램프.
func get_room_size(room_ref: String) -> Vector3:
	var p: Dictionary = _room_points.get(room_ref, {})
	return p.get("size", Vector3(8, 0, 8))


## 방 **안쪽** 장애물의 월드 위치들 — 상자를 기둥 옆에 붙이는 앵커.
## 벽과 구분은 「방 경계에서 안쪽으로 떨어져 있는가」로 한다(도형 종류가 아니라 위치로).
## 그래서 authored 맵이 어떤 메시를 놓든 같은 규칙이 선다. 손으로 목록을 관리하지 않는다.
func get_obstacle_positions(room_ref: String) -> Array:
	var p: Dictionary = _room_points.get(room_ref, {})
	if p.is_empty():
		return []
	var c: Vector3 = p.get("spawn", Vector3.ZERO)
	var s: Vector3 = p.get("size", Vector3.ZERO)
	var hx: float = s.x * 0.5 - INTERIOR_MARGIN_M
	var hz: float = s.z * 0.5 - INTERIOR_MARGIN_M
	var out: Array = []
	for occ in _occluders:
		var o: Vector2 = occ["center"]
		if absf(o.x - c.x) < hx and absf(o.y - c.z) < hz:
			out.append(Vector3(o.x, c.y, o.y))   # 방 바닥 높이를 따라간다(계약이 y를 나른다)
	return out


## 방 안쪽 먼 곳의 스폰 지점 — 적을 입구 시선에서 빼둔다(파티 접근 반대편).
func get_deep_spawn_position(room_ref: String, away_from: Vector3) -> Vector3:
	const MARGIN := 11.0  # 스폰 산포 링 + 유닛/벽 여유
	var p: Dictionary = _room_points.get(room_ref, {})
	var center: Vector3 = p.get("spawn", Vector3.ZERO)
	var size: Vector3 = p.get("size", Vector3(8, 0, 8))
	var dir := center - away_from
	dir.y = 0.0
	if dir.length() < 0.01:
		return center
	dir = dir.normalized()
	var avail_x := maxf(0.0, size.x * 0.5 - MARGIN)
	var avail_z := maxf(0.0, size.z * 0.5 - MARGIN)
	var tx: float = avail_x / absf(dir.x) if absf(dir.x) > 0.001 else INF
	var tz: float = avail_z / absf(dir.z) if absf(dir.z) > 0.001 else INF
	return center + dir * minf(tx, tz)


## 추출 지점(지면).
func get_extraction_position() -> Vector3:
	return _extraction_point


## LOS 오클루더 footprint(월드 XZ) — **적 시야 레이캐스트가 쓰는 콜라이더와 같은 출처**.
## `derive_occluders()`가 레이어 1 콜라이더에서 유도하므로 둘이 어긋날 수 없다. F-011 전제.
func get_occluder_footprints() -> Array:
	return _occluders


## 미니맵용 방 footprint: [{center: Vector3, size: Vector3}] (XZ 사용).
func get_room_rects() -> Array:
	var out: Array = []
	for ref in _room_points:
		var p: Dictionary = _room_points[ref]
		out.append({"center": p["spawn"], "size": p["size"]})
	return out


# ============================================================================
# 오클루더 유도 — **규약이 아니라 구조로** 「같은 출처」를 보장한다
# ============================================================================

## 지오메트리 아래 레이어 1 콜라이더 중 **LOS 높이를 가리는 것**의 XZ footprint를 모은다.
## 예전에는 절차 생성 도중 `_occluders.append(...)`로 손기록했다 — 그러면 생성기를 안 타는
## 맵(Blender authored)에선 **아무도 안 채우고**, 안개는 벽을 모르는데 적 시야만 아는 상태가 된다.
## 유도로 바꾸면 무엇을 어떻게 짓든 「레이캐스트가 맞는 것 = 안개가 아는 것」이 성립한다.
func derive_occluders() -> void:
	_occluders.clear()
	_collect_occluders(geometry_root())


func _collect_occluders(n: Node) -> void:
	for c in n.get_children():
		if c is StaticBody3D and (int((c as StaticBody3D).collision_layer) & 1) != 0:
			for cs in c.get_children():
				if cs is CollisionShape3D:
					var fp := _footprint(cs as CollisionShape3D)
					if not fp.is_empty():
						_occluders.append(fp)
		_collect_occluders(c)


## 콜리전 도형 → XZ footprint. LOS 높이를 안 가리면 빈 사전(= 오클루더 아님).
## 회전한 박스는 8꼭짓점을 XZ에 투영한 AABB로 근사한다(축정렬이면 정확히 같은 값이다).
func _footprint(cs: CollisionShape3D) -> Dictionary:
	var shape: Shape3D = cs.shape
	if shape == null:
		return {}
	var xf := cs.global_transform
	if shape is BoxShape3D:
		var h: Vector3 = (shape as BoxShape3D).size * 0.5
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		var y_mn := INF
		var y_mx := -INF
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var w: Vector3 = xf * Vector3(h.x * sx, h.y * sy, h.z * sz)
					mn.x = minf(mn.x, w.x); mn.y = minf(mn.y, w.z)
					mx.x = maxf(mx.x, w.x); mx.y = maxf(mx.y, w.z)
					y_mn = minf(y_mn, w.y); y_mx = maxf(y_mx, w.y)
		if y_mn > LOS_EYE_Y or y_mx < LOS_EYE_Y:
			return {}
		return {"center": (mn + mx) * 0.5, "half": (mx - mn) * 0.5}
	if shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		var o: Vector3 = xf.origin
		if (o.y - cyl.height * 0.5) > LOS_EYE_Y or (o.y + cyl.height * 0.5) < LOS_EYE_Y:
			return {}
		return {"center": Vector2(o.x, o.z), "radius": cyl.radius}
	if shape is ConvexPolygonShape3D:
		# 임의 형상(사선 벽·기울어진 기둥)의 XZ 볼록껍질. 안개는 이미 폴리곤을 그리므로
		# box/cyl은 편의 표기일 뿐이고 **이쪽이 일반형**이다.
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
		if ymn > LOS_EYE_Y or ymx < LOS_EYE_Y:
			return {}
		var hull := Geometry2D.convex_hull(flat)
		if hull.size() < 3:
			return {}
		return {"center": acc / float(pts.size()), "poly": hull}
	# **Concave(trimesh)는 일부러 건너뛴다.** Godot `-col` 임포트가 방 벽 전체를 콜라이더 하나로
	# 만드는 경우가 흔한데, 그 볼록껍질은 **방 안쪽 전체**가 되어 안개가 거짓말을 하게 된다.
	# authored 맵은 `OCC_*-colonly` 프록시(박스/볼록)를 따로 두는 규약이다. ref: 플랜 §Blender 저작 규약.
	if shape is ConcavePolygonShape3D and not _warned_concave:
		_warned_concave = true
		push_warning("[MAP] Concave(trimesh) 콜라이더는 오클루더로 쓰지 않는다 — OCC_* 프록시를 두라")
	return {}


# ============================================================================
# Navigation — 두 구현이 공유한다(임포트된 콜라이더도 같은 경로로 파싱된다)
# ============================================================================

func bake_navigation() -> void:
	if _nav_region == null:
		_nav_region = NavigationRegion3D.new()
		_nav_region.name = "NavRegion"
		add_child(_nav_region)
	var navmesh := NavigationMesh.new()
	navmesh.agent_radius = 0.5      # 2× cell_size — 베이커의 ceil과 일치(정밀도 경고 없음)
	navmesh.agent_height = 1.25     # 5× cell_height
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25      # navigation map cell_height와 일치(래스터화 불일치 없음)
	navmesh.agent_max_climb = 0.25  # 1× cell_height — 단차(Phase 5)는 이 값이 상한이다
	navmesh.agent_max_slope = 45.0
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var source_geo := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source_geo, geometry_root())
	# 활성 치명존을 깎아 내비가 **돌아가게** 한다(벽과 같은 취급).
	for z in get_tree().get_nodes_in_group("fatal_zone"):
		if z.is_active():
			_carve_zone(source_geo, z.global_position, float(z.radius))
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source_geo)
	_nav_region.navigation_mesh = navmesh
	print("[MAP] NavMesh baked: %d polygons" % navmesh.get_polygon_count())


## 치명존 생성/해제 시 재베이크 — 그룹 `navmap`으로 호출된다.
func rebake_navigation() -> void:
	bake_navigation()


func _carve_zone(geo: NavigationMeshSourceGeometryData3D, center: Vector3, radius: float) -> void:
	var verts := PackedVector3Array()
	var segs := 14
	for i in segs:
		var a := float(i) * TAU / float(segs)
		verts.append(Vector3(center.x + cos(a) * radius, 0.0, center.z + sin(a) * radius))
	geo.add_projected_obstruction(verts, -1.0, 4.0, true)  # elevation, height, carve=true


# ============================================================================

## 방 트리거 Area3D가 물릴 핸들러 — 하위 구현이 `bind(room_ref)` 해서 연결한다.
func _on_body_entered(body: Node3D, room_ref: String) -> void:
	if not body.is_in_group("player"):
		return
	room_entered.emit(room_ref)

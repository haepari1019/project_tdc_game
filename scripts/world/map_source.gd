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

## 적 시야 레이가 지나는 높이 — **방 바닥 기준 상대값**이다. 이 높이를 가리는 레이어 1 콜라이더만
## 오클루더이고, 바닥(두께 0.3 m)은 규칙에서 자동으로 빠진다.
## 🔴 **절대 월드 Y가 아니다.** 예전엔 상수 1.0을 월드 좌표로 썼는데, 그러면 바닥이 y=−6인 방
## (계단으로 내려간 구획)의 벽이 y∈[−6,−2.5]라 **오클루더에서 통째로 빠진다** — 안개가 없는 방이
## 조용히 생긴다. 게이트도 못 잡는다(양쪽이 같은 절대 규칙을 쓰므로 사이좋게 0개로 일치한다).
const LOS_EYE_H := 1.0
## 방 경계에서 이만큼 안쪽에 있는 오클루더 = 벽이 아니라 **방 안 장애물**(상자 배치 앵커).
const INTERIOR_MARGIN_M := 1.0

## **레이어 → world 콜리전 비트.** 레이어가 XZ를 공유해도 서로의 시야·경로를 안 건드리게 하려면
## 지오메트리가 **레이어별 비트**에 있어야 한다(`LDG-001` §9.2 · `DEC-20260824-001`).
## `layer 0` = 비트 1 = 기존 `"world"` → **현 맵은 아무것도 안 바뀐다.**
## 비트 2(party)·4(enemy)·8(AB-033 엄폐 돔)은 이미 쓰이므로 layer 1부터 **비트 16**에서 시작한다.
const MAX_LAYERS := 4
static func world_bit(layer: int) -> int:
	return 1 if layer <= 0 else (1 << (3 + layer))
## 전 레이어 world 비트 합집합 — 「이 콜라이더가 맵 지오메트리인가」 판정용.
static func world_mask_all() -> int:
	var m := 0
	for i in MAX_LAYERS:
		m |= world_bit(i)
	return m
## 비트 → 레이어 역변환(모르면 -1).
static func layer_of_bit(mask: int) -> int:
	for i in MAX_LAYERS:
		if (mask & world_bit(i)) != 0:
			return i
	return -1

# --- 계약 상태 (하위 구현이 채우거나, 이 클래스가 유도한다) --------------------
## room_ref -> {spawn: Vector3, size: Vector3}. **하위 구현이 채운다.**
var _room_points: Dictionary = {}
## 추출 지점(지면). **하위 구현이 채운다.**
var _extraction_point: Vector3 = Vector3.ZERO
## LOS 오클루더 footprint(월드 XZ). `derive_occluders()`가 콜라이더에서 유도한다 — 손으로 채우지 않는다.
## {center: Vector2, half: Vector2}(box) 또는 {center: Vector2, radius: float}(cyl).
var _occluders: Array = []
## 레이어별 내비 리전·맵. **`layer 0`은 월드 기본 맵에 그대로 둔다** — 기존 호출부
## (`get_world_3d().navigation_map`)가 하나도 안 바뀐다. `layer ≥ 1`만 자기 맵을 갖는다.
## 층마다 **별도 맵**인 이유: 활성/비활성 토글로 하면 비활성 층의 적이 경로를 못 찾는데,
## 「전 레이어 실시간 진행」이 결정이라 **모든 층이 동시에 살아 있어야** 한다.
var _nav_regions: Dictionary = {}   # layer -> NavigationRegion3D
var _nav_maps: Dictionary = {}      # layer -> RID (layer 0 제외)
var _warned_concave := false
## 앵커 — 방 안의 「무엇이 어디에」. room_ref -> kind -> Array[{ref?, role?, type?, pos: Vector3(월드), ...}].
## 그레이박스는 `resolve_anchors_from_data()`가 rooms.json의 **로컬 XZ**에서 채우고, authored 맵은
## 씬의 `MK_*` 마커에서 채운다 — 그때 데이터에는 종류·개수·ref만 남고 좌표는 씬이 소유한다.
var _anchors: Dictionary = {}
## 에디터 폴백용 rooms.json 캐시(autoload가 없을 때만 채워진다).
var _rooms_disk: Dictionary = {}
## 현재 파티가 있는 레이어. 안개·오클루더 조회가 이 값으로 걸러진다(활성 레이어는 언제나 하나).
var _active_layer: int = 0


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

## 방 데이터(rooms.json). **런타임은 autoload, 에디터(@tool 프리뷰)는 디스크에서 직접** 읽는다 —
## 에디터에는 autoload가 없어서, 이 폴백이 없으면 프리뷰가 첫 줄에서 죽는다.
func _rooms_doc() -> Dictionary:
	var sd := get_node_or_null("/root/Slice01Data")
	if sd != null and sd.has_method("get_rooms_document"):
		return sd.get_rooms_document()
	if _rooms_disk.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/slice01/rooms.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			_rooms_disk = parsed
	return _rooms_disk


func _room_row(room_ref: String) -> Dictionary:
	for row in _rooms_doc().get("rooms", []):
		if typeof(row) == TYPE_DICTIONARY and String((row as Dictionary).get("room_ref", "")) == room_ref:
			return row
	return {}


## 파티가 진입하는 방(`rooms.json` `entry_room`). 맵마다 다르므로 **데이터가 소유한다**.
func get_entry_room() -> String:
	var e := String(_rooms_doc().get("entry_room", ""))
	if not e.is_empty():
		return e
	for row in _rooms_doc().get("rooms", []):   # 폴백: 첫 방
		if typeof(row) == TYPE_DICTIONARY:
			return String((row as Dictionary).get("room_ref", ""))
	return ""


## **층 간 전이(계단) 목록** — `[[from_room, to_room], ...]`. `connects`(공유벽·도보)와 **별개**다:
## `connects`는 걸어서 갈 수 있다는 뜻이고 계단은 워프다. 도달성은 **둘을 합쳐** 봐야 한다.
func stair_links() -> Array:
	var out: Array = []
	for ref in _anchors:
		for a in (_anchors[ref] as Dictionary).get("transitions", []):
			var d := a as Dictionary
			if String(d.get("role", "")) != "stairs":
				continue
			var to := String(d.get("to", ""))
			if not to.is_empty():
				out.append([String(ref), to])
	return out


## 방이 속한 레이어(`rooms.json` `layer`; 기본 0 = 지상).
func get_room_layer(room_ref: String) -> int:
	return int(_room_row(room_ref).get("layer", 0))


## 활성 레이어 — 파티가 있는 층. 전이(계단) 시 바뀐다.
func get_active_layer() -> int:
	return _active_layer


func set_active_layer(layer: int) -> void:
	_active_layer = layer


## 방 조명 프로파일(lit/standard/dim/unlit). SSOT = `rooms.json`. F-011 §3.1.
func get_room_profile(room_ref: String) -> String:
	var row: Dictionary = _room_row(room_ref)
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
## `derive_occluders()`가 world 콜라이더에서 유도하므로 둘이 어긋날 수 없다. F-011 전제.
## **활성 레이어만** 돌려준다 — 안개는 XZ 텍스처 하나라 다른 층 도형이 섞이면 거짓말을 한다.
func get_occluder_footprints() -> Array:
	var out: Array = []
	for occ in _occluders:
		if int((occ as Dictionary).get("layer", 0)) == _active_layer:
			out.append(occ)
	return out


## 레이어 무관 전체(게이트·디버그용).
func get_all_occluder_footprints() -> Array:
	return _occluders


## 미니맵용 방 footprint: [{center, size, room_ref, layer}] (XZ 사용).
## `layer`가 실려 오므로 미니맵은 **활성 층만** 그릴 수 있다 — 층이 XZ를 공유하니
## 다 그리면 겹쳐서 「지금 어느 층인지」를 잃는다(`F-024` 인지 예산).
## 안개 바운딩은 반대로 **전 층 합집합**을 쓴다 — 다만 그게 **필수는 아니다**: 한 번에 한 층만
## 렌더하므로 층별 바운딩도 가능하다. 합집합을 쓰는 이유는 ① **겹치는 층이 전제**라 합집합 ≈ 각 층의
## 상자여서 절약분이 없고 ② 층별로 하면 전이마다 공유 뷰포트를 리사이즈하고 오클루더·라이트 좌표를
## 다시 계산해야 하는데, 바운딩과 텍스처가 어긋나면 **안개가 미터 단위로 밀린다**(전이는 원자적이어야 한다).
## → 저작 규칙: **어떤 층도 다른 층 밖으로 뻗지 않게.** 뻗으면 그 비용을 **모든 층이 함께** 낸다.
## 확장 비용의 실체는 바운딩이 아니라 **방문한 층 수 × 탐색 누적 텍스처 1장**이다.
func get_room_rects() -> Array:
	var out: Array = []
	for ref in _room_points:
		var p: Dictionary = _room_points[ref]
		out.append({"center": p["spawn"], "size": p["size"],
			"room_ref": String(ref), "layer": get_room_layer(String(ref))})
	return out


## 방 연결(무향, 중복 제거) — `[[room_a, room_b, opening_width], ...]`.
## **`rooms.json` `connects`가 단일 소유자다.** 예전에는 지오메트리 상수(`CONNECTIONS`)와
## 데이터가 같은 연결을 두 벌 갖고 있었고, 어긋나도 아무도 알려주지 않았다(DEBT-DM3).
func room_connections() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for row in _rooms_doc().get("rooms", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var a := String((row as Dictionary).get("room_ref", ""))
		for c in (row as Dictionary).get("connects", []):
			var b := ""
			var width := 8.0
			if typeof(c) == TYPE_DICTIONARY:
				b = String((c as Dictionary).get("to", ""))
				width = float((c as Dictionary).get("width", 8.0))
			else:
				b = String(c)          # 하위호환: 폭 없는 문자열 항목
			if b.is_empty():
				continue
			var key: String = ("%s|%s" % [a, b]) if a < b else ("%s|%s" % [b, a])
			if seen.has(key):
				continue
			seen[key] = true
			out.append([a, b, width])
	return out


## 방 안 앵커(월드 좌표). kind = obstacles | interactions | hazards | transitions | props.
func get_anchors(room_ref: String, kind: String) -> Array:
	return (_anchors.get(room_ref, {}) as Dictionary).get(kind, [])


## 맵 전체 앵커. 각 항목에 `room_ref`가 실려 온다.
func get_all_anchors(kind: String) -> Array:
	var out: Array = []
	for ref in _anchors:
		for a in (_anchors[ref] as Dictionary).get(kind, []):
			var e: Dictionary = (a as Dictionary).duplicate()
			e["room_ref"] = ref
			out.append(e)
	return out


## rooms.json `anchors`(방 중심 기준 로컬 XZ) → 월드. **그레이박스 전용 폴백**이다 —
## authored 구현은 이걸 부르지 않고 마커에서 `_anchors`를 채운다(좌표의 소유자가 씬이 된다).
## y는 방 바닥 높이를 따라간다(계약이 y를 나른다 — Phase 5 단차 대비).
func resolve_anchors_from_data() -> void:
	_anchors.clear()
	for row in _rooms_doc().get("rooms", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var ref := String((row as Dictionary).get("room_ref", ""))
		var block: Dictionary = (row as Dictionary).get("anchors", {})
		if block.is_empty() or not _room_points.has(ref):
			continue
		var origin: Vector3 = _room_points[ref]["spawn"]
		var by_kind: Dictionary = {}
		for kind in block:
			var list: Array = []
			for a in block[kind]:
				var e: Dictionary = (a as Dictionary).duplicate()
				var lp: Array = e.get("pos", [0, 0])
				e["pos"] = Vector3(origin.x + float(lp[0]), origin.y, origin.z + float(lp[1]))
				list.append(e)
			by_kind[String(kind)] = list
		_anchors[ref] = by_kind


# ============================================================================
# 오클루더 유도 — **규약이 아니라 구조로** 「같은 출처」를 보장한다
# ============================================================================

## 그 XZ 지점의 **방 바닥 높이**. 계단으로 내려간 구획(바닥 y<0)에서도 LOS 기준이 따라오게 한다.
## 어느 방에도 안 들어가면 0(맵 밖 지오메트리).
func floor_y_at(xz: Vector2) -> float:
	for ref in _room_points:
		var p: Dictionary = _room_points[ref]
		var c: Vector3 = p["spawn"]
		var sz: Vector3 = p["size"]
		if absf(xz.x - c.x) <= sz.x * 0.5 + 0.5 and absf(xz.y - c.z) <= sz.z * 0.5 + 0.5:
			return c.y
	return 0.0


## 지오메트리 아래 레이어 1 콜라이더 중 **LOS 높이를 가리는 것**의 XZ footprint를 모은다.
## 예전에는 절차 생성 도중 `_occluders.append(...)`로 손기록했다 — 그러면 생성기를 안 타는
## 맵(Blender authored)에선 **아무도 안 채우고**, 안개는 벽을 모르는데 적 시야만 아는 상태가 된다.
## 유도로 바꾸면 무엇을 어떻게 짓든 「레이캐스트가 맞는 것 = 안개가 아는 것」이 성립한다.
func derive_occluders() -> void:
	_occluders.clear()
	_collect_occluders(geometry_root())


func _collect_occluders(n: Node) -> void:
	for c in n.get_children():
		if c is StaticBody3D and (int((c as StaticBody3D).collision_layer) & world_mask_all()) != 0:
			var lyr := layer_of_bit(int((c as StaticBody3D).collision_layer))
			for cs in c.get_children():
				if cs is CollisionShape3D:
					var fp := _footprint(cs as CollisionShape3D)
					if not fp.is_empty():
						fp["layer"] = maxi(0, lyr)   # 지오메트리의 **비트**가 곧 레이어다
						_occluders.append(fp)
		_collect_occluders(c)


## 콜리전 도형 → XZ footprint. LOS 높이를 안 가리면 빈 사전(= 오클루더 아님).
## 회전한 박스는 8꼭짓점을 XZ에 투영한 AABB로 근사한다(축정렬이면 정확히 같은 값이다).
func _footprint(cs: CollisionShape3D) -> Dictionary:
	var shape: Shape3D = cs.shape
	if shape == null:
		return {}
	var xf := cs.global_transform
	var eye: float = floor_y_at(Vector2(xf.origin.x, xf.origin.z)) + LOS_EYE_H
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
		if y_mn > eye or y_mx < eye:
			return {}
		return {"center": (mn + mx) * 0.5, "half": (mx - mn) * 0.5}
	if shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		var o: Vector3 = xf.origin
		if (o.y - cyl.height * 0.5) > eye or (o.y + cyl.height * 0.5) < eye:
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
		if ymn > eye or ymx < eye:
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

## 그 레이어의 내비 맵 RID. `layer 0` = 월드 기본 맵(기존 동작).
func get_nav_map(layer: int) -> RID:
	if layer <= 0 or not _nav_maps.has(layer):
		return get_world_3d().navigation_map
	return _nav_maps[layer]


## 지오메트리에 **실제로 쓰인** 레이어들. 「비트가 곧 레이어」이므로 콜라이더에서 읽는다 —
## 데이터(rooms.json)와 씬이 어긋나도 씬이 정답이다(안 그러면 리전 없는 층이 생긴다).
func layers_present() -> Array:
	var out: Array = [0]
	_collect_layers(geometry_root(), out)
	out.sort()
	return out


func _collect_layers(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is StaticBody3D:
			var l := layer_of_bit(int((c as StaticBody3D).collision_layer))
			if l > 0 and not out.has(l):
				out.append(l)
		_collect_layers(c, out)


## **비활성 층을 숨긴다.** 층이 XZ를 공유하므로 다 보이면 겹쳐 그려진다 — 한 번에 한 층만 보인다.
## 방 노드 이름이 `room_ref`라는 규약(절차·authored 공통)을 이용해 방 단위로 토글한다.
func set_visible_layer(active: int) -> void:
	var root := geometry_root()
	if root == null:
		return
	for c in root.get_children():
		var ref := String(c.name)
		if not _room_points.has(ref):
			continue
		if c is Node3D:
			(c as Node3D).visible = (get_room_layer(ref) == active)


## 그 XZ 지점의 레이어(방 기준). 치명존이 **자기 층만** 깎게 한다.
func layer_at(xz: Vector2) -> int:
	for ref in _room_points:
		var p: Dictionary = _room_points[ref]
		var c: Vector3 = p["spawn"]
		var sz: Vector3 = p["size"]
		if absf(xz.x - c.x) <= sz.x * 0.5 + 0.5 and absf(xz.y - c.z) <= sz.z * 0.5 + 0.5:
			return get_room_layer(String(ref))
	return 0


func bake_navigation() -> void:
	for layer in layers_present():
		_bake_layer(int(layer))


func _bake_layer(layer: int) -> void:
	var region: NavigationRegion3D = _nav_regions.get(layer)
	if region == null:
		region = NavigationRegion3D.new()
		region.name = "NavRegion_L%d" % layer
		add_child(region)
		_nav_regions[layer] = region
		if layer > 0:
			# 자기 맵을 만들어 붙인다 — 셀 규격은 아래 navmesh와 맞춘다(래스터화 불일치 방지).
			var rid := NavigationServer3D.map_create()
			NavigationServer3D.map_set_up(rid, Vector3.UP)
			NavigationServer3D.map_set_cell_size(rid, 0.25)
			NavigationServer3D.map_set_cell_height(rid, 0.25)
			NavigationServer3D.map_set_active(rid, true)
			_nav_maps[layer] = rid
			region.set_navigation_map(rid)
	var navmesh := NavigationMesh.new()
	navmesh.agent_radius = 0.5      # 2× cell_size — 베이커의 ceil과 일치(정밀도 경고 없음)
	navmesh.agent_height = 1.25     # 5× cell_height
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25      # navigation map cell_height와 일치(래스터화 불일치 없음)
	navmesh.agent_max_climb = 0.25  # 1× cell_height — 단차(Phase 5)는 이 값이 상한이다
	navmesh.agent_max_slope = 45.0
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	navmesh.geometry_collision_mask = world_bit(layer)   # ← **이 층의 지오메트리만** 파싱한다
	var source_geo := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source_geo, geometry_root())
	# 활성 치명존을 깎아 내비가 **돌아가게** 한다(벽과 같은 취급). **자기 층 것만** 깎는다 —
	# 층이 XZ를 공유하므로 남의 층 장판이 이 층 바닥에 구멍을 내면 안 된다.
	for z in get_tree().get_nodes_in_group("fatal_zone"):
		if z.is_active() and layer_at(Vector2(z.global_position.x, z.global_position.z)) == layer:
			_carve_zone(source_geo, z.global_position, float(z.radius))
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source_geo)
	(_nav_regions[layer] as NavigationRegion3D).navigation_mesh = navmesh
	print("[MAP] NavMesh baked (layer %d): %d polygons" % [layer, navmesh.get_polygon_count()])


## 치명존 생성/해제 시 재베이크 — 그룹 `navmap`으로 호출된다.
func rebake_navigation() -> void:
	bake_navigation()


func _carve_zone(geo: NavigationMeshSourceGeometryData3D, center: Vector3, radius: float) -> void:
	var verts := PackedVector3Array()
	var segs := 14
	for i in segs:
		var a := float(i) * TAU / float(segs)
		verts.append(Vector3(center.x + cos(a) * radius, 0.0, center.z + sin(a) * radius))
	# elevation은 **존이 놓인 바닥 기준**이다 — 절대 −1.0을 쓰면 내려간 구획에서 엉뚱한 높이를 깎는다.
	geo.add_projected_obstruction(verts, center.y - 1.0, 4.0, true)  # elevation, height, carve=true


# ============================================================================

## 방 트리거 Area3D가 물릴 핸들러 — 하위 구현이 `bind(room_ref)` 해서 연결한다.
func _on_body_entered(body: Node3D, room_ref: String) -> void:
	if not body.is_in_group("player"):
		return
	room_entered.emit(room_ref)

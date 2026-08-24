@tool
extends "res://scripts/world/map_source.gd"
## **MAP-DEMO-001 — 절차 그레이박스 MapSource 구현.** 방을 **맵 문서**(`geometry` + `connects`)에서
## 박스로 생성한다. 계약 자체는 base `map_source.gd`가 소유하고, 여기는 **공간을 만드는 방법**만
## 안다 — 같은 계약의 authored(Blender) 구현이 나란히 설 수 있는 이유다.
## ref: docs/design/map_upgrade_plan.html §Phase 0 · 게이트 tools/map_smoke.gd

const PROFILE_COLORS: Dictionary = {
	"lit": Color(0.45, 0.42, 0.38),
	"standard": Color(0.35, 0.33, 0.30),
	"dim": Color(0.22, 0.20, 0.25),
}

## 라이팅 옵션 오브젝트 — 방별 lighting_profile에 따라 배치되는 천장 광원 픽스처.
## 어두운 던전(전역광 약화 + 어두운 ambient) 위에서 시야를 만든다. 시야 축소
## dim/unlit 은 스펙 F-011(시야 축소 dim 0.85×·unlit 0.65×)과 직결.
## energy=0 이면 광원 미배치(unlit). ref: data/slice01/rooms.json lighting_profile
const LIGHT_PROFILES: Dictionary = {
	"lit": {"energy": 3.0, "range_scale": 0.95, "color": Color(1.00, 0.90, 0.74)},
	"standard": {"energy": 2.1, "range_scale": 0.90, "color": Color(0.96, 0.86, 0.70)},
	"dim": {"energy": 1.1, "range_scale": 0.78, "color": Color(0.58, 0.60, 0.78)},
	"unlit": {"energy": 0.0, "range_scale": 0.0, "color": Color(0.50, 0.50, 0.60)},
}
## 횃불 광원(ENT-TORCH) 1개가 담당하는 대략적 그리드 셀 크기(m). 너무 많지 않게 성기게 깐다.
const LIGHT_GRID_SPACING := 20.0
const Lantern := preload("res://scripts/world/objects/lantern.gd")

const WALL_HEIGHT := 3.5
const WALL_THICKNESS := 0.4
## Two adjacent rooms each build a wall on their SHARED edge → coplanar duplicate faces that
## z-fight ("jitter", exposed by the Forward+ depth buffer). Pull each room's wall ring in by
## this much so the duplicated faces separate cleanly (invisible; walls still overlap + block).
const WALL_DEDUP_EPS := 0.04
const FLOOR_THICKNESS := 0.3

## Cover obstacles — LOS blockers + navmesh holes (units route around). Heights
## clear the party→enemy LOS ray so enemies behind them are occluded. F-011 pre-step.
const OBSTACLE_TYPES: Dictionary = {
	"pillar":  {"shape": "cyl", "radius": 2.0, "height": WALL_HEIGHT, "color": Color(0.30, 0.28, 0.26)},
	"crates":  {"shape": "box", "size": Vector3(5.0, 2.4, 5.0), "color": Color(0.42, 0.32, 0.18)},
	"barrier": {"shape": "box", "size": Vector3(8.0, 2.4, 1.6), "color": Color(0.34, 0.30, 0.27)},
}

@onready var _rooms_root: Node3D = $Rooms
@onready var _markers_root: Node3D = $Markers

var _room_areas: Dictionary = {}
## Per-room openings: room_ref -> Array of {side, pos_along, width}
var _room_openings: Dictionary = {}
## 맵 문서에서 읽은 방 기하 캐시 — `{room_ref: {center, size, label, extraction}}`.
## 삽입 순서 = 문서 배열 순서 = **생성 순서**(벽 dedup이 순서에 의존한다).
var _specs: Dictionary = {}


## 에디터 프리뷰(**옵트인**) — 켜면 3D 뷰포트에 그레이박스가 뜬다. 생성 노드는 `owner`를 설정하지
## 않으므로 **`.tscn`에 직렬화되지 않는다** — 데이터가 SSOT로 남고, 손으로 옮긴 벽이 저장돼
## 데이터와 두 벌이 되는 사고가 원천적으로 안 생긴다(플랜 §「에디터 = 뷰어」).
## 기본값 false: 씬을 열 때마다 16방을 짓지 않는다. 켜기 전엔 `tools/map_shot.gd`가 더 싸다.
@export var preview_in_editor := false


func _ready() -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	add_to_group(NAVMAP_GROUP)                 # 치명존 carve → rebake_navigation
	_rooms_root.add_to_group(GEOMETRY_GROUP)   # 안개가 노드 **이름**이 아니라 그룹으로 찾는다
	_resolve_room_points()
	resolve_anchors_from_data()        # 코드 상수가 아니라 rooms.json이 「무엇이 어디에」를 소유한다
	_compute_openings()
	_build_map()
	derive_occluders()                         # 손기록이 아니라 **콜라이더에서 유도**(F-011 같은 출처)
	if Engine.is_editor_hint():
		return                                 # 프리뷰는 형태만 본다 — navmesh 베이크는 런타임에서만
	bake_navigation()


# ============================================================================
# MapSource 구현부 — 계약 getter는 전부 base(map_source.gd)에 있다.
# 여기가 채우는 것은 셋뿐: `_room_points`/`_extraction_point` · 레이어 1 지오메트리 ·
# 방 트리거. 그래서 Blender authored 맵으로 갈아끼울 때 **호출부는 하나도 안 고친다**.
# ============================================================================

## 지오메트리 루트 — navmesh 파싱과 오클루더 유도가 여기서 시작한다.
func geometry_root() -> Node3D:
	return _rooms_root



## Populate the runtime room-points table + extraction point. Placeholder derives
## from the map document `geometry`. A real (Blender) map replaces this — e.g. read authored
## Marker3D points per room_ref — and every getter above keeps working unchanged.
func _resolve_room_points() -> void:
	_room_points.clear()
	_specs.clear()
	for room_ref in data_room_refs():
		var spec: Dictionary = room_geometry(String(room_ref))
		if spec.is_empty():
			push_error("[MAP] %s: 맵 문서에 `geometry` 없음 — 그레이박스는 데이터가 좌표를 갖는다" % room_ref)
			continue
		_specs[String(room_ref)] = spec
		var center: Vector3 = spec["center"]
		_room_points[String(room_ref)] = {
			"spawn": center + Vector3(0, 0.02, 0),
			"size": spec.get("size", Vector3(8, 0, 8)),
		}
		if bool(spec["extraction"]):
			_extraction_point = center   # 계약이 y를 나른다 — 바닥 높이가 다른 맵(Phase 5 단차)에 대비


func _compute_openings() -> void:
	for room_ref in _specs.keys():
		_room_openings[room_ref] = []

	for conn in room_connections():   # SSOT = rooms.json `connects`(개구부 폭 포함)
		var ref_a: String = conn[0]
		var ref_b: String = conn[1]
		var width: float = conn[2]
		if not _specs.has(ref_a) or not _specs.has(ref_b):
			continue                      # 기하 없는 방은 위에서 이미 에러를 냈다
		var ca: Vector3 = _specs[ref_a]["center"]
		var cb: Vector3 = _specs[ref_b]["center"]
		var sa: Vector3 = _specs[ref_a]["size"]
		var sb: Vector3 = _specs[ref_b]["size"]
		var diff := cb - ca

		if absf(diff.x) > absf(diff.z):
			# Horizontal adjacency (east/west)
			# Opening is on Z axis — pos_along is relative to room center Z
			# Find Z overlap center between the two rooms
			var a_z_min: float = ca.z - sa.z * 0.5
			var a_z_max: float = ca.z + sa.z * 0.5
			var b_z_min: float = cb.z - sb.z * 0.5
			var b_z_max: float = cb.z + sb.z * 0.5
			var overlap_center_z: float = (maxf(a_z_min, b_z_min) + minf(a_z_max, b_z_max)) * 0.5

			if diff.x > 0:
				_room_openings[ref_a].append({"side": "east", "pos_along": overlap_center_z - ca.z, "width": width})
				_room_openings[ref_b].append({"side": "west", "pos_along": overlap_center_z - cb.z, "width": width})
			else:
				_room_openings[ref_a].append({"side": "west", "pos_along": overlap_center_z - ca.z, "width": width})
				_room_openings[ref_b].append({"side": "east", "pos_along": overlap_center_z - cb.z, "width": width})
		else:
			# Vertical adjacency (north/south)
			# Opening is on X axis — pos_along is relative to room center X
			var a_x_min: float = ca.x - sa.x * 0.5
			var a_x_max: float = ca.x + sa.x * 0.5
			var b_x_min: float = cb.x - sb.x * 0.5
			var b_x_max: float = cb.x + sb.x * 0.5
			var overlap_center_x: float = (maxf(a_x_min, b_x_min) + minf(a_x_max, b_x_max)) * 0.5

			if diff.z > 0:
				_room_openings[ref_a].append({"side": "north", "pos_along": overlap_center_x - ca.x, "width": width})
				_room_openings[ref_b].append({"side": "south", "pos_along": overlap_center_x - cb.x, "width": width})
			else:
				_room_openings[ref_a].append({"side": "south", "pos_along": overlap_center_x - ca.x, "width": width})
				_room_openings[ref_b].append({"side": "north", "pos_along": overlap_center_x - cb.x, "width": width})


func _build_map() -> void:
	for room_ref in _specs.keys():
		_build_room(String(room_ref))


func _build_room(room_ref: String) -> void:
	var spec: Dictionary = _specs[room_ref]
	var center: Vector3 = spec["center"]
	var size: Vector3 = spec["size"]
	var profile: String = get_room_profile(room_ref)  # SSOT = rooms.json
	# 이 방의 지오메트리가 놓일 **world 콜리전 비트**. layer 0 = 비트 1(기존 값) → 현 맵 불변.
	var wbit: int = world_bit(get_room_layer(room_ref))

	var room_node := Node3D.new()
	room_node.name = room_ref
	_rooms_root.add_child(room_node)

	var col: Color = PROFILE_COLORS.get(profile, Color.GRAY)
	if bool(spec["extraction"]):
		col = Color(0.25, 0.55, 0.35)

	# Floor
	_add_floor(room_node, center, size, col, wbit)

	# Walls with openings
	var openings: Array = _room_openings.get(room_ref, [])
	_add_walls_with_openings(room_node, center, size, col, openings, wbit)

	# Lighting option objects (per-room fixtures keyed by profile)
	_add_room_lighting(room_node, center, size, profile)

	# Cover obstacles — LOS blockers + navmesh holes (baked with the room)
	_build_obstacles(room_node, room_ref, center, wbit)

	# Room trigger volume
	var area := Area3D.new()
	area.name = "RoomVolume"
	area.position = center
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	area.monitoring = true
	var shape := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(size.x, 4.0, size.z)
	shape.shape = cs
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered.bind(room_ref))
	room_node.add_child(area)
	_room_areas[room_ref] = area

	# Label
	var room_label: String = String(spec["label"])
	var label := Label3D.new()
	label.text = "%s\n%s" % [room_ref, room_label]
	label.position = center + Vector3(0, 3.2, 0)
	label.font_size = 36
	label.fixed_size = true       # 카메라 거리와 무관하게 화면상 일정 크기
	label.pixel_size = 0.0005
	label.modulate = Color(1, 1, 1, 0.65)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_markers_root.add_child(label)

	# Extraction marker
	if room_ref == "RM-EXT-01":
		var ext := MeshInstance3D.new()
		ext.name = "POINT-DEMO-01"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.5
		cyl.bottom_radius = 1.8
		cyl.height = 0.15
		ext.mesh = cyl
		ext.position = center + Vector3(0, 0.08, 0)
		var ext_mat := StandardMaterial3D.new()
		ext_mat.albedo_color = Color(0.2, 0.85, 0.4, 0.7)
		ext_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ext_mat.emission_enabled = true
		ext_mat.emission = Color(0.1, 0.6, 0.3)
		ext.material_override = ext_mat
		_markers_root.add_child(ext)


## Places the room's light sources as fixed LANTERNS (floor braziers) on a grid — stable room
## lighting that can't be grabbed. Carriable ENT-TORCH are hand-placed near the oil instead
## (dungeon_run), so an enemy can't dark out a whole room by throwing every light. profile
## "unlit" (energy 0) places none; dimmer profiles use lower energy. Warm light regardless.
func _add_room_lighting(parent: Node3D, center: Vector3, size: Vector3, profile: String) -> void:
	var prof: Dictionary = LIGHT_PROFILES.get(profile, LIGHT_PROFILES["standard"])
	var energy: float = float(prof["energy"])
	if energy <= 0.0:
		return

	var count_x: int = maxi(1, int(round(size.x / LIGHT_GRID_SPACING)))
	var count_z: int = maxi(1, int(round(size.z / LIGHT_GRID_SPACING)))
	var cell_x: float = size.x / float(count_x)
	var cell_z: float = size.z / float(count_z)
	var torch_range: float = clampf(maxf(cell_x, cell_z) * float(prof["range_scale"]) + 3.0, 11.0, 22.0)
	var warm := Color(1.0, 0.72, 0.42)

	var fixtures := Node3D.new()
	fixtures.name = "Lighting"
	parent.add_child(fixtures)

	for ix in count_x:
		for iz in count_z:
			var lx: float = -size.x * 0.5 + cell_x * (float(ix) + 0.5)
			var lz: float = -size.z * 0.5 + cell_z * (float(iz) + 0.5)
			var lantern := Lantern.new()
			lantern.position = center + Vector3(lx, 0.0, lz)
			fixtures.add_child(lantern)                         # _ready builds its light
			lantern.configure_light(energy * 0.6, torch_range, warm)


func _add_floor(parent: Node3D, center: Vector3, size: Vector3, color: Color, wbit: int = 1) -> void:
	var body := StaticBody3D.new()
	body.name = "FloorBody"
	body.position = center + Vector3(0, -FLOOR_THICKNESS * 0.5, 0)
	body.collision_layer = wbit

	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(size.x, FLOOR_THICKNESS, size.z)
	col_shape.shape = box_shape
	body.add_child(col_shape)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, FLOOR_THICKNESS, size.z)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh.material_override = mat
	body.add_child(mesh)

	parent.add_child(body)


func _add_walls_with_openings(parent: Node3D, center: Vector3, size: Vector3, base_color: Color, openings: Array, wbit: int = 1) -> void:
	var wall_color := base_color.darkened(0.25)
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5

	var side_openings: Dictionary = {"north": [], "south": [], "east": [], "west": []}
	for opening in openings:
		var side: String = opening["side"]
		side_openings[side].append(opening)

	# Pull the wall ring in by WALL_DEDUP_EPS so a shared edge with the adjacent room isn't built
	# as two coplanar (z-fighting) walls — they separate cleanly while still overlapping/blocking.
	var hx := half_x - WALL_DEDUP_EPS
	var hz := half_z - WALL_DEDUP_EPS
	# North (+Z), South (-Z): wall runs along X, length = size.x
	_build_wall_with_gaps(parent, center + Vector3(0, 0, hz), size.x, "x", wall_color, side_openings["north"], wbit)
	_build_wall_with_gaps(parent, center + Vector3(0, 0, -hz), size.x, "x", wall_color, side_openings["south"], wbit)
	# East (+X), West (-X): wall runs along Z, length = size.z
	_build_wall_with_gaps(parent, center + Vector3(hx, 0, 0), size.z, "z", wall_color, side_openings["east"], wbit)
	_build_wall_with_gaps(parent, center + Vector3(-hx, 0, 0), size.z, "z", wall_color, side_openings["west"], wbit)


func _build_wall_with_gaps(parent: Node3D, wall_center: Vector3, wall_length: float, axis: String, color: Color, openings: Array, wbit: int = 1) -> void:
	if openings.is_empty():
		var seg_size: Vector3
		if axis == "x":
			seg_size = Vector3(wall_length, WALL_HEIGHT, WALL_THICKNESS)
		else:
			seg_size = Vector3(WALL_THICKNESS, WALL_HEIGHT, wall_length)
		_add_wall_segment(parent, wall_center + Vector3(0, WALL_HEIGHT * 0.5, 0), seg_size, color, wbit)
		return

	var sorted_openings: Array = openings.duplicate()
	sorted_openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["pos_along"]) < float(b["pos_along"]))

	var half_len := wall_length * 0.5
	var cursor: float = -half_len

	for opening in sorted_openings:
		var gap_center: float = float(opening["pos_along"])
		var gap_half: float = float(opening["width"]) * 0.5
		var gap_start: float = gap_center - gap_half
		var gap_end: float = gap_center + gap_half

		if gap_start - cursor > 0.1:
			_add_wall_along(parent, wall_center, cursor, gap_start, axis, color, wbit)
		cursor = gap_end

	if half_len - cursor > 0.1:
		_add_wall_along(parent, wall_center, cursor, half_len, axis, color, wbit)


func _add_wall_along(parent: Node3D, wall_center: Vector3, from_along: float, to_along: float, axis: String, color: Color, wbit: int = 1) -> void:
	var seg_len: float = to_along - from_along
	var seg_mid: float = (from_along + to_along) * 0.5
	var pos: Vector3
	var seg_size: Vector3

	if axis == "x":
		pos = wall_center + Vector3(seg_mid, WALL_HEIGHT * 0.5, 0)
		seg_size = Vector3(seg_len, WALL_HEIGHT, WALL_THICKNESS)
	else:
		pos = wall_center + Vector3(0, WALL_HEIGHT * 0.5, seg_mid)
		seg_size = Vector3(WALL_THICKNESS, WALL_HEIGHT, seg_len)

	_add_wall_segment(parent, pos, seg_size, color, wbit)


func _add_wall_segment(parent: Node3D, pos: Vector3, size: Vector3, color: Color, wbit: int = 1) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = wbit

	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	body.add_child(col_shape)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mesh.material_override = mat
	body.add_child(mesh)

	parent.add_child(body)


## 장애물 배치 = rooms.json `anchors.obstacles`(구 OBSTACLE_SPECS). 치수는 킷(OBSTACLE_TYPES)이,
## **어디에 놓을지는 데이터**가 소유한다 — 방을 고칠 때 코드를 안 고치기 위한 분리.
func _build_obstacles(parent: Node3D, room_ref: String, center: Vector3, wbit: int = 1) -> void:
	for obs in get_anchors(room_ref, "obstacles"):
		var t: Dictionary = OBSTACLE_TYPES.get(obs.get("type", ""), {})
		if t.is_empty():
			continue
		var ap: Vector3 = obs["pos"]
		var ground := Vector3(ap.x, center.y, ap.z)
		var mesh: Mesh
		var shape: Shape3D
		var height: float
		if String(t.get("shape", "box")) == "cyl":
			var r: float = float(t["radius"])
			height = float(t["height"])
			var cyl := CylinderMesh.new()
			cyl.top_radius = r
			cyl.bottom_radius = r
			cyl.height = height
			mesh = cyl
			var cshape := CylinderShape3D.new()
			cshape.radius = r
			cshape.height = height
			shape = cshape
		else:
			var size: Vector3 = t["size"]
			height = size.y
			var box := BoxMesh.new()
			box.size = size
			mesh = box
			var bshape := BoxShape3D.new()
			bshape.size = size
			shape = bshape
		_add_obstacle_body(parent, ground + Vector3(0, height * 0.5, 0), mesh, shape, t["color"], wbit)


## StaticBody(layer 1) + mesh — LOS-blocks (raycast mask 1) and navmesh-bakes.
func _add_obstacle_body(parent: Node3D, pos: Vector3, mesh: Mesh, shape: Shape3D, color: Color, wbit: int = 1) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = wbit
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)

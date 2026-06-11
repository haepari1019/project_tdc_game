extends Node3D
## MAP-DEMO-001 placeholder — 6 rooms, shared-wall connections with arch openings.
## Layout matches 단면도.png (52m × 76m footprint). ref: WORK_ORDER §MAP scope

signal room_entered(room_ref: String)

## Room centers placed so adjacent rooms share wall edges directly.
## Z+ = north (forward in 단면도). ×1.5 scale from 단면도 for better character-to-map ratio.
## Original 단면도 52×76m → actual ~78×114m footprint.
const ROOM_SPECS: Dictionary = {
	"RM-ENTRY-01": {
		"center": Vector3(0, 0, 0),
		"size": Vector3(27, 0, 22.5),
		"profile": "lit",
		"label": "Ward Threshold",
	},
	"RM-ADV-01": {
		"center": Vector3(0, 0, 32.25),
		"size": Vector3(42, 0, 42),
		"profile": "lit",
		"label": "Open Combat Court",
	},
	"RM-OBJ-01": {
		"center": Vector3(-33, 0, 41.25),
		"size": Vector3(24, 0, 24),
		"profile": "dim",
		"label": "Dim Reliquary",
	},
	"RM-ADV-02": {
		"center": Vector3(27, 0, 45.75),
		"size": Vector3(12, 0, 27),
		"profile": "standard",
		"label": "East Passage",
	},
	"RM-ROUTE-01": {
		"center": Vector3(27, 0, 68.25),
		"size": Vector3(6, 0, 18),
		"profile": "standard",
		"label": "North Corridor",
	},
	"RM-EXT-01": {
		"center": Vector3(27, 0, 83.25),
		"size": Vector3(18, 0, 12),
		"profile": "lit",
		"extraction": true,
		"label": "Extraction Landing",
	},
}

## Connections: rooms share wall edges — only arch openings needed, no corridors.
## [room_a, room_b, opening_width]
const CONNECTIONS: Array = [
	["RM-ENTRY-01", "RM-ADV-01", 8.0],
	["RM-ADV-01", "RM-OBJ-01", 8.0],
	["RM-ADV-01", "RM-ADV-02", 8.0],
	["RM-ADV-02", "RM-ROUTE-01", 6.0],
	["RM-ROUTE-01", "RM-EXT-01", 6.0],
]

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
## 픽스처 1개가 담당하는 대략적 그리드 셀 크기(m). 길쭉한/큰 방은 여러 개로 분할
## 해 중앙 falloff로 양끝이 희미해지는 현상을 막는다.
const LIGHT_GRID_SPACING := 18.0

const WALL_HEIGHT := 3.5
const WALL_THICKNESS := 0.4
const FLOOR_THICKNESS := 0.3

## Cover obstacles — LOS blockers + navmesh holes (units route around). Heights
## clear the party→enemy LOS ray so enemies behind them are occluded. F-011 pre-step.
const OBSTACLE_TYPES: Dictionary = {
	"pillar":  {"shape": "cyl", "radius": 2.0, "height": WALL_HEIGHT, "color": Color(0.30, 0.28, 0.26)},
	"crates":  {"shape": "box", "size": Vector3(5.0, 2.4, 5.0), "color": Color(0.42, 0.32, 0.18)},
	"barrier": {"shape": "box", "size": Vector3(8.0, 2.4, 1.6), "color": Color(0.34, 0.30, 0.27)},
}
## Per-room placement: pos = Vector2(local_x, local_z) from room center (ground).
## Kept off openings / spawn cluster / PASS lane. Tunable.
const OBSTACLE_SPECS: Dictionary = {
	"RM-ADV-01": [
		{"type": "pillar",  "pos": Vector2(-9, 2)},
		{"type": "crates",  "pos": Vector2(10, -5)},
		{"type": "barrier", "pos": Vector2(-2, 12)},
		{"type": "pillar",  "pos": Vector2(-7, -11)},
		{"type": "crates",  "pos": Vector2(8, 9)},
	],
	"RM-OBJ-01": [
		{"type": "crates",  "pos": Vector2(-4, 2)},
		{"type": "pillar",  "pos": Vector2(6, -4)},
	],
}

@onready var _rooms_root: Node3D = $Rooms
@onready var _markers_root: Node3D = $Markers

var _room_areas: Dictionary = {}
## Per-room openings: room_ref -> Array of {side, pos_along, width}
var _room_openings: Dictionary = {}
var _nav_region: NavigationRegion3D
## Data-driven interface table (decouples the map *contract* from how geometry is
## made). room_ref -> {spawn: Vector3, size: Vector3}; + the extraction point. The
## getters below read THIS, not ROOM_SPECS — so a real (Blender) map only has to
## populate it (override _resolve_room_points / author markers) to reuse all callers.
var _room_points: Dictionary = {}
var _extraction_point: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("navmap")  # fatal zones call rebake_navigation on this group when they carve
	_resolve_room_points()
	_compute_openings()
	_build_map()
	_bake_navigation()


# ============================================================================
# Map contract (interface) — read by combat/run/party. A real (Blender) map only
# needs to satisfy THIS + collision layer 1 (walls, for LOS) + a baked
# NavigationRegion3D + room Area3D triggers emitting `room_entered`. ref: ARCHITECTURE.
# Geometry source is decoupled: getters read `_room_points` / rooms.json, not the
# procedural ROOM_SPECS — so swapping the placeholder geometry touches no callers.
# ============================================================================

## lighting_profile of a room (lit/standard/dim/unlit). SSOT = `rooms.json`
## (`Slice01Data`); ROOM_SPECS.profile is a build-time fallback only. F-011 §3.1.
func get_room_profile(room_ref: String) -> String:
	return _room_profile(room_ref)


func get_spawn_position(room_ref: String = "RM-ENTRY-01") -> Vector3:
	# Floor top is y=0; units use a feet-on-origin convention (tiny y epsilon baked in).
	var p: Dictionary = _room_points.get(room_ref, {})
	return p.get("spawn", Vector3(0, 0.02, 0))


## A spawn point pushed toward the room's FAR interior, away from `away_from` (the
## party's approach). Keeps enemies out of the start sightline/combat range until
## the party advances in. Clamped inside the room with margin for spawn scatter.
func get_deep_spawn_position(room_ref: String, away_from: Vector3) -> Vector3:
	const MARGIN := 11.0  # reserve room for the spawn scatter ring + unit/wall size
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
	var t := minf(tx, tz)
	return center + dir * t


## POINT-DEMO-01 extraction point (ground).
func get_extraction_position() -> Vector3:
	return _extraction_point


## Each room's footprint for the minimap: [{center: Vector3, size: Vector3}] (XZ used).
## Reads the decoupled _room_points interface, so a Blender map reuses it unchanged.
func get_room_rects() -> Array:
	var out: Array = []
	for ref in _room_points:
		var p: Dictionary = _room_points[ref]
		out.append({"center": p["spawn"], "size": p["size"]})
	return out


# --- Interface backing (placeholder = ROOM_SPECS; a Blender map overrides) -------

## Room lighting profile — `rooms.json` (SSOT) first, ROOM_SPECS fallback. De-dups
## the previous double-ownership (ARCHITECTURE DEBT-DM3).
func _room_profile(room_ref: String) -> String:
	var row: Dictionary = Slice01Data.get_room_row(room_ref)
	if not row.is_empty() and row.has("lighting_profile"):
		return String(row.get("lighting_profile", "standard"))
	return String((ROOM_SPECS.get(room_ref, {}) as Dictionary).get("profile", "standard"))


## Populate the runtime room-points table + extraction point. Placeholder derives
## from ROOM_SPECS geometry. A real (Blender) map replaces this — e.g. read authored
## Marker3D points per room_ref — and every getter above keeps working unchanged.
func _resolve_room_points() -> void:
	_room_points.clear()
	for room_ref in ROOM_SPECS.keys():
		var spec: Dictionary = ROOM_SPECS[room_ref]
		var center: Vector3 = spec.get("center", Vector3.ZERO)
		_room_points[String(room_ref)] = {
			"spawn": center + Vector3(0, 0.02, 0),
			"size": spec.get("size", Vector3(8, 0, 8)),
		}
		if spec.get("extraction", false):
			_extraction_point = Vector3(center.x, 0.0, center.z)


func _compute_openings() -> void:
	for room_ref in ROOM_SPECS.keys():
		_room_openings[room_ref] = []

	for conn in CONNECTIONS:
		var ref_a: String = conn[0]
		var ref_b: String = conn[1]
		var width: float = conn[2]
		var ca: Vector3 = ROOM_SPECS[ref_a]["center"]
		var cb: Vector3 = ROOM_SPECS[ref_b]["center"]
		var sa: Vector3 = ROOM_SPECS[ref_a]["size"]
		var sb: Vector3 = ROOM_SPECS[ref_b]["size"]
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
	for room_ref in ROOM_SPECS.keys():
		_build_room(String(room_ref))


func _build_room(room_ref: String) -> void:
	var spec: Dictionary = ROOM_SPECS[room_ref]
	var center: Vector3 = spec["center"]
	var size: Vector3 = spec["size"]
	var profile: String = _room_profile(room_ref)  # SSOT = rooms.json

	var room_node := Node3D.new()
	room_node.name = room_ref
	_rooms_root.add_child(room_node)

	var col: Color = PROFILE_COLORS.get(profile, Color.GRAY)
	if spec.get("extraction", false):
		col = Color(0.25, 0.55, 0.35)

	# Floor
	_add_floor(room_node, center, size, col)

	# Walls with openings
	var openings: Array = _room_openings.get(room_ref, [])
	_add_walls_with_openings(room_node, center, size, col, openings)

	# Lighting option objects (per-room fixtures keyed by profile)
	_add_room_lighting(room_node, center, size, profile)

	# Cover obstacles — LOS blockers + navmesh holes (baked with the room)
	_build_obstacles(room_node, room_ref, center)

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
	var room_label: String = spec.get("label", room_ref)
	var label := Label3D.new()
	label.text = "%s\n%s" % [room_ref, room_label]
	label.position = center + Vector3(0, 3.2, 0)
	label.font_size = 36
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


## Places ceiling light fixtures for one room based on its lighting_profile.
## Big rooms get a grid of fixtures so corners aren't left dark; small rooms get
## a single central light. Fixtures are shadowless (cheap) — the party torch
## carries the dramatic shadows. profile "unlit" (energy 0) places nothing.
func _add_room_lighting(parent: Node3D, center: Vector3, size: Vector3, profile: String) -> void:
	var prof: Dictionary = LIGHT_PROFILES.get(profile, LIGHT_PROFILES["standard"])
	var energy: float = float(prof["energy"])
	if energy <= 0.0:
		return

	var count_x: int = maxi(1, int(round(size.x / LIGHT_GRID_SPACING)))
	var count_z: int = maxi(1, int(round(size.z / LIGHT_GRID_SPACING)))
	var cell_x: float = size.x / float(count_x)
	var cell_z: float = size.z / float(count_z)
	var light_y: float = WALL_HEIGHT * 0.86
	var fixture_range: float = clampf(maxf(cell_x, cell_z) * float(prof["range_scale"]) + 4.0, 7.0, 28.0)

	var fixtures := Node3D.new()
	fixtures.name = "Lighting"
	parent.add_child(fixtures)

	for ix in count_x:
		for iz in count_z:
			var lx: float = -size.x * 0.5 + cell_x * (float(ix) + 0.5)
			var lz: float = -size.z * 0.5 + cell_z * (float(iz) + 0.5)
			var omni := OmniLight3D.new()
			omni.position = center + Vector3(lx, light_y, lz)
			omni.omni_range = fixture_range
			omni.omni_attenuation = 1.0  # 완만한 falloff → 방 전체 고른 밝기
			omni.light_energy = energy
			omni.light_color = prof["color"]
			omni.shadow_enabled = false
			fixtures.add_child(omni)


func _add_floor(parent: Node3D, center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "FloorBody"
	body.position = center + Vector3(0, -FLOOR_THICKNESS * 0.5, 0)
	body.collision_layer = 1

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


func _add_walls_with_openings(parent: Node3D, center: Vector3, size: Vector3, base_color: Color, openings: Array) -> void:
	var wall_color := base_color.darkened(0.25)
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5

	var side_openings: Dictionary = {"north": [], "south": [], "east": [], "west": []}
	for opening in openings:
		var side: String = opening["side"]
		side_openings[side].append(opening)

	# North (+Z), South (-Z): wall runs along X, length = size.x
	_build_wall_with_gaps(parent, center + Vector3(0, 0, half_z), size.x, "x", wall_color, side_openings["north"])
	_build_wall_with_gaps(parent, center + Vector3(0, 0, -half_z), size.x, "x", wall_color, side_openings["south"])
	# East (+X), West (-X): wall runs along Z, length = size.z
	_build_wall_with_gaps(parent, center + Vector3(half_x, 0, 0), size.z, "z", wall_color, side_openings["east"])
	_build_wall_with_gaps(parent, center + Vector3(-half_x, 0, 0), size.z, "z", wall_color, side_openings["west"])


func _build_wall_with_gaps(parent: Node3D, wall_center: Vector3, wall_length: float, axis: String, color: Color, openings: Array) -> void:
	if openings.is_empty():
		var seg_size: Vector3
		if axis == "x":
			seg_size = Vector3(wall_length, WALL_HEIGHT, WALL_THICKNESS)
		else:
			seg_size = Vector3(WALL_THICKNESS, WALL_HEIGHT, wall_length)
		_add_wall_segment(parent, wall_center + Vector3(0, WALL_HEIGHT * 0.5, 0), seg_size, color)
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
			_add_wall_along(parent, wall_center, cursor, gap_start, axis, color)
		cursor = gap_end

	if half_len - cursor > 0.1:
		_add_wall_along(parent, wall_center, cursor, half_len, axis, color)


func _add_wall_along(parent: Node3D, wall_center: Vector3, from_along: float, to_along: float, axis: String, color: Color) -> void:
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

	_add_wall_segment(parent, pos, seg_size, color)


func _add_wall_segment(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1

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


func _build_obstacles(parent: Node3D, room_ref: String, center: Vector3) -> void:
	for obs in OBSTACLE_SPECS.get(room_ref, []):
		var t: Dictionary = OBSTACLE_TYPES.get(obs.get("type", ""), {})
		if t.is_empty():
			continue
		var p: Vector2 = obs["pos"]
		var ground := center + Vector3(p.x, 0.0, p.y)
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
		_add_obstacle_body(parent, ground + Vector3(0, height * 0.5, 0), mesh, shape, t["color"])


## StaticBody(layer 1) + mesh — LOS-blocks (raycast mask 1) and navmesh-bakes.
func _add_obstacle_body(parent: Node3D, pos: Vector3, mesh: Mesh, shape: Shape3D, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
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


func _bake_navigation() -> void:
	if _nav_region == null:
		_nav_region = NavigationRegion3D.new()
		_nav_region.name = "NavRegion"
		add_child(_nav_region)
	var navmesh := NavigationMesh.new()
	navmesh.agent_radius = 0.4
	navmesh.agent_height = 1.2
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.2
	navmesh.agent_max_climb = 0.3
	navmesh.agent_max_slope = 45.0
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	# Parse geometry from the Rooms subtree directly via NavigationServer3D
	var source_geo := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source_geo, _rooms_root)
	# Carve active fatal zones so navigation routes AROUND them (impassable, like walls).
	for z in get_tree().get_nodes_in_group("fatal_zone"):
		if z.is_active():
			_carve_zone(source_geo, z.global_position, float(z.radius))
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source_geo)
	_nav_region.navigation_mesh = navmesh
	print("[MAP] NavMesh baked: %d polygons" % navmesh.get_polygon_count())


## Re-bake the navmesh (e.g. when a fatal zone spawns/clears) so pathing reflects it.
func rebake_navigation() -> void:
	_bake_navigation()


## Carve a circular impassable column into the nav source geometry (fatal zone = wall),
## so map_get_path routes around it (or finds no path when it severs a corridor).
func _carve_zone(geo: NavigationMeshSourceGeometryData3D, center: Vector3, radius: float) -> void:
	var verts := PackedVector3Array()
	var segs := 14
	for i in segs:
		var a := float(i) * TAU / float(segs)
		verts.append(Vector3(center.x + cos(a) * radius, 0.0, center.z + sin(a) * radius))
	geo.add_projected_obstruction(verts, -1.0, 4.0, true)  # elevation, height, carve=true


func _on_body_entered(body: Node3D, room_ref: String) -> void:
	if not body.is_in_group("player"):
		return
	room_entered.emit(room_ref)

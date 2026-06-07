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

const WALL_HEIGHT := 3.5
const WALL_THICKNESS := 0.4
const FLOOR_THICKNESS := 0.3

@onready var _rooms_root: Node3D = $Rooms
@onready var _markers_root: Node3D = $Markers

var _room_areas: Dictionary = {}
## Per-room openings: room_ref -> Array of {side, pos_along, width}
var _room_openings: Dictionary = {}
var _nav_region: NavigationRegion3D


func _ready() -> void:
	_compute_openings()
	_build_map()
	_bake_navigation()


func get_spawn_position(room_ref: String = "RM-ENTRY-01") -> Vector3:
	# Floor top is y=0; units use a feet-on-origin convention, so spawn at ground
	# (tiny epsilon avoids initial floor penetration).
	var spec: Dictionary = ROOM_SPECS.get(room_ref, {})
	var center: Vector3 = spec.get("center", Vector3.ZERO)
	return center + Vector3(0, 0.02, 0)


## POINT-DEMO-01 extraction point (RM-EXT-01 center, ground).
func get_extraction_position() -> Vector3:
	var spec: Dictionary = ROOM_SPECS.get("RM-EXT-01", {})
	var center: Vector3 = spec.get("center", Vector3.ZERO)
	return Vector3(center.x, 0.0, center.z)


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
	var profile: String = spec.get("profile", "standard")

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


func _bake_navigation() -> void:
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
	_nav_region.navigation_mesh = navmesh
	# Parse geometry from the Rooms subtree directly via NavigationServer3D
	var source_geo := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source_geo, _rooms_root)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source_geo)
	_nav_region.navigation_mesh = navmesh
	print("[MAP] NavMesh baked: %d polygons" % navmesh.get_polygon_count())


func _on_body_entered(body: Node3D, room_ref: String) -> void:
	if not body.is_in_group("player"):
		return
	room_entered.emit(room_ref)

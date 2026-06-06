extends Node3D
## MAP-DEMO-001 placeholder — 6 rooms with floors, walls, corridors. ref: WORK_ORDER §MAP scope

signal room_entered(room_ref: String)

const ROOM_SPECS: Dictionary = {
	"RM-ENTRY-01": {
		"center": Vector3(0, 0, 0),
		"size": Vector3(14, 0, 10),
		"profile": "lit",
	},
	"RM-ADV-01": {
		"center": Vector3(0, 0, 22),
		"size": Vector3(24, 0, 24),
		"profile": "lit",
	},
	"RM-ADV-02": {
		"center": Vector3(18, 0, 42),
		"size": Vector3(6, 0, 14),
		"profile": "standard",
	},
	"RM-OBJ-01": {
		"center": Vector3(-18, 0, 42),
		"size": Vector3(12, 0, 12),
		"profile": "dim",
	},
	"RM-ROUTE-01": {
		"center": Vector3(18, 0, 58),
		"size": Vector3(6, 0, 10),
		"profile": "standard",
	},
	"RM-EXT-01": {
		"center": Vector3(18, 0, 70),
		"size": Vector3(12, 0, 10),
		"profile": "lit",
		"extraction": true,
	},
}

## Corridors: connect rooms with walkable passages
const CORRIDORS: Array = [
	# [from_room, to_room, width]
	["RM-ENTRY-01", "RM-ADV-01", 5.0],
	["RM-ADV-01", "RM-ADV-02", 5.0],
	["RM-ADV-01", "RM-OBJ-01", 5.0],
	["RM-ADV-02", "RM-ROUTE-01", 5.0],
	["RM-ROUTE-01", "RM-EXT-01", 5.0],
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


func _ready() -> void:
	_build_map()


func get_spawn_position(room_ref: String = "RM-ENTRY-01") -> Vector3:
	var spec: Dictionary = ROOM_SPECS.get(room_ref, {})
	var center: Vector3 = spec.get("center", Vector3.ZERO)
	return center + Vector3(0, 1.0, 0)


func _build_map() -> void:
	for room_ref in ROOM_SPECS.keys():
		_build_room(String(room_ref))
	for corridor in CORRIDORS:
		_build_corridor(String(corridor[0]), String(corridor[1]), float(corridor[2]))


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

	# Floor (static body for collision)
	_add_floor(room_node, center, size, col)

	# Walls (4 sides)
	_add_walls(room_node, center, size, col)

	# Room trigger volume
	var area := Area3D.new()
	area.name = "RoomVolume"
	area.position = center
	area.collision_layer = 0
	area.collision_mask = 2  # detect party layer
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
	var label := Label3D.new()
	label.text = room_ref
	label.position = center + Vector3(0, 3.0, 0)
	label.font_size = 42
	label.modulate = Color(1, 1, 1, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_markers_root.add_child(label)

	# Extraction marker
	if room_ref == "RM-EXT-01":
		var ext := MeshInstance3D.new()
		ext.name = "POINT-DEMO-01"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.2
		cyl.height = 0.15
		ext.mesh = cyl
		ext.position = center + Vector3(0, 0.08, 0)
		var ext_mat := StandardMaterial3D.new()
		ext_mat.albedo_color = Color(0.2, 0.85, 0.4, 0.8)
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


func _add_walls(parent: Node3D, center: Vector3, size: Vector3, base_color: Color) -> void:
	var wall_color := base_color.darkened(0.25)
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5

	# North wall (positive Z)
	_add_wall_segment(parent, center + Vector3(0, WALL_HEIGHT * 0.5, half_z), Vector3(size.x, WALL_HEIGHT, WALL_THICKNESS), wall_color)
	# South wall (negative Z)
	_add_wall_segment(parent, center + Vector3(0, WALL_HEIGHT * 0.5, -half_z), Vector3(size.x, WALL_HEIGHT, WALL_THICKNESS), wall_color)
	# East wall (positive X)
	_add_wall_segment(parent, center + Vector3(half_x, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, size.z), wall_color)
	# West wall (negative X)
	_add_wall_segment(parent, center + Vector3(-half_x, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, size.z), wall_color)


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


func _build_corridor(from_ref: String, to_ref: String, width: float) -> void:
	var from_spec: Dictionary = ROOM_SPECS.get(from_ref, {})
	var to_spec: Dictionary = ROOM_SPECS.get(to_ref, {})
	if from_spec.is_empty() or to_spec.is_empty():
		return

	var from_center: Vector3 = from_spec["center"]
	var to_center: Vector3 = to_spec["center"]
	var mid := (from_center + to_center) * 0.5

	# Calculate corridor dimensions between room edges
	var from_size: Vector3 = from_spec["size"]
	var to_size: Vector3 = to_spec["size"]

	var diff := to_center - from_center
	var corridor_length: float
	var corridor_size: Vector3
	var corridor_pos: Vector3

	if absf(diff.x) > absf(diff.z):
		# Horizontal corridor
		var from_edge := from_center.x + sign(diff.x) * from_size.x * 0.5
		var to_edge := to_center.x - sign(diff.x) * to_size.x * 0.5
		corridor_length = absf(to_edge - from_edge)
		corridor_pos = Vector3((from_edge + to_edge) * 0.5, 0, from_center.z + diff.z * 0.5)
		corridor_size = Vector3(corridor_length, 0, width)
	else:
		# Vertical corridor
		var from_edge := from_center.z + sign(diff.z) * from_size.z * 0.5
		var to_edge := to_center.z - sign(diff.z) * to_size.z * 0.5
		corridor_length = absf(to_edge - from_edge)
		corridor_pos = Vector3(from_center.x + diff.x * 0.5, 0, (from_edge + to_edge) * 0.5)
		corridor_size = Vector3(width, 0, corridor_length)

	if corridor_length < 0.5:
		return

	var corridor_node := Node3D.new()
	corridor_node.name = "Corridor_%s_%s" % [from_ref, to_ref]
	_rooms_root.add_child(corridor_node)

	var col := PROFILE_COLORS["standard"].lightened(0.05)
	_add_floor(corridor_node, corridor_pos, corridor_size, col)

	# Corridor walls (along the length)
	var wall_color := col.darkened(0.25)
	var half_w := width * 0.5
	if corridor_size.x > corridor_size.z:
		# Horizontal: walls on north/south
		_add_wall_segment(corridor_node, corridor_pos + Vector3(0, WALL_HEIGHT * 0.5, half_w), Vector3(corridor_size.x, WALL_HEIGHT, WALL_THICKNESS), wall_color)
		_add_wall_segment(corridor_node, corridor_pos + Vector3(0, WALL_HEIGHT * 0.5, -half_w), Vector3(corridor_size.x, WALL_HEIGHT, WALL_THICKNESS), wall_color)
	else:
		# Vertical: walls on east/west
		_add_wall_segment(corridor_node, corridor_pos + Vector3(half_w, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, corridor_size.z), wall_color)
		_add_wall_segment(corridor_node, corridor_pos + Vector3(-half_w, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, corridor_size.z), wall_color)


func _on_body_entered(body: Node3D, room_ref: String) -> void:
	if not body.is_in_group("player"):
		return
	room_entered.emit(room_ref)

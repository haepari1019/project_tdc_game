extends Node3D
## MAP-DEMO-001 placeholder boxes — WORK_ORDER MAP scope (1u = 1m).

signal room_entered(room_ref: String)

const ROOM_SPECS: Dictionary = {
	"RM-ENTRY-01": {
		"center": Vector3(0, 0, 0),
		"size": Vector3(14, 0.3, 10),
		"profile": "lit",
	},
	"RM-ADV-01": {
		"center": Vector3(0, 0, 22),
		"size": Vector3(24, 0.3, 24),
		"profile": "lit",
	},
	"RM-ADV-02": {
		"center": Vector3(20, 0, 40),
		"size": Vector3(6, 0.3, 16),
		"profile": "standard",
	},
	"RM-OBJ-01": {
		"center": Vector3(-20, 0, 40),
		"size": Vector3(12, 0.3, 12),
		"profile": "dim",
	},
	"RM-ROUTE-01": {
		"center": Vector3(20, 0, 56),
		"size": Vector3(6, 0.3, 12),
		"profile": "standard",
	},
	"RM-EXT-01": {
		"center": Vector3(20, 0, 68),
		"size": Vector3(12, 0.3, 10),
		"profile": "lit",
		"extraction": true,
	},
}

const PROFILE_COLORS: Dictionary = {
	"lit": Color(0.55, 0.58, 0.62),
	"standard": Color(0.42, 0.45, 0.48),
	"dim": Color(0.28, 0.30, 0.38),
}

@onready var _rooms_root: Node3D = $Rooms
@onready var _markers_root: Node3D = $Markers

var _room_areas: Dictionary = {}


func _ready() -> void:
	_build_map()


func get_spawn_position(room_ref: String = "RM-ENTRY-01") -> Vector3:
	var spec: Dictionary = ROOM_SPECS.get(room_ref, {})
	var center: Vector3 = spec.get("center", Vector3.ZERO)
	return center + Vector3(0, 1.2, 0)


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

	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	var box := BoxMesh.new()
	box.size = size
	floor.mesh = box
	floor.position = center + Vector3(0, -0.15, 0)
	var mat := StandardMaterial3D.new()
	var col: Color = PROFILE_COLORS.get(profile, Color.GRAY)
	if spec.get("extraction", false):
		col = Color(0.35, 0.75, 0.45)
	mat.albedo_color = col
	floor.material_override = mat
	room_node.add_child(floor)

	var area := Area3D.new()
	area.name = "RoomVolume"
	area.position = center
	area.collision_layer = 0
	area.collision_mask = 1
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

	var label := Label3D.new()
	label.text = room_ref
	label.position = center + Vector3(0, 2.5, 0)
	label.font_size = 48
	label.modulate = Color(1, 1, 1, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_markers_root.add_child(label)

	if room_ref == "RM-EXT-01":
		var ext := MeshInstance3D.new()
		ext.name = "POINT-DEMO-01"
		var pillar := BoxMesh.new()
		pillar.size = Vector3(1.5, 3, 1.5)
		ext.mesh = pillar
		ext.position = center + Vector3(0, 1.5, 0)
		var ext_mat := StandardMaterial3D.new()
		ext_mat.albedo_color = Color(0.2, 0.95, 0.5)
		ext.material_override = ext_mat
		_markers_root.add_child(ext)


func _on_body_entered(body: Node3D, room_ref: String) -> void:
	if not body.is_in_group("player"):
		return
	room_entered.emit(room_ref)

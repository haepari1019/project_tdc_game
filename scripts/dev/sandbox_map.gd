extends Node3D
## DEBUG one-room arena for the combat sandbox (scenes/dev/combat_sandbox). Floor + walls
## (collision layer 1, for LOS) + a baked NavigationRegion3D + lighting. Implements the tiny
## map contract CombatController needs (get_spawn_position / get_deep_spawn_position). NOT part
## of the real dungeon — dev tooling only. ref: scripts/dev/combat_sandbox.gd.

@warning_ignore("unused_signal")  # contract parity with the real map interface (intentionally unused here)
signal room_entered(room_ref: String)

const ROOM_SIZE := Vector3(48, 0, 48)
const WALL_H := 3.5
const WALL_T := 0.4
const FLOOR_T := 0.3
const PARTY_SPAWN := Vector3(0, 0.02, -17)   # south edge — party
const DEEP_SPAWN := Vector3(0, 0.02, 13)     # north interior — enemies (away from party)

var _rooms: Node3D
var _nav: NavigationRegion3D


func _ready() -> void:
	add_to_group("navmap")  # rebake hook parity
	_rooms = Node3D.new()
	_rooms.name = "Rooms"
	add_child(_rooms)
	_build_floor()
	_build_walls()
	_build_lighting()
	_bake_nav()


# --- map contract (read by CombatController) ---
func get_spawn_position(_room_ref: String = "SANDBOX") -> Vector3:
	return PARTY_SPAWN


func get_deep_spawn_position(_room_ref: String = "SANDBOX", _away_from: Vector3 = Vector3.ZERO) -> Vector3:
	return DEEP_SPAWN


func get_extraction_position() -> Vector3:
	return PARTY_SPAWN


func rebake_navigation() -> void:
	_bake_nav()


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, -FLOOR_T * 0.5, 0)
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(ROOM_SIZE.x, FLOOR_T, ROOM_SIZE.z)
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.30, 0.28)
	mat.roughness = 0.85
	mi.material_override = mat
	body.add_child(mi)
	_rooms.add_child(body)


func _build_walls() -> void:
	var hx := ROOM_SIZE.x * 0.5
	var hz := ROOM_SIZE.z * 0.5
	_wall(Vector3(0, WALL_H * 0.5, hz), Vector3(ROOM_SIZE.x, WALL_H, WALL_T))    # north
	_wall(Vector3(0, WALL_H * 0.5, -hz), Vector3(ROOM_SIZE.x, WALL_H, WALL_T))   # south
	_wall(Vector3(hx, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, ROOM_SIZE.z))    # east
	_wall(Vector3(-hx, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, ROOM_SIZE.z))   # west


func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.21, 0.24)
	mi.material_override = mat
	body.add_child(mi)
	_rooms.add_child(body)


func _build_lighting() -> void:
	# Sparse omni fixtures so the colored unit meshes read clearly (no dungeon fog here).
	for gx in [-12.0, 12.0]:
		for gz in [-12.0, 12.0]:
			var l := OmniLight3D.new()
			l.position = Vector3(gx, 6.0, gz)
			l.omni_range = 26.0
			l.light_energy = 2.0
			l.light_color = Color(1.0, 0.95, 0.85)
			add_child(l)


func _bake_nav() -> void:
	if _nav == null:
		_nav = NavigationRegion3D.new()
		_nav.name = "NavRegion"
		add_child(_nav)
	var navmesh := NavigationMesh.new()
	navmesh.agent_radius = 0.5      # 2× cell_size — matches the baker's ceil (no precision warning)
	navmesh.agent_height = 1.25     # 5× cell_height — matches the baker's ceil (no precision warning)
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25      # match the navigation map cell_height (no rasterization mismatch)
	navmesh.agent_max_climb = 0.25  # 1× cell_height — matches the baker's floor (no precision warning)
	navmesh.agent_max_slope = 45.0
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var geo := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, geo, _rooms)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, geo)
	_nav.navigation_mesh = navmesh
	print("[SANDBOX] NavMesh baked: %d polygons" % navmesh.get_polygon_count())

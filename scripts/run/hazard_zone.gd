extends Node3D
## Fatal hazard zone — a persistent ground area that ticks lethal damage to ANY unit
## (party or enemy) standing in it (피아무구분, F-021). Spawned by a Trap; cleared by a
## Lever (reset). Party AI treats an active zone as do-not-cross (F-004 Fatal avoidance),
## so a zone across a chokepoint splits the party. ref: F-006 hazard severity / F-021 ZONE.
##
## Registered in group "fatal_zone"; query via `contains_point()` / `blocks_segment()`.

const TICK_S := 0.2
const UNIT_GROUPS := ["party_member", "enemy"]

var radius: float = 3.0
var dps: float = 90.0          # fatal tier — lethal in ~1-2s of standing in it
var _telegraph_s: float = 0.0  # warning phase: in group (avoidance) but non-lethal
var _lethal: bool = true
var _active: bool = true
var _tick_accum: float = 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


func setup(p_radius: float, p_dps: float, p_telegraph_s: float = 0.0) -> void:
	radius = p_radius
	dps = p_dps
	_telegraph_s = p_telegraph_s


func _ready() -> void:
	add_to_group("fatal_zone")  # in group from spawn so party AI avoids/flees during telegraph
	if _telegraph_s > 0.0:
		_lethal = false
		get_tree().create_timer(_telegraph_s).timeout.connect(_go_lethal)
	_build()
	get_tree().call_group("navmap", "rebake_navigation")  # carve this zone into the navmesh


func _go_lethal() -> void:
	_lethal = true
	if _mat:
		_mat.albedo_color = Color(0.95, 0.18, 0.12, 0.5)
		_mat.emission = Color(0.95, 0.22, 0.10)


func is_active() -> bool:
	return _active


## Is a world point inside the zone (horizontal disc)? Used by damage + party avoidance.
func contains_point(p: Vector3, pad: float = 0.0) -> bool:
	if not _active:
		return false
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	return d.length() <= radius + pad


## Does the segment a→b pass through the zone (with padding)? Used by follower avoidance
## so a member won't path *across* a fatal zone to rejoin.
func blocks_segment(a: Vector3, b: Vector3, pad: float = 0.6) -> bool:
	if not _active:
		return false
	var c := Vector2(global_position.x, global_position.z)
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	var pq := q - p
	var l2 := pq.length_squared()
	var nearest: Vector2 = p if l2 < 0.0001 else p + pq * clampf((c - p).dot(pq) / l2, 0.0, 1.0)
	return (c - nearest).length() <= radius + pad


## Lever reset — fade out and free, re-opening the path.
func clear_zone() -> void:
	if not _active:
		return
	_active = false
	remove_from_group("fatal_zone")
	get_tree().call_group("navmap", "rebake_navigation")  # un-carve → the path reopens
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_property(_mesh, "scale:y", 0.04, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if not _active or not _lethal:
		return  # inactive, or telegraph phase (avoidance only, no damage yet)
	_tick_accum += delta
	if _tick_accum < TICK_S:
		return
	var dmg := dps * _tick_accum
	_tick_accum = 0.0
	for g in UNIT_GROUPS:
		for u in get_tree().get_nodes_in_group(g):
			if u is Node3D and u.has_method("take_damage") and contains_point((u as Node3D).global_position):
				u.take_damage(dmg)


func _build() -> void:
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.12
	cyl.radial_segments = 32
	_mesh.mesh = cyl
	_mat = StandardMaterial3D.new()
	var warn := not _lethal  # telegraph = orange warning until it goes lethal red
	_mat.albedo_color = Color(0.98, 0.62, 0.12, 0.42) if warn else Color(0.95, 0.18, 0.12, 0.5)
	_mat.emission_enabled = true
	_mat.emission = Color(0.95, 0.55, 0.10) if warn else Color(0.95, 0.22, 0.10)
	_mat.emission_energy_multiplier = 1.6
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.render_priority = 2   # draw after enemy vision cones (priority -1, depth-writing)
	_mesh.material_override = _mat
	_mesh.position.y = 0.4      # above the vision cone (y=0.3) so the cone can't occlude it
	add_child(_mesh)
	# warning pulse so the lethal floor reads at a glance
	var tw := create_tween().set_loops()
	tw.tween_property(_mat, "emission_energy_multiplier", 2.6, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_mat, "emission_energy_multiplier", 1.4, 0.6).set_trans(Tween.TRANS_SINE)

extends Node3D
## Chokepoint trap — a pressure plate that, when the CONTROLLED member crosses it, spawns
## a fatal HazardZone (telegraph → lethal) BEHIND them (south), so the followers strung
## out behind get cut off — splitting the party at the corridor. A linked Lever resets it
## (clears the zone + re-arms). ref: F-006 trap classification / F-021 telegraph.

const HazardZone := preload("res://scripts/world/hazard_zone.gd")

const TRIGGER_RADIUS := 2.4
const TELEGRAPH_S := 0.8
const ZONE_RADIUS := 4.0
const ZONE_DPS := 90.0

var zone_offset: Vector3 = Vector3(0, 0, -7.0)  # zone spawns south of the plate (behind the leader)
var _armed: bool = true
var _zone: Node = null
var _plate_mat: StandardMaterial3D


func _ready() -> void:
	_build_plate()


func is_armed() -> bool:
	return _armed


func has_active_zone() -> bool:
	return _zone != null and is_instance_valid(_zone) and _zone.is_active()


func _physics_process(_delta: float) -> void:
	if not _armed:
		return
	for m in get_tree().get_nodes_in_group("party_member"):
		if m is Node3D and m.has_method("is_controlled") and m.is_controlled() \
				and global_position.distance_to((m as Node3D).global_position) <= TRIGGER_RADIUS:
			_trigger()
			return


func _trigger() -> void:
	_armed = false
	_set_plate_color(Color(0.9, 0.28, 0.12))
	_zone = HazardZone.new()
	_zone.setup(ZONE_RADIUS, ZONE_DPS, TELEGRAPH_S)
	_zone.position = global_position + zone_offset
	get_parent().add_child(_zone)
	print("[TDC] Trap triggered — fatal zone splitting the corridor")


## Lever reset — clear the fatal zone + re-arm ("함정 회복").
func reset() -> void:
	if _zone != null and is_instance_valid(_zone):
		_zone.clear_zone()
	_zone = null
	_armed = true
	_set_plate_color(Color(0.85, 0.78, 0.30))


func _build_plate() -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = TRIGGER_RADIUS
	cyl.bottom_radius = TRIGGER_RADIUS
	cyl.height = 0.08
	mi.mesh = cyl
	_plate_mat = StandardMaterial3D.new()
	_plate_mat.albedo_color = Color(0.85, 0.78, 0.30)
	_plate_mat.emission_enabled = true
	_plate_mat.emission = Color(0.55, 0.45, 0.10)
	_plate_mat.emission_energy_multiplier = 0.7
	mi.material_override = _plate_mat
	mi.position.y = 0.05
	add_child(mi)


func _set_plate_color(c: Color) -> void:
	if _plate_mat:
		_plate_mat.albedo_color = c
		_plate_mat.emission = c.darkened(0.5)

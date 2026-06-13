extends Node
## MIA / separation-leash subsystem — extracted from PartyController (ARCHITECTURE DEBT-GOD).
## A child of PartyController; owns the warn→MIA timers, the unbound distance leash + return
## ring, and the rejoin-failure nav-path check. Two spec entry paths converge here
## (F-003 §3.6.2 "OR"):
##  • Unbound distance leash (§3.3.1): in 파티비결속, straight distance to the anchor
##    (지휘권 보유자) > leash → warning + return ring at 1 s → MIA at 5 s. Applies to the
##    controlled scout too — on MIA, control is forced to the anchor.
##  • Rejoin failure (§3.6.2 / F-004 §3.3): a non-controlled member's nav PATH to the anchor
##    is too long / severed (fatal zones are carved out of the navmesh) → MIA.
## MIA blocks swap (F-001 §3.6) + holds. Combat freezes distance-MIA (§3.3.1). Clears the
## instant the member is back within range / reachable. Pulls party context via accessors and
## calls back force_control_off (the control mutation stays single-owned on the controller).

const _UNBOUND_ANCHOR_MAX_M: float = 20.0  # leash (demo tuning; §3.3.1 example 12 m)
const _WARN_AFTER_S: float = 1.0           # §3.3.1 t_unbound_separation_warn
const _MIA_AFTER_S: float = 5.0            # 경고 후 여유 (demo tuning; §3.3.1 t_mia 3.0)
const _MIA_DISTANCE_M: float = 20.0        # rejoin-failure nav-path leash (matches the leash)
const _MIA_RECHECK_S: float = 0.2          # throttle nav-path queries

var _party: Node = null
var _mia_timer: Dictionary = {}
var _mia_dist_cache: Dictionary = {}
var _mia_recheck: float = 0.0
var _leash_ring: MeshInstance3D = null
var _pip_list: Array = []


func setup(party: Node) -> void:
	_party = party


## Per-frame warn→MIA evaluation for the unbound leash + the rejoin-failure nav path.
## (was PartyController._update_mia.)
func tick(delta: float) -> void:
	if _party == null:
		return
	_mia_recheck -= delta
	var recompute: bool = _mia_recheck <= 0.0
	if recompute:
		_mia_recheck = _MIA_RECHECK_S
	var members: Array = _party.get_members()
	var anchor: CharacterBody3D = _party.get_anchor()
	var unbound: bool = _party.is_unbound()
	var engaging: bool = _party.is_combat_engaging()
	var ring_at := Vector3.ZERO
	var show_ring := false
	for member in members:
		if anchor == null or member == anchor or not member.is_alive():
			_clear_member_sep(member)
			continue
		if engaging:
			continue  # §3.3.1: combat doesn't distance-(de)MIA — freeze current warn/MIA
		# Path B — unbound straight-distance leash (the controlled scout counts too).
		var leash_sep := false
		if unbound:
			var dx: float = member.global_position.x - anchor.global_position.x
			var dz: float = member.global_position.z - anchor.global_position.z
			leash_sep = dx * dx + dz * dz > _UNBOUND_ANCHOR_MAX_M * _UNBOUND_ANCHOR_MAX_M
		# Path A — rejoin failure: non-controlled member can't reach the anchor (nav path).
		var reach_sep := false
		if not member.is_controlled():
			if recompute:
				_mia_dist_cache[member] = _reachable_dist(member, anchor.global_position)
			reach_sep = float(_mia_dist_cache.get(member, 0.0)) > _MIA_DISTANCE_M
		if leash_sep or reach_sep:
			if leash_sep:
				show_ring = true  # boundary ring appears the instant you cross the leash
				ring_at = anchor.global_position
			var t: float = float(_mia_timer.get(member, 0.0)) + delta
			_mia_timer[member] = t
			if t >= _MIA_AFTER_S:
				if not member.is_mia():  # transition into MIA (UI-006 MIAEntered)
					if member.is_controlled():
						_party.force_control_off(member)  # hand control to the anchor, then lock out
					else:
						_party.party_alert.emit("%s MIA — 집합 필요" % member.class_id, 1)
				member.set_warn(false)
				member.set_mia(true)
			elif t >= _WARN_AFTER_S:
				if not member.is_warn() and not member.is_mia():  # transition into warning
					_party.party_alert.emit("%s 이탈 — 파티 범위로 복귀하세요" % member.class_id, 0)
				member.set_warn(true)
		else:
			_clear_member_sep(member)
	_update_leash_ring(show_ring, ring_at, members)
	# UI-006 §7 / §7.8 — PIP shows MIA members (after control transferred off them). Collect
	# all MIA members so the PIP can show a count + cycle when 2+ are stranded.
	var mia_list: Array = []
	for member in members:
		if member.is_mia():
			mia_list.append(member)
	if mia_list != _pip_list:
		_pip_list = mia_list.duplicate()
		_party.pip_targets.emit(mia_list)


func _clear_member_sep(member: CharacterBody3D) -> void:
	_mia_timer.erase(member)
	_mia_dist_cache.erase(member)
	member.set_warn(false)
	member.set_mia(false)


## The return ring around the anchor, shown during a separation warning.
func _update_leash_ring(show: bool, anchor_pos: Vector3, members: Array) -> void:
	if not show:
		if _leash_ring != null:
			_leash_ring.visible = false
		return
	if _leash_ring == null:
		if members.is_empty():
			return
		_leash_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = _UNBOUND_ANCHOR_MAX_M - 0.12  # thin boundary outline only
		torus.outer_radius = _UNBOUND_ANCHOR_MAX_M
		torus.rings = 96         # main-circle smoothness (was 3 → triangle + edges far inside)
		torus.ring_segments = 8  # tube cross-section (thin)
		_leash_ring.mesh = torus  # TorusMesh already lies flat in the XZ plane — no rotation
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.82, 0.2, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.72, 0.1)
		mat.emission_energy_multiplier = 1.5
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.render_priority = 2
		_leash_ring.material_override = mat
		members[0].get_parent().add_child(_leash_ring)
	_leash_ring.visible = true
	_leash_ring.global_position = Vector3(anchor_pos.x, 0.25, anchor_pos.z)


## Navmesh PATH distance from a member to the anchor. Fatal zones are carved out of the
## navmesh (map_demo_layout), so the path routes AROUND them; INF if there's no path or it
## can't actually reach the anchor (a corridor severed). ref: F-004 §3.3 (거리 = nav path
## length; 경로 단절/우회 → reachable distance; 도달 불가 → hold/MIA).
func _reachable_dist(member: CharacterBody3D, anchor_pos: Vector3) -> float:
	var map: RID = member.get_world_3d().navigation_map
	if not map.is_valid():
		return 0.0
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, member.global_position, anchor_pos, true)
	if path.size() < 2:
		return INF
	if path[path.size() - 1].distance_to(anchor_pos) > 2.5:
		return INF  # path ends short of the anchor → severed (carved zone) → unreachable
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	return total

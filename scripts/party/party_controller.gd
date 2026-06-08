extends Node3D
## 4-member party — F-001 swap, F-003 formation (bound/unbound smoke). ref: QA-030 §3.2

const PartyCohesion := preload("res://scripts/party/party_cohesion.gd")
const MemberScene := preload("res://scenes/party/party_member.tscn")
const PlayerControl := preload("res://scripts/run/player_controller.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")

signal controlled_changed(member: CharacterBody3D)
signal cohesion_changed(mode: int)
signal formation_priority_changed(on: bool)

@export var move_speed: float = 9.0

var _in_combat: bool = false  ## set via combat signals (bind_combat). ref: DEBT-CPL-COMBAT
var cohesion_mode: int = PartyCohesion.MODE_BOUND
## Formation-priority toggle. OFF (default) = combat priority: in combat,
## followers break formation and engage enemies. ON = hold slots even in combat.
var _formation_priority: bool = false
var _combat_engaging: bool = false

var _members: Array[CharacterBody3D] = []
var _controlled_index: int = 0
var _leader_index: int = 0
var _slot_offsets: Dictionary = {}
var _follower_move_speed: float = 14.0
var _follower_move_speed_near: float = 9.0
var _follower_speed_far_dist: float = 5.0
var _follower_accel_mps2: float = 50.0
var _player_accel_mps2: float = 0.0
var _player_decel_mps2: float = 0.0
var _arrive_distance: float = 0.5
var _tank_min_lead: float = 3.2
var _collision_radius: float = 0.26
var _collision_height: float = 1.15
var _formation_forward: Vector3 = Vector3(0, 0, 1)
var _last_formation_forward: Vector3 = Vector3(0, 0, 1)
var _formation_forward_smooth: float = 12.0
var _formation_min_speed: float = 0.2
var _formation_update_angle_deg: float = 30.0
var _formation_forward_hold_s: float = 0.08
var _forward_hold_timer: float = 0.0
var _backpedal_continuous_s: float = 0.0
var _backpedal_stop_accum_s: float = 0.0
var _commit_override_cooldown_s: float = 0.0
var _commit_override_opposite_dot: float = -0.6
var _commit_override_cooldown_duration: float = 0.75
var _commit_backpedal_s_fast: float = 1.0
var _commit_backpedal_s_slow: float = 2.5
var _commit_opposite_s_fast: float = 0.65
var _commit_opposite_s_slow: float = 2.4
var _commit_speed_fast_mps: float = 6.5
var _commit_speed_slow_mps: float = 2.8
var _backpedal_reset_stop_fast: float = 0.12
var _backpedal_reset_stop_slow: float = 0.35
var _last_backpedal_speed: float = 0.0
var _tank_correction_gain: float = 5.0
var _tank_motion_forward_dot: float = 0.35
var _tank_inherit_min_dot: float = 0.35
var _tank_preferred_anchor_distance: float = 2.0
var _tank_reversal_orbit_strength: float = 4.5
var _tank_reversal_clear_radius: float = 2.8
var _preferred_anchor_distance: float = 1.35
var _lateral_approach_blend: float = 0.45
var _slot_arrive_extra: float = 0.45
var _party_separation_radius: float = 1.25
var _party_separation_strength: float = 6.5
var _party_separation_max_mps: float = 5.0
var _party_separation_stationary_boost: float = 1.65
var _party_slot_target_separation_blend: float = 0.55
var _party_separation_boost_moving: float = 1.35
var _party_separation_max_mps_moving: float = 8.5
var _anchor_path_clearance_extra_m: float = 0.45
var _reposition_delay_min: float = 0.0
var _reposition_delay_max: float = 0.16
var _reposition_delay_large_max: float = 0.28
var _swap_reposition_delay_min: float = 0.05
var _swap_reposition_delay_max: float = 0.26
var _layout_change_angle_deg: float = 25.0
var _layout_change_large_angle_deg: float = 100.0
var _formation_shift_counter: int = 0
var _jitter_prev_forward: Vector3 = Vector3(0, 0, 1)
var _party_layout_origin: Vector3 = Vector3.ZERO
var _party_layout_origin_valid: bool = false

# --- Steering v1 config (loaded from formation.json "steering_v1" block) ---
var _sv1_sep_zero_radius: float = 1.0
var _sv1_sep_zero_anchor_extra: float = 0.2
var _sv1_sep_touch_radius: float = 0.52
var _sv1_sep_urgency_power: float = 2.2
var _sv1_sep_strength: float = 7.0
var _sv1_sep_max_mps: float = 9.0
var _sv1_sep_deadzone_ratio: float = 0.85
var _sv1_collinear_opposing_dot: float = -0.65
var _sv1_bypass_strength: float = 5.5
## Only bypass an ally that lies within this distance AHEAD along the path. A
## far obstacle (e.g. the anchor at the center while orbiting) no longer triggers
## a premature wide detour — near-range separation still prevents overlap.
var _sv1_bypass_lookahead_m: float = 1.5
var _sv1_arrive_extra: float = 0.45
var _sv1_seek_gain: float = 4.0
var _sv1_slot_proximity_damping_min: float = 0.2
var _sv1_dir_smooth_rate: float = 14.0
var _sv1_wall_clip_enabled: bool = true
var _sv1_goal_ramp_after_delay_s: float = 0.08
var _sv1_slot_min_distance_pair: float = 2.5
var _sv1_slot_min_distance_anchor: float = 2.0
var _sv1_sep_asymmetry_min: float = 0.15
var _sv1_noise_dir_deg: float = 6.0
var _sv1_noise_dir_freq: float = 0.7
var _sv1_noise_speed_pct: float = 0.12
var _sv1_noise_speed_freq: float = 0.5
## Slot target room-clamp: keep slot DIRECTION from anchor, clamp DISTANCE so the
## point stays inside the anchor's line-of-sight (= same room). Kills the
## "slot behind a wall" oscillation by making the target a continuous function
## of geometry instead of a binary anchor/slot toggle.
## Max speed a follower may travel directly AWAY from its slot. Caps only the
## away-radial velocity component (toward-slot + sideways bypass are untouched),
## so separation/bypass can't fling a member out of formation on a turn.
var _sv1_away_speed_cap: float = 1.5
var _sv1_slot_clamp_enabled: bool = true
var _sv1_slot_clamp_margin: float = 0.4
var _sv1_slot_clamp_angle_step_deg: float = 15.0
var _sv1_slot_clamp_angle_max_deg: float = 60.0

# --- Steering v1 per-member state ---
var _sv1_prev_dir: Dictionary = {}
var _sv1_w_goal: Dictionary = {}
var _sv1_wall_normals: Dictionary = {}
var _sv1_noise: FastNoiseLite
var _sv1_noise_seed_offset: Dictionary = {}
## Per-member nav mode: true = NAVMESH mode (wall blocking path), false = DIRECT mode
var _sv1_nav_mode: Dictionary = {}
## Delay timer before exiting NAVMESH → DIRECT when path clears
var _sv1_nav_exit_timer: Dictionary = {}
const _SV1_NAV_EXIT_DELAY_S: float = 0.3
## Per-member timer: seconds the member has been wall-separated from anchor
var _sv1_separated_timer: Dictionary = {}
const _SV1_REJOIN_AFTER_S: float = 0.8


func _ready() -> void:
	_load_formation_config()
	_spawn_party_from_data()


func _physics_process(delta: float) -> void:
	_update_formation_forward(delta)
	_update_formation_follow(delta)


func get_controlled() -> CharacterBody3D:
	if _members.is_empty():
		return null
	return _members[_controlled_index]


func get_member(index: int) -> CharacterBody3D:
	if index < 0 or index >= _members.size():
		return null
	return _members[index]


func get_members() -> Array:
	return _members.duplicate()


## Subscribe to the combat-state owner (CombatController). ref: DEBT-CPL-COMBAT.
func bind_combat(combat: Node) -> void:
	combat.combat_started.connect(_on_combat_started)
	combat.combat_ended.connect(_on_combat_ended)


func _on_combat_started(_encounter_id: String) -> void:
	_in_combat = true


func _on_combat_ended(_result: String, _encounter_id: String) -> void:
	_in_combat = false


func try_swap_to(index: int) -> bool:
	if index < 0 or index >= _members.size():
		return false
	if index == _controlled_index:
		return false
	if not _members[index].is_alive():
		print("[TDC] Swap ignored (target downed)")  # can't control a downed member
		return false
	if not _can_swap():
		print("[TDC] Swap ignored (control locked)")  # F-001 §3.6 Control Lock / MIA
		return false
	_set_controlled_index(index)
	return true


func toggle_cohesion_mode() -> void:
	if cohesion_mode == PartyCohesion.MODE_BOUND:
		cohesion_mode = PartyCohesion.MODE_UNBOUND
	else:
		cohesion_mode = PartyCohesion.MODE_BOUND
	cohesion_changed.emit(cohesion_mode)
	_sync_tank_follow_collision()
	var label := "파티비결속" if cohesion_mode == PartyCohesion.MODE_UNBOUND else "파티결속"
	print("[TDC] Cohesion -> %s (anchor=%s)" % [label, _get_anchor().name])


func spawn_at(world_pos: Vector3) -> void:
	if _members.is_empty():
		return
	_place_party_at_anchor(world_pos)


func _on_member_downed(member: CharacterBody3D) -> void:
	if member != get_controlled():
		return
	# Controlled char went down — auto-swap to a living member so input isn't stuck.
	for i in _members.size():
		if _members[i] != member and _members[i].is_alive():
			_set_controlled_index(i)
			return
	push_warning("[TDC] Party wiped — all members down")


func _can_swap() -> bool:
	# F-001 §3.3/§3.6: swap is NOT gated by combat (only Control Lock / MIA).
	var run := get_parent().get_node_or_null("RunController")
	if run and run.has_method("can_swap"):
		return run.can_swap()
	return true


func _set_controlled_index(index: int) -> void:
	for i in _members.size():
		_members[i].set_controlled(i == index)
		var ctrl_script: Node = _members[i].get_node_or_null("Control")
		if ctrl_script:
			ctrl_script.set_physics_process(i == index)
	_controlled_index = index
	_apply_controlled_move_speeds()
	_sync_tank_follow_collision()
	_queue_swap_reposition_delays()
	var member := _members[index]
	controlled_changed.emit(member)
	print("[TDC] Controlled -> %s (%s)" % [member.identity_skill_id, member.class_id])


func _get_anchor() -> CharacterBody3D:
	if cohesion_mode == PartyCohesion.MODE_UNBOUND:
		return _members[_leader_index]
	return get_controlled()


func _anchor_velocity_h(anchor: CharacterBody3D) -> Vector3:
	return Vector3(anchor.velocity.x, 0.0, anchor.velocity.z)


func _reposition_delay_s(member: CharacterBody3D) -> float:
	return float(member.get("follow_reposition_delay_s"))


func _set_reposition_delay_s(member: CharacterBody3D, delay_s: float) -> void:
	member.set("follow_reposition_delay_s", delay_s)


func _anchor_motion_forward(anchor: CharacterBody3D) -> Vector3:
	var vel := _anchor_velocity_h(anchor)
	if vel.length() >= _formation_min_speed:
		return vel.normalized()
	return _slot_formation_forward()


func _slot_formation_forward() -> Vector3:
	if _formation_forward.length_squared() > 0.01:
		return _formation_forward
	if _last_formation_forward.length_squared() > 0.01:
		return _last_formation_forward
	return Vector3(0, 0, 1)


## Shared party layout axes — same for every slot (do not vary per follower class).
## Always use smoothed _formation_forward to prevent slot target jumps on brief taps.
func _layout_axes(_anchor: CharacterBody3D) -> Dictionary:
	var forward := _slot_formation_forward().normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	return {"forward": forward, "right": right}


func _axes_forward(axes: Dictionary) -> Vector3:
	return axes.get("forward", Vector3.FORWARD)


func _axes_right(axes: Dictionary) -> Vector3:
	return axes.get("right", Vector3.RIGHT)


func _offset_to_world(axes: Dictionary, slot_offset: Vector3) -> Vector3:
	# JSON: x = right, z = forward (탱 전방 = +z when following anchor).
	return _axes_right(axes) * slot_offset.x + _axes_forward(axes) * slot_offset.z


func _update_party_layout_origin(anchor: CharacterBody3D, axes: Dictionary, anchor_pos: Vector3) -> void:
	var anchor_class_id: String = String(anchor.get("class_id"))
	var anchor_slot: Vector3 = _slot_offsets.get(anchor_class_id, Vector3.ZERO)
	_party_layout_origin = anchor_pos - _offset_to_world(axes, anchor_slot)
	_party_layout_origin.y = anchor_pos.y
	_party_layout_origin_valid = true


func _anchor_slot_offset(anchor: CharacterBody3D) -> Vector3:
	var anchor_class_id: String = String(anchor.get("class_id"))
	return _slot_offsets.get(anchor_class_id, Vector3.ZERO)


func _slot_world_target(class_id: String, axes: Dictionary, ground_y: float) -> Vector3:
	var slot_offset: Vector3 = _slot_offsets.get(class_id, Vector3.ZERO)
	var world_off := _offset_to_world(axes, slot_offset)
	if class_id == "Tank":
		var fwd := _axes_forward(axes)
		var ahead: float = world_off.dot(fwd)
		if ahead < _tank_min_lead:
			world_off += fwd * (_tank_min_lead - ahead)
	var target := _party_layout_origin + world_off
	target.y = ground_y
	return target


func _load_formation_config() -> void:
	var path := "res://data/slice01/formation.json"
	if not FileAccess.file_exists(path):
		push_warning("[TDC] Missing formation.json — using defaults")
		return
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(doc) != TYPE_DICTIONARY:
		return
	_arrive_distance = float(doc.get("formation_arrive_distance_m", 0.5))
	_tank_min_lead = float(doc.get("tank_min_lead_m", 3.2))
	_formation_forward_smooth = float(doc.get("formation_forward_smooth_rate", 12.0))
	var fwd_cfg = doc.get("formation_forward", {})
	if typeof(fwd_cfg) == TYPE_DICTIONARY:
		_formation_min_speed = float(fwd_cfg.get("min_speed_mps", 0.2))
		_formation_update_angle_deg = float(fwd_cfg.get("update_angle_deg", 30.0))
		_formation_forward_hold_s = float(fwd_cfg.get("hold_s", 0.08))
		_commit_backpedal_s_fast = float(
			fwd_cfg.get("commit_override_backpedal_s_fast", fwd_cfg.get("commit_override_backpedal_s", 1.0))
		)
		_commit_backpedal_s_slow = float(fwd_cfg.get("commit_override_backpedal_s_slow", 2.5))
		_commit_opposite_s_fast = float(
			fwd_cfg.get("commit_override_opposite_s_fast", fwd_cfg.get("commit_override_opposite_s", 0.65))
		)
		_commit_opposite_s_slow = float(fwd_cfg.get("commit_override_opposite_s_slow", 2.4))
		_commit_override_opposite_dot = float(fwd_cfg.get("commit_override_opposite_dot", -0.6))
		_commit_speed_fast_mps = float(fwd_cfg.get("commit_speed_fast_mps", 6.5))
		_commit_speed_slow_mps = float(fwd_cfg.get("commit_speed_slow_mps", 2.8))
		_commit_override_cooldown_duration = float(
			fwd_cfg.get("commit_override_cooldown_s", 0.75)
		)
		_backpedal_reset_stop_fast = float(
			fwd_cfg.get("backpedal_timer_reset_stop_fast", fwd_cfg.get("backpedal_timer_reset_stop_s", 0.12))
		)
		_backpedal_reset_stop_slow = float(fwd_cfg.get("backpedal_timer_reset_stop_slow", 0.35))
	var tank_follow = doc.get("tank_follow", {})
	if typeof(tank_follow) == TYPE_DICTIONARY:
		_tank_correction_gain = float(tank_follow.get("correction_gain", 5.0))
		_tank_motion_forward_dot = float(tank_follow.get("motion_forward_dot", 0.35))
		_tank_inherit_min_dot = float(tank_follow.get("inherit_min_dot", 0.35))
		_tank_preferred_anchor_distance = float(
			tank_follow.get("preferred_min_anchor_distance_m", 2.0)
		)
		_tank_reversal_orbit_strength = float(tank_follow.get("reversal_orbit_strength", 4.5))
		_tank_reversal_clear_radius = float(tank_follow.get("reversal_clear_radius_m", 2.8))
	if doc.has("controlled_move_speed_mps"):
		move_speed = float(doc.get("controlled_move_speed_mps", move_speed))
	_follower_move_speed = float(doc.get("follower_move_speed_mps", 14.0))
	_follower_move_speed_near = float(doc.get("follower_move_speed_near_mps", 9.0))
	_follower_speed_far_dist = float(doc.get("follower_speed_far_distance_m", 5.0))
	_follower_accel_mps2 = float(doc.get("follower_accel_mps2", 50.0))
	_player_accel_mps2 = float(doc.get("player_accel_mps2", 0.0))
	_player_decel_mps2 = float(doc.get("player_decel_mps2", 0.0))
	var sv1 = doc.get("steering_v1", {})
	if typeof(sv1) == TYPE_DICTIONARY and sv1.size() > 0:
		_sv1_sep_zero_radius = float(sv1.get("sep_zero_radius_m", 1.0))
		_sv1_sep_zero_anchor_extra = float(sv1.get("sep_zero_anchor_extra_m", 0.2))
		_sv1_sep_touch_radius = float(sv1.get("sep_touch_radius_m", 0.52))
		_sv1_sep_urgency_power = float(sv1.get("sep_urgency_power", 2.2))
		_sv1_sep_strength = float(sv1.get("sep_strength", 7.0))
		_sv1_sep_max_mps = float(sv1.get("sep_max_mps", 9.0))
		_sv1_sep_deadzone_ratio = float(sv1.get("sep_deadzone_ratio", 0.85))
		_sv1_collinear_opposing_dot = float(sv1.get("collinear_opposing_dot", -0.65))
		_sv1_bypass_strength = float(sv1.get("bypass_strength", 5.5))
		_sv1_bypass_lookahead_m = float(sv1.get("bypass_lookahead_m", 1.5))
		_sv1_arrive_extra = float(sv1.get("arrive_radius_extra_m", 0.45))
		_sv1_seek_gain = float(sv1.get("seek_gain", 4.0))
		_sv1_slot_proximity_damping_min = float(sv1.get("slot_proximity_damping_min", 0.2))
		_sv1_dir_smooth_rate = float(sv1.get("dir_smooth_rate", 14.0))
		_sv1_wall_clip_enabled = bool(sv1.get("wall_clip_enabled", true))
		_sv1_goal_ramp_after_delay_s = float(sv1.get("goal_ramp_after_delay_s", 0.08))
		_sv1_slot_min_distance_pair = float(sv1.get("slot_min_distance_pair_m", 2.5))
		_sv1_slot_min_distance_anchor = float(sv1.get("slot_min_distance_anchor_m", 2.0))
		_sv1_sep_asymmetry_min = float(sv1.get("sep_asymmetry_min", 0.15))
		_sv1_noise_dir_deg = float(sv1.get("noise_dir_deg", 6.0))
		_sv1_noise_dir_freq = float(sv1.get("noise_dir_freq", 0.7))
		_sv1_noise_speed_pct = float(sv1.get("noise_speed_pct", 0.12))
		_sv1_noise_speed_freq = float(sv1.get("noise_speed_freq", 0.5))
		_sv1_away_speed_cap = float(sv1.get("away_speed_cap_mps", 1.5))
		_sv1_slot_clamp_enabled = bool(sv1.get("slot_clamp_enabled", true))
		_sv1_slot_clamp_margin = float(sv1.get("slot_clamp_margin_m", 0.4))
		_sv1_slot_clamp_angle_step_deg = float(sv1.get("slot_clamp_angle_step_deg", 15.0))
		_sv1_slot_clamp_angle_max_deg = float(sv1.get("slot_clamp_angle_max_deg", 60.0))
		_sv1_noise = FastNoiseLite.new()
		_sv1_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_sv1_noise.frequency = 1.0
		_sv1_noise.seed = randi()
	var variation = doc.get("follow_variation", {})
	if typeof(variation) == TYPE_DICTIONARY:
		_reposition_delay_min = float(
			variation.get("reposition_start_delay_min_s", variation.get("direction_change_delay_min_s", 0.0))
		)
		_reposition_delay_max = float(
			variation.get("reposition_start_delay_max_s", variation.get("direction_change_delay_max_s", 0.16))
		)
		_reposition_delay_large_max = float(
			variation.get(
				"reposition_start_delay_large_max_s",
				variation.get("direction_change_delay_large_max_s", 0.28)
			)
		)
		_layout_change_angle_deg = float(
			variation.get("layout_change_angle_deg", variation.get("direction_change_angle_deg", 25.0))
		)
		_layout_change_large_angle_deg = float(
			variation.get("large_layout_change_angle_deg", variation.get("large_direction_change_angle_deg", 100.0))
		)
		_swap_reposition_delay_min = float(variation.get("swap_reposition_start_delay_min_s", 0.05))
		_swap_reposition_delay_max = float(variation.get("swap_reposition_start_delay_max_s", 0.26))
	var col = doc.get("collision", {})
	if typeof(col) == TYPE_DICTIONARY:
		_collision_radius = float(col.get("capsule_radius_m", 0.26))
		_collision_height = float(col.get("capsule_height_m", 1.15))
	for slot in doc.get("slots", []):
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		var cid := String(slot.get("class_id", ""))
		var off: Array = slot.get("offset", [0, 0, 0])
		if off.size() >= 3:
			_slot_offsets[cid] = Vector3(float(off[0]), float(off[1]), float(off[2]))
	_sv1_enforce_slot_constraints()


func _spawn_party_from_data() -> void:
	var rows: Array = Slice01Data.get_identity_rows()
	_leader_index = 0
	for i in rows.size():
		var row: Dictionary = rows[i]
		if String(row.get("class_id", "")) == "Tank":
			_leader_index = i
			break
	for i in rows.size():
		var row: Dictionary = rows[i]
		var class_id := String(row.get("class_id", ""))
		var member: CharacterBody3D = MemberScene.instantiate()
		$Members.add_child(member)
		member.setup(
			row,
			i,
			UnitVisuals.role_color(class_id),
			_collision_radius,
			_collision_height,
			UnitVisuals.role_scale(class_id)
		)
		var ctrl := PlayerControl.new()
		ctrl.name = "Control"
		member.add_child(ctrl)
		ctrl.set_physics_process(false)
		member.downed.connect(_on_member_downed)
		_members.append(member)
		_sv1_noise_seed_offset[member] = float(i) * 100.0
	if _members.is_empty():
		push_error("[TDC] Party spawn failed — no identities")
		return
	_apply_controlled_move_speeds()
	_set_controlled_index(0)


func _update_formation_forward(delta: float) -> void:
	var anchor := _get_anchor()
	if anchor == null:
		return
	if _commit_override_cooldown_s > 0.0:
		_commit_override_cooldown_s = maxf(0.0, _commit_override_cooldown_s - delta)
	var vel := _anchor_velocity_h(anchor)
	var speed := vel.length()
	if speed < _formation_min_speed:
		if _formation_forward.length_squared() > 0.01:
			_last_formation_forward = _formation_forward
		_backpedal_stop_accum_s += delta
		if _backpedal_stop_accum_s >= _backpedal_reset_stop_for_speed(_last_backpedal_speed):
			_backpedal_continuous_s = 0.0
		_forward_hold_timer = 0.0
		return
	_backpedal_stop_accum_s = 0.0
	var move_dir := vel.normalized()
	if _formation_forward.length_squared() < 0.01:
		_set_formation_forward(move_dir)
		return
	# F-003 §3.0.2 — backpedal: never flip formationForward while move opposes it.
	if move_dir.dot(_formation_forward) < 0.0:
		_forward_hold_timer = 0.0
		_last_backpedal_speed = speed
		_tick_backpedal_commit_override(delta, move_dir, speed)
		return
	_backpedal_continuous_s = 0.0
	var angle_deg := rad_to_deg(acos(clampf(move_dir.dot(_formation_forward), -1.0, 1.0)))
	if angle_deg <= _formation_update_angle_deg:
		_blend_formation_forward_toward(move_dir, delta)
		_forward_hold_timer = 0.0
		return
	_forward_hold_timer += delta
	if _forward_hold_timer >= _formation_forward_hold_s:
		_blend_formation_forward_toward(move_dir, delta)
		_forward_hold_timer = 0.0
	_queue_reposition_start_delays()


func _set_formation_forward(dir: Vector3) -> void:
	_formation_forward = dir.normalized()
	_last_formation_forward = _formation_forward
	_queue_reposition_start_delays()


func _blend_formation_forward_toward(desired: Vector3, delta: float) -> void:
	var blend: float = 1.0 - exp(-_formation_forward_smooth * delta)
	_formation_forward = _formation_forward.lerp(desired, blend).normalized()
	_last_formation_forward = _formation_forward
	_queue_reposition_start_delays()


func _queue_reposition_start_delays() -> void:
	var cur := _slot_formation_forward()
	if _jitter_prev_forward.length_squared() < 0.01:
		_jitter_prev_forward = cur
		return
	var angle_deg := rad_to_deg(acos(clampf(_jitter_prev_forward.dot(cur), -1.0, 1.0)))
	_jitter_prev_forward = cur
	if angle_deg < _layout_change_angle_deg:
		return
	_formation_shift_counter += 1
	var delay_max := (
		_reposition_delay_large_max if angle_deg >= _layout_change_large_angle_deg
		else _reposition_delay_max
	)
	for member in _members:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s:%d" % [member.identity_skill_id, _formation_shift_counter])
		var delay := rng.randf_range(_reposition_delay_min, delay_max)
		_set_reposition_delay_s(member, maxf(_reposition_delay_s(member), delay))


func _queue_swap_reposition_delays() -> void:
	var anchor := _get_anchor()
	if anchor == null:
		return
	if _anchor_velocity_h(anchor).length() >= _formation_min_speed:
		return
	_formation_shift_counter += 1
	for member in _members:
		if member == anchor:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("swap:%s:%d" % [member.identity_skill_id, _formation_shift_counter])
		var delay := rng.randf_range(_swap_reposition_delay_min, _swap_reposition_delay_max)
		_set_reposition_delay_s(member, maxf(_reposition_delay_s(member), delay))


func _commit_speed_blend(speed: float) -> float:
	return clampf(
		inverse_lerp(_commit_speed_slow_mps, _commit_speed_fast_mps, speed),
		0.0,
		1.0
	)


func _backpedal_commit_threshold(move_dir: Vector3, speed: float) -> float:
	var blend := _commit_speed_blend(speed)
	if move_dir.dot(_formation_forward) < _commit_override_opposite_dot:
		return lerpf(_commit_opposite_s_slow, _commit_opposite_s_fast, blend)
	return lerpf(_commit_backpedal_s_slow, _commit_backpedal_s_fast, blend)


func _backpedal_reset_stop_for_speed(speed: float) -> float:
	return lerpf(_backpedal_reset_stop_slow, _backpedal_reset_stop_fast, _commit_speed_blend(speed))


func _tick_backpedal_commit_override(delta: float, move_dir: Vector3, speed: float) -> void:
	if _in_combat:
		_backpedal_continuous_s = 0.0
		return
	if _commit_override_cooldown_s > 0.0:
		return
	_backpedal_continuous_s += delta
	var threshold := _backpedal_commit_threshold(move_dir, speed)
	if _backpedal_continuous_s >= threshold:
		_set_formation_forward(move_dir)
		_backpedal_continuous_s = 0.0
		_commit_override_cooldown_s = _commit_override_cooldown_duration


func _update_formation_follow(delta: float) -> void:
	var anchor := _get_anchor()
	if anchor == null:
		return
	var anchor_pos := anchor.global_position
	var layout_axes := _layout_axes(anchor)
	var anchor_moving := _anchor_velocity_h(anchor).length() >= _formation_min_speed
	if not _party_layout_origin_valid:
		_update_party_layout_origin(anchor, layout_axes, anchor_pos)
	elif anchor_moving:
		_update_party_layout_origin(anchor, layout_axes, anchor_pos)
	# Combat: followers leave their slots and engage enemies autonomously —
	# unless formation-priority is ON (hold slots), or combat ended / no enemies.
	_combat_engaging = _in_combat and not _formation_priority and _has_live_enemies()
	var peer_slot_targets: Dictionary = {}
	for m in _members:
		if _combat_engaging and m != anchor and not m.is_controlled():
			peer_slot_targets[m] = _combat_engage_target(m)
		else:
			var cid: String = String(m.get("class_id"))
			peer_slot_targets[m] = _slot_world_target(cid, layout_axes, anchor_pos.y)
	_sv1_update_follow(anchor, anchor_pos, layout_axes, peer_slot_targets, delta)


## Formation-priority toggle (hotkey). ON = hold slots even in combat;
## OFF = combat priority (followers engage enemies).
func toggle_formation_priority() -> void:
	_formation_priority = not _formation_priority
	formation_priority_changed.emit(_formation_priority)
	print("[TDC] Formation priority -> %s" % (
		"ON (hold slots)" if _formation_priority else "OFF (fight)"
	))


func is_formation_priority() -> bool:
	return _formation_priority


func _has_live_enemies() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			return true
	return false


## Goal point for an engaging follower: a spot just inside its attack range of
## the nearest enemy (so it closes in, then the basic-attack loop fires).
func _combat_engage_target(member: CharacterBody3D) -> Vector3:
	var mp := member.global_position
	var nearest: Node3D = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = mp.distance_squared_to(e.global_position)
		if d < best:
			best = d
			nearest = e
	if nearest == null:
		return mp
	# Stop well inside attack range (not at the edge) so separation jitter can't
	# push the follower out of range — keeps it reliably attacking.
	var br: float = float(member.get("basic_range_m"))
	var reach: float = clampf(br - 0.6, 0.8, br)
	var to := mp - nearest.global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= reach or dist < 0.001:
		return Vector3(mp.x, nearest.global_position.y, mp.z)  # in range — hold & attack
	var t := nearest.global_position + (to / dist) * reach
	t.y = nearest.global_position.y
	return t



# ============================================================================
# Steering v1 — single-model follow (replaces v0 compose stack)
# ============================================================================


func _sv1_update_follow(
	anchor: CharacterBody3D,
	anchor_pos: Vector3,
	layout_axes: Dictionary,
	peer_slot_targets: Dictionary,
	delta: float
) -> void:
	# Pass 0: project every slot target into the anchor's room — preserve the
	# anchor→slot DIRECTION, clamp DISTANCE to line-of-sight. Resolved first for
	# all members so separation/bypass use the in-room peer targets too.
	# Skipped while engaging: combat targets are intentionally out at the enemies.
	if _sv1_slot_clamp_enabled and not _combat_engaging:
		for member in _members:
			if member == anchor:
				continue
			peer_slot_targets[member] = _sv1_resolve_slot_target(
				member, peer_slot_targets[member], anchor, anchor_pos
			)
	# Pass 1: compute all velocities (no position changes)
	var planned: Dictionary = {}
	for member in _members:
		if member == anchor:
			planned[member] = Vector3.ZERO
			continue
		if member.is_controlled():
			continue
		if member.has_method("is_alive") and not member.is_alive():
			member.velocity = Vector3.ZERO
			continue  # downed — stays where it fell
		var slot_target: Vector3 = peer_slot_targets[member]
		# Rejoin fallback (member-POV): the clamped slot is always in the anchor's
		# room, so this only fires when the member itself is physically stuck in
		# another room. Then path back to the anchor via navmesh instead of holding
		# the unreachable slot. No longer a binary slot/anchor flip → no oscillation.
		# Skipped while engaging — followers should head to enemies, not the anchor.
		if not _combat_engaging:
			var separated: bool = _sv1_path_blocked(member, anchor_pos)
			if separated:
				var t: float = _sv1_separated_timer.get(member, 0.0) + delta
				_sv1_separated_timer[member] = t
				if t >= _SV1_REJOIN_AFTER_S:
					slot_target = anchor_pos
					peer_slot_targets[member] = slot_target
			else:
				_sv1_separated_timer[member] = 0.0
		planned[member] = _sv1_velocity(anchor, member, slot_target, anchor_pos, peer_slot_targets, delta)
	# Pass 2: apply all velocities (anchor is handled by player_controller)
	for member in _members:
		if member == anchor or member.is_controlled():
			continue
		if not planned.has(member):
			continue  # downed / skipped
		var target_vel: Vector3 = planned.get(member, Vector3.ZERO)
		if _follower_accel_mps2 > 0.0:
			member.velocity = member.velocity.move_toward(target_vel, _follower_accel_mps2 * delta)
		else:
			member.velocity = target_vel
		member.move_and_slide()
		_sv1_store_wall_normals(member)


func _sv1_effective_radius(member: CharacterBody3D) -> float:
	var base := _collision_radius
	if member.is_controlled():
		base *= member.CONTROLLED_SCALE
	return base


func _sv1_member_priority(member: CharacterBody3D, anchor: CharacterBody3D) -> float:
	if member == anchor:
		return 1000.0
	var offset: Vector3 = _slot_offsets.get(member.class_id, Vector3.ZERO)
	return offset.z


func _sv1_repel(pos: Vector3, ally_pos: Vector3, r_self: float, r_ally: float, is_anchor: bool) -> Vector3:
	var offset := pos - ally_pos
	offset.y = 0.0
	var d := offset.length()
	var R_zero: float = _sv1_sep_zero_radius
	if is_anchor:
		R_zero += _sv1_sep_zero_anchor_extra
	var R_dead: float = R_zero * _sv1_sep_deadzone_ratio
	if d >= R_dead or d < 0.05:
		return Vector3.ZERO
	var R_touch_pair: float = r_self + r_ally
	var urgency: float
	if d <= R_touch_pair:
		urgency = 1.0
	else:
		var effective_range := R_dead - R_touch_pair
		if effective_range <= 0.01:
			urgency = 1.0
		else:
			urgency = pow((R_dead - d) / effective_range, _sv1_sep_urgency_power)
	return offset.normalized() * _sv1_sep_strength * urgency


func _sv1_compute_sep_and_bypass(
	member: CharacterBody3D,
	pos: Vector3,
	slot_target: Vector3,
	anchor: CharacterBody3D,
	anchor_pos: Vector3,
	peer_slot_targets: Dictionary
) -> Dictionary:
	var F_sep := Vector3.ZERO
	var F_bypass := Vector3.ZERO
	var d_goal := slot_target - pos
	d_goal.y = 0.0
	var d_goal_len := d_goal.length()
	var d_goal_dir := d_goal / maxf(d_goal_len, 0.001)
	var r_self := _sv1_effective_radius(member)
	var needs_bypass := false
	var anchor_repel_vec := Vector3.ZERO
	var pri_self := _sv1_member_priority(member, anchor)

	for other in _members:
		if other == member:
			continue
		var other_pos := other.global_position
		var r_other := _sv1_effective_radius(other)
		var is_anchor_other := (other == anchor)
		var repel_vec := _sv1_repel(pos, other_pos, r_self, r_other, is_anchor_other)
		# Fixed priority weight: forward slot = higher priority = less repulsion received.
		# Pair sums to 2.0 so total energy is conserved.
		var pri_other := _sv1_member_priority(other, anchor)
		var asym_w: float
		if pri_self > pri_other + 0.01:
			asym_w = _sv1_sep_asymmetry_min
		elif pri_self < pri_other - 0.01:
			asym_w = 2.0 - _sv1_sep_asymmetry_min
		else:
			asym_w = 1.0
		repel_vec *= asym_w
		F_sep += repel_vec
		if is_anchor_other:
			anchor_repel_vec = repel_vec
		# Bypass condition 1: pos->slot segment passes near ally
		if not needs_bypass and d_goal_len > 0.5:
			var to_ally := other_pos - pos
			to_ally.y = 0.0
			var along: float = to_ally.dot(d_goal_dir)
			if along > 0.0 and along < minf(d_goal_len, _sv1_bypass_lookahead_m):
				var perp_dist := (to_ally - d_goal_dir * along).length()
				var check_r: float = _sv1_sep_zero_radius
				if is_anchor_other:
					check_r += _sv1_sep_zero_anchor_extra
				if perp_dist < check_r:
					needs_bypass = true
					var side := signf(d_goal_dir.cross(to_ally).y)
					if absf(side) < 0.01:
						side = 1.0
					var perp := Vector3(-d_goal_dir.z, 0.0, d_goal_dir.x)
					F_bypass = perp * side * _sv1_bypass_strength * asym_w

	# Bypass condition 2: anchor repel opposes goal direction
	if not needs_bypass and anchor_repel_vec.length_squared() > 0.01:
		if anchor_repel_vec.normalized().dot(d_goal_dir) < _sv1_collinear_opposing_dot:
			var to_anchor := anchor_pos - pos
			to_anchor.y = 0.0
			var side := signf(d_goal_dir.cross(to_anchor).y)
			if absf(side) < 0.01:
				side = 1.0
			var perp := Vector3(-d_goal_dir.z, 0.0, d_goal_dir.x)
			F_bypass = perp * side * _sv1_bypass_strength

	F_sep = F_sep.limit_length(_sv1_sep_max_mps)
	return {"F_sep": F_sep, "F_bypass": F_bypass}


func _sv1_clip_walls(vec: Vector3, member: CharacterBody3D) -> Vector3:
	if not _sv1_wall_clip_enabled:
		return vec
	# Pass 1: cached normals from previous frame
	var normals: Array = _sv1_wall_normals.get(member, [])
	for n: Vector3 in normals:
		var into := vec.dot(n)
		if into < 0.0:
			vec -= n * into
	# Pass 2: test_move fallback
	if vec.length_squared() < 0.001:
		return vec
	var test_vel := vec * (1.0 / 60.0)
	var collision := KinematicCollision3D.new()
	if member.test_move(member.global_transform, test_vel, collision):
		var n2 := collision.get_normal()
		n2.y = 0.0
		if n2.length_squared() > 0.01:
			n2 = n2.normalized()
			var into2 := vec.dot(n2)
			if into2 < 0.0:
				vec -= n2 * into2
	return vec



## Project an ideal slot target into the same room as the anchor.
## Keeps the anchor→slot DIRECTION; clamps DISTANCE so the result stays within
## the anchor's line-of-sight (= same room, directly reachable). When the exact
## bearing collapses against a wall, fans out by small angles to recover distance
## while preserving the rough left/right/rear intent.
func _sv1_resolve_slot_target(
	member: CharacterBody3D,
	ideal_slot: Vector3,
	anchor: CharacterBody3D,
	anchor_pos: Vector3
) -> Vector3:
	var dir := ideal_slot - anchor_pos
	dir.y = 0.0
	var dist := dir.length()
	if dist < 0.05:
		return ideal_slot
	dir /= dist
	# Primary: straight bearing from anchor toward the ideal slot.
	var reach := _sv1_anchor_ray_reach(member, anchor, anchor_pos, dir, dist)
	if reach >= dist:
		return ideal_slot  # slot already visible from anchor → same room, keep it
	if reach >= _sv1_slot_min_distance_anchor:
		return _sv1_point_along(anchor_pos, dir, reach, ideal_slot.y)
	# Bearing collapsed against a wall — fan out to recover distance.
	var best_dir := dir
	var best_reach := reach
	var steps := int(_sv1_slot_clamp_angle_max_deg / maxf(_sv1_slot_clamp_angle_step_deg, 1.0))
	for i in range(1, steps + 1):
		var a := deg_to_rad(_sv1_slot_clamp_angle_step_deg * float(i))
		for s: float in [1.0, -1.0]:
			var cand_dir := dir.rotated(Vector3.UP, a * s)
			var cand_reach := _sv1_anchor_ray_reach(member, anchor, anchor_pos, cand_dir, dist)
			if cand_reach > best_reach:
				best_reach = cand_reach
				best_dir = cand_dir
		if best_reach >= dist:
			break
	return _sv1_point_along(anchor_pos, best_dir, best_reach, ideal_slot.y)


func _sv1_point_along(origin: Vector3, dir: Vector3, dist: float, ground_y: float) -> Vector3:
	var p := origin + dir * dist
	p.y = ground_y
	return p


## Distance the anchor can travel along `dir` before a wall, capped at `max_dist`.
## Returns max_dist when clear; otherwise pulls the hit point back by the clamp
## margin so the member doesn't end up embedded in the wall.
func _sv1_anchor_ray_reach(
	member: CharacterBody3D,
	anchor: CharacterBody3D,
	anchor_pos: Vector3,
	dir: Vector3,
	max_dist: float
) -> float:
	var space := member.get_world_3d().direct_space_state
	if space == null:
		return max_dist
	var origin := anchor_pos + Vector3(0, 0.5, 0)
	var dest := origin + dir * max_dist
	var query := PhysicsRayQueryParameters3D.create(origin, dest, 1)
	query.exclude = [member.get_rid(), anchor.get_rid()]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return max_dist
	var hit: Vector3 = result.position
	var reach: float = (Vector3(hit.x, origin.y, hit.z) - origin).length() - _sv1_slot_clamp_margin
	return maxf(0.0, reach)


## Returns true if a wall blocks the direct line from member to target.
func _sv1_path_blocked(member: CharacterBody3D, target: Vector3) -> bool:
	var space := member.get_world_3d().direct_space_state
	if space == null:
		return false
	var origin := member.global_position + Vector3(0, 0.5, 0)
	var dest := Vector3(target.x, origin.y, target.z)
	var query := PhysicsRayQueryParameters3D.create(origin, dest, 1)
	query.exclude = [member.get_rid()]
	var result := space.intersect_ray(query)
	return not result.is_empty()


## Returns true if any wall is within proximity radius of the member.
func _sv1_wall_nearby(member: CharacterBody3D) -> bool:
	var space := member.get_world_3d().direct_space_state
	if space == null:
		return false
	var origin := member.global_position + Vector3(0, 0.5, 0)
	var radius: float = 1.2
	for i in 4:
		var angle := float(i) * TAU / 4.0
		var d := Vector3(cos(angle), 0, sin(angle))
		var query := PhysicsRayQueryParameters3D.create(origin, origin + d * radius, 1)
		query.exclude = [member.get_rid()]
		if not space.intersect_ray(query).is_empty():
			return true
	return false


## Updates per-member nav mode state. Returns true if NAVMESH mode is active.
func _sv1_update_nav_mode(member: CharacterBody3D, slot_target: Vector3, delta: float) -> bool:
	var need_nav: bool = _sv1_path_blocked(member, slot_target) or _sv1_wall_nearby(member)
	var in_nav: bool = _sv1_nav_mode.get(member, false)

	if need_nav:
		_sv1_nav_mode[member] = true
		_sv1_nav_exit_timer[member] = 0.0
		return true

	if in_nav:
		var timer: float = _sv1_nav_exit_timer.get(member, 0.0) + delta
		if timer >= _SV1_NAV_EXIT_DELAY_S:
			_sv1_nav_mode[member] = false
			_sv1_nav_exit_timer[member] = 0.0
			return false
		_sv1_nav_exit_timer[member] = timer
		return true

	return false


func _sv1_speed_seek(dist: float) -> float:
	var arrive_r: float = _arrive_distance + _sv1_arrive_extra
	if dist <= arrive_r:
		return 0.0
	var dist_ratio := clampf(dist / maxf(_follower_speed_far_dist, 0.01), 0.0, 1.0)
	var max_speed := lerpf(_follower_move_speed_near, _follower_move_speed, dist_ratio)
	return minf(max_speed, dist * _sv1_seek_gain)


func _sv1_slot_proximity_damping(member_pos: Vector3, slot_target: Vector3) -> float:
	var to_slot := member_pos - slot_target
	to_slot.y = 0.0
	var d := to_slot.length()
	var arrive_r: float = _arrive_distance + _sv1_arrive_extra
	var threshold := arrive_r * 1.5
	if d >= threshold:
		return 1.0
	return lerpf(_sv1_slot_proximity_damping_min, 1.0, d / maxf(threshold, 0.001))


func _sv1_smooth_direction(member: CharacterBody3D, raw_dir: Vector3, delta: float) -> Vector3:
	if raw_dir.length_squared() < 0.001:
		return raw_dir
	var prev: Vector3 = _sv1_prev_dir.get(member, Vector3.ZERO)
	if prev.length_squared() < 0.001:
		_sv1_prev_dir[member] = raw_dir
		return raw_dir
	var blend := 1.0 - exp(-_sv1_dir_smooth_rate * delta)
	var smoothed := prev.slerp(raw_dir, blend)
	_sv1_prev_dir[member] = smoothed
	return smoothed


func _sv1_update_w_goal(member: CharacterBody3D, delta: float) -> float:
	var delay := _reposition_delay_s(member)
	if delay > 0.0:
		_sv1_w_goal[member] = 0.0
		return 0.0
	var current: float = _sv1_w_goal.get(member, 1.0)
	if current < 1.0:
		var ramp_speed := 1.0 / maxf(_sv1_goal_ramp_after_delay_s, 0.001)
		current = minf(1.0, current + ramp_speed * delta)
		_sv1_w_goal[member] = current
		return current
	return 1.0


func _sv1_velocity(
	anchor: CharacterBody3D,
	member: CharacterBody3D,
	slot_target: Vector3,
	anchor_pos: Vector3,
	peer_slot_targets: Dictionary,
	delta: float
) -> Vector3:
	# Tick reposition delay
	var delay_s: float = _reposition_delay_s(member)
	if delay_s > 0.0:
		delay_s = maxf(0.0, delay_s - delta)
		_set_reposition_delay_s(member, delay_s)

	var pos := member.global_position
	var w := _sv1_update_w_goal(member, delta)

	# Compute separation + bypass in a single loop
	var sep_result := _sv1_compute_sep_and_bypass(member, pos, slot_target, anchor, anchor_pos, peer_slot_targets)
	var F_sep: Vector3 = sep_result.F_sep
	var F_bypass: Vector3 = sep_result.F_bypass

	# Slot proximity damping
	F_sep *= _sv1_slot_proximity_damping(pos, slot_target)

	# While engaging, weaken inter-ally separation so a follower can push through
	# the melee clump to reach its target (physics still prevents overlap).
	if _combat_engaging:
		F_sep *= 0.35

	# Clip F_sep against walls
	F_sep = _sv1_clip_walls(F_sep, member)

	# --- DIRECT / NAVMESH mode switch ---
	var use_nav := _sv1_update_nav_mode(member, slot_target, delta)

	var d_goal := Vector3.ZERO
	if w > 0.0:
		if use_nav:
			# NAVMESH mode: follow navmesh path only, zero separation
			member.nav_set_target(slot_target)
			var next_wp: Vector3 = member.nav_get_next_position()
			var to_wp := next_wp - pos
			to_wp.y = 0.0
			if to_wp.length_squared() > 0.01:
				d_goal = to_wp.normalized()
			else:
				# NavMesh has no valid path — fallback to straight line
				var to_slot_fb := slot_target - pos
				to_slot_fb.y = 0.0
				if to_slot_fb.length_squared() > 0.01:
					d_goal = to_slot_fb.normalized()
			F_sep = Vector3.ZERO
			F_bypass = Vector3.ZERO
		else:
			# DIRECT mode: straight line to slot, full separation
			var to_slot := slot_target - pos
			to_slot.y = 0.0
			if to_slot.length_squared() > 0.01:
				d_goal = to_slot.normalized()

	# Compose direction
	var raw_dir := d_goal * w + F_sep + F_bypass
	if raw_dir.length_squared() < 0.0001:
		return Vector3.ZERO
	raw_dir = raw_dir.normalized()

	# Direction smoothing — skip in NAVMESH mode for instant path following
	var dir: Vector3
	if use_nav:
		dir = raw_dir
		_sv1_prev_dir[member] = raw_dir
	else:
		dir = _sv1_smooth_direction(member, raw_dir, delta)

	# Speed — scale max with distance to slot
	var to_slot_h := slot_target - pos
	to_slot_h.y = 0.0
	var dist := to_slot_h.length()
	var speed := _sv1_speed_seek(dist)

	if speed < 0.01:
		# At slot — only separation
		if F_sep.length_squared() > 0.01:
			return _sv1_clip_walls(F_sep, member)
		return Vector3.ZERO

	# Movement noise (direction + speed) — only while travelling
	if _sv1_noise and speed > 0.1:
		var t := float(Engine.get_physics_frames()) / 60.0
		var seed_off: float = _sv1_noise_seed_offset.get(member, 0.0)
		# Direction noise: rotate dir around Y by small angle
		var n_dir := _sv1_noise.get_noise_2d(t * _sv1_noise_dir_freq, seed_off)
		var angle_rad := deg_to_rad(_sv1_noise_dir_deg) * n_dir
		dir = dir.rotated(Vector3.UP, angle_rad)
		# Speed noise: scale speed by ±pct
		var n_spd := _sv1_noise.get_noise_2d(t * _sv1_noise_speed_freq, seed_off + 50.0)
		speed *= (1.0 + _sv1_noise_speed_pct * n_spd)

	var v_target := dir * speed

	# Party cohesion: never travel fast directly AWAY from the slot. Split the
	# velocity into radial (toward/away slot) + tangential, and hard-cap only the
	# away-radial part. Sideways bypass (tangential) is kept at full speed, so
	# go-arounds still work but separation/bypass can't fling a follower out of
	# formation on a direction change.
	# Skip in NAVMESH mode — wall detours legitimately move away from the slot.
	if not use_nav and dist > 0.01:
		var slot_dir := to_slot_h / dist
		var radial: float = v_target.dot(slot_dir)  # + toward slot, - away
		if radial < -_sv1_away_speed_cap:
			var tangential: Vector3 = v_target - slot_dir * radial
			v_target = tangential - slot_dir * _sv1_away_speed_cap

	# Final wall clip (safety net)
	v_target = _sv1_clip_walls(v_target, member)
	return v_target


func _sv1_store_wall_normals(member: CharacterBody3D) -> void:
	var normals: Array = []
	for i in member.get_slide_collision_count():
		var col := member.get_slide_collision(i)
		var n := col.get_normal()
		n.y = 0.0
		if n.length_squared() > 0.01:
			normals.append(n.normalized())
	_sv1_wall_normals[member] = normals


func _sv1_enforce_slot_constraints() -> void:
	var ids := _slot_offsets.keys()
	# Pass 1: enforce minimum distance from anchor origin (0,0,0).
	for id in ids:
		var offset: Vector3 = _slot_offsets[id]
		var h := Vector3(offset.x, 0.0, offset.z)
		var d := h.length()
		if d < _sv1_slot_min_distance_anchor and d > 0.01:
			var corrected := h.normalized() * _sv1_slot_min_distance_anchor
			_slot_offsets[id] = Vector3(corrected.x, offset.y, corrected.z)
			push_warning(
				"[TDC] steering_v1: slot %s too close to anchor (%.2fm < %.2fm), pushed to %.2fm"
				% [id, d, _sv1_slot_min_distance_anchor, _sv1_slot_min_distance_anchor]
			)
	# Pass 2: enforce minimum pairwise distance.
	# Iterate until no violations remain (max 10 passes to avoid infinite loop).
	for _pass in 10:
		var fixed := true
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a: Vector3 = _slot_offsets[ids[i]]
				var b: Vector3 = _slot_offsets[ids[j]]
				var ab := Vector3(b.x - a.x, 0.0, b.z - a.z)
				var dist := ab.length()
				if dist < _sv1_slot_min_distance_pair and dist > 0.01:
					var deficit := _sv1_slot_min_distance_pair - dist
					var push_dir := ab.normalized()
					# Push each slot outward by half the deficit.
					var half := push_dir * (deficit * 0.5)
					_slot_offsets[ids[i]] = a - half
					_slot_offsets[ids[j]] = b + half
					push_warning(
						"[TDC] steering_v1: slot pair %s-%s too close (%.2fm < %.2fm), separated to %.2fm"
						% [ids[i], ids[j], dist, _sv1_slot_min_distance_pair, _sv1_slot_min_distance_pair]
					)
					fixed = false
		if fixed:
			break


func _sync_tank_follow_collision() -> void:
	for member in _members:
		member.set_party_member_collision(true)


func _apply_controlled_move_speeds() -> void:
	for member in _members:
		var ctrl: Node = member.get_node_or_null("Control")
		if ctrl and "move_speed" in ctrl:
			ctrl.set("move_speed", move_speed)
			if _player_accel_mps2 > 0.0:
				ctrl.set("use_accel_model", true)
				ctrl.set("accel_mps2", _player_accel_mps2)
				ctrl.set("decel_mps2", _player_decel_mps2)


func _place_party_at_anchor(world_pos: Vector3) -> void:
	var anchor := _get_anchor()
	var layout_axes := _layout_axes(anchor)
	_update_party_layout_origin(anchor, layout_axes, world_pos)
	for member in _members:
		var member_class_id: String = String(member.get("class_id"))
		member.global_position = _slot_world_target(member_class_id, layout_axes, world_pos.y)
		member.global_position.y = world_pos.y  # feet-on-origin → rest on floor
		member.velocity = Vector3.ZERO

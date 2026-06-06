extends Node3D
## 4-member party — F-001 swap, F-003 formation (bound/unbound smoke). ref: QA-030 §3.2

const PartyCohesion := preload("res://scripts/party/party_cohesion.gd")
const MemberScene := preload("res://scenes/party/party_member.tscn")
const PlayerControl := preload("res://scripts/run/player_controller.gd")

signal controlled_changed(member: CharacterBody3D)
signal cohesion_changed(mode: int)

const CLASS_COLORS: Dictionary = {
	"Tank": Color(0.19, 0.44, 0.80),    # #3070CC Blue
	"DPS": Color(0.13, 0.63, 0.63),     # #20A0A0 Teal
	"Nuker": Color(0.38, 0.25, 0.69),   # #6040B0 Indigo
	"Healer": Color(0.19, 0.63, 0.31),  # #30A050 Green
}

## Role-based mesh scale multiplier (relative to default 1.0)
const CLASS_SCALES: Dictionary = {
	"Tank": 1.25,
	"DPS": 1.0,
	"Nuker": 0.95,
	"Healer": 0.9,
}

@export var move_speed: float = 9.0

var party_in_combat: bool = false
var cohesion_mode: int = PartyCohesion.MODE_BOUND

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
var _sv1_enabled: bool = false

# --- Steering v1 per-member state ---
var _sv1_prev_dir: Dictionary = {}
var _sv1_w_goal: Dictionary = {}
var _sv1_wall_normals: Dictionary = {}
var _sv1_noise: FastNoiseLite
var _sv1_noise_seed_offset: Dictionary = {}


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


func try_swap_to(index: int) -> bool:
	if index < 0 or index >= _members.size():
		return false
	if index == _controlled_index:
		return false
	if not _can_swap():
		print("[TDC] Swap blocked (partyInCombat=%s)" % party_in_combat)
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


func _can_swap() -> bool:
	var run := get_parent().get_node_or_null("RunController")
	if run and run.has_method("can_swap"):
		return run.can_swap()
	return not party_in_combat


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
## v1: always use smoothed _formation_forward to prevent slot target jumps on brief taps.
## v0: raw velocity override for responsiveness (inherit_velocity dampened the jump).
func _layout_axes(anchor: CharacterBody3D) -> Dictionary:
	var forward := _slot_formation_forward()
	if not _sv1_enabled:
		var vel := _anchor_velocity_h(anchor)
		if vel.length() >= _formation_min_speed:
			forward = vel
	forward = forward.normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	return {"forward": forward, "right": right}


func _tank_steer_axes(anchor: CharacterBody3D) -> Dictionary:
	var axes := _layout_axes(anchor)
	var motion := _anchor_motion_forward(anchor)
	if motion.length_squared() > 0.01 and motion.dot(axes.forward) >= _tank_motion_forward_dot:
		if axes.forward.dot(motion) >= _tank_motion_forward_dot:
			axes.forward = motion
			axes.right = axes.forward.cross(Vector3.UP).normalized()
	return axes


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
		_sv1_enabled = true
		_sv1_sep_zero_radius = float(sv1.get("sep_zero_radius_m", 1.0))
		_sv1_sep_zero_anchor_extra = float(sv1.get("sep_zero_anchor_extra_m", 0.2))
		_sv1_sep_touch_radius = float(sv1.get("sep_touch_radius_m", 0.52))
		_sv1_sep_urgency_power = float(sv1.get("sep_urgency_power", 2.2))
		_sv1_sep_strength = float(sv1.get("sep_strength", 7.0))
		_sv1_sep_max_mps = float(sv1.get("sep_max_mps", 9.0))
		_sv1_sep_deadzone_ratio = float(sv1.get("sep_deadzone_ratio", 0.85))
		_sv1_collinear_opposing_dot = float(sv1.get("collinear_opposing_dot", -0.65))
		_sv1_bypass_strength = float(sv1.get("bypass_strength", 5.5))
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
	if _sv1_enabled:
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
			CLASS_COLORS.get(class_id, Color.GRAY),
			_collision_radius,
			_collision_height,
			CLASS_SCALES.get(class_id, 1.0)
		)
		var ctrl := PlayerControl.new()
		ctrl.name = "Control"
		member.add_child(ctrl)
		ctrl.set_physics_process(false)
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
		if not _sv1_enabled and member.class_id == "Tank":
			continue
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
	if party_in_combat:
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
	var peer_slot_targets: Dictionary = {}
	for m in _members:
		var cid: String = String(m.get("class_id"))
		peer_slot_targets[m] = _slot_world_target(cid, layout_axes, anchor_pos.y)
	if _sv1_enabled:
		_sv1_update_follow(anchor, anchor_pos, layout_axes, peer_slot_targets, delta)
	else:
		_v0_update_follow(anchor, anchor_pos, layout_axes, peer_slot_targets, delta)



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
	# Pass 1: compute all velocities (no position changes)
	var planned: Dictionary = {}
	for member in _members:
		if member == anchor:
			planned[member] = Vector3.ZERO
			continue
		if member.is_controlled():
			continue
		var slot_target: Vector3 = peer_slot_targets[member]
		planned[member] = _sv1_velocity(anchor, member, slot_target, anchor_pos, peer_slot_targets, delta)
	# Pass 2: apply all velocities (anchor is handled by player_controller)
	for member in _members:
		if member == anchor or member.is_controlled():
			continue
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
			if along > 0.0 and along < d_goal_len:
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

	# Clip F_sep against walls
	F_sep = _sv1_clip_walls(F_sep, member)

	# Goal direction (weighted by w_goal)
	var d_goal := Vector3.ZERO
	if w > 0.0:
		var to_slot := slot_target - pos
		to_slot.y = 0.0
		if to_slot.length_squared() > 0.01:
			d_goal = to_slot.normalized()

	# Compose direction
	var raw_dir := d_goal * w + F_sep + F_bypass
	if raw_dir.length_squared() < 0.0001:
		return Vector3.ZERO
	raw_dir = raw_dir.normalized()

	# Direction smoothing
	var dir := _sv1_smooth_direction(member, raw_dir, delta)

	# Speed — scale max with distance to slot
	var to_slot_h := slot_target - pos
	to_slot_h.y = 0.0
	var dist := to_slot_h.length()
	var speed := _sv1_speed_seek(dist)

	if speed < 0.01:
		# At slot — only separation force applies
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

	# Dampen speed when moving away from slot (party cohesion)
	if dist > 0.01:
		var slot_dir := to_slot_h / dist
		var away_dot := -dir.dot(slot_dir)  # positive when moving away from slot
		if away_dot > 0.0:
			speed *= 1.0 - (away_dot * 0.75)

	var v_target := dir * speed

	# Final wall clip
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


# ============================================================================
# v0 follow model (deprecated — kept for rollback reference)
# ============================================================================


func _v0_update_follow(
	anchor: CharacterBody3D,
	anchor_pos: Vector3,
	layout_axes: Dictionary,
	peer_slot_targets: Dictionary,
	delta: float
) -> void:
	var anchor_moving := _anchor_velocity_h(anchor).length() >= _formation_min_speed
	for member in _members:
		if member == anchor:
			member.velocity = Vector3.ZERO
			member.move_and_slide()
			continue
		if member.is_controlled():
			continue
		var class_id: String = String(member.get("class_id"))
		var slot_offset: Vector3 = _slot_offsets.get(class_id, Vector3.ZERO)
		var slot_target: Vector3 = peer_slot_targets[member]
		var steer_axes: Dictionary = (
			_tank_steer_axes(anchor) if class_id == "Tank" else layout_axes
		)
		member.velocity = _v0_follower_velocity(
			anchor, member, slot_target, anchor_pos, steer_axes,
			slot_offset, anchor_moving, peer_slot_targets, delta,
			class_id == "Tank"
		)
		member.move_and_slide()


# --- v0 Follow model: v = compose(inherit, slot_pull, spacing); spacing wins on speed cap ---


func _min_clearance_radius(anchor_moving: bool) -> float:
	var base: float = maxf(_party_separation_radius, _preferred_anchor_distance)
	if anchor_moving:
		return base + _anchor_path_clearance_extra_m
	return base


func _spacing_cap(anchor_moving: bool, boost: float) -> float:
	var cap: float = (
		_party_separation_max_mps_moving if anchor_moving else _party_separation_max_mps
	)
	return cap * minf(boost, 2.2)


func _separation_boost(member: CharacterBody3D, anchor_moving: bool) -> float:
	if anchor_moving:
		var moving_boost: float = _party_separation_boost_moving
		if _reposition_delay_s(member) > 0.0:
			moving_boost = maxf(moving_boost, _party_separation_boost_moving * 1.15)
		return moving_boost
	var stat_boost: float = _party_separation_stationary_boost
	if _reposition_delay_s(member) > 0.0:
		stat_boost = maxf(stat_boost, _party_separation_stationary_boost * 1.2)
	return stat_boost


func _repel_from_point(
	member_pos: Vector3,
	point: Vector3,
	radius: float,
	weight: float,
	boost: float
) -> Vector3:
	var offset := member_pos - point
	offset.y = 0.0
	var dist := offset.length()
	if dist >= radius or dist < 0.05:
		return Vector3.ZERO
	var urgency: float = 1.0 - dist / radius
	urgency = urgency * urgency
	return offset.normalized() * _party_separation_strength * urgency * weight * boost


func _spacing_velocity(
	member: CharacterBody3D,
	anchor_pos: Vector3,
	anchor_moving: bool,
	peer_slot_targets: Dictionary,
	anchor_clearance_radius: float
) -> Vector3:
	var member_pos := member.global_position
	var boost: float = _separation_boost(member, anchor_moving)
	var radius: float = _min_clearance_radius(anchor_moving)
	var push := Vector3.ZERO
	push += _repel_from_point(
		member_pos, anchor_pos, maxf(radius, anchor_clearance_radius), 1.0, boost
	)
	for other in _members:
		if other == member:
			continue
		push += _repel_from_point(member_pos, other.global_position, radius, 1.0, boost)
	if not anchor_moving:
		for other in _members:
			if other == member or not peer_slot_targets.has(other):
				continue
			push += _repel_from_point(
				member_pos,
				peer_slot_targets[other],
				radius,
				_party_slot_target_separation_blend,
				boost
			)
	return push.limit_length(_spacing_cap(anchor_moving, boost))


func _path_requires_flank(member_pos: Vector3, slot_target: Vector3, anchor_pos: Vector3) -> bool:
	var delta := slot_target - member_pos
	delta.y = 0.0
	var seg_len := delta.length()
	if seg_len < 0.25:
		return false
	var dir: Vector3 = delta / seg_len
	var to_anchor := anchor_pos - member_pos
	to_anchor.y = 0.0
	var along: float = to_anchor.dot(dir)
	if along < -0.15 or along > seg_len + 0.15:
		return false
	var perp: Vector3 = to_anchor - dir * along
	if perp.length() < _min_clearance_radius(true):
		return true
	if to_anchor.length() >= _min_clearance_radius(true):
		return false
	var to_target := slot_target - member_pos
	to_target.y = 0.0
	if to_target.length() < 0.2:
		return false
	return to_anchor.normalized().dot(to_target.normalized()) > 0.12


func _pick_less_crowded_side(member: CharacterBody3D, from_pos: Vector3, axes: Dictionary) -> float:
	var right_axis: Vector3 = _axes_right(axes)
	var right_count := 0
	var left_count := 0
	for other in _members:
		if other == member:
			continue
		var side: float = (other.global_position - from_pos).dot(right_axis)
		if side > 0.25:
			right_count += 1
		elif side < -0.25:
			left_count += 1
	return 1.0 if left_count <= right_count else -1.0


func _pick_flank_sign(
	member: CharacterBody3D,
	member_pos: Vector3,
	anchor_pos: Vector3,
	axes: Dictionary
) -> float:
	var rel := member_pos - anchor_pos
	rel.y = 0.0
	var side: float = signf(rel.dot(_axes_right(axes)))
	if absf(side) > 0.01:
		return side
	return _pick_less_crowded_side(member, member_pos, axes)


func _steer_goal(
	member: CharacterBody3D,
	member_pos: Vector3,
	slot_target: Vector3,
	anchor_pos: Vector3,
	axes: Dictionary
) -> Vector3:
	if not _path_requires_flank(member_pos, slot_target, anchor_pos):
		return slot_target
	var flank_sign: float = _pick_flank_sign(member, member_pos, anchor_pos, axes)
	return anchor_pos + _axes_right(axes) * flank_sign * _min_clearance_radius(true)


func _slot_pull_velocity(
	member_pos: Vector3,
	goal: Vector3,
	max_speed: float,
	gain: float,
	slot_lateral_x: float,
	axes: Dictionary
) -> Vector3:
	var to_goal := goal - member_pos
	to_goal.y = 0.0
	var dist := to_goal.length()
	if dist < 0.05:
		return Vector3.ZERO
	var pull: Vector3 = to_goal.normalized() * minf(max_speed, dist * gain)
	if absf(slot_lateral_x) > 0.05:
		var lateral: Vector3 = (
			_axes_right(axes) * signf(slot_lateral_x) * max_speed * _lateral_approach_blend
		)
		pull = pull.lerp(pull + lateral, _lateral_approach_blend * 0.5)
	return pull


func _inherit_velocity(
	anchor_vel: Vector3,
	member_pos: Vector3,
	goal: Vector3,
	anchor_moving: bool,
	min_dot: float
) -> Vector3:
	if not anchor_moving or anchor_vel.length() < 0.1:
		return Vector3.ZERO
	var to_goal := goal - member_pos
	to_goal.y = 0.0
	if to_goal.length() < 0.2:
		return anchor_vel
	if anchor_vel.normalized().dot(to_goal.normalized()) < min_dot:
		return Vector3.ZERO
	return anchor_vel


func _compose_follow_velocity(
	inherit: Vector3,
	slot_pull: Vector3,
	spacing: Vector3,
	max_speed: float
) -> Vector3:
	var vel := inherit + slot_pull + spacing
	if vel.length() <= max_speed:
		return vel
	var spacing_len := spacing.length()
	if spacing_len >= max_speed:
		return spacing.normalized() * max_speed
	var pull_budget: float = maxf(0.0, max_speed - spacing_len)
	var pull := slot_pull
	if pull.length() > pull_budget:
		pull = pull.normalized() * pull_budget
	vel = inherit + pull + spacing
	if vel.length() > max_speed:
		vel = vel.normalized() * max_speed
	return vel


func _tank_orbit_extra(anchor: CharacterBody3D, member: CharacterBody3D, axes: Dictionary) -> Vector3:
	if not _needs_tank_reversal_steering(anchor, member, axes):
		return Vector3.ZERO
	return _tank_reversal_orbit(anchor, member, axes)


func _v0_follower_velocity(
	anchor: CharacterBody3D,
	member: CharacterBody3D,
	slot_target: Vector3,
	anchor_pos: Vector3,
	axes: Dictionary,
	slot_offset: Vector3,
	anchor_moving: bool,
	peer_slot_targets: Dictionary,
	delta: float,
	is_tank: bool
) -> Vector3:
	var delay_s: float = _reposition_delay_s(member)
	if delay_s > 0.0:
		delay_s = maxf(0.0, delay_s - delta)
		_set_reposition_delay_s(member, delay_s)
		if delay_s > 0.0:
			var anchor_r: float = (
				_tank_preferred_anchor_distance if is_tank else _preferred_anchor_distance
			)
			return _spacing_velocity(
				member, anchor_pos, anchor_moving, peer_slot_targets, anchor_r
			)
	var member_pos := member.global_position
	var anchor_vel := _anchor_velocity_h(anchor)
	var max_speed: float = _follower_move_speed
	var arrive: float = _arrive_distance + _slot_arrive_extra
	var anchor_clearance: float = (
		_tank_preferred_anchor_distance if is_tank else _preferred_anchor_distance
	)
	var spacing := _spacing_velocity(
		member, anchor_pos, anchor_moving, peer_slot_targets, anchor_clearance
	)
	if is_tank:
		spacing += _tank_orbit_extra(anchor, member, axes)
	var goal := _steer_goal(member, member_pos, slot_target, anchor_pos, axes)
	var inherit_min_dot: float = _tank_inherit_min_dot if is_tank else 0.2
	var inherit := _inherit_velocity(anchor_vel, member_pos, goal, anchor_moving, inherit_min_dot)
	var speed_cap: float = maxf(max_speed, anchor_vel.length() + 1.0) if is_tank else max_speed
	var dist_slot := (slot_target - member_pos).length()
	if is_tank and inherit.length() > 0.1 and dist_slot <= arrive + 1.2:
		var to_goal := goal - member_pos
		to_goal.y = 0.0
		var fix := Vector3.ZERO
		if to_goal.length() > 0.12:
			fix = to_goal.normalized() * minf(2.5, to_goal.length() * 1.6)
		return _compose_follow_velocity(inherit, fix, spacing, speed_cap)
	if dist_slot <= arrive:
		return _compose_follow_velocity(inherit, Vector3.ZERO, spacing, speed_cap)
	var gain: float = _tank_correction_gain if is_tank else 4.0
	var slot_pull := _slot_pull_velocity(
		member_pos, goal, max_speed, gain, slot_offset.x, axes
	)
	if anchor_moving and dist_slot > arrive:
		var need_close: float = maxf(0.0, anchor_vel.length() + 1.0 - slot_pull.length())
		if need_close > 0.0:
			var to_slot := slot_target - member_pos
			to_slot.y = 0.0
			if to_slot.length() > 0.05:
				slot_pull += to_slot.normalized() * minf(max_speed - inherit.length(), need_close)
	return _compose_follow_velocity(inherit, slot_pull, spacing, speed_cap)


func _needs_tank_reversal_steering(
	anchor: CharacterBody3D,
	member: CharacterBody3D,
	axes: Dictionary
) -> bool:
	var vel := _anchor_velocity_h(anchor)
	if vel.length() >= _formation_min_speed and vel.normalized().dot(_formation_forward) < 0.0:
		return false
	var motion := _anchor_motion_forward(anchor)
	if motion.dot(_formation_forward) < 0.0:
		return false
	if _formation_forward.dot(motion) < 0.4:
		return true
	var rel := member.global_position - anchor.global_position
	rel.y = 0.0
	if rel.length() < 0.5:
		return false
	return rel.normalized().dot(_axes_forward(axes)) < 0.25


func _tank_reversal_orbit(
	anchor: CharacterBody3D,
	member: CharacterBody3D,
	axes: Dictionary
) -> Vector3:
	var to_anchor := member.global_position - anchor.global_position
	to_anchor.y = 0.0
	var dist := to_anchor.length()
	if dist >= _tank_reversal_clear_radius or dist < 0.05:
		return Vector3.ZERO
	var tangent: Vector3 = _axes_forward(axes).cross(Vector3.UP).normalized()
	var flank: float = signf(to_anchor.dot(tangent))
	if absf(flank) < 0.01:
		flank = 1.0
	var urgency: float = 1.0 - dist / _tank_reversal_clear_radius
	return tangent * flank * _tank_reversal_orbit_strength * urgency

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
		member.global_position.y = world_pos.y + 1.2
		member.velocity = Vector3.ZERO

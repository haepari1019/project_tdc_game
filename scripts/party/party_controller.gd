extends Node3D
## 4-member party — F-001 swap, F-003 formation (bound/unbound smoke). ref: QA-030 §3.2

const PartyCohesion := preload("res://scripts/party/party_cohesion.gd")
const MemberScene := preload("res://scenes/party/party_member.tscn")
const PlayerControl := preload("res://scripts/run/controllers/player_controller.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const CombatPositioning := preload("res://scripts/party/combat_positioning.gd")
const MiaController := preload("res://scripts/party/mia_controller.gd")

signal controlled_changed(member: CharacterBody3D)
signal cohesion_changed(mode: int)
signal formation_priority_changed(on: bool)
signal party_alert(text: String, level: int)  # UI-006 separation/MIA warning (0=warn, 1=MIA)
@warning_ignore("unused_signal")  # emitted cross-class (mia_controller) → connected in dungeon_run
signal pip_targets(members: Array)             # UI-006 §7 PIP camera targets (empty = close)

@export var move_speed: float = 9.0

var _party_damaged: bool = false  ## latch: a party member was hit (formation-break trigger; cleared on disengage)
var _tank_engaged: bool = false   ## latch: tank landed its first hit (opens 2nd-line DPS/Nuker engage; cleared on disengage)
const OVERDRIVE_OOC_RESET_S := 5.0   ## DPS 「초월」: 비전투가 이 시간 유지되면 게이지 초기화
var _ooc_timer: Timer = null         ## 비전투 카운트다운(one-shot) — 재교전 시 정지
var cohesion_mode: int = PartyCohesion.MODE_BOUND
## Formation-priority toggle. OFF (default) = combat priority: followers may
## break formation to engage — but ONLY after contact (party was hit, or an enemy
## reached an ally's basic range; see CombatPositioning.enemy_in_party_basic_range), NOT on mere
## encounter spawn or enemy aggro. ON = hold slots always; the player keeps full
## positional command (regroup/reposition) without anyone peeling off. Either way
## members auto-attack foes inside basic_range_m.
var _formation_priority: bool = false
var _combat_engaging: bool = false
## Combat goal-point logic (child node): engage targets + healer positioning. DEBT-GOD.
var _combat_pos: CombatPositioning
var _mia: MiaController

var _members: Array[CharacterBody3D] = []
var _controlled_index: int = 0
var _leader_index: int = 0
## F-003 §3.2: Party Subleader — backup anchor in 파티비결속 (must differ from leader;
## UI-005 designation deferred → defaults to the first non-leader member).
var _sub_leader_index: int = 1
## F-003 §3.0.4: the 파티비결속 **Formation Rally Anchor** — where non-controlled members
## form up each frame. Per the separation model, the *Command Holder* (= leader; the
## Move-Ping/MIA target) is stable, but this rally anchor steps aside to a stand-in while
## the leader is out (controlled=scouting, or walking back) and reverts once it returns.
## (Ping/MIA aren't implemented yet, so holder==leader is implicit here.) -1 until resolved.
var _command_holder_index: int = -1
## Leader counts as "returned to formation" once within this of the stand-in anchor →
## the anchor reverts to the leader (so it doesn't snap the party). ~slot offset + margin.
const LEADER_RETURN_RADIUS_M := 5.0
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
# (DEBT-V0 정리 2026-06-10: 죽은 v0 스티어링 config 17종 제거 — tank_follow 보정/리버설,
#  v0 separation, preferred_anchor/lateral_approach 등. sv1은 `_sv1_*` config 사용.)
var _swap_reposition_delay_min: float = 0.05
var _swap_reposition_delay_max: float = 0.26
var _formation_shift_counter: int = 0
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
	_combat_pos = CombatPositioning.new()
	add_child(_combat_pos)
	_combat_pos.setup(self)
	_spawn_party_from_data()
	_mia = MiaController.new()  # MIA / separation-leash subsystem (DEBT-GOD extraction)
	add_child(_mia)
	_mia.setup(self)


func _physics_process(delta: float) -> void:
	_update_command_holder()  # 비결속 앵커: leader 정본 + 정찰/복귀 시 임시 stand-in
	_update_formation_forward(delta)
	_update_formation_follow(delta)
	_mia.tick(delta)


func get_controlled() -> CharacterBody3D:
	if _members.is_empty():
		return null
	return _members[_controlled_index]


## A controlled member going MIA → force control to the anchor (or any living non-MIA
## member), so the player isn't left driving a stranded character. F-003 §3.3.1.
func force_control_off(member: CharacterBody3D) -> void:
	var target := -1
	if _member_valid(_command_holder_index):
		var h: CharacterBody3D = _members[_command_holder_index]
		if h != member and h.is_alive() and not h.is_mia():
			target = _command_holder_index
	if target < 0:
		for i in _members.size():
			var c: CharacterBody3D = _members[i]
			if c != member and c.is_alive() and not c.is_mia():
				target = i
				break
	if target >= 0:
		_set_controlled_index(target)
		party_alert.emit("%s MIA — 조작 전환 → %s" % [member.class_id, _members[target].class_id], 1)
		print("[TDC] %s went MIA (leash) — control forced to the anchor" % member.class_id)


## Read accessors for MiaController (the MIA subsystem pulls party context). ref: DEBT-GOD.
func get_anchor() -> CharacterBody3D:
	return _get_anchor()


func is_unbound() -> bool:
	return cohesion_mode == PartyCohesion.MODE_UNBOUND


func is_combat_engaging() -> bool:
	return _combat_engaging


func get_member(index: int) -> CharacterBody3D:
	if index < 0 or index >= _members.size():
		return null
	return _members[index]


func get_members() -> Array:
	return _members.duplicate()


## Subscribe to the combat-state owner (CombatController). ref: DEBT-CPL-COMBAT.
func bind_combat(combat: Node) -> void:
	combat.party_damaged.connect(_on_party_damaged)
	combat.engagement_changed.connect(_on_engagement_changed)
	combat.tank_engaged.connect(_on_tank_engaged)
	# 비전투 5초 → DPS 초월 게이지 초기화. one-shot 타이머(전투 종료 시 시작 / 재교전 시 정지).
	_ooc_timer = Timer.new()
	_ooc_timer.one_shot = true
	_ooc_timer.wait_time = OVERDRIVE_OOC_RESET_S
	_ooc_timer.timeout.connect(_reset_overdrive_all)
	add_child(_ooc_timer)


## 노드 → 파티 인덱스(좌클릭 스왑용, dungeon_run._select_party_under_mouse). 미소속이면 -1.
func index_of(member: Node) -> int:
	return _members.find(member)


func _on_party_damaged() -> void:
	_party_damaged = true


func _on_tank_engaged() -> void:
	_tank_engaged = true


## partyInCombat → false (all squads disengaged) clears the damage latch so
## followers stop engaging and re-form. Re-arms on the next hit.
func _on_engagement_changed(engaged: bool) -> void:
	for m in _members:                                   # 전투 템포 A: 전투 시 이동 ×2/3, 비전투 스프린트
		if is_instance_valid(m):
			m.combat_slowed = engaged
	if not engaged:
		_party_damaged = false
		_tank_engaged = false
		if _ooc_timer != null:
			_ooc_timer.start()   # 비전투 진입 → 5초 뒤 초월 초기화(그 전에 재교전하면 정지)
	elif _ooc_timer != null:
		_ooc_timer.stop()        # 재교전 → 초기화 취소(게이지 유지)


## 비전투 5초 경과 → 전 멤버 초월 게이지 초기화(초월 없는 멤버는 no-op).
func _reset_overdrive_all() -> void:
	for m in _members:
		if m != null and is_instance_valid(m) and m.has_method("overdrive_reset"):
			m.overdrive_reset()


func try_swap_to(index: int) -> bool:
	if index < 0 or index >= _members.size():
		return false
	if index == _controlled_index:
		return false
	if not _members[index].is_alive():
		print("[TDC] Swap ignored (target downed)")  # can't control a downed member
		return false
	if _members[index].has_method("is_mia") and _members[index].is_mia():
		print("[TDC] Swap ignored (target MIA — cut off by a hazard)")  # F-001 §3.6
		return false
	if not _can_swap():
		print("[TDC] Swap ignored (control locked)")  # F-001 §3.6 Control Lock / MIA
		return false
	_set_controlled_index(index)
	return true


func toggle_cohesion_mode() -> void:
	if cohesion_mode == PartyCohesion.MODE_BOUND:
		cohesion_mode = PartyCohesion.MODE_UNBOUND
		_update_command_holder()  # F-003 §3.4: pick the active anchor on entry
	else:
		cohesion_mode = PartyCohesion.MODE_BOUND
	cohesion_changed.emit(cohesion_mode)
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
	var prev_controlled := _controlled_index  # the char that just detached (now far)
	_controlled_index = index
	# F-003 §3.4: on swap while 파티비결속, re-evaluate the anchor immediately (it's also
	# maintained per-frame). The newly controlled char can't be the anchor, and the char
	# that just detached must not become the stand-in (the party would chase it); if the
	# leader is the one out, a stand-in holds until the leader walks back into formation.
	if cohesion_mode == PartyCohesion.MODE_UNBOUND:
		_update_command_holder(prev_controlled)
	_apply_controlled_move_speeds()
	_queue_swap_reposition_delays()
	var member := _members[index]
	controlled_changed.emit(member)
	print("[TDC] Controlled -> %s (%s)" % [member.identity_skill_id, member.class_id])


func _get_anchor() -> CharacterBody3D:
	if cohesion_mode == PartyCohesion.MODE_UNBOUND:
		# Re-resolve if the holder died/MIA, or somehow ended up the controlled char
		# (the controlled char must be free to move, so it can't also be the anchor).
		if not _member_valid(_command_holder_index) or _command_holder_index == _controlled_index:
			_update_command_holder()
		if _member_valid(_command_holder_index):
			return _members[_command_holder_index]
	return get_controlled()


## Valid as a command holder / rally anchor / stand-in. A MIA member is stranded, so it
## can NEVER be the anchor — else the rally point drifts onto a cut-off char (tangle).
func _member_valid(i: int) -> bool:
	return i >= 0 and i < _members.size() and is_instance_valid(_members[i]) \
			and (not _members[i].has_method("is_alive") or _members[i].is_alive()) \
			and not (_members[i].has_method("is_mia") and _members[i].is_mia())


## F-003 §3.4: maintain the Command Holder (Active Anchor) for 파티비결속, re-evaluated
## each frame. The LEADER is the canonical holder — the rally point the party forms
## around, and the future Move-Ping target. It only steps aside while it's "out":
##  • Leader controlled (scouting) → a stand-in holds so the party keeps its position.
##  • Leader released but still walking back → KEEP the stand-in (don't snap the party to
##    the leader's far position); the leader rejoins as a follower.
##  • Leader back in formation (within LEADER_RETURN_RADIUS_M) → hand the anchor BACK to
##    the leader. So the anchor doesn't drift to an arbitrary member — it returns home.
## `avoid_scout` (set on swap = the member that just detached) is kept out of the
## stand-in pick so the party doesn't rally on a char that just ran off.
func _update_command_holder(avoid_scout: int = -1) -> void:
	if cohesion_mode != PartyCohesion.MODE_UNBOUND:
		return
	var leader_free := _member_valid(_leader_index) and _leader_index != _controlled_index
	if leader_free and _leader_returned():
		_command_holder_index = _leader_index  # leader back & free → it's the anchor again
		return
	# Leader is scouting or returning → hold a stand-in. Keep the current one if it's
	# still a valid, non-controlled, non-leader member (don't bounce the rally point).
	if _member_valid(_command_holder_index) \
			and _command_holder_index != _controlled_index \
			and _command_holder_index != _leader_index:
		return
	# Pick a stand-in: exclude the leader (scouting/returning) AND the just-detached
	# scout (far away). Fall back to allowing each if there's no other valid member.
	var idx := _pick_command_holder(_leader_index, avoid_scout)
	if idx < 0:
		idx = _pick_command_holder(_leader_index)  # no spare → allow the just-detached
	if idx < 0:
		idx = _pick_command_holder(-1)             # tiny party → allow the leader too
	if idx < 0:
		# No valid (non-MIA) stand-in. If the others are MIA (stranded, not dead), STAY
		# unbound — _get_anchor() falls back to the controlled char so the leash keeps the
		# MIA members held; switching to bound drops the leash and auto-rejoins everyone.
		if not _has_living_noncontrolled():
			cohesion_mode = PartyCohesion.MODE_BOUND  # §3.4 #4 — no living member to anchor
	else:
		_command_holder_index = idx


## Leader has walked back into formation? True when it's already the anchor, or within
## return range of the current stand-in anchor (so the hand-back doesn't snap the party).
func _leader_returned() -> bool:
	if not _member_valid(_command_holder_index) or _command_holder_index == _leader_index:
		return true
	var d: Vector3 = _members[_leader_index].global_position - _members[_command_holder_index].global_position
	d.y = 0.0
	return d.length() <= LEADER_RETURN_RADIUS_M


## A valid anchor that is none of: the controlled char, `avoid_a`, `avoid_b`. Prefer
## leader, then subleader, then any member by index. -1 if none.
func _pick_command_holder(avoid_a: int, avoid_b: int = -1) -> int:
	for idx in [_leader_index, _sub_leader_index]:
		if idx != _controlled_index and idx != avoid_a and idx != avoid_b and _member_valid(idx):
			return idx
	for i in _members.size():
		if i != _controlled_index and i != avoid_a and i != avoid_b and _member_valid(i):
			return i
	return -1


## Any non-controlled member still alive? MIA counts as alive (stranded, not dead) — so
## an all-MIA party keeps a living member and stays unbound (leash holds the MIA chars).
func _has_living_noncontrolled() -> bool:
	for i in _members.size():
		if i == _controlled_index:
			continue
		var mm: CharacterBody3D = _members[i]
		if is_instance_valid(mm) and (not mm.has_method("is_alive") or mm.is_alive()):
			return true
	return false


## Any living Tank in the party? Gate fallback — if the tank is down, dealers fight freely.
func _any_living_tank() -> bool:
	for m in _members:
		if is_instance_valid(m) and String(m.get("class_id")) == "Tank" \
				and (not m.has_method("is_alive") or m.is_alive()):
			return true
	return false


func _anchor_velocity_h(anchor: CharacterBody3D) -> Vector3:
	return Vector3(anchor.velocity.x, 0.0, anchor.velocity.z)


## Followers / non-controlled anchor won't walk INTO an active fatal zone — strip the
## velocity component crossing the boundary so they hold at the edge (F-004 Fatal
## avoidance). The controlled member is player-driven and NOT clamped (player may enter).
func _clamp_fatal(member: CharacterBody3D, delta: float) -> void:
	const STANDOFF := 1.6  # hold this far OUTSIDE the lethal edge — no edge-riding bleed
	const FLEE_SPEED := 4.5  # gentle bounded back-off (never a launch)
	var pos := member.global_position
	for z in get_tree().get_nodes_in_group("fatal_zone"):
		if not z.is_active():
			continue
		var to_c: Vector3 = z.global_position - pos
		to_c.y = 0.0
		var dist := to_c.length()
		if dist < 0.01:
			continue
		var n := to_c / dist                       # unit vector toward the zone center
		var keep: float = z.radius + STANDOFF
		if dist < keep:
			# inside the stand-off band — OVERRIDE with a gentle outward drift that eases to
			# zero at the ring, so the follower settles off the edge (no launch, no oscillation,
			# and the seek's up-to-14 m/s can't compound into an eject).
			var t := clampf((keep - dist) / STANDOFF, 0.0, 1.0)
			member.velocity = -n * (FLEE_SPEED * t)
		elif z.contains_point(pos + member.velocity * delta, STANDOFF):
			var into := member.velocity.dot(n)
			if into > 0.0:
				member.velocity -= n * into  # about to enter the band — strip the inward component


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


## Formation slot offset for a class (F-003 / UI-005 — deployment editor reads/writes these).
func get_slot_offset(class_id: String) -> Vector3:
	return _slot_offsets.get(class_id, Vector3.ZERO)


func set_slot_offset(class_id: String, offset: Vector3) -> void:
	_slot_offsets[class_id] = offset


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
	# (DEBT-V0: formation.json "tank_follow" 블록은 죽은 v0 보정 config라 로드 안 함.)
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
		_sv1_slot_min_distance_pair = float(sv1.get("slot_min_distance_pair_m", 2.5)) * UnitVisuals.UNIT_SCALE
		_sv1_slot_min_distance_anchor = float(sv1.get("slot_min_distance_anchor_m", 2.0)) * UnitVisuals.UNIT_SCALE
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
		_swap_reposition_delay_min = float(variation.get("swap_reposition_start_delay_min_s", 0.05))
		_swap_reposition_delay_max = float(variation.get("swap_reposition_start_delay_max_s", 0.26))
	var col = doc.get("collision", {})
	if typeof(col) == TYPE_DICTIONARY:
		_collision_radius = float(col.get("capsule_radius_m", 0.26)) * UnitVisuals.UNIT_SCALE
		_collision_height = float(col.get("capsule_height_m", 1.15)) * UnitVisuals.UNIT_SCALE
	for slot in doc.get("slots", []):
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		var cid := String(slot.get("class_id", ""))
		var off: Array = slot.get("offset", [0, 0, 0])
		if off.size() >= 3:
			# Same UNIT_SCALE as the mesh — keeps the party proportional when units shrink.
			_slot_offsets[cid] = Vector3(float(off[0]), float(off[1]), float(off[2])) * UnitVisuals.UNIT_SCALE
	_sv1_enforce_slot_constraints()


func _spawn_party_from_data() -> void:
	# Only STARTER identities (one per class) become party members. The other identities are
	# gear-selectable alternatives — Backpack.equipped overrides each member's worn gear via
	# apply_to_party after spawn (F-008 §3.7). So the party is always the 4 starter classes.
	var rows: Array = []
	for row in Slice01Data.get_identity_rows():
		if not Slice01Data.get_starter_gear_for_identity(String(row.get("identity_skill_id", ""))).is_empty():
			rows.append(row)
	_leader_index = 0
	for i in rows.size():
		var row: Dictionary = rows[i]
		if String(row.get("class_id", "")) == "Tank":
			_leader_index = i
			break
	# Default subleader = first member that isn't the leader (UI-005 designation TBD).
	_sub_leader_index = (_leader_index + 1) % maxi(1, rows.size())
	_command_holder_index = _leader_index
	for i in rows.size():
		var row: Dictionary = rows[i]
		var class_id := String(row.get("class_id", ""))
		# Identity is gear-bound (F-008 §3.7): resolve the starter gear for this
		# identity and let the member derive its identity from the equipped gear.
		var gear: Dictionary = Slice01Data.get_starter_gear_for_identity(String(row.get("identity_skill_id", "")))
		if gear.is_empty():
			push_error("[TDC] No starter gear for identity '%s'" % row.get("identity_skill_id", ""))
			continue
		var member: CharacterBody3D = MemberScene.instantiate()
		$Members.add_child(member)
		member.setup(
			gear,
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


## Formation front follows the CAMERA (screen-up), not movement direction — so
## backpedal (S) never flips the formation and a 180° turn is a smooth camera
## rotation. Replaces the old movement-reversal flip + commit-override machinery.
func _update_formation_forward(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return
	fwd = fwd.normalized()
	if _formation_forward.length_squared() < 0.01:
		_formation_forward = fwd
	else:
		var blend: float = 1.0 - exp(-_formation_forward_smooth * delta)
		_formation_forward = _formation_forward.lerp(fwd, blend).normalized()
	_last_formation_forward = _formation_forward


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
	# 전투우선 followers leave their slots to fight ONLY after contact — the party
	# has been hit (_party_damaged), or an enemy reached an ally's basic range.
	# Before that everyone holds their slot so nobody darts across the room toward a
	# far enemy. Enemy perception/aggro does NOT trigger this (slot-break ≠ combat).
	# 진형우선 forces hold regardless (the player's regroup/command). ref: F-004.
	_combat_engaging = false
	if not _formation_priority and _combat_pos.has_live_enemies():
		_combat_engaging = _party_damaged or _combat_pos.enemy_in_party_basic_range()
	var tank_alive := _any_living_tank()
	var peer_slot_targets: Dictionary = {}
	for m in _members:
		var cid: String = String(m.get("class_id"))
		var slot_target: Vector3 = _slot_world_target(cid, layout_axes, anchor_pos.y)
		var engage: bool = _combat_engaging and m != anchor and not m.is_controlled()
		# 2nd-line dealers (DPS/Nuker) don't break formation to engage until the tank has landed
		# its first hit (unless no tank is alive). Keeps them behind the front line. ref: 탱커 선공.
		if engage and not _tank_engaged and tank_alive and (cid == "DPS" or cid == "Nuker"):
			engage = false
		if engage:
			peer_slot_targets[m] = _combat_pos.engage_target(m, slot_target)
		else:
			peer_slot_targets[m] = slot_target
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


# ============================================================================
# Steering v1 — single-model follow (replaces v0 compose stack)
# ============================================================================


func _sv1_update_follow(
	anchor: CharacterBody3D,
	anchor_pos: Vector3,
	_axes: Dictionary,
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
		if member.has_method("is_mia") and member.is_mia():
			member.velocity = Vector3.ZERO
			continue  # MIA — holds in place for player regroup (F-004 §3.4)
		if member.has_method("is_channeling") and member.is_channeling():
			member.velocity = Vector3.ZERO
			continue  # 캐스팅(채널) 중 비조작 멤버 — 진형 추종\교전을 멈추고 제자리 유지(스킬 발현까지 진형 깨져도 유지). 조작 중이면 위에서 skip → WASD 이동 시 정상 취소.
		if member.has_method("is_provoked") and member.is_provoked():
			planned[member] = _provoked_seek_vel(member)  # forced toward the taunt caster (AB-099)
			continue
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
		_clamp_fatal(member, delta)
		if member.has_method("move_speed_mult"):
			member.velocity *= member.move_speed_mult()  # Oil slick etc.
		member.move_and_slide()
		_sv1_store_wall_normals(member)
	# Pass 3: the anchor. Pass 1/2 skip it (they assume it's the player-driven
	# character). When it is NOT controlled — e.g. the Tank leader in 파티비결속 — it
	# would otherwise stand at the formation origin while everyone else engages, so
	# drive it into combat here too. Outside combat it holds (the formation reference).
	if not anchor.is_controlled() and (not anchor.has_method("is_alive") or anchor.is_alive()):
		# 채널 중인 비조작 앵커도 제자리 유지(스킬 발현까지 진형 깨져도 유지).
		if anchor.has_method("is_channeling") and anchor.is_channeling():
			anchor.velocity = Vector3.ZERO
			return
		# A provoked NC anchor is forced to the caster like any other member (AB-099).
		if anchor.has_method("is_provoked") and anchor.is_provoked():
			anchor.velocity = _provoked_seek_vel(anchor)
			_clamp_fatal(anchor, delta)
			anchor.move_and_slide()
			return
		var av := Vector3.ZERO
		if _combat_engaging:
			var atgt: Vector3 = _combat_pos.engage_target(anchor, anchor.global_position)
			anchor.nav_set_target(atgt)
			var wp: Vector3 = anchor.nav_get_next_position()
			var to_wp: Vector3 = wp - anchor.global_position
			to_wp.y = 0.0
			var d := to_wp.length()
			if d > _arrive_distance:
				av = (to_wp / d) * _follower_move_speed_near
		if _follower_accel_mps2 > 0.0:
			anchor.velocity = anchor.velocity.move_toward(av, _follower_accel_mps2 * delta)
		else:
			anchor.velocity = av
		_clamp_fatal(anchor, delta)
		if anchor.has_method("move_speed_mult"):
			anchor.velocity *= anchor.move_speed_mult()
		anchor.move_and_slide()


## Provoked (AB-099) forced movement: velocity toward the taunt caster until inside basic
## range, then hold (the forced attack runs in CombatController). Navmesh-routed. Shared by
## NC followers (Pass 1) and an NC anchor (Pass 3); the controlled member uses player_controller.
func _provoked_seek_vel(member: CharacterBody3D) -> Vector3:
	var src = member.get_provoke_source()
	if src == null or not is_instance_valid(src):
		return Vector3.ZERO
	var to: Vector3 = src.global_position - member.global_position
	to.y = 0.0
	var stop_at: float = maxf(float(member.get("basic_range_m")) - 0.3, 0.6)
	if to.length() <= stop_at:
		return Vector3.ZERO
	var wp: Vector3 = src.global_position
	if member.has_method("nav_set_target"):
		member.nav_set_target(src.global_position)
		wp = member.nav_get_next_position()
	var d: Vector3 = wp - member.global_position
	d.y = 0.0
	return (d.normalized() * _follower_move_speed_near) if d.length() > 0.05 else Vector3.ZERO


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
	_peer_slot_targets: Dictionary
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

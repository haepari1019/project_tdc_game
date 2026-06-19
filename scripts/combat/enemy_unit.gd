extends CharacterBody3D
## ENC enemy placeholder — box + warm color (A3 replaces mesh).
## ref: WORK_ORDER §code PH · ENC-NORM-001 units.

signal died(unit: CharacterBody3D)

## Layer 3 = bit value 4. (Was 3 = bits 1|2, which put enemies on the WORLD bit —
## broke LOS raycasts and made steering wall-rays treat enemies as walls. Fixed 2026-06-08.)
const LAYER_ENEMY := 4
## Collide with world(1) + party(2) + enemy(4) = 1|2|4 = 7
const MASK_WORLD_PARTY_ENEMY := 7

## Base box footprint at scale 1.0 — collision matches the visual mesh exactly.
const BOX_BASE := Vector3(0.7, 1.4, 0.7)
const HealthBar := preload("res://scripts/combat/health_bar.gd")

var enemy_id: String = ""
var role: String = ""
var display_name: String = ""

var max_hp: float = 50.0
var hp: float = 50.0
var move_speed: float = 3.5
var contact_damage: float = 6.0
var attack_range_m: float = 1.6
var attack_interval_s: float = 1.2
## Per-unit attack timer, ticked by CombatController.
var attack_cooldown_s: float = 0.0
## Ability instances [{ref, trigger, n}] from data — SIGNATURE AB-### only (every_n etc.).
var abilities: Array = []
## Basic-attack archetype id (rom_*, EN-COR-000) — resolved vs enemy_basics catalog.
var basic_attack: String = ""
## Engaged combat pattern (PT-###, EN-AI-000) + its resolved catalog row (patterns.json).
## engage_profile drives per-enemy positioning in EnemyAI (advance/standoff/kite/zone/orbit/probe/surround).
var pattern_ref: String = ""
var engage_profile: Dictionary = {}
## Probe (EN-006/PT-006) hit-and-back-off timer: set on each strike, retreats while > 0.
var probe_backstep_s: float = 0.0
## Cooldown-triggered signature (e.g. AB-098 heal, AB-006/013 dash) — ticked while engaged,
## independent of the basic-attack rhythm (every_n). One per enemy is enough for the demo set.
var sig_cooldown_s: float = 0.0
## Dash state (AB-006 gap-close / AB-013 backstab) — a short velocity-takeover lunge after the
## telegraph, resolved (and AB-013's hit applied) by EnemyAI when dash_timer_s elapses.
var dashing: bool = false
var dash_vel: Vector3 = Vector3.ZERO
var dash_timer_s: float = 0.0
var dash_eff: Dictionary = {}
var dash_chosen: Dictionary = {}
var dash_target: CharacterBody3D = null
## AssassinTransform (ENC tag — NORM-003/HARD-011): disguised among fodder, stalks a backline
## target, then reveals with a telegraph and EXECUTES (high burst). Reverts to normal after.
## Set per-encounter at spawn (not a unit-catalog property). ref: ENC-NORM-003 / D-013 tags.
var assassin: bool = false
var assassin_telegraph_s: float = 0.6
var assassin_revealed: bool = false
var attack_count: int = 0
# F-021 §3.1.2 object-priority: this enemy seeks + uses nearby enemy-usable objects. A held
# object runs its OWN combat behavior (e.g. torch → throw); held_object is set by the object.
var interacts_with_objects: bool = false
var held_object: Node = null

## Squad (분대) = encounter group. Engagement is per-enemy but propagates only to
## squad-mates within cohesion range, so a strayed member fighting alone doesn't
## drag the distant squad into combat. ref: CombatController._engage_enemy.
var squad_id: int = -1
var engaged: bool = false       # this enemy is in active combat (vs dormant)
var engage_grace_s: float = 0.0 # D-010 §4.2 per-enemy disengage countdown

## Telegraph wind-up state machine (frame-driven; driven by CombatController). ref: DEBT-OTHER-AWAIT.
var winding: bool = false
var windup_timer_s: float = 0.0
var windup_eff: Dictionary = {}
var windup_chosen: Dictionary = {}
var windup_target: CharacterBody3D = null

# --- Perception facing + vision cone (Phase C2: hybrid vision cone) ---
const SCAN_HALF_DEG := 35.0   # dormant idle scan sweep amplitude
const SCAN_PERIOD_S := 4.0     # full left-right sweep period
var facing: Vector3 = Vector3(0, 0, 1)         # horizontal look direction
var _base_facing: Vector3 = Vector3(0, 0, 1)   # scan pivots around this
var _scan_t: float = 0.0
var _scan_mult: float = 1.0   # per-enemy scan speed → desync the idle sweep so cones aren't in lockstep
# Dormant roaming (alive feel): wander near the spawn home. State driven by EnemyAI._tick_roam.
var home_pos: Vector3 = Vector3.INF   # captured on first dormant tick
var roaming: bool = false
var roam_target: Vector3 = Vector3.ZERO
var roam_timer_s: float = 0.0
## Perception memory: where this enemy last perceived the party. While investigating
## it walks here even after losing sight, then gives up. (Distinct from last_seen_pos,
## which is where the PARTY last saw this enemy — fog-of-war rendering.)
var investigate_pos: Vector3 = Vector3.ZERO
var has_investigate: bool = false
## Search-on-hit: damaged from outside vision → engage + walk toward the hit's source
## direction (investigate even without LOS, then grace gives up). ref: F-011 / F-013.
const SEARCH_GRACE_S := 6.0
var search_pos: Vector3 = Vector3.ZERO
var has_search: bool = false

## Cached navmesh path (mirrors party_member) — lets enemies route AROUND walls when
## chasing/investigating instead of rubbing straight into them.
var _nav_path: PackedVector3Array = PackedVector3Array()
var _nav_path_idx: int = 0
var _nav_target: Vector3 = Vector3.ZERO
# Vision cone params (the cone is drawn by EnemyVisionOverlay as a unioned ground mask, not a
# per-enemy mesh — overlapping cone meshes z-fought / alpha-stacked). ref: vision cone union.
var _cone_active := false
var _cone_range := 0.0
var _cone_combat_r := 0.0
var _cone_fov_half := 0.0
var _alert_label: Label3D
var _alert_level: int = -1

var _body_material: StandardMaterial3D
var _base_albedo: Color = Color.WHITE
var _hp_bar: Node3D
var _flash_tw: Tween


func setup(row: Dictionary, color: Color, box_scale: float) -> void:
	# Desync the idle scan across enemies (random phase + slightly varied speed) so vision cones
	# don't all sweep in lockstep — looks alive, not synchronised.
	_scan_t = randf() * SCAN_PERIOD_S
	_scan_mult = randf_range(0.8, 1.2)
	roam_timer_s = randf_range(0.5, 4.0)   # stagger the first roam so enemies don't all set off at once
	enemy_id = String(row.get("enemy_id", ""))
	role = String(row.get("role", ""))
	display_name = String(row.get("display_name", ""))
	var stats: Dictionary = row.get("stats", {})
	max_hp = float(stats.get("hp", 50.0))
	hp = max_hp
	move_speed = float(stats.get("move_speed", 3.5))
	contact_damage = float(stats.get("contact_damage", 6.0))
	attack_range_m = float(stats.get("attack_range_m", 1.6))
	attack_interval_s = float(stats.get("attack_interval_s", 1.2))
	var ab = row.get("abilities", [])
	abilities = ab if typeof(ab) == TYPE_ARRAY else []
	basic_attack = String(row.get("basic_attack", ""))
	# Resolve the engaged positioning pattern (PT-###) once at spawn — EnemyAI reads engage_profile.
	pattern_ref = String(row.get("pattern_ref", ""))
	engage_profile = Slice01Data.get_pattern(pattern_ref) if pattern_ref != "" else {}
	# ENC-bound torch carry (EN-AI-000 §6 worldInteractProfile) is set at spawn, not from the
	# unit catalog (spec: not an enemyId property). Demo binding = ENC-PAT-003 (P2-S3) → false now.
	interacts_with_objects = bool(row.get("interacts_with_objects", false))
	name = enemy_id
	_base_albedo = color
	var box_size := BOX_BASE * box_scale
	_apply_collision_size(box_size)
	_build_box_mesh(color, box_size)
	_build_hp_bar(box_size)
	_build_alert_mark(box_size)
	collision_layer = LAYER_ENEMY
	collision_mask = MASK_WORLD_PARTY_ENEMY
	add_to_group("enemy")
	# §5.3 주의어그로 — elite/boss get HP-bar emphasis (attentionTier High).
	if role == "elite" or role == "boss":
		set_attention(true)


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	_flash()
	if hp <= 0.0:
		died.emit(self)
		queue_free()


func is_alive() -> bool:
	return hp > 0.0


## Restore HP (AB-098 Mire Mend Pulse — EN-014 sustain heals its squad). Clamped to max,
## green flash for the Read. No-op on the dead.
func heal(amount: float) -> void:
	if hp <= 0.0 or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	if _body_material:
		if _flash_tw and _flash_tw.is_valid():
			_flash_tw.kill()
		_body_material.albedo_color = Color(0.4, 1.0, 0.5)
		_flash_tw = create_tween()
		_flash_tw.tween_property(_body_material, "albedo_color", _base_albedo, 0.25)


# --- Perceived visibility (party-union LOS occlusion; driven by EnemyVisibility) ---
var _seen: bool = true
var _seen_tw: Tween
## Last position the party saw this enemy at — for a future last-seen marker. F-011 pre-step.
var last_seen_pos: Vector3 = Vector3.ZERO
const _SEEN_FADE_S := 0.18

## Fade in/out by whether any party member has LOS. Stores last-seen pos on hide.
func set_seen(seen: bool) -> void:
	if seen == _seen:
		return
	_seen = seen
	if not seen:
		last_seen_pos = global_position
	if _seen_tw and _seen_tw.is_valid():
		_seen_tw.kill()
	if _body_material == null:
		visible = seen
		return
	_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if seen:
		visible = true
	_seen_tw = create_tween()
	_seen_tw.tween_property(_body_material, "albedo_color:a", 1.0 if seen else 0.0, _SEEN_FADE_S)
	if not seen:
		_seen_tw.tween_callback(func() -> void: visible = false)


# --- Threat Table (F-022) — per-enemy threat per party member ---
var threat: Dictionary = {}
var current_target: CharacterBody3D = null
var imminent_target: CharacterBody3D = null  # §5.2 next-target (switch imminent)
var last_gainer: CharacterBody3D = null
var first_hit: bool = false  # §3.4 first-attack bonus applied?
var floor_of: Dictionary = {}  # member -> threat floor (§3.5)
const DEFAULT_FLOOR := 10.0
const IMMINENT_RATIO := 0.85  # §3.2 2nd >= 1st * this → imminent switch UI
## Proportional (exponential) decay: fraction of threat RETAINED per second.
## Lower = shorter memory → recent threat dominates, aggro bounces (harder).
const THREAT_RETAIN_PER_S := 0.6

# --- Status: slow (Nuker Nova sub) ---
var slow_timer_s: float = 0.0
var slow_factor: float = 1.0

# --- Status: stun / interrupt (party Toll Stun etc.) — freezes the enemy AND cancels any
# in-progress cast/dash (EN-AI-000 §2 channel interrupt). Ticked by EnemyAI while engaged. ---
var stun_timer_s: float = 0.0

# --- Status: knockback (smoothed push over KB_TIME, not an instant teleport) ---
const KB_TIME := 0.18
var kb_vel: Vector3 = Vector3.ZERO
var kb_timer: float = 0.0


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer_s = maxf(slow_timer_s, duration)


func tick_slow(delta: float) -> void:
	if slow_timer_s > 0.0:
		slow_timer_s -= delta
		if slow_timer_s <= 0.0:
			slow_factor = 1.0


## Stun / interrupt (EN-AI-000 §2). Freezes the enemy; EnemyAI cancels any channel/dash in
## progress (cast fails — cooldown stays consumed). No-op on the dead.
func apply_stun(duration: float) -> void:
	if hp <= 0.0 or duration <= 0.0:
		return
	stun_timer_s = maxf(stun_timer_s, duration)


func is_stunned() -> bool:
	return stun_timer_s > 0.0


func tick_stun(delta: float) -> void:
	if stun_timer_s > 0.0:
		stun_timer_s = maxf(0.0, stun_timer_s - delta)


func current_move_speed() -> float:
	return move_speed * slow_factor if slow_timer_s > 0.0 else move_speed


## Knockback away from a source — spread over KB_TIME so it reads as a push,
## not an instant teleport. Resolved by tick_knockback() each frame.
func apply_knockback(dir: Vector3, dist: float) -> void:
	var d := dir
	d.y = 0.0
	if dist <= 0.0 or d.length() < 0.01:
		return
	kb_vel = d.normalized() * (dist / KB_TIME)
	kb_timer = KB_TIME


## While knocked back, drive movement from kb_vel (collision-stopped). Returns
## true if a knockback is active this frame (caller should skip normal steering).
func tick_knockback(delta: float) -> bool:
	if kb_timer <= 0.0:
		return false
	kb_timer -= delta
	velocity = kb_vel  # constant push → exact knockback distance over KB_TIME
	move_and_slide()
	return true


## Show current target slot color on the HP bar + next-target (imminent) marker.
func set_target_marker(member: CharacterBody3D) -> void:
	if _hp_bar == null:
		return
	if member != null and member.has_method("get_class_color"):
		_hp_bar.set_target(member.get_class_color())
	else:
		_hp_bar.clear_target()
	# §5.2 imminent switch marker (pulsing, next target's color).
	if imminent_target != null and is_instance_valid(imminent_target) \
			and imminent_target.has_method("get_class_color"):
		_hp_bar.set_imminent(imminent_target.get_class_color())
	else:
		_hp_bar.clear_imminent()


## §5.3 주의어그로 — Elite/Boss HP bar emphasis.
func set_attention(high: bool) -> void:
	if _hp_bar and _hp_bar.has_method("set_attention"):
		_hp_bar.set_attention(high)


# ===== Perception facing + tells (Phase C2: hybrid vision cone) =====

## Base look direction (dormant scan pivots around this). Set at spawn toward the
## party's entry so enemies "watch the door".
func set_base_facing(dir: Vector3) -> void:
	var d := dir
	d.y = 0.0
	if d.length() < 0.01:
		return
	_base_facing = d.normalized()
	facing = _base_facing
	_orient_cone()


## Dormant idle: sweep facing left-right around the base so the cone moves and the
## player gets windows to slip past.
func scan(delta: float) -> void:
	_scan_t += delta * _scan_mult
	var ang := deg_to_rad(SCAN_HALF_DEG) * sin(_scan_t * TAU / SCAN_PERIOD_S)
	facing = _base_facing.rotated(Vector3.UP, ang)
	_orient_cone()


## Snap facing toward a world point (alert/engaged: look at the target/sighting).
func face_toward(pos: Vector3) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	facing = d.normalized()
	_orient_cone()


## Alert mark above head: 0 none, 1 '?' (경계), 2 '!' (전투).
func set_alert_mark(level: int) -> void:
	if level == _alert_level or _alert_label == null:
		return
	_alert_level = level
	if level <= 0:
		_alert_label.visible = false
		return
	_alert_label.visible = true
	if level == 1:
		_alert_label.text = "?"
		_alert_label.modulate = Color(1.0, 0.85, 0.2)
	else:
		_alert_label.text = "!"
		_alert_label.modulate = Color(1.0, 0.25, 0.2)


func _build_alert_mark(box_size: Vector3) -> void:
	_alert_label = Label3D.new()
	_alert_label.text = "?"
	_alert_label.font_size = 48
	_alert_label.position = Vector3(0, box_size.y + 1.15, 0)
	_alert_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_label.no_depth_test = true
	_alert_label.modulate = Color(1.0, 0.85, 0.2)
	_alert_label.visible = false
	add_child(_alert_label)


## Dev VFX: vision cone (player would unlock this with a consumable; forced on for now).
## No longer a per-enemy mesh — overlapping translucent cones z-fought / alpha-stacked. We just
## STORE the params here; EnemyVisionOverlay rasterises every enemy's sector into ONE top-down
## union mask and tints the ground once (combat=red, alert=yellow). ref: vision cone union.
func build_vision_cone(range_m: float, fov_deg: float, alert_frac: float) -> void:
	_cone_range = range_m
	_cone_combat_r = range_m * (1.0 - alert_frac)
	_cone_fov_half = deg_to_rad(fov_deg * 0.5)
	_cone_active = true


## Read by EnemyVisionOverlay each frame to build the union mask. `facing` → world-space angle.
func vision_cone_data() -> Dictionary:
	return {
		"active": _cone_active and is_alive(),
		"range": _cone_range,
		"combat_r": _cone_combat_r,
		"fov_half": _cone_fov_half,
		"facing": atan2(facing.x, facing.z),
	}


func _orient_cone() -> void:
	pass  # cone is drawn by EnemyVisionOverlay now (facing is read live); kept as a no-op


# ===== Navmesh path (route around walls; mirrors party_member) =====

func nav_set_target(target: Vector3) -> void:
	if _nav_target.distance_squared_to(target) < 0.25:
		return  # target hasn't moved enough to bother re-pathing
	_nav_target = target
	var maps := NavigationServer3D.get_maps()
	var map_rid: RID = maps[0] if maps.size() > 0 else RID()
	if not map_rid.is_valid():
		_nav_path = PackedVector3Array()
		return
	var from := Vector3(global_position.x, 0, global_position.z)
	var to := Vector3(target.x, 0, target.z)
	_nav_path = NavigationServer3D.map_get_path(map_rid, from, to, true)
	_nav_path_idx = 1  # skip path[0] (start position)


func nav_get_next_position() -> Vector3:
	if _nav_path.size() == 0:
		return global_position
	var pos_flat := Vector3(global_position.x, 0, global_position.z)
	while _nav_path_idx < _nav_path.size():
		var wp: Vector3 = _nav_path[_nav_path_idx]
		if pos_flat.distance_to(wp) > 0.5:
			return Vector3(wp.x, global_position.y, wp.z)
		_nav_path_idx += 1
	return global_position


func nav_has_path() -> bool:
	return _nav_path.size() > 1 and _nav_path_idx < _nav_path.size()


## Velocity toward `dest` along the navmesh (routes around walls). ZERO when arrived / no path.
## Used by EnemyAI and by held objects driving the carrier's approach (e.g. torch throw).
func nav_move_toward(dest: Vector3, speed: float) -> Vector3:
	nav_set_target(dest)
	var wp: Vector3 = nav_get_next_position()
	var to_wp := wp - global_position
	to_wp.y = 0.0
	var d := to_wp.length()
	if d < 0.05:
		return Vector3.ZERO
	return (to_wp / d) * speed


func add_threat(member: CharacterBody3D, amount: float) -> void:
	if member == null or amount == 0.0:
		return
	threat[member] = float(threat.get(member, 0.0)) + amount
	if amount > 0.0:
		last_gainer = member


## Took damage from `attacker` (any source) — engage and remember its direction so this
## enemy walks over to search even with no LOS. The AI consumes search_pos when blind.
func perceive_attacker(attacker: Node) -> void:
	if attacker == null or not is_instance_valid(attacker) or not (attacker is Node3D):
		return
	engaged = true
	engage_grace_s = maxf(engage_grace_s, SEARCH_GRACE_S)
	search_pos = (attacker as Node3D).global_position
	has_search = true


## Raise this member's threat floor on this enemy (§3.5 — never lowers).
func set_threat_floor(member: CharacterBody3D, f: float) -> void:
	if member == null:
		return
	floor_of[member] = maxf(float(floor_of.get(member, DEFAULT_FLOOR)), f)


## Proportional decay toward each member's floor (§3.5, recency-weighted): old
## threat fades at a fixed % per second so the latest threat wins aggro.
func decay_threat(delta: float) -> void:
	var k := pow(THREAT_RETAIN_PER_S, delta)
	for m in threat.keys():
		if not is_instance_valid(m):
			threat.erase(m)
			continue
		threat[m] = maxf(float(threat[m]) * k, float(floor_of.get(m, DEFAULT_FLOOR)))


## Highest-threat candidate; keep current target unless a challenger exceeds it
## by switch_ratio (F-022 §3.6 hysteresis). Tie → last threat gainer.
func pick_target(candidates: Array, switch_ratio: float) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_v := -1.0
	for m in candidates:
		var v := float(threat.get(m, 0.0))
		if v > best_v or (v == best_v and m == last_gainer):
			best_v = v
			best = m
	if best != null and current_target != null and is_instance_valid(current_target) \
			and current_target != best and candidates.has(current_target):
		if best_v < float(threat.get(current_target, 0.0)) * switch_ratio:
			best = current_target
	current_target = best
	# §5.2 imminent switch: highest OTHER candidate within [imminent, switch) of current.
	imminent_target = null
	if best != null:
		var cur_v := float(threat.get(best, 0.0))
		var chal: CharacterBody3D = null
		var chal_v := -1.0
		for cm in candidates:
			if cm == best:
				continue
			var cv := float(threat.get(cm, 0.0))
			if cv > chal_v:
				chal_v = cv
				chal = cm
		if chal != null and cur_v > 0.0 \
				and chal_v >= cur_v * IMMINENT_RATIO and chal_v < cur_v * switch_ratio:
			imminent_target = chal
	return best


func _apply_collision_size(box_size: Vector3) -> void:
	var col_shape := $CollisionShape3D.shape as BoxShape3D
	if col_shape == null:
		return
	col_shape.size = box_size
	# Align collision with the visual mesh (both sit feet-on-origin) so the box
	# rests on the floor instead of half-sinking — avoids pop/jitter when moving.
	$CollisionShape3D.position.y = box_size.y * 0.5


func _build_box_mesh(color: Color, box_size: Vector3) -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	var box := BoxMesh.new()
	box.size = box_size
	mesh_node.mesh = box
	mesh_node.position.y = box_size.y * 0.5
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = color
	_body_material.roughness = 0.5
	mesh_node.material_override = _body_material


## Body (mesh) color — for the enemy info panel portrait (and an enemy marker for clicks).
func get_body_color() -> Color:
	return _base_albedo


## Floating HP bar (PH dev visibility — A4 replaces with real HUD).
func _build_hp_bar(box_size: Vector3) -> void:
	_hp_bar = HealthBar.new()
	_hp_bar.position = Vector3(0, box_size.y + 0.55, 0)
	add_child(_hp_bar)
	_hp_bar.set_ratio(1.0)


## Brief white flash on hit.
func _flash() -> void:
	if _body_material == null:
		return
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	_body_material.albedo_color = Color(1, 1, 1)
	_flash_tw = create_tween()
	_flash_tw.tween_property(_body_material, "albedo_color", _base_albedo, 0.18)

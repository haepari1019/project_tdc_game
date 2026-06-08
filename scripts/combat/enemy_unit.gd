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
## Ability instances [{ref, trigger, n}] from data (resolved vs ability_catalog).
var abilities: Array = []
var attack_count: int = 0

## Telegraph wind-up state machine (frame-driven; driven by CombatController). ref: DEBT-OTHER-AWAIT.
var winding: bool = false
var windup_timer_s: float = 0.0
var windup_eff: Dictionary = {}
var windup_chosen: Dictionary = {}
var windup_target: CharacterBody3D = null

var _body_material: StandardMaterial3D
var _base_albedo: Color = Color.WHITE
var _hp_bar: Node3D
var _flash_tw: Tween


func setup(row: Dictionary, color: Color, box_scale: float) -> void:
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
	name = enemy_id
	_base_albedo = color
	var box_size := BOX_BASE * box_scale
	_apply_collision_size(box_size)
	_build_box_mesh(color, box_size)
	_build_hp_bar(box_size)
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


func add_threat(member: CharacterBody3D, amount: float) -> void:
	if member == null or amount == 0.0:
		return
	threat[member] = float(threat.get(member, 0.0)) + amount
	if amount > 0.0:
		last_gainer = member


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

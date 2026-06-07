extends CharacterBody3D
## One party slot — cylinder placeholder with role color/size (A2 replaces mesh).

signal became_controlled
signal became_non_controlled
signal downed(member: CharacterBody3D)

const LAYER_PARTY := 2
## world(1) + enemy(4). Party members do NOT physically collide with each other
## (steering separation handles ally spacing) — prevents climbing/stacking when
## they bunch. Still blocked by walls and enemies.
const MASK_PARTY := 5
const MASK_WORLD_ONLY := 1
const DEFAULT_COLLISION_RADIUS := 0.26
const DEFAULT_COLLISION_HEIGHT := 1.15

const CONTROLLED_SCALE := 1.15
const CONTROLLED_EMISSION := 0.55
const HealthBar := preload("res://scripts/combat/health_bar.gd")

var identity_skill_id: String = ""
var class_id: String = ""
var ability_id: String = ""
var slot_index: int = -1
## Seconds to wait before moving toward a new slot after layout forward changes.
var follow_reposition_delay_s: float = 0.0

# --- Combat (from identity `combat` block; generic plumbing) ---
var max_hp: float = 100.0
var hp: float = 100.0
var basic_damage: float = 8.0
var basic_range_m: float = 2.0
var basic_interval_s: float = 1.0
var attack_cooldown_s: float = 0.0
## F-022 damageThreatMultiplier — Tank amplifies its damage-threat to hold aggro.
var threat_mult: float = 1.0
var _alive: bool = true

# --- Identity skill (from `identity` block) + shield (AB-020) ---
var identity_params: Dictionary = {}
var identity_cooldown_s: float = 0.0
## Player-activated sub skill (key 1 on the controlled member). NC never auto-uses.
var sub_ability_id: String = ""
var sub_params: Dictionary = {}
var sub_cooldown_s: float = 0.0
## Damage-absorbing shield (consumed before HP). AB-020 Shield Policy.
var shield: float = 0.0
var shield_timer_s: float = 0.0
# --- Status effects (F-021): stun (can't act) + poison (DoT, bypasses shield) ---
var stun_timer_s: float = 0.0
var poison_timer_s: float = 0.0
var poison_dps: float = 0.0
var _poison_accum: float = 0.0
var _stun_dur: float = 1.0
var _poison_dur: float = 1.0
var _shield_dur: float = 1.0
var _status_orb: MeshInstance3D
var _flash_heal_tw: Tween

var _controlled: bool = false
var _base_color: Color = Color.WHITE
var _body_material: StandardMaterial3D
var _role_scale: float = 1.0
var _hp_bar: Node3D
var _flash_tw: Tween

## Cached navmesh path (y=0 projected, queried via NavigationServer3D)
var _nav_path: PackedVector3Array = PackedVector3Array()
var _nav_path_idx: int = 0
var _nav_target: Vector3 = Vector3.ZERO


func setup(row: Dictionary, index: int, color: Color, collision_radius: float = -1.0, collision_height: float = -1.0, role_scale: float = 1.0) -> void:
	identity_skill_id = String(row.get("identity_skill_id", ""))
	class_id = String(row.get("class_id", ""))
	ability_id = String(row.get("ability_id", ""))
	slot_index = index
	_base_color = color
	_role_scale = role_scale
	var combat: Dictionary = row.get("combat", {})
	max_hp = float(combat.get("hp", 100.0))
	hp = max_hp
	basic_damage = float(combat.get("basic_damage", 8.0))
	basic_range_m = float(combat.get("basic_range_m", 2.0))
	basic_interval_s = float(combat.get("basic_interval_s", 1.0))
	threat_mult = float(combat.get("threat_mult", 1.0))  # F-022 damageThreatMultiplier
	# Identity + sub skill params are LINKED by id (abilities.json catalog).
	identity_params = Slice01Data.get_ability(ability_id)
	sub_ability_id = String(row.get("sub_ability_id", ""))
	sub_params = Slice01Data.get_ability(sub_ability_id)
	name = identity_skill_id
	_apply_collision_size(collision_radius, collision_height)
	_build_cylinder_mesh(color, role_scale)
	collision_layer = LAYER_PARTY
	collision_mask = MASK_PARTY
	add_to_group("party_member")
	_apply_controlled_visual(false)
	_build_hp_bar()


func set_controlled(active: bool) -> void:
	if _controlled == active:
		return
	_controlled = active
	if active:
		add_to_group("player")
		became_controlled.emit()
	else:
		remove_from_group("player")
		became_non_controlled.emit()
	_apply_controlled_visual(active)


func is_controlled() -> bool:
	return _controlled


func set_party_member_collision(enabled: bool) -> void:
	collision_mask = MASK_PARTY if enabled else MASK_WORLD_ONLY


func nav_set_target(target: Vector3) -> void:
	# Only recompute path when target moved significantly
	if _nav_target.distance_squared_to(target) < 0.25:
		return
	_nav_target = target
	var map_rid: RID = NavigationServer3D.get_maps()[0] if NavigationServer3D.get_maps().size() > 0 else RID()
	if not map_rid.is_valid():
		_nav_path = PackedVector3Array()
		return
	# Project positions to y=0 (navmesh plane) for reliable queries
	var from := Vector3(global_position.x, 0, global_position.z)
	var to := Vector3(target.x, 0, target.z)
	_nav_path = NavigationServer3D.map_get_path(map_rid, from, to, true)
	_nav_path_idx = 1  # skip path[0] which is the start position


func nav_get_next_position() -> Vector3:
	if _nav_path.size() == 0:
		return global_position
	# Advance past reached waypoints
	var pos_flat := Vector3(global_position.x, 0, global_position.z)
	while _nav_path_idx < _nav_path.size():
		var wp: Vector3 = _nav_path[_nav_path_idx]
		if pos_flat.distance_to(wp) > 0.5:
			# Return this waypoint at character's Y level
			return Vector3(wp.x, global_position.y, wp.z)
		_nav_path_idx += 1
	# Reached end of path
	return global_position


func nav_has_path() -> bool:
	return _nav_path.size() > 1 and _nav_path_idx < _nav_path.size()


func _apply_collision_size(radius: float, height: float) -> void:
	var col_shape := $CollisionShape3D.shape as CapsuleShape3D
	if col_shape == null:
		return
	col_shape.radius = radius if radius > 0.0 else DEFAULT_COLLISION_RADIUS
	col_shape.height = height if height > 0.0 else DEFAULT_COLLISION_HEIGHT
	# Feet-on-origin: align capsule bottom with the mesh (which is offset up),
	# so the body rests on the floor when its origin is at ground level.
	$CollisionShape3D.position.y = col_shape.height * 0.5


func _build_cylinder_mesh(color: Color, role_scale: float) -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35 * role_scale
	cyl.bottom_radius = 0.40 * role_scale
	cyl.height = 1.4 * role_scale
	mesh_node.mesh = cyl
	mesh_node.position.y = cyl.height * 0.5
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = color
	_body_material.roughness = 0.4
	mesh_node.material_override = _body_material


func _apply_controlled_visual(active: bool) -> void:
	if _body_material:
		_body_material.emission_enabled = active
		_body_material.emission = _base_color * CONTROLLED_EMISSION if active else Color.BLACK
	var s := _role_scale * CONTROLLED_SCALE if active else _role_scale
	scale = Vector3(s, s, s)


func take_damage(amount: float) -> void:
	if not _alive:
		return
	# Shield absorbs first (AB-020).
	if shield > 0.0:
		var absorbed: float = minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if shield <= 0.0:
			shield_timer_s = 0.0
	_flash()
	if amount <= 0.0:
		return  # fully absorbed
	hp = maxf(0.0, hp - amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	if hp <= 0.0:
		_go_down()


## Returns the effective heal applied (excludes overheal — F-022 §3.9).
func heal(amount: float) -> float:
	if not _alive or hp >= max_hp:
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	_heal_flash()
	return hp - before


## AB-020 Shield Policy: keep the higher value; refresh duration only when new >= old.
func add_shield(value: float, duration: float) -> void:
	if value >= shield:
		shield = value
		shield_timer_s = duration
		_shield_dur = duration


func is_alive() -> bool:
	return _alive


## Party slot color (for aggro markers etc.).
func get_class_color() -> Color:
	return _base_color


## Instant knockback away from a source (collision-stopped). KB-LIGHT etc.
func apply_knockback(dir: Vector3, dist: float) -> void:
	if not _alive or dist <= 0.0:
		return
	var d := dir
	d.y = 0.0
	if d.length() < 0.01:
		return
	move_and_collide(d.normalized() * dist)


func _physics_process(delta: float) -> void:
	if sub_cooldown_s > 0.0:
		sub_cooldown_s -= delta
	if shield_timer_s > 0.0:
		shield_timer_s -= delta
		if shield_timer_s <= 0.0:
			shield = 0.0
	_tick_status(delta)


# --- Status (F-021) ---

func apply_stun(duration: float) -> void:
	if not _alive:
		return
	stun_timer_s = maxf(stun_timer_s, duration)
	_stun_dur = maxf(_stun_dur, stun_timer_s)
	_update_status_orb()


func apply_poison(duration: float, dps: float) -> void:
	if not _alive:
		return
	poison_timer_s = maxf(poison_timer_s, duration)
	_poison_dur = maxf(_poison_dur, poison_timer_s)
	poison_dps = maxf(poison_dps, dps)
	_update_status_orb()


## Active buffs/debuffs for the party-sheet overlay (UI-002/003).
## Each: {color, ratio=elapsed (0 fresh → 1 expiring), buff}. Colored arc = remaining.
func get_status_list() -> Array:
	var out: Array = []
	if shield > 0.0:  # buff
		out.append({
			"color": Color(0.36, 0.66, 1.0),
			"ratio": 1.0 - clampf(shield_timer_s / maxf(_shield_dur, 0.01), 0.0, 1.0),
			"buff": true,
		})
	if is_stunned():  # debuff
		out.append({
			"color": Color(1.0, 0.85, 0.2),
			"ratio": 1.0 - clampf(stun_timer_s / maxf(_stun_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	if poison_timer_s > 0.0:  # debuff
		out.append({
			"color": Color(0.36, 0.9, 0.32),
			"ratio": 1.0 - clampf(poison_timer_s / maxf(_poison_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	return out


func is_stunned() -> bool:
	return _alive and stun_timer_s > 0.0


func _tick_status(delta: float) -> void:
	var changed := false
	if stun_timer_s > 0.0:
		stun_timer_s -= delta
		if stun_timer_s <= 0.0:
			changed = true
	if poison_timer_s > 0.0:
		poison_timer_s -= delta
		_poison_accum += poison_dps * delta
		if _poison_accum >= 1.0:  # apply whole-HP DoT ticks (bypasses shield)
			var dmg := floorf(_poison_accum)
			_poison_accum -= dmg
			_apply_dot(dmg)
		if poison_timer_s <= 0.0:
			poison_dps = 0.0
			_poison_accum = 0.0
			changed = true
	if changed:
		_update_status_orb()


func _apply_dot(amount: float) -> void:
	if not _alive or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	if hp <= 0.0:
		_go_down()


## Small overhead orb signalling active status (stun = yellow, poison = green).
func _update_status_orb() -> void:
	var active := is_stunned() or poison_timer_s > 0.0
	if not active:
		if _status_orb:
			_status_orb.visible = false
		return
	if _status_orb == null:
		_status_orb = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		_status_orb.mesh = s
		_status_orb.position = Vector3(0, 2.0, 0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		_status_orb.material_override = mat
		add_child(_status_orb)
	var col: Color = Color(1.0, 0.85, 0.2) if is_stunned() else Color(0.35, 0.9, 0.3)
	(_status_orb.material_override as StandardMaterial3D).albedo_color = col
	_status_orb.visible = true


func _heal_flash() -> void:
	if _body_material == null:
		return
	if _flash_heal_tw and _flash_heal_tw.is_valid():
		_flash_heal_tw.kill()
	_body_material.albedo_color = Color(0.4, 1.0, 0.5)
	_flash_heal_tw = create_tween()
	_flash_heal_tw.tween_property(_body_material, "albedo_color", _base_color, 0.3)


## Floating HP bar (PH dev visibility — A4 replaces with real HUD).
func _build_hp_bar() -> void:
	_hp_bar = HealthBar.new()
	_hp_bar.position = Vector3(0, 1.4 * _role_scale + 0.7, 0)
	add_child(_hp_bar)
	_hp_bar.set_ratio(1.0)


func _flash() -> void:
	if _body_material == null:
		return
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	_body_material.albedo_color = Color(1, 1, 1)
	_flash_tw = create_tween()
	_flash_tw.tween_property(_body_material, "albedo_color", _base_color, 0.18)


func _go_down() -> void:
	_alive = false
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	remove_from_group("party_member")
	if _body_material:
		_body_material.albedo_color = Color(0.30, 0.30, 0.30)
		_body_material.emission_enabled = false
	downed.emit(self)

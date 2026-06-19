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

# --- Identity Gear (F-008 §3.7 / DEC-20260611-001): gear is the source of identity ---
## base_gear_id -> bundled_identity_skill_id -> identities.json row -> the identity fields below.
var equipped_gear: Dictionary = {}
var base_gear_id: String = ""
var gear_kind: String = ""
var basic_attack_profile_id: String = ""
var equip_classes: Array = []

# --- Identity (resolved from equipped_gear's bundled identity) ---
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
var _mia: bool = false
var _warn: bool = false
var _mia_marker: Label3D = null
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
var _slow_dur: float = 0.0

# --- Identity skill (from `identity` block) + shield (AB-020) ---
var identity_params: Dictionary = {}
var identity_cooldown_s: float = 0.0
## Player-activated sub skill (key 1 on the controlled member). NC never auto-uses.
## (legacy single-sub fields — kept empty; subs now come from skillbook_slots below.)
var sub_ability_id: String = ""
var sub_params: Dictionary = {}
var sub_cooldown_s: float = 0.0
## Sub skillbook slots Q/E/R (F-009 §3.1 / DEC-20260611-002). Each = null or an instance:
## {base_ability_id, display_name, params, charges, charges_max, cooldown_s, equip_classes, color}.
var skillbook_slots: Array = [null, null, null]
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
## Provoked (AB-099 Iron Mockery): movement input + active skills locked, forced basic attack
## on the caster. Character-bound (swap keeps it). Stunned suppresses the EFFECTS (is_provoked
## returns false while stunned) but the timer keeps running. ref: AB-099 / STATUS-ACTOR-CORE.
var provoked_timer_s: float = 0.0
var _provoke_dur: float = 1.0
var provoke_source: Node = null
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


## Spawn a party member from its Identity Gear master (F-008 §3.7): the gear's
## bundled_identity_skill_id resolves the identity row that drives stats + skills.
func setup(gear: Dictionary, index: int, color: Color, collision_radius: float = -1.0, collision_height: float = -1.0, role_scale: float = 1.0) -> void:
	slot_index = index
	_base_color = color
	_role_scale = role_scale
	_bind_gear(gear, true)
	name = identity_skill_id
	_apply_collision_size(collision_radius, collision_height)
	_build_cylinder_mesh(color, role_scale)
	collision_layer = LAYER_PARTY
	collision_mask = MASK_PARTY
	add_to_group("party_member")
	_apply_controlled_visual(false)
	_build_hp_bar()


## Resolve identity from an Identity Gear master and apply it to this member.
## base_gear_id -> bundled_identity_skill_id -> identities.json row -> stats/skills.
## reset_hp=true on spawn; false on mid-run swap (keep current HP, clamp to new max).
func _bind_gear(gear: Dictionary, reset_hp: bool) -> void:
	equipped_gear = gear
	base_gear_id = String(gear.get("base_gear_id", ""))
	gear_kind = String(gear.get("gear_kind", ""))
	basic_attack_profile_id = String(gear.get("basic_attack_profile_id", ""))
	equip_classes = gear.get("equip_classes", [])
	identity_skill_id = String(gear.get("bundled_identity_skill_id", ""))
	var row: Dictionary = Slice01Data.get_identity_row(identity_skill_id)
	class_id = String(row.get("class_id", ""))
	ability_id = String(row.get("ability_id", ""))
	var combat: Dictionary = row.get("combat", {})
	max_hp = float(combat.get("hp", 100.0))
	hp = max_hp if reset_hp else minf(hp, max_hp)
	basic_damage = float(combat.get("basic_damage", 8.0))
	basic_range_m = float(combat.get("basic_range_m", 2.0))
	basic_interval_s = float(combat.get("basic_interval_s", 1.0))
	threat_mult = float(combat.get("threat_mult", 1.0))  # F-022 damageThreatMultiplier
	# Identity + sub skill params are LINKED by id (abilities.json catalog).
	identity_params = Slice01Data.get_ability(ability_id)
	# Sub skills come from looted skillbooks (F-009 §3.1), NOT the identity/gear — the
	# Q/E/R slots start empty and fill by equipping skillbooks. (was: innate AB-S01..S04)
	sub_ability_id = ""
	sub_params = {}
	identity_cooldown_s = 0.0


## Role gate (F-008 §3.4, strict): a member may only equip gear for its own class.
func can_equip_gear(gear: Dictionary) -> bool:
	var classes = gear.get("equip_classes", [])
	return typeof(classes) == TYPE_ARRAY and classes.has(class_id)


## Mid-run / hub gear swap (F-008 §3.2): caller enforces partyInCombat==false.
## Returns false (no change) on cross-role gear. Re-syncs identity to the new gear.
func equip_gear(gear: Dictionary) -> bool:
	if not can_equip_gear(gear):
		return false
	_bind_gear(gear, false)
	name = identity_skill_id
	return true


## Remove the equipped gear (drag-out to inventory). Identity skill goes inactive until
## a same-role gear is re-equipped; basic stats persist. Returns the removed master ({} if none).
func unequip_gear() -> Dictionary:
	var prev: Dictionary = equipped_gear
	equipped_gear = {}
	base_gear_id = ""
	identity_params = {}
	return prev


## Sub skillbook slots (F-009 §3.1). Role gate = equipClasses on the skillbook master.
func can_equip_skillbook(master: Dictionary) -> bool:
	var classes = master.get("equip_classes", [])
	return typeof(classes) == TYPE_ARRAY and classes.has(class_id)


func get_skillbook(slot_index: int):
	if slot_index < 0 or slot_index >= skillbook_slots.size():
		return null
	return skillbook_slots[slot_index]


## Put `inst` (or null) in slot; returns whatever it displaced (null if empty).
func set_skillbook(slot_index: int, inst):
	if slot_index < 0 or slot_index >= skillbook_slots.size():
		return null
	var prev = skillbook_slots[slot_index]
	skillbook_slots[slot_index] = inst
	return prev


## Equip a skillbook into a Q/E/R slot by base_ability_id (deployment loadout apply, F-010).
func equip_skillbook_by_id(slot_index: int, base_ability_id: String) -> void:
	if slot_index < 0 or slot_index >= skillbook_slots.size() or base_ability_id == "":
		return
	var master: Dictionary = Slice01Data.get_skillbook_master(base_ability_id)
	if master.is_empty():
		return
	var cmax := int(master.get("charges_max", 30))
	set_skillbook(slot_index, {
		"base_ability_id": base_ability_id,
		"display_name": String(master.get("display_name", base_ability_id)),
		"params": master.get("cast", {}),
		"charges": cmax,
		"charges_max": cmax,
		"cooldown_s": 0.0,
		"equip_classes": master.get("equip_classes", [class_id]),
		"color": _base_color,
	})


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


func is_mia() -> bool:
	return _mia


func is_warn() -> bool:
	return _warn


## Separation warning (anchor leash, before MIA) — party_sheet tints the portrait.
func set_warn(on: bool) -> void:
	_warn = on


## Missing-In-Action — cut off from the party by a hazard (driven by party_controller).
## Shows a world marker; swap is blocked while MIA (F-001 §3.6). Clears on rejoin.
func set_mia(on: bool) -> void:
	if _mia == on:
		return
	_mia = on
	if on and _mia_marker == null:
		_mia_marker = Label3D.new()
		_mia_marker.text = "⚠ MIA"
		_mia_marker.font_size = 44
		_mia_marker.modulate = Color(1.0, 0.5, 0.15)
		_mia_marker.position = Vector3(0, 2.7, 0)
		_mia_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mia_marker.no_depth_test = true
		add_child(_mia_marker)
	if _mia_marker != null:
		_mia_marker.visible = on


## Revive a downed member (revival consumable). Restores alive state + HP; re-adds to
## the party_member group and un-dims the body. No-op (false) if already alive.
func revive(hp_fraction: float = 0.5) -> bool:
	if _alive:
		return false
	_alive = true
	hp = clampf(max_hp * hp_fraction, 1.0, max_hp)
	if not is_in_group("party_member"):
		add_to_group("party_member")
	if _body_material:
		_body_material.albedo_color = _base_color
		_body_material.emission_enabled = true
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	_apply_controlled_visual(_controlled)
	return true


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
	for s in skillbook_slots:
		if s != null and float(s.cooldown_s) > 0.0:
			s.cooldown_s = float(s.cooldown_s) - delta
	if shield_timer_s > 0.0:
		shield_timer_s -= delta
		if shield_timer_s <= 0.0:
			shield = 0.0
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0
	if _hp_bar:
		_hp_bar.set_shield_ratio(shield / maxf(max_hp, 1.0))  # white overlay on the HP bar
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


## Movement slow (e.g. Oil slick) — multiplies move speed while active (피아무구분).
func apply_slow(factor: float, duration: float) -> void:
	if not _alive:
		return
	_slow_factor = factor
	_slow_timer = maxf(_slow_timer, duration)
	_slow_dur = maxf(_slow_dur, _slow_timer)


## Provoke (AB-099): force this member to basic-attack `source`; movement/skills lock.
func apply_provoke(source: Node, duration: float) -> void:
	if not _alive:
		return
	provoke_source = source
	provoked_timer_s = maxf(provoked_timer_s, duration)
	_provoke_dur = maxf(_provoke_dur, provoked_timer_s)
	_update_status_orb()


## Provoked AND able to act on it. False while stunned — Stunned suppresses Provoked's
## effects (forced attack/move/skill-lock) though the timer keeps running (AB-099 edge case).
func is_provoked() -> bool:
	return _alive and provoked_timer_s > 0.0 and stun_timer_s <= 0.0


## The taunt caster to force-attack — null (and unlinked) if it died / went away.
func get_provoke_source() -> Node:
	if provoke_source != null and (not is_instance_valid(provoke_source) \
			or (provoke_source.has_method("is_alive") and not provoke_source.is_alive())):
		provoke_source = null
	return provoke_source


func move_speed_mult() -> float:
	return _slow_factor if _slow_timer > 0.0 else 1.0


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
	if poison_timer_s > 0.0:  # debuff (DoT — poison / fire / toxic gas)
		out.append({
			"color": Color(0.36, 0.9, 0.32),
			"ratio": 1.0 - clampf(poison_timer_s / maxf(_poison_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	if _slow_timer > 0.0:  # debuff (slow — Oil slick etc.)
		out.append({
			"color": Color(0.40, 0.78, 1.0),
			"ratio": 1.0 - clampf(_slow_timer / maxf(_slow_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	if provoked_timer_s > 0.0:  # debuff (Provoked — forced taunt, AB-099)
		out.append({
			"color": Color(0.95, 0.35, 0.2),
			"ratio": 1.0 - clampf(provoked_timer_s / maxf(_provoke_dur, 0.01), 0.0, 1.0),
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
	if provoked_timer_s > 0.0:
		provoked_timer_s -= delta
		# End early if the caster died (tauntSourceId 무효화, AB-099 edge case).
		if provoked_timer_s <= 0.0 or get_provoke_source() == null:
			provoked_timer_s = 0.0
			provoke_source = null
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
	var active := is_stunned() or poison_timer_s > 0.0 or provoked_timer_s > 0.0
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
	var col: Color = Color(0.35, 0.9, 0.3)  # poison (default)
	if is_stunned():
		col = Color(1.0, 0.85, 0.2)            # stun (yellow, highest display priority)
	elif provoked_timer_s > 0.0:
		col = Color(0.95, 0.35, 0.2)           # provoked (red-orange)
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
	set_mia(false)  # a downed member is not MIA
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	remove_from_group("party_member")
	if _body_material:
		_body_material.albedo_color = Color(0.30, 0.30, 0.30)
		_body_material.emission_enabled = false
	downed.emit(self)

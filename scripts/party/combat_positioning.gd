extends Node
## CombatPositioning — goal-point logic for 전투우선 followers (where to stand when the
## party engages): the post-contact slot-break trigger, melee close-to-attack-range
## point, and the healer's "stay on the wounded" support point. Extracted from
## PartyController to isolate combat positioning from the steering/formation engine
## (ARCHITECTURE DEBT-GOD). A child of PartyController; reads the member list via it.
## ref: F-004 (safe-first slot break) · F-005 (healer role).

var _party: Node3D  # PartyController — owns _members / formation


func setup(party: Node3D) -> void:
	_party = party


func has_live_enemies() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			return true
	return false


## Is any live enemy within basic attack range of a non-controlled, living
## follower? Horizontal distance (party floats above enemies). This is the
## post-contact trigger for leaving formation — until an enemy is this close,
## followers hold their slots instead of charging a distant foe.
func enemy_in_party_basic_range() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return false
	for m in _party._members:
		if not is_instance_valid(m) or m.is_controlled():
			continue
		if m.has_method("is_alive") and not m.is_alive():
			continue
		var r: float = float(m.get("basic_range_m"))
		var r2 := r * r
		var mp: Vector3 = m.global_position
		for e in enemies:
			if not is_instance_valid(e):
				continue
			var d: Vector3 = mp - e.global_position
			d.y = 0.0
			if d.length_squared() <= r2:
				return true
	return false


## Goal point for an engaging follower. Healers position to keep the most-wounded
## ally inside heal range (support); everyone else closes to attack range of the
## nearest enemy. `slot_target` is the safe fallback when there's no goal.
const MELEE_RANGE_MAX := 3.5  # basic_range above this = ranged → deal from the backline (no approach)

func engage_target(member: CharacterBody3D, slot_target: Vector3) -> Vector3:
	# Healer (radius_heal): stay on the wounded, not on the enemy.
	if String(member.identity_params.get("kind", "")) == "radius_heal":
		return _healer_support_target(member, slot_target)
	var br: float = float(member.get("basic_range_m"))
	# Ranged dealers (DPS / ranged Nuker) attack from the backline — hold the formation slot;
	# auto-attack picks up any enemy in range. They never approach ahead of the tank.
	if br > MELEE_RANGE_MAX:
		return slot_target
	var mp := member.global_position
	var nearest := _nearest_enemy(mp)
	if nearest == null:
		return mp
	# Melee dealer (e.g. a melee Nuker): take a FLANK point off the tank→enemy axis — a side
	# attack at melee reach, never the front, never overtaking the tank. ref: 2선 측면 딜.
	var reach: float = clampf(br - 0.6, 0.8, br)
	var epos := nearest.global_position
	# Tank = front line: close STRAIGHT to melee range (own approach) and hold there. It LEADS
	# the engage, so it must not flank — and it must reach a foe to land the gating first hit.
	# (Without this the anchored tank ran the flank path, orbiting itself → "spinning in place".)
	if String(member.get("class_id")) == "Tank":
		var tdir := Vector2(mp.x - epos.x, mp.z - epos.z)
		var td := tdir.length()
		if td <= reach or td < 0.001:
			return Vector3(mp.x, epos.y, mp.z)  # in range — hold & attack
		tdir /= td
		return Vector3(epos.x + tdir.x * reach, epos.y, epos.z + tdir.y * reach)
	var me := Vector2(mp.x - epos.x, mp.z - epos.z)
	var tank: Variant = _tank_position()
	var flank: Vector2
	if tank != null:
		var t3: Vector3 = tank
		var axis := Vector2(epos.x - t3.x, epos.z - t3.z)  # tank→enemy = front direction
		axis = axis.normalized() if axis.length() > 0.01 else Vector2(0.0, 1.0)
		var perp := Vector2(-axis.y, axis.x)
		if me.dot(perp) < 0.0:
			perp = -perp                       # the flank side the member is already on
		flank = perp
	else:
		flank = me.normalized() if me.length() > 0.01 else Vector2(0.0, 1.0)  # no tank → own side
	var t := epos + Vector3(flank.x, 0.0, flank.y) * reach
	t.y = epos.y
	return t


func _nearest_enemy(from: Vector3) -> Node3D:
	var nearest: Node3D = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best:
			best = d
			nearest = e
	return nearest


## Living tank's position (the front line) or null — the melee flank is taken off the
## tank→enemy axis so dealers attack from the side, behind the front.
func _tank_position() -> Variant:
	for m in _party._members:
		if is_instance_valid(m) and String(m.get("class_id")) == "Tank" \
				and (not m.has_method("is_alive") or m.is_alive()):
			return m.global_position
	return null


## Healer combat goal: move so the most-wounded ally (below its Mend Circle
## threshold) sits inside heal radius. Stops just inside so jitter can't drop the
## target out of range. If nobody needs healing, hold the safe formation slot —
## the healer never chases enemies. ref: F-005 healer role.
func _healer_support_target(member: CharacterBody3D, slot_target: Vector3) -> Vector3:
	var wounded := _lowest_hp_ally_below_threshold(member)
	if wounded == null:
		return slot_target  # nobody to heal — stay safe with the formation
	var mp := member.global_position
	var radius: float = float(member.identity_params.get("radius_m", 4.0))
	var reach: float = clampf(radius - 0.8, 1.0, radius)
	var to := mp - wounded.global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= reach or dist < 0.001:
		return Vector3(mp.x, wounded.global_position.y, mp.z)  # in range — hold
	var t := wounded.global_position + (to / dist) * reach
	t.y = wounded.global_position.y
	return t


## Most-wounded living ally below its Mend Circle heal threshold (Tank vs others),
## using the same thresholds as AbilityDispatch._cast_mend_circle so the healer
## repositions exactly for the allies its heal would target. null if all are fine.
func _lowest_hp_ally_below_threshold(healer: CharacterBody3D) -> CharacterBody3D:
	var p: Dictionary = healer.identity_params
	var ally_t: float = float(p.get("ally_threshold_pct", 0.85))
	var tank_t: float = float(p.get("tank_threshold_pct", 0.90))
	var best: CharacterBody3D = null
	var best_ratio := INF
	for m in _party._members:
		if not is_instance_valid(m):
			continue
		if m.has_method("is_alive") and not m.is_alive():
			continue
		var mhp: float = float(m.max_hp)
		if mhp <= 0.0:
			continue
		var ratio: float = float(m.hp) / mhp
		var t: float = tank_t if String(m.get("class_id")) == "Tank" else ally_t
		if ratio < t and ratio < best_ratio:
			best_ratio = ratio
			best = m
	return best

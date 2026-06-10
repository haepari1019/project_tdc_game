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
func engage_target(member: CharacterBody3D, slot_target: Vector3) -> Vector3:
	# Healer (radius_heal): stay on the wounded, not on the enemy.
	if String(member.identity_params.get("kind", "")) == "radius_heal":
		return _healer_support_target(member, slot_target)
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

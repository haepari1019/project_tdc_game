extends Node3D
## Spawns & runs ENC encounters (box PH enemies). Combat loop added in CP4–5.
## ref: WORK_ORDER §4 · ENC-NORM-001 · QA-005 §2.6 (NC sub skillbook: NO auto).

## partyInCombat (전투중/휴식중) changed — true while ANY enemy is engaged. Derived
## from per-enemy squad engagement; drives HUD + follower re-form. (see is_engaged)
signal engagement_changed(engaged: bool)
## A party member just took damage. Drives the follower formation-break trigger
## (slot-break on being hit), separate from engagement/perception.
signal party_damaged()
## Camera feedback (dungeon_run): trauma 0..1 to add (trauma² shake), kick_world =
## directional push in world XZ (ZERO for hit-feel). Controlled events full, others muted.
signal camera_shake(trauma: float, kick_world: Vector3)
## A party member took a directional hit — drives the screen-edge damage indicator.
## from_dir_world = world XZ toward the attacker; severity 0..1; is_controlled gates the
## (controlled-only) edge UI. Emitted for ALL hits above a chip threshold (incl. basic).
signal party_hit(from_dir_world: Vector3, severity: float, is_controlled: bool)
## An enemy was defeated at world_pos — drives world item drops (loot). ref: F-010 loot.
signal enemy_defeated(world_pos: Vector3, ability_refs: Array)

const EnemyScene := preload("res://scenes/combat/enemy_unit.tscn")
const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const Spatial := preload("res://scripts/core/spatial.gd")
const EnemyAI := preload("res://scripts/combat/enemy_ai.gd")
const AbilityDispatch := preload("res://scripts/combat/abilities/ability_dispatch.gd")
const ReactionSystem := preload("res://scripts/combat/abilities/reaction_system.gd")

## D-010 §4.2 combat_exit_grace_s — an engaged enemy with no combat event and no
## line of sight to the party for this long disengages (전투중 → dormant). Tuning.
const COMBAT_EXIT_GRACE_S := 6.0
## Squad cohesion: a newly-engaged enemy wakes squad-mates within this radius. A
## strayed member (off investigating) is outside it, so killing it alone does NOT
## wake the distant squad. Tuning.
const SQUAD_PROP_RADIUS_M := 9.0
## Lateral spacing between squads sharing one room (relocated start-room encounter
## sits beside the room's own squad instead of overlapping it).
const SQUAD_LANE_SPACING := 12.0

# F-022 threat tuning (§3.2 Draft).
const FIRST_ATTACK_BONUS := 120.0   # §3.4 first aggressor on the hit enemy
const GROUP_PULL_BONUS := 60.0      # §3.7 group reacts to first aggressor
const FIRST_AGGRESSOR_FLOOR := 25.0 # §3.5 first aggressor min threat
const PERCEIVE_THREAT := 40.0       # threat seeded on the member an enemy perceives/hits (it targets who it saw)
const HEAL_THREAT_PER_HP := 0.5     # §3.9 healer threat per effective HP


var _party: Node3D
var _map: Node3D
var _enemies: Array[CharacterBody3D] = []
## Squads (분대) — one per pre-spawned encounter group. Engagement is per-enemy
## (enemy.engaged), but a squad's reinforcement ticks while any of its members is
## engaged. partyInCombat = ANY enemy engaged (derived each tick).
var _squads: Array = []  # [{id, room_ref, reinforce, pending, activated, timer, warned}]
var _next_squad_id: int = 0
var _room_squad_count: Dictionary = {}  # room_ref -> squads placed there (lateral lane offset)
var _spawn_origin: Vector3 = Vector3.ZERO  # party start — squads spawn/face away from it
var _party_in_combat: bool = false  # derived cache (emits engagement_changed on change)
## First party member to damage any enemy (§3.7 group pull source).
var _first_aggressor: CharacterBody3D = null
## The Tank landed its first hit this engagement → opens the gate that holds AI DPS/Nuker
## (2nd-line dealers) from engaging before the tank. Reset on full disengage.
signal tank_engaged()
var _tank_engaged: bool = false

## Enemy perception/combat brain (child node). Per-enemy tick delegated here; it
## calls back for engage/grace/signals (combat state stays owned here). DEBT-GOD2.
var _enemy_ai: EnemyAI
## Party Identity/Sub skill effects (child node). Calls back for spatial queries /
## damage / heal-threat / camera shake (shared systems stay owned here). DEBT-GOD2.
var _ability_dispatch: AbilityDispatch
## World-object AoE + RX-OIL-FIRE hazard chemistry (child node). DEBT-GOD2.
var _reactions: ReactionSystem


func setup(party: Node3D, map: Node3D) -> void:
	_party = party
	_map = map
	_enemy_ai = EnemyAI.new()
	add_child(_enemy_ai)
	_enemy_ai.setup(self)
	_reactions = ReactionSystem.new()
	add_child(_reactions)
	_reactions.setup(self)
	_ability_dispatch = AbilityDispatch.new()
	add_child(_ability_dispatch)
	_ability_dispatch.setup(self, _reactions)


## partyInCombat: true while ANY enemy is engaged. Drives HUD + follower re-form.
func is_engaged() -> bool:
	return _party_in_combat


## Recompute the derived partyInCombat flag and emit on change.
func _refresh_party_in_combat() -> void:
	var any := false
	for e in _enemies:
		if is_instance_valid(e) and e.engaged:
			any = true
			break
	if any != _party_in_combat:
		_party_in_combat = any
		engagement_changed.emit(any)
	if not any:
		_tank_engaged = false  # combat over → the next fight must be opened by the tank again


## A combat event on one enemy (it dealt/took damage, or perceived the party):
## engage it, refresh its grace, and wake squad-mates within cohesion radius. A
## strayed member is outside that radius, so its distant squad stays dormant.
func _engage_enemy(e: CharacterBody3D, target_member: CharacterBody3D = null) -> void:
	if e == null or not is_instance_valid(e):
		return
	var has_target: bool = target_member != null and is_instance_valid(target_member)
	var was: bool = e.engaged
	e.engaged = true
	e.engage_grace_s = COMBAT_EXIT_GRACE_S
	if has_target:
		e.add_threat(target_member, PERCEIVE_THREAT)  # target who we saw/were hit by
	if was:
		return
	var r2 := SQUAD_PROP_RADIUS_M * SQUAD_PROP_RADIUS_M
	for o in _enemies:
		if o == e or not is_instance_valid(o) or o.engaged:
			continue
		if o.squad_id != e.squad_id:
			continue
		if Spatial.h_dist2(o.global_position, e.global_position) <= r2:
			o.engaged = true
			o.engage_grace_s = COMBAT_EXIT_GRACE_S
			if has_target:
				o.add_threat(target_member, PERCEIVE_THREAT)  # squad shares the target


## EnemyAI calls this each frame an engaged enemy still has LOS to its prey —
## refreshes the disengage grace (D-010 §4.2) without re-seeding threat.
func refresh_engage_grace(e: CharacterBody3D) -> void:
	e.engage_grace_s = COMBAT_EXIT_GRACE_S


func _physics_process(delta: float) -> void:
	if _enemies.is_empty():
		_refresh_party_in_combat()  # last enemy died → clear partyInCombat (휴식중)
		return
	# DEBT-EFF-GRP: fetch the party-member list once per tick, thread it through.
	var targets := get_tree().get_nodes_in_group("party_member")
	# Per-enemy disengage grace (D-010 §4.2): an engaged enemy reverts to dormant
	# after the grace lapses (grace is refreshed by combat events + active LOS).
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.engaged:
			enemy.engage_grace_s -= delta
			if enemy.engage_grace_s <= 0.0:
				enemy.engaged = false
	# Tick every enemy: dormant ones perceive/idle, engaged ones fight (EnemyAI).
	for enemy in _enemies:
		if is_instance_valid(enemy):
			_enemy_ai.tick(enemy, targets, delta)
	# Party auto-attack runs always — attacking a foe is what commits the party.
	_tick_party_attacks(targets, delta)
	# Per-squad reinforcement ticks while that squad has any engaged member.
	for squad in _squads:
		_tick_reinforcement(squad, delta)
	# partyInCombat = any enemy engaged (derived); drives HUD + follower re-form.
	_refresh_party_in_combat()


## ENC-HARD-005: a squad's rear reinforcement arrives after delay (counted once the
## squad first engages), or instantly once its initial wave is cleared.
func _tick_reinforcement(squad: Dictionary, delta: float) -> void:
	if not squad.get("pending", false):
		return
	if not squad.get("activated", false):
		if _squad_engaged(squad["id"]):
			squad["activated"] = true
		else:
			return  # squad still dormant — don't start the reinforcement clock
	squad["timer"] = float(squad["timer"]) - delta
	var cleared := _squad_alive_count(squad["id"]) == 0
	if not squad.get("warned", false) and (float(squad["timer"]) <= 2.0 or cleared):
		squad["warned"] = true
		print("[TDC] Reinforcements incoming! (%s)" % _reinforce_direction(squad))
		SkillVfx.telegraph(self, _reinforce_point(String(squad["room_ref"]), _reinforce_direction(squad)), Color(0.95, 0.3, 0.2, 0.55))
	if float(squad["timer"]) <= 0.0 or cleared:
		squad["pending"] = false
		_spawn_reinforcement(squad)


func _squad_engaged(squad_id: int) -> bool:
	for e in _enemies:
		if is_instance_valid(e) and e.squad_id == squad_id and e.engaged:
			return true
	return false


func _squad_alive_count(squad_id: int) -> int:
	var n := 0
	for e in _enemies:
		if is_instance_valid(e) and e.squad_id == squad_id:
			n += 1
	return n


## Step 5: each member auto-uses its Identity skill when usable, else basic
## attack (F-005 §3.8 fallback). NO sub/passive auto (QA-005 §2.6).
func _tick_party_attacks(members: Array, delta: float) -> void:
	# Tank-first gate: AI DPS/Nuker (2nd-line dealers) hold their attack + Identity until the
	# Tank lands its first hit. Open if no Tank is alive; controlled units are always exempt.
	var tank_alive := false
	for t in members:
		if is_instance_valid(t) and String(t.get("class_id")) == "Tank" and t.is_alive():
			tank_alive = true
			break
	for m in members:
		if not is_instance_valid(m):
			continue
		if m.is_stunned():  # F-021: stunned members can't act
			continue
		m.attack_cooldown_s = maxf(0.0, m.attack_cooldown_s - delta)
		m.identity_cooldown_s = maxf(0.0, m.identity_cooldown_s - delta)
		# Provoked (AB-099): forced basic on the caster only — NO Identity/Sub, no normal target,
		# bypasses the tank-first gate. Movement toward the caster is driven by the controllers.
		if m.has_method("is_provoked") and m.is_provoked():
			var src = m.get_provoke_source()
			if src != null and is_instance_valid(src) and m.attack_cooldown_s <= 0.0:
				var to_src: Vector3 = src.global_position - m.global_position
				to_src.y = 0.0
				if to_src.length() <= m.basic_range_m:
					_deal_damage(src, m, m.basic_damage)
					m.attack_cooldown_s = m.basic_interval_s
			continue
		if tank_alive and not _tank_engaged and not m.is_controlled():
			var gcid: String = String(m.get("class_id"))
			if gcid == "DPS" or gcid == "Nuker":
				continue  # 2nd-line dealer waits for the tank's first hit
		# Identity (main) first; fall back to basic when not castable.
		if m.identity_cooldown_s <= 0.0 and _ability_dispatch.try_identity(m):
			continue
		if m.attack_cooldown_s > 0.0:
			continue
		var foe := _nearest_enemy_in_range(m.global_position, m.basic_range_m)
		if foe == null:
			continue
		_deal_damage(foe, m, m.basic_damage)  # basic 평타 → no camera shake
		m.attack_cooldown_s = m.basic_interval_s


func cast_skillbook(member: CharacterBody3D, slot_index: int, target_pos: Vector3 = Vector3.ZERO) -> void:
	_ability_dispatch.cast_skillbook(member, slot_index, target_pos)


## FireDamageHit at a point (F-027 ENT-TORCH) — torch landing / oil contact. ref: F-021.
func ignite_at(center: Vector3, radius: float, source: Node = null) -> void:
	_reactions.ignite_at(center, radius, source)


func _enemies_in_radius(pos: Vector3, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		if Spatial.h_dist2(pos, e.global_position) <= r2:
			out.append(e)
	return out


func _enemies_in_cone(pos: Vector3, axis: Vector3, r: float, half_angle: float) -> Array:
	var out: Array = []
	var r2 := r * r
	var cos_half := cos(half_angle)
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		var to := e.global_position - pos
		to.y = 0.0
		var d2 := to.length_squared()
		if d2 > r2 or d2 < 0.0001:
			continue
		if to.normalized().dot(axis) >= cos_half:
			out.append(e)
	return out


func _lowest_hp_enemy_in_radius(pos: Vector3, r: float) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_hp := INF
	var r2 := r * r
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		if Spatial.h_dist2(pos, e.global_position) > r2:
			continue
		if e.hp < best_hp:
			best_hp = e.hp
			best = e
	return best


func _allies_in_radius(pos: Vector3, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	for a in get_tree().get_nodes_in_group("party_member"):
		var ally := a as Node3D
		if ally == null:
			continue
		if Spatial.h_dist2(pos, ally.global_position) <= r2:
			out.append(ally)
	return out


func _nearest_enemy_in_range(from: Vector3, range_m: float) -> CharacterBody3D:
	# Horizontal (x,z) distance only — party floats above enemies, so a 3D check
	# would push in-range targets out of range by the height gap.
	var best: CharacterBody3D = null
	var best_d := range_m * range_m
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		var d: float = Spatial.h_dist2(from, e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best


## Party→enemy damage with F-022 threat: damage*mult, first-attack bonus,
## group-pull propagation, and first-aggressor floor.
func _deal_damage(enemy: CharacterBody3D, attacker: CharacterBody3D, dmg: float) -> void:
	# D-010 §4.1: damaging a foe engages it and wakes its squad (cohesion radius);
	# group-pull threat below stays within the same squad so distant squads sleep.
	# (Camera hit-feel is emitted ONCE per SUB cast — see AbilityDispatch._sub_hit_shake
	# — not per damaged target, so AOE subs don't stack into a max-out shake.)
	_engage_enemy(enemy)
	enemy.perceive_attacker(attacker)   # hit → search toward the attacker even with no LOS
	enemy.add_threat(attacker, dmg * float(attacker.threat_mult))
	if not _tank_engaged and String(attacker.get("class_id")) == "Tank":
		_tank_engaged = true            # tank's first hit → open the 2nd-line dealer gate
		tank_engaged.emit()
	if not enemy.first_hit:
		enemy.first_hit = true
		enemy.add_threat(attacker, FIRST_ATTACK_BONUS)        # §3.4
		enemy.set_threat_floor(attacker, FIRST_AGGRESSOR_FLOOR)
		if _first_aggressor == null:
			_first_aggressor = attacker
		for e in _enemies:                                    # §3.7 group pull (same squad)
			if is_instance_valid(e) and e != enemy and e.squad_id == enemy.squad_id:
				e.add_threat(attacker, GROUP_PULL_BONUS)
				e.set_threat_floor(attacker, FIRST_AGGRESSOR_FLOOR)
	enemy.take_damage(dmg)


## §3.9 healer threat: each enemy that threatens the healed ally gives the
## healer threat = effectiveHeal * 0.5 (overheal already excluded by heal()).
func _heal_threat(healer: CharacterBody3D, healed: Node, eff_heal: float) -> void:
	if eff_heal <= 0.0:
		return
	var amt := eff_heal * HEAL_THREAT_PER_HP
	for e in _enemies:
		if is_instance_valid(e) and float(e.threat.get(healed, 0.0)) > 0.0:
			e.add_threat(healer, amt)


## Pre-spawn every room's bound encounter as a dormant squad at run start (instead
## of spawning on room entry). Each encounter = one squad; enemies wait dormant deep
## in their rooms (away from the start) — fog-of-war hides them until the party gains
## LOS. Call once after the party has spawned (for base-facing + away-from origin).
func prespawn_encounters(spawn_room: String = "RM-ENTRY-01") -> void:
	# Deterministic "party origin" = the spawn room center (not the controlled
	# char, whose transform may not be settled yet). Squads spawn on the far side
	# of their rooms relative to this, and face away from it (see _init_enemy_perception).
	if _map and _map.has_method("get_spawn_position"):
		_spawn_origin = _map.get_spawn_position(spawn_room)
	# Resolve per room via the spawn table: (pool, run difficulty, room world_layer).
	var difficulty := RunLoadout.get_difficulty()   # hub selection > manifest default (single source)
	for row in Slice01Data.get_rooms_document().get("rooms", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var room_ref := String(row.get("room_ref", ""))
		var pool := String(row.get("pool_slot", ""))
		var layer := String(row.get("world_layer", "Upper"))
		var enc_id := Slice01Data.get_encounter_for_pool(pool, difficulty, layer)
		if enc_id.is_empty():
			continue
		print("[TDC] prespawn resolve: room=%s pool=%s layer=%s diff=%s -> %s" % [room_ref, pool, layer, difficulty, enc_id])
		# The start room's own encounter would spawn on the party — relocate it into
		# the main combat room (the start room's connected room) as its own squad.
		var target_room := room_ref
		if room_ref == spawn_room:
			target_room = _first_connected(spawn_room)
			if target_room.is_empty():
				continue
		_spawn_squad(enc_id, target_room)


## Spawn one encounter as a dormant squad, pushed toward the room's FAR side (away
## from the party) so the start-adjacent room isn't in combat range at spawn.
func _spawn_squad(encounter_id: String, room_ref: String) -> void:
	var enc := Slice01Data.get_encounter(encounter_id)
	var units: Array = enc.get("units", [])
	if units.is_empty():
		return
	var squad_id := _next_squad_id
	_next_squad_id += 1
	# Lane = how many squads already share this room → lateral offset so co-located
	# squads (e.g. relocated start-room encounter + the court's own) don't overlap.
	var lane := int(_room_squad_count.get(room_ref, 0))
	_room_squad_count[room_ref] = lane + 1
	var center: Vector3 = _squad_spawn_center(room_ref, lane)
	_spawn_at(units, center, squad_id, false)
	var reinf: Dictionary = enc.get("reinforcement", {})
	_squads.append({
		"id": squad_id,
		"room_ref": room_ref,
		"reinforce": reinf,
		"pending": not reinf.is_empty(),
		"activated": false,
		"timer": float(reinf.get("delay_s", 12.0)),
		"warned": false,
	})
	print("[TDC] Squad %d (%s) spawned dormant in %s @ %s (origin %s)" % [squad_id, encounter_id, room_ref, center, _spawn_origin])


## Far-interior spawn point for a squad — away from the party's start (_spawn_origin)
## so start-adjacent rooms stay out of combat range until the party advances in.
## `lane` shifts the spawn perpendicular so multiple squads in one room don't stack.
func _squad_spawn_center(room_ref: String, lane: int = 0) -> Vector3:
	if _map == null:
		return Vector3.ZERO
	var center: Vector3 = Vector3.ZERO
	if _map.has_method("get_deep_spawn_position"):
		center = _map.get_deep_spawn_position(room_ref, _spawn_origin)
	elif _map.has_method("get_spawn_position"):
		center = _map.get_spawn_position(room_ref)
	if lane > 0:
		var dir := center - _spawn_origin
		dir.y = 0.0
		if dir.length() > 0.01:
			dir = dir.normalized()
			var perp := Vector3(dir.z, 0.0, -dir.x)  # 90° to the approach axis
			center += perp * (float(lane) * SQUAD_LANE_SPACING)
	return center


## First room the given room opens onto (used to relocate the start-room encounter).
func _first_connected(room_ref: String) -> String:
	var conns: Array = Slice01Data.get_room_row(room_ref).get("connects", [])
	return String(conns[0]) if not conns.is_empty() else ""


func _spawn_at(units: Array, center: Vector3, squad_id: int, engaged: bool) -> void:
	var index := 0
	for u in units:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		var eid := String(u.get("enemy_id", ""))
		var count := int(u.get("count", 1))
		var row := Slice01Data.get_enemy_row(eid)
		if row.is_empty():
			continue
		var vis: Dictionary = UnitVisuals.enemy_visual(eid)
		var s: float = vis["scale"]
		for _c in count:
			var unit: CharacterBody3D = EnemyScene.instantiate()
			add_child(unit)
			# Box collision matches the visual mesh (scaled), so no corner overlap.
			unit.setup(row, vis["color"], s)
			unit.global_position = center + _spawn_offset(index)
			unit.squad_id = squad_id
			unit.engaged = engaged
			if engaged:
				unit.engage_grace_s = COMBAT_EXIT_GRACE_S
			_init_enemy_perception(unit)
			unit.died.connect(_on_enemy_died)
			_enemies.append(unit)
			index += 1


## Give a freshly placed enemy its vision cone (dev viz) + base facing AWAY from the
## party's start (into the room). A straight approach from the entrance comes from
## behind/blind, so combat doesn't trigger the instant you advance — you must flank,
## get close (proximity), or wait out the scan. Keeps the start safe + scoutable.
func _init_enemy_perception(unit: CharacterBody3D) -> void:
	_enemy_ai.attach_vision_cone(unit)  # cone size = AI perception params
	var dir := unit.global_position - _spawn_origin
	dir.y = 0.0
	if dir.length() > 0.5:
		unit.set_base_facing(dir)


## Entry point for a squad's reinforcement wave by direction (ENC reinforcement.direction):
## "rear" (default, ENC-HARD-005 — behind the spawn toward the entrance) or "flank"
## (ENC-HARD-010 — lateral arc, a new side threat rather than the front).
func _reinforce_point(room_ref: String, direction: String) -> Vector3:
	var c := Vector3.ZERO
	if _map and _map.has_method("get_spawn_position"):
		c = _map.get_spawn_position(room_ref)
	if direction == "flank":
		return c + Vector3(9.0, 0, 2.0)   # 측면 — side arc, not the front entrance
	return c + Vector3(0, 0, -8)          # rear — toward the entrance (default)


func _reinforce_direction(squad: Dictionary) -> String:
	var reinf = squad.get("reinforce", {})
	return String(reinf.get("direction", "rear")) if typeof(reinf) == TYPE_DICTIONARY else "rear"


## Spawn a squad's reinforcement wave (already engaged — they arrive into the fight).
func _spawn_reinforcement(squad: Dictionary) -> void:
	var reinf: Dictionary = squad.get("reinforce", {})
	var units: Array = reinf.get("units", [])
	if units.is_empty():
		return
	_spawn_at(units, _reinforce_point(String(squad["room_ref"]), _reinforce_direction(squad)), int(squad["id"]), true)
	print("[TDC] Squad %d reinforcement wave spawned (%s)" % [int(squad["id"]), _reinforce_direction(squad)])


## Deterministic scatter near room center, biased deeper (+Z, away from entrance).
func _spawn_offset(i: int) -> Vector3:
	const RING := [
		Vector3(0, 0, 2.5),
		Vector3(-3.0, 0, 4.5), Vector3(3.0, 0, 4.5),
		Vector3(-1.5, 0, 6.5), Vector3(1.5, 0, 6.5),
		Vector3(0, 0, 8.5),
	]
	if i < RING.size():
		return RING[i]
	return Vector3(float((i * 37) % 8) - 4.0, 0, 3.0 + float((i * 53) % 6))


func _on_enemy_died(unit: CharacterBody3D) -> void:
	_enemies.erase(unit)
	if is_instance_valid(unit):
		var refs: Array = []  # the enemy's own ability refs (dungeon_run filters lootable)
		for a in unit.abilities:
			if typeof(a) == TYPE_DICTIONARY:
				refs.append(String(a.get("ref", "")))
		enemy_defeated.emit(unit.global_position, refs)  # → dungeon_run rolls per-kill loot

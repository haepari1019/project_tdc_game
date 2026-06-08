extends Node3D
## Spawns & runs ENC encounters (box PH enemies). Combat loop added in CP4–5.
## ref: WORK_ORDER §4 · ENC-NORM-001 · QA-005 §2.6 (NC sub skillbook: NO auto).

signal combat_started(encounter_id: String)
signal combat_ended(result: String, encounter_id: String)

const EnemyScene := preload("res://scenes/combat/enemy_unit.tscn")
const SkillVfx := preload("res://scripts/combat/skill_vfx.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")

const COMBAT_TIMEOUT_S := 120.0  # QA-030 §3.3 encounter timeout

# F-022 threat tuning (§3.2 Draft).
const FIRST_ATTACK_BONUS := 120.0   # §3.4 first aggressor on the hit enemy
const GROUP_PULL_BONUS := 60.0      # §3.7 group reacts to first aggressor
const FIRST_AGGRESSOR_FLOOR := 25.0 # §3.5 first aggressor min threat
const TANK_PULSE_FLOOR := 40.0      # §3.10 Anchor Guard temp floor
const HEAL_THREAT_PER_HP := 0.5     # §3.9 healer threat per effective HP
## §3.6 target-switch hysteresis. Lower = aggro bounces more readily (harder).
const SWITCH_RATIO := 1.02


var _party: Node3D
var _map: Node3D
var _enemies: Array[CharacterBody3D] = []
var _active_encounter: String = ""
## Rooms whose encounter has already spawned (no re-spawn on re-entry).
var _spawned_rooms: Dictionary = {}
var _combat_active: bool = false
var _combat_timer_s: float = 0.0
## First party member to damage any enemy this encounter (§3.7 group pull source).
var _first_aggressor: CharacterBody3D = null
# Phase-2 rear reinforcement (ENC-HARD-005 model).
var _reinforce_units: Array = []
var _reinforce_timer_s: float = 0.0
var _reinforce_room: String = ""
var _reinforce_pending: bool = false
var _reinforce_warned: bool = false

## Ability kind -> handler Callable(actor, params, target_pos) -> bool. Built in setup().
## Adding an ability kind = abilities.json data + one registry entry. ref: DEBT-CPL-DUCK.
var _ability_handlers: Dictionary = {}


func setup(party: Node3D, map: Node3D) -> void:
	_party = party
	_map = map
	_build_ability_handlers()


## Data-driven dispatch: kind -> handler. No match statement to grow per ability.
func _build_ability_handlers() -> void:
	_ability_handlers = {
		"shield_pulse": _cast_anchor_guard,
		"cone_sweep": _cast_press_line,
		"mark_burst": _cast_mark_ruin,
		"radius_heal": _cast_mend_circle,
		"sub_taunt": _sub_taunt,
		"sub_lunge": _sub_lunge,
		"sub_nova": _sub_nova,
		"sub_sanctuary": _sub_sanctuary,
	}


## Single source of truth for "are we in combat". Consumers subscribe to
## combat_started/combat_ended or query this — no duplicated flags. ref: DEBT-CPL-COMBAT.
func is_in_combat() -> bool:
	return _combat_active


func _physics_process(delta: float) -> void:
	if not _combat_active:
		return
	_combat_timer_s += delta
	var targets := get_tree().get_nodes_in_group("party_member")
	for enemy in _enemies:
		if is_instance_valid(enemy):
			_tick_enemy(enemy, targets, delta)
	_tick_party_attacks(delta)
	_tick_reinforcement(delta)
	# End conditions: all enemies down (and no reinforcement pending) or timeout.
	if _enemies.is_empty() and not _reinforce_pending:
		_end_combat("victory")
	elif _combat_timer_s >= COMBAT_TIMEOUT_S:
		_end_combat("timeout")


## ENC-HARD-005: rear reinforcement arrives after delay, or instantly once the
## first wave is cleared (so a fast clear still triggers the sandwich).
func _tick_reinforcement(delta: float) -> void:
	if not _reinforce_pending:
		return
	_reinforce_timer_s -= delta
	if not _reinforce_warned and (_reinforce_timer_s <= 2.0 or _enemies.is_empty()):
		_reinforce_warned = true
		print("[TDC] Reinforcements incoming!")
		SkillVfx.telegraph(self, _reinforce_center(), Color(0.95, 0.3, 0.2, 0.55))
	if _reinforce_timer_s <= 0.0 or _enemies.is_empty():
		_reinforce_pending = false
		_spawn_reinforcement()


## Step 5: each member auto-uses its Identity skill when usable, else basic
## attack (F-005 §3.8 fallback). NO sub/passive auto (QA-005 §2.6).
func _tick_party_attacks(delta: float) -> void:
	for m in get_tree().get_nodes_in_group("party_member"):
		if not is_instance_valid(m):
			continue
		if m.is_stunned():  # F-021: stunned members can't act
			continue
		m.attack_cooldown_s = maxf(0.0, m.attack_cooldown_s - delta)
		m.identity_cooldown_s = maxf(0.0, m.identity_cooldown_s - delta)
		# Identity (main) first; fall back to basic when not castable.
		if m.identity_cooldown_s <= 0.0 and _try_identity(m):
			continue
		if m.attack_cooldown_s > 0.0:
			continue
		var foe := _nearest_enemy_in_range(m.global_position, m.basic_range_m)
		if foe == null:
			continue
		_deal_damage(foe, m, m.basic_damage)
		m.attack_cooldown_s = m.basic_interval_s


## Dispatch Identity skill by the LINKED ability's `kind` (not class) — any
## character with that ability_id gets the behavior. Returns true if cast.
func _try_identity(m: CharacterBody3D) -> bool:
	var p: Dictionary = m.identity_params
	var h: Callable = _ability_handlers.get(String(p.get("kind", "")), Callable())
	if not h.is_valid():
		return false
	if h.call(m, p, Vector3.ZERO):
		m.identity_cooldown_s = float(p.get("cooldown_s", 6.0))
		return true
	return false


## AB-020 — self shield + threat pulse when foes in radius. (threat = step 7 smoke)
func _cast_anchor_guard(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3) -> bool:
	var foes := _enemies_in_radius(m.global_position, float(p.get("radius_m", 5.0)))
	if foes.is_empty():
		return false
	var shield_val: float = minf(
		float(p.get("shield_cap", 160.0)),
		float(p.get("shield_base", 80.0)) + float(p.get("shield_per_enemy", 20.0)) * foes.size()
	)
	m.add_shield(shield_val, float(p.get("shield_duration_s", 4.0)))
	# F-022 §3.10: threat pulse to affected foes — tank holds aggro w/o damage race.
	var pulse: float = float(p.get("threat_pulse", 0.0))
	if pulse > 0.0:
		for e in foes:
			e.add_threat(m, pulse)
			e.set_threat_floor(m, TANK_PULSE_FLOOR)  # §3.10 temp threat floor
	SkillVfx.anchor_guard(self, m.global_position, float(p.get("radius_m", 5.0)))
	print("[ID] %s Anchor Guard — shield %d (%d foes)" % [m.identity_skill_id, int(shield_val), foes.size()])
	return true


## AB-024 — forward cone, 3-hit sweep AoE (v1: total applied at once).
func _cast_press_line(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3) -> bool:
	var range_m := float(p.get("range_m", 5.0))
	var nearest := _nearest_enemy_in_range(m.global_position, range_m)
	if nearest == null:
		return false
	var axis := nearest.global_position - m.global_position
	axis.y = 0.0
	axis = axis.normalized()
	var half := deg_to_rad(float(p.get("cone_deg", 60.0)) * 0.5)
	var targets := _enemies_in_cone(m.global_position, axis, range_m, half)
	if targets.is_empty():
		return false
	var total: float = float(p.get("hit_damage_mult", 0.35)) * int(p.get("hits", 3)) * m.basic_damage
	for e in targets:
		_deal_damage(e, m, total)
	SkillVfx.press_line(self, m.global_position, axis, range_m, float(p.get("cone_deg", 60.0)) * 0.5)
	print("[ID] %s Press the Line — %d in cone, %d ea" % [m.identity_skill_id, targets.size(), int(total)])
	return true


## AB-025 — single high-burst on lowest-HP enemy in range (fodder fallback; v1: no telegraph).
func _cast_mark_ruin(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3) -> bool:
	var target := _lowest_hp_enemy_in_radius(m.global_position, float(p.get("range_m", 8.0)))
	if target == null:
		return false
	var dmg: float = float(p.get("ruin_damage_mult", 7.0)) * m.basic_damage
	var tpos: Vector3 = target.global_position
	_deal_damage(target, m, dmg)
	SkillVfx.mark_ruin(self, tpos)
	print("[ID] %s Mark & Ruin -> %s (%d dmg)" % [m.identity_skill_id, target.enemy_id, int(dmg)])
	return true


## AB-026 — radius heal when any ally below threshold (Tank 90% / others 85%).
func _cast_mend_circle(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3) -> bool:
	var radius := float(p.get("radius_m", 4.0))
	var allies := _allies_in_radius(m.global_position, radius)
	var ally_t := float(p.get("ally_threshold_pct", 0.85))
	var tank_t := float(p.get("tank_threshold_pct", 0.90))
	var should := false
	for a in allies:
		var t: float = tank_t if a.class_id == "Tank" else ally_t
		if a.hp / a.max_hp < t:
			should = true
			break
	if not should:
		return false
	var heal_pct := float(p.get("heal_pct", 0.12))
	for a in allies:
		var eff: float = a.heal(a.max_hp * heal_pct)
		_heal_threat(m, a, eff)
	SkillVfx.mend_circle(self, m.global_position, radius)
	print("[ID] %s Mend Circle — %d allies healed" % [m.identity_skill_id, allies.size()])
	return true


# ============================================================================
# Sub skills — PLAYER-activated on the controlled member (key 1). NC never auto.
# ============================================================================

func cast_sub(member: CharacterBody3D, target_pos: Vector3 = Vector3.ZERO) -> void:
	if member == null or not is_instance_valid(member) or not member.is_alive():
		return
	if member.sub_cooldown_s > 0.0:
		print("[SUB] on cooldown (%.1fs)" % member.sub_cooldown_s)
		return
	var p: Dictionary = member.sub_params
	if p.is_empty():
		return
	var h: Callable = _ability_handlers.get(String(p.get("kind", "")), Callable())
	if h.is_valid() and h.call(member, p, target_pos):
		member.sub_cooldown_s = float(p.get("cooldown_s", 10.0))


## Tank: knock back + force aggro on nearby foes + big self shield.
func _sub_taunt(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3) -> bool:
	var pos := m.global_position
	var foes := _enemies_in_radius(pos, float(p.get("radius_m", 6.5)))
	var kb := float(p.get("knockback_m", 3.0))
	var amt := float(p.get("threat_amount", 1500.0))
	for e in foes:
		e.add_threat(m, amt)
		if kb > 0.0:
			e.apply_knockback(e.global_position - pos, kb)
	m.add_shield(float(p.get("shield", 200.0)), float(p.get("shield_duration_s", 5.0)))
	SkillVfx.sub_taunt(self, pos, float(p.get("radius_m", 6.5)))
	print("[SUB] %s Taunt Slam — %d foes pulled" % [m.identity_skill_id, foes.size()])
	return true


## DPS: dash to the targeted ground point (clamped to range) + AoE strike there.
func _sub_lunge(m: CharacterBody3D, p: Dictionary, target_pos: Vector3) -> bool:
	var from := m.global_position
	var off := target_pos - from
	off.y = 0.0
	var dist := off.length()
	var range_m := float(p.get("range_m", 9.0))
	if dist > range_m:
		off = off / dist * range_m
	var dest := from + off
	dest.y = from.y
	m.global_position = dest
	var dmg: float = float(p.get("damage_mult", 5.0)) * m.basic_damage
	for e in _enemies_in_radius(dest, float(p.get("aoe_radius_m", 2.8))):
		_deal_damage(e, m, dmg)
	SkillVfx.sub_lunge(self, from, dest)
	print("[SUB] %s Lunge (dash strike)" % m.identity_skill_id)
	return true


## Nuker: AoE burst + slow at the targeted ground point.
func _sub_nova(m: CharacterBody3D, p: Dictionary, target_pos: Vector3) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var radius := float(p.get("radius_m", 6.5))
	var foes := _enemies_in_radius(center, radius)
	var dmg: float = float(p.get("damage_mult", 3.0)) * m.basic_damage
	var sf := float(p.get("slow_factor", 0.4))
	var sd := float(p.get("slow_duration_s", 4.0))
	for e in foes:
		_deal_damage(e, m, dmg)
		e.apply_slow(sf, sd)
	SkillVfx.sub_nova(self, center, radius)
	print("[SUB] %s Nova @target — %d foes" % [m.identity_skill_id, foes.size()])
	return true


## Healer: big AoE heal + shield to nearby allies.
func _sub_sanctuary(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3) -> bool:
	var pos := m.global_position
	var allies := _allies_in_radius(pos, float(p.get("radius_m", 6.5)))
	var hp_pct := float(p.get("heal_pct", 0.4))
	var sh := float(p.get("shield", 120.0))
	var sdur := float(p.get("shield_duration_s", 6.0))
	for a in allies:
		var eff: float = a.heal(a.max_hp * hp_pct)
		a.add_shield(sh, sdur)
		_heal_threat(m, a, eff)
	SkillVfx.sub_sanctuary(self, pos, float(p.get("radius_m", 6.5)))
	print("[SUB] %s Sanctuary — %d allies" % [m.identity_skill_id, allies.size()])
	return true


func _enemies_in_radius(pos: Vector3, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		var off := pos - e.global_position
		off.y = 0.0
		if off.length_squared() <= r2:
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
		var off := pos - e.global_position
		off.y = 0.0
		if off.length_squared() > r2:
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
		var off: Vector3 = pos - ally.global_position
		off.y = 0.0
		if off.length_squared() <= r2:
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
		var off := from - e.global_position
		off.y = 0.0
		var d: float = off.length_squared()
		if d <= best_d:
			best_d = d
			best = e
	return best


func _end_combat(result: String) -> void:
	_combat_active = false
	if result == "timeout":
		_despawn_all()
	combat_ended.emit(result, _active_encounter)
	print("[TDC] Encounter %s ended: %s (%.1fs)" % [_active_encounter, result, _combat_timer_s])


func _despawn_all() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()


## CP4: chase only — approach the nearest party member, stop at attack range.
## Contact damage intentionally omitted (damage comes from explicit attacks later).
func _tick_enemy(enemy: CharacterBody3D, targets: Array, delta: float) -> void:
	enemy.attack_cooldown_s = maxf(0.0, enemy.attack_cooldown_s - delta)
	enemy.tick_slow(delta)
	# Smoothed knockback push takes over movement for its short duration.
	if enemy.tick_knockback(delta):
		return
	# F-022: target highest-threat party member; pre-threat fallback = nearest.
	enemy.decay_threat(delta)
	var target: CharacterBody3D = enemy.pick_target(_alive_members(targets), SWITCH_RATIO)
	if target == null or float(enemy.threat.get(target, 0.0)) <= 0.0:
		target = _nearest_alive(enemy.global_position, targets)
	if target == null:
		enemy.velocity = Vector3.ZERO
		enemy.move_and_slide()
		return
	enemy.set_target_marker(target)
	var to := target.global_position - enemy.global_position
	to.y = 0.0
	var dist := to.length()
	if dist > enemy.attack_range_m:
		enemy.velocity = (to / maxf(dist, 0.001)) * enemy.current_move_speed()
	else:
		# In range: stop and attack on cooldown (data-driven ability).
		enemy.velocity = Vector3.ZERO
		if enemy.attack_cooldown_s <= 0.0:
			_enemy_attack(enemy, target)
			enemy.attack_cooldown_s = enemy.attack_interval_s
	enemy.move_and_slide()


## Data-driven enemy attack: choose ability (every_n pattern > basic) and apply
## damage*mult + knockback + cue from the shared ability_catalog. Extensible —
## assign any ability to any unit via enemies.json abilities[].ref.
func _enemy_attack(enemy: CharacterBody3D, target: CharacterBody3D) -> void:
	enemy.attack_count += 1
	var chosen: Dictionary = _select_enemy_ability(enemy)
	var eff: Dictionary = {}
	if not chosen.is_empty():
		eff = Slice01Data.get_ability(String(chosen.get("ref", "")))
	var kind := String(eff.get("kind", "enemy_melee"))
	var from := enemy.global_position
	var tpos := target.global_position
	# Telegraphed cast — warning VFX + wind-up; melee can be dodged out of range.
	var tele: float = float(eff.get("telegraph_s", 0.0))
	if tele > 0.0:
		SkillVfx.telegraph(self, tpos, _telegraph_color(kind))
		await get_tree().create_timer(tele).timeout
		if not is_instance_valid(enemy) or not is_instance_valid(target) or not target.is_alive():
			return
		if kind == "enemy_stun":
			var d := target.global_position - enemy.global_position
			d.y = 0.0
			if d.length() > enemy.attack_range_m + 0.6:
				return  # dodged the wind-up
		from = enemy.global_position
		tpos = target.global_position
	target.take_damage(enemy.contact_damage * float(eff.get("damage_mult", 1.0)))
	match kind:
		"enemy_poison":
			target.apply_poison(float(eff.get("poison_dur_s", 4.0)), float(eff.get("poison_dps", 5.0)))
		"enemy_stun":
			target.apply_stun(float(eff.get("stun_s", 1.0)))
		_:
			var kb: float = float(eff.get("knockback_m", 0.0))
			if kb > 0.0:
				target.apply_knockback(target.global_position - from, kb)
	var vfx := String(eff.get("vfx", ""))
	if vfx != "":
		SkillVfx.enemy_vfx(vfx, self, from, tpos)
	if String(chosen.get("trigger", "")) == "every_n" or kind in ["enemy_stun", "enemy_poison"]:
		print("[EN] %s %s -> %s" % [enemy.enemy_id, String(chosen.get("ref", "")), target.identity_skill_id])


func _telegraph_color(kind: String) -> Color:
	match kind:
		"enemy_stun":
			return Color(1.0, 0.85, 0.2, 0.5)
		"enemy_poison":
			return Color(0.4, 0.9, 0.3, 0.5)
	return Color(0.9, 0.3, 0.2, 0.5)


## Pattern ability (every_n match) takes priority; else the basic ability.
func _select_enemy_ability(enemy: CharacterBody3D) -> Dictionary:
	var basic: Dictionary = {}
	for ab in enemy.abilities:
		if typeof(ab) != TYPE_DICTIONARY:
			continue
		var trig := String(ab.get("trigger", ""))
		if trig == "every_n":
			var n := int(ab.get("n", 0))
			if n > 0 and enemy.attack_count % n == 0:
				return ab
		elif trig == "basic" and basic.is_empty():
			basic = ab
	return basic


func _nearest_alive(from: Vector3, nodes: Array) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d := INF
	for n in nodes:
		if not is_instance_valid(n):
			continue
		if n.has_method("is_alive") and not n.is_alive():
			continue
		var d: float = from.distance_squared_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _alive_members(nodes: Array) -> Array:
	var out: Array = []
	for n in nodes:
		if is_instance_valid(n) and (not n.has_method("is_alive") or n.is_alive()):
			out.append(n)
	return out


## Party→enemy damage with F-022 threat: damage*mult, first-attack bonus,
## group-pull propagation, and first-aggressor floor.
func _deal_damage(enemy: CharacterBody3D, attacker: CharacterBody3D, dmg: float) -> void:
	enemy.add_threat(attacker, dmg * float(attacker.threat_mult))
	if not enemy.first_hit:
		enemy.first_hit = true
		enemy.add_threat(attacker, FIRST_ATTACK_BONUS)        # §3.4
		enemy.set_threat_floor(attacker, FIRST_AGGRESSOR_FLOOR)
		if _first_aggressor == null:
			_first_aggressor = attacker
			for e in _enemies:                                # §3.7 group pull
				if is_instance_valid(e) and e != enemy:
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


func on_encounter_triggered(encounter_id: String, room_ref: String) -> void:
	if _spawned_rooms.has(room_ref):
		return
	var enc := Slice01Data.get_encounter(encounter_id)
	var units: Array = enc.get("units", [])
	if units.is_empty():
		return
	_spawned_rooms[room_ref] = true
	_active_encounter = encounter_id
	_first_aggressor = null
	_spawn_units(units, room_ref)
	# Phase-2 reinforcement (optional) — arrives after delay or when wave 1 cleared.
	var reinf: Dictionary = enc.get("reinforcement", {})
	_reinforce_pending = not reinf.is_empty()
	_reinforce_warned = false
	if _reinforce_pending:
		_reinforce_units = reinf.get("units", [])
		_reinforce_timer_s = float(reinf.get("delay_s", 12.0))
		_reinforce_room = room_ref
	print("[TDC] Encounter %s spawned in %s (%d units)" % [
		encounter_id, room_ref, _enemies.size()
	])
	_combat_timer_s = 0.0
	_combat_active = true
	combat_started.emit(encounter_id)


func _spawn_units(units: Array, room_ref: String) -> void:
	var center := Vector3.ZERO
	if _map and _map.has_method("get_spawn_position"):
		center = _map.get_spawn_position(room_ref)
	_spawn_at(units, center)


func _spawn_at(units: Array, center: Vector3) -> void:
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
			unit.died.connect(_on_enemy_died)
			_enemies.append(unit)
			index += 1


## Rear point for reinforcements — behind the initial spawn (toward entrance).
func _reinforce_center() -> Vector3:
	var c := Vector3.ZERO
	if _map and _map.has_method("get_spawn_position"):
		c = _map.get_spawn_position(_reinforce_room)
	return c + Vector3(0, 0, -8)


func _spawn_reinforcement() -> void:
	if _reinforce_units.is_empty():
		return
	_spawn_at(_reinforce_units, _reinforce_center())
	print("[TDC] Reinforcement wave spawned (%d units)" % _enemies.size())
	_reinforce_units = []


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

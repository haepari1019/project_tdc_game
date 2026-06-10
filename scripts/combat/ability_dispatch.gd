extends Node3D
## AbilityDispatch — runs party Identity (auto, NC + controlled) and Sub (player-only,
## controlled) skill effects, dispatched by the LINKED ability's `kind` (data-driven,
## not class). Extracted from CombatController to isolate "what each skill does" from the
## combat loop / spawning / threat (ARCHITECTURE DEBT-GOD2). A child of CombatController:
## parents skill VFX + calls back for spatial queries / damage / heal-threat / camera
## shake (those shared systems stay single-owned on the controller).
## ref: F-005 (NC main-skill rules) · QA-005 §2.6 (no sub auto) · AB-020/024/025/026 + sub.

const SkillVfx := preload("res://scripts/combat/skill_vfx.gd")

const TANK_PULSE_FLOOR := 40.0    # F-022 §3.10 Anchor Guard temp threat floor

# Camera hit-feel for player SUB skills — ONE shake per cast (not per AOE target).
const SUB_SHAKE_MULT_REF := 8.0   # 타격감: trauma = sub damage_mult/ref
const HIT_SHAKE_CAP := 0.6

var _combat: Node3D  # CombatController — spatial queries / damage / threat / shake owner

## Ability kind -> handler Callable(actor, params, target_pos) -> bool. Built in setup().
## Adding an ability kind = abilities.json data + one registry entry. ref: DEBT-CPL-DUCK.
var _ability_handlers: Dictionary = {}


func setup(combat: Node3D) -> void:
	_combat = combat
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


## Dispatch Identity skill by the LINKED ability's `kind` (not class) — any character
## with that ability_id gets the behavior. Returns true if cast. (Called by the combat
## loop's party auto-attack: Identity first, basic attack as the fallback.)
func try_identity(m: CharacterBody3D) -> bool:
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
	var foes: Array = _combat._enemies_in_radius(m.global_position, float(p.get("radius_m", 5.0)))
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
	var nearest: CharacterBody3D = _combat._nearest_enemy_in_range(m.global_position, range_m)
	if nearest == null:
		return false
	var axis := nearest.global_position - m.global_position
	axis.y = 0.0
	axis = axis.normalized()
	var half := deg_to_rad(float(p.get("cone_deg", 60.0)) * 0.5)
	var targets: Array = _combat._enemies_in_cone(m.global_position, axis, range_m, half)
	if targets.is_empty():
		return false
	var total: float = float(p.get("hit_damage_mult", 0.35)) * int(p.get("hits", 3)) * m.basic_damage
	for e in targets:
		_combat._deal_damage(e, m, total)
	SkillVfx.press_line(self, m.global_position, axis, range_m, float(p.get("cone_deg", 60.0)) * 0.5)
	print("[ID] %s Press the Line — %d in cone, %d ea" % [m.identity_skill_id, targets.size(), int(total)])
	return true


## AB-025 — single high-burst on lowest-HP enemy in range (fodder fallback; v1: no telegraph).
func _cast_mark_ruin(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3) -> bool:
	var target: CharacterBody3D = _combat._lowest_hp_enemy_in_radius(m.global_position, float(p.get("range_m", 8.0)))
	if target == null:
		return false
	var dmg: float = float(p.get("ruin_damage_mult", 7.0)) * m.basic_damage
	var tpos: Vector3 = target.global_position
	_combat._deal_damage(target, m, dmg)
	SkillVfx.mark_ruin(self, tpos)
	print("[ID] %s Mark & Ruin -> %s (%d dmg)" % [m.identity_skill_id, target.enemy_id, int(dmg)])
	return true


## AB-026 — radius heal when any ally below threshold (Tank 90% / others 85%).
func _cast_mend_circle(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3) -> bool:
	var radius := float(p.get("radius_m", 4.0))
	var allies: Array = _combat._allies_in_radius(m.global_position, radius)
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
		_combat._heal_threat(m, a, eff)
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
	var foes: Array = _combat._enemies_in_radius(pos, float(p.get("radius_m", 6.5)))
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


## Camera hit-feel for a player-activated SUB skill — ONE shake per cast (not per
## damaged target, so AOE subs don't stack to max), scaled by the skill's damage_mult
## (lunge 5.0 > nova 3.0). Subs are controlled-only (NC never auto-subs) → no attenuation.
func _sub_hit_shake(p: Dictionary) -> void:
	var t: float = clampf(float(p.get("damage_mult", 1.0)) / SUB_SHAKE_MULT_REF, 0.0, HIT_SHAKE_CAP)
	_combat.camera_shake.emit(t, Vector3.ZERO)


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
	for e in _combat._enemies_in_radius(dest, float(p.get("aoe_radius_m", 2.8))):
		_combat._deal_damage(e, m, dmg)
	_sub_hit_shake(p)  # 서브 타격감: 캐스트당 1회(타깃 수와 무관)
	SkillVfx.sub_lunge(self, from, dest)
	print("[SUB] %s Lunge (dash strike)" % m.identity_skill_id)
	return true


## Nuker: AoE burst + slow at the targeted ground point.
func _sub_nova(m: CharacterBody3D, p: Dictionary, target_pos: Vector3) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var radius := float(p.get("radius_m", 6.5))
	var foes: Array = _combat._enemies_in_radius(center, radius)
	var dmg: float = float(p.get("damage_mult", 3.0)) * m.basic_damage
	var sf := float(p.get("slow_factor", 0.4))
	var sd := float(p.get("slow_duration_s", 4.0))
	for e in foes:
		_combat._deal_damage(e, m, dmg)
		e.apply_slow(sf, sd)
	_sub_hit_shake(p)  # 서브 타격감: 캐스트당 1회(타깃 수와 무관)
	SkillVfx.sub_nova(self, center, radius)
	print("[SUB] %s Nova @target — %d foes" % [m.identity_skill_id, foes.size()])
	return true


## Healer: big AoE heal + shield to nearby allies.
func _sub_sanctuary(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3) -> bool:
	var pos := m.global_position
	var allies: Array = _combat._allies_in_radius(pos, float(p.get("radius_m", 6.5)))
	var hp_pct := float(p.get("heal_pct", 0.4))
	var sh := float(p.get("shield", 120.0))
	var sdur := float(p.get("shield_duration_s", 6.0))
	for a in allies:
		var eff: float = a.heal(a.max_hp * hp_pct)
		a.add_shield(sh, sdur)
		_combat._heal_threat(m, a, eff)
	SkillVfx.sub_sanctuary(self, pos, float(p.get("radius_m", 6.5)))
	print("[SUB] %s Sanctuary — %d allies" % [m.identity_skill_id, allies.size()])
	return true

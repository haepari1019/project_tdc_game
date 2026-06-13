extends Node3D
## AbilityDispatch — dispatches party Identity (auto, NC + controlled) + Sub (player-only)
## skill effects by the LINKED ability's `kind`. Each EFFECT is its own drop-in file under
## effects/ implementing `kind() -> String` + `cast(actor, params, target_pos, ctx) -> bool`.
## This node is BOTH the dispatcher AND the `ctx` facade skills call back (spatial queries /
## damage / heal-threat / camera shake / reactions / VFX parent). Shared systems stay owned by
## CombatController + ReactionSystem; skills never touch them directly.
## **ADD A SKILL = drop a file in effects/ + add one line to _SKILL_SCRIPTS** (the kind()
## string lives in the file — no other central edit). ref: F-005 · F-009 · QA-005 §2.6.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")

## Drop-in skill effects. Each is loaded + instantiated once at setup() and registered by its
## kind(). Horizontal expansion: new skill = new effects/<name>.gd + one preload line here.
const _SKILL_SCRIPTS := [
	preload("res://scripts/combat/abilities/effects/anchor_guard.gd"),
	preload("res://scripts/combat/abilities/effects/press_line.gd"),
	preload("res://scripts/combat/abilities/effects/mark_ruin.gd"),
	preload("res://scripts/combat/abilities/effects/mend_circle.gd"),
	preload("res://scripts/combat/abilities/effects/taunt.gd"),
	preload("res://scripts/combat/abilities/effects/lunge.gd"),
	preload("res://scripts/combat/abilities/effects/nova.gd"),
	preload("res://scripts/combat/abilities/effects/sanctuary.gd"),
	preload("res://scripts/combat/abilities/effects/sb_strike.gd"),
	preload("res://scripts/combat/abilities/effects/sb_poison.gd"),
	preload("res://scripts/combat/abilities/effects/sb_stun.gd"),
	preload("res://scripts/combat/abilities/effects/sb_fire.gd"),
]

# F-009 §3.2.1 Family Mismatch Penalty — off-main-class (sub) skillbook use. Demo heuristic:
# main class = first equip class; others equip+use but at this coeff. Spec −10%.
const SUB_CLASS_COEFF := 0.9
# Camera hit-feel for player SUB skills — ONE shake per cast (not per AOE target).
const SUB_SHAKE_MULT_REF := 8.0   # 타격감: trauma = sub damage_mult/ref
const HIT_SHAKE_CAP := 0.6

var _combat: Node3D    # CombatController — spatial queries / damage / threat / shake owner
var _reactions: Node3D  # ReactionSystem — destructibles + RX-OIL-FIRE chain
var _skills: Dictionary = {}  # kind -> skill instance (built from _SKILL_SCRIPTS)


func setup(combat: Node3D, reactions: Node3D) -> void:
	_combat = combat
	_reactions = reactions
	for s in _SKILL_SCRIPTS:
		var skill = s.new()
		_skills[String(skill.kind())] = skill


## Dispatch Identity skill by the LINKED ability's `kind` (not class) — any character with
## that ability_id gets the behavior. Returns true if cast. (party auto-attack: Identity first.)
func try_identity(m: CharacterBody3D) -> bool:
	var p: Dictionary = m.identity_params
	var skill = _skills.get(String(p.get("kind", "")))
	if skill == null:
		return false
	if skill.cast(m, p, Vector3.ZERO, self):
		m.identity_cooldown_s = float(p.get("cooldown_s", 6.0))
		return true
	return false


## Player-activated SUB on the controlled member (key 1). NC never auto-subs.
func cast_sub(member: CharacterBody3D, target_pos: Vector3 = Vector3.ZERO) -> void:
	if member == null or not is_instance_valid(member) or not member.is_alive():
		return
	if member.sub_cooldown_s > 0.0:
		print("[SUB] on cooldown (%.1fs)" % member.sub_cooldown_s)
		return
	var p: Dictionary = member.sub_params
	if p.is_empty():
		return
	var skill = _skills.get(String(p.get("kind", "")))
	if skill != null and skill.cast(member, p, target_pos, self):
		member.sub_cooldown_s = float(p.get("cooldown_s", 10.0))


## Player-cast a sub skillbook from slot Q/E/R. Charges + cooldown gated; on success
## -1 charge + set the slot's cooldown. Effect = the Shared AB applied to enemies.
func cast_skillbook(member: CharacterBody3D, slot_index: int, target_pos: Vector3 = Vector3.ZERO) -> void:
	if member == null or not is_instance_valid(member) or not member.is_alive():
		return
	var inst = member.get_skillbook(slot_index)
	if inst == null:
		return
	if int(inst.charges) <= 0:
		print("[SB] %s depleted" % inst.get("display_name", "?"))
		return
	if float(inst.cooldown_s) > 0.0:
		return
	var p: Dictionary = inst.params
	# F-009 §3.2.1 — off-main-class (sub) use is penalized; main = first equip class.
	var classes: Array = inst.get("equip_classes", [])
	p["_coeff"] = SUB_CLASS_COEFF if not classes.is_empty() and String(member.class_id) != String(classes[0]) else 1.0
	# target_pos = aimed ground point (targeted subs) or caster position (self-centered).
	var skill = _skills.get(String(p.get("kind", "")))
	if skill != null and skill.cast(member, p, target_pos, self):
		inst.charges = int(inst.charges) - 1
		inst.cooldown_s = float(p.get("cooldown_s", 6.0))


# ============================================================================
# ctx facade — drop-in skills call these (shared systems stay single-owned).
# ============================================================================

func enemies_in_radius(pos: Vector3, r: float) -> Array:
	return _combat._enemies_in_radius(pos, r)


func nearest_enemy_in_range(pos: Vector3, r: float) -> CharacterBody3D:
	return _combat._nearest_enemy_in_range(pos, r)


func enemies_in_cone(pos: Vector3, axis: Vector3, r: float, half: float) -> Array:
	return _combat._enemies_in_cone(pos, axis, r, half)


func lowest_hp_enemy_in_radius(pos: Vector3, r: float) -> CharacterBody3D:
	return _combat._lowest_hp_enemy_in_radius(pos, r)


func allies_in_radius(pos: Vector3, r: float) -> Array:
	return _combat._allies_in_radius(pos, r)


func deal_damage(e: CharacterBody3D, source: CharacterBody3D, dmg: float) -> void:
	_combat._deal_damage(e, source, dmg)


func heal_threat(healer: CharacterBody3D, ally: CharacterBody3D, eff: float) -> void:
	_combat._heal_threat(healer, ally, eff)


func shake(trauma: float) -> void:
	_combat.camera_shake.emit(trauma, Vector3.ZERO)


## SUB hit-feel: ONE shake per cast, scaled by damage_mult (capped). Skills call after impact.
func sub_shake(p: Dictionary) -> void:
	var t: float = clampf(float(p.get("damage_mult", 1.0)) / SUB_SHAKE_MULT_REF, 0.0, HIT_SHAKE_CAP)
	_combat.camera_shake.emit(t, Vector3.ZERO)


func damage_destructibles(pos: Vector3, r: float, dmg: float) -> bool:
	return _reactions.damage_destructibles(pos, r, dmg)


func fire_hit(center: Vector3, r: float, depth: int, source: Node = null) -> void:
	_reactions.fire_hit(center, r, depth, source)

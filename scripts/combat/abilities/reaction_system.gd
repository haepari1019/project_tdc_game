extends Node3D
## ReactionSystem — world-object AoE interactions + hazard chemistry, extracted from
## AbilityDispatch (ARCHITECTURE DEBT-GOD2). Owns: breaking destructibles (ENT-BARREL), the
## RX-OIL-FIRE-001 oil ignition chain (explosion + Fire/ToxicGas zones, depth-limited), and
## the public FireDamageHit entry (torches). A child of CombatController: skill handlers call
## damage_destructibles()/fire_hit(); torches reach ignite_at() via the combat facade.
## ref: F-021 / F-027 (ZONE-OIL, RX-OIL-FIRE, ENT-BARREL/TORCH).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const HazardZone := preload("res://scripts/world/hazards/hazard_zone.gd")

const FIRE_DPS := 14.0
const FIRE_TTL := 4.0
const GAS_DPS := 8.0
const GAS_TTL := 5.0
const EXPLOSION_DMG := 60.0
const MAX_CHAIN_DEPTH := 2
const EXPLOSION_SHAKE := 0.6   # an explosion always shakes at the per-cast cap

var _combat: Node3D  # CombatController — camera shake owner


func setup(combat: Node3D) -> void:
	_combat = combat


## AoE breaks barrels / destructibles (ENT-BARREL) in range. Returns true if any hit.
func damage_destructibles(center: Vector3, radius: float, dmg: float) -> bool:
	var hit := false
	for d in get_tree().get_nodes_in_group("destructible"):
		if d is Node3D and d.has_method("take_damage"):
			var off := Vector2(d.global_position.x - center.x, d.global_position.z - center.z)
			if off.length() <= radius:
				d.take_damage(dmg)
				hit = true
	return hit


## A fire damage hit at a point — ignites any overlapping Oil zone (RX-OIL-FIRE-001).
func fire_hit(center: Vector3, radius: float, depth: int, source: Node = null) -> void:
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if z.is_active() and String(z.status) == "Oil":
			var d := Vector2(z.global_position.x - center.x, z.global_position.z - center.z)
			if d.length() <= radius + float(z.radius):
				_ignite_oil(z, depth, source)


## RX-OIL-FIRE-001 — consume the oil → explosion + Fire zone + ToxicGas, then chain to
## adjacent oil (depth-limited; F-021 §3.2.1 depth 1 center / 2 rare / 3+ forbidden).
func _ignite_oil(oil: Node, depth: int, source: Node = null) -> void:
	var parent := oil.get_parent()
	var pos: Vector3 = oil.global_position
	var r: float = float(oil.radius)
	oil.clear_zone()  # consume the oil (removed from group immediately → no re-ignite)
	_explosion(pos, r + 1.0, EXPLOSION_DMG, source)
	var fire := HazardZone.new()
	fire.setup(r, FIRE_DPS, 0.0, "Fire", false, FIRE_TTL)
	fire.position = pos
	parent.add_child(fire)
	var gas := HazardZone.new()
	gas.setup(r + 1.5, GAS_DPS, 0.0, "ToxicGas", false, GAS_TTL)
	gas.position = pos
	parent.add_child(gas)
	if source != null:
		fire.set_source(source)
		gas.set_source(source)
	print("[RX] Oil ignited (depth %d) → explosion + fire + toxic gas" % depth)
	if depth < MAX_CHAIN_DEPTH:
		fire_hit(pos, r + 1.5, depth + 1, source)  # explosion reaches adjacent oil → chain +1


## AoE explosion — damage ALL units (피아무구분, F-021 §3.3.1) + destructibles + shake.
func _explosion(pos: Vector3, radius: float, dmg: float, source: Node = null) -> void:
	for g in ["party_member", "enemy"]:
		for u in get_tree().get_nodes_in_group(g):
			if u is Node3D and u.has_method("take_damage"):
				var d := Vector2(u.global_position.x - pos.x, u.global_position.z - pos.z)
				if d.length() <= radius:
					u.take_damage(dmg)
					if g == "enemy" and source != null and is_instance_valid(source) and u.has_method("add_threat"):
						u.add_threat(source, dmg)
						if u.has_method("perceive_attacker"):
							u.perceive_attacker(source)
	damage_destructibles(pos, radius, dmg)
	_combat.camera_shake.emit(EXPLOSION_SHAKE, Vector3.ZERO)
	SkillVfx.telegraph(self, pos, Color(1.0, 0.55, 0.12))


## Public FireDamageHit at a point (F-027 ENT-TORCH) — a thrown/dropped torch landing, or a
## lit torch touching oil. Lays a short Fire zone (the spot burns) and ignites any overlapping
## Oil → RX-OIL-FIRE-001 explosion + chain. ref: F-021 §3.1.2.
func ignite_at(center: Vector3, radius: float, source: Node = null) -> void:
	var fire := HazardZone.new()
	fire.setup(radius, FIRE_DPS, 0.0, "Fire", false, FIRE_TTL)
	add_child(fire)
	fire.global_position = center
	if source != null:
		fire.set_source(source)
	fire_hit(center, radius, 0, source)
	SkillVfx.telegraph(self, center, Color(1.0, 0.5, 0.12))

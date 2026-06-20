extends Node3D
## ReactionSystem — world-object AoE interactions + hazard chemistry, extracted from
## AbilityDispatch (ARCHITECTURE DEBT-GOD2). Owns: breaking destructibles (ENT-BARREL), the
## RX-OIL-FIRE-001 oil ignition chain (explosion + Ignited + Fire/Smoke zones, depth-limited), and
## the public FireDamageHit entry (torches). A child of CombatController: skill handlers call
## damage_destructibles()/fire_hit(); torches reach ignite_at() via the combat facade.
## ref: F-021 / F-027 (ZONE-OIL, RX-OIL-FIRE, ENT-BARREL/TORCH).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const HazardZone := preload("res://scripts/world/hazards/hazard_zone.gd")

const FIRE_DPS := 8.0       # residual fire = Ignited burn dps (hazard_zone Fire→Ignited)
const FIRE_TTL := 4.0       # SPAWN-ZONE-FIRE-4S-R2
const IGNITE_DUR := 5.0     # APPLY-IGNITED-…-5S — explosion ignites caught units
const SMOKE_TTL := 5.0      # SPAWN-ZONE-SMOKE-5S-R3 — 연소 연기(무해·시야), ToxicGas 아님
const EXPLOSION_DMG := 60.0
const MAX_CHAIN_DEPTH := 2
const EXPLOSION_SHAKE := 0.6   # an explosion always shakes at the per-cast cap
const STEAM_TTL := 5.0         # RX-FIRE-WATER → Steam
const GAS_FLASH_DMG := 22.0    # RX-TOXICGAS-FIRE flash
## EVENT-CORE §3 primaryMedium priority (high→low) — resolver picks ONE combo RX per Hit tile.
const RX_PRIORITY := ["Oil", "ToxicGas", "Water", "Fire", "Steam", "Smoke", "Ice", "Vegetation", "Wind"]
## Live FireDamageHit combo matrix (primaryMedium → RX). Lightning/Cold/Physical RX activate when
## their emitter ABs land (S3f); Fire/Smoke/Ice/Wind primary = no combo (skill damage only).
const RX_FIRE_MATRIX := {
	"Oil": "oil_fire", "Water": "fire_water", "Vegetation": "fire_vegetation", "ToxicGas": "toxicgas_fire",
}
## ColdDamageHit combo matrix (AB-041 Glacial Bolt). Water→Ice (freeze), Vegetation→Slowed (frostbite).
const RX_COLD_MATRIX := {
	"Water": "cold_water", "Vegetation": "vegetation_cold",
}
## LightningHit (AB-004 charge): Water→Shock (conductive), Steam→Shock (weak).
const RX_LIGHTNING_MATRIX := { "Water": "lightning_water", "Steam": "steam_lightning" }
## PhysicalImpact (knockback / bash): Oil→Slippery (knocked onto a slick).
const RX_PHYSICAL_MATRIX := { "Oil": "oil_physical" }

var _combat: Node3D  # CombatController — camera shake owner


func setup(combat: Node3D) -> void:
	_combat = combat
	add_to_group("event_bus")  # zones/skills emit via call_group("event_bus", "emit_event", …)


## Central event bus (EVENT-CORE). Skills/zones/entities emit; RX handlers dispatch here. For now
## FireDamageHit → oil ignition; EnterZone/ExitZone/Explosion/Lightning/Cold/Physical are foundation
## (the data-driven RX matrix + primaryMedium resolver land in P2-S3d).
func emit_event(event_id: String, payload: Dictionary) -> void:
	match event_id:
		"FireDamageHit":
			_on_fire_damage_hit(payload)
		"ColdDamageHit":
			_on_cold_damage_hit(payload)
		"LightningHit":
			_on_lightning_hit(payload)
		"PhysicalImpact":
			_on_physical_impact(payload)
		_:
			pass  # EnterZone/ExitZone aura = per-tick; WindGust spread = S3e


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


## Public FireDamageHit entry (callers: torch ignite_at, RX-OIL-FIRE chain) — emits the event so
## the RX layer (event bus) handles it. ref: EVENT-CORE FireDamageHit.
func fire_hit(center: Vector3, radius: float, depth: int, source: Node = null) -> void:
	emit_event("FireDamageHit", {"position": center, "radius": radius, "depth": depth, "source": source})


## FireDamageHit → resolve the tile's primaryMedium (EVENT-CORE §3) → ONE combo RX. Oil→explosion,
## Water→Steam, Vegetation→burn, ToxicGas→toxic flash. (Fire/Smoke/Ice/Wind primary → no combo.)
func _on_fire_damage_hit(p: Dictionary) -> void:
	var center: Vector3 = p.get("position", Vector3.ZERO)
	var radius: float = float(p.get("radius", 1.0))
	var depth: int = int(p.get("depth", 0))
	var source: Node = p.get("source")
	var zones := _zones_overlapping(center, radius)
	if zones.is_empty():
		return  # no environment medium → skill damage only
	match String(RX_FIRE_MATRIX.get(_primary_medium_of(zones), "")):
		"oil_fire":
			for z in zones:
				if String(z.status) == "Oil":
					_ignite_oil(z, depth, source)
					return
		"fire_water":
			_rx_fire_water(zones, source)
		"fire_vegetation":
			_rx_fire_vegetation(zones, source)
		"toxicgas_fire":
			_rx_toxicgas_fire(zones, source)


## Active ground zones overlapping a hit point (within radius + zone radius).
func _zones_overlapping(center: Vector3, radius: float) -> Array:
	var out: Array = []
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if z.is_active():
			var d := Vector2(z.global_position.x - center.x, z.global_position.z - center.z)
			if d.length() <= radius + float(z.radius):
				out.append(z)
	return out


## primaryMedium of a tile = highest-priority medium present (EVENT-CORE §3 / INT-002 §6.1).
func _primary_medium_of(zones: Array) -> String:
	var best := ""
	var best_rank := 999
	for z in zones:
		var rank := RX_PRIORITY.find(String(z.status))
		if rank >= 0 and rank < best_rank:
			best_rank = rank
			best = String(z.status)
	return best


## Spawn a medium zone (RX result). dps>0 carries the source for aggro crediting.
func spawn_zone(medium: String, pos: Vector3, radius: float, dps: float, ttl: float, source: Node) -> void:
	var z := HazardZone.new()
	z.setup(radius, dps, 0.0, medium, false, ttl)
	add_child(z)
	z.global_position = pos
	if source != null and dps > 0.0:
		z.set_source(source)


## RX-FIRE-WATER-001 — Water boils off → Steam (consume Water, spawn Steam). out: Steam.
func _rx_fire_water(zones: Array, source: Node) -> void:
	var done := false
	for z in zones:
		if String(z.status) == "Water":
			var pos: Vector3 = z.global_position
			var r: float = float(z.radius)
			z.clear_zone()
			if not done:
				spawn_zone("Steam", pos, r, 0.0, STEAM_TTL, source)
				done = true
	print("[RX] FireDamageHit + Water → Steam (RX-FIRE-WATER-001)")


## RX-FIRE-VEGETATION-001 — vegetation catches fire → Fire zone (Ignited). out: Ignited.
func _rx_fire_vegetation(zones: Array, source: Node) -> void:
	for z in zones:
		if String(z.status) == "Vegetation":
			var pos: Vector3 = z.global_position
			var r: float = float(z.radius)
			z.clear_zone()
			spawn_zone("Fire", pos, r, FIRE_DPS, FIRE_TTL, source)
	print("[RX] FireDamageHit + Vegetation → burn (RX-FIRE-VEGETATION-001)")


## RX-TOXICGAS-FIRE-001 — toxic flash: burst damage + Poisoned to units in the gas, consume it.
func _rx_toxicgas_fire(zones: Array, source: Node) -> void:
	for z in zones:
		if String(z.status) != "ToxicGas":
			continue
		for g in ["party_member", "enemy"]:
			for u in get_tree().get_nodes_in_group(g):
				if u is Node3D and z.contains_point((u as Node3D).global_position):
					if u.has_method("apply_poison"):
						u.apply_poison(4.0, FIRE_DPS)
					elif u.has_method("take_damage"):
						u.take_damage(GAS_FLASH_DMG)
		z.clear_zone()
	_combat.camera_shake.emit(0.3, Vector3.ZERO)
	print("[RX] FireDamageHit + ToxicGas → toxic flash (RX-TOXICGAS-FIRE-001)")


## ColdDamageHit → primaryMedium combo: Water→freeze to Ice, Vegetation→frostbite Slowed.
func _on_cold_damage_hit(p: Dictionary) -> void:
	var center: Vector3 = p.get("position", Vector3.ZERO)
	var radius: float = float(p.get("radius", 1.5))
	var zones := _zones_overlapping(center, radius)
	if zones.is_empty():
		return
	match String(RX_COLD_MATRIX.get(_primary_medium_of(zones), "")):
		"cold_water":
			_rx_cold_water(zones, p.get("source"))
		"vegetation_cold":
			_rx_vegetation_cold(zones)


## RX-COLD-WATER-001 — Water freezes → Ice (consume Water, spawn Ice). out: Ice (ENV).
func _rx_cold_water(zones: Array, source: Node) -> void:
	var done := false
	for z in zones:
		if String(z.status) == "Water":
			var pos: Vector3 = z.global_position
			var r: float = float(z.radius)
			z.clear_zone()
			if not done:
				spawn_zone("Ice", pos, r, 0.0, STEAM_TTL, source)
				done = true
	print("[RX] ColdDamageHit + Water → Ice (RX-COLD-WATER-001)")


## RX-VEGETATION-COLD-001 — frostbitten plants → Chilled to units in the patch. out: Slowed.
func _rx_vegetation_cold(zones: Array) -> void:
	_rx_outcome_in(zones, "Vegetation", "Chilled", 3.0)
	print("[RX] ColdDamageHit + Vegetation → frostbite (RX-VEGETATION-COLD-001)")


## LightningHit → primaryMedium combo: Water/Steam conduct → Shock to everyone in the medium.
func _on_lightning_hit(p: Dictionary) -> void:
	var zones := _zones_overlapping(p.get("position", Vector3.ZERO), float(p.get("radius", 1.5)))
	if zones.is_empty():
		return
	match String(RX_LIGHTNING_MATRIX.get(_primary_medium_of(zones), "")):
		"lightning_water":
			_rx_outcome_in(zones, "Water", "Shock", 2.0)
			print("[RX] LightningHit + Water → Shock (RX-LIGHTNING-WATER-001)")
		"steam_lightning":
			_rx_outcome_in(zones, "Steam", "Shock", 1.0)
			print("[RX] LightningHit + Steam → Shock weak (RX-STEAM-LIGHTNING-001)")


## PhysicalImpact → Oil-Physical: knocked onto a slick → Slippery (RX-OIL-PHYSICAL-001).
func _on_physical_impact(p: Dictionary) -> void:
	var zones := _zones_overlapping(p.get("position", Vector3.ZERO), float(p.get("radius", 1.5)))
	if zones.is_empty():
		return
	if String(RX_PHYSICAL_MATRIX.get(_primary_medium_of(zones), "")) == "oil_physical":
		_rx_outcome_in(zones, "Oil", "Slippery", 3.0)
		print("[RX] PhysicalImpact + Oil → Slippery (RX-OIL-PHYSICAL-001)")


## Apply an outcome to every unit standing in zones of the given medium (피아무구분).
func _rx_outcome_in(zones: Array, medium: String, outcome: String, dur: float) -> void:
	for z in zones:
		if String(z.status) != medium:
			continue
		for g in ["party_member", "enemy"]:
			for u in get_tree().get_nodes_in_group(g):
				if u is Node3D and z.contains_point((u as Node3D).global_position) and u.has_method("apply_outcome"):
					u.apply_outcome(outcome, dur)


## RX-OIL-FIRE-001 — consume the oil → explosion (+Ignited) + Fire zone + harmless Smoke (NOT
## ToxicGas; spec: 연소 연기·무해), then chain to adjacent oil (depth-limited; F-021 §3.2.1).
func _ignite_oil(oil: Node, depth: int, source: Node = null) -> void:
	var parent := oil.get_parent()
	var pos: Vector3 = oil.global_position
	var r: float = float(oil.radius)
	oil.clear_zone()  # consume the oil (removed from group immediately → no re-ignite)
	_explosion(pos, r + 1.0, EXPLOSION_DMG, source)
	var fire := HazardZone.new()
	fire.setup(r, FIRE_DPS, 0.0, "Fire", false, FIRE_TTL)  # residual fire → Ignited (hazard_zone)
	fire.position = pos
	parent.add_child(fire)
	if source != null:
		fire.set_source(source)
	var smoke := HazardZone.new()
	smoke.setup(r + 1.5, 0.0, 0.0, "Smoke", false, SMOKE_TTL)  # 연소 연기 — 무해(시야), 독 아님
	smoke.position = pos
	parent.add_child(smoke)
	print("[RX] Oil ignited (depth %d) → explosion + Ignited + fire + smoke (RX-OIL-FIRE-001)" % depth)
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
					if u.has_method("apply_outcome"):
						u.apply_outcome("Ignited", IGNITE_DUR, FIRE_DPS)  # APPLY-IGNITED-…-5S
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

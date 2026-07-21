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
## B7 WindGust spread (S3e) — a Wind zone blows overlapping media downwind as small child zones.
## Bounded: ≤SPREAD_PER_GUST children per wind zone per tick, ≤SPREAD_CAP live spread zones total
## (per-room cap proxy). Spread children don't re-spread. First pass — needs F5 tuning. ref F-021 §3.2.
const SPREAD_CADENCE_S := 2.0
const SPREAD_PER_GUST := 2
const SPREAD_CAP := 6
const SPREAD_STEP_M := 1.6
const SPREAD_TTL := 4.0
## passive 존 쌍 반응(사용자 2026-07-21) — 두 존이 그냥 겹쳐 있으면 물리적으로 반응(Hit 없이).
const ZONE_RX_CADENCE_S := 0.4    # 겹침 검사 주기
const ZONE_SHRINK_STEP := 0.5     # Fire↔Water 상호 소진 시 틱당 반경 감소(원 단위 확산 근사)
const SPREADABLE_MEDIA := ["Oil", "Water", "Fire", "Ice", "Vegetation", "ToxicGas"]
## EVENT-CORE §3 primaryMedium priority (high→low) — resolver picks ONE combo RX per Hit tile.
const RX_PRIORITY := ["Oil", "ToxicGas", "Water", "Fire", "Steam", "Smoke", "Ice", "Vegetation", "Wind"]
## Live FireDamageHit combo matrix (primaryMedium → RX). Lightning/Cold/Physical RX activate when
## their emitter ABs land (S3f); Fire/Smoke/Ice/Wind primary = no combo (skill damage only).
const RX_FIRE_MATRIX := {
	"Oil": "oil_fire", "Water": "fire_water", "Vegetation": "fire_vegetation", "ToxicGas": "toxicgas_fire",
	"Ice": "fire_ice",   # F3: Ice melts → Water (RX-FIRE-ICE-001)
}
## ColdDamageHit combo matrix (AB-041 Glacial Bolt). Water→Ice (freeze), Vegetation→Slowed (frostbite).
const RX_COLD_MATRIX := {
	"Water": "cold_water", "Vegetation": "vegetation_cold",
	"Fire": "cold_fire", "Steam": "cold_steam",   # F3: quench fire → Steam · condense steam → Water
}
## LightningHit (AB-004 charge): Water→Shock (conductive), Steam→Shock (weak).
const RX_LIGHTNING_MATRIX := { "Water": "lightning_water", "Steam": "steam_lightning" }
## PhysicalImpact (knockback / bash): Oil→Slippery (knocked onto a slick).
const RX_PHYSICAL_MATRIX := { "Oil": "oil_physical" }

var _combat: Node3D  # CombatController — camera shake owner


func setup(combat: Node3D) -> void:
	_combat = combat
	add_to_group("event_bus")  # zones/skills emit via call_group("event_bus", "emit_event", …)


var _spread_accum: float = 0.0
var _rx_zone_accum: float = 0.0

## B7: WindGust spread tick (S3e) + passive 존 쌍 반응(Oil+Fire·Fire+Water). 각자 자기 cadence로 구동.
func _physics_process(delta: float) -> void:
	_rx_zone_accum += delta
	if _rx_zone_accum >= ZONE_RX_CADENCE_S:
		_rx_zone_accum = 0.0
		_zone_reaction_tick()
	_spread_accum += delta
	if _spread_accum < SPREAD_CADENCE_S:
		return
	_spread_accum = 0.0
	if not HazardZone.USE_SURFACE_GRID:
		_spread_tick()   # WindGust 원-확산(자식 원). flag ON은 SurfaceGrid._wind_push(셀)가 대체.


func _spread_tick() -> void:
	var winds: Array = []
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if z.is_active() and String(z.status) == "Wind":
			winds.append(z)
	if winds.is_empty():
		return  # spread only exists downwind of a Wind zone (rare → contained)
	for w in winds:
		if get_tree().get_nodes_in_group("spread_zone").size() >= SPREAD_CAP:
			return  # global cap (per-room proxy) reached
		var wc: Vector3 = w.global_position
		var seeded := 0
		for z in _zones_overlapping(wc, float(w.radius)):
			if seeded >= SPREAD_PER_GUST:
				break
			var med := String(z.status)
			if not SPREADABLE_MEDIA.has(med) or z.is_in_group("spread_zone"):
				continue  # only real media spread; spread children don't re-spread (no runaway)
			var dir := Vector3(z.global_position.x - wc.x, 0.0, z.global_position.z - wc.z)
			dir = dir.normalized() if dir.length() > 0.01 else Vector3(1.0, 0.0, 0.0)
			var child := HazardZone.new()
			child.setup(maxf(float(z.radius) * 0.7, 1.0), float(z.dps), 0.0, med, false, SPREAD_TTL)
			add_child(child)
			child.global_position = z.global_position + dir * SPREAD_STEP_M
			child.add_to_group("spread_zone")
			seeded += 1


## passive 존 쌍 반응(사용자 2026-07-21) — Hit 없이 **겹쳐 있기만 하면** 물리적으로 반응. 활성 존 쌍을
## O(n²) 순회(실전 존 수 적음). Oil+Fire=점화(폭발) · Fire+Water=교집합 Steam + 양쪽 소진(원 단위 확산 근사).
func _zone_reaction_tick() -> void:
	var zs: Array = []
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if z.is_active() and not z.is_in_group("spread_zone"):
			zs.append(z)   # spread 자식은 제외(폭주 방지)
	for i in range(zs.size()):
		for j in range(i + 1, zs.size()):
			_resolve_zone_pair(zs[i], zs[j])


## 겹친 존 한 쌍의 passive 반응. 겹침 없으면 무시.
func _resolve_zone_pair(a: Node, b: Node) -> void:
	if not (a.is_active() and b.is_active()):
		return
	var dx: float = a.global_position.x - b.global_position.x
	var dz: float = a.global_position.z - b.global_position.z
	if sqrt(dx * dx + dz * dz) > float(a.radius) + float(b.radius):
		return   # 안 겹침
	var sa := String(a.status)
	var sb := String(b.status)
	# Oil + Fire → 점화(기존 _ignite_oil 재사용: 폭발 + Ignited + Fire존 + 인접 연쇄). Oil 소비.
	if (sa == "Oil" and sb == "Fire") or (sa == "Fire" and sb == "Oil"):
		_ignite_oil(a if sa == "Oil" else b, 0, null)
		return
	# Fire + Water → 교집합에 Steam + 양쪽 반경 소진(서서히 사라짐 = 원 단위 확산 근사).
	if (sa == "Fire" and sb == "Water") or (sa == "Water" and sb == "Fire"):
		var mid: Vector3 = (a.global_position + b.global_position) * 0.5
		var sr: float = minf(float(a.radius), float(b.radius)) * 0.6
		spawn_zone("Steam", mid, maxf(sr, 0.6), 0.0, STEAM_TTL, null)
		a.shrink(ZONE_SHRINK_STEP)
		b.shrink(ZONE_SHRINK_STEP)


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
			pass  # EnterZone/ExitZone aura = per-tick; WindGust spread = _physics_process (B7)


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


## FireDamageHit → **겹친 모든 medium이 각각 반응**(DRIFT-093, EVENT-CORE §3 primaryMedium 개정). Oil→explosion,
## Water→Steam, Vegetation→burn, ToxicGas→toxic flash, Ice→Water melt. (Fire/Smoke/Wind → no combo.)
## Oil은 _ignite_oil이 fire_hit 재귀(인접 연쇄)라 **마지막**에 처리 — 다른 medium은 먼저 소비돼 재귀 중복을 피한다.
## Ice→Water 변환물은 새 zone(현재 스냅샷 zones에 없음)이라 이번 틱엔 재반응하지 않는다(연쇄 폭주 방지).
func _on_fire_damage_hit(p: Dictionary) -> void:
	var center: Vector3 = p.get("position", Vector3.ZERO)
	var radius: float = float(p.get("radius", 1.0))
	var depth: int = int(p.get("depth", 0))
	var source: Node = p.get("source")
	var zones := _zones_overlapping(center, radius)
	if zones.is_empty():
		return  # no environment medium → skill damage only
	var media := {}
	for z in zones:
		media[String(z.status)] = true
	for med in media:                        # 비-Oil RX 먼저(재귀 없음). 각 핸들러가 zones에서 자기 medium을 소비.
		if med == "Oil":
			continue
		match String(RX_FIRE_MATRIX.get(med, "")):
			"fire_water":      _rx_fire_water(zones, source)
			"fire_vegetation": _rx_fire_vegetation(zones, source)
			"toxicgas_fire":   _rx_toxicgas_fire(zones, source)
			"fire_ice":        _rx_fire_ice(zones, source)
	if media.has("Oil"):                     # Oil 점화 — 명중 지점(center) 전달 → 셀판은 그 자리부터 creep, 원판은 whole
		for z in zones:
			if String(z.status) == "Oil" and z.is_active():
				_ignite_oil(z, depth, source, center)
				break


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
				SkillVfx.rx_steam(self, pos, r)  # hissing wisps
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
			SkillVfx.rx_burn(self, pos, r)  # green-tinged flames
	print("[RX] FireDamageHit + Vegetation → burn (RX-FIRE-VEGETATION-001)")


## RX-TOXICGAS-FIRE-001 — toxic flash: burst damage + Poisoned to units in the gas, consume it.
func _rx_toxicgas_fire(zones: Array, _source: Node) -> void:
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
		SkillVfx.rx_toxic_flash(self, z.global_position, float(z.radius))  # sickly ignition
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
	var media := {}                          # 겹친 매질 각각 반응(DRIFT-093 통일). cold는 재귀 없음 → 순서 무관.
	for z in zones:
		media[String(z.status)] = true
	for med in media:                        # 변환물(Water→Ice·Fire→Steam 등)은 새 zone이라 같은 틱 재반응 안 함.
		match String(RX_COLD_MATRIX.get(med, "")):
			"cold_water":      _rx_cold_water(zones, p.get("source"))
			"vegetation_cold": _rx_vegetation_cold(zones)
			"cold_fire":       _rx_cold_fire(zones, p.get("source"))
			"cold_steam":      _rx_cold_steam(zones, p.get("source"))


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
				SkillVfx.rx_freeze(self, pos, r)  # cyan crystal pop
				done = true
	print("[RX] ColdDamageHit + Water → Ice (RX-COLD-WATER-001)")


## RX-VEGETATION-COLD-001 — frostbitten plants → Chilled to units in the patch. out: Slowed.
func _rx_vegetation_cold(zones: Array) -> void:
	_rx_outcome_in(zones, "Vegetation", "Chilled", 3.0)
	_rx_burst(zones, "Vegetation", "freeze")
	print("[RX] ColdDamageHit + Vegetation → frostbite (RX-VEGETATION-COLD-001)")


## LightningHit → primaryMedium combo: Water/Steam conduct → Shock to everyone in the medium.
func _on_lightning_hit(p: Dictionary) -> void:
	var zones := _zones_overlapping(p.get("position", Vector3.ZERO), float(p.get("radius", 1.5)))
	if zones.is_empty():
		return
	var media := {}                          # 겹친 매질 각각 반응(DRIFT-093 통일).
	for z in zones:
		media[String(z.status)] = true
	for med in media:
		match String(RX_LIGHTNING_MATRIX.get(med, "")):
			"lightning_water":
				_rx_outcome_in(zones, "Water", "Shock", 2.0)
				_rx_burst(zones, "Water", "electrify")
				print("[RX] LightningHit + Water → Shock (RX-LIGHTNING-WATER-001)")
			"steam_lightning":
				_rx_outcome_in(zones, "Steam", "Shock", 1.0)
				_rx_burst(zones, "Steam", "electrify")
				print("[RX] LightningHit + Steam → Shock weak (RX-STEAM-LIGHTNING-001)")


## PhysicalImpact → Oil-Physical: knocked onto a slick → OilSlick (RX-OIL-PHYSICAL-001).
func _on_physical_impact(p: Dictionary) -> void:
	var zones := _zones_overlapping(p.get("position", Vector3.ZERO), float(p.get("radius", 1.5)))
	if zones.is_empty():
		return
	if String(RX_PHYSICAL_MATRIX.get(_primary_medium_of(zones), "")) == "oil_physical":
		_rx_outcome_in(zones, "Oil", "OilSlick", 3.0)
		_rx_burst(zones, "Oil", "slick")
		print("[RX] PhysicalImpact + Oil → OilSlick (RX-OIL-PHYSICAL-001)")


## Apply an outcome to every unit standing in zones of the given medium (피아무구분).
func _rx_outcome_in(zones: Array, medium: String, outcome: String, dur: float) -> void:
	for z in zones:
		if String(z.status) != medium:
			continue
		for g in ["party_member", "enemy"]:
			for u in get_tree().get_nodes_in_group(g):
				if u is Node3D and z.contains_point((u as Node3D).global_position) and u.has_method("apply_outcome"):
					u.apply_outcome(outcome, dur)


## First active zone of `medium` among `zones` (or null) — for placing a reaction VFX on it.
func _zone_of(zones: Array, medium: String) -> Node:
	for z in zones:
		if String(z.status) == medium:
			return z
	return null


## Fire the named reaction VFX at the medium's zone (outcome-based RX that don't consume the zone).
func _rx_burst(zones: Array, medium: String, kind: String) -> void:
	var z := _zone_of(zones, medium)
	if z == null:
		return
	var pos: Vector3 = z.global_position
	var r: float = float(z.radius)
	match kind:
		"electrify": SkillVfx.rx_electrify(self, pos, r)
		"slick": SkillVfx.rx_slick(self, pos, r)
		"freeze": SkillVfx.rx_freeze(self, pos, r)


## RX-OIL-FIRE-001 — consume the oil → explosion (+Ignited) + Fire zone + harmless Smoke (NOT
## ToxicGas; spec: 연소 연기·무해), then chain to adjacent oil (depth-limited; F-021 §3.2.1).
func _ignite_oil(oil: Node, depth: int, source: Node = null, hit_pos = null) -> void:
	var pos: Vector3 = oil.global_position
	var r: float = float(oil.radius)
	var fsafe: bool = bool(oil.friendly_safe)   # 초월 아군안심 기름 → 직후 RX(폭발)만 상속(DRIFT-094)
	var sfac: String = String(oil.safe_faction)
	# 셀판 국소 점화(flag ON): 명중 지점 인근만 불씨 → Fire creep이 나머지 oil 셀을 태운다 = 맞힌 자리부터 확산.
	# 존 전체 즉시점화(옛 원 모델)를 대체. 인접 연쇄도 creep이 담당(재귀 fire_hit 불요).
	if HazardZone.USE_SURFACE_GRID and _combat != null and _combat.has_method("surface_grid_ignite_oil"):
		var hp: Vector3 = hit_pos if hit_pos != null else pos
		_combat.surface_grid_ignite_oil(oil, hp)
		_explosion(hp, minf(r, 2.5), EXPLOSION_DMG, source, fsafe, sfac)   # 점화 순간 국소 폭발
		var smoke_l := HazardZone.new()
		smoke_l.setup(r * 0.6 + 0.5, 0.0, 0.0, "Smoke", false, SMOKE_TTL)
		add_child(smoke_l)
		smoke_l.global_position = hp
		oil.clear_zone()   # 존 제거(셀은 detach돼 생존 — creep이 태움)
		print("[RX] Oil ignited LOCAL @hit (depth %d) — creep from hit point (RX-OIL-FIRE-001, cell)" % depth)
		return
	# flag OFF: 기존 whole-oil 즉시 점화(원 모델).
	var parent := oil.get_parent()
	oil.clear_zone()  # consume the oil (removed from group immediately → no re-ignite)
	_explosion(pos, r + 1.0, EXPLOSION_DMG, source, fsafe, sfac)
	var fire := HazardZone.new()
	fire.setup(r, FIRE_DPS, 0.0, "Fire", false, FIRE_TTL)  # residual fire → Ignited (hazard_zone)
	fire.position = pos
	parent.add_child(fire)
	if source != null:
		fire.set_source(source)
	if fsafe:
		fire.set_friendly_safe(sfac)   # 직후 파생 Fire존만 아군 면제(인접 연쇄는 상속 안 함 = 사용자 결정)
	var smoke := HazardZone.new()
	smoke.setup(r + 1.5, 0.0, 0.0, "Smoke", false, SMOKE_TTL)  # 연소 연기 — 무해(시야), 독 아님
	smoke.position = pos
	parent.add_child(smoke)
	print("[RX] Oil ignited (depth %d) → explosion + Ignited + fire + smoke (RX-OIL-FIRE-001)" % depth)
	if depth < MAX_CHAIN_DEPTH:
		fire_hit(pos, r + 1.5, depth + 1, source)  # explosion reaches adjacent oil → chain +1


## AoE explosion — damage ALL units (피아무구분, F-021 §3.3.1) + destructibles + shake.
func _explosion(pos: Vector3, radius: float, dmg: float, source: Node = null, friendly_safe: bool = false, safe_faction: String = "") -> void:
	for g in ["party_member", "enemy"]:
		if friendly_safe and g == safe_faction:
			continue   # 초월 아군안심 기름 파생 폭발 = safe_faction 면제(F-021 예외·DRIFT-094)
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
	SkillVfx.rx_explosion(self, pos, radius)  # fireball: blast + glow + flame licks


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


## RX-FIRE-ICE-001 (F3) — Ice melts → Water (consume Ice, spawn Water). out: Water (ENV).
func _rx_fire_ice(zones: Array, source: Node) -> void:
	var done := false
	for z in zones:
		if String(z.status) == "Ice":
			var pos: Vector3 = z.global_position
			var r: float = float(z.radius)
			z.clear_zone()
			if not done:
				spawn_zone("Water", pos, r, 0.0, STEAM_TTL, source)
				SkillVfx.rx_steam(self, pos, r)  # melt wisp
				done = true
	print("[RX] FireDamageHit + Ice → Water melt (RX-FIRE-ICE-001)")


## RX-COLD-FIRE-001 (F3) — cold snuffs the flames → Fire consumed + brief Steam (quench). out: Steam.
func _rx_cold_fire(zones: Array, source: Node) -> void:
	var done := false
	for z in zones:
		if String(z.status) == "Fire":
			var pos: Vector3 = z.global_position
			var r: float = float(z.radius)
			z.clear_zone()
			if not done:
				spawn_zone("Steam", pos, r, 0.0, STEAM_TTL, source)
				SkillVfx.rx_steam(self, pos, r)  # quench hiss
				done = true
	print("[RX] ColdDamageHit + Fire → quench (RX-COLD-FIRE-001)")


## RX-COLD-STEAM-001 (F3) — steam condenses → Water (consume Steam, spawn Water). out: Water (ENV).
func _rx_cold_steam(zones: Array, source: Node) -> void:
	var done := false
	for z in zones:
		if String(z.status) == "Steam":
			var pos: Vector3 = z.global_position
			var r: float = float(z.radius)
			z.clear_zone()
			if not done:
				spawn_zone("Water", pos, r, 0.0, STEAM_TTL, source)
				SkillVfx.rx_freeze(self, pos, r)  # condensation shimmer
				done = true
	print("[RX] ColdDamageHit + Steam → Water condense (RX-COLD-STEAM-001)")

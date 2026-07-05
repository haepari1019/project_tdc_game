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
const _RampartBarrier := preload("res://scripts/world/objects/rampart_barrier.gd")  # AB-034 spawn
const _Projectile := preload("res://scripts/combat/abilities/projectile.gd")        # delivery=projectile

## Drop-in skill effects. Each is loaded + instantiated once at setup() and registered by its
## kind(). Horizontal expansion: new skill = new effects/<name>.gd + one preload line here.
const _SKILL_SCRIPTS := [
	preload("res://scripts/combat/abilities/effects/anchor_guard.gd"),
	preload("res://scripts/combat/abilities/effects/press_line.gd"),
	preload("res://scripts/combat/abilities/effects/mark_ruin.gd"),
	preload("res://scripts/combat/abilities/effects/mend_circle.gd"),
	preload("res://scripts/combat/abilities/effects/sb_strike.gd"),
	preload("res://scripts/combat/abilities/effects/sb_poison.gd"),
	preload("res://scripts/combat/abilities/effects/sb_stun.gd"),
	preload("res://scripts/combat/abilities/effects/sb_fire.gd"),
	preload("res://scripts/combat/abilities/effects/sb_zone.gd"),
	preload("res://scripts/combat/abilities/effects/sb_cold.gd"),
	# P2-S6a — Third-faction lootables (AB-100~106 party side; DEC-20260621-001).
	preload("res://scripts/combat/abilities/effects/sb_root.gd"),    # AB-102 Snare Net (Tank)
	preload("res://scripts/combat/abilities/effects/sb_pin.gd"),     # AB-100 Pounce (Nuker)
	preload("res://scripts/combat/abilities/effects/sb_tether.gd"),  # AB-103 Tether (Nuker)
	preload("res://scripts/combat/abilities/effects/sb_charge.gd"),  # AB-104 Rampage (Tank)
	preload("res://scripts/combat/abilities/effects/sb_execute.gd"), # AB-106 Devour (Nuker)
	preload("res://scripts/combat/abilities/effects/sb_scent.gd"),   # AB-101 Scent of Blood (Healer)
	# Gear-catalog Identity skills (non-starter identities; spec PT-pending → intent impl, params drift).
	preload("res://scripts/combat/abilities/effects/beacon_threat.gd"),  # IDA-021 Iron Beacon (Tank)
	preload("res://scripts/combat/abilities/effects/march_advance.gd"),  # IDA-022 Bulwark March (Tank)
	preload("res://scripts/combat/abilities/effects/sentinel_form.gd"),  # IDA-052 Sentinel Form (Tank)
	preload("res://scripts/combat/abilities/effects/arc_line.gd"),       # IDA-027 Arc Weave (DPS)
	preload("res://scripts/combat/abilities/effects/flank_dash.gd"),     # IDA-029 Flank Collapse (Nuker)
	preload("res://scripts/combat/abilities/effects/ward_shield.gd"),    # IDA-031 Ward Pulse (Healer)
	# P2-S6a B1 — party lootable sub effect kinds (new, beyond reused strike/fire/stun/cold/zone).
	preload("res://scripts/combat/abilities/effects/sb_heal.gd"),        # AB-064 Quick Mend (Healer)
	preload("res://scripts/combat/abilities/effects/sb_dr.gd"),          # AB-046/047/068 Shield Wall·Aegis·Warding (Tank/Healer)
	preload("res://scripts/combat/abilities/effects/sb_ally_shield.gd"), # AB-067 Aegis Blessing (Healer)
	preload("res://scripts/combat/abilities/effects/sb_hot.gd"),         # AB-065 Renewing Tide (Healer)
	preload("res://scripts/combat/abilities/effects/sb_blink.gd"),       # AB-061 Shadowstep (Nuker)
	preload("res://scripts/combat/abilities/effects/sb_vulnerable.gd"),  # AB-057 Focus Fire (Healer)
	preload("res://scripts/combat/abilities/effects/sb_haste.gd"),       # AB-069 Swift Grace (Healer)
	# P2-S6a B1 잔여 — stealth/buff/channel/barrier/purge/silence (AB-075 reuses skillbook_shield).
	preload("res://scripts/combat/abilities/effects/sb_stealth.gd"),     # AB-062 Smoke Veil (Nuker, Veiled)
	preload("res://scripts/combat/abilities/effects/sb_beam.gd"),        # AB-054 Rending Beam (DPS, channel)
	preload("res://scripts/combat/abilities/effects/sb_barrier.gd"),     # AB-034 Rampart Slam (Tank, ENT-RAMPART-001)
	preload("res://scripts/combat/abilities/effects/sb_purge.gd"),       # AB-070 Purge Light (Healer)
	preload("res://scripts/combat/abilities/effects/sb_silence.gd"),     # AB-044 Hush Ward (Healer, Silenced)
	# P2-S6a B2 — remaining ranged/burst lootables → one targeted bolt kind (옵션 lightning→Shock).
	preload("res://scripts/combat/abilities/effects/sb_bolt.gd"),        # AB-003/004/008/055/056/058/059/073
	# P2-S6a B2 잔여 bespoke — Tank control + Healer utility.
	preload("res://scripts/combat/abilities/effects/sb_taunt.gd"),       # AB-035 Challenge Mark (Tank)
	preload("res://scripts/combat/abilities/effects/sb_pull.gd"),        # AB-051 Shield Throw (Tank)
	preload("res://scripts/combat/abilities/effects/sb_slow.gd"),        # AB-050 Warding Shout (Tank)
	preload("res://scripts/combat/abilities/effects/sb_relocate_ally.gd"), # AB-045 Lifeline (Healer)
	preload("res://scripts/combat/abilities/effects/sb_reveal.gd"),      # AB-032 Beacon Sight (Healer)
]

# F-009 §3.2.1 / D-016 §3.2 / D-012 §2.4 — cross-class (sub) skillbook penalty by IDENTITY-DISTANCE
# BAND, not a flat −10% (that policy was retired, DEC-20260617-002). mainClasses (B0) = full coeff;
# subClasses carry a band (B1 인접 / B2 중간 / B3 이탈) read from the skillbook master's `sub_bands`
# {classId: band}. A class NOT listed in sub_bands = main (B0 = ×1.0). The Role Equip Gate stays
# `equip_classes` (= mainClasses ∪ subClasses). coeff numbers are TUNING (spec: 수치 TBD, band 라벨만
# SSOT — SPEC_DRIFT log only, DRIFT-057).
const BAND_COEFF := {"B0": 1.0, "B1": 0.9, "B2": 0.75, "B3": 0.55}
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
	# F-008 §3.7 gear potency_mult 옵션 roll → identity 위력(per-cast _coeff). 직전 set이라 공유 dict 순차안전.
	p["_coeff"] = float(m.identity_potency_mult) if "identity_potency_mult" in m else 1.0
	if skill.cast(m, p, Vector3.ZERO, self):
		# F-008 §3.7 gear cd_mult 옵션 roll → identity 쿨다운에 곱(낮을수록 빠름). 1.0 = none.
		var cdm: float = float(m.cooldown_mult) if "cooldown_mult" in m else 1.0
		m.identity_cooldown_s = float(p.get("cooldown_s", 6.0)) * cdm
		# P4a Kit Binding 「표식」 — Beacon 정체성은 시전 시 눈앞의 적에게 표식을 남긴다. 결속=조작 전용
		# (NC 미적용, F-020 §3.3) → is_controlled 게이트. 표식 대상 처치 시 링크 전 슬롯 쿨 감소.
		if m.is_controlled() and BindingFixtures.identity_marks(String(m.base_gear_id), String(m.ability_id)):
			var mk: Dictionary = BindingFixtures.MARK
			var e: CharacterBody3D = nearest_enemy_in_range(m.global_position, float(mk["radius_m"]))
			if e != null:
				m.binding_mark(e, float(mk["window_s"]), float(mk["cd_reduce"]))
		return true
	return false




## Cross-class coeff for `cid` using a skillbook whose master carries `sub_bands` {classId: band}.
## main class (not listed) → ×1.0 (B0); sub class → its band's coeff. ref: D-016 §3.2 · D-012 §2.4.
func _band_coeff(cid: String, sub_bands: Dictionary) -> float:
	return float(BAND_COEFF.get(String(sub_bands.get(cid, "B0")), 1.0))


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
	# D-016 §3.2 / D-012 §2.4 — sub-class use is penalised by identity-distance band (the master's
	# `sub_bands`); main class = full coeff. (was: flat −10% off the first equip class.)
	var bands: Dictionary = Slice01Data.get_skillbook_master(String(inst.get("base_ability_id", ""))).get("sub_bands", {})
	# D-018 §7.3 — affix coeffMult는 cross-class 밴드와 **독립**으로 곱(합산 ≤15% 안전 클램프). cd_trade는 쿨 가산.
	var affix: Dictionary = inst.get("affix", {})
	p["_coeff"] = _band_coeff(String(member.class_id), bands) * (1.0 + clampf(float(affix.get("coeff", 0.0)), -0.15, 0.15))
	# target_pos = aimed ground point (targeted subs) or caster position (self-centered).
	var skill = _skills.get(String(p.get("kind", "")))
	if skill != null and skill.cast(member, p, target_pos, self):
		inst.charges = int(inst.charges) - 1
		inst.cooldown_s = float(p.get("cooldown_s", 6.0)) * (1.0 + float(affix.get("cd_trade", 0.0)))
		_apply_binding(member, slot_index, target_pos)   # P4a Kit Binding overlay (if the triple matches)


# ============================================================================
# P4a Kit Binding (결속) — resolveEffectiveAbility overlay application (F-020 §3.7). After a base sub
# cast, triple-match the member's LIVE gear + identity + slot sub against the pilot fixtures and apply
# the overlay's runtime DELTA (AB files are NOT cloned). NON-CANONICAL pilot; NC never reaches here
# (cast_skillbook is ally-only). ref: binding_fixtures.gd · ROLE-010 §4.5 · QA-005 §2.12.
# ============================================================================

func _apply_binding(member: CharacterBody3D, slot_index: int, target_pos: Vector3) -> void:
	var inst = member.get_skillbook(slot_index)
	if inst == null:
		return
	var ov: Dictionary = BindingFixtures.resolve(
		String(member.base_gear_id), String(member.ability_id),
		String(inst.get("base_ability_id", "")), slot_index)
	if ov.is_empty():
		return
	var pos: Vector3 = member.global_position
	var aim: Vector3 = target_pos if target_pos != Vector3.ZERO else pos
	match String(ov.get("delta", "")):
		# --- Anchor 「방벽 충전」: 모든 서브가 방벽 +1(공통 버프) → 세 겹이면 기절(캡스톤) ---
		"bulwark_charge":
			_anchor_stack(member, pos)
		# --- Beacon 「표식」: 모든 서브가 표식 대상에게 추가 위협(상태-조건부). 표식 없으면 base만 ---
		"beacon_mark":
			_beacon_mark_threat(member)
		"beacon_mark_refresh":   # R 도전 선포 — 위협 + 표식 유지 시간 갱신.
			_beacon_mark_threat(member)
			var mk: Dictionary = BindingFixtures.MARK
			member.binding_remark(nearest_enemy_in_range(aim, float(mk["radius_m"])), float(mk["window_s"]))


## Anchor 「방벽 충전」 — add a BulwarkCharge; on the 3-stack consume, stun the nearest enemy (capstone).
func _anchor_stack(member: CharacterBody3D, pos: Vector3) -> void:
	var b: Dictionary = BindingFixtures.BULWARK
	if member.binding_bulwark_add(int(b["stacks_needed"]), float(b["icd_s"])):
		var e: CharacterBody3D = nearest_enemy_in_range(pos, float(b["radius_m"]))
		if e != null and e.has_method("apply_stun"):
			e.apply_stun(float(b["stun_s"]))


## Beacon 「표식」 — 규약의 상태-조건부 버프: 유효한 표식 대상이 있을 때만 그 대상에게 추가 위협을 얹는다.
## 표식이 없으면(정체성이 아직 안 남겼거나 대상 사망) 아무것도 하지 않는다 → base 스킬만 발현.
func _beacon_mark_threat(member: CharacterBody3D) -> void:
	var e = member.get_marked_enemy()
	if e == null:
		return
	var t: float = float(BindingFixtures.MARK["threat"])
	if e.has_method("add_threat"):
		e.add_threat(member, t)
	if e.has_method("set_threat_floor"):
		e.set_threat_floor(member, t)


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


## Spawn a medium ground zone (party spawn-zone subs: AB-009/036/039/040/042/043).
func spawn_zone(medium: String, pos: Vector3, radius: float, dps: float, ttl: float, source: Node = null) -> void:
	_reactions.spawn_zone(medium, pos, radius, dps, ttl, source)


## Emit a ColdDamageHit at a point (party Glacial Bolt, AB-041) → Cold RX (Water→Ice, Veg→Slowed).
func cold_hit(center: Vector3, radius: float, source: Node = null) -> void:
	_reactions.emit_event("ColdDamageHit", {"position": center, "radius": radius, "source": source})


## Emit a LightningHit at a point (party Rending Beam, AB-054) → Shock RX (Water/Steam conduct).
func lightning_hit(center: Vector3, radius: float, source: Node = null) -> void:
	_reactions.emit_event("LightningHit", {"position": center, "radius": radius, "source": source})


## Spawn a Rampart Barrier (AB-034) — a destructible forward wall. Parented under the dispatch node
## (a world child), so it persists through the cast and self-frees on Break. ref: ENT-RAMPART-001.
func spawn_barrier(caster: CharacterBody3D, pos: Vector3, facing: Vector3, p: Dictionary) -> void:
	var bar = _RampartBarrier.new()
	add_child(bar)
	bar.setup(caster, pos, facing, p, self)


## Scout reveal (AB-032 Beacon Sight) — force every enemy visible through the fog for `dur`s
## (EnemyVisibility owns set_seen; it holds the reveal for the window). ref: F-011 · AB-032.
func reveal_enemies(dur: float) -> void:
	for v in get_tree().get_nodes_in_group("enemy_visibility"):
		if v.has_method("reveal"):
			v.reveal(dur)


## Spawn a traveling projectile (delivery="projectile") that carries `effect` as its payload — on
## impact it calls effect.resolve_at(). Hit mask excludes the caster's own side (no friendly fire);
## Rampart (world layer) blocks/absorbs it. ref: F-021 · AB-034 · DRIFT-059.
func spawn_projectile(effect, caster: CharacterBody3D, target_pos: Vector3, params: Dictionary) -> void:
	var proj = _Projectile.new()
	add_child(proj)
	proj.setup(caster, caster.global_position, target_pos, float(params.get("speed_mps", 18.0)),
		_projectile_mask(caster), effect, params, self)


## Projectile hit mask by caster side: ally → world(1) + enemy(4); enemy → world(1) + party(2).
## Rampart Barrier sits on world(1), so it's hit either way. The caster's own layer is excluded.
func _projectile_mask(caster: CharacterBody3D) -> int:
	return (1 | 4) if caster.is_in_group("party_member") else (1 | 2)

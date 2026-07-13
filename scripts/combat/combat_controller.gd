extends Node3D
## Spawns & runs ENC encounters (box PH enemies). Combat loop added in CP4–5.
## ref: WORK_ORDER §4 · ENC-NORM-001 · QA-005 §2.6 (NC sub skillbook: NO auto).

## partyInCombat (전투중/휴식중) changed — true while ANY enemy is engaged. Derived
## from per-enemy squad engagement; drives HUD + follower re-form. (see is_engaged)
signal engagement_changed(engaged: bool)
## A party member just took damage. Drives the follower formation-break trigger
## (slot-break on being hit), separate from engagement/perception.
@warning_ignore("unused_signal")  # emitted cross-class (enemy_ai) → connected in party_controller
signal party_damaged()
## Camera feedback (dungeon_run): trauma 0..1 to add (trauma² shake), kick_world =
## directional push in world XZ (ZERO for hit-feel). Controlled events full, others muted.
@warning_ignore("unused_signal")  # emitted cross-class (ability_dispatch/enemy_ai) → connected in dungeon_run
signal camera_shake(trauma: float, kick_world: Vector3)
## A party member took a directional hit — drives the screen-edge damage indicator.
## from_dir_world = world XZ toward the attacker; severity 0..1; is_controlled gates the
## (controlled-only) edge UI. Emitted for ALL hits above a chip threshold (incl. basic).
@warning_ignore("unused_signal")  # emitted cross-class (enemy_ai) → connected in dungeon_run
signal party_hit(from_dir_world: Vector3, severity: float, is_controlled: bool, member: Node)
## An enemy was defeated at world_pos — drives world item drops (loot). ref: F-010 loot.
signal enemy_defeated(world_pos: Vector3, ability_refs: Array, by_party: bool)
## A squad's last enemy fell — drives ENC-bound haul drops (HUB-COR-000 §3). Fires once per squad.
signal squad_cleared(encounter_id: String, world_pos: Vector3)

const EnemyScene := preload("res://scenes/combat/enemy_unit.tscn")
const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const Spatial := preload("res://scripts/core/spatial.gd")
const EnemyAI := preload("res://scripts/combat/enemy_ai.gd")
const AbilityDispatch := preload("res://scripts/combat/abilities/ability_dispatch.gd")
const ReactionSystem := preload("res://scripts/combat/abilities/reaction_system.gd")
const CastContext := preload("res://scripts/combat/abilities/cast_context.gd")   # PILOT — enemy 통합 캐스트 ctx

## D-010 §4.2 combat_exit_grace_s — an engaged enemy with no combat event and no
## line of sight to the party for this long disengages (전투중 → dormant). Tuning.
const COMBAT_EXIT_GRACE_S := 6.0
## EN-AI-000 §3 distance-leash (leash_m 28): an engaged enemy dragged this far from its spawn
## anchor gives up the chase (arena-boundary kite prevention) and returns to post (B6). Tuning.
const DISENGAGE_LEASH_M := 28.0
## Squad cohesion: a newly-engaged enemy wakes squad-mates within this radius. A
## strayed member (off investigating) is outside it, so killing it alone does NOT
## wake the distant squad. Tuning.
const SQUAD_PROP_RADIUS_M := 9.0
## Lateral spacing between squads sharing one room (relocated start-room encounter
## sits beside the room's own squad instead of overlapping it).
const SQUAD_LANE_SPACING := 12.0
const SPAWN_SCATTER_M := 4.5   # per-run seeded scatter of the squad spawn center (navmesh-snapped)
const EncounterGenerator := preload("res://scripts/run/encounter_generator.gd")   # S5b 조합 제너레이터
const GEN_SCATTER_FRAC := 0.28   # 절차적 스폰: 방 최소변의 이 비율까지 deep-anchor 주변 산포(고정 4.5 대체)
const GEN_SCATTER_MAX := 13.0    # 산포 반경 상한(m)
const SPAWN_WALL_MARGIN := 5.0   # 산포 후 벽에서 안쪽 클램프(유닛/스폰 여유)
const RUN_ENCOUNTER_MIN := 4     # 런 전체 전투 수 하한(사용자: 한 런에 4~5 전투)
const RUN_ENCOUNTER_MAX := 5     # 런 전체 전투 수 상한 — 방마다 무조건 X, 가중 추첨한 방에만 1분대
const THIRD_FACTION_CHANCE := 0.6   # F-028 제3세력 창발: 런당 0~1 squad(이 확률로 1) — 난장판 방지
const THIRD_FACTION_NAME := "Third"   # 제3세력 combat faction(ENC-3RD-001과 동일) — 몬스터("Dungeon")·파티에 적대
const THIRD_FACTION_PACK: Array = [   # Stalker Pack(EN-3RD-01 추적자 + 02 포획꾼 + 03 학살자)
	{"enemy_id": "EN-3RD-01", "count": 1}, {"enemy_id": "EN-3RD-02", "count": 1}, {"enemy_id": "EN-3RD-03", "count": 1},
]
const ANCHOR_SEP_M := 14.0   # AmbushHold dual-anchor separation (> SQUAD_PROP_RADIUS_M so the two
							 # hiding spots wake independently — sequential reveal)

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
## PILOT — enemy-faction cast context: runs UNIFIED skillbook effects for enemy casters (one skill
## definition, two casting front-ends). ref: cast_context.gd · AB-003 파일럿.
var _enemy_cast_ctx: CastContext


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
	_enemy_cast_ctx = CastContext.new()
	add_child(_enemy_cast_ctx)
	_enemy_cast_ctx.setup(self, _ability_dispatch, "enemy")


## partyInCombat: true while ANY enemy is engaged. Drives HUD + follower re-form.
func is_engaged() -> bool:
	return _party_in_combat


## Recompute the derived partyInCombat flag and emit on change.
func _refresh_party_in_combat() -> void:
	var any := false
	for e in _enemies:
		if not (is_instance_valid(e) and e.engaged):
			continue
		# F-028: '교전중'이라도 대상이 다른 진영뿐이면 partyInCombat 아님 — 파티원에 대한 threat가
		# 있어야 진짜 파티 교전(HUD·follower 재정렬은 파티 전투에만 반응).
		for t in e.threat.keys():
			if is_instance_valid(t) and t.is_in_group("party_member") and float(e.threat[t]) > 0.0:
				any = true
				break
		if any:
			break
	if any != _party_in_combat:
		_party_in_combat = any
		engagement_changed.emit(any)
	if not any:
		_tank_engaged = false  # combat over → the next fight must be opened by the tank again


## A combat event on one enemy (it dealt/took damage, or perceived the party):
## engage it, refresh its grace, and wake squad-mates within cohesion radius. A
## strayed member is outside that radius, so its distant squad stays dormant.
## 전투 템포 B-2 소프트 동시성 캡(K=1): 같은 스쿼드의 다른 적이 지금 cap-eligible(threat/control)
## 캐스트를 winding 중인가. 알파 스트라이크/재겹침 방지(DRIFT-083). 평타·비-cap 무제한.
func squad_cast_busy(caster: CharacterBody3D) -> bool:
	var sid: int = caster.squad_id
	for e in _enemies:
		if e == caster or not is_instance_valid(e):
			continue
		if not e.engaged or e.squad_id != sid:
			continue
		if e.winding and AbilityRoles.is_cap_eligible(String(e.windup_chosen.get("ref", ""))):
			return true
	return false


func _engage_enemy(e: CharacterBody3D, target_member: CharacterBody3D = null) -> void:
	if e == null or not is_instance_valid(e):
		return
	var has_target: bool = target_member != null and is_instance_valid(target_member)
	var was: bool = e.engaged
	e.engaged = true
	e.returning = false   # re-engaging cancels any return-to-spawn walk (B6)
	e.engage_grace_s = COMBAT_EXIT_GRACE_S
	if has_target:
		e.add_threat(target_member, PERCEIVE_THREAT)  # target who we saw/were hit by
	if not was and String(e.placement_mode) == "AmbushHold":
		SkillVfx.ambush_spring(self, e.global_position)  # sprang from hiding (reveal feedback)
	if was:
		return
	var r2 := SQUAD_PROP_RADIUS_M * SQUAD_PROP_RADIUS_M
	for o in _enemies:
		if o == e or not is_instance_valid(o) or o.engaged:
			continue
		if o.squad_id != e.squad_id:
			continue
		if String(o.faction) != String(e.faction):
			continue  # F-028: 경보 전파는 같은 진영만 (혼합-진영 분대여도 적끼리는 안 깨움)
		# Sequential wake (ENC-AMB-002): a sprung anchor does NOT wake the OTHER anchor — it waits
		# for the party to reach its own reveal radius. Same-anchor squadmates still wake together.
		if String(e.wake_policy) == "sequential" and int(o.anchor_id) != int(e.anchor_id):
			continue
		if Spatial.h_dist2(o.global_position, e.global_position) <= r2:
			o.engaged = true
			o.returning = false
			o.engage_grace_s = COMBAT_EXIT_GRACE_S
			if String(o.placement_mode) == "AmbushHold":
				SkillVfx.ambush_spring(self, o.global_position)  # squadmate springs too
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
	# F-028: 적 AI엔 전 전투원(파티 + 모든 적)을 넘겨 각자 적대(다른 진영+파티)만 필터(_hostiles).
	# 파티 오토어택 루프는 파티원만(아래 _tick_party_attacks). 단일 진영 분대 = 같은 분대 제외.
	var party := get_tree().get_nodes_in_group("party_member")
	var targets: Array = []
	targets.append_array(party)
	targets.append_array(_enemies)
	# Per-enemy disengage grace (D-010 §4.2): an engaged enemy reverts to dormant
	# after the grace lapses (grace is refreshed by combat events + active LOS).
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.engaged and not enemy.training_dummy:
			enemy.engage_grace_s -= delta
			# Distance-leash (B5): dragged too far from the spawn anchor → give up (kite prevention).
			var leashed: bool = enemy.home_pos != Vector3.INF \
				and Spatial.h_dist2(enemy.global_position, enemy.home_pos) > DISENGAGE_LEASH_M * DISENGAGE_LEASH_M
			if enemy.engage_grace_s <= 0.0 or leashed:
				enemy.engaged = false
				enemy.returning = true    # B6: path back to the spawn anchor
	# Tick every enemy: dormant ones perceive/idle, engaged ones fight (EnemyAI).
	# 허수아비(training_dummy)는 AI 미구동 → 정지·비공격(스킬샷 표적).
	for enemy in _enemies:
		if is_instance_valid(enemy) and not enemy.training_dummy:
			_enemy_ai.tick(enemy, targets, delta)
	# Party auto-attack runs always — attacking a foe is what commits the party. (party원만 actor)
	_tick_party_attacks(party, delta)
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
		SkillVfx.telegraph(self, _reinforce_point(squad), Color(0.95, 0.3, 0.2, 0.55))
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
				if to_src.length() <= m.basic_range_m and m.basic_enabled and not m.is_channeling():
					_resolve_basic(m, src)
					m.attack_cooldown_s = m.attack_interval()   # Haste(AB-069)-aware
			continue
		if tank_alive and not _tank_engaged and not m.is_controlled():
			var gcid: String = String(m.get("class_id"))
			if gcid == "DPS" or gcid == "Nuker":
				continue  # 2nd-line dealer waits for the tank's first hit
		# Identity (main) first; fall back to basic when not castable. Per-member identity_enabled /
		# basic_enabled (sandbox 검증) let either channel be turned off independently of the gear.
		if m.identity_enabled and m.identity_cooldown_s <= 0.0 and _ability_dispatch.try_identity(m):
			continue
		if not m.basic_enabled:
			continue   # 평타 검증: 이 멤버 평타 OFF (identity만 / 또는 완전 정지)
		if m.is_channeling():
			continue   # 캐스트(cast_s wind-up) 진행 중엔 평타 정지 — 캐스트에 전념(적 winding 직렬화와 대칭). ref: DRIFT-075
		if m.attack_cooldown_s > 0.0:
			continue
		var foe := _nearest_enemy_in_range(m.global_position, m.basic_range_m)
		if foe == null:
			continue
		_resolve_basic(m, foe)
		m.attack_cooldown_s = m.attack_interval()   # Haste(AB-069)-aware


func cast_skillbook(member: CharacterBody3D, slot_index: int, target_pos: Vector3 = Vector3.ZERO) -> void:
	_ability_dispatch.cast_skillbook(member, slot_index, target_pos)


## PILOT — resolve a UNIFIED skillbook ability CAST BY AN ENEMY through the SAME sb_* effect the ally
## uses, via the faction-flipped CastContext. `params` = the skillbook's flattened `cast` dict (the
## single definition both sides share). ref: cast_context.gd · enemy_ai._resolve_enemy_attack.
func resolve_unified_cast(caster: CharacterBody3D, params: Dictionary, target_pos: Vector3) -> void:
	var effect = _ability_dispatch.skill_for(String(params.get("kind", "")))
	if effect != null:
		effect.cast(caster, params, target_pos, _enemy_cast_ctx)


const BASIC_CLEAVE_FALLOFF := 0.6   # 평타 cleave 2차 대상 피해 비율 (ba 아키타입 splash)
const BASIC_PIERCE_FALLOFF := 0.7   # 평타 pierce 관통 대상 피해 비율
const PIERCE_HALF_WIDTH := 0.9      # 관통선 반폭(m) — 이 안의 적이 관통 피격

## 평타 1회 해소 — 1차 대상 피해 + (cleave 시) 주변 splash + (knockback 시) 넉백 + VFX 1회.
## 단일타 gear는 cleave_m/kb_m=0이라 1차 대상만 → 기존과 동일. provoked·일반 평타 공용(F-008 §3.7).
func _resolve_basic(m: CharacterBody3D, foe: CharacterBody3D) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	# 「집중」 빌드(mark_ruin 누커, 조작/AI 공통) — 평타로 1차 대상에 집중 누적, 누적 비례로 이 평타를 증폭.
	# 집중-누커가 아니면 1.0(무영향). ref: ability_dispatch.nuker_focus_accumulate · DRIFT-076.
	var focus_mult: float = _ability_dispatch.nuker_focus_accumulate(m, foe)
	_deal_damage(foe, m, m.basic_damage * focus_mult)
	_ability_dispatch.dps_overdrive_on_basic(m)   # DPS 「초월」 평타 게이지 빌드(press_line 정체성만; 조작/AI 공통)
	var vfx_to: Vector3 = foe.global_position   # pierce면 관통 끝점까지 VFX 연장
	var cleave: float = float(m.basic_cleave_m) if "basic_cleave_m" in m else 0.0
	var kb: float = float(m.basic_knockback_m) if "basic_knockback_m" in m else 0.0
	if cleave > 0.0:
		for e in _enemies_in_radius(foe.global_position, cleave):
			if e != foe and is_instance_valid(e):
				_deal_damage(e, m, m.basic_damage * BASIC_CLEAVE_FALLOFF)
				if kb > 0.0:
					_knockback_from(e, m, kb)
	if kb > 0.0:
		_knockback_from(foe, m, kb)
	var pierce: float = float(m.basic_pierce_m) if "basic_pierce_m" in m else 0.0
	if pierce > 0.0:
		var axis: Vector3 = foe.global_position - m.global_position
		axis.y = 0.0
		if axis.length() > 0.01:
			axis = axis.normalized()
			for e in _enemies_in_radius(m.global_position, pierce):
				if e == foe or not is_instance_valid(e):
					continue
				var rel: Vector3 = e.global_position - m.global_position
				rel.y = 0.0
				var along: float = rel.dot(axis)
				if along <= 0.0:
					continue  # 캐스터 뒤 → 관통선 밖
				if (rel - axis * along).length() <= PIERCE_HALF_WIDTH:
					_deal_damage(e, m, m.basic_damage * BASIC_PIERCE_FALLOFF)
			vfx_to = m.global_position + axis * pierce   # 항상 최대 사거리까지 빔(적 없어도 보임 → 조준 직관)
	if pierce > 0.0:
		SkillVfx.basic_pierce_beam(m.basic_attack_profile_id, self, m.global_position, vfx_to)   # 관통 전용 또렷한 빔
	SkillVfx.party_basic(m.basic_attack_profile_id, self, m.global_position, vfx_to, foe)


func _knockback_from(e: CharacterBody3D, m: CharacterBody3D, dist: float) -> void:
	if e == null or not is_instance_valid(e) or not e.has_method("apply_knockback"):
		return
	var dir: Vector3 = e.global_position - m.global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		e.apply_knockback(dir.normalized(), dist)


## FireDamageHit at a point (F-027 ENT-TORCH) — torch landing / oil contact. ref: F-021.
func ignite_at(center: Vector3, radius: float, source: Node = null) -> void:
	_reactions.ignite_at(center, radius, source)


## Spawn a medium ground zone (AB-009/036/039/040/042/043 — enemy/lootable). ref: F-027 ZONE-*.
func spawn_zone(medium: String, pos: Vector3, radius: float, dps: float, ttl: float, source: Node = null) -> void:
	_reactions.spawn_zone(medium, pos, radius, dps, ttl, source)


## Enemies within radius. `faction` != "" → only that faction (F-028: 힐/지원은 같은 진영만).
func _enemies_in_radius(pos: Vector3, r: float, faction: String = "") -> Array:
	var out: Array = []
	var r2 := r * r
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		if faction != "" and String(e.faction) != faction:
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


## Enemies in a forward RECTANGLE lane — along-axis ∈ [0, length], perpendicular ≤ half_width.
func _enemies_in_rect(pos: Vector3, axis: Vector3, length: float, half_width: float) -> Array:
	var out: Array = []
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		var rel: Vector3 = e.global_position - pos
		rel.y = 0.0
		var along: float = rel.dot(axis)
		if along < 0.0 or along > length:
			continue
		if (rel - axis * along).length() <= half_width:
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
	# Shadowstep (AB-061) — the caster's NEXT hit is boosted, consumed here (basic OR sub; threat
	# below reflects the boosted damage). No-op for members without a pending bonus.
	if attacker != null and attacker.has_method("consume_next_hit_bonus"):
		dmg *= 1.0 + attacker.consume_next_hit_bonus()
	# AB-012 HEX-WEAK — a hexed attacker deals reduced outgoing damage (basic OR sub; the threat
	# below reflects the reduced dmg). No-op (×1.0) when not hexed.
	if attacker != null and attacker.has_method("hex_weak_mult"):
		dmg *= attacker.hex_weak_mult()
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
	enemy.take_damage(dmg, attacker)   # attacker 전달 — killed_by_party 귀속(파티 킬 로그/전리품) + 처치 관여 크레딧(잠행 은신)


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
	var run_seed := int(RunLoadout.get_run_seed())  # weighted ENC resolve + spawn scatter (LDG-SPAWN §2)
	# 런 전체 전투 수 = 예산(RUN_ENCOUNTER 4~5). 방마다 무조건(난장판) 대신 pool 방을 spawn_weight로
	# 가중 추첨해 예산만큼만 1분대씩 배치. spawn_weight=선택 확률(0=제외·조밀할수록 잘 뽑힘). 향후 전투는 더 무겁게.
	var candidates: Array = []
	for row in Slice01Data.get_rooms_document().get("rooms", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var pool := String(row.get("pool_slot", ""))
		if pool.is_empty():
			continue   # 비전투 룸(OBJ/EXT 등)
		var weight := float(row.get("spawn_weight", 1.0))
		if weight <= 0.0:
			continue
		candidates.append({"room": String(row.get("room_ref", "")), "pool": pool, "layer": String(row.get("world_layer", "Upper")), "weight": weight})
	var budget: int = RUN_ENCOUNTER_MIN + abs(hash("encbudget|%d" % run_seed)) % (RUN_ENCOUNTER_MAX - RUN_ENCOUNTER_MIN + 1)
	var chosen: Array = _weighted_pick_rooms(candidates, budget, run_seed)
	var combat_rooms: Array = []
	var used_encs: Dictionary = {}   # S5b P4 런 내 비복원 — 같은 ENC frame 반복 회피(시드 재롤)
	for cand in chosen:
		var enc_id := ""
		for attempt in 4:   # 미사용 ENC를 찾도록 몇 번 재롤(풀이 단일이면 어쩔 수 없이 반복)
			enc_id = Slice01Data.get_encounter_for_pool(String(cand["pool"]), difficulty, String(cand["layer"]), run_seed + attempt * 7919)
			if enc_id.is_empty() or not used_encs.has(enc_id):
				break
		if enc_id.is_empty():
			continue
		used_encs[enc_id] = true
		# 시작 방이 뽑히면 파티 위로 스폰 → 연결된 방으로 이전.
		var target_room := String(cand["room"])
		if target_room == spawn_room:
			target_room = _first_connected(spawn_room)
			if target_room.is_empty():
				continue
		print("[TDC] prespawn: room=%s w=%.1f pool=%s -> %s (예산 %d방)" % [String(cand["room"]), float(cand["weight"]), String(cand["pool"]), enc_id, chosen.size()])
		# S5b 하이브리드: 보스·제3세력은 authored set-piece, 그 외는 조합 제너레이터로 유닛 생성(frame 유지).
		var units_override: Array = []
		if _should_generate(enc_id):
			var comp: Dictionary = EncounterGenerator.generate(difficulty, abs(hash("%d|%s" % [run_seed, target_room])))
			units_override = _comp_to_units(comp.get("enemies", []))
		_spawn_squad(enc_id, target_room, units_override)
		if not combat_rooms.has(target_room):
			combat_rooms.append(target_room)
	# S5b P3 (F-028) — 제3세력 창발: 4~5 전투 중 0~1개만 3세력이 다투는 방으로(난장판 방지).
	_inject_third_faction(run_seed, combat_rooms)


## DEBUG (dev combat sandbox): spawn ONE encounter. engaged=true skips the perception dance.
## encounter_id "" clears only. `additive`=true keeps existing squads (예: 일반 ENC + ENC-3RD를
## 같이 스폰해 진영전 테스트 — F-028). dev-only.
func debug_spawn_only(encounter_id: String, room_ref: String, engaged: bool = false, additive: bool = false) -> void:
	if not additive:
		for e in _enemies:
			if is_instance_valid(e):
				e.queue_free()
		_enemies.clear()
		_squads.clear()
		_room_squad_count.clear()
		_next_squad_id = 0
	if _map and _map.has_method("get_spawn_position"):
		_spawn_origin = _map.get_spawn_position(room_ref)
	if encounter_id.is_empty():
		return
	_spawn_squad(encounter_id, room_ref)
	if engaged:
		for e in _enemies:
			if is_instance_valid(e):
				e.engaged = true
				e.engage_grace_s = COMBAT_EXIT_GRACE_S


## DEBUG (sandbox): ADD `count` of ONE enemy as its own squad (additive — does NOT clear, so
## you can build up a group, e.g. several EN-009 for surround). Clear via debug_spawn_only("").
func debug_spawn_unit(enemy_id: String, count: int, room_ref: String, engaged: bool = false, faction: String = "Dungeon") -> void:
	if enemy_id.is_empty() or count <= 0:
		return
	if _map and _map.has_method("get_spawn_position"):
		_spawn_origin = _map.get_spawn_position(room_ref)
	var units := [{"enemy_id": enemy_id, "count": count}]
	var squad_id := _next_squad_id
	_next_squad_id += 1
	var lane := int(_room_squad_count.get(room_ref, 0))
	_room_squad_count[room_ref] = lane + 1
	var center := _squad_spawn_center(room_ref, lane)
	_spawn_at(units, center, squad_id, engaged, "Fixed", 1, "all", faction)
	_squads.append({"id": squad_id, "room_ref": room_ref, "encounter_id": "", "cleared": false, "reinforce": {}, "pending": false, "activated": false, "timer": 0.0, "warned": false})


## Spawn one encounter as a dormant squad, pushed toward the room's FAR side (away
## from the party) so the start-adjacent room isn't in combat range at spawn.
func _spawn_squad(encounter_id: String, room_ref: String, units_override: Array = []) -> void:
	var enc := Slice01Data.get_encounter(encounter_id)
	# S5b: 생성 조합이 있으면 ENC의 authored units를 대체(frame=placement/faction/reinforcement는 유지).
	var units: Array = units_override if not units_override.is_empty() else enc.get("units", [])
	if units.is_empty():
		return
	var squad_id := _next_squad_id
	_next_squad_id += 1
	# Lane = how many squads already share this room → lateral offset so co-located
	# squads (e.g. relocated start-room encounter + the court's own) don't overlap.
	var lane := int(_room_squad_count.get(room_ref, 0))
	_room_squad_count[room_ref] = lane + 1
	var center: Vector3 = _squad_spawn_center(room_ref, lane)
	_spawn_at(units, center, squad_id, false, String(enc.get("placement_behavior", "Fixed")),
		int(enc.get("ambush_anchor_count", 1)), String(enc.get("wake_policy", "all")),
		String(enc.get("faction", "Dungeon")))
	var reinf: Dictionary = enc.get("reinforcement", {})
	_squads.append({
		"id": squad_id,
		"room_ref": room_ref,
		"encounter_id": encounter_id,   # HUB-COR-000: ENC-bound haul on clear
		"cleared": false,
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
	# Seeded scatter (LDG-SPAWN-DEMO-001 §2 placement variety, game-side): nudge the spawn off the
	# exact deep point per run so positions aren't memorizable. run_seed=0 (sandbox/no run) → none.
	# NOTE: no navmesh snap here — at prespawn the NavigationServer map isn't synced yet, so
	# map_get_closest_point() returns origin (0,0,0) and would collapse EVERY squad onto the party
	# start. The deep point is interior and the scatter (±SPAWN_SCATTER_M) is within the same range
	# the fixed _spawn_offset ring already uses safely, so a snap isn't needed.
	var rng_seed := int(RunLoadout.get_run_seed())
	if rng_seed != 0:
		var h: int = abs(hash("%d|%s|%d" % [rng_seed, room_ref, lane]))
		var ang := float(h % 360) * (PI / 180.0)
		# 절차적 스폰 위치(S5b) — 고정 4.5m 대신 방 크기 비례 반경으로 deep-anchor 주변을 넓게 산포 →
		# 런마다·방마다 위치가 달라짐. deep anchor가 far-side 편향을 유지(파티 반대편).
		var size: Vector3 = _map.get_room_size(room_ref) if _map.has_method("get_room_size") else Vector3(16, 0, 16)
		var max_rad := clampf(GEN_SCATTER_FRAC * minf(size.x, size.z), SPAWN_SCATTER_M, GEN_SCATTER_MAX)
		@warning_ignore("integer_division")  # intentional — hash bit extraction for the seeded scatter
		var rad := max_rad * (0.35 + 0.65 * float((h / 360) % 100) / 100.0)
		center += Vector3(cos(ang), 0.0, sin(ang)) * rad
		# 벽 안으로 클램프(방 중심 ± size/2 − margin) — 산포가 벽을 뚫지 않게.
		var c0: Vector3 = _map.get_spawn_position(room_ref)
		var hx := maxf(1.0, size.x * 0.5 - SPAWN_WALL_MARGIN)
		var hz := maxf(1.0, size.z * 0.5 - SPAWN_WALL_MARGIN)
		center.x = clampf(center.x, c0.x - hx, c0.x + hx)
		center.z = clampf(center.z, c0.z - hz, c0.z + hz)
	return center


## AmbushHold dual-anchor: spread `anchor_count` hiding spots perpendicular to the party's approach,
## centered on `base`, ANCHOR_SEP_M apart. anchor_count<=1 → just `base` (single corner).
func _anchor_center(base: Vector3, anchor_id: int, anchor_count: int) -> Vector3:
	if anchor_count <= 1:
		return base
	var dir := base - _spawn_origin
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	var perp := Vector3(dir.z, 0.0, -dir.x)  # 90° to the approach axis
	var t := float(anchor_id) - float(anchor_count - 1) * 0.5  # center the spread (2 → -0.5,+0.5)
	return base + perp * (t * ANCHOR_SEP_M)


## pool 방 후보를 spawn_weight로 가중 추첨(비복원) → 최대 `count`개 선택(시드 결정적). 런 전체 전투 예산.
## spawn_weight = 선택 확률(조밀할수록 잘 뽑힘·0은 후보에서 이미 제외). 향후 각 전투를 더 무겁게 만들 예정.
func _weighted_pick_rooms(candidates: Array, count: int, seed: int) -> Array:
	var pool: Array = candidates.duplicate()
	var chosen: Array = []
	var draw := 0
	while not pool.is_empty() and chosen.size() < count:
		var total := 0.0
		for c in pool:
			total += float(c["weight"])
		if total <= 0.0:
			break
		# 시드 결정적 가중 추첨(draw마다 다른 해시).
		var r := float(abs(hash("encpick|%d|%d" % [seed, draw])) % 100000) / 100000.0 * total
		var acc := 0.0
		var idx := 0
		for i in pool.size():
			acc += float(pool[i]["weight"])
			if r < acc:
				idx = i
				break
		chosen.append(pool[idx])
		pool.remove_at(idx)
		draw += 1
	return chosen


## S5b P3 (F-028) — 제3세력 창발 주입. 4~5 전투 중 **0~1개**만(THIRD_FACTION_CHANCE 확률로 1) 몬스터 방을
## 골라 Stalker Pack을 활성(engaged) 스폰 → 동일 방 몬스터(교차진영)와 기존 지각/전투로 실시간 교전(매
## 프레임 틱이라 오프스크린에서도 진행) → 플레이어는 입장 시 교전중/약화/정리 상태를 만남. (난장판 방지로 1개 한정.)
func _inject_third_faction(seed: int, combat_rooms: Array) -> void:
	if combat_rooms.is_empty() or seed == 0:
		return   # run_seed=0(샌드박스/무런)이면 주입 안 함
	if float(abs(hash("3rdchance|%d" % seed)) % 1000) / 1000.0 >= THIRD_FACTION_CHANCE:
		return   # 이 런엔 제3세력 없음
	var room := String(combat_rooms[abs(hash("3rdroom|%d" % seed)) % combat_rooms.size()])
	_spawn_third_squad(room)
	print("[TDC] 제3세력 창발 주입: 1 squad → %s" % room)


## 한 방에 제3세력 Stalker Pack을 활성 스폰(engaged) — 즉시 가장 가까운 적대(몬스터)를 사냥.
func _spawn_third_squad(room_ref: String) -> void:
	var squad_id := _next_squad_id
	_next_squad_id += 1
	var lane := int(_room_squad_count.get(room_ref, 0))
	_room_squad_count[room_ref] = lane + 1
	var center := _squad_spawn_center(room_ref, lane)
	_spawn_at(THIRD_FACTION_PACK, center, squad_id, true, "Fixed", 1, "all", THIRD_FACTION_NAME)  # engaged=true → 몬스터 사냥
	_squads.append({"id": squad_id, "room_ref": room_ref, "encounter_id": "ENC-3RD-emergent", "cleared": false, "reinforce": {}, "pending": false, "activated": true, "timer": 0.0, "warned": false})
	print("[TDC] 제3세력 Squad %d (창발) %s @ %s" % [squad_id, room_ref, center])


## S5b 하이브리드 게이트 — 보스·제3세력(set-piece)은 authored 유지, 나머지 일반 전투는 생성.
## (forceEncounter QA핀은 get_encounter_for_pool에서 이미 처리됨 — 여기선 그 결과 id로 판정.)
func _should_generate(encounter_id: String) -> bool:
	if encounter_id.is_empty():
		return false
	return not (encounter_id.begins_with("ENC-BOSS") or encounter_id.begins_with("ENC-3RD"))


## 생성기의 flat enemy_id 리스트 → {enemy_id, count} 유닛 리스트(같은 id 집계, 등장 순서 유지).
func _comp_to_units(enemy_ids: Array) -> Array:
	var counts: Dictionary = {}
	var order: Array = []
	for eid in enemy_ids:
		var s := String(eid)
		if not counts.has(s):
			order.append(s)
		counts[s] = int(counts.get(s, 0)) + 1
	var out: Array = []
	for s in order:
		out.append({"enemy_id": s, "count": int(counts[s])})
	return out


## First room the given room opens onto (used to relocate the start-room encounter).
func _first_connected(room_ref: String) -> String:
	var conns: Array = Slice01Data.get_room_row(room_ref).get("connects", [])
	return String(conns[0]) if not conns.is_empty() else ""


func _spawn_at(units: Array, center: Vector3, squad_id: int, engaged: bool, placement: String = "Fixed", anchor_count: int = 1, wake_policy: String = "all", faction: String = "Dungeon") -> void:
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
			# AmbushHold dual-anchor: distribute units round-robin across the anchor spots.
			var aid := index % maxi(anchor_count, 1)
			unit.global_position = _anchor_center(center, aid, anchor_count) + _spawn_offset(index)
			unit.squad_id = squad_id
			unit.faction = String(u.get("faction", faction))   # F-028 — ENC faction; 유닛별 override 가능(혼합 진영)
			# F-028 비주얼 마커: 비-Dungeon 진영은 콘(원뿔)+violet 틴트로 박스 적과 구분.
			if unit.faction != "Dungeon" and unit.has_method("apply_faction_shape"):
				unit.apply_faction_shape()
			# AssassinTransform: per-ENCOUNTER tag (not a unit-catalog property) — one fodder
			# row flagged disguised; same enemy_id rows without the flag stay normal.
			if bool(u.get("assassin", false)):
				unit.assassin = true
				unit.assassin_telegraph_s = float(u.get("assassin_telegraph_s", 0.6))
			# MiniBoss overlay (ENC-BOSS-001): per-ENC promotion — ccTenacity + HP-phase + High attention.
			if bool(u.get("boss", false)):
				unit.miniboss = true
				unit.cc_tenacity = float(u.get("cc_tenacity", 1.2))
				unit.boss_phase2_hp_frac = float(u.get("phase2_hp_frac", 0.5))
				unit.boss_phase2_telegraph_delta = float(u.get("phase2_telegraph_delta", -0.15))
				if unit.has_method("set_attention"):
					unit.set_attention(true)
			# Placement (F-006, P2-S2-place): encounter-level Patrol/AmbushHold/Fixed. Per-unit
			# interacts_with_objects override = torch bearer (PAT-003 EN-010).
			unit.placement_mode = placement
			unit.anchor_id = aid
			unit.wake_policy = wake_policy
			if bool(u.get("interacts_with_objects", false)):
				unit.interacts_with_objects = true
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
## Reinforcement arrival point — relative to WHOEVER THE SQUAD IS CURRENTLY FIGHTING (its nearest
## hostile), not a fixed room point. "rear" = behind that hostile (a pincer on the squad's enemy);
## "flank" = to its side. So in faction warfare a boss's adds join the boss-vs-3rd fight (behind the
## 3rd), NOT at the stale entrance behind a distant observer. Falls back to the room point only when
## the squad has no living members (reinforce-on-clear). ref: 사용자 — "증원이 내 뒤에 생김(진영전)".
func _reinforce_point(squad: Dictionary) -> Vector3:
	var direction := _reinforce_direction(squad)
	var sid := int(squad["id"])
	var centroid := _squad_centroid(sid)
	if centroid == Vector3.INF:
		# whole squad dead (on-clear reinforce) → no anchor; use the room spawn + entrance offset.
		var rc := _squad_spawn_center(String(squad["room_ref"]))
		return rc + (Vector3(9.0, 0, 2.0) if direction == "flank" else Vector3(0, 0, -8))
	var off := 6.0
	var hostile := _squad_primary_hostile(sid, centroid)
	var anchor: Vector3 = hostile.global_position if hostile != null else centroid
	var dir := anchor - centroid
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.5 else Vector3(0, 0, 1)
	if direction == "flank":
		return anchor + Vector3(dir.z, 0.0, -dir.x) * off   # to the side of the squad's current fight
	return anchor + dir * off                               # behind the squad's current enemy (pincer)


## Centroid of a squad's LIVING members (Vector3.INF if none alive).
func _squad_centroid(squad_id: int) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for e in _enemies:
		if is_instance_valid(e) and e.squad_id == squad_id and e.is_alive():
			sum += e.global_position
			n += 1
	return (sum / float(n)) if n > 0 else Vector3.INF


## The unit a squad is currently fighting = nearest LIVING hostile to the squad's faction (party
## always hostile; cross-faction enemies). null if none. Aims reinforcement arrival at the real fight.
func _squad_primary_hostile(squad_id: int, centroid: Vector3) -> Node3D:
	var fac := ""
	for e in _enemies:
		if is_instance_valid(e) and e.squad_id == squad_id and e.is_alive():
			fac = String(e.faction)
			break
	var best: Node3D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("party_member"):
		if is_instance_valid(p) and (not p.has_method("is_alive") or p.is_alive()):
			var d: float = centroid.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = p
	for e in _enemies:
		if is_instance_valid(e) and e.is_alive() and e.squad_id != squad_id and String(e.faction) != fac:
			var d: float = centroid.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


func _reinforce_direction(squad: Dictionary) -> String:
	var reinf = squad.get("reinforce", {})
	return String(reinf.get("direction", "rear")) if typeof(reinf) == TYPE_DICTIONARY else "rear"


## Spawn a squad's reinforcement wave (already engaged — they arrive into the fight).
func _spawn_reinforcement(squad: Dictionary) -> void:
	var reinf: Dictionary = squad.get("reinforce", {})
	var units: Array = reinf.get("units", [])
	if units.is_empty():
		return
	_spawn_at(units, _reinforce_point(squad), int(squad["id"]), true)
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
		var by_party: bool = bool(unit.killed_by_party) if "killed_by_party" in unit else true
		enemy_defeated.emit(unit.global_position, refs, by_party)  # → 파티 킬만 loot/scrap
		# Squad fully cleared → ENC-bound haul drop, once (HUB-COR-000 §3).
		var sq_id := int(unit.squad_id)
		if _squad_alive_count(sq_id) == 0:
			for sq in _squads:
				if int(sq.get("id", -1)) == sq_id and not bool(sq.get("cleared", false)):
					sq["cleared"] = true
					var eid := String(sq.get("encounter_id", ""))
					if not eid.is_empty():
						squad_cleared.emit(eid, unit.global_position)
					break

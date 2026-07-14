extends CharacterBody3D
## One party slot — cylinder placeholder with role color/size (A2 replaces mesh).

signal became_controlled
signal became_non_controlled
signal downed(member: CharacterBody3D)

const LAYER_PARTY := 2
## world(1) + enemy(4). Party members do NOT physically collide with each other
## (steering separation handles ally spacing) — prevents climbing/stacking when
## they bunch. Still blocked by walls and enemies.
const MASK_PARTY := 5
const MASK_WORLD_ONLY := 1
const DEFAULT_COLLISION_RADIUS := 0.26
const DEFAULT_COLLISION_HEIGHT := 1.15

const CONTROLLED_SCALE := 1.15
const CONTROLLED_EMISSION := 0.55
const HealthBar := preload("res://scripts/combat/health_bar.gd")

# --- Identity Gear (F-008 §3.7 / DEC-20260611-001): gear is the source of identity ---
## base_gear_id -> bundled_identity_skill_id -> identities.json row -> the identity fields below.
var equipped_gear: Dictionary = {}
var base_gear_id: String = ""
var gear_kind: String = ""
var basic_attack_profile_id: String = ""
## F-008 §3.7 / D-019 — 평타 특수거동은 ba 아키타입(basic_attack_profile_id) 소관. profile id → {cleave_m, kb_m}.
## cleave_m = 1차 대상 주변 splash 반경(2차=BASIC_CLEAVE_FALLOFF 피해), kb_m = 피격 적 넉백 거리. 없으면 단일타.
const BASIC_BEHAVIOR := {
	"ba_tank_march_stomp": {"cleave_m": 3.0, "kb_m": 1.5},
	"ba_tank_line_jab": {"cleave_m": 2.5},
	"ba_tank_aegis_ram": {"kb_m": 2.5},
	"ba_tank_hook_tug": {"kb_m": 1.5},
	"ba_dps_brand_sweep": {"cleave_m": 3.0},
	"ba_dps_ripple_pulse": {"cleave_m": 2.5},
	"ba_dps_weave_lance": {"pierce_m": 9.0},     # 원거리 관통(lance/needle/shard/coil)
	"ba_dps_needle_prick": {"pierce_m": 8.0},
	"ba_nuker_shard_shot": {"pierce_m": 8.0},
	"ba_mag_coil_snap": {"pierce_m": 9.0},
	"ba_mag_volt_needle": {"pierce_m": 8.0},
}
var basic_cleave_m: float = 0.0       # >0 = 평타 splash 반경(ba 아키타입 파생)
var basic_knockback_m: float = 0.0    # >0 = 평타 피격 넉백 거리(ba 아키타입 파생)
var basic_pierce_m: float = 0.0       # >0 = 평타 라인 관통 길이(ba 아키타입, 원거리)
var equip_classes: Array = []
## F-008 §3.7 rolled 서브옵션(dmg_mult/cd_mult 등) — 인스턴스 굴림 저장 + 스탯 적용(G3). ref: gear_roll_table.md.
var gear_rolls: Dictionary = {}
## cd_mult 적용분 — identity 스킬 쿨다운에 곱(ability_dispatch.try_identity). 1.0 = none.
var cooldown_mult: float = 1.0
## potency_mult 적용분 — identity 스킬 위력(_coeff)에 곱(ability_dispatch.try_identity). 1.0 = none. F-008 §3.7.
var identity_potency_mult: float = 1.0

# --- Identity (resolved from equipped_gear's bundled identity) ---
var identity_skill_id: String = ""
var class_id: String = ""
var ability_id: String = ""
var slot_index: int = -1
## Seconds to wait before moving toward a new slot after layout forward changes.
var follow_reposition_delay_s: float = 0.0

# --- Combat (from identity `combat` block; generic plumbing) ---
var max_hp: float = 100.0
var hp: float = 100.0
var basic_damage: float = 8.0
var basic_range_m: float = 2.0
var basic_interval_s: float = 1.0
var attack_cooldown_s: float = 0.0
## F-022 damageThreatMultiplier — Tank amplifies its damage-threat to hold aggro.
var threat_mult: float = 1.0
var _alive: bool = true
var _mia: bool = false
var _warn: bool = false
var _mia_marker: Label3D = null
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
var _slow_dur: float = 0.0
var _hexweak_mult: float = 1.0    # AB-012 HEX-WEAK: outgoing-damage multiplier (1.0 = none)
var _hexweak_timer_s: float = 0.0
var _hexweak_dur: float = 0.0

# --- Identity skill (from `identity` block) + shield (IDA-020) ---
var identity_params: Dictionary = {}
var identity_cooldown_s: float = 0.0
## DEBUG (combat sandbox): independent on/off for this member's basic attack + Identity skill, so
## 평타 검증 / identity 검증 can be isolated per-member. Both default true; a gear equip resets both
## on (gear binds 평타+identity together — these let the sandbox split them). ref: DRIFT-056.
var basic_enabled: bool = true
var identity_enabled: bool = true
## Player-activated sub skill (key 1 on the controlled member). NC never auto-uses.
## (legacy single-sub fields — kept empty; subs now come from skillbook_slots below.)
var sub_ability_id: String = ""
var sub_params: Dictionary = {}
var sub_cooldown_s: float = 0.0
## Sub skillbook slots Q/E/R (F-009 §3.1 / DEC-20260611-002). Each = null or an instance:
## {base_ability_id, display_name, params, charges, charges_max, cooldown_s, equip_classes, color}.
var skillbook_slots: Array = [null, null, null]
## Damage-absorbing shield (consumed before HP). IDA-020 Shield Policy.
var shield: float = 0.0
var shield_timer_s: float = 0.0
# 수호-흡수 힐(skillbook_ward_heal) — dur초 보호막, 종료 시 흡수한 피해량만큼 치유(ward_heal 노드가 정산).
var _ward_hp: float = 0.0          # 남은 수호 보호막
var _ward_timer_s: float = 0.0     # 수호 유지 시간(0 = 없음/종료)
var _ward_absorbed: float = 0.0    # 이 수호가 흡수한 누적 피해(→ 종료 시 치유량)
# --- Status effects (F-021): stun (can't act) + poison (DoT, bypasses shield) ---
var stun_timer_s: float = 0.0
var poison_timer_s: float = 0.0
var poison_dps: float = 0.0
var _poison_accum: float = 0.0
var _stun_dur: float = 1.0
var _poison_dur: float = 1.0
var _shield_dur: float = 1.0
# F-008 Sentinel Form (IDA-052) — temporary turtle-stance damage reduction (1.0 = none) + timer.
var damage_taken_mult: float = 1.0
var _sentinel_timer_s: float = 0.0
var _sentinel_reflect: float = 0.0   # IDA-052 reflect fraction of incoming hits while the stance holds
# F-009 HoT (Renewing Tide AB-065 / 지속치유 IDA-031) — **중첩** 가능: 각 적용이 독립 인스턴스로 쌓인다.
var _regen_hots: Array = []        # [{pct: maxHP%/s, t: 남은 초}] — 매 프레임 활성분 합산 회복
var _regen_accum: float = 0.0      # 소수 HP 누적(정수 단위로 heal)
const REGEN_TICK_S := 0.5          # HoT 틱 피드백 주기 — 이 간격마다 "+N" 초록 플로팅(1안)
var _regen_tick_heal: float = 0.0  # 틱 주기 동안 실제 회복분 누적(base, 초록)
var _regen_tick_bonus: float = 0.0 # 틱 주기 동안 성역 등 추가분 누적(금색)
var _regen_pop_t: float = 0.0      # 틱 팝업 주기 타이머
# F-009 Haste (Swift Grace AB-069) — move + attack speed multiplier (1.0 = none).
var _haste_mult: float = 1.0
var _haste_timer_s: float = 0.0
# F-009 Veiled (Smoke Veil AB-062) — brief stealth: enemy targeting drops this member while active.
var _veil_timer_s: float = 0.0
var _veil_dur: float = 1.0
# F-009 Shadowstep (AB-061) — the NEXT damaging hit by this member is boosted, consumed once.
var _next_hit_bonus: float = 0.0
# F-009 Casting (wind-up, skill_cast) — caster occupied; blocks other active casts until the cast
# resolves. NOTE: AB-054 Rending Beam is a CHANNEL, not a wind-up cast — it does NOT set this (it no
# longer occupies/roots; instead moving or casting interrupts it via _active_channel below).
var _channel_timer_s: float = 0.0
## AB-054 채널 진행 노드 참조 — 이동/다른 스킬 시전이 채널을 강제로 막지 않고 대신 중단시킨다(begin_channel 점유와 별개).
var _active_channel: Node = null
## Elemental OUTCOME statuses (STATUS-OUTCOME-CORE): Sodden/Chilled/SteamHaze/Slippery/Shock/Ignited/
## WindBuffeted — shared container with enemy_unit. Movement folds into move_speed_mult; Slippery
## adds inertia (player_controller); Ignited DoT applied in _physics_process.
var _outcome = preload("res://scripts/combat/outcome_status.gd").new()
## Provoked (AB-099 Iron Mockery): movement input + active skills locked, forced basic attack
## on the caster. Character-bound (swap keeps it). Stunned suppresses the EFFECTS (is_provoked
## returns false while stunned) but the timer keeps running. ref: AB-099 / STATUS-ACTOR-CORE.
var provoked_timer_s: float = 0.0
var _provoke_dur: float = 1.0
var provoke_source: Node = null
# P4a Kit Binding (결속) — transient overlay runtime state (BIND-*). Controlled-ally only
# (NC never casts subs, F-020 §3.3). Applied by AbilityDispatch after a base sub cast; ticked here.
# ref: F-020 §3.7 · binding_overlays.gd. All cleared on debug_reset.
const BULWARK_STACK_WINDOW := 5.0  # 이 시간 안에 다음 스택을 안 쌓으면 방벽 스택 리셋(누적 방지)
var bulwark_stacks: int = 0        # BIND-001 — Intercept accrues; 3-stack consume → stun + reset
var _bulwark_icd_s: float = 0.0    # ICD after a consume (pilot: member-wide; spec = per-enemy 8s)
var _bulwark_stack_timer: float = 0.0  # 스택 만료 타이머(마지막 스택 이후 경과)
var _badges = null                 # OverheadBadges 스트립(lazy) — 방벽 등 자기 스택 상태를 한 줄로 통합
var _marked_enemy = null           # Beacon 「표식」 — identity가 남긴 표식 대상 (untyped: may hold a freed ref)
var _mark_timer_s: float = 0.0
var _mark_cd_reduce: float = 0.0
var _focus_enemy = null            # Mark&Ruin 「집중」 — identity가 새긴 집중 대상 (untyped: may hold a freed ref)
var _focus_timer_s: float = 0.0    # 집중 유지(마지막 갱신 후 경과); 0 = 집중 없음
var _focus_stacks: int = 0         # 집중 누적(딜링 서브가 집중 대상 명중 시 +1); 처형이 소모
var _focus_cd_reduce: float = 0.0  # 처형 막타 시 링크 서브 쿨 감소율
var _sanctuary_pos: Vector3 = Vector3.ZERO   # Mend Circle 「성역」 — identity가 세운 좁은 zone의 고정 지면 위치
var _sanctuary_timer_s: float = 0.0          # 성역 유지 시간; 0 = 없음
var _sanctuary_radius: float = 3.0
var _sanctuary_ring: MeshInstance3D = null   # 지면 링(top_level — 시전자 이동과 무관하게 고정)
var _od_gauge: float = 0.0            # DPS press_line 「초월」 게이지(0.._od_gauge_max). 가득 차면 발동 상태로 유지
var _od_gauge_max: float = 100.0      # (지속시간 없음) — 강화 서브 1회 시전 시 소모, 비전투 5초면 초기화(party_controller)
var _od_active: bool = false          # 초월 발동 상태(다음 서브 1회가 강화 변형) — ability_dispatch가 조회·소모
var _status_orb: MeshInstance3D
var _flash_heal_tw: Tween

var _controlled: bool = false
var _base_color: Color = Color.WHITE
var _body_material: StandardMaterial3D
var _role_scale: float = 1.0
var _hp_bar: Node3D
var _flash_tw: Tween

## Cached navmesh path (y=0 projected, queried via NavigationServer3D)
var _nav_path: PackedVector3Array = PackedVector3Array()
var _nav_path_idx: int = 0
var _nav_target: Vector3 = Vector3.ZERO


## Spawn a party member from its Identity Gear master (F-008 §3.7): the gear's
## bundled_identity_skill_id resolves the identity row that drives stats + skills.
func setup(gear: Dictionary, index: int, color: Color, collision_radius: float = -1.0, collision_height: float = -1.0, role_scale: float = 1.0) -> void:
	slot_index = index
	_base_color = color
	_role_scale = role_scale
	_bind_gear(gear, true)
	name = identity_skill_id
	_apply_collision_size(collision_radius, collision_height)
	_build_cylinder_mesh(color, role_scale)
	collision_layer = LAYER_PARTY
	collision_mask = MASK_PARTY
	add_to_group("party_member")
	_apply_controlled_visual(false)
	_build_hp_bar()


## Resolve identity from an Identity Gear master and apply it to this member.
## base_gear_id -> bundled_identity_skill_id -> identities.json row -> stats/skills.
## reset_hp=true on spawn; false on mid-run swap (keep current HP, clamp to new max).
func _bind_gear(gear: Dictionary, reset_hp: bool) -> void:
	equipped_gear = gear
	base_gear_id = String(gear.get("base_gear_id", ""))
	gear_kind = String(gear.get("gear_kind", ""))
	basic_attack_profile_id = String(gear.get("basic_attack_profile_id", ""))
	_apply_basic_behavior()   # F-008 §3.7 ba 아키타입 평타 특수거동(cleave/knockback)
	equip_classes = gear.get("equip_classes", [])
	# F-008 §3.7 — effective Identity = 인스턴스의 rolled_identity_skill_id(있으면) > 아키타입 bundled
	# (스타터 핀·폴백). master 행엔 rolled 없음 → bundled. ref: gear_roll_table.md.
	identity_skill_id = String(gear.get("rolled_identity_skill_id", gear.get("bundled_identity_skill_id", "")))
	gear_rolls = gear.get("rolls", {}) if typeof(gear.get("rolls", {})) == TYPE_DICTIONARY else {}   # G2 저장(적용=G3)
	var row: Dictionary = Slice01Data.get_identity_row(identity_skill_id)
	class_id = String(row.get("class_id", ""))
	ability_id = String(row.get("ability_id", ""))
	var combat: Dictionary = row.get("combat", {})
	max_hp = float(combat.get("hp", 100.0))
	hp = max_hp if reset_hp else minf(hp, max_hp)
	# F-008 / D-019 §4.4: the basic attack is GEAR-bound (the gear's ba_* archetype owns
	# damage/CD/range), NOT the identity. Read from the gear; fall back to the identity's combat
	# block when the gear doesn't specify it (starter gears = identity default). 특수거동(cleave/
	# knockback)은 ba 아키타입 소관 → _apply_basic_behavior(BASIC_BEHAVIOR). pierce(라인관통)=후속.
	basic_damage = float(gear.get("basic_damage", combat.get("basic_damage", 8.0)))
	basic_range_m = float(gear.get("basic_range_m", combat.get("basic_range_m", 2.0)))
	basic_interval_s = float(gear.get("basic_interval_s", combat.get("basic_interval_s", 1.0)))
	threat_mult = float(combat.get("threat_mult", 1.0))  # F-022 damageThreatMultiplier
	# F-008 §3.7 옵션 roll 적용(G3): dmg_mult→평타 위력(매 bind마다 fresh 재계산이라 비누적), cd_mult→
	# identity 쿨(ability_dispatch.try_identity가 cooldown_mult를 곱). ref: gear_roll_table.md.
	basic_damage *= float(gear_rolls.get("dmg_mult", 1.0))
	cooldown_mult = float(gear_rolls.get("cd_mult", 1.0))
	identity_potency_mult = float(gear_rolls.get("potency_mult", 1.0))   # F-008 §3.7 — identity 위력 굴림(비누적)
	_apply_chapel_passive()   # F-029 성소(chapel) T1 효과 실연동 — 역할별 passive(F-020-lite). bind마다 fresh.
	hp = max_hp if reset_hp else minf(hp, max_hp)   # 패시브로 max_hp 변동 → hp 재클램프
	# Identity + sub skill params are LINKED by id (abilities.json catalog).
	identity_params = Slice01Data.get_ability(ability_id)
	# Sub skills come from looted skillbooks (F-009 §3.1), NOT the identity/gear — the
	# Q/E/R slots start empty and fill by equipping skillbooks. (was: innate AB-S01..S04)
	sub_ability_id = ""
	sub_params = {}
	identity_cooldown_s = 0.0
	# Gear binds BOTH channels → equipping resets both on (sandbox may split them again after).
	basic_enabled = true
	identity_enabled = true


## Role gate (F-008 §3.4, strict): a member may only equip gear for its own class.
func can_equip_gear(gear: Dictionary) -> bool:
	var classes = gear.get("equip_classes", [])
	return typeof(classes) == TYPE_ARRAY and classes.has(class_id)


## Mid-run / hub gear swap (F-008 §3.2): caller enforces partyInCombat==false.
## Returns false (no change) on cross-role gear. Re-syncs identity to the new gear.
func equip_gear(gear: Dictionary) -> bool:
	if not can_equip_gear(gear):
		return false
	_bind_gear(gear, false)
	name = identity_skill_id
	return true


## Remove the equipped gear (drag-out to inventory). Identity skill goes inactive until
## a same-role gear is re-equipped; basic stats persist. Returns the removed master ({} if none).
func unequip_gear() -> Dictionary:
	var prev: Dictionary = equipped_gear
	equipped_gear = {}
	base_gear_id = ""
	identity_params = {}
	return prev


## Sub skillbook slots (F-009 §3.1). Role gate = equipClasses on the skillbook master.
func can_equip_skillbook(master: Dictionary) -> bool:
	var classes = master.get("equip_classes", [])
	return typeof(classes) == TYPE_ARRAY and classes.has(class_id)


func get_skillbook(sb_slot: int):
	if sb_slot < 0 or sb_slot >= skillbook_slots.size():
		return null
	return skillbook_slots[sb_slot]


## Put `inst` (or null) in slot; returns whatever it displaced (null if empty).
func set_skillbook(sb_slot: int, inst):
	if sb_slot < 0 or sb_slot >= skillbook_slots.size():
		return null
	var prev = skillbook_slots[sb_slot]
	skillbook_slots[sb_slot] = inst
	return prev


## Equip a skillbook into a Q/E/R slot by base_ability_id (deployment loadout apply, F-010).
## F-029 성소(chapel) T1 효과 실연동 — 역할별 passive 강화(F-020-lite). HubProfile 시설 Tier ≥1이면 적용.
## _bind_gear에서 호출(bind마다 fresh 재계산 → 비누적). F-020 패시브 트리 미구현 → 역할별 단일 노드 데모 근사.
func _apply_chapel_passive() -> void:
	var hub := get_node_or_null("/root/HubProfile")
	if hub == null or not hub.has_method("facility_tier") or int(hub.facility_tier("chapel")) < 1:
		return
	match class_id:
		"Tank": max_hp *= 1.15        # 전선 내구
		"Healer": max_hp *= 1.12      # 생존
		"DPS", "Nuker": basic_damage *= 1.12   # 화력


func equip_skillbook_by_id(sb_slot: int, base_ability_id: String, affix: Dictionary = {}) -> void:
	if sb_slot < 0 or sb_slot >= skillbook_slots.size() or base_ability_id == "":
		return
	var master: Dictionary = Slice01Data.get_skillbook_master(base_ability_id)
	if master.is_empty():
		return
	# D-018 §7.6 affix_charges_small → chargesMax 가산(coeff affix와 별도).
	var cmax := int(master.get("charges_max", 30)) + int(affix.get("charges", 0))
	set_skillbook(sb_slot, {
		"base_ability_id": base_ability_id,
		"display_name": String(master.get("display_name", base_ability_id)),
		"params": master.get("cast", {}),
		"charges": cmax,
		"charges_max": cmax,
		"cooldown_s": 0.0,
		"equip_classes": master.get("equip_classes", [class_id]),
		"color": _base_color,
		"affix": affix,   # D-018 §7.3 — coeffMult/cd_trade는 cast 시 적용(ability_dispatch)
	})


# ============================================================================
# P4a Kit Binding (결속) — runtime overlay state helpers. Driven by AbilityDispatch._apply_binding
# after a base sub cast (which owns ctx / enemy queries); this side holds + ticks the per-member
# transient state. NON-CANONICAL pilot. ref: F-020 §3.7 · binding_overlays.gd.
# ============================================================================

func _tick_binding(delta: float) -> void:
	if _bulwark_icd_s > 0.0:
		_bulwark_icd_s -= delta
	if _bulwark_stack_timer > 0.0:                 # 스택 만료: 창 안에 안 쌓이면 리셋(오발 방지)
		_bulwark_stack_timer -= delta
		if _bulwark_stack_timer <= 0.0 and bulwark_stacks > 0:
			bulwark_stacks = 0
			if _badges != null:
				_badges.clear_badge("bulwark")
	if _mark_timer_s > 0.0:
		_mark_timer_s -= delta
		if _binding_mark_dead():
			_binding_mark_refund()   # 표식 대상 처치 → 링크된 모든 슬롯 스킬 쿨 동시 감소
		elif _mark_timer_s <= 0.0:
			_binding_mark_clear()
	if _focus_timer_s > 0.0:                        # 집중: 대상 사망(처형 외) 또는 만료 시 정리
		_focus_timer_s -= delta
		if _binding_focus_dead() or _focus_timer_s <= 0.0:
			binding_focus_clear()
	if _sanctuary_timer_s > 0.0:                    # 성역: 만료 시 정리 + 링 밝기로 in/out(증폭 여부) 표시
		_sanctuary_timer_s -= delta
		if _sanctuary_timer_s <= 0.0:
			binding_sanctuary_clear()
		elif _sanctuary_ring != null:              # 안 = 밝게(증폭 중) / 밖 = 흐리게(들어가야 증폭)
			(_sanctuary_ring.material_override as StandardMaterial3D).albedo_color = \
				Color(1.0, 0.9, 0.55, 0.9) if in_sanctuary() else Color(1.0, 0.9, 0.55, 0.32)
	# 초월은 더 이상 시간으로 감소하지 않는다 — 가득 차면 강화 서브 1회를 쓸 때까지(overdrive_reset) 유지.
	# 비전투 5초 시 초기화는 party_controller가 처리(전투 상태를 아는 쪽).


## Read the watched enemy internally (untyped) — a freed instance passed as a typed arg throws
## "previously freed" before the body runs, so we never pass it across a typed boundary.
func _binding_mark_dead() -> bool:
	var e = _marked_enemy
	if not is_instance_valid(e):
		return true
	if e.has_method("is_alive"):
		return not e.is_alive()
	return float(e.get("hp")) <= 0.0 if ("hp" in e) else false


## 표식 대상 처치 → 링크된 모든 슬롯 스킬(Q/E/R)의 쿨다운을 동시에 감소.
func _binding_mark_refund() -> void:
	for s in skillbook_slots:
		if s != null and float(s.cooldown_s) > 0.0:
			s.cooldown_s = float(s.cooldown_s) * (1.0 - _mark_cd_reduce)
	_binding_mark_clear()


func _binding_mark_clear() -> void:
	if is_instance_valid(_marked_enemy) and _marked_enemy.has_method("hide_mark"):
		_marked_enemy.hide_mark()
	_marked_enemy = null
	_mark_timer_s = 0.0
	_mark_cd_reduce = 0.0


## BIND-001 — add a BulwarkCharge; returns true when a full-stack consume fires (caller stuns).
## Drives an overhead pip readout so the 누적 is visible (QA-005 §2.12 gate feedback).
func binding_bulwark_add(needed: int, icd_s: float) -> bool:
	if _bulwark_icd_s > 0.0:
		return false
	bulwark_stacks += 1
	if bulwark_stacks >= needed:
		bulwark_stacks = 0
		_bulwark_stack_timer = 0.0
		_bulwark_icd_s = icd_s
		if _badges != null:
			_badges.clear_badge("bulwark")
		popup_status("⚡ 방벽 소모", Color(1.0, 0.9, 0.3))   # consume flash(transient) — 실제 기절은 적에 표시
		return true
	# pips: filled = current stacks, hollow = remaining toward the consume.
	_bulwark_stack_timer = BULWARK_STACK_WINDOW   # 창 안에 다음 스택 안 쌓이면 리셋
	_badge_strip().set_badge("bulwark", "🛡" + "◆".repeat(bulwark_stacks) + "◇".repeat(maxi(0, needed - bulwark_stacks)))
	return false


## 픽스처 적용/재시작 시 결속 트랜지언트 상태 초기화(잔여 스택으로 인한 오발 방지).
func binding_reset() -> void:
	bulwark_stacks = 0
	_bulwark_icd_s = 0.0
	_bulwark_stack_timer = 0.0
	if _badges != null:
		_badges.clear_badge("bulwark")
	_binding_mark_clear()
	binding_focus_clear()
	binding_sanctuary_clear()


## 여러 스택 상태를 한 줄로 모으는 배지 스트립(lazy). 방벽 등 자기 스택이 세로로 나열되지 않게 통합.
const _OverheadBadges := preload("res://scripts/ui/overhead_badges.gd")
func _badge_strip():
	if _badges == null:
		_badges = _OverheadBadges.new()
		_badges.position = Vector3(0, 2.4, 0)
		add_child(_badges)
	return _badges


## BIND-003 — self shield (never lowers an existing larger shield). Uses the IDA-020 shield channel.
func binding_self_shield(amount: float, dur: float) -> void:
	if shield_timer_s <= 0.0:
		popup_status("보호막", Color(0.4, 0.9, 1.0))
	shield = maxf(shield, amount)
	shield_timer_s = maxf(shield_timer_s, dur)
	_shield_dur = maxf(_shield_dur, dur)


## Beacon 「표식」 — identity가 `enemy`에 표식을 남긴다. window 안에 그 적이 죽으면 링크된 모든 슬롯
## 쿨을 frac만큼 동시 감소(F-020 §3.7 identity-source binding). 새 표식은 이전 것을 대체.
func binding_mark(enemy, window: float, frac: float) -> void:
	# 표식 이동: 이전 대상의 표식 표시를 끈다.
	if _marked_enemy != enemy and is_instance_valid(_marked_enemy) and _marked_enemy.has_method("hide_mark"):
		_marked_enemy.hide_mark()
	_marked_enemy = enemy
	_mark_timer_s = window
	_mark_cd_reduce = frac
	if enemy != null and enemy.has_method("show_mark"):
		enemy.show_mark(window)   # 적 위에 "◈ 표식" 표시(발동 순간 가시화)


## R Challenge Mark — 표식 갱신: 활성 표식이 있을 때만 대상(있으면 교체)·유지 시간을 리셋.
func binding_remark(enemy, window: float) -> void:
	if _mark_timer_s <= 0.0:
		return
	if enemy != null and _marked_enemy != enemy:
		if is_instance_valid(_marked_enemy) and _marked_enemy.has_method("hide_mark"):
			_marked_enemy.hide_mark()
		_marked_enemy = enemy
	_mark_timer_s = maxf(_mark_timer_s, window)
	if is_instance_valid(_marked_enemy) and _marked_enemy.has_method("show_mark"):
		_marked_enemy.show_mark(_mark_timer_s)


## 현재 유효한 표식 대상(표식 유지 중 + 살아있음) 또는 null — 서브의 표식-조건부 추가효과 게이트.
func get_marked_enemy():
	if _mark_timer_s <= 0.0 or not is_instance_valid(_marked_enemy):
		return null
	if _marked_enemy.has_method("is_alive") and not _marked_enemy.is_alive():
		return null
	return _marked_enemy


# ---- Mark&Ruin 「집중」 (BIND-007~009) — identity가 집중 대상 새김 → 딜링 서브 누적 → 처형 폭발 -----------

## Read the focus enemy internally (untyped) — never cross a typed boundary with a possibly-freed ref.
func _binding_focus_dead() -> bool:
	var e = _focus_enemy
	if not is_instance_valid(e):
		return true
	if e.has_method("is_alive"):
		return not e.is_alive()
	return float(e.get("hp")) <= 0.0 if ("hp" in e) else false


## identity가 `enemy`를 집중 대상으로 새긴다(누적 초기화). 이미 살아있는 집중이 있으면 caller가 재지정 안 함(고정).
func binding_focus(enemy, window: float) -> void:
	if _focus_enemy != enemy and is_instance_valid(_focus_enemy) and _focus_enemy.has_method("hide_focus"):
		_focus_enemy.hide_focus()
	_focus_enemy = enemy
	_focus_timer_s = window
	_focus_stacks = 0
	if enemy != null and enemy.has_method("show_focus"):
		enemy.show_focus(0)   # 적 위에 "🎯 집중" 표시(발동 순간 가시화)


## 집중이 유지 중이고 살아있으면 그 대상, 아니면 null — 딜링 서브의 집중-조건부 추가효과 게이트.
func get_focus_enemy():
	if _focus_timer_s <= 0.0 or _binding_focus_dead():
		return null
	return _focus_enemy


## 집중 활성 여부(대상이 방금 죽었어도 창이 살아있으면 true) — 처형 막타 판정용.
func has_focus() -> bool:
	return _focus_timer_s > 0.0


## 딜링 서브가 집중 대상을 명중 → 집중 +1(cap), 유지 시간 갱신, 현재 누적 반환. 유효 집중 없으면 0.
func binding_focus_add(cap: int, window: float) -> int:
	if get_focus_enemy() == null:
		return 0
	_focus_stacks = mini(cap, _focus_stacks + 1)
	_focus_timer_s = window
	if is_instance_valid(_focus_enemy) and _focus_enemy.has_method("show_focus"):
		_focus_enemy.show_focus(_focus_stacks, _focus_stacks >= cap)   # 캡 도달 → 금색 MAX 큐(A)
	return _focus_stacks


## 다른 적을 조준 → 누적 끊김(집중 대상·유지 시간은 그대로, 스택만 0).
func binding_focus_break() -> void:
	_focus_stacks = 0
	if is_instance_valid(_focus_enemy) and _focus_enemy.has_method("show_focus"):
		_focus_enemy.show_focus(0)


## 「집중」 전이(E) — 현재 집중을 `enemy`로 옮긴다. 누적·유지 시간 유지, 마커도 이전. 집중 없으면 무시.
func binding_focus_transfer(enemy) -> void:
	if _focus_timer_s <= 0.0 or enemy == null:
		return
	if _focus_enemy != enemy and is_instance_valid(_focus_enemy) and _focus_enemy.has_method("hide_focus"):
		_focus_enemy.hide_focus()
	_focus_enemy = enemy
	if enemy.has_method("show_focus"):
		enemy.show_focus(_focus_stacks)


## 소모 아키타입 스킬: 현재 누적을 반환하고 0으로 소모. 집중 대상은 유지(살아있으면) → 다시 쌓아 재소모 가능.
func binding_focus_take() -> int:
	var n := _focus_stacks
	_focus_stacks = 0
	if is_instance_valid(_focus_enemy) and _focus_enemy.has_method("show_focus"):
		_focus_enemy.show_focus(0)   # 마커를 0으로 리셋(대상은 유지)
	return n


func binding_focus_clear() -> void:
	if is_instance_valid(_focus_enemy) and _focus_enemy.has_method("hide_focus"):
		_focus_enemy.hide_focus()
	_focus_enemy = null
	_focus_timer_s = 0.0
	_focus_stacks = 0


# ---- DPS press_line 「초월(Overdrive)」 (BIND-019~021) — 명중 게이지 → 강화 변형(1회). ability_dispatch 구동 ----
## 게이지 충전(발동 중엔 홀드라 무시). 가득 차면 발동 — 지속시간 없이 유지되며, 다음 강화 서브 1회 시전 시
## overdrive_reset로 소모된다(비전투 5초면 party_controller가 초기화). `_dur`은 미사용(구 지속형 잔재).
## 조작/AI 공통(is_controlled 무관 — DRIFT-076 스코프).
func overdrive_add(amount: float, gauge_max: float, _dur: float = 0.0) -> void:
	if _od_active or not _alive:
		return
	_od_gauge_max = gauge_max
	_od_gauge = minf(gauge_max, _od_gauge + amount)
	if _od_gauge >= gauge_max:
		_od_active = true
		_set_overdrive_glow(true)
		popup_status("초월!", Color(1.0, 0.85, 0.35))
	_update_overdrive_ui()


func overdrive_is_active() -> bool:
	return _od_active


func overdrive_gauge_frac() -> float:
	return clampf(_od_gauge / maxf(1.0, _od_gauge_max), 0.0, 1.0)


## 초월 소모/초기화 — 강화 서브 1회 시전(소모, ability_dispatch) 또는 비전투 5초(초기화, party_controller) 시
## 호출. 게이지·발동을 모두 클리어. 이미 비어 있으면 no-op.
func overdrive_reset() -> void:
	if not _od_active and _od_gauge <= 0.0:
		return
	_od_active = false
	_od_gauge = 0.0
	_set_overdrive_glow(false)
	_update_overdrive_ui()


func _set_overdrive_glow(on: bool) -> void:
	if on:
		_badge_strip().set_badge("overdrive", "초월", true)   # 금색 강조 뱃지
	elif _badges != null:
		_badges.clear_badge("overdrive")


func _update_overdrive_ui() -> void:
	if _hp_bar != null and _hp_bar.has_method("set_overdrive"):
		_hp_bar.set_overdrive(overdrive_gauge_frac(), _od_active)


# ---- DPS arc_weave 「혈풍(Blood Gale)」 (BIND-022~024) — 서브 시전 HP 대가 + 명중 적 수 비례 회복 ----
## 소모(자살 불가 — floor 클램프) + 회복(명중 적 비례). `overheal_shield_dur`>0(혈빙)이면 max_hp 초과 회복분을
## 임시 보호막으로 전환. 붉은 −N / 초록 +N(막) 팝업. ability_dispatch가 kind별 정산으로 호출.
func blood_soak(cost: float, refund: float, floor_hp: float, overheal_shield_dur: float = 0.0) -> void:
	if not _alive:
		return
	if cost > 0.0:
		hp = maxf(floor_hp, hp - cost)
		popup_status("-%d" % int(round(cost)), Color(0.95, 0.35, 0.3))
	if refund > 0.0:
		var healed: float = minf(max_hp - hp, refund)
		hp += healed
		var overflow: float = refund - healed
		if overflow > 0.5 and overheal_shield_dur > 0.0:
			add_shield(overflow, overheal_shield_dur)            # 혈빙 — 과회복분 임시 보호막
			popup_status("+%d(막)" % int(round(refund)), Color(0.6, 0.85, 1.0))
		else:
			popup_status("+%d" % int(round(maxf(healed, 0.0))), Color(0.4, 0.95, 0.55))
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)


# ---- Mend Circle 「성역」 (BIND-016~018) — identity가 좁은 고정 zone을 세움, 그 안에서 시전 시 치유 증폭 ----

## identity가 `pos`에 성역을 세운다(반경 radius, dur초). 지면 링을 top_level로 그 위치에 고정.
func binding_sanctuary(pos: Vector3, radius: float, dur: float) -> void:
	_sanctuary_pos = pos
	_sanctuary_radius = radius
	_sanctuary_timer_s = dur
	if _sanctuary_ring == null:
		_sanctuary_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.16
		torus.outer_radius = radius
		torus.rings = 96          # 원 매끄럽게
		torus.ring_segments = 8   # 얇은 단면
		_sanctuary_ring.mesh = torus   # TorusMesh는 XZ 평면에 이미 눕혀 있음 — 회전 불요(mia 링과 동일)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.55, 0.7)   # 성역=금빛 홀리(독 zone 초록과 확실히 구분)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.82, 0.35)
		mat.emission_energy_multiplier = 1.8
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.render_priority = 2
		_sanctuary_ring.material_override = mat
		_sanctuary_ring.top_level = true                # 시전자 이동과 무관하게 월드 고정
		add_child(_sanctuary_ring)
	_sanctuary_ring.global_position = Vector3(pos.x, pos.y + 0.06, pos.z)
	_sanctuary_ring.visible = true


## 시전자가 지금 성역 안에 서 있는가 — 치유 choke의 in-zone 증폭 게이트.
func in_sanctuary() -> bool:
	if _sanctuary_timer_s <= 0.0:
		return false
	var d := global_position - _sanctuary_pos
	d.y = 0.0
	return d.length() <= _sanctuary_radius


## 성역이 유지 중인가(위치 무관) — identity 재설치 스티키 판정용.
func has_sanctuary() -> bool:
	return _sanctuary_timer_s > 0.0


func binding_sanctuary_clear() -> void:
	_sanctuary_timer_s = 0.0
	if _sanctuary_ring != null:
		_sanctuary_ring.visible = false


## 처치 훅(enemy_unit.take_damage 사망 시 가해자에게 호출) — 「잠행」(Flank Collapse) 정체성이면 짧은 은신(veil):
## apply_veil = 적 표적 드롭(어그로 감소) + 몸체 디밍. 어떤 처치든(정체성/서브/평타) 발동 → 암살 후 이탈 판타지.
func notify_kill(_enemy) -> void:
	if BindingOverlays.identity_flanks(String(base_gear_id), String(ability_id)):
		apply_veil(float(BindingOverlays.FLANK["veil_s"]))


## DEBUG (combat sandbox): full reset to re-run an experiment — alive, full HP, all statuses +
## cooldowns cleared, sub charges refilled, downed members revived.
func debug_reset() -> void:
	_alive = true
	basic_enabled = true
	identity_enabled = true
	if not is_in_group("party_member"):
		add_to_group("party_member")
	hp = max_hp
	shield = 0.0
	shield_timer_s = 0.0
	stun_timer_s = 0.0
	poison_timer_s = 0.0
	poison_dps = 0.0
	_poison_accum = 0.0
	_regen_hots.clear()               # HoT 인스턴스 정리(리셋 시 잔여 회복/예측 제거)
	_regen_accum = 0.0
	_regen_tick_heal = 0.0
	_regen_pop_t = 0.0
	if _hp_bar and _hp_bar.has_method("set_projected"):
		_hp_bar.set_projected(0.0)
	_slow_timer = 0.0
	_slow_factor = 1.0
	_outcome.clear()
	provoked_timer_s = 0.0
	provoke_source = null
	identity_cooldown_s = 0.0
	sub_cooldown_s = 0.0
	attack_cooldown_s = 0.0
	binding_reset()   # P4a Kit Binding transient state (스택/ICD/만료타이머/표식)
	for s in skillbook_slots:
		if s != null:
			s.charges = int(s.charges_max)
			s.cooldown_s = 0.0
	if _body_material:
		_body_material.albedo_color = _base_color
	if _hp_bar:
		_hp_bar.set_ratio(1.0)
		_hp_bar.set_shield_ratio(0.0)
	_update_status_orb()
	_apply_controlled_visual(_controlled)


## DEBUG (combat sandbox): re-point the Identity skill to another identity's ability WITHOUT
## changing class/stats/gear, so formation/slots stay stable — ability-behavior testing only.
func debug_set_identity(identity_skill_id_new: String) -> void:
	if identity_skill_id_new == "":
		# Sandbox "(none)" — strip the Identity skill so this member basic-attacks only
		# (try_identity finds no kind → false → basic fallback). Per-member; re-equip a gear
		# or pick an identity to restore. (HUD shows the slot as 미장착.)
		identity_skill_id = ""
		ability_id = ""
		identity_params = {}
		identity_cooldown_s = 0.0
		return
	var row: Dictionary = Slice01Data.get_identity_row(identity_skill_id_new)
	if row.is_empty():
		return
	identity_skill_id = identity_skill_id_new
	ability_id = String(row.get("ability_id", ""))
	identity_params = Slice01Data.get_ability(ability_id)
	identity_cooldown_s = 0.0


## DEBUG (combat sandbox): set ONLY the basic-attack half from a gear (damage/CD/range + ba profile
## for the VFX archetype), leaving the Identity skill untouched — verify 평타 independent of identity.
## Mirrors _bind_gear's basic resolution (gear-first, identity combat fallback). Enables basic.
func debug_set_basic_from_gear(gear: Dictionary) -> void:
	var combat: Dictionary = Slice01Data.get_identity_row(String(gear.get("bundled_identity_skill_id", ""))).get("combat", {})
	basic_damage = float(gear.get("basic_damage", combat.get("basic_damage", 8.0)))
	basic_range_m = float(gear.get("basic_range_m", combat.get("basic_range_m", 2.0)))
	basic_interval_s = float(gear.get("basic_interval_s", combat.get("basic_interval_s", 1.0)))
	basic_attack_profile_id = String(gear.get("basic_attack_profile_id", ""))
	_apply_basic_behavior()
	basic_enabled = true


## ba 아키타입(basic_attack_profile_id) → 평타 특수거동(cleave/knockback) 적재. bind마다 fresh.
func _apply_basic_behavior() -> void:
	var b: Dictionary = BASIC_BEHAVIOR.get(basic_attack_profile_id, {})
	basic_cleave_m = float(b.get("cleave_m", 0.0))
	basic_knockback_m = float(b.get("kb_m", 0.0))
	basic_pierce_m = float(b.get("pierce_m", 0.0))


func set_controlled(active: bool) -> void:
	if _controlled == active:
		return
	_controlled = active
	if active:
		add_to_group("player")
		became_controlled.emit()
	else:
		remove_from_group("player")
		became_non_controlled.emit()
	_apply_controlled_visual(active)


func is_controlled() -> bool:
	return _controlled


func set_party_member_collision(enabled: bool) -> void:
	collision_mask = MASK_PARTY if enabled else MASK_WORLD_ONLY


func nav_set_target(target: Vector3) -> void:
	# Only recompute path when target moved significantly
	if _nav_target.distance_squared_to(target) < 0.25:
		return
	_nav_target = target
	var map_rid: RID = NavigationServer3D.get_maps()[0] if NavigationServer3D.get_maps().size() > 0 else RID()
	if not map_rid.is_valid():
		_nav_path = PackedVector3Array()
		return
	# Project positions to y=0 (navmesh plane) for reliable queries
	var from := Vector3(global_position.x, 0, global_position.z)
	var to := Vector3(target.x, 0, target.z)
	_nav_path = NavigationServer3D.map_get_path(map_rid, from, to, true)
	_nav_path_idx = 1  # skip path[0] which is the start position


func nav_get_next_position() -> Vector3:
	if _nav_path.size() == 0:
		return global_position
	# Advance past reached waypoints
	var pos_flat := Vector3(global_position.x, 0, global_position.z)
	while _nav_path_idx < _nav_path.size():
		var wp: Vector3 = _nav_path[_nav_path_idx]
		if pos_flat.distance_to(wp) > 0.5:
			# Return this waypoint at character's Y level
			return Vector3(wp.x, global_position.y, wp.z)
		_nav_path_idx += 1
	# Reached end of path
	return global_position


func nav_has_path() -> bool:
	return _nav_path.size() > 1 and _nav_path_idx < _nav_path.size()


func _apply_collision_size(radius: float, height: float) -> void:
	var col_shape := $CollisionShape3D.shape as CapsuleShape3D
	if col_shape == null:
		return
	col_shape.radius = radius if radius > 0.0 else DEFAULT_COLLISION_RADIUS
	col_shape.height = height if height > 0.0 else DEFAULT_COLLISION_HEIGHT
	# Feet-on-origin: align capsule bottom with the mesh (which is offset up),
	# so the body rests on the floor when its origin is at ground level.
	$CollisionShape3D.position.y = col_shape.height * 0.5


func _build_cylinder_mesh(color: Color, role_scale: float) -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35 * role_scale
	cyl.bottom_radius = 0.40 * role_scale
	cyl.height = 1.4 * role_scale
	mesh_node.mesh = cyl
	mesh_node.position.y = cyl.height * 0.5
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = color
	_body_material.roughness = 0.4
	mesh_node.material_override = _body_material


func _apply_controlled_visual(active: bool) -> void:
	if _body_material:
		_body_material.emission_enabled = active
		_body_material.emission = _base_color * CONTROLLED_EMISSION if active else Color.BLACK
	var s := _role_scale * CONTROLLED_SCALE if active else _role_scale
	scale = Vector3(s, s, s)


func take_damage(amount: float, attacker: Node = null) -> void:
	if not _alive:
		return
	# F-008 Sentinel Form (IDA-052) — reflect a fraction of the incoming hit back to the attacker
	# (melee 근사: any direct attacker-sourced hit while the stance holds; pre-mitigation amount).
	if _sentinel_reflect > 0.0 and _sentinel_timer_s > 0.0 and attacker != null \
			and is_instance_valid(attacker) and attacker.has_method("take_damage"):
		attacker.take_damage(amount * _sentinel_reflect)
	amount *= damage_taken_mult   # F-008 Sentinel Form stance DR (IDA-052; 1.0 = none)
	# 수호-흡수 보호막: 일반 보호막보다 먼저 흡수하고 흡수량을 기록(종료 시 그만큼 치유).
	if _ward_hp > 0.0 and _ward_timer_s > 0.0 and amount > 0.0:
		var wa: float = minf(_ward_hp, amount)
		_ward_hp -= wa
		_ward_absorbed += wa
		amount -= wa
	# Shield absorbs first (IDA-020).
	if shield > 0.0:
		var absorbed: float = minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if shield <= 0.0:
			shield_timer_s = 0.0
	_flash()
	if amount <= 0.0:
		return  # fully absorbed
	hp = maxf(0.0, hp - amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	if hp <= 0.0:
		_go_down()


## Returns the effective heal applied (excludes overheal — F-022 §3.9).
func heal(amount: float) -> float:
	if not _alive or hp >= max_hp:
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	_heal_flash()
	return hp - before


## IDA-020 Shield Policy: keep the higher value; refresh duration only when new >= old.
## Floating combat text — 이 멤버 위에 버프/디버프 이름을 잠깐 띄우고 위로 페이드아웃(MMO식). ref: float_text.gd.
## preload로 참조(global class-cache 미갱신 시 "not declared" 회피).
const _FloatText := preload("res://scripts/ui/float_text.gd")
func popup_status(txt: String, color: Color) -> void:
	_FloatText.popup(self, txt, color, 2.6)


## 성역 증폭 회복 표기 — 기본 회복(초록)과 성역으로 인한 추가분(금빛)을 위아래로 분리해 띄운다(직관적 파악).
func popup_heal_split(base: float, bonus: float) -> void:
	_FloatText.popup(self, "+%d" % int(round(base)), Color(0.45, 1.0, 0.5), 2.4)
	if bonus >= 1.0:
		_FloatText.popup(self, "+%d" % int(round(bonus)), Color(1.0, 0.85, 0.4), 3.35)


func add_shield(value: float, duration: float) -> void:
	if value >= shield:
		popup_status("보호막", Color(0.4, 0.9, 1.0))
		shield = value
		shield_timer_s = duration
		_shield_dur = duration


## 수호-흡수 힐 — `amount` 보호막을 `dur`초. 흡수 카운터 리셋. 종료 시 ward_heal 노드가 흡수분을 치유로 정산.
func apply_ward_shield(amount: float, dur: float) -> void:
	if not _alive:
		return
	popup_status("수호", Color(0.55, 0.85, 1.0))
	_ward_hp = maxf(_ward_hp, amount)
	_ward_timer_s = maxf(_ward_timer_s, dur)
	_ward_absorbed = 0.0


## 수호가 아직 유지 중인가(종료 감지용 — ward_heal 노드가 폴링).
func ward_active() -> bool:
	return _ward_timer_s > 0.0


## 수호 종료 정산 — 흡수 누적을 반환하고 수호 상태를 완전히 비운다(1회).
func ward_take_absorbed() -> float:
	var a := _ward_absorbed
	_ward_hp = 0.0
	_ward_timer_s = 0.0
	_ward_absorbed = 0.0
	return a


## F-008 Sentinel Form (IDA-052) — enter the turtle stance: reduce incoming damage by `dr` (0..1)
## and move-lock for `dur` seconds. Reflects `reflect` of each incoming hit back at the attacker.
func enter_sentinel(dr: float, dur: float, reflect: float = 0.0) -> void:
	popup_status("태세", Color(0.7, 0.82, 1.0))
	damage_taken_mult = clampf(1.0 - dr, 0.0, 1.0)
	_sentinel_timer_s = dur
	_sentinel_reflect = clampf(reflect, 0.0, 1.0)   # IDA-052 reflect (40% draft)
	_outcome.apply("Rooted", dur)   # move-lock (MOVE_MULT 0.0) — self-root, 팝업은 "태세"로 대체


## F-009 temporary damage reduction (Shield Wall AB-046 / Aegis Pulse AB-047 subs) — DR WITHOUT the
## Sentinel move-lock. Shares the Sentinel decay (_sentinel_timer → damage_taken_mult resets to 1.0).
## Strongest DR wins while active (minf). ref: STATUS Fortified/Warded.
func apply_damage_reduction(dr: float, dur: float) -> void:
	if not _alive:
		return
	popup_status("피해 감소", Color(0.6, 0.8, 1.0))
	damage_taken_mult = minf(damage_taken_mult, clampf(1.0 - dr, 0.0, 1.0))
	_sentinel_timer_s = maxf(_sentinel_timer_s, dur)


## F-009 heal-over-time — `pct_per_s` × maxHP/초를 `dur`초간. **중첩**: 매 적용이 독립 인스턴스로 쌓여 합산된다.
## `bonus_per_s` = 성역 등으로 인한 추가분(틱마다 금색으로 base와 분리 표기).
func apply_regen(pct_per_s: float, dur: float, bonus_per_s: float = 0.0) -> void:
	if not _alive or (pct_per_s + bonus_per_s) <= 0.0 or dur <= 0.0:
		return
	if _regen_hots.is_empty():
		popup_status("재생", Color(0.5, 1.0, 0.5))
	_regen_hots.append({"pct": pct_per_s, "bonus": bonus_per_s, "t": dur})


## 활성 HoT들이 앞으로 채울 예상 회복량(HP) — HP바/캐릭터 시트 예측 세그먼트용(2안). base+bonus 합산.
func hot_pending_hp() -> float:
	var pending := 0.0
	for h in _regen_hots:
		pending += (float(h["pct"]) + float(h.get("bonus", 0.0))) * max_hp * maxf(float(h["t"]), 0.0)
	return pending


## HoT 틱 flush — 누적된 기본분(초록)과 성역 추가분(금색)을 위아래로 분리 팝업하고 리셋.
func _flush_regen_tick() -> void:
	if _regen_tick_heal >= 1.0:
		_FloatText.popup(self, "+%d" % int(round(_regen_tick_heal)), Color(0.45, 1.0, 0.5), 2.4)
	if _regen_tick_bonus >= 1.0:
		_FloatText.popup(self, "+%d" % int(round(_regen_tick_bonus)), Color(1.0, 0.85, 0.4), 3.35)
	_regen_tick_heal = 0.0
	_regen_tick_bonus = 0.0
	_regen_pop_t = 0.0


## F-009 Haste (Swift Grace AB-069) — move + attack speed × (1+pct) for `dur`. Strongest wins.
func apply_haste(pct: float, dur: float) -> void:
	if not _alive:
		return
	if _haste_timer_s <= 0.0:
		popup_status("가속", Color(0.9, 1.0, 0.4))
	_haste_mult = maxf(_haste_mult, 1.0 + pct)
	_haste_timer_s = maxf(_haste_timer_s, dur)


## Effective basic-attack interval (Haste shortens it). combat_controller reads this, not basic_interval_s.
func attack_interval() -> float:
	return basic_interval_s / _haste_mult if _haste_mult > 0.0 else basic_interval_s


## F-009 Veiled (Smoke Veil AB-062) — brief stealth escape. While veiled, enemy targeting drops
## this member (enemy_ai._is_hostile returns false), so threat acquisition lets go for the window.
## Movement + the member's own attacks are unaffected. Dims the body for a self-readable cue.
const _VEIL_COLOR := Color(0.55, 0.6, 0.72, 0.28)   # 은신 반투명 톤(냉회색 + 저알파) — 유령처럼
func apply_veil(dur: float) -> void:
	if not _alive:
		return
	popup_status("은신", Color(0.72, 0.72, 0.78))   # 매 발동(처치)마다 floating — 연속 처치도 재-announce
	_badge_strip().set_badge("veil", "👻 은신")     # 지속 배지 — 반투명 누커를 따라다니며 「이 유닛이 은신 중」 명시
	_veil_timer_s = maxf(_veil_timer_s, dur)
	_veil_dur = maxf(_veil_dur, _veil_timer_s)
	if _body_material:
		_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_body_material.albedo_color = _VEIL_COLOR      # 반투명 + 냉회색 톤 → 은신 느낌
		_body_material.emission_enabled = false        # 발광 끄기(조작 발광이 반투명을 덮지 않게)
	_update_status_orb()


func is_veiled() -> bool:
	return _alive and _veil_timer_s > 0.0


## F-009 Shadowstep (AB-061) — boost this member's NEXT damaging hit; consumed once on damage.
func grant_next_hit_bonus(b: float) -> void:
	_next_hit_bonus = maxf(_next_hit_bonus, b)


## Read + clear the next-hit damage bonus (combat_controller._deal_damage calls this per hit). 0 if none.
func consume_next_hit_bonus() -> float:
	var b := _next_hit_bonus
	_next_hit_bonus = 0.0
	return b


## F-009 Channeling (AB-054 Rending Beam) — mark the caster occupied for `dur` (blocks other sub casts).
func begin_channel(dur: float) -> void:
	_channel_timer_s = maxf(_channel_timer_s, dur)


func is_channeling() -> bool:
	return _alive and _channel_timer_s > 0.0


## 채널 종료/취소 — 점유 즉시 해제(완료·취소 공통). ref: channel_heal.
func end_channel() -> void:
	_channel_timer_s = 0.0


## AB-054 채널 노드 등록(시전 시). 이전 채널이 남아 있으면 먼저 중단.
func set_active_channel(n: Node) -> void:
	interrupt_active_channel()
	_active_channel = n


## 진행 중인 AB-054 채널을 즉시 중단(이동·새 스킬 시전이 트리거). 노드가 스스로 정리한다.
func interrupt_active_channel() -> void:
	var c := _active_channel
	_active_channel = null
	if c != null and is_instance_valid(c) and c.has_method("cancel_channel"):
		c.cancel_channel()


## 채널 노드가 자연 종료 시 호출 — 아직 자기 자신일 때만 참조 해제(더 새 채널을 덮어쓰지 않게).
func clear_active_channel(n: Node) -> void:
	if _active_channel == n:
		_active_channel = null


## F-009/F-008 Ward Pulse (IDA-031) — cleanse one debuff. Returns the removed outcome id ("" if none).
func cleanse_one() -> String:
	return _outcome.cleanse_one() if _outcome != null else ""


func is_alive() -> bool:
	return _alive


func is_mia() -> bool:
	return _mia


func is_warn() -> bool:
	return _warn


## Separation warning (anchor leash, before MIA) — party_sheet tints the portrait.
func set_warn(on: bool) -> void:
	_warn = on


## Missing-In-Action — cut off from the party by a hazard (driven by party_controller).
## Shows a world marker; swap is blocked while MIA (F-001 §3.6). Clears on rejoin.
func set_mia(on: bool) -> void:
	if _mia == on:
		return
	_mia = on
	if on and _mia_marker == null:
		_mia_marker = Label3D.new()
		_mia_marker.text = "⚠ MIA"
		_mia_marker.font_size = 44
		_mia_marker.fixed_size = true
		_mia_marker.pixel_size = 0.0005
		_mia_marker.modulate = Color(1.0, 0.5, 0.15)
		_mia_marker.position = Vector3(0, 2.7, 0)
		_mia_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mia_marker.no_depth_test = true
		add_child(_mia_marker)
	if _mia_marker != null:
		_mia_marker.visible = on


## Revive a downed member (revival consumable). Restores alive state + HP; re-adds to
## the party_member group and un-dims the body. No-op (false) if already alive.
func revive(hp_fraction: float = 0.5) -> bool:
	if _alive:
		return false
	_alive = true
	hp = clampf(max_hp * hp_fraction, 1.0, max_hp)
	if not is_in_group("party_member"):
		add_to_group("party_member")
	if _body_material:
		_body_material.albedo_color = _base_color
		_body_material.emission_enabled = true
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	_apply_controlled_visual(_controlled)
	return true


## Party slot color (for aggro markers etc.).
func get_class_color() -> Color:
	return _base_color


## Instant knockback away from a source (collision-stopped). KB-LIGHT etc.
func apply_knockback(dir: Vector3, dist: float) -> void:
	if not _alive or dist <= 0.0:
		return
	var d := dir
	d.y = 0.0
	if d.length() < 0.01:
		return
	move_and_collide(d.normalized() * dist)


func _physics_process(delta: float) -> void:
	if sub_cooldown_s > 0.0:
		sub_cooldown_s -= delta
	for s in skillbook_slots:
		if s != null and float(s.cooldown_s) > 0.0:
			s.cooldown_s = float(s.cooldown_s) - delta
	_tick_binding(delta)   # P4a Kit Binding — bulwark ICD + BIND-006 recycle window
	if shield_timer_s > 0.0:
		shield_timer_s -= delta
		if shield_timer_s <= 0.0:
			shield = 0.0
	if _ward_timer_s > 0.0:            # 수호-흡수: 유지 시간 감소(종료 시 ward_heal 노드가 흡수분 치유 정산)
		_ward_timer_s -= delta
	if _sentinel_timer_s > 0.0:
		_sentinel_timer_s -= delta
		if _sentinel_timer_s <= 0.0:
			damage_taken_mult = 1.0   # Sentinel Form expired → normal damage
			_sentinel_reflect = 0.0   # reflect ends with the stance
	if _channel_timer_s > 0.0:        # AB-054 Rending Beam channel — caster occupied while > 0
		_channel_timer_s -= delta
	if not _regen_hots.is_empty():     # F-009 HoT(중첩) — 활성 인스턴스 합산 회복 + 틱 피드백(base 초록/성역 금색) + 예측
		var base_rate := 0.0           # 기본분 pct/s 합
		var bonus_rate := 0.0          # 성역 등 추가분 pct/s 합
		var pending := 0.0             # 예측 잔여 회복(HP)
		for h in _regen_hots:
			h["t"] = float(h["t"]) - delta
			var pc := float(h["pct"])
			var bn := float(h.get("bonus", 0.0))
			base_rate += pc
			bonus_rate += bn
			pending += (pc + bn) * max_hp * maxf(float(h["t"]), 0.0)
		var j := _regen_hots.size() - 1
		while j >= 0:                  # 만료 인스턴스 제거
			if float(_regen_hots[j]["t"]) <= 0.0:
				_regen_hots.remove_at(j)
			j -= 1
		var total_rate := base_rate + bonus_rate
		_regen_accum += max_hp * total_rate * delta
		if _regen_accum >= 1.0:
			var rh := floorf(_regen_accum)
			_regen_accum -= rh
			var eff := heal(rh)                           # 실제 회복분(만렙이면 0)
			var bfrac: float = (bonus_rate / total_rate) if total_rate > 0.0 else 0.0
			_regen_tick_bonus += eff * bfrac              # 성역 추가분(금색)
			_regen_tick_heal += eff * (1.0 - bfrac)       # 기본분(초록)
		_regen_pop_t += delta
		if _regen_pop_t >= REGEN_TICK_S:                  # 틱마다 base 초록 + 성역 금색 분리 표기
			_flush_regen_tick()
		if _hp_bar and _hp_bar.has_method("set_projected"):   # 2안: 회복 완료 도달치 예측(base+bonus 합)
			_hp_bar.set_projected((hp + pending) / max_hp)
		if _regen_hots.is_empty():                        # 전부 만료 → 정리
			_regen_accum = 0.0
			_flush_regen_tick()                           # 남은 틱 flush
			if _hp_bar and _hp_bar.has_method("set_projected"):
				_hp_bar.set_projected(0.0)                # 예측 세그먼트 제거
	if _haste_timer_s > 0.0:           # F-009 Haste expiry → speed back to normal
		_haste_timer_s -= delta
		if _haste_timer_s <= 0.0:
			_haste_mult = 1.0
	if _veil_timer_s > 0.0:            # F-009 Veiled (stealth) expiry → un-dim + retargetable
		_veil_timer_s -= delta
		if _veil_timer_s <= 0.0:
			if _body_material:
				_body_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				_body_material.albedo_color = _base_color
			if _badges != null:
				_badges.clear_badge("veil")
			_apply_controlled_visual(_controlled)   # 발광/스케일 원복(조작 중이면 재발광)
			_update_status_orb()
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0
	if _hexweak_timer_s > 0.0:         # AB-012 HEX-WEAK expiry → outgoing damage back to normal
		_hexweak_timer_s -= delta
		if _hexweak_timer_s <= 0.0:
			_hexweak_mult = 1.0
	if _hp_bar:
		_hp_bar.set_shield_ratio(shield / maxf(max_hp, 1.0))  # white overlay on the HP bar
	_tick_status(delta)
	var burn := _outcome.tick(delta)  # elemental outcome timers + Ignited DoT (bypasses shield)
	if burn > 0.0:
		_apply_dot(burn)
	var pt := _outcome.take_poison_tick()
	if pt > 0.0:
		_FloatText.popup(self, str(int(round(pt))), Color(0.72, 0.38, 0.95), 2.4, 0.9)   # 중독 DoT = 보라(우측 빗겨)


# --- Status (F-021) ---

func apply_stun(duration: float) -> void:
	if not _alive:
		return
	if stun_timer_s <= 0.0:
		popup_status("기절", Color(1.0, 0.9, 0.3))
	stun_timer_s = maxf(stun_timer_s, duration)
	_stun_dur = maxf(_stun_dur, stun_timer_s)
	_update_status_orb()


func apply_poison(duration: float, dps: float) -> void:
	if not _alive:
		return
	if poison_timer_s <= 0.0:
		popup_status("중독", Color(0.6, 0.9, 0.35))
	poison_timer_s = maxf(poison_timer_s, duration)
	_poison_dur = maxf(_poison_dur, poison_timer_s)
	poison_dps = maxf(poison_dps, dps)
	_update_status_orb()


## Movement slow (e.g. Oil slick) — multiplies move speed while active (피아무구분).
func apply_slow(factor: float, duration: float) -> void:
	if not _alive:
		return
	if _slow_timer <= 0.0:
		popup_status("둔화", Color(0.5, 0.75, 1.0))
	_slow_factor = factor
	_slow_timer = maxf(_slow_timer, duration)
	_slow_dur = maxf(_slow_dur, _slow_timer)


## HEX-WEAK (AB-012 Hex Bolt) — reduce this member's OUTGOING damage by `factor` (0..1) for `dur`s.
## Consumed in CombatController._deal_damage (the party→enemy damage choke). Strongest hex wins (minf).
func apply_hex_weak(factor: float, duration: float) -> void:
	if not _alive:
		return
	if _hexweak_timer_s <= 0.0:
		popup_status("약화", Color(1.0, 0.5, 0.5))
	_hexweak_mult = minf(_hexweak_mult, clampf(1.0 - factor, 0.0, 1.0))
	_hexweak_timer_s = maxf(_hexweak_timer_s, duration)
	_hexweak_dur = maxf(_hexweak_dur, _hexweak_timer_s)


## Current outgoing-damage multiplier from HEX-WEAK (1.0 when not hexed / expired).
func hex_weak_mult() -> float:
	return _hexweak_mult if _hexweak_timer_s > 0.0 else 1.0


## Provoke (AB-099): force this member to basic-attack `source`; movement/skills lock.
func apply_provoke(source: Node, duration: float) -> void:
	if not _alive:
		return
	if provoked_timer_s <= 0.0:
		popup_status("도발", Color(1.0, 0.6, 0.3))
	provoke_source = source
	provoked_timer_s = maxf(provoked_timer_s, duration)
	_provoke_dur = maxf(_provoke_dur, provoked_timer_s)
	_update_status_orb()


## Provoked AND able to act on it. False while stunned — Stunned suppresses Provoked's
## effects (forced attack/move/skill-lock) though the timer keeps running (AB-099 edge case).
func is_provoked() -> bool:
	return _alive and provoked_timer_s > 0.0 and stun_timer_s <= 0.0


## The taunt caster to force-attack — null (and unlinked) if it died / went away.
func get_provoke_source() -> Node:
	if provoke_source != null and (not is_instance_valid(provoke_source) \
			or (provoke_source.has_method("is_alive") and not provoke_source.is_alive())):
		provoke_source = null
	return provoke_source


## 전투 감속(전투 템포 A): 교전 중이면 ×2/3. party_controller가 engagement_changed로 combat_slowed 토글.
## controlled(player_controller)·follower(party_controller) 양쪽이 이 배수를 소비 → 한 곳에서 둘 다 커버.
const COMBAT_MOVE_MULT := 2.0 / 3.0
var combat_slowed: bool = false

func move_speed_mult() -> float:
	var m := _slow_factor if _slow_timer > 0.0 else 1.0
	m *= _outcome.move_mult() * _haste_mult  # slow × elemental outcomes × Haste (AB-069)
	if combat_slowed:
		m *= COMBAT_MOVE_MULT  # 비전투는 현행(스프린트), 전투 시 2/3
	return m


## Apply an elemental OUTCOME status (STATUS-OUTCOME-CORE). WindBuffeted's push is a separate
## knockback by the source; this carries the brief tag + the movement/DoT outcomes.
func apply_outcome(id: String, dur: float, mag: float = 0.0) -> void:
	if not _alive:
		return
	if not _outcome.has(id) and _FloatText.OUTCOME_KO.has(id):
		popup_status(_FloatText.OUTCOME_KO[id], Color(1.0, 0.7, 0.55))
	_outcome.apply(id, dur, mag)
	_update_status_orb()


## AB-010 스택형 독 DoT — 재적용마다 dps 누적(스택↑)·지속 갱신. 두 번 걸면 틱 배증. DoT는 _outcome tick이 굴린다.
func apply_poison_stack(dur: float, add_dps: float, cap_dps: float, unit_dps: float) -> void:
	if not _alive:
		return
	if not _outcome.has("Poison"):
		popup_status("중독", Color(0.5, 0.9, 0.4))
	_outcome.apply_stack("Poison", dur, add_dps, cap_dps, unit_dps)
	_update_status_orb()


## Public outcome query (Third-faction Scent/Root targeting reads this). ref: DEC-20260621-001.
func has_outcome(id: String) -> bool:
	return _outcome.has(id)


func is_slippery() -> bool:
	return _alive and _outcome.is_slippery()


## Active buffs/debuffs for the party-sheet overlay (UI-002/003).
## Each: {color, ratio=elapsed (0 fresh → 1 expiring), buff}. Colored arc = remaining.
func get_status_list() -> Array:
	var out: Array = []
	if shield > 0.0:  # buff
		out.append({
			"color": Color(0.36, 0.66, 1.0),
			"ratio": 1.0 - clampf(shield_timer_s / maxf(_shield_dur, 0.01), 0.0, 1.0),
			"buff": true,
		})
	if is_veiled():  # buff (Veiled — Smoke Veil AB-062 stealth)
		out.append({
			"color": Color(0.55, 0.62, 0.70),
			"ratio": 1.0 - clampf(_veil_timer_s / maxf(_veil_dur, 0.01), 0.0, 1.0),
			"buff": true,
		})
	if is_stunned():  # debuff
		out.append({
			"color": Color(1.0, 0.85, 0.2),
			"ratio": 1.0 - clampf(stun_timer_s / maxf(_stun_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	if poison_timer_s > 0.0:  # debuff (DoT — poison / fire / toxic gas)
		out.append({
			"color": Color(0.36, 0.9, 0.32),
			"ratio": 1.0 - clampf(poison_timer_s / maxf(_poison_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	if _slow_timer > 0.0:  # debuff (slow — Oil slick etc.)
		out.append({
			"color": Color(0.40, 0.78, 1.0),
			"ratio": 1.0 - clampf(_slow_timer / maxf(_slow_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	if _hexweak_timer_s > 0.0:  # debuff (Hex-Weak — reduced outgoing damage, AB-012)
		out.append({
			"color": Color(0.6, 0.35, 0.85),
			"ratio": 1.0 - clampf(_hexweak_timer_s / maxf(_hexweak_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	if provoked_timer_s > 0.0:  # debuff (Provoked — forced taunt, AB-099)
		out.append({
			"color": Color(0.95, 0.35, 0.2),
			"ratio": 1.0 - clampf(provoked_timer_s / maxf(_provoke_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	out.append_array(_outcome.status_list())  # elemental outcomes (Sodden/Chilled/Ignited/…)
	return out


func is_stunned() -> bool:
	return _alive and stun_timer_s > 0.0


func _tick_status(delta: float) -> void:
	var changed := false
	if stun_timer_s > 0.0:
		stun_timer_s -= delta
		if stun_timer_s <= 0.0:
			changed = true
	if poison_timer_s > 0.0:
		poison_timer_s -= delta
		_poison_accum += poison_dps * delta
		if _poison_accum >= 1.0:  # apply whole-HP DoT ticks (bypasses shield)
			var dmg := floorf(_poison_accum)
			_poison_accum -= dmg
			_apply_dot(dmg)
		if poison_timer_s <= 0.0:
			poison_dps = 0.0
			_poison_accum = 0.0
			changed = true
	if provoked_timer_s > 0.0:
		provoked_timer_s -= delta
		# End early if the caster died (tauntSourceId 무효화, AB-099 edge case).
		if provoked_timer_s <= 0.0 or get_provoke_source() == null:
			provoked_timer_s = 0.0
			provoke_source = null
			changed = true
	if changed:
		_update_status_orb()


func _apply_dot(amount: float) -> void:
	if not _alive or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	if hp <= 0.0:
		_go_down()


## Small overhead orb signalling active status (stun = yellow, poison = green).
func _update_status_orb() -> void:
	var active := is_stunned() or poison_timer_s > 0.0 or provoked_timer_s > 0.0 or _outcome.any()
	if not active:
		if _status_orb:
			_status_orb.visible = false
		return
	if _status_orb == null:
		_status_orb = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		_status_orb.mesh = s
		_status_orb.position = Vector3(0, 2.0, 0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		_status_orb.material_override = mat
		add_child(_status_orb)
	var col: Color = Color(0.35, 0.9, 0.3)  # poison (default)
	if is_stunned():
		col = Color(1.0, 0.85, 0.2)            # stun (yellow, highest display priority)
	elif provoked_timer_s > 0.0:
		col = Color(0.95, 0.35, 0.2)           # provoked (red-orange)
	elif poison_timer_s <= 0.0:
		var oc = _outcome.orb_color()           # elemental outcome (fire/shock/chill/…)
		if oc != null:
			col = oc
	(_status_orb.material_override as StandardMaterial3D).albedo_color = col
	_status_orb.visible = true


func _heal_flash() -> void:
	if _body_material == null:
		return
	if _flash_heal_tw and _flash_heal_tw.is_valid():
		_flash_heal_tw.kill()
	_body_material.albedo_color = Color(0.4, 1.0, 0.5)
	_flash_heal_tw = create_tween()
	_flash_heal_tw.tween_property(_body_material, "albedo_color", _VEIL_COLOR if is_veiled() else _base_color, 0.3)


## Floating HP bar (PH dev visibility — A4 replaces with real HUD).
func _build_hp_bar() -> void:
	_hp_bar = HealthBar.new()
	_hp_bar.position = Vector3(0, 1.4 * _role_scale + 0.7, 0)
	add_child(_hp_bar)
	_hp_bar.set_ratio(1.0)


func _flash() -> void:
	if _body_material == null or is_veiled():   # 은신 중엔 피격 플래시 없음(반투명 유지 · 어차피 표적에서 빠짐)
		return
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	_body_material.albedo_color = Color(1, 1, 1)
	_flash_tw = create_tween()
	_flash_tw.tween_property(_body_material, "albedo_color", _base_color, 0.18)


func _go_down() -> void:
	_alive = false
	set_mia(false)  # a downed member is not MIA
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	remove_from_group("party_member")
	if _body_material:
		_body_material.albedo_color = Color(0.30, 0.30, 0.30)
		_body_material.emission_enabled = false
	downed.emit(self)

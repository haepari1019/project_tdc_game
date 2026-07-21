extends CharacterBody3D
## ENC enemy placeholder — box + warm color (A3 replaces mesh).
## ref: WORK_ORDER §code PH · ENC-NORM-001 units.

signal died(unit: CharacterBody3D)

## 마지막 가해자가 파티였는지 — 킬 귀속(파티 킬만 전리품/재화). 3세력·몬스터 간 킬 = false. (S5b P3b)
var killed_by_party: bool = false

## Layer 3 = bit value 4. (Was 3 = bits 1|2, which put enemies on the WORLD bit —
## broke LOS raycasts and made steering wall-rays treat enemies as walls. Fixed 2026-06-08.)
const LAYER_ENEMY := 4
## Collide with world(1) + party(2) + enemy(4) = 1|2|4 = 7
const MASK_WORLD_PARTY_ENEMY := 7

## Base box footprint at scale 1.0 — collision matches the visual mesh exactly.
const BOX_BASE := Vector3(0.7, 1.4, 0.7)
const HealthBar := preload("res://scripts/combat/health_bar.gd")

var enemy_id: String = ""
var role: String = ""
var display_name: String = ""

var max_hp: float = 50.0
var hp: float = 50.0
var move_speed: float = 3.5
var contact_damage: float = 6.0
## Shared skillbook effects (sb_*) read the caster uniformly as `basic_damage` / `class_id`. Enemies
## expose these as read aliases so a UNIFIED ability (CastContext 파일럿) resolves identically for an
## enemy caster — one effect definition, two casting front-ends. ref: cast_context.gd · AB-003 파일럿.
var basic_damage: float:
	get:
		return contact_damage
var class_id: String:
	get:
		return enemy_id
var attack_range_m: float = 1.6
var attack_interval_s: float = 1.2
## Per-unit attack timer, ticked by CombatController.
var attack_cooldown_s: float = 0.0
## Ability instances [{ref}] from data — SIGNATURE AB-### refs. Each fires on its own AB cooldown_s
## (per-ability timer in ability_cd), NOT every-N-basics. Dispatch is by AB kind in EnemyAI.
var abilities: Array = []
## Basic-attack archetype id (rom_*, EN-COR-000) — resolved vs enemy_basics catalog.
var basic_attack: String = ""
## Engaged combat pattern (PT-###, EN-AI-000) + its resolved catalog row (patterns.json).
## engage_profile drives per-enemy positioning in EnemyAI (advance/standoff/kite/zone/orbit/probe/surround).
var pattern_ref: String = ""
var engage_profile: Dictionary = {}
## Probe (EN-006/PT-006) hit-and-back-off timer: set on each strike, retreats while > 0.
var probe_backstep_s: float = 0.0
## Per-ability cooldown timers {ref -> remaining_s} — ticked while engaged. Every signature AB
## (damage casts, heal, provoke, dash) fires on its own AB cooldown_s; independent timers so an
## enemy with multiple ABs (e.g. EN-001 AB-099+AB-002) doesn't share one clock.
var ability_cd: Dictionary = {}
## 전투 템포 B-1(DRIFT-083): 교전 직후 cap-eligible 캐스트 지연 창(초). 0=지연 없음.
var cast_stagger_s: float = 0.0
var stagger_armed: bool = false  # 교전 진입 1회 시딩 가드(재교전 시 재시딩)
## Dash state (AB-006 gap-close / AB-013 backstab) — a short velocity-takeover lunge after the
## telegraph, resolved (and AB-013's hit applied) by EnemyAI when dash_timer_s elapses.
var dashing: bool = false
var dash_vel: Vector3 = Vector3.ZERO
var dash_timer_s: float = 0.0
var dash_eff: Dictionary = {}
var dash_chosen: Dictionary = {}
var dash_target: CharacterBody3D = null
## AssassinTransform (ENC tag — NORM-003/HARD-011): disguised among fodder, stalks a backline
## target, then reveals with a telegraph and EXECUTES (high burst). Reverts to normal after.
## Set per-encounter at spawn (not a unit-catalog property). ref: ENC-NORM-003 / D-013 tags.
var assassin: bool = false
var assassin_telegraph_s: float = 0.6
var assassin_revealed: bool = false
## MiniBoss overlay (ENC-BOSS-001 per-ENC tag): cc_tenacity shortens incoming stun, a 50% HP
## phase shortens telegraphs. attentionTier=High via set_attention at spawn. ref: ENC-BOSS-001.
var miniboss: bool = false
var cc_tenacity: float = 1.0
var boss_phase2_hp_frac: float = 0.0     # 0 = no phase; e.g. 0.5 → phase at 50% HP
var boss_phase2_telegraph_delta: float = 0.0
var boss_phased: bool = false
var attack_count: int = 0
# Placement behavior (F-006, P2-S2-place; set per-encounter at spawn): Fixed = dormant roam,
# Patrol = walk a loop around spawn home, AmbushHold = hold hidden + spring on party proximity.
var placement_mode: String = "Fixed"
var ambush_reveal_radius_m: float = 8.0   # AmbushHold: spring when a party actor is within this
var patrol_idx: int = 0                   # current waypoint index on the patrol loop
var anchor_id: int = 0                    # AmbushHold dual-anchor: which hiding spot this unit holds
var wake_policy: String = "all"           # "all" = squad wakes together; "sequential" = per-anchor
# F-021 §3.1.2 object-priority: this enemy seeks + uses nearby enemy-usable objects. A held
# object runs its OWN combat behavior (e.g. torch → throw); held_object is set by the object.
var interacts_with_objects: bool = false
var interaction_policy: String = "priority"   # priority(torch·항상 최우선) / opportunistic(배럴·어쩌다)
var held_object: Node = null
var object_committed: Node = null             # opportunistic: 현재 부수러 가는 대상(진동 방지)
var object_interact_cd: float = 0.0           # opportunistic: 다음 기회까지 쿨(완주/롤실패 후)
var object_cast_s: float = 0.0                # opportunistic: 배럴 앞 부수기 캐스트(윈드업) 잔여(0=미시전)
# F-028 교전 진영 — 다른 진영끼리 적대(3세력 ↔ 일반 몬스터 ↔ 파티 실시간 교전). 기본 Dungeon.
# loot는 누가 죽이든 드롭(F-028 clearsRoomLoot:false — 3세력이 정리해도 플레이어 파밍 비차단).
var faction: String = "Dungeon"

## Squad (분대) = encounter group. Engagement is per-enemy but propagates only to
## squad-mates within cohesion range, so a strayed member fighting alone doesn't
## drag the distant squad into combat. ref: CombatController._engage_enemy.
var squad_id: int = -1
var engaged: bool = false       # this enemy is in active combat (vs dormant)
var engage_grace_s: float = 0.0 # D-010 §4.2 per-enemy disengage countdown

## Telegraph wind-up state machine (frame-driven; driven by CombatController). ref: DEBT-OTHER-AWAIT.
var winding: bool = false
var windup_timer_s: float = 0.0
var windup_eff: Dictionary = {}
var windup_chosen: Dictionary = {}
var windup_target: CharacterBody3D = null
var windup_pos: Vector3 = Vector3.ZERO   # ground-target capture (spawn_zone — telegraphed spot)
## PILOT — UNIFIED skillbook cast params stashed between wind-up start and resolve; non-empty → resolve
## through the SAME sb_* effect the ally uses (via CastContext), not _deliver_enemy_hit. ref: AB-003 파일럿.
var windup_unified: Dictionary = {}
## PILOT — 통합 캐스트 진행바(HP 바 위) + 총 캐스트시간(진행률 계산). 아군 CastBar 파리티. ref: enemy_ai.
var windup_bar: Node = null
var windup_total_s: float = 0.0

# --- Perception facing + vision cone (Phase C2: hybrid vision cone) ---
const SCAN_HALF_DEG := 35.0   # dormant idle scan sweep amplitude
const SCAN_PERIOD_S := 4.0     # full left-right sweep period
var facing: Vector3 = Vector3(0, 0, 1)         # horizontal look direction
var _base_facing: Vector3 = Vector3(0, 0, 1)   # scan pivots around this
var _scan_t: float = 0.0
var _scan_mult: float = 1.0   # per-enemy scan speed → desync the idle sweep so cones aren't in lockstep
# Dormant roaming (alive feel): wander near the spawn home. State driven by EnemyAI._tick_roam.
var home_pos: Vector3 = Vector3.INF   # captured on first dormant tick
var roaming: bool = false
var roam_target: Vector3 = Vector3.ZERO
var returning: bool = false   # B6: disengaged by leash/grace → walking back to home_pos
var roam_timer_s: float = 0.0
## Perception memory: where this enemy last perceived the party. While investigating
## it walks here even after losing sight, then gives up. (Distinct from last_seen_pos,
## which is where the PARTY last saw this enemy — fog-of-war rendering.)
var investigate_pos: Vector3 = Vector3.ZERO
var has_investigate: bool = false
## Search-on-hit: damaged from outside vision → engage + walk toward the hit's source
## direction (investigate even without LOS, then grace gives up). ref: F-011 / F-013.
const SEARCH_GRACE_S := 6.0
var search_pos: Vector3 = Vector3.ZERO
var has_search: bool = false

## Cached navmesh path (mirrors party_member) — lets enemies route AROUND walls when
## chasing/investigating instead of rubbing straight into them.
var _nav_path: PackedVector3Array = PackedVector3Array()
var _nav_path_idx: int = 0
var _nav_target: Vector3 = Vector3.ZERO
# Vision cone params (the cone is drawn by EnemyVisionOverlay as a unioned ground mask, not a
# per-enemy mesh — overlapping cone meshes z-fought / alpha-stacked). ref: vision cone union.
var _cone_active := false
var _cone_range := 0.0
var _cone_combat_r := 0.0
var _cone_fov_half := 0.0
var _alert_label: Label3D
var _alert_level: int = -1
var _stun_label: Label3D   # C3: overhead stun mark (DRIFT-044 잔여 — 적 stun 가독성)

var _body_material: StandardMaterial3D
var _base_albedo: Color = Color.WHITE
var _hp_bar: Node3D
var _flash_tw: Tween
var _box_size: Vector3 = BOX_BASE   # cached so apply_faction_shape() can swap box→cone post-spawn


func setup(row: Dictionary, color: Color, box_scale: float) -> void:
	# Desync the idle scan across enemies (random phase + slightly varied speed) so vision cones
	# don't all sweep in lockstep — looks alive, not synchronised.
	_scan_t = randf() * SCAN_PERIOD_S
	_scan_mult = randf_range(0.8, 1.2)
	roam_timer_s = randf_range(0.5, 4.0)   # stagger the first roam so enemies don't all set off at once
	enemy_id = String(row.get("enemy_id", ""))
	role = String(row.get("role", ""))
	display_name = String(row.get("display_name", ""))
	var stats: Dictionary = row.get("stats", {})
	max_hp = float(stats.get("hp", 50.0))
	hp = max_hp
	move_speed = float(stats.get("move_speed", 3.5))
	contact_damage = float(stats.get("contact_damage", 6.0))
	attack_range_m = float(stats.get("attack_range_m", 1.6))
	attack_interval_s = float(stats.get("attack_interval_s", 1.2))
	var ab = row.get("abilities", [])
	abilities = ab if typeof(ab) == TYPE_ARRAY else []
	basic_attack = String(row.get("basic_attack", ""))
	# Resolve the engaged positioning pattern (PT-###) once at spawn — EnemyAI reads engage_profile.
	pattern_ref = String(row.get("pattern_ref", ""))
	engage_profile = Slice01Data.get_pattern(pattern_ref) if pattern_ref != "" else {}
	# ENC-bound torch carry (EN-AI-000 §6 worldInteractProfile) is set at spawn, not from the
	# unit catalog (spec: not an enemyId property). Demo binding = ENC-PAT-003 (P2-S3) → false now.
	interacts_with_objects = bool(row.get("interacts_with_objects", false))
	name = enemy_id
	_base_albedo = color
	var box_size := BOX_BASE * box_scale
	_box_size = box_size
	_apply_collision_size(box_size)
	_build_box_mesh(color, box_size)
	_build_hp_bar(box_size)
	_build_alert_mark(box_size)
	collision_layer = LAYER_ENEMY
	collision_mask = MASK_WORLD_PARTY_ENEMY
	add_to_group("enemy")
	# §5.3 주의어그로 — elite/boss get HP-bar emphasis (attentionTier High).
	if role == "elite" or role == "boss":
		set_attention(true)


## attacker → 마지막 가해자 진영 기억(킬 귀속). 파티 킬만 전리품/재화(loot_service) — 3세력·몬스터 간
## 오프스크린 킬은 플레이어에게 드롭/재화 안 줌(S5b P3b). (enemies don't reflect.)
func take_damage(amount: float, attacker: Node = null) -> void:
	if hp <= 0.0:
		return
	if attacker != null and is_instance_valid(attacker):
		killed_by_party = attacker.is_in_group("party_member")
	amount *= 1.0 + _outcome.mag("Vulnerable")   # AB-057 Focus Fire — Vulnerable: 받는 피해 증폭
	if training_dummy:
		accumulated_damage += amount   # 허수아비: 누적딜만 집계, HP 미소모(불사)
		_flash()
		return
	hp = maxf(0.0, hp - amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	_flash()
	# MiniBoss phase trigger (ENC-BOSS-001): crossing the HP threshold shortens telegraphs.
	if miniboss and not boss_phased and boss_phase2_hp_frac > 0.0 and hp > 0.0 and hp <= max_hp * boss_phase2_hp_frac:
		boss_phased = true
		print("[EN] %s MiniBoss PHASE 2 (HP <= %d%%, telegraph %+.2fs)" % [enemy_id, int(boss_phase2_hp_frac * 100.0), boss_phase2_telegraph_delta])
	if hp <= 0.0:
		if attacker != null and is_instance_valid(attacker) and attacker.has_method("notify_kill"):
			attacker.notify_kill(self)   # 처치(막타) 훅 — 「잠행」(Flank) 정체성은 여기서 은신(veil) 발동
		died.emit(self)
		queue_free()


func is_alive() -> bool:
	return hp > 0.0


# ============================================================================
# Sandbox training dummy (허수아비) — 스킬샷 테스트 대상. combat_controller가 AI tick을 스킵해 정지·비공격.
# ============================================================================

## 이 적을 허수아비로 전환: 불사·정지·거대 HP, 옆에 누적딜/어그로 라벨 생성.
func mark_as_dummy() -> void:
	training_dummy = true
	engaged = true            # 아군이 교전 대상으로 삼도록
	move_speed = 0.0
	max_hp = 999999.0
	hp = max_hp
	if _hp_bar:
		_hp_bar.set_ratio(1.0)
	_build_dummy_labels()


func reset_accumulated_damage() -> void:
	accumulated_damage = 0.0


func reset_threat() -> void:
	threat.clear()
	floor_of.clear()
	last_gainer = null
	current_target = null
	imminent_target = null


func _build_dummy_labels() -> void:
	_dummy_dmg_label = Label3D.new()
	_dummy_dmg_label.font_size = 40
	_dummy_dmg_label.fixed_size = true       # 카메라 거리와 무관하게 화면상 일정 크기
	_dummy_dmg_label.pixel_size = 0.0005
	_dummy_dmg_label.position = Vector3(1.7, 2.5, 0)
	_dummy_dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dummy_dmg_label.no_depth_test = true
	_dummy_dmg_label.modulate = Color(1.0, 0.55, 0.45)
	add_child(_dummy_dmg_label)
	_dummy_threat_label = Label3D.new()
	_dummy_threat_label.font_size = 30
	_dummy_threat_label.fixed_size = true
	_dummy_threat_label.pixel_size = 0.0005
	_dummy_threat_label.position = Vector3(1.7, 1.85, 0)
	_dummy_threat_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dummy_threat_label.no_depth_test = true
	_dummy_threat_label.modulate = Color(1.0, 0.82, 0.4)
	add_child(_dummy_threat_label)


func _physics_process(delta: float) -> void:
	if _mark_timer_display > 0.0:              # Beacon 표식 표시 자기 만료
		_mark_timer_display -= delta
		if _mark_timer_display <= 0.0 and _badges != null:
			_badges.clear_badge("mark")
	if not training_dummy:
		return   # 일반 적은 이동을 EnemyAI가 구동 — 이하 허수아비 전용.
	# 허수아비는 AI tick을 스킵하므로 여기서 상태 타이머를 직접 감소 → 디버프가 만료되고 재적용/재팝업 가능.
	tick_stun(delta)
	tick_silence(delta)
	tick_slow(delta)
	tick_outcome(delta)
	if _dummy_dmg_label:
		_dummy_dmg_label.text = "누적딜 %d" % int(round(accumulated_damage))
	if _dummy_threat_label:
		_dummy_threat_label.text = _threat_readout()


## 여러 스택 상태를 한 줄로 모으는 배지 스트립(lazy). 표식/집중 등이 세로로 나열되지 않게 통합.
const _OverheadBadges := preload("res://scripts/ui/overhead_badges.gd")
func _badge_strip():
	if _badges == null:
		_badges = _OverheadBadges.new()
		_badges.position = Vector3(0, _box_size.y + 1.4, 0)
		add_child(_badges)
	return _badges


## 디버프 아이콘 로우(lazy) — 체력바 위, get_status_list 디버프를 코인 아이콘으로.
const _OverheadStatusIcons := preload("res://scripts/ui/overhead_status_icons.gd")
func _status_icon_strip():
	if _status_icons == null:
		_status_icons = _OverheadStatusIcons.new()
		_status_icons.position = Vector3(0, _box_size.y + 1.0, 0)
		add_child(_status_icons)
	return _status_icons


## Beacon 「표식」 시각 표시 — 결속 정체성이 표식을 걸/갱신할 때 호출. `dur`s 후 자동으로 사라짐.
func show_mark(dur: float) -> void:
	_badge_strip().set_badge("mark", "◈")
	_mark_timer_display = dur


func hide_mark() -> void:
	_mark_timer_display = 0.0
	if _badges != null:
		_badges.clear_badge("mark")


## Mark&Ruin 「집중」 시각 표시 — 집중을 새기거나 누적이 바뀔 때 호출. stacks=현재 누적, at_cap=만렙(캡 큐, 금색).
func show_focus(stacks: int, at_cap: bool = false) -> void:
	var txt := "🎯" if stacks <= 0 else ("🎯MAX" if at_cap else "🎯%d" % stacks)
	_badge_strip().set_badge("focus", txt, at_cap)


func hide_focus() -> void:
	if _badges != null:
		_badges.clear_badge("focus")


## 어그로 미터 — 파티원별 threat를 내림차순으로. floor(고정) 표기는 생략(현재 값만).
func _threat_readout() -> String:
	var rows: Array = []
	for m in threat.keys():
		if is_instance_valid(m):
			rows.append({"n": String(m.get("class_id")), "v": float(threat[m])})
	if rows.is_empty():
		return "어그로 —"
	rows.sort_custom(func(a, b): return a["v"] > b["v"])
	var parts: Array = []
	for r in rows:
		parts.append("%s %d" % [r["n"], int(round(r["v"]))])
	return "어그로 ▸ " + " / ".join(parts)


## Restore HP (AB-098 Mire Mend Pulse — EN-014 sustain heals its squad). Clamped to max,
## green flash for the Read. No-op on the dead.
func heal(amount: float) -> void:
	if hp <= 0.0 or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	if _hp_bar:
		_hp_bar.set_ratio(hp / max_hp)
	if _body_material:
		if _flash_tw and _flash_tw.is_valid():
			_flash_tw.kill()
		_body_material.albedo_color = Color(0.4, 1.0, 0.5)
		_flash_tw = create_tween()
		_flash_tw.tween_property(_body_material, "albedo_color", _base_albedo, 0.25)


# --- Perceived visibility (party-union LOS occlusion; driven by EnemyVisibility) ---
var _seen: bool = true
var _seen_tw: Tween
## Last position the party saw this enemy at — for a future last-seen marker. F-011 pre-step.
var last_seen_pos: Vector3 = Vector3.ZERO
const _SEEN_FADE_S := 0.18

## Fade in/out by whether any party member has LOS. Stores last-seen pos on hide.
func set_seen(seen: bool) -> void:
	if seen == _seen:
		return
	_seen = seen
	if not seen:
		last_seen_pos = global_position
	if _seen_tw and _seen_tw.is_valid():
		_seen_tw.kill()
	if _body_material == null:
		visible = seen
		return
	_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if seen:
		visible = true
	_seen_tw = create_tween()
	_seen_tw.tween_property(_body_material, "albedo_color:a", 1.0 if seen else 0.0, _SEEN_FADE_S)
	if not seen:
		_seen_tw.tween_callback(func() -> void: visible = false)


# --- Threat Table (F-022) — per-enemy threat per party member ---
var threat: Dictionary = {}
var current_target: CharacterBody3D = null
var imminent_target: CharacterBody3D = null  # §5.2 next-target (switch imminent)
var last_gainer: CharacterBody3D = null
var first_hit: bool = false  # §3.4 first-attack bonus applied?

# --- Sandbox training dummy (허수아비) — 스킬샷 테스트용. 불사·정지(combat_controller가 AI tick 스킵)
# ·가해 누적딜 집계. 옆에 누적딜/어그로 Label3D 표시. ---
var training_dummy: bool = false
var accumulated_damage: float = 0.0
var _dummy_dmg_label: Label3D
var _dummy_threat_label: Label3D
# Beacon 「표식」 시각 표시 — 결속 정체성이 표식을 걸면 이 적 위에 "◈ 표식"(자기 만료).
var _badges = null                 # OverheadBadges 스트립(lazy) — 표식/집중 등 스택 상태를 한 줄로 통합
var _status_icons = null           # OverheadStatusIcons 로우(lazy) — 디버프 아이콘(색+심볼+시계 타이머)
var _mark_timer_display: float = 0.0
var floor_of: Dictionary = {}  # member -> threat floor (§3.5)
const DEFAULT_FLOOR := 10.0
const IMMINENT_RATIO := 0.85  # §3.2 2nd >= 1st * this → imminent switch UI
## Proportional (exponential) decay: fraction of threat RETAINED per second.
## Lower = shorter memory → recent threat dominates, aggro bounces (harder).
const THREAT_RETAIN_PER_S := 0.6

# --- Status: slow (Nuker Nova sub) ---
var slow_timer_s: float = 0.0
var slow_factor: float = 1.0
var _slow_dur: float = 0.0     # 슬로우 총 지속(적 인스펙트 패널 arc용)
## Elemental OUTCOME statuses (STATUS-OUTCOME-CORE) — shared container with party_member. Ticked
## via tick_outcome() from EnemyAI; folds into current_move_speed; INERTIA(OilSlick·IceGlide) flags inertia in EnemyAI.
var _outcome = preload("res://scripts/combat/outcome_status.gd").new()

# --- Status: stun / interrupt (party Toll Stun etc.) — freezes the enemy AND cancels any
# in-progress cast/dash (EN-AI-000 §2 channel interrupt). Ticked by EnemyAI while engaged. ---
var stun_timer_s: float = 0.0
var _stun_dur: float = 0.0     # 기절 총 지속(인스펙트 패널 arc용)
# --- Status: silence (AB-044 Hush Ward) — blocks ACTIVE ability casts (signature/dash/provoke/
# frenzy). Movement + basic attacks stay allowed (AB-044 §2). ccTenacity shortens it. ---
var silence_timer_s: float = 0.0
var _silence_dur: float = 0.0  # 침묵 총 지속(인스펙트 패널 arc용)

# --- Status: knockback (smoothed push over KB_TIME, not an instant teleport) ---
const KB_TIME := 0.18
var kb_vel: Vector3 = Vector3.ZERO
var kb_timer: float = 0.0


## Floating combat text — 대상 위에 상태 이름을 잠깐 띄우고 위로 페이드아웃(MMO식). ref: float_text.gd.
## preload로 참조(global class-cache 미갱신 시 "not declared" 회피).
const _FloatText := preload("res://scripts/ui/float_text.gd")
func popup_status(txt: String, color: Color) -> void:
	_FloatText.popup(self, txt, color, _box_size.y + 1.6)


func apply_slow(factor: float, duration: float) -> void:
	if slow_timer_s <= 0.0:
		popup_status("둔화", Color(0.5, 0.75, 1.0))
	slow_factor = factor
	slow_timer_s = maxf(slow_timer_s, duration)
	_slow_dur = maxf(_slow_dur, slow_timer_s)


func tick_slow(delta: float) -> void:
	if slow_timer_s > 0.0:
		slow_timer_s -= delta
		if slow_timer_s <= 0.0:
			slow_factor = 1.0
			_slow_dur = 0.0


## Elemental outcome timers + Ignited DoT. Called each engaged tick by EnemyAI (like tick_slow).
func tick_outcome(delta: float) -> void:
	var burn := _outcome.tick(delta)
	if burn > 0.0:
		take_damage(burn)
	# DoT 피해 표기 — 종류 무관 동일 규격(카메라 기준 우측 빗겨 · 체력바/아이콘 안 가리게). 색만 종류별.
	for t in _outcome.take_dot_ticks():
		_FloatText.popup(self, str(int(round(float(t["dmg"])))),
				OutcomeStatus.dot_color(String(t["id"])), _box_size.y + 0.3, 0.9)
	_update_status_badges()   # 디버프 아이콘(체력바 위) 갱신 — 만료/DoT 반영


## Apply an elemental OUTCOME status (STATUS-OUTCOME-CORE). ref: zones / RX (P2-S3).
func apply_outcome(id: String, dur: float, mag: float = 0.0) -> void:
	if hp <= 0.0:
		return
	if not _outcome.has(id) and _FloatText.OUTCOME_KO.has(id):
		popup_status(_FloatText.OUTCOME_KO[id], Color(0.75, 0.9, 1.0))
	_outcome.apply(id, dur, mag)


## AB-010 스택형 독 DoT — 재적용마다 dps 누적(스택↑)·지속 갱신. 두 번 걸면 틱 배증. DoT는 tick_outcome이 굴린다.
func apply_poison_stack(dur: float, add_dps: float, cap_dps: float, unit_dps: float) -> void:
	if hp <= 0.0:
		return
	if not _outcome.has("Poison"):
		popup_status("중독", Color(0.5, 0.9, 0.4))
	_outcome.apply_stack("Poison", dur, add_dps, cap_dps, unit_dps)
	_update_status_badges()   # 즉시 갱신(중독 스택 배지)


## Public outcome query (Third-faction targeting reads Scented/Rooted/etc.). ref: DEC-20260621-001.
func has_outcome(id: String) -> bool:
	return _outcome.has(id)


## Purgeable enemy buffs (AB-070 Purge Light removes one). Bloodlust is the live enemy self-buff;
## the rest are forward-compat (spec AB-070 removes_status — no enemy carries them yet). ref: AB-070.
const PURGEABLE_BUFFS := ["Bloodlust", "Fortified", "Hasted", "Shielded", "Warded", "Regenerating"]

## Remove one active enemy buff (AB-070 Purge Light). Returns the removed id ("" if none).
func purge_one_buff() -> String:
	for id in PURGEABLE_BUFFS:
		if _outcome.has(id):
			_outcome.remove(id)
			return id
	return ""


# --- Bloodlust (AB-105 enemy_frenzy, EN-3RD-03 Reaver): self-rage at low HP — while the Bloodlust
# outcome is active, attack faster + hit harder (mults set when the frenzy cast resolves). ---
var bloodlust_spd_mult: float = 1.0
var bloodlust_dmg_mult: float = 1.0

func is_bloodlust() -> bool:
	return _outcome.has("Bloodlust")

## Missing-HP fraction (0 at full, 1 at death) — Bloodlust scales by this (AB-105 scaleByMissingHp).
func _missing_hp_frac() -> float:
	return clampf(1.0 - hp / maxf(max_hp, 1.0), 0.0, 1.0)

## Attack interval folding Bloodlust haste — scales with MISSING HP (DRIFT-055 resolve): the stored
## bloodlust_spd_mult is the MAX rage (at 0 HP); at the cast threshold it ramps from there by missing HP.
func attack_interval_now() -> float:
	if not is_bloodlust():
		return attack_interval_s
	var spd: float = 1.0 + (bloodlust_spd_mult - 1.0) * _missing_hp_frac()
	return attack_interval_s / maxf(spd, 0.01)

## Damage multiplier from Bloodlust (1.0 when not raging), scaled by missing HP. EnemyAI folds it in.
func contact_damage_mult() -> float:
	if not is_bloodlust():
		return 1.0
	return 1.0 + (bloodlust_dmg_mult - 1.0) * _missing_hp_frac()


func is_slippery() -> bool:
	return hp > 0.0 and _outcome.is_slippery()


## 관성 강도 배율(OilSlick 1.0 / IceGlide 0.7) — EnemyAI가 SLIP_ACCEL에 곱해 미끄럼 정도를 조절.
func inertia_scale() -> float:
	return _outcome.inertia_scale()


## Stun / interrupt (EN-AI-000 §2). Freezes the enemy; EnemyAI cancels any channel/dash in
## progress (cast fails — cooldown stays consumed). No-op on the dead.
func apply_stun(duration: float) -> void:
	if hp <= 0.0 or duration <= 0.0:
		return
	if stun_timer_s <= 0.0:
		popup_status("기절", Color(1.0, 0.9, 0.3))
	stun_timer_s = maxf(stun_timer_s, duration / maxf(cc_tenacity, 0.01))  # ccTenacity shortens CC
	_stun_dur = maxf(_stun_dur, stun_timer_s)
	if _stun_label:
		_stun_label.visible = true    # C3: overhead stun mark for the duration


func is_stunned() -> bool:
	return stun_timer_s > 0.0


func tick_stun(delta: float) -> void:
	if stun_timer_s > 0.0:
		stun_timer_s = maxf(0.0, stun_timer_s - delta)
		if stun_timer_s <= 0.0:
			_stun_dur = 0.0
			if _stun_label:
				_stun_label.visible = false


## Silence (AB-044 Hush Ward) — block active ability casts for `duration` (ccTenacity shortens).
## Pre-emptive: does NOT interrupt an in-progress cast (that's AB-030). No-op on the dead.
func apply_silence(duration: float) -> void:
	if hp <= 0.0 or duration <= 0.0:
		return
	if silence_timer_s <= 0.0:
		popup_status("침묵", Color(0.8, 0.5, 1.0))
	silence_timer_s = maxf(silence_timer_s, duration / maxf(cc_tenacity, 0.01))
	_silence_dur = maxf(_silence_dur, silence_timer_s)


func is_silenced() -> bool:
	return silence_timer_s > 0.0


func tick_silence(delta: float) -> void:
	if silence_timer_s > 0.0:
		silence_timer_s = maxf(0.0, silence_timer_s - delta)
		if silence_timer_s <= 0.0:
			_silence_dur = 0.0


## Active buffs/debuffs for the enemy inspect panel (enemy_info.gd) — same shape as
## party_member.get_status_list(): each {color, ratio (0 fresh → 1 expiring), buff}. Timer-based CC
## first (stun/slow/silence), then elemental outcomes (Chilled/Ignited/Bloodlust/Vulnerable/…).
func get_status_list() -> Array:
	var out: Array = []
	if stun_timer_s > 0.0:  # debuff (기절/인터럽트)
		out.append({
			"name": "기절",
			"color": Color(1.0, 0.85, 0.2),
			"ratio": 1.0 - clampf(stun_timer_s / maxf(_stun_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	if slow_timer_s > 0.0:  # debuff (둔화)
		out.append({
			"name": "둔화",
			"color": Color(0.40, 0.78, 1.0),
			"ratio": 1.0 - clampf(slow_timer_s / maxf(_slow_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	if silence_timer_s > 0.0:  # debuff (침묵 — 액티브 시전 봉쇄)
		out.append({
			"name": "침묵",
			"color": Color(0.8, 0.5, 1.0),
			"ratio": 1.0 - clampf(silence_timer_s / maxf(_silence_dur, 0.01), 0.0, 1.0),
			"buff": false,
		})
	out.append_array(_outcome.status_list())  # 원소 아웃컴(Sodden/Chilled/Ignited/Bloodlust/…)
	return out


## 디버프 아이콘 로우 갱신 — 활성 디버프(버프 제외)를 체력바 위 코인 아이콘으로(색+한글 심볼+시계 타이머).
## 독 등 스택형은 심볼에 스택 수가 붙는다(예 "독5"). status_list의 {name,color,ratio,stacks}를 그대로 전달.
func _update_status_badges() -> void:
	var list: Array = []
	for s in get_status_list():
		if not bool(s.get("buff", false)):
			list.append(s)   # 디버프만
	if list.is_empty():
		if _status_icons != null:
			_status_icons.sync([])
	else:
		_status_icon_strip().sync(list)


## 전투 감속(전투 템포 A / DRIFT-083): 교전 중이면 ×2/3. 비전투(roam/patrol)는 각 상태
## fraction만 적용되어 현행 유지. 아군도 대칭(party_member.move_speed_mult). 유닛별 변별·안티카이팅 비율 유지.
const COMBAT_MOVE_MULT := 2.0 / 3.0

func current_move_speed() -> float:
	var base := move_speed * slow_factor if slow_timer_s > 0.0 else move_speed
	var m := base * _outcome.move_mult()  # fold elemental movement outcomes (Sodden/Chilled/…)
	if engaged:
		m *= COMBAT_MOVE_MULT  # 교전 시 2/3
	return m


## Knockback away from a source — spread over KB_TIME so it reads as a push,
## not an instant teleport. Resolved by tick_knockback() each frame.
func apply_knockback(dir: Vector3, dist: float) -> void:
	var d := dir
	d.y = 0.0
	if dist <= 0.0 or d.length() < 0.01:
		return
	kb_vel = d.normalized() * (dist / KB_TIME)
	kb_timer = KB_TIME


## While knocked back, drive movement from kb_vel (collision-stopped). Returns
## true if a knockback is active this frame (caller should skip normal steering).
func tick_knockback(delta: float) -> bool:
	if kb_timer <= 0.0:
		return false
	kb_timer -= delta
	velocity = kb_vel  # constant push → exact knockback distance over KB_TIME
	move_and_slide()
	return true


## Show current target slot color on the HP bar + next-target (imminent) marker.
func set_target_marker(member: CharacterBody3D) -> void:
	if _hp_bar == null:
		return
	if member != null and member.has_method("get_class_color"):
		_hp_bar.set_target(member.get_class_color())
	else:
		_hp_bar.clear_target()
	# §5.2 imminent switch marker (pulsing, next target's color).
	if imminent_target != null and is_instance_valid(imminent_target) \
			and imminent_target.has_method("get_class_color"):
		_hp_bar.set_imminent(imminent_target.get_class_color())
	else:
		_hp_bar.clear_imminent()


## §5.3 주의어그로 — Elite/Boss HP bar emphasis.
func set_attention(high: bool) -> void:
	if _hp_bar and _hp_bar.has_method("set_attention"):
		_hp_bar.set_attention(high)


# ===== Perception facing + tells (Phase C2: hybrid vision cone) =====

## Base look direction (dormant scan pivots around this). Set at spawn toward the
## party's entry so enemies "watch the door".
func set_base_facing(dir: Vector3) -> void:
	var d := dir
	d.y = 0.0
	if d.length() < 0.01:
		return
	_base_facing = d.normalized()
	facing = _base_facing
	_orient_cone()


## Dormant idle: sweep facing left-right around the base so the cone moves and the
## player gets windows to slip past.
func scan(delta: float) -> void:
	_scan_t += delta * _scan_mult
	var ang := deg_to_rad(SCAN_HALF_DEG) * sin(_scan_t * TAU / SCAN_PERIOD_S)
	facing = _base_facing.rotated(Vector3.UP, ang)
	_orient_cone()


## Snap facing toward a world point (alert/engaged: look at the target/sighting).
func face_toward(pos: Vector3) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	facing = d.normalized()
	_orient_cone()


## Alert mark above head: 0 none, 1 '?' (경계), 2 '!' (전투).
func set_alert_mark(level: int) -> void:
	if level == _alert_level or _alert_label == null:
		return
	_alert_level = level
	if level <= 0:
		_alert_label.visible = false
		return
	_alert_label.visible = true
	if level == 1:
		_alert_label.text = "?"
		_alert_label.modulate = Color(1.0, 0.85, 0.2)
	else:
		_alert_label.text = "!"
		_alert_label.modulate = Color(1.0, 0.25, 0.2)


func _build_alert_mark(box_size: Vector3) -> void:
	_alert_label = Label3D.new()
	_alert_label.text = "?"
	_alert_label.font_size = 48
	_alert_label.fixed_size = true
	_alert_label.pixel_size = 0.0005
	_alert_label.position = Vector3(0, box_size.y + 1.15, 0)
	_alert_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_label.no_depth_test = true
	_alert_label.modulate = Color(1.0, 0.85, 0.2)
	_alert_label.visible = false
	add_child(_alert_label)
	_stun_label = Label3D.new()                # C3: shown while stunned (over the alert mark)
	_stun_label.text = "✦"
	_stun_label.font_size = 44
	_stun_label.fixed_size = true
	_stun_label.pixel_size = 0.0005
	_stun_label.position = Vector3(0, box_size.y + 1.9, 0)
	_stun_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stun_label.no_depth_test = true
	_stun_label.modulate = Color(1.0, 0.95, 0.35)
	_stun_label.visible = false
	add_child(_stun_label)


## Dev VFX: vision cone (player would unlock this with a consumable; forced on for now).
## No longer a per-enemy mesh — overlapping translucent cones z-fought / alpha-stacked. We just
## STORE the params here; EnemyVisionOverlay rasterises every enemy's sector into ONE top-down
## union mask and tints the ground once (combat=red, alert=yellow). ref: vision cone union.
func build_vision_cone(range_m: float, fov_deg: float, alert_frac: float) -> void:
	_cone_range = range_m
	_cone_combat_r = range_m * (1.0 - alert_frac)
	_cone_fov_half = deg_to_rad(fov_deg * 0.5)
	_cone_active = true


## Read by EnemyVisionOverlay each frame to build the union mask. `facing` → world-space angle.
func vision_cone_data() -> Dictionary:
	return {
		"active": _cone_active and is_alive(),
		"range": _cone_range,
		"combat_r": _cone_combat_r,
		"fov_half": _cone_fov_half,
		"facing": atan2(facing.x, facing.z),
	}


func _orient_cone() -> void:
	pass  # cone is drawn by EnemyVisionOverlay now (facing is read live); kept as a no-op


# ===== Navmesh path (route around walls; mirrors party_member) =====

func nav_set_target(target: Vector3) -> void:
	if _nav_target.distance_squared_to(target) < 0.25:
		return  # target hasn't moved enough to bother re-pathing
	_nav_target = target
	var maps := NavigationServer3D.get_maps()
	var map_rid: RID = maps[0] if maps.size() > 0 else RID()
	if not map_rid.is_valid():
		_nav_path = PackedVector3Array()
		return
	var from := Vector3(global_position.x, 0, global_position.z)
	var to := Vector3(target.x, 0, target.z)
	_nav_path = NavigationServer3D.map_get_path(map_rid, from, to, true)
	_nav_path_idx = 1  # skip path[0] (start position)


func nav_get_next_position() -> Vector3:
	if _nav_path.size() == 0:
		return global_position
	var pos_flat := Vector3(global_position.x, 0, global_position.z)
	while _nav_path_idx < _nav_path.size():
		var wp: Vector3 = _nav_path[_nav_path_idx]
		if pos_flat.distance_to(wp) > 0.5:
			return Vector3(wp.x, global_position.y, wp.z)
		_nav_path_idx += 1
	return global_position


func nav_has_path() -> bool:
	return _nav_path.size() > 1 and _nav_path_idx < _nav_path.size()


## Velocity toward `dest` along the navmesh (routes around walls). ZERO when arrived / no path.
## Used by EnemyAI and by held objects driving the carrier's approach (e.g. torch throw).
func nav_move_toward(dest: Vector3, speed: float) -> Vector3:
	nav_set_target(dest)
	var wp: Vector3 = nav_get_next_position()
	var to_wp := wp - global_position
	to_wp.y = 0.0
	var d := to_wp.length()
	if d < 0.05:
		return Vector3.ZERO
	return (to_wp / d) * speed


## AB-007 이탈 어그로 감소 — 이 유닛의 특정 멤버 위협을 배율 k로 스케일(없으면 no-op).
func scale_threat(member: CharacterBody3D, k: float) -> void:
	if threat.has(member):
		threat[member] = float(threat[member]) * k


func add_threat(member: CharacterBody3D, amount: float) -> void:
	if member == null or amount == 0.0:
		return
	threat[member] = float(threat.get(member, 0.0)) + amount
	if amount > 0.0:
		last_gainer = member


## Took damage from `attacker` (any source) — engage and remember its direction so this
## enemy walks over to search even with no LOS. The AI consumes search_pos when blind.
func perceive_attacker(attacker: Node) -> void:
	if attacker == null or not is_instance_valid(attacker) or not (attacker is Node3D):
		return
	engaged = true
	engage_grace_s = maxf(engage_grace_s, SEARCH_GRACE_S)
	search_pos = (attacker as Node3D).global_position
	has_search = true


## Raise this member's threat floor on this enemy (§3.5 — never lowers).
func set_threat_floor(member: CharacterBody3D, f: float) -> void:
	if member == null:
		return
	floor_of[member] = maxf(float(floor_of.get(member, DEFAULT_FLOOR)), f)


## Proportional decay toward each member's floor (§3.5, recency-weighted): old
## threat fades at a fixed % per second so the latest threat wins aggro.
func decay_threat(delta: float) -> void:
	var k := pow(THREAT_RETAIN_PER_S, delta)
	for m in threat.keys():
		if not is_instance_valid(m):
			threat.erase(m)
			continue
		threat[m] = maxf(float(threat[m]) * k, float(floor_of.get(m, DEFAULT_FLOOR)))


## Highest-threat candidate; keep current target unless a challenger exceeds it
## by switch_ratio (F-022 §3.6 hysteresis). Tie → last threat gainer.
func pick_target(candidates: Array, switch_ratio: float) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_v := -1.0
	for m in candidates:
		var v := float(threat.get(m, 0.0))
		if v > best_v or (v == best_v and m == last_gainer):
			best_v = v
			best = m
	if best != null and current_target != null and is_instance_valid(current_target) \
			and current_target != best and candidates.has(current_target):
		if best_v < float(threat.get(current_target, 0.0)) * switch_ratio:
			best = current_target
	current_target = best
	# §5.2 imminent switch: highest OTHER candidate within [imminent, switch) of current.
	imminent_target = null
	if best != null:
		var cur_v := float(threat.get(best, 0.0))
		var chal: CharacterBody3D = null
		var chal_v := -1.0
		for cm in candidates:
			if cm == best:
				continue
			var cv := float(threat.get(cm, 0.0))
			if cv > chal_v:
				chal_v = cv
				chal = cm
		if chal != null and cur_v > 0.0 \
				and chal_v >= cur_v * IMMINENT_RATIO and chal_v < cur_v * switch_ratio:
			imminent_target = chal
	return best


func _apply_collision_size(box_size: Vector3) -> void:
	var col_shape := $CollisionShape3D.shape as BoxShape3D
	if col_shape == null:
		return
	col_shape.size = box_size
	# Align collision with the visual mesh (both sit feet-on-origin) so the box
	# rests on the floor instead of half-sinking — avoids pop/jitter when moving.
	$CollisionShape3D.position.y = box_size.y * 0.5


func _build_box_mesh(color: Color, box_size: Vector3) -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	var box := BoxMesh.new()
	box.size = box_size
	mesh_node.mesh = box
	mesh_node.position.y = box_size.y * 0.5
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = color
	_body_material.roughness = 0.5
	mesh_node.material_override = _body_material


## Faction visual marker (F-028): a non-Dungeon faction renders as a CONE (vs the default box) + a
## violet tint, so a Third-faction pack reads as visibly different from dungeon monsters at a glance.
## Called by the spawner AFTER `faction` is set (mesh is built box-first in setup). ref: DEC-20260621-001.
func apply_faction_shape() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = maxf(_box_size.x, _box_size.z) * 0.62
	cone.height = _box_size.y
	cone.radial_segments = 14
	mesh_node.mesh = cone
	mesh_node.position.y = _box_size.y * 0.5
	# Tint toward a Third-faction violet (keeps the per-unit hue but pushes the whole pack violet),
	# update _base_albedo so the hit-flash / heal-flash tweens restore to the tinted colour.
	_base_albedo = _base_albedo.lerp(Color(0.62, 0.22, 0.92), 0.4)
	if _body_material:
		_body_material.albedo_color = _base_albedo
		_body_material.emission_enabled = true
		_body_material.emission = Color(0.45, 0.12, 0.75)
		_body_material.emission_energy_multiplier = 0.5


## Body (mesh) color — for the enemy info panel portrait (and an enemy marker for clicks).
func get_body_color() -> Color:
	return _base_albedo


## Floating HP bar (PH dev visibility — A4 replaces with real HUD).
func _build_hp_bar(box_size: Vector3) -> void:
	_hp_bar = HealthBar.new()
	_hp_bar.position = Vector3(0, box_size.y + 0.55, 0)
	add_child(_hp_bar)
	_hp_bar.set_ratio(1.0)


## Brief white flash on hit.
func _flash() -> void:
	if _body_material == null:
		return
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	_body_material.albedo_color = Color(1, 1, 1)
	_flash_tw = create_tween()
	_flash_tw.tween_property(_body_material, "albedo_color", _base_albedo, 0.18)

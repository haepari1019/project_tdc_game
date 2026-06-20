extends Node3D
## EnemyAI — per-enemy perception (휴식중: 시야콘+LOS+근접존) + combat behavior
## (전투중: 위협타겟 추적·LOS 게이트 공격·시야상실 추격·텔레그래프 윈드업). Extracted
## from CombatController to isolate enemy decision-making from spawning / threat /
## ability dispatch (ARCHITECTURE DEBT-GOD2). A child of CombatController: shares the
## world (LOS raycast) + parents enemy VFX, and calls back into the controller for
## engage / grace / signals — combat state stays single-owned there.
## ref: F-013 EnemyCombatAI · F-011 Vision · F-022 Threat.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")

# Line-of-sight raycast (perception + attack gating). Mask = world layer (1) only —
# walls/cover block; party(2)/enemy(3,4) are ignored. ref: enemy_visibility.
const LOS_MASK := 1
const LOS_FROM_H := 1.1  # ray origin above the looker's feet
const LOS_TO_H := 0.7    # aim at the target's center

# Hybrid vision cone perception (Phase C2). F-011 partial impl; tuning → DRIFT log.
const SIGHT_RANGE_M := 12.0     # max cone distance
const FOV_DEG := 160.0          # cone full angle (blind behind ~200°)
const PROXIMITY_M := 2.5        # 360° "right next to me" floor → combat zone
const ALERT_ZONE_FRAC := 0.2    # outer 20% of range = 경계존 (alert); inner 80% = 전투존
const INVESTIGATE_SPEED_FRAC := 0.35  # cautious, slow "huh? something there?" approach
const INVESTIGATE_ARRIVE_M := 1.0    # reached last-seen point → give up the search
## Pursuit speed once LOS is lost (engaged enemy heading to the last-seen spot).
## Below party speed so a target that breaks line of sight can gain distance and
## re-hide before the enemy re-acquires; grace then disengages it.
const CHASE_BLIND_SPEED_FRAC := 0.55

# --- Engaged positioning (EN-AI-000 / PT-###; profile per enemy.engage_profile) ---
# Demo PH tuning → DRIFT log. Movement only — strike gating is shared & profile-agnostic.
const MELEE_THREAT_M := 4.0        # kite: flee when a target closes inside this (EN-014 §1 = 4m)
const RETREAT_STEP_M := 3.0        # how far ahead to aim a retreat/backstep destination
const RETREAT_SPEED_FRAC := 1.0    # flee at full speed (being chased)
const SLIP_ACCEL := 3.0            # Slippery (oil): velocity lerp rate — low = slidey/inertial
const ENGAGE_LEASH_M := 18.0       # kite/zone: don't stray past this from spawn anchor (§3 default)
# healer (PT-016 EN-014): FOLLOW the squad — prefer the most-wounded mate (below HEAL_HUG_THRESHOLD),
# else just the nearest ally, keeping within HEAL_HUG_M (inside the AB-098 heal radius) so it tags
# along as the pack chases (doesn't get left behind). HEAL_SEEK_M is generous so a moving group
# stays acquirable. No melee-close on the player (avoids the kite jitter that hit a melee support).
const HEAL_HUG_M := 2.5
const HEAL_SEEK_M := 30.0
const HEAL_HUG_THRESHOLD := 0.9
const ZONE_RADIUS_DEFAULT := 8.0   # zone: engage only while target is within this of the anchor
const ZONE_RETURN_SLACK_M := 1.0   # zone: already-home tolerance (don't jitter at the anchor)
# orbit: arc toward the target while curving to the side. ORBIT_TANGENT_W = sideways weight (lower
# → straighter, less detour); ORBIT_INWARD_FAR = inward weight when far (higher → less circling);
# ORBIT_RADIUS_M = "far" reference for the inward ramp; ORBIT_LOOKAHEAD_M = steer point ahead.
# Approach angle off the direct line ≈ atan2(ORBIT_TANGENT_W, inward): ~33° near … ~47° far.
const ORBIT_RADIUS_M := 6.0
const ORBIT_TANGENT_W := 0.65
const ORBIT_INWARD_FAR := 0.6
const ORBIT_LOOKAHEAD_M := 3.5
# hit-and-run flanker (EN-008, damaging dash): the flank STANDOFF distance held between backstabs —
# out of melee but inside dash reach. Kites to keep this until the dash is off cooldown. The kite
# gets a speed BURST (× base) so it can actually open a gap vs the faster player (9.0 > base 6.0);
# otherwise the player just outruns the retreat and stays glued.
const FLANK_KEEP_M := 6.0
const FLANK_KITE_SPEED_MULT := 1.7
const FLANK_KITE_TRIGGER_M := 4.0  # burst away only when a party actor is THIS close (< FLANK_KEEP
                                   # so it can settle on its standoff without self-kiting)
const FLANK_STRIKE_COS := 0.6      # backstab only when within ~53° of the flank axis (perpendicular
                                   # to the Tank→rearmost spine) — never head-on
const FLANK_PARTY_SCAN_M := 40.0   # radius to gather the party when computing the flank axis
const FLANK_STAGGER_M := 2.0       # along-spine spread between same-side flankers
const PROBE_BACKSTEP_S := 0.6      # probe: retreat window after each strike (EN-006 맞고 빠지기)
const SURROUND_RING_M := 0.9       # surround: ring radius as a fraction of attack_range

# --- Dash signatures (AB-006 gap-close / AB-013 backstab; EN-003/008) ---
const DASH_TIME := 0.2             # lunge duration (velocity takeover, mirrors knockback)
const DASH_MAX_M := 9.0            # cap a single lunge so it never teleports across the map
const DASH_FLANK_OFFSET_M := 1.3   # AB-013: lateral offset so the dash ends at the target's flank
const DASH_TRIGGER_BUFFER_M := 0.5 # only dash when farther than attack_range + this (a real gap)

# --- AssassinTransform (NORM-003/HARD-011): disguised → reveal → backline execute ---
const ASSASSIN_EXECUTE_MULT := 3.0  # backline execute burst (vs normal basic) — 후열 처형

# Dormant roaming (alive feel): wander within this radius of the spawn home, pausing between legs.
const ROAM_RADIUS_M := 5.0
const ROAM_SPEED_FRAC := 0.4
const ROAM_ARRIVE_M := 0.8
const ROAM_PAUSE_MIN_S := 1.5
const ROAM_PAUSE_MAX_S := 4.0
const ROAM_MAX_WALK_S := 8.0   # safety: abandon a roam leg that can't arrive

## F-022 §3.6 target-switch hysteresis. Lower = aggro bounces more readily (harder).
const SWITCH_RATIO := 1.02

# F-021 §3.1.2 object-priority: a flagged enemy seeks the nearest enemy-usable interactable
# (objects opt in via enemy_usable(); chest/door/etc. don't → auto-excluded) and uses it. What
# a held object DOES (e.g. a torch's throw) lives IN THE OBJECT — no per-object branch here.
const OBJECT_SEEK_RADIUS_M := 16.0   # how far the enemy looks for a usable object
const OBJECT_REACH_M := 1.6          # close enough to use it

# Camera damage feedback (피격, F-012). AB-DEFINED 스킬 피해만 — 평타·접촉뎀 제외.
# trauma = (dmg/maxHP)*gain, 방향 킥 = 맞은 방향. 비조작 멤버 이벤트는 감쇄.
const DMG_SHAKE_GAIN := 3.0
const DMG_SHAKE_MIN_FRAC := 0.02  # 이 미만 피해비율 → 셰이크 없음(잔뎀 컷)
const DMG_SHAKE_CAP := 0.65
const DMG_KICK_M := 1.2           # 방향 킥 오프셋(m) @ trauma 1
const SHAKE_NONCTRL_MULT := 0.4   # 비조작 멤버 이벤트 감쇄

# Directional hit indicator (screen-edge red glow, F-011 info-war HUD). ALL hits above a
# chip threshold (평타 포함) — less intrusive than shake, so broader gate. severity =
# (dmg/maxHP)*gain. dungeon_run filters to the controlled member + converts to screen space.
const HIT_INDICATOR_MIN_FRAC := 0.012  # 이 미만 피해비율 → 표시 없음(잔뎀 컷)
const HIT_INDICATOR_GAIN := 4.0

var _combat: Node3D  # CombatController — owns engage/grace/signals + spawning/threat


func setup(combat: Node3D) -> void:
	_combat = combat


## Attach the dev-viz vision cone sized to this AI's perception (range / FOV / alert
## zone) — called by the spawner so cone visuals always match the perception logic.
func attach_vision_cone(unit: CharacterBody3D) -> void:
	unit.build_vision_cone(SIGHT_RANGE_M, FOV_DEG, ALERT_ZONE_FRAC)


## Clear line of sight between two nodes? Raycast masked to world geometry only —
## walls/cover block it, units don't. Used for both attack gating and perception.
func _has_los(from_node: Node3D, to_node: Node3D) -> bool:
	var a: Vector3 = from_node.global_position + Vector3(0, LOS_FROM_H, 0)
	var b: Vector3 = to_node.global_position + Vector3(0, LOS_TO_H, 0)
	var q := PhysicsRayQueryParameters3D.create(a, b, LOS_MASK)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Velocity toward `dest` following the navmesh — routes the enemy AROUND walls
## instead of grinding straight into them. ZERO when arrived / no path.
func _nav_move(enemy: CharacterBody3D, dest: Vector3, speed: float) -> Vector3:
	return enemy.nav_move_toward(dest, speed)


## Dormant tick (휴식중): hybrid vision cone perception. Scans party members within
## the forward cone + LOS (or the 360° proximity floor) and splits the cone range
## into 전투존 (inner 80% → '!' + wake the encounter) and 경계존 (outer 20% → '?' +
## investigate: move toward the sighting). Sees nothing → idle scan in place.
func _tick_dormant(enemy: CharacterBody3D, members: Array, delta: float) -> void:
	enemy.winding = false  # cancel any wind-up carried over from a prior engagement
	enemy.set_target_marker(null)
	var ep: Vector3 = enemy.global_position
	var facing: Vector3 = enemy.facing
	var cos_half := cos(deg_to_rad(FOV_DEG * 0.5))
	var combat_r := SIGHT_RANGE_M * (1.0 - ALERT_ZONE_FRAC)
	var zone := 0
	var seen: CharacterBody3D = null
	var seen_d := INF
	for m in members:
		if not is_instance_valid(m) or (m.has_method("is_alive") and not m.is_alive()):
			continue
		var to: Vector3 = m.global_position - ep
		to.y = 0.0
		var dist := to.length()
		if dist > SIGHT_RANGE_M:
			continue
		var in_prox := dist <= PROXIMITY_M
		var in_cone := dist < 0.001 or to.normalized().dot(facing) >= cos_half
		if not in_prox and not in_cone:
			continue  # outside cone & proximity → skip the LOS raycast entirely
		if not _has_los(enemy, m):
			continue  # occluded by a wall → not perceived
		var z := 2 if (in_prox or dist <= combat_r) else 1  # 전투존 vs 경계존
		if dist < seen_d:
			seen_d = dist
			seen = m
		zone = maxi(zone, z)
	if zone == 2:  # 전투존 → engage this enemy + wake its squad (cohesion radius)
		if seen != null:
			enemy.face_toward(seen.global_position)
		enemy.set_alert_mark(2)
		enemy.has_investigate = false
		_combat._engage_enemy(enemy, seen)  # target the member we actually saw
		enemy.velocity = Vector3.ZERO
		enemy.move_and_slide()
		return
	if zone == 1 and seen != null:  # 경계존 → record the sighting as last-seen
		enemy.investigate_pos = seen.global_position
		enemy.has_investigate = true
	# Investigate: walk to the last place the party was perceived — even after the
	# party slips out of cone/LOS — then give up on arrival. (Phase D: return to post.)
	if enemy.has_investigate:
		enemy.set_alert_mark(1)
		enemy.face_toward(enemy.investigate_pos)
		var to: Vector3 = enemy.investigate_pos - ep
		to.y = 0.0
		if to.length() <= INVESTIGATE_ARRIVE_M:
			enemy.has_investigate = false  # reached last-seen, nothing there → give up
			enemy.set_alert_mark(0)
			enemy.velocity = Vector3.ZERO
			enemy.move_and_slide()
			return
		# Navmesh toward the last-seen point — walk around walls, not into them.
		enemy.velocity = _nav_move(enemy, enemy.investigate_pos, enemy.current_move_speed() * INVESTIGATE_SPEED_FRAC)
		enemy.move_and_slide()
		return
	# Nothing perceived and no lead → idle: gentle roam near home + scan while paused (alive feel).
	enemy.set_alert_mark(0)
	_tick_roam(enemy, delta)


## Dormant idle movement: wander to random points near the spawn home, pausing (and scanning)
## between legs. Navmesh-routed so it skirts walls. Keeps dormant enemies alive, not frozen.
func _tick_roam(enemy: CharacterBody3D, delta: float) -> void:
	# home_pos is captured at the top of tick() (any state) — no need to re-capture here.
	enemy.roam_timer_s -= delta
	if enemy.roaming:
		var to: Vector3 = enemy.roam_target - enemy.global_position
		to.y = 0.0
		if to.length() <= ROAM_ARRIVE_M or enemy.roam_timer_s <= 0.0:
			enemy.roaming = false
			enemy.roam_timer_s = randf_range(ROAM_PAUSE_MIN_S, ROAM_PAUSE_MAX_S)
			enemy.set_base_facing(enemy.facing)   # scan around the heading it arrived on
			enemy.velocity = Vector3.ZERO
		else:
			enemy.face_toward(enemy.roam_target)
			enemy.velocity = _nav_move(enemy, enemy.roam_target, enemy.current_move_speed() * ROAM_SPEED_FRAC)
		enemy.move_and_slide()
		return
	# Paused → look around (scan sweep), then occasionally set off to a new nearby point.
	enemy.scan(delta)
	enemy.velocity = Vector3.ZERO
	enemy.move_and_slide()
	if enemy.roam_timer_s <= 0.0:
		var ang := randf() * TAU
		var r := sqrt(randf()) * ROAM_RADIUS_M   # uniform within the disc
		enemy.roam_target = enemy.home_pos + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		enemy.roaming = true
		enemy.roam_timer_s = ROAM_MAX_WALK_S


## Per-enemy tick entry. Dormant (휴식중) enemies perceive (see _tick_dormant);
## engaged ones chase the highest-threat party member and attack at range (with LOS).
func tick(enemy: CharacterBody3D, targets: Array, delta: float) -> void:
	# Anchor home on the FIRST tick in ANY state — an enemy spawned directly into combat (sandbox,
	# or aggro'd before ever roaming) must still capture its spawn point, or zone (PT-004) has no
	# anchor and follows the enemy → infinite chase, never returns.
	if enemy.home_pos == Vector3.INF:
		enemy.home_pos = enemy.global_position
	if not enemy.engaged:
		_tick_dormant(enemy, targets, delta)
		return
	enemy.attack_cooldown_s = maxf(0.0, enemy.attack_cooldown_s - delta)
	enemy.tick_slow(delta)
	enemy.tick_stun(delta)
	enemy.tick_outcome(delta)  # elemental outcome timers + Ignited DoT
	# Stunned (EN-AI-000 §2): frozen + INTERRUPT — any channel/cast or dash in progress fails
	# (no resolve; its cooldown stays consumed). Player counterplay: stun EN-001 mid-Mockery.
	if enemy.is_stunned():
		if enemy.winding:
			enemy.winding = false
			enemy.windup_target = null
			print("[EN] %s cast interrupted (stun)" % enemy.enemy_id)
		enemy.dashing = false
		enemy.velocity = Vector3.ZERO
		enemy.move_and_slide()
		return
	# Smoothed knockback push takes over movement for its short duration.
	if enemy.tick_knockback(delta):
		return
	# Frame-driven telegraph wind-up — strike resolves when its timer elapses
	# (replaces an await; keeps the encounter deterministic). ref: DEBT-OTHER-AWAIT.
	if enemy.winding:
		enemy.windup_timer_s -= delta
		if enemy.windup_timer_s <= 0.0:
			_resolve_enemy_attack(enemy)  # dash abilities set enemy.dashing here
	# Dash takeover (AB-006/013): a short post-telegraph lunge drives movement (like knockback);
	# on arrival, AB-013 lands its backstab. Resolves before normal steering this whole window.
	if enemy.dashing:
		enemy.dash_timer_s -= delta
		enemy.velocity = enemy.dash_vel
		enemy.move_and_slide()
		if enemy.dash_timer_s <= 0.0:
			enemy.dashing = false
			_resolve_dash_hit(enemy)
		return
	# Post-strike back-off timer (probe hit / EN-008 backstab) — decremented centrally so any
	# movement profile (probe AND orbit) can retreat while it runs.
	enemy.probe_backstep_s = maxf(0.0, enemy.probe_backstep_s - delta)
	# Per-ability cooldowns tick down while engaged (each AB on its own clock). Heal (AB-098) is
	# target-less, so its pass runs early — EN-014 kites + rarely melees, can't ride the attack
	# gate. Every cast pass checks its own ability_cd[ref] internally.
	for r in enemy.ability_cd.keys():
		enemy.ability_cd[r] = maxf(0.0, float(enemy.ability_cd[r]) - delta)
	if not enemy.winding:
		_try_cast_signature(enemy)
	# F-022: target highest-threat party member. With no threat, fall back to the
	# nearest member the enemy can actually SEE (LOS) — NOT the global nearest — so a
	# far, never-perceived group (e.g. the hidden 본대) is never chased. No threat and
	# nobody visible → hold; grace will disengage it back to dormant.
	enemy.decay_threat(delta)
	var target: CharacterBody3D = enemy.pick_target(_alive_members(targets), SWITCH_RATIO)
	if target == null or float(enemy.threat.get(target, 0.0)) <= 0.0:
		target = _nearest_visible(enemy, targets)
	if target == null:
		enemy.velocity = Vector3.ZERO
		enemy.move_and_slide()
		return
	# Flanker target preference (PT-003 EN-003 / PT-008 EN-008): seek the BACKLINE (squishiest
	# non-Tank), ignoring the frontal tank's threat — so basics/orbit/dash all dive the DPS/Healer
	# before the tank pulls aggro (EN-AI-000 §1 "정면 Tank 무시 시도"). Falls back to threat target.
	if String(enemy.engage_profile.get("target_pref", "")) == "backline":
		var bl := _pick_backline_target(targets)
		if bl != null:
			target = bl
	# Disguised assassin (AssassinTransform): ignore threat, stalk a BACKLINE target (squishiest
	# non-Tank) to execute. Reverts to normal targeting once revealed.
	if enemy.assassin and not enemy.assassin_revealed:
		var ex := _pick_backline_target(targets)
		if ex != null:
			target = ex
	enemy.set_target_marker(target)
	enemy.set_alert_mark(2)  # 전투 (!)
	var to := target.global_position - enemy.global_position
	to.y = 0.0
	var dist := to.length()
	var has_los := _has_los(enemy, target)
	if has_los:
		_combat.refresh_engage_grace(enemy)               # still sees prey → stay engaged
		enemy.investigate_pos = target.global_position    # remember the last-seen spot
		enemy.has_investigate = true
	elif enemy.has_search:
		# Hit from outside vision: search toward the hit's source direction (F-011/F-013).
		enemy.investigate_pos = enemy.search_pos
		enemy.has_investigate = true
		enemy.has_search = false                          # consumed into investigate_pos
	# F-021 §3.1.2 object-priority: a flagged enemy uses nearby objects; a held object runs its
	# OWN combat behavior (torch → throw). Falls back to normal combat with no usable object.
	if enemy.interacts_with_objects and _try_object_interaction(enemy, target, has_los, delta):
		enemy.move_and_slide()
		return
	# Dash signature (AB-006/013): close the gap on the current target (backline for flankers).
	if not enemy.winding and not enemy.dashing:
		_try_cast_dash(enemy, target, dist, has_los)
	# Provoke signature (AB-099): aims the FRONT fan at the engaged target (so it's directional,
	# not stale-facing) and only fires when a party actor is actually in that fan. Needs target.
	if not enemy.winding and not enemy.dashing and has_los:
		_try_cast_provoke(enemy, target)
	# Per-enemy engaged behavior (EN-AI-000 / PT-###): MOVEMENT is profile-specific
	# (_engage_move owns velocity incl. ZERO = plant); the ATTACK gate below is shared —
	# in range + LOS + off cooldown → strike, even while a kiter keeps backpedalling.
	var move_vel := _engage_move(enemy, target, dist, has_los, delta)
	if has_los and dist <= enemy.attack_range_m:
		enemy.face_toward(target.global_position)  # face to strike even while repositioning
		if enemy.attack_cooldown_s <= 0.0 and not enemy.winding:
			if enemy.assassin and not enemy.assassin_revealed:
				_begin_assassin_execute(enemy, target)  # disguised → reveal telegraph → execute
			else:
				_begin_enemy_attack(enemy, target)
			enemy.attack_cooldown_s = enemy.attack_interval_s
			if String(enemy.engage_profile.get("engage", "")) == "probe":
				enemy.probe_backstep_s = PROBE_BACKSTEP_S  # hit landed → back off (EN-006)
	if enemy.is_slippery():  # Slippery (oil): inertial — can't change/stop velocity instantly
		enemy.velocity = enemy.velocity.lerp(move_vel, SLIP_ACCEL * delta)
	else:
		enemy.velocity = move_vel
	enemy.move_and_slide()


## Engaged movement by per-enemy pattern (EN-AI-000 §1 / PT-### via enemy.engage_profile).
## Returns the desired velocity (ZERO = plant & attack). Blind (no LOS) is shared: every
## profile falls back to a cautious advance toward the last-seen spot so it can re-acquire.
func _engage_move(enemy: CharacterBody3D, target: CharacterBody3D, dist: float, has_los: bool, delta: float) -> Vector3:
	# Channeled cast (EN-AI-000 §2): hold position for the wind-up — EN-007 hex 이동금지,
	# EN-002 charge 제자리, EN-014 pulse 제자리, EN-006 stun(AB-011) 제자리. Non-channel (AB-010) still moves.
	if enemy.winding and bool(enemy.windup_eff.get("channel", false)):
		return Vector3.ZERO
	var spd: float = enemy.current_move_speed()
	if not has_los:
		if not enemy.has_investigate:
			return Vector3.ZERO
		enemy.face_toward(enemy.investigate_pos)
		return _nav_move(enemy, enemy.investigate_pos, spd * CHASE_BLIND_SPEED_FRAC)
	var tp: Vector3 = target.global_position
	match String(enemy.engage_profile.get("engage", "advance")):
		"standoff": return _move_standoff(enemy, tp, dist, spd)
		"kite":     return _move_kite(enemy, tp, dist, spd)
		"healer":   return _move_healer(enemy, tp, dist, spd)
		"zone":     return _move_zone(enemy, tp, dist, spd)
		"orbit":    return _move_orbit(enemy, tp, dist, spd)
		"probe":    return _move_probe(enemy, tp, dist, spd, delta)
		"surround": return _move_surround(enemy, tp, dist, spd)
		_:          return _move_advance(enemy, tp, dist, spd)


## advance (PT-001/012/014 + skitter PT-015): close to melee, then plant. chase_speed_mult
## lets Skitter (EN-013) chase 10% faster (EN-AI-000 §1).
func _move_advance(enemy: CharacterBody3D, tp: Vector3, dist: float, spd: float) -> Vector3:
	enemy.face_toward(tp)
	if dist <= enemy.attack_range_m:
		return Vector3.ZERO
	return _nav_move(enemy, tp, spd * float(enemy.engage_profile.get("chase_speed_mult", 1.0)))


## standoff (PT-002/007/013): ranged hold — close to attack band if out of range, else plant
## and shoot. No flee even when crowded (EN-002 "후퇴 bias 없음").
func _move_standoff(enemy: CharacterBody3D, tp: Vector3, dist: float, spd: float) -> Vector3:
	enemy.face_toward(tp)
	if dist > enemy.attack_range_m:
		return _nav_move(enemy, tp, spd)
	return Vector3.ZERO


## Flee one step directly away from `tp`. When `leashed`, clamp to the spawn-anchor leash so a
## ranged kiter (EN-005) can't run off the map. Roaming units that move with the fight (EN-008's
## post-dash hit-and-run) pass leashed=false — else, having dashed past the leash, the clamp would
## freeze them until the next dash (a "stuck after skill" bug). Nav still keeps them off walls.
func _kite_flee(enemy: CharacterBody3D, tp: Vector3, spd: float, leashed: bool = true) -> Vector3:
	var away := enemy.global_position - tp
	away.y = 0.0
	if away.length() < 0.01:
		away = -enemy.facing
	var dest := enemy.global_position + away.normalized() * RETREAT_STEP_M
	if leashed:
		var anchor: Vector3 = enemy.home_pos if enemy.home_pos != Vector3.INF else enemy.global_position
		if Vector2(dest.x - anchor.x, dest.z - anchor.z).length() > ENGAGE_LEASH_M:
			return Vector3.ZERO  # cornered at the leash → hold rather than flee off the map
	return _nav_move(enemy, dest, spd * RETREAT_SPEED_FRAC)


## kite (PT-005): flee when a target closes inside MELEE_THREAT_M; else hold/close to attack band.
## Stable only for RANGED kiters (attack_range > MELEE_THREAT). Melee-range supports use _move_healer.
func _move_kite(enemy: CharacterBody3D, tp: Vector3, dist: float, spd: float) -> Vector3:
	enemy.face_toward(tp)
	if dist < MELEE_THREAT_M:
		return _kite_flee(enemy, tp, spd)
	if dist > enemy.attack_range_m:
		return _nav_move(enemy, tp, spd)
	return Vector3.ZERO


## healer (PT-016 EN-014): enemy SUPPORT — kites the player (flee if it closes to melee) but does
## NOT close to melee-attack (that caused jitter for a 1.7m-range unit). Instead HUGS its most-
## wounded squad-mate to keep it inside the AB-098 heal radius. Alone / nobody wounded → just hold.
func _move_healer(enemy: CharacterBody3D, tp: Vector3, dist: float, spd: float) -> Vector3:
	enemy.face_toward(tp)
	if dist < MELEE_THREAT_M:
		return _kite_flee(enemy, tp, spd)  # player too close → kite away
	var ally := _heal_follow_target(enemy)
	if ally != null:
		var to_ally := ally.global_position - enemy.global_position
		to_ally.y = 0.0
		if to_ally.length() > HEAL_HUG_M:
			enemy.face_toward(ally.global_position)
			return _nav_move(enemy, ally.global_position, spd)  # tag along / close to heal range
	return Vector3.ZERO  # already with the group / truly alone → hold (no melee-close, no jitter)


## Who EN-014 should follow: the most-wounded squad-mate (below HEAL_HUG_THRESHOLD) so it can heal,
## ELSE the nearest living ally so it tags along with the moving group (never left behind). null if
## truly alone. Self excluded (self-heals work in place). Searched within HEAL_SEEK_M.
func _heal_follow_target(enemy: CharacterBody3D) -> CharacterBody3D:
	var wounded: CharacterBody3D = null
	var wounded_frac := HEAL_HUG_THRESHOLD
	var nearest: CharacterBody3D = null
	var nearest_d := INF
	for a in _combat._enemies_in_radius(enemy.global_position, HEAL_SEEK_M):
		if a == enemy or not is_instance_valid(a) or (a.has_method("is_alive") and not a.is_alive()):
			continue
		var frac: float = a.hp / maxf(float(a.max_hp), 1.0)
		if frac < wounded_frac:
			wounded_frac = frac
			wounded = a
		var d: float = enemy.global_position.distance_to(a.global_position)
		if d < nearest_d:
			nearest_d = d
			nearest = a
	return wounded if wounded != null else nearest


## zone (PT-004): hold near the spawn anchor — engage only while the target is inside the
## zone radius; if it leaves, return to the anchor instead of chasing out (EN-004 zone > chase).
func _move_zone(enemy: CharacterBody3D, tp: Vector3, dist: float, spd: float) -> Vector3:
	enemy.face_toward(tp)
	if dist <= enemy.attack_range_m:
		return Vector3.ZERO
	var anchor: Vector3 = enemy.home_pos if enemy.home_pos != Vector3.INF else enemy.global_position
	var zr := float(enemy.engage_profile.get("zone_radius_m", ZONE_RADIUS_DEFAULT))
	if Vector2(tp.x - anchor.x, tp.z - anchor.z).length() <= zr:
		return _nav_move(enemy, tp, spd)  # target inside the zone → approach to attack band
	if Vector2(enemy.global_position.x - anchor.x, enemy.global_position.z - anchor.z).length() > ZONE_RETURN_SLACK_M:
		enemy.face_toward(anchor)
		return _nav_move(enemy, anchor, spd)  # target fled the zone → fall back to the anchor
	return Vector3.ZERO


## orbit (PT-003/008): steer TANGENTIALLY around the target (circle it) while spiralling inward —
## a wide circular detour to the side/rear, not a near-straight diagonal. Far → mostly tangential
## (wide arc); the closer to attack range, the more it cuts inward to close. Side fixed per-enemy.
func _move_orbit(enemy: CharacterBody3D, tp: Vector3, dist: float, spd: float) -> Vector3:
	enemy.face_toward(tp)
	var to := tp - enemy.global_position
	to.y = 0.0
	if to.length() < 0.01:
		return Vector3.ZERO
	var radial := to.normalized()                                    # toward the target (close in)
	var side := 1.0 if (enemy.get_instance_id() % 2 == 0) else -1.0
	var tangent := Vector3(-radial.z, 0.0, radial.x) * side          # perpendicular (circle around)
	# Hit-and-run flanker (EN-008): the dash does the engaging, so BETWEEN dashes it holds a flank
	# standoff (FLANK_KEEP) — kite out if the target closes (keeps distance until the dash is ready),
	# else circle at range WITHOUT spiralling into melee. The dash fires from here when off cooldown.
	if _is_hit_run_flanker(enemy):
		return _move_hit_run_flank(enemy, tp, spd)
	# Sustained flanker (EN-003, gap-close dash): spiral in to stick & flurry.
	if dist <= enemy.attack_range_m:
		return Vector3.ZERO
	# Far past attack range → less inward (wider arc); near → full inward. Tangent scaled by
	# ORBIT_TANGENT_W so the detour is a moderate diagonal flank, not a near-perpendicular circle.
	var far := clampf((dist - enemy.attack_range_m) / ORBIT_RADIUS_M, 0.0, 1.0)
	var radial_w := lerpf(1.0, ORBIT_INWARD_FAR, far)
	var move_dir := (tangent * ORBIT_TANGENT_W + radial * radial_w).normalized()
	return _nav_move(enemy, enemy.global_position + move_dir * ORBIT_LOOKAHEAD_M, spd)


## True if the unit has a DAMAGING dash (hit_on_arrival) → it's a hit-and-run flanker (EN-008) that
## holds distance between dives. A non-damaging gap-close dash (EN-003 AB-006) sticks instead.
func _is_hit_run_flanker(enemy: CharacterBody3D) -> bool:
	for ab in enemy.abilities:
		if typeof(ab) != TYPE_DICTIONARY:
			continue
		var eff: Dictionary = Slice01Data.get_ability(String(ab.get("ref", "")))
		if String(eff.get("kind", "")) == "enemy_dash" and bool(eff.get("hit_on_arrival", false)):
			return true
	return false


## ── EN-008 Corner Knife — hit-and-run FLANK model ─────────────────────────────────────────────
## One loop, governed by two questions (on the flank? dash ready?):
##   REPOSITION → STRIKE (backstab from the flank) → RESET (kite out) → REPOSITION
## • FLANK = the party's exposed side: the axis perpendicular to the Tank→rearmost spine (user def).
## • REPOSITION (_move_hit_run_flank): hold a standoff on that flank; burst-kite anyone who closes.
## • STRIKE: _try_cast_dash only fires the backstab when on the flank arc + off cooldown (no head-on).
## • RESET: post-dash the target is < kite trigger → it bursts back out to the standoff.
## Never approaches head-on, never brawls in melee — all the old standalone tweaks collapse into this.

## REPOSITION step: kite out if any party actor is too close, else move to the flank standoff. Burst
## speed + unleashed so it holds distance vs the faster player and isn't frozen by the spawn leash.
func _move_hit_run_flank(enemy: CharacterBody3D, tp: Vector3, spd: float) -> Vector3:
	var threat := _nearest_party(enemy, FLANK_KITE_TRIGGER_M)
	if threat != null:
		return _kite_flee(enemy, threat.global_position, spd * FLANK_KITE_SPEED_MULT, false)
	return _nav_move(enemy, _flank_standoff(enemy, tp), spd)


## The party's FLANK axis = unit vector PERPENDICULAR to the spine (Tank → rearmost party member).
## Vector3.ZERO if there's no Tank or the spine is degenerate (caller falls back). ref: 사용자 정의 —
## "탱커와 가장 후열 캐릭터를 이은 선에 중앙 직교하는 방향".
func _party_flank_axis(enemy: CharacterBody3D) -> Vector3:
	var party: Array = _combat._allies_in_radius(enemy.global_position, FLANK_PARTY_SCAN_M)
	var tank: CharacterBody3D = null
	for a in party:
		if is_instance_valid(a) and a.is_alive() and String(a.get("class_id")) == "Tank":
			tank = a
			break
	if tank == null:
		return Vector3.ZERO
	var back: CharacterBody3D = null
	var max_d := -1.0
	for a in party:
		if is_instance_valid(a) and a.is_alive() and a != tank:
			var d: float = tank.global_position.distance_to(a.global_position)
			if d > max_d:
				max_d = d
				back = a
	if back == null:
		return Vector3.ZERO
	var spine := back.global_position - tank.global_position
	spine.y = 0.0
	if spine.length() < 1.0:
		return Vector3.ZERO  # tank+backline stacked → no meaningful axis
	return Vector3(-spine.z, 0.0, spine.x).normalized()  # perpendicular to the spine


## Standoff point on the flank: target + flank-axis × FLANK_KEEP. Side fixed per-enemy (L/R of the
## party) + a per-enemy stagger along the spine so multiple flankers spread, not stack. No readable
## axis (no Tank) → hold the current bearing out from the target (just keep distance).
func _flank_standoff(enemy: CharacterBody3D, tp: Vector3) -> Vector3:
	var axis := _party_flank_axis(enemy)
	if axis == Vector3.ZERO:
		var out := enemy.global_position - tp
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else -enemy.facing
		return tp + out * FLANK_KEEP_M
	var side := 1.0 if (enemy.get_instance_id() % 2 == 0) else -1.0
	var spine_dir := Vector3(axis.z, 0.0, -axis.x)  # back along the spine
	var stagger := (float(enemy.get_instance_id() % 3) - 1.0) * FLANK_STAGGER_M
	return tp + axis * (side * FLANK_KEEP_M) + spine_dir * stagger


## Nearest living PARTY member within `r` of the enemy (or null) — the closest threat to keep
## distance from. Uses the combat's party query (same source as the provoke fan check).
func _nearest_party(enemy: CharacterBody3D, r: float) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d := INF
	for a in _combat._allies_in_radius(enemy.global_position, r):
		if not is_instance_valid(a) or (a.has_method("is_alive") and not a.is_alive()):
			continue
		var d: float = enemy.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


## probe (PT-006): hit-and-back-off. While the post-strike backstep timer runs, retreat;
## otherwise close to melee and plant (the strike sets probe_backstep_s in tick()).
func _move_probe(enemy: CharacterBody3D, tp: Vector3, dist: float, spd: float, _delta: float) -> Vector3:
	enemy.face_toward(tp)
	if enemy.probe_backstep_s > 0.0:  # decremented centrally in tick()
		var away := enemy.global_position - tp
		away.y = 0.0
		if away.length() < 0.01:
			away = -enemy.facing
		return _nav_move(enemy, enemy.global_position + away.normalized() * RETREAT_STEP_M, spd)
	if dist <= enemy.attack_range_m:
		return Vector3.ZERO
	return _nav_move(enemy, tp, spd)


## surround (PT-009): converge on a ring point around the target (angle fixed per-enemy) so the
## swarm encircles instead of stacking on one face; attack gate fires once within real range.
func _move_surround(enemy: CharacterBody3D, tp: Vector3, dist: float, spd: float) -> Vector3:
	enemy.face_toward(tp)
	if dist <= enemy.attack_range_m:
		return Vector3.ZERO
	var ang := float(enemy.get_instance_id() % 8) / 8.0 * TAU
	var ring: float = enemy.attack_range_m * SURROUND_RING_M
	var slot: Vector3 = tp + Vector3(cos(ang), 0.0, sin(ang)) * ring
	return _nav_move(enemy, slot, spd)


## Object-priority interaction (F-021 §3.1.2): if holding an object, run ITS combat behavior;
## else seek + use the nearest enemy-usable interactable. Returns true if it drove this frame.
func _try_object_interaction(enemy: CharacterBody3D, target: CharacterBody3D, has_los: bool, delta: float) -> bool:
	var held = enemy.held_object
	if held != null and is_instance_valid(held) and held.has_method("enemy_combat_tick"):
		return held.enemy_combat_tick(enemy, target, has_los, delta)   # the object owns its behavior
	# not holding → seek the nearest enemy-usable object (objects opt in via enemy_usable())
	var obj := _nearest_usable_object(enemy)
	if obj == null:
		return false   # nothing usable → fall back to normal combat
	var op: Vector3 = obj.global_position
	if Vector2(op.x - enemy.global_position.x, op.z - enemy.global_position.z).length() <= OBJECT_REACH_M:
		obj.enemy_use(enemy)   # the object decides (torch → pick_up + set enemy.held_object)
		enemy.velocity = Vector3.ZERO
	else:
		enemy.face_toward(op)
		enemy.velocity = _nav_move(enemy, op, enemy.current_move_speed())
	return true


## Nearest enemy-usable interactable within seek radius (group "interactable" + enemy_usable()).
## Objects that don't implement enemy_usable() (chest/door/lever/trap) are auto-excluded.
func _nearest_usable_object(enemy: CharacterBody3D) -> Node:
	var best: Node = null
	var best_d := OBJECT_SEEK_RADIUS_M * OBJECT_SEEK_RADIUS_M
	for t in get_tree().get_nodes_in_group("interactable"):
		if not (t is Node3D) or not t.has_method("enemy_usable") or not t.enemy_usable():
			continue
		var d := Vector2(t.global_position.x - enemy.global_position.x, t.global_position.z - enemy.global_position.z).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best


## Data-driven enemy attack: choose ability (ready cooldown signature > basic). Telegraphed
## casts start a frame-driven wind-up (resolved in tick); others hit now.
## Extensible — assign any ability to any unit via enemies.json abilities[].ref.
func _begin_enemy_attack(enemy: CharacterBody3D, target: CharacterBody3D) -> void:
	enemy.attack_count += 1
	var chosen: Dictionary = _select_enemy_ability(enemy)
	var eff: Dictionary = {}
	if not chosen.is_empty():
		var ref := String(chosen.get("ref", ""))
		# Basics are rom_* (enemy_basics catalog); signatures are AB-### (abilities catalog).
		eff = Slice01Data.get_enemy_basic(ref) if ref.begins_with("rom_") else Slice01Data.get_ability(ref)
		# A signature picked via the gate fires now → start its own per-ability cooldown.
		if String(chosen.get("trigger", "")) == "signature":
			enemy.ability_cd[ref] = float(eff.get("cooldown_s", 0.0))
	var tele: float = float(eff.get("telegraph_s", 0.0))
	if enemy.boss_phased and tele > 0.0:
		tele = maxf(0.3, tele + enemy.boss_phase2_telegraph_delta)  # MiniBoss phase-2: faster cast
	if tele > 0.0:
		# Warning cue now; the strike resolves when the wind-up timer elapses.
		enemy.winding = true
		enemy.windup_timer_s = tele
		enemy.windup_eff = eff
		enemy.windup_chosen = chosen
		enemy.windup_target = target
		# Telegraph PLACEMENT = dodge affordance. Ground-at-impact marker ONLY for positional AoE
		# (splash — space out to avoid). Target-LOCKED signature casts cue ON the caster. BASIC pokes
		# get NO telegraph at all (impact feedback is enough; a tell adds noise for a cheap poke).
		var k := String(eff.get("kind", "enemy_melee"))
		if String(chosen.get("trigger", "")) == "basic":
			pass  # 평타급: no telegraph cue (windup timing kept; only the hit reads)
		elif k == "enemy_charge":
			SkillVfx.charge_up(self, enemy.global_position, tele, _telegraph_color(k))  # caster charge
			enemy.face_toward(target.global_position)  # aim the bolt
		else:
			# Target-LOCKED casts (incl. splash — the primary is locked, splash is incidental): a
			# caster wind-up cue. No ground-at-spot marker — the homing orb lands ON the moving target.
			SkillVfx.windup_cue(self, enemy.global_position, tele, _telegraph_color(k))
	else:
		_deliver_enemy_hit(enemy, target, eff, chosen)  # no telegraph → resolve immediately


## Resolve a telegraphed strike at wind-up end. Re-validates target (+ stun dodge).
func _resolve_enemy_attack(enemy: CharacterBody3D) -> void:
	var eff: Dictionary = enemy.windup_eff
	var chosen: Dictionary = enemy.windup_chosen
	var target: CharacterBody3D = enemy.windup_target
	enemy.winding = false
	enemy.windup_target = null
	# Zone/ally signatures are target-less — resolve before the party-target validation/LOS gate.
	if String(eff.get("kind", "")) == "enemy_heal":
		_apply_enemy_heal(enemy, eff, chosen)
		return
	if String(eff.get("kind", "")) == "enemy_provoke":
		_apply_enemy_provoke(enemy, eff, chosen)
		return
	if not is_instance_valid(target) or not target.is_alive():
		return
	if not _has_los(enemy, target):
		return  # target broke line of sight during the wind-up — strike fizzles
	if String(eff.get("kind", "")) == "enemy_dash":
		_begin_dash(enemy, eff, chosen, target)  # telegraph done → start the lunge (hit on arrival)
		return
	# AB-011 stun is a combo OPENER (spec) + channel: it LANDS once the channel completes (locked).
	# Counterplay is INTERRUPT (stun EN-006 mid-channel) or break LOS — not stepping out of range.
	_deliver_enemy_hit(enemy, target, eff, chosen)


## Flying-orb vfx keys (homing projectiles). These hits are LOCKED (unavoidable) but the orb takes
## SHOT_FLIGHT_S to reach the target, so the damage is deferred to arrival (not applied at resolve).
const _PROJECTILE_VFX := ["projectile", "shot_venom", "shot_slag", "shot_hex"]


## Deliver a resolved enemy hit. Launches the vfx now; for a homing PROJECTILE the orb locks onto
## the target and the damage/feedback land when it ARRIVES (SHOT_FLIGHT_S later) — a moving target
## can't visually outrun a locked hit, and the damage coincides with impact. Instant cues (melee
## bash / lightning) apply immediately. ref: 사용자 — "락온 유도 + 도달 시 데미지".
func _deliver_enemy_hit(enemy: CharacterBody3D, target: CharacterBody3D, eff: Dictionary, chosen: Dictionary) -> void:
	var vfx := String(eff.get("vfx", ""))
	if vfx != "":
		SkillVfx.enemy_vfx(vfx, self, enemy.global_position, target)
	if vfx in _PROJECTILE_VFX:
		# Homing shot: the hit lands when the orb reaches the target.
		get_tree().create_timer(SkillVfx.SHOT_FLIGHT_S).timeout.connect(
			_on_shot_arrived.bind(enemy, target, eff, chosen))
	else:
		_apply_enemy_hit(enemy, target, eff, chosen)  # instant (no travel)


## Homing projectile reached its target → apply the locked hit (if both still valid + target alive).
func _on_shot_arrived(enemy: CharacterBody3D, target: CharacterBody3D, eff: Dictionary, chosen: Dictionary) -> void:
	if is_instance_valid(enemy) and is_instance_valid(target) and target.is_alive():
		_apply_enemy_hit(enemy, target, eff, chosen)


## Apply an enemy hit: damage + status/knockback + camera/indicator feedback. The VFX is launched
## separately by _deliver_enemy_hit; for homing projectiles THIS runs on arrival (damage lands when
## the orb reaches the target), so the feedback (shake/indicator) coincides with the visual impact.
func _apply_enemy_hit(enemy: CharacterBody3D, target: CharacterBody3D, eff: Dictionary, chosen: Dictionary) -> void:
	var kind := String(eff.get("kind", "enemy_melee"))
	var from := enemy.global_position
	# Multi-hit rom_* (voltaic double / melee flurry / flank stab) fold into one resolved total
	# for now (true sequential hits = S2b polish). hits defaults 1.
	var hits: int = maxi(1, int(eff.get("hits", 1)))
	var dmg: float = enemy.contact_damage * float(eff.get("damage_mult", 1.0)) * float(hits)
	target.take_damage(dmg)
	_combat._engage_enemy(enemy)  # D-010 §4.1: keep engaged (target already has threat/LOS)
	_combat.party_damaged.emit()  # follower formation-break trigger
	# Directional hit indicator (screen-edge): ALL hits above a chip threshold (평타 포함).
	# dir = toward the attacker; dungeon_run filters to controlled + converts to screen space.
	var hit_frac: float = dmg / maxf(float(target.max_hp), 1.0)
	if hit_frac >= HIT_INDICATOR_MIN_FRAC:
		var src: Vector3 = from - target.global_position  # toward the attacker
		src.y = 0.0
		_combat.party_hit.emit(src, clampf(hit_frac * HIT_INDICATOR_GAIN, 0.2, 1.0), target.is_controlled())
	# Camera damage feedback — AB-DEFINED SKILL hits only. `chosen` = the picked
	# ability {ref:"AB-###", trigger}. AB-defined = ref 있음, 스킬 = trigger != "basic"
	# (평타 ability·무-ability 접촉뎀 제외). 방향 킥 = 맞은 방향(위협 정보) + trauma.
	var atk_ref: String = String(chosen.get("ref", ""))
	var is_ab_skill: bool = not atk_ref.is_empty() and String(chosen.get("trigger", "basic")) != "basic"
	if is_ab_skill:
		var frac: float = dmg / maxf(float(target.max_hp), 1.0)
		if frac >= DMG_SHAKE_MIN_FRAC:
			var dt: float = clampf(frac * DMG_SHAKE_GAIN, 0.0, DMG_SHAKE_CAP)
			if not target.is_controlled():
				dt *= SHAKE_NONCTRL_MULT
			var kdir: Vector3 = target.global_position - from
			kdir.y = 0.0
			kdir = kdir.normalized() if kdir.length() > 0.01 else Vector3.ZERO
			_combat.camera_shake.emit(dt, kdir * (DMG_KICK_M * dt))
	match kind:
		"enemy_poison":
			target.apply_poison(float(eff.get("poison_dur_s", 4.0)), float(eff.get("poison_dps", 5.0)))
		"enemy_stun":
			target.apply_stun(float(eff.get("stun_s", 1.0)))
		"enemy_charge":  # AB-004 Charged Voltaic — Shock outcome (감전; STATUS-OUTCOME-CORE)
			target.apply_outcome("Shock", float(eff.get("shock_dur_s", 2.0)))
		"enemy_hex":  # AB-012 Hex Bolt — HEX-WEAK soft CC (이동 감소; 피해감소 half = 후속)
			target.apply_slow(float(eff.get("hex_slow", 0.6)), float(eff.get("hex_dur_s", 4.0)))
		"enemy_splash":  # AB-008 Slag Spit — splash to party members near the impact point
			var sr := float(eff.get("splash_radius_m", 1.5))
			var sfrac := float(eff.get("splash_frac", 0.6))
			for a in _combat._allies_in_radius(target.global_position, sr):
				if a != target and is_instance_valid(a) and a.has_method("take_damage"):
					a.take_damage(dmg * sfrac)
		_:
			var kb: float = float(eff.get("knockback_m", 0.0))
			if kb > 0.0:
				target.apply_knockback(target.global_position - from, kb)
	if String(chosen.get("trigger", "")) == "signature" or kind in ["enemy_stun", "enemy_poison"]:
		print("[EN] %s %s -> %s" % [enemy.enemy_id, String(chosen.get("ref", "")), target.identity_skill_id])
	if kind == "enemy_execute":
		enemy.assassin_revealed = true  # disguise dropped after the execute lands
		print("[EN] %s ASSASSIN execute (x%.1f) -> %s" % [enemy.enemy_id, float(eff.get("damage_mult", 1.0)), target.identity_skill_id])


func _telegraph_color(kind: String) -> Color:
	match kind:
		"enemy_ranged":  # rom_* ranged basic wind-up cue (amber, on caster)
			return Color(0.95, 0.82, 0.35, 0.7)
		"enemy_melee":  # rom_* melee basic wind-up cue (warm, on caster)
			return Color(1.0, 0.62, 0.3, 0.7)
		"enemy_stun":
			return Color(1.0, 0.85, 0.2, 0.5)
		"enemy_poison":
			return Color(0.4, 0.9, 0.3, 0.5)
		"enemy_charge":  # AB-004 Voltaic — electric blue
			return Color(0.4, 0.7, 1.0, 0.55)
		"enemy_hex":  # AB-012 Hex — purple rune (보라색 룬탄)
			return Color(0.7, 0.35, 0.95, 0.5)
		"enemy_heal":  # AB-098 Mire Mend — green ward pulse (녹색 결계)
			return Color(0.35, 1.0, 0.5, 0.5)
		"enemy_splash":  # AB-008 Slag — slag orange
			return Color(0.95, 0.6, 0.25, 0.5)
		"enemy_dash":  # AB-006/013 dash — sharp cyan crouch-tell
			return Color(0.5, 0.95, 0.95, 0.55)
		"enemy_provoke":  # AB-099 Iron Mockery — metallic gold fan (방패 금속 울림)
			return Color(0.9, 0.8, 0.4, 0.55)
		"enemy_execute":  # AssassinTransform reveal — crimson aim line (조준선)
			return Color(0.85, 0.05, 0.15, 0.6)
	return Color(0.9, 0.3, 0.2, 0.5)


## Target-less heal signature (AB-098): if off its own cooldown and a squad-mate is wounded,
## start the channel (telegraph) and reset ability_cd[ref]. Runs early (target-less); provoke/dash
## have their own passes. Returns true if a cast began.
func _try_cast_signature(enemy: CharacterBody3D) -> bool:
	for ab in enemy.abilities:
		if typeof(ab) != TYPE_DICTIONARY:
			continue
		var ref := String(ab.get("ref", ""))
		var eff: Dictionary = Slice01Data.get_ability(ref)
		var kind := String(eff.get("kind", ""))
		if kind != "enemy_heal":
			continue  # this early pass is heal only (provoke=_try_cast_provoke, dash=_try_cast_dash)
		if float(enemy.ability_cd.get(ref, 0.0)) > 0.0:
			continue  # AB still on cooldown
		# Condition: a squad-mate (incl. self) within heal radius below the HP threshold.
		var r := float(eff.get("radius_m", 3.0))
		var thr := float(eff.get("ally_threshold_pct", 0.9))
		var wounded := false
		for a in _combat._enemies_in_radius(enemy.global_position, r):
			if is_instance_valid(a) and a.is_alive() and a.hp < a.max_hp * thr:
				wounded = true
				break
		if not wounded:
			continue  # nothing to heal → save the cooldown
		# Begin the channel — windup_target null (target-less); resolved by _resolve_enemy_attack.
		enemy.winding = true
		enemy.windup_timer_s = float(eff.get("telegraph_s", 0.55))
		enemy.windup_eff = eff
		enemy.windup_chosen = {"ref": ref, "trigger": "signature"}
		enemy.windup_target = null
		enemy.ability_cd[ref] = float(eff.get("cooldown_s", 8.0))
		# Telegraph the heal AoE at the caster, radius = actual heal radius (was a fixed 1.9 disc).
		SkillVfx.telegraph(self, enemy.global_position, _telegraph_color(kind), float(eff.get("radius_m", 3.0)))
		return true
	return false


## Resolve AB-098 Mire Mend Pulse — heal every squad-mate (incl. self) within radius by
## heal_pct of their max HP. Target-less (allies, not the party). ref: AB-098 / EN-014.
func _apply_enemy_heal(enemy: CharacterBody3D, eff: Dictionary, chosen: Dictionary) -> void:
	var r := float(eff.get("radius_m", 3.0))
	var pct := float(eff.get("heal_pct", 0.08))
	var healed := 0
	for a in _combat._enemies_in_radius(enemy.global_position, r):
		if is_instance_valid(a) and a.has_method("heal") and a.is_alive() and a.hp < a.max_hp:
			a.heal(a.max_hp * pct)
			healed += 1
	# (No resolve telegraph — the channel telegraph at cast is the cue; re-drawing = double-cast look.)
	print("[EN] %s %s heal x%d (r%.1f %d%%)" % [enemy.enemy_id, String(chosen.get("ref", "")), healed, r, int(pct * 100.0)])


## Cooldown provoke signature (AB-099 Iron Mockery): face the engaged target (aim the front fan),
## fire only if a party actor is in that fan. Channeled (channel-freeze holds it); a fan-shaped
## telegraph shows the zone. Resolved by _resolve_enemy_attack → _apply_enemy_provoke.
func _try_cast_provoke(enemy: CharacterBody3D, target: CharacterBody3D) -> bool:
	for ab in enemy.abilities:
		if typeof(ab) != TYPE_DICTIONARY:
			continue
		var ref := String(ab.get("ref", ""))
		var eff: Dictionary = Slice01Data.get_ability(ref)
		if String(eff.get("kind", "")) != "enemy_provoke":
			continue
		if float(enemy.ability_cd.get(ref, 0.0)) > 0.0:
			continue  # AB still on cooldown
		var r := float(eff.get("zone_radius_m", 4.0))
		var deg := float(eff.get("zone_deg", 60.0))
		enemy.face_toward(target.global_position)  # aim the fan at the party it's fighting (cast-start)
		if _party_in_fan(enemy, r, deg).is_empty():
			return false  # no party actor in the front fan → don't taunt an empty zone
		enemy.winding = true
		enemy.windup_timer_s = float(eff.get("telegraph_s", 0.85))
		enemy.windup_eff = eff
		enemy.windup_chosen = {"ref": ref, "trigger": "signature"}
		enemy.windup_target = null
		enemy.ability_cd[ref] = float(eff.get("cooldown_s", 14.0))
		SkillVfx.fan_telegraph(self, enemy.global_position, enemy.facing, r, deg, _telegraph_color("enemy_provoke"), float(eff.get("telegraph_s", 0.85)))
		return true
	return false


## Resolve AB-099 Iron Mockery — apply Provoked to every party actor in the forward fan
## (front zone_deg°, zone_radius_m from the caster). Fan aimed by enemy.facing (set at cast).
func _apply_enemy_provoke(enemy: CharacterBody3D, eff: Dictionary, chosen: Dictionary) -> void:
	var r := float(eff.get("zone_radius_m", 4.0))
	var deg := float(eff.get("zone_deg", 60.0))
	var dur := float(eff.get("provoke_dur_s", 2.0))
	var n := 0
	for a in _party_in_fan(enemy, r, deg):
		if a.has_method("apply_provoke"):
			a.apply_provoke(enemy, dur)
			n += 1
	print("[EN] %s %s Provoked x%d (r%.1f %d° %.1fs)" % [enemy.enemy_id, String(chosen.get("ref", "")), n, r, int(deg), dur])


## Party actors inside the caster's forward fan (front `deg`° cone, `radius_m`). Used by
## AB-099 for both the cast condition and the resolve hit. facing = the caster's look dir.
func _party_in_fan(enemy: CharacterBody3D, radius_m: float, deg: float) -> Array:
	var out: Array = []
	var cos_half := cos(deg_to_rad(deg * 0.5))
	var ep: Vector3 = enemy.global_position
	var f: Vector3 = enemy.facing
	for a in _combat._allies_in_radius(ep, radius_m):
		if not is_instance_valid(a) or (a.has_method("is_alive") and not a.is_alive()):
			continue
		var to: Vector3 = a.global_position - ep
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or to.normalized().dot(f) >= cos_half:
			out.append(a)
	return out


## Dash intent colour: crimson = a damaging STRIKE (AB-013 backstab), teal = a non-damaging
## REPOSITION (AB-006 gap-close). Used for the telegraph, the trail, and the landing cue so the
## two dashes read as different actions at a glance.
func _dash_color(eff: Dictionary) -> Color:
	if bool(eff.get("hit_on_arrival", false)):
		return Color(0.92, 0.22, 0.24, 0.55)  # backstab — attack
	return Color(0.22, 0.9, 0.88, 0.5)         # gap-close — reposition


## Cooldown dash signature (AB-006 gap-close / AB-013 backstab): close the gap on the unit's
## current target (which is already the backline for flankers via target_pref). Fires when there's
## a real gap to the seen target within dash reach.
func _try_cast_dash(enemy: CharacterBody3D, target: CharacterBody3D, dist: float, has_los: bool) -> bool:
	if not has_los:
		return false
	for ab in enemy.abilities:
		if typeof(ab) != TYPE_DICTIONARY:
			continue
		var ref := String(ab.get("ref", ""))
		var eff: Dictionary = Slice01Data.get_ability(ref)
		if String(eff.get("kind", "")) != "enemy_dash":
			continue
		if float(enemy.ability_cd.get(ref, 0.0)) > 0.0:
			continue  # AB still on cooldown
		# Backstab (hit_on_arrival): STRIKE only from the FLANK — perpendicular to the party spine.
		# If not on the flank arc yet, hold and let REPOSITION circle there first (no head-on dash).
		if bool(eff.get("hit_on_arrival", false)):
			var axis := _party_flank_axis(enemy)
			if axis != Vector3.ZERO:
				var toe := enemy.global_position - target.global_position
				toe.y = 0.0
				if toe.length() < 0.01 or absf(toe.normalized().dot(axis)) < FLANK_STRIKE_COS:
					return false  # in the front/back arc → keep repositioning
		if dist <= enemy.attack_range_m + DASH_TRIGGER_BUFFER_M:
			return false
		if dist > float(eff.get("dash_range_m", DASH_MAX_M)):
			return false
		enemy.winding = true
		enemy.windup_timer_s = float(eff.get("telegraph_s", 0.3))
		enemy.windup_eff = eff
		enemy.windup_chosen = {"ref": ref, "trigger": "signature"}
		enemy.windup_target = target
		enemy.ability_cd[ref] = float(eff.get("cooldown_s", 5.0))
		SkillVfx.telegraph(self, enemy.global_position, _dash_color(eff))  # teal reposition / crimson strike
		return true
	return false


## Start the lunge after a dash telegraph: compute the destination (AB-006 = just inside melee;
## AB-013 = the target's flank), set a clamped velocity over DASH_TIME. The hit (AB-013) lands
## in _resolve_dash_hit when the timer elapses. Movement is driven by tick()'s dash takeover.
func _begin_dash(enemy: CharacterBody3D, eff: Dictionary, chosen: Dictionary, target: CharacterBody3D) -> void:
	var to := target.global_position - enemy.global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.01:
		return
	var dir := to / d
	var dest: Vector3
	if bool(eff.get("flank", false)):
		# AB-013: end at the target's flank (side fixed per-enemy), level with it.
		var perp := Vector3(-dir.z, 0.0, dir.x) * (1.0 if (enemy.get_instance_id() % 2 == 0) else -1.0)
		dest = target.global_position + perp * DASH_FLANK_OFFSET_M
	else:
		# AB-006: stop just inside melee range (pure gap-close, no overshoot).
		dest = enemy.global_position + dir * maxf(0.0, d - enemy.attack_range_m * 0.8)
	var move := dest - enemy.global_position
	move.y = 0.0
	if move.length() > DASH_MAX_M:
		move = move.normalized() * DASH_MAX_M
	enemy.dashing = true
	enemy.dash_timer_s = DASH_TIME
	enemy.dash_vel = move / DASH_TIME
	enemy.dash_eff = eff
	enemy.dash_chosen = chosen
	enemy.dash_target = target
	enemy.face_toward(target.global_position)
	# Trail in the dash's intent colour (teal reposition vs crimson strike) — the clearest tell
	# apart, since the flank dest also makes AB-013's streak curve to the side vs AB-006's straight-in.
	SkillVfx.dash_streak(self, enemy.global_position, enemy.global_position + move, _dash_color(eff))


## End of a dash: AB-013 lands its backstab if the target is still in reach (AB-006 is mobility
## only — no hit). Re-validates the target (it may have died/moved during the 0.2s lunge).
func _resolve_dash_hit(enemy: CharacterBody3D) -> void:
	var eff: Dictionary = enemy.dash_eff
	var chosen: Dictionary = enemy.dash_chosen
	var target: CharacterBody3D = enemy.dash_target
	enemy.dash_target = null
	if not bool(eff.get("hit_on_arrival", false)):
		SkillVfx.dash_land(self, enemy.global_position, _dash_color(eff))  # teal "repositioned" ring
		return  # AB-006 gap-close — no damage; normal flurry/orbit resumes
	if not is_instance_valid(target) or not target.is_alive():
		return
	var to := target.global_position - enemy.global_position
	to.y = 0.0
	if to.length() <= enemy.attack_range_m + 1.0:
		_apply_enemy_hit(enemy, target, eff, chosen)
	# Re-flank: the orbit profile's hit-and-run keep-distance (FLANK_KEEP) peels EN-008 back out and
	# holds the gap until AB-013 is off cooldown — no fixed backstep needed here.


## Disguised assassin reveal+execute (AssassinTransform): telegraph (assassin_telegraph_s) →
## a high-burst strike on the backline target. Resolved via _resolve_enemy_attack → _apply_enemy_hit
## (kind enemy_execute), which sets assassin_revealed. ref: ENC-NORM-003 / ENC-HARD-011.
func _begin_assassin_execute(enemy: CharacterBody3D, target: CharacterBody3D) -> void:
	enemy.attack_count += 1
	var eff := {
		"kind": "enemy_execute",
		"telegraph_s": float(enemy.assassin_telegraph_s),
		"damage_mult": ASSASSIN_EXECUTE_MULT,
		"knockback_m": 1.0,
		"vfx": "projectile",
	}
	enemy.winding = true
	enemy.windup_timer_s = float(enemy.assassin_telegraph_s)
	enemy.windup_eff = eff
	enemy.windup_chosen = {"ref": "", "trigger": "assassin"}
	enemy.windup_target = target
	SkillVfx.telegraph(self, target.global_position, _telegraph_color("enemy_execute"))
	print("[EN] %s ASSASSIN reveal (%.2fs) -> %s" % [enemy.enemy_id, float(enemy.assassin_telegraph_s), target.identity_skill_id])


## Backline execute target for the disguised assassin: the squishiest NON-Tank living member
## (Tanks pushed to the back of the queue) — the "후열 처형" victim. null if no member.
func _pick_backline_target(nodes: Array) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_score := INF
	for n in _alive_members(nodes):
		if not is_instance_valid(n):
			continue
		var is_tank := String(n.get("class_id")) == "Tank"
		var score: float = float(n.hp) + (100000.0 if is_tank else 0.0)  # prefer non-Tank, then low HP
		if score < best_score:
			best_score = score
			best = n
	return best


## Choose this attack-gate's strike: a ready in-range signature (its AB cooldown elapsed) takes
## priority over the basic. Heal/provoke/dash are NOT picked here — they fire via their own cooldown
## passes. The chosen signature's cooldown is reset in _begin_enemy_attack when it's committed.
func _select_enemy_ability(enemy: CharacterBody3D) -> Dictionary:
	# Signature kinds that fire as a "special attack" through the attack gate (need in-range + LOS).
	var gate_kinds := ["enemy_charge", "enemy_splash", "enemy_hex", "enemy_melee", "enemy_stun", "enemy_poison"]
	for ab in enemy.abilities:
		if typeof(ab) != TYPE_DICTIONARY:
			continue
		var ref := String(ab.get("ref", ""))
		if ref.is_empty():
			continue
		var eff: Dictionary = Slice01Data.get_ability(ref)
		if not gate_kinds.has(String(eff.get("kind", ""))):
			continue  # heal/provoke/dash → own passes
		if float(enemy.ability_cd.get(ref, 0.0)) <= 0.0:
			return {"ref": ref, "trigger": "signature"}  # off cooldown → cast (cd set on commit)
	# Otherwise the unit's rom_* basic archetype (EN-COR-000 §rom_*).
	if enemy.basic_attack != "":
		return {"ref": enemy.basic_attack, "trigger": "basic"}
	return {}


func _alive_members(nodes: Array) -> Array:
	var out: Array = []
	for n in nodes:
		if is_instance_valid(n) and (not n.has_method("is_alive") or n.is_alive()):
			out.append(n)
	return out


## Nearest living party member the enemy has clear line of sight to (null if none).
## Used as the no-threat fallback so enemies never lock onto unseen, distant members.
func _nearest_visible(enemy: CharacterBody3D, nodes: Array) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d := INF
	var from: Vector3 = enemy.global_position
	for n in nodes:
		if not is_instance_valid(n):
			continue
		if n.has_method("is_alive") and not n.is_alive():
			continue
		var d: float = from.distance_squared_to(n.global_position)
		if d >= best_d:
			continue
		if not _has_los(enemy, n):
			continue
		best_d = d
		best = n
	return best

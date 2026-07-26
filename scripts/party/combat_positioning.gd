extends Node
## CombatPositioning — goal-point logic for 전투우선 followers (where to stand when the
## party engages): the post-contact slot-break trigger, melee close-to-attack-range
## point, and the healer's "stay on the wounded" support point. Extracted from
## PartyController to isolate combat positioning from the steering/formation engine
## (ARCHITECTURE DEBT-GOD). A child of PartyController; reads the member list via it.
## ref: F-004 (safe-first slot break) · F-005 (healer role).

var _party: Node3D  # PartyController — owns _members / formation
## 팔로워별 교전 커밋 상태(줄다리기 방지): member instance_id → {"target": Node, "until_ms": int}.
var _engage: Dictionary = {}


func setup(party: Node3D) -> void:
	_party = party


func has_live_enemies() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			return true
	return false


## Is any live enemy within basic attack range of a non-controlled, living
## follower? Horizontal distance (party floats above enemies). This is the
## post-contact trigger for leaving formation — until an enemy is this close,
## followers hold their slots instead of charging a distant foe.
func enemy_in_party_basic_range() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return false
	for m in _party._members:
		if not is_instance_valid(m) or m.is_controlled():
			continue
		if m.has_method("is_alive") and not m.is_alive():
			continue
		var r: float = float(m.get("basic_range_m"))
		var r2 := r * r
		var mp: Vector3 = m.global_position
		for e in enemies:
			if not is_instance_valid(e):
				continue
			var d: Vector3 = mp - e.global_position
			d.y = 0.0
			if d.length_squared() <= r2:
				return true
	return false


## Goal point for an engaging follower. Healers position to keep the most-wounded
## ally inside heal range (support); everyone else closes to attack range of the
## nearest enemy. `slot_target` is the safe fallback when there's no goal.
const MELEE_RANGE_MAX := 3.5  # basic_range above this = ranged → deal from the backline (no approach)
## 근접 팔로워 추격 리시: 포메이션 슬롯에서 이 반경(수평) 안의 적만 교전(카이터 무한추격/대열이탈 방지).
## 표적이 밖으로 나가면 같은 반경의 다른 적으로 재타겟, 없으면 슬롯 홀드. ref: 사용자.
const FOLLOWER_ENGAGE_LEASH_M := 5.0
## 탱커는 교전을 여는 전방 리더라 리시 반경이 더 넉넉(게이팅 첫타 도달용). 이보다 먼 단독 카이터는 못 열 수 있음.
const FOLLOWER_ENGAGE_LEASH_TANK_M := 8.0
## 줄다리기 방지 — 깊은 acquire + 시간기반 엣지 홀드 + 짧은 복귀 인터미션 (ref: 사용자):
##  · ACQUIRE = leash×ENGAGE_ACQUIRE_FRAC (깊이): 이 안으로 빨려들어와야 (재)교전 — 엣지 진동은 재트리거 X
##  · 표적이 leash(엣지) 밖으로 나가면 리시 엣지에서 HOLD_EDGE_S 동안 "잠시 홀드"(최단거리 지점 추적) 후 복귀.
##    단 leash×ENGAGE_HARD_RELEASE_MULT보다 멀면 홀드 없이 즉시 놓음(맵 너머 추적 방지).
##  · 놓은 뒤 REENGAGE_INTERMISSION_S 동안 재교전 금지(복귀 중 즉시 재무름 방지)
##  · 전환은 커밋(ENGAGE_COMMIT_S) 후 새 표적이 ENGAGE_SWITCH_MARGIN_M 이상 더 가까울 때만
const ENGAGE_ACQUIRE_FRAC := 0.65
const HOLD_EDGE_S := 2.5
const ENGAGE_HARD_RELEASE_MULT := 2.0
const ENGAGE_COMMIT_S := 2.5
const ENGAGE_SWITCH_MARGIN_M := 1.5
const REENGAGE_INTERMISSION_S := 0.3

func engage_target(member: CharacterBody3D, slot_target: Vector3) -> Vector3:
	# Healer (radius_heal): stay on the wounded, not on the enemy.
	if String(member.identity_params.get("kind", "")) == "radius_heal":
		return _healer_support_target(member, slot_target)
	var br: float = float(member.get("basic_range_m"))
	# Ranged dealers (DPS / ranged Nuker) attack from the backline — hold the formation slot;
	# auto-attack picks up any enemy in range. They never approach ahead of the tank.
	if br > MELEE_RANGE_MAX:
		return slot_target
	var mp := member.global_position
	var reach: float = clampf(br - 0.6, 0.8, br)
	var is_tank := String(member.get("class_id")) == "Tank"
	var leash: float = FOLLOWER_ENGAGE_LEASH_TANK_M if is_tank else FOLLOWER_ENGAGE_LEASH_M
	# Committed engage target (깊은 acquire / 넓은 release 히스테리시스 + 복귀 인터미션). null → 슬롯 복귀.
	var foe := _committed_engage_target(member, slot_target, leash)
	if foe == null:
		return slot_target
	var epos := foe.global_position
	var goal: Vector3
	if is_tank:
		# Tank LEADS: close STRAIGHT to melee range (no flank) — must reach a foe for the gating hit.
		var tdir := Vector2(mp.x - epos.x, mp.z - epos.z)
		var td := tdir.length()
		if td <= reach or td < 0.001:
			goal = Vector3(mp.x, epos.y, mp.z)  # in range — hold & attack
		else:
			tdir /= td
			goal = Vector3(epos.x + tdir.x * reach, epos.y, epos.z + tdir.y * reach)
	else:
		# Melee dealer: FLANK point off the tank→enemy axis — side attack, behind the front.
		var me := Vector2(mp.x - epos.x, mp.z - epos.z)
		var tank: Variant = _tank_position()
		var flank: Vector2
		if tank != null:
			var t3: Vector3 = tank
			var axis := Vector2(epos.x - t3.x, epos.z - t3.z)  # tank→enemy = front direction
			axis = axis.normalized() if axis.length() > 0.01 else Vector2(0.0, 1.0)
			var perp := Vector2(-axis.y, axis.x)
			if me.dot(perp) < 0.0:
				perp = -perp                       # the flank side the member is already on
			flank = perp
		else:
			flank = me.normalized() if me.length() > 0.01 else Vector2(0.0, 1.0)  # no tank → own side
		goal = epos + Vector3(flank.x, 0.0, flank.y) * reach
		goal.y = epos.y
	# Idea 1 — CLAMP the goal to the leash edge from the SLOT (continuous). 적이 사거리 밖이면 goal이 엣지에
	# 연속으로 머물러 "전방 가드" → 슬롯↔적 급점프(줄다리기)가 사라진다. ref: 사용자.
	var off := Vector2(goal.x - slot_target.x, goal.z - slot_target.z)
	if off.length() > leash:
		off = off.normalized() * leash
		goal.x = slot_target.x + off.x
		goal.z = slot_target.z + off.y   # off = Vector2(dx, dz) → 두 번째 성분은 .y
	return goal


## Nearest live enemy within `radius` (horizontal) of `center` = the follower's formation slot — the
## leashed engage candidate. null → no in-leash foe, so the melee dealer holds its slot (no chase-out).
func _nearest_enemy_within(center: Vector3, radius: float) -> Node3D:
	var nearest: Node3D = null
	var best := radius * radius
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length_squared()
		if d < best:
			best = d
			nearest = e
	return nearest


## node에서 포메이션 슬롯까지의 수평 거리.
func _slot_dist(node: Node3D, slot: Vector3) -> float:
	return Vector2(node.global_position.x - slot.x, node.global_position.z - slot.z).length()


## 교전 표적 선택 — 깊은 acquire + 시간기반 엣지 홀드 + 짧은 복귀 인터미션(줄다리기 방지). 물고 있는 표적이
## leash(엣지) 안이면 교전(도달), 밖으로 나가면 리시 엣지에서 HOLD_EDGE_S 동안 유지("잠시 홀드", goal은 엣지로
## 클램프됨) 후 복귀. leash×ENGAGE_HARD_RELEASE_MULT보다 멀면 즉시 놓음. 홀드 중 acquire 안에 새 적이 빨려들면
## 그쪽으로 즉시 전환. 놓은 뒤 REENGAGE_INTERMISSION_S 재교전 금지. 죽은 표적은 즉시 재획득. null=슬롯 홀드.
func _committed_engage_target(member: CharacterBody3D, slot_target: Vector3, leash: float) -> Node3D:
	var acquire_r := leash * ENGAGE_ACQUIRE_FRAC              # 깊이 — 이 안으로 들어와야 (재)교전
	var hard_release := leash * ENGAGE_HARD_RELEASE_MULT      # 이보다 멀면 홀드 없이 즉시 놓음
	var now := Time.get_ticks_msec()
	var key := member.get_instance_id()
	var st: Dictionary = _engage.get(key, {})
	var cur = st.get("target", null)
	var cur_ok: bool = cur != null and is_instance_valid(cur) and (not cur.has_method("is_alive") or cur.is_alive())
	if cur_ok:
		var d := _slot_dist(cur, slot_target)
		if d <= leash:
			# ENGAGE (도달 가능) — 홀드 타이머 해제 + 커밋 만료 시 acquire 안 '더 가까운' 적으로만 전환.
			st.erase("hold_ms")
			if now >= int(st.get("until_ms", 0)):
				var cand := _nearest_enemy_within(slot_target, acquire_r)
				if cand != null and cand != cur and _slot_dist(cand, slot_target) < d - ENGAGE_SWITCH_MARGIN_M:
					cur = cand
					st["target"] = cur
				st["until_ms"] = now + int(ENGAGE_COMMIT_S * 1000.0)
			_engage[key] = st
			return cur
		if d <= hard_release:
			# 엣지 밖이지만 너무 멀진 않음 → 새로 깊이 들어온 적 있으면 즉시 전환, 아니면 엣지에서 잠시 홀드.
			var near := _nearest_enemy_within(slot_target, acquire_r)
			if near != null:
				_engage[key] = {"target": near, "until_ms": now + int(ENGAGE_COMMIT_S * 1000.0)}
				return near
			var hold_ms := int(st.get("hold_ms", 0))
			if hold_ms == 0:
				hold_ms = now + int(HOLD_EDGE_S * 1000.0)    # 엣지 진입 순간부터 홀드 시작
				st["hold_ms"] = hold_ms
				_engage[key] = st
			if now < hold_ms:
				return cur                                   # HOLD_EDGE_S 동안 엣지에서 잠시 홀드
		# hard_release 밖 OR 홀드 창 만료 → 놓음 → 복귀 인터미션.
		_engage[key] = {"reengage_after_ms": now + int(REENGAGE_INTERMISSION_S * 1000.0)}
		return null
	# 비교전(대기/복귀): 인터미션 중이면 홀드, 지나면 acquire(깊이) 안에 빨려든 적만 (재)교전.
	if now < int(st.get("reengage_after_ms", 0)):
		return null
	var best := _nearest_enemy_within(slot_target, acquire_r)
	if best == null:
		_engage.erase(key)
		return null
	_engage[key] = {"target": best, "until_ms": now + int(ENGAGE_COMMIT_S * 1000.0)}
	return best


## Living tank's position (the front line) or null — the melee flank is taken off the
## tank→enemy axis so dealers attack from the side, behind the front.
func _tank_position() -> Variant:
	for m in _party._members:
		if is_instance_valid(m) and String(m.get("class_id")) == "Tank" \
				and (not m.has_method("is_alive") or m.is_alive()):
			return m.global_position
	return null


## Healer combat goal: move so the most-wounded ally (below its Mend Circle
## threshold) sits inside heal radius. Stops just inside so jitter can't drop the
## target out of range. If nobody needs healing, hold the safe formation slot —
## the healer never chases enemies. ref: F-005 healer role.
func _healer_support_target(member: CharacterBody3D, slot_target: Vector3) -> Vector3:
	var wounded := _lowest_hp_ally_below_threshold(member)
	if wounded == null:
		return slot_target  # nobody to heal — stay safe with the formation
	var mp := member.global_position
	var radius: float = float(member.identity_params.get("radius_m", 4.0))
	var reach: float = clampf(radius - 0.8, 1.0, radius)
	var to := mp - wounded.global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= reach or dist < 0.001:
		return Vector3(mp.x, wounded.global_position.y, mp.z)  # in range — hold
	var t := wounded.global_position + (to / dist) * reach
	t.y = wounded.global_position.y
	return t


## Most-wounded living ally below its Mend Circle heal threshold (Tank vs others),
## using the same thresholds as AbilityDispatch._cast_mend_circle so the healer
## repositions exactly for the allies its heal would target. null if all are fine.
func _lowest_hp_ally_below_threshold(healer: CharacterBody3D) -> CharacterBody3D:
	var p: Dictionary = healer.identity_params
	var ally_t: float = float(p.get("ally_threshold_pct", 0.85))
	var tank_t: float = float(p.get("tank_threshold_pct", 0.90))
	var best: CharacterBody3D = null
	var best_ratio := INF
	for m in _party._members:
		if not is_instance_valid(m):
			continue
		if m.has_method("is_alive") and not m.is_alive():
			continue
		var mhp: float = float(m.max_hp)
		if mhp <= 0.0:
			continue
		var ratio: float = float(m.hp) / mhp
		var t: float = tank_t if String(m.get("class_id")) == "Tank" else ally_t
		if ratio < t and ratio < best_ratio:
			best_ratio = ratio
			best = m
	return best
